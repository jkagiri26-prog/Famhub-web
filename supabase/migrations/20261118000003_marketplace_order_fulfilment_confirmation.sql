-- Marketplace order fulfilment confirmation: accepted -> confirmed.
--
-- The existing trg_process_order_stock trigger performs physical consumption
-- by inserting the canonical commerce.stock_movements row, whose
-- trg_apply_stock_movement trigger decreases stock_registry.quantity, and by
-- decreasing stock_registry.reserved_quantity. This migration does not replace
-- or duplicate that path.
--
-- The new RPC is atomic with the trigger. It validates the order, reservation
-- and stock immediately before the single status update, then marks the
-- reservation consumed and verifies the stock movement. Any failure rolls the
-- entire transition back, leaving the order accepted.

ALTER TABLE commerce.orders
  ADD COLUMN IF NOT EXISTS confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS stock_consumed_at timestamptz;

COMMENT ON COLUMN commerce.orders.confirmed_at IS
  'When seller fulfilment confirmation moved the order to confirmed.';
COMMENT ON COLUMN commerce.orders.stock_consumed_at IS
  'Set atomically with confirmed when the canonical stock movement succeeded.';

CREATE OR REPLACE FUNCTION commerce.confirm_order_fulfilment(p_order_id uuid)
RETURNS commerce.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_profile_id uuid;
  v_entity_id uuid;
  v_order commerce.orders%ROWTYPE;
  v_reservation commerce.stock_reservations%ROWTYPE;
  v_stock_id uuid;
  v_reserved_qty numeric := 0;
  v_reservation_count integer := 0;
  v_item_count integer;
  v_item_qty numeric;
  v_item_stock_id uuid;
  v_stock_qty numeric;
  v_stock_reserved numeric;
  v_movement_count integer;
  v_movement_sum numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  v_profile_id := core.current_profile_id();
  IF v_profile_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM users.profiles AS p
    WHERE p.id = v_profile_id
      AND p.is_active = true
      AND p.account_status = 'active'
      AND p.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'active seller profile required' USING ERRCODE = '42501';
  END IF;

  v_entity_id := core.get_active_entity();
  IF v_entity_id IS NULL THEN
    RAISE EXCEPTION 'active seller entity required' USING ERRCODE = '42501';
  END IF;

  SELECT *
    INTO v_order
  FROM commerce.orders AS o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_entity_id IS DISTINCT FROM v_order.seller_entity_id
     OR NOT commerce.can_access_stock(v_order.seller_entity_id) THEN
    RAISE EXCEPTION 'not authorized to confirm this order' USING ERRCODE = '42501';
  END IF;

  -- Replay is a true no-op. No order UPDATE occurs, so the canonical AFTER
  -- UPDATE trigger cannot create a second stock movement.
  IF v_order.status = 'confirmed' THEN
    RETURN v_order;
  END IF;

  IF v_order.status <> 'accepted' THEN
    RAISE EXCEPTION 'order cannot be confirmed from status %', v_order.status
      USING ERRCODE = '22023';
  END IF;

  IF v_order.payment_status = 'completed' THEN
    -- The existing trigger intentionally skips stock when payment is complete.
    -- This milestone must not mix payment completion with fulfilment.
    RAISE EXCEPTION 'fulfilment confirmation requires an unpaid order reservation'
      USING ERRCODE = '22023';
  END IF;

  -- Require the existing reservation to be present and still valid.
  FOR v_reservation IN
    SELECT *
    FROM commerce.stock_reservations AS r
    WHERE r.order_id = v_order.id
      AND r.status = 'reserved'
    FOR UPDATE
  LOOP
    IF v_stock_id IS NULL THEN
      v_stock_id := v_reservation.stock_id;
    ELSIF v_stock_id <> v_reservation.stock_id THEN
      RAISE EXCEPTION 'order reservation spans multiple stock rows'
        USING ERRCODE = 'P0001';
    END IF;
    v_reserved_qty := v_reserved_qty + v_reservation.quantity;
    v_reservation_count := v_reservation_count + 1;
  END LOOP;

  IF v_reservation_count = 0 OR v_reserved_qty <= 0 THEN
    RAISE EXCEPTION 'valid reserved stock is required for confirmation'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_reserved_qty <> v_order.quantity THEN
    RAISE EXCEPTION 'reserved quantity does not match order quantity'
      USING ERRCODE = 'P0001';
  END IF;

  -- The existing trigger consumes from order_items. The order foundation
  -- creates exactly one line, so enforce that contract rather than guessing
  -- how to reconcile a multi-line order with a single reservation.
  SELECT count(*)::integer, COALESCE(sum(oi.quantity), 0)
    INTO v_item_count, v_item_qty
  FROM commerce.order_items AS oi
  WHERE oi.order_id = v_order.id;

  IF v_item_count <> 1 OR v_item_qty <> v_reserved_qty THEN
    RAISE EXCEPTION 'order item quantity does not match reserved stock'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT oi.stock_id
    INTO v_item_stock_id
  FROM commerce.order_items AS oi
  WHERE oi.order_id = v_order.id
  LIMIT 1;

  IF v_item_stock_id IS DISTINCT FROM v_stock_id THEN
    RAISE EXCEPTION 'order item stock does not match reservation'
      USING ERRCODE = 'P0001';
  END IF;

  -- Serialize any competing stock change and validate both counters before
  -- the trigger is allowed to consume.
  SELECT sr.quantity, sr.reserved_quantity
    INTO v_stock_qty, v_stock_reserved
  FROM commerce.stock_registry AS sr
  WHERE sr.id = v_stock_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'reserved stock row not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_stock_qty < v_reserved_qty THEN
    RAISE EXCEPTION 'physical stock is insufficient for fulfilment'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stock_reserved < v_reserved_qty THEN
    RAISE EXCEPTION 'reservation accounting is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM commerce.stock_movements AS sm
    WHERE sm.order_id = v_order.id
      AND sm.source_module = 'commerce.orders'
      AND sm.source_type = 'order'
      AND sm.movement_type = 'sale'
  ) THEN
    RAISE EXCEPTION 'order already has a fulfilment stock movement'
      USING ERRCODE = 'P0001';
  END IF;

  -- Single order UPDATE. The canonical AFTER UPDATE trigger performs:
  --   * stock_movements insert (sale, negative quantity)
  --   * stock_registry.quantity decrease through apply_stock_movement()
  --   * stock_registry.reserved_quantity decrease
  -- No direct quantity mutation occurs in this function.
  UPDATE commerce.orders
  SET status = 'confirmed',
      confirmed_at = now(),
      stock_consumed_at = now(),
      status_changed_by_profile_id = v_profile_id,
      status_reason = NULL,
      updated_at = now()
  WHERE id = v_order.id
  RETURNING * INTO v_order;

  -- The trigger intentionally does not update stock_reservations. Mark the
  -- reservation consumed only after the physical movement succeeded.
  UPDATE commerce.stock_reservations
  SET status = 'consumed'
  WHERE order_id = v_order.id
    AND status = 'reserved';

  GET DIAGNOSTICS v_reservation_count = ROW_COUNT;
  IF v_reservation_count = 0 THEN
    RAISE EXCEPTION 'reservation was not consumed' USING ERRCODE = 'P0001';
  END IF;

  -- Verify the canonical movement happened exactly once and for the exact
  -- reserved quantity. Any mismatch aborts and rolls back order/status/stock.
  SELECT count(*)::integer, COALESCE(sum(sm.quantity_change), 0)
    INTO v_movement_count, v_movement_sum
  FROM commerce.stock_movements AS sm
  WHERE sm.order_id = v_order.id
    AND sm.source_module = 'commerce.orders'
    AND sm.source_type = 'order'
    AND sm.movement_type = 'sale'
    AND sm.stock_id = v_stock_id;

  IF v_movement_count <> 1 OR v_movement_sum <> -v_reserved_qty THEN
    RAISE EXCEPTION 'canonical stock consumption did not match reservation'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT sr.quantity, sr.reserved_quantity
    INTO v_stock_qty, v_stock_reserved
  FROM commerce.stock_registry AS sr
  WHERE sr.id = v_stock_id;

  IF v_stock_qty < 0 OR v_stock_reserved < 0 THEN
    RAISE EXCEPTION 'stock counters became negative' USING ERRCODE = 'P0001';
  END IF;

  RETURN v_order;
END;
$function$;

COMMENT ON FUNCTION commerce.confirm_order_fulfilment(uuid) IS
  'Seller confirms accepted order; existing process_order_stock trigger performs the single canonical physical stock consumption.';

REVOKE ALL ON FUNCTION commerce.confirm_order_fulfilment(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.confirm_order_fulfilment(uuid)
  TO authenticated;

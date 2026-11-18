-- Marketplace order lifecycle: seller acceptance/rejection and buyer
-- cancellation.
--
-- Scope:
--   * extends the existing commerce.orders status set with accepted/rejected;
--   * reuses commerce.stock_reservations and stock_registry.reserved_quantity;
--   * releases reservations exactly once;
--   * does not touch payment_status, payments, Finance, M-Pesa or fulfilment.
--
-- Lifecycle:
--   pending -> accepted (seller; reservation preserved)
--   pending -> rejected (seller; reservation released)
--   pending -> cancelled (buyer; reservation released)
--   accepted is intentionally NOT confirmed: the existing
--   trg_process_order_stock trigger consumes stock on confirmed, while seller
--   acceptance must preserve the reservation. Fulfilment/payment remains a
--   later milestone.

ALTER TABLE commerce.orders
  ADD COLUMN IF NOT EXISTS accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS rejected_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS stock_released_at timestamptz,
  ADD COLUMN IF NOT EXISTS status_changed_by_profile_id uuid
    REFERENCES users.profiles(id),
  ADD COLUMN IF NOT EXISTS status_reason text;

COMMENT ON COLUMN commerce.orders.accepted_at IS
  'When the seller accepted the order. Acceptance preserves stock reservation.';
COMMENT ON COLUMN commerce.orders.rejected_at IS
  'When the seller rejected the order.';
COMMENT ON COLUMN commerce.orders.cancelled_at IS
  'When the buyer cancelled the order.';
COMMENT ON COLUMN commerce.orders.stock_released_at IS
  'When the order reservation was released; NULL while stock remains reserved.';
COMMENT ON COLUMN commerce.orders.status_changed_by_profile_id IS
  'Authenticated profile that performed the latest lifecycle transition.';
COMMENT ON COLUMN commerce.orders.status_reason IS
  'Optional seller/buyer supplied lifecycle reason; never a financial value.';

ALTER TABLE commerce.orders
  DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE commerce.orders
  ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'pending',
    'accepted',
    'confirmed',
    'shipped',
    'delivered',
    'rejected',
    'cancelled',
    'returned'
  )) NOT VALID;

-- Lifecycle writes must go through the RPCs so stock release cannot be
-- bypassed. Reads remain available under existing RLS.
REVOKE UPDATE, DELETE ON commerce.orders FROM anon, authenticated;
DROP POLICY IF EXISTS "orders_supplier_update" ON commerce.orders;
DROP POLICY IF EXISTS "orders_update_supplier" ON commerce.orders;
DROP POLICY IF EXISTS "orders_delete_supplier" ON commerce.orders;

-- Reservations are internal stock state. Browser roles must not be able to
-- release or rewrite another order's reservation directly.
REVOKE ALL ON TABLE commerce.stock_reservations FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- Internal once-only release primitive.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.release_order_stock_reservation(
  p_order_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_reservation commerce.stock_reservations%ROWTYPE;
  v_stock_id uuid;
  v_release_qty numeric := 0;
  v_reserved_qty numeric;
BEGIN
  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'order_id is required' USING ERRCODE = '22023';
  END IF;

  FOR v_reservation IN
    SELECT *
    FROM commerce.stock_reservations AS r
    WHERE r.order_id = p_order_id
      AND r.status = 'reserved'
    FOR UPDATE
  LOOP
    IF v_stock_id IS NULL THEN
      v_stock_id := v_reservation.stock_id;
    ELSIF v_stock_id <> v_reservation.stock_id THEN
      RAISE EXCEPTION 'order reservation spans multiple stock rows'
        USING ERRCODE = 'P0001';
    END IF;
    v_release_qty := v_release_qty + v_reservation.quantity;
  END LOOP;

  IF v_release_qty <= 0 THEN
    RAISE EXCEPTION 'no reserved stock found for order' USING ERRCODE = 'P0001';
  END IF;

  SELECT sr.reserved_quantity
    INTO v_reserved_qty
  FROM commerce.stock_registry AS sr
  WHERE sr.id = v_stock_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'reserved stock row not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_reserved_qty < v_release_qty THEN
    RAISE EXCEPTION 'reservation accounting is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE commerce.stock_registry
  SET reserved_quantity = reserved_quantity - v_release_qty,
      updated_at = now()
  WHERE id = v_stock_id;

  UPDATE commerce.stock_reservations
  SET status = 'released'
  WHERE order_id = p_order_id
    AND status = 'reserved';

  RETURN v_release_qty;
END;
$function$;

REVOKE ALL ON FUNCTION commerce.release_order_stock_reservation(uuid)
  FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Seller acceptance: pending -> accepted, reservation preserved.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.accept_listing_order(p_order_id uuid)
RETURNS commerce.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_profile_id uuid;
  v_entity_id uuid;
  v_order commerce.orders%ROWTYPE;
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
    RAISE EXCEPTION 'not authorized to accept this order' USING ERRCODE = '42501';
  END IF;

  IF v_order.status = 'accepted' THEN
    RETURN v_order;
  END IF;

  IF v_order.status <> 'pending' THEN
    RAISE EXCEPTION 'order cannot be accepted from status %', v_order.status
      USING ERRCODE = '22023';
  END IF;

  UPDATE commerce.orders
  SET status = 'accepted',
      accepted_at = now(),
      status_changed_by_profile_id = v_profile_id,
      status_reason = NULL,
      updated_at = now()
  WHERE id = v_order.id
  RETURNING * INTO v_order;

  RETURN v_order;
END;
$function$;

COMMENT ON FUNCTION commerce.accept_listing_order(uuid) IS
  'Seller accepts a pending order without consuming or releasing its stock reservation.';

REVOKE ALL ON FUNCTION commerce.accept_listing_order(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.accept_listing_order(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- Seller rejection: pending -> rejected, release reservation once.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.reject_listing_order(
  p_order_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS commerce.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_profile_id uuid;
  v_entity_id uuid;
  v_order commerce.orders%ROWTYPE;
  v_reason text;
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
    RAISE EXCEPTION 'not authorized to reject this order' USING ERRCODE = '42501';
  END IF;

  IF v_order.status = 'rejected' THEN
    RETURN v_order;
  END IF;

  IF v_order.status <> 'pending' THEN
    RAISE EXCEPTION 'order cannot be rejected from status %', v_order.status
      USING ERRCODE = '22023';
  END IF;

  PERFORM commerce.release_order_stock_reservation(v_order.id);
  v_reason := NULLIF(btrim(COALESCE(p_reason, '')), '');

  UPDATE commerce.orders
  SET status = 'rejected',
      rejected_at = now(),
      stock_released_at = now(),
      status_changed_by_profile_id = v_profile_id,
      status_reason = v_reason,
      updated_at = now()
  WHERE id = v_order.id
  RETURNING * INTO v_order;

  RETURN v_order;
END;
$function$;

COMMENT ON FUNCTION commerce.reject_listing_order(uuid, text) IS
  'Seller rejects a pending order and releases its reservation exactly once.';

REVOKE ALL ON FUNCTION commerce.reject_listing_order(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.reject_listing_order(uuid, text)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- Buyer cancellation: pending -> cancelled, release reservation once.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.cancel_listing_order(
  p_order_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS commerce.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_profile_id uuid;
  v_entity_id uuid;
  v_order commerce.orders%ROWTYPE;
  v_reason text;
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
    RAISE EXCEPTION 'active buyer profile required' USING ERRCODE = '42501';
  END IF;

  v_entity_id := core.get_active_entity();
  IF v_entity_id IS NULL THEN
    RAISE EXCEPTION 'active buyer entity required' USING ERRCODE = '42501';
  END IF;

  SELECT *
    INTO v_order
  FROM commerce.orders AS o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_profile_id IS DISTINCT FROM v_order.buyer_id
     OR v_entity_id IS DISTINCT FROM v_order.buyer_entity_id THEN
    RAISE EXCEPTION 'not authorized to cancel this order' USING ERRCODE = '42501';
  END IF;

  IF v_order.status = 'cancelled' THEN
    RETURN v_order;
  END IF;

  IF v_order.status <> 'pending' THEN
    RAISE EXCEPTION 'order cannot be cancelled from status %', v_order.status
      USING ERRCODE = '22023';
  END IF;

  PERFORM commerce.release_order_stock_reservation(v_order.id);
  v_reason := NULLIF(btrim(COALESCE(p_reason, '')), '');

  UPDATE commerce.orders
  SET status = 'cancelled',
      cancelled_at = now(),
      stock_released_at = now(),
      status_changed_by_profile_id = v_profile_id,
      status_reason = v_reason,
      updated_at = now()
  WHERE id = v_order.id
  RETURNING * INTO v_order;

  RETURN v_order;
END;
$function$;

COMMENT ON FUNCTION commerce.cancel_listing_order(uuid, text) IS
  'Buyer cancels a pending order and releases its reservation exactly once.';

REVOKE ALL ON FUNCTION commerce.cancel_listing_order(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.cancel_listing_order(uuid, text)
  TO authenticated;

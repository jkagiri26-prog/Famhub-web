-- Stock-accounting correction: exactly one authoritative mechanism per quantity.
--
-- Proven defect (rolled-back fixtures, no committed data):
--   Inserting commerce.order_items fires trg_reserve_stock -> commerce.reserve_stock(),
--   which increments stock_registry.reserved_quantity.
--   Completing payment then decremented stock THREE times and released reserved TWICE:
--     1. trg_process_order_stock (status='confirmed') inserts a stock_movement
--        -> trg_apply_stock_movement auto-applies it to quantity, and the trigger
--           also decrements reserved_quantity directly;
--     2. the completion function decremented quantity and reserved_quantity explicitly;
--     3. the completion function's own stock_movement insert auto-applied again.
--   Observable results before this fix:
--     * production-shaped row (reserved_quantity = this order's reservation):
--         ERROR 23514 stock_registry_reserved_quantity_check  -> completion always aborts;
--     * row with reserved headroom: quantity -3x, reserved_quantity -2x, 2 movement rows.
--
-- Fix:
--   * quantity            -> only commerce.apply_stock_movement(), driven by exactly one
--                            stock_movement row written by the completion function;
--   * reserved_quantity   -> only the completion function's explicit release;
--   * stock_reservations  -> only the completion function's delete;
--   * trg_process_order_stock  -> applies stock only when payment_status <> 'completed'
--                            (preserves the legacy non-payment confirmation path, which
--                            was already correct on its own: 1 movement + 1 release).
--
-- Scope notes:
--   * Does NOT modify commerce.assert_payment_verified (the applied fail-closed gate).
--   * Does NOT add any service_role bypass to commerce.assert_order_payment_authorized.
--   * Does NOT grant anon/authenticated access to any payment or stock table.
--   * No data changes; DDL only.

-- ---------------------------------------------------------------------------
-- 1. Trigger function: skip orders whose payment completion owns the stock write.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.process_order_stock()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.status = 'confirmed' AND NEW.payment_status <> 'completed' THEN

      INSERT INTO commerce.stock_movements (
            stock_id,
                  quantity_change,
                        movement_type,
                              source_module,
                                    source_type,
                                          source_ref_id,
                                                order_id
                                                    )
            SELECT
                  oi.stock_id,
                        -oi.quantity,
                              'sale',
                                    'commerce.orders',
                                          'order',
                                                NEW.id,
                                                      NEW.id
                  FROM commerce.order_items oi
                  WHERE oi.order_id = NEW.id;

      UPDATE commerce.stock_registry sr
         SET
    reserved_quantity = reserved_quantity - oi.quantity,
           updated_at = now()
         FROM commerce.order_items oi
         WHERE oi.order_id = NEW.id
               AND sr.id = oi.stock_id;

  END IF;

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Payment completion (order path).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.complete_order_payment(p_order_id uuid, p_transaction_ref text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_stock_id uuid;
  v_reserved_qty numeric;
  v_current_qty numeric;
  v_current_reserved numeric;
  v_verified_ref text;
BEGIN
  PERFORM commerce.assert_order_payment_authorized(p_order_id);

  -- Prevent double processing
  IF (SELECT payment_status FROM commerce.orders WHERE id = p_order_id) = 'completed' THEN
    RETURN;
  END IF;

  -- Fail closed: certify payment only from server-side provider verification
  v_verified_ref := commerce.assert_payment_verified(p_order_id, p_transaction_ref);

  -- Lock order
  UPDATE commerce.orders
     SET payment_status = 'completed',
         status = 'confirmed',
         updated_at = now()
   WHERE id = p_order_id;

  -- Get reservation + lock stock
  SELECT r.stock_id, r.quantity, sr.quantity, sr.reserved_quantity
    INTO v_stock_id, v_reserved_qty, v_current_qty, v_current_reserved
    FROM commerce.stock_reservations r
    JOIN commerce.stock_registry sr ON sr.id = r.stock_id
   WHERE r.order_id = p_order_id
     FOR UPDATE;

  IF v_stock_id IS NULL THEN
    RAISE EXCEPTION 'No reservation found for order';
  END IF;

  -- Safety check
  IF v_current_qty < v_reserved_qty THEN
    RAISE EXCEPTION 'Stock inconsistency detected';
  END IF;

  IF v_current_reserved < v_reserved_qty THEN
    RAISE EXCEPTION 'Stock inconsistency detected';
  END IF;

  -- Release reservation hold. quantity is deliberately NOT decremented here:
  -- the stock_movement insert below is applied to quantity by
  -- commerce.apply_stock_movement (trg_apply_stock_movement).
  UPDATE commerce.stock_registry
     SET reserved_quantity = reserved_quantity - v_reserved_qty,
         updated_at = now()
   WHERE id = v_stock_id;

  -- Record stock movement (the single quantity deduction for this payment)
  INSERT INTO commerce.stock_movements (
      stock_id, quantity_change, movement_type,
      source_module, source_type, source_ref_id, order_id, entity_id
  ) VALUES (
      v_stock_id, -v_reserved_qty, 'sale',
      'marketplace', 'order', p_order_id, p_order_id,
      (SELECT entity_id FROM commerce.orders WHERE id = p_order_id)
  );

  -- Record payment
  INSERT INTO commerce.transactions (
      order_id, supplier_id, amount, currency,
      payment_method, payment_status, transaction_id, recorded_by
  )
  SELECT o.id, o.supplier_id, o.total_amount, 'KES',
         'mpesa', 'completed', v_verified_ref, 'system'
    FROM commerce.orders o
   WHERE o.id = p_order_id;

  -- Remove reservation
  DELETE FROM commerce.stock_reservations
   WHERE order_id = p_order_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Payment completion (M-Pesa server path). Same accounting contract as above.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.server_complete_mpesa_payment(p_checkout_request_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'marketplace', 'core', 'users'
AS $function$
DECLARE
  v_pr            commerce.payment_requests%ROWTYPE;
  v_order         commerce.orders%ROWTYPE;
  v_verified_ref  text;
  v_tx_exists     boolean;
  v_stock_id      uuid;
  v_reserved_qty  numeric;
  v_current_qty   numeric;
  v_current_reserved numeric;
BEGIN
  IF coalesce(btrim(p_checkout_request_id), '') = '' THEN
    RAISE EXCEPTION 'checkout_request_id is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_pr
    FROM commerce.payment_requests
   WHERE checkout_request_id = p_checkout_request_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown payment request: %', p_checkout_request_id
      USING ERRCODE = '22023';
  END IF;

  -- Idempotency: only a verified request may complete anything, and only once.
  IF v_pr.status <> 'completed' THEN
    RETURN;
  END IF;

  IF coalesce(btrim(v_pr.mpesa_receipt_ref), '') = '' THEN
    RAISE EXCEPTION 'Provider receipt missing for payment request %', p_checkout_request_id
      USING ERRCODE = '42501',
            HINT = 'Record a verified provider receipt before completing payment.';
  END IF;

  SELECT * INTO v_order
    FROM commerce.orders
   WHERE id = v_pr.order_id
     FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', v_pr.order_id;
  END IF;

  -- Explicit verification-record check: reuses the applied fail-closed gate and
  -- requires the caller-supplied ref to equal the recorded provider receipt.
  v_verified_ref := commerce.assert_payment_verified(v_order.id, v_pr.mpesa_receipt_ref);

  -- Contact-unlock completion only when the schema actually links the unlock to
  -- this order (marketplace.unlock_contact leaves order_id NULL, so this is a no-op
  -- for the standalone unlock flow and is never forced through an order path).
  UPDATE marketplace.contact_unlocks
     SET payment_status = 'completed',
         unlocked       = true,
         valid_until    = NULL
   WHERE order_id = v_order.id
     AND payment_status = 'pending'
     AND unlocked = false;

  IF v_order.payment_status = 'completed' THEN
    RETURN;
  END IF;

  IF v_order.payment_status NOT IN ('pending', 'failed') THEN
    RAISE EXCEPTION 'Order payment_status is not eligible: %, status=%',
      v_order.id, v_order.payment_status;
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM commerce.transactions t
     WHERE t.order_id = v_order.id
       AND t.transaction_id = v_verified_ref
  ) INTO v_tx_exists;

  IF v_order.order_kind = 'service' THEN
    -- Mirrors commerce.complete_service_order_payment.
    IF NOT v_tx_exists THEN
      INSERT INTO commerce.transactions (
        id, order_id, supplier_id, amount, currency,
        payment_method, payment_status, transaction_id, recorded_by, profile_id
      ) VALUES (
        public.uuid_generate_v7(), v_order.id, v_order.supplier_id,
        v_order.total_amount, 'KES', 'mpesa', 'completed',
        v_verified_ref, 'system', v_order.buyer_id
      );
    END IF;

    UPDATE commerce.orders
       SET payment_status = 'completed',
           status         = 'confirmed',
           updated_at     = now()
     WHERE id = v_order.id
       AND payment_status <> 'completed';
  ELSE
    -- Mirrors commerce.complete_order_payment (stock orders).
    UPDATE commerce.orders
       SET payment_status = 'completed',
           status         = 'confirmed',
           updated_at     = now()
     WHERE id = v_order.id
       AND payment_status <> 'completed';

    SELECT r.stock_id, r.quantity, sr.quantity, sr.reserved_quantity
      INTO v_stock_id, v_reserved_qty, v_current_qty, v_current_reserved
      FROM commerce.stock_reservations r
      JOIN commerce.stock_registry sr ON sr.id = r.stock_id
     WHERE r.order_id = v_order.id
       FOR UPDATE;

    IF v_stock_id IS NULL THEN
      RAISE EXCEPTION 'No reservation found for order';
    END IF;

    IF v_current_qty < v_reserved_qty THEN
      RAISE EXCEPTION 'Stock inconsistency detected';
    END IF;

    IF v_current_reserved < v_reserved_qty THEN
      RAISE EXCEPTION 'Stock inconsistency detected';
    END IF;

    -- Release reservation hold only; the stock_movement insert below is the single
    -- quantity deduction (applied by commerce.apply_stock_movement).
    UPDATE commerce.stock_registry
       SET reserved_quantity = reserved_quantity - v_reserved_qty,
           updated_at        = now()
     WHERE id = v_stock_id;

    INSERT INTO commerce.stock_movements (
      stock_id, quantity_change, movement_type,
      source_module, source_type, source_ref_id, order_id, entity_id
    ) VALUES (
      v_stock_id, -v_reserved_qty, 'sale',
      'marketplace', 'order', v_order.id, v_order.id, v_order.entity_id
    );

    IF NOT v_tx_exists THEN
      INSERT INTO commerce.transactions (
        order_id, supplier_id, amount, currency,
        payment_method, payment_status, transaction_id, recorded_by
      ) VALUES (
        v_order.id, v_order.supplier_id, v_order.total_amount, 'KES',
        'mpesa', 'completed', v_verified_ref, 'system'
      );
    END IF;

    DELETE FROM commerce.stock_reservations WHERE order_id = v_order.id;
  END IF;
END;
$function$;

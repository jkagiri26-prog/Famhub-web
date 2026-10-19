-- Fail-closed payment-verification gate (Phase 0B, Step 1 - FINAL)
--
-- Closes every RPC path that can set payment_status = 'completed' without
-- trusted server-side provider verification. Verified complete-writer set:
--   commerce.process_order_payment(uuid)                     [SECDEF]
--   commerce.complete_order_payment(uuid,text)               [SECDEF]
--   commerce.complete_service_order_payment(uuid,text)       [SECDEF]
--   commerce.confirm_payment(uuid)                           [was INVOKER, PUBLIC EXECUTE, no guard]
--   marketplace.complete_contact_unlock_for_order(uuid)      [was INVOKER, anon EXECUTE, no guard]
-- (marketplace.get_seller_contact_for_unlock, marketplace.unlock_contact and
--  public.get_listing_with_contact only READ cu.payment_status - not writers.)
--
-- Changes: one new gate function; guard + idempotency + gate added to the two
-- previously unguarded functions; SECURITY DEFINER + pinned search_path added to
-- those two; PUBLIC/anon EXECUTE revoked from them; verified reference now
-- recorded in commerce.transactions instead of the caller-supplied one.
-- No signature is changed. No grant is added to service_role anywhere.
--
-- Restore path: payment processing resumes by writing a real server-side
-- verification row to commerce.payments - no code change required. There is
-- intentionally no rollback script: restoring the pre-gate bodies would
-- silently re-enable self-certification of payment.

CREATE OR REPLACE FUNCTION commerce.assert_payment_verified(
  p_order_id uuid,
  p_transaction_ref text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce'
AS $function$
DECLARE
  v_verified_ref      text;
  v_payment_amount    numeric;
  v_payment_currency  text;
  v_payment_payer     uuid;
  v_order_amount      numeric;
  v_order_buyer       uuid;
BEGIN
  SELECT p.transaction_ref, p.amount, p.currency, p.payer_id
    INTO v_verified_ref, v_payment_amount, v_payment_currency, v_payment_payer
    FROM commerce.payments AS p
   WHERE p.order_id = p_order_id
     AND p.payment_status = 'completed'
   ORDER BY p.created_at DESC, p.id DESC
   LIMIT 1;

  IF v_verified_ref IS NULL OR btrim(v_verified_ref) = '' THEN
    RAISE EXCEPTION 'Payment verification missing for order %', p_order_id
      USING ERRCODE = '42501',
            HINT = 'Record a server-side provider verification in commerce.payments (payment_status=completed with a non-empty transaction_ref) before completing payment.';
  END IF;

  -- commerce.orders has no currency column; every completion path writes 'KES'
  -- into commerce.transactions and commerce.payments.currency defaults to 'KES'.
  IF v_payment_currency IS NULL OR btrim(v_payment_currency) = ''
     OR upper(btrim(v_payment_currency)) <> 'KES' THEN
    RAISE EXCEPTION 'Payment currency mismatch for order %', p_order_id
      USING ERRCODE = '42501',
            HINT = 'Verified payment currency must be KES.';
  END IF;

  SELECT o.total_amount, o.buyer_id
    INTO v_order_amount, v_order_buyer
    FROM commerce.orders AS o
   WHERE o.id = p_order_id;

  IF v_order_amount IS NULL OR v_payment_amount IS NULL
     OR v_payment_amount <> v_order_amount THEN
    RAISE EXCEPTION 'Payment amount mismatch for order %', p_order_id
      USING ERRCODE = '42501',
            HINT = 'Verified payment amount must equal orders.total_amount.';
  END IF;

  IF v_order_buyer IS NULL OR v_payment_payer IS NULL
     OR v_payment_payer <> v_order_buyer THEN
    RAISE EXCEPTION 'Payment payer mismatch for order %', p_order_id
      USING ERRCODE = '42501',
            HINT = 'Verified payment payer_id must equal orders.buyer_id.';
  END IF;

  IF p_transaction_ref IS NOT NULL
     AND btrim(p_transaction_ref) <> btrim(v_verified_ref) THEN
    RAISE EXCEPTION 'Payment reference mismatch for order %', p_order_id
      USING ERRCODE = '42501',
            HINT = 'Caller-supplied transaction reference does not match the server-side verified reference.';
  END IF;

  RETURN v_verified_ref;
END;
$function$;

REVOKE ALL ON FUNCTION commerce.assert_payment_verified(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION commerce.assert_payment_verified(uuid, text) TO postgres, service_role;
CREATE OR REPLACE FUNCTION commerce.process_order_payment(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_payment_status text;
  v_stock_id uuid;
  v_required_qty numeric;
  v_available_qty numeric;
  v_verified_ref text;
BEGIN
  PERFORM commerce.assert_order_payment_authorized(p_order_id);

  -- Lock order (prevents race conditions)
  SELECT payment_status
    INTO v_payment_status
    FROM commerce.orders
   WHERE id = p_order_id
     FOR UPDATE;

  -- Idempotency guard
  IF v_payment_status = 'completed' THEN
    RETURN;
  END IF;

  -- Fail closed: certify payment only from server-side provider verification
  v_verified_ref := commerce.assert_payment_verified(p_order_id);

  -- Get reserved stock
  SELECT r.stock_id, r.quantity
    INTO v_stock_id, v_required_qty
    FROM commerce.stock_reservations r
   WHERE r.order_id = p_order_id
     FOR UPDATE;

  -- Lock stock row
  SELECT quantity
    INTO v_available_qty
    FROM commerce.stock_registry
   WHERE id = v_stock_id
     FOR UPDATE;

  -- Invariant check (NO NEGATIVE STOCK)
  IF v_available_qty < v_required_qty THEN
    RAISE EXCEPTION 'Insufficient stock for order %', p_order_id;
  END IF;

  -- Deduct stock safely
  UPDATE commerce.stock_registry
     SET quantity = quantity - v_required_qty,
         updated_at = now()
   WHERE id = v_stock_id;

  -- Mark payment completed
  UPDATE commerce.orders
     SET payment_status = 'completed',
         status = 'confirmed',
         updated_at = now()
   WHERE id = p_order_id;

  -- Record transaction
  INSERT INTO commerce.transactions (
      order_id, supplier_id, amount, currency, payment_method, payment_status, transaction_id
  )
  SELECT o.id, o.supplier_id, o.total_amount, 'KES', 'mpesa', 'completed', v_verified_ref
    FROM commerce.orders o
   WHERE o.id = p_order_id;

  -- Record stock movement
  INSERT INTO commerce.stock_movements (
      stock_id, quantity_change, movement_type,
      source_module, source_type, source_ref_id, order_id, entity_id
  )
  VALUES (
      v_stock_id, -v_required_qty, 'sale',
      'marketplace', 'order', p_order_id, p_order_id,
      (SELECT entity_id FROM commerce.orders WHERE id = p_order_id)
  );
END;
$function$;
CREATE OR REPLACE FUNCTION commerce.complete_order_payment(p_order_id uuid, p_transaction_ref text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_stock_id uuid;
  v_reserved_qty numeric;
  v_current_qty numeric;
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
  SELECT r.stock_id, r.quantity, sr.quantity
    INTO v_stock_id, v_reserved_qty, v_current_qty
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

  -- Deduct stock
  UPDATE commerce.stock_registry
     SET quantity = quantity - v_reserved_qty,
         reserved_quantity = reserved_quantity - v_reserved_qty,
         updated_at = now()
   WHERE id = v_stock_id;

  -- Record stock movement
  INSERT INTO commerce.stock_movements (
      stock_id, quantity_change, movement_type,
      source_module, source_type, source_ref_id, order_id, entity_id
  )
  VALUES (
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
CREATE OR REPLACE FUNCTION commerce.complete_service_order_payment(p_order_id uuid, p_transaction_ref text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users', 'public'
AS $function$
DECLARE
  v_order commerce.orders%rowtype;
  v_tx_exists boolean;
  v_payment_amount numeric;
  v_payment_currency text;
  v_payment_method text;
  v_payment_supplier_id uuid;
  v_buyer_id uuid;
  v_verified_ref text;
BEGIN
  PERFORM commerce.assert_order_payment_authorized(p_order_id);

  SELECT * INTO v_order
    FROM commerce.orders
   WHERE id = p_order_id
     FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.order_kind <> 'service' THEN
    RAISE EXCEPTION 'Order is not a service order: %', p_order_id;
  END IF;

  IF v_order.payment_status = 'completed' THEN
    RETURN;
  END IF;

  IF v_order.payment_status NOT IN ('pending','failed') THEN
    RAISE EXCEPTION 'Order payment_status is not eligible: %, status=%',
      p_order_id, v_order.payment_status;
  END IF;

  -- Fail closed: certify payment only from server-side provider verification
  v_verified_ref := commerce.assert_payment_verified(p_order_id, p_transaction_ref);

  -- Idempotency: don't create duplicate transaction records
  SELECT EXISTS (
    SELECT 1
      FROM commerce.transactions t
     WHERE t.order_id = p_order_id
       AND t.transaction_id = v_verified_ref
  ) INTO v_tx_exists;

  IF NOT v_tx_exists THEN
    v_payment_amount      := v_order.total_amount;
    v_payment_currency    := 'KES';
    v_payment_method      := 'mpesa';
    v_payment_supplier_id := v_order.supplier_id;
    v_buyer_id            := v_order.buyer_id;

    INSERT INTO commerce.transactions (
      id, order_id, supplier_id, amount, currency,
      payment_method, payment_status, transaction_id, recorded_by, profile_id
    ) VALUES (
      uuid_generate_v7(), v_order.id, v_payment_supplier_id, v_payment_amount,
      v_payment_currency, v_payment_method, 'completed', v_verified_ref,
      'system', v_buyer_id
    );
  END IF;

  UPDATE commerce.orders
     SET payment_status = 'completed',
         status = 'confirmed',
         updated_at = now()
   WHERE id = p_order_id
     AND payment_status <> 'completed';
END;
$function$;

CREATE OR REPLACE FUNCTION commerce.confirm_payment(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce'
AS $function$
BEGIN
  PERFORM commerce.assert_order_payment_authorized(p_order_id);

  IF (SELECT payment_status FROM commerce.orders WHERE id = p_order_id) = 'completed' THEN
    RETURN;
  END IF;

  PERFORM commerce.assert_payment_verified(p_order_id);

  UPDATE commerce.orders
     SET payment_status = 'completed',
         status = 'confirmed'
   WHERE id = p_order_id;

  UPDATE commerce.stock_reservations
     SET status = 'consumed'
   WHERE order_id = p_order_id;

  UPDATE commerce.stock_registry sr
     SET quantity = quantity - (
           SELECT o.quantity
             FROM commerce.orders o
            WHERE o.id = p_order_id
         )
   WHERE sr.id = (
           SELECT r.stock_id
             FROM commerce.stock_reservations r
            WHERE r.order_id = p_order_id
         );
END;
$function$;

CREATE OR REPLACE FUNCTION marketplace.complete_contact_unlock_for_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'marketplace'
AS $function$
DECLARE
  v_order commerce.orders%rowtype;
BEGIN
  PERFORM commerce.assert_order_payment_authorized(p_order_id);

  SELECT * INTO v_order
    FROM commerce.orders
   WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.order_kind <> 'service' THEN
    RAISE EXCEPTION 'Order is not a service order: %', p_order_id;
  END IF;

  PERFORM commerce.assert_payment_verified(p_order_id);

  UPDATE marketplace.contact_unlocks cu
     SET payment_status = 'completed',
         unlocked = true,
         valid_until = null
   WHERE cu.order_id = p_order_id
     AND cu.payment_status = 'pending'
     AND cu.unlocked = false;
END;
$function$;

-- least privilege: neither function may be reached unauthenticated
REVOKE ALL ON FUNCTION commerce.confirm_payment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.confirm_payment(uuid) TO postgres, authenticated, service_role;

REVOKE ALL ON FUNCTION marketplace.complete_contact_unlock_for_order(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION marketplace.complete_contact_unlock_for_order(uuid) TO postgres, authenticated, service_role;

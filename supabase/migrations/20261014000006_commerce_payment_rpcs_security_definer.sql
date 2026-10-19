-- ============================================================================
-- 20261014000006_commerce_payment_rpcs_security_definer
-- Phase 0B / SEPARATE -- PREPARED, REQUIRES EXPLICIT APPROVAL BEFORE APPLYING
-- ----------------------------------------------------------------------------
-- PURPOSE
--   This is the migration that makes the LAST part of 0B safe: once these
--   three RPCs no longer depend on the caller's table privileges,
--   `authenticated` can finally be revoked from commerce.transactions.
--   Batch 1 (20261014000004) deliberately stopped at revoking `anon` only.
--
-- WHY IT IS SEPARATE
--   Converting an invoker-rights RPC to SECURITY DEFINER changes WHO the
--   database trusts when the function runs. That is a payment-path change and
--   must be approved on its own, after 0B batch 1 has been observed.
--
-- PROBLEM
--   commerce.process_order_payment
--   commerce.complete_order_payment
--   commerce.complete_service_order_payment
--   are all invoker-rights (prosecdef = false), search_path NOT pinned, and
--   each INSERTs into commerce.transactions. They therefore inherit whatever
--   privileges the caller holds -- which today is full DML on that table.
--
-- WHAT THIS CHANGES
--   1. Adds commerce.assert_order_payment_authorized(p_order_id uuid)
--      SECURITY DEFINER, search_path pinned to pg_catalog + the schemas it
--      touches. Raises unless the caller is the order's buyer, or the caller
--      holds the `admin.overview` permission. Anon therefore cannot proceed.
--   2. Rewrites the three RPCs as SECURITY DEFINER with a pinned search_path
--      and the authorization guard as their first statement. Bodies are
--      otherwise unchanged: same column lists, same idempotency guards, same
--      stock invariant checks, same 'KES'/'mpesa' literals.
--   3. Revokes EXECUTE on the RPCs from anon and PUBLIC.
--
-- BEHAVIOUR DIFFERENCES (both intentional, both flagged)
--   a. Unauthorized or anonymous callers now get a clear exception instead of
--      a silent no-op. No authorized flow is affected.
--   b. complete_order_payment previously returned silently when p_order_id did
--      not exist (the UPDATE simply matched zero rows). It now raises
--      'Order payment unauthorized or not found'. Treating a missing order as
--      a silent success is unsafe, so this is kept as a deliberate tightening.
--
-- AFTER THIS MIGRATION IS APPLIED AND VERIFIED, RUN:
--   REVOKE ALL PRIVILEGES ON TABLE commerce.transactions FROM authenticated;
--   (see 20261014000007_revoke_authenticated_commerce_transactions.sql)
-- ============================================================================
--
-- STATUS (recorded 2026-10-19, Piece 5A audit -- comment-only note; no SQL changed)
--   This migration IS RECORDED AS APPLIED in supabase_migrations.schema_migrations
--   (version 20261014000006, name commerce_payment_rpcs_security_definer) and its
--   effects are live: the payment RPCs are SECURITY DEFINER with pinned
--   search_path, and anon EXECUTE has been revoked. It was applied via
--   /root/supabase/baseline/apply_packet_separate_5_6_7.sql, which is why the
--   "requires explicit approval" wording above was never reconciled.
--   DO NOT RE-APPLY. The executable SQL below is identical to the applied copy
--   (normalized checksum verified against the database-stored statements).

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Shared authorization guard
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.assert_order_payment_authorized(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_caller_profile uuid;
  v_buyer_id       uuid;
BEGIN
  v_caller_profile := core.current_profile_id();

  IF v_caller_profile IS NULL THEN
    RAISE EXCEPTION 'Order payment unauthorized: no authenticated profile'
      USING ERRCODE = '42501';
  END IF;

  SELECT o.buyer_id INTO v_buyer_id
  FROM commerce.orders AS o
  WHERE o.id = p_order_id;

  IF v_buyer_id IS NOT NULL AND v_buyer_id = v_caller_profile THEN
    RETURN;
  END IF;

  IF core.has_permission('admin.overview') THEN
    RETURN;
  END IF;

  RAISE EXCEPTION 'Order payment unauthorized or not found: %', p_order_id
    USING ERRCODE = '42501';
END;
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION commerce.assert_order_payment_authorized(uuid)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION commerce.assert_order_payment_authorized(uuid)
    TO authenticated, service_role, postgres;

-- ---------------------------------------------------------------------------
-- 2. process_order_payment -- authorization guard prepended, body otherwise unchanged
-- ---------------------------------------------------------------------------
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
      order_id, supplier_id, amount, currency, payment_method, payment_status
  )
  SELECT o.id, o.supplier_id, o.total_amount, 'KES', 'mpesa', 'completed'
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

-- ---------------------------------------------------------------------------
-- 3. complete_order_payment
-- ---------------------------------------------------------------------------
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
BEGIN
  PERFORM commerce.assert_order_payment_authorized(p_order_id);

  -- Prevent double processing
  IF (SELECT payment_status FROM commerce.orders WHERE id = p_order_id) = 'completed' THEN
    RETURN;
  END IF;

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
         'mpesa', 'completed', p_transaction_ref, 'system'
    FROM commerce.orders o
   WHERE o.id = p_order_id;

  -- Remove reservation
  DELETE FROM commerce.stock_reservations
   WHERE order_id = p_order_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. complete_service_order_payment
-- ---------------------------------------------------------------------------
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

  -- Idempotency: don't create duplicate transaction records
  SELECT EXISTS (
    SELECT 1
      FROM commerce.transactions t
     WHERE t.order_id = p_order_id
       AND t.transaction_id = p_transaction_ref
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
      v_payment_currency, v_payment_method, 'completed', p_transaction_ref,
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

-- ---------------------------------------------------------------------------
-- 5. Lock down who may call them
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON FUNCTION commerce.process_order_payment(uuid)
    FROM PUBLIC, anon;
REVOKE ALL PRIVILEGES ON FUNCTION commerce.complete_order_payment(uuid, text)
    FROM PUBLIC, anon;
REVOKE ALL PRIVILEGES ON FUNCTION commerce.complete_service_order_payment(uuid, text)
    FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION commerce.process_order_payment(uuid)
    TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION commerce.complete_order_payment(uuid, text)
    TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION commerce.complete_service_order_payment(uuid, text)
    TO authenticated, service_role, postgres;

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- DROP FUNCTION IF EXISTS commerce.assert_order_payment_authorized(uuid);
-- Then restore the three original invoker-rights bodies from
--   baseline/schema_manifest_20261014.sql  (section [FUNCTION] commerce.*)
-- and re-grant EXECUTE to PUBLIC and anon.

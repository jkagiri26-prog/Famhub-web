-- M-Pesa (Daraja) STK Push: server-created payment requests keyed by CheckoutRequestID,
-- duplicate-payment guard, and a narrowly scoped server-only completion path.
--
-- Scope notes:
--   * Does NOT modify commerce.assert_payment_verified (the applied fail-closed gate).
--   * Does NOT add any service_role bypass to commerce.assert_order_payment_authorized.
--   * Does NOT grant anon/authenticated any access to payment tables.
--   * Does NOT touch marketplace.contact_unlocks (unlock flow is order-unlinked by design;
--     marketplace.unlock_contact inserts with order_id NULL).

-- ---------------------------------------------------------------------------
-- 1. Server-created payment request, correlated to Daraja CheckoutRequestID.
--    `amount` / `initiated_by` are written by the Edge Function from the
--    authenticated caller + commerce.orders, never from client-supplied values.
-- ---------------------------------------------------------------------------
CREATE TABLE commerce.payment_requests (
  id                   uuid PRIMARY KEY DEFAULT public.uuid_generate_v7(),
  order_id             uuid NOT NULL REFERENCES commerce.orders(id) ON DELETE CASCADE,
  checkout_request_id  text NOT NULL,
  phone                text NOT NULL,
  amount               numeric NOT NULL CHECK (amount > 0),
  currency             text NOT NULL DEFAULT 'KES' CHECK (upper(btrim(currency)) = 'KES'),
  status               text NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','completed','failed','cancelled','rejected','expired')),
  initiated_by         uuid REFERENCES users.profiles(id),
  result_code          integer,
  result_desc          text,
  mpesa_receipt_ref    text,
  provider_response    jsonb,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  verified_at          timestamptz,
  expires_at           timestamptz
);

CREATE UNIQUE INDEX payment_requests_checkout_request_id_key
  ON commerce.payment_requests (checkout_request_id);

CREATE INDEX payment_requests_order_id_idx
  ON commerce.payment_requests (order_id);

CREATE TRIGGER set_updated_at BEFORE UPDATE ON commerce.payment_requests
  FOR EACH ROW EXECUTE FUNCTION core.set_updated_at();

-- RLS on, no policies: only postgres / service_role (the Edge Function) can touch it.
ALTER TABLE commerce.payment_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE commerce.payment_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE commerce.payment_requests TO service_role;

-- ---------------------------------------------------------------------------
-- 2. Prevent duplicate verified payment records for the same provider receipt.
--    Completed rows are required by the gate to carry a non-empty transaction_ref,
--    so the predicate covers every row the gate can ever read.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX payments_completed_transaction_ref_key
  ON commerce.payments (transaction_ref)
  WHERE payment_status = 'completed'
    AND transaction_ref IS NOT NULL
    AND btrim(transaction_ref) <> '';

-- ---------------------------------------------------------------------------
-- 3. Narrow server-only completion path (Edge Function / service_role only).
--    Explicit verification-record check reuses the applied gate, is idempotent,
--    has a pinned search_path, and is not executable by anon/authenticated.
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

    SELECT r.stock_id, r.quantity, sr.quantity
      INTO v_stock_id, v_reserved_qty, v_current_qty
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

    UPDATE commerce.stock_registry
       SET quantity           = quantity - v_reserved_qty,
           reserved_quantity  = reserved_quantity - v_reserved_qty,
           updated_at         = now()
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

REVOKE ALL ON FUNCTION commerce.server_complete_mpesa_payment(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION commerce.server_complete_mpesa_payment(text)
  TO postgres, service_role;

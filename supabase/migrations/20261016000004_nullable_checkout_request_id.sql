-- STK initiation durability: allow a payment request to exist BEFORE Daraja is called.
--
-- Why: commerce.payment_requests.checkout_request_id was NOT NULL, so the local record
-- could only be written after Daraja returned a CheckoutRequestID. If that insert failed
-- the callback had no row to find, returned 200 "unknown", and a real charge had no
-- local record. Recording the request first guarantees every initiation attempt leaves
-- durable evidence; the CheckoutRequestID is adopted immediately afterwards.
--
-- Scope notes:
--   * Does NOT modify commerce.assert_payment_verified (the applied fail-closed gate).
--   * Does NOT add any service_role bypass to commerce.assert_order_payment_authorized.
--   * Does NOT grant anon/authenticated access to payment tables.
--   * No data changes; DDL only.

ALTER TABLE commerce.payment_requests
  ALTER COLUMN checkout_request_id DROP NOT NULL;

-- The unique index already allows any number of NULLs (PostgreSQL treats NULLs as
-- distinct), so concurrent in-flight initiations remain possible while a completed
-- request can never lose its provider correlation.
ALTER TABLE commerce.payment_requests
  ADD CONSTRAINT payment_requests_completed_requires_checkout
  CHECK (status <> 'completed' OR checkout_request_id IS NOT NULL);

CREATE INDEX payment_requests_pending_order_idx
  ON commerce.payment_requests (order_id)
  WHERE status = 'pending';

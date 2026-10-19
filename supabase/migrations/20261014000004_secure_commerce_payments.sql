-- ============================================================================
-- 20261014000004_secure_commerce_payments
-- Phase 0B / batch 1 -- FAMHUB Unified Subscriptions, Entitlements & Usage
-- ----------------------------------------------------------------------------
-- GOAL
--   Remove the anonymous write path into the commerce ledger while leaving
--   the authenticated payment-RPC path intact for this batch.
--
-- SPLIT DECISION (important)
--   commerce.payments       -- deny outright.
--                             rls=true with ZERO policies today, and NO
--                             function in the database INSERTs into it.
--                             Revoking client privileges changes nothing for
--                             legitimate flows: they were already blocked by RLS.
--
--   commerce.transactions   -- revoke `anon` ONLY in this batch.
--                             Three non-SECURITY-DEFINER functions write to it:
--                               commerce.process_order_payment
--                               commerce.complete_order_payment
--                               commerce.complete_service_order_payment
--                             Because they are invoker-rights, they run with the
--                             caller's privileges. Revoking `authenticated` now
--                             would BREAK every payment completion flow.
--                             The follow-up migration
--                             20261014000006_commerce_payment_rpcs_security_definer.sql
--                             converts those three to SECURITY DEFINER with a
--                             pinned search_path and an explicit ownership
--                             check; only then may `authenticated` be revoked.
--
-- BEFORE STATE (verified 2026-10-14)
--   commerce.payments       rls=true  policies=0  anon=arwdDxtm authenticated=arwdDxtm
--   commerce.transactions   rls=false policies=0  anon=arwdDxtm authenticated=arwdDxtm
--
-- AFFECTED OBJECTS
--   commerce.payments, commerce.transactions
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. commerce.payments -- full client deny (RLS already blocks reads anyway)
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE commerce.payments FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. commerce.transactions -- anonymous caller deny only
--    Keep `authenticated` SELECT + INSERT + UPDATE + DELETE so the three
--    invoker-rights payment RPCs continue to work.
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE commerce.transactions FROM anon;

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE commerce.payments      TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE commerce.transactions  TO anon;

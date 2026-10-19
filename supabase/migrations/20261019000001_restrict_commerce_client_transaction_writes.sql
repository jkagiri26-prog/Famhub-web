-- ============================================================================
-- 20261019000001_restrict_commerce_client_transaction_writes
-- ----------------------------------------------------------------------------
-- Records a privilege repair that was ALREADY APPLIED AND VERIFIED on the
-- live Supabase project (ref erbxiqdfjmqnoeyjupru). This migration exists so
-- the recorded state matches the repository; do not treat it as a pending
-- change to be re-applied blindly (running it is a no-op if live state was
-- already verified).
--
-- GOAL
--   Remove unintended client-side WRITE access to the commerce ledger while
--   preserving the one supported client read path:
--     * anon: no table privileges on commerce.transactions or commerce.payments.
--     * authenticated: SELECT only on both tables (required by the Business
--       Hub payments tab, which reads commerce.transactions directly).
--     * service_role / postgres: unchanged.
--   Writes to commerce.transactions continue only through the SECURITY
--   DEFINER payment RPCs (20261014000006); commerce.payments rows are written
--   only by the mpesa_callback Edge Function via service_role.
--
-- BEFORE STATE (live-verified pre-repair)
--   commerce.transactions  rls=false  policies=none
--     postgres=arwdDxtm service_role=arwdDxtm anon=arwd authenticated=arwd
--   commerce.payments      rls=true   policies=none
--     postgres=arwdDxtm service_role=arwdDxtm anon=arwd authenticated=arwd
--   (The anon/authenticated arwd grants were the ROLLBACK text from
--   migrations 20261014000001-4 / 20261014000007 having been executed,
--   which undid those migrations' revokes.)
--
-- AFTER STATE (live-verified post-repair)
--   commerce.transactions  rls=false  policies=none
--     postgres=arwdDxtm service_role=arwdDxtm authenticated=arwd(SELECT only)
--   commerce.payments      rls=true   policies=none
--     postgres=arwdDxtm service_role=arwdDxtm authenticated=arwd(SELECT only)
--
-- NOTES
--   * Does NOT change RLS, FORCE RLS, or row policies on either table
--     (transactions stays rls=false; payments stays rls=true with zero
--     policies; service_role bypasses RLS regardless).
--   * Does NOT change service_role or postgres privileges.
--   * Does NOT touch commerce.payment_requests or any other commerce table.
--   * Runtime verification of the Business Hub read path and an M-Pesa
--     callback regression test were NOT performed at repair time; only the
--     ACL/RLS/RPC-definition/row-count verification queries were run.
-- ============================================================================

BEGIN;

REVOKE ALL PRIVILEGES ON TABLE commerce.transactions FROM anon;
REVOKE ALL PRIVILEGES ON TABLE commerce.payments FROM anon;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON TABLE commerce.transactions FROM authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON TABLE commerce.payments    FROM authenticated;

COMMIT;

-- ============================================================================
-- ROLLBACK  (SECURITY-SENSITIVE -- DO NOT RUN AUTOMATICALLY)
-- ============================================================================
-- Restoring these grants re-opens direct client write access to the commerce
-- ledger for every anon/authenticated session. It must only ever be executed
-- as an explicitly approved emergency reversion (and the pre-repair security
-- finding would immediately be reinstated).
--
-- Previous grants, exactly as present before this repair:
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE commerce.transactions TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE commerce.payments    TO anon, authenticated;

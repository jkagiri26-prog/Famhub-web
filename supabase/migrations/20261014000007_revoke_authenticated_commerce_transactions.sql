-- ============================================================================
-- 20261014000007_revoke_authenticated_commerce_transactions
-- Phase 0B / SEPARATE -- APPLY ONLY AFTER 20261014000006 IS VERIFIED
-- ----------------------------------------------------------------------------
-- PREREQUISITE
--   20261014000006_commerce_payment_rpcs_security_definer.sql must be applied
--   AND the payment smoke test must pass (see
--   baseline/phase0b_pre_post_validation.sql, section E).
--
-- GOAL
--   Complete the last open client path into the commerce ledger. After this
--   statement, no `anon` or `authenticated` session can read, insert, update,
--   or delete a row in commerce.transactions. Only postgres and service_role
--   can -- via the three SECURITY DEFINER RPCs.
--
-- BEFORE STATE (after 0B batch 1 + migration 6)
--   commerce.transactions  rls=false
--   postgres=arwdDxtm authenticated=arwd service_role=arwd   (anon removed)
--
-- AFTER STATE
--   postgres=arwdDxtm service_role=arwd
--
-- NOTE
--   RLS is deliberately left disabled on this table. The table is now
--   reachable only by the table owner and by service_role; enabling RLS
--   without policies would also block service_role unless a policy is written
--   for it, which is an Entitlements-phase concern, not a Phase 0 one.
-- ============================================================================

BEGIN;

REVOKE ALL PRIVILEGES ON TABLE commerce.transactions FROM authenticated;

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE commerce.transactions TO authenticated;

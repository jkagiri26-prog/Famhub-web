-- ============================================================================
-- 20261014000001_secure_system_billing_ledger
-- Phase 0B / batch 1 -- FAMHUB Unified Subscriptions, Entitlements & Usage
-- ----------------------------------------------------------------------------
-- GOAL
--   Close the unauthenticated AND authenticated direct-data path into the
--   financial core of the platform. These 12 tables are internal-only state;
--   no DB object and no application code reads them (verified 2026-10-14).
--
-- WHAT THIS DOES
--   1. Revoke every table privilege currently held by `anon` and
--      `authenticated` (today: SELECT, INSERT, UPDATE, DELETE).
--   2. Enable Row Level Security so that even a future mistaken GRANT cannot
--      expose rows: with RLS on and zero policies, all non-privileged roles
--      read 0 rows and write 0 rows.
--   3. Creates NO policies. Client access is intentionally denied.
--
-- WHAT THIS DOES NOT DO
--   - No data is read, written, or migrated.
--   - No column, constraint, index, or trigger is altered.
--   - `service_role` and the table owner are untouched, so Edge Functions
--     and server-side work are unaffected.
--   - `system.active_subscriptions.status` keeps its questionable
--     DEFAULT 'active'; correcting it is Phase 1+ (changes behaviour).
--
-- BEFORE STATE (verified 2026-10-14 via pg_class.relacl / pg_policies)
--   Every table: rls=false, force=false, policies=0,
--   relacl={postgres=arwdDxtm, anon=arwd, authenticated=arwd, service_role=arwd}
--
-- AFFECTED OBJECTS
--   system.active_subscriptions     system.revenue_ledger
--   system.billing_accounts         system.wallet_balances
--   system.invoices                 system.payout_requests
--   system.invoice_items            system.payout_disbursements
--   system.payment_attempts         system.commission_rules
--   system.transaction_reconciliation   system.module_access_rules
--
-- ROLLBACK (exact restore of the before state; see ROLLBACK section at EOF)
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Deny-by-revocation for anon + authenticated
-- ---------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON TABLE system.active_subscriptions       FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.billing_accounts           FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.invoices                   FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.invoice_items              FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.payment_attempts           FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.transaction_reconciliation FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.revenue_ledger             FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.wallet_balances            FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.payout_requests            FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.payout_disbursements       FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.commission_rules           FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE system.module_access_rules        FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Defense in depth: enable RLS with no policies (deny-all for non-owners)
-- ---------------------------------------------------------------------------
ALTER TABLE system.active_subscriptions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.billing_accounts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.invoices                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.invoice_items              ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.payment_attempts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.transaction_reconciliation ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.revenue_ledger             ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.wallet_balances            ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.payout_requests            ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.payout_disbursements       ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.commission_rules           ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.module_access_rules        ENABLE ROW LEVEL SECURITY;

COMMIT;

-- ============================================================================
-- ROLLBACK -- run only if this migration must be reverted
-- ============================================================================
-- ALTER TABLE system.active_subscriptions       DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.billing_accounts           DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.invoices                   DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.invoice_items              DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.payment_attempts           DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.transaction_reconciliation DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.revenue_ledger             DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.wallet_balances            DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.payout_requests            DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.payout_disbursements       DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.commission_rules           DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.module_access_rules        DISABLE ROW LEVEL SECURITY;
--
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.active_subscriptions       TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.billing_accounts           TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.invoices                   TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.invoice_items              TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.payment_attempts           TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.transaction_reconciliation TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.revenue_ledger             TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.wallet_balances            TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.payout_requests            TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.payout_disbursements       TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.commission_rules           TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.module_access_rules        TO anon, authenticated;

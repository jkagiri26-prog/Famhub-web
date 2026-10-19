-- ============================================================================
-- 20261014000003_secure_marketplace_and_market_pricing
-- Phase 0B / batch 1 -- FAMHUB Unified Subscriptions, Entitlements & Usage
-- ----------------------------------------------------------------------------
-- GOAL
--   Remove client write access to the two pricing configuration tables while
--   preserving every read path that a verified consumer depends on.
--
-- CONSUMER EVIDENCE (2026-10-14, full pg_proc.prosrc scan)
--   market_prices.platform_pricing
--       read by public.set_promoted_amount()  -- BEFORE INSERT OR UPDATE
--                                          --    trigger on core.unlocks_expiry_log
--                                          --    NOT security-definer, NO search_path pin
--       -> SELECT must remain available to the role that writes
--          core.unlocks_expiry_log (today: anon + authenticated).
--   marketplace.buyer_pricing
--       read by marketplace.unlock_contact()  -- SECURITY DEFINER, search_path pinned
--       existing policy: anon_select_buyer_pricing (SELECT TO anon USING true)
--       -> unaffected by revoking client DML.
--   Flutter app: no reference to either table (verified by .from()/.schema()
--   inventory of /tmp/opencode/fa).
--
-- BEFORE STATE (verified 2026-10-14)
--   market_prices.platform_pricing  rls=false policies=0  anon=arwdDxtm authenticated=arwdDxtm
--   marketplace.buyer_pricing       rls=true  policies=1  anon=arwdDxtm authenticated=arwdDxtm
--
-- AFTER STATE
--   both tables: client INSERT/UPDATE/DELETE/TRUNCATE revoked; RLS enabled;
--   SELECT preserved (policy for platform_pricing, existing policy for
--   buyer_pricing).
--
-- SEPARATE FINDING (not remediated here -- reported to the operator)
--   core.unlocks_expiry_log is client-writable (anon=arwdDxtm, rls=false) and
--   is the only writer into the unlock-expiry audit trail. It should be made
--   server-authoritative in a later migration, which would then let
--   platform_pricing drop its client SELECT policy as well.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. market_prices.platform_pricing -- keep read, drop write
-- ---------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON TABLE market_prices.platform_pricing FROM anon, authenticated;

ALTER TABLE market_prices.platform_pricing ENABLE ROW LEVEL SECURITY;

CREATE POLICY platform_pricing_read_catalog
    ON market_prices.platform_pricing
    FOR SELECT TO anon, authenticated
    USING (true);

-- ---------------------------------------------------------------------------
-- 2. marketplace.buyer_pricing -- keep the existing anon read policy, drop write
-- ---------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON TABLE marketplace.buyer_pricing FROM anon, authenticated;

-- RLS is already enabled here with anon_select_buyer_pricing; nothing to change.

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- DROP POLICY IF EXISTS platform_pricing_read_catalog ON market_prices.platform_pricing;
-- ALTER TABLE market_prices.platform_pricing DISABLE ROW LEVEL SECURITY;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE market_prices.platform_pricing TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE marketplace.buyer_pricing     TO anon, authenticated;

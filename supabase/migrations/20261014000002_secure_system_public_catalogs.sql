-- ============================================================================
-- 20261014000002_secure_system_public_catalogs
-- Phase 0B / batch 1 -- FAMHUB Unified Subscriptions, Entitlements & Usage
-- ----------------------------------------------------------------------------
-- GOAL
--   Make the three public "catalog" tables read-only for clients while
--   preserving the one read path that is verified to be live.
--
-- WHY THIS GROUP
--   These tables are configuration catalogs that the Flutter app reads on
--   start-up to decide which modules to show. They must stay readable; they
--   must never be writable or deletable from a client.
--
-- CONSUMER EVIDENCE (2026-10-14)
--   system.modules         -> lib/core/services/module_service.dart:54
--                             `schema('system').from('modules')`
--                             lib/core/feature_flags/infrastructure/repositories/module_repository.dart:20
--   system.feature_flags   -> read by the same repository pair
--   system.subscription_plans -> no DB object references it; read only as a
--                             public price catalog (kept readable on purpose)
--
-- BEFORE STATE (verified 2026-10-14)
--   All three: rls=false, policies=0,
--   relacl={postgres=arwdDxtm, anon=arwd, authenticated=arwd, service_role=arwd}
--   -> clients currently hold full write access. Removing that is the fix.
--
-- AFTER STATE
--   rls=true, one permissive SELECT policy for `anon, authenticated`
--   USING (true). INSERT / UPDATE / DELETE / TRUNCATE denied by revocation.
--
-- NOTE
--   `system.modules` is referenced by a Supabase Realtime subscription in the
--   app. Enabling RLS does not block Realtime: the SELECT policy keeps the
--   rows visible to anon and authenticated.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Drop client write access, keep client read access
-- ---------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON TABLE system.modules           FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON TABLE system.feature_flags     FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON TABLE system.subscription_plans FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Turn RLS on and grant the read path explicitly via policy
-- ---------------------------------------------------------------------------
ALTER TABLE system.modules            ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.feature_flags      ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY modules_read_catalog
    ON system.modules
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY feature_flags_read_catalog
    ON system.feature_flags
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY subscription_plans_read_catalog
    ON system.subscription_plans
    FOR SELECT TO anon, authenticated
    USING (true);

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- DROP POLICY IF EXISTS modules_read_catalog           ON system.modules;
-- DROP POLICY IF EXISTS feature_flags_read_catalog     ON system.feature_flags;
-- DROP POLICY IF EXISTS subscription_plans_read_catalog ON system.subscription_plans;
-- ALTER TABLE system.modules            DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.feature_flags      DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE system.subscription_plans DISABLE ROW LEVEL SECURITY;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.modules            TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.feature_flags      TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system.subscription_plans TO anon, authenticated;

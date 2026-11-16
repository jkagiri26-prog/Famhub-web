-- ============================================================================
-- ALREADY APPLIED — repository migration body restored from deployed audited state
-- 20261114000010_revoke_direct_referral_consumer_service_execute
-- ----------------------------------------------------------------------------
-- Forward-only removal of the direct service-role consumer entry point.
--
-- Verified internal call chain:
--   system.process_referral_finance_events
--     -> referrals.process_pending_finance_events
--       -> referrals.consume_finance_event
--         -> referrals.consume_finance_event_core
--
-- All four functions are SECURITY DEFINER and owned by postgres. The worker
-- gateway is granted to service_role. The internal calls execute as the owner,
-- so the owner's implicit EXECUTE privilege preserves the worker path without
-- granting direct consumer access to service_role, anon, or authenticated.
--
-- This migration only changes the public EXECUTE ACL. It does not replace any
-- function, owner, SECURITY DEFINER setting, or pinned search_path.
-- ============================================================================

BEGIN;

DO $preflight$
DECLARE
    v_invalid text;
BEGIN
    SELECT string_agg(format('%I.%I', n.nspname, p.proname), ', ')
      INTO v_invalid
      FROM pg_proc AS p
      JOIN pg_namespace AS n ON n.oid = p.pronamespace
     WHERE (
             (n.nspname = 'system'
              AND p.proname = 'process_referral_finance_events')
             OR
             (n.nspname = 'referrals'
              AND p.proname IN (
                  'process_pending_finance_events',
                  'consume_finance_event',
                  'consume_finance_event_core'
              ))
           )
       AND (
             pg_get_userbyid(p.proowner) <> 'postgres'
             OR p.prosecdef IS NOT TRUE
           );

    IF v_invalid IS NOT NULL THEN
        RAISE EXCEPTION
            'Worker call chain must remain SECURITY DEFINER and postgres-owned; invalid: %',
            v_invalid
            USING ERRCODE = '55000';
    END IF;
END;
$preflight$;

REVOKE EXECUTE ON FUNCTION referrals.consume_finance_event(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

COMMIT;

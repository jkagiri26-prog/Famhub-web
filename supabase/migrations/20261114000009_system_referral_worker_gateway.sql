-- ============================================================================
-- ALREADY APPLIED — repository migration body restored from deployed audited state
-- 20261114000009_system_referral_worker_gateway
-- ----------------------------------------------------------------------------
-- Narrow service-role worker gateway in the already exposed system schema.
-- The referrals schema does not need to be exposed to PostgREST.
--
-- system.process_referral_finance_events: service_role only.
-- system.replay_referral_finance_event: authenticated Admin only.
-- Internal referrals implementations remain private.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION system.process_referral_finance_events(
    p_limit integer DEFAULT 50,
    p_max_attempts integer DEFAULT 5
)
RETURNS TABLE(
    gate_enabled boolean,
    selected_count integer,
    processed_count integer,
    failed_count integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'referrals'
AS $function$
  SELECT *
    FROM referrals.process_pending_finance_events(p_limit, p_max_attempts);
$function$;

ALTER FUNCTION system.process_referral_finance_events(integer, integer) OWNER TO postgres;
REVOKE ALL ON FUNCTION system.process_referral_finance_events(integer, integer)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION system.process_referral_finance_events(integer, integer)
    TO "service_role";

CREATE OR REPLACE FUNCTION system.replay_referral_finance_event(
    p_event_id uuid,
    p_reason text,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'referrals'
AS $function$
  SELECT referrals.admin_replay_finance_event(
      p_event_id, p_reason, p_actor_profile_id
  );
$function$;

ALTER FUNCTION system.replay_referral_finance_event(uuid, text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION system.replay_referral_finance_event(uuid, text, uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION system.replay_referral_finance_event(uuid, text, uuid)
    TO "authenticated";

COMMIT;

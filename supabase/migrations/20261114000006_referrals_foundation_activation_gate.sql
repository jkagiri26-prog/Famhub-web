-- ============================================================================
-- 20261114000006_referrals_foundation_activation_gate
-- ----------------------------------------------------------------------------
-- Release 1 foundation-only activation gate.
--
-- Default: DISABLED.
-- Attribution and referral registration remain available.
-- Reward creation, withdrawals, payouts, recovery and Finance-event
-- consumption fail closed until an authorized platform Admin enables the gate.
--
-- The gate reuses the existing Admin/entity authority and does not create a
-- second platform-admin role.
-- ============================================================================

BEGIN;

ALTER TABLE referrals.program_settings
    ADD COLUMN IF NOT EXISTS foundation_activation_enabled boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION referrals.foundation_activation_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals'
AS $function$
  SELECT coalesce(
    (SELECT ps.foundation_activation_enabled
       FROM referrals.program_settings AS ps
      WHERE ps.id IS TRUE),
    false
  );
$function$;

ALTER FUNCTION referrals.foundation_activation_enabled() OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.foundation_activation_enabled() FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION referrals.set_foundation_activation(
    p_enabled boolean,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'core', 'users', 'auth'
AS $function$
DECLARE
    v_actor uuid;
    v_before boolean;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

    SELECT foundation_activation_enabled INTO v_before
      FROM referrals.program_settings
     WHERE id IS TRUE
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Referral programme settings row is missing' USING ERRCODE = '55000';
    END IF;

    UPDATE referrals.program_settings
       SET foundation_activation_enabled = p_enabled,
           updated_by = v_actor,
           updated_at = now()
     WHERE id IS TRUE;

    INSERT INTO referrals.audit_events (
        entity_type, entity_id, event_type, actor_profile_id, reason, before_state, after_state
    ) VALUES (
        'program_settings', gen_random_uuid(), 'foundation_activation_changed', v_actor,
        CASE WHEN p_enabled THEN 'foundation_activation_enabled' ELSE 'foundation_activation_disabled' END,
        jsonb_build_object('foundation_activation_enabled', v_before),
        jsonb_build_object('foundation_activation_enabled', p_enabled)
    );
END;
$function$;

ALTER FUNCTION referrals.set_foundation_activation(boolean, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.set_foundation_activation(boolean, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.set_foundation_activation(boolean, uuid) TO "authenticated", "service_role";

CREATE OR REPLACE FUNCTION referrals.require_foundation_activation()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals'
AS $function$
BEGIN
    IF referrals.foundation_activation_enabled() IS NOT TRUE THEN
        RAISE EXCEPTION 'Refer & Earn foundation activation is disabled'
            USING ERRCODE = '55000';
    END IF;
END;
$function$;

ALTER FUNCTION referrals.require_foundation_activation() OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.require_foundation_activation() FROM PUBLIC, "anon", "authenticated", "service_role";

-- Gate the consumer at its entry point, including already-processed events.
-- The original consumer remains private behind the wrapper so a service-role
-- caller cannot bypass the activation gate by naming the underlying function.
ALTER FUNCTION referrals.consume_finance_event(uuid) RENAME TO consume_finance_event_core;
REVOKE ALL ON FUNCTION referrals.consume_finance_event_core(uuid) FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION referrals.consume_finance_event(p_event_id uuid)
RETURNS TABLE(
    finance_event_id uuid,
    outcome text,
    reward_id uuid,
    message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals'
AS $function$
BEGIN
    PERFORM referrals.require_foundation_activation();
    RETURN QUERY
    SELECT *
      FROM referrals.consume_finance_event_core(p_event_id);
END;
$function$;

ALTER FUNCTION referrals.consume_finance_event(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.consume_finance_event(uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.consume_finance_event(uuid) TO "service_role";

CREATE OR REPLACE FUNCTION referrals.guard_foundation_activation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals'
AS $function$
BEGIN
    PERFORM referrals.require_foundation_activation();
    RETURN NEW;
END;
$function$;

ALTER FUNCTION referrals.guard_foundation_activation() OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.guard_foundation_activation() FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS rewards_foundation_activation_gate ON referrals.rewards;
CREATE TRIGGER rewards_foundation_activation_gate
BEFORE INSERT OR UPDATE ON referrals.rewards
FOR EACH ROW EXECUTE FUNCTION referrals.guard_foundation_activation();

DROP TRIGGER IF EXISTS withdrawal_requests_foundation_activation_gate ON referrals.withdrawal_requests;
CREATE TRIGGER withdrawal_requests_foundation_activation_gate
BEFORE INSERT OR UPDATE ON referrals.withdrawal_requests
FOR EACH ROW EXECUTE FUNCTION referrals.guard_foundation_activation();

DROP TRIGGER IF EXISTS withdrawal_items_foundation_activation_gate ON referrals.withdrawal_items;
CREATE TRIGGER withdrawal_items_foundation_activation_gate
BEFORE INSERT OR UPDATE ON referrals.withdrawal_items
FOR EACH ROW EXECUTE FUNCTION referrals.guard_foundation_activation();

DROP TRIGGER IF EXISTS withdrawal_events_foundation_activation_gate ON referrals.withdrawal_events;
CREATE TRIGGER withdrawal_events_foundation_activation_gate
BEFORE INSERT OR UPDATE ON referrals.withdrawal_events
FOR EACH ROW EXECUTE FUNCTION referrals.guard_foundation_activation();

DROP TRIGGER IF EXISTS reward_events_foundation_activation_gate ON referrals.reward_events;
CREATE TRIGGER reward_events_foundation_activation_gate
BEFORE INSERT OR UPDATE ON referrals.reward_events
FOR EACH ROW EXECUTE FUNCTION referrals.guard_foundation_activation();

DROP TRIGGER IF EXISTS event_consumptions_foundation_activation_gate ON referrals.event_consumptions;
CREATE TRIGGER event_consumptions_foundation_activation_gate
BEFORE INSERT OR UPDATE ON referrals.event_consumptions
FOR EACH ROW EXECUTE FUNCTION referrals.guard_foundation_activation();

COMMIT;

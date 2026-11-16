-- ============================================================================
-- ALREADY APPLIED — repository migration body restored from deployed audited state
-- 20261114000007_referrals_finance_event_worker
-- ----------------------------------------------------------------------------
-- Internal bounded worker orchestration and dead-letter/replay lifecycle.
-- ============================================================================

BEGIN;

ALTER TABLE referrals.event_consumptions
    ADD COLUMN IF NOT EXISTS dead_lettered_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS dead_letter_reason text,
    ADD COLUMN IF NOT EXISTS replay_count integer NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION referrals.process_pending_finance_events(
    p_limit integer DEFAULT 50,
    p_max_attempts integer DEFAULT 5
)
RETURNS TABLE(
    gate_enabled boolean,
    selected_count integer,
    processed_count integer,
    failed_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'finance'
AS $function$
DECLARE
    v_event record;
    v_result record;
    v_selected integer := 0;
    v_processed integer := 0;
    v_failed integer := 0;
BEGIN
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION 'Worker batch limit must be between 1 and 100'
            USING ERRCODE = '22023';
    END IF;
    IF p_max_attempts IS NULL OR p_max_attempts < 1 OR p_max_attempts > 10 THEN
        RAISE EXCEPTION 'Worker max attempts must be between 1 and 10'
            USING ERRCODE = '22023';
    END IF;

    IF referrals.foundation_activation_enabled() IS NOT TRUE THEN
        RETURN QUERY SELECT false, 0, 0, 0;
        RETURN;
    END IF;

    FOR v_event IN
        SELECT e.id, e.event_type, e.source_type
          FROM finance.events AS e
          LEFT JOIN referrals.event_consumptions AS ec
            ON ec.finance_event_id = e.id
         WHERE e.event_type = 'finance.subscription.annual.activated'
           AND e.source_type = 'finance.subscription_cycle'
           AND ec.dead_lettered_at IS NULL
           AND (
             ec.id IS NULL
             OR (
               ec.status = 'failed'
               AND ec.attempts < p_max_attempts
               AND ec.updated_at <= clock_timestamp()
                   - make_interval(mins => least(60, (2 ^ ec.attempts)::integer))
             )
             OR (
               ec.status = 'processing'
               AND ec.updated_at <= clock_timestamp() - interval '10 minutes'
             )
           )
         ORDER BY e.created_at, e.id
         FOR UPDATE OF e SKIP LOCKED
         LIMIT p_limit
    LOOP
        v_selected := v_selected + 1;

        BEGIN
            SELECT * INTO v_result
              FROM referrals.consume_finance_event(v_event.id);

            IF v_result.outcome = 'failed' THEN
                v_failed := v_failed + 1;
                UPDATE referrals.event_consumptions
                   SET dead_lettered_at = coalesce(dead_lettered_at, now()),
                       dead_letter_reason = coalesce(dead_letter_reason, last_error)
                 WHERE finance_event_id = v_event.id
                   AND attempts >= p_max_attempts
                   AND dead_lettered_at IS NULL;
            ELSE
                v_processed := v_processed + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_failed := v_failed + 1;
            INSERT INTO referrals.event_consumptions (
                finance_event_id, event_type, status, attempts, last_error
            ) VALUES (
                v_event.id, v_event.event_type, 'failed', 1, left(SQLERRM, 1000)
            )
            ON CONFLICT (finance_event_id) DO UPDATE
            SET status = 'failed',
                attempts = referrals.event_consumptions.attempts + 1,
                last_error = left(SQLERRM, 1000),
                updated_at = now();

            UPDATE referrals.event_consumptions
               SET dead_lettered_at = coalesce(dead_lettered_at, now()),
                   dead_letter_reason = coalesce(dead_letter_reason, last_error)
             WHERE finance_event_id = v_event.id
               AND attempts >= p_max_attempts
               AND dead_lettered_at IS NULL;

            INSERT INTO referrals.event_failures (
                finance_event_id, event_type, attempts, last_error
            ) VALUES (
                v_event.id, v_event.event_type, 1, left(SQLERRM, 1000)
            )
            ON CONFLICT (finance_event_id) DO NOTHING;
        END;
    END LOOP;

    RETURN QUERY SELECT true, v_selected, v_processed, v_failed;
END;
$function$;

ALTER FUNCTION referrals.process_pending_finance_events(integer, integer) OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.process_pending_finance_events(integer, integer)
    FROM PUBLIC, "anon", "authenticated", "service_role";
-- Internal implementation only; system.process_referral_finance_events is the
-- sole service-role entry point.

CREATE OR REPLACE FUNCTION referrals.admin_replay_finance_event(
    p_event_id uuid,
    p_reason text,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'core', 'users', 'auth'
AS $function$
DECLARE
    v_actor uuid;
    v_before referrals.event_consumptions%ROWTYPE;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

    IF coalesce(btrim(p_reason), '') = '' THEN
        RAISE EXCEPTION 'A replay reason is required' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_before
      FROM referrals.event_consumptions
     WHERE finance_event_id = p_event_id
     FOR UPDATE;
    IF NOT FOUND OR v_before.dead_lettered_at IS NULL THEN
        RAISE EXCEPTION 'Finance event is not dead-lettered' USING ERRCODE = '55000';
    END IF;

    UPDATE referrals.event_consumptions
       SET status = 'pending',
           attempts = 0,
           dead_lettered_at = NULL,
           dead_letter_reason = NULL,
           replay_count = replay_count + 1,
           updated_at = now()
     WHERE finance_event_id = p_event_id;

    INSERT INTO referrals.audit_events (
        entity_type, entity_id, event_type, actor_profile_id, reason, before_state, after_state
    ) VALUES (
        'finance_event', p_event_id, 'finance_event_replayed', v_actor, p_reason,
        jsonb_build_object('attempts', v_before.attempts,
                           'dead_lettered_at', v_before.dead_lettered_at,
                           'dead_letter_reason', v_before.dead_letter_reason,
                           'replay_count', v_before.replay_count),
        jsonb_build_object('status', 'pending', 'attempts', 0,
                           'replay_count', v_before.replay_count + 1)
    );
END;
$function$;

ALTER FUNCTION referrals.admin_replay_finance_event(uuid, text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.admin_replay_finance_event(uuid, text, uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

COMMIT;

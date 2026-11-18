-- ============================================================================
-- PROPOSED — NOT APPLIED
-- 20261114000011_worker_test_isolation
-- ----------------------------------------------------------------------------
-- Test-only isolation for the referral finance worker.
--
-- Default behavior is unchanged: with referrals.worker_test_run_id unset,
-- process_pending_finance_events selects exactly the same events as before.
--
-- A test harness may set the custom GUC
--   SET LOCAL referrals.worker_test_run_id = '<run-id>';
-- and register only its synthetic event IDs in referrals.worker_test_events.
-- Test mode then selects only those registered events. Historical events are
-- never selected in test mode because they have no test-run registration.
--
-- The marker table has no grants to API roles. The existing system gateway is
-- unchanged, so the Edge Function never sets test mode.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS referrals.worker_test_events (
    finance_event_id uuid PRIMARY KEY
        REFERENCES finance.events(id) ON DELETE CASCADE,
    test_run_id text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    created_by uuid
);

ALTER TABLE referrals.worker_test_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE referrals.worker_test_events
    FROM PUBLIC, "anon", "authenticated", "service_role";

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
    v_test_run_id text := nullif(current_setting('referrals.worker_test_run_id', true), '');
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
           AND (
             v_test_run_id IS NULL
             OR EXISTS (
               SELECT 1
                 FROM referrals.worker_test_events AS wt
                WHERE wt.finance_event_id = e.id
                  AND wt.test_run_id = v_test_run_id
             )
           )
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

COMMIT;

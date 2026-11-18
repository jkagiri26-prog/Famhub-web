-- ============================================================================
-- referrals_finance_worker_test_isolation_test.sql
-- LOCAL-ONLY test for the optional worker test-run isolation mechanism.
-- Requires proposed 20261114000011.
-- ============================================================================
BEGIN;

UPDATE referrals.program_settings
   SET foundation_activation_enabled = true
 WHERE id = true;

INSERT INTO finance.events (
    id, event_type, source_type, source_id, idempotency_key, payload, created_at
) VALUES
(
    '76000000-0000-4000-8000-0000000000e1',
    'finance.subscription.annual.activated',
    'finance.subscription_cycle',
    gen_random_uuid(),
    'isolation-unmarked-event',
    '{}'::jsonb,
    now() - interval '2 minutes'
),
(
    '76000000-0000-4000-8000-0000000000e2',
    'finance.subscription.annual.activated',
    'finance.subscription_cycle',
    gen_random_uuid(),
    'isolation-marked-event',
    '{}'::jsonb,
    now()
);

INSERT INTO referrals.worker_test_events (finance_event_id, test_run_id)
VALUES ('76000000-0000-4000-8000-0000000000e2', 'isolation-test-run');

-- Default mode must still select the unmarked historical-style event.
SAVEPOINT default_selection;
DO $default$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(1);
    IF v_result.gate_enabled IS NOT TRUE
       OR v_result.selected_count <> 1
       OR v_result.failed_count <> 1 THEN
        RAISE EXCEPTION 'default selection changed: %', row_to_json(v_result);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM referrals.event_consumptions
         WHERE finance_event_id = '76000000-0000-4000-8000-0000000000e1'
           AND status = 'failed'
    ) THEN
        RAISE EXCEPTION 'default selection did not select the unmarked event';
    END IF;
END;
$default$;
ROLLBACK TO SAVEPOINT default_selection;

-- Test mode must select only the registered test event.
SET LOCAL referrals.worker_test_run_id = 'isolation-test-run';
DO $isolated$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5);
    IF v_result.gate_enabled IS NOT TRUE
       OR v_result.selected_count <> 1
       OR v_result.failed_count <> 1 THEN
        RAISE EXCEPTION 'isolated selection failed: %', row_to_json(v_result);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM referrals.event_consumptions
         WHERE finance_event_id = '76000000-0000-4000-8000-0000000000e2'
           AND status = 'failed'
    ) THEN
        RAISE EXCEPTION 'isolated selection did not select the marked event';
    END IF;
    IF EXISTS (
        SELECT 1 FROM referrals.event_consumptions
         WHERE finance_event_id = '76000000-0000-4000-8000-0000000000e1'
    ) THEN
        RAISE EXCEPTION 'isolated selection consumed the unmarked historical-style event';
    END IF;
    IF EXISTS (
        SELECT 1 FROM referrals.rewards
         WHERE source_finance_event_id IN (
             '76000000-0000-4000-8000-0000000000e1',
             '76000000-0000-4000-8000-0000000000e2'
         )
    ) THEN
        RAISE EXCEPTION 'test mode created a reward';
    END IF;
END;
$isolated$;
RESET referrals.worker_test_run_id;

DO $authorization$
BEGIN
    IF has_table_privilege('anon', 'referrals.worker_test_events', 'SELECT')
       OR has_table_privilege('authenticated', 'referrals.worker_test_events', 'SELECT')
       OR has_table_privilege('service_role', 'referrals.worker_test_events', 'SELECT') THEN
        RAISE EXCEPTION 'worker test marker table is exposed to an API role';
    END IF;
    IF has_function_privilege('authenticated', 'system.process_referral_finance_events(integer,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated can invoke the worker gateway';
    END IF;
    IF has_function_privilege('service_role', 'referrals.process_pending_finance_events(integer,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'service_role can invoke the internal worker';
    END IF;
END;
$authorization$;

ROLLBACK;

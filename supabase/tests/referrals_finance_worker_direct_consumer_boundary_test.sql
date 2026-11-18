-- ============================================================================
-- referrals_finance_worker_direct_consumer_boundary_test.sql
-- LOCAL-ONLY regression test for the direct consumer boundary.
-- Requires the proposed worker migrations, including 20261114000010.
-- ============================================================================
BEGIN;

UPDATE referrals.program_settings
   SET foundation_activation_enabled = true
 WHERE id = true;

INSERT INTO finance.events (
    id, event_type, source_type, source_id, idempotency_key, payload
) VALUES (
    '76000000-0000-4000-8000-0000000000d1',
    'finance.subscription.annual.activated',
    'finance.subscription_cycle',
    gen_random_uuid(),
    'worker-direct-consumer-boundary-event',
    '{}'::jsonb
);

DO $grants$
BEGIN
    IF has_function_privilege(
        'service_role',
        'referrals.consume_finance_event(uuid)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'service_role still has direct consumer EXECUTE';
    END IF;
    IF has_function_privilege(
        'anon',
        'referrals.consume_finance_event(uuid)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anon has direct consumer EXECUTE';
    END IF;
    IF has_function_privilege(
        'authenticated',
        'referrals.consume_finance_event(uuid)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'authenticated has direct consumer EXECUTE';
    END IF;
    IF NOT has_function_privilege(
        'service_role',
        'system.process_referral_finance_events(integer,integer)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'service_role lost the controlled worker gateway';
    END IF;
END;
$grants$;

SET LOCAL ROLE service_role;

DO $direct_denied$
BEGIN
    BEGIN
        PERFORM *
          FROM referrals.consume_finance_event(
              '76000000-0000-4000-8000-0000000000d1'
          );
        RAISE EXCEPTION 'service_role invoked the direct consumer';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL;
    END;
END;
$direct_denied$;

DO $worker_path$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result
      FROM system.process_referral_finance_events(5);

    IF v_result.gate_enabled IS NOT TRUE
       OR v_result.selected_count <> 1
       OR v_result.failed_count <> 1 THEN
        RAISE EXCEPTION
            'controlled worker path did not process the malformed event: %',
            row_to_json(v_result);
    END IF;
END;
$worker_path$;

RESET ROLE;

DO $durable$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM referrals.event_consumptions
         WHERE finance_event_id = '76000000-0000-4000-8000-0000000000d1'
           AND status = 'failed'
           AND attempts = 1
    ) THEN
        RAISE EXCEPTION 'controlled worker path did not record consumption';
    END IF;
END;
$durable$;

ROLLBACK;

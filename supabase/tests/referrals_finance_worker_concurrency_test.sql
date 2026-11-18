-- ============================================================================
-- referrals_finance_worker_concurrency_test.sql
-- LOCAL-ONLY concurrent worker claim test. Uses committed disposable fixture
-- because dblink sessions require visibility across connections.
-- Run only on a disposable local database; the committed fixture is append-only.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;

CREATE TEMP TABLE _worker_concurrency_results (
    worker text,
    gate_enabled boolean,
    selected_count integer,
    processed_count integer,
    failed_count integer
) ON COMMIT PRESERVE ROWS;

UPDATE referrals.program_settings SET foundation_activation_enabled=true;

INSERT INTO finance.events (id,event_type,source_type,source_id,idempotency_key,payload)
VALUES ('76000000-0000-4000-8000-000000000010',
        'finance.subscription.annual.activated','finance.subscription_cycle',
        gen_random_uuid(),'worker-concurrency-event','{}'::jsonb);

COMMIT;

DO $connect$
DECLARE
    v_conn text;
BEGIN
    SELECT format('host=%s port=%s dbname=%s user=%s',
                  split_part(setting, ',', 1),
                  current_setting('port'),
                  current_database(),
                  current_user)
      INTO v_conn
      FROM pg_settings
     WHERE name = 'unix_socket_directories';
    PERFORM dblink_connect('worker_1', v_conn);
    PERFORM dblink_connect('worker_2', v_conn);
END;
$connect$;

SELECT dblink_send_query(
    'worker_1',
    'SELECT * FROM system.process_referral_finance_events(1)'
);
SELECT dblink_send_query(
    'worker_2',
    'SELECT * FROM system.process_referral_finance_events(1)'
);

INSERT INTO _worker_concurrency_results
SELECT 'worker_1', * FROM dblink_get_result('worker_1')
    AS t(gate_enabled boolean, selected_count integer, processed_count integer, failed_count integer);
INSERT INTO _worker_concurrency_results
SELECT 'worker_2', * FROM dblink_get_result('worker_2')
    AS t(gate_enabled boolean, selected_count integer, processed_count integer, failed_count integer);

DO $assert$
DECLARE
    v_total_selected integer;
BEGIN
    SELECT coalesce(sum(selected_count), 0) INTO v_total_selected
      FROM _worker_concurrency_results;
    IF v_total_selected <> 1 THEN
        RAISE EXCEPTION 'concurrent workers selected event % times, expected exactly 1', v_total_selected;
    END IF;
END;
$assert$;

SELECT dblink_disconnect('worker_1');
SELECT dblink_disconnect('worker_2');

-- This test intentionally leaves the committed fixture. Run it only on a
-- disposable local database that is discarded after the test.

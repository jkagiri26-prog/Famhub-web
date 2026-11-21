-- ============================================================================
-- reputation_processing_work_ledger_concurrency_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE concurrency test for Phase 2C-2.
--
-- Uses committed disposable work state because dblink sessions require
-- visibility across connections. Discard the local database afterward.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;

CREATE TABLE pg_temp.conc_ref (
    label text PRIMARY KEY,
    order_id uuid NOT NULL,
    work_id uuid,
    claim_token uuid
);

CREATE TABLE pg_temp.claims (
    worker text NOT NULL,
    work_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    claim_token uuid NOT NULL
);

INSERT INTO pg_temp.conc_ref (label, order_id)
VALUES ('enqueue', gen_random_uuid()),
       ('reclaim', gen_random_uuid()),
       ('complete', gen_random_uuid());

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

    PERFORM dblink_connect('s1', v_conn);
    PERFORM dblink_connect('s2', v_conn);
END;
$connect$;

DO $install$
DECLARE
    v_enqueue text := $fn$
CREATE FUNCTION pg_temp.try_enqueue(p_order uuid)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    r record;
BEGIN
    SELECT * INTO r
      FROM system.enqueue_reputation_stock_order_work(p_order);
    RETURN r.work_id::text || '|' || r.status || '|' || r.created::text;
END;
$body$;
$fn$;
    v_claim text := $fn$
CREATE FUNCTION pg_temp.try_claim(p_worker text, p_lease integer, p_limit integer)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    v_result text;
BEGIN
    SELECT string_agg(
               r.work_id::text || '|' || r.attempt_number::text
               || '|' || r.claim_token::text,
               ',' ORDER BY r.work_id
           )
      INTO v_result
      FROM system.claim_reputation_processing_work(p_limit, p_worker, p_lease) AS r;
    RETURN COALESCE(v_result, 'none');
END;
$body$;
$fn$;
    v_complete text := $fn$
CREATE FUNCTION pg_temp.try_complete(p_work_id uuid, p_claim_token uuid)
RETURNS text
LANGUAGE plpgsql
AS $body$
BEGIN
    PERFORM system.complete_reputation_processing_work(
        p_work_id, p_claim_token, 'succeeded'
    );
    RETURN 'ok';
EXCEPTION WHEN SQLSTATE '55000' THEN
    RETURN 'stale';
END;
$body$;
$fn$;
BEGIN
    PERFORM dblink_exec('s1', v_enqueue);
    PERFORM dblink_exec('s1', v_claim);
    PERFORM dblink_exec('s1', v_complete);
    PERFORM dblink_exec('s2', v_enqueue);
    PERFORM dblink_exec('s2', v_claim);
    PERFORM dblink_exec('s2', v_complete);
END;
$install$;

DO $concurrent_enqueue$
DECLARE
    v_order_id uuid;
    v_a text;
    v_b text;
    v_count integer;
    v_claim record;
BEGIN
    SELECT order_id INTO v_order_id
      FROM pg_temp.conc_ref WHERE label='enqueue';

    PERFORM dblink_exec('s1', 'BEGIN');
    PERFORM dblink_exec('s2', 'BEGIN');

    PERFORM dblink_send_query(
        's1',
        format('SELECT pg_temp.try_enqueue(%L::uuid)', v_order_id)
    );
    PERFORM pg_sleep(0.2);
    PERFORM dblink_send_query(
        's2',
        format('SELECT pg_temp.try_enqueue(%L::uuid)', v_order_id)
    );
    PERFORM pg_sleep(0.2);

    SELECT result INTO v_a
      FROM dblink_get_result('s1') AS t(result text);
    PERFORM result FROM dblink_get_result('s1') AS t(result text);
    PERFORM dblink_exec('s1', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('s2') AS t(result text);
    PERFORM result FROM dblink_get_result('s2') AS t(result text);
    PERFORM dblink_exec('s2', 'COMMIT');

    IF split_part(v_a, '|', 3) = split_part(v_b, '|', 3) THEN
        RAISE EXCEPTION
            'Concurrent enqueue did not produce one created and one existing: % / %',
            v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.processing_work
     WHERE source_reference = v_order_id::text;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Concurrent enqueue created % work rows', v_count;
    END IF;

    UPDATE pg_temp.conc_ref
       SET work_id = w.id
      FROM reputation.processing_work w
     WHERE pg_temp.conc_ref.label='enqueue'
       AND w.source_reference = v_order_id::text;

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'enqueue-finish', 300);
    IF v_claim.work_id <> (SELECT work_id FROM pg_temp.conc_ref WHERE label='enqueue') THEN
        RAISE EXCEPTION 'Concurrent enqueue work was not claimable';
    END IF;
    PERFORM system.complete_reputation_processing_work(
        v_claim.work_id, v_claim.claim_token, 'succeeded'
    );
END;
$concurrent_enqueue$;

DO $batch_setup$
DECLARE
    v_i integer;
    v_result record;
BEGIN
    FOR v_i IN 1..6 LOOP
        SELECT * INTO v_result
          FROM system.enqueue_reputation_stock_order_work(gen_random_uuid());
        INSERT INTO pg_temp.claims(worker, work_id, attempt_number, claim_token)
        VALUES ('pending', v_result.work_id, 0, gen_random_uuid());
    END LOOP;
END;
$batch_setup$;

DO $concurrent_claim$
DECLARE
    v_a text;
    v_b text;
    v_claim_count integer;
    v_distinct_count integer;
    v_wrong_count integer;
    v_attempt_total integer;
    v_token_count integer;
    v_r record;
BEGIN
    PERFORM dblink_exec('s1', 'BEGIN');
    PERFORM dblink_exec('s2', 'BEGIN');

    PERFORM dblink_send_query(
        's1', $q$SELECT pg_temp.try_claim('claim-1', 300, 3)$q$
    );
    PERFORM pg_sleep(0.2);
    PERFORM dblink_send_query(
        's2', $q$SELECT pg_temp.try_claim('claim-2', 300, 3)$q$
    );
    PERFORM pg_sleep(0.2);

    SELECT result INTO v_a
      FROM dblink_get_result('s1') AS t(result text);
    PERFORM result FROM dblink_get_result('s1') AS t(result text);
    PERFORM dblink_exec('s1', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('s2') AS t(result text);
    PERFORM result FROM dblink_get_result('s2') AS t(result text);
    PERFORM dblink_exec('s2', 'COMMIT');

    IF v_a <> 'none' THEN
        INSERT INTO pg_temp.claims(worker, work_id, attempt_number, claim_token)
        SELECT 'claim-1',
               split_part(x, '|', 1)::uuid,
               split_part(x, '|', 2)::integer,
               split_part(x, '|', 3)::uuid
          FROM unnest(string_to_array(v_a, ',')) AS x;
    END IF;

    IF v_b <> 'none' THEN
        INSERT INTO pg_temp.claims(worker, work_id, attempt_number, claim_token)
        SELECT 'claim-2',
               split_part(x, '|', 1)::uuid,
               split_part(x, '|', 2)::integer,
               split_part(x, '|', 3)::uuid
          FROM unnest(string_to_array(v_b, ',')) AS x;
    END IF;

    SELECT count(*), count(DISTINCT work_id), count(DISTINCT claim_token)
      INTO v_claim_count, v_distinct_count, v_token_count
      FROM pg_temp.claims
     WHERE worker IN ('claim-1', 'claim-2');

    IF v_claim_count <> 6
       OR v_distinct_count <> 6
       OR v_token_count <> 6 THEN
        RAISE EXCEPTION
            'Concurrent batch claim was not exclusive: claims=%, distinct=%, tokens=%',
            v_claim_count, v_distinct_count, v_token_count;
    END IF;

    SELECT count(*) INTO v_wrong_count
      FROM pg_temp.claims c
      JOIN reputation.processing_work w ON w.id=c.work_id
     WHERE c.worker IN ('claim-1', 'claim-2')
       AND (w.status <> 'processing'
            OR w.attempt_count <> 1
            OR w.claim_token <> c.claim_token
            OR w.claimed_by <> c.worker);

    IF v_wrong_count <> 0 THEN
        RAISE EXCEPTION 'Concurrent batch claim persisted state is inconsistent';
    END IF;

    SELECT count(*) INTO v_attempt_total
      FROM reputation.processing_attempts a
      JOIN pg_temp.claims c ON c.work_id=a.work_id
     WHERE c.worker IN ('claim-1', 'claim-2');
    IF v_attempt_total <> 0 THEN
        RAISE EXCEPTION 'Concurrent batch claim created in-progress attempt rows';
    END IF;

    FOR v_r IN
        SELECT * FROM pg_temp.claims WHERE worker IN ('claim-1', 'claim-2')
    LOOP
        PERFORM system.complete_reputation_processing_work(
            v_r.work_id, v_r.claim_token, 'succeeded'
        );
    END LOOP;

    SELECT count(*) INTO v_wrong_count
      FROM pg_temp.claims c
      JOIN reputation.processing_work w ON w.id=c.work_id
     WHERE c.worker IN ('claim-1', 'claim-2')
       AND (w.status <> 'succeeded' OR w.attempt_count <> 1);

    IF v_wrong_count <> 0 THEN
        RAISE EXCEPTION 'Concurrent batch completion left inconsistent state';
    END IF;
END;
$concurrent_claim$;

DO $reclaim_setup$
DECLARE
    v_order_id uuid;
    v_enqueue record;
    v_claim record;
BEGIN
    SELECT order_id INTO v_order_id
      FROM pg_temp.conc_ref WHERE label='reclaim';

    SELECT * INTO v_enqueue
      FROM system.enqueue_reputation_stock_order_work(v_order_id);

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'old-worker', 1);
    IF v_claim.work_id <> v_enqueue.work_id OR v_claim.claim_token IS NULL THEN
        RAISE EXCEPTION 'Reclaim fixture could not be claimed';
    END IF;

    UPDATE pg_temp.conc_ref
       SET work_id=v_enqueue.work_id,
           claim_token=v_claim.claim_token
     WHERE label='reclaim';
END;
$reclaim_setup$;

DO $concurrent_reclaim$
DECLARE
    v_work_id uuid;
    v_old_token uuid;
    v_a text;
    v_b text;
    v_winner text;
    v_loser text;
    v_winner_token uuid;
    v_status text;
    v_attempt_count integer;
    v_attempt_rows integer;
BEGIN
    SELECT work_id, claim_token INTO v_work_id, v_old_token
      FROM pg_temp.conc_ref WHERE label='reclaim';

    IF v_work_id IS NULL OR v_old_token IS NULL THEN
        RAISE EXCEPTION 'Reclaim fixture is missing';
    END IF;

    PERFORM pg_sleep(1.1);

    PERFORM dblink_exec('s1', 'BEGIN');
    PERFORM dblink_exec('s2', 'BEGIN');

    PERFORM dblink_send_query(
        's1', $q$SELECT pg_temp.try_claim('reclaim-1', 300, 1)$q$
    );
    PERFORM pg_sleep(0.2);
    PERFORM dblink_send_query(
        's2', $q$SELECT pg_temp.try_claim('reclaim-2', 300, 1)$q$
    );
    PERFORM pg_sleep(0.2);

    SELECT result INTO v_a
      FROM dblink_get_result('s1') AS t(result text);
    PERFORM result FROM dblink_get_result('s1') AS t(result text);
    PERFORM dblink_exec('s1', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('s2') AS t(result text);
    PERFORM result FROM dblink_get_result('s2') AS t(result text);
    PERFORM dblink_exec('s2', 'COMMIT');

    IF (v_a = 'none') = (v_b = 'none') THEN
        RAISE EXCEPTION 'Concurrent reclaim did not produce exactly one winner: % / %',
            v_a, v_b;
    END IF;

    v_winner := CASE WHEN v_a <> 'none' THEN v_a ELSE v_b END;
    v_loser := CASE WHEN v_a = 'none' THEN v_a ELSE v_b END;

    IF split_part(v_winner, '|', 1)::uuid <> v_work_id
       OR split_part(v_winner, '|', 2)::integer <> 2 THEN
        RAISE EXCEPTION 'Concurrent reclaim winner mismatch: %', v_winner;
    END IF;

    v_winner_token := split_part(v_winner, '|', 3)::uuid;
    IF v_winner_token = v_old_token THEN
        RAISE EXCEPTION 'Concurrent reclaim did not rotate claim token';
    END IF;

    IF v_loser <> 'none' THEN
        RAISE EXCEPTION 'Concurrent reclaim loser obtained a claim';
    END IF;

    SELECT status, attempt_count, claim_token
      INTO v_status, v_attempt_count, v_winner_token
      FROM reputation.processing_work
     WHERE id=v_work_id;

    IF v_status <> 'processing'
       OR v_attempt_count <> 2
       OR v_winner_token IS NULL THEN
        RAISE EXCEPTION 'Concurrent reclaim persisted state is wrong';
    END IF;

    BEGIN
        PERFORM system.complete_reputation_processing_work(
            v_work_id, v_old_token, 'succeeded'
        );
        RAISE EXCEPTION 'Old token completed after concurrent reclaim';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
    END;

    SELECT count(*) INTO v_attempt_rows
      FROM reputation.processing_attempts
     WHERE work_id=v_work_id;
    IF v_attempt_rows <> 0 THEN
        RAISE EXCEPTION 'Old token completion appended attempt history';
    END IF;

    PERFORM system.complete_reputation_processing_work(
        v_work_id, v_winner_token, 'succeeded'
    );

    SELECT status, attempt_count INTO v_status, v_attempt_count
      FROM reputation.processing_work WHERE id=v_work_id;
    IF v_status <> 'succeeded' OR v_attempt_count <> 2 THEN
        RAISE EXCEPTION 'Concurrent reclaim winner completion failed';
    END IF;

    SELECT count(*) INTO v_attempt_rows
      FROM reputation.processing_attempts
     WHERE work_id=v_work_id AND attempt_number=2;
    IF v_attempt_rows <> 1 THEN
        RAISE EXCEPTION 'Concurrent reclaim attempt history is wrong';
    END IF;
END;
$concurrent_reclaim$;

DO $completion_setup$
DECLARE
    v_order_id uuid;
    v_enqueue record;
    v_claim record;
BEGIN
    SELECT order_id INTO v_order_id
      FROM pg_temp.conc_ref WHERE label='complete';

    SELECT * INTO v_enqueue
      FROM system.enqueue_reputation_stock_order_work(v_order_id);

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'completion-worker', 300);
    IF v_claim.work_id <> v_enqueue.work_id OR v_claim.claim_token IS NULL THEN
        RAISE EXCEPTION 'Concurrent completion fixture could not be claimed';
    END IF;

    UPDATE pg_temp.conc_ref
       SET work_id=v_enqueue.work_id,
           claim_token=v_claim.claim_token
     WHERE label='complete';
END;
$completion_setup$;

DO $concurrent_completion$
DECLARE
    v_work_id uuid;
    v_token uuid;
    v_a text;
    v_b text;
    v_status text;
    v_attempt_count integer;
    v_attempt_rows integer;
BEGIN
    SELECT work_id, claim_token INTO v_work_id, v_token
      FROM pg_temp.conc_ref WHERE label='complete';

    IF v_work_id IS NULL OR v_token IS NULL THEN
        RAISE EXCEPTION 'Concurrent completion fixture is missing';
    END IF;

    PERFORM dblink_exec('s1', 'BEGIN');
    PERFORM dblink_exec('s2', 'BEGIN');

    PERFORM dblink_send_query(
        's1',
        format('SELECT pg_temp.try_complete(%L::uuid, %L::uuid)',
               v_work_id, v_token)
    );
    PERFORM pg_sleep(0.2);
    PERFORM dblink_send_query(
        's2',
        format('SELECT pg_temp.try_complete(%L::uuid, %L::uuid)',
               v_work_id, v_token)
    );
    PERFORM pg_sleep(0.2);

    SELECT result INTO v_a
      FROM dblink_get_result('s1') AS t(result text);
    PERFORM result FROM dblink_get_result('s1') AS t(result text);
    PERFORM dblink_exec('s1', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('s2') AS t(result text);
    PERFORM result FROM dblink_get_result('s2') AS t(result text);
    PERFORM dblink_exec('s2', 'COMMIT');

    IF NOT (
        (v_a = 'ok' AND v_b = 'stale')
        OR (v_a = 'stale' AND v_b = 'ok')
    ) THEN
        RAISE EXCEPTION 'Concurrent completion was not exclusive: % / %',
            v_a, v_b;
    END IF;

    SELECT status, attempt_count INTO v_status, v_attempt_count
      FROM reputation.processing_work WHERE id=v_work_id;
    IF v_status <> 'succeeded' OR v_attempt_count <> 1 THEN
        RAISE EXCEPTION 'Concurrent completion final state is wrong';
    END IF;

    SELECT count(*) INTO v_attempt_rows
      FROM reputation.processing_attempts
     WHERE work_id=v_work_id;
    IF v_attempt_rows <> 1 THEN
        RAISE EXCEPTION 'Concurrent completion created % attempt rows',
            v_attempt_rows;
    END IF;
END;
$concurrent_completion$;

SELECT dblink_disconnect('s2');
SELECT dblink_disconnect('s1');

-- Committed disposable work is intentionally left for inspection. Discard
-- the local database after this test.

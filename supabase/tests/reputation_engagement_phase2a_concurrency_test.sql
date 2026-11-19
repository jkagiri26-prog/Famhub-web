-- ============================================================================
-- reputation_engagement_phase2a_concurrency_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE concurrency and persistence tests.
--
-- Covers subject retirement vs subject-link insertion, conflict auditing after
-- void across a committed boundary, and simultaneous identical/conflicting
-- source-event submissions.
--
-- Uses committed disposable fixtures because dblink sessions require visibility
-- across connections. Run only against a disposable local database and discard
-- the database afterward. Never run against production.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;

BEGIN;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('30000000-0000-4000-8000-000000000001', 'Concurrency Test Country', 'QC', 'QCC', '9998', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('30000000-0000-4000-8000-000000000002', 'Concurrency Test Location',
        '30000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('30000000-0000-4000-8000-000000000003', 'concurrency-test-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);
INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES ('31000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000901',
        'Concurrency Seller', '30000000-0000-4000-8000-000000000001', true, 'active');
SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES ('32000000-0000-4000-8000-000000000001', 'Concurrency Seller Entity',
        'farm', '31000000-0000-4000-8000-000000000001', true, 'verified');
INSERT INTO core.items (id, name)
VALUES ('33000000-0000-4000-8000-000000000001', 'Concurrency Test Item');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('33000000-0000-4000-8000-000000000002',
        '33000000-0000-4000-8000-000000000001', 'Concurrency Test Variant');
INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status
) VALUES (
    '33000000-0000-4000-8000-000000000003',
    '32000000-0000-4000-8000-000000000001',
    'Concurrency Test Listing', 10.00, 'KES',
    '30000000-0000-4000-8000-000000000002',
    '33000000-0000-4000-8000-000000000002',
    5.00, '30000000-0000-4000-8000-000000000003', 'active'
);

INSERT INTO reputation.subjects (id, subject_type, subject_role, listing_id)
VALUES ('34000000-0000-4000-8000-000000000001', 'listing', 'listing',
        '33000000-0000-4000-8000-000000000003');
INSERT INTO reputation.subjects (id, subject_type, subject_role, item_id)
VALUES ('34000000-0000-4000-8000-000000000002', 'item', 'product',
        '33000000-0000-4000-8000-000000000001');

INSERT INTO reputation.engagements (
    id, engagement_kind, source_system, source_reference,
    source_snapshot, source_snapshot_hash, source_occurred_at
) VALUES
    ('35000000-0000-4000-8000-000000000001', 'external_transaction',
     'concurrency', 'link-first',
     '{"snapshot_version":1}', pg_catalog.sha256(convert_to('{"snapshot_version":1}'::jsonb::text,'UTF8')),
     '2026-11-19T10:00:00Z'),
    ('35000000-0000-4000-8000-000000000002', 'external_transaction',
     'concurrency', 'retire-first',
     '{"snapshot_version":1}', pg_catalog.sha256(convert_to('{"snapshot_version":1}'::jsonb::text,'UTF8')),
     '2026-11-19T10:00:00Z');

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES
    ('35000000-0000-4000-8000-000000000001', 'reputation',
     'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('35000000-0000-4000-8000-000000000002', 'reputation',
     'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}');

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

    PERFORM dblink_connect('link_first', v_conn);
    PERFORM dblink_connect('retire_first', v_conn);
END;
$connect$;

-- ----------------------------------------------------------------------------
-- Case 1: link transaction holds FOR SHARE first; retirement blocks, then
-- succeeds after link commit. The historical link remains.
-- ----------------------------------------------------------------------------
SELECT dblink_exec('link_first', 'BEGIN');
SELECT dblink_exec('link_first', $SQL$
    INSERT INTO reputation.engagement_subjects (
        engagement_id, subject_id, relationship, source_fact
    ) VALUES (
        '35000000-0000-4000-8000-000000000001'::uuid,
        '34000000-0000-4000-8000-000000000001'::uuid,
        'listing',
        '{}'::jsonb
    )
$SQL$);

SELECT dblink_send_query(
    'retire_first',
    $SQL$SELECT reputation.retire_subject('34000000-0000-4000-8000-000000000001'::uuid)$SQL$
);

SELECT pg_sleep(0.4);
SELECT dblink_exec('link_first', 'COMMIT');

SELECT * FROM dblink_get_result('retire_first') AS t(retired_id uuid);
SELECT dblink_disconnect('retire_first');

DO $case1$
DECLARE
    v_status text;
    v_link_count integer;
BEGIN
    SELECT status INTO v_status
      FROM reputation.subjects
     WHERE id='34000000-0000-4000-8000-000000000001';
    SELECT count(*) INTO v_link_count
      FROM reputation.engagement_subjects
     WHERE engagement_id='35000000-0000-4000-8000-000000000001'
       AND subject_id='34000000-0000-4000-8000-000000000001';

    IF v_status <> 'retired' THEN
        RAISE EXCEPTION 'retirement did not complete after link commit';
    END IF;
    IF v_link_count <> 1 THEN
        RAISE EXCEPTION 'historical subject link was not preserved';
    END IF;
END;
$case1$;

-- ----------------------------------------------------------------------------
-- Case 2: retirement holds FOR UPDATE first; link waits, then sees the retired
-- subject and fails. No link is inserted.
-- ----------------------------------------------------------------------------
DO $connect2$
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

    PERFORM dblink_connect('retire_holder', v_conn);
    PERFORM dblink_connect('link_waiter', v_conn);
END;
$connect2$;

SELECT dblink_exec('retire_holder', 'BEGIN');
SELECT *
  FROM dblink(
      'retire_holder',
      $SQL$SELECT reputation.retire_subject('34000000-0000-4000-8000-000000000002'::uuid)$SQL$
  ) AS t(retired_id uuid);
SELECT dblink_exec(
    'link_waiter',
    $define$
    CREATE FUNCTION pg_temp.try_link() RETURNS text
    LANGUAGE plpgsql
    AS $body$
    BEGIN
        BEGIN
            INSERT INTO reputation.engagement_subjects (
                engagement_id, subject_id, relationship, source_fact
            ) VALUES (
                '35000000-0000-4000-8000-000000000002'::uuid,
                '34000000-0000-4000-8000-000000000002'::uuid,
                'product',
                '{}'::jsonb
            );
        EXCEPTION WHEN OTHERS THEN
            RETURN SQLSTATE;
        END;
        RETURN 'unexpected-success';
    END;
    $body$;
    $define$
);

SELECT dblink_send_query('link_waiter', 'SELECT pg_temp.try_link()');

SELECT pg_sleep(0.4);
SELECT dblink_exec('retire_holder', 'COMMIT');

DO $case2$
DECLARE
    v_result text;
    v_link_count integer;
BEGIN
    SELECT result INTO v_result
      FROM dblink_get_result('link_waiter') AS t(result text);

    SELECT count(*) INTO v_link_count
      FROM reputation.engagement_subjects
     WHERE engagement_id='35000000-0000-4000-8000-000000000002'
       AND subject_id='34000000-0000-4000-8000-000000000002';

    IF v_result IS DISTINCT FROM '23514' THEN
        RAISE EXCEPTION 'expected inactive-subject failure 23514, got %', v_result;
    END IF;
    IF v_link_count <> 0 THEN
        RAISE EXCEPTION 'retired subject link was inserted';
    END IF;
END;
$case2$;

SELECT dblink_disconnect('link_waiter');
SELECT dblink_disconnect('retire_holder');
SELECT dblink_disconnect('link_first');

-- ============================================================================
-- Phase 2A final regression: conflict audit after void, persisted audit
-- across a committed boundary, and concurrent source identity submissions.
-- Disposable local database only. Fixtures are committed so separate
-- connections can observe them.
-- ============================================================================
BEGIN;

CREATE FUNCTION pg_temp.event_hash(
    p_event_type text,
    p_event_at timestamptz,
    p_namespace text,
    p_reference text,
    p_actor uuid,
    p_details jsonb
)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT pg_catalog.sha256(
        convert_to(
            jsonb_build_object(
                'event_version', 1,
                'event_type', p_event_type,
                'event_at', to_char(
                    p_event_at AT TIME ZONE 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                ),
                'source_namespace', p_namespace,
                'source_event_reference', p_reference,
                'actor_profile_id', p_actor::text,
                'details', p_details
            )::text,
            'UTF8'
        )
    )
$body$;

INSERT INTO reputation.engagements (
    id, engagement_kind, source_system, source_reference,
    source_snapshot, source_snapshot_hash, source_occurred_at
) VALUES
    ('36000000-0000-4000-8000-000000000001', 'external_transaction',
     'concurrency', 'void-conflict-audit',
     '{"snapshot_version":1}',
     pg_catalog.sha256(convert_to('{"snapshot_version":1}'::jsonb::text,'UTF8')),
     '2020-01-01T00:00:00Z'),
    ('36000000-0000-4000-8000-000000000002', 'external_transaction',
     'concurrency', 'simultaneous-identical',
     '{"snapshot_version":1}',
     pg_catalog.sha256(convert_to('{"snapshot_version":1}'::jsonb::text,'UTF8')),
     '2020-01-01T00:00:00Z'),
    ('36000000-0000-4000-8000-000000000003', 'external_transaction',
     'concurrency', 'simultaneous-conflict',
     '{"snapshot_version":1}',
     pg_catalog.sha256(convert_to('{"snapshot_version":1}'::jsonb::text,'UTF8')),
     '2020-01-01T00:00:00Z');

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES
    ('36000000-0000-4000-8000-000000000001', 'reputation',
     'engagement_recorded', '2020-01-01T00:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('36000000-0000-4000-8000-000000000002', 'reputation',
     'engagement_recorded', '2020-01-01T00:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('36000000-0000-4000-8000-000000000003', 'reputation',
     'engagement_recorded', '2020-01-01T00:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}');

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key,
    source_namespace, source_event_reference, payload_hash, details
) VALUES (
    '36000000-0000-4000-8000-000000000001', 'source',
    'source_synchronized', '2020-01-01T00:00:02Z', 'void-source-1',
    'concurrency-src', 'void-src-ref-1',
    pg_temp.event_hash(
        'source_synchronized', '2020-01-01T00:00:02Z',
        'concurrency-src', 'void-src-ref-1', NULL, '{}'::jsonb
    ),
    '{}'
);

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES (
    '36000000-0000-4000-8000-000000000001', 'reputation',
    'engagement_voided', '2020-01-02T00:00:00Z', 'void-1',
    '{"invalidity_code":"conflict_after_void_test"}'
);

COMMIT;

DO $pre_audit$
DECLARE
    v_status text;
    v_outcome text;
    v_integrity text;
BEGIN
    SELECT status, source_outcome, source_integrity_status
      INTO v_status, v_outcome, v_integrity
      FROM reputation.v_engagement_current_state
     WHERE engagement_id='36000000-0000-4000-8000-000000000001';

    IF v_status <> 'voided' OR v_outcome <> 'completed' OR v_integrity <> 'consistent' THEN
        RAISE EXCEPTION 'pre-audit voided state mismatch: %/%/%',
            v_status, v_outcome, v_integrity;
    END IF;
END;
$pre_audit$;

DO $reject_after_void$
DECLARE
    v_hash bytea;
    v_type text;
    v_details jsonb;
BEGIN
    -- A conflicting source event against the original identity is rejected.
    v_hash := pg_temp.event_hash(
        'order_refunded', '2020-01-01T00:00:03Z',
        'concurrency-src', 'void-src-ref-1', NULL,
        '{"attempt":"conflict"}'::jsonb
    );
    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key,
            source_namespace, source_event_reference, payload_hash, details
        ) VALUES (
            '36000000-0000-4000-8000-000000000001', 'source',
            'order_refunded', '2020-01-01T00:00:03Z', 'void-source-conflict',
            'concurrency-src', 'void-src-ref-1', v_hash,
            '{"attempt":"conflict"}'
        );
        RAISE EXCEPTION 'conflicting source event after void unexpectedly succeeded';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Source-origin events with fresh identities remain terminal after void.
    FOREACH v_type IN ARRAY ARRAY[
        'order_returned',
        'order_refunded',
        'source_synchronized',
        'source_correction_recorded',
        'source_integrity_changed'
    ] LOOP
        v_details := CASE
            WHEN v_type = 'source_integrity_changed'
                THEN '{"source_integrity_status":"conflicted"}'::jsonb
            ELSE '{}'::jsonb
        END;

        BEGIN
            INSERT INTO reputation.engagement_events (
                engagement_id, event_origin, event_type, event_at, event_key,
                source_namespace, source_event_reference, payload_hash, details
            ) VALUES (
                '36000000-0000-4000-8000-000000000001', 'source',
                v_type, '2020-01-03T00:00:00Z',
                'void-after-source-' || v_type,
                'concurrency-src', 'void-after-' || v_type,
                pg_temp.event_hash(
                    v_type, '2020-01-03T00:00:00Z',
                    'concurrency-src', 'void-after-' || v_type,
                    NULL, v_details
                ),
                v_details
            );
            RAISE EXCEPTION 'source event % after void unexpectedly succeeded', v_type;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;

    -- Reputation lifecycle events remain terminal after void.
    FOREACH v_type IN ARRAY ARRAY[
        'dispute_opened',
        'dispute_dismissed',
        'dispute_upheld',
        'engagement_voided'
    ] LOOP
        v_details := CASE
            WHEN v_type = 'engagement_voided'
                THEN '{"invalidity_code":"after_void"}'::jsonb
            ELSE '{}'::jsonb
        END;

        BEGIN
            INSERT INTO reputation.engagement_events (
                engagement_id, event_origin, event_type, event_at, event_key,
                details
            ) VALUES (
                '36000000-0000-4000-8000-000000000001', 'reputation',
                v_type, '2020-01-03T00:00:01Z',
                'void-after-reputation-' || v_type, v_details
            );
            RAISE EXCEPTION 'reputation event % after void unexpectedly succeeded', v_type;
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
END;
$reject_after_void$;

-- The audit is written in its own transaction and committed, so the next
-- transaction observes a persisted row rather than an uncommitted fixture.
SELECT reputation.record_source_event_conflict(
    '36000000-0000-4000-8000-000000000001',
    'concurrency-src',
    'void-src-ref-1',
    'order_refunded',
    '2020-01-01T00:00:03Z',
    pg_temp.event_hash(
        'order_refunded', '2020-01-01T00:00:03Z',
        'concurrency-src', 'void-src-ref-1', NULL,
        '{"attempt":"conflict"}'::jsonb
    ),
    'conflict_after_void'
);

DO $post_audit$
DECLARE
    v_count integer;
    v_namespace text;
    v_reference text;
    v_type text;
    v_reason text;
    v_status text;
    v_outcome text;
    v_integrity text;
BEGIN
    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id='36000000-0000-4000-8000-000000000001'
       AND event_origin='reputation'
       AND event_type='source_event_conflict';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'committed conflict audit count is %', v_count;
    END IF;

    SELECT details->>'attempted_source_namespace',
           details->>'attempted_source_event_reference',
           details->>'attempted_event_type',
           details->>'reason'
      INTO v_namespace, v_reference, v_type, v_reason
      FROM reputation.engagement_events
     WHERE engagement_id='36000000-0000-4000-8000-000000000001'
       AND event_type='source_event_conflict';

    IF v_namespace <> 'concurrency-src'
       OR v_reference <> 'void-src-ref-1'
       OR v_type <> 'order_refunded'
       OR v_reason <> 'conflict_after_void' THEN
        RAISE EXCEPTION 'conflict audit details were not preserved: %/%/%/%',
            v_namespace, v_reference, v_type, v_reason;
    END IF;

    SELECT status, source_outcome, source_integrity_status
      INTO v_status, v_outcome, v_integrity
      FROM reputation.v_engagement_current_state
     WHERE engagement_id='36000000-0000-4000-8000-000000000001';

    IF v_status <> 'voided' OR v_outcome <> 'completed' OR v_integrity <> 'consistent' THEN
        RAISE EXCEPTION 'audit changed derived state: %/%/%',
            v_status, v_outcome, v_integrity;
    END IF;
END;
$post_audit$;

-- ----------------------------------------------------------------------------
-- Concurrent submissions. The engagement row lock serializes source identity
-- resolution across separate connections.
-- ----------------------------------------------------------------------------
DO $connect_final$
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

    PERFORM dblink_connect('ident_a', v_conn);
    PERFORM dblink_connect('ident_b', v_conn);
    PERFORM dblink_connect('conflict_a', v_conn);
    PERFORM dblink_connect('conflict_b', v_conn);
END;
$connect_final$;

DO $install_hash$
DECLARE
    v_sql text := $fn$
CREATE FUNCTION pg_temp.event_hash(
    p_event_type text,
    p_event_at timestamptz,
    p_namespace text,
    p_reference text,
    p_actor uuid,
    p_details jsonb
)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT pg_catalog.sha256(
        convert_to(
            jsonb_build_object(
                'event_version', 1,
                'event_type', p_event_type,
                'event_at', to_char(
                    p_event_at AT TIME ZONE 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                ),
                'source_namespace', p_namespace,
                'source_event_reference', p_reference,
                'actor_profile_id', p_actor::text,
                'details', p_details
            )::text,
            'UTF8'
        )
    )
$body$;
$fn$;
    v_conn text;
BEGIN
    FOREACH v_conn IN ARRAY ARRAY[
        'ident_a', 'ident_b', 'conflict_a', 'conflict_b'
    ] LOOP
        PERFORM dblink_exec(v_conn, v_sql);
    END LOOP;
END;
$install_hash$;

DO $install_ident$
DECLARE
    v_sql text := $fn$
CREATE FUNCTION pg_temp.try_identical_source(p_event_key text)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    v_rows integer;
BEGIN
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '36000000-0000-4000-8000-000000000002'::uuid, 'source',
        'source_synchronized', '2020-01-01T00:00:02Z'::timestamptz,
        p_event_key, 'concurrency-src', 'ident-ref',
        pg_temp.event_hash(
            'source_synchronized', '2020-01-01T00:00:02Z',
            'concurrency-src', 'ident-ref', NULL, '{}'::jsonb
        ),
        '{}'::jsonb
    );
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 1 THEN
        RETURN 'inserted';
    END IF;
    RETURN 'noop';
END;
$body$;
$fn$;
    v_conn text;
BEGIN
    FOREACH v_conn IN ARRAY ARRAY['ident_a', 'ident_b'] LOOP
        PERFORM dblink_exec(v_conn, v_sql);
    END LOOP;
END;
$install_ident$;

DO $install_conflict$
DECLARE
    v_sql text := $fn$
CREATE FUNCTION pg_temp.try_conflicting_source(
    p_event_key text,
    p_details jsonb
)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    v_hash bytea;
    v_state text;
BEGIN
    v_hash := pg_temp.event_hash(
        'source_synchronized', '2020-01-01T00:00:02Z',
        'concurrency-src', 'conflict-ref', NULL, p_details
    );

    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key,
            source_namespace, source_event_reference, payload_hash, details
        ) VALUES (
            '36000000-0000-4000-8000-000000000003'::uuid, 'source',
            'source_synchronized', '2020-01-01T00:00:02Z'::timestamptz,
            p_event_key, 'concurrency-src', 'conflict-ref',
            v_hash, p_details
        );
    EXCEPTION WHEN unique_violation THEN
        v_state := SQLSTATE;
    END;

    IF v_state = '23505' THEN
        PERFORM reputation.record_source_event_conflict(
            '36000000-0000-4000-8000-000000000003'::uuid,
            'concurrency-src', 'conflict-ref', 'source_synchronized',
            '2020-01-01T00:00:02Z', v_hash, 'simultaneous_conflict'
        );
        RETURN '23505:audited';
    END IF;

    RETURN 'inserted';
END;
$body$;
$fn$;
    v_conn text;
BEGIN
    FOREACH v_conn IN ARRAY ARRAY['conflict_a', 'conflict_b'] LOOP
        PERFORM dblink_exec(v_conn, v_sql);
    END LOOP;
END;
$install_conflict$;

DO $run_ident$
DECLARE
    v_a text;
    v_b text;
    v_count integer;
BEGIN
    PERFORM dblink_exec('ident_a', 'BEGIN');
    PERFORM dblink_exec('ident_b', 'BEGIN');

    PERFORM dblink_send_query(
        'ident_a', $q$SELECT pg_temp.try_identical_source('ident-a')$q$
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'ident_b', $q$SELECT pg_temp.try_identical_source('ident-b')$q$
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_a
      FROM dblink_get_result('ident_a') AS t(result text);
    PERFORM result
      FROM dblink_get_result('ident_a') AS t(result text);
    PERFORM dblink_exec('ident_a', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('ident_b') AS t(result text);
    PERFORM result
      FROM dblink_get_result('ident_b') AS t(result text);
    PERFORM dblink_exec('ident_b', 'COMMIT');

    IF v_a NOT IN ('inserted', 'noop') OR v_b NOT IN ('inserted', 'noop') THEN
        RAISE EXCEPTION 'unexpected identical submission results: % / %',
            v_a, v_b;
    END IF;

    IF (v_a = 'inserted')::int + (v_b = 'inserted')::int <> 1 THEN
        RAISE EXCEPTION 'identical submissions did not produce exactly one insert: % / %',
            v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id='36000000-0000-4000-8000-000000000002'
       AND event_origin='source'
       AND source_namespace='concurrency-src'
       AND source_event_reference='ident-ref';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'identical source event persisted % times', v_count;
    END IF;
END;
$run_ident$;

DO $run_conflict$
DECLARE
    v_a text;
    v_b text;
    v_count integer;
    v_status text;
    v_outcome text;
    v_integrity text;
BEGIN
    PERFORM dblink_exec('conflict_a', 'BEGIN');
    PERFORM dblink_exec('conflict_b', 'BEGIN');

    PERFORM dblink_send_query(
        'conflict_a',
        $q$SELECT pg_temp.try_conflicting_source('conflict-a','{"attempt":"first"}'::jsonb)$q$
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'conflict_b',
        $q$SELECT pg_temp.try_conflicting_source('conflict-b','{"attempt":"second"}'::jsonb)$q$
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_a
      FROM dblink_get_result('conflict_a') AS t(result text);
    PERFORM result
      FROM dblink_get_result('conflict_a') AS t(result text);
    PERFORM dblink_exec('conflict_a', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('conflict_b') AS t(result text);
    PERFORM result
      FROM dblink_get_result('conflict_b') AS t(result text);
    PERFORM dblink_exec('conflict_b', 'COMMIT');

    IF v_a <> 'inserted' OR v_b <> '23505:audited' THEN
        RAISE EXCEPTION 'unexpected conflicting submission results: % / %',
            v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id='36000000-0000-4000-8000-000000000003'
       AND event_origin='source'
       AND source_namespace='concurrency-src'
       AND source_event_reference='conflict-ref';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'conflicting source event persisted % original rows', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id='36000000-0000-4000-8000-000000000003'
       AND event_type='source_event_conflict'
       AND details->>'attempted_source_event_reference' = 'conflict-ref';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'committed conflict audit rows: %', v_count;
    END IF;

    SELECT status, source_outcome, source_integrity_status
      INTO v_status, v_outcome, v_integrity
      FROM reputation.v_engagement_current_state
     WHERE engagement_id='36000000-0000-4000-8000-000000000003';

    IF v_status <> 'active' OR v_outcome <> 'completed' OR v_integrity <> 'consistent' THEN
        RAISE EXCEPTION 'conflict audit changed non-voided state: %/%/%',
            v_status, v_outcome, v_integrity;
    END IF;
END;
$run_conflict$;

SELECT dblink_disconnect('conflict_b');
SELECT dblink_disconnect('conflict_a');
SELECT dblink_disconnect('ident_b');
SELECT dblink_disconnect('ident_a');

-- Committed disposable fixture is intentionally left for inspection. Discard
-- the local database after this test.

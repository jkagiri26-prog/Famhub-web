-- ============================================================================
-- reputation_evidence_phase2b_concurrency_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE concurrency and transaction-boundary test.
--
-- Uses committed disposable fixtures because dblink sessions require visibility
-- across connections. Run only against a disposable local database and discard
-- the database afterward. Never run against production.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;

BEGIN;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('60000000-0000-4000-8000-000000000001', 'Evidence Concurrency Country', 'EC', 'ECT', '9996', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('60000000-0000-4000-8000-000000000002', 'Evidence Concurrency Location',
        '60000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('60000000-0000-4000-8000-000000000003', 'evidence-concurrency-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);
INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('61000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000901',
     'Evidence Concurrency Buyer', '60000000-0000-4000-8000-000000000001', true, 'active'),
    ('61000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000902',
     'Evidence Concurrency Seller', '60000000-0000-4000-8000-000000000001', true, 'active');
SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES
    ('62000000-0000-4000-8000-000000000001', 'Evidence Concurrency Buyer Entity',
     'individual_pro', '61000000-0000-4000-8000-000000000001', true, 'verified'),
    ('62000000-0000-4000-8000-000000000002', 'Evidence Concurrency Seller Entity',
     'farm', '61000000-0000-4000-8000-000000000002', true, 'verified');

INSERT INTO core.items (id, name)
VALUES ('63000000-0000-4000-8000-000000000001', 'Evidence Concurrency Item');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('63000000-0000-4000-8000-000000000002',
        '63000000-0000-4000-8000-000000000001', 'Evidence Concurrency Variant');

INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    '63000000-0000-4000-8000-000000000004',
    '62000000-0000-4000-8000-000000000002',
    '64000000-0000-4000-8000-000000000001',
    '63000000-0000-4000-8000-000000000002',
    '63000000-0000-4000-8000-000000000001',
    '60000000-0000-4000-8000-000000000002',
    100.00, 0.00, '60000000-0000-4000-8000-000000000003', 'active'
);

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    '63000000-0000-4000-8000-000000000003',
    '62000000-0000-4000-8000-000000000002',
    'Evidence Concurrency Listing', 50.00, 'KES',
    '60000000-0000-4000-8000-000000000002',
    '63000000-0000-4000-8000-000000000002',
    100.00, '60000000-0000-4000-8000-000000000003', 'active',
    '63000000-0000-4000-8000-000000000004'
);

INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    '64000000-0000-4000-8000-000000000001', 'farm',
    '61000000-0000-4000-8000-000000000002', 'Evidence Concurrency Supplier',
    'verified', true, '62000000-0000-4000-8000-000000000002', true
);

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, delivery_date, entity_id,
    order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
    status_changed_by_profile_id
) VALUES
    ('65000000-0000-4000-8000-000000000001',
     '61000000-0000-4000-8000-000000000001',
     '63000000-0000-4000-8000-000000000003',
     '64000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T10:00:00Z', '2026-11-19T10:00:00Z',
     '62000000-0000-4000-8000-000000000002', 'stock',
     '62000000-0000-4000-8000-000000000001',
     '62000000-0000-4000-8000-000000000002', 'KES',
     '60000000-0000-4000-8000-000000000003',
     '61000000-0000-4000-8000-000000000001'),
    ('65000000-0000-4000-8000-000000000002',
     '61000000-0000-4000-8000-000000000001',
     '63000000-0000-4000-8000-000000000003',
     '64000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T11:00:00Z', '2026-11-19T11:00:00Z',
     '62000000-0000-4000-8000-000000000002', 'stock',
     '62000000-0000-4000-8000-000000000001',
     '62000000-0000-4000-8000-000000000002', 'KES',
     '60000000-0000-4000-8000-000000000003',
     '61000000-0000-4000-8000-000000000001'),
    ('65000000-0000-4000-8000-000000000003',
     '61000000-0000-4000-8000-000000000001',
     '63000000-0000-4000-8000-000000000003',
     '64000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T12:00:00Z', '2026-11-19T12:00:00Z',
     '62000000-0000-4000-8000-000000000002', 'stock',
     '62000000-0000-4000-8000-000000000001',
     '62000000-0000-4000-8000-000000000002', 'KES',
     '60000000-0000-4000-8000-000000000003',
     '61000000-0000-4000-8000-000000000001');

INSERT INTO commerce.order_items (
    id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
    stock_id, variant_id, unit_id
) VALUES
    ('66000000-0000-4000-8000-000000000001',
     '65000000-0000-4000-8000-000000000001',
     '63000000-0000-4000-8000-000000000003',
     '63000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '63000000-0000-4000-8000-000000000004',
     '63000000-0000-4000-8000-000000000002',
     '60000000-0000-4000-8000-000000000003'),
    ('66000000-0000-4000-8000-000000000002',
     '65000000-0000-4000-8000-000000000002',
     '63000000-0000-4000-8000-000000000003',
     '63000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '63000000-0000-4000-8000-000000000004',
     '63000000-0000-4000-8000-000000000002',
     '60000000-0000-4000-8000-000000000003'),
    ('66000000-0000-4000-8000-000000000003',
     '65000000-0000-4000-8000-000000000003',
     '63000000-0000-4000-8000-000000000003',
     '63000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '63000000-0000-4000-8000-000000000004',
     '63000000-0000-4000-8000-000000000002',
     '60000000-0000-4000-8000-000000000003');

CREATE FUNCTION pg_temp.snapshot_hash(p_snapshot jsonb)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT pg_catalog.sha256(convert_to(p_snapshot::text, 'UTF8'))
$$;

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
AS $$
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
$$;

INSERT INTO reputation.engagements (
    id, engagement_kind, source_system, source_reference, commerce_order_id,
    source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
) VALUES
    ('67000000-0000-4000-8000-000000000001', 'vunio_order', 'vunio',
     '65000000-0000-4000-8000-000000000001',
     '65000000-0000-4000-8000-000000000001',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T10:00:00Z', 'KES', 100.00),
    ('67000000-0000-4000-8000-000000000002', 'vunio_order', 'vunio',
     '65000000-0000-4000-8000-000000000002',
     '65000000-0000-4000-8000-000000000002',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T11:00:00Z', 'KES', 100.00),
    ('67000000-0000-4000-8000-000000000003', 'vunio_order', 'vunio',
     '65000000-0000-4000-8000-000000000003',
     '65000000-0000-4000-8000-000000000003',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T12:00:00Z', 'KES', 100.00);

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES
    ('67000000-0000-4000-8000-000000000001', 'reputation',
     'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('67000000-0000-4000-8000-000000000002', 'reputation',
     'engagement_recorded', '2026-11-19T11:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('67000000-0000-4000-8000-000000000003', 'reputation',
     'engagement_recorded', '2026-11-19T12:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}');

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key,
    source_namespace, source_event_reference, payload_hash, details
) VALUES
    ('67000000-0000-4000-8000-000000000001', 'source', 'order_delivered',
     '2026-11-19T10:00:00Z', 'vunio:delivered',
     'vunio', 'order:65000000-0000-4000-8000-000000000001:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T10:00:00Z', 'vunio',
         'order:65000000-0000-4000-8000-000000000001:delivered', NULL, '{}'::jsonb
     ), '{}'),
    ('67000000-0000-4000-8000-000000000002', 'source', 'order_delivered',
     '2026-11-19T11:00:00Z', 'vunio:delivered',
     'vunio', 'order:65000000-0000-4000-8000-000000000002:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T11:00:00Z', 'vunio',
         'order:65000000-0000-4000-8000-000000000002:delivered', NULL, '{}'::jsonb
     ), '{}'),
    ('67000000-0000-4000-8000-000000000003', 'source', 'order_delivered',
     '2026-11-19T12:00:00Z', 'vunio:delivered',
     'vunio', 'order:65000000-0000-4000-8000-000000000003:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T12:00:00Z', 'vunio',
         'order:65000000-0000-4000-8000-000000000003:delivered', NULL, '{}'::jsonb
     ), '{}');

COMMIT;

CREATE TABLE pg_temp.concurrency_ref (
    label text PRIMARY KEY,
    evidence_id uuid,
    conflict_event_id uuid
);

-- ----------------------------------------------------------------------------
-- Connections and remote helpers
-- ----------------------------------------------------------------------------
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

    PERFORM dblink_connect('ident_a', v_conn);
    PERFORM dblink_connect('ident_b', v_conn);
    PERFORM dblink_connect('conflict_a', v_conn);
    PERFORM dblink_connect('conflict_b', v_conn);
    PERFORM dblink_connect('revoke_a', v_conn);
    PERFORM dblink_connect('capture_b', v_conn);
    PERFORM dblink_connect('supersede_a', v_conn);
    PERFORM dblink_connect('supersede_b', v_conn);
END;
$connect$;

DO $install_helpers$
DECLARE
    v_capture text := $fn$
CREATE FUNCTION pg_temp.try_capture(p_engagement uuid)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    r record;
BEGIN
    SELECT * INTO r
      FROM system.capture_reputation_order_evidence(p_engagement);
    RETURN r.evidence_id::text || '|' || r.outcome || '|'
        || r.evidence_status || '|'
        || COALESCE(r.conflict_event_id::text, '');
END;
$body$;
$fn$;
    v_capture_after_update text := $fn$
CREATE FUNCTION pg_temp.try_capture_after_engagement_update(
    p_engagement uuid,
    p_order uuid,
    p_delivered timestamptz
)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    r record;
BEGIN
    -- Exercise the documented engagement -> order -> evidence lock order.
    PERFORM 1
      FROM reputation.engagements AS e
     WHERE e.id = p_engagement
     FOR UPDATE;

    UPDATE commerce.orders
       SET delivered_at = p_delivered,
           delivery_date = p_delivered,
           updated_at = now()
     WHERE id = p_order;

    SELECT * INTO r
      FROM system.capture_reputation_order_evidence(p_engagement);
    RETURN r.evidence_id::text || '|' || r.outcome || '|'
        || r.evidence_status || '|'
        || COALESCE(r.conflict_event_id::text, '');
END;
$body$;
$fn$;
    v_supersede text := $fn$
CREATE FUNCTION pg_temp.try_supersede(
    p_engagement uuid,
    p_old uuid,
    p_version text
)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    r record;
BEGIN
    SELECT * INTO r
      FROM system.supersede_reputation_order_evidence(
          p_engagement, p_old, p_version
      );
    RETURN r.evidence_id::text || '|'
        || r.superseded_evidence_id::text || '|'
        || r.outcome;
END;
$body$;
$fn$;
    v_revoke text := $fn$
CREATE FUNCTION pg_temp.try_revoke(p_evidence uuid)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    r record;
BEGIN
    SELECT * INTO r
      FROM system.revoke_reputation_evidence(
          p_evidence, 'concurrency_test', 'concurrency revocation'
      );
    RETURN r.evidence_id::text || '|' || r.outcome || '|' || r.evidence_status;
END;
$body$;
$fn$;
    v_conn text;
BEGIN
    FOREACH v_conn IN ARRAY ARRAY[
        'ident_a', 'ident_b', 'conflict_a', 'conflict_b', 'revoke_a',
        'capture_b', 'supersede_a', 'supersede_b'
    ] LOOP
        PERFORM dblink_exec(v_conn, v_capture);
        PERFORM dblink_exec(v_conn, v_capture_after_update);
        PERFORM dblink_exec(v_conn, v_revoke);
        PERFORM dblink_exec(v_conn, v_supersede);
    END LOOP;
END;
$install_helpers$;

-- ----------------------------------------------------------------------------
-- Case 1: simultaneous identical captures
-- ----------------------------------------------------------------------------
DO $identical$
DECLARE
    v_a text;
    v_b text;
    v_count integer;
BEGIN
    PERFORM dblink_exec('ident_a', 'BEGIN');
    PERFORM dblink_exec('ident_b', 'BEGIN');

    PERFORM dblink_send_query(
        'ident_a', $q$SELECT pg_temp.try_capture('67000000-0000-4000-8000-000000000001'::uuid)$q$
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'ident_b', $q$SELECT pg_temp.try_capture('67000000-0000-4000-8000-000000000001'::uuid)$q$
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_a
      FROM dblink_get_result('ident_a') AS t(result text);
    PERFORM result FROM dblink_get_result('ident_a') AS t(result text);
    PERFORM dblink_exec('ident_a', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('ident_b') AS t(result text);
    PERFORM result FROM dblink_get_result('ident_b') AS t(result text);
    PERFORM dblink_exec('ident_b', 'COMMIT');

    IF split_part(v_a, '|', 2) <> 'recorded'
       OR split_part(v_b, '|', 2) <> 'already_recorded' THEN
        RAISE EXCEPTION 'unexpected identical capture results: % / %', v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='67000000-0000-4000-8000-000000000001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'identical captures created % evidence rows', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events ee
      JOIN reputation.evidence e ON e.id = ee.evidence_id
     WHERE e.engagement_id='67000000-0000-4000-8000-000000000001'
       AND ee.event_type='evidence_recorded';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'identical captures created % initial events', v_count;
    END IF;

    INSERT INTO pg_temp.concurrency_ref(label, evidence_id, conflict_event_id)
    SELECT 'e1', id, NULL
      FROM reputation.evidence
     WHERE engagement_id='67000000-0000-4000-8000-000000000001';
END;
$identical$;

-- ----------------------------------------------------------------------------
-- Case 2: simultaneous conflicting captures
-- ----------------------------------------------------------------------------
DO $conflicting$
DECLARE
    v_a text;
    v_b text;
    v_count integer;
    v_evidence_id uuid;
    v_conflict_id uuid;
BEGIN
    PERFORM dblink_exec('conflict_a', 'BEGIN');
    PERFORM dblink_exec('conflict_b', 'BEGIN');

    PERFORM dblink_send_query(
        'conflict_a', $q$SELECT pg_temp.try_capture('67000000-0000-4000-8000-000000000002'::uuid)$q$
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'conflict_b',
        $q$SELECT pg_temp.try_capture_after_engagement_update(
            '67000000-0000-4000-8000-000000000002'::uuid,
            '65000000-0000-4000-8000-000000000002'::uuid,
            '2026-11-19T11:05:00Z'::timestamptz
        )$q$
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_a
      FROM dblink_get_result('conflict_a') AS t(result text);
    PERFORM result FROM dblink_get_result('conflict_a') AS t(result text);
    PERFORM dblink_exec('conflict_a', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('conflict_b') AS t(result text);
    PERFORM result FROM dblink_get_result('conflict_b') AS t(result text);
    PERFORM dblink_exec('conflict_b', 'COMMIT');

    IF split_part(v_a, '|', 2) <> 'recorded'
       OR split_part(v_b, '|', 2) <> 'conflict_recorded' THEN
        RAISE EXCEPTION 'unexpected conflicting capture results: % / %', v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='67000000-0000-4000-8000-000000000002';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'conflicting captures created % evidence rows', v_count;
    END IF;

    SELECT id INTO v_evidence_id
      FROM reputation.evidence
     WHERE engagement_id='67000000-0000-4000-8000-000000000002';

    SELECT id INTO v_conflict_id
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id
       AND event_type='evidence_conflict_detected';

    IF v_conflict_id IS NULL THEN
        RAISE EXCEPTION 'conflict evidence event is missing';
    END IF;

    INSERT INTO pg_temp.concurrency_ref(label, evidence_id, conflict_event_id)
    VALUES ('e2', v_evidence_id, v_conflict_id);
END;
$conflicting$;

-- The next transaction verifies the committed conflict audit.
DO $conflict_persisted$
DECLARE
    v_evidence_id uuid;
    v_conflict_id uuid;
    v_count integer;
BEGIN
    SELECT evidence_id, conflict_event_id
      INTO v_evidence_id, v_conflict_id
      FROM pg_temp.concurrency_ref
     WHERE label='e2';

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events ee
     WHERE ee.id=v_conflict_id
       AND ee.evidence_id=v_evidence_id
       AND ee.event_type='evidence_conflict_detected'
       AND ee.details->>'attempted_source_reference'='65000000-0000-4000-8000-000000000002'
       AND ee.details->>'reason_code'='source_snapshot_mismatch'
       AND ee.details->>'attempted_source_snapshot_hash' ~ '^[0-9a-f]{64}$';

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'committed conflict audit is not queryable';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.v_evidence_current_state v
         WHERE v.evidence_id=v_evidence_id
           AND v.evidence_status='conflicted'
           AND v.unresolved_conflict_count=1
    ) THEN
        RAISE EXCEPTION 'committed conflict state is wrong';
    END IF;
END;
$conflict_persisted$;

-- ----------------------------------------------------------------------------
-- Case 3: simultaneous supersession attempts and retries
-- ----------------------------------------------------------------------------
DO $prepare_supersede$
DECLARE
    v_capture record;
BEGIN
    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          '67000000-0000-4000-8000-000000000003'
      );
    IF v_capture.outcome <> 'recorded' THEN
        RAISE EXCEPTION 'supersession concurrency fixture capture failed';
    END IF;
    INSERT INTO pg_temp.concurrency_ref(label, evidence_id)
    VALUES ('e3v1', v_capture.evidence_id);
END;
$prepare_supersede$;

DO $supersede_concurrency$
DECLARE
    v_v1 uuid;
    v_a text;
    v_b text;
    v_count integer;
BEGIN
    SELECT evidence_id INTO v_v1
      FROM pg_temp.concurrency_ref
     WHERE label='e3v1';

    PERFORM dblink_exec('supersede_a', 'BEGIN');
    PERFORM dblink_exec('supersede_b', 'BEGIN');

    PERFORM dblink_send_query(
        'supersede_a',
        format(
            'SELECT pg_temp.try_supersede(%L::uuid, %L::uuid, %L)',
            '67000000-0000-4000-8000-000000000003',
            v_v1,
            'delivery:v2'
        )
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'supersede_b',
        format(
            'SELECT pg_temp.try_supersede(%L::uuid, %L::uuid, %L)',
            '67000000-0000-4000-8000-000000000003',
            v_v1,
            'delivery:v2'
        )
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_a
      FROM dblink_get_result('supersede_a') AS t(result text);
    PERFORM result FROM dblink_get_result('supersede_a') AS t(result text);
    PERFORM dblink_exec('supersede_a', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('supersede_b') AS t(result text);
    PERFORM result FROM dblink_get_result('supersede_b') AS t(result text);
    PERFORM dblink_exec('supersede_b', 'COMMIT');

    IF NOT (
        (split_part(v_a, '|', 3) = 'superseded'
         AND split_part(v_b, '|', 3) = 'already_recorded')
        OR
        (split_part(v_a, '|', 3) = 'already_recorded'
         AND split_part(v_b, '|', 3) = 'superseded')
    ) THEN
        RAISE EXCEPTION 'unexpected supersession results: % / %', v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='67000000-0000-4000-8000-000000000003';
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'simultaneous supersession created % evidence rows', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_v1 AND event_type='evidence_superseded';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'simultaneous supersession created % supersession events', v_count;
    END IF;

    -- Simultaneous retries must both return already_recorded.
    PERFORM dblink_exec('supersede_a', 'BEGIN');
    PERFORM dblink_exec('supersede_b', 'BEGIN');

    PERFORM dblink_send_query(
        'supersede_a',
        format(
            'SELECT pg_temp.try_supersede(%L::uuid, %L::uuid, %L)',
            '67000000-0000-4000-8000-000000000003',
            v_v1,
            'delivery:v2'
        )
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'supersede_b',
        format(
            'SELECT pg_temp.try_supersede(%L::uuid, %L::uuid, %L)',
            '67000000-0000-4000-8000-000000000003',
            v_v1,
            'delivery:v2'
        )
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_a
      FROM dblink_get_result('supersede_a') AS t(result text);
    PERFORM result FROM dblink_get_result('supersede_a') AS t(result text);
    PERFORM dblink_exec('supersede_a', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('supersede_b') AS t(result text);
    PERFORM result FROM dblink_get_result('supersede_b') AS t(result text);
    PERFORM dblink_exec('supersede_b', 'COMMIT');

    IF split_part(v_a, '|', 3) <> 'already_recorded'
       OR split_part(v_b, '|', 3) <> 'already_recorded' THEN
        RAISE EXCEPTION 'simultaneous supersession retries were not idempotent: % / %',
            v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='67000000-0000-4000-8000-000000000003';
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'supersession retries duplicated evidence';
    END IF;
END;
$supersede_concurrency$;

-- ----------------------------------------------------------------------------
-- Case 4: capture versus revocation
-- ----------------------------------------------------------------------------
DO $capture_vs_revoke$
DECLARE
    v_evidence_id uuid;
    v_revoke text;
    v_capture text;
    v_count integer;
    v_status text;
BEGIN
    SELECT evidence_id INTO v_evidence_id
      FROM pg_temp.concurrency_ref
     WHERE label='e1';

    PERFORM dblink_exec('revoke_a', 'BEGIN');
    PERFORM dblink_exec('capture_b', 'BEGIN');

    PERFORM dblink_send_query(
        'revoke_a', format('SELECT pg_temp.try_revoke(%L::uuid)', v_evidence_id)
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'capture_b', $q$SELECT pg_temp.try_capture('67000000-0000-4000-8000-000000000001'::uuid)$q$
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_revoke
      FROM dblink_get_result('revoke_a') AS t(result text);
    PERFORM result FROM dblink_get_result('revoke_a') AS t(result text);
    PERFORM dblink_exec('revoke_a', 'COMMIT');

    SELECT result INTO v_capture
      FROM dblink_get_result('capture_b') AS t(result text);
    PERFORM result FROM dblink_get_result('capture_b') AS t(result text);
    PERFORM dblink_exec('capture_b', 'COMMIT');

    IF split_part(v_revoke, '|', 2) <> 'revoked'
       OR split_part(v_capture, '|', 2) <> 'already_recorded'
       OR split_part(v_capture, '|', 3) <> 'revoked' THEN
        RAISE EXCEPTION 'capture/revocation ordering mismatch: % / %', v_revoke, v_capture;
    END IF;

    SELECT evidence_status INTO v_status
      FROM reputation.v_evidence_current_state
     WHERE evidence_id=v_evidence_id;

    IF v_status <> 'revoked' THEN
        RAISE EXCEPTION 'final status after revocation is %', v_status;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id AND event_type='evidence_revoked';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'revocation event count is %', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='67000000-0000-4000-8000-000000000001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'capture after revocation created duplicate evidence';
    END IF;
END;
$capture_vs_revoke$;

SELECT dblink_disconnect('supersede_b');
SELECT dblink_disconnect('supersede_a');
SELECT dblink_disconnect('capture_b');
SELECT dblink_disconnect('revoke_a');
SELECT dblink_disconnect('conflict_b');
SELECT dblink_disconnect('conflict_a');
SELECT dblink_disconnect('ident_b');
SELECT dblink_disconnect('ident_a');

-- Committed disposable fixtures remain for inspection. Discard the local
-- database after this test.

-- ============================================================================
-- reputation_engagement_phase2a_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE test for the Phase 2A engagement foundation.
--
-- Run only against a local/disposable database with all migrations applied.
-- Never run against production.
-- ============================================================================
BEGIN;

-- ----------------------------------------------------------------------------
-- Fixtures
-- ----------------------------------------------------------------------------
INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('20000000-0000-4000-8000-000000000001', 'Engagement Test Country', 'QT', 'QTX', '9999', true);

INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('20000000-0000-4000-8000-000000000002', 'Engagement Test Location',
        '20000000-0000-4000-8000-000000000001', true);

INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('20000000-0000-4000-8000-000000000003', 'engagement-test-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('21000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000901',
     'Engagement Buyer', '20000000-0000-4000-8000-000000000001', true, 'active'),
    ('21000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000902',
     'Engagement Seller', '20000000-0000-4000-8000-000000000001', true, 'active');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES
    ('22000000-0000-4000-8000-000000000001', 'Engagement Buyer Entity',
     'individual_pro', '21000000-0000-4000-8000-000000000001', true, 'verified'),
    ('22000000-0000-4000-8000-000000000002', 'Engagement Seller Entity',
     'farm', '21000000-0000-4000-8000-000000000002', true, 'verified');

INSERT INTO core.items (id, name)
VALUES ('23000000-0000-4000-8000-000000000001', 'Engagement Test Item');

INSERT INTO core.item_variants (id, item_id, name)
VALUES ('23000000-0000-4000-8000-000000000002',
        '23000000-0000-4000-8000-000000000001', 'Engagement Test Variant');

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status
)
VALUES (
    '23000000-0000-4000-8000-000000000003',
    '22000000-0000-4000-8000-000000000002',
    'Engagement Test Listing',
    50.00,
    'KES',
    '20000000-0000-4000-8000-000000000002',
    '23000000-0000-4000-8000-000000000002',
    10.00,
    '20000000-0000-4000-8000-000000000003',
    'active'
);

INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
)
VALUES (
    '24000000-0000-4000-8000-000000000001',
    'farm',
    '21000000-0000-4000-8000-000000000002',
    'Engagement Test Supplier',
    'verified',
    true,
    '22000000-0000-4000-8000-000000000002',
    true
);

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, entity_id, order_kind,
    buyer_entity_id, seller_entity_id, currency
)
VALUES (
    '25000000-0000-4000-8000-000000000001',
    '21000000-0000-4000-8000-000000000001',
    '23000000-0000-4000-8000-000000000003',
    '24000000-0000-4000-8000-000000000001',
    2.00,
    100.00,
    'delivered',
    'pending',
    '2026-11-19T09:00:00Z',
    '2026-11-19T10:00:00Z',
    '22000000-0000-4000-8000-000000000002',
    'stock',
    '22000000-0000-4000-8000-000000000001',
    '22000000-0000-4000-8000-000000000002',
    'KES'
);

INSERT INTO reputation.subjects (id, subject_type, subject_role, entity_id)
VALUES ('26000000-0000-4000-8000-000000000001', 'entity', 'seller',
        '22000000-0000-4000-8000-000000000002');

INSERT INTO reputation.subjects (id, subject_type, subject_role, listing_id)
VALUES ('26000000-0000-4000-8000-000000000002', 'listing', 'listing',
        '23000000-0000-4000-8000-000000000003');

INSERT INTO reputation.subjects (id, subject_type, subject_role, item_id)
VALUES ('26000000-0000-4000-8000-000000000003', 'item', 'product',
        '23000000-0000-4000-8000-000000000001');

INSERT INTO reputation.subjects (id, subject_type, subject_role, variant_id)
VALUES ('26000000-0000-4000-8000-000000000004', 'variant', 'product_variant',
        '23000000-0000-4000-8000-000000000002');

-- ----------------------------------------------------------------------------
-- Test helpers
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- Engagements and initial events
-- ----------------------------------------------------------------------------
DO $initial$
DECLARE
    v_snapshot jsonb;
    v_delivered_hash bytea;
BEGIN
    v_snapshot := jsonb_build_object(
        'snapshot_version', 1,
        'order', jsonb_build_object(
            'id', '25000000-0000-4000-8000-000000000001',
            'status', 'delivered',
            'order_kind', 'stock',
            'payment_status', 'pending',
            'buyer_id', '21000000-0000-4000-8000-000000000001',
            'buyer_entity_id', '22000000-0000-4000-8000-000000000001',
            'seller_entity_id', '22000000-0000-4000-8000-000000000002',
            'supplier_id', '24000000-0000-4000-8000-000000000001',
            'entity_id', '22000000-0000-4000-8000-000000000002',
            'listing_id', '23000000-0000-4000-8000-000000000003',
            'currency', 'KES',
            'quantity', '2.00',
            'total_amount', '100.00',
            'unit_id', '20000000-0000-4000-8000-000000000003',
            'order_date', '2026-11-19T09:00:00.000000Z',
            'delivered_at', '2026-11-19T10:00:00.000000Z'
        ),
        'order_items', jsonb_build_array(
            jsonb_build_object(
                'id', '25000000-0000-4000-8000-000000000002',
                'listing_id', '23000000-0000-4000-8000-000000000003',
                'product_id', '23000000-0000-4000-8000-000000000001',
                'variant_id', '23000000-0000-4000-8000-000000000002',
                'quantity', '2.00',
                'price_per_unit', '50.00',
                'total_amount', '100.00'
            )
        ),
        'resolved', jsonb_build_object(
            'listings', jsonb_build_array(jsonb_build_object(
                'id', '23000000-0000-4000-8000-000000000003',
                'entity_id', '22000000-0000-4000-8000-000000000002',
                'variant_id', '23000000-0000-4000-8000-000000000002'
            )),
            'variants', jsonb_build_array(jsonb_build_object(
                'id', '23000000-0000-4000-8000-000000000002',
                'item_id', '23000000-0000-4000-8000-000000000001',
                'name', 'Engagement Test Variant'
            )),
            'items', jsonb_build_array(jsonb_build_object(
                'id', '23000000-0000-4000-8000-000000000001',
                'name', 'Engagement Test Item'
            ))
        )
    );

    INSERT INTO reputation.engagements (
        id, engagement_kind, source_system, source_reference, commerce_order_id,
        source_snapshot, source_snapshot_hash, source_occurred_at,
        currency, gross_amount
    ) VALUES (
        '27000000-0000-4000-8000-000000000001',
        'vunio_order', 'vunio', '25000000-0000-4000-8000-000000000001',
        '25000000-0000-4000-8000-000000000001',
        v_snapshot, pg_temp.snapshot_hash(v_snapshot),
        '2026-11-19T10:00:00Z', 'KES', 100.00
    );

    INSERT INTO reputation.engagement_participants (
        engagement_id, party_role, profile_id, entity_id
    ) VALUES (
        '27000000-0000-4000-8000-000000000001', 'buyer',
        '21000000-0000-4000-8000-000000000001',
        '22000000-0000-4000-8000-000000000001'
    );

    INSERT INTO reputation.engagement_participants (
        engagement_id, party_role, entity_id
    ) VALUES (
        '27000000-0000-4000-8000-000000000001', 'seller',
        '22000000-0000-4000-8000-000000000002'
    );

    INSERT INTO reputation.engagement_subjects (
        engagement_id, subject_id, relationship, source_fact
    ) VALUES
        ('27000000-0000-4000-8000-000000000001',
         '26000000-0000-4000-8000-000000000001',
         'seller_entity', '{"seller_entity_id":"22000000-0000-4000-8000-000000000002"}'),
        ('27000000-0000-4000-8000-000000000001',
         '26000000-0000-4000-8000-000000000002',
         'listing', '{"listing_id":"23000000-0000-4000-8000-000000000003"}'),
        ('27000000-0000-4000-8000-000000000001',
         '26000000-0000-4000-8000-000000000003',
         'product', '{"item_id":"23000000-0000-4000-8000-000000000001"}'),
        ('27000000-0000-4000-8000-000000000001',
         '26000000-0000-4000-8000-000000000004',
         'variant', '{"variant_id":"23000000-0000-4000-8000-000000000002"}');

    -- Secondary engagements for event and subject tests.
    INSERT INTO reputation.engagements (
        id, engagement_kind, source_system, source_reference,
        source_snapshot, source_snapshot_hash, source_occurred_at
    ) VALUES
        ('27000000-0000-4000-8000-000000000002', 'external_transaction',
         'test', 'external-b', '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
         '2026-11-19T10:00:00Z'),
        ('27000000-0000-4000-8000-000000000003', 'external_transaction',
         'test', 'external-c', '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
         '2026-11-19T10:00:00Z'),
        ('27000000-0000-4000-8000-000000000004', 'external_transaction',
         'test', 'external-d', '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
         '2026-11-19T10:00:00Z'),
        ('27000000-0000-4000-8000-000000000005', 'external_transaction',
         'test', 'external-e', '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
         '2026-11-19T10:00:00Z');

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, details
    ) VALUES
        ('27000000-0000-4000-8000-000000000001', 'reputation',
         'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
         '{"source_integrity_status":"consistent"}'),
        ('27000000-0000-4000-8000-000000000002', 'reputation',
         'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
         '{"source_integrity_status":"consistent"}'),
        ('27000000-0000-4000-8000-000000000003', 'reputation',
         'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
         '{"source_integrity_status":"consistent"}'),
        ('27000000-0000-4000-8000-000000000004', 'reputation',
         'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
         '{"source_integrity_status":"consistent"}'),
        ('27000000-0000-4000-8000-000000000005', 'reputation',
         'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
         '{"source_integrity_status":"consistent"}');

    v_delivered_hash := pg_temp.event_hash(
        'order_delivered',
        '2026-11-19T10:00:00Z',
        'vunio',
        'order:25000000-0000-4000-8000-000000000001:delivered',
        NULL,
        '{}'::jsonb
    );

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000001', 'source',
        'order_delivered', '2026-11-19T10:00:00Z', 'vunio:delivered',
        'vunio', 'order:25000000-0000-4000-8000-000000000001:delivered',
        v_delivered_hash, '{}'
    );
END;
$initial$;

SET CONSTRAINTS ALL IMMEDIATE;

-- ----------------------------------------------------------------------------
-- Schema, immutability and security
-- ----------------------------------------------------------------------------
DO $schema$
DECLARE
    v_cols text[];
    v_rls boolean;
BEGIN
    IF to_regclass('reputation.engagements') IS NULL
       OR to_regclass('reputation.engagement_participants') IS NULL
       OR to_regclass('reputation.engagement_subjects') IS NULL
       OR to_regclass('reputation.engagement_events') IS NULL THEN
        RAISE EXCEPTION 'Phase 2A tables are missing';
    END IF;

    IF to_regclass('reputation.v_engagement_current_state') IS NULL THEN
        RAISE EXCEPTION 'Phase 2A state view is missing';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname='reputation'
           AND c.relname IN (
               'engagements','engagement_participants',
               'engagement_subjects','engagement_events'
           )
           AND pg_get_userbyid(c.relowner) <> 'postgres'
    ) THEN
        RAISE EXCEPTION 'Reputation table owner is not postgres';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname='reputation'
           AND p.proname='validate_engagement_event'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = false
           AND p.proconfig @> ARRAY['search_path=pg_catalog, reputation']
    ) THEN
        RAISE EXCEPTION 'validate_engagement_event security properties are wrong';
    END IF;

    SELECT array_agg(column_name::text ORDER BY ordinal_position)
      INTO v_cols
      FROM information_schema.columns
     WHERE table_schema='reputation' AND table_name='engagements';

    IF v_cols && ARRAY['status','source_outcome','source_integrity_status','updated_at']::text[] THEN
        RAISE EXCEPTION 'engagements must not contain mutable summary columns';
    END IF;

    IF (
        SELECT count(*)
          FROM pg_tables
         WHERE schemaname='reputation'
           AND tablename IN (
               'engagements',
               'engagement_participants',
               'engagement_subjects',
               'engagement_events',
               'subjects'
           )
    ) <> 5 THEN
        RAISE EXCEPTION 'Phase 2A reputation tables are missing';
    END IF;

    IF to_regclass('reputation.verification_decisions') IS NOT NULL
       OR to_regclass('reputation.review_eligibilities') IS NOT NULL
       OR to_regclass('reputation.reviews') IS NOT NULL THEN
        RAISE EXCEPTION 'out-of-scope Phase 2A object exists';
    END IF;

    SELECT relrowsecurity INTO v_rls
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='reputation' AND c.relname='engagements';
    IF v_rls IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'engagements RLS is not enabled';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_policies
         WHERE schemaname='reputation'
           AND tablename IN ('engagements','engagement_participants',
                             'engagement_subjects','engagement_events')
    ) THEN
        RAISE EXCEPTION 'unexpected Reputation policies exist';
    END IF;

    IF has_table_privilege('anon','reputation.engagements','SELECT')
       OR has_table_privilege('anon','reputation.engagement_participants','SELECT')
       OR has_table_privilege('anon','reputation.engagement_subjects','SELECT')
       OR has_table_privilege('anon','reputation.engagement_events','SELECT')
       OR has_table_privilege('authenticated','reputation.engagements','SELECT')
       OR has_table_privilege('authenticated','reputation.engagement_participants','SELECT')
       OR has_table_privilege('authenticated','reputation.engagement_subjects','SELECT')
       OR has_table_privilege('authenticated','reputation.engagement_events','SELECT')
       OR has_table_privilege('service_role','reputation.engagements','SELECT')
       OR has_table_privilege('service_role','reputation.engagement_participants','SELECT')
       OR has_table_privilege('service_role','reputation.engagement_subjects','SELECT')
       OR has_table_privilege('service_role','reputation.engagement_events','SELECT') THEN
        RAISE EXCEPTION 'browser or service_role has direct Reputation table access';
    END IF;

    IF has_table_privilege('anon','reputation.v_engagement_current_state','SELECT')
       OR has_table_privilege('authenticated','reputation.v_engagement_current_state','SELECT')
       OR has_table_privilege('service_role','reputation.v_engagement_current_state','SELECT') THEN
        RAISE EXCEPTION 'unexpected view access';
    END IF;

    IF has_function_privilege('anon','reputation.validate_engagement_event()','EXECUTE')
       OR has_function_privilege('authenticated','reputation.validate_engagement_event()','EXECUTE')
       OR has_function_privilege('service_role','reputation.validate_engagement_event()','EXECUTE') THEN
        RAISE EXCEPTION 'validation trigger function is directly executable';
    END IF;

    IF NOT has_function_privilege('service_role','reputation.register_subject(text,text,uuid)','EXECUTE') THEN
        RAISE EXCEPTION 'Phase 1 trusted function execute grant changed';
    END IF;
END;
$schema$;

DO $immutability$
BEGIN
    BEGIN
        UPDATE reputation.engagements SET source_snapshot = source_snapshot
         WHERE id='27000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'engagement UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM reputation.engagements
         WHERE id='27000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'engagement DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE reputation.engagement_participants SET party_role = party_role
         WHERE engagement_id='27000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'participant UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE reputation.engagement_subjects SET relationship = relationship
         WHERE engagement_id='27000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'subject link UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE reputation.engagement_events SET details = details
         WHERE engagement_id='27000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'event UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM reputation.engagement_events
         WHERE engagement_id='27000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'event DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$immutability$;

-- ----------------------------------------------------------------------------
-- Snapshot and initial state
-- ----------------------------------------------------------------------------
DO $snapshot$
DECLARE
    v_hash bytea;
    v_expected bytea;
    v_total text;
    v_state_count integer;
BEGIN
    SELECT source_snapshot_hash,
           pg_catalog.sha256(convert_to(source_snapshot::text,'UTF8')),
           source_snapshot->'order'->>'total_amount'
      INTO v_hash, v_expected, v_total
      FROM reputation.engagements
     WHERE id='27000000-0000-4000-8000-000000000001';

    IF v_hash IS DISTINCT FROM v_expected OR octet_length(v_hash) <> 32 THEN
        RAISE EXCEPTION 'snapshot hash mismatch or wrong length';
    END IF;
    IF v_total <> '100.00' THEN
        RAISE EXCEPTION 'snapshot monetary string was not canonical';
    END IF;

    BEGIN
        INSERT INTO reputation.engagements (
            id, engagement_kind, source_system, source_reference,
            source_snapshot, source_snapshot_hash, source_occurred_at
        ) VALUES (
            '28000000-0000-4000-8000-000000000001', 'external_transaction',
            'test', 'bad-snapshot-hash', '{"snapshot_version":1}',
            decode(repeat('00', 32), 'hex'), '2026-11-19T10:00:00Z'
        );
        RAISE EXCEPTION 'snapshot hash mismatch unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    SELECT count(*) INTO v_state_count
      FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000001'
       AND status='active'
       AND source_outcome='completed'
       AND source_integrity_status='consistent';
    IF v_state_count <> 1 THEN
        RAISE EXCEPTION 'initial derived state is wrong';
    END IF;
END;
$snapshot$;

-- ----------------------------------------------------------------------------
-- Source idempotency, conflict audit and namespace collision
-- ----------------------------------------------------------------------------
DO $idempotency$
DECLARE
    v_hash bytea;
    v_conflict_hash bytea;
    v_rows integer;
    v_count integer;
BEGIN
    v_hash := pg_temp.event_hash(
        'order_delivered', '2026-11-19T10:00:00Z', 'vunio',
        'order:25000000-0000-4000-8000-000000000001:delivered',
        NULL, '{}'::jsonb
    );

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000001', 'source',
        'order_delivered', '2026-11-19T10:00:00Z', 'vunio:delivered-retry',
        'vunio', 'order:25000000-0000-4000-8000-000000000001:delivered',
        v_hash, '{}'
    );
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 0 THEN
        RAISE EXCEPTION 'identical source retry was not a no-op';
    END IF;

    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key,
            source_namespace, source_event_reference, payload_hash, details
        ) VALUES (
            '27000000-0000-4000-8000-000000000003', 'source',
            'order_returned', '2026-11-19T10:01:00Z', 'c:bad-hash',
            'test', 'bad-hash', decode(repeat('00', 32), 'hex'), '{}'
        );
        RAISE EXCEPTION 'source event hash mismatch unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    v_conflict_hash := pg_temp.event_hash(
        'order_refunded', '2026-11-19T11:00:00Z', 'vunio',
        'order:25000000-0000-4000-8000-000000000001:delivered',
        NULL, '{"refund":"full"}'::jsonb
    );

    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key,
            source_namespace, source_event_reference, payload_hash, details
        ) VALUES (
            '27000000-0000-4000-8000-000000000001', 'source',
            'order_refunded', '2026-11-19T11:00:00Z', 'vunio:conflict',
            'vunio', 'order:25000000-0000-4000-8000-000000000001:delivered',
            v_conflict_hash, '{"refund":"full"}'::jsonb
        );
        RAISE EXCEPTION 'conflicting source identity unexpectedly succeeded';
    EXCEPTION WHEN unique_violation THEN
        PERFORM reputation.record_source_event_conflict(
            '27000000-0000-4000-8000-000000000001',
            'vunio',
            'order:25000000-0000-4000-8000-000000000001:delivered',
            'order_refunded',
            '2026-11-19T11:00:00Z',
            v_conflict_hash,
            'different_event'
        );
    END;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id='27000000-0000-4000-8000-000000000001'
       AND event_type='source_event_conflict';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'conflict audit was not preserved';
    END IF;

    -- Same external reference in a different namespace is allowed.
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000001', 'source',
        'order_returned', '2026-11-19T12:00:00Z', 'mpesa:shared-ref',
        'mpesa', 'order:25000000-0000-4000-8000-000000000001:delivered',
        pg_temp.event_hash(
            'order_returned', '2026-11-19T12:00:00Z', 'mpesa',
            'order:25000000-0000-4000-8000-000000000001:delivered',
            NULL, '{}'::jsonb
        ),
        '{}'
    );
END;
$idempotency$;

-- ----------------------------------------------------------------------------
-- Out-of-order source events, refund rules and derived summary
-- ----------------------------------------------------------------------------
DO $ordering$
DECLARE
    v_hash bytea;
    v_state text;
    v_outcome text;
    v_integrity text;
BEGIN
    -- Partial, then full, then a late older partial.
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000002', 'source',
        'order_partially_refunded', '2026-11-19T10:03:00Z', 'b:partial-1',
        'test', 'partial-1',
        pg_temp.event_hash('order_partially_refunded','2026-11-19T10:03:00Z','test','partial-1',NULL,'{}'::jsonb),
        '{}'
    );

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000002', 'source',
        'order_refunded', '2026-11-19T10:04:00Z', 'b:full-1',
        'test', 'full-1',
        pg_temp.event_hash('order_refunded','2026-11-19T10:04:00Z','test','full-1',NULL,'{}'::jsonb),
        '{}'
    );

    -- Older partial arriving late is valid historically but must not regress.
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000002', 'source',
        'order_partially_refunded', '2026-11-19T10:02:00Z', 'b:partial-late',
        'test', 'partial-late',
        pg_temp.event_hash('order_partially_refunded','2026-11-19T10:02:00Z','test','partial-late',NULL,'{}'::jsonb),
        '{}'
    );

    SELECT status, source_outcome, source_integrity_status
      INTO v_state, v_outcome, v_integrity
      FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000002';
    IF v_state <> 'active' OR v_outcome <> 'refunded' OR v_integrity <> 'consistent' THEN
        RAISE EXCEPTION 'out-of-order / refund summary mismatch: %/%/%',
            v_state, v_outcome, v_integrity;
    END IF;

    -- Partial after full is invalid.
    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key,
            source_namespace, source_event_reference, payload_hash, details
        ) VALUES (
            '27000000-0000-4000-8000-000000000002', 'source',
            'order_partially_refunded', '2026-11-19T10:05:00Z', 'b:partial-invalid',
            'test', 'partial-invalid',
            pg_temp.event_hash('order_partially_refunded','2026-11-19T10:05:00Z','test','partial-invalid',NULL,'{}'::jsonb),
            '{}'
        );
        RAISE EXCEPTION 'partial refund after full refund unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Return after refund is allowed and becomes the latest outcome.
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000002', 'source',
        'order_returned', '2026-11-19T10:06:00Z', 'b:return-1',
        'test', 'return-1',
        pg_temp.event_hash('order_returned','2026-11-19T10:06:00Z','test','return-1',NULL,'{}'::jsonb),
        '{}'
    );

    SELECT source_outcome INTO v_outcome
      FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000002';
    IF v_outcome <> 'returned' THEN
        RAISE EXCEPTION 'return after refund did not become latest outcome';
    END IF;

    -- Integrity transitions and older correction ordering.
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000002', 'source',
        'source_integrity_changed', '2026-11-19T10:07:00Z', 'b:integrity-incomplete',
        'test', 'integrity-incomplete',
        pg_temp.event_hash('source_integrity_changed','2026-11-19T10:07:00Z','test','integrity-incomplete',NULL,'{"source_integrity_status":"incomplete"}'::jsonb),
        '{"source_integrity_status":"incomplete"}'
    );

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000002', 'source',
        'source_integrity_changed', '2026-11-19T10:05:30Z', 'b:integrity-old-conflict',
        'test', 'integrity-old-conflict',
        pg_temp.event_hash('source_integrity_changed','2026-11-19T10:05:30Z','test','integrity-old-conflict',NULL,'{"source_integrity_status":"conflicted"}'::jsonb),
        '{"source_integrity_status":"conflicted"}'
    );

    SELECT source_integrity_status INTO v_integrity
      FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000002';
    IF v_integrity <> 'incomplete' THEN
        RAISE EXCEPTION 'older integrity correction regressed newer summary';
    END IF;

    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key,
            source_namespace, source_event_reference, payload_hash, details
        ) VALUES (
            '27000000-0000-4000-8000-000000000002', 'source',
            'source_integrity_changed', '2026-11-19T10:08:00Z', 'b:integrity-invalid',
            'test', 'integrity-invalid',
            pg_temp.event_hash('source_integrity_changed','2026-11-19T10:08:00Z','test','integrity-invalid',NULL,'{"source_integrity_status":"bogus"}'::jsonb),
            '{"source_integrity_status":"bogus"}'
        );
        RAISE EXCEPTION 'invalid source_integrity_status unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$ordering$;

-- ----------------------------------------------------------------------------
-- Disputes and void terminality
-- ----------------------------------------------------------------------------
DO $disputes$
DECLARE
    v_status text;
BEGIN
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000005', 'reputation',
        'dispute_opened', '2026-11-19T10:02:00Z', 'e:dispute-1-open', '{}'
    );

    SELECT status INTO v_status FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000005';
    IF v_status <> 'disputed' THEN
        RAISE EXCEPTION 'dispute open did not set disputed';
    END IF;

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000005', 'reputation',
        'dispute_dismissed', '2026-11-19T10:03:00Z', 'e:dispute-1-dismiss', '{}'
    );

    SELECT status INTO v_status FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000005';
    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'dispute dismissal did not restore active';
    END IF;

    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key, details
        ) VALUES (
            '27000000-0000-4000-8000-000000000005', 'reputation',
            'dispute_upheld', '2026-11-19T10:04:00Z', 'e:dispute-orphan', '{}'
        );
        RAISE EXCEPTION 'orphan dispute_upheld unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000005', 'reputation',
        'dispute_opened', '2026-11-19T10:05:00Z', 'e:dispute-2-open', '{}'
    );
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000005', 'reputation',
        'dispute_upheld', '2026-11-19T10:06:00Z', 'e:dispute-2-upheld', '{}'
    );

    SELECT status INTO v_status FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000005';
    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'generic upheld dispute voided or failed to restore active';
    END IF;

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000005', 'reputation',
        'engagement_voided', '2026-11-19T10:07:00Z', 'e:void-1',
        '{"invalidity_code":"duplicate"}'
    );

    SELECT status INTO v_status FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000005';
    IF v_status <> 'voided' THEN
        RAISE EXCEPTION 'explicit void did not set voided';
    END IF;

    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key, details
        ) VALUES (
            '27000000-0000-4000-8000-000000000005', 'reputation',
            'dispute_opened', '2026-11-19T10:08:00Z', 'e:after-void', '{}'
        );
        RAISE EXCEPTION 'event after void unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$disputes$;

-- ----------------------------------------------------------------------------
-- Same-effective-time dispute ordering
-- Validator order is event_at, recorded_at, id ascending. The derived view
-- uses the same effective time with recorded_at and id descending.
-- ----------------------------------------------------------------------------
DO $same_time$
DECLARE
    v_status text;
    v_same_time constant timestamptz := '2026-11-19T10:02:00Z';
    v_same_time_id constant timestamptz := '2026-11-19T10:03:00Z';
BEGIN
    -- recorded_at decides the order: open before dismiss is valid.
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, recorded_at,
        event_key, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000004', 'reputation',
        'dispute_opened', v_same_time, '2026-11-19T10:02:00.100000Z',
        'd:open-recorded', '{}'
    );
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, recorded_at,
        event_key, details
    ) VALUES (
        '27000000-0000-4000-8000-000000000004', 'reputation',
        'dispute_dismissed', v_same_time, '2026-11-19T10:02:00.200000Z',
        'd:dismiss-recorded', '{}'
    );

    SELECT status INTO v_status FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000004';
    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'same-time recorded_at dispute state mismatch: %', v_status;
    END IF;

    -- A same-time resolution ordered before its opening is invalid.
    BEGIN
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, recorded_at,
            event_key, details
        ) VALUES (
            '27000000-0000-4000-8000-000000000004', 'reputation',
            'dispute_upheld', v_same_time, '2026-11-19T10:02:00.050000Z',
            'd:invalid-upheld-recorded', '{}'
        );
        RAISE EXCEPTION 'same-time resolution before opening unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- The id is the final tie-breaker when event_at and recorded_at are equal.
    INSERT INTO reputation.engagement_events (
        id, engagement_id, event_origin, event_type, event_at, recorded_at,
        event_key, details
    ) VALUES (
        '29000000-0000-4000-8000-000000000001',
        '27000000-0000-4000-8000-000000000003', 'reputation',
        'dispute_opened', v_same_time_id, '2026-11-19T10:03:00.300000Z',
        'd2:open-id', '{}'
    );
    INSERT INTO reputation.engagement_events (
        id, engagement_id, event_origin, event_type, event_at, recorded_at,
        event_key, details
    ) VALUES (
        '29000000-0000-4000-8000-000000000002',
        '27000000-0000-4000-8000-000000000003', 'reputation',
        'dispute_dismissed', v_same_time_id, '2026-11-19T10:03:00.300000Z',
        'd2:dismiss-id', '{}'
    );

    SELECT status INTO v_status FROM reputation.v_engagement_current_state
     WHERE engagement_id='27000000-0000-4000-8000-000000000003';
    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'same-time id dispute state mismatch: %', v_status;
    END IF;

    -- An id that sorts before the opening makes the same-time sequence invalid.
    BEGIN
        INSERT INTO reputation.engagement_events (
            id, engagement_id, event_origin, event_type, event_at, recorded_at,
            event_key, details
        ) VALUES (
            '29000000-0000-4000-8000-000000000000',
            '27000000-0000-4000-8000-000000000003', 'reputation',
            'dispute_upheld', v_same_time_id, '2026-11-19T10:03:00.300000Z',
            'd2:invalid-upheld-id', '{}'
        );
        RAISE EXCEPTION 'same-time id resolution before opening unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$same_time$;

-- ----------------------------------------------------------------------------
-- Subject validation and retirement
-- ----------------------------------------------------------------------------
DO $subjects$
BEGIN
    BEGIN
        INSERT INTO reputation.engagement_subjects (
            engagement_id, subject_id, relationship, source_fact
        ) VALUES (
            '27000000-0000-4000-8000-000000000004',
            '26000000-0000-4000-8000-000000000001',
            'product', '{}'
        );
        RAISE EXCEPTION 'subject type/role mismatch unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    PERFORM reputation.retire_subject('26000000-0000-4000-8000-000000000002');

    BEGIN
        INSERT INTO reputation.engagement_subjects (
            engagement_id, subject_id, relationship, source_fact
        ) VALUES (
            '27000000-0000-4000-8000-000000000004',
            '26000000-0000-4000-8000-000000000002',
            'listing', '{}'
        );
        RAISE EXCEPTION 'retired subject link unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.engagement_subjects
         WHERE engagement_id='27000000-0000-4000-8000-000000000001'
           AND subject_id='26000000-0000-4000-8000-000000000002'
    ) THEN
        RAISE EXCEPTION 'existing historical subject link was lost';
    END IF;
END;
$subjects$;

ROLLBACK;

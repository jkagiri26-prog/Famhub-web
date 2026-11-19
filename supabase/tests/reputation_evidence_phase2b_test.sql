-- ============================================================================
-- reputation_evidence_phase2b_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE functional and security test for Phase 2B.
--
-- Run only against a local/disposable database with all migrations applied.
-- Never run against production.
-- ============================================================================
BEGIN;

-- ----------------------------------------------------------------------------
-- Fixtures
-- ----------------------------------------------------------------------------
INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('40000000-0000-4000-8000-000000000001', 'Evidence Test Country', 'EV', 'EVT', '9997', true);

INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('40000000-0000-4000-8000-000000000002', 'Evidence Test Location',
        '40000000-0000-4000-8000-000000000001', true);

INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('40000000-0000-4000-8000-000000000003', 'evidence-test-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('41000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000901',
     'Evidence Buyer', '40000000-0000-4000-8000-000000000001', true, 'active'),
    ('41000000-0000-4000-8000-000000000002', '41000000-0000-4000-8000-000000000902',
     'Evidence Seller', '40000000-0000-4000-8000-000000000001', true, 'active');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES
    ('42000000-0000-4000-8000-000000000001', 'Evidence Buyer Entity',
     'individual_pro', '41000000-0000-4000-8000-000000000001', true, 'verified'),
    ('42000000-0000-4000-8000-000000000002', 'Evidence Seller Entity',
     'farm', '41000000-0000-4000-8000-000000000002', true, 'verified');

INSERT INTO core.items (id, name)
VALUES ('43000000-0000-4000-8000-000000000001', 'Evidence Test Item');

INSERT INTO core.item_variants (id, item_id, name)
VALUES ('43000000-0000-4000-8000-000000000002',
        '43000000-0000-4000-8000-000000000001', 'Evidence Test Variant');

INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    '43000000-0000-4000-8000-000000000004',
    '42000000-0000-4000-8000-000000000002',
    '44000000-0000-4000-8000-000000000001',
    '43000000-0000-4000-8000-000000000002',
    '43000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    100.00, 0.00, '40000000-0000-4000-8000-000000000003', 'active'
);

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    '43000000-0000-4000-8000-000000000003',
    '42000000-0000-4000-8000-000000000002',
    'Evidence Test Listing',
    50.00,
    'KES',
    '40000000-0000-4000-8000-000000000002',
    '43000000-0000-4000-8000-000000000002',
    100.00,
    '40000000-0000-4000-8000-000000000003',
    'active',
    '43000000-0000-4000-8000-000000000004'
);

INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    '44000000-0000-4000-8000-000000000001',
    'farm',
    '41000000-0000-4000-8000-000000000002',
    'Evidence Test Supplier',
    'verified',
    true,
    '42000000-0000-4000-8000-000000000002',
    true
);

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, delivery_date, entity_id,
    order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
    status_changed_by_profile_id
) VALUES
    ('45000000-0000-4000-8000-000000000001',
     '41000000-0000-4000-8000-000000000001',
     '43000000-0000-4000-8000-000000000003',
     '44000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T10:00:00Z', '2026-11-19T10:00:00Z',
     '42000000-0000-4000-8000-000000000002', 'stock',
     '42000000-0000-4000-8000-000000000001',
     '42000000-0000-4000-8000-000000000002', 'KES',
     '40000000-0000-4000-8000-000000000003',
     '41000000-0000-4000-8000-000000000001'),
    ('45000000-0000-4000-8000-000000000002',
     '41000000-0000-4000-8000-000000000001',
     '43000000-0000-4000-8000-000000000003',
     '44000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T11:00:00Z', '2026-11-19T11:00:00Z',
     '42000000-0000-4000-8000-000000000002', 'stock',
     '42000000-0000-4000-8000-000000000001',
     '42000000-0000-4000-8000-000000000002', 'KES',
     '40000000-0000-4000-8000-000000000003',
     '41000000-0000-4000-8000-000000000001'),
    ('45000000-0000-4000-8000-000000000003',
     '41000000-0000-4000-8000-000000000001',
     '43000000-0000-4000-8000-000000000003',
     '44000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T12:00:00Z', '2026-11-19T12:00:00Z',
     '42000000-0000-4000-8000-000000000002', 'stock',
     '42000000-0000-4000-8000-000000000001',
     '42000000-0000-4000-8000-000000000002', 'KES',
     '40000000-0000-4000-8000-000000000003',
     '41000000-0000-4000-8000-000000000001'),
    ('45000000-0000-4000-8000-000000000005',
     '41000000-0000-4000-8000-000000000001',
     '43000000-0000-4000-8000-000000000003',
     '44000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T13:00:00Z', '2026-11-19T13:00:00Z',
     '42000000-0000-4000-8000-000000000002', 'stock',
     '42000000-0000-4000-8000-000000000001',
     '42000000-0000-4000-8000-000000000002', 'KES',
     '40000000-0000-4000-8000-000000000003',
     '41000000-0000-4000-8000-000000000001'),
    ('45000000-0000-4000-8000-000000000006',
     '41000000-0000-4000-8000-000000000001',
     '43000000-0000-4000-8000-000000000003',
     '44000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T14:00:00Z', '2026-11-19T14:00:00Z',
     '42000000-0000-4000-8000-000000000002', 'service',
     '42000000-0000-4000-8000-000000000001',
     '42000000-0000-4000-8000-000000000002', 'KES',
     '40000000-0000-4000-8000-000000000003',
     '41000000-0000-4000-8000-000000000001'),
    ('45000000-0000-4000-8000-000000000008',
     '41000000-0000-4000-8000-000000000001',
     '43000000-0000-4000-8000-000000000003',
     '44000000-0000-4000-8000-000000000001',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-19T09:00:00Z', '2026-11-19T15:00:00Z', '2026-11-19T15:00:00Z',
     '42000000-0000-4000-8000-000000000002', 'stock',
     '42000000-0000-4000-8000-000000000001',
     '42000000-0000-4000-8000-000000000002', 'KES',
     '40000000-0000-4000-8000-000000000003',
     '41000000-0000-4000-8000-000000000001');

INSERT INTO commerce.order_items (
    id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
    stock_id, variant_id, unit_id
) VALUES
    ('46000000-0000-4000-8000-000000000001',
     '45000000-0000-4000-8000-000000000001',
     '43000000-0000-4000-8000-000000000003',
     '43000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '43000000-0000-4000-8000-000000000004',
     '43000000-0000-4000-8000-000000000002',
     '40000000-0000-4000-8000-000000000003'),
    ('46000000-0000-4000-8000-000000000002',
     '45000000-0000-4000-8000-000000000002',
     '43000000-0000-4000-8000-000000000003',
     '43000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '43000000-0000-4000-8000-000000000004',
     '43000000-0000-4000-8000-000000000002',
     '40000000-0000-4000-8000-000000000003'),
    ('46000000-0000-4000-8000-000000000003',
     '45000000-0000-4000-8000-000000000003',
     '43000000-0000-4000-8000-000000000003',
     '43000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '43000000-0000-4000-8000-000000000004',
     '43000000-0000-4000-8000-000000000002',
     '40000000-0000-4000-8000-000000000003'),
    ('46000000-0000-4000-8000-000000000005',
     '45000000-0000-4000-8000-000000000005',
     '43000000-0000-4000-8000-000000000003',
     '43000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '43000000-0000-4000-8000-000000000004',
     '43000000-0000-4000-8000-000000000002',
     '40000000-0000-4000-8000-000000000003'),
    ('46000000-0000-4000-8000-000000000006',
     '45000000-0000-4000-8000-000000000006',
     '43000000-0000-4000-8000-000000000003',
     '43000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '43000000-0000-4000-8000-000000000004',
     '43000000-0000-4000-8000-000000000002',
     '40000000-0000-4000-8000-000000000003'),
    ('46000000-0000-4000-8000-000000000008',
     '45000000-0000-4000-8000-000000000008',
     '43000000-0000-4000-8000-000000000003',
     '43000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00,
     '43000000-0000-4000-8000-000000000004',
     '43000000-0000-4000-8000-000000000002',
     '40000000-0000-4000-8000-000000000003');

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
    ('47000000-0000-4000-8000-000000000001', 'vunio_order', 'vunio',
     '45000000-0000-4000-8000-000000000001',
     '45000000-0000-4000-8000-000000000001',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T10:00:00Z', 'KES', 100.00),
    ('47000000-0000-4000-8000-000000000002', 'vunio_order', 'vunio',
     '45000000-0000-4000-8000-000000000002',
     '45000000-0000-4000-8000-000000000002',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T11:00:00Z', 'KES', 100.00),
    ('47000000-0000-4000-8000-000000000003', 'vunio_order', 'vunio',
     '45000000-0000-4000-8000-000000000003',
     '45000000-0000-4000-8000-000000000003',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T12:00:00Z', 'KES', 100.00),
    ('47000000-0000-4000-8000-000000000004', 'external_transaction', 'test',
     'external-evidence-test', NULL,
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T12:30:00Z', NULL, NULL),
    ('47000000-0000-4000-8000-000000000005', 'vunio_order', 'vunio',
     '45000000-0000-4000-8000-000000000005',
     '45000000-0000-4000-8000-000000000005',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T13:00:00Z', 'KES', 100.00),
    ('47000000-0000-4000-8000-000000000006', 'vunio_order', 'vunio',
     '45000000-0000-4000-8000-000000000006',
     '45000000-0000-4000-8000-000000000006',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T14:00:00Z', 'KES', 100.00),
    ('47000000-0000-4000-8000-000000000008', 'vunio_order', 'vunio',
     '45000000-0000-4000-8000-000000000008',
     '45000000-0000-4000-8000-000000000008',
     '{"snapshot_version":1}', pg_temp.snapshot_hash('{"snapshot_version":1}'::jsonb),
     '2026-11-19T15:00:00Z', 'KES', 100.00);

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES
    ('47000000-0000-4000-8000-000000000001', 'reputation',
     'engagement_recorded', '2026-11-19T10:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('47000000-0000-4000-8000-000000000002', 'reputation',
     'engagement_recorded', '2026-11-19T11:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('47000000-0000-4000-8000-000000000003', 'reputation',
     'engagement_recorded', '2026-11-19T12:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('47000000-0000-4000-8000-000000000004', 'reputation',
     'engagement_recorded', '2026-11-19T12:30:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('47000000-0000-4000-8000-000000000005', 'reputation',
     'engagement_recorded', '2026-11-19T13:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('47000000-0000-4000-8000-000000000006', 'reputation',
     'engagement_recorded', '2026-11-19T14:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('47000000-0000-4000-8000-000000000008', 'reputation',
     'engagement_recorded', '2026-11-19T15:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}'),
    ('47000000-0000-4000-8000-000000000003', 'reputation',
     'engagement_voided', '2026-11-19T12:10:00Z', 'void-1',
     '{"invalidity_code":"evidence_test"}');

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key,
    source_namespace, source_event_reference, payload_hash, details
) VALUES
    ('47000000-0000-4000-8000-000000000001', 'source', 'order_delivered',
     '2026-11-19T10:00:00Z', 'vunio:delivered',
     'vunio', 'order:45000000-0000-4000-8000-000000000001:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T10:00:00Z', 'vunio',
         'order:45000000-0000-4000-8000-000000000001:delivered', NULL, '{}'::jsonb
     ), '{}'),
    ('47000000-0000-4000-8000-000000000002', 'source', 'order_delivered',
     '2026-11-19T11:00:00Z', 'vunio:delivered',
     'vunio', 'order:45000000-0000-4000-8000-000000000002:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T11:00:00Z', 'vunio',
         'order:45000000-0000-4000-8000-000000000002:delivered', NULL, '{}'::jsonb
     ), '{}'),
    ('47000000-0000-4000-8000-000000000003', 'source', 'order_delivered',
     '2026-11-19T12:00:00Z', 'vunio:delivered',
     'vunio', 'order:45000000-0000-4000-8000-000000000003:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T12:00:00Z', 'vunio',
         'order:45000000-0000-4000-8000-000000000003:delivered', NULL, '{}'::jsonb
     ), '{}'),
    ('47000000-0000-4000-8000-000000000005', 'source', 'order_delivered',
     '2026-11-19T13:00:00Z', 'vunio:delivered',
     'vunio', 'order:45000000-0000-4000-8000-000000000005:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T13:00:00Z', 'vunio',
         'order:45000000-0000-4000-8000-000000000005:delivered', NULL, '{}'::jsonb
     ), '{}'),
    ('47000000-0000-4000-8000-000000000006', 'source', 'order_delivered',
     '2026-11-19T14:00:00Z', 'vunio:delivered',
     'vunio', 'order:45000000-0000-4000-8000-000000000006:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T14:00:00Z', 'vunio',
         'order:45000000-0000-4000-8000-000000000006:delivered', NULL, '{}'::jsonb
     ), '{}'),
    ('47000000-0000-4000-8000-000000000008', 'source', 'order_delivered',
     '2026-11-19T15:00:00Z', 'vunio:delivered',
     'vunio', 'order:45000000-0000-4000-8000-000000000008:delivered',
     pg_temp.event_hash(
         'order_delivered', '2026-11-19T15:00:00Z', 'vunio',
         'order:45000000-0000-4000-8000-000000000008:delivered', NULL, '{}'::jsonb
     ), '{}');

CREATE TABLE pg_temp.evidence_ref (
    label text PRIMARY KEY,
    evidence_id uuid NOT NULL
);

CREATE TABLE pg_temp.conflict_ref (
    label text PRIMARY KEY,
    conflict_event_id uuid NOT NULL
);

SET CONSTRAINTS
    reputation.reputation_engagements_initial_events_complete,
    reputation.reputation_engagement_events_complete
    IMMEDIATE;

-- ----------------------------------------------------------------------------
-- Schema, immutability and security
-- ----------------------------------------------------------------------------
DO $schema$
DECLARE
    v_rls boolean;
    v_view_options text[];
BEGIN
    IF to_regclass('reputation.evidence') IS NULL
       OR to_regclass('reputation.evidence_events') IS NULL
       OR to_regclass('reputation.v_evidence_current_state') IS NULL THEN
        RAISE EXCEPTION 'Phase 2B evidence objects are missing';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname='reputation'
           AND c.relname IN ('evidence','evidence_events','v_evidence_current_state')
           AND pg_get_userbyid(c.relowner) <> 'postgres'
    ) THEN
        RAISE EXCEPTION 'Evidence object owner is not postgres';
    END IF;

    SELECT relrowsecurity INTO v_rls
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='reputation' AND c.relname='evidence';
    IF v_rls IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'evidence RLS is not enabled';
    END IF;

    SELECT relrowsecurity INTO v_rls
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='reputation' AND c.relname='evidence_events';
    IF v_rls IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'evidence_events RLS is not enabled';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_policies
         WHERE schemaname='reputation'
           AND tablename IN ('evidence','evidence_events')
    ) THEN
        RAISE EXCEPTION 'unexpected evidence policies exist';
    END IF;

    SELECT reloptions INTO v_view_options
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='reputation' AND c.relname='v_evidence_current_state';
    IF NOT (COALESCE(v_view_options, ARRAY[]::text[]) @> ARRAY['security_invoker=true']) THEN
        RAISE EXCEPTION 'evidence view is not security_invoker';
    END IF;

    IF (SELECT count(*) FROM pg_tables WHERE schemaname='reputation') <> 7 THEN
        RAISE EXCEPTION 'unexpected reputation table count';
    END IF;

    IF to_regclass('reputation.evidence') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
            WHERE table_schema='reputation'
              AND table_name='evidence'
              AND column_name IN ('payment_status','payment_mode','mpesa_reference')
       ) THEN
        RAISE EXCEPTION 'evidence table contains excluded payment columns';
    END IF;

    IF has_table_privilege('anon','reputation.evidence','SELECT')
       OR has_table_privilege('authenticated','reputation.evidence','SELECT')
       OR has_table_privilege('service_role','reputation.evidence','SELECT')
       OR has_table_privilege('anon','reputation.evidence_events','SELECT')
       OR has_table_privilege('authenticated','reputation.evidence_events','SELECT')
       OR has_table_privilege('service_role','reputation.evidence_events','SELECT') THEN
        RAISE EXCEPTION 'browser or service_role has direct evidence table access';
    END IF;

    IF has_table_privilege('anon','reputation.v_evidence_current_state','SELECT')
       OR has_table_privilege('authenticated','reputation.v_evidence_current_state','SELECT')
       OR has_table_privilege('service_role','reputation.v_evidence_current_state','SELECT') THEN
        RAISE EXCEPTION 'unexpected evidence view access';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='reputation'
           AND p.proname='capture_order_delivery_evidence'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = true
           AND p.proconfig @> ARRAY['search_path=pg_catalog, reputation, commerce, core, users']
    ) THEN
        RAISE EXCEPTION 'capture_order_delivery_evidence security properties are wrong';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='system'
           AND p.proname='capture_reputation_order_evidence'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = true
           AND p.proconfig @> ARRAY['search_path=pg_catalog, system, reputation']
    ) THEN
        RAISE EXCEPTION 'system capture gateway security properties are wrong';
    END IF;

    IF has_function_privilege(
           'service_role',
           'reputation.capture_order_delivery_evidence(uuid,text,text,uuid,jsonb)',
           'EXECUTE')
       OR has_function_privilege(
           'authenticated',
           'reputation.capture_order_delivery_evidence(uuid,text,text,uuid,jsonb)',
           'EXECUTE') THEN
        RAISE EXCEPTION 'internal evidence capture is directly executable';
    END IF;

    IF NOT has_function_privilege(
           'service_role',
           'system.capture_reputation_order_evidence(uuid,uuid,text)',
           'EXECUTE')
       OR has_function_privilege(
           'authenticated',
           'system.capture_reputation_order_evidence(uuid,uuid,text)',
           'EXECUTE')
       OR has_function_privilege(
           'anon',
           'system.capture_reputation_order_evidence(uuid,uuid,text)',
           'EXECUTE') THEN
        RAISE EXCEPTION 'system evidence gateway grants are wrong';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger t
          JOIN pg_class c ON c.oid=t.tgrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='reputation' AND c.relname='evidence'
           AND t.tgname='reputation_evidence_append_only'
           AND pg_get_triggerdef(t.oid) LIKE '%BEFORE DELETE OR UPDATE%'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger t
          JOIN pg_class c ON c.oid=t.tgrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='reputation' AND c.relname='evidence'
           AND t.tgname='reputation_evidence_no_truncate'
           AND pg_get_triggerdef(t.oid) LIKE '%BEFORE TRUNCATE%'
           AND pg_get_triggerdef(t.oid) LIKE '%FOR EACH STATEMENT%'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger t
          JOIN pg_class c ON c.oid=t.tgrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='reputation' AND c.relname='evidence_events'
           AND t.tgname='reputation_evidence_events_append_only'
           AND pg_get_triggerdef(t.oid) LIKE '%BEFORE DELETE OR UPDATE%'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger t
          JOIN pg_class c ON c.oid=t.tgrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='reputation' AND c.relname='evidence_events'
           AND t.tgname='reputation_evidence_events_no_truncate'
           AND pg_get_triggerdef(t.oid) LIKE '%BEFORE TRUNCATE%'
           AND pg_get_triggerdef(t.oid) LIKE '%FOR EACH STATEMENT%'
    ) THEN
        RAISE EXCEPTION 'append-only or truncate protection is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
          JOIN pg_namespace n ON n.oid=t.relnamespace
         WHERE n.nspname='reputation' AND t.relname='evidence'
           AND c.conname='reputation_evidence_snapshot_hash_check'
    ) THEN
        RAISE EXCEPTION 'snapshot hash constraint is missing';
    END IF;

    IF to_regclass('reputation.verification_decisions') IS NOT NULL
       OR to_regclass('reputation.review_eligibilities') IS NOT NULL
       OR to_regclass('reputation.reviews') IS NOT NULL THEN
        RAISE EXCEPTION 'out-of-scope Phase 2B objects exist';
    END IF;
END;
$schema$;

-- ----------------------------------------------------------------------------
-- Delivery capture, canonical snapshot and provenance
-- ----------------------------------------------------------------------------
DO $capture$
DECLARE
    v_result record;
    v_before integer;
    v_after integer;
    v_snapshot jsonb;
    v_hash bytea;
    v_expected bytea;
BEGIN
    SELECT count(*) INTO v_before
      FROM reputation.engagement_events
     WHERE engagement_id='47000000-0000-4000-8000-000000000001';

    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000001', NULL, 'req-evidence-1'
      );

    IF v_result.outcome <> 'recorded' OR v_result.evidence_status <> 'active' THEN
        RAISE EXCEPTION 'delivery capture outcome mismatch: %/%',
            v_result.outcome, v_result.evidence_status;
    END IF;

    INSERT INTO pg_temp.evidence_ref(label, evidence_id)
    VALUES ('e1', v_result.evidence_id);

    SELECT source_snapshot, source_snapshot_hash
      INTO v_snapshot, v_hash
      FROM reputation.evidence
     WHERE id = v_result.evidence_id;

    v_expected := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));
    IF v_hash IS DISTINCT FROM v_expected OR octet_length(v_hash) <> 32 THEN
        RAISE EXCEPTION 'evidence snapshot hash mismatch';
    END IF;

    IF v_snapshot->>'snapshot_schema_version' <> '1'
       OR v_snapshot->>'source_version' <> 'delivery:v1'
       OR v_snapshot->>'evidence_type' <> 'commerce_order_delivery'
       OR v_snapshot#>>'{source,source_system}' <> 'commerce'
       OR v_snapshot#>>'{source,source_reference}' <> '45000000-0000-4000-8000-000000000001'
       OR v_snapshot#>>'{delivery,status}' <> 'delivered'
       OR v_snapshot#>>'{delivery,delivered_at}' <> '2026-11-19T10:00:00.000000Z'
       OR v_snapshot#>>'{delivery,delivery_confirmed_by_profile_id}'
          <> '41000000-0000-4000-8000-000000000001'
       OR v_snapshot#>>'{order,id}' <> '45000000-0000-4000-8000-000000000001'
       OR v_snapshot#>>'{order,buyer_entity_id}' <> '42000000-0000-4000-8000-000000000001'
       OR v_snapshot#>>'{order,seller_entity_id}' <> '42000000-0000-4000-8000-000000000002'
       OR v_snapshot#>>'{order,currency}' <> 'KES'
       OR v_snapshot#>>'{order,quantity}' <> '2.00'
       OR v_snapshot#>>'{order,total_amount}' <> '100.00'
       OR jsonb_array_length(v_snapshot->'items') <> 1 THEN
        RAISE EXCEPTION 'delivery snapshot content mismatch: %', v_snapshot;
    END IF;

    IF v_snapshot::text LIKE '%payment_status%'
       OR v_snapshot::text LIKE '%payment_mode%'
       OR v_snapshot::text LIKE '%mpesa%'
       OR v_snapshot::text LIKE '%status_reason%'
       OR v_snapshot::text LIKE '%idempotency_key%'
       OR v_snapshot::text LIKE '%updated_at%'
       OR v_snapshot::text LIKE '%contact%' THEN
        RAISE EXCEPTION 'delivery snapshot contains excluded fields';
    END IF;

    IF (SELECT count(*) FROM reputation.evidence_events
         WHERE evidence_id=v_result.evidence_id
           AND event_type='evidence_recorded') <> 1 THEN
        RAISE EXCEPTION 'initial evidence event missing';
    END IF;

    IF (SELECT count(*) FROM reputation.evidence_events
         WHERE evidence_id=v_result.evidence_id
           AND event_type='evidence_conflict_detected') <> 0 THEN
        RAISE EXCEPTION 'unexpected initial conflict event';
    END IF;

    SELECT count(*) INTO v_after
      FROM reputation.engagement_events
     WHERE engagement_id='47000000-0000-4000-8000-000000000001';
    IF v_before <> v_after THEN
        RAISE EXCEPTION 'evidence capture inserted Phase 2A engagement events';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.evidence e
         WHERE e.id=v_result.evidence_id
           AND e.source_system='commerce'
           AND e.source_reference='45000000-0000-4000-8000-000000000001'
           AND e.source_version='delivery:v1'
           AND e.snapshot_version=1
           AND e.capture_method='trusted_service'
           AND e.capture_process='system.capture_reputation_order_evidence'
           AND e.source_occurred_at='2026-11-19T10:00:00Z'
           AND e.provenance->>'gateway'='system.capture_reputation_order_evidence'
           AND e.provenance->>'request_id'='req-evidence-1'
    ) THEN
        RAISE EXCEPTION 'evidence provenance is incomplete';
    END IF;
END;
$capture$;

DO $immutability$
BEGIN
    BEGIN
        UPDATE reputation.evidence SET provenance = provenance
         WHERE engagement_id='47000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'evidence UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM reputation.evidence
         WHERE engagement_id='47000000-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'evidence DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE reputation.evidence_events SET details = details
         WHERE evidence_id IN (
             SELECT evidence_id FROM reputation.evidence
              WHERE engagement_id='47000000-0000-4000-8000-000000000001'
         );
        RAISE EXCEPTION 'evidence event UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM reputation.evidence_events
         WHERE evidence_id IN (
             SELECT evidence_id FROM reputation.evidence
              WHERE engagement_id='47000000-0000-4000-8000-000000000001'
         );
        RAISE EXCEPTION 'evidence event DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    SET CONSTRAINTS
        reputation.reputation_evidence_initial_event_complete,
        reputation.reputation_evidence_events_complete
        IMMEDIATE;

    BEGIN
        TRUNCATE reputation.evidence_events;
        RAISE EXCEPTION 'evidence_events TRUNCATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        TRUNCATE reputation.evidence CASCADE;
        RAISE EXCEPTION 'evidence TRUNCATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    SET CONSTRAINTS
        reputation.reputation_evidence_initial_event_complete,
        reputation.reputation_evidence_events_complete
        DEFERRED;
END;
$immutability$;

-- ----------------------------------------------------------------------------
-- Idempotency, excluded mutable fields and deterministic hashing
-- ----------------------------------------------------------------------------
DO $idempotency$
DECLARE
    v_evidence_id uuid;
    v_hash_before bytea;
    v_hash_after bytea;
    v_result record;
    v_count integer;
BEGIN
    SELECT evidence_id INTO v_evidence_id
      FROM pg_temp.evidence_ref WHERE label='e1';
    SELECT source_snapshot_hash INTO v_hash_before
      FROM reputation.evidence WHERE id=v_evidence_id;

    UPDATE commerce.orders
       SET payment_status='completed',
           status_reason='excluded field change',
           delivery_date=delivered_at + interval '1 minute',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000001';

    FOR v_count IN 1..3 LOOP
        SELECT * INTO v_result
          FROM system.capture_reputation_order_evidence(
              '47000000-0000-4000-8000-000000000001'
          );
        IF v_result.outcome <> 'already_recorded'
           OR v_result.evidence_id <> v_evidence_id THEN
            RAISE EXCEPTION 'worker retry was not idempotent: %/%',
                v_result.outcome, v_result.evidence_id;
        END IF;
    END LOOP;

    SELECT source_snapshot_hash INTO v_hash_after
      FROM reputation.evidence WHERE id=v_evidence_id;
    IF v_hash_after IS DISTINCT FROM v_hash_before THEN
        RAISE EXCEPTION 'excluded mutable fields changed the evidence hash';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='47000000-0000-4000-8000-000000000001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'idempotent retries duplicated evidence';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id AND event_type='evidence_recorded';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'idempotent retries duplicated initial events';
    END IF;
END;
$idempotency$;

-- ----------------------------------------------------------------------------
-- Capture validation
-- ----------------------------------------------------------------------------
DO $validation$
DECLARE
    v_snapshot jsonb;
    v_hash bytea;
BEGIN
    BEGIN
        UPDATE commerce.orders SET status='shipped', updated_at=now()
         WHERE id='45000000-0000-4000-8000-000000000001';
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000001'
        );
        RAISE EXCEPTION 'non-delivered order evidence unexpectedly succeeded';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    UPDATE commerce.orders SET status='delivered', updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000001';

    BEGIN
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000003'
        );
        RAISE EXCEPTION 'voided engagement evidence unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000004'
        );
        RAISE EXCEPTION 'external engagement evidence unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000006'
        );
        RAISE EXCEPTION 'service order evidence unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    UPDATE commerce.orders SET buyer_entity_id=NULL, updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';
    BEGIN
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000002'
        );
        RAISE EXCEPTION 'missing buyer entity evidence unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE commerce.orders SET buyer_entity_id='42000000-0000-4000-8000-000000000001',
                              updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    UPDATE commerce.orders SET seller_entity_id=NULL, updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';
    BEGIN
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000002'
        );
        RAISE EXCEPTION 'missing seller entity evidence unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE commerce.orders SET seller_entity_id='42000000-0000-4000-8000-000000000002',
                              updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    UPDATE users.profiles SET is_active=false
     WHERE id='41000000-0000-4000-8000-000000000001';
    BEGIN
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000001',
            '41000000-0000-4000-8000-000000000001'
        );
        RAISE EXCEPTION 'inactive actor capture unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    UPDATE users.profiles SET is_active=true
     WHERE id='41000000-0000-4000-8000-000000000001';

    UPDATE users.profiles SET deleted_at=now()
     WHERE id='41000000-0000-4000-8000-000000000001';
    BEGIN
        PERFORM system.capture_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000001',
            '41000000-0000-4000-8000-000000000001'
        );
        RAISE EXCEPTION 'deleted actor capture unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    UPDATE users.profiles SET deleted_at=NULL
     WHERE id='41000000-0000-4000-8000-000000000001';

    -- Direct insert with a valid hash but mismatched snapshot source identity.
    v_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1,
        'source_version', 'delivery:v99',
        'evidence_type', 'commerce_order_delivery',
        'source', jsonb_build_object(
            'source_system', 'commerce',
            'source_reference', 'mismatched-reference'
        ),
        'delivery', jsonb_build_object(
            'status', 'delivered',
            'delivered_at', '2026-11-19T15:00:00.000000Z',
            'delivery_confirmed_by_profile_id', NULL
        ),
        'order', '{}'::jsonb,
        'items', '[]'::jsonb
    );
    v_hash := pg_temp.snapshot_hash(v_snapshot);

    BEGIN
        INSERT INTO reputation.evidence (
            engagement_id, evidence_type, source_system, source_reference,
            source_version, source_occurred_at, snapshot_version,
            source_snapshot, source_snapshot_hash, capture_method,
            capture_process, provenance
        ) VALUES (
            '47000000-0000-4000-8000-000000000008',
            'commerce_order_delivery', 'commerce',
            '45000000-0000-4000-8000-000000000008', 'delivery:v99',
            '2026-11-19T15:00:00Z', 1, v_snapshot, v_hash,
            'trusted_service', 'test:snapshot-identity', '{}'::jsonb
        );
        RAISE EXCEPTION 'snapshot identity mismatch unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Direct insertion of a second active version must be rejected.
    v_snapshot := reputation.canonical_order_delivery_snapshot(
        '45000000-0000-4000-8000-000000000001'
    );
    v_snapshot := jsonb_set(v_snapshot, '{source_version}', '"delivery:v2"');
    v_snapshot := jsonb_set(v_snapshot, '{source,source_version}', '"delivery:v2"');
    v_hash := pg_temp.snapshot_hash(v_snapshot);

    BEGIN
        INSERT INTO reputation.evidence (
            engagement_id, evidence_type, source_system, source_reference,
            source_version, source_occurred_at, snapshot_version,
            source_snapshot, source_snapshot_hash, capture_method,
            capture_process, provenance
        ) VALUES (
            '47000000-0000-4000-8000-000000000001',
            'commerce_order_delivery', 'commerce',
            '45000000-0000-4000-8000-000000000001', 'delivery:v2',
            '2026-11-19T10:00:00Z', 1, v_snapshot, v_hash,
            'trusted_service', 'test:second-active-version', '{}'::jsonb
        );
        RAISE EXCEPTION 'second active evidence version unexpectedly succeeded';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    IF EXISTS (
        SELECT 1 FROM reputation.evidence
         WHERE engagement_id IN (
             '47000000-0000-4000-8000-000000000003',
             '47000000-0000-4000-8000-000000000004',
             '47000000-0000-4000-8000-000000000006'
         )
    ) THEN
        RAISE EXCEPTION 'invalid capture created evidence';
    END IF;
END;
$validation$;

-- ----------------------------------------------------------------------------
-- Conflict detection, original preservation, independent resolution
-- ----------------------------------------------------------------------------
DO $conflict$
DECLARE
    v_evidence_id uuid;
    v_hash_before bytea;
    v_snapshot_before jsonb;
    v_hash_after bytea;
    v_snapshot_after jsonb;
    v_result record;
    v_conflict_1 uuid;
    v_conflict_2 uuid;
    v_event_id uuid;
    v_count integer;
BEGIN
    SELECT evidence_id INTO v_evidence_id
      FROM pg_temp.evidence_ref WHERE label='e1';
    SELECT source_snapshot_hash, source_snapshot
      INTO v_hash_before, v_snapshot_before
      FROM reputation.evidence WHERE id=v_evidence_id;

    UPDATE commerce.orders
       SET delivered_at='2026-11-19T10:05:00Z',
           delivery_date='2026-11-19T10:05:00Z',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000001';

    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000001'
      );
    IF v_result.outcome <> 'conflict_recorded'
       OR v_result.evidence_id <> v_evidence_id
       OR v_result.evidence_status <> 'conflicted'
       OR v_result.conflict_event_id IS NULL THEN
        RAISE EXCEPTION 'first conflict outcome mismatch: %/%/%',
            v_result.outcome, v_result.evidence_status, v_result.conflict_event_id;
    END IF;
    v_conflict_1 := v_result.conflict_event_id;
    INSERT INTO pg_temp.conflict_ref(label, conflict_event_id)
    VALUES ('c1', v_conflict_1);

    SELECT source_snapshot_hash, source_snapshot
      INTO v_hash_after, v_snapshot_after
      FROM reputation.evidence WHERE id=v_evidence_id;
    IF v_hash_after IS DISTINCT FROM v_hash_before
       OR v_snapshot_after IS DISTINCT FROM v_snapshot_before THEN
        RAISE EXCEPTION 'conflict rewrote original evidence';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.evidence_events ee
         WHERE ee.id=v_conflict_1
           AND ee.evidence_id=v_evidence_id
           AND ee.event_type='evidence_conflict_detected'
           AND ee.details->>'attempted_source_system'='commerce'
           AND ee.details->>'attempted_source_reference'='45000000-0000-4000-8000-000000000001'
           AND ee.details->>'attempted_source_version'='delivery:v1'
           AND ee.details->>'reason_code'='source_snapshot_mismatch'
           AND ee.details->>'attempted_delivered_at'='2026-11-19T10:05:00.000000Z'
           AND ee.details->>'attempted_source_snapshot_hash' ~ '^[0-9a-f]{64}$'
           AND jsonb_typeof(ee.details->'attempted_source_snapshot')='object'
    ) THEN
        RAISE EXCEPTION 'conflict audit details were not preserved';
    END IF;

    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000001'
      );
    IF v_result.outcome <> 'conflict_recorded'
       OR v_result.conflict_event_id <> v_conflict_1 THEN
        RAISE EXCEPTION 'conflict retry was not idempotent';
    END IF;
    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id AND event_type='evidence_conflict_detected';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'conflict retry duplicated conflict events';
    END IF;

    UPDATE commerce.orders
       SET delivered_at='2026-11-19T10:06:00Z',
           delivery_date='2026-11-19T10:06:00Z',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000001';

    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000001'
      );
    IF v_result.outcome <> 'conflict_recorded'
       OR v_result.conflict_event_id = v_conflict_1 THEN
        RAISE EXCEPTION 'second conflict was not independently recorded';
    END IF;
    v_conflict_2 := v_result.conflict_event_id;
    INSERT INTO pg_temp.conflict_ref(label, conflict_event_id)
    VALUES ('c2', v_conflict_2);

    BEGIN
        PERFORM system.resolve_reputation_evidence_conflict(
            gen_random_uuid(), 'false_positive', 'nonexistent conflict'
        );
        RAISE EXCEPTION 'nonexistent conflict resolution unexpectedly succeeded';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;

    SELECT id INTO v_event_id
      FROM reputation.evidence_events
     WHERE evidence_id = v_evidence_id
       AND event_type = 'evidence_recorded';
    BEGIN
        PERFORM system.resolve_reputation_evidence_conflict(
            v_event_id, 'false_positive', 'not a conflict event'
        );
        RAISE EXCEPTION 'non-conflict event resolution unexpectedly succeeded';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;

    BEGIN
        PERFORM system.resolve_reputation_evidence_conflict(
            v_conflict_1, repeat('x', 101), 'resolution code too long'
        );
        RAISE EXCEPTION 'oversized resolution code unexpectedly succeeded';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    SELECT * INTO v_result
      FROM system.resolve_reputation_evidence_conflict(
          v_conflict_1, 'false_positive', 'attempt was not authoritative'
      );
    IF v_result.outcome <> 'resolved'
       OR v_result.evidence_status <> 'conflicted' THEN
        RAISE EXCEPTION 'resolving one of two conflicts changed status incorrectly: %/%',
            v_result.outcome, v_result.evidence_status;
    END IF;

    SELECT * INTO v_result
      FROM system.resolve_reputation_evidence_conflict(
          v_conflict_1, 'false_positive', 'duplicate resolution'
      );
    IF v_result.outcome <> 'already_resolved'
       OR v_result.evidence_status <> 'conflicted' THEN
        RAISE EXCEPTION 'duplicate conflict resolution was not idempotent';
    END IF;

    SELECT * INTO v_result
      FROM system.resolve_reputation_evidence_conflict(
          v_conflict_2, 'false_positive', 'second attempt invalid'
      );
    IF v_result.outcome <> 'resolved'
       OR v_result.evidence_status <> 'active' THEN
        RAISE EXCEPTION 'second independent resolution failed: %/%',
            v_result.outcome, v_result.evidence_status;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id
       AND event_type='evidence_conflict_resolved';
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'conflict resolutions were not independently preserved';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.evidence_events ee
         WHERE ee.evidence_id=v_evidence_id
           AND ee.event_type='evidence_conflict_resolved'
           AND ee.details->>'resolved_conflict_event_id'=v_conflict_1::text
    ) OR NOT EXISTS (
        SELECT 1 FROM reputation.evidence_events ee
         WHERE ee.evidence_id=v_evidence_id
           AND ee.event_type='evidence_conflict_resolved'
           AND ee.details->>'resolved_conflict_event_id'=v_conflict_2::text
    ) THEN
        RAISE EXCEPTION 'resolution events did not reference exact conflict events';
    END IF;
END;
$conflict$;

-- ----------------------------------------------------------------------------
-- Revocation terminality
-- ----------------------------------------------------------------------------
DO $revocation$
DECLARE
    v_result record;
    v_evidence_id uuid;
    v_status text;
    v_count integer;
BEGIN
    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000005'
      );
    IF v_result.outcome <> 'recorded' THEN
        RAISE EXCEPTION 'revocation fixture capture failed';
    END IF;
    v_evidence_id := v_result.evidence_id;
    INSERT INTO pg_temp.evidence_ref(label, evidence_id)
    VALUES ('e5', v_evidence_id);

    BEGIN
        PERFORM system.revoke_reputation_evidence(
            v_evidence_id, repeat('x', 101), 'reason code too long'
        );
        RAISE EXCEPTION 'oversized reason code unexpectedly succeeded';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    SELECT * INTO v_result
      FROM system.revoke_reputation_evidence(
          v_evidence_id, 'source_invalidated', 'test revocation'
      );
    IF v_result.outcome <> 'revoked' OR v_result.evidence_status <> 'revoked' THEN
        RAISE EXCEPTION 'revocation outcome mismatch';
    END IF;

    SELECT * INTO v_result
      FROM system.revoke_reputation_evidence(
          v_evidence_id, 'source_invalidated', 'test revocation repeat'
      );
    IF v_result.outcome <> 'already_revoked'
       OR v_result.evidence_status <> 'revoked' THEN
        RAISE EXCEPTION 'revocation was not idempotent';
    END IF;

    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000005'
      );
    IF v_result.outcome <> 'already_recorded'
       OR v_result.evidence_id <> v_evidence_id
       OR v_result.evidence_status <> 'revoked' THEN
        RAISE EXCEPTION 'capture resurrected revoked evidence';
    END IF;

    UPDATE commerce.orders
       SET delivered_at='2026-11-19T13:05:00Z',
           delivery_date='2026-11-19T13:05:00Z',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000005';

    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000005'
      );
    IF v_result.outcome <> 'conflict_recorded'
       OR v_result.evidence_status <> 'revoked'
       OR v_result.conflict_event_id IS NULL THEN
        RAISE EXCEPTION 'conflict after revocation did not remain audit-only';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id AND event_type='evidence_revoked';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'revocation events were not exactly once';
    END IF;

    BEGIN
        PERFORM system.supersede_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000005',
            v_evidence_id,
            'delivery:v2'
        );
        RAISE EXCEPTION 'revoked evidence was superseded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$revocation$;

-- ----------------------------------------------------------------------------
-- Atomic supersession and worker idempotency
-- ----------------------------------------------------------------------------
DO $supersession$
DECLARE
    v_result record;
    v_old_id uuid;
    v_new_id uuid;
    v_v3_id uuid;
    v_v10_id uuid;
    v_old_snapshot jsonb;
    v_old_hash bytea;
    v_old_snapshot_after jsonb;
    v_old_hash_after bytea;
    v_count integer;
BEGIN
    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000002'
      );
    IF v_result.outcome <> 'recorded' THEN
        RAISE EXCEPTION 'supersession fixture capture failed';
    END IF;
    v_old_id := v_result.evidence_id;
    INSERT INTO pg_temp.evidence_ref(label, evidence_id)
    VALUES ('e2v1', v_old_id);

    -- Correction must reject service orders.
    UPDATE commerce.orders SET order_kind='service', updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';
    BEGIN
        PERFORM system.supersede_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000002',
            v_old_id,
            'delivery:v2'
        );
        RAISE EXCEPTION 'service order correction unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE commerce.orders SET order_kind='stock', updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    -- Correction must reject incomplete participant information.
    UPDATE commerce.orders SET seller_entity_id=NULL, updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';
    BEGIN
        PERFORM system.supersede_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000002',
            v_old_id,
            'delivery:v2'
        );
        RAISE EXCEPTION 'incomplete participant correction unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE commerce.orders
       SET seller_entity_id='42000000-0000-4000-8000-000000000002',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    SELECT source_snapshot, source_snapshot_hash
      INTO v_old_snapshot, v_old_hash
      FROM reputation.evidence WHERE id=v_old_id;

    UPDATE commerce.orders
       SET delivered_at='2026-11-19T11:05:00Z',
           delivery_date='2026-11-19T11:05:00Z',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    SELECT * INTO v_result
      FROM system.supersede_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000002',
          v_old_id,
          'delivery:v2',
          NULL,
          'req-supersede-1'
      );
    IF v_result.outcome <> 'superseded'
       OR v_result.superseded_evidence_id <> v_old_id
       OR v_result.evidence_id IS NULL THEN
        RAISE EXCEPTION 'supersession outcome mismatch';
    END IF;
    v_new_id := v_result.evidence_id;
    INSERT INTO pg_temp.evidence_ref(label, evidence_id)
    VALUES ('e2v2', v_new_id);

    SELECT source_snapshot, source_snapshot_hash
      INTO v_old_snapshot_after, v_old_hash_after
      FROM reputation.evidence WHERE id=v_old_id;
    IF v_old_snapshot_after IS DISTINCT FROM v_old_snapshot
       OR v_old_hash_after IS DISTINCT FROM v_old_hash THEN
        RAISE EXCEPTION 'supersession rewrote original evidence';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.evidence e
         WHERE e.id=v_new_id
           AND e.supersedes_evidence_id=v_old_id
           AND e.source_version='delivery:v2'
           AND e.provenance->>'gateway'='system.supersede_reputation_order_evidence'
    ) THEN
        RAISE EXCEPTION 'replacement evidence provenance mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.v_evidence_current_state v
         WHERE v.evidence_id=v_old_id AND v.evidence_status='superseded'
    ) OR NOT EXISTS (
        SELECT 1 FROM reputation.v_evidence_current_state v
         WHERE v.evidence_id=v_new_id AND v.evidence_status='active'
    ) THEN
        RAISE EXCEPTION 'supersession status mismatch';
    END IF;

    SELECT * INTO v_result
      FROM system.supersede_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000002',
          v_old_id,
          'delivery:v2',
          NULL,
          'req-supersede-1'
      );
    IF v_result.outcome <> 'already_recorded'
       OR v_result.evidence_id <> v_new_id
       OR v_result.superseded_evidence_id <> v_old_id THEN
        RAISE EXCEPTION 'supersession retry was not idempotent';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='47000000-0000-4000-8000-000000000002';
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'supersession retry duplicated evidence';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_old_id AND event_type='evidence_superseded';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'supersession retry duplicated supersession events';
    END IF;

    -- A same-version correction retry with changed delivery facts must not
    -- silently return already_recorded.
    UPDATE commerce.orders
       SET delivered_at='2026-11-19T11:06:00Z',
           delivery_date='2026-11-19T11:06:00Z',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    SELECT * INTO v_result
      FROM system.supersede_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000002',
          v_old_id,
          'delivery:v2',
          NULL,
          'req-supersede-1'
      );
    IF v_result.outcome <> 'conflict_recorded'
       OR v_result.evidence_id <> v_new_id
       OR v_result.superseded_evidence_id <> v_old_id THEN
        RAISE EXCEPTION 'same-version correction divergence was not audited';
    END IF;

    SELECT * INTO v_result
      FROM system.supersede_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000002',
          v_old_id,
          'delivery:v2',
          NULL,
          'req-supersede-1'
      );
    IF v_result.outcome <> 'conflict_recorded'
       OR v_result.evidence_id <> v_new_id THEN
        RAISE EXCEPTION 'same-version correction conflict retry was not idempotent';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_new_id AND event_type='evidence_conflict_detected';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'correction divergence conflict was duplicated';
    END IF;

    -- Accepted chain: v1 -> v2 -> v3 -> v10.
    UPDATE commerce.orders
       SET delivered_at='2026-11-19T11:07:00Z',
           delivery_date='2026-11-19T11:07:00Z',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    SELECT * INTO v_result
      FROM system.supersede_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000002',
          v_new_id,
          'delivery:v3'
      );
    IF v_result.outcome <> 'superseded'
       OR v_result.superseded_evidence_id <> v_new_id THEN
        RAISE EXCEPTION 'v2 -> v3 supersession failed';
    END IF;
    v_v3_id := v_result.evidence_id;
    INSERT INTO pg_temp.evidence_ref(label, evidence_id)
    VALUES ('e2v3', v_v3_id);

    UPDATE commerce.orders
       SET delivered_at='2026-11-19T11:08:00Z',
           delivery_date='2026-11-19T11:08:00Z',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    SELECT * INTO v_result
      FROM system.supersede_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000002',
          v_v3_id,
          'delivery:v10'
      );
    IF v_result.outcome <> 'superseded'
       OR v_result.superseded_evidence_id <> v_v3_id THEN
        RAISE EXCEPTION 'v3 -> v10 supersession failed';
    END IF;
    v_v10_id := v_result.evidence_id;
    INSERT INTO pg_temp.evidence_ref(label, evidence_id)
    VALUES ('e2v10', v_v10_id);

    -- Lower version v10 -> v2 must be rejected by monotonic validation.
    BEGIN
        PERFORM system.supersede_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000002',
            v_v10_id,
            'delivery:v2'
        );
        RAISE EXCEPTION 'lower-version supersession unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- An already superseded predecessor cannot be superseded again.
    BEGIN
        PERFORM system.supersede_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000002',
            v_old_id,
            'delivery:v11'
        );
        RAISE EXCEPTION 'already superseded evidence was superseded again';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$supersession$;

-- ----------------------------------------------------------------------------
-- Atomic rollback on forced supersession failure
-- ----------------------------------------------------------------------------
DO $atomic_rollback$
DECLARE
    v_result record;
    v_old_id uuid;
    v_count integer;
BEGIN
    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000008'
      );
    IF v_result.outcome <> 'recorded' THEN
        RAISE EXCEPTION 'atomic rollback fixture capture failed';
    END IF;
    v_old_id := v_result.evidence_id;
    INSERT INTO pg_temp.evidence_ref(label, evidence_id)
    VALUES ('e8v1', v_old_id);

    CREATE TABLE pg_temp.fail_old (evidence_id uuid PRIMARY KEY);
    INSERT INTO pg_temp.fail_old VALUES (v_old_id);

    EXECUTE $sql$
        CREATE FUNCTION pg_temp.fail_supersede_event()
        RETURNS trigger
        LANGUAGE plpgsql
        SET search_path TO 'pg_catalog', 'pg_temp'
        AS $body$
        BEGIN
            IF NEW.event_type = 'evidence_superseded'
               AND EXISTS (
                   SELECT 1
                     FROM pg_temp.fail_old AS f
                    WHERE f.evidence_id = NEW.evidence_id
               ) THEN
                RAISE EXCEPTION 'forced supersession failure'
                    USING ERRCODE = 'P0001';
            END IF;
            RETURN NEW;
        END;
        $body$;

        CREATE TRIGGER test_fail_supersede
            BEFORE INSERT ON reputation.evidence_events
            FOR EACH ROW
            EXECUTE FUNCTION pg_temp.fail_supersede_event();
    $sql$;

    BEGIN
        PERFORM system.supersede_reputation_order_evidence(
            '47000000-0000-4000-8000-000000000008',
            v_old_id,
            'delivery:v2'
        );
        RAISE EXCEPTION 'forced supersession failure did not occur';
    EXCEPTION WHEN raise_exception THEN NULL;
    END;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE engagement_id='47000000-0000-4000-8000-000000000008';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'failed supersession left partial evidence';
    END IF;

    IF EXISTS (
        SELECT 1 FROM reputation.evidence_events
         WHERE evidence_id=v_old_id AND event_type='evidence_superseded'
    ) THEN
        RAISE EXCEPTION 'failed supersession left a supersession event';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.v_evidence_current_state
         WHERE evidence_id=v_old_id AND evidence_status='active'
    ) THEN
        RAISE EXCEPTION 'failed supersession changed original status';
    END IF;

    DROP TRIGGER test_fail_supersede ON reputation.evidence_events;
    DROP FUNCTION pg_temp.fail_supersede_event();
    DROP TABLE pg_temp.fail_old;
END;
$atomic_rollback$;

-- ----------------------------------------------------------------------------
-- Actual service_role gateway execution and direct-access denial
-- ----------------------------------------------------------------------------
SET LOCAL ROLE service_role;

DO $service_role$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result
      FROM system.capture_reputation_order_evidence(
          '47000000-0000-4000-8000-000000000008'
      );
    IF v_result.outcome <> 'already_recorded' THEN
        RAISE EXCEPTION 'service_role gateway call failed: %', v_result.outcome;
    END IF;

    BEGIN
        PERFORM 1 FROM reputation.evidence LIMIT 1;
        RAISE EXCEPTION 'service_role read the evidence table';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        PERFORM 1 FROM reputation.v_evidence_current_state LIMIT 1;
        RAISE EXCEPTION 'service_role read the evidence view';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        PERFORM reputation.capture_order_delivery_evidence(
            '47000000-0000-4000-8000-000000000008'
        );
        RAISE EXCEPTION 'service_role executed the internal capture function';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$service_role$;

RESET ROLE;

-- ----------------------------------------------------------------------------
-- Refunds/returns cannot rewrite delivery evidence
-- ----------------------------------------------------------------------------
DO $returns$
DECLARE
    v_old_id uuid;
    v_new_id uuid;
    v_v3_id uuid;
    v_v10_id uuid;
    v_old_snapshot jsonb;
    v_new_snapshot jsonb;
    v_v3_snapshot jsonb;
    v_v10_snapshot jsonb;
BEGIN
    SELECT evidence_id INTO v_old_id
      FROM pg_temp.evidence_ref WHERE label='e2v1';
    SELECT evidence_id INTO v_new_id
      FROM pg_temp.evidence_ref WHERE label='e2v2';
    SELECT evidence_id INTO v_v3_id
      FROM pg_temp.evidence_ref WHERE label='e2v3';
    SELECT evidence_id INTO v_v10_id
      FROM pg_temp.evidence_ref WHERE label='e2v10';

    SELECT source_snapshot INTO v_old_snapshot
      FROM reputation.evidence WHERE id=v_old_id;
    SELECT source_snapshot INTO v_new_snapshot
      FROM reputation.evidence WHERE id=v_new_id;
    SELECT source_snapshot INTO v_v3_snapshot
      FROM reputation.evidence WHERE id=v_v3_id;
    SELECT source_snapshot INTO v_v10_snapshot
      FROM reputation.evidence WHERE id=v_v10_id;

    UPDATE commerce.orders
       SET status='returned',
           payment_status='refunded',
           status_reason='simulated return and refund',
           updated_at=now()
     WHERE id='45000000-0000-4000-8000-000000000002';

    IF (SELECT source_snapshot FROM reputation.evidence WHERE id=v_old_id)
       IS DISTINCT FROM v_old_snapshot
       OR (SELECT source_snapshot FROM reputation.evidence WHERE id=v_new_id)
       IS DISTINCT FROM v_new_snapshot
       OR (SELECT source_snapshot FROM reputation.evidence WHERE id=v_v3_id)
       IS DISTINCT FROM v_v3_snapshot
       OR (SELECT source_snapshot FROM reputation.evidence WHERE id=v_v10_id)
       IS DISTINCT FROM v_v10_snapshot THEN
        RAISE EXCEPTION 'return/refund rewrote delivery evidence';
    END IF;
END;
$returns$;

SET CONSTRAINTS
    reputation.reputation_evidence_initial_event_complete,
    reputation.reputation_evidence_events_complete
    IMMEDIATE;

ROLLBACK;

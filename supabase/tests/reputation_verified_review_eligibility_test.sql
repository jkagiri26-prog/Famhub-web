-- ============================================================================
-- reputation_verified_review_eligibility_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE functional/security test for Phase 3A.
-- ============================================================================
BEGIN;

-- Production-faithful local bootstrap for core.user_roles/core.entity_members.
-- Column types, defaults, primary keys, unique constraints, check constraints and
-- foreign keys match the committed baseline. RLS is enabled on entity_members.
-- The authenticated self-select policy is omitted because the disposable
-- bootstrap has no auth.uid(); the resolver is SECURITY DEFINER and runs as
-- postgres, so RLS does not participate in these tests. The user_roles
-- updated_at trigger and production grants are also not reproduced locally.
CREATE TABLE IF NOT EXISTS core.user_roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    type text NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT roles_name_key UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS core.entity_members (
    id uuid PRIMARY KEY DEFAULT public.uuid_generate_v7(),
    entity_id uuid NOT NULL REFERENCES core.entities(id),
    profile_id uuid NOT NULL REFERENCES users.profiles(id),
    role_id uuid NOT NULL REFERENCES core.user_roles(id),
    assigned_at timestamptz DEFAULT now(),
    is_active boolean DEFAULT true,
    can_sell boolean DEFAULT false,
    can_manage boolean DEFAULT false,
    can_receive_payments boolean DEFAULT false,
    membership_status text DEFAULT 'active',
    CONSTRAINT entity_members_entity_id_profile_id_key UNIQUE (entity_id, profile_id),
    CONSTRAINT entity_members_membership_status_check
        CHECK (membership_status IN ('pending', 'active', 'suspended', 'revoked'))
);

ALTER TABLE core.entity_members ENABLE ROW LEVEL SECURITY;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('e6000000-0000-4000-8000-000000000001', 'Eligibility Test Country', 'LC', 'LCT', '9992', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('e6000000-0000-4000-8000-000000000002', 'Eligibility Test Location',
        'e6000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('e6000000-0000-4000-8000-000000000003', 'eligibility-test-kilogram', 'kg', 'mass');

SELECT set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', 'service_role', true),
       set_config('request.jwt.claims', '{"role":"service_role"}', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('e6000000-0000-4000-8000-000000000101', 'e6000000-0000-4000-8000-000000000901',
     'Eligibility Buyer', 'e6000000-0000-4000-8000-000000000001', true, 'active'),
    ('e6000000-0000-4000-8000-000000000102', 'e6000000-0000-4000-8000-000000000902',
     'Eligibility Seller', 'e6000000-0000-4000-8000-000000000001', true, 'active');

SELECT set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', '', true),
       set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, primary_contact_profile_id, is_active, verification_status)
VALUES
    ('e6000000-0000-4000-8000-000000000201', 'Eligibility Seller Entity', 'farm',
     'e6000000-0000-4000-8000-000000000102', 'e6000000-0000-4000-8000-000000000102', true, 'verified'),
    ('e6000000-0000-4000-8000-000000000202', 'Eligibility Buyer Entity', 'individual_pro',
     'e6000000-0000-4000-8000-000000000101', 'e6000000-0000-4000-8000-000000000101', true, 'verified'),
    ('e6000000-0000-4000-8000-000000000203', 'Eligibility Owner-Control Entity', 'farm',
     'e6000000-0000-4000-8000-000000000101', 'e6000000-0000-4000-8000-000000000102', true, 'verified'),
    ('e6000000-0000-4000-8000-000000000204', 'Eligibility Primary-Contact Entity', 'farm',
     'e6000000-0000-4000-8000-000000000102', 'e6000000-0000-4000-8000-000000000101', true, 'verified'),
    ('e6000000-0000-4000-8000-000000000205', 'Eligibility Manager Entity', 'farm',
     'e6000000-0000-4000-8000-000000000102', 'e6000000-0000-4000-8000-000000000102', true, 'verified'),
    ('e6000000-0000-4000-8000-000000000206', 'Eligibility Retired Entity', 'farm',
     'e6000000-0000-4000-8000-000000000102', 'e6000000-0000-4000-8000-000000000102', true, 'verified');

INSERT INTO core.items (id, name) VALUES ('e6000000-0000-4000-8000-000000000301', 'Eligibility Item');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('e6000000-0000-4000-8000-000000000302', 'e6000000-0000-4000-8000-000000000301', 'Eligibility Variant');
INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    'e6000000-0000-4000-8000-000000000401',
    'e6000000-0000-4000-8000-000000000201',
    'e6000000-0000-4000-8000-000000000402',
    'e6000000-0000-4000-8000-000000000302',
    'e6000000-0000-4000-8000-000000000301',
    'e6000000-0000-4000-8000-000000000002',
    1000.00, 0.00, 'e6000000-0000-4000-8000-000000000003', 'active'
);
INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    'e6000000-0000-4000-8000-000000000402', 'farm',
    'e6000000-0000-4000-8000-000000000102', 'Eligibility Supplier',
    'verified', true, 'e6000000-0000-4000-8000-000000000201', true
);
INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    'e6000000-0000-4000-8000-000000000403',
    'e6000000-0000-4000-8000-000000000201',
    'Eligibility Listing', 50.00, 'KES',
    'e6000000-0000-4000-8000-000000000002',
    'e6000000-0000-4000-8000-000000000302',
    1000.00, 'e6000000-0000-4000-8000-000000000003', 'active',
    'e6000000-0000-4000-8000-000000000401'
);

INSERT INTO reputation.subjects (id, subject_type, subject_role, entity_id, status)
VALUES
    ('e6000000-0000-4000-8000-000000000501', 'entity', 'seller', 'e6000000-0000-4000-8000-000000000201', 'active'),
    ('e6000000-0000-4000-8000-000000000502', 'entity', 'seller', 'e6000000-0000-4000-8000-000000000203', 'active'),
    ('e6000000-0000-4000-8000-000000000503', 'entity', 'seller', 'e6000000-0000-4000-8000-000000000204', 'active'),
    ('e6000000-0000-4000-8000-000000000504', 'entity', 'seller', 'e6000000-0000-4000-8000-000000000205', 'active'),
    ('e6000000-0000-4000-8000-000000000505', 'entity', 'seller', 'e6000000-0000-4000-8000-000000000206', 'active');

INSERT INTO reputation.subjects (id, subject_type, subject_role, listing_id, status)
VALUES ('e6000000-0000-4000-8000-000000000506', 'listing', 'listing',
        'e6000000-0000-4000-8000-000000000403', 'active');

INSERT INTO reputation.subjects (id, subject_type, subject_role, item_id, status)
VALUES ('e6000000-0000-4000-8000-000000000507', 'item', 'product',
        'e6000000-0000-4000-8000-000000000301', 'active');

INSERT INTO reputation.subjects (id, subject_type, subject_role, variant_id, status)
VALUES ('e6000000-0000-4000-8000-000000000508', 'variant', 'product_variant',
        'e6000000-0000-4000-8000-000000000302', 'active');

INSERT INTO core.user_roles (id, name, type, is_active)
VALUES ('e6000000-0000-4000-8000-000000000602',
        'Phase 3A Eligibility Manager', 'entity', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO core.entity_members (id, entity_id, profile_id, role_id, is_active, can_manage, membership_status)
VALUES ('e6000000-0000-4000-8000-000000000601',
        'e6000000-0000-4000-8000-000000000205',
        'e6000000-0000-4000-8000-000000000101',
        'e6000000-0000-4000-8000-000000000602', true, true, 'active');

CREATE FUNCTION pg_temp.insert_eligibility_order(p_id uuid, p_kind text)
RETURNS void LANGUAGE sql AS $f$
    INSERT INTO commerce.orders (
        id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
        payment_status, order_date, delivered_at, delivery_date, entity_id,
        order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
        status_changed_by_profile_id
    ) VALUES (
        p_id, 'e6000000-0000-4000-8000-000000000101',
        'e6000000-0000-4000-8000-000000000403',
        'e6000000-0000-4000-8000-000000000402',
        1.00, 50.00, 'delivered', 'pending',
        '2026-11-22T08:00:00Z', '2026-11-22T09:00:00Z', '2026-11-22T09:00:00Z',
        'e6000000-0000-4000-8000-000000000201', p_kind,
        'e6000000-0000-4000-8000-000000000202',
        'e6000000-0000-4000-8000-000000000201',
        'KES', 'e6000000-0000-4000-8000-000000000003',
        'e6000000-0000-4000-8000-000000000101'
    );
$f$;

CREATE FUNCTION pg_temp.make_entry(
    p_engagement_id uuid,
    p_order_id uuid,
    p_buyer_entity_id uuid,
    p_seller_entity_id uuid,
    p_subject_id uuid,
    p_kind text DEFAULT 'vunio_order'
) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    v_snapshot jsonb;
    v_hash bytea;
    v_delivered_at timestamptz := '2026-11-22T09:00:00Z';
    v_event_hash bytea;
BEGIN
    v_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1,
        'source', jsonb_build_object('source_system', CASE WHEN p_kind='vunio_order' THEN 'vunio' ELSE 'test' END,
                                     'source_reference', COALESCE(p_order_id::text, p_engagement_id::text))
    );
    v_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));

    INSERT INTO reputation.engagements (
        id, engagement_kind, source_system, source_reference, commerce_order_id,
        source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
    ) VALUES (
        p_engagement_id, p_kind,
        CASE WHEN p_kind='vunio_order' THEN 'vunio' ELSE 'test' END,
        COALESCE(p_order_id::text, p_engagement_id::text),
        CASE WHEN p_kind='vunio_order' THEN p_order_id ELSE NULL END,
        v_snapshot, v_hash, v_delivered_at, 'KES', 50.00
    );

    IF p_kind = 'vunio_order' THEN
        INSERT INTO reputation.engagement_participants (engagement_id, party_role, profile_id, entity_id)
        VALUES (p_engagement_id, 'buyer', 'e6000000-0000-4000-8000-000000000101', p_buyer_entity_id);
        INSERT INTO reputation.engagement_participants (engagement_id, party_role, entity_id)
        VALUES (p_engagement_id, 'seller', p_seller_entity_id);
        INSERT INTO reputation.engagement_subjects (engagement_id, subject_id, relationship, source_fact)
        VALUES (p_engagement_id, p_subject_id, 'seller_entity', '{}'::jsonb);

        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key, event_version, details
        ) VALUES (
            p_engagement_id, 'reputation', 'engagement_recorded',
            '2026-11-22T08:00:00Z', 'engagement-recorded', 1,
            '{"source_integrity_status":"consistent"}'::jsonb
        );

        v_event_hash := pg_catalog.sha256(convert_to(jsonb_build_object(
            'event_version', 1,
            'event_type', 'order_delivered',
            'event_at', to_char(v_delivered_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
            'source_namespace', 'vunio',
            'source_event_reference', 'order:' || p_order_id::text || ':delivered',
            'actor_profile_id', NULL::text,
            'details', '{}'::jsonb
        )::text, 'UTF8'));
        INSERT INTO reputation.engagement_events (
            engagement_id, event_origin, event_type, event_at, event_key,
            source_namespace, source_event_reference, payload_hash, event_version, details
        ) VALUES (
            p_engagement_id, 'source', 'order_delivered', v_delivered_at,
            'vunio:delivered', 'vunio', 'order:' || p_order_id::text || ':delivered',
            v_event_hash, 1, '{}'::jsonb
        );
    END IF;
END;
$f$;

CREATE FUNCTION pg_temp.add_evidence(
    p_evidence_id uuid,
    p_engagement_id uuid,
    p_order_id uuid,
    p_version text DEFAULT 'delivery:v1',
    p_supersedes uuid DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE
    v_snapshot jsonb;
    v_hash bytea;
BEGIN
    v_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1,
        'evidence_type', 'commerce_order_delivery',
        'source_version', p_version,
        'source', jsonb_build_object(
            'source_system', 'commerce',
            'source_reference', p_order_id::text
        ),
        'test_evidence', p_evidence_id
    );
    v_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));
    INSERT INTO reputation.evidence (
        id, engagement_id, evidence_type, source_system, source_reference,
        source_version, source_occurred_at, snapshot_version, captured_at,
        source_snapshot, source_snapshot_hash, capture_method, capture_process,
        provenance, supersedes_evidence_id
    ) VALUES (
        p_evidence_id, p_engagement_id, 'commerce_order_delivery', 'commerce',
        p_order_id::text, p_version, '2026-11-22T09:00:00Z', 1, clock_timestamp(),
        v_snapshot, v_hash, 'trusted_service', 'eligibility-test',
        '{}'::jsonb, p_supersedes
    );
    INSERT INTO reputation.evidence_events (
        evidence_id, event_type, event_at, event_key, event_version,
        actor_process, details
    ) VALUES (
        p_evidence_id, 'evidence_recorded', clock_timestamp(), 'evidence-recorded', 1,
        'eligibility-test', jsonb_build_object(
            'source_integrity_status', 'consistent',
            'snapshot_version', 1,
            'source_occurred_at', '2026-11-22T09:00:00Z',
            'source_snapshot_hash', encode(v_hash, 'hex'),
            'capture_method', 'trusted_service',
            'capture_process', 'eligibility-test',
            'provenance', '{}'::jsonb
        )
    );
    RETURN p_evidence_id;
END;
$f$;

CREATE FUNCTION pg_temp.add_revoked(p_evidence_id uuid) RETURNS void LANGUAGE sql AS $f$
    INSERT INTO reputation.evidence_events (
        evidence_id, event_type, event_at, event_key, event_version, actor_process, details
    ) VALUES (
        p_evidence_id, 'evidence_revoked', clock_timestamp(), 'revoked', 1,
        'eligibility-test', '{"reason_code":"test_revoke"}'::jsonb
    );
$f$;

CREATE FUNCTION pg_temp.add_conflict(p_evidence_id uuid) RETURNS void LANGUAGE sql AS $f$
    INSERT INTO reputation.evidence_events (
        evidence_id, event_type, event_at, event_key, event_version, actor_process, details
    ) VALUES (
        p_evidence_id, 'evidence_conflict_detected', clock_timestamp(), 'conflict:test', 1,
        'eligibility-test', jsonb_build_object(
            'attempted_source_system', 'commerce',
            'attempted_source_reference', 'test-order',
            'attempted_source_version', 'delivery:v1',
            'attempted_source_snapshot', '{}'::jsonb,
            'attempted_source_snapshot_hash', repeat('0', 64),
            'reason_code', 'test_conflict'
        )
    );
$f$;

CREATE FUNCTION pg_temp.add_supersession(p_old uuid, p_new uuid) RETURNS void LANGUAGE sql AS $f$
    INSERT INTO reputation.evidence_events (
        evidence_id, event_type, event_at, event_key, event_version, actor_process, details
    ) VALUES (
        p_old, 'evidence_superseded', clock_timestamp(), 'superseded:' || p_new::text, 1,
        'eligibility-test', jsonb_build_object(
            'superseded_by_evidence_id', p_new,
            'reason_code', 'test_correction'
        )
    );
$f$;

CREATE FUNCTION pg_temp.add_source_outcome(
    p_engagement_id uuid, p_order_id uuid, p_event_type text
) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    v_at timestamptz := '2026-11-22T10:00:00Z';
    v_ref text := 'test:' || p_event_type || ':' || p_order_id::text;
    v_hash bytea;
BEGIN
    v_hash := pg_catalog.sha256(convert_to(jsonb_build_object(
        'event_version', 1,
        'event_type', p_event_type,
        'event_at', to_char(v_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'source_namespace', 'vunio',
        'source_event_reference', v_ref,
        'actor_profile_id', NULL::text,
        'details', '{}'::jsonb
    )::text, 'UTF8'));
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, event_version, details
    ) VALUES (
        p_engagement_id, 'source', p_event_type, v_at, v_ref,
        'vunio', v_ref, v_hash, 1, '{}'::jsonb
    );
END;
$f$;

CREATE FUNCTION pg_temp.add_void(p_engagement_id uuid) RETURNS void LANGUAGE sql AS $f$
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, event_version, details
    ) VALUES (
        p_engagement_id, 'reputation', 'engagement_voided', '2026-11-22T11:00:00Z',
        'engagement-voided', 1, '{"invalidity_code":"test_void"}'::jsonb
    );
$f$;

CREATE FUNCTION pg_temp.add_dispute(p_engagement_id uuid) RETURNS void LANGUAGE sql AS $f$
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, event_version, details
    ) VALUES (
        p_engagement_id, 'reputation', 'dispute_opened', '2026-11-22T11:00:00Z',
        'dispute-opened', 1, '{}'::jsonb
    );
$f$;

-- Orders and base engagements.
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000001', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000002', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000003', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000004', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000005', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000006', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000007', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000008', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000009', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000010', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000011', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000012', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000013', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000014', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000015', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000016', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000017', 'stock');
SELECT pg_temp.insert_eligibility_order('e7000000-0000-4000-8000-000000000018', 'stock');

SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000001', 'e7000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000002', 'e7000000-0000-4000-8000-000000000002', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000003', 'e7000000-0000-4000-8000-000000000003', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000004', 'e7000000-0000-4000-8000-000000000004', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000005', 'e7000000-0000-4000-8000-000000000005', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000006', 'e7000000-0000-4000-8000-000000000006', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000007', 'e7000000-0000-4000-8000-000000000007', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000008', 'e7000000-0000-4000-8000-000000000008', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000009', 'e7000000-0000-4000-8000-000000000009', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000010', 'e7000000-0000-4000-8000-000000000010', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000011', 'e7000000-0000-4000-8000-000000000011', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000012', 'e7000000-0000-4000-8000-000000000012', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000013', 'e7000000-0000-4000-8000-000000000013', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000014', 'e7000000-0000-4000-8000-000000000014', NULL, 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000015', 'e7000000-0000-4000-8000-000000000015', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000203', 'e6000000-0000-4000-8000-000000000502');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000016', 'e7000000-0000-4000-8000-000000000016', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000204', 'e6000000-0000-4000-8000-000000000503');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000017', 'e7000000-0000-4000-8000-000000000017', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000205', 'e6000000-0000-4000-8000-000000000504');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000018', NULL, NULL, 'e6000000-0000-4000-8000-000000000206', 'e6000000-0000-4000-8000-000000000505', 'service_engagement');
SELECT pg_temp.make_entry('e8000000-0000-4000-8000-000000000019', 'e7000000-0000-4000-8000-000000000018', 'e6000000-0000-4000-8000-000000000202', 'e6000000-0000-4000-8000-000000000201', 'e6000000-0000-4000-8000-000000000501');

-- Base active evidence and extra non-target subject.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000001', 'e7000000-0000-4000-8000-000000000001');
INSERT INTO reputation.engagement_subjects (engagement_id, subject_id, relationship, source_fact)
VALUES
    ('e8000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000506', 'listing', '{}'::jsonb),
    ('e8000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000507', 'product', '{}'::jsonb),
    ('e8000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000508', 'variant', '{}'::jsonb);

-- Multiple items still produce exactly one engagement-level decision.
INSERT INTO commerce.order_items (
    id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
    stock_id, variant_id, unit_id
) VALUES
    ('e6a00000-0000-4000-8000-000000000001', 'e7000000-0000-4000-8000-000000000001',
     'e6000000-0000-4000-8000-000000000403', 'e6000000-0000-4000-8000-000000000301',
     1.00, 'kg', 25.00, 'e6000000-0000-4000-8000-000000000401',
     'e6000000-0000-4000-8000-000000000302', 'e6000000-0000-4000-8000-000000000003'),
    ('e6a00000-0000-4000-8000-000000000002', 'e7000000-0000-4000-8000-000000000001',
     'e6000000-0000-4000-8000-000000000403', 'e6000000-0000-4000-8000-000000000301',
     1.00, 'kg', 25.00, 'e6000000-0000-4000-8000-000000000401',
     'e6000000-0000-4000-8000-000000000302', 'e6000000-0000-4000-8000-000000000003');

-- Processing-work state is operational only and must not affect eligibility.
DELETE FROM reputation.processing_work
 WHERE source_system = 'vunio'
   AND source_reference = 'e7000000-0000-4000-8000-000000000001';
INSERT INTO reputation.processing_work (
    id, work_kind, source_system, source_reference, status, attempt_count,
    dead_letter_reason_code, dead_lettered_at, created_at, updated_at
) VALUES (
    'e6b00000-0000-4000-8000-000000000001', 'stock_order_engagement_ingestion',
    'vunio', 'e7000000-0000-4000-8000-000000000001', 'dead_letter', 1,
    'test_dead_letter', '2026-11-22T00:00:02Z', '2026-11-22T00:00:00Z',
    '2026-11-22T00:00:03Z'
);

-- Missing evidence is E2.
-- Revoked evidence.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000003', 'e8000000-0000-4000-8000-000000000003', 'e7000000-0000-4000-8000-000000000003');
SELECT pg_temp.add_revoked('e9000000-0000-4000-8000-000000000003');
-- Conflicted evidence.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000004', 'e8000000-0000-4000-8000-000000000004', 'e7000000-0000-4000-8000-000000000004');
SELECT pg_temp.add_conflict('e9000000-0000-4000-8000-000000000004');
-- Superseded original with active replacement.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000005', 'e8000000-0000-4000-8000-000000000005', 'e7000000-0000-4000-8000-000000000005', 'delivery:v1');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000006', 'e8000000-0000-4000-8000-000000000005', 'e7000000-0000-4000-8000-000000000005', 'delivery:v2', 'e9000000-0000-4000-8000-000000000005');
SELECT pg_temp.add_supersession('e9000000-0000-4000-8000-000000000005', 'e9000000-0000-4000-8000-000000000006');
-- The current Phase 2B lifecycle rejects superseding revoked evidence, so a
-- legitimate revoked-original-with-active-replacement fixture cannot be
-- constructed through the authoritative schema. The superseded-original case
-- below proves corrected active evidence restoration.
-- Voided and disputed.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000009', 'e8000000-0000-4000-8000-000000000007', 'e7000000-0000-4000-8000-000000000007');
SELECT pg_temp.add_void('e8000000-0000-4000-8000-000000000007');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000010', 'e8000000-0000-4000-8000-000000000008', 'e7000000-0000-4000-8000-000000000008');
SELECT pg_temp.add_dispute('e8000000-0000-4000-8000-000000000008');
-- Source outcomes.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000011', 'e8000000-0000-4000-8000-000000000009', 'e7000000-0000-4000-8000-000000000009');
SELECT pg_temp.add_source_outcome('e8000000-0000-4000-8000-000000000009', 'e7000000-0000-4000-8000-000000000009', 'order_returned');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000012', 'e8000000-0000-4000-8000-000000000010', 'e7000000-0000-4000-8000-000000000010');
SELECT pg_temp.add_source_outcome('e8000000-0000-4000-8000-000000000010', 'e7000000-0000-4000-8000-000000000010', 'order_refunded');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000013', 'e8000000-0000-4000-8000-000000000011', 'e7000000-0000-4000-8000-000000000011');
SELECT pg_temp.add_source_outcome('e8000000-0000-4000-8000-000000000011', 'e7000000-0000-4000-8000-000000000011', 'order_partially_refunded');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000014', 'e8000000-0000-4000-8000-000000000012', 'e7000000-0000-4000-8000-000000000012');
SELECT pg_temp.add_source_outcome('e8000000-0000-4000-8000-000000000012', 'e7000000-0000-4000-8000-000000000012', 'order_reversed');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000015', 'e8000000-0000-4000-8000-000000000013', 'e7000000-0000-4000-8000-000000000013');
SELECT pg_temp.add_source_outcome('e8000000-0000-4000-8000-000000000013', 'e7000000-0000-4000-8000-000000000013', 'order_cancelled');
-- Buyer without buyer entity.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000016', 'e8000000-0000-4000-8000-000000000014', 'e7000000-0000-4000-8000-000000000014');
-- Self-review entities.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000017', 'e8000000-0000-4000-8000-000000000015', 'e7000000-0000-4000-8000-000000000015');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000018', 'e8000000-0000-4000-8000-000000000016', 'e7000000-0000-4000-8000-000000000016');
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000019', 'e8000000-0000-4000-8000-000000000017', 'e7000000-0000-4000-8000-000000000017');
-- Service engagement carrying stock-delivery evidence must still not qualify.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000021', 'e8000000-0000-4000-8000-000000000018', 'e7000000-0000-4000-8000-000000000017');
-- Retired subject: evidence on E19, then retire subject.
SELECT pg_temp.add_evidence('e9000000-0000-4000-8000-000000000020', 'e8000000-0000-4000-8000-000000000019', 'e7000000-0000-4000-8000-000000000018');
SELECT reputation.retire_subject('e6000000-0000-4000-8000-000000000505');

DO $assertions$
DECLARE
    r record;
BEGIN
    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'eligible'
       OR r.reason_code IS NOT NULL
       OR r.subject_id <> 'e6000000-0000-4000-8000-000000000501'
       OR r.evidence_id <> 'e9000000-0000-4000-8000-000000000001'
       OR r.evidence_source_version <> 'delivery:v1'
       OR r.rule_version <> 1 THEN
        RAISE EXCEPTION 'eligible base case mismatch: %', r;
    END IF;

    IF (SELECT count(*) FROM reputation.resolve_verified_review_eligibility(
            'e8000000-0000-4000-8000-000000000001',
            'e6000000-0000-4000-8000-000000000101')) <> 1 THEN
        RAISE EXCEPTION 'multiple items/subjects produced multiple eligibility decisions';
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000002', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'ineligible' OR r.reason_code <> 'evidence_missing' THEN
        RAISE EXCEPTION 'missing evidence mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000003', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'ineligible' OR r.reason_code <> 'evidence_not_active' THEN
        RAISE EXCEPTION 'revoked evidence mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000004', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'ineligible' OR r.reason_code <> 'evidence_conflicted' THEN
        RAISE EXCEPTION 'conflicted evidence mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000005', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'eligible'
       OR r.evidence_id <> 'e9000000-0000-4000-8000-000000000006'
       OR r.evidence_source_version <> 'delivery:v2' THEN
        RAISE EXCEPTION 'superseded replacement mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000007', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'ineligible' OR r.reason_code <> 'engagement_voided' THEN
        RAISE EXCEPTION 'voided engagement mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000008', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'suspended' OR r.reason_code <> 'engagement_suspended' THEN
        RAISE EXCEPTION 'disputed engagement mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000009', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'ineligible' OR r.reason_code <> 'source_outcome_not_completed' THEN
        RAISE EXCEPTION 'returned order mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000010', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'source_outcome_not_completed' THEN
        RAISE EXCEPTION 'refunded order mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000011', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'source_outcome_not_completed' THEN
        RAISE EXCEPTION 'partially refunded order mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000012', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'source_outcome_not_completed' THEN
        RAISE EXCEPTION 'reversed order mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000013', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'source_outcome_not_completed' THEN
        RAISE EXCEPTION 'cancelled order mismatch: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000014', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligibility_status <> 'eligible' THEN
        RAISE EXCEPTION 'buyer without entity should be eligible: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000015', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'self_review_owner' THEN
        RAISE EXCEPTION 'owner self-review was not blocked: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000016', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'self_review_primary_contact' THEN
        RAISE EXCEPTION 'primary-contact self-review was not blocked: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000017', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'self_review_manager' THEN
        RAISE EXCEPTION 'manager self-review was not blocked: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000019', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'subject_retired' THEN
        RAISE EXCEPTION 'retired subject was not blocked: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000018', 'e6000000-0000-4000-8000-000000000101');
    IF r.reason_code <> 'unsupported_engagement_kind' THEN
        RAISE EXCEPTION 'service engagement was not blocked: %', r;
    END IF;

    SELECT * INTO r FROM reputation.resolve_verified_review_eligibility(
        'e8000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000102');
    IF r.reason_code <> 'reviewer_not_buyer' THEN
        RAISE EXCEPTION 'seller reviewer was not blocked: %', r;
    END IF;
END;
$assertions$;

-- Gateway is sanitized and matches the resolver.
DO $gateway$
DECLARE
    r record;
    v_result text;
BEGIN
    SELECT * INTO r FROM system.resolve_reputation_review_eligibility(
        'e8000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000101');
    IF r.eligible IS NOT TRUE
       OR r.eligibility_status <> 'eligible'
       OR r.subject_id <> 'e6000000-0000-4000-8000-000000000501'
       OR r.rule_version <> 1 THEN
        RAISE EXCEPTION 'gateway eligible mismatch: %', r;
    END IF;

    v_result := pg_get_function_result(
        'system.resolve_reputation_review_eligibility(uuid,uuid)'::regprocedure);
    IF v_result LIKE '%reviewer_profile_id%'
       OR v_result LIKE '%evidence_id%'
       OR v_result LIKE '%evidence_source_version%'
       OR v_result LIKE '%evidence_snapshot_hash%' THEN
        RAISE EXCEPTION 'gateway exposes private fields: %', v_result;
    END IF;
END;
$gateway$;

-- Effective grants.
DO $security$
BEGIN
    IF has_function_privilege('service_role', 'reputation.resolve_verified_review_eligibility(uuid,uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'reputation.resolve_verified_review_eligibility(uuid,uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'reputation.resolve_verified_review_eligibility(uuid,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'private resolver is executable by an API role';
    END IF;

    IF NOT has_function_privilege('service_role', 'system.resolve_reputation_review_eligibility(uuid,uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'system.resolve_reputation_review_eligibility(uuid,uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'system.resolve_reputation_review_eligibility(uuid,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'gateway grants are wrong';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        CROSS JOIN LATERAL aclexplode(p.proacl) a
        WHERE p.oid = 'reputation.resolve_verified_review_eligibility(uuid,uuid)'::regprocedure
          AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'private resolver executable by PUBLIC';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        CROSS JOIN LATERAL aclexplode(p.proacl) a
        WHERE p.oid = 'system.resolve_reputation_review_eligibility(uuid,uuid)'::regprocedure
          AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'gateway executable by PUBLIC';
    END IF;

    IF has_table_privilege('anon', 'reputation.evidence', 'SELECT')
       OR has_table_privilege('authenticated', 'reputation.evidence', 'SELECT')
       OR has_table_privilege('service_role', 'reputation.evidence', 'SELECT')
       OR has_table_privilege('anon', 'reputation.engagements', 'SELECT') THEN
        RAISE EXCEPTION 'browser or service_role has direct Reputation access';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        WHERE p.oid = 'reputation.resolve_verified_review_eligibility(uuid,uuid)'::regprocedure
          AND p.prosecdef
          AND p.proowner = 'postgres'::regrole
          AND p.proconfig::text LIKE '%search_path=pg_catalog, reputation, core, users%'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_proc p
        WHERE p.oid = 'system.resolve_reputation_review_eligibility(uuid,uuid)'::regprocedure
          AND p.prosecdef
          AND p.proowner = 'postgres'::regrole
          AND p.proconfig::text LIKE '%search_path=pg_catalog, system, reputation%'
    ) THEN
        RAISE EXCEPTION 'resolver/gateway security attributes are wrong';
    END IF;
END;
$security$;

ROLLBACK;

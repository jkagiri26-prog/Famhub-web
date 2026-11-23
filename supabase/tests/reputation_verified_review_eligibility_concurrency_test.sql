-- ============================================================================
-- reputation_verified_review_eligibility_concurrency_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE concurrency/security test for Phase 3A.
--
-- Creates a committed disposable fixture because dblink sessions require
-- visibility across connections. Discard the local database afterward.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;

-- Production-faithful local bootstrap for core.user_roles/core.entity_members.
-- Column types, defaults, primary keys, unique constraints, check constraints and
-- foreign keys match the committed baseline. RLS is enabled on entity_members.
-- The authenticated self-select policy is omitted because the disposable
-- bootstrap has no auth.uid(); the resolver is SECURITY DEFINER and runs as
-- postgres, so RLS does not participate in this test. The user_roles updated_at
-- trigger and production grants are also not reproduced locally.
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
VALUES ('f6000000-0000-4000-8000-000000000001', 'Eligibility Lock Country', 'KQ', 'KQT', '9991', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('f6000000-0000-4000-8000-000000000002', 'Eligibility Lock Location',
        'f6000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('f6000000-0000-4000-8000-000000000003', 'eligibility-lock-kilogram', 'kg', 'mass');

SELECT set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', 'service_role', true),
       set_config('request.jwt.claims', '{"role":"service_role"}', true);
INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('f6000000-0000-4000-8000-000000000101', 'f6000000-0000-4000-8000-000000000901',
     'Lock Buyer', 'f6000000-0000-4000-8000-000000000001', true, 'active'),
    ('f6000000-0000-4000-8000-000000000102', 'f6000000-0000-4000-8000-000000000902',
     'Lock Seller', 'f6000000-0000-4000-8000-000000000001', true, 'active');
SELECT set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', '', true),
       set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, primary_contact_profile_id, is_active, verification_status)
VALUES
    ('f6000000-0000-4000-8000-000000000201', 'Lock Seller Entity', 'farm',
     'f6000000-0000-4000-8000-000000000102', 'f6000000-0000-4000-8000-000000000102', true, 'verified'),
    ('f6000000-0000-4000-8000-000000000202', 'Lock Buyer Entity', 'individual_pro',
     'f6000000-0000-4000-8000-000000000101', 'f6000000-0000-4000-8000-000000000101', true, 'verified');

INSERT INTO core.items (id, name) VALUES ('f6000000-0000-4000-8000-000000000301', 'Lock Item');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('f6000000-0000-4000-8000-000000000302', 'f6000000-0000-4000-8000-000000000301', 'Lock Variant');
INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    'f6000000-0000-4000-8000-000000000401',
    'f6000000-0000-4000-8000-000000000201',
    'f6000000-0000-4000-8000-000000000402',
    'f6000000-0000-4000-8000-000000000302',
    'f6000000-0000-4000-8000-000000000301',
    'f6000000-0000-4000-8000-000000000002',
    1000.00, 0.00, 'f6000000-0000-4000-8000-000000000003', 'active'
);
INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    'f6000000-0000-4000-8000-000000000402', 'farm',
    'f6000000-0000-4000-8000-000000000102', 'Lock Supplier',
    'verified', true, 'f6000000-0000-4000-8000-000000000201', true
);
INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    'f6000000-0000-4000-8000-000000000403',
    'f6000000-0000-4000-8000-000000000201',
    'Lock Listing', 50.00, 'KES',
    'f6000000-0000-4000-8000-000000000002',
    'f6000000-0000-4000-8000-000000000302',
    1000.00, 'f6000000-0000-4000-8000-000000000003', 'active',
    'f6000000-0000-4000-8000-000000000401'
);

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, delivery_date, entity_id,
    order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
    status_changed_by_profile_id
) VALUES (
    'f6000000-0000-4000-8000-000000000501',
    'f6000000-0000-4000-8000-000000000101',
    'f6000000-0000-4000-8000-000000000403',
    'f6000000-0000-4000-8000-000000000402',
    1.00, 50.00, 'delivered', 'pending',
    '2026-11-22T08:00:00Z', '2026-11-22T09:00:00Z', '2026-11-22T09:00:00Z',
    'f6000000-0000-4000-8000-000000000201', 'stock',
    'f6000000-0000-4000-8000-000000000202',
    'f6000000-0000-4000-8000-000000000201',
    'KES', 'f6000000-0000-4000-8000-000000000003',
    'f6000000-0000-4000-8000-000000000101'
);

INSERT INTO reputation.subjects (id, subject_type, subject_role, entity_id, status)
VALUES ('f6000000-0000-4000-8000-000000000601', 'entity', 'seller',
        'f6000000-0000-4000-8000-000000000201', 'active');

DO $fixture$
DECLARE
    v_engagement_id uuid := 'f6000000-0000-4000-8000-000000000701';
    v_order_id uuid := 'f6000000-0000-4000-8000-000000000501';
    v_snapshot jsonb;
    v_hash bytea;
    v_event_hash bytea;
    v_evidence_snapshot jsonb;
    v_evidence_hash bytea;
BEGIN
    v_snapshot := jsonb_build_object('snapshot_schema_version', 1,
        'source', jsonb_build_object('source_system', 'vunio',
                                     'source_reference', v_order_id::text));
    v_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));

    INSERT INTO reputation.engagements (
        id, engagement_kind, source_system, source_reference, commerce_order_id,
        source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
    ) VALUES (
        v_engagement_id, 'vunio_order', 'vunio', v_order_id::text, v_order_id,
        v_snapshot, v_hash, '2026-11-22T09:00:00Z', 'KES', 50.00
    );

    INSERT INTO reputation.engagement_participants (engagement_id, party_role, profile_id, entity_id)
    VALUES (v_engagement_id, 'buyer', 'f6000000-0000-4000-8000-000000000101',
            'f6000000-0000-4000-8000-000000000202');
    INSERT INTO reputation.engagement_participants (engagement_id, party_role, entity_id)
    VALUES (v_engagement_id, 'seller', 'f6000000-0000-4000-8000-000000000201');
    INSERT INTO reputation.engagement_subjects (engagement_id, subject_id, relationship, source_fact)
    VALUES (v_engagement_id, 'f6000000-0000-4000-8000-000000000601', 'seller_entity', '{}'::jsonb);

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, event_version, details
    ) VALUES (
        v_engagement_id, 'reputation', 'engagement_recorded',
        '2026-11-22T08:00:00Z', 'engagement-recorded', 1,
        '{"source_integrity_status":"consistent"}'::jsonb
    );

    v_event_hash := pg_catalog.sha256(convert_to(jsonb_build_object(
        'event_version', 1,
        'event_type', 'order_delivered',
        'event_at', '2026-11-22T09:00:00.000000Z',
        'source_namespace', 'vunio',
        'source_event_reference', 'order:' || v_order_id::text || ':delivered',
        'actor_profile_id', NULL::text,
        'details', '{}'::jsonb
    )::text, 'UTF8'));
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, event_version, details
    ) VALUES (
        v_engagement_id, 'source', 'order_delivered', '2026-11-22T09:00:00Z',
        'vunio:delivered', 'vunio', 'order:' || v_order_id::text || ':delivered',
        v_event_hash, 1, '{}'::jsonb
    );

    v_evidence_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1,
        'evidence_type', 'commerce_order_delivery',
        'source_version', 'delivery:v1',
        'source', jsonb_build_object('source_system', 'commerce',
                                     'source_reference', v_order_id::text)
    );
    v_evidence_hash := pg_catalog.sha256(convert_to(v_evidence_snapshot::text, 'UTF8'));

    INSERT INTO reputation.evidence (
        id, engagement_id, evidence_type, source_system, source_reference,
        source_version, source_occurred_at, snapshot_version, captured_at,
        source_snapshot, source_snapshot_hash, capture_method, capture_process,
        provenance
    ) VALUES (
        'f6000000-0000-4000-8000-000000000801', v_engagement_id,
        'commerce_order_delivery', 'commerce', v_order_id::text,
        'delivery:v1', '2026-11-22T09:00:00Z', 1, clock_timestamp(),
        v_evidence_snapshot, v_evidence_hash, 'trusted_service',
        'eligibility-concurrency-test', '{}'::jsonb
    );
    INSERT INTO reputation.evidence_events (
        evidence_id, event_type, event_at, event_key, event_version,
        actor_process, details
    ) VALUES (
        'f6000000-0000-4000-8000-000000000801', 'evidence_recorded',
        clock_timestamp(), 'evidence-recorded', 1, 'eligibility-concurrency-test',
        jsonb_build_object(
            'source_integrity_status', 'consistent',
            'snapshot_version', 1,
            'source_occurred_at', '2026-11-22T09:00:00Z',
            'source_snapshot_hash', encode(v_evidence_hash, 'hex'),
            'capture_method', 'trusted_service',
            'capture_process', 'eligibility-concurrency-test',
            'provenance', '{}'::jsonb
        )
    );
END;
$fixture$;

DO $structural_lock_check$
DECLARE
    v_name text;
    v_def text;
BEGIN
    FOREACH v_name IN ARRAY ARRAY[
        'capture_order_delivery_evidence',
        'capture_order_delivery_evidence_correction',
        'revoke_evidence',
        'resolve_evidence_conflict'
    ] LOOP
        SELECT pg_get_functiondef(p.oid) INTO v_def
          FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='reputation' AND p.proname=v_name
         LIMIT 1;
        IF v_def IS NULL
           OR v_def NOT LIKE '%reputation.engagements%'
           OR v_def NOT LIKE '%FOR UPDATE%' THEN
            RAISE EXCEPTION 'evidence lifecycle function % does not lock engagements', v_name;
        END IF;
    END LOOP;
END;
$structural_lock_check$;

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
     WHERE name='unix_socket_directories';
    PERFORM dblink_connect('lock_a', v_conn);
    PERFORM dblink_connect('lock_b', v_conn);
END;
$connect$;

DO $locking$
DECLARE
    v_busy integer;
    v_result record;
BEGIN
    PERFORM dblink_exec('lock_a', 'BEGIN');
    PERFORM dblink_send_query('lock_a', $q$
        SELECT 1 FROM reputation.engagements
         WHERE id='f6000000-0000-4000-8000-000000000701'
         FOR SHARE
    $q$);
    PERFORM pg_sleep(0.2);

    PERFORM dblink_exec('lock_b', 'BEGIN');
    PERFORM dblink_send_query('lock_b', $q$
        SELECT * FROM system.revoke_reputation_evidence(
            'f6000000-0000-4000-8000-000000000801',
            'concurrency_test',
            'lock compatibility test',
            NULL
        )
    $q$);
    PERFORM pg_sleep(0.5);

    SELECT dblink_is_busy('lock_b') INTO v_busy;
    IF v_busy <> 1 THEN
        RAISE EXCEPTION 'revoke did not wait on engagement lock';
    END IF;

    PERFORM * FROM dblink_get_result('lock_a') AS t(value integer);
    PERFORM * FROM dblink_get_result('lock_a') AS t(value integer);
    PERFORM dblink_exec('lock_a', 'COMMIT');

    PERFORM * FROM dblink_get_result('lock_b')
        AS t(evidence_id uuid, outcome text, evidence_status text);
    PERFORM * FROM dblink_get_result('lock_b')
        AS t(evidence_id uuid, outcome text, evidence_status text);
    PERFORM dblink_exec('lock_b', 'COMMIT');

    SELECT * INTO v_result
      FROM reputation.resolve_verified_review_eligibility(
          'f6000000-0000-4000-8000-000000000701',
          'f6000000-0000-4000-8000-000000000101'
      );
    IF v_result.eligibility_status <> 'ineligible'
       OR v_result.reason_code <> 'evidence_not_active' THEN
        RAISE EXCEPTION 'revoked evidence remained eligible: %', v_result;
    END IF;
END;
$locking$;

SELECT dblink_disconnect('lock_b');
SELECT dblink_disconnect('lock_a');

-- ============================================================================
-- reputation_ratings_reviews_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE functional/security test for Phase 3B.
-- ============================================================================
BEGIN;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $f$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$f$;
CREATE OR REPLACE FUNCTION auth.role()
RETURNS text LANGUAGE sql STABLE AS $f$
    SELECT NULLIF(current_setting('request.jwt.claim.role', true), '')
$f$;
CREATE OR REPLACE FUNCTION core.current_profile_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog', 'users'
AS $f$
    SELECT p.id FROM users.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1
$f$;
CREATE OR REPLACE FUNCTION core.has_permission(p_permission text)
RETURNS boolean LANGUAGE sql STABLE AS $f$
    SELECT COALESCE(current_setting('test.allow_moderation', true), 'false') = 'true'
$f$;

ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS middle_name text;
ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS last_name text;
ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS profile_image text;

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
VALUES ('d3000000-0000-4000-8000-000000000001', 'Ratings Test Country', 'RQ', 'RQT', '9987', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('d3000000-0000-4000-8000-000000000002', 'Ratings Test Location',
        'd3000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('d3000000-0000-4000-8000-000000000003', 'ratings-kilogram', 'kg', 'mass');

INSERT INTO users.profiles (id, auth_user_id, first_name, last_name, country_id, is_active, account_status)
VALUES
    ('d3000000-0000-4000-8000-000000000101', 'd3000000-0000-4000-8000-000000000901',
     'Ratings Buyer', 'One', 'd3000000-0000-4000-8000-000000000001', true, 'active'),
    ('d3000000-0000-4000-8000-000000000102', 'd3000000-0000-4000-8000-000000000902',
     'Ratings Buyer', 'Two', 'd3000000-0000-4000-8000-000000000001', true, 'active'),
    ('d3000000-0000-4000-8000-000000000103', 'd3000000-0000-4000-8000-000000000903',
     'Ratings Seller', 'Owner', 'd3000000-0000-4000-8000-000000000001', true, 'active');

INSERT INTO core.entities (id, name, entity_type, owner_id, primary_contact_profile_id, is_active, verification_status)
VALUES
    ('d3000000-0000-4000-8000-000000000201', 'Ratings Seller Entity', 'farm',
     'd3000000-0000-4000-8000-000000000103', 'd3000000-0000-4000-8000-000000000103', true, 'verified'),
    ('d3000000-0000-4000-8000-000000000202', 'Ratings Buyer Entity', 'individual_pro',
     'd3000000-0000-4000-8000-000000000101', 'd3000000-0000-4000-8000-000000000101', true, 'verified');

INSERT INTO core.items (id, name)
VALUES
    ('d3000000-0000-4000-8000-000000000301', 'Ratings Product One'),
    ('d3000000-0000-4000-8000-000000000302', 'Ratings Product Two');
INSERT INTO core.item_variants (id, item_id, name)
VALUES
    ('d3000000-0000-4000-8000-000000000311', 'd3000000-0000-4000-8000-000000000301', 'Variant One'),
    ('d3000000-0000-4000-8000-000000000312', 'd3000000-0000-4000-8000-000000000302', 'Variant Two');
INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES
    ('d3000000-0000-4000-8000-000000000401', 'd3000000-0000-4000-8000-000000000201',
     'd3000000-0000-4000-8000-000000000402', 'd3000000-0000-4000-8000-000000000311',
     'd3000000-0000-4000-8000-000000000301', 'd3000000-0000-4000-8000-000000000002',
     1000, 0, 'd3000000-0000-4000-8000-000000000003', 'active'),
    ('d3000000-0000-4000-8000-000000000402', 'd3000000-0000-4000-8000-000000000201',
     'd3000000-0000-4000-8000-000000000403', 'd3000000-0000-4000-8000-000000000312',
     'd3000000-0000-4000-8000-000000000302', 'd3000000-0000-4000-8000-000000000002',
     1000, 0, 'd3000000-0000-4000-8000-000000000003', 'active');
INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES
    ('d3000000-0000-4000-8000-000000000402', 'farm', 'd3000000-0000-4000-8000-000000000103',
     'Ratings Supplier', 'verified', true, 'd3000000-0000-4000-8000-000000000201', true),
    ('d3000000-0000-4000-8000-000000000403', 'farm', 'd3000000-0000-4000-8000-000000000103',
     'Ratings Supplier Two', 'verified', true, 'd3000000-0000-4000-8000-000000000201', true);
INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES
    ('d3000000-0000-4000-8000-000000000501', 'd3000000-0000-4000-8000-000000000201',
     'Ratings Listing One', 50, 'KES', 'd3000000-0000-4000-8000-000000000002',
     'd3000000-0000-4000-8000-000000000311', 1000, 'd3000000-0000-4000-8000-000000000003',
     'active', 'd3000000-0000-4000-8000-000000000401'),
    ('d3000000-0000-4000-8000-000000000502', 'd3000000-0000-4000-8000-000000000201',
     'Ratings Listing Two', 50, 'KES', 'd3000000-0000-4000-8000-000000000002',
     'd3000000-0000-4000-8000-000000000312', 1000, 'd3000000-0000-4000-8000-000000000003',
     'active', 'd3000000-0000-4000-8000-000000000402');

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, delivery_date, entity_id,
    order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
    status_changed_by_profile_id
) VALUES (
    'd3000000-0000-4000-8000-000000000601', 'd3000000-0000-4000-8000-000000000101',
    'd3000000-0000-4000-8000-000000000501', 'd3000000-0000-4000-8000-000000000402',
    2, 100, 'delivered', 'pending', '2026-11-23T08:00:00Z',
    '2026-11-23T09:00:00Z', '2026-11-23T09:00:00Z',
    'd3000000-0000-4000-8000-000000000201', 'stock',
    'd3000000-0000-4000-8000-000000000202', 'd3000000-0000-4000-8000-000000000201',
    'KES', 'd3000000-0000-4000-8000-000000000003', 'd3000000-0000-4000-8000-000000000101'
);
INSERT INTO commerce.order_items (
    id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
    stock_id, variant_id, unit_id
) VALUES
    ('d3000000-0000-4000-8000-000000000611', 'd3000000-0000-4000-8000-000000000601',
     'd3000000-0000-4000-8000-000000000501', 'd3000000-0000-4000-8000-000000000301',
     1, 'kg', 50, 'd3000000-0000-4000-8000-000000000401',
     'd3000000-0000-4000-8000-000000000311', 'd3000000-0000-4000-8000-000000000003'),
    ('d3000000-0000-4000-8000-000000000612', 'd3000000-0000-4000-8000-000000000601',
     'd3000000-0000-4000-8000-000000000502', 'd3000000-0000-4000-8000-000000000302',
     1, 'kg', 50, 'd3000000-0000-4000-8000-000000000402',
     'd3000000-0000-4000-8000-000000000312', 'd3000000-0000-4000-8000-000000000003');

-- Register canonical subjects.
DO $subjects$
DECLARE
    v_seller uuid;
    v_item1 uuid;
    v_item2 uuid;
BEGIN
    v_seller := reputation.register_subject('entity', 'seller',
        'd3000000-0000-4000-8000-000000000201');
    v_item1 := reputation.register_subject('item', 'product',
        'd3000000-0000-4000-8000-000000000301');
    v_item2 := reputation.register_subject('item', 'product',
        'd3000000-0000-4000-8000-000000000302');
    PERFORM reputation.register_subject('listing', 'listing',
        'd3000000-0000-4000-8000-000000000501');
    PERFORM reputation.register_subject('variant', 'product_variant',
        'd3000000-0000-4000-8000-000000000311');
    PERFORM reputation.register_subject('variant', 'product_variant',
        'd3000000-0000-4000-8000-000000000312');
END;
$subjects$;

-- Direct stock engagement fixture with active delivery evidence.
DO $engagement$
DECLARE
    v_snapshot jsonb;
    v_hash bytea;
    v_event_hash bytea;
    v_evidence_snapshot jsonb;
    v_evidence_hash bytea;
    v_seller_subject uuid;
    v_item1_subject uuid;
    v_item2_subject uuid;
    v_listing_subject uuid;
    v_variant1_subject uuid;
    v_variant2_subject uuid;
BEGIN
    SELECT id INTO v_seller_subject FROM reputation.subjects
     WHERE subject_type='entity' AND subject_role='seller'
       AND entity_id='d3000000-0000-4000-8000-000000000201';
    SELECT id INTO v_item1_subject FROM reputation.subjects
     WHERE subject_type='item' AND subject_role='product'
       AND item_id='d3000000-0000-4000-8000-000000000301';
    SELECT id INTO v_item2_subject FROM reputation.subjects
     WHERE subject_type='item' AND subject_role='product'
       AND item_id='d3000000-0000-4000-8000-000000000302';
    SELECT id INTO v_listing_subject FROM reputation.subjects
     WHERE subject_type='listing' AND subject_role='listing'
       AND listing_id='d3000000-0000-4000-8000-000000000501';
    SELECT id INTO v_variant1_subject FROM reputation.subjects
     WHERE subject_type='variant' AND subject_role='product_variant'
       AND variant_id='d3000000-0000-4000-8000-000000000311';
    SELECT id INTO v_variant2_subject FROM reputation.subjects
     WHERE subject_type='variant' AND subject_role='product_variant'
       AND variant_id='d3000000-0000-4000-8000-000000000312';

    v_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1,
        'source', jsonb_build_object('source_system', 'vunio',
                                     'source_reference', 'd3000000-0000-4000-8000-000000000601')
    );
    v_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));

    INSERT INTO reputation.engagements (
        id, engagement_kind, source_system, source_reference, commerce_order_id,
        source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
    ) VALUES (
        'd3000000-0000-4000-8000-000000000701', 'vunio_order', 'vunio',
        'd3000000-0000-4000-8000-000000000601', 'd3000000-0000-4000-8000-000000000601',
        v_snapshot, v_hash, '2026-11-23T09:00:00Z', 'KES', 100
    );
    INSERT INTO reputation.engagement_participants (engagement_id, party_role, profile_id, entity_id)
    VALUES ('d3000000-0000-4000-8000-000000000701', 'buyer',
            'd3000000-0000-4000-8000-000000000101',
            'd3000000-0000-4000-8000-000000000202');
    INSERT INTO reputation.engagement_participants (engagement_id, party_role, entity_id)
    VALUES ('d3000000-0000-4000-8000-000000000701', 'seller',
            'd3000000-0000-4000-8000-000000000201');
    INSERT INTO reputation.engagement_subjects (engagement_id, subject_id, relationship, source_fact)
    VALUES
        ('d3000000-0000-4000-8000-000000000701', v_seller_subject, 'seller_entity', '{}'::jsonb),
        ('d3000000-0000-4000-8000-000000000701', v_listing_subject, 'listing', '{}'::jsonb),
        ('d3000000-0000-4000-8000-000000000701', v_item1_subject, 'product', '{}'::jsonb),
        ('d3000000-0000-4000-8000-000000000701', v_item2_subject, 'product', '{}'::jsonb),
        ('d3000000-0000-4000-8000-000000000701', v_variant1_subject, 'variant', '{}'::jsonb),
        ('d3000000-0000-4000-8000-000000000701', v_variant2_subject, 'variant', '{}'::jsonb);

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, event_version, details
    ) VALUES (
        'd3000000-0000-4000-8000-000000000701', 'reputation', 'engagement_recorded',
        '2026-11-23T08:00:00Z', 'engagement-recorded', 1,
        '{"source_integrity_status":"consistent"}'::jsonb
    );
    v_event_hash := pg_catalog.sha256(convert_to(jsonb_build_object(
        'event_version', 1,
        'event_type', 'order_delivered',
        'event_at', '2026-11-23T09:00:00.000000Z',
        'source_namespace', 'vunio',
        'source_event_reference', 'order:d3000000-0000-4000-8000-000000000601:delivered',
        'actor_profile_id', NULL::text,
        'details', '{}'::jsonb
    )::text, 'UTF8'));
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, event_version, details
    ) VALUES (
        'd3000000-0000-4000-8000-000000000701', 'source', 'order_delivered',
        '2026-11-23T09:00:00Z', 'vunio:delivered', 'vunio',
        'order:d3000000-0000-4000-8000-000000000601:delivered', v_event_hash, 1, '{}'::jsonb
    );

    v_evidence_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1,
        'evidence_type', 'commerce_order_delivery',
        'source_version', 'delivery:v1',
        'source', jsonb_build_object('source_system', 'commerce',
                                     'source_reference', 'd3000000-0000-4000-8000-000000000601')
    );
    v_evidence_hash := pg_catalog.sha256(convert_to(v_evidence_snapshot::text, 'UTF8'));
    INSERT INTO reputation.evidence (
        id, engagement_id, evidence_type, source_system, source_reference,
        source_version, source_occurred_at, snapshot_version, captured_at,
        source_snapshot, source_snapshot_hash, capture_method, capture_process,
        provenance
    ) VALUES (
        'd3000000-0000-4000-8000-000000000801', 'd3000000-0000-4000-8000-000000000701',
        'commerce_order_delivery', 'commerce',
        'd3000000-0000-4000-8000-000000000601', 'delivery:v1',
        '2026-11-23T09:00:00Z', 1, clock_timestamp(), v_evidence_snapshot,
        v_evidence_hash, 'trusted_service', 'phase3b-test', '{}'::jsonb
    );
    INSERT INTO reputation.evidence_events (
        evidence_id, event_type, event_at, event_key, event_version, actor_process, details
    ) VALUES (
        'd3000000-0000-4000-8000-000000000801', 'evidence_recorded',
        clock_timestamp(), 'evidence-recorded', 1, 'phase3b-test',
        jsonb_build_object(
            'source_integrity_status', 'consistent',
            'snapshot_version', 1,
            'source_occurred_at', '2026-11-23T09:00:00Z',
            'source_snapshot_hash', encode(v_evidence_hash, 'hex'),
            'capture_method', 'trusted_service',
            'capture_process', 'phase3b-test',
            'provenance', '{}'::jsonb
        )
    );
END;
$engagement$;

CREATE FUNCTION pg_temp.actor(p_auth_id uuid, p_role text DEFAULT '')
RETURNS void LANGUAGE sql AS $f$
    SELECT set_config('request.jwt.claim.sub', COALESCE(p_auth_id::text, ''), true),
           set_config('request.jwt.claim.role', COALESCE(p_role, ''), true);
$f$;

DO $ratings$
DECLARE
    v_seller uuid;
    v_product1 uuid;
    v_product2 uuid;
    r record;
    v_rating_id uuid;
BEGIN
    SELECT id INTO v_seller FROM reputation.subjects WHERE subject_type='entity'
     AND subject_role='seller' AND entity_id='d3000000-0000-4000-8000-000000000201';
    SELECT id INTO v_product1 FROM reputation.subjects WHERE subject_type='item'
     AND subject_role='product' AND item_id='d3000000-0000-4000-8000-000000000301';
    SELECT id INTO v_product2 FROM reputation.subjects WHERE subject_type='item'
     AND subject_role='product' AND item_id='d3000000-0000-4000-8000-000000000302';

    -- Unverified seller rating without review.
    PERFORM pg_temp.actor('d3000000-0000-4000-8000-000000000902');
    SELECT * INTO r FROM reputation.submit_rating(v_seller, 4::smallint, NULL);
    IF r.verification_status <> 'unverified' THEN
        RAISE EXCEPTION 'unverified seller rating mismatch: %', r;
    END IF;

    -- One rating per reviewer/subject.
    BEGIN
        PERFORM reputation.submit_rating(v_seller, 3::smallint, NULL);
        RAISE EXCEPTION 'duplicate rating unexpectedly succeeded';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Verified seller rating.
    PERFORM pg_temp.actor('d3000000-0000-4000-8000-000000000901');
    SELECT * INTO r FROM reputation.submit_rating(v_seller, 5::smallint,
        'd3000000-0000-4000-8000-000000000701');
    IF r.verification_status <> 'verified' THEN
        RAISE EXCEPTION 'verified seller rating mismatch: %', r;
    END IF;
    v_rating_id := r.rating_id;

    -- Edit rating, one current row and revision history.
    SELECT * INTO r FROM reputation.edit_rating(v_rating_id, 3::smallint);
    IF r.outcome <> 'edited' THEN
        RAISE EXCEPTION 'rating edit mismatch: %', r;
    END IF;
    IF (SELECT count(*) FROM reputation.rating_revisions WHERE rating_id = v_rating_id) <> 2 THEN
        RAISE EXCEPTION 'rating revision history missing';
    END IF;

    -- Verified product ratings for two products in one engagement.
    SELECT * INTO r FROM reputation.submit_rating(v_product1, 5::smallint,
        'd3000000-0000-4000-8000-000000000701');
    IF r.verification_status <> 'verified' THEN
        RAISE EXCEPTION 'verified product one rating mismatch: %', r;
    END IF;
    SELECT * INTO r FROM reputation.submit_rating(v_product2, 4::smallint,
        'd3000000-0000-4000-8000-000000000701');
    IF r.verification_status <> 'verified' THEN
        RAISE EXCEPTION 'verified product two rating mismatch: %', r;
    END IF;

    -- Distribution and independent verified/unverified counts.
    SELECT * INTO r FROM reputation.get_subject_rating_summary(v_seller);
    IF r.verified_rating_count <> 1 OR r.unverified_rating_count <> 1 THEN
        RAISE EXCEPTION 'seller summary counts mismatch: %', r;
    END IF;
    IF (r.verified_distribution->>'3')::int <> 1 THEN
        RAISE EXCEPTION 'seller distribution mismatch: %', r;
    END IF;
END;
$ratings$;

DO $reviews$
DECLARE
    v_seller uuid;
    v_product1 uuid;
    v_product2 uuid;
    v_rating uuid;
    r record;
    v_review_id uuid;
BEGIN
    SELECT id INTO v_seller FROM reputation.subjects WHERE subject_type='entity'
     AND subject_role='seller' AND entity_id='d3000000-0000-4000-8000-000000000201';
    SELECT id INTO v_product1 FROM reputation.subjects WHERE subject_type='item'
     AND subject_role='product' AND item_id='d3000000-0000-4000-8000-000000000301';
    SELECT id INTO v_product2 FROM reputation.subjects WHERE subject_type='item'
     AND subject_role='product' AND item_id='d3000000-0000-4000-8000-000000000302';
    SELECT id INTO v_rating FROM reputation.ratings
     WHERE reviewer_profile_id='d3000000-0000-4000-8000-000000000101'
       AND subject_id=v_product1;

    -- Review without rating, independent and anonymous.
    PERFORM pg_temp.actor('d3000000-0000-4000-8000-000000000902');
    SELECT * INTO r FROM reputation.submit_review(
        v_seller, 'Independent seller review without rating.', 'Independent',
        NULL, NULL, 'anonymous');
    IF r.verification_status <> 'unverified' THEN
        RAISE EXCEPTION 'unverified seller review mismatch: %', r;
    END IF;

    -- A second independent seller review for the same reviewer is rejected.
    BEGIN
        PERFORM reputation.submit_review(v_seller, 'Duplicate independent review.',
            'Duplicate', NULL, NULL, 'display_name');
        RAISE EXCEPTION 'duplicate independent review unexpectedly succeeded';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Verified seller review.
    PERFORM pg_temp.actor('d3000000-0000-4000-8000-000000000901');
    SELECT * INTO r FROM reputation.submit_review(
        v_seller, 'Verified seller review.', 'Verified seller',
        NULL, 'd3000000-0000-4000-8000-000000000701', 'display_name');
    IF r.verification_status <> 'verified' THEN
        RAISE EXCEPTION 'verified seller review mismatch: %', r;
    END IF;

    -- Second verified seller review in same engagement is rejected.
    BEGIN
        PERFORM reputation.submit_review(v_seller, 'Duplicate verified seller review.',
            'Duplicate', NULL, 'd3000000-0000-4000-8000-000000000701', 'display_name');
        RAISE EXCEPTION 'duplicate verified seller review unexpectedly succeeded';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Product review with linked rating.
    SELECT * INTO r FROM reputation.submit_review(
        v_product1, 'Verified product one review.', 'Product one',
        v_rating, 'd3000000-0000-4000-8000-000000000701', 'display_name');
    IF r.verification_status <> 'verified' THEN
        RAISE EXCEPTION 'verified product review mismatch: %', r;
    END IF;
    v_review_id := r.review_id;

    -- Multiple products in one engagement.
    SELECT * INTO r FROM reputation.submit_review(
        v_product2, 'Verified product two review.', 'Product two',
        NULL, 'd3000000-0000-4000-8000-000000000701', 'display_name');
    IF r.verification_status <> 'verified' THEN
        RAISE EXCEPTION 'second product review mismatch: %', r;
    END IF;

    -- Rating without review remains valid and a review can be ratingless.
    IF NOT EXISTS (
        SELECT 1 FROM reputation.ratings
         WHERE subject_id = v_product1
           AND reviewer_profile_id = 'd3000000-0000-4000-8000-000000000101'
    ) THEN
        RAISE EXCEPTION 'product rating disappeared';
    END IF;

    -- Edit review and preserve revisions.
    SELECT * INTO r FROM reputation.edit_review(v_review_id, 'Edited product review body.',
        'Edited title', v_rating, 'display_name');
    IF r.outcome <> 'edited' THEN RAISE EXCEPTION 'review edit mismatch: %', r; END IF;
    IF (SELECT count(*) FROM reputation.review_revisions WHERE review_id = v_review_id) <> 2 THEN
        RAISE EXCEPTION 'review revision history missing';
    END IF;

    -- Public review read is sanitized and returns linked rating.
    SELECT * INTO r FROM reputation.list_subject_reviews(v_product1);
    IF r.review_id IS NULL OR r.rating <> 5 OR r.verification_status <> 'verified' THEN
        RAISE EXCEPTION 'public product review mismatch: %', r;
    END IF;
    IF r.reviewer_display_name IS NULL THEN
        RAISE EXCEPTION 'public display name missing';
    END IF;

    -- Anonymous public read does not leak a display name.
    IF NOT EXISTS (
        SELECT 1 FROM reputation.list_subject_reviews(v_seller) x
         WHERE x.reviewer_display_name IS NULL
    ) THEN
        RAISE EXCEPTION 'anonymous review was not publicly anonymous';
    END IF;
END;
$reviews$;

DO $moderation_response$
DECLARE
    v_seller uuid;
    v_product1 uuid;
    v_review uuid;
    v_rating uuid;
    v_response uuid;
    r record;
BEGIN
    SELECT id INTO v_seller FROM reputation.subjects WHERE subject_type='entity'
     AND subject_role='seller' AND entity_id='d3000000-0000-4000-8000-000000000201';
    SELECT id INTO v_product1 FROM reputation.subjects WHERE subject_type='item'
     AND subject_role='product' AND item_id='d3000000-0000-4000-8000-000000000301';
    SELECT id INTO v_review FROM reputation.reviews
     WHERE subject_id = v_seller AND verification_status = 'verified' LIMIT 1;
    SELECT id INTO v_rating FROM reputation.ratings
     WHERE subject_id = v_product1 AND reviewer_profile_id = 'd3000000-0000-4000-8000-000000000101';

    -- Seller owner responds to a verified seller review.
    PERFORM pg_temp.actor('d3000000-0000-4000-8000-000000000903');
    v_response := reputation.respond_to_review(v_review, 'Thank you for the review.');
    IF v_response IS NULL THEN RAISE EXCEPTION 'seller response missing'; END IF;

    -- Moderate response and rating.
    PERFORM set_config('test.allow_moderation', 'true', true);
    PERFORM reputation.moderate_rating_review('response', v_response, 'publish', 'test');
    PERFORM reputation.moderate_rating_review('rating', v_rating, 'hide', 'test');

    SELECT * INTO r FROM reputation.get_subject_rating_summary(v_product1);
    IF r.verified_rating_count <> 0 OR r.unverified_rating_count <> 0 THEN
        RAISE EXCEPTION 'hidden rating still counted: %', r;
    END IF;

    -- Review moderation removes it from public list.
    PERFORM reputation.moderate_rating_review('review', v_review, 'hide', 'test');
    IF EXISTS (SELECT 1 FROM reputation.list_subject_reviews(v_seller) x WHERE x.review_id = v_review) THEN
        RAISE EXCEPTION 'hidden review still public';
    END IF;

    -- Report remains available for moderation.
    PERFORM pg_temp.actor('d3000000-0000-4000-8000-000000000902');
    PERFORM reputation.report_rating_review('review', v_review, 'test_report', 'reason');
END;
$moderation_response$;

DO $my_state$
DECLARE
    v_seller uuid;
    r record;
BEGIN
    SELECT id INTO v_seller FROM reputation.subjects WHERE subject_type='entity'
     AND subject_role='seller' AND entity_id='d3000000-0000-4000-8000-000000000201';
    PERFORM pg_temp.actor('d3000000-0000-4000-8000-000000000901');
    SELECT * INTO r FROM reputation.get_my_subject_state(v_seller);
    IF r.rating_id IS NULL OR r.review_id IS NULL THEN
        RAISE EXCEPTION 'author state missing: %', r;
    END IF;
END;
$my_state$;

DO $security$
BEGIN
    IF has_table_privilege('authenticated', 'reputation.ratings', 'INSERT')
       OR has_table_privilege('authenticated', 'reputation.reviews', 'INSERT')
       OR has_table_privilege('authenticated', 'reputation.subject_rating_summaries', 'INSERT')
       OR has_table_privilege('service_role', 'reputation.ratings', 'INSERT') THEN
        RAISE EXCEPTION 'direct ratings/reviews writes are exposed';
    END IF;
    IF NOT has_function_privilege('anon', 'system.get_reputation_rating_summary(uuid)', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'system.list_reputation_reviews(uuid,timestamptz,uuid,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'public reputation read grants missing';
    END IF;
    IF has_function_privilege('anon', 'reputation.submit_rating(uuid,smallint,uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'reputation.submit_rating(uuid,smallint,uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'system.submit_reputation_rating(uuid,smallint,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'submission RPC exposed to anon or base role';
    END IF;
    IF pg_get_function_result('system.get_reputation_rating_summary(uuid)'::regprocedure)
       LIKE '%reviewer_profile_id%'
       OR pg_get_function_result('system.list_reputation_reviews(uuid,timestamptz,uuid,integer)'::regprocedure)
       LIKE '%reviewer_profile_id%' THEN
        RAISE EXCEPTION 'public read exposes reviewer profile';
    END IF;
END;
$security$;

ROLLBACK;

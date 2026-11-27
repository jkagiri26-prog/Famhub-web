-- ============================================================================
-- reputation_ratings_reviews_concurrency_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE concurrency test for Phase 3B.
-- Creates committed fixtures because dblink sessions need visibility.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;
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
RETURNS boolean LANGUAGE sql STABLE AS $f$ SELECT false $f$;

ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS middle_name text;
ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS last_name text;
ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS profile_image text;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('e3000000-0000-4000-8000-000000000001', 'Ratings Concurrency Country', 'SQ', 'SQT', '9986', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, last_name, country_id, is_active, account_status)
VALUES ('e3000000-0000-4000-8000-000000000101', 'e3000000-0000-4000-8000-000000000901',
        'Concurrent Reviewer', 'One', 'e3000000-0000-4000-8000-000000000001', true, 'active');

INSERT INTO core.items (id, name)
VALUES ('e3000000-0000-4000-8000-000000000201', 'Concurrent Product');

-- Hardening fixture: seller operation association for the product subject,
-- plus eligible engagements used by the verified-submission race test.
INSERT INTO users.profiles (id, auth_user_id, first_name, last_name, country_id, is_active, account_status)
VALUES ('e3000000-0000-4000-8000-000000000102', 'e3000000-0000-4000-8000-000000000902',
        'Concurrent Seller', 'Owner', 'e3000000-0000-4000-8000-000000000001', true, 'active');
INSERT INTO core.entities (id, name, entity_type, owner_id, primary_contact_profile_id, is_active, verification_status)
VALUES ('e3000000-0000-4000-8000-000000000301', 'Concurrent Seller Entity', 'trading_company',
        'e3000000-0000-4000-8000-000000000102', 'e3000000-0000-4000-8000-000000000102', true, 'verified');
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('e3000000-0000-4000-8000-000000000501', 'concurrent-unit', 'cu', 'mass');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('e3000000-0000-4000-8000-000000000401', 'e3000000-0000-4000-8000-000000000201', 'Concurrent Variant');
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('e3000000-0000-4000-8000-000000000701', 'Concurrent Location',
        'e3000000-0000-4000-8000-000000000001', true);
INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES ('e3000000-0000-4000-8000-000000000702', 'company',
          'e3000000-0000-4000-8000-000000000102', 'Concurrent Supplier', 'verified',
          true, 'e3000000-0000-4000-8000-000000000301', true);
INSERT INTO commerce.stock_registry (
    id, entity_id, variant_id, product_id, quantity, reserved_quantity, unit_id, status
) VALUES ('e3000000-0000-4000-8000-000000000601', 'e3000000-0000-4000-8000-000000000301',
          'e3000000-0000-4000-8000-000000000401', 'e3000000-0000-4000-8000-000000000201',
          100, 0, 'e3000000-0000-4000-8000-000000000501', 'active');
INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id, variant_id, unit_id, status
) VALUES ('e3000000-0000-4000-8000-000000000801', 'e3000000-0000-4000-8000-000000000301',
          'Concurrent Listing', 50, 'KES', 'e3000000-0000-4000-8000-000000000701',
          'e3000000-0000-4000-8000-000000000401', 'e3000000-0000-4000-8000-000000000501', 'active');

DO $fixture$
BEGIN
    PERFORM reputation.register_subject('item', 'product',
        'e3000000-0000-4000-8000-000000000201');
END;
$fixture$;

DO $fixtures2$
BEGIN
    PERFORM reputation.register_subject('entity', 'seller',
        'e3000000-0000-4000-8000-000000000301');
END;
$fixtures2$;

CREATE FUNCTION pg_temp.seed_conc_engagement(
    p_engagement_id uuid,
    p_order_id uuid,
    p_evidence_id uuid
) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    v_seller_subject uuid;
    v_snapshot jsonb;
    v_hash bytea;
    v_ev_snapshot jsonb;
    v_ev_hash bytea;
    v_src_hash bytea;
BEGIN
    SELECT id INTO v_seller_subject FROM reputation.subjects
     WHERE subject_type='entity' AND subject_role='seller'
       AND entity_id='e3000000-0000-4000-8000-000000000301';

    INSERT INTO commerce.orders (
        id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
        payment_status, order_date, delivered_at, delivery_date, entity_id,
        order_kind, seller_entity_id, currency, unit_id, status_changed_by_profile_id
    ) VALUES (
        p_order_id, 'e3000000-0000-4000-8000-000000000101',
        'e3000000-0000-4000-8000-000000000801', 'e3000000-0000-4000-8000-000000000702',
        1, 50, 'delivered', 'pending', '2026-11-23T08:00:00Z',
        '2026-11-23T09:00:00Z', '2026-11-23T09:00:00Z',
        'e3000000-0000-4000-8000-000000000301', 'stock',
        'e3000000-0000-4000-8000-000000000301', 'KES',
        'e3000000-0000-4000-8000-000000000501',
        'e3000000-0000-4000-8000-000000000101'
    );

    v_snapshot := jsonb_build_object('snapshot_schema_version', 1,
        'source', jsonb_build_object('source_system', 'vunio',
                                     'source_reference', p_order_id::text));
    v_hash := sha256(convert_to(v_snapshot::text, 'UTF8'));
    INSERT INTO reputation.engagements (
        id, engagement_kind, source_system, source_reference, commerce_order_id,
        source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
    ) VALUES (
        p_engagement_id, 'vunio_order', 'vunio', p_order_id::text, p_order_id,
        v_snapshot, v_hash, '2026-11-23T09:00:00Z', 'KES', 50
    );
    INSERT INTO reputation.engagement_participants (engagement_id, party_role, profile_id)
    VALUES (p_engagement_id, 'buyer', 'e3000000-0000-4000-8000-000000000101');
    INSERT INTO reputation.engagement_participants (engagement_id, party_role, entity_id)
    VALUES (p_engagement_id, 'seller', 'e3000000-0000-4000-8000-000000000301');
    INSERT INTO reputation.engagement_subjects (engagement_id, subject_id, relationship, source_fact)
    VALUES (p_engagement_id, v_seller_subject, 'seller_entity', '{}'::jsonb);

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, event_version, details
    ) VALUES (p_engagement_id, 'reputation', 'engagement_recorded',
              '2026-11-23T08:00:00Z', 'engagement-recorded', 1,
              '{"source_integrity_status":"consistent"}'::jsonb);

    v_src_hash := sha256(convert_to(jsonb_build_object(
        'event_version', 1, 'event_type', 'order_delivered',
        'event_at', '2026-11-23T09:00:00.000000Z', 'source_namespace', 'vunio',
        'source_event_reference', 'order:' || p_order_id::text || ':delivered',
        'actor_profile_id', NULL::text, 'details', '{}'::jsonb
    )::text, 'UTF8'));
    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key,
        source_namespace, source_event_reference, payload_hash, event_version, details
    ) VALUES (p_engagement_id, 'source', 'order_delivered',
              '2026-11-23T09:00:00Z', 'vunio:delivered', 'vunio',
              'order:' || p_order_id::text || ':delivered', v_src_hash, 1, '{}'::jsonb);

    v_ev_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1, 'evidence_type', 'commerce_order_delivery',
        'source_version', 'delivery:v1',
        'source', jsonb_build_object('source_system', 'commerce',
                                     'source_reference', p_order_id::text)
    );
    v_ev_hash := sha256(convert_to(v_ev_snapshot::text, 'UTF8'));
    INSERT INTO reputation.evidence (
        id, engagement_id, evidence_type, source_system, source_reference,
        source_version, source_occurred_at, snapshot_version, captured_at,
        source_snapshot, source_snapshot_hash, capture_method, capture_process, provenance
    ) VALUES (
        p_evidence_id, p_engagement_id, 'commerce_order_delivery', 'commerce',
        p_order_id::text, 'delivery:v1', '2026-11-23T09:00:00Z', 1, clock_timestamp(),
        v_ev_snapshot, v_ev_hash, 'trusted_service', 'hardening-concurrency', '{}'::jsonb
    );
    INSERT INTO reputation.evidence_events (
        evidence_id, event_type, event_at, event_key, event_version, actor_process, details
    ) VALUES (p_evidence_id, 'evidence_recorded', clock_timestamp(), 'evidence-recorded', 1,
              'hardening-concurrency', jsonb_build_object(
                  'source_integrity_status', 'consistent', 'snapshot_version', 1,
                  'source_occurred_at', '2026-11-23T09:00:00Z',
                  'source_snapshot_hash', encode(v_ev_hash, 'hex'),
                  'capture_method', 'trusted_service',
                  'capture_process', 'hardening-concurrency', 'provenance', '{}'::jsonb));
END;
$f$;

DO $seed_engagements$
BEGIN
    PERFORM pg_temp.seed_conc_engagement(
        'e3000000-0000-4000-8000-000000000911',
        'e3000000-0000-4000-8000-000000000901',
        'e3000000-0000-4000-8000-000000000921');
    PERFORM pg_temp.seed_conc_engagement(
        'e3000000-0000-4000-8000-000000000912',
        'e3000000-0000-4000-8000-000000000902',
        'e3000000-0000-4000-8000-000000000922');
END;
$seed_engagements$;

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
    PERFORM dblink_connect('p3b_a', v_conn);
    PERFORM dblink_connect('p3b_b', v_conn);
END;
$connect$;

-- Concurrent rating: exactly one current rating.
DO $rating_race$
DECLARE
    v_busy integer;
BEGIN
    PERFORM dblink_exec('p3b_a', 'BEGIN');
    PERFORM dblink_exec('p3b_a', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_a', $q$
        SELECT * FROM reputation.submit_rating(
            (SELECT id FROM reputation.subjects
              WHERE subject_type='item' AND subject_role='product'
                AND item_id='e3000000-0000-4000-8000-000000000201'),
            5::smallint, NULL
        )
    $q$);
    PERFORM pg_sleep(0.2);

    PERFORM dblink_exec('p3b_b', 'BEGIN');
    PERFORM dblink_exec('p3b_b', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_b', $q$
        DO $block$
        BEGIN
            PERFORM reputation.submit_rating(
                (SELECT id FROM reputation.subjects
                  WHERE subject_type='item' AND subject_role='product'
                    AND item_id='e3000000-0000-4000-8000-000000000201'),
                4::smallint, NULL
            );
        EXCEPTION WHEN unique_violation THEN
            NULL;
        END;
        $block$
    $q$);
    PERFORM pg_sleep(0.5);
    SELECT dblink_is_busy('p3b_b') INTO v_busy;
    IF v_busy <> 1 THEN
        RAISE EXCEPTION 'concurrent rating did not serialize';
    END IF;

    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(rating_id uuid, outcome text, verification_status text);
    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(rating_id uuid, outcome text, verification_status text);
    PERFORM dblink_exec('p3b_a', 'COMMIT');
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM dblink_exec('p3b_b', 'COMMIT');

    IF (SELECT count(*) FROM reputation.ratings
         WHERE subject_id = (SELECT id FROM reputation.subjects
                              WHERE subject_type='item' AND subject_role='product'
                                AND item_id='e3000000-0000-4000-8000-000000000201')
           AND reviewer_profile_id = 'e3000000-0000-4000-8000-000000000101') <> 1 THEN
        RAISE EXCEPTION 'concurrent ratings produced duplicate current ratings';
    END IF;
END;
$rating_race$;

-- Concurrent unverified review: exactly one independent review.
DO $review_race$
DECLARE
    v_busy integer;
BEGIN
    PERFORM dblink_exec('p3b_a', 'BEGIN');
    PERFORM dblink_exec('p3b_a', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_a', $q$
        SELECT * FROM reputation.submit_review(
            (SELECT id FROM reputation.subjects
              WHERE subject_type='item' AND subject_role='product'
                AND item_id='e3000000-0000-4000-8000-000000000201'),
            'Concurrent review A', 'A', NULL, NULL, 'display_name'
        )
    $q$);
    PERFORM pg_sleep(0.2);

    PERFORM dblink_exec('p3b_b', 'BEGIN');
    PERFORM dblink_exec('p3b_b', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_b', $q$
        DO $block$
        BEGIN
            PERFORM reputation.submit_review(
                (SELECT id FROM reputation.subjects
                  WHERE subject_type='item' AND subject_role='product'
                    AND item_id='e3000000-0000-4000-8000-000000000201'),
                'Concurrent review B', 'B', NULL, NULL, 'display_name'
            );
        EXCEPTION WHEN unique_violation THEN
            NULL;
        END;
        $block$
    $q$);
    PERFORM pg_sleep(0.5);
    SELECT dblink_is_busy('p3b_b') INTO v_busy;
    IF v_busy <> 1 THEN
        RAISE EXCEPTION 'concurrent review did not serialize';
    END IF;

    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(review_id uuid, outcome text, verification_status text);
    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(review_id uuid, outcome text, verification_status text);
    PERFORM dblink_exec('p3b_a', 'COMMIT');
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM dblink_exec('p3b_b', 'COMMIT');

    IF (SELECT count(*) FROM reputation.reviews
         WHERE subject_id = (SELECT id FROM reputation.subjects
                              WHERE subject_type='item' AND subject_role='product'
                                AND item_id='e3000000-0000-4000-8000-000000000201')
           AND reviewer_profile_id = 'e3000000-0000-4000-8000-000000000101'
           AND engagement_id IS NULL) <> 1 THEN
        RAISE EXCEPTION 'concurrent reviews produced duplicate independent reviews';
    END IF;
END;
$review_race$;


-- ===========================================================================
-- Hardening race: engagement void cannot race past verified submission.
-- ===========================================================================
DO $engagement_race$
DECLARE
    v_busy integer;
    v_seller uuid;
    v_rating_id uuid;
    v_status text;
BEGIN
    SELECT id INTO v_seller FROM reputation.subjects
     WHERE subject_type='entity' AND subject_role='seller'
       AND entity_id='e3000000-0000-4000-8000-000000000301';

    PERFORM dblink_exec('p3b_a', $cmd$BEGIN$cmd$);
    PERFORM dblink_exec('p3b_a',
        format($cmd$SET LOCAL request.jwt.claim.sub = %L$cmd$,
               'e3000000-0000-4000-8000-000000000901'));
    PERFORM dblink_send_query('p3b_a',
        format($q$SELECT * FROM reputation.submit_rating(%L::uuid, 5::smallint, %L::uuid)$q$,
               v_seller, 'e3000000-0000-4000-8000-000000000911'));
    PERFORM pg_sleep(0.2);

    PERFORM dblink_exec('p3b_b', $cmd$BEGIN$cmd$);
    PERFORM dblink_send_query('p3b_b',
        format($q$INSERT INTO reputation.engagement_events
        (engagement_id, event_origin, event_type, event_at, event_key, event_version, details)
        VALUES (%L::uuid, 'reputation', 'engagement_voided', clock_timestamp(), 'race-void', 1,
                '{"invalidity_code":"race"}'::jsonb)$q$,
               'e3000000-0000-4000-8000-000000000911'));
    PERFORM pg_sleep(0.5);
    SELECT dblink_is_busy('p3b_b') INTO v_busy;
    IF v_busy <> 1 THEN
        RAISE EXCEPTION 'engagement void did not serialize behind verified submission';
    END IF;

    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(rating_id uuid, outcome text, verification_status text);
    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(rating_id uuid, outcome text, verification_status text);
    PERFORM dblink_exec('p3b_a', $cmd$COMMIT$cmd$);
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM dblink_exec('p3b_b', $cmd$COMMIT$cmd$);

    SELECT r.id, r.verification_status INTO v_rating_id, v_status
      FROM reputation.ratings r
     WHERE r.subject_id = v_seller
       AND r.reviewer_profile_id = 'e3000000-0000-4000-8000-000000000101'
     ORDER BY r.created_at DESC LIMIT 1;
    IF v_rating_id IS NULL OR v_status <> 'verified' THEN
        RAISE EXCEPTION 'verified submission was not recorded under lock';
    END IF;

    INSERT INTO reputation.engagement_events (
        engagement_id, event_origin, event_type, event_at, event_key, event_version, details
    ) VALUES ('e3000000-0000-4000-8000-000000000912'::uuid, 'reputation',
              'engagement_voided', clock_timestamp(), 'void-first', 1,
              '{"invalidity_code":"void_first"}'::jsonb);
    PERFORM set_config('request.jwt.claim.sub',
        'e3000000-0000-4000-8000-000000000901', true);
    BEGIN
        PERFORM reputation.submit_rating(v_seller, 4::smallint,
            'e3000000-0000-4000-8000-000000000912'::uuid);
        RAISE EXCEPTION 'TEST FAILED: voided engagement submission was accepted';
    EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
    END;
    IF EXISTS (SELECT 1 FROM reputation.ratings
                WHERE subject_id = v_seller
                  AND reviewer_profile_id = 'e3000000-0000-4000-8000-000000000101'
                  AND current_verification_snapshot_id IS NULL) THEN
        RAISE EXCEPTION 'TEST FAILED: voided engagement produced an unverified fallback';
    END IF;
END;
$engagement_race$;

SELECT dblink_disconnect('p3b_b');
SELECT dblink_disconnect('p3b_a');

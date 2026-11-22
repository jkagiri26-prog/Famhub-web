-- ============================================================================
-- reputation_delivery_evidence_production_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE integration test for Phase 2D.
--
-- Exercises the real Phase 2C-1 ingestion and Phase 2B evidence gateways.
-- ============================================================================
BEGIN;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('d5000000-0000-4000-8000-000000000001', 'Evidence Test Country', 'EC', 'ECT', '9993', true);

INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('d5000000-0000-4000-8000-000000000002', 'Evidence Test Location',
        'd5000000-0000-4000-8000-000000000001', true);

INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('d5000000-0000-4000-8000-000000000003', 'evidence-test-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('d5000000-0000-4000-8000-000000000101', 'd5000000-0000-4000-8000-000000000901',
     'Evidence Buyer', 'd5000000-0000-4000-8000-000000000001', true, 'active'),
    ('d5000000-0000-4000-8000-000000000102', 'd5000000-0000-4000-8000-000000000902',
     'Evidence Seller', 'd5000000-0000-4000-8000-000000000001', true, 'active');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES
    ('d5000000-0000-4000-8000-000000000201', 'Evidence Buyer Entity',
     'individual_pro', 'd5000000-0000-4000-8000-000000000101', true, 'verified'),
    ('d5000000-0000-4000-8000-000000000202', 'Evidence Seller Entity',
     'farm', 'd5000000-0000-4000-8000-000000000102', true, 'verified');

INSERT INTO core.items (id, name)
VALUES ('d5000000-0000-4000-8000-000000000301', 'Evidence Test Item');

INSERT INTO core.item_variants (id, item_id, name)
VALUES ('d5000000-0000-4000-8000-000000000302',
        'd5000000-0000-4000-8000-000000000301', 'Evidence Test Variant');

INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    'd5000000-0000-4000-8000-000000000401', 'farm',
    'd5000000-0000-4000-8000-000000000102', 'Evidence Test Supplier',
    'verified', true, 'd5000000-0000-4000-8000-000000000202', true
);

INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    'd5000000-0000-4000-8000-000000000402',
    'd5000000-0000-4000-8000-000000000202',
    'd5000000-0000-4000-8000-000000000401',
    'd5000000-0000-4000-8000-000000000302',
    'd5000000-0000-4000-8000-000000000301',
    'd5000000-0000-4000-8000-000000000002',
    1000.00, 0.00, 'd5000000-0000-4000-8000-000000000003', 'active'
);

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    'd5000000-0000-4000-8000-000000000501',
    'd5000000-0000-4000-8000-000000000202',
    'Evidence Test Listing', 50.00, 'KES',
    'd5000000-0000-4000-8000-000000000002',
    'd5000000-0000-4000-8000-000000000302',
    1000.00, 'd5000000-0000-4000-8000-000000000003', 'active',
    'd5000000-0000-4000-8000-000000000402'
);

CREATE FUNCTION pg_temp.insert_evidence_order(
    p_id uuid,
    p_order_kind text
)
RETURNS void
LANGUAGE sql
AS $function$
    INSERT INTO commerce.orders (
        id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
        payment_status, order_date, delivered_at, delivery_date, entity_id,
        order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
        status_changed_by_profile_id
    ) VALUES (
        p_id,
        'd5000000-0000-4000-8000-000000000101',
        'd5000000-0000-4000-8000-000000000501',
        'd5000000-0000-4000-8000-000000000401',
        1.00, 50.00, 'delivered', 'pending',
        '2026-11-22T08:00:00Z', '2026-11-22T09:00:00Z', '2026-11-22T09:00:00Z',
        'd5000000-0000-4000-8000-000000000202',
        p_order_kind,
        'd5000000-0000-4000-8000-000000000201',
        'd5000000-0000-4000-8000-000000000202',
        'KES', 'd5000000-0000-4000-8000-000000000003',
        'd5000000-0000-4000-8000-000000000101'
    );
$function$;

CREATE FUNCTION pg_temp.insert_evidence_order_item(
    p_id uuid,
    p_order_id uuid
)
RETURNS void
LANGUAGE sql
AS $function$
    INSERT INTO commerce.order_items (
        id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
        stock_id, variant_id, unit_id
    ) VALUES (
        p_id, p_order_id,
        'd5000000-0000-4000-8000-000000000501',
        'd5000000-0000-4000-8000-000000000301',
        1.00, 'kg', 50.00,
        'd5000000-0000-4000-8000-000000000402',
        'd5000000-0000-4000-8000-000000000302',
        'd5000000-0000-4000-8000-000000000003'
    );
$function$;

-- Four delivered orders: one normal, one revocation fixture, one supersession
-- fixture, and one service order that must never receive stock evidence.
SELECT pg_temp.insert_evidence_order('d5000000-0000-4000-8000-000000000601', 'stock');
SELECT pg_temp.insert_evidence_order('d5000000-0000-4000-8000-000000000602', 'stock');
SELECT pg_temp.insert_evidence_order('d5000000-0000-4000-8000-000000000603', 'stock');
SELECT pg_temp.insert_evidence_order('d5000000-0000-4000-8000-000000000604', 'service');

SELECT pg_temp.insert_evidence_order_item('d5000000-0000-4000-8000-000000000701', 'd5000000-0000-4000-8000-000000000601');
SELECT pg_temp.insert_evidence_order_item('d5000000-0000-4000-8000-000000000702', 'd5000000-0000-4000-8000-000000000602');
SELECT pg_temp.insert_evidence_order_item('d5000000-0000-4000-8000-000000000703', 'd5000000-0000-4000-8000-000000000603');
SELECT pg_temp.insert_evidence_order_item('d5000000-0000-4000-8000-000000000704', 'd5000000-0000-4000-8000-000000000604');

DO $evidence_success$
DECLARE
    v_ingest record;
    v_capture record;
    v_evidence record;
    v_hash bytea;
    v_event_count integer;
BEGIN
    SELECT * INTO v_ingest
      FROM system.ingest_reputation_stock_order_engagement(
          'd5000000-0000-4000-8000-000000000601'
      );
    IF v_ingest.outcome <> 'created' OR v_ingest.engagement_id IS NULL THEN
        RAISE EXCEPTION 'engagement ingestion failed';
    END IF;

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_ingest.engagement_id, NULL, 'phase2d-success'
      );
    IF v_capture.outcome <> 'recorded'
       OR v_capture.evidence_id IS NULL
       OR v_capture.evidence_status <> 'active' THEN
        RAISE EXCEPTION 'evidence capture failed: %', v_capture;
    END IF;

    SELECT * INTO v_evidence
      FROM reputation.evidence
     WHERE id = v_capture.evidence_id;
    v_hash := pg_catalog.sha256(convert_to(v_evidence.source_snapshot::text, 'UTF8'));
    IF v_evidence.evidence_type <> 'commerce_order_delivery'
       OR v_evidence.source_system <> 'commerce'
       OR v_evidence.source_reference <> 'd5000000-0000-4000-8000-000000000601'
       OR v_evidence.source_version <> 'delivery:v1'
       OR v_evidence.source_snapshot_hash IS DISTINCT FROM v_hash THEN
        RAISE EXCEPTION 'evidence identity/hash mismatch';
    END IF;

    SELECT count(*) INTO v_event_count
      FROM reputation.evidence_events
     WHERE evidence_id = v_capture.evidence_id
       AND event_type = 'evidence_recorded';
    IF v_event_count <> 1 THEN
        RAISE EXCEPTION 'evidence_recorded event count mismatch';
    END IF;

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_ingest.engagement_id, NULL, 'phase2d-duplicate'
      );
    IF v_capture.outcome <> 'already_recorded' THEN
        RAISE EXCEPTION 'duplicate evidence capture was not idempotent';
    END IF;

    SELECT count(*) INTO v_event_count
      FROM reputation.evidence
     WHERE engagement_id = v_ingest.engagement_id
       AND source_reference = 'd5000000-0000-4000-8000-000000000601';
    IF v_event_count <> 1 THEN
        RAISE EXCEPTION 'duplicate evidence rows exist';
    END IF;
END;
$evidence_success$;

DO $evidence_conflict$
DECLARE
    v_ingest record;
    v_engagement_id uuid;
    v_evidence_id uuid;
    v_capture record;
    v_event_count integer;
    v_hash_before bytea;
BEGIN
    SELECT * INTO v_ingest
      FROM system.ingest_reputation_stock_order_engagement(
          'd5000000-0000-4000-8000-000000000602'
      );
    IF v_ingest.outcome <> 'created' OR v_ingest.engagement_id IS NULL THEN
        RAISE EXCEPTION 'conflict fixture engagement ingestion failed';
    END IF;
    v_engagement_id := v_ingest.engagement_id;

    SELECT evidence_id INTO v_evidence_id
      FROM system.capture_reputation_order_evidence(
          v_engagement_id, NULL, 'phase2d-conflict-v1'
      );
    SELECT source_snapshot_hash INTO v_hash_before
      FROM reputation.evidence WHERE id=v_evidence_id;

    UPDATE commerce.orders
       SET total_amount = 60.00,
           updated_at = clock_timestamp()
     WHERE id='d5000000-0000-4000-8000-000000000602';

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_engagement_id, NULL, 'phase2d-conflict-v1'
      );
    IF v_capture.outcome <> 'conflict_recorded'
       OR v_capture.evidence_status <> 'conflicted'
       OR v_capture.conflict_event_id IS NULL THEN
        RAISE EXCEPTION 'evidence conflict was not recorded';
    END IF;

    IF (SELECT source_snapshot_hash FROM reputation.evidence WHERE id=v_evidence_id)
       IS DISTINCT FROM v_hash_before THEN
        RAISE EXCEPTION 'conflict rewrote existing evidence';
    END IF;

    SELECT count(*) INTO v_event_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id
       AND event_type='evidence_conflict_detected';
    IF v_event_count <> 1 THEN
        RAISE EXCEPTION 'conflict event was not exactly once';
    END IF;

    PERFORM system.capture_reputation_order_evidence(
        v_engagement_id, NULL, 'phase2d-conflict-repeat'
    );
    SELECT count(*) INTO v_event_count
      FROM reputation.evidence_events
     WHERE evidence_id=v_evidence_id
       AND event_type='evidence_conflict_detected';
    IF v_event_count <> 1 THEN
        RAISE EXCEPTION 'duplicate conflict event was created';
    END IF;
END;
$evidence_conflict$;

DO $evidence_revoked$
DECLARE
    v_engagement_id uuid;
    v_evidence_id uuid;
    v_capture record;
    v_status text;
BEGIN
    SELECT id INTO v_engagement_id
      FROM reputation.engagements
     WHERE commerce_order_id='d5000000-0000-4000-8000-000000000601';
    SELECT id INTO v_evidence_id
      FROM reputation.evidence
     WHERE engagement_id=v_engagement_id
       AND source_version='delivery:v1';

    PERFORM system.revoke_reputation_evidence(
        v_evidence_id, 'test_revoke', 'phase2d revocation fixture', NULL
    );

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_engagement_id, NULL, 'phase2d-revoked'
      );
    IF v_capture.outcome <> 'already_recorded'
       OR v_capture.evidence_status <> 'revoked' THEN
        RAISE EXCEPTION 'revoked evidence was reopened';
    END IF;

    SELECT evidence_status INTO v_status
      FROM reputation.v_evidence_current_state
     WHERE evidence_id=v_evidence_id;
    IF v_status <> 'revoked' THEN
        RAISE EXCEPTION 'revoked evidence status mismatch';
    END IF;
END;
$evidence_revoked$;

DO $evidence_superseded$
DECLARE
    v_ingest record;
    v_engagement_id uuid;
    v_old_id uuid;
    v_new_id uuid;
    v_capture record;
    v_status text;
BEGIN
    SELECT * INTO v_ingest
      FROM system.ingest_reputation_stock_order_engagement(
          'd5000000-0000-4000-8000-000000000603'
      );
    IF v_ingest.outcome <> 'created' OR v_ingest.engagement_id IS NULL THEN
        RAISE EXCEPTION 'supersession fixture engagement ingestion failed';
    END IF;
    v_engagement_id := v_ingest.engagement_id;

    SELECT evidence_id INTO v_old_id
      FROM system.capture_reputation_order_evidence(
          v_engagement_id, NULL, 'phase2d-supersede-v1'
      );

    SELECT evidence_id INTO v_new_id
      FROM system.supersede_reputation_order_evidence(
          v_engagement_id, v_old_id, 'delivery:v2', NULL, 'phase2d-supersede-v2'
      );
    IF v_new_id IS NULL OR v_new_id = v_old_id THEN
        RAISE EXCEPTION 'supersession did not create replacement evidence';
    END IF;

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_engagement_id, NULL, 'phase2d-supersede-retry'
      );
    IF v_capture.outcome <> 'already_recorded'
       OR v_capture.evidence_status <> 'superseded' THEN
        RAISE EXCEPTION 'superseded evidence was reopened';
    END IF;

    SELECT evidence_status INTO v_status
      FROM reputation.v_evidence_current_state
     WHERE evidence_id=v_old_id;
    IF v_status <> 'superseded' THEN
        RAISE EXCEPTION 'superseded evidence status mismatch';
    END IF;
END;
$evidence_superseded$;

DO $no_service_evidence$
DECLARE
    v_ingest record;
    v_count integer;
BEGIN
    SELECT * INTO v_ingest
      FROM system.ingest_reputation_stock_order_engagement(
          'd5000000-0000-4000-8000-000000000604'
      );
    IF v_ingest.outcome <> 'ineligible'
       OR v_ingest.reason_code <> 'not_stock_order' THEN
        RAISE EXCEPTION 'service order ingestion was not rejected as not_stock_order';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.evidence
     WHERE source_reference='d5000000-0000-4000-8000-000000000604';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'service order created delivery evidence';
    END IF;
END;
$no_service_evidence$;

ROLLBACK;

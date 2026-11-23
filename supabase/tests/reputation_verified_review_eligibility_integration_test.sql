-- ============================================================================
-- reputation_verified_review_eligibility_integration_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE Phase 3A integration test.
--
-- Uses actual Phase 2C-1 ingestion and Phase 2B capture, correction, conflict
-- resolution and revocation gateways. No evidence/event rows are fabricated.
-- ============================================================================
BEGIN;

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
VALUES ('a6000000-0000-4000-8000-000000000001', 'Gateway Integration Country', 'GI', 'GIT', '9990', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('a6000000-0000-4000-8000-000000000002', 'Gateway Integration Location',
        'a6000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('a6000000-0000-4000-8000-000000000003', 'gateway-integration-kilogram', 'kg', 'mass');

SELECT set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', 'service_role', true),
       set_config('request.jwt.claims', '{"role":"service_role"}', true);
INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('a6000000-0000-4000-8000-000000000101', 'a6000000-0000-4000-8000-000000000901',
     'Gateway Buyer', 'a6000000-0000-4000-8000-000000000001', true, 'active'),
    ('a6000000-0000-4000-8000-000000000102', 'a6000000-0000-4000-8000-000000000902',
     'Gateway Seller', 'a6000000-0000-4000-8000-000000000001', true, 'active');
SELECT set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', '', true),
       set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, primary_contact_profile_id, is_active, verification_status)
VALUES
    ('a6000000-0000-4000-8000-000000000201', 'Gateway Seller Entity', 'farm',
     'a6000000-0000-4000-8000-000000000102', 'a6000000-0000-4000-8000-000000000102', true, 'verified'),
    ('a6000000-0000-4000-8000-000000000202', 'Gateway Buyer Entity', 'individual_pro',
     'a6000000-0000-4000-8000-000000000101', 'a6000000-0000-4000-8000-000000000101', true, 'verified');

INSERT INTO core.items (id, name) VALUES ('a6000000-0000-4000-8000-000000000301', 'Gateway Item');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('a6000000-0000-4000-8000-000000000302', 'a6000000-0000-4000-8000-000000000301', 'Gateway Variant');
INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    'a6000000-0000-4000-8000-000000000401',
    'a6000000-0000-4000-8000-000000000201',
    'a6000000-0000-4000-8000-000000000402',
    'a6000000-0000-4000-8000-000000000302',
    'a6000000-0000-4000-8000-000000000301',
    'a6000000-0000-4000-8000-000000000002',
    1000.00, 0.00, 'a6000000-0000-4000-8000-000000000003', 'active'
);
INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    'a6000000-0000-4000-8000-000000000402', 'farm',
    'a6000000-0000-4000-8000-000000000102', 'Gateway Supplier',
    'verified', true, 'a6000000-0000-4000-8000-000000000201', true
);
INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    'a6000000-0000-4000-8000-000000000403',
    'a6000000-0000-4000-8000-000000000201',
    'Gateway Listing', 50.00, 'KES',
    'a6000000-0000-4000-8000-000000000002',
    'a6000000-0000-4000-8000-000000000302',
    1000.00, 'a6000000-0000-4000-8000-000000000003', 'active',
    'a6000000-0000-4000-8000-000000000401'
);

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, delivery_date, entity_id,
    order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
    status_changed_by_profile_id
) VALUES
    ('a7000000-0000-4000-8000-000000000001',
     'a6000000-0000-4000-8000-000000000101',
     'a6000000-0000-4000-8000-000000000403',
     'a6000000-0000-4000-8000-000000000402',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-22T08:00:00Z', '2026-11-22T09:00:00Z', '2026-11-22T09:00:00Z',
     'a6000000-0000-4000-8000-000000000201', 'stock',
     'a6000000-0000-4000-8000-000000000202',
     'a6000000-0000-4000-8000-000000000201',
     'KES', 'a6000000-0000-4000-8000-000000000003',
     'a6000000-0000-4000-8000-000000000101'),
    ('a7000000-0000-4000-8000-000000000002',
     'a6000000-0000-4000-8000-000000000101',
     'a6000000-0000-4000-8000-000000000403',
     'a6000000-0000-4000-8000-000000000402',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-22T08:00:00Z', '2026-11-22T09:00:00Z', '2026-11-22T09:00:00Z',
     'a6000000-0000-4000-8000-000000000201', 'stock',
     'a6000000-0000-4000-8000-000000000202',
     'a6000000-0000-4000-8000-000000000201',
     'KES', 'a6000000-0000-4000-8000-000000000003',
     'a6000000-0000-4000-8000-000000000101'),
    ('a7000000-0000-4000-8000-000000000003',
     'a6000000-0000-4000-8000-000000000101',
     'a6000000-0000-4000-8000-000000000403',
     'a6000000-0000-4000-8000-000000000402',
     2.00, 100.00, 'delivered', 'pending',
     '2026-11-22T08:00:00Z', '2026-11-22T09:00:00Z', '2026-11-22T09:00:00Z',
     'a6000000-0000-4000-8000-000000000201', 'stock',
     'a6000000-0000-4000-8000-000000000202',
     'a6000000-0000-4000-8000-000000000201',
     'KES', 'a6000000-0000-4000-8000-000000000003',
     'a6000000-0000-4000-8000-000000000101');

INSERT INTO commerce.order_items (
    id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
    stock_id, variant_id, unit_id
) VALUES
    ('a7100000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000001',
     'a6000000-0000-4000-8000-000000000403', 'a6000000-0000-4000-8000-000000000301',
     2.00, 'kg', 50.00, 'a6000000-0000-4000-8000-000000000401',
     'a6000000-0000-4000-8000-000000000302', 'a6000000-0000-4000-8000-000000000003'),
    ('a7100000-0000-4000-8000-000000000002', 'a7000000-0000-4000-8000-000000000002',
     'a6000000-0000-4000-8000-000000000403', 'a6000000-0000-4000-8000-000000000301',
     2.00, 'kg', 50.00, 'a6000000-0000-4000-8000-000000000401',
     'a6000000-0000-4000-8000-000000000302', 'a6000000-0000-4000-8000-000000000003'),
    ('a7100000-0000-4000-8000-000000000003', 'a7000000-0000-4000-8000-000000000003',
     'a6000000-0000-4000-8000-000000000403', 'a6000000-0000-4000-8000-000000000301',
     2.00, 'kg', 50.00, 'a6000000-0000-4000-8000-000000000401',
     'a6000000-0000-4000-8000-000000000302', 'a6000000-0000-4000-8000-000000000003');

DO $capture_correction$
DECLARE
    v_ingest record;
    v_capture record;
    v_correction record;
    v_resolver record;
    v_old_status text;
BEGIN
    SELECT * INTO v_ingest
      FROM system.ingest_reputation_stock_order_engagement(
          'a7000000-0000-4000-8000-000000000001'
      );
    IF v_ingest.outcome <> 'created' OR v_ingest.engagement_id IS NULL THEN
        RAISE EXCEPTION 'actual ingestion failed: %', v_ingest;
    END IF;

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101',
          'phase3a-integration-capture'
      );
    IF v_capture.outcome <> 'recorded'
       OR v_capture.evidence_status <> 'active'
       OR v_capture.evidence_id IS NULL THEN
        RAISE EXCEPTION 'actual capture failed: %', v_capture;
    END IF;

    SELECT * INTO v_resolver
      FROM reputation.resolve_verified_review_eligibility(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_resolver.eligibility_status <> 'eligible'
       OR v_resolver.reason_code IS NOT NULL
       OR v_resolver.evidence_id <> v_capture.evidence_id
       OR v_resolver.evidence_source_version <> 'delivery:v1' THEN
        RAISE EXCEPTION 'resolver rejected actual captured evidence: %', v_resolver;
    END IF;

    SELECT * INTO v_correction
      FROM system.supersede_reputation_order_evidence(
          v_ingest.engagement_id,
          v_capture.evidence_id,
          'delivery:v2',
          'a6000000-0000-4000-8000-000000000101',
          'phase3a-integration-correction'
      );
    IF v_correction.outcome <> 'superseded'
       OR v_correction.superseded_evidence_id <> v_capture.evidence_id
       OR v_correction.evidence_id IS NULL THEN
        RAISE EXCEPTION 'actual correction failed: %', v_correction;
    END IF;

    SELECT evidence_status INTO v_old_status
      FROM reputation.v_evidence_current_state
     WHERE evidence_id = v_capture.evidence_id;
    IF v_old_status <> 'superseded' THEN
        RAISE EXCEPTION 'original evidence was not superseded: %', v_old_status;
    END IF;

    SELECT * INTO v_resolver
      FROM reputation.resolve_verified_review_eligibility(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_resolver.eligibility_status <> 'eligible'
       OR v_resolver.reason_code IS NOT NULL
       OR v_resolver.evidence_id <> v_correction.evidence_id
       OR v_resolver.evidence_source_version <> 'delivery:v2' THEN
        RAISE EXCEPTION 'correction did not restore active replacement eligibility: %', v_resolver;
    END IF;
END;
$capture_correction$;

DO $conflict$
DECLARE
    v_ingest record;
    v_capture record;
    v_conflict record;
    v_resolution record;
    v_resolver record;
BEGIN
    SELECT * INTO v_ingest
      FROM system.ingest_reputation_stock_order_engagement(
          'a7000000-0000-4000-8000-000000000002'
      );
    IF v_ingest.outcome <> 'created' OR v_ingest.engagement_id IS NULL THEN
        RAISE EXCEPTION 'conflict ingestion failed: %', v_ingest;
    END IF;

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101',
          'phase3a-integration-conflict-base'
      );
    IF v_capture.outcome <> 'recorded' OR v_capture.evidence_id IS NULL THEN
        RAISE EXCEPTION 'conflict base capture failed: %', v_capture;
    END IF;

    UPDATE commerce.orders
       SET total_amount = total_amount + 10,
           updated_at = clock_timestamp()
     WHERE id = 'a7000000-0000-4000-8000-000000000002';

    SELECT * INTO v_conflict
      FROM system.capture_reputation_order_evidence(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101',
          'phase3a-integration-conflict'
      );
    IF v_conflict.outcome <> 'conflict_recorded'
       OR v_conflict.conflict_event_id IS NULL
       OR v_conflict.evidence_status <> 'conflicted' THEN
        RAISE EXCEPTION 'actual conflict capture failed: %', v_conflict;
    END IF;

    SELECT * INTO v_resolver
      FROM reputation.resolve_verified_review_eligibility(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_resolver.eligibility_status <> 'ineligible'
       OR v_resolver.reason_code <> 'evidence_conflicted' THEN
        RAISE EXCEPTION 'resolver allowed conflicted evidence: %', v_resolver;
    END IF;

    SELECT * INTO v_resolution
      FROM system.resolve_reputation_evidence_conflict(
          v_conflict.conflict_event_id,
          'accepted_original',
          'phase3a integration conflict resolution',
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_resolution.outcome <> 'resolved'
       OR v_resolution.evidence_status <> 'active' THEN
        RAISE EXCEPTION 'actual conflict resolution failed: %', v_resolution;
    END IF;

    SELECT * INTO v_resolver
      FROM reputation.resolve_verified_review_eligibility(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_resolver.eligibility_status <> 'eligible'
       OR v_resolver.reason_code IS NOT NULL
       OR v_resolver.evidence_id <> v_capture.evidence_id THEN
        RAISE EXCEPTION 'conflict resolution did not restore eligibility: %', v_resolver;
    END IF;
END;
$conflict$;

DO $revocation$
DECLARE
    v_ingest record;
    v_capture record;
    v_revoke record;
    v_revoke_again record;
    v_resolver record;
BEGIN
    SELECT * INTO v_ingest
      FROM system.ingest_reputation_stock_order_engagement(
          'a7000000-0000-4000-8000-000000000003'
      );
    IF v_ingest.outcome <> 'created' OR v_ingest.engagement_id IS NULL THEN
        RAISE EXCEPTION 'revocation ingestion failed: %', v_ingest;
    END IF;

    SELECT * INTO v_capture
      FROM system.capture_reputation_order_evidence(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101',
          'phase3a-integration-revoke-base'
      );
    IF v_capture.outcome <> 'recorded' OR v_capture.evidence_id IS NULL THEN
        RAISE EXCEPTION 'revocation base capture failed: %', v_capture;
    END IF;

    SELECT * INTO v_revoke
      FROM system.revoke_reputation_evidence(
          v_capture.evidence_id,
          'phase3a_integration_revoke',
          'actual gateway revocation',
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_revoke.outcome <> 'revoked' OR v_revoke.evidence_status <> 'revoked' THEN
        RAISE EXCEPTION 'actual revocation failed: %', v_revoke;
    END IF;

    SELECT * INTO v_revoke_again
      FROM system.revoke_reputation_evidence(
          v_capture.evidence_id,
          'phase3a_integration_revoke_again',
          'idempotent terminal revocation',
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_revoke_again.outcome <> 'already_revoked'
       OR v_revoke_again.evidence_status <> 'revoked' THEN
        RAISE EXCEPTION 'revocation was not terminal: %', v_revoke_again;
    END IF;

    SELECT * INTO v_resolver
      FROM reputation.resolve_verified_review_eligibility(
          v_ingest.engagement_id,
          'a6000000-0000-4000-8000-000000000101'
      );
    IF v_resolver.eligibility_status <> 'ineligible'
       OR v_resolver.reason_code <> 'evidence_not_active' THEN
        RAISE EXCEPTION 'revoked evidence authorized a review: %', v_resolver;
    END IF;
END;
$revocation$;

ROLLBACK;

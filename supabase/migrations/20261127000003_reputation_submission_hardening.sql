-- ============================================================================
-- 20261127000003_reputation_submission_hardening
-- ----------------------------------------------------------------------------
-- Reputation Phase 3A/3B security hardening (follow-up only; does not modify
-- the applied Phase 3A/3B migrations or their objects' contracts).
--
-- Scope:
--   1. Engagement TOCTOU: verified submission now locks the engagement row
--      (SELECT ... FOR UPDATE) before evaluating eligibility, and the insert
--      happens in the same transaction. Engagement lifecycle events carry an
--      FK to the engagement row, so their KEY SHARE lock serializes with this
--      FOR UPDATE.
--   2. Explicit rejection: an explicitly supplied engagement_id that is not
--      eligible (ineligible or suspended) is rejected with SQLSTATE P0001
--      instead of silently falling back to an unverified submission.
--   3. Self-review: shared affiliate helper (owner / primary contact / active
--      can_manage manager) applied to rating and review submissions for seller
--      entities and for product/item subjects via the existing listing/stock
--      seller relationship. Unknown product seller association fails closed.
--   4. Subject creation: ensure_* requires authority over the seller entity or
--      the product's seller operation, or a trusted service/direct-DB path.
--      Public read/resolve APIs are unchanged.
--
-- NOT in scope / documented limitations:
--   * No returns/refunds/disputes/voids producer is added here. Phase 3A can
--     only reflect lifecycle outcomes that exist as reputation events; the
--     pending commerce returns/refunds migration does not emit Reputation
--     events. Do not claim end-to-end refund/return integration yet.
--   * No Finance changes, no Marketplace/order architecture changes, no
--     identity changes, no verified-edit/duplicate-policy changes, no seller
--     response/moderation/full-name policy changes.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Shared helpers (internal only; not exposed to API roles).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.is_seller_affiliate(
    p_entity_id uuid,
    p_profile_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core', 'users'
AS $fn$
  SELECT
    COALESCE((
      SELECT true
        FROM core.entities AS e
       WHERE e.id = p_entity_id
         AND (e.owner_id = p_profile_id
              OR e.primary_contact_profile_id = p_profile_id)
    ), false)
    OR COALESCE((
      SELECT true
        FROM core.entity_members AS m
       WHERE m.entity_id = p_entity_id
         AND m.profile_id = p_profile_id
         AND m.is_active IS TRUE
         AND m.membership_status = 'active'
         AND m.can_manage IS TRUE
    ), false);
$fn$;

COMMENT ON FUNCTION reputation.is_seller_affiliate(uuid, uuid) IS
  'Internal self-review/authority predicate: entity owner, primary contact, or active can_manage manager.';

CREATE OR REPLACE FUNCTION reputation.product_seller_entity_ids(
    p_item_id uuid
)
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core', 'commerce', 'marketplace'
AS $fn$
  SELECT DISTINCT l.entity_id
    FROM marketplace.listings AS l
    JOIN core.item_variants AS iv ON iv.id = l.variant_id
   WHERE iv.item_id = p_item_id
     AND l.entity_id IS NOT NULL
  UNION
  SELECT DISTINCT sr.entity_id
    FROM commerce.stock_registry AS sr
    LEFT JOIN core.item_variants AS iv2 ON iv2.id = sr.variant_id
   WHERE sr.entity_id IS NOT NULL
     AND (sr.product_id = p_item_id OR iv2.item_id = p_item_id);
$fn$;

COMMENT ON FUNCTION reputation.product_seller_entity_ids(uuid) IS
  'Resolves existing seller entities for a product item via Marketplace listings and Commerce stock (read-only; no new ownership model).';

REVOKE ALL ON FUNCTION reputation.is_seller_affiliate(uuid, uuid)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.product_seller_entity_ids(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Subject creation authorization.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.ensure_product_subject(p_variant_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users', 'commerce', 'marketplace'
AS $fn$
DECLARE
    v_item_id uuid;
    v_subject_id uuid;
    v_profile_id uuid;
    v_trusted boolean;
BEGIN
    IF p_variant_id IS NULL THEN
        RAISE EXCEPTION 'variant_id is required' USING ERRCODE = '22023';
    END IF;
    SELECT iv.item_id INTO v_item_id
      FROM core.item_variants AS iv
     WHERE iv.id = p_variant_id;
    IF v_item_id IS NULL THEN
        RAISE EXCEPTION 'Variant not found' USING ERRCODE = 'P0002';
    END IF;

    v_profile_id := core.current_profile_id();
    v_trusted := COALESCE(auth.role(), '') = 'service_role'
                 OR (auth.uid() IS NULL AND v_profile_id IS NULL);
    IF NOT v_trusted AND NOT EXISTS (
        SELECT 1
          FROM reputation.product_seller_entity_ids(v_item_id) AS eid
         WHERE reputation.is_seller_affiliate(eid, v_profile_id)
    ) THEN
        RAISE EXCEPTION 'not authorized to create product reputation subject'
            USING ERRCODE = '42501';
    END IF;

    SELECT s.id INTO v_subject_id
      FROM reputation.subjects AS s
     WHERE s.subject_type = 'item'
       AND s.subject_role = 'product'
       AND s.item_id = v_item_id
       AND s.status = 'active';
    IF v_subject_id IS NULL THEN
        v_subject_id := reputation.register_subject('item', 'product', v_item_id);
    END IF;
    RETURN v_subject_id;
END;
$fn$;

CREATE OR REPLACE FUNCTION reputation.ensure_seller_subject(p_entity_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $fn$
DECLARE
    v_subject_id uuid;
    v_profile_id uuid;
    v_trusted boolean;
BEGIN
    IF p_entity_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM core.entities e WHERE e.id = p_entity_id AND e.is_active = true
    ) THEN
        RAISE EXCEPTION 'Active seller entity required' USING ERRCODE = '22023';
    END IF;

    v_profile_id := core.current_profile_id();
    v_trusted := COALESCE(auth.role(), '') = 'service_role'
                 OR (auth.uid() IS NULL AND v_profile_id IS NULL);
    IF NOT v_trusted
       AND NOT reputation.is_seller_affiliate(p_entity_id, v_profile_id) THEN
        RAISE EXCEPTION 'not authorized to create seller reputation subject'
            USING ERRCODE = '42501';
    END IF;

    SELECT s.id INTO v_subject_id
      FROM reputation.subjects AS s
     WHERE s.subject_type = 'entity'
       AND s.subject_role = 'seller'
       AND s.entity_id = p_entity_id
       AND s.status = 'active';
    IF v_subject_id IS NULL THEN
        v_subject_id := reputation.register_subject('entity', 'seller', p_entity_id);
    END IF;
    RETURN v_subject_id;
END;
$fn$;

-- ----------------------------------------------------------------------------
-- Rating submission (hardened).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.submit_rating(
    p_subject_id uuid,
    p_rating smallint,
    p_engagement_id uuid DEFAULT NULL
)
RETURNS TABLE (
    rating_id uuid,
    outcome text,
    verification_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users', 'commerce', 'marketplace'
AS $function$
DECLARE
    v_profile_id uuid;
    v_subject reputation.subjects%ROWTYPE;
    v_base record;
    v_product record;
    v_verified boolean := false;
    v_snapshot jsonb := '{}'::jsonb;
    v_snapshot_hash bytea;
    v_snapshot_id uuid;
    v_rating_id uuid;
    v_snap_seller_subject_id uuid;
    v_snap_seller_entity_id uuid;
    v_snap_item_id uuid;
    v_snap_variant_id uuid;
    v_snap_order_item_id uuid;
    v_snap_listing_id uuid;
    v_snap_evidence_id uuid;
    v_snap_evidence_version text;
    v_snap_evidence_hash bytea;
    v_snap_rule_version smallint := 1;
    v_locked_engagement_id uuid;
BEGIN
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'rating must be between 1 and 5' USING ERRCODE = '22023';
    END IF;
    v_profile_id := core.current_profile_id();
    IF v_profile_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM users.profiles p
         WHERE p.id = v_profile_id AND p.is_active AND p.account_status = 'active' AND p.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'active profile required' USING ERRCODE = '42501';
    END IF;

    SELECT s.* INTO v_subject FROM reputation.subjects s WHERE s.id = p_subject_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Subject not found' USING ERRCODE = 'P0002';
    END IF;
    IF NOT (v_subject.subject_type = 'entity' AND v_subject.subject_role = 'seller')
       AND NOT (v_subject.subject_type = 'item' AND v_subject.subject_role = 'product') THEN
        RAISE EXCEPTION 'Unsupported rating subject' USING ERRCODE = '22023';
    END IF;
    IF v_subject.status <> 'active' THEN
        RAISE EXCEPTION 'Subject is not active' USING ERRCODE = '22023';
    END IF;

    -- Self-review protection (applies with or without an engagement).
    IF v_subject.subject_type = 'entity' THEN
        IF reputation.is_seller_affiliate(v_subject.entity_id, v_profile_id) THEN
            RAISE EXCEPTION 'self-review is not allowed' USING ERRCODE = '42501';
        END IF;
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM reputation.product_seller_entity_ids(v_subject.item_id)
        ) THEN
            RAISE EXCEPTION 'REPUTATION_VERIFICATION_REJECTED: product_seller_unresolved'
                USING ERRCODE = 'P0001';
        END IF;
        IF EXISTS (
            SELECT 1
              FROM reputation.product_seller_entity_ids(v_subject.item_id) AS eid
             WHERE reputation.is_seller_affiliate(eid, v_profile_id)
        ) THEN
            RAISE EXCEPTION 'self-review is not allowed' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_engagement_id IS NOT NULL THEN
        -- Serialize against engagement lifecycle events (FK KEY SHARE conflicts
        -- with FOR UPDATE). Eligibility is then evaluated on this locked state.
        SELECT e.id INTO v_locked_engagement_id
          FROM reputation.engagements AS e
         WHERE e.id = p_engagement_id
         FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Engagement not found' USING ERRCODE = 'P0002';
        END IF;

        IF v_subject.subject_type = 'item' THEN
            SELECT * INTO v_product
              FROM reputation.resolve_verified_product_review_eligibility(
                  p_engagement_id, v_profile_id, p_subject_id
              );
            IF v_product.eligibility_status IS DISTINCT FROM 'eligible' THEN
                RAISE EXCEPTION 'REPUTATION_VERIFICATION_REJECTED: %',
                    COALESCE(v_product.reason_code, 'ineligible')
                    USING ERRCODE = 'P0001';
            END IF;
            v_verified := true;
            v_snapshot := v_product.snapshot;
            v_snap_seller_subject_id := v_product.seller_subject_id;
            v_snap_seller_entity_id := v_product.seller_entity_id;
            v_snap_item_id := v_product.purchased_item_id;
            v_snap_variant_id := v_product.purchased_variant_id;
            v_snap_order_item_id := v_product.order_item_id;
            v_snap_listing_id := v_product.listing_id;
            v_snap_evidence_id := v_product.evidence_id;
            v_snap_evidence_version := v_product.evidence_source_version;
            v_snap_evidence_hash := v_product.evidence_snapshot_hash;
            v_snap_rule_version := v_product.rule_version;
        ELSE
            SELECT * INTO v_base
              FROM reputation.resolve_verified_review_eligibility(
                  p_engagement_id, v_profile_id
              );
            IF v_base.eligibility_status IS DISTINCT FROM 'eligible'
               OR v_base.subject_id IS DISTINCT FROM p_subject_id THEN
                RAISE EXCEPTION 'REPUTATION_VERIFICATION_REJECTED: %',
                    COALESCE(v_base.reason_code, 'subject_mismatch')
                    USING ERRCODE = 'P0001';
            END IF;
            v_verified := true;
            v_snap_seller_subject_id := p_subject_id;
            SELECT ep.entity_id INTO v_snap_seller_entity_id
              FROM reputation.engagement_participants ep
             WHERE ep.engagement_id = p_engagement_id
               AND ep.party_role = 'seller' LIMIT 1;
            v_snap_evidence_id := v_base.evidence_id;
            v_snap_evidence_version := v_base.evidence_source_version;
            v_snap_evidence_hash := v_base.evidence_snapshot_hash;
            v_snap_rule_version := v_base.rule_version;
            v_snapshot := jsonb_build_object(
                'kind', 'seller',
                'engagement_id', p_engagement_id,
                'reviewer_profile_id', v_profile_id,
                'subject_id', p_subject_id,
                'seller_subject_id', p_subject_id,
                'evidence_id', v_base.evidence_id,
                'evidence_source_version', v_base.evidence_source_version,
                'evidence_snapshot_hash', encode(v_base.evidence_snapshot_hash, 'hex'),
                'rule_version', v_base.rule_version
            );
        END IF;
    END IF;

    BEGIN
        INSERT INTO reputation.ratings (
            subject_id, reviewer_profile_id, rating, status,
            verification_status
        ) VALUES (
            p_subject_id, v_profile_id, p_rating, 'published',
            CASE WHEN v_verified THEN 'verified' ELSE 'unverified' END
        )
        RETURNING id INTO v_rating_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'A rating already exists for this subject and reviewer'
            USING ERRCODE = '23505';
    END;

    INSERT INTO reputation.rating_revisions (
        rating_id, revision_number, previous_rating, rating, edited_by_profile_id
    ) VALUES (v_rating_id, 1, NULL, p_rating, v_profile_id);

    IF v_verified THEN
        v_snapshot_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));
        INSERT INTO reputation.verification_snapshots (
            rating_id, engagement_id, reviewer_profile_id, subject_id,
            seller_subject_id, seller_entity_id, purchased_item_id,
            purchased_variant_id, order_item_id, listing_id, evidence_id,
            evidence_source_version, evidence_snapshot_hash, rule_version,
            verified_at, snapshot_hash, snapshot
        ) VALUES (
            v_rating_id, p_engagement_id, v_profile_id, p_subject_id,
            v_snap_seller_subject_id, v_snap_seller_entity_id,
            v_snap_item_id, v_snap_variant_id,
            v_snap_order_item_id, v_snap_listing_id, v_snap_evidence_id,
            v_snap_evidence_version, v_snap_evidence_hash,
            v_snap_rule_version, clock_timestamp(), v_snapshot_hash, v_snapshot
        ) RETURNING id INTO v_snapshot_id;

        UPDATE reputation.ratings
           SET current_verification_snapshot_id = v_snapshot_id,
               verification_status = 'verified',
               updated_at = clock_timestamp()
         WHERE id = v_rating_id;
    END IF;

    INSERT INTO reputation.rating_review_events (
        target_type, target_id, event_type, actor_profile_id, details
    ) VALUES (
        'rating', v_rating_id, 'submitted', v_profile_id,
        jsonb_build_object('verified', v_verified)
    );

    RETURN QUERY SELECT v_rating_id, 'submitted'::text,
        CASE WHEN v_verified THEN 'verified' ELSE 'unverified' END;
END;
$function$;

ALTER FUNCTION reputation.submit_rating(uuid, smallint, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.submit_rating(uuid, smallint, uuid)
    FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Review submission (hardened).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.submit_review(
    p_subject_id uuid,
    p_body text,
    p_title text DEFAULT NULL,
    p_rating_id uuid DEFAULT NULL,
    p_engagement_id uuid DEFAULT NULL,
    p_public_identity_mode text DEFAULT 'display_name'
)
RETURNS TABLE (
    review_id uuid,
    outcome text,
    verification_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users', 'commerce', 'marketplace'
AS $function$
DECLARE
    v_profile_id uuid;
    v_profile users.profiles%ROWTYPE;
    v_subject reputation.subjects%ROWTYPE;
    v_rating reputation.ratings%ROWTYPE;
    v_base record;
    v_product record;
    v_verified boolean := false;
    v_snapshot jsonb := '{}'::jsonb;
    v_snapshot_hash bytea;
    v_snapshot_id uuid;
    v_review_id uuid;
    v_snap_seller_subject_id uuid;
    v_snap_seller_entity_id uuid;
    v_snap_item_id uuid;
    v_snap_variant_id uuid;
    v_snap_order_item_id uuid;
    v_snap_listing_id uuid;
    v_snap_evidence_id uuid;
    v_snap_evidence_version text;
    v_snap_evidence_hash bytea;
    v_snap_rule_version smallint := 1;
    v_display_name text;
    v_body text := btrim(COALESCE(p_body, ''));
    v_locked_engagement_id uuid;
BEGIN
    IF v_body = '' OR length(v_body) > 20000 THEN
        RAISE EXCEPTION 'body is required and must be at most 20000 characters' USING ERRCODE = '22023';
    END IF;
    IF p_public_identity_mode NOT IN ('display_name', 'anonymous') THEN
        RAISE EXCEPTION 'invalid public identity mode' USING ERRCODE = '22023';
    END IF;
    v_profile_id := core.current_profile_id();
    SELECT * INTO v_profile FROM users.profiles WHERE id = v_profile_id;
    IF NOT FOUND OR v_profile.is_active IS NOT TRUE
       OR v_profile.account_status IS DISTINCT FROM 'active' OR v_profile.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'active profile required' USING ERRCODE = '42501';
    END IF;
    v_display_name := COALESCE(
        NULLIF(btrim(concat_ws(' ', v_profile.first_name, v_profile.middle_name, v_profile.last_name)), ''),
        'Vunio member'
    );

    SELECT s.* INTO v_subject FROM reputation.subjects s WHERE s.id = p_subject_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Subject not found' USING ERRCODE = 'P0002'; END IF;
    IF NOT (v_subject.subject_type = 'entity' AND v_subject.subject_role = 'seller')
       AND NOT (v_subject.subject_type = 'item' AND v_subject.subject_role = 'product') THEN
        RAISE EXCEPTION 'Unsupported review subject' USING ERRCODE = '22023';
    END IF;
    IF v_subject.status <> 'active' THEN
        RAISE EXCEPTION 'Subject is not active' USING ERRCODE = '22023';
    END IF;

    -- Self-review protection (applies with or without an engagement).
    IF v_subject.subject_type = 'entity' THEN
        IF reputation.is_seller_affiliate(v_subject.entity_id, v_profile_id) THEN
            RAISE EXCEPTION 'self-review is not allowed' USING ERRCODE = '42501';
        END IF;
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM reputation.product_seller_entity_ids(v_subject.item_id)
        ) THEN
            RAISE EXCEPTION 'REPUTATION_VERIFICATION_REJECTED: product_seller_unresolved'
                USING ERRCODE = 'P0001';
        END IF;
        IF EXISTS (
            SELECT 1
              FROM reputation.product_seller_entity_ids(v_subject.item_id) AS eid
             WHERE reputation.is_seller_affiliate(eid, v_profile_id)
        ) THEN
            RAISE EXCEPTION 'self-review is not allowed' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_rating_id IS NOT NULL THEN
        SELECT * INTO v_rating FROM reputation.ratings
         WHERE id = p_rating_id AND reviewer_profile_id = v_profile_id AND subject_id = p_subject_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Linked rating must belong to the same reviewer and subject'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF p_engagement_id IS NOT NULL THEN
        SELECT e.id INTO v_locked_engagement_id
          FROM reputation.engagements AS e
         WHERE e.id = p_engagement_id
         FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Engagement not found' USING ERRCODE = 'P0002';
        END IF;

        IF v_subject.subject_type = 'item' THEN
            SELECT * INTO v_product FROM reputation.resolve_verified_product_review_eligibility(
                p_engagement_id, v_profile_id, p_subject_id);
            IF v_product.eligibility_status IS DISTINCT FROM 'eligible' THEN
                RAISE EXCEPTION 'REPUTATION_VERIFICATION_REJECTED: %',
                    COALESCE(v_product.reason_code, 'ineligible')
                    USING ERRCODE = 'P0001';
            END IF;
            v_verified := true;
            v_snapshot := v_product.snapshot;
            v_snap_seller_subject_id := v_product.seller_subject_id;
            v_snap_seller_entity_id := v_product.seller_entity_id;
            v_snap_item_id := v_product.purchased_item_id;
            v_snap_variant_id := v_product.purchased_variant_id;
            v_snap_order_item_id := v_product.order_item_id;
            v_snap_listing_id := v_product.listing_id;
            v_snap_evidence_id := v_product.evidence_id;
            v_snap_evidence_version := v_product.evidence_source_version;
            v_snap_evidence_hash := v_product.evidence_snapshot_hash;
            v_snap_rule_version := v_product.rule_version;
        ELSE
            SELECT * INTO v_base FROM reputation.resolve_verified_review_eligibility(
                p_engagement_id, v_profile_id);
            IF v_base.eligibility_status IS DISTINCT FROM 'eligible'
               OR v_base.subject_id IS DISTINCT FROM p_subject_id THEN
                RAISE EXCEPTION 'REPUTATION_VERIFICATION_REJECTED: %',
                    COALESCE(v_base.reason_code, 'subject_mismatch')
                    USING ERRCODE = 'P0001';
            END IF;
            v_verified := true;
            v_snap_seller_subject_id := p_subject_id;
            SELECT ep.entity_id INTO v_snap_seller_entity_id
              FROM reputation.engagement_participants ep
             WHERE ep.engagement_id = p_engagement_id
               AND ep.party_role = 'seller' LIMIT 1;
            v_snap_evidence_id := v_base.evidence_id;
            v_snap_evidence_version := v_base.evidence_source_version;
            v_snap_evidence_hash := v_base.evidence_snapshot_hash;
            v_snap_rule_version := v_base.rule_version;
            v_snapshot := jsonb_build_object(
                'kind', 'seller', 'engagement_id', p_engagement_id,
                'reviewer_profile_id', v_profile_id, 'subject_id', p_subject_id,
                'seller_subject_id', p_subject_id,
                'evidence_id', v_base.evidence_id,
                'evidence_source_version', v_base.evidence_source_version,
                'evidence_snapshot_hash', encode(v_base.evidence_snapshot_hash, 'hex'),
                'rule_version', v_base.rule_version
            );
        END IF;
    END IF;

    INSERT INTO reputation.reviews (
        subject_id, reviewer_profile_id, rating_id, engagement_id, title, body,
        verification_status, status, public_identity_mode,
        reviewer_display_name_snapshot, reviewer_avatar_snapshot,
        current_revision_number
    ) VALUES (
        p_subject_id, v_profile_id, p_rating_id,
        CASE WHEN v_verified THEN p_engagement_id ELSE NULL END,
        NULLIF(btrim(COALESCE(p_title, '')), ''), v_body,
        CASE WHEN v_verified THEN 'verified' ELSE 'unverified' END,
        'published', p_public_identity_mode, v_display_name,
        v_profile.profile_image, 1
    ) RETURNING id INTO v_review_id;

    INSERT INTO reputation.review_revisions (
        review_id, revision_number, previous_title, title, previous_body, body,
        edited_by_profile_id
    ) VALUES (
        v_review_id, 1, NULL, NULLIF(btrim(COALESCE(p_title, '')), ''),
        NULL, v_body, v_profile_id
    );

    IF v_verified THEN
        v_snapshot_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));
        INSERT INTO reputation.verification_snapshots (
            review_id, engagement_id, reviewer_profile_id, subject_id,
            seller_subject_id, seller_entity_id, purchased_item_id,
            purchased_variant_id, order_item_id, listing_id, evidence_id,
            evidence_source_version, evidence_snapshot_hash, rule_version,
            verified_at, snapshot_hash, snapshot
        ) VALUES (
            v_review_id, p_engagement_id, v_profile_id, p_subject_id,
            v_snap_seller_subject_id, v_snap_seller_entity_id,
            v_snap_item_id, v_snap_variant_id,
            v_snap_order_item_id, v_snap_listing_id, v_snap_evidence_id,
            v_snap_evidence_version, v_snap_evidence_hash,
            v_snap_rule_version, clock_timestamp(), v_snapshot_hash, v_snapshot
        ) RETURNING id INTO v_snapshot_id;
        UPDATE reputation.reviews
           SET current_verification_snapshot_id = v_snapshot_id,
               verification_status = 'verified',
               updated_at = clock_timestamp()
         WHERE id = v_review_id;
    END IF;

    INSERT INTO reputation.rating_review_events (
        target_type, target_id, event_type, actor_profile_id, details
    ) VALUES ('review', v_review_id, 'submitted', v_profile_id,
              jsonb_build_object('verified', v_verified, 'rating_linked', p_rating_id IS NOT NULL));

    RETURN QUERY SELECT v_review_id, 'submitted'::text,
        CASE WHEN v_verified THEN 'verified' ELSE 'unverified' END;
END;
$function$;

ALTER FUNCTION reputation.submit_review(uuid, text, text, uuid, uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.submit_review(uuid, text, text, uuid, uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;

COMMIT;

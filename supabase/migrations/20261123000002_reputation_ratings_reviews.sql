-- Vunio Reputation Phase 3B - shared Ratings & Reviews foundation.
--
-- Shared by Marketplace seller entities and product item subjects. No separate
-- product/seller review tables. Ratings and reviews are independent records.
-- Verification is represented by immutable snapshots, not a mutable boolean.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Ratings.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.ratings (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    subject_id uuid NOT NULL REFERENCES reputation.subjects(id) ON DELETE RESTRICT,
    reviewer_profile_id uuid NOT NULL REFERENCES users.profiles(id) ON DELETE RESTRICT,
    rating smallint NOT NULL,
    status text NOT NULL DEFAULT 'published',
    verification_status text NOT NULL DEFAULT 'unverified',
    current_verification_snapshot_id uuid,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT ratings_pkey PRIMARY KEY (id),
    CONSTRAINT ratings_rating_check CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ratings_status_check CHECK (status IN ('published', 'hidden', 'removed')),
    CONSTRAINT ratings_verification_status_check CHECK (verification_status IN ('verified', 'unverified')),
    CONSTRAINT ratings_subject_reviewer_key UNIQUE (subject_id, reviewer_profile_id)
);

ALTER TABLE reputation.ratings OWNER TO postgres;
ALTER TABLE reputation.ratings ENABLE ROW LEVEL SECURITY;

CREATE INDEX ratings_subject_status_idx ON reputation.ratings (subject_id, status);
CREATE INDEX ratings_reviewer_idx ON reputation.ratings (reviewer_profile_id);

CREATE TABLE reputation.rating_revisions (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    rating_id uuid NOT NULL REFERENCES reputation.ratings(id) ON DELETE RESTRICT,
    revision_number integer NOT NULL,
    previous_rating smallint,
    rating smallint NOT NULL,
    edited_by_profile_id uuid NOT NULL REFERENCES users.profiles(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT rating_revisions_pkey PRIMARY KEY (id),
    CONSTRAINT rating_revisions_number_check CHECK (revision_number > 0),
    CONSTRAINT rating_revisions_rating_check CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT rating_revisions_prev_rating_check CHECK (previous_rating IS NULL OR previous_rating BETWEEN 1 AND 5),
    CONSTRAINT rating_revisions_unique UNIQUE (rating_id, revision_number)
);

ALTER TABLE reputation.rating_revisions OWNER TO postgres;
ALTER TABLE reputation.rating_revisions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. Reviews.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.reviews (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    subject_id uuid NOT NULL REFERENCES reputation.subjects(id) ON DELETE RESTRICT,
    reviewer_profile_id uuid NOT NULL REFERENCES users.profiles(id) ON DELETE RESTRICT,
    rating_id uuid REFERENCES reputation.ratings(id) ON DELETE RESTRICT,
    engagement_id uuid REFERENCES reputation.engagements(id) ON DELETE RESTRICT,
    title text,
    body text NOT NULL,
    verification_status text NOT NULL DEFAULT 'unverified',
    current_verification_snapshot_id uuid,
    status text NOT NULL DEFAULT 'published',
    public_identity_mode text NOT NULL DEFAULT 'display_name',
    reviewer_display_name_snapshot text NOT NULL,
    reviewer_avatar_snapshot text,
    current_revision_number integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT reviews_pkey PRIMARY KEY (id),
    CONSTRAINT reviews_body_check CHECK (btrim(body) <> '' AND length(body) <= 20000),
    CONSTRAINT reviews_title_check CHECK (title IS NULL OR length(title) <= 200),
    CONSTRAINT reviews_verification_status_check CHECK (verification_status IN ('verified', 'unverified')),
    CONSTRAINT reviews_status_check CHECK (status IN ('published', 'pending', 'hidden', 'removed')),
    CONSTRAINT reviews_identity_mode_check CHECK (public_identity_mode IN ('display_name', 'anonymous')),
    CONSTRAINT reviews_revision_check CHECK (current_revision_number > 0),
    CONSTRAINT reviews_verified_engagement_check CHECK (
        (verification_status = 'verified' AND engagement_id IS NOT NULL)
        OR (verification_status = 'unverified' AND engagement_id IS NULL)
    ),
    CONSTRAINT reviews_rating_key UNIQUE (rating_id)
);

ALTER TABLE reputation.reviews OWNER TO postgres;
ALTER TABLE reputation.reviews ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reviews_verified_engagement_subject_uidx
    ON reputation.reviews (engagement_id, subject_id)
    WHERE engagement_id IS NOT NULL;

CREATE UNIQUE INDEX reviews_unverified_reviewer_subject_uidx
    ON reputation.reviews (reviewer_profile_id, subject_id)
    WHERE engagement_id IS NULL;

CREATE INDEX reviews_subject_status_created_idx
    ON reputation.reviews (subject_id, status, created_at DESC, id DESC);

CREATE INDEX reviews_reviewer_idx ON reputation.reviews (reviewer_profile_id);

CREATE TABLE reputation.review_revisions (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    review_id uuid NOT NULL REFERENCES reputation.reviews(id) ON DELETE RESTRICT,
    revision_number integer NOT NULL,
    previous_title text,
    title text,
    previous_body text,
    body text NOT NULL,
    edited_by_profile_id uuid NOT NULL REFERENCES users.profiles(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT review_revisions_pkey PRIMARY KEY (id),
    CONSTRAINT review_revisions_number_check CHECK (revision_number > 0),
    CONSTRAINT review_revisions_body_check CHECK (btrim(body) <> ''),
    CONSTRAINT review_revisions_unique UNIQUE (review_id, revision_number)
);

ALTER TABLE reputation.review_revisions OWNER TO postgres;
ALTER TABLE reputation.review_revisions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 3. Immutable verification snapshots.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.verification_snapshots (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    rating_id uuid REFERENCES reputation.ratings(id) ON DELETE RESTRICT,
    review_id uuid REFERENCES reputation.reviews(id) ON DELETE RESTRICT,
    engagement_id uuid NOT NULL REFERENCES reputation.engagements(id) ON DELETE RESTRICT,
    reviewer_profile_id uuid NOT NULL REFERENCES users.profiles(id) ON DELETE RESTRICT,
    subject_id uuid NOT NULL REFERENCES reputation.subjects(id) ON DELETE RESTRICT,
    seller_subject_id uuid REFERENCES reputation.subjects(id) ON DELETE RESTRICT,
    seller_entity_id uuid REFERENCES core.entities(id) ON DELETE RESTRICT,
    purchased_item_id uuid REFERENCES core.items(id) ON DELETE RESTRICT,
    purchased_variant_id uuid REFERENCES core.item_variants(id) ON DELETE RESTRICT,
    order_item_id uuid REFERENCES commerce.order_items(id) ON DELETE RESTRICT,
    listing_id uuid REFERENCES marketplace.listings(id) ON DELETE RESTRICT,
    evidence_id uuid REFERENCES reputation.evidence(id) ON DELETE RESTRICT,
    evidence_source_version text,
    evidence_snapshot_hash bytea,
    rule_version smallint NOT NULL,
    verified_at timestamptz NOT NULL,
    snapshot_hash bytea NOT NULL,
    snapshot jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT verification_snapshots_pkey PRIMARY KEY (id),
    CONSTRAINT verification_snapshots_target_check CHECK (
        (rating_id IS NOT NULL AND review_id IS NULL)
        OR (rating_id IS NULL AND review_id IS NOT NULL)
    ),
    CONSTRAINT verification_snapshots_rule_version_check CHECK (rule_version > 0),
    CONSTRAINT verification_snapshots_hash_check CHECK (octet_length(snapshot_hash) = 32),
    CONSTRAINT verification_snapshots_snapshot_check CHECK (jsonb_typeof(snapshot) = 'object')
);

ALTER TABLE reputation.verification_snapshots OWNER TO postgres;
ALTER TABLE reputation.verification_snapshots ENABLE ROW LEVEL SECURITY;

CREATE INDEX verification_snapshots_rating_idx ON reputation.verification_snapshots (rating_id);
CREATE INDEX verification_snapshots_review_idx ON reputation.verification_snapshots (review_id);

ALTER TABLE reputation.ratings
    ADD CONSTRAINT ratings_current_snapshot_fkey
    FOREIGN KEY (current_verification_snapshot_id)
    REFERENCES reputation.verification_snapshots(id) ON DELETE RESTRICT;

ALTER TABLE reputation.reviews
    ADD CONSTRAINT reviews_current_snapshot_fkey
    FOREIGN KEY (current_verification_snapshot_id)
    REFERENCES reputation.verification_snapshots(id) ON DELETE RESTRICT;

-- ---------------------------------------------------------------------------
-- 4. Aggregates, reports, responses and lifecycle audit.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.subject_rating_summaries (
    subject_id uuid NOT NULL REFERENCES reputation.subjects(id) ON DELETE RESTRICT,
    verified_rating_count integer NOT NULL DEFAULT 0,
    verified_rating_sum integer NOT NULL DEFAULT 0,
    verified_rating_average numeric(4,2) NOT NULL DEFAULT 0,
    verified_1_count integer NOT NULL DEFAULT 0,
    verified_2_count integer NOT NULL DEFAULT 0,
    verified_3_count integer NOT NULL DEFAULT 0,
    verified_4_count integer NOT NULL DEFAULT 0,
    verified_5_count integer NOT NULL DEFAULT 0,
    unverified_rating_count integer NOT NULL DEFAULT 0,
    unverified_1_count integer NOT NULL DEFAULT 0,
    unverified_2_count integer NOT NULL DEFAULT 0,
    unverified_3_count integer NOT NULL DEFAULT 0,
    unverified_4_count integer NOT NULL DEFAULT 0,
    unverified_5_count integer NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT subject_rating_summaries_pkey PRIMARY KEY (subject_id),
    CONSTRAINT subject_rating_summaries_counts_check CHECK (
        verified_rating_count >= 0 AND unverified_rating_count >= 0
        AND verified_rating_sum >= 0
        AND verified_1_count >= 0 AND verified_2_count >= 0 AND verified_3_count >= 0
        AND verified_4_count >= 0 AND verified_5_count >= 0
        AND unverified_1_count >= 0 AND unverified_2_count >= 0 AND unverified_3_count >= 0
        AND unverified_4_count >= 0 AND unverified_5_count >= 0
    )
);

ALTER TABLE reputation.subject_rating_summaries OWNER TO postgres;
ALTER TABLE reputation.subject_rating_summaries ENABLE ROW LEVEL SECURITY;

CREATE TABLE reputation.rating_review_events (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    event_type text NOT NULL,
    actor_profile_id uuid REFERENCES users.profiles(id) ON DELETE SET NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT rating_review_events_pkey PRIMARY KEY (id),
    CONSTRAINT rating_review_events_target_type_check CHECK (target_type IN ('rating', 'review', 'response')),
    CONSTRAINT rating_review_events_event_type_check CHECK (btrim(event_type) <> ''),
    CONSTRAINT rating_review_events_details_check CHECK (jsonb_typeof(details) = 'object')
);

ALTER TABLE reputation.rating_review_events OWNER TO postgres;
ALTER TABLE reputation.rating_review_events ENABLE ROW LEVEL SECURITY;

CREATE TABLE reputation.rating_review_reports (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    reporter_profile_id uuid NOT NULL REFERENCES users.profiles(id) ON DELETE RESTRICT,
    reason_code text NOT NULL,
    reason text,
    status text NOT NULL DEFAULT 'pending',
    resolved_by_profile_id uuid REFERENCES users.profiles(id) ON DELETE SET NULL,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT rating_review_reports_pkey PRIMARY KEY (id),
    CONSTRAINT rating_review_reports_target_type_check CHECK (target_type IN ('rating', 'review')),
    CONSTRAINT rating_review_reports_status_check CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    CONSTRAINT rating_review_reports_reason_check CHECK (btrim(reason_code) <> '')
);

ALTER TABLE reputation.rating_review_reports OWNER TO postgres;
ALTER TABLE reputation.rating_review_reports ENABLE ROW LEVEL SECURITY;

CREATE TABLE reputation.review_responses (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    review_id uuid NOT NULL REFERENCES reputation.reviews(id) ON DELETE RESTRICT,
    responder_entity_id uuid NOT NULL REFERENCES core.entities(id) ON DELETE RESTRICT,
    body text NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    moderated_by_profile_id uuid REFERENCES users.profiles(id) ON DELETE SET NULL,
    moderated_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT review_responses_pkey PRIMARY KEY (id),
    CONSTRAINT review_responses_review_key UNIQUE (review_id),
    CONSTRAINT review_responses_body_check CHECK (btrim(body) <> '' AND length(body) <= 5000),
    CONSTRAINT review_responses_status_check CHECK (status IN ('pending', 'published', 'hidden', 'removed'))
);

ALTER TABLE reputation.review_responses OWNER TO postgres;
ALTER TABLE reputation.review_responses ENABLE ROW LEVEL SECURITY;

CREATE INDEX review_reports_status_idx ON reputation.rating_review_reports (status, created_at);
CREATE INDEX review_responses_status_idx ON reputation.review_responses (status, created_at);

-- ---------------------------------------------------------------------------
-- 5. Privileges: no direct API writes.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE reputation.ratings FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.rating_revisions FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.reviews FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.review_revisions FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.verification_snapshots FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.subject_rating_summaries FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.rating_review_events FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.rating_review_reports FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.review_responses FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. Summary refresh primitives.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.recompute_subject_rating_summary(p_subject_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_verified_count integer;
    v_verified_sum integer;
    v_verified_1 integer;
    v_verified_2 integer;
    v_verified_3 integer;
    v_verified_4 integer;
    v_verified_5 integer;
    v_unverified_count integer;
    v_unverified_1 integer;
    v_unverified_2 integer;
    v_unverified_3 integer;
    v_unverified_4 integer;
    v_unverified_5 integer;
BEGIN
    IF p_subject_id IS NULL THEN
        RAISE EXCEPTION 'subject_id is required' USING ERRCODE = '22023';
    END IF;

    SELECT
        count(*) FILTER (WHERE verification_status = 'verified'),
        COALESCE(sum(rating) FILTER (WHERE verification_status = 'verified'), 0),
        count(*) FILTER (WHERE verification_status = 'verified' AND rating = 1),
        count(*) FILTER (WHERE verification_status = 'verified' AND rating = 2),
        count(*) FILTER (WHERE verification_status = 'verified' AND rating = 3),
        count(*) FILTER (WHERE verification_status = 'verified' AND rating = 4),
        count(*) FILTER (WHERE verification_status = 'verified' AND rating = 5),
        count(*) FILTER (WHERE verification_status = 'unverified'),
        count(*) FILTER (WHERE verification_status = 'unverified' AND rating = 1),
        count(*) FILTER (WHERE verification_status = 'unverified' AND rating = 2),
        count(*) FILTER (WHERE verification_status = 'unverified' AND rating = 3),
        count(*) FILTER (WHERE verification_status = 'unverified' AND rating = 4),
        count(*) FILTER (WHERE verification_status = 'unverified' AND rating = 5)
      INTO
        v_verified_count, v_verified_sum,
        v_verified_1, v_verified_2, v_verified_3, v_verified_4, v_verified_5,
        v_unverified_count,
        v_unverified_1, v_unverified_2, v_unverified_3, v_unverified_4, v_unverified_5
      FROM reputation.ratings
     WHERE subject_id = p_subject_id
       AND status = 'published';

    INSERT INTO reputation.subject_rating_summaries AS s (
        subject_id, verified_rating_count, verified_rating_sum,
        verified_rating_average,
        verified_1_count, verified_2_count, verified_3_count, verified_4_count, verified_5_count,
        unverified_rating_count,
        unverified_1_count, unverified_2_count, unverified_3_count, unverified_4_count, unverified_5_count,
        updated_at
    ) VALUES (
        p_subject_id, v_verified_count, v_verified_sum,
        CASE WHEN v_verified_count = 0 THEN 0 ELSE round(v_verified_sum::numeric / v_verified_count, 2) END,
        v_verified_1, v_verified_2, v_verified_3, v_verified_4, v_verified_5,
        v_unverified_count,
        v_unverified_1, v_unverified_2, v_unverified_3, v_unverified_4, v_unverified_5,
        clock_timestamp()
    )
    ON CONFLICT (subject_id) DO UPDATE SET
        verified_rating_count = EXCLUDED.verified_rating_count,
        verified_rating_sum = EXCLUDED.verified_rating_sum,
        verified_rating_average = EXCLUDED.verified_rating_average,
        verified_1_count = EXCLUDED.verified_1_count,
        verified_2_count = EXCLUDED.verified_2_count,
        verified_3_count = EXCLUDED.verified_3_count,
        verified_4_count = EXCLUDED.verified_4_count,
        verified_5_count = EXCLUDED.verified_5_count,
        unverified_rating_count = EXCLUDED.unverified_rating_count,
        unverified_1_count = EXCLUDED.unverified_1_count,
        unverified_2_count = EXCLUDED.unverified_2_count,
        unverified_3_count = EXCLUDED.unverified_3_count,
        unverified_4_count = EXCLUDED.unverified_4_count,
        unverified_5_count = EXCLUDED.unverified_5_count,
        updated_at = EXCLUDED.updated_at;
END;
$function$;

ALTER FUNCTION reputation.recompute_subject_rating_summary(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.recompute_subject_rating_summary(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION reputation.refresh_subject_rating_summary_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    PERFORM reputation.recompute_subject_rating_summary(
        CASE WHEN TG_OP = 'DELETE' THEN OLD.subject_id ELSE NEW.subject_id END
    );
    RETURN NULL;
END;
$function$;

ALTER FUNCTION reputation.refresh_subject_rating_summary_trigger() OWNER TO postgres;

CREATE TRIGGER ratings_refresh_summary
    AFTER INSERT OR UPDATE OF rating, status, verification_status OR DELETE
    ON reputation.ratings
    FOR EACH ROW
    EXECUTE FUNCTION reputation.refresh_subject_rating_summary_trigger();

CREATE OR REPLACE FUNCTION reputation.guard_review_rating_link()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_rating reputation.ratings%ROWTYPE;
BEGIN
    IF NEW.rating_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_rating FROM reputation.ratings WHERE id = NEW.rating_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Linked rating not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_rating.reviewer_profile_id IS DISTINCT FROM NEW.reviewer_profile_id
       OR v_rating.subject_id IS DISTINCT FROM NEW.subject_id THEN
        RAISE EXCEPTION 'Linked rating must belong to the same reviewer and subject'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.guard_review_rating_link() OWNER TO postgres;

CREATE TRIGGER reviews_guard_rating_link
    BEFORE INSERT OR UPDATE OF rating_id ON reputation.reviews
    FOR EACH ROW
    EXECUTE FUNCTION reputation.guard_review_rating_link();

-- ---------------------------------------------------------------------------
-- 7. Canonical subject resolution for Marketplace.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.ensure_product_subject(p_variant_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core'
AS $function$
DECLARE
    v_item_id uuid;
    v_subject_id uuid;
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
$function$;

ALTER FUNCTION reputation.ensure_product_subject(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.ensure_product_subject(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION reputation.ensure_seller_subject(p_entity_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core'
AS $function$
DECLARE
    v_subject_id uuid;
BEGIN
    IF p_entity_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM core.entities e WHERE e.id = p_entity_id AND e.is_active = true
    ) THEN
        RAISE EXCEPTION 'Active seller entity required' USING ERRCODE = '22023';
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
$function$;

ALTER FUNCTION reputation.ensure_seller_subject(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.ensure_seller_subject(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 8. Product-specific eligibility.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.resolve_verified_product_review_eligibility(
    p_engagement_id uuid,
    p_reviewer_profile_id uuid,
    p_subject_id uuid
)
RETURNS TABLE (
    eligibility_status text,
    reason_code text,
    engagement_id uuid,
    reviewer_profile_id uuid,
    subject_id uuid,
    seller_subject_id uuid,
    seller_entity_id uuid,
    purchased_item_id uuid,
    purchased_variant_id uuid,
    order_item_id uuid,
    listing_id uuid,
    evidence_id uuid,
    evidence_source_version text,
    evidence_snapshot_hash bytea,
    rule_version smallint,
    snapshot jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'commerce', 'core', 'marketplace'
AS $function$
DECLARE
    v_base record;
    v_subject reputation.subjects%ROWTYPE;
    v_order_id uuid;
    v_seller_entity_id uuid;
    v_order_item_id uuid;
    v_variant_id uuid;
    v_listing_id uuid;
    v_items jsonb;
BEGIN
    SELECT * INTO v_base
      FROM reputation.resolve_verified_review_eligibility(
          p_engagement_id, p_reviewer_profile_id
      );

    IF v_base.eligibility_status IS DISTINCT FROM 'eligible' THEN
        RETURN QUERY SELECT
            v_base.eligibility_status, v_base.reason_code,
            p_engagement_id, p_reviewer_profile_id, p_subject_id,
            v_base.subject_id, NULL::uuid, NULL::uuid, NULL::uuid,
            NULL::uuid, NULL::uuid, v_base.evidence_id,
            v_base.evidence_source_version, v_base.evidence_snapshot_hash,
            1::smallint, '{}'::jsonb;
        RETURN;
    END IF;

    SELECT s.* INTO v_subject
      FROM reputation.subjects AS s
     WHERE s.id = p_subject_id
       AND s.subject_type = 'item'
       AND s.subject_role = 'product';
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'ineligible', 'unsupported_product_subject',
            p_engagement_id, p_reviewer_profile_id, p_subject_id,
            v_base.subject_id, NULL::uuid, NULL::uuid, NULL::uuid,
            NULL::uuid, NULL::uuid, v_base.evidence_id,
            v_base.evidence_source_version, v_base.evidence_snapshot_hash,
            1::smallint, '{}'::jsonb;
        RETURN;
    END IF;
    IF v_subject.status <> 'active' THEN
        RETURN QUERY SELECT 'ineligible', 'product_subject_not_active',
            p_engagement_id, p_reviewer_profile_id, p_subject_id,
            v_base.subject_id, NULL::uuid, NULL::uuid, NULL::uuid,
            NULL::uuid, NULL::uuid, v_base.evidence_id,
            v_base.evidence_source_version, v_base.evidence_snapshot_hash,
            1::smallint, '{}'::jsonb;
        RETURN;
    END IF;

    SELECT e.commerce_order_id
      INTO v_order_id
      FROM reputation.engagements AS e
     WHERE e.id = p_engagement_id;

    SELECT ep.entity_id
      INTO v_seller_entity_id
      FROM reputation.engagement_participants AS ep
     WHERE ep.engagement_id = p_engagement_id
       AND ep.party_role = 'seller'
     LIMIT 1;

    IF NOT EXISTS (
        SELECT 1
          FROM reputation.engagement_subjects AS es
         WHERE es.engagement_id = p_engagement_id
           AND es.subject_id = p_subject_id
           AND es.relationship = 'product'
    ) THEN
        RETURN QUERY SELECT 'ineligible', 'product_not_attached_to_engagement',
            p_engagement_id, p_reviewer_profile_id, p_subject_id,
            v_base.subject_id, v_seller_entity_id, v_subject.item_id,
            NULL::uuid, NULL::uuid, NULL::uuid, v_base.evidence_id,
            v_base.evidence_source_version, v_base.evidence_snapshot_hash,
            1::smallint, '{}'::jsonb;
        RETURN;
    END IF;

    SELECT oi.id,
           oi.variant_id,
           oi.listing_id
      INTO v_order_item_id, v_variant_id, v_listing_id
      FROM commerce.order_items AS oi
      JOIN marketplace.listings AS l ON l.id = oi.listing_id
     WHERE oi.order_id = v_order_id
       AND oi.product_id = v_subject.item_id
       AND l.entity_id = v_seller_entity_id
     ORDER BY oi.id
     LIMIT 1;

    IF v_order_item_id IS NULL THEN
        RETURN QUERY SELECT 'ineligible', 'product_not_purchased',
            p_engagement_id, p_reviewer_profile_id, p_subject_id,
            v_base.subject_id, v_seller_entity_id, v_subject.item_id,
            NULL::uuid, NULL::uuid, NULL::uuid, v_base.evidence_id,
            v_base.evidence_source_version, v_base.evidence_snapshot_hash,
            1::smallint, '{}'::jsonb;
        RETURN;
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'order_item_id', oi.id,
                'listing_id', oi.listing_id,
                'product_id', oi.product_id,
                'variant_id', oi.variant_id,
                'quantity', oi.quantity::text
            )
            ORDER BY oi.id
        ),
        '[]'::jsonb
    )
      INTO v_items
      FROM commerce.order_items AS oi
      JOIN marketplace.listings AS l ON l.id = oi.listing_id
     WHERE oi.order_id = v_order_id
       AND oi.product_id = v_subject.item_id
       AND l.entity_id = v_seller_entity_id;

    RETURN QUERY SELECT
        'eligible'::text, NULL::text,
        p_engagement_id, p_reviewer_profile_id, p_subject_id,
        v_base.subject_id, v_seller_entity_id, v_subject.item_id,
        v_variant_id, v_order_item_id, v_listing_id, v_base.evidence_id,
        v_base.evidence_source_version, v_base.evidence_snapshot_hash,
        1::smallint,
        jsonb_build_object(
            'kind', 'product',
            'engagement_id', p_engagement_id,
            'reviewer_profile_id', p_reviewer_profile_id,
            'subject_id', p_subject_id,
            'seller_subject_id', v_base.subject_id,
            'seller_entity_id', v_seller_entity_id,
            'purchased_item_id', v_subject.item_id,
            'purchased_variant_ids', (
                SELECT COALESCE(jsonb_agg(DISTINCT oi.variant_id), '[]'::jsonb)
                  FROM commerce.order_items AS oi
                  JOIN marketplace.listings AS l ON l.id = oi.listing_id
                 WHERE oi.order_id = v_order_id
                   AND oi.product_id = v_subject.item_id
                   AND l.entity_id = v_seller_entity_id
                   AND oi.variant_id IS NOT NULL
            ),
            'order_items', v_items,
            'evidence_id', v_base.evidence_id,
            'evidence_source_version', v_base.evidence_source_version,
            'evidence_snapshot_hash', encode(v_base.evidence_snapshot_hash, 'hex'),
            'rule_version', 1
        );
END;
$function$;

ALTER FUNCTION reputation.resolve_verified_product_review_eligibility(uuid, uuid, uuid)
    OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.resolve_verified_product_review_eligibility(uuid, uuid, uuid)
    FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 9. Ratings and reviews submission.
-- ---------------------------------------------------------------------------
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

    IF v_subject.subject_type = 'entity' THEN
        IF EXISTS (
            SELECT 1 FROM core.entities e
             WHERE e.id = v_subject.entity_id AND e.owner_id = v_profile_id
            UNION ALL
            SELECT 1 FROM core.entities e
             WHERE e.id = v_subject.entity_id AND e.primary_contact_profile_id = v_profile_id
            UNION ALL
            SELECT 1 FROM core.entity_members m
             WHERE m.entity_id = v_subject.entity_id AND m.profile_id = v_profile_id
               AND m.is_active AND m.membership_status = 'active' AND m.can_manage
        ) THEN
            RAISE EXCEPTION 'self-review is not allowed' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_engagement_id IS NOT NULL THEN
        IF v_subject.subject_type = 'item' THEN
            SELECT * INTO v_product
              FROM reputation.resolve_verified_product_review_eligibility(
                  p_engagement_id, v_profile_id, p_subject_id
              );
            IF v_product.eligibility_status = 'eligible' THEN
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
            END IF;
        ELSE
            SELECT * INTO v_base
              FROM reputation.resolve_verified_review_eligibility(
                  p_engagement_id, v_profile_id
              );
            IF v_base.eligibility_status = 'eligible'
               AND v_base.subject_id = p_subject_id THEN
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

CREATE OR REPLACE FUNCTION reputation.edit_rating(
    p_rating_id uuid,
    p_rating smallint
)
RETURNS TABLE (
    rating_id uuid,
    outcome text,
    verification_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_profile_id uuid;
    v_rating reputation.ratings%ROWTYPE;
    v_revision integer;
BEGIN
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'rating must be between 1 and 5' USING ERRCODE = '22023';
    END IF;
    v_profile_id := core.current_profile_id();
    SELECT * INTO v_rating FROM reputation.ratings WHERE id = p_rating_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Rating not found' USING ERRCODE = 'P0002'; END IF;
    IF v_rating.reviewer_profile_id IS DISTINCT FROM v_profile_id THEN
        RAISE EXCEPTION 'not authorized to edit this rating' USING ERRCODE = '42501';
    END IF;
    SELECT COALESCE(max(revision_number), 0) + 1 INTO v_revision
      FROM reputation.rating_revisions rr WHERE rr.rating_id = p_rating_id;
    INSERT INTO reputation.rating_revisions (
        rating_id, revision_number, previous_rating, rating, edited_by_profile_id
    ) VALUES (p_rating_id, v_revision, v_rating.rating, p_rating, v_profile_id);
    UPDATE reputation.ratings
       SET rating = p_rating, updated_at = clock_timestamp()
     WHERE id = p_rating_id;
    INSERT INTO reputation.rating_review_events (
        target_type, target_id, event_type, actor_profile_id, details
    ) VALUES ('rating', p_rating_id, 'edited', v_profile_id,
              jsonb_build_object('previous_rating', v_rating.rating, 'rating', p_rating));
    RETURN QUERY SELECT p_rating_id, 'edited'::text, v_rating.verification_status;
END;
$function$;

ALTER FUNCTION reputation.edit_rating(uuid, smallint) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.edit_rating(uuid, smallint)
    FROM PUBLIC, anon, authenticated, service_role;

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

    IF p_rating_id IS NOT NULL THEN
        SELECT * INTO v_rating FROM reputation.ratings
         WHERE id = p_rating_id AND reviewer_profile_id = v_profile_id AND subject_id = p_subject_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Linked rating must belong to the same reviewer and subject'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF p_engagement_id IS NOT NULL THEN
        IF v_subject.subject_type = 'item' THEN
            SELECT * INTO v_product FROM reputation.resolve_verified_product_review_eligibility(
                p_engagement_id, v_profile_id, p_subject_id);
            IF v_product.eligibility_status = 'eligible' THEN
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
            END IF;
        ELSE
            SELECT * INTO v_base FROM reputation.resolve_verified_review_eligibility(
                p_engagement_id, v_profile_id);
            IF v_base.eligibility_status = 'eligible' AND v_base.subject_id = p_subject_id THEN
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
    END IF;

    INSERT INTO reputation.reviews (
        subject_id, reviewer_profile_id, rating_id, engagement_id, title, body,
        verification_status, status, public_identity_mode,
        reviewer_display_name_snapshot, reviewer_avatar_snapshot,
        current_revision_number
    ) VALUES (
        p_subject_id, v_profile_id, p_rating_id, p_engagement_id,
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

CREATE OR REPLACE FUNCTION reputation.edit_review(
    p_review_id uuid,
    p_body text,
    p_title text DEFAULT NULL,
    p_rating_id uuid DEFAULT NULL,
    p_public_identity_mode text DEFAULT 'display_name'
)
RETURNS TABLE (
    review_id uuid,
    outcome text,
    verification_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_profile_id uuid;
    v_review reputation.reviews%ROWTYPE;
    v_rating reputation.ratings%ROWTYPE;
    v_revision integer;
    v_body text := btrim(COALESCE(p_body, ''));
BEGIN
    IF v_body = '' OR length(v_body) > 20000 THEN
        RAISE EXCEPTION 'body is required and must be at most 20000 characters' USING ERRCODE = '22023';
    END IF;
    IF p_public_identity_mode NOT IN ('display_name', 'anonymous') THEN
        RAISE EXCEPTION 'invalid public identity mode' USING ERRCODE = '22023';
    END IF;
    v_profile_id := core.current_profile_id();
    SELECT * INTO v_review FROM reputation.reviews WHERE id = p_review_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Review not found' USING ERRCODE = 'P0002'; END IF;
    IF v_review.reviewer_profile_id IS DISTINCT FROM v_profile_id THEN
        RAISE EXCEPTION 'not authorized to edit this review' USING ERRCODE = '42501';
    END IF;
    IF p_rating_id IS NOT NULL THEN
        SELECT * INTO v_rating FROM reputation.ratings
         WHERE id = p_rating_id AND reviewer_profile_id = v_profile_id
           AND subject_id = v_review.subject_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Linked rating must belong to the same reviewer and subject'
                USING ERRCODE = '23514';
        END IF;
    END IF;
    SELECT COALESCE(max(revision_number), 0) + 1 INTO v_revision
      FROM reputation.review_revisions rr WHERE rr.review_id = p_review_id;
    INSERT INTO reputation.review_revisions (
        review_id, revision_number, previous_title, title, previous_body, body,
        edited_by_profile_id
    ) VALUES (
        p_review_id, v_revision, v_review.title,
        NULLIF(btrim(COALESCE(p_title, '')), ''),
        v_review.body, v_body, v_profile_id
    );
    UPDATE reputation.reviews
       SET title = NULLIF(btrim(COALESCE(p_title, '')), ''),
           body = v_body,
           rating_id = p_rating_id,
           public_identity_mode = p_public_identity_mode,
           current_revision_number = v_revision,
           updated_at = clock_timestamp()
     WHERE id = p_review_id;
    INSERT INTO reputation.rating_review_events (
        target_type, target_id, event_type, actor_profile_id, details
    ) VALUES ('review', p_review_id, 'edited', v_profile_id,
              jsonb_build_object('revision_number', v_revision));
    RETURN QUERY SELECT p_review_id, 'edited'::text, v_review.verification_status;
END;
$function$;

ALTER FUNCTION reputation.edit_review(uuid, text, text, uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.edit_review(uuid, text, text, uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 10. Moderation, reports and responses.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.moderate_rating_review(
    p_target_type text,
    p_target_id uuid,
    p_action text,
    p_reason text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_profile_id uuid;
    v_status text;
BEGIN
    IF NOT (core.has_permission('reputation.reviews.moderate') OR core.has_permission('admin.overview')) THEN
        RAISE EXCEPTION 'review moderation permission required' USING ERRCODE = '42501';
    END IF;
    v_profile_id := core.current_profile_id();
    IF p_action NOT IN ('publish', 'hide', 'remove', 'restore') THEN
        RAISE EXCEPTION 'invalid moderation action' USING ERRCODE = '22023';
    END IF;
    IF p_target_type = 'rating' THEN
        v_status := CASE p_action WHEN 'remove' THEN 'removed' WHEN 'hide' THEN 'hidden' ELSE 'published' END;
        UPDATE reputation.ratings SET status = v_status, updated_at = clock_timestamp()
         WHERE id = p_target_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'Rating not found' USING ERRCODE = 'P0002'; END IF;
    ELSIF p_target_type = 'review' THEN
        v_status := CASE p_action WHEN 'remove' THEN 'removed' WHEN 'hide' THEN 'hidden' ELSE 'published' END;
        UPDATE reputation.reviews SET status = v_status, updated_at = clock_timestamp()
         WHERE id = p_target_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'Review not found' USING ERRCODE = 'P0002'; END IF;
    ELSIF p_target_type = 'response' THEN
        v_status := CASE p_action WHEN 'remove' THEN 'removed' WHEN 'hide' THEN 'hidden' ELSE 'published' END;
        UPDATE reputation.review_responses
           SET status = v_status, moderated_by_profile_id = v_profile_id,
               moderated_at = clock_timestamp(), updated_at = clock_timestamp()
         WHERE id = p_target_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'Response not found' USING ERRCODE = 'P0002'; END IF;
    ELSE
        RAISE EXCEPTION 'invalid moderation target type' USING ERRCODE = '22023';
    END IF;
    INSERT INTO reputation.rating_review_events (
        target_type, target_id, event_type, actor_profile_id, details
    ) VALUES (p_target_type, p_target_id, 'moderated', v_profile_id,
              jsonb_build_object('action', p_action, 'status', v_status, 'reason', p_reason));
    RETURN v_status;
END;
$function$;

ALTER FUNCTION reputation.moderate_rating_review(text, uuid, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.moderate_rating_review(text, uuid, text, text)
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION reputation.report_rating_review(
    p_target_type text,
    p_target_id uuid,
    p_reason_code text,
    p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_profile_id uuid;
    v_id uuid;
BEGIN
    v_profile_id := core.current_profile_id();
    IF v_profile_id IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501'; END IF;
    IF p_target_type NOT IN ('rating', 'review') OR btrim(COALESCE(p_reason_code, '')) = '' THEN
        RAISE EXCEPTION 'valid target type and reason_code are required' USING ERRCODE = '22023';
    END IF;
    IF p_target_type = 'rating' AND NOT EXISTS (SELECT 1 FROM reputation.ratings WHERE id = p_target_id) THEN
        RAISE EXCEPTION 'Rating not found' USING ERRCODE = 'P0002';
    END IF;
    IF p_target_type = 'review' AND NOT EXISTS (SELECT 1 FROM reputation.reviews WHERE id = p_target_id) THEN
        RAISE EXCEPTION 'Review not found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO reputation.rating_review_reports (
        target_type, target_id, reporter_profile_id, reason_code, reason
    ) VALUES (p_target_type, p_target_id, v_profile_id, btrim(p_reason_code), NULLIF(btrim(COALESCE(p_reason, '')), ''))
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$function$;

ALTER FUNCTION reputation.report_rating_review(text, uuid, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.report_rating_review(text, uuid, text, text)
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION reputation.respond_to_review(
    p_review_id uuid,
    p_body text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_profile_id uuid;
    v_review reputation.reviews%ROWTYPE;
    v_seller_entity_id uuid;
    v_changed integer;
    v_response_id uuid;
BEGIN
    v_profile_id := core.current_profile_id();
    IF v_profile_id IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501'; END IF;
    IF btrim(COALESCE(p_body, '')) = '' OR length(p_body) > 5000 THEN
        RAISE EXCEPTION 'response body is required and must be at most 5000 characters' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO v_review FROM reputation.reviews WHERE id = p_review_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Review not found' USING ERRCODE = 'P0002'; END IF;

    SELECT seller_entity_id INTO v_seller_entity_id
      FROM reputation.verification_snapshots
     WHERE review_id = p_review_id AND seller_entity_id IS NOT NULL
     ORDER BY created_at DESC LIMIT 1;

    IF v_seller_entity_id IS NULL AND v_review.engagement_id IS NOT NULL THEN
        SELECT entity_id INTO v_seller_entity_id
          FROM reputation.engagement_participants
         WHERE engagement_id = v_review.engagement_id AND party_role = 'seller'
         LIMIT 1;
    END IF;
    IF v_seller_entity_id IS NULL THEN
        RAISE EXCEPTION 'Seller response target cannot be resolved' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM core.entities e
         WHERE e.id = v_seller_entity_id AND e.owner_id = v_profile_id
    ) AND NOT EXISTS (
        SELECT 1 FROM core.entity_members m
         WHERE m.entity_id = v_seller_entity_id AND m.profile_id = v_profile_id
           AND m.is_active AND m.membership_status = 'active' AND m.can_manage
    ) AND NOT core.has_permission('admin.overview') THEN
        RAISE EXCEPTION 'not authorized to respond for this seller' USING ERRCODE = '42501';
    END IF;

    INSERT INTO reputation.review_responses (
        review_id, responder_entity_id, body, status
    ) VALUES (p_review_id, v_seller_entity_id, btrim(p_body), 'pending')
    ON CONFLICT (review_id) DO UPDATE SET
        body = EXCLUDED.body, status = 'pending', updated_at = clock_timestamp()
    RETURNING id INTO v_response_id;

    INSERT INTO reputation.rating_review_events (
        target_type, target_id, event_type, actor_profile_id, details
    ) VALUES ('response', v_response_id, 'submitted', v_profile_id,
              jsonb_build_object('review_id', p_review_id, 'seller_entity_id', v_seller_entity_id));
    RETURN v_response_id;
END;
$function$;

ALTER FUNCTION reputation.respond_to_review(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.respond_to_review(uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 11. Sanitized public reads.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.get_subject_rating_summary(p_subject_id uuid)
RETURNS TABLE (
    subject_id uuid,
    verified_rating_count integer,
    verified_rating_average numeric,
    verified_distribution jsonb,
    unverified_rating_count integer,
    unverified_distribution jsonb,
    review_count integer,
    updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
    SELECT
        s.subject_id,
        s.verified_rating_count,
        s.verified_rating_average,
        jsonb_build_object(
            '1', s.verified_1_count, '2', s.verified_2_count,
            '3', s.verified_3_count, '4', s.verified_4_count,
            '5', s.verified_5_count
        ),
        s.unverified_rating_count,
        jsonb_build_object(
            '1', s.unverified_1_count, '2', s.unverified_2_count,
            '3', s.unverified_3_count, '4', s.unverified_4_count,
            '5', s.unverified_5_count
        ),
        (SELECT count(*)::integer FROM reputation.reviews r
          WHERE r.subject_id = p_subject_id AND r.status = 'published'),
        s.updated_at
      FROM reputation.subject_rating_summaries s
     WHERE s.subject_id = p_subject_id;
$function$;

ALTER FUNCTION reputation.get_subject_rating_summary(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.get_subject_rating_summary(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION reputation.list_subject_reviews(
    p_subject_id uuid,
    p_cursor_created_at timestamptz DEFAULT NULL,
    p_cursor_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 20
)
RETURNS TABLE (
    review_id uuid,
    subject_id uuid,
    rating smallint,
    title text,
    body text,
    verification_status text,
    reviewer_display_name text,
    reviewer_avatar text,
    response_body text,
    response_status text,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
    SELECT
        r.id,
        r.subject_id,
        rt.rating,
        r.title,
        r.body,
        r.verification_status,
        CASE WHEN r.public_identity_mode = 'anonymous' THEN NULL ELSE r.reviewer_display_name_snapshot END,
        CASE WHEN r.public_identity_mode = 'anonymous' THEN NULL ELSE r.reviewer_avatar_snapshot END,
        CASE WHEN resp.status = 'published' THEN resp.body ELSE NULL END,
        resp.status,
        r.created_at
      FROM reputation.reviews r
      LEFT JOIN reputation.ratings rt
        ON rt.id = r.rating_id AND rt.status = 'published'
      LEFT JOIN reputation.review_responses resp
        ON resp.review_id = r.id
     WHERE r.subject_id = p_subject_id
       AND r.status = 'published'
       AND (
           p_cursor_created_at IS NULL
           OR (r.created_at, r.id) < (p_cursor_created_at, COALESCE(p_cursor_id, '00000000-0000-0000-0000-000000000000'::uuid))
       )
     ORDER BY r.created_at DESC, r.id DESC
     LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
$function$;

ALTER FUNCTION reputation.list_subject_reviews(uuid, timestamptz, uuid, integer) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.list_subject_reviews(uuid, timestamptz, uuid, integer)
    FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 12. Subject lookup and authenticated author state.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.product_subject_for_variant(p_variant_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core'
AS $function$
    SELECT s.id
      FROM core.item_variants iv
      JOIN reputation.subjects s
        ON s.item_id = iv.item_id
       AND s.subject_type = 'item'
       AND s.subject_role = 'product'
       AND s.status = 'active'
     WHERE iv.id = p_variant_id
     LIMIT 1
$function$;

ALTER FUNCTION reputation.product_subject_for_variant(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.product_subject_for_variant(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION reputation.seller_subject_for_entity(p_entity_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core'
AS $function$
    SELECT s.id
      FROM reputation.subjects s
     WHERE s.entity_id = p_entity_id
       AND s.subject_type = 'entity'
       AND s.subject_role = 'seller'
       AND s.status = 'active'
     LIMIT 1
$function$;

ALTER FUNCTION reputation.seller_subject_for_entity(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.seller_subject_for_entity(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION reputation.get_my_subject_state(p_subject_id uuid)
RETURNS TABLE (
    rating_id uuid,
    rating smallint,
    rating_verification_status text,
    review_id uuid,
    review_title text,
    review_body text,
    review_rating_id uuid,
    review_verification_status text,
    review_public_identity_mode text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core'
AS $function$
BEGIN
    RETURN QUERY
    WITH me AS (
        SELECT core.current_profile_id() AS profile_id
    )
    SELECT
        r.id,
        r.rating,
        r.verification_status,
        v.id,
        v.title,
        v.body,
        v.rating_id,
        v.verification_status,
        v.public_identity_mode
      FROM me
      LEFT JOIN reputation.ratings r
        ON r.subject_id = p_subject_id
       AND r.reviewer_profile_id = me.profile_id
      LEFT JOIN LATERAL (
          SELECT x.*
            FROM reputation.reviews x
           WHERE x.subject_id = p_subject_id
             AND x.reviewer_profile_id = me.profile_id
           ORDER BY x.created_at DESC, x.id DESC
           LIMIT 1
      ) v ON true;
END;
$function$;

ALTER FUNCTION reputation.get_my_subject_state(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION reputation.get_my_subject_state(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 13. System/PostgREST gateway wrappers.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION system.ensure_reputation_product_subject(p_variant_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT reputation.ensure_product_subject(p_variant_id) $function$;

CREATE OR REPLACE FUNCTION system.ensure_reputation_seller_subject(p_entity_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT reputation.ensure_seller_subject(p_entity_id) $function$;

CREATE OR REPLACE FUNCTION system.resolve_reputation_product_subject(p_variant_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT reputation.product_subject_for_variant(p_variant_id) $function$;

CREATE OR REPLACE FUNCTION system.resolve_reputation_seller_subject(p_entity_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT reputation.seller_subject_for_entity(p_entity_id) $function$;

CREATE OR REPLACE FUNCTION system.get_my_reputation_subject_state(p_subject_id uuid)
RETURNS TABLE (
    rating_id uuid,
    rating smallint,
    rating_verification_status text,
    review_id uuid,
    review_title text,
    review_body text,
    review_rating_id uuid,
    review_verification_status text,
    review_public_identity_mode text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT * FROM reputation.get_my_subject_state(p_subject_id) $function$;

CREATE OR REPLACE FUNCTION system.get_reputation_rating_summary(p_subject_id uuid)
RETURNS TABLE (
    subject_id uuid,
    verified_rating_count integer,
    verified_rating_average numeric,
    verified_distribution jsonb,
    unverified_rating_count integer,
    unverified_distribution jsonb,
    review_count integer,
    updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT * FROM reputation.get_subject_rating_summary(p_subject_id) $function$;

CREATE OR REPLACE FUNCTION system.list_reputation_reviews(
    p_subject_id uuid,
    p_cursor_created_at timestamptz DEFAULT NULL,
    p_cursor_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 20
)
RETURNS TABLE (
    review_id uuid,
    subject_id uuid,
    rating smallint,
    title text,
    body text,
    verification_status text,
    reviewer_display_name text,
    reviewer_avatar text,
    response_body text,
    response_status text,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
    SELECT * FROM reputation.list_subject_reviews(
        p_subject_id, p_cursor_created_at, p_cursor_id, p_limit
    )
$function$;

CREATE OR REPLACE FUNCTION system.submit_reputation_rating(
    p_subject_id uuid,
    p_rating smallint,
    p_engagement_id uuid DEFAULT NULL
)
RETURNS TABLE (rating_id uuid, outcome text, verification_status text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT * FROM reputation.submit_rating(p_subject_id, p_rating, p_engagement_id) $function$;

CREATE OR REPLACE FUNCTION system.edit_reputation_rating(p_rating_id uuid, p_rating smallint)
RETURNS TABLE (rating_id uuid, outcome text, verification_status text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT * FROM reputation.edit_rating(p_rating_id, p_rating) $function$;

CREATE OR REPLACE FUNCTION system.submit_reputation_review(
    p_subject_id uuid,
    p_body text,
    p_title text DEFAULT NULL,
    p_rating_id uuid DEFAULT NULL,
    p_engagement_id uuid DEFAULT NULL,
    p_public_identity_mode text DEFAULT 'display_name'
)
RETURNS TABLE (review_id uuid, outcome text, verification_status text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
    SELECT * FROM reputation.submit_review(
        p_subject_id, p_body, p_title, p_rating_id, p_engagement_id, p_public_identity_mode
    )
$function$;

CREATE OR REPLACE FUNCTION system.edit_reputation_review(
    p_review_id uuid,
    p_body text,
    p_title text DEFAULT NULL,
    p_rating_id uuid DEFAULT NULL,
    p_public_identity_mode text DEFAULT 'display_name'
)
RETURNS TABLE (review_id uuid, outcome text, verification_status text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
    SELECT * FROM reputation.edit_review(
        p_review_id, p_body, p_title, p_rating_id, p_public_identity_mode
    )
$function$;

CREATE OR REPLACE FUNCTION system.report_reputation_content(
    p_target_type text,
    p_target_id uuid,
    p_reason_code text,
    p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT reputation.report_rating_review(p_target_type, p_target_id, p_reason_code, p_reason) $function$;

CREATE OR REPLACE FUNCTION system.respond_to_reputation_review(p_review_id uuid, p_body text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT reputation.respond_to_review(p_review_id, p_body) $function$;

CREATE OR REPLACE FUNCTION system.moderate_reputation_content(
    p_target_type text,
    p_target_id uuid,
    p_action text,
    p_reason text DEFAULT NULL
)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$ SELECT reputation.moderate_rating_review(p_target_type, p_target_id, p_action, p_reason) $function$;

REVOKE ALL ON FUNCTION system.resolve_reputation_product_subject(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.resolve_reputation_seller_subject(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.get_my_reputation_subject_state(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.ensure_reputation_product_subject(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.ensure_reputation_seller_subject(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.get_reputation_rating_summary(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.list_reputation_reviews(uuid, timestamptz, uuid, integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.submit_reputation_rating(uuid, smallint, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.edit_reputation_rating(uuid, smallint) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.submit_reputation_review(uuid, text, text, uuid, uuid, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.edit_reputation_review(uuid, text, text, uuid, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.report_reputation_content(text, uuid, text, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.respond_to_reputation_review(uuid, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.moderate_reputation_content(text, uuid, text, text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION system.resolve_reputation_product_subject(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION system.resolve_reputation_seller_subject(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION system.get_my_reputation_subject_state(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION system.ensure_reputation_product_subject(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION system.ensure_reputation_seller_subject(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION system.get_reputation_rating_summary(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION system.list_reputation_reviews(uuid, timestamptz, uuid, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION system.submit_reputation_rating(uuid, smallint, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION system.edit_reputation_rating(uuid, smallint) TO authenticated;
GRANT EXECUTE ON FUNCTION system.submit_reputation_review(uuid, text, text, uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION system.edit_reputation_review(uuid, text, text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION system.report_reputation_content(text, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION system.respond_to_reputation_review(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION system.moderate_reputation_content(text, uuid, text, text) TO authenticated, service_role;

COMMIT;

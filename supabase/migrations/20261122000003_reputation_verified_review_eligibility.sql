-- Reputation Phase 3A - verified review eligibility foundation.
--
-- Eligibility is derived from immutable engagement/evidence state. No mutable
-- eligibility table or boolean is introduced. The future review-submission RPC
-- must lock the engagement row, recompute this resolver in the same transaction,
-- and store an immutable verification snapshot.

BEGIN;

CREATE OR REPLACE FUNCTION reputation.resolve_verified_review_eligibility(
    p_engagement_id uuid,
    p_reviewer_profile_id uuid
)
RETURNS TABLE (
    eligibility_status text,
    reason_code text,
    engagement_id uuid,
    reviewer_profile_id uuid,
    subject_id uuid,
    evidence_id uuid,
    evidence_source_version text,
    evidence_snapshot_hash bytea,
    rule_version smallint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_engagement reputation.engagements%ROWTYPE;
    v_state record;
    v_reviewer record;
    v_buyer_count integer;
    v_seller_count integer;
    v_seller_entity_id uuid;
    v_subject record;
    v_subject_count integer;
    v_evidence record;
    v_evidence_count integer;
    v_has_conflict boolean;
    v_has_integrity_issue boolean;
    v_is_owner boolean;
    v_is_primary_contact boolean;
    v_is_manager boolean;
BEGIN
    IF p_engagement_id IS NULL OR p_reviewer_profile_id IS NULL THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'invalid_request'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT e.*
      INTO v_engagement
      FROM reputation.engagements AS e
     WHERE e.id = p_engagement_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'engagement_not_found'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_engagement.engagement_kind <> 'vunio_order' THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'unsupported_engagement_kind'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_engagement.commerce_order_id IS NULL THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'missing_commerce_order'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT st.*
      INTO v_state
      FROM reputation.v_engagement_current_state AS st
     WHERE st.engagement_id = p_engagement_id;

    IF v_state.status = 'voided' THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'engagement_voided'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_state.status = 'disputed' THEN
        RETURN QUERY SELECT
            'suspended'::text, 'engagement_suspended'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_state.status <> 'active' THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'engagement_not_active'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_state.source_outcome IS DISTINCT FROM 'completed' THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'source_outcome_not_completed'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_state.source_integrity_status IS DISTINCT FROM 'consistent' THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'engagement_integrity_not_consistent'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT p.*
      INTO v_reviewer
      FROM users.profiles AS p
     WHERE p.id = p_reviewer_profile_id;

    IF NOT FOUND
       OR v_reviewer.deleted_at IS NOT NULL
       OR v_reviewer.is_active IS NOT TRUE
       OR v_reviewer.account_status IS DISTINCT FROM 'active' THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'reviewer_inactive'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT count(*)
      INTO v_buyer_count
      FROM reputation.engagement_participants AS ep
     WHERE ep.engagement_id = p_engagement_id
       AND ep.party_role = 'buyer'
       AND ep.profile_id = p_reviewer_profile_id;

    IF v_buyer_count <> 1 THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'reviewer_not_buyer'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT count(*)
      INTO v_seller_count
      FROM reputation.engagement_participants AS ep
     WHERE ep.engagement_id = p_engagement_id
       AND ep.party_role = 'seller'
       AND ep.entity_id IS NOT NULL;

    IF v_seller_count <> 1 THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'seller_participant_missing'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT ep.entity_id
      INTO v_seller_entity_id
      FROM reputation.engagement_participants AS ep
     WHERE ep.engagement_id = p_engagement_id
       AND ep.party_role = 'seller'
       AND ep.entity_id IS NOT NULL;

    IF v_seller_entity_id IS NULL THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'seller_participant_missing'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT count(*)
      INTO v_subject_count
      FROM reputation.engagement_subjects AS es
     WHERE es.engagement_id = p_engagement_id
       AND es.relationship = 'seller_entity';

    IF v_subject_count <> 1 THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'seller_subject_missing'::text,
            p_engagement_id, p_reviewer_profile_id,
            NULL::uuid, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT es.subject_id, s.status AS subject_status, s.subject_type,
           s.subject_role, s.entity_id
      INTO v_subject
      FROM reputation.engagement_subjects AS es
      JOIN reputation.subjects AS s ON s.id = es.subject_id
     WHERE es.engagement_id = p_engagement_id
       AND es.relationship = 'seller_entity';

    IF v_subject.subject_status <> 'active' THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'subject_retired'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_subject.subject_type <> 'entity'
       OR v_subject.subject_role <> 'seller'
       OR v_subject.entity_id IS DISTINCT FROM v_seller_entity_id THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'seller_subject_mismatch'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT (ent.owner_id = p_reviewer_profile_id) AS is_owner,
           (ent.primary_contact_profile_id = p_reviewer_profile_id) AS is_primary_contact
      INTO v_is_owner, v_is_primary_contact
      FROM core.entities AS ent
     WHERE ent.id = v_seller_entity_id;

    IF v_is_owner THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'self_review_owner'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_is_primary_contact THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'self_review_primary_contact'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT EXISTS (
        SELECT 1
          FROM core.entity_members AS em
         WHERE em.entity_id = v_seller_entity_id
           AND em.profile_id = p_reviewer_profile_id
           AND em.is_active = true
           AND em.membership_status = 'active'
           AND em.can_manage = true
    ) INTO v_is_manager;

    IF v_is_manager THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'self_review_manager'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    SELECT v.evidence_id, v.source_version, v.source_snapshot_hash
      INTO v_evidence
      FROM reputation.v_evidence_current_state AS v
     WHERE v.engagement_id = p_engagement_id
       AND v.evidence_type = 'commerce_order_delivery'
       AND v.source_system = 'commerce'
       AND v.source_reference = v_engagement.commerce_order_id::text
       AND v.evidence_status = 'active'
       AND v.source_integrity_status = 'consistent'
       AND v.unresolved_conflict_count = 0
     ORDER BY
       substring(v.source_version from '^delivery:v([0-9]+)$')::integer DESC,
       v.recorded_at DESC,
       v.evidence_id DESC
     LIMIT 1;

    IF FOUND THEN
        RETURN QUERY SELECT
            'eligible'::text, NULL::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, v_evidence.evidence_id,
            v_evidence.source_version, v_evidence.source_snapshot_hash,
            1::smallint;
        RETURN;
    END IF;

    SELECT count(*),
           COALESCE(bool_or(v.evidence_status = 'conflicted'), false),
           COALESCE(bool_or(v.source_integrity_status IS DISTINCT FROM 'consistent'), false)
      INTO v_evidence_count, v_has_conflict, v_has_integrity_issue
      FROM reputation.v_evidence_current_state AS v
     WHERE v.engagement_id = p_engagement_id
       AND v.evidence_type = 'commerce_order_delivery'
       AND v.source_system = 'commerce'
       AND v.source_reference = v_engagement.commerce_order_id::text;

    IF v_evidence_count = 0 THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'evidence_missing'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_has_conflict THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'evidence_conflicted'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    IF v_has_integrity_issue THEN
        RETURN QUERY SELECT
            'ineligible'::text, 'evidence_integrity_not_consistent'::text,
            p_engagement_id, p_reviewer_profile_id,
            v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
        RETURN;
    END IF;

    RETURN QUERY SELECT
        'ineligible'::text, 'evidence_not_active'::text,
        p_engagement_id, p_reviewer_profile_id,
        v_subject.subject_id, NULL::uuid, NULL::text, NULL::bytea, 1::smallint;
END;
$function$;

ALTER FUNCTION reputation.resolve_verified_review_eligibility(uuid, uuid)
    OWNER TO postgres;

COMMENT ON FUNCTION reputation.resolve_verified_review_eligibility(uuid, uuid) IS
    'Derives stock-order verified review eligibility from immutable engagement, participant, subject and evidence state.';

CREATE OR REPLACE FUNCTION system.resolve_reputation_review_eligibility(
    p_engagement_id uuid,
    p_reviewer_profile_id uuid
)
RETURNS TABLE (
    eligible boolean,
    eligibility_status text,
    reason_code text,
    engagement_id uuid,
    subject_id uuid,
    rule_version smallint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.eligibility_status = 'eligible',
        r.eligibility_status,
        r.reason_code,
        r.engagement_id,
        r.subject_id,
        r.rule_version
    FROM reputation.resolve_verified_review_eligibility(
        p_engagement_id,
        p_reviewer_profile_id
    ) AS r;
END;
$function$;

ALTER FUNCTION system.resolve_reputation_review_eligibility(uuid, uuid)
    OWNER TO postgres;

COMMENT ON FUNCTION system.resolve_reputation_review_eligibility(uuid, uuid) IS
    'Service-role-only sanitized verified review eligibility gateway.';

REVOKE ALL ON FUNCTION reputation.resolve_verified_review_eligibility(uuid, uuid)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.resolve_reputation_review_eligibility(uuid, uuid)
    FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION system.resolve_reputation_review_eligibility(uuid, uuid)
    TO service_role;

COMMIT;

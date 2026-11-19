-- Reputation Phase 2B - service-role evidence gateways.
--
-- The reputation schema is not exposed through PostgREST. These narrow system
-- gateway functions are the only trusted server-side entry points.

BEGIN;

CREATE OR REPLACE FUNCTION system.capture_reputation_order_evidence(
    p_engagement_id uuid,
    p_capture_actor_profile_id uuid DEFAULT NULL,
    p_request_id text DEFAULT NULL
)
RETURNS TABLE (
    evidence_id uuid,
    outcome text,
    evidence_status text,
    conflict_event_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
DECLARE
    v_provenance jsonb;
BEGIN
    IF p_request_id IS NOT NULL
       AND length(p_request_id) > 200 THEN
        RAISE EXCEPTION 'request_id is too long'
            USING ERRCODE = '22023';
    END IF;

    v_provenance := jsonb_strip_nulls(
        jsonb_build_object(
            'gateway', 'system.capture_reputation_order_evidence',
            'request_id', NULLIF(btrim(COALESCE(p_request_id, '')), '')
        )
    );

    RETURN QUERY
    SELECT
        r.evidence_id,
        r.outcome,
        r.evidence_status,
        r.conflict_event_id
    FROM reputation.capture_order_delivery_evidence(
        p_engagement_id,
        'trusted_service',
        'system.capture_reputation_order_evidence',
        p_capture_actor_profile_id,
        v_provenance
    ) AS r;
END;
$function$;

ALTER FUNCTION system.capture_reputation_order_evidence(uuid, uuid, text)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION system.revoke_reputation_evidence(
    p_evidence_id uuid,
    p_reason_code text,
    p_reason text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS TABLE (
    evidence_id uuid,
    outcome text,
    evidence_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.evidence_id,
        r.outcome,
        r.evidence_status
    FROM reputation.revoke_evidence(
        p_evidence_id,
        p_reason_code,
        p_reason,
        p_actor_profile_id,
        'system.revoke_reputation_evidence'
    ) AS r;
END;
$function$;

ALTER FUNCTION system.revoke_reputation_evidence(uuid, text, text, uuid)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION system.resolve_reputation_evidence_conflict(
    p_conflict_event_id uuid,
    p_resolution_code text,
    p_reason text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS TABLE (
    conflict_event_id uuid,
    outcome text,
    evidence_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.conflict_event_id,
        r.outcome,
        r.evidence_status
    FROM reputation.resolve_evidence_conflict(
        p_conflict_event_id,
        p_resolution_code,
        p_reason,
        p_actor_profile_id,
        'system.resolve_reputation_evidence_conflict'
    ) AS r;
END;
$function$;

ALTER FUNCTION system.resolve_reputation_evidence_conflict(uuid, text, text, uuid)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION system.supersede_reputation_order_evidence(
    p_engagement_id uuid,
    p_supersedes_evidence_id uuid,
    p_source_version text,
    p_capture_actor_profile_id uuid DEFAULT NULL,
    p_request_id text DEFAULT NULL
)
RETURNS TABLE (
    evidence_id uuid,
    superseded_evidence_id uuid,
    outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
DECLARE
    v_provenance jsonb;
BEGIN
    IF p_request_id IS NOT NULL
       AND length(p_request_id) > 200 THEN
        RAISE EXCEPTION 'request_id is too long'
            USING ERRCODE = '22023';
    END IF;

    v_provenance := jsonb_strip_nulls(
        jsonb_build_object(
            'gateway', 'system.supersede_reputation_order_evidence',
            'request_id', NULLIF(btrim(COALESCE(p_request_id, '')), '')
        )
    );

    RETURN QUERY
    SELECT
        r.evidence_id,
        r.superseded_evidence_id,
        r.outcome
    FROM reputation.capture_order_delivery_evidence_correction(
        p_engagement_id,
        p_supersedes_evidence_id,
        p_source_version,
        'trusted_service',
        'system.supersede_reputation_order_evidence',
        p_capture_actor_profile_id,
        v_provenance
    ) AS r;
END;
$function$;

ALTER FUNCTION system.supersede_reputation_order_evidence(
    uuid, uuid, text, uuid, text
) OWNER TO postgres;

COMMENT ON FUNCTION system.capture_reputation_order_evidence(uuid, uuid, text) IS
    'Service-role-only delivery evidence capture gateway.';
COMMENT ON FUNCTION system.revoke_reputation_evidence(uuid, text, text, uuid) IS
    'Service-role-only evidence revocation gateway.';
COMMENT ON FUNCTION system.resolve_reputation_evidence_conflict(uuid, text, text, uuid) IS
    'Service-role-only evidence conflict resolution gateway.';
COMMENT ON FUNCTION system.supersede_reputation_order_evidence(uuid, uuid, text, uuid, text) IS
    'Service-role-only corrected delivery evidence supersession gateway.';

REVOKE ALL ON FUNCTION system.capture_reputation_order_evidence(uuid, uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.revoke_reputation_evidence(uuid, text, text, uuid)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.resolve_reputation_evidence_conflict(uuid, text, text, uuid)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.supersede_reputation_order_evidence(uuid, uuid, text, uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION system.capture_reputation_order_evidence(uuid, uuid, text)
    TO service_role;
GRANT EXECUTE ON FUNCTION system.revoke_reputation_evidence(uuid, text, text, uuid)
    TO service_role;
GRANT EXECUTE ON FUNCTION system.resolve_reputation_evidence_conflict(uuid, text, text, uuid)
    TO service_role;
GRANT EXECUTE ON FUNCTION system.supersede_reputation_order_evidence(uuid, uuid, text, uuid, text)
    TO service_role;

COMMIT;

-- Reputation Phase 2C-1 - service-role engagement ingestion gateway.
--
-- The reputation schema is not exposed through PostgREST. This narrow system
-- gateway is the only service-role entry point for stock-order engagement
-- ingestion.

BEGIN;

CREATE OR REPLACE FUNCTION system.ingest_reputation_stock_order_engagement(
    p_order_id uuid
)
RETURNS TABLE (
    engagement_id uuid,
    outcome text,
    reason_code text,
    details jsonb,
    source_event_id uuid,
    participant_count integer,
    subject_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.engagement_id,
        r.outcome,
        r.reason_code,
        r.details,
        r.source_event_id,
        r.participant_count,
        r.subject_count
    FROM reputation.ingest_stock_order_engagement(p_order_id) AS r;
END;
$function$;

ALTER FUNCTION system.ingest_reputation_stock_order_engagement(uuid)
    OWNER TO postgres;

COMMENT ON FUNCTION system.ingest_reputation_stock_order_engagement(uuid) IS
    'Service-role-only gateway for trusted Vunio stock-order engagement ingestion.';

REVOKE ALL ON FUNCTION system.ingest_reputation_stock_order_engagement(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION system.ingest_reputation_stock_order_engagement(uuid)
    TO service_role;

COMMIT;

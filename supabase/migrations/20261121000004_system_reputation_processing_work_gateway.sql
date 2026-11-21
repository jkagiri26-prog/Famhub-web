-- Reputation Phase 2C-2 - service-role processing work gateways.
--
-- The reputation schema is not exposed through PostgREST. These narrow system
-- gateways are the only trusted entry points for the processing ledger.

BEGIN;

CREATE OR REPLACE FUNCTION system.enqueue_reputation_stock_order_work(
    p_order_id uuid
)
RETURNS TABLE (
    work_id uuid,
    status text,
    created boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.work_id,
        r.status,
        r.created
    FROM reputation.enqueue_stock_order_engagement_work(p_order_id) AS r;
END;
$function$;

ALTER FUNCTION system.enqueue_reputation_stock_order_work(uuid)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION system.claim_reputation_processing_work(
    p_limit integer,
    p_worker_id text,
    p_lease_seconds integer
)
RETURNS TABLE (
    work_id uuid,
    work_kind text,
    source_system text,
    source_reference text,
    attempt_number integer,
    claim_token uuid,
    lease_expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.work_id,
        r.work_kind,
        r.source_system,
        r.source_reference,
        r.attempt_number,
        r.claim_token,
        r.lease_expires_at
    FROM reputation.claim_processing_work(
        p_limit,
        p_worker_id,
        p_lease_seconds
    ) AS r;
END;
$function$;

ALTER FUNCTION system.claim_reputation_processing_work(integer, text, integer)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION system.complete_reputation_processing_work(
    p_work_id uuid,
    p_claim_token uuid,
    p_outcome text,
    p_error_category text DEFAULT NULL,
    p_error_code text DEFAULT NULL,
    p_error_message text DEFAULT NULL,
    p_run_id text DEFAULT NULL
)
RETURNS TABLE (
    work_id uuid,
    status text,
    attempt_count integer,
    next_attempt_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'system', 'reputation'
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        r.work_id,
        r.status,
        r.attempt_count,
        r.next_attempt_at
    FROM reputation.complete_processing_work(
        p_work_id,
        p_claim_token,
        p_outcome,
        p_error_category,
        p_error_code,
        p_error_message,
        p_run_id
    ) AS r;
END;
$function$;

ALTER FUNCTION system.complete_reputation_processing_work(
    uuid, uuid, text, text, text, text, text
) OWNER TO postgres;

COMMENT ON FUNCTION system.enqueue_reputation_stock_order_work(uuid) IS
    'Service-role-only idempotent processing work enqueue gateway.';
COMMENT ON FUNCTION system.claim_reputation_processing_work(integer, text, integer) IS
    'Service-role-only processing work claim gateway.';
COMMENT ON FUNCTION system.complete_reputation_processing_work(
    uuid, uuid, text, text, text, text, text
) IS
    'Service-role-only processing work completion/retry gateway.';

REVOKE ALL ON FUNCTION system.enqueue_reputation_stock_order_work(uuid)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.claim_reputation_processing_work(integer, text, integer)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION system.complete_reputation_processing_work(
    uuid, uuid, text, text, text, text, text
)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION system.enqueue_reputation_stock_order_work(uuid)
    TO service_role;
GRANT EXECUTE ON FUNCTION system.claim_reputation_processing_work(integer, text, integer)
    TO service_role;
GRANT EXECUTE ON FUNCTION system.complete_reputation_processing_work(
    uuid, uuid, text, text, text, text, text
)
    TO service_role;

COMMIT;

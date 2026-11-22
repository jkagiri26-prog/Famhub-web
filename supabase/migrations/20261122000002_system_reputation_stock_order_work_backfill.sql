-- Reputation Phase 2C-5 - bounded historical stock-order work backfill.
--
-- This gateway pages delivered stock orders by UUID and reuses the existing
-- idempotent processing-work enqueue. It never writes to Commerce and never
-- reopens terminal work.

BEGIN;

CREATE OR REPLACE FUNCTION system.backfill_reputation_stock_order_work(
    p_limit integer DEFAULT 100,
    p_after_order_id uuid DEFAULT NULL
)
RETURNS TABLE (
    scanned_count integer,
    enqueued_count integer,
    existing_count integer,
    failed_count integer,
    failed_order_id uuid,
    failed_sqlstate text,
    failed_error_class text,
    last_processed_order_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $function$
DECLARE
    v_order_id uuid;
    v_enqueue record;
    v_scanned_count integer := 0;
    v_enqueued_count integer := 0;
    v_existing_count integer := 0;
    v_failed_count integer := 0;
    v_failed_order_id uuid;
    v_failed_sqlstate text;
    v_failed_error_class text;
    v_last_processed_order_id uuid;
BEGIN
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
        RAISE EXCEPTION 'Backfill limit must be between 1 and 500'
            USING ERRCODE = '22023';
    END IF;

    FOR v_order_id IN
        SELECT o.id
          FROM commerce.orders AS o
         WHERE o.status = 'delivered'
           AND o.order_kind = 'stock'
           AND o.delivered_at IS NOT NULL
           AND (p_after_order_id IS NULL OR o.id > p_after_order_id)
         ORDER BY o.id
         LIMIT p_limit
    LOOP
        v_scanned_count := v_scanned_count + 1;

        BEGIN
            SELECT *
              INTO v_enqueue
              FROM reputation.enqueue_stock_order_engagement_work(v_order_id);

            IF v_enqueue.created THEN
                v_enqueued_count := v_enqueued_count + 1;
            ELSE
                v_existing_count := v_existing_count + 1;
            END IF;

            v_last_processed_order_id := v_order_id;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_failed_sqlstate = RETURNED_SQLSTATE;

            v_failed_error_class := CASE
                WHEN v_failed_sqlstate LIKE '08%'
                  OR v_failed_sqlstate LIKE '40%'
                  OR v_failed_sqlstate LIKE '53%'
                  OR v_failed_sqlstate LIKE '57%'
                  OR v_failed_sqlstate LIKE '58%'
                    THEN 'transient_unavailable'
                WHEN v_failed_sqlstate IN ('42501', '28000', '28P01')
                    THEN 'permission_denied'
                WHEN v_failed_sqlstate IN ('42P01', '42883', '42703', '3F000', '3D000')
                    THEN 'missing_object'
                WHEN v_failed_sqlstate LIKE '22%'
                  OR v_failed_sqlstate LIKE '23%'
                    THEN 'constraint_violation'
                ELSE 'unknown_failure'
            END;

            RAISE WARNING
                'Reputation backfill enqueue failed: order_id=%, sqlstate=%',
                v_order_id, v_failed_sqlstate;

            v_failed_count := 1;
            v_failed_order_id := v_order_id;
            EXIT;
        END;
    END LOOP;

    RETURN QUERY SELECT
        v_scanned_count,
        v_enqueued_count,
        v_existing_count,
        v_failed_count,
        v_failed_order_id,
        v_failed_sqlstate,
        v_failed_error_class,
        v_last_processed_order_id;
END;
$function$;

ALTER FUNCTION system.backfill_reputation_stock_order_work(integer, uuid)
    OWNER TO postgres;

COMMENT ON FUNCTION system.backfill_reputation_stock_order_work(integer, uuid) IS
    'Service-role-only bounded backfill of delivered stock-order processing work. Retry using last_processed_order_id; never use failed_order_id as the cursor.';

REVOKE ALL ON FUNCTION system.backfill_reputation_stock_order_work(integer, uuid)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION system.backfill_reputation_stock_order_work(integer, uuid)
    TO service_role;

COMMIT;

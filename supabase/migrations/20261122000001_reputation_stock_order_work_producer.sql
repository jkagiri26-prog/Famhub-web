-- Reputation Phase 2C-5 - stock-order work producer.
--
-- Newly delivered stock orders enqueue their Reputation processing work in the
-- same transaction as the delivery update. Historical orders are handled by
-- the separate bounded backfill gateway.

BEGIN;

CREATE OR REPLACE FUNCTION reputation.enqueue_stock_order_delivery_work()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_sqlstate text;
BEGIN
    BEGIN
        PERFORM reputation.enqueue_stock_order_engagement_work(NEW.id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
        RAISE WARNING
            'Reputation enqueue failed for order %: sqlstate %',
            NEW.id, v_sqlstate;
        RAISE EXCEPTION 'Delivery processing is temporarily unavailable'
            USING ERRCODE = 'P2C05';
    END;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.enqueue_stock_order_delivery_work()
    OWNER TO postgres;

COMMENT ON FUNCTION reputation.enqueue_stock_order_delivery_work() IS
    'Enqueues idempotent Reputation work when a commerce order becomes an eligible delivered stock order.';

CREATE TRIGGER reputation_stock_order_delivery_work_insert
    AFTER INSERT ON commerce.orders
    FOR EACH ROW
    WHEN (
        NEW.status = 'delivered'
        AND NEW.order_kind = 'stock'
        AND NEW.delivered_at IS NOT NULL
    )
    EXECUTE FUNCTION reputation.enqueue_stock_order_delivery_work();

CREATE TRIGGER reputation_stock_order_delivery_work_update
    AFTER UPDATE OF status, order_kind, delivered_at ON commerce.orders
    FOR EACH ROW
    WHEN (
        NEW.status = 'delivered'
        AND NEW.order_kind = 'stock'
        AND NEW.delivered_at IS NOT NULL
        AND NOT (
            OLD.status = 'delivered'
            AND OLD.order_kind = 'stock'
            AND OLD.delivered_at IS NOT NULL
        )
    )
    EXECUTE FUNCTION reputation.enqueue_stock_order_delivery_work();

REVOKE ALL ON FUNCTION reputation.enqueue_stock_order_delivery_work()
    FROM PUBLIC, anon, authenticated, service_role;

COMMIT;

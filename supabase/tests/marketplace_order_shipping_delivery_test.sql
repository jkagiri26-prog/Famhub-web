-- ============================================================================
-- marketplace_order_shipping_delivery_test.sql
-- LOCAL-ONLY structural/ACL test for confirmed -> shipped -> delivered.
-- Requires 20261118000004_marketplace_order_shipping_delivery.sql.
-- ============================================================================
BEGIN;

DO $objects$
DECLARE
    v_ship oid := to_regprocedure('commerce.ship_listing_order(uuid,text)');
    v_deliver oid := to_regprocedure(
        'commerce.confirm_listing_order_delivery(uuid,text)'
    );
BEGIN
    IF v_ship IS NULL OR v_deliver IS NULL THEN
        RAISE EXCEPTION 'shipping/delivery RPC is missing';
    END IF;

    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_ship)
       OR NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_deliver) THEN
        RAISE EXCEPTION 'shipping/delivery RPCs must be SECURITY DEFINER';
    END IF;

    IF NOT has_function_privilege('authenticated', v_ship, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_deliver, 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot execute shipping/delivery RPCs';
    END IF;

    IF has_function_privilege('anon', v_ship, 'EXECUTE')
       OR has_function_privilege('anon', v_deliver, 'EXECUTE') THEN
        RAISE EXCEPTION 'anon can execute shipping/delivery RPCs';
    END IF;

    IF has_table_privilege('authenticated', 'commerce.orders', 'UPDATE')
       OR has_table_privilege('authenticated', 'commerce.orders', 'DELETE') THEN
        RAISE EXCEPTION 'authenticated can bypass lifecycle via direct order writes';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'shipped_at'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'delivered_at'
    ) THEN
        RAISE EXCEPTION 'shipping/delivery audit columns are missing';
    END IF;
END;
$objects$;

ROLLBACK;

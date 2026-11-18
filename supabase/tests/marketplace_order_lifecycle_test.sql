-- ============================================================================
-- marketplace_order_lifecycle_test.sql
-- LOCAL-ONLY structural/ACL test for seller/buyer order lifecycle.
-- Requires 20261118000002_marketplace_order_lifecycle.sql.
-- ============================================================================
BEGIN;

DO $objects$
DECLARE
    v_accept oid := to_regprocedure('commerce.accept_listing_order(uuid)');
    v_reject oid := to_regprocedure('commerce.reject_listing_order(uuid,text)');
    v_cancel oid := to_regprocedure('commerce.cancel_listing_order(uuid,text)');
    v_release oid := to_regprocedure(
        'commerce.release_order_stock_reservation(uuid)'
    );
BEGIN
    IF v_accept IS NULL OR v_reject IS NULL OR v_cancel IS NULL THEN
        RAISE EXCEPTION 'order lifecycle RPC is missing';
    END IF;

    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_accept)
       OR NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_reject)
       OR NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_cancel) THEN
        RAISE EXCEPTION 'order lifecycle RPCs must be SECURITY DEFINER';
    END IF;

    IF NOT has_function_privilege('authenticated', v_accept, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_reject, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_cancel, 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot execute lifecycle RPCs';
    END IF;

    IF has_function_privilege('anon', v_accept, 'EXECUTE')
       OR has_function_privilege('anon', v_reject, 'EXECUTE')
       OR has_function_privilege('anon', v_cancel, 'EXECUTE') THEN
        RAISE EXCEPTION 'anon can execute lifecycle RPCs';
    END IF;

    IF v_release IS NULL THEN
        RAISE EXCEPTION 'internal reservation release helper is missing';
    END IF;

    IF has_function_privilege('authenticated', v_release, 'EXECUTE')
       OR has_function_privilege('anon', v_release, 'EXECUTE')
       OR has_function_privilege('service_role', v_release, 'EXECUTE') THEN
        RAISE EXCEPTION 'internal reservation release helper is exposed';
    END IF;

    IF has_table_privilege('authenticated', 'commerce.stock_reservations', 'SELECT')
       OR has_table_privilege('authenticated', 'commerce.stock_reservations', 'INSERT')
       OR has_table_privilege('authenticated', 'commerce.stock_reservations', 'UPDATE')
       OR has_table_privilege('authenticated', 'commerce.stock_reservations', 'DELETE') THEN
        RAISE EXCEPTION 'authenticated can access stock reservations directly';
    END IF;

    IF has_table_privilege('authenticated', 'commerce.orders', 'UPDATE')
       OR has_table_privilege('authenticated', 'commerce.orders', 'DELETE') THEN
        RAISE EXCEPTION 'authenticated can bypass lifecycle via direct order writes';
    END IF;
END;
$objects$;

DO $statuses$
DECLARE
    v_definition text;
BEGIN
    SELECT pg_get_constraintdef(c.oid)
      INTO v_definition
    FROM pg_constraint AS c
    JOIN pg_class AS t ON t.oid = c.conrelid
    JOIN pg_namespace AS n ON n.oid = t.relnamespace
    WHERE n.nspname = 'commerce'
      AND t.relname = 'orders'
      AND c.conname = 'orders_status_check';

    IF v_definition IS NULL
       OR position('accepted' in v_definition) = 0
       OR position('rejected' in v_definition) = 0
       OR position('cancelled' in v_definition) = 0 THEN
        RAISE EXCEPTION 'orders_status_check does not contain lifecycle states';
    END IF;
END;
$statuses$;

ROLLBACK;

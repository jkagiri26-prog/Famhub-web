-- ============================================================================
-- marketplace_order_foundation_test.sql
-- LOCAL-ONLY structural/ACL test for the Marketplace order foundation.
-- Requires 20261118000001_marketplace_order_foundation.sql.
-- ============================================================================
BEGIN;

DO $objects$
DECLARE
    v_function oid := to_regprocedure(
        'commerce.create_listing_order(uuid,numeric,text)'
    );
    v_index oid := to_regclass(
        'commerce.orders_buyer_idempotency_key_uidx'
    );
BEGIN
    IF v_function IS NULL THEN
        RAISE EXCEPTION 'create_listing_order function is missing';
    END IF;

    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_function) THEN
        RAISE EXCEPTION 'create_listing_order must be SECURITY DEFINER';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE oid = v_function
          AND proconfig @> ARRAY[
            'search_path=pg_catalog, commerce, core, marketplace, users'
          ]
    ) THEN
        RAISE EXCEPTION 'create_listing_order search_path is not pinned';
    END IF;

    IF NOT has_function_privilege('authenticated', v_function, 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot create listing orders';
    END IF;
    IF has_function_privilege('anon', v_function, 'EXECUTE') THEN
        RAISE EXCEPTION 'anon can create listing orders';
    END IF;

    IF v_index IS NULL THEN
        RAISE EXCEPTION 'buyer idempotency unique index is missing';
    END IF;

    IF has_table_privilege('authenticated', 'commerce.orders', 'INSERT') THEN
        RAISE EXCEPTION 'authenticated still has direct order INSERT';
    END IF;
    IF has_table_privilege('authenticated', 'commerce.order_items', 'INSERT')
       OR has_table_privilege('authenticated', 'commerce.order_items', 'UPDATE')
       OR has_table_privilege('authenticated', 'commerce.order_items', 'DELETE') THEN
        RAISE EXCEPTION 'authenticated still has direct order-item writes';
    END IF;

    IF has_function_privilege(
            'authenticated',
            'commerce.create_order(uuid,numeric)',
            'EXECUTE'
        )
       OR has_function_privilege(
            'authenticated',
            'commerce.create_order_with_reservation(uuid,numeric)',
            'EXECUTE'
        ) THEN
        RAISE EXCEPTION 'legacy unsafe order RPC remains client-executable';
    END IF;
END;
$objects$;

DO $columns$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'buyer_entity_id'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'seller_entity_id'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'currency'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'idempotency_key'
    ) THEN
        RAISE EXCEPTION 'canonical order identity columns are incomplete';
    END IF;
END;
$columns$;

ROLLBACK;

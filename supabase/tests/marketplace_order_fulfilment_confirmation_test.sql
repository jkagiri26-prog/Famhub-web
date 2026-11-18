-- ============================================================================
-- marketplace_order_fulfilment_confirmation_test.sql
-- LOCAL-ONLY structural/ACL test for accepted -> confirmed fulfilment.
-- Requires 20261118000003_marketplace_order_fulfilment_confirmation.sql.
-- ============================================================================
BEGIN;

DO $objects$
DECLARE
    v_confirm oid := to_regprocedure(
        'commerce.confirm_order_fulfilment(uuid)'
    );
BEGIN
    IF v_confirm IS NULL THEN
        RAISE EXCEPTION 'confirm_order_fulfilment function is missing';
    END IF;

    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_confirm) THEN
        RAISE EXCEPTION 'confirm_order_fulfilment must be SECURITY DEFINER';
    END IF;

    IF NOT has_function_privilege('authenticated', v_confirm, 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot confirm fulfilment';
    END IF;

    IF has_function_privilege('anon', v_confirm, 'EXECUTE') THEN
        RAISE EXCEPTION 'anon can confirm fulfilment';
    END IF;

    IF has_table_privilege('authenticated', 'commerce.orders', 'UPDATE') THEN
        RAISE EXCEPTION 'authenticated can bypass confirmation via direct order UPDATE';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'confirmed_at'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'commerce'
          AND table_name = 'orders'
          AND column_name = 'stock_consumed_at'
    ) THEN
        RAISE EXCEPTION 'confirmation audit columns are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_process_order_stock'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'canonical process_order_stock trigger is missing';
    END IF;
END;
$objects$;

ROLLBACK;

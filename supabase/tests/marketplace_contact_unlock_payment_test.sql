-- ============================================================================
-- marketplace_contact_unlock_payment_test.sql
-- LOCAL-ONLY structural/ACL test for the contact-unlock payment lifecycle.
-- Requires 20261115000003_marketplace_contact_unlock_payment.sql.
-- ============================================================================
BEGIN;

DO $functions$
DECLARE
    v_request oid := to_regprocedure(
        'marketplace.request_contact_unlock_payment(uuid,text,text)'
    );
    v_status oid := to_regprocedure(
        'marketplace.contact_unlock_status(uuid)'
    );
    v_confirm oid := to_regprocedure(
        'marketplace.confirm_contact_unlock_payment(uuid,uuid)'
    );
BEGIN
    IF v_request IS NULL OR v_status IS NULL OR v_confirm IS NULL THEN
        RAISE EXCEPTION 'contact-unlock payment functions are missing';
    END IF;

    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_request)
       OR NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_status)
       OR NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_confirm) THEN
        RAISE EXCEPTION 'contact-unlock payment functions must be SECURITY DEFINER';
    END IF;

    IF NOT has_function_privilege('authenticated', v_request, 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot request contact-unlock payment';
    END IF;
    IF has_function_privilege('anon', v_request, 'EXECUTE') THEN
        RAISE EXCEPTION 'anon can request contact-unlock payment';
    END IF;
    IF has_function_privilege('service_role', v_request, 'EXECUTE') THEN
        RAISE EXCEPTION 'service_role can request contact-unlock payment';
    END IF;

    IF NOT has_function_privilege('authenticated', v_status, 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot read contact-unlock status';
    END IF;
    IF has_function_privilege('anon', v_status, 'EXECUTE') THEN
        RAISE EXCEPTION 'anon can read contact-unlock status';
    END IF;

    IF NOT has_function_privilege('service_role', v_confirm, 'EXECUTE') THEN
        RAISE EXCEPTION 'service_role cannot confirm contact-unlock payment';
    END IF;
    IF has_function_privilege('authenticated', v_confirm, 'EXECUTE')
       OR has_function_privilege('anon', v_confirm, 'EXECUTE') THEN
        RAISE EXCEPTION 'client role can confirm contact-unlock payment';
    END IF;
END;
$functions$;

ROLLBACK;

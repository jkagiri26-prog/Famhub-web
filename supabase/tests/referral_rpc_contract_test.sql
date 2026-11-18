-- ============================================================================
-- referral_rpc_contract_test.sql
-- ----------------------------------------------------------------------------
-- Local-only structural checks for the Refer & Earn RPC surface.
--
-- Run after applying migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

DO $test$
DECLARE
    v_fn oid;
    v_args text;
    v_result text;
    v_secdef boolean;
    v_config text[];
    v_has_authenticated boolean;
    v_has_service_role boolean;
    v_has_anon boolean;
    v_has_public boolean;
BEGIN
    -- system.ensure_individual_billing_account()
    v_fn := to_regprocedure('system.ensure_individual_billing_account()');
    IF v_fn IS NULL THEN
        RAISE EXCEPTION 'system.ensure_individual_billing_account() is missing';
    END IF;
    SELECT pg_get_function_identity_arguments(v_fn), pg_get_function_result(v_fn),
           p.prosecdef, p.proconfig
      INTO v_args, v_result, v_secdef, v_config
      FROM pg_proc p
     WHERE p.oid = v_fn;

    IF v_args <> '' THEN
        RAISE EXCEPTION 'ensure_individual_billing_account must accept no arguments, found %', v_args;
    END IF;
    IF v_secdef IS NOT TRUE THEN
        RAISE EXCEPTION 'ensure_individual_billing_account must be SECURITY DEFINER';
    END IF;
    IF v_config IS NULL OR NOT EXISTS (
        SELECT 1 FROM unnest(v_config) AS cfg WHERE cfg LIKE 'search_path=%'
    ) THEN
        RAISE EXCEPTION 'ensure_individual_billing_account must pin search_path';
    END IF;
    IF v_result NOT LIKE '%billing_account_id%'
       OR v_result NOT LIKE '%entity_id%'
       OR v_result NOT LIKE '%profile_id%'
       OR v_result NOT LIKE '%account_type%'
       OR v_result NOT LIKE '%currency%'
       OR v_result NOT LIKE '%status%' THEN
        RAISE EXCEPTION 'unexpected billing account return shape: %', v_result;
    END IF;

    SELECT
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'authenticated'),
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'service_role'),
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'anon'),
      bool_or(a.grantee = 0)
      INTO v_has_authenticated, v_has_service_role, v_has_anon, v_has_public
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS a
     WHERE p.oid = v_fn;

    IF v_has_authenticated IS NOT TRUE
       OR COALESCE(v_has_service_role, false)
       OR COALESCE(v_has_anon, false)
       OR COALESCE(v_has_public, false) THEN
        RAISE EXCEPTION 'ensure_individual_billing_account grants are not authenticated-only';
    END IF;

    -- system.allocate_invoice_number()
    v_fn := to_regprocedure('system.allocate_invoice_number()');
    IF v_fn IS NULL THEN
        RAISE EXCEPTION 'system.allocate_invoice_number() is missing';
    END IF;
    SELECT pg_get_function_identity_arguments(v_fn), pg_get_function_result(v_fn),
           p.prosecdef, p.proconfig
      INTO v_args, v_result, v_secdef, v_config
      FROM pg_proc p
     WHERE p.oid = v_fn;

    IF v_args <> '' THEN
        RAISE EXCEPTION 'allocate_invoice_number must accept no arguments, found %', v_args;
    END IF;
    IF v_result <> 'text' THEN
        RAISE EXCEPTION 'allocate_invoice_number must return text, found %', v_result;
    END IF;
    IF v_secdef IS NOT TRUE THEN
        RAISE EXCEPTION 'allocate_invoice_number must be SECURITY DEFINER';
    END IF;

    SELECT
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'authenticated'),
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'service_role'),
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'anon'),
      bool_or(a.grantee = 0)
      INTO v_has_authenticated, v_has_service_role, v_has_anon, v_has_public
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS a
     WHERE p.oid = v_fn;

    IF v_has_service_role IS NOT TRUE
       OR COALESCE(v_has_authenticated, false)
       OR COALESCE(v_has_anon, false)
       OR COALESCE(v_has_public, false) THEN
        RAISE EXCEPTION 'allocate_invoice_number grants are not service_role-only';
    END IF;

    -- finance.create_annual_subscription(...)
    v_fn := to_regprocedure(
      'finance.create_annual_subscription(uuid,uuid,text,text,date,timestamp with time zone)'
    );
    IF v_fn IS NULL THEN
        RAISE EXCEPTION 'finance.create_annual_subscription(...) signature is missing';
    END IF;
    SELECT pg_get_function_identity_arguments(v_fn), pg_get_function_result(v_fn),
           p.prosecdef, p.proconfig
      INTO v_args, v_result, v_secdef, v_config
      FROM pg_proc p
     WHERE p.oid = v_fn;

    IF v_args <> 'p_billing_account_id uuid, p_plan_id uuid, p_invoice_number text, p_idempotency_key text, p_requested_start_date date, p_due_at timestamp with time zone' THEN
        RAISE EXCEPTION 'unexpected create_annual_subscription args: %', v_args;
    END IF;
    IF v_secdef IS NOT TRUE THEN
        RAISE EXCEPTION 'create_annual_subscription must be SECURITY DEFINER';
    END IF;
    IF v_result NOT LIKE '%subscription_cycle_id%'
       OR v_result NOT LIKE '%active_subscription_id%'
       OR v_result NOT LIKE '%invoice_id%'
       OR v_result NOT LIKE '%obligation_id%'
       OR v_result NOT LIKE '%annual_sequence%'
       OR v_result NOT LIKE '%cycle_type%' THEN
        RAISE EXCEPTION 'unexpected create_annual_subscription return shape: %', v_result;
    END IF;

    SELECT
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'authenticated'),
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'service_role'),
      bool_or(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END = 'anon'),
      bool_or(a.grantee = 0)
      INTO v_has_authenticated, v_has_service_role, v_has_anon, v_has_public
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS a
     WHERE p.oid = v_fn;

    IF v_has_service_role IS NOT TRUE
       OR COALESCE(v_has_authenticated, false)
       OR COALESCE(v_has_anon, false)
       OR COALESCE(v_has_public, false) THEN
        RAISE EXCEPTION 'create_annual_subscription grants are not service_role-only';
    END IF;
END;
$test$;

ROLLBACK;

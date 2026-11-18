-- ============================================================================
-- 20261112000008_annual_subscription_plans
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Controlled creation of annual personal subscription plan rows.
--
-- LIVE FACTS THIS MIGRATION RESPECTS
--   * No live subscription plans exist yet.
--   * Plan amounts are supplied by the operator; they are not invented.
--   * Only annual (yearly), KES plans are created by this function.
--
-- SCOPE
--   Function only. No plan row is inserted by the migration itself. No billing
--   account, invoice, subscription, obligation or accounting period is touched.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS system.create_annual_subscription_plan(text, text, numeric, text, jsonb);
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION "system"."create_annual_subscription_plan"(
    "p_plan_key" text,
    "p_plan_name" text,
    "p_amount" numeric,
    "p_module_key" text DEFAULT NULL,
    "p_features_json" jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
    "plan_id" uuid,
    "plan_key" text,
    "plan_name" text,
    "amount" numeric,
    "currency" text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, system
AS $function$
DECLARE
    v_plan_key text := nullif(btrim(p_plan_key), '');
    v_plan_name text := nullif(btrim(p_plan_name), '');
    v_module_key text := nullif(btrim(p_module_key), '');
    v_existing system.subscription_plans%ROWTYPE;
    v_plan_id uuid;
BEGIN
    IF v_plan_key IS NULL OR v_plan_name IS NULL THEN
        RAISE EXCEPTION 'Plan key and plan name are required'
            USING ERRCODE = '22023';
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Plan amount must be positive'
            USING ERRCODE = '22023';
    END IF;
    IF p_features_json IS NULL OR jsonb_typeof(p_features_json) <> 'object' THEN
        RAISE EXCEPTION 'Plan features must be a JSON object'
            USING ERRCODE = '22023';
    END IF;

    SELECT p.* INTO v_existing
      FROM system.subscription_plans AS p
     WHERE p.plan_key = v_plan_key
     FOR UPDATE;

    IF FOUND THEN
        IF v_existing.plan_name IS DISTINCT FROM v_plan_name
           OR v_existing.module_key IS DISTINCT FROM v_module_key
           OR v_existing.billing_cycle <> 'yearly'
           OR v_existing.amount IS DISTINCT FROM p_amount
           OR v_existing.currency <> 'KES'
           OR v_existing.is_active IS NOT TRUE
           OR v_existing.features_json IS DISTINCT FROM p_features_json THEN
            RAISE EXCEPTION 'Annual plan key % already exists with different data', v_plan_key
                USING ERRCODE = '23505';
        END IF;

        RETURN QUERY
        SELECT v_existing.id, v_existing.plan_key, v_existing.plan_name,
               v_existing.amount, v_existing.currency;
        RETURN;
    END IF;

    INSERT INTO system.subscription_plans (
        plan_key, plan_name, module_key, billing_cycle,
        amount, currency, is_active, features_json
    ) VALUES (
        v_plan_key, v_plan_name, v_module_key, 'yearly',
        p_amount, 'KES', true, p_features_json
    ) RETURNING id INTO v_plan_id;

    RETURN QUERY
    SELECT v_plan_id, v_plan_key, v_plan_name, p_amount, 'KES'::text;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."create_annual_subscription_plan"(text, text, numeric, text, jsonb)
    FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "system"."create_annual_subscription_plan"(text, text, numeric, text, jsonb)
    TO "service_role";

COMMENT ON FUNCTION "system"."create_annual_subscription_plan"(text, text, numeric, text, jsonb)
    IS 'Controlled annual KES plan creation. Amounts and keys are supplied by an authorized operator.';

COMMIT;

-- ============================================================================
-- 20261116000002_annual_subscription_purchase_foundation
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Provide the smallest customer-safe contract required by the existing
--   subscription-billing Edge Function:
--     * authenticated annual plan catalog;
--     * authenticated create/reuse of one pending annual subscription cycle.
--
-- REUSED CANONICAL OBJECTS
--   system.subscription_plans
--   system.billing_accounts / system.ensure_individual_billing_account()
--   system.allocate_invoice_number()
--   finance.create_annual_subscription(...)
--   finance.subscription_cycles
--   system.active_subscriptions
--   system.invoices
--   finance.obligations
--
-- SECURITY
--   * No amount, currency, profile, entity, invoice, or obligation is accepted
--     from the client.
--   * Price and currency are derived from the canonical plan row.
--   * The existing service-role-only cycle function is called by a narrow
--     SECURITY DEFINER wrapper; its privileges are not weakened.
--   * No client receives service-role credentials, obligation ids, invoice ids,
--     ledger data, or another user's cycle.
--   * Creating a cycle does not activate entitlement.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS system.create_or_reuse_annual_subscription_purchase(uuid);
--   DROP FUNCTION IF EXISTS system.list_annual_subscription_plans();
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Authenticated annual plan catalog. Only customer-facing fields are exposed.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "system"."list_annual_subscription_plans"()
RETURNS TABLE (
    "plan_id" uuid,
    "plan_key" text,
    "plan_name" text,
    "amount" numeric,
    "currency" text,
    "billing_cycle" text,
    "is_active" boolean,
    "features_json" jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, system, auth
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT p.id, p.plan_key, p.plan_name, p.amount, p.currency,
           p.billing_cycle, p.is_active, p.features_json
      FROM system.subscription_plans AS p
     WHERE p.is_active IS TRUE
       AND p.billing_cycle = 'yearly'
       AND p.currency = 'KES'
       AND p.amount > 0
     ORDER BY p.amount, p.plan_name, p.id;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."list_annual_subscription_plans"()
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."list_annual_subscription_plans"()
    TO "authenticated";

COMMENT ON FUNCTION "system"."list_annual_subscription_plans"()
    IS 'Authenticated customer-facing catalog of active annual KES subscription plans.';

-- ----------------------------------------------------------------------------
-- Authenticated create/reuse of one pending annual subscription cycle.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "system"."create_or_reuse_annual_subscription_purchase"(
    "p_plan_id" uuid
)
RETURNS TABLE (
    "subscription_cycle_id" uuid,
    "plan_id" uuid,
    "plan_key" text,
    "plan_name" text,
    "amount" numeric,
    "currency" text,
    "period_start" date,
    "period_end" date,
    "status" text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, system, finance, core, auth, users
AS $function$
DECLARE
    v_billing record;
    v_plan system.subscription_plans%ROWTYPE;
    v_pending finance.subscription_cycles%ROWTYPE;
    v_active finance.subscription_cycles%ROWTYPE;
    v_created record;
    v_next_sequence integer;
    v_idempotency_key text;
    v_invoice_number text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;
    IF p_plan_id IS NULL THEN
        RAISE EXCEPTION 'Annual subscription plan is required'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_plan
      FROM system.subscription_plans
     WHERE id = p_plan_id
       AND is_active IS TRUE
       AND billing_cycle = 'yearly'
       AND currency = 'KES'
       AND amount > 0
     FOR SHARE;

    SELECT * INTO v_billing
      FROM system.ensure_individual_billing_account();

    -- Same serialization key used by finance.create_annual_subscription.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            'subscription-cycle:' || v_billing.profile_id::text,
            0
        )
    );

    SELECT * INTO v_pending
      FROM finance.subscription_cycles AS c
     WHERE c.billing_account_id = v_billing.billing_account_id
       AND c.status = 'pending'
     ORDER BY c.created_at DESC, c.id DESC
     LIMIT 1
     FOR UPDATE;

    IF FOUND THEN
        IF v_pending.plan_id IS DISTINCT FROM p_plan_id THEN
            RAISE EXCEPTION 'A different annual subscription plan is already pending'
                USING ERRCODE = '23505';
        END IF;

        RETURN QUERY
        SELECT v_pending.id, v_plan.id, v_plan.plan_key, v_plan.plan_name,
               v_pending.amount, v_pending.currency,
               v_pending.period_start, v_pending.period_end, v_pending.status;
        RETURN;
    END IF;

    -- Never turn an existing active/future purchase into a second cycle.
    SELECT * INTO v_active
      FROM finance.subscription_cycles AS c
      JOIN system.active_subscriptions AS a
        ON a.id = c.active_subscription_id
     WHERE c.billing_account_id = v_billing.billing_account_id
       AND c.status = 'active'
       AND a.status = 'active'
       AND (a.end_date IS NULL OR a.end_date > now())
     ORDER BY c.created_at DESC, c.id DESC
     LIMIT 1
     FOR UPDATE OF c;

    IF FOUND THEN
        IF v_active.plan_id IS DISTINCT FROM p_plan_id THEN
            RAISE EXCEPTION 'An active annual subscription for a different plan already exists'
                USING ERRCODE = '23505';
        END IF;

        RETURN QUERY
        SELECT v_active.id, v_plan.id, v_plan.plan_key, v_plan.plan_name,
               v_active.amount, v_active.currency,
               v_active.period_start, v_active.period_end, v_active.status;
        RETURN;
    END IF;

    SELECT COALESCE(max(c.annual_sequence), 0) + 1
      INTO v_next_sequence
      FROM finance.subscription_cycles AS c
     WHERE c.subscriber_profile_id = v_billing.profile_id;

    v_idempotency_key := 'annual-purchase:' ||
        v_billing.billing_account_id::text || ':' ||
        p_plan_id::text || ':' || v_next_sequence::text;
    v_invoice_number := system.allocate_invoice_number();

    SELECT * INTO STRICT v_created
      FROM finance.create_annual_subscription(
          v_billing.billing_account_id,
          p_plan_id,
          v_invoice_number,
          v_idempotency_key,
          NULL,
          NULL
      );

    RETURN QUERY
    SELECT v_created.subscription_cycle_id, v_plan.id, v_plan.plan_key,
           v_plan.plan_name, v_created.amount, v_created.currency,
           v_created.period_start, v_created.period_end, v_created.status;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."create_or_reuse_annual_subscription_purchase"(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."create_or_reuse_annual_subscription_purchase"(uuid)
    TO "authenticated";

COMMENT ON FUNCTION "system"."create_or_reuse_annual_subscription_purchase"(uuid)
    IS 'Authenticated self-scoped create/reuse of a pending annual subscription cycle. Price comes from the canonical plan; the existing service-role cycle function remains unchanged.';

COMMIT;

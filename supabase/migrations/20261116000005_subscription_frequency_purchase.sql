-- ============================================================================
-- 20261116000005_subscription_frequency_purchase
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Generalize the customer purchase-cycle foundation to the canonical plan
--   billing frequencies: monthly, quarterly and yearly.
--
-- CANONICAL SOURCE OF FREQUENCY
--   system.subscription_plans.billing_cycle
--
-- FINANCE CYCLE TYPES
--   monthly   -> initial_monthly / renewal_monthly
--   quarterly -> initial_quarterly / renewal_quarterly
--   yearly    -> initial_annual / renewal_annual (existing values)
--
-- PERIODS
--   monthly   -> one calendar month
--   quarterly -> three calendar months
--   yearly    -> one calendar year
--   Business dates are computed in Africa/Nairobi; active boundaries are
--   stored as UTC timestamps, start inclusive and end exclusive.
--
-- SCOPE
--   No new subscription/payment/entitlement/ledger table. Invoice, Finance
--   obligation, cycle and access rows continue through the existing schema.
--   No multi-year support, no Daraja and no activation.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Extend the canonical cycle-type checks. Existing annual values remain valid.
-- ----------------------------------------------------------------------------
ALTER TABLE finance.subscription_cycles
    DROP CONSTRAINT IF EXISTS subscription_cycles_cycle_type_check;
ALTER TABLE finance.subscription_cycles
    ADD CONSTRAINT subscription_cycles_cycle_type_check
    CHECK (cycle_type = ANY (ARRAY[
        'initial_annual', 'renewal_annual',
        'initial_monthly', 'renewal_monthly',
        'initial_quarterly', 'renewal_quarterly'
    ]::text[]));

ALTER TABLE finance.subscription_cycles
    DROP CONSTRAINT IF EXISTS subscription_cycles_initial_sequence_check;
ALTER TABLE finance.subscription_cycles
    ADD CONSTRAINT subscription_cycles_initial_sequence_check
    CHECK (
        (cycle_type LIKE 'initial_%' AND annual_sequence = 1)
        OR (cycle_type LIKE 'renewal_%' AND annual_sequence > 1)
    );

ALTER TABLE finance.subscription_cycles
    DROP CONSTRAINT IF EXISTS subscription_cycles_renewal_lineage_check;
ALTER TABLE finance.subscription_cycles
    ADD CONSTRAINT subscription_cycles_renewal_lineage_check
    CHECK (
        (cycle_type LIKE 'initial_%' AND previous_cycle_id IS NULL)
        OR (cycle_type LIKE 'renewal_%' AND previous_cycle_id IS NOT NULL)
    );

-- ----------------------------------------------------------------------------
-- Frequency-aware canonical cycle creation. Service-role only.
-- Existing finance.create_annual_subscription(...) remains unchanged.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "finance"."create_subscription_cycle"(
    "p_billing_account_id" uuid,
    "p_plan_id" uuid,
    "p_invoice_number" text,
    "p_idempotency_key" text,
    "p_requested_start_date" date DEFAULT NULL,
    "p_due_at" timestamp with time zone DEFAULT NULL
)
RETURNS TABLE (
    "subscription_cycle_id" uuid,
    "active_subscription_id" uuid,
    "invoice_id" uuid,
    "obligation_id" uuid,
    "annual_sequence" integer,
    "cycle_type" text,
    "period_start" date,
    "period_end" date,
    "amount" numeric,
    "currency" text,
    "status" text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, finance, system, core, users
AS $function$
DECLARE
    v_existing finance.subscription_cycles%ROWTYPE;
    v_existing_invoice_number text;
    v_account system.billing_accounts%ROWTYPE;
    v_plan system.subscription_plans%ROWTYPE;
    v_entity core.entities%ROWTYPE;
    v_prev finance.subscription_cycles%ROWTYPE;
    v_platform_entity_id uuid;
    v_subscriber_profile_id uuid;
    v_cycle_id uuid;
    v_active_subscription_id uuid;
    v_invoice_id uuid;
    v_obligation_id uuid;
    v_annual_sequence integer;
    v_cycle_type text;
    v_frequency text;
    v_cycle_label text;
    v_period_start date;
    v_period_end date;
    v_amount numeric(20,4);
    v_currency text := 'KES';
    v_invoice_number text := nullif(btrim(p_invoice_number), '');
    v_idempotency_key text := nullif(btrim(p_idempotency_key), '');
    v_today date := (now() AT TIME ZONE 'Africa/Nairobi')::date;
    v_metadata jsonb;
BEGIN
    IF v_invoice_number IS NULL OR v_idempotency_key IS NULL THEN
        RAISE EXCEPTION 'Invoice number and idempotency key are required'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_existing
      FROM finance.subscription_cycles
     WHERE idempotency_key = v_idempotency_key;

    IF FOUND THEN
        SELECT i.invoice_number INTO v_existing_invoice_number
          FROM system.invoices i
         WHERE i.id = v_existing.invoice_id;

        IF v_existing.billing_account_id IS DISTINCT FROM p_billing_account_id
           OR v_existing.plan_id IS DISTINCT FROM p_plan_id
           OR v_existing_invoice_number IS DISTINCT FROM v_invoice_number THEN
            RAISE EXCEPTION 'Idempotency key was already used with different purchase data'
                USING ERRCODE = '23505';
        END IF;

        RETURN QUERY
        SELECT v_existing.id, v_existing.active_subscription_id, v_existing.invoice_id,
               v_existing.obligation_id, v_existing.annual_sequence, v_existing.cycle_type,
               v_existing.period_start, v_existing.period_end, v_existing.amount,
               v_existing.currency, v_existing.status;
        RETURN;
    END IF;

    SELECT * INTO STRICT v_account
      FROM system.billing_accounts
     WHERE id = p_billing_account_id;

    IF v_account.status <> 'active'
       OR v_account.account_type <> 'individual'
       OR v_account.currency <> 'KES'
       OR v_account.profile_id IS NULL
       OR v_account.entity_id IS NULL THEN
        RAISE EXCEPTION 'Only active KES personal/individual billing accounts can buy subscriptions'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_entity
      FROM core.entities
     WHERE id = v_account.entity_id
       AND is_active IS TRUE;

    IF v_entity.entity_type <> 'individual_pro'
       OR v_entity.owner_id <> v_account.profile_id THEN
        RAISE EXCEPTION 'Billing account entity is not the owner individual_pro entity'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_plan
      FROM system.subscription_plans
     WHERE id = p_plan_id
       AND is_active IS TRUE;

    IF v_plan.billing_cycle NOT IN ('monthly', 'quarterly', 'yearly')
       OR v_plan.currency <> 'KES'
       OR v_plan.amount <= 0 THEN
        RAISE EXCEPTION 'Plan must be an active positive-amount monthly, quarterly or yearly KES plan'
            USING ERRCODE = '22023';
    END IF;

    v_frequency := v_plan.billing_cycle;
    v_cycle_label := CASE v_frequency
        WHEN 'yearly' THEN 'annual'
        ELSE v_frequency
    END;

    SELECT id INTO STRICT v_platform_entity_id
      FROM core.entities
     WHERE is_active IS TRUE
       AND metadata->>'platform_entity' = 'true'
       AND metadata->>'purpose' = 'platform_administration';

    v_subscriber_profile_id := v_account.profile_id;
    v_amount := v_plan.amount;

    PERFORM pg_advisory_xact_lock(
        hashtextextended('subscription-cycle:' || v_subscriber_profile_id::text, 0)
    );

    SELECT c.* INTO v_prev
      FROM finance.subscription_cycles AS c
     WHERE c.subscriber_profile_id = v_subscriber_profile_id
     ORDER BY c.annual_sequence DESC, c.created_at DESC
     LIMIT 1
     FOR UPDATE;

    v_annual_sequence := COALESCE(v_prev.annual_sequence, 0) + 1;

    IF v_annual_sequence = 1 THEN
        v_cycle_type := 'initial_' || v_cycle_label;
        v_period_start := COALESCE(p_requested_start_date, v_today);
        IF v_period_start < v_today THEN
            RAISE EXCEPTION 'Initial subscription start cannot be in the past'
                USING ERRCODE = '22023';
        END IF;
    ELSE
        v_cycle_type := 'renewal_' || v_cycle_label;
        IF v_prev.id IS NULL THEN
            RAISE EXCEPTION 'Renewal requires a previous subscription cycle'
                USING ERRCODE = '55000';
        END IF;
        -- Early renewal starts the day after the previous period ends.
        -- Late renewal starts on the current Nairobi business date.
        v_period_start := CASE
            WHEN v_today <= v_prev.period_end THEN v_prev.period_end + 1
            ELSE v_today
        END;
    END IF;

    v_period_end := CASE v_frequency
        WHEN 'monthly' THEN
            (v_period_start + interval '1 month' - interval '1 day')::date
        WHEN 'quarterly' THEN
            (v_period_start + interval '3 months' - interval '1 day')::date
        WHEN 'yearly' THEN
            (v_period_start + interval '1 year' - interval '1 day')::date
    END;

    IF EXISTS (
        SELECT 1
          FROM finance.subscription_cycles AS c
         WHERE c.billing_account_id = p_billing_account_id
           AND c.plan_id = p_plan_id
           AND c.period_start = v_period_start
    ) THEN
        RAISE EXCEPTION 'A subscription cycle already exists for this account, plan and period start'
            USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
        SELECT 1 FROM system.invoices WHERE invoice_number = v_invoice_number
    ) THEN
        RAISE EXCEPTION 'Invoice number already exists: %', v_invoice_number
            USING ERRCODE = '23505';
    END IF;

    v_cycle_id := gen_random_uuid();

    INSERT INTO system.active_subscriptions (
        billing_account_id, plan_id, status, start_date, end_date, auto_renew
    ) VALUES (
        p_billing_account_id, p_plan_id, 'pending',
        v_period_start::timestamp AT TIME ZONE 'Africa/Nairobi',
        (v_period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi',
        false
    ) RETURNING id INTO v_active_subscription_id;

    INSERT INTO system.invoices (
        billing_account_id, invoice_number, module_name, reference_table,
        reference_id, status, total_amount, currency, due_date
    ) VALUES (
        p_billing_account_id, v_invoice_number, 'subscription',
        'finance.subscription_cycles', v_cycle_id, 'pending',
        v_amount, v_currency, p_due_at
    ) RETURNING id INTO v_invoice_id;

    INSERT INTO system.invoice_items (
        invoice_id, item_type, description, quantity, unit_price, total_amount
    ) VALUES (
        v_invoice_id, 'subscription', v_plan.plan_name, 1, v_amount, v_amount
    );

    v_metadata := jsonb_build_object(
        'finance_charge_code', 'subscription',
        'tax_treatment', 'not_applicable',
        'billing_cycle', v_frequency,
        'subscription_cycle_id', v_cycle_id,
        'plan_id', p_plan_id,
        'subscriber_profile_id', v_subscriber_profile_id
    );

    v_obligation_id := finance.create_obligation(
        v_account.entity_id,
        v_platform_entity_id,
        v_amount,
        v_currency,
        'subscription-obligation:' || v_cycle_id::text,
        'subscription',
        NULL,
        NULL,
        p_due_at,
        'Personal subscription cycle ' || v_cycle_id::text,
        v_metadata
    );

    INSERT INTO finance.subscription_cycles (
        id, billing_account_id, subscriber_profile_id, entity_id, plan_id,
        active_subscription_id, annual_sequence, cycle_type, previous_cycle_id,
        period_start, period_end, invoice_id, obligation_id,
        amount, currency, status, idempotency_key
    ) VALUES (
        v_cycle_id, p_billing_account_id, v_subscriber_profile_id, v_account.entity_id,
        p_plan_id, v_active_subscription_id, v_annual_sequence, v_cycle_type,
        v_prev.id, v_period_start, v_period_end, v_invoice_id, v_obligation_id,
        v_amount, v_currency, 'pending', v_idempotency_key
    );

    RETURN QUERY
    SELECT v_cycle_id, v_active_subscription_id, v_invoice_id, v_obligation_id,
           v_annual_sequence, v_cycle_type, v_period_start, v_period_end,
           v_amount, v_currency, 'pending'::text;
END;
$function$;

REVOKE ALL ON FUNCTION "finance"."create_subscription_cycle"(uuid, uuid, text, text, date, timestamp with time zone)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "finance"."create_subscription_cycle"(uuid, uuid, text, text, date, timestamp with time zone)
    TO "service_role";

COMMENT ON FUNCTION "finance"."create_subscription_cycle"(uuid, uuid, text, text, date, timestamp with time zone)
    IS 'Creates/reuses a pending monthly, quarterly or yearly personal subscription cycle using canonical plan frequency, invoices and Finance obligations. No entitlement activation.';

-- ----------------------------------------------------------------------------
-- Authenticated create/reuse wrapper for all three frequencies.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "system"."create_or_reuse_subscription_purchase"(
    "p_plan_id" uuid
)
RETURNS TABLE (
    "subscription_cycle_id" uuid,
    "plan_id" uuid,
    "plan_key" text,
    "plan_name" text,
    "billing_cycle" text,
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
        RAISE EXCEPTION 'Subscription plan is required'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_plan
      FROM system.subscription_plans
     WHERE id = p_plan_id
       AND is_active IS TRUE
       AND billing_cycle IN ('monthly', 'quarterly', 'yearly')
       AND currency = 'KES'
       AND amount > 0
     FOR SHARE;

    SELECT * INTO v_billing
      FROM system.ensure_individual_billing_account();

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
            RAISE EXCEPTION 'A different subscription plan is already pending'
                USING ERRCODE = '23505';
        END IF;

        RETURN QUERY
        SELECT v_pending.id, v_plan.id, v_plan.plan_key, v_plan.plan_name,
               v_plan.billing_cycle, v_pending.amount, v_pending.currency,
               v_pending.period_start, v_pending.period_end, v_pending.status;
        RETURN;
    END IF;

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
            RAISE EXCEPTION 'An active subscription for a different plan already exists'
                USING ERRCODE = '23505';
        END IF;

        RETURN QUERY
        SELECT v_active.id, v_plan.id, v_plan.plan_key, v_plan.plan_name,
               v_plan.billing_cycle, v_active.amount, v_active.currency,
               v_active.period_start, v_active.period_end, v_active.status;
        RETURN;
    END IF;

    SELECT COALESCE(max(c.annual_sequence), 0) + 1
      INTO v_next_sequence
      FROM finance.subscription_cycles AS c
     WHERE c.subscriber_profile_id = v_billing.profile_id;

    v_idempotency_key := 'subscription-purchase:' ||
        v_billing.billing_account_id::text || ':' ||
        p_plan_id::text || ':' || v_next_sequence::text;
    v_invoice_number := system.allocate_invoice_number();

    SELECT * INTO STRICT v_created
      FROM finance.create_subscription_cycle(
          v_billing.billing_account_id,
          p_plan_id,
          v_invoice_number,
          v_idempotency_key,
          NULL,
          NULL
      );

    RETURN QUERY
    SELECT v_created.subscription_cycle_id, v_plan.id, v_plan.plan_key,
           v_plan.plan_name, v_plan.billing_cycle, v_created.amount,
           v_created.currency, v_created.period_start, v_created.period_end,
           v_created.status;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."create_or_reuse_subscription_purchase"(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."create_or_reuse_subscription_purchase"(uuid)
    TO "authenticated";

COMMENT ON FUNCTION "system"."create_or_reuse_subscription_purchase"(uuid)
    IS 'Authenticated self-scoped create/reuse of a pending monthly, quarterly or yearly subscription cycle. Price, currency and frequency come from the canonical plan.';

-- ----------------------------------------------------------------------------
-- Frequency-aware customer plan catalog.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "system"."list_subscription_plans"()
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
       AND p.billing_cycle IN ('monthly', 'quarterly', 'yearly')
       AND p.currency = 'KES'
       AND p.amount > 0
     ORDER BY p.amount, p.plan_name, p.id;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."list_subscription_plans"()
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."list_subscription_plans"()
    TO "authenticated";

COMMENT ON FUNCTION "system"."list_subscription_plans"()
    IS 'Authenticated customer-facing catalog for active monthly, quarterly and yearly KES plans.';

COMMIT;

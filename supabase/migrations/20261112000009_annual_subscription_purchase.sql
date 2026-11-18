-- ============================================================================
-- 20261112000009_annual_subscription_purchase
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Create one annual personal subscription purchase in a single transaction:
--     * pending current-access row in system.active_subscriptions
--     * invoice and invoice item
--     * Finance subscription obligation
--     * permanent finance.subscription_cycles row
--
-- APPROVED RULES
--   * Personal / individual annual subscriptions only.
--   * Early renewal starts the day after the previous period ends.
--   * Late renewal starts on the current date; no retroactive access/grace.
--   * Initial cycle is annual_sequence = 1; later cycles are renewals.
--   * No reward for renewal is implemented here; this function only sells.
--
-- LIVE DEPENDENCIES NOT INVENTED HERE
--   * p_invoice_number MUST come from the approved invoice-numbering procedure.
--     This function validates uniqueness but does not invent a numbering scheme.
--   * finance.create_obligation must exist with the captured signature.
--   * The platform administration entity must exist with the captured metadata.
--
-- SCOPE
--   No journal is posted. No ledger account is created. No accounting period is
--   opened. No M-Pesa request is created. No subscription is activated here.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS finance.create_annual_subscription(uuid, uuid, text, text, date, timestamp with time zone);
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION "finance"."create_annual_subscription"(
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
    v_period_start date;
    v_period_end date;
    v_amount numeric(20,4);
    v_currency text := 'KES';
    v_invoice_number text := nullif(btrim(p_invoice_number), '');
    v_idempotency_key text := nullif(btrim(p_idempotency_key), '');
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
        RAISE EXCEPTION 'Only active KES personal/individual billing accounts can buy annual subscriptions'
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

    IF v_plan.billing_cycle <> 'yearly'
       OR v_plan.currency <> 'KES'
       OR v_plan.amount <= 0 THEN
        RAISE EXCEPTION 'Plan must be an active positive-amount yearly KES plan'
            USING ERRCODE = '22023';
    END IF;

    SELECT id INTO STRICT v_platform_entity_id
      FROM core.entities
     WHERE is_active IS TRUE
       AND metadata->>'platform_entity' = 'true'
       AND metadata->>'purpose' = 'platform_administration';

    v_subscriber_profile_id := v_account.profile_id;
    v_amount := v_plan.amount;

    -- Serialize annual-cycle assignment for this subscriber.
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
        v_cycle_type := 'initial_annual';
        v_period_start := COALESCE(p_requested_start_date, current_date);
        IF v_period_start < current_date THEN
            RAISE EXCEPTION 'Initial annual subscription start cannot be in the past'
                USING ERRCODE = '22023';
        END IF;
    ELSE
        v_cycle_type := 'renewal_annual';
        IF v_prev.id IS NULL THEN
            RAISE EXCEPTION 'Renewal requires a previous annual cycle'
                USING ERRCODE = '55000';
        END IF;
        -- Early renewal: day after the previous period end.
        -- Late renewal: current date. No retroactive access or grace period.
        v_period_start := CASE
            WHEN current_date <= v_prev.period_end THEN v_prev.period_end + 1
            ELSE current_date
        END;
    END IF;

    v_period_end := (v_period_start + interval '1 year' - interval '1 day')::date;

    IF EXISTS (
        SELECT 1
          FROM finance.subscription_cycles AS c
         WHERE c.billing_account_id = p_billing_account_id
           AND c.plan_id = p_plan_id
           AND c.period_start = v_period_start
    ) THEN
        RAISE EXCEPTION 'An annual cycle already exists for this account, plan and period start'
            USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
        SELECT 1 FROM system.invoices WHERE invoice_number = v_invoice_number
    ) THEN
        RAISE EXCEPTION 'Invoice number already exists: %', v_invoice_number
            USING ERRCODE = '23505';
    END IF;

    v_cycle_id := gen_random_uuid();

    -- Pending current-access row. Activation is a separate consumer step.
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
        'billing_cycle', 'yearly',
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
        'Annual personal subscription cycle ' || v_cycle_id::text,
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

REVOKE ALL ON FUNCTION "finance"."create_annual_subscription"(uuid, uuid, text, text, date, timestamp with time zone)
    FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "finance"."create_annual_subscription"(uuid, uuid, text, text, date, timestamp with time zone)
    TO "service_role";

COMMENT ON FUNCTION "finance"."create_annual_subscription"(uuid, uuid, text, text, date, timestamp with time zone)
    IS 'Creates a pending personal annual subscription, invoice, Finance obligation and permanent cycle. Requires an externally supplied invoice number. Does not post journals, open periods or initiate M-Pesa.';

COMMIT;

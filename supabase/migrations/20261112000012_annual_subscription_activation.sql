-- ============================================================================
-- 20261112000012_annual_subscription_activation
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Complete a pending annual subscription from an already-verified Finance
--   settlement. This function is a consumer of Finance truth, not a payment
--   engine.
--
-- FINANCE SOURCE OF TRUTH
--   * finance.obligations.status = 'settled'
--   * sum(finance.obligation_settlements.amount) = obligation.amount
--   * every settlement currency = obligation.currency
--   * the settlement payment exists and is verified
--   * linked payment attempt, when present, is succeeded
--
-- SCOPE
--   * reads Finance payments/settlements/attempts
--   * updates only system.active_subscriptions, system.invoices and
--     finance.subscription_cycles
--   * inserts one durable finance.events row
--   * creates no journal, no settlement, no payment, no referral reward
--   * requires no accounting period
--
-- IDEMPOTENCY / CONCURRENCY
--   * locks the cycle, obligation, active subscription and invoice rows
--   * repeated calls return the same completed state
--   * finance.events has unique source-event and idempotency guards
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS finance.complete_annual_subscription(uuid, uuid);
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION "finance"."complete_annual_subscription"(
    "p_subscription_cycle_id" uuid,
    "p_obligation_id" uuid DEFAULT NULL
)
RETURNS TABLE (
    "subscription_cycle_id" uuid,
    "active_subscription_id" uuid,
    "invoice_id" uuid,
    "obligation_id" uuid,
    "settlement_id" uuid,
    "payment_id" uuid,
    "settled_at" timestamp with time zone,
    "annual_sequence" integer,
    "cycle_type" text,
    "period_start" date,
    "period_end" date,
    "amount" numeric,
    "currency" text,
    "status" text,
    "event_id" uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, finance, system, core, users
AS $function$
DECLARE
    v_cycle finance.subscription_cycles%ROWTYPE;
    v_obligation finance.obligations%ROWTYPE;
    v_active system.active_subscriptions%ROWTYPE;
    v_invoice system.invoices%ROWTYPE;
    v_settlement finance.obligation_settlements%ROWTYPE;
    v_payment finance.payments%ROWTYPE;
    v_attempt_status text;
    v_settlement_count bigint;
    v_total_settled numeric(20,4);
    v_completed boolean;
    v_event_id uuid;
    v_event_key text;
    v_payload jsonb;
    v_existing_event finance.events%ROWTYPE;
BEGIN
    IF p_subscription_cycle_id IS NULL THEN
        RAISE EXCEPTION 'Subscription cycle id is required'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_cycle
      FROM finance.subscription_cycles
     WHERE id = p_subscription_cycle_id
     FOR UPDATE;

    IF p_obligation_id IS NOT NULL
       AND p_obligation_id IS DISTINCT FROM v_cycle.obligation_id THEN
        RAISE EXCEPTION 'Obligation does not belong to the subscription cycle'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_obligation
      FROM finance.obligations
     WHERE id = v_cycle.obligation_id
     FOR UPDATE;

    IF v_obligation.obligation_type <> 'subscription'
       OR v_obligation.payer_entity_id <> v_cycle.entity_id
       OR v_obligation.amount IS DISTINCT FROM v_cycle.amount
       OR v_obligation.currency <> v_cycle.currency
       OR coalesce(v_obligation.metadata->>'subscription_cycle_id', '') <> v_cycle.id::text
       OR coalesce(v_obligation.metadata->>'finance_charge_code', '') <> 'subscription' THEN
        RAISE EXCEPTION 'Finance obligation does not match the subscription cycle'
            USING ERRCODE = '55000';
    END IF;

    SELECT * INTO STRICT v_active
      FROM system.active_subscriptions
     WHERE id = v_cycle.active_subscription_id
     FOR UPDATE;

    SELECT * INTO STRICT v_invoice
      FROM system.invoices
     WHERE id = v_cycle.invoice_id
     FOR UPDATE;

    IF v_active.billing_account_id <> v_cycle.billing_account_id
       OR v_active.plan_id <> v_cycle.plan_id THEN
        RAISE EXCEPTION 'Active subscription does not match the subscription cycle'
            USING ERRCODE = '55000';
    END IF;

    IF v_invoice.billing_account_id <> v_cycle.billing_account_id
       OR v_invoice.total_amount IS DISTINCT FROM v_cycle.amount
       OR v_invoice.currency <> v_cycle.currency THEN
        RAISE EXCEPTION 'Invoice does not match the subscription cycle'
            USING ERRCODE = '55000';
    END IF;

    IF v_cycle.status NOT IN ('pending', 'active') THEN
        RAISE EXCEPTION 'Subscription cycle is not completable in status %', v_cycle.status
            USING ERRCODE = '55000';
    END IF;

    IF v_active.status NOT IN ('pending', 'active') THEN
        RAISE EXCEPTION 'Active subscription is not completable in status %', v_active.status
            USING ERRCODE = '55000';
    END IF;

    IF v_invoice.status NOT IN ('pending', 'paid') THEN
        RAISE EXCEPTION 'Invoice is not completable in status %', v_invoice.status
            USING ERRCODE = '55000';
    END IF;

    v_completed := v_cycle.status = 'active'
        AND v_active.status = 'active'
        AND v_invoice.status = 'paid';

    IF v_cycle.status = 'active' AND NOT v_completed THEN
        RAISE EXCEPTION 'Subscription cycle is marked active but completion state is inconsistent'
            USING ERRCODE = '55000';
    END IF;

    -- Authoritative Finance settlement check.
    IF v_obligation.status <> 'settled' THEN
        RAISE EXCEPTION 'Subscription obligation is not fully settled'
            USING ERRCODE = '55000';
    END IF;

    SELECT count(*), coalesce(sum(s.amount), 0)
      INTO v_settlement_count, v_total_settled
      FROM finance.obligation_settlements AS s
     WHERE s.obligation_id = v_obligation.id;

    IF v_settlement_count = 0
       OR v_total_settled IS DISTINCT FROM v_obligation.amount THEN
        RAISE EXCEPTION 'Subscription obligation settlement is partial or missing'
            USING ERRCODE = '55000';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM finance.obligation_settlements AS s
         WHERE s.obligation_id = v_obligation.id
           AND s.currency <> v_obligation.currency
    ) THEN
        RAISE EXCEPTION 'Settlement currency does not match the subscription obligation'
            USING ERRCODE = '55000';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM finance.obligation_settlements AS s
          LEFT JOIN finance.payments AS p ON p.id = s.payment_id
         WHERE s.obligation_id = v_obligation.id
           AND (p.id IS NULL OR p.verified_at IS NULL)
    ) THEN
        RAISE EXCEPTION 'Settlement is not backed by a verified Finance payment'
            USING ERRCODE = '55000';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM finance.obligation_settlements AS s
          JOIN finance.payments AS p ON p.id = s.payment_id
          LEFT JOIN finance.payment_attempts AS a ON a.id = p.payment_attempt_id
         WHERE s.obligation_id = v_obligation.id
           AND p.payment_attempt_id IS NOT NULL
           AND (a.id IS NULL OR a.status <> 'succeeded')
    ) THEN
        RAISE EXCEPTION 'A settlement payment attempt is not successfully completed'
            USING ERRCODE = '55000';
    END IF;

    SELECT s.* INTO STRICT v_settlement
      FROM finance.obligation_settlements AS s
     WHERE s.obligation_id = v_obligation.id
     ORDER BY s.settled_at DESC, s.id DESC
     LIMIT 1;

    SELECT * INTO STRICT v_payment
      FROM finance.payments
     WHERE id = v_settlement.payment_id;

    IF v_payment.obligation_id <> v_obligation.id
       OR v_payment.currency <> v_obligation.currency
       OR v_payment.amount < v_settlement.amount
       OR v_payment.verified_at IS NULL THEN
        RAISE EXCEPTION 'Settlement payment does not match the subscription obligation'
            USING ERRCODE = '55000';
    END IF;

    IF v_payment.payment_attempt_id IS NOT NULL THEN
        SELECT a.status INTO v_attempt_status
          FROM finance.payment_attempts AS a
         WHERE a.id = v_payment.payment_attempt_id
           AND a.obligation_id = v_obligation.id;

        IF NOT FOUND OR v_attempt_status <> 'succeeded' THEN
            RAISE EXCEPTION 'Payment attempt is not successfully completed'
                USING ERRCODE = '55000';
        END IF;
    END IF;

    v_event_key := 'subscription-cycle-activated:' || v_cycle.id::text;
    v_payload := jsonb_build_object(
        'subscription_cycle_id', v_cycle.id,
        'subscriber_profile_id', v_cycle.subscriber_profile_id,
        'subscriber_entity_id', v_cycle.entity_id,
        'plan_id', v_cycle.plan_id,
        'billing_account_id', v_cycle.billing_account_id,
        'invoice_id', v_cycle.invoice_id,
        'obligation_id', v_cycle.obligation_id,
        'settlement_id', v_settlement.id,
        'payment_id', v_settlement.payment_id,
        'settled_at', v_settlement.settled_at,
        'payment_verified_at', v_payment.verified_at,
        'amount', v_obligation.amount,
        'currency', v_obligation.currency,
        'annual_sequence', v_cycle.annual_sequence,
        'cycle_type', v_cycle.cycle_type,
        'period_start', v_cycle.period_start,
        'period_end', v_cycle.period_end
    );

    IF v_completed THEN
        IF v_active.start_date IS DISTINCT FROM v_cycle.period_start::timestamp AT TIME ZONE 'Africa/Nairobi'
           OR v_active.end_date IS DISTINCT FROM (v_cycle.period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi' THEN
            RAISE EXCEPTION 'Completed active subscription dates do not match the permanent cycle'
                USING ERRCODE = '55000';
        END IF;

        IF v_cycle.settled_at IS DISTINCT FROM v_settlement.settled_at THEN
            RAISE EXCEPTION 'Completed cycle settlement timestamp does not match the verified settlement'
                USING ERRCODE = '55000';
        END IF;

        IF v_invoice.paid_at IS DISTINCT FROM v_settlement.settled_at THEN
            RAISE EXCEPTION 'Completed invoice paid_at does not match the verified settlement'
                USING ERRCODE = '55000';
        END IF;

        SELECT * INTO v_existing_event
          FROM finance.events
         WHERE idempotency_key = v_event_key;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Completed subscription has no activation event'
                USING ERRCODE = '55000';
        END IF;

        IF v_existing_event.event_type <> 'finance.subscription.annual.activated'
           OR v_existing_event.source_type <> 'finance.subscription_cycle'
           OR v_existing_event.source_id <> v_cycle.id
           OR v_existing_event.payload IS DISTINCT FROM v_payload THEN
            RAISE EXCEPTION 'Existing activation event has a conflicting payload'
                USING ERRCODE = '55000';
        END IF;

        v_event_id := v_existing_event.id;

        RETURN QUERY
        SELECT v_cycle.id, v_cycle.active_subscription_id, v_cycle.invoice_id,
               v_cycle.obligation_id, v_settlement.id, v_settlement.payment_id,
               v_settlement.settled_at, v_cycle.annual_sequence, v_cycle.cycle_type,
               v_cycle.period_start, v_cycle.period_end, v_obligation.amount,
               v_obligation.currency, 'active'::text, v_event_id;
        RETURN;
    END IF;

    IF NOT v_completed THEN
        -- Use the stored permanent cycle dates. Never recalculate renewal dates.
        UPDATE system.active_subscriptions AS a
           SET status = 'active',
               start_date = v_cycle.period_start::timestamp AT TIME ZONE 'Africa/Nairobi',
               end_date = (v_cycle.period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'
         WHERE a.id = v_active.id
           AND a.status IN ('pending', 'active')
         RETURNING a.* INTO v_active;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Active subscription could not be activated'
                USING ERRCODE = '55000';
        END IF;

        UPDATE system.invoices AS i
           SET status = 'paid',
               paid_at = coalesce(i.paid_at, v_settlement.settled_at)
         WHERE i.id = v_invoice.id
           AND i.status IN ('pending', 'paid')
         RETURNING i.* INTO v_invoice;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Invoice could not be marked paid'
                USING ERRCODE = '55000';
        END IF;

        UPDATE finance.subscription_cycles AS c
           SET status = 'active',
               settled_at = v_settlement.settled_at,
               activated_at = coalesce(c.activated_at, clock_timestamp())
         WHERE c.id = v_cycle.id
           AND c.status IN ('pending', 'active')
         RETURNING c.* INTO v_cycle;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Subscription cycle could not be activated'
                USING ERRCODE = '55000';
        END IF;
    END IF;

    INSERT INTO finance.events (
        event_type, source_type, source_id, idempotency_key, payload
    ) VALUES (
        'finance.subscription.annual.activated',
        'finance.subscription_cycle',
        v_cycle.id,
        v_event_key,
        v_payload
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO v_event_id;

    IF v_event_id IS NULL THEN
        SELECT * INTO v_existing_event
          FROM finance.events
         WHERE idempotency_key = v_event_key;

        IF NOT FOUND
           OR v_existing_event.event_type <> 'finance.subscription.annual.activated'
           OR v_existing_event.source_type <> 'finance.subscription_cycle'
           OR v_existing_event.source_id <> v_cycle.id
           OR v_existing_event.payload IS DISTINCT FROM v_payload THEN
            RAISE EXCEPTION 'Existing activation event has a conflicting payload'
                USING ERRCODE = '55000';
        END IF;

        v_event_id := v_existing_event.id;
    END IF;

    RETURN QUERY
    SELECT v_cycle.id, v_cycle.active_subscription_id, v_cycle.invoice_id,
           v_cycle.obligation_id, v_settlement.id, v_settlement.payment_id,
           v_settlement.settled_at, v_cycle.annual_sequence, v_cycle.cycle_type,
           v_cycle.period_start, v_cycle.period_end, v_obligation.amount,
           v_obligation.currency, 'active'::text, v_event_id;
END;
$function$;

REVOKE ALL ON FUNCTION "finance"."complete_annual_subscription"(uuid, uuid)
    FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "finance"."complete_annual_subscription"(uuid, uuid)
    TO "service_role";

COMMENT ON FUNCTION "finance"."complete_annual_subscription"(uuid, uuid)
    IS 'Consumes a fully settled Finance subscription obligation and deterministically activates its permanent annual cycle. No journal, period, payment or referral reward is created.';

COMMIT;

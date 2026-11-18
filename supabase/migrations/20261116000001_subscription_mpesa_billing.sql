-- ============================================================================
-- 20261116000001_subscription_mpesa_billing
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Connect the existing annual subscription cycle to the existing generic
--   Finance M-Pesa rail.
--
-- FLOW
--   pending finance.subscription_cycles
--     -> finance.request_mpesa_attempt
--     -> existing generic M-Pesa orchestration/provider
--     -> finance.finalize_mpesa_payment
--     -> finance.complete_annual_subscription
--
-- SCOPE
--   * Two functions only.
--   * No table, ledger, subscription entitlement system, or payment state.
--   * No Daraja endpoint, credential, callback authentication, or provider
--     request is introduced.
--   * Finance remains the only owner of payment/attempt/settlement truth.
--   * The subscription domain remains the owner of cycle/access state.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS finance.confirm_annual_subscription_payment(uuid, uuid);
--   DROP FUNCTION IF EXISTS finance.request_annual_subscription_mpesa_attempt(uuid, text, text);
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Start/reuse an M-Pesa payment attempt for one pending annual subscription.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "finance"."request_annual_subscription_mpesa_attempt"(
    "p_subscription_cycle_id" uuid,
    "p_phone" text,
    "p_idempotency_key" text
)
RETURNS TABLE (
    "payment_attempt_id" uuid,
    "subscription_cycle_id" uuid,
    "obligation_id" uuid,
    "amount" numeric,
    "currency" text,
    "attempt_status" text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, finance, system, core, auth
AS $function$
DECLARE
    v_cycle finance.subscription_cycles%ROWTYPE;
    v_profile_id uuid := core.current_profile_id();
    v_attempt_id uuid;
BEGIN
    IF auth.uid() IS NULL OR v_profile_id IS NULL THEN
        RAISE EXCEPTION 'An active authenticated subscription owner is required'
            USING ERRCODE = '42501';
    END IF;
    IF p_subscription_cycle_id IS NULL THEN
        RAISE EXCEPTION 'Subscription cycle id is required'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_cycle
      FROM finance.subscription_cycles
     WHERE id = p_subscription_cycle_id
     FOR UPDATE;

    IF v_cycle.subscriber_profile_id IS DISTINCT FROM v_profile_id THEN
        RAISE EXCEPTION 'Caller does not own this subscription cycle'
            USING ERRCODE = '42501';
    END IF;
    IF v_cycle.status <> 'pending' THEN
        RAISE EXCEPTION 'Only a pending subscription cycle can start payment'
            USING ERRCODE = '55000';
    END IF;
    IF v_cycle.active_subscription_id IS NULL
       OR NOT EXISTS (
           SELECT 1
             FROM system.active_subscriptions AS a
            WHERE a.id = v_cycle.active_subscription_id
              AND a.billing_account_id = v_cycle.billing_account_id
              AND a.plan_id = v_cycle.plan_id
              AND a.status = 'pending'
       ) THEN
        RAISE EXCEPTION 'Pending subscription access row is missing or inconsistent'
            USING ERRCODE = '55000';
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM system.invoices AS i
         WHERE i.id = v_cycle.invoice_id
           AND i.billing_account_id = v_cycle.billing_account_id
           AND i.status = 'pending'
           AND i.total_amount = v_cycle.amount
           AND i.currency = v_cycle.currency
    ) THEN
        RAISE EXCEPTION 'Pending subscription invoice is missing or inconsistent'
            USING ERRCODE = '55000';
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM finance.obligations AS o
         WHERE o.id = v_cycle.obligation_id
           AND o.obligation_type = 'subscription'
           AND o.status IN ('open', 'partially_settled')
           AND o.amount = v_cycle.amount
           AND o.currency = v_cycle.currency
           AND o.metadata->>'finance_charge_code' = 'subscription'
           AND o.metadata->>'subscription_cycle_id' = v_cycle.id::text
    ) THEN
        RAISE EXCEPTION 'Subscription Finance obligation is missing or inconsistent'
            USING ERRCODE = '55000';
    END IF;

    v_attempt_id := finance.request_mpesa_attempt(
        v_cycle.obligation_id,
        v_cycle.amount,
        p_phone,
        p_idempotency_key
    );

    RETURN QUERY
    SELECT a.id, v_cycle.id, a.obligation_id, a.amount, a.currency, a.status
      FROM finance.payment_attempts AS a
     WHERE a.id = v_attempt_id;
END;
$function$;

REVOKE ALL ON FUNCTION "finance"."request_annual_subscription_mpesa_attempt"(uuid, text, text)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "finance"."request_annual_subscription_mpesa_attempt"(uuid, text, text)
    TO "authenticated";

COMMENT ON FUNCTION "finance"."request_annual_subscription_mpesa_attempt"(uuid, text, text)
    IS 'Starts or reuses an M-Pesa attempt for a caller-owned pending annual subscription cycle. Delegates attempt ownership and idempotency to Finance.';

-- ----------------------------------------------------------------------------
-- Confirm a verified M-Pesa payment and activate its subscription atomically.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "finance"."confirm_annual_subscription_payment"(
    "p_payment_attempt_id" uuid,
    "p_provider_event_id" uuid
)
RETURNS TABLE (
    "payment_id" uuid,
    "subscription_cycle_id" uuid,
    "active_subscription_id" uuid,
    "event_id" uuid,
    "status" text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, finance, system, core, auth
AS $function$
DECLARE
    v_attempt finance.payment_attempts%ROWTYPE;
    v_cycle finance.subscription_cycles%ROWTYPE;
    v_payment_id uuid;
    v_completion record;
BEGIN
    IF p_payment_attempt_id IS NULL OR p_provider_event_id IS NULL THEN
        RAISE EXCEPTION 'Payment attempt and provider event ids are required'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_attempt
      FROM finance.payment_attempts
     WHERE id = p_payment_attempt_id
     FOR UPDATE;

    IF lower(v_attempt.provider) <> 'mpesa' THEN
        RAISE EXCEPTION 'Only an M-Pesa payment attempt can confirm an annual subscription'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO STRICT v_cycle
      FROM finance.subscription_cycles
     WHERE obligation_id = v_attempt.obligation_id;

    IF v_cycle.status NOT IN ('pending', 'active') THEN
        RAISE EXCEPTION 'Subscription cycle is not confirmable in status %', v_cycle.status
            USING ERRCODE = '55000';
    END IF;
    IF v_attempt.amount IS DISTINCT FROM v_cycle.amount
       OR v_attempt.currency IS DISTINCT FROM v_cycle.currency THEN
        RAISE EXCEPTION 'Payment attempt does not match the subscription cycle amount or currency'
            USING ERRCODE = '55000';
    END IF;

    v_payment_id := finance.finalize_mpesa_payment(
        v_attempt.id,
        p_provider_event_id
    );

    SELECT * INTO v_completion
      FROM finance.complete_annual_subscription(
          v_cycle.id,
          v_cycle.obligation_id
      );

    RETURN QUERY
    SELECT v_payment_id, v_cycle.id, v_completion.active_subscription_id,
           v_completion.event_id, v_completion.status;
END;
$function$;

REVOKE ALL ON FUNCTION "finance"."confirm_annual_subscription_payment"(uuid, uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "finance"."confirm_annual_subscription_payment"(uuid, uuid)
    TO "service_role";

COMMENT ON FUNCTION "finance"."confirm_annual_subscription_payment"(uuid, uuid)
    IS 'Service-role-only atomic Finance finalization plus annual subscription activation. Reuses existing M-Pesa evidence, payment, settlement, journal and activation functions.';

COMMIT;

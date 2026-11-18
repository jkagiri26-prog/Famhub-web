-- ============================================================================
-- subscription_activation_test.sql
-- ----------------------------------------------------------------------------
-- Local-only tests for finance.complete_annual_subscription.
--
-- Run after applying migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000006001', 'Testland', 'KE', 'KEN', '254');

INSERT INTO users.profiles(id, first_name, country_id)
VALUES (
  '00000000-0000-0000-0000-000000006002',
  'Activation Tester',
  '00000000-0000-0000-0000-000000006001'
);

INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata) VALUES
  ('00000000-0000-0000-0000-000000006003', 'Activation Tester Entity', 'individual_pro', '00000000-0000-0000-0000-000000006002', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000006004', 'Platform Administration Test', 'trading_company', '00000000-0000-0000-0000-000000006002', true, '{"platform_entity":"true","purpose":"platform_administration"}'::jsonb);

INSERT INTO system.billing_accounts(id, entity_id, profile_id, account_type, status, currency)
VALUES (
  '00000000-0000-0000-0000-000000006005',
  '00000000-0000-0000-0000-000000006003',
  '00000000-0000-0000-0000-000000006002',
  'individual',
  'active',
  'KES'
);

CREATE OR REPLACE FUNCTION pg_temp.make_cycle(
    p_suffix text,
    p_plan_id uuid,
    p_billing_account_id uuid
)
RETURNS TABLE (
    cycle_id uuid,
    active_id uuid,
    invoice_id uuid,
    obligation_id uuid
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT f.subscription_cycle_id, f.active_subscription_id, f.invoice_id, f.obligation_id
      FROM finance.create_annual_subscription(
        p_billing_account_id,
        p_plan_id,
        'ACT-INV-' || p_suffix,
        'act-' || p_suffix,
        NULL,
        NULL
      ) AS f;
END;
$function$;

DO $test$
DECLARE
    v_plan_id uuid;
    v_cycle_id uuid;
    v_active_id uuid;
    v_invoice_id uuid;
    v_obligation_id uuid;
    v_other_obligation_id uuid;
    v_payment_id uuid;
    v_settlement_id uuid;
    v_settled_at timestamptz := '2026-01-15 10:00:00+00'::timestamptz;
    v_start date;
    v_end date;
    v_result record;
    v_retry record;
    v_count bigint;
    v_journal_before bigint;
    v_journal_after bigint;
BEGIN
    SELECT plan_id INTO v_plan_id
      FROM system.create_annual_subscription_plan(
        'activation-test-plan',
        'Activation Test Annual',
        12000,
        NULL,
        '{}'::jsonb
      );

    -- ------------------------------------------------------------------
    -- 3/4/5/6/7/8/9/13. Fully settled obligation activates exactly once,
    -- preserves cycle dates, uses settlement timestamp, and creates no journal.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c1', v_plan_id, '00000000-0000-0000-0000-000000006005');

    SELECT period_start, period_end INTO v_start, v_end
      FROM finance.subscription_cycles WHERE id = v_cycle_id;

    INSERT INTO finance.payments (
        obligation_id, payer_entity_id, payee_entity_id, provider,
        provider_reference, amount, currency, verified_at
    ) VALUES (
        v_obligation_id,
        '00000000-0000-0000-0000-000000006003',
        '00000000-0000-0000-0000-000000006004',
        'test', 'VERIFY-ACT-1', 12000, 'KES', v_settled_at
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key
    ) VALUES (
        v_obligation_id, v_payment_id, 'KES', 12000, v_settled_at, 'settle-act-1'
    ) RETURNING id INTO v_settlement_id;

    UPDATE finance.obligations SET status = 'settled' WHERE id = v_obligation_id;

    SELECT count(*) INTO v_journal_before FROM finance.journals;

    SELECT * INTO v_result
      FROM finance.complete_annual_subscription(v_cycle_id, v_obligation_id);

    IF v_result.status <> 'active' THEN
        RAISE EXCEPTION 'expected active completion, found %', v_result.status;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM system.active_subscriptions
         WHERE id = v_active_id
           AND status = 'active'
           AND start_date = v_start::timestamp AT TIME ZONE 'Africa/Nairobi'
           AND end_date = (v_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'
    ) THEN
        RAISE EXCEPTION 'active subscription was not activated with stored cycle dates';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM system.invoices
         WHERE id = v_invoice_id
           AND status = 'paid'
           AND paid_at = v_settled_at
    ) THEN
        RAISE EXCEPTION 'invoice was not paid with the verified settlement timestamp';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM finance.subscription_cycles
         WHERE id = v_cycle_id
           AND status = 'active'
           AND period_start = v_start
           AND period_end = v_end
           AND settled_at = v_settled_at
    ) THEN
        RAISE EXCEPTION 'permanent cycle history was not preserved correctly';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM finance.events
         WHERE id = v_result.event_id
           AND event_type = 'finance.subscription.annual.activated'
           AND source_type = 'finance.subscription_cycle'
           AND source_id = v_cycle_id
           AND payload->>'subscription_cycle_id' = v_cycle_id::text
           AND payload->>'settlement_id' = v_settlement_id::text
           AND payload->>'payment_id' = v_payment_id::text
           AND payload->>'amount' = '12000.0000'
           AND payload->>'currency' = 'KES'
    ) THEN
        RAISE EXCEPTION 'durable subscription activation event is missing or incomplete';
    END IF;

    SELECT * INTO v_retry
      FROM finance.complete_annual_subscription(v_cycle_id);

    IF v_retry.event_id <> v_result.event_id
       OR v_retry.settlement_id <> v_result.settlement_id
       OR v_retry.subscription_cycle_id <> v_cycle_id THEN
        RAISE EXCEPTION 'idempotent completion returned different results';
    END IF;

    SELECT count(*) INTO v_count
      FROM finance.events
     WHERE idempotency_key = 'subscription-cycle-activated:' || v_cycle_id::text;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'duplicate subscription activation events were created';
    END IF;

    SELECT count(*) INTO v_count
      FROM system.invoices
     WHERE id = v_invoice_id AND status = 'paid';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'invoice paid count is not exactly one';
    END IF;

    SELECT count(*) INTO v_count
      FROM system.active_subscriptions
     WHERE id = v_active_id AND status = 'active';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'active subscription count is not exactly one';
    END IF;

    SELECT count(*) INTO v_journal_after FROM finance.journals;
    IF v_journal_after <> v_journal_before THEN
        RAISE EXCEPTION 'activation created or modified a Finance journal';
    END IF;

    v_other_obligation_id := v_obligation_id;

    -- ------------------------------------------------------------------
    -- 1. Unsettled obligation cannot activate.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c2', v_plan_id, '00000000-0000-0000-0000-000000006005');

    BEGIN
        PERFORM finance.complete_annual_subscription(v_cycle_id);
        RAISE EXCEPTION 'expected unsettled obligation rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;

    -- ------------------------------------------------------------------
    -- 2. Partial settlement cannot activate.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c3', v_plan_id, '00000000-0000-0000-0000-000000006005');

    INSERT INTO finance.payments (
        obligation_id, payer_entity_id, payee_entity_id, provider,
        provider_reference, amount, currency, verified_at
    ) VALUES (
        v_obligation_id,
        '00000000-0000-0000-0000-000000006003',
        '00000000-0000-0000-0000-000000006004',
        'test', 'VERIFY-ACT-3', 5000, 'KES', v_settled_at
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key
    ) VALUES (
        v_obligation_id, v_payment_id, 'KES', 5000, v_settled_at, 'settle-act-3'
    );

    UPDATE finance.obligations SET status = 'partially_settled' WHERE id = v_obligation_id;

    BEGIN
        PERFORM finance.complete_annual_subscription(v_cycle_id);
        RAISE EXCEPTION 'expected partial settlement rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;

    -- ------------------------------------------------------------------
    -- 11. A different obligation cannot activate the subscription.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c4', v_plan_id, '00000000-0000-0000-0000-000000006005');

    BEGIN
        PERFORM finance.complete_annual_subscription(v_cycle_id, v_other_obligation_id);
        RAISE EXCEPTION 'expected different-obligation rejection';
    EXCEPTION WHEN SQLSTATE '22023' THEN
        NULL;
    END;

    -- ------------------------------------------------------------------
    -- 12. Currency mismatch cannot activate.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c5', v_plan_id, '00000000-0000-0000-0000-000000006005');

    INSERT INTO finance.payments (
        obligation_id, payer_entity_id, payee_entity_id, provider,
        provider_reference, amount, currency, verified_at
    ) VALUES (
        v_obligation_id,
        '00000000-0000-0000-0000-000000006003',
        '00000000-0000-0000-0000-000000006004',
        'test', 'VERIFY-ACT-5', 12000, 'USD', v_settled_at
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key
    ) VALUES (
        v_obligation_id, v_payment_id, 'USD', 12000, v_settled_at, 'settle-act-5'
    );

    UPDATE finance.obligations SET status = 'settled' WHERE id = v_obligation_id;

    BEGIN
        PERFORM finance.complete_annual_subscription(v_cycle_id);
        RAISE EXCEPTION 'expected currency mismatch rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;

    -- ------------------------------------------------------------------
    -- 10. Failed payment attempt cannot activate.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c6', v_plan_id, '00000000-0000-0000-0000-000000006005');

    INSERT INTO finance.payment_attempts (
        obligation_id, payer_entity_id, provider, method_type,
        amount, currency, status, idempotency_key
    ) VALUES (
        v_obligation_id,
        '00000000-0000-0000-0000-000000006003',
        'test', 'other', 12000, 'KES', 'failed', 'attempt-act-6'
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.payments (
        obligation_id, payment_attempt_id, payer_entity_id, payee_entity_id,
        provider, provider_reference, amount, currency, verified_at
    ) VALUES (
        v_obligation_id, v_payment_id,
        '00000000-0000-0000-0000-000000006003',
        '00000000-0000-0000-0000-000000006004',
        'test', 'VERIFY-ACT-6', 12000, 'KES', v_settled_at
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key
    ) VALUES (
        v_obligation_id, v_payment_id, 'KES', 12000, v_settled_at, 'settle-act-6'
    );

    UPDATE finance.obligations SET status = 'settled' WHERE id = v_obligation_id;

    BEGIN
        PERFORM finance.complete_annual_subscription(v_cycle_id);
        RAISE EXCEPTION 'expected failed-attempt rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;

    -- ------------------------------------------------------------------
    -- Existing activation event with a conflicting payload must fail.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c7', v_plan_id, '00000000-0000-0000-0000-000000006005');

    INSERT INTO finance.payments (
        obligation_id, payer_entity_id, payee_entity_id, provider,
        provider_reference, amount, currency, verified_at
    ) VALUES (
        v_obligation_id,
        '00000000-0000-0000-0000-000000006003',
        '00000000-0000-0000-0000-000000006004',
        'test', 'VERIFY-ACT-7', 12000, 'KES', v_settled_at
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key
    ) VALUES (
        v_obligation_id, v_payment_id, 'KES', 12000, v_settled_at, 'settle-act-7'
    );

    UPDATE finance.obligations SET status = 'settled' WHERE id = v_obligation_id;

    INSERT INTO finance.events (
        event_type, source_type, source_id, idempotency_key, payload
    ) VALUES (
        'finance.subscription.annual.activated',
        'finance.subscription_cycle',
        v_cycle_id,
        'subscription-cycle-activated:' || v_cycle_id::text,
        '{"conflict":true}'::jsonb
    );

    BEGIN
        PERFORM finance.complete_annual_subscription(v_cycle_id);
        RAISE EXCEPTION 'expected conflicting activation event rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;

    -- ------------------------------------------------------------------
    -- Already-active state without an event must not be accepted as retry.
    -- ------------------------------------------------------------------
    SELECT cycle_id, active_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM pg_temp.make_cycle('c8', v_plan_id, '00000000-0000-0000-0000-000000006005');

    SELECT period_start, period_end INTO v_start, v_end
      FROM finance.subscription_cycles WHERE id = v_cycle_id;

    INSERT INTO finance.payments (
        obligation_id, payer_entity_id, payee_entity_id, provider,
        provider_reference, amount, currency, verified_at
    ) VALUES (
        v_obligation_id,
        '00000000-0000-0000-0000-000000006003',
        '00000000-0000-0000-0000-000000006004',
        'test', 'VERIFY-ACT-8', 12000, 'KES', v_settled_at
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key
    ) VALUES (
        v_obligation_id, v_payment_id, 'KES', 12000, v_settled_at, 'settle-act-8'
    );

    UPDATE finance.obligations SET status = 'settled' WHERE id = v_obligation_id;
    UPDATE system.active_subscriptions
       SET status = 'active',
           start_date = v_start::timestamp AT TIME ZONE 'Africa/Nairobi',
           end_date = (v_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'
     WHERE id = v_active_id;
    UPDATE system.invoices
       SET status = 'paid', paid_at = v_settled_at
     WHERE id = v_invoice_id;
    UPDATE finance.subscription_cycles
       SET status = 'active', settled_at = v_settled_at, activated_at = now()
     WHERE id = v_cycle_id;

    BEGIN
        PERFORM finance.complete_annual_subscription(v_cycle_id);
        RAISE EXCEPTION 'expected missing activation event rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;
END;
$test$;

ROLLBACK;

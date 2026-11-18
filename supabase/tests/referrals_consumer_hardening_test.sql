-- ============================================================================
-- referrals_consumer_hardening_test.sql
-- LOCAL-ONLY qualification safeguard tests for the referral consumer.
-- ============================================================================
BEGIN;

UPDATE referrals.program_settings SET foundation_activation_enabled=true;

SELECT finance.ensure_referral_accounts(
  '00000000-0000-4000-8000-000000000104', '2400', 'Staging Referral Rewards Payable');
INSERT INTO finance.accounting_periods (entity_id, start_date, end_date, status, created_by)
SELECT '00000000-0000-4000-8000-000000000104', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date, 'open',
       '00000000-0000-4000-8000-000000000103'
WHERE NOT EXISTS (
  SELECT 1 FROM finance.accounting_periods
  WHERE entity_id='00000000-0000-4000-8000-000000000104'
    AND status='open' AND current_date BETWEEN start_date AND end_date
);
INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('10000000-0000-4000-8000-000000000101', 'Consumer Testland', 'ZZ', 'ZZZ', '999', true);
INSERT INTO users.profiles (id, auth_user_id, first_name, last_name, email, phone, country_id, is_active, account_status)
VALUES ('10000000-0000-4000-8000-000000000110', '20000000-0000-4000-8000-000000000110',
        'Referrer', 'Owner', 'consumer-referrer@example.invalid', '+254711000110',
        '10000000-0000-4000-8000-000000000101', true, 'active');

CREATE OR REPLACE FUNCTION pg_temp.make_event(
    p_kind text,
    p_settled_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
AS $function$
DECLARE
    v_profile uuid := gen_random_uuid();
    v_entity uuid := gen_random_uuid();
    v_billing uuid := gen_random_uuid();
    v_plan uuid := gen_random_uuid();
    v_active uuid := gen_random_uuid();
    v_invoice uuid := gen_random_uuid();
    v_obligation uuid := gen_random_uuid();
    v_attempt uuid;
    v_payment uuid := gen_random_uuid();
    v_settlement uuid := gen_random_uuid();
    v_cycle uuid := gen_random_uuid();
    v_prev_invoice uuid := gen_random_uuid();
    v_prev_obligation uuid := gen_random_uuid();
    v_prev_cycle uuid := gen_random_uuid();
    v_previous uuid;
    v_event uuid := gen_random_uuid();
    v_amount numeric := 12000;
    v_settle numeric := 12000;
    v_obligation_status text := 'settled';
    v_invoice_status text := 'paid';
    v_attempt_status text;
    v_sequence integer := 1;
    v_cycle_type text := 'initial_annual';
    v_referral_status text := 'attributed';
    v_referral_code text := 'CONSUMER-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
BEGIN
    IF p_kind = 'pending' THEN v_obligation_status := 'open'; v_invoice_status := 'pending';
    ELSIF p_kind = 'partial' THEN v_obligation_status := 'partially_settled'; v_settle := 5000;
    ELSIF p_kind = 'failed_attempt' THEN v_attempt_status := 'failed';
    ELSIF p_kind = 'renewal' THEN v_sequence := 2; v_cycle_type := 'renewal_annual'; v_previous := v_prev_cycle;
    ELSIF p_kind = 'review' THEN v_referral_status := 'review_required';
    END IF;

    INSERT INTO users.profiles (id, first_name, last_name, email, phone, country_id, is_active, account_status)
    VALUES (v_profile, 'Consumer', p_kind, p_kind || '-' || v_profile || '@example.invalid',
            '+2547' || right(replace(v_profile::text, '-', ''), 8),
            '10000000-0000-4000-8000-000000000101', true, 'active');
    INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, metadata)
    VALUES (v_entity, 'Consumer Entity ' || p_kind, 'individual_pro', v_profile, true, '{}'::jsonb);
    INSERT INTO system.billing_accounts (id, entity_id, profile_id, account_type, currency, status)
    VALUES (v_billing, v_entity, v_profile, 'individual', 'KES', 'active');
    INSERT INTO system.subscription_plans (id, plan_key, plan_name, billing_cycle, amount, currency, is_active)
    VALUES (v_plan, 'consumer-' || v_plan, 'Consumer Plan', 'yearly', 12000, 'KES', true);
    INSERT INTO system.active_subscriptions (id, billing_account_id, plan_id, status, start_date, end_date)
    VALUES (v_active, v_billing, v_plan, 'active', p_settled_at, p_settled_at + interval '1 year');
    INSERT INTO system.invoices (id, billing_account_id, invoice_number, module_name, status, total_amount, currency, paid_at)
    VALUES (v_invoice, v_billing, 'CONSUMER-' || replace(v_invoice::text,'-',''), 'subscription', v_invoice_status, 12000, 'KES',
            CASE WHEN v_invoice_status='paid' THEN p_settled_at ELSE NULL END);
    INSERT INTO finance.obligations (id, payer_entity_id, payee_entity_id, obligation_type, status, amount, currency, idempotency_key, metadata)
    VALUES (v_obligation, v_entity, '00000000-0000-4000-8000-000000000104', 'subscription', v_obligation_status, 12000, 'KES',
            'consumer-obligation-' || v_obligation, '{"finance_charge_code":"subscription","tax_treatment":"not_applicable"}'::jsonb);
    IF v_attempt_status IS NOT NULL THEN
        v_attempt := gen_random_uuid();
        INSERT INTO finance.payment_attempts (id, obligation_id, payer_entity_id, provider, method_type, amount, currency, status, idempotency_key)
        VALUES (v_attempt, v_obligation, v_entity, 'test', 'other', 12000, 'KES', v_attempt_status, 'consumer-attempt-' || v_attempt);
    END IF;
    INSERT INTO finance.payments (id, obligation_id, payment_attempt_id, payer_entity_id, payee_entity_id, provider, provider_reference, amount, currency, verified_at)
    VALUES (v_payment, v_obligation, v_attempt, v_entity, '00000000-0000-4000-8000-000000000104',
            'test', 'consumer-payment-' || v_payment, 12000, 'KES', p_settled_at);
    INSERT INTO finance.obligation_settlements (id, obligation_id, payment_id, currency, amount, settled_at, idempotency_key)
    VALUES (v_settlement, v_obligation, v_payment, 'KES', v_settle, p_settled_at, 'consumer-settlement-' || v_settlement);
    IF p_kind = 'renewal' THEN
        INSERT INTO system.invoices (id, billing_account_id, invoice_number, module_name, status, total_amount, currency, paid_at)
        VALUES (v_prev_invoice, v_billing, 'CONSUMER-PREV-' || replace(v_prev_invoice::text,'-',''), 'subscription', 'paid', 12000, 'KES', p_settled_at - interval '1 year');
        INSERT INTO finance.obligations (id, payer_entity_id, payee_entity_id, obligation_type, status, amount, currency, idempotency_key, metadata)
        VALUES (v_prev_obligation, v_entity, '00000000-0000-4000-8000-000000000104', 'subscription', 'settled', 12000, 'KES',
                'consumer-prev-obligation-' || v_prev_obligation, '{"finance_charge_code":"subscription","tax_treatment":"not_applicable"}'::jsonb);
        INSERT INTO finance.subscription_cycles (
            id, billing_account_id, subscriber_profile_id, entity_id, plan_id, active_subscription_id,
            annual_sequence, cycle_type, period_start, period_end, invoice_id, obligation_id,
            amount, currency, status, idempotency_key
        ) VALUES (
            v_prev_cycle, v_billing, v_profile, v_entity, v_plan, v_active, 1, 'initial_annual',
            (p_settled_at - interval '1 year')::date, (p_settled_at - interval '1 day')::date,
            v_prev_invoice, v_prev_obligation, 12000, 'KES', 'active', 'consumer-prev-cycle-' || v_prev_cycle
        );
    END IF;
    INSERT INTO finance.subscription_cycles (
        id, billing_account_id, subscriber_profile_id, entity_id, plan_id, active_subscription_id,
        annual_sequence, cycle_type, previous_cycle_id, period_start, period_end, invoice_id, obligation_id,
        amount, currency, status, idempotency_key
    ) VALUES (
        v_cycle, v_billing, v_profile, v_entity, v_plan, v_active, v_sequence, v_cycle_type, v_previous,
        p_settled_at::date, p_settled_at::date + 364, v_invoice, v_obligation,
        12000, 'KES', 'active', 'consumer-cycle-' || v_cycle
    );
    INSERT INTO referrals.referrals (id, referrer_profile_id, referred_profile_id, referral_code, attribution_method, status)
    VALUES (gen_random_uuid(), '10000000-0000-4000-8000-000000000110', v_profile, v_referral_code, 'code', v_referral_status);
    INSERT INTO finance.events (id, event_type, source_type, source_id, idempotency_key, payload)
    VALUES (v_event, 'finance.subscription.annual.activated', 'finance.subscription_cycle', v_cycle,
            'consumer-event-' || v_event,
            jsonb_build_object('subscription_cycle_id', v_cycle, 'subscriber_profile_id', v_profile,
              'subscriber_entity_id', v_entity, 'plan_id', v_plan, 'billing_account_id', v_billing,
              'invoice_id', v_invoice, 'obligation_id', v_obligation, 'settlement_id', v_settlement,
              'payment_id', v_payment, 'settled_at', p_settled_at, 'payment_verified_at', p_settled_at,
              'amount', 12000, 'currency', 'KES', 'annual_sequence', v_sequence,
              'cycle_type', v_cycle_type, 'period_start', p_settled_at::date, 'period_end', p_settled_at::date + 364));
    RETURN v_event;
END;
$function$;

DO $safeguards$
DECLARE
    v_event uuid;
    v_result record;
    v_reward_count bigint;
    v_ts timestamptz := '2026-11-11 12:00:00+00';
BEGIN
    -- Pending/unsettled.
    v_event := pg_temp.make_event('pending', v_ts);
    SELECT * INTO v_result FROM referrals.consume_finance_event(v_event);
    IF v_result.outcome <> 'not_fully_settled' THEN RAISE EXCEPTION 'pending event was not rejected: %', v_result.outcome; END IF;

    -- Partial settlement.
    v_event := pg_temp.make_event('partial', v_ts);
    SELECT * INTO v_result FROM referrals.consume_finance_event(v_event);
    IF v_result.outcome <> 'not_fully_settled' THEN RAISE EXCEPTION 'partial event was not rejected: %', v_result.outcome; END IF;

    -- Failed payment attempt.
    v_event := pg_temp.make_event('failed_attempt', v_ts);
    SELECT * INTO v_result FROM referrals.consume_finance_event(v_event);
    IF v_result.outcome <> 'payment_attempt_not_succeeded' THEN RAISE EXCEPTION 'failed attempt was not rejected: %', v_result.outcome; END IF;

    -- Renewal.
    v_event := pg_temp.make_event('renewal', v_ts);
    SELECT * INTO v_result FROM referrals.consume_finance_event(v_event);
    IF v_result.outcome <> 'renewal_excluded' THEN RAISE EXCEPTION 'renewal was not excluded: %', v_result.outcome; END IF;

    -- Ambiguous referral held for review.
    v_event := pg_temp.make_event('review', v_ts);
    SELECT * INTO v_result FROM referrals.consume_finance_event(v_event);
    IF v_result.outcome <> 'referral_not_eligible' THEN RAISE EXCEPTION 'review referral was not held: %', v_result.outcome; END IF;

    -- Partner employee / ordinary referred user succeeds.
    v_event := pg_temp.make_event('partner', v_ts);
    SELECT * INTO v_result FROM referrals.consume_finance_event(v_event);
    IF v_result.outcome <> 'rewarded' THEN RAISE EXCEPTION 'partner employee was not rewarded: %', v_result.outcome; END IF;
    SELECT count(*) INTO v_reward_count FROM referrals.rewards WHERE source_finance_event_id=v_event;
    IF v_reward_count <> 1 THEN RAISE EXCEPTION 'expected one partner reward, found %', v_reward_count; END IF;

    -- Vunio employee exclusion at consumer level, equal timestamp.
    v_event := pg_temp.make_event('employee', v_ts);
    INSERT INTO referrals.employee_exclusions (profile_id, employer_entity_id, employment_start_at, reason, created_by)
    SELECT r.referred_profile_id, '00000000-0000-4000-8000-000000000104', v_ts, 'Vunio employee', '00000000-0000-4000-8000-000000000103'
      FROM referrals.referrals r JOIN finance.events e ON e.id=v_event AND r.referred_profile_id=(e.payload->>'subscriber_profile_id')::uuid;
    SELECT * INTO v_result FROM referrals.consume_finance_event(v_event);
    IF v_result.outcome <> 'employee_excluded' THEN RAISE EXCEPTION 'employee event was not excluded: %', v_result.outcome; END IF;
END;
$safeguards$;

ROLLBACK;

-- ============================================================================
-- referrals_runtime_workflow_test.sql
-- LOCAL-ONLY tests for the forward-only Refer & Earn workflow.
-- ============================================================================
BEGIN;

UPDATE referrals.program_settings SET foundation_activation_enabled=true;

-- Minimal local setup for reward accrual and payout obligations.
SELECT finance.ensure_referral_accounts(
  '00000000-0000-4000-8000-000000000104',
  '2400',
  'Staging Referral Rewards Payable'
);

INSERT INTO finance.ledger_accounts (entity_id, account_code, account_name, account_type, normal_balance, currency, is_active)
VALUES ('00000000-0000-4000-8000-000000000104', '1000', 'M-Pesa Platform Collections Clearing', 'asset', 'debit', 'KES', true)
ON CONFLICT (entity_id, account_code) DO NOTHING;

INSERT INTO finance.accounting_periods (entity_id, start_date, end_date, status, created_by)
SELECT '00000000-0000-4000-8000-000000000104', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date, 'open',
       '00000000-0000-4000-8000-000000000103'
WHERE NOT EXISTS (
  SELECT 1 FROM finance.accounting_periods
  WHERE entity_id='00000000-0000-4000-8000-000000000104'
    AND status='open' AND current_date BETWEEN start_date AND end_date
);

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('10000000-0000-4000-8000-000000000001', 'Referral Testland', 'ZZ', 'ZZZ', '999', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, last_name, email, phone, country_id, is_active, account_status)
VALUES
 ('10000000-0000-4000-8000-000000000010', '20000000-0000-4000-8000-000000000010', 'Alice', 'Referrer', 'alice@example.invalid', '+254700000010', '10000000-0000-4000-8000-000000000001', true, 'active'),
 ('10000000-0000-4000-8000-000000000011', '20000000-0000-4000-8000-000000000011', 'Bob', 'Referred', 'bob@example.invalid', '+254700000011', '10000000-0000-4000-8000-000000000001', true, 'active'),
 ('10000000-0000-4000-8000-000000000012', '20000000-0000-4000-8000-000000000012', 'Carol', 'Same', 'carol@example.invalid', '+254700000012', '10000000-0000-4000-8000-000000000001', true, 'active'),
 ('10000000-0000-4000-8000-000000000013', '20000000-0000-4000-8000-000000000013', 'Dave', 'Employee', 'dave@example.invalid', '+254700000013', '10000000-0000-4000-8000-000000000001', true, 'active');

INSERT INTO core.user_roles (name, type, description, is_active)
SELECT 'Admin', 'administration',
       'Existing platform administration role used by Refer & Earn tests', true
WHERE NOT EXISTS (SELECT 1 FROM core.user_roles WHERE name='Admin');

INSERT INTO core.entity_roles (profile_id, entity_id, role_id, assigned_by, is_active)
SELECT '10000000-0000-4000-8000-000000000010',
       '00000000-0000-4000-8000-000000000104', id,
       '00000000-0000-4000-8000-000000000103', true
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (profile_id, entity_id, role_id) DO NOTHING;

INSERT INTO core.entity_members (entity_id, profile_id, role_id, is_active, membership_status)
SELECT '00000000-0000-4000-8000-000000000104',
       '10000000-0000-4000-8000-000000000010', id, true, 'active'
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (entity_id, profile_id) DO UPDATE
SET role_id = EXCLUDED.role_id, is_active = true, membership_status = 'active';

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, metadata)
VALUES ('10000000-0000-4000-8000-000000000020', 'Alice Individual', 'individual_pro',
        '10000000-0000-4000-8000-000000000010', true, '{}'::jsonb);

DO $attribution$
DECLARE
    v_code text;
    v_ref record;
    v_self record;
    v_review record;
BEGIN
    PERFORM set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000010', true);
    v_code := referrals.get_or_create_referral_code();
    IF v_code IS NULL OR length(v_code) < 5 THEN
        RAISE EXCEPTION 'referral code generation failed';
    END IF;

    PERFORM set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000011', true);
    SELECT * INTO v_ref FROM referrals.register_referral(v_code, NULL, '+254700000011', 'bob@example.invalid');
    IF v_ref.referral_status <> 'attributed' THEN
        RAISE EXCEPTION 'ordinary referral was not attributed: %', v_ref.referral_status;
    END IF;

    -- Same phone is a confirmed self-referral signal.
    PERFORM set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000012', true);
    SELECT * INTO v_self FROM referrals.register_referral(v_code, NULL, '+254700000010', 'carol@example.invalid');
    IF v_self.referral_status <> 'ineligible' THEN
        RAISE EXCEPTION 'self phone referral was not rejected: %', v_self.referral_status;
    END IF;

    -- Same normalized name with different contact signals requires review.
    UPDATE users.profiles SET first_name='Alice', last_name='Referrer'
     WHERE id='10000000-0000-4000-8000-000000000013';
    PERFORM set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000013', true);
    SELECT * INTO v_review FROM referrals.register_referral(v_code, NULL, '+254700000099', 'dave@example.invalid');
    IF v_review.referral_status <> 'review_required' THEN
        RAISE EXCEPTION 'ambiguous referral was not held for review: %', v_review.referral_status;
    END IF;
END;
$attribution$;

DO $employee$
DECLARE
    v_settled timestamptz := '2026-11-11 12:00:00+00';
    v_result boolean;
BEGIN
    INSERT INTO referrals.employee_exclusions (
        profile_id, employer_entity_id, employment_start_at, employment_end_at,
        reason, created_by
    ) VALUES (
        '10000000-0000-4000-8000-000000000013',
        '00000000-0000-4000-8000-000000000104',
        v_settled, v_settled + interval '30 days', 'Vunio employee', '00000000-0000-4000-8000-000000000103'
    );
    v_result := referrals.is_employee_excluded(
        '10000000-0000-4000-8000-000000000013', NULL, NULL, v_settled);
    IF v_result IS NOT TRUE THEN
        RAISE EXCEPTION 'equal employment start must be excluded';
    END IF;
    v_result := referrals.is_employee_excluded(
        '10000000-0000-4000-8000-000000000013', NULL, NULL, v_settled - interval '1 second');
    IF v_result IS NOT FALSE THEN
        RAISE EXCEPTION 'settlement before employment start must be eligible';
    END IF;
    v_result := referrals.is_employee_excluded(
        '10000000-0000-4000-8000-000000000013', NULL, NULL, v_settled + interval '31 days');
    IF v_result IS NOT FALSE THEN
        RAISE EXCEPTION 'settlement after employment end must be eligible';
    END IF;
END;
$employee$;

-- Finance qualification fixture for Bob.
INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, metadata)
VALUES ('10000000-0000-4000-8000-000000000031', 'Bob Individual', 'individual_pro',
        '10000000-0000-4000-8000-000000000011', true, '{}'::jsonb);
INSERT INTO system.billing_accounts (id, entity_id, profile_id, account_type, currency, status)
VALUES ('10000000-0000-4000-8000-000000000030', '10000000-0000-4000-8000-000000000031',
        '10000000-0000-4000-8000-000000000011', 'individual', 'KES', 'active');
INSERT INTO system.subscription_plans (id, plan_key, plan_name, billing_cycle, amount, currency, is_active)
VALUES ('10000000-0000-4000-8000-000000000032', 'ref-test-yearly', 'Referral Test Yearly', 'yearly', 12000, 'KES', true);
INSERT INTO system.active_subscriptions (id, billing_account_id, plan_id, status, start_date, end_date)
VALUES ('10000000-0000-4000-8000-000000000033', '10000000-0000-4000-8000-000000000030',
        '10000000-0000-4000-8000-000000000032', 'active', now(), now() + interval '1 year');
INSERT INTO system.invoices (id, billing_account_id, invoice_number, module_name, status, total_amount, currency, paid_at)
VALUES ('10000000-0000-4000-8000-000000000034', '10000000-0000-4000-8000-000000000030',
        'REF-TEST-001', 'subscription', 'paid', 12000, 'KES', now());
INSERT INTO system.invoice_items (invoice_id, item_type, description, quantity, unit_price, total_amount)
VALUES ('10000000-0000-4000-8000-000000000034', 'subscription', 'Referral test plan', 1, 12000, 12000);
INSERT INTO finance.obligations (
    id, payer_entity_id, payee_entity_id, obligation_type, status, amount, currency,
    idempotency_key, metadata
) VALUES (
    '10000000-0000-4000-8000-000000000035', '10000000-0000-4000-8000-000000000031',
    '00000000-0000-4000-8000-000000000104', 'subscription', 'settled', 12000, 'KES',
    'ref-test-obligation', '{"finance_charge_code":"subscription","tax_treatment":"not_applicable"}'::jsonb
);
INSERT INTO finance.payments (
    id, obligation_id, payer_entity_id, payee_entity_id, provider, provider_reference,
    amount, currency, verified_at
) VALUES (
    '10000000-0000-4000-8000-000000000036', '10000000-0000-4000-8000-000000000035',
    '10000000-0000-4000-8000-000000000031', '00000000-0000-4000-8000-000000000104',
    'test', 'ref-test-payment', 12000, 'KES', now()
);
INSERT INTO finance.obligation_settlements (
    id, obligation_id, payment_id, currency, amount, settled_at, idempotency_key
) VALUES (
    '10000000-0000-4000-8000-000000000037', '10000000-0000-4000-8000-000000000035',
    '10000000-0000-4000-8000-000000000036', 'KES', 12000, now(), 'ref-test-settlement'
);
INSERT INTO finance.subscription_cycles (
    id, billing_account_id, subscriber_profile_id, entity_id, plan_id, active_subscription_id,
    annual_sequence, cycle_type, period_start, period_end, invoice_id, obligation_id,
    amount, currency, status, idempotency_key
) VALUES (
    '10000000-0000-4000-8000-000000000038', '10000000-0000-4000-8000-000000000030',
    '10000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000031',
    '10000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000033',
    1, 'initial_annual', current_date, current_date + 364,
    '10000000-0000-4000-8000-000000000034', '10000000-0000-4000-8000-000000000035',
    12000, 'KES', 'active', 'ref-test-cycle'
);
INSERT INTO finance.events (
    id, event_type, source_type, source_id, idempotency_key, payload
) VALUES (
    '10000000-0000-4000-8000-000000000039', 'finance.subscription.annual.activated',
    'finance.subscription_cycle', '10000000-0000-4000-8000-000000000038',
    'subscription-cycle-activated:ref-test',
    jsonb_build_object(
      'subscription_cycle_id','10000000-0000-4000-8000-000000000038',
      'subscriber_profile_id','10000000-0000-4000-8000-000000000011',
      'subscriber_entity_id','10000000-0000-4000-8000-000000000031',
      'plan_id','10000000-0000-4000-8000-000000000032',
      'billing_account_id','10000000-0000-4000-8000-000000000030',
      'invoice_id','10000000-0000-4000-8000-000000000034',
      'obligation_id','10000000-0000-4000-8000-000000000035',
      'settlement_id','10000000-0000-4000-8000-000000000037',
      'payment_id','10000000-0000-4000-8000-000000000036',
      'settled_at', now(), 'payment_verified_at', now(),
      'amount',12000,'currency','KES','annual_sequence',1,
      'cycle_type','initial_annual','period_start',current_date,'period_end',current_date+364
    )
);

DO $qualification$
DECLARE
    v_result record;
    v_retry record;
    v_reward_id uuid;
BEGIN
    SELECT * INTO v_result FROM referrals.consume_finance_event('10000000-0000-4000-8000-000000000039');
    IF v_result.outcome <> 'rewarded' OR v_result.reward_id IS NULL THEN
        RAISE EXCEPTION 'qualification failed: %', row_to_json(v_result);
    END IF;
    SELECT * INTO v_retry FROM referrals.consume_finance_event('10000000-0000-4000-8000-000000000039');
    IF v_retry.reward_id IS DISTINCT FROM v_result.reward_id THEN
        RAISE EXCEPTION 'duplicate event created a different reward';
    END IF;
    IF (SELECT count(*) FROM referrals.rewards WHERE referral_id = (
        SELECT id FROM referrals.referrals WHERE referred_profile_id='10000000-0000-4000-8000-000000000011')) <> 1 THEN
        RAISE EXCEPTION 'duplicate reward rows detected';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.rewards WHERE id=v_result.reward_id AND amount=40 AND currency='KES' AND status='eligible' AND accrual_journal_id IS NOT NULL) THEN
        RAISE EXCEPTION 'reward amount/status/journal linkage is incorrect';
    END IF;
END;
$qualification$;

-- Withdrawal threshold and lifecycle fixtures: add twelve more eligible rewards.
INSERT INTO users.profiles (id, first_name, country_id, is_active, account_status)
SELECT ('30000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       'Threshold User ' || g, '10000000-0000-4000-8000-000000000001', true, 'active'
FROM generate_series(1,12) g;
INSERT INTO referrals.referrals (id, referrer_profile_id, referred_profile_id, referral_code, attribution_method, status)
SELECT ('31000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       '10000000-0000-4000-8000-000000000010',
       ('30000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       'THRESH-' || g, 'code', 'qualified'
FROM generate_series(1,12) g;
INSERT INTO referrals.rewards (referral_id, beneficiary_profile_id, amount, currency, status, earned_at)
SELECT ('31000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       '10000000-0000-4000-8000-000000000010', 40, 'KES', 'eligible', now()
FROM generate_series(1,12) g;

DO $withdrawal$
DECLARE
    v_balance numeric;
    v_request record;
    v_request_id uuid;
    v_failed boolean := false;
BEGIN
    PERFORM set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000010', true);
    SELECT referrals.get_reward_balance() INTO v_balance;
    IF v_balance <> 520 THEN
        RAISE EXCEPTION 'expected 520 eligible balance, found %', v_balance;
    END IF;
    BEGIN
        SELECT * INTO v_request FROM referrals.request_withdrawal(480, 'withdraw-480');
        RAISE EXCEPTION 'expected KSh 480 minimum rejection';
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION 'KSh 480 was not rejected'; END IF;

    SELECT * INTO v_request FROM referrals.request_withdrawal(520, 'withdraw-520');
    v_request_id := v_request.withdrawal_request_id;
    IF v_request.status <> 'requested' THEN
        RAISE EXCEPTION 'expected requested withdrawal';
    END IF;
    IF referrals.get_reward_balance() <> 0 THEN
        RAISE EXCEPTION 'reserved rewards still count as eligible balance';
    END IF;
    BEGIN
        PERFORM referrals.request_withdrawal(520, 'withdraw-520-dup');
        RAISE EXCEPTION 'expected duplicate open withdrawal rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
    END;
END;
$withdrawal$;

DO $payout_recovery$
DECLARE
    v_request_id uuid;
    v_obligation uuid;
    v_reward_id uuid;
    v_recovery uuid;
BEGIN
    PERFORM set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000010',true);
    SELECT id INTO v_request_id FROM referrals.withdrawal_requests WHERE beneficiary_profile_id='10000000-0000-4000-8000-000000000010' AND status='requested' ORDER BY requested_at DESC LIMIT 1;
    v_obligation := referrals.approve_withdrawal(v_request_id, '10000000-0000-4000-8000-000000000020', 'test approval');
    IF v_obligation IS NULL THEN RAISE EXCEPTION 'payout obligation missing'; END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.withdrawal_requests
                    WHERE id=v_request_id
                      AND reviewed_by='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'withdrawal approval actor was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.withdrawal_events
                    WHERE withdrawal_request_id=v_request_id
                      AND event_type='withdrawal_approved'
                      AND actor_profile_id='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'withdrawal approval event actor was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.audit_events
                    WHERE entity_id=v_request_id AND event_type='withdrawal_approved'
                      AND actor_profile_id='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'withdrawal approval audit actor was not recorded';
    END IF;
    PERFORM referrals.record_manual_payout(v_request_id, 'MPESA-REF-TEST-1', '{"channel":"manual"}'::jsonb, now());
    IF NOT EXISTS (SELECT 1 FROM referrals.withdrawal_requests WHERE id=v_request_id AND status='paid') THEN
        RAISE EXCEPTION 'manual payout did not mark request paid';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.withdrawal_events
                    WHERE withdrawal_request_id=v_request_id
                      AND event_type='withdrawal_paid'
                      AND actor_profile_id='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'manual payout event actor was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.audit_events
                    WHERE entity_id=v_request_id AND event_type='withdrawal_paid'
                      AND actor_profile_id='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'manual payout audit actor was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.obligations WHERE id=v_obligation AND status='settled') THEN
        RAISE EXCEPTION 'payout obligation was not settled';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM finance.payments
         WHERE obligation_id=v_obligation AND provider='manual_mpesa'
           AND provider_reference='MPESA-REF-TEST-1' AND amount=520 AND currency='KES'
    ) THEN
        RAISE EXCEPTION 'payout payment was not linked';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM finance.obligation_settlements
         WHERE obligation_id=v_obligation AND amount=520 AND currency='KES'
           AND idempotency_key='referral-payout:' || v_request_id::text
    ) THEN
        RAISE EXCEPTION 'payout settlement was not linked';
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM finance.journals j
          JOIN finance.journal_lines l ON l.journal_id=j.id
         WHERE j.source_type='payment' AND j.source_id=(
           SELECT id FROM finance.payments WHERE obligation_id=v_obligation AND provider_reference='MPESA-REF-TEST-1')
           AND j.status='posted'
         GROUP BY j.id
        HAVING sum(l.debit_amount)=520 AND sum(l.credit_amount)=520
    ) THEN
        RAISE EXCEPTION 'payout journal is not balanced';
    END IF;
    BEGIN
        PERFORM referrals.record_manual_payout(v_request_id, 'MPESA-REF-TEST-1', '{"channel":"manual"}'::jsonb, now());
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'identical payout retry was not idempotent';
    END;
    IF NOT EXISTS (SELECT 1 FROM referrals.withdrawal_events
                    WHERE withdrawal_request_id=v_request_id
                      AND event_type='withdrawal_paid'
                      AND actor_profile_id='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'idempotent payout retry changed actor attribution';
    END IF;
    BEGIN
        PERFORM referrals.record_manual_payout(v_request_id, 'MPESA-REF-TEST-2', '{"channel":"manual"}'::jsonb, now());
        RAISE EXCEPTION 'second payout receipt was accepted';
    EXCEPTION WHEN SQLSTATE '23505' THEN
        NULL;
    END;
    SELECT id INTO v_reward_id FROM referrals.rewards WHERE withdrawal_request_id=v_request_id AND status='paid' LIMIT 1;
    v_recovery := referrals.record_recovery(v_reward_id, 'manual audit correction', 'recovery-ref-test-1');
    IF v_recovery IS NULL OR NOT EXISTS (SELECT 1 FROM referrals.rewards WHERE id=v_reward_id AND recovery_obligation_id=v_recovery AND withdrawal_blocked IS TRUE) THEN
        RAISE EXCEPTION 'recovery obligation/block not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.reward_events
                    WHERE reward_id=v_reward_id AND event_type='recovery_created'
                      AND actor_profile_id='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'recovery event actor was not recorded';
    END IF;
    PERFORM referrals.resolve_recovery(v_reward_id, 'cleared', 'review cleared');
    IF NOT EXISTS (SELECT 1 FROM referrals.reward_events
                    WHERE reward_id=v_reward_id AND event_type='recovery_cleared'
                      AND actor_profile_id='10000000-0000-4000-8000-000000000010') THEN
        RAISE EXCEPTION 'recovery resolution event actor was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.rewards WHERE id=v_reward_id AND withdrawal_blocked IS FALSE AND status='paid') THEN
        RAISE EXCEPTION 'recovery resolution did not clear block while preserving paid status';
    END IF;
END;
$payout_recovery$;

DO $security$
BEGIN
    IF has_function_privilege('authenticated', 'referrals.consume_finance_event(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated must not execute event consumer';
    END IF;
    IF has_function_privilege('anon', 'referrals.approve_withdrawal(uuid,uuid,text,uuid)', 'EXECUTE')
       OR has_function_privilege('public', 'referrals.approve_withdrawal(uuid,uuid,text,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'anon/PUBLIC must not execute withdrawal approval';
    END IF;
    IF has_function_privilege('anon', 'referrals.record_manual_payout(uuid,text,jsonb,timestamp with time zone,uuid)', 'EXECUTE')
       OR has_function_privilege('public', 'referrals.record_manual_payout(uuid,text,jsonb,timestamp with time zone,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'anon/PUBLIC must not execute payout recording';
    END IF;
    IF has_function_privilege('anon', 'referrals.record_recovery(uuid,text,text,uuid)', 'EXECUTE')
       OR has_function_privilege('public', 'referrals.record_recovery(uuid,text,text,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'anon/PUBLIC must not execute recovery';
    END IF;
    IF has_table_privilege('authenticated', 'referrals.rewards', 'INSERT') THEN
        RAISE EXCEPTION 'authenticated must not directly insert rewards';
    END IF;
END;
$security$;

ROLLBACK;

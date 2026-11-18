-- ============================================================================
-- referrals_concurrency_hardening_test.sql
-- LOCAL-ONLY concurrency checks using separate PostgreSQL sessions (dblink).
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

UPDATE referrals.program_settings SET foundation_activation_enabled=true;

-- Committed disposable fixture: platform referral accounts and accounting period.
SELECT finance.ensure_referral_accounts(
  '00000000-0000-4000-8000-000000000104', '2400', 'Concurrency Referral Payable');
INSERT INTO finance.accounting_periods (entity_id, start_date, end_date, status, created_by)
VALUES ('00000000-0000-4000-8000-000000000104', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date, 'open',
        '00000000-0000-4000-8000-000000000103');

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('40000000-0000-4000-8000-000000000001', 'Concurrency Referralland', 'ZZ', 'ZZZ', '999', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO users.profiles (id, auth_user_id, first_name, last_name, email, phone, country_id, is_active, account_status)
VALUES ('40000000-0000-4000-8000-000000000010', '50000000-0000-4000-8000-000000000010',
        'Concurrent', 'Referrer', 'conc-referrer@example.invalid', '+254722000010',
        '40000000-0000-4000-8000-000000000001', true, 'active')
ON CONFLICT (id) DO NOTHING;

-- Qualification fixture.
INSERT INTO users.profiles (id, first_name, last_name, email, phone, country_id, is_active, account_status)
VALUES ('40000000-0000-4000-8000-000000000011', 'Concurrent', 'Referred',
        'conc-referred@example.invalid', '+254722000011',
        '40000000-0000-4000-8000-000000000001', true, 'active')
ON CONFLICT (id) DO NOTHING;
INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, metadata)
VALUES ('40000000-0000-4000-8000-000000000021', 'Concurrent Referred Entity', 'individual_pro',
        '40000000-0000-4000-8000-000000000011', true, '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;
INSERT INTO system.billing_accounts (id, entity_id, profile_id, account_type, currency, status)
VALUES ('40000000-0000-4000-8000-000000000030', '40000000-0000-4000-8000-000000000021',
        '40000000-0000-4000-8000-000000000011', 'individual', 'KES', 'active')
ON CONFLICT (id) DO NOTHING;
INSERT INTO system.subscription_plans (id, plan_key, plan_name, billing_cycle, amount, currency, is_active)
VALUES ('40000000-0000-4000-8000-000000000032', 'conc-referral-yearly', 'Concurrency Referral Yearly', 'yearly', 12000, 'KES', true)
ON CONFLICT (id) DO NOTHING;
INSERT INTO system.active_subscriptions (id, billing_account_id, plan_id, status, start_date, end_date)
VALUES ('40000000-0000-4000-8000-000000000033', '40000000-0000-4000-8000-000000000030',
        '40000000-0000-4000-8000-000000000032', 'active', now(), now() + interval '1 year')
ON CONFLICT (id) DO NOTHING;
INSERT INTO system.invoices (id, billing_account_id, invoice_number, module_name, status, total_amount, currency, paid_at)
VALUES ('40000000-0000-4000-8000-000000000034', '40000000-0000-4000-8000-000000000030',
        'CONC-REF-001', 'subscription', 'paid', 12000, 'KES', now())
ON CONFLICT (id) DO NOTHING;
INSERT INTO finance.obligations (id, payer_entity_id, payee_entity_id, obligation_type, status, amount, currency, idempotency_key, metadata)
VALUES ('40000000-0000-4000-8000-000000000035', '40000000-0000-4000-8000-000000000021',
        '00000000-0000-4000-8000-000000000104', 'subscription', 'settled', 12000, 'KES',
        'conc-ref-obligation', '{"finance_charge_code":"subscription","tax_treatment":"not_applicable"}'::jsonb)
ON CONFLICT (id) DO NOTHING;
INSERT INTO finance.payments (id, obligation_id, payer_entity_id, payee_entity_id, provider, provider_reference, amount, currency, verified_at)
VALUES ('40000000-0000-4000-8000-000000000036', '40000000-0000-4000-8000-000000000035',
        '40000000-0000-4000-8000-000000000021', '00000000-0000-4000-8000-000000000104',
        'test', 'conc-ref-payment', 12000, 'KES', now())
ON CONFLICT (id) DO NOTHING;
INSERT INTO finance.obligation_settlements (id, obligation_id, payment_id, currency, amount, settled_at, idempotency_key)
VALUES ('40000000-0000-4000-8000-000000000037', '40000000-0000-4000-8000-000000000035',
        '40000000-0000-4000-8000-000000000036', 'KES', 12000, now(), 'conc-ref-settlement')
ON CONFLICT (id) DO NOTHING;
INSERT INTO finance.subscription_cycles (
    id, billing_account_id, subscriber_profile_id, entity_id, plan_id, active_subscription_id,
    annual_sequence, cycle_type, period_start, period_end, invoice_id, obligation_id,
    amount, currency, status, idempotency_key)
VALUES ('40000000-0000-4000-8000-000000000038', '40000000-0000-4000-8000-000000000030',
        '40000000-0000-4000-8000-000000000011', '40000000-0000-4000-8000-000000000021',
        '40000000-0000-4000-8000-000000000032', '40000000-0000-4000-8000-000000000033',
        1, 'initial_annual', current_date, current_date + 364,
        '40000000-0000-4000-8000-000000000034', '40000000-0000-4000-8000-000000000035',
        12000, 'KES', 'active', 'conc-ref-cycle')
ON CONFLICT (id) DO NOTHING;
INSERT INTO referrals.referrals (id, referrer_profile_id, referred_profile_id, referral_code, attribution_method, status)
VALUES ('40000000-0000-4000-8000-000000000040', '40000000-0000-4000-8000-000000000010',
        '40000000-0000-4000-8000-000000000011', 'CONC-REFERRAL', 'code', 'attributed')
ON CONFLICT (referred_profile_id) DO NOTHING;
INSERT INTO finance.events (id, event_type, source_type, source_id, idempotency_key, payload)
VALUES ('40000000-0000-4000-8000-000000000039', 'finance.subscription.annual.activated',
        'finance.subscription_cycle', '40000000-0000-4000-8000-000000000038',
        'conc-ref-event', jsonb_build_object(
          'subscription_cycle_id','40000000-0000-4000-8000-000000000038',
          'subscriber_profile_id','40000000-0000-4000-8000-000000000011',
          'subscriber_entity_id','40000000-0000-4000-8000-000000000021',
          'plan_id','40000000-0000-4000-8000-000000000032',
          'billing_account_id','40000000-0000-4000-8000-000000000030',
          'invoice_id','40000000-0000-4000-8000-000000000034',
          'obligation_id','40000000-0000-4000-8000-000000000035',
          'settlement_id','40000000-0000-4000-8000-000000000037',
          'payment_id','40000000-0000-4000-8000-000000000036',
          'settled_at', now(), 'payment_verified_at', now(),
          'amount',12000,'currency','KES','annual_sequence',1,
          'cycle_type','initial_annual','period_start',current_date,'period_end',current_date+364))
ON CONFLICT (id) DO NOTHING;

-- Twelve additional eligible rewards for the referrer, direct local fixtures for balance concurrency.
INSERT INTO users.profiles (id, first_name, country_id, is_active, account_status)
SELECT ('41000000-0000-4000-8000-' || lpad((g + 100)::text, 12, '0'))::uuid,
       'Concurrent Threshold ' || g, '40000000-0000-4000-8000-000000000001', true, 'active'
FROM generate_series(1,12) g
ON CONFLICT (id) DO NOTHING;
INSERT INTO referrals.referrals (id, referrer_profile_id, referred_profile_id, referral_code, attribution_method, status)
SELECT ('41000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       '40000000-0000-4000-8000-000000000010',
       ('41000000-0000-4000-8000-' || lpad((g + 100)::text, 12, '0'))::uuid,
       'CONC-THRESH-' || g, 'code', 'qualified'
FROM generate_series(1,12) g
ON CONFLICT (referred_profile_id) DO NOTHING;
INSERT INTO referrals.rewards (referral_id, beneficiary_profile_id, amount, currency, status, earned_at)
SELECT ('41000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       '40000000-0000-4000-8000-000000000010', 40, 'KES', 'eligible', now()
FROM generate_series(1,12) g
ON CONFLICT (referral_id) DO NOTHING;

COMMIT;

DO $connect$
DECLARE
    v_conn text;
BEGIN
    SELECT format('host=%s port=%s dbname=%s user=%s',
                  split_part(setting, ',', 1), current_setting('port'),
                  current_database(), current_user)
      INTO v_conn FROM pg_settings WHERE name = 'unix_socket_directories';
    PERFORM dblink_connect('ref_worker_1', v_conn);
    PERFORM dblink_connect('ref_worker_2', v_conn);
END;
$connect$;

-- Concurrent qualification of the same Finance event.
SELECT dblink_send_query('ref_worker_1', $SQL$SELECT * FROM referrals.consume_finance_event('40000000-0000-4000-8000-000000000039')$SQL$);
SELECT dblink_send_query('ref_worker_2', $SQL$SELECT * FROM referrals.consume_finance_event('40000000-0000-4000-8000-000000000039')$SQL$);
CREATE TEMP TABLE _conc_results (source text, finance_event_id uuid, outcome text, reward_id uuid, message text);
INSERT INTO _conc_results SELECT 'w1', * FROM dblink_get_result('ref_worker_1') AS t(finance_event_id uuid, outcome text, reward_id uuid, message text);
INSERT INTO _conc_results SELECT 'w2', * FROM dblink_get_result('ref_worker_2') AS t(finance_event_id uuid, outcome text, reward_id uuid, message text);
SELECT * FROM dblink_get_result('ref_worker_1') AS t(finance_event_id uuid, outcome text, reward_id uuid, message text);
SELECT * FROM dblink_get_result('ref_worker_2') AS t(finance_event_id uuid, outcome text, reward_id uuid, message text);

DO $assert_qual$
DECLARE
    v_reward_count bigint;
    v_distinct bigint;
BEGIN
    SELECT count(*), count(DISTINCT id) INTO v_reward_count, v_distinct
      FROM referrals.rewards WHERE referral_id = '40000000-0000-4000-8000-000000000040';
    IF v_reward_count <> 1 THEN
        RAISE EXCEPTION 'concurrent qualification created % rewards', v_reward_count;
    END IF;
    IF (SELECT count(DISTINCT id) FROM referrals.rewards WHERE referral_id = '40000000-0000-4000-8000-000000000040') <> 1 THEN
        RAISE EXCEPTION 'duplicate reward ids detected';
    END IF;
END;
$assert_qual$;

-- Concurrent withdrawal requests against the same eligible balance.
SELECT dblink_send_query('ref_worker_1', $SQL$DO $$ BEGIN PERFORM set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000010',true); PERFORM referrals.request_withdrawal(520, 'conc-withdrawal-a'); EXCEPTION WHEN OTHERS THEN NULL; END $$;$SQL$);
SELECT dblink_send_query('ref_worker_2', $SQL$DO $$ BEGIN PERFORM set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000010',true); PERFORM referrals.request_withdrawal(520, 'conc-withdrawal-b'); EXCEPTION WHEN OTHERS THEN NULL; END $$;$SQL$);
SELECT * FROM dblink_get_result('ref_worker_1') AS t(x text);
SELECT * FROM dblink_get_result('ref_worker_2') AS t(x text);

DO $assert_withdraw$
DECLARE
    v_requests bigint;
    v_reserved bigint;
    v_balance numeric;
BEGIN
    SELECT count(*) INTO v_requests FROM referrals.withdrawal_requests
     WHERE beneficiary_profile_id='40000000-0000-4000-8000-000000000010'
       AND status IN ('requested','approved','uncertain');
    IF v_requests <> 1 THEN
        RAISE EXCEPTION 'expected one open withdrawal, found %', v_requests;
    END IF;
    SELECT count(*) INTO v_reserved FROM referrals.withdrawal_items wi
      JOIN referrals.withdrawal_requests wr ON wr.id=wi.withdrawal_request_id
     WHERE wr.beneficiary_profile_id='40000000-0000-4000-8000-000000000010';
    IF v_reserved <> 13 THEN
        RAISE EXCEPTION 'expected 13 reserved rewards, found %', v_reserved;
    END IF;
    SELECT referrals.get_reward_balance() INTO v_balance
      FROM (SELECT set_config('request.jwt.claim.sub','50000000-0000-4000-8000-000000000010',true)) s;
    IF v_balance <> 0 THEN
        RAISE EXCEPTION 'concurrent withdrawal left eligible balance %', v_balance;
    END IF;
END;
$assert_withdraw$;

SELECT dblink_disconnect('ref_worker_1');
SELECT dblink_disconnect('ref_worker_2');

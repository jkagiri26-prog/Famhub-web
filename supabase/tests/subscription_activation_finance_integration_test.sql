-- ============================================================================
-- subscription_activation_finance_integration_test.sql
-- ----------------------------------------------------------------------------
-- LOCAL-ONLY integration test using the actual captured Finance functions:
--   finance.create_payment_attempt
--   finance.record_verified_payment
--   finance.post_journal
--   finance.settle_payment
--   finance.create_accounting_period
--   finance.complete_annual_subscription
--
-- PREREQUISITE
--   The local database must have the captured Finance schema applied with
--   primary-key/unique constraints ordered before dependent foreign keys.
--   The repo capture is a live snapshot and is not directly replay-safe in its
--   stored statement order.
--
-- This test commits its fixture because the two installments must receive
-- distinct transaction timestamps. Run only against a disposable local DB.
-- ============================================================================

CREATE TEMP TABLE _finance_int_fixture (
    plan_id uuid,
    billing_id uuid,
    subscriber_entity_id uuid,
    platform_entity_id uuid,
    full_cycle_id uuid,
    full_active_id uuid,
    full_invoice_id uuid,
    full_obligation_id uuid,
    partial_cycle_id uuid,
    partial_active_id uuid,
    partial_invoice_id uuid,
    partial_obligation_id uuid
) ON COMMIT PRESERVE ROWS;

CREATE OR REPLACE FUNCTION pg_temp.make_verified_payment(
    p_obligation_id uuid,
    p_payer_entity_id uuid,
    p_payee_entity_id uuid,
    p_amount numeric,
    p_suffix text
)
RETURNS uuid
LANGUAGE plpgsql
AS $function$
DECLARE
    v_attempt_id uuid;
    v_event_id uuid;
    v_payment_id uuid;
BEGIN
    v_attempt_id := finance.create_payment_attempt(
        p_obligation_id,
        'test',
        'other',
        p_amount,
        'attempt-' || p_suffix,
        NULL,
        '{}'::jsonb
    );

    INSERT INTO finance.provider_events (
        provider, provider_event_id, payment_attempt_id, event_type,
        signature_verified, payload
    ) VALUES (
        'test', 'event-' || p_suffix, v_attempt_id, 'test_verified',
        true, '{}'::jsonb
    ) RETURNING id INTO v_event_id;

    v_payment_id := finance.record_verified_payment(
        v_attempt_id,
        v_event_id,
        'receipt-' || p_suffix,
        p_amount,
        'KES',
        '{}'::jsonb
    );

    RETURN v_payment_id;
END;
$function$;

CREATE OR REPLACE FUNCTION pg_temp.make_payment_journal(
    p_payment_id uuid,
    p_entity_id uuid,
    p_amount numeric,
    p_suffix text
)
RETURNS uuid
LANGUAGE plpgsql
AS $function$
DECLARE
    v_debit_account uuid;
    v_credit_account uuid;
    v_journal_id uuid;
BEGIN
    SELECT id INTO STRICT v_debit_account
      FROM finance.ledger_accounts
     WHERE entity_id = p_entity_id AND account_code = '1000' AND is_active IS TRUE;

    SELECT id INTO STRICT v_credit_account
      FROM finance.ledger_accounts
     WHERE entity_id = p_entity_id AND account_code = '4200' AND is_active IS TRUE;

    INSERT INTO finance.journals (
        entity_id, journal_date, currency, status, description,
        source_type, source_id, idempotency_key
    ) VALUES (
        p_entity_id, current_date, 'KES', 'draft', 'Integration payment ' || p_suffix,
        'payment', p_payment_id, 'journal-' || p_suffix
    ) RETURNING id INTO v_journal_id;

    INSERT INTO finance.journal_lines (
        journal_id, entity_id, currency, line_number, account_id,
        debit_amount, credit_amount, description
    ) VALUES
      (v_journal_id, p_entity_id, 'KES', 1, v_debit_account,
       p_amount, 0, 'Payment received'),
      (v_journal_id, p_entity_id, 'KES', 2, v_credit_account,
       0, p_amount, 'Subscription revenue');

    PERFORM finance.post_journal(v_journal_id);
    RETURN v_journal_id;
END;
$function$;

DO $setup$
DECLARE
    v_country_id uuid := gen_random_uuid();
    v_subscriber_id uuid := gen_random_uuid();
    v_platform_owner_id uuid := gen_random_uuid();
    v_platform_owner_auth_id uuid := gen_random_uuid();
    v_subscriber_entity_id uuid := gen_random_uuid();
    v_platform_entity_id uuid := gen_random_uuid();
    v_billing_id uuid := gen_random_uuid();
    v_plan_id uuid;
    v_cycle_id uuid;
    v_active_id uuid;
    v_invoice_id uuid;
    v_obligation_id uuid;
    v_payment_id uuid;
    v_journal_id uuid;
    v_settlement_id uuid;
    v_suffix text := replace(clock_timestamp()::text, ' ', '');
    v_result record;
    v_count bigint;
BEGIN
    INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
    VALUES (v_country_id, 'Finance Integration Testland', 'KE', 'KEN', '254');

    INSERT INTO users.profiles(id, auth_user_id, first_name, country_id, is_active, account_status)
    VALUES
      (v_subscriber_id, gen_random_uuid(), 'Finance Subscriber', v_country_id, true, 'active'),
      (v_platform_owner_id, v_platform_owner_auth_id, 'Platform Finance Owner', v_country_id, true, 'active');

    INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata) VALUES
      (v_subscriber_entity_id, 'Finance Subscriber Entity', 'individual_pro', v_subscriber_id, true, '{}'::jsonb),
      (v_platform_entity_id, 'Finance Platform Administration', 'trading_company', v_platform_owner_id, true,
       '{"platform_entity":"true","purpose":"platform_administration"}'::jsonb);

    INSERT INTO core.entity_members(entity_id, profile_id, role_id, is_active, membership_status, can_manage)
    VALUES (
      v_platform_entity_id, v_platform_owner_id,
      (SELECT id FROM core.user_roles WHERE lower(name) = 'owner' AND type = 'system' AND is_active ORDER BY id LIMIT 1),
      true, 'active', true
    );

    INSERT INTO system.billing_accounts(id, entity_id, profile_id, account_type, status, currency)
    VALUES (v_billing_id, v_subscriber_entity_id, v_subscriber_id, 'individual', 'active', 'KES');

    SELECT plan_id INTO v_plan_id
      FROM system.create_annual_subscription_plan(
        'finance-int-plan-' || v_suffix,
        'Finance Integration Annual',
        12000,
        NULL,
        '{}'::jsonb
      );

    INSERT INTO finance.ledger_accounts (
        entity_id, account_code, account_name, account_type,
        normal_balance, currency, is_active
    ) VALUES
      (v_platform_entity_id, '1000', 'Integration Clearing', 'asset', 'debit', 'KES', true),
      (v_platform_entity_id, '4200', 'Integration Subscription Revenue', 'revenue', 'credit', 'KES', true)
    ON CONFLICT (entity_id, account_code) DO NOTHING;

    -- Open a disposable accounting period through the actual Finance function.
    PERFORM set_config('request.jwt.claim.sub', v_platform_owner_auth_id::text, true);
    PERFORM finance.create_accounting_period(
        v_platform_entity_id,
        date_trunc('month', current_date)::date,
        (date_trunc('month', current_date) + interval '1 month - 1 day')::date
    );
    PERFORM set_config('request.jwt.claim.sub', '', true);

    -- ------------------------------------------------------------------
    -- Full settlement path.
    -- ------------------------------------------------------------------
    SELECT f.subscription_cycle_id, f.active_subscription_id, f.invoice_id, f.obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM finance.create_annual_subscription(
        v_billing_id, v_plan_id, 'FIN-INT-FULL-' || v_suffix,
        'finance-int-full-' || v_suffix, NULL, NULL
      ) AS f;

    v_payment_id := pg_temp.make_verified_payment(
        v_obligation_id, v_subscriber_entity_id, v_platform_entity_id,
        12000, v_suffix || '-full'
    );
    v_journal_id := pg_temp.make_payment_journal(
        v_payment_id, v_platform_entity_id, 12000, v_suffix || '-full'
    );
    v_settlement_id := finance.settle_payment(
        v_payment_id, 12000, 'settle-' || v_suffix || '-full', v_journal_id
    );

    SELECT count(*) INTO v_count FROM finance.journals;
    SELECT * INTO v_result
      FROM finance.complete_annual_subscription(v_cycle_id, v_obligation_id);

    IF v_result.status <> 'active' THEN
        RAISE EXCEPTION 'full settlement activation failed';
    END IF;
    IF (SELECT count(*) FROM finance.journals) <> v_count THEN
        RAISE EXCEPTION 'activation created a Finance journal';
    END IF;

    INSERT INTO _finance_int_fixture (
        plan_id, billing_id, subscriber_entity_id, platform_entity_id,
        full_cycle_id, full_active_id, full_invoice_id, full_obligation_id,
        partial_cycle_id, partial_active_id, partial_invoice_id, partial_obligation_id
    ) VALUES (
        v_plan_id, v_billing_id, v_subscriber_entity_id, v_platform_entity_id,
        v_cycle_id, v_active_id, v_invoice_id, v_obligation_id,
        NULL, NULL, NULL, NULL
    );

    -- ------------------------------------------------------------------
    -- Partial installment one: 5000/12000.
    -- ------------------------------------------------------------------
    SELECT f.subscription_cycle_id, f.active_subscription_id, f.invoice_id, f.obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM finance.create_annual_subscription(
        v_billing_id, v_plan_id, 'FIN-INT-PART-' || v_suffix,
        'finance-int-part-' || v_suffix, NULL, NULL
      ) AS f;

    v_payment_id := pg_temp.make_verified_payment(
        v_obligation_id, v_subscriber_entity_id, v_platform_entity_id,
        5000, v_suffix || '-part1'
    );
    v_journal_id := pg_temp.make_payment_journal(
        v_payment_id, v_platform_entity_id, 5000, v_suffix || '-part1'
    );
    PERFORM finance.settle_payment(
        v_payment_id, 5000, 'settle-' || v_suffix || '-part1', v_journal_id
    );

    UPDATE _finance_int_fixture
       SET partial_cycle_id = v_cycle_id,
           partial_active_id = v_active_id,
           partial_invoice_id = v_invoice_id,
           partial_obligation_id = v_obligation_id;
END;
$setup$;

COMMIT;

DO $partial$
DECLARE
    v_fix _finance_int_fixture%ROWTYPE;
    v_payment_id uuid;
    v_journal_id uuid;
    v_result record;
    v_settled_at timestamptz;
    v_count bigint;
    v_rejected boolean := false;
BEGIN
    SELECT * INTO v_fix FROM _finance_int_fixture;

    BEGIN
        PERFORM finance.complete_annual_subscription(v_fix.partial_cycle_id);
    EXCEPTION WHEN SQLSTATE '55000' THEN
        v_rejected := true;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'partial settlement was incorrectly accepted';
    END IF;

    -- Second installment: 7000/12000, in a later transaction so settled_at differs.
    v_payment_id := pg_temp.make_verified_payment(
        v_fix.partial_obligation_id, v_fix.subscriber_entity_id,
        v_fix.platform_entity_id, 7000, 'part2-' || v_fix.partial_cycle_id::text
    );
    v_journal_id := pg_temp.make_payment_journal(
        v_payment_id, v_fix.platform_entity_id, 7000,
        'part2-' || v_fix.partial_cycle_id::text
    );
    PERFORM finance.settle_payment(
        v_payment_id, 7000,
        'settle-part2-' || v_fix.partial_cycle_id::text, v_journal_id
    );

    SELECT settled_at INTO v_settled_at
      FROM finance.obligation_settlements
     WHERE obligation_id = v_fix.partial_obligation_id
     ORDER BY settled_at DESC, id DESC
     LIMIT 1;

    SELECT count(*) INTO v_count FROM finance.journals;

    SELECT * INTO v_result
      FROM finance.complete_annual_subscription(v_fix.partial_cycle_id);

    IF v_result.status <> 'active' THEN
        RAISE EXCEPTION 'full second installment did not activate';
    END IF;
    IF v_result.settled_at IS DISTINCT FROM v_settled_at THEN
        RAISE EXCEPTION 'activation did not select the final settlement timestamp';
    END IF;
    IF (SELECT count(*) FROM finance.journals) <> v_count THEN
        RAISE EXCEPTION 'activation created a Finance journal';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM system.invoices
         WHERE id = v_fix.partial_invoice_id
           AND status = 'paid'
           AND paid_at = v_settled_at
    ) THEN
        RAISE EXCEPTION 'partial invoice was not paid with the final settlement timestamp';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM system.active_subscriptions
         WHERE id = v_fix.partial_active_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'partial subscription was not activated';
    END IF;

    SELECT count(*) INTO v_count
      FROM finance.events
     WHERE idempotency_key = 'subscription-cycle-activated:' || v_fix.partial_cycle_id::text;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one partial activation event, found %', v_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM system.invoices
         WHERE id = v_fix.full_invoice_id
           AND status = 'paid'
    ) THEN
        RAISE EXCEPTION 'full invoice was not paid';
    END IF;

    SELECT count(*) INTO v_count
      FROM finance.events
     WHERE idempotency_key = 'subscription-cycle-activated:' || v_fix.full_cycle_id::text;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one full activation event, found %', v_count;
    END IF;
END;
$partial$;

COMMIT;

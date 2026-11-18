-- ============================================================================
-- annual_subscription_purchase_test.sql
-- ----------------------------------------------------------------------------
-- Local-only checks for annual personal plan creation and purchase:
--   * invoice + invoice item + Finance obligation + permanent cycle
--   * pending access row, not activated
--   * idempotency
--   * early renewal and late renewal period rules
--   * no accounting period opened, no journal posted
--
-- Run after applying migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000004001', 'Testland', 'KE', 'KEN', '254');

INSERT INTO users.profiles(id, first_name, country_id) VALUES
  ('00000000-0000-0000-0000-000000004002', 'Subscriber One', '00000000-0000-0000-0000-000000004001'),
  ('00000000-0000-0000-0000-000000004003', 'Subscriber Two', '00000000-0000-0000-0000-000000004001'),
  ('00000000-0000-0000-0000-000000004004', 'Platform Owner', '00000000-0000-0000-0000-000000004001'),
  ('00000000-0000-0000-0000-000000004011', 'USD Subscriber', '00000000-0000-0000-0000-000000004001'),
  ('00000000-0000-0000-0000-000000004014', 'Business Subscriber', '00000000-0000-0000-0000-000000004001');

INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata) VALUES
  ('00000000-0000-0000-0000-000000004005', 'Subscriber One Entity', 'individual_pro', '00000000-0000-0000-0000-000000004002', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000004006', 'Subscriber Two Entity', 'individual_pro', '00000000-0000-0000-0000-000000004003', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000004007', 'Platform Administration Test', 'trading_company', '00000000-0000-0000-0000-000000004004', true, '{"platform_entity":"true","purpose":"platform_administration"}'::jsonb),
  ('00000000-0000-0000-0000-000000004012', 'USD Subscriber Entity', 'individual_pro', '00000000-0000-0000-0000-000000004011', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000004015', 'Business Subscriber Entity', 'individual_pro', '00000000-0000-0000-0000-000000004014', true, '{}'::jsonb);

INSERT INTO system.billing_accounts(id, entity_id, profile_id, account_type, status, currency) VALUES
  ('00000000-0000-0000-0000-000000004008', '00000000-0000-0000-0000-000000004005', '00000000-0000-0000-0000-000000004002', 'individual', 'active', 'KES'),
  ('00000000-0000-0000-0000-000000004009', '00000000-0000-0000-0000-000000004006', '00000000-0000-0000-0000-000000004003', 'individual', 'active', 'KES'),
  ('00000000-0000-0000-0000-000000004016', '00000000-0000-0000-0000-000000004015', '00000000-0000-0000-0000-000000004014', 'business', 'active', 'KES'),
  ('00000000-0000-0000-0000-000000004013', '00000000-0000-0000-0000-000000004012', '00000000-0000-0000-0000-000000004011', 'individual', 'active', 'USD');

DO $test$
DECLARE
    v_plan_id uuid;
    v_cycle_id uuid;
    v_active_id uuid;
    v_invoice_id uuid;
    v_obligation_id uuid;
    v_sequence integer;
    v_cycle_type text;
    v_period_start date;
    v_period_end date;
    v_retry_cycle_id uuid;
    v_renewal_cycle_id uuid;
    v_renewal_start date;
    v_after_retry_count bigint;
    v_period_count bigint;
    v_journal_count bigint;
BEGIN
    SELECT plan_id INTO v_plan_id
      FROM system.create_annual_subscription_plan(
        'annual-personal-test',
        'Annual Personal Test',
        12000,
        NULL,
        '{}'::jsonb
      );

    SELECT subscription_cycle_id, active_subscription_id, invoice_id, obligation_id,
           annual_sequence, cycle_type, period_start, period_end
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id,
           v_sequence, v_cycle_type, v_period_start, v_period_end
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000004008',
        v_plan_id,
        'TEST-INV-ANNUAL-1',
        'purchase-idem-1',
        NULL,
        now()
      );

    IF v_sequence <> 1 OR v_cycle_type <> 'initial_annual' THEN
        RAISE EXCEPTION 'expected initial annual cycle, found %/%', v_sequence, v_cycle_type;
    END IF;
    IF v_period_end <> (v_period_start + interval '1 year' - interval '1 day')::date THEN
        RAISE EXCEPTION 'initial period length is incorrect';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM system.active_subscriptions
         WHERE id = v_active_id
           AND status = 'pending'
           AND start_date = v_period_start::timestamp AT TIME ZONE 'Africa/Nairobi'
           AND end_date = (v_period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'
    ) THEN
        RAISE EXCEPTION 'pending active subscription row is missing or has incorrect Africa/Nairobi boundaries';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM system.invoices
         WHERE id = v_invoice_id
           AND invoice_number = 'TEST-INV-ANNUAL-1'
           AND status = 'pending'
           AND total_amount = 12000
           AND currency = 'KES'
    ) THEN
        RAISE EXCEPTION 'invoice was not created as expected';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM system.invoice_items
         WHERE invoice_id = v_invoice_id
           AND item_type = 'subscription'
           AND total_amount = 12000
    ) THEN
        RAISE EXCEPTION 'invoice item is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM finance.obligations
         WHERE id = v_obligation_id
           AND obligation_type = 'subscription'
           AND amount = 12000
           AND currency = 'KES'
           AND metadata->>'finance_charge_code' = 'subscription'
           AND metadata->>'tax_treatment' = 'not_applicable'
           AND metadata->>'subscription_cycle_id' = v_cycle_id::text
    ) THEN
        RAISE EXCEPTION 'Finance obligation metadata is incorrect';
    END IF;

    -- Idempotent retry returns the same cycle and does not duplicate rows.
    SELECT subscription_cycle_id INTO v_retry_cycle_id
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000004008',
        v_plan_id,
        'TEST-INV-ANNUAL-1',
        'purchase-idem-1',
        NULL,
        now()
      );

    IF v_retry_cycle_id <> v_cycle_id THEN
        RAISE EXCEPTION 'idempotent retry returned a different cycle';
    END IF;

    SELECT count(*) INTO v_after_retry_count
      FROM finance.subscription_cycles
     WHERE billing_account_id = '00000000-0000-0000-0000-000000004008';
    IF v_after_retry_count <> 1 THEN
        RAISE EXCEPTION 'idempotent retry created duplicate cycles';
    END IF;

    -- Idempotency key reuse with different invoice must fail.
    BEGIN
        PERFORM finance.create_annual_subscription(
            '00000000-0000-0000-0000-000000004008',
            v_plan_id,
            'TEST-INV-ANNUAL-OTHER',
            'purchase-idem-1',
            NULL,
            now()
        );
        RAISE EXCEPTION 'expected idempotency-key conflict';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    -- Early renewal starts the day after the current period end.
    SELECT subscription_cycle_id, period_start
      INTO v_renewal_cycle_id, v_renewal_start
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000004008',
        v_plan_id,
        'TEST-INV-ANNUAL-2',
        'purchase-idem-2',
        NULL,
        now()
      );

    IF v_renewal_start <> v_period_end + 1 THEN
        RAISE EXCEPTION 'early renewal start was %, expected %', v_renewal_start, v_period_end + 1;
    END IF;

    -- Late renewal: force a past previous period for subscriber two.
    SELECT subscription_cycle_id INTO v_cycle_id
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000004009',
        v_plan_id,
        'TEST-INV-ANNUAL-3',
        'purchase-idem-3',
        NULL,
        now()
      );

    UPDATE finance.subscription_cycles
       SET period_start = current_date - 400,
           period_end = current_date - 35
     WHERE id = v_cycle_id;

    SELECT period_start INTO v_renewal_start
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000004009',
        v_plan_id,
        'TEST-INV-ANNUAL-4',
        'purchase-idem-4',
        NULL,
        now()
      );

    IF v_renewal_start <> current_date THEN
        RAISE EXCEPTION 'late renewal start was %, expected %', v_renewal_start, current_date;
    END IF;

    -- Business billing account must be rejected.
    BEGIN
        PERFORM finance.create_annual_subscription(
            '00000000-0000-0000-0000-000000004016',
            v_plan_id,
            'TEST-INV-BUSINESS',
            'purchase-idem-business',
            NULL,
            now()
        );
        RAISE EXCEPTION 'expected personal-only rejection';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;

    -- Non-KES individual billing account must be rejected.
    BEGIN
        PERFORM finance.create_annual_subscription(
            '00000000-0000-0000-0000-000000004013',
            v_plan_id,
            'TEST-INV-USD',
            'purchase-idem-usd',
            NULL,
            now()
        );
        RAISE EXCEPTION 'expected KES-only rejection';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;

    -- No accounting period or journal may be created by this flow.
    SELECT count(*) INTO v_period_count FROM finance.accounting_periods;
    IF v_period_count <> 0 THEN
        RAISE EXCEPTION 'subscription purchase opened an accounting period';
    END IF;

    SELECT count(*) INTO v_journal_count FROM finance.journals;
    IF v_journal_count <> 0 THEN
        RAISE EXCEPTION 'subscription purchase posted a journal';
    END IF;
END;
$test$;

ROLLBACK;

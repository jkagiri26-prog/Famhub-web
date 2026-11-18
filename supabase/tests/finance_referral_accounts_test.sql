-- ============================================================================
-- finance_referral_accounts_test.sql
-- ----------------------------------------------------------------------------
-- Local-only checks for the controlled Refer & Earn Finance account setup.
--
-- Run after applying migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000003001', 'Testland', 'KE', 'KEN', '254');

INSERT INTO users.profiles(id, first_name, country_id)
VALUES (
  '00000000-0000-0000-0000-000000003002',
  'Finance Tester',
  '00000000-0000-0000-0000-000000003001'
);

INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata)
VALUES (
  '00000000-0000-0000-0000-000000003003',
  'Platform Administration Test',
  'trading_company',
  '00000000-0000-0000-0000-000000003002',
  true,
  '{"platform_entity":"true","purpose":"platform_administration"}'::jsonb
);

DO $test$
DECLARE
    v_expense_id uuid;
    v_payable_id uuid;
    v_period_count bigint;
BEGIN
    SELECT expense_account_id, payable_account_id
      INTO v_expense_id, v_payable_id
      FROM finance.ensure_referral_accounts(
        '00000000-0000-0000-0000-000000003003',
        'TEST-REF-PAYABLE',
        'Test Referral Rewards Payable'
      );

    IF v_expense_id IS NULL OR v_payable_id IS NULL THEN
        RAISE EXCEPTION 'account setup did not return both account ids';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM finance.ledger_accounts
         WHERE id = v_expense_id
           AND entity_id = '00000000-0000-0000-0000-000000003003'
           AND account_code = '5200'
           AND account_type = 'expense'
           AND normal_balance = 'debit'
           AND currency = 'KES'
           AND is_active IS TRUE
    ) THEN
        RAISE EXCEPTION '5200 account was not created/validated as expected';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM finance.ledger_accounts
         WHERE id = v_payable_id
           AND entity_id = '00000000-0000-0000-0000-000000003003'
           AND account_code = 'TEST-REF-PAYABLE'
           AND account_type = 'liability'
           AND normal_balance = 'credit'
           AND currency = 'KES'
           AND is_active IS TRUE
    ) THEN
        RAISE EXCEPTION 'payable account was not created/validated as expected';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM finance.referral_account_settings
         WHERE platform_entity_id = '00000000-0000-0000-0000-000000003003'
           AND expense_account_id = v_expense_id
           AND payable_account_id = v_payable_id
           AND currency = 'KES'
    ) THEN
        RAISE EXCEPTION 'referral account mapping is missing';
    END IF;

    SELECT count(*) INTO v_period_count
      FROM finance.accounting_periods
     WHERE entity_id = '00000000-0000-0000-0000-000000003003';
    IF v_period_count <> 0 THEN
        RAISE EXCEPTION 'account setup must not open accounting periods';
    END IF;

    -- Idempotent second call.
    PERFORM finance.ensure_referral_accounts(
        '00000000-0000-0000-0000-000000003003',
        'TEST-REF-PAYABLE',
        'Test Referral Rewards Payable'
    );
END;
$test$;

-- A wrong-type account code must fail.
INSERT INTO finance.ledger_accounts(
    entity_id, account_code, account_name, account_type,
    normal_balance, currency, is_active
) VALUES (
    '00000000-0000-0000-0000-000000003003',
    'TEST-COLLISION',
    'Wrong Type Account',
    'asset',
    'debit',
    'KES',
    true
);

DO $test$
BEGIN
    BEGIN
        PERFORM finance.ensure_referral_accounts(
            '00000000-0000-0000-0000-000000003003',
            'TEST-COLLISION',
            'Wrong Type Account'
        );
        RAISE EXCEPTION 'expected wrong-type account failure';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;
END;
$test$;

ROLLBACK;

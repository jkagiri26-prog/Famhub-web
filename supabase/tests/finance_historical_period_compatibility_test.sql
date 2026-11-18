-- ============================================================================
-- finance_historical_period_compatibility_test.sql
-- LOCAL-ONLY compatibility check for non-monthly historical periods.
--
-- This test DOES NOT move a row across a real migration boundary. It drops the
-- NOT VALID constraints inside a transaction, inserts a legacy row, re-adds the
-- constraints NOT VALID, and verifies that the reporting views exclude the row
-- without reclassifying it. A true boundary test would require a disposable
-- database at the pre-00001 migration state, which is not available in this
-- local fixture.
-- ============================================================================
BEGIN;

ALTER TABLE finance.accounting_periods DROP CONSTRAINT IF EXISTS accounting_periods_month_start_check;
ALTER TABLE finance.accounting_periods DROP CONSTRAINT IF EXISTS accounting_periods_month_end_check;
ALTER TABLE finance.accounting_periods DROP CONSTRAINT IF EXISTS accounting_periods_same_month_check;

INSERT INTO finance.accounting_periods (entity_id, start_date, end_date, status, created_by)
VALUES ('00000000-0000-4000-8000-000000000104','2025-06-01','2025-06-15','open',
        '00000000-0000-4000-8000-000000000103');

INSERT INTO finance.ledger_accounts (entity_id, account_code, account_name, account_type, normal_balance, currency, is_active)
VALUES
 ('00000000-0000-4000-8000-000000000104','9940','Legacy Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9941','Legacy Revenue','revenue','credit','KES',true)
ON CONFLICT (entity_id, account_code) DO NOTHING;

ALTER TABLE finance.accounting_periods
    ADD CONSTRAINT accounting_periods_month_start_check
    CHECK (start_date = date_trunc('month', start_date)::date) NOT VALID;
ALTER TABLE finance.accounting_periods
    ADD CONSTRAINT accounting_periods_month_end_check
    CHECK (end_date = (date_trunc('month', end_date) + interval '1 month - 1 day')::date) NOT VALID;
ALTER TABLE finance.accounting_periods
    ADD CONSTRAINT accounting_periods_same_month_check
    CHECK (date_trunc('month', start_date) = date_trunc('month', end_date)) NOT VALID;

DO $test$
DECLARE
    v_legacy uuid;
    v_journal uuid;
BEGIN
    SELECT id INTO v_legacy
      FROM finance.accounting_periods
     WHERE entity_id='00000000-0000-4000-8000-000000000104'
       AND start_date='2025-06-01' AND end_date='2025-06-15';
    IF v_legacy IS NULL THEN RAISE EXCEPTION 'legacy period was not preserved'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM finance.accounting_periods
         WHERE id=v_legacy AND start_date='2025-06-01' AND end_date='2025-06-15'
    ) THEN
        RAISE EXCEPTION 'legacy period dates were silently reclassified';
    END IF;

    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2025-06-05','KES','draft','Legacy period test','test',gen_random_uuid(),'legacy-period-journal')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,50,0,'Legacy debit'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9940';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,50,'Legacy credit'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9941';
    PERFORM finance.post_journal(v_journal);

    IF EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_legacy) THEN
        RAISE EXCEPTION 'legacy non-monthly period leaked into monthly P&L';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE period_id=v_legacy) THEN
        RAISE EXCEPTION 'legacy non-monthly period leaked into monthly trial balance';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_legacy) THEN
        RAISE EXCEPTION 'legacy non-monthly period leaked into monthly balance sheet';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000104' AND financial_year=2025) THEN
        RAISE EXCEPTION 'legacy non-monthly period leaked into financial-year summary';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid='finance.accounting_periods'::regclass
           AND conname IN ('accounting_periods_month_start_check','accounting_periods_month_end_check','accounting_periods_same_month_check')
           AND convalidated
    ) THEN
        RAISE EXCEPTION 'monthly constraints were unexpectedly validated';
    END IF;
END;
$test$;

ROLLBACK;

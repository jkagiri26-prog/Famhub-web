-- ============================================================================
-- finance_monthly_accounting_policy_test.sql
-- LOCAL-ONLY monthly period, closing and reporting tests.
-- ============================================================================
BEGIN;

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active)
VALUES ('00000000-0000-4000-8000-000000000105', 'Monthly Test Entity B', 'trading_company',
        '00000000-0000-4000-8000-000000000103', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO finance.ledger_accounts (entity_id, account_code, account_name, account_type, normal_balance, currency, is_active)
VALUES
 ('00000000-0000-4000-8000-000000000104','9900','Monthly Test Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9901','Monthly Test Revenue','revenue','credit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9902','Monthly Test Expense','expense','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9910','Monthly USD Asset','asset','debit','USD',true),
 ('00000000-0000-4000-8000-000000000104','9911','Monthly USD Revenue','revenue','credit','USD',true),
 ('00000000-0000-4000-8000-000000000104','9920','Unbalanced Test Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9921','Unbalanced Test Revenue','revenue','credit','KES',true),
 ('00000000-0000-4000-8000-000000000105','9930','Entity B Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000105','9931','Entity B Revenue','revenue','credit','KES',true)
ON CONFLICT (entity_id, account_code) DO NOTHING;

DO $test$
DECLARE
    v_nov uuid;
    v_dec uuid;
    v_105_nov uuid;
    v_leap uuid;
    v_2027 uuid;
    v_exp uuid;
    v_later uuid;
    v_rejected boolean;
    v_journal uuid;
    v_unbalanced uuid;
BEGIN
    UPDATE users.profiles SET auth_user_id='20000000-0000-4000-8000-000000000103'
     WHERE id='00000000-0000-4000-8000-000000000103';
    PERFORM set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000103',true);

    v_nov := finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2026-11-01','2026-11-30');
    v_dec := finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2026-12-01','2026-12-31');
    v_105_nov := finance.create_accounting_period('00000000-0000-4000-8000-000000000105','2026-11-01','2026-11-30');
    IF v_nov IS NULL OR v_dec IS NULL OR v_105_nov IS NULL THEN RAISE EXCEPTION 'monthly periods not created'; END IF;

    v_rejected := false;
    BEGIN
        PERFORM finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2026-11-02','2026-11-30');
    EXCEPTION WHEN SQLSTATE '22023' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'non-month-start period accepted'; END IF;

    v_rejected := false;
    BEGIN
        PERFORM finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2026-01-01','2026-02-01');
    EXCEPTION WHEN SQLSTATE '22023' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'cross-month period accepted'; END IF;

    v_rejected := false;
    BEGIN
        PERFORM finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2026-11-01','2026-11-30');
    EXCEPTION WHEN SQLSTATE '23P01' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'duplicate/overlapping month accepted'; END IF;

    -- Leap-year February must accept the real month end and reject invalid
    -- February boundaries (including a non-leap-style end date).
    v_leap := finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2028-02-01','2028-02-29');
    IF v_leap IS NULL THEN RAISE EXCEPTION '2028 leap-year February period not created'; END IF;

    v_rejected := false;
    BEGIN
        PERFORM finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2028-02-01','2028-02-28');
    EXCEPTION WHEN SQLSTATE '22023' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'invalid February 2028 end date accepted'; END IF;

    v_rejected := false;
    BEGIN
        PERFORM finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2028-02-01','2028-03-01');
    EXCEPTION WHEN SQLSTATE '22023' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'February-to-March period accepted'; END IF;

    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2026-11-15','KES','draft','Monthly test','test',gen_random_uuid(),'monthly-policy-journal')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,100,0,'Debit asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9900';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,100,'Credit revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9901';
    PERFORM finance.post_journal(v_journal);

    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2026-11-16','KES','draft','Monthly expense','test',gen_random_uuid(),'monthly-policy-expense')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,40,0,'Debit expense'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9902';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,40,'Credit asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9900';
    PERFORM finance.post_journal(v_journal);

    -- Independent currency journal: USD must never be added to KES.
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2026-11-17','USD','draft','Monthly USD test','test',gen_random_uuid(),'monthly-policy-usd')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','USD',1,id,250,0,'Debit USD asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9910';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','USD',2,id,0,250,'Credit USD revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9911';
    PERFORM finance.post_journal(v_journal);

    -- Entity B journal proves entity isolation in all four reporting views.
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000105','2026-11-18','KES','draft','Entity B test','test',gen_random_uuid(),'monthly-policy-entity-b')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000105','KES',1,id,75,0,'Debit entity B asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000105' AND account_code='9930';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000105','KES',2,id,0,75,'Credit entity B revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000105' AND account_code='9931';
    PERFORM finance.post_journal(v_journal);

    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_nov AND account_code='9901' AND net_amount=100 AND currency='KES') THEN
        RAISE EXCEPTION 'monthly P&L does not show KES revenue 100';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_nov AND account_code='9902' AND net_amount=40 AND currency='KES') THEN
        RAISE EXCEPTION 'monthly P&L does not show KES expense 40';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_nov AND account_code='9911' AND net_amount=250 AND currency='USD') THEN
        RAISE EXCEPTION 'monthly P&L does not keep USD revenue isolated';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_nov AND account_code='9931') THEN
        RAISE EXCEPTION 'P&L leaked entity B activity';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE period_id=v_nov AND account_code='9900' AND total_debits=100 AND total_credits=40 AND debit_balance=60 AND currency='KES') THEN
        RAISE EXCEPTION 'monthly KES trial balance mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE period_id=v_nov AND account_code='9911' AND total_debits=0 AND total_credits=250 AND currency='USD') THEN
        RAISE EXCEPTION 'monthly USD trial balance mismatch';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE period_id=v_nov AND account_code='9930') THEN
        RAISE EXCEPTION 'trial balance leaked entity B activity';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_nov AND account_code='9900' AND balance=60 AND currency='KES') THEN
        RAISE EXCEPTION 'monthly KES balance sheet mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_nov AND account_code='CURRENT_PERIOD_RESULT' AND balance=60 AND currency='KES') THEN
        RAISE EXCEPTION 'monthly KES current-period result mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_nov AND account_code='CURRENT_PERIOD_RESULT' AND balance=250 AND currency='USD') THEN
        RAISE EXCEPTION 'monthly USD current-period result mismatch';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_nov AND account_code='9930') THEN
        RAISE EXCEPTION 'balance sheet leaked entity B activity';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM finance.v_monthly_balance_sheet
        WHERE period_id=v_nov
        GROUP BY period_id, currency
        HAVING round(sum(CASE WHEN account_type='asset' THEN balance ELSE 0 END),4)
            <> round(sum(CASE WHEN account_type='liability' THEN balance ELSE 0 END)
                   + sum(CASE WHEN account_type='equity' THEN balance ELSE 0 END),4)
    ) THEN
        RAISE EXCEPTION 'balance sheet equation does not reconcile';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_nov AND is_reconciled IS NOT TRUE) THEN
        RAISE EXCEPTION 'balance sheet did not report reconciliation status';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM finance.v_monthly_balance_sheet
        WHERE period_id=v_105_nov
        GROUP BY period_id, currency
        HAVING round(sum(CASE WHEN account_type='asset' THEN balance ELSE 0 END),4)
            <> round(sum(CASE WHEN account_type='liability' THEN balance ELSE 0 END)
                   + sum(CASE WHEN account_type='equity' THEN balance ELSE 0 END),4)
    ) THEN
        RAISE EXCEPTION 'entity B balance sheet equation does not reconcile';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_105_nov AND is_reconciled IS NOT TRUE) THEN
        RAISE EXCEPTION 'entity B balance sheet did not report reconciliation status';
    END IF;

    -- Zero-activity period must still expose a zero current-period result for
    -- each reporting currency present on the entity's ledger accounts.
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_dec AND account_code='CURRENT_PERIOD_RESULT' AND currency='KES' AND balance=0 AND is_reconciled) THEN
        RAISE EXCEPTION 'zero-activity KES current-period result missing or not reconciled';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_dec AND account_code='CURRENT_PERIOD_RESULT' AND currency='USD' AND balance=0 AND is_reconciled) THEN
        RAISE EXCEPTION 'zero-activity USD current-period result missing or not reconciled';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000104' AND financial_year=2026 AND currency='KES' AND total_revenue=100 AND total_expense=40 AND net_result=60 AND reporting_label='initial_operating_2026_nov_dec') THEN
        RAISE EXCEPTION 'financial-year KES report/label mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000104' AND financial_year=2026 AND currency='USD' AND total_revenue=250 AND total_expense=0 AND net_result=250) THEN
        RAISE EXCEPTION 'financial-year USD report mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000105' AND financial_year=2026 AND currency='KES' AND total_revenue=75 AND net_result=75) THEN
        RAISE EXCEPTION 'entity B financial-year report mismatch';
    END IF;

    -- Expense-only period: current-period result is negative and the balance
    -- sheet still reconciles.
    v_exp := finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2027-03-01','2027-03-31');
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2027-03-10','KES','draft','Expense-only period','test',gen_random_uuid(),'monthly-policy-expense-only')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,30,0,'Expense-only debit'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9902';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,30,'Expense-only asset credit'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9900';
    PERFORM finance.post_journal(v_journal);
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_exp AND account_code='9902' AND net_amount=30 AND currency='KES') THEN
        RAISE EXCEPTION 'expense-only P&L mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_exp AND account_code='CURRENT_PERIOD_RESULT' AND balance=-30 AND currency='KES' AND is_reconciled) THEN
        RAISE EXCEPTION 'expense-only current-period result mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000104' AND financial_year=2027 AND currency='KES' AND total_expense=30 AND net_result=-30) THEN
        RAISE EXCEPTION 'expense-only financial-year summary mismatch';
    END IF;

    -- Deactivation must not erase historical balances. Account 9900 has a
    -- posted KES balance of 60 after the revenue/expense journals.
    UPDATE finance.ledger_accounts SET is_active=false
     WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code IN ('9900','9901');
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_nov AND account_code='9901' AND net_amount=100 AND currency='KES' AND is_active=false) THEN
        RAISE EXCEPTION 'inactive revenue account was erased from P&L';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE period_id=v_nov AND account_code='9900' AND debit_balance=60 AND is_active=false) THEN
        RAISE EXCEPTION 'inactive account was erased from trial balance';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_nov AND account_code='9900' AND balance=60 AND is_active=false) THEN
        RAISE EXCEPTION 'inactive account was erased from balance sheet';
    END IF;
    v_later := finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2027-04-01','2027-04-30');
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_nov AND account_code='9900' AND balance=60 AND is_active=false) THEN
        RAISE EXCEPTION 'inactive historical balance disappeared after a later period was created';
    END IF;

    PERFORM finance.close_accounting_period(v_nov);
    IF NOT EXISTS (SELECT 1 FROM finance.accounting_periods WHERE id=v_nov AND status='closed' AND closed_by='00000000-0000-4000-8000-000000000103') THEN
        RAISE EXCEPTION 'period close audit fields mismatch';
    END IF;

    v_rejected := false;
    BEGIN
        UPDATE finance.accounting_periods SET status='open' WHERE id=v_nov;
    EXCEPTION WHEN SQLSTATE '55000' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'closed period was reopened by direct update'; END IF;

    v_rejected := false;
    BEGIN
        INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
        VALUES ('00000000-0000-4000-8000-000000000104','2026-11-20','KES','draft','Closed period journal','test',gen_random_uuid(),'closed-period-journal');
    EXCEPTION WHEN SQLSTATE '55000' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'closed-period journal insert was accepted'; END IF;

    -- Build a deliberately unbalanced posted journal to exercise the close
    -- guard. This bypass is confined to the local test transaction; normal
    -- application paths cannot post unbalanced journals.
    v_2027 := finance.create_accounting_period('00000000-0000-4000-8000-000000000104','2027-01-01','2027-01-31');
    PERFORM set_config('session_replication_role','replica',true);
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key,posted_at)
    VALUES ('00000000-0000-4000-8000-000000000104','2027-01-10','KES','posted','Unbalanced test','test',gen_random_uuid(),'unbalanced-close-test',now())
    RETURNING id INTO v_unbalanced;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_unbalanced,'00000000-0000-4000-8000-000000000104','KES',1,id,100,0,'Unbalanced debit'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9920';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_unbalanced,'00000000-0000-4000-8000-000000000104','KES',2,id,0,50,'Unbalanced credit'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9921';
    PERFORM set_config('session_replication_role','origin',true);
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_2027 AND is_reconciled IS FALSE) THEN
        RAISE EXCEPTION 'unbalanced posted journal did not set is_reconciled=false';
    END IF;

    v_rejected := false;
    BEGIN
        PERFORM finance.close_accounting_period(v_2027);
    EXCEPTION WHEN SQLSTATE '55000' THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'period with unbalanced posted journal was closed'; END IF;
END;
$test$;

ROLLBACK;

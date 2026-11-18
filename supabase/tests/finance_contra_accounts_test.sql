-- ============================================================================
-- finance_contra_accounts_test.sql
-- LOCAL-ONLY contra-account sign and reconciliation tests.
-- ============================================================================
BEGIN;

INSERT INTO finance.ledger_accounts (entity_id,account_code,account_name,account_type,normal_balance,currency,is_active)
VALUES
 ('00000000-0000-4000-8000-000000000104','9960','Contra Asset','asset','credit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9961','Contra Liability','liability','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9962','Contra Equity','equity','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9963','Contra Revenue','revenue','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9964','Contra Expense','expense','credit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9965','Standard Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','9966','Standard Expense','expense','debit','KES',true)
ON CONFLICT (entity_id,account_code) DO NOTHING;

DO $test$
DECLARE
    v_period uuid;
    v_journal uuid;
BEGIN
    UPDATE users.profiles SET auth_user_id='20000000-0000-4000-8000-000000000103'
     WHERE id='00000000-0000-4000-8000-000000000103';
    PERFORM set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000103',true);

    v_period := finance.create_accounting_period(
        '00000000-0000-4000-8000-000000000104','2032-01-01','2032-01-31');

    -- Contra asset: credit asset, debit standard expense.
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2032-01-10','KES','draft','Contra asset','test',gen_random_uuid(),'contra-asset')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,10,0,'Expense'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9966';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,10,'Contra asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9960';
    PERFORM finance.post_journal(v_journal);

    -- Contra liability: debit liability, credit standard asset.
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2032-01-11','KES','draft','Contra liability','test',gen_random_uuid(),'contra-liability')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,5,0,'Contra liability'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9961';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,5,'Asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9965';
    PERFORM finance.post_journal(v_journal);

    -- Contra equity: debit equity, credit standard asset.
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2032-01-12','KES','draft','Contra equity','test',gen_random_uuid(),'contra-equity')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,7,0,'Contra equity'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9962';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,7,'Asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9965';
    PERFORM finance.post_journal(v_journal);

    -- Contra revenue: debit revenue, credit standard asset.
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2032-01-13','KES','draft','Contra revenue','test',gen_random_uuid(),'contra-revenue')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,3,0,'Contra revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9963';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,3,'Asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9965';
    PERFORM finance.post_journal(v_journal);

    -- Contra expense: debit standard asset, credit expense.
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2032-01-14','KES','draft','Contra expense','test',gen_random_uuid(),'contra-expense')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,4,0,'Asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9965';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,4,'Contra expense'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='9964';
    PERFORM finance.post_journal(v_journal);

    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_code='9960' AND account_type='asset' AND normal_balance='credit' AND balance=-10 AND is_reconciled) THEN
        RAISE EXCEPTION 'contra asset balance/sign mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_code='9961' AND account_type='liability' AND normal_balance='debit' AND balance=-5 AND is_reconciled) THEN
        RAISE EXCEPTION 'contra liability balance/sign mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_code='9962' AND account_type='equity' AND normal_balance='debit' AND balance=-7 AND is_reconciled) THEN
        RAISE EXCEPTION 'contra equity balance/sign mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_code='9965' AND balance=-11 AND is_reconciled) THEN
        RAISE EXCEPTION 'standard asset balance mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_code='CURRENT_PERIOD_RESULT' AND balance=-9 AND is_reconciled) THEN
        RAISE EXCEPTION 'contra current-period result mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_period AND account_code='9963' AND net_amount=-3 AND currency='KES') THEN
        RAISE EXCEPTION 'contra revenue P&L sign mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_period AND account_code='9964' AND net_amount=-4 AND currency='KES') THEN
        RAISE EXCEPTION 'contra expense P&L sign mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE period_id=v_period AND account_code='9966' AND net_amount=10 AND currency='KES') THEN
        RAISE EXCEPTION 'standard expense P&L sign mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000104' AND financial_year=2032 AND currency='KES' AND total_revenue=-3 AND total_expense=6 AND net_result=-9) THEN
        RAISE EXCEPTION 'contra financial-year summary sign mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_type='asset' AND is_reconciled GROUP BY period_id,currency HAVING sum(balance)=-21) THEN
        RAISE EXCEPTION 'contra balance-sheet asset total mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_type='liability' AND is_reconciled GROUP BY period_id,currency HAVING sum(balance)=-5) THEN
        RAISE EXCEPTION 'contra balance-sheet liability total mismatch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE period_id=v_period AND account_type='equity' AND is_reconciled GROUP BY period_id,currency HAVING sum(balance)=-16) THEN
        RAISE EXCEPTION 'contra balance-sheet equity total mismatch';
    END IF;
END;
$test$;

ROLLBACK;

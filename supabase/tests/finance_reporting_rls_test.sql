-- ============================================================================
-- finance_reporting_rls_test.sql
-- LOCAL-ONLY authenticated reporting and entity-isolation tests.
-- Runs under the captured baseline grants: authenticated has no direct SELECT
-- on core.entity_members. The finance SECURITY DEFINER helper supplies access.
-- ============================================================================
BEGIN;

DO $grants$
BEGIN
    IF has_table_privilege('authenticated','core.entity_members','SELECT') THEN
        RAISE EXCEPTION 'authenticated must not have direct core.entity_members access';
    END IF;
    IF NOT has_function_privilege('authenticated','finance.user_can_read_entity(uuid)','EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot execute reporting membership helper';
    END IF;
    IF NOT has_table_privilege('authenticated','finance.v_monthly_profit_and_loss','SELECT')
       OR NOT has_table_privilege('authenticated','finance.v_monthly_trial_balance','SELECT')
       OR NOT has_table_privilege('authenticated','finance.v_monthly_balance_sheet','SELECT')
       OR NOT has_table_privilege('authenticated','finance.v_financial_year_summary','SELECT') THEN
        RAISE EXCEPTION 'authenticated is missing a reporting view grant';
    END IF;
END;
$grants$;

INSERT INTO users.profiles (id,auth_user_id,first_name,country_id,is_active,account_status)
VALUES
 ('aaaaaaaa-0000-4000-8000-000000000001','bbbbbbbb-0000-4000-8000-000000000001','RLS User A',
  (SELECT id FROM core.countries LIMIT 1), true, 'active'),
 ('aaaaaaaa-0000-4000-8000-000000000002','bbbbbbbb-0000-4000-8000-000000000002','RLS User B',
  (SELECT id FROM core.countries LIMIT 1), true, 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO core.entities (id,name,entity_type,owner_id,is_active,metadata)
VALUES
 ('00000000-0000-4000-8000-000000000104','RLS Entity A','trading_company',
  'aaaaaaaa-0000-4000-8000-000000000001',true,'{}'::jsonb),
 ('00000000-0000-4000-8000-000000000106','RLS Entity B','trading_company',
  'aaaaaaaa-0000-4000-8000-000000000002',true,'{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO core.entity_members (entity_id,profile_id,role_id,is_active,membership_status)
VALUES
 ('00000000-0000-4000-8000-000000000104','aaaaaaaa-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000102',true,'active'),
 ('00000000-0000-4000-8000-000000000106','aaaaaaaa-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000102',true,'active')
ON CONFLICT (entity_id,profile_id) DO NOTHING;

INSERT INTO finance.ledger_accounts (entity_id,account_code,account_name,account_type,normal_balance,currency,is_active)
VALUES
 ('00000000-0000-4000-8000-000000000104','1000','RLS A Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000104','4200','RLS A Revenue','revenue','credit','KES',true),
 ('00000000-0000-4000-8000-000000000106','1000','RLS B Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000106','4200','RLS B Revenue','revenue','credit','KES',true)
ON CONFLICT (entity_id,account_code) DO NOTHING;

DO $fixture$
DECLARE
    v_period uuid;
    v_journal uuid;
BEGIN
    INSERT INTO finance.accounting_periods (entity_id,start_date,end_date,status,created_by)
    VALUES
     ('00000000-0000-4000-8000-000000000104','2026-11-01','2026-11-30','open',
      'aaaaaaaa-0000-4000-8000-000000000001'),
     ('00000000-0000-4000-8000-000000000106','2026-11-01','2026-11-30','open',
      'aaaaaaaa-0000-4000-8000-000000000002');

    PERFORM set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000001',true);
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000104','2026-11-15','KES','draft','RLS A','test',gen_random_uuid(),'rls-report-a')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',1,id,100,0,'A asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='1000';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000104','KES',2,id,0,100,'A revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000104' AND account_code='4200';
    PERFORM finance.post_journal(v_journal);

    PERFORM set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000002',true);
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000106','2026-11-16','KES','draft','RLS B','test',gen_random_uuid(),'rls-report-b')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000106','KES',1,id,200,0,'B asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000106' AND account_code='1000';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000106','KES',2,id,0,200,'B revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000106' AND account_code='4200';
    PERFORM finance.post_journal(v_journal);
END;
$fixture$;

SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $assert_a$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'authenticated user A cannot read own P&L';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'authenticated user A cannot read own trial balance';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'authenticated user A cannot read own balance sheet';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'authenticated user A cannot read own financial-year summary';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'user A can read user B P&L';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'user A can read user B trial balance';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'user A can read user B balance sheet';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'user A can read user B financial-year summary';
    END IF;
END;
$assert_a$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $assert_b$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'authenticated user B cannot read own P&L';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'authenticated user B cannot read own trial balance';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'authenticated user B cannot read own balance sheet';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000106') THEN
        RAISE EXCEPTION 'authenticated user B cannot read own financial-year summary';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'user B can read user A P&L';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'user B can read user A trial balance';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'user B can read user A balance sheet';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000104') THEN
        RAISE EXCEPTION 'user B can read user A financial-year summary';
    END IF;
END;
$assert_b$;
RESET ROLE;

ROLLBACK;

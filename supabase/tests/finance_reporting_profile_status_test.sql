-- ============================================================================
-- finance_reporting_profile_status_test.sql
-- LOCAL-ONLY profile active-state and entity-isolation tests for the four
-- monthly Finance reporting views.
-- ============================================================================
BEGIN;

DO $grants$
BEGIN
    IF has_table_privilege('authenticated','core.entity_members','SELECT') THEN
        RAISE EXCEPTION 'authenticated must not have direct core.entity_members access';
    END IF;
    IF NOT has_function_privilege('authenticated','finance.user_can_read_entity(uuid)','EXECUTE') THEN
        RAISE EXCEPTION 'authenticated cannot execute the reporting helper';
    END IF;
    IF NOT has_function_privilege('service_role','finance.user_can_read_entity(uuid)','EXECUTE') THEN
        RAISE EXCEPTION 'service_role cannot execute the reporting helper';
    END IF;
    IF has_function_privilege('anon','finance.user_can_read_entity(uuid)','EXECUTE') THEN
        RAISE EXCEPTION 'anon must not execute the reporting helper';
    END IF;
END;
$grants$;

INSERT INTO users.profiles (id,auth_user_id,first_name,country_id,is_active,account_status)
VALUES
 ('aaaaaaaa-0000-4000-8000-000000000301','bbbbbbbb-0000-4000-8000-000000000401','Active A',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('aaaaaaaa-0000-4000-8000-000000000302','bbbbbbbb-0000-4000-8000-000000000402','Inactive A',
  (SELECT id FROM core.countries LIMIT 1),false,'active'),
 ('aaaaaaaa-0000-4000-8000-000000000303','bbbbbbbb-0000-4000-8000-000000000403','Suspended A',
  (SELECT id FROM core.countries LIMIT 1),true,'suspended'),
 ('aaaaaaaa-0000-4000-8000-000000000304','bbbbbbbb-0000-4000-8000-000000000404','Blocked A',
  (SELECT id FROM core.countries LIMIT 1),true,'blocked'),
 ('aaaaaaaa-0000-4000-8000-000000000305','bbbbbbbb-0000-4000-8000-000000000405','Reactivated A',
  (SELECT id FROM core.countries LIMIT 1),false,'active'),
 ('aaaaaaaa-0000-4000-8000-000000000306','bbbbbbbb-0000-4000-8000-000000000406','No Membership A',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('aaaaaaaa-0000-4000-8000-000000000307','bbbbbbbb-0000-4000-8000-000000000407','Active B',
  (SELECT id FROM core.countries LIMIT 1),true,'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO core.entities (id,name,entity_type,owner_id,is_active,metadata)
VALUES
 ('00000000-0000-4000-8000-000000000201','Profile Status Entity A','trading_company',
  'aaaaaaaa-0000-4000-8000-000000000301',true,'{}'::jsonb),
 ('00000000-0000-4000-8000-000000000202','Profile Status Entity B','trading_company',
  'aaaaaaaa-0000-4000-8000-000000000307',true,'{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO core.entity_members (entity_id,profile_id,role_id,is_active,membership_status)
VALUES
 ('00000000-0000-4000-8000-000000000201','aaaaaaaa-0000-4000-8000-000000000301','00000000-0000-4000-8000-000000000102',true,'active'),
 ('00000000-0000-4000-8000-000000000201','aaaaaaaa-0000-4000-8000-000000000302','00000000-0000-4000-8000-000000000102',true,'active'),
 ('00000000-0000-4000-8000-000000000201','aaaaaaaa-0000-4000-8000-000000000303','00000000-0000-4000-8000-000000000102',true,'active'),
 ('00000000-0000-4000-8000-000000000201','aaaaaaaa-0000-4000-8000-000000000304','00000000-0000-4000-8000-000000000102',true,'active'),
 ('00000000-0000-4000-8000-000000000201','aaaaaaaa-0000-4000-8000-000000000305','00000000-0000-4000-8000-000000000102',true,'active'),
 ('00000000-0000-4000-8000-000000000202','aaaaaaaa-0000-4000-8000-000000000307','00000000-0000-4000-8000-000000000102',true,'active')
ON CONFLICT (entity_id,profile_id) DO NOTHING;

INSERT INTO finance.ledger_accounts (entity_id,account_code,account_name,account_type,normal_balance,currency,is_active)
VALUES
 ('00000000-0000-4000-8000-000000000201','1000','Profile A Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000201','4200','Profile A Revenue','revenue','credit','KES',true),
 ('00000000-0000-4000-8000-000000000202','1000','Profile B Asset','asset','debit','KES',true),
 ('00000000-0000-4000-8000-000000000202','4200','Profile B Revenue','revenue','credit','KES',true)
ON CONFLICT (entity_id,account_code) DO NOTHING;

DO $fixture$
DECLARE
    v_period uuid;
    v_journal uuid;
BEGIN
    INSERT INTO finance.accounting_periods (entity_id,start_date,end_date,status,created_by)
    VALUES
     ('00000000-0000-4000-8000-000000000201','2026-11-01','2026-11-30','open','aaaaaaaa-0000-4000-8000-000000000301'),
     ('00000000-0000-4000-8000-000000000202','2026-11-01','2026-11-30','open','aaaaaaaa-0000-4000-8000-000000000307');

    PERFORM set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000401',true);
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000201','2026-11-15','KES','draft','Profile A','test',gen_random_uuid(),'profile-status-a')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000201','KES',1,id,100,0,'A asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000201' AND account_code='1000';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000201','KES',2,id,0,100,'A revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000201' AND account_code='4200';
    PERFORM finance.post_journal(v_journal);

    PERFORM set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000407',true);
    INSERT INTO finance.journals (entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES ('00000000-0000-4000-8000-000000000202','2026-11-16','KES','draft','Profile B','test',gen_random_uuid(),'profile-status-b')
    RETURNING id INTO v_journal;
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000202','KES',1,id,200,0,'B asset'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000202' AND account_code='1000';
    INSERT INTO finance.journal_lines (journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    SELECT v_journal,'00000000-0000-4000-8000-000000000202','KES',2,id,0,200,'B revenue'
      FROM finance.ledger_accounts WHERE entity_id='00000000-0000-4000-8000-000000000202' AND account_code='4200';
    PERFORM finance.post_journal(v_journal);
END;
$fixture$;

-- Active profile with active membership: all four views expose own data.
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000401',true);
SET LOCAL ROLE authenticated;
DO $assert_active$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE entity_id='00000000-0000-4000-8000-000000000201') THEN
        RAISE EXCEPTION 'active profile cannot read own P&L';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE entity_id='00000000-0000-4000-8000-000000000201') THEN
        RAISE EXCEPTION 'active profile cannot read own trial balance';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE entity_id='00000000-0000-4000-8000-000000000201') THEN
        RAISE EXCEPTION 'active profile cannot read own balance sheet';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000201') THEN
        RAISE EXCEPTION 'active profile cannot read own financial-year summary';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE entity_id='00000000-0000-4000-8000-000000000202')
       OR EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE entity_id='00000000-0000-4000-8000-000000000202')
       OR EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE entity_id='00000000-0000-4000-8000-000000000202')
       OR EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000202') THEN
        RAISE EXCEPTION 'active user A can read entity B reports';
    END IF;
END;
$assert_active$;
RESET ROLE;

-- Inactive profile with active membership: all four views must be empty.
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000402',true);
SET LOCAL ROLE authenticated;
DO $assert_inactive$
BEGIN
    IF (SELECT count(*) FROM finance.v_monthly_profit_and_loss) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_trial_balance) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_balance_sheet) <> 0
       OR (SELECT count(*) FROM finance.v_financial_year_summary) <> 0 THEN
        RAISE EXCEPTION 'inactive profile can read reports';
    END IF;
END;
$assert_inactive$;
RESET ROLE;

-- Suspended profile with active membership: all four views must be empty.
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000403',true);
SET LOCAL ROLE authenticated;
DO $assert_suspended$
BEGIN
    IF (SELECT count(*) FROM finance.v_monthly_profit_and_loss) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_trial_balance) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_balance_sheet) <> 0
       OR (SELECT count(*) FROM finance.v_financial_year_summary) <> 0 THEN
        RAISE EXCEPTION 'suspended profile can read reports';
    END IF;
END;
$assert_suspended$;
RESET ROLE;

-- Blocked profile with active membership: all four views must be empty.
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000404',true);
SET LOCAL ROLE authenticated;
DO $assert_blocked$
BEGIN
    IF (SELECT count(*) FROM finance.v_monthly_profit_and_loss) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_trial_balance) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_balance_sheet) <> 0
       OR (SELECT count(*) FROM finance.v_financial_year_summary) <> 0 THEN
        RAISE EXCEPTION 'blocked profile can read reports';
    END IF;
END;
$assert_blocked$;
RESET ROLE;

-- Reactivation: initially inactive, then active; access must be restored.
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000405',true);
SET LOCAL ROLE authenticated;
DO $assert_reactivated_before$
BEGIN
    IF (SELECT count(*) FROM finance.v_monthly_profit_and_loss) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_trial_balance) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_balance_sheet) <> 0
       OR (SELECT count(*) FROM finance.v_financial_year_summary) <> 0 THEN
        RAISE EXCEPTION 'reactivated-before profile can read reports';
    END IF;
END;
$assert_reactivated_before$;
RESET ROLE;

UPDATE users.profiles SET is_active=true, account_status='active'
 WHERE id='aaaaaaaa-0000-4000-8000-000000000305';
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000405',true);
SET LOCAL ROLE authenticated;
DO $assert_reactivated_after$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM finance.v_monthly_profit_and_loss WHERE entity_id='00000000-0000-4000-8000-000000000201')
       OR NOT EXISTS (SELECT 1 FROM finance.v_monthly_trial_balance WHERE entity_id='00000000-0000-4000-8000-000000000201')
       OR NOT EXISTS (SELECT 1 FROM finance.v_monthly_balance_sheet WHERE entity_id='00000000-0000-4000-8000-000000000201')
       OR NOT EXISTS (SELECT 1 FROM finance.v_financial_year_summary WHERE entity_id='00000000-0000-4000-8000-000000000201') THEN
        RAISE EXCEPTION 'reactivated profile cannot read reports';
    END IF;
END;
$assert_reactivated_after$;
RESET ROLE;

-- Active profile without membership: all four views must be empty.
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-0000-4000-8000-000000000406',true);
SET LOCAL ROLE authenticated;
DO $assert_no_membership$
BEGIN
    IF (SELECT count(*) FROM finance.v_monthly_profit_and_loss) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_trial_balance) <> 0
       OR (SELECT count(*) FROM finance.v_monthly_balance_sheet) <> 0
       OR (SELECT count(*) FROM finance.v_financial_year_summary) <> 0 THEN
        RAISE EXCEPTION 'active profile without membership can read reports';
    END IF;
END;
$assert_no_membership$;
RESET ROLE;

ROLLBACK;

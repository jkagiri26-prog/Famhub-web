-- ============================================================================
-- 20261114000003_finance_reporting_rls_and_signs
-- ----------------------------------------------------------------------------
-- Second-review corrections:
--   * SECURITY DEFINER membership helper for authenticated reporting
--   * RLS policies no longer require direct core.entity_members access
--   * Balance Sheet signs derived from account_type
--   * Contra revenue/expense presentation corrected
--   * Zero-value CURRENT_PERIOD_RESULT for zero-activity periods
-- ============================================================================

BEGIN;

-- Narrowly scoped membership check. The caller only needs EXECUTE on this
-- function; authenticated users are not granted access to core.entity_members.
CREATE OR REPLACE FUNCTION finance.user_can_read_entity(p_entity_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core'
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM core.entity_members AS em
     WHERE em.entity_id = p_entity_id
       AND em.profile_id = core.current_profile_id()
       AND em.is_active IS TRUE
       AND em.membership_status = 'active'
  );
$function$;

REVOKE ALL ON FUNCTION finance.user_can_read_entity(uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION finance.user_can_read_entity(uuid) TO "authenticated", "service_role";

DROP POLICY IF EXISTS accounting_periods_entity_member_read ON finance.accounting_periods;
CREATE POLICY accounting_periods_entity_member_read ON finance.accounting_periods
FOR SELECT TO authenticated
USING (finance.user_can_read_entity(entity_id));

DROP POLICY IF EXISTS journals_entity_read ON finance.journals;
CREATE POLICY journals_entity_read ON finance.journals
FOR SELECT TO authenticated
USING (finance.user_can_read_entity(entity_id));

DROP POLICY IF EXISTS journal_lines_active_entity_guard ON finance.journal_lines;
DROP POLICY IF EXISTS journal_lines_entity_read ON finance.journal_lines;
CREATE POLICY journal_lines_active_entity_guard ON finance.journal_lines
FOR SELECT TO authenticated
USING (finance.user_can_read_entity(entity_id));
CREATE POLICY journal_lines_entity_read ON finance.journal_lines
FOR SELECT TO authenticated
USING (finance.user_can_read_entity(entity_id));

DROP POLICY IF EXISTS ledger_accounts_entity_read ON finance.ledger_accounts;
CREATE POLICY ledger_accounts_entity_read ON finance.ledger_accounts
FOR SELECT TO authenticated
USING (finance.user_can_read_entity(entity_id));

CREATE OR REPLACE VIEW finance.v_monthly_profit_and_loss
WITH (security_invoker='true') AS
SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
       la.account_code, la.account_name, la.account_type, la.normal_balance,
       coalesce(sum(l.debit_amount),0) AS debits,
       coalesce(sum(l.credit_amount),0) AS credits,
       CASE WHEN la.account_type='revenue'
            THEN coalesce(sum(l.credit_amount),0)-coalesce(sum(l.debit_amount),0)
            WHEN la.account_type='expense'
            THEN coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0)
            ELSE 0 END AS net_amount,
       coalesce(l.currency, la.currency) AS currency,
       la.is_active
FROM finance.accounting_periods p
JOIN finance.ledger_accounts la ON la.entity_id=p.entity_id
LEFT JOIN finance.journals j ON j.entity_id=p.entity_id AND j.status='posted'
 AND j.journal_date BETWEEN p.start_date AND p.end_date
LEFT JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
 AND l.account_id=la.id AND l.currency=j.currency
WHERE date_trunc('month',p.start_date)::date=p.start_date
  AND p.end_date=(date_trunc('month',p.end_date)+interval '1 month - 1 day')::date
  AND date_trunc('month',p.start_date)=date_trunc('month',p.end_date)
  AND la.account_type IN ('revenue','expense')
GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.account_code,la.account_name,
         la.account_type,la.normal_balance,coalesce(l.currency,la.currency),la.is_active;

CREATE OR REPLACE VIEW finance.v_monthly_balance_sheet
WITH (security_invoker='true') AS
WITH monthly_periods AS (
  SELECT p.id, p.entity_id, p.start_date, p.end_date
  FROM finance.accounting_periods p
  WHERE date_trunc('month',p.start_date)::date=p.start_date
    AND p.end_date=(date_trunc('month',p.end_date)+interval '1 month - 1 day')::date
    AND date_trunc('month',p.start_date)=date_trunc('month',p.end_date)
), period_rows AS (
  SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
         la.account_code, la.account_name, la.account_type, la.normal_balance,
         CASE WHEN la.account_type='asset'
              THEN coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0)
              ELSE coalesce(sum(l.credit_amount),0)-coalesce(sum(l.debit_amount),0) END AS balance,
         coalesce(l.currency, la.currency) AS currency,
         la.is_active
  FROM monthly_periods p
  JOIN finance.ledger_accounts la ON la.entity_id=p.entity_id
  LEFT JOIN finance.journals j ON j.entity_id=p.entity_id AND j.status='posted'
   AND j.journal_date BETWEEN p.start_date AND p.end_date
  LEFT JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
   AND l.account_id=la.id AND l.currency=j.currency
  WHERE la.account_type IN ('asset','liability','equity')
  GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.account_code,la.account_name,
           la.account_type,la.normal_balance,coalesce(l.currency,la.currency),la.is_active
), revenue_expense_activity AS (
  SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
         l.currency,
         sum(l.credit_amount-l.debit_amount) AS balance
  FROM monthly_periods p
  JOIN finance.journals j ON j.entity_id=p.entity_id AND j.status='posted'
   AND j.journal_date BETWEEN p.start_date AND p.end_date
  JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
  JOIN finance.ledger_accounts la ON la.id=l.account_id AND la.entity_id=l.entity_id
  WHERE la.account_type IN ('revenue','expense')
  GROUP BY p.id,p.entity_id,p.start_date,p.end_date,l.currency
), period_currencies AS (
  SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date, la.currency
  FROM monthly_periods p
  JOIN finance.ledger_accounts la ON la.entity_id=p.entity_id
  WHERE la.currency IS NOT NULL
  GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.currency
  UNION
  SELECT period_id, entity_id, start_date, end_date, currency
  FROM revenue_expense_activity
  WHERE currency IS NOT NULL
), current_result AS (
  SELECT pc.period_id, pc.entity_id, pc.start_date, pc.end_date,
         'CURRENT_PERIOD_RESULT'::text AS account_code,
         'Current Period Result'::text AS account_name,
         'equity'::text AS account_type,
         'credit'::text AS normal_balance,
         coalesce(rea.balance,0) AS balance,
         pc.currency,
         true AS is_active
  FROM period_currencies pc
  LEFT JOIN revenue_expense_activity rea
    ON rea.period_id=pc.period_id AND rea.currency=pc.currency
), all_rows AS (
  SELECT * FROM period_rows
  UNION ALL
  SELECT * FROM current_result
), reconciliation AS (
  SELECT period_id, currency,
         round(coalesce(sum(CASE WHEN account_type='asset' THEN balance ELSE 0 END),0),4)
           = round(coalesce(sum(CASE WHEN account_type='liability' THEN balance ELSE 0 END),0)
                 + coalesce(sum(CASE WHEN account_type='equity' THEN balance ELSE 0 END),0),4)
           AS is_reconciled
  FROM all_rows
  GROUP BY period_id, currency
)
SELECT r.*, rec.is_reconciled
FROM all_rows r
JOIN reconciliation rec ON rec.period_id=r.period_id AND rec.currency IS NOT DISTINCT FROM r.currency;

CREATE OR REPLACE VIEW finance.v_financial_year_summary
WITH (security_invoker='true') AS
SELECT j.entity_id,
       date_part('year', j.journal_date)::integer AS financial_year,
       min(j.journal_date) AS first_journal_date,
       max(j.journal_date) AS last_journal_date,
       sum(CASE WHEN la.account_type='revenue'
                THEN l.credit_amount-l.debit_amount ELSE 0 END) AS total_revenue,
       sum(CASE WHEN la.account_type='expense'
                THEN l.debit_amount-l.credit_amount ELSE 0 END) AS total_expense,
       sum(CASE WHEN la.account_type IN ('revenue','expense')
                THEN l.credit_amount-l.debit_amount ELSE 0 END) AS net_result,
       CASE WHEN date_part('year', j.journal_date)::integer=2026
                  AND min(j.journal_date) >= date '2026-11-01'
            THEN 'initial_operating_2026_nov_dec'
            ELSE 'full_financial_year' END AS reporting_label,
       l.currency
FROM finance.journals j
JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
JOIN finance.ledger_accounts la ON la.id=l.account_id AND la.entity_id=l.entity_id
JOIN finance.accounting_periods p ON p.entity_id=j.entity_id
 AND j.journal_date BETWEEN p.start_date AND p.end_date
WHERE j.status='posted'
  AND date_trunc('month',p.start_date)::date=p.start_date
  AND p.end_date=(date_trunc('month',p.end_date)+interval '1 month - 1 day')::date
  AND date_trunc('month',p.start_date)=date_trunc('month',p.end_date)
GROUP BY j.entity_id,date_part('year',j.journal_date),l.currency;

REVOKE ALL ON TABLE finance.v_monthly_profit_and_loss FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON TABLE finance.v_monthly_trial_balance FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON TABLE finance.v_monthly_balance_sheet FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON TABLE finance.v_financial_year_summary FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_monthly_profit_and_loss TO "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_monthly_trial_balance TO "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_monthly_balance_sheet TO "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_financial_year_summary TO "authenticated", "service_role";

COMMIT;

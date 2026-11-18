-- ============================================================================
-- 20261114000002_finance_monthly_reporting_corrections
-- ----------------------------------------------------------------------------
-- Corrects monthly reporting for:
--   * current-period earnings in the Balance Sheet
--   * inactive accounts with historical balances
--   * currency-separated reporting
--   * monthly-only historical period filtering
--   * closed-period reopening denial
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION finance.reject_closed_period_reopen()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  IF OLD.status = 'closed' AND NEW.status = 'open' THEN
    RAISE EXCEPTION 'Closed accounting periods cannot be reopened without an authorized correction workflow'
      USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS accounting_periods_no_reopen ON finance.accounting_periods;
CREATE TRIGGER accounting_periods_no_reopen
BEFORE UPDATE OF status ON finance.accounting_periods
FOR EACH ROW EXECUTE FUNCTION finance.reject_closed_period_reopen();

REVOKE ALL ON FUNCTION finance.reject_closed_period_reopen() FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE OR REPLACE VIEW finance.v_monthly_profit_and_loss
WITH (security_invoker='true') AS
SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
       la.account_code, la.account_name, la.account_type, la.normal_balance,
       coalesce(sum(l.debit_amount),0) AS debits,
       coalesce(sum(l.credit_amount),0) AS credits,
       CASE WHEN la.normal_balance='credit'
            THEN coalesce(sum(l.credit_amount),0)-coalesce(sum(l.debit_amount),0)
            ELSE coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0) END AS net_amount,
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

CREATE OR REPLACE VIEW finance.v_monthly_trial_balance
WITH (security_invoker='true') AS
SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
       la.account_code, la.account_name, la.account_type, la.normal_balance,
       coalesce(sum(l.debit_amount),0) AS total_debits,
       coalesce(sum(l.credit_amount),0) AS total_credits,
       coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0) AS debit_balance,
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
GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.account_code,la.account_name,
         la.account_type,la.normal_balance,coalesce(l.currency,la.currency),la.is_active;

CREATE OR REPLACE VIEW finance.v_monthly_balance_sheet
WITH (security_invoker='true') AS
WITH period_rows AS (
  SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
         la.account_code, la.account_name, la.account_type, la.normal_balance,
         CASE WHEN la.normal_balance='debit'
              THEN coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0)
              ELSE coalesce(sum(l.credit_amount),0)-coalesce(sum(l.debit_amount),0) END AS balance,
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
    AND la.account_type IN ('asset','liability','equity')
  GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.account_code,la.account_name,
           la.account_type,la.normal_balance,coalesce(l.currency,la.currency),la.is_active
), current_result AS (
  SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
         'CURRENT_PERIOD_RESULT'::text AS account_code,
         'Current Period Result'::text AS account_name,
         'equity'::text AS account_type,
         'credit'::text AS normal_balance,
         sum(CASE WHEN la.account_type IN ('revenue','expense')
                  THEN l.credit_amount-l.debit_amount ELSE 0 END) AS balance,
         l.currency,
         true AS is_active
  FROM finance.accounting_periods p
  JOIN finance.journals j ON j.entity_id=p.entity_id AND j.status='posted'
   AND j.journal_date BETWEEN p.start_date AND p.end_date
  JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
  JOIN finance.ledger_accounts la ON la.id=l.account_id AND la.entity_id=l.entity_id
  WHERE date_trunc('month',p.start_date)::date=p.start_date
    AND p.end_date=(date_trunc('month',p.end_date)+interval '1 month - 1 day')::date
    AND date_trunc('month',p.start_date)=date_trunc('month',p.end_date)
    AND la.account_type IN ('revenue','expense')
  GROUP BY p.id,p.entity_id,p.start_date,p.end_date,l.currency
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
       sum(CASE WHEN la.account_type='revenue' AND la.normal_balance='credit' THEN l.credit_amount-l.debit_amount
                WHEN la.account_type='revenue' THEN l.debit_amount-l.credit_amount ELSE 0 END) AS total_revenue,
       sum(CASE WHEN la.account_type='expense' AND la.normal_balance='debit' THEN l.debit_amount-l.credit_amount
                WHEN la.account_type='expense' THEN l.credit_amount-l.debit_amount ELSE 0 END) AS total_expense,
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

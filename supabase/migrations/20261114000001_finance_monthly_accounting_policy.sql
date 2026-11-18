-- ============================================================================
-- 20261114000001_finance_monthly_accounting_policy
-- ----------------------------------------------------------------------------
-- Approved monthly accounting-period foundation:
--   * January-December financial year
--   * calendar-month periods with inclusive boundaries
--   * monthly reporting views
--   * closed-period journal protection
--   * no year-end closing or opening-balance postings
-- ============================================================================

BEGIN;

-- Enforce calendar-month periods for new rows. NOT VALID preserves any
-- pre-existing historical periods while enforcing the approved policy for all
-- new periods.
DO $constraints$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='accounting_periods_month_start_check' AND conrelid='finance.accounting_periods'::regclass) THEN
        ALTER TABLE finance.accounting_periods
            ADD CONSTRAINT accounting_periods_month_start_check
            CHECK (start_date = date_trunc('month', start_date)::date) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='accounting_periods_month_end_check' AND conrelid='finance.accounting_periods'::regclass) THEN
        ALTER TABLE finance.accounting_periods
            ADD CONSTRAINT accounting_periods_month_end_check
            CHECK (end_date = (date_trunc('month', end_date) + interval '1 month - 1 day')::date) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='accounting_periods_same_month_check' AND conrelid='finance.accounting_periods'::regclass) THEN
        ALTER TABLE finance.accounting_periods
            ADD CONSTRAINT accounting_periods_same_month_check
            CHECK (date_trunc('month', start_date) = date_trunc('month', end_date)) NOT VALID;
    END IF;
END;
$constraints$;

CREATE OR REPLACE FUNCTION finance.create_accounting_period(p_entity_id uuid, p_start_date date, p_end_date date)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  v_profile_id uuid;
  v_period_id uuid;
BEGIN
  IF p_entity_id IS NULL OR p_start_date IS NULL OR p_end_date IS NULL OR p_end_date < p_start_date THEN
    RAISE EXCEPTION 'A valid entity and inclusive period date range are required' USING ERRCODE = '22023';
  END IF;
  IF p_start_date <> date_trunc('month', p_start_date)::date
     OR p_end_date <> (date_trunc('month', p_end_date) + interval '1 month - 1 day')::date
     OR date_trunc('month', p_start_date) <> date_trunc('month', p_end_date) THEN
    RAISE EXCEPTION 'Accounting periods must be complete calendar months' USING ERRCODE = '22023';
  END IF;

  SELECT p.id INTO v_profile_id
    FROM users.profiles AS p
   WHERE p.auth_user_id = auth.uid()
     AND p.is_active IS TRUE
     AND p.account_status = 'active';

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'An active authenticated profile is required' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM core.entities AS e
     WHERE e.id = p_entity_id
       AND e.is_active IS TRUE
       AND (
         e.owner_id = v_profile_id
         OR EXISTS (
           SELECT 1 FROM core.entity_members AS em
            WHERE em.entity_id = e.id
              AND em.profile_id = v_profile_id
              AND em.is_active IS TRUE
              AND em.membership_status = 'active'
              AND em.can_manage IS TRUE
         )
       )
  ) THEN
    RAISE EXCEPTION 'Insufficient authority to manage accounting periods for this entity' USING ERRCODE = '42501';
  END IF;

  INSERT INTO finance.accounting_periods (entity_id, start_date, end_date, created_by)
  VALUES (p_entity_id, p_start_date, p_end_date, v_profile_id)
  RETURNING id INTO v_period_id;

  RETURN v_period_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.close_accounting_period(p_period_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  v_period finance.accounting_periods%ROWTYPE;
  v_profile_id uuid;
BEGIN
  IF p_period_id IS NULL THEN
    RAISE EXCEPTION 'Accounting period id is required' USING ERRCODE = '22023';
  END IF;

  SELECT p.id INTO v_profile_id
    FROM users.profiles AS p
   WHERE p.auth_user_id = auth.uid()
     AND p.is_active IS TRUE
     AND p.account_status = 'active';
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'An active authenticated profile is required' USING ERRCODE = '42501';
  END IF;

  SELECT ap.* INTO v_period
    FROM finance.accounting_periods AS ap
   WHERE ap.id = p_period_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Accounting period not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM core.entities AS e
     WHERE e.id = v_period.entity_id
       AND e.is_active IS TRUE
       AND (
         e.owner_id = v_profile_id
         OR EXISTS (
           SELECT 1 FROM core.entity_members AS em
            WHERE em.entity_id = e.id
              AND em.profile_id = v_profile_id
              AND em.is_active IS TRUE
              AND em.membership_status = 'active'
              AND em.can_manage IS TRUE
         )
       )
  ) THEN
    RAISE EXCEPTION 'Insufficient authority to close this accounting period' USING ERRCODE = '42501';
  END IF;

  IF v_period.status = 'closed' THEN
    RETURN v_period.id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM finance.journals j
     WHERE j.entity_id = v_period.entity_id
       AND j.journal_date BETWEEN v_period.start_date AND v_period.end_date
       AND j.status = 'draft'
  ) THEN
    RAISE EXCEPTION 'Cannot close an accounting period while draft journals remain' USING ERRCODE = '55000';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM finance.journals j
      JOIN finance.journal_lines l ON l.journal_id = j.id
     WHERE j.entity_id = v_period.entity_id
       AND j.journal_date BETWEEN v_period.start_date AND v_period.end_date
       AND j.status = 'posted'
     GROUP BY j.id
    HAVING sum(l.debit_amount) <> sum(l.credit_amount)
  ) THEN
    RAISE EXCEPTION 'Cannot close an accounting period with unbalanced posted journals' USING ERRCODE = '55000';
  END IF;

  UPDATE finance.accounting_periods
     SET status = 'closed', closed_at = clock_timestamp(), closed_by = v_profile_id
   WHERE id = v_period.id;

  RETURN v_period.id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.guard_closed_period_journal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'finance'
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1 FROM finance.accounting_periods ap
     WHERE ap.entity_id = NEW.entity_id
       AND ap.status = 'closed'
       AND NEW.journal_date BETWEEN ap.start_date AND ap.end_date
  ) THEN
    RAISE EXCEPTION 'Cannot insert or move a journal into a closed accounting period' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS journals_closed_period_guard ON finance.journals;
CREATE TRIGGER journals_closed_period_guard
BEFORE INSERT OR UPDATE OF entity_id, journal_date ON finance.journals
FOR EACH ROW EXECUTE FUNCTION finance.guard_closed_period_journal();

-- Posted, period-aware reporting views.
CREATE OR REPLACE VIEW finance.v_monthly_profit_and_loss
WITH (security_invoker='true') AS
SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
       la.account_code, la.account_name, la.account_type, la.normal_balance,
       coalesce(sum(l.debit_amount),0) AS debits,
       coalesce(sum(l.credit_amount),0) AS credits,
       CASE WHEN la.normal_balance='credit'
            THEN coalesce(sum(l.credit_amount),0)-coalesce(sum(l.debit_amount),0)
            ELSE coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0) END AS net_amount
FROM finance.accounting_periods p
JOIN finance.ledger_accounts la ON la.entity_id=p.entity_id AND la.is_active IS TRUE
LEFT JOIN finance.journals j ON j.entity_id=p.entity_id AND j.status='posted'
 AND j.journal_date BETWEEN p.start_date AND p.end_date
LEFT JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
 AND l.account_id=la.id AND l.currency=j.currency
WHERE la.account_type IN ('revenue','expense')
GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.account_code,la.account_name,la.account_type,la.normal_balance;

CREATE OR REPLACE VIEW finance.v_monthly_trial_balance
WITH (security_invoker='true') AS
SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
       la.account_code, la.account_name, la.account_type, la.normal_balance,
       coalesce(sum(l.debit_amount),0) AS total_debits,
       coalesce(sum(l.credit_amount),0) AS total_credits,
       coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0) AS debit_balance
FROM finance.accounting_periods p
JOIN finance.ledger_accounts la ON la.entity_id=p.entity_id AND la.is_active IS TRUE
LEFT JOIN finance.journals j ON j.entity_id=p.entity_id AND j.status='posted'
 AND j.journal_date BETWEEN p.start_date AND p.end_date
LEFT JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
 AND l.account_id=la.id AND l.currency=j.currency
GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.account_code,la.account_name,la.account_type,la.normal_balance;

CREATE OR REPLACE VIEW finance.v_monthly_balance_sheet
WITH (security_invoker='true') AS
SELECT p.id AS period_id, p.entity_id, p.start_date, p.end_date,
       la.account_code, la.account_name, la.account_type, la.normal_balance,
       CASE WHEN la.normal_balance='debit'
            THEN coalesce(sum(l.debit_amount),0)-coalesce(sum(l.credit_amount),0)
            ELSE coalesce(sum(l.credit_amount),0)-coalesce(sum(l.debit_amount),0) END AS balance
FROM finance.accounting_periods p
JOIN finance.ledger_accounts la ON la.entity_id=p.entity_id AND la.is_active IS TRUE
LEFT JOIN finance.journals j ON j.entity_id=p.entity_id AND j.status='posted'
 AND j.journal_date BETWEEN p.start_date AND p.end_date
LEFT JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
 AND l.account_id=la.id AND l.currency=j.currency
WHERE la.account_type IN ('asset','liability','equity')
GROUP BY p.id,p.entity_id,p.start_date,p.end_date,la.account_code,la.account_name,la.account_type,la.normal_balance;

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
       sum(CASE WHEN la.account_type='revenue' AND la.normal_balance='credit' THEN l.credit_amount-l.debit_amount
                WHEN la.account_type='revenue' THEN l.debit_amount-l.credit_amount
                WHEN la.account_type='expense' AND la.normal_balance='debit' THEN -(l.debit_amount-l.credit_amount)
                WHEN la.account_type='expense' THEN -(l.credit_amount-l.debit_amount) ELSE 0 END) AS net_result,
       CASE WHEN date_part('year', j.journal_date)::integer=2026
                  AND min(j.journal_date) >= date '2026-11-01'
            THEN 'initial_operating_2026_nov_dec'
            ELSE 'full_financial_year' END AS reporting_label
FROM finance.journals j
JOIN finance.journal_lines l ON l.journal_id=j.id AND l.entity_id=j.entity_id
JOIN finance.ledger_accounts la ON la.id=l.account_id AND la.entity_id=l.entity_id
WHERE j.status='posted'
GROUP BY j.entity_id,date_part('year',j.journal_date);

REVOKE ALL ON TABLE finance.v_monthly_profit_and_loss FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON TABLE finance.v_monthly_trial_balance FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON TABLE finance.v_monthly_balance_sheet FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON TABLE finance.v_financial_year_summary FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_monthly_profit_and_loss TO "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_monthly_trial_balance TO "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_monthly_balance_sheet TO "authenticated", "service_role";
GRANT SELECT ON TABLE finance.v_financial_year_summary TO "authenticated", "service_role";

COMMIT;

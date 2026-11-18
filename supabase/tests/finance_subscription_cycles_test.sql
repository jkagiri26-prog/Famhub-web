-- ============================================================================
-- finance_subscription_cycles_test.sql
-- ----------------------------------------------------------------------------
-- Local-only behavioral checks for permanent annual subscription cycles and
-- Finance event idempotency.
--
-- Run after applying the Refer & Earn migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000001001', 'Testland', 'KE', 'KEN', '254');

INSERT INTO users.profiles(id, first_name, country_id)
VALUES (
  '00000000-0000-0000-0000-000000001002',
  'Cycle Tester',
  '00000000-0000-0000-0000-000000001001'
);

INSERT INTO core.entities(id, name, entity_type, owner_id)
VALUES (
  '00000000-0000-0000-0000-000000001003',
  'Cycle Tester Entity',
  'individual_pro',
  '00000000-0000-0000-0000-000000001002'
);

INSERT INTO system.billing_accounts(id, entity_id, profile_id, account_type)
VALUES (
  '00000000-0000-0000-0000-000000001004',
  '00000000-0000-0000-0000-000000001003',
  '00000000-0000-0000-0000-000000001002',
  'individual'
);

INSERT INTO system.subscription_plans(
  id, plan_key, plan_name, billing_cycle, amount, currency
) VALUES (
  '00000000-0000-0000-0000-000000001005',
  'annual-test',
  'Annual Test Plan',
  'yearly',
  12000,
  'KES'
);

INSERT INTO system.active_subscriptions(id, billing_account_id, plan_id, status)
VALUES (
  '00000000-0000-0000-0000-000000001006',
  '00000000-0000-0000-0000-000000001004',
  '00000000-0000-0000-0000-000000001005',
  'active'
);

INSERT INTO system.invoices(
  id, billing_account_id, invoice_number, module_name, total_amount, currency
) VALUES
  ('00000000-0000-0000-0000-000000001007', '00000000-0000-0000-0000-000000001004', 'INV-CYCLE-1', 'subscription', 12000, 'KES'),
  ('00000000-0000-0000-0000-000000001008', '00000000-0000-0000-0000-000000001004', 'INV-CYCLE-2', 'subscription', 12000, 'KES');

INSERT INTO finance.obligations(id) VALUES
  ('00000000-0000-0000-0000-000000001009'),
  ('00000000-0000-0000-0000-000000001010');

INSERT INTO finance.subscription_cycles(
  id, billing_account_id, subscriber_profile_id, entity_id, plan_id,
  active_subscription_id, annual_sequence, cycle_type, period_start, period_end,
  invoice_id, obligation_id, amount, status
) VALUES (
  '00000000-0000-0000-0000-000000001011',
  '00000000-0000-0000-0000-000000001004',
  '00000000-0000-0000-0000-000000001002',
  '00000000-0000-0000-0000-000000001003',
  '00000000-0000-0000-0000-000000001005',
  '00000000-0000-0000-0000-000000001006',
  1, 'initial_annual', '2026-01-01', '2026-12-31',
  '00000000-0000-0000-0000-000000001007',
  '00000000-0000-0000-0000-000000001009',
  12000, 'active'
);

-- Early renewal: future period, linked previous cycle, existing access row.
INSERT INTO finance.subscription_cycles(
  id, billing_account_id, subscriber_profile_id, entity_id, plan_id,
  active_subscription_id, annual_sequence, cycle_type, previous_cycle_id,
  period_start, period_end, invoice_id, obligation_id, amount, status
) VALUES (
  '00000000-0000-0000-0000-000000001012',
  '00000000-0000-0000-0000-000000001004',
  '00000000-0000-0000-0000-000000001002',
  '00000000-0000-0000-0000-000000001003',
  '00000000-0000-0000-0000-000000001005',
  '00000000-0000-0000-0000-000000001006',
  2, 'renewal_annual', '00000000-0000-0000-0000-000000001011',
  '2027-01-01', '2027-12-31',
  '00000000-0000-0000-0000-000000001008',
  '00000000-0000-0000-0000-000000001010',
  12000, 'pending'
);

-- Renewal without a previous cycle must fail.
DO $test$
BEGIN
  BEGIN
    INSERT INTO finance.subscription_cycles(
      id, billing_account_id, subscriber_profile_id, entity_id, plan_id,
      annual_sequence, cycle_type, period_start, period_end,
      invoice_id, obligation_id, amount, status
    ) VALUES (
      '00000000-0000-0000-0000-000000001013',
      '00000000-0000-0000-0000-000000001004',
      '00000000-0000-0000-0000-000000001002',
      '00000000-0000-0000-0000-000000001003',
      '00000000-0000-0000-0000-000000001005',
      3, 'renewal_annual', '2028-01-01', '2028-12-31',
      '00000000-0000-0000-0000-000000001007',
      '00000000-0000-0000-0000-000000001009',
      12000, 'pending'
    );
    RAISE EXCEPTION 'expected renewal lineage constraint failure';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END;
$test$;

-- Cycle deletion must fail.
DO $test$
BEGIN
  BEGIN
    DELETE FROM finance.subscription_cycles
     WHERE id = '00000000-0000-0000-0000-000000001011';
    RAISE EXCEPTION 'expected cycle delete guard failure';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    NULL;
  END;
END;
$test$;

-- Finance outbox: same source cannot emit twice, and an idempotency key cannot
-- be reused for another source.
INSERT INTO finance.events(
  id, event_type, source_type, source_id, idempotency_key, payload
) VALUES (
  '00000000-0000-0000-0000-000000001020',
  'finance.subscription.initial_annual.settled',
  'finance.obligation',
  '00000000-0000-0000-0000-000000001009',
  'cycle-event-1',
  '{}'::jsonb
);

DO $test$
BEGIN
  BEGIN
    INSERT INTO finance.events(
      id, event_type, source_type, source_id, idempotency_key, payload
    ) VALUES (
      '00000000-0000-0000-0000-000000001021',
      'finance.subscription.initial_annual.settled',
      'finance.obligation',
      '00000000-0000-0000-0000-000000001009',
      'cycle-event-2',
      '{}'::jsonb
    );
    RAISE EXCEPTION 'expected duplicate source-event failure';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO finance.events(
      id, event_type, source_type, source_id, idempotency_key, payload
    ) VALUES (
      '00000000-0000-0000-0000-000000001022',
      'finance.subscription.initial_annual.settled',
      'finance.obligation',
      '00000000-0000-0000-0000-000000001010',
      'cycle-event-1',
      '{}'::jsonb
    );
    RAISE EXCEPTION 'expected duplicate idempotency-key failure';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;
END;
$test$;

ROLLBACK;

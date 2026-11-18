-- ============================================================================
-- referrals_withdrawal_behavior_test.sql
-- ----------------------------------------------------------------------------
-- Local-only behavioral checks for reward reservation, withdrawal locking,
-- failed-payout release, receipt idempotency and append-only history.
--
-- Run after applying the Refer & Earn migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

UPDATE referrals.program_settings SET foundation_activation_enabled=true;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000002001', 'Testland', 'KE', 'KEN', '254');

INSERT INTO users.profiles(id, first_name, country_id) VALUES
  ('00000000-0000-0000-0000-000000002002', 'Referrer', '00000000-0000-0000-0000-000000002001'),
  ('00000000-0000-0000-0000-000000002003', 'Referred', '00000000-0000-0000-0000-000000002001');

INSERT INTO core.entities(id, name, entity_type, owner_id)
VALUES (
  '00000000-0000-0000-0000-000000002004',
  'Referrer Entity',
  'individual_pro',
  '00000000-0000-0000-0000-000000002002'
);

INSERT INTO finance.obligations(id) VALUES
  ('00000000-0000-0000-0000-000000002005');

INSERT INTO referrals.referrals(
  id, referrer_profile_id, referred_profile_id, referral_code,
  attribution_method, status
) VALUES (
  '00000000-0000-0000-0000-000000002006',
  '00000000-0000-0000-0000-000000002002',
  '00000000-0000-0000-0000-000000002003',
  'TESTCODE', 'code', 'attributed'
);

INSERT INTO referrals.rewards(
  id, referral_id, beneficiary_profile_id, amount, currency, status
) VALUES (
  '00000000-0000-0000-0000-000000002007',
  '00000000-0000-0000-0000-000000002006',
  '00000000-0000-0000-0000-000000002002',
  40, 'KES', 'eligible'
);

INSERT INTO referrals.withdrawal_requests(
  id, beneficiary_profile_id, amount, currency, status, idempotency_key
) VALUES (
  '00000000-0000-0000-0000-000000002008',
  '00000000-0000-0000-0000-000000002002',
  500, 'KES', 'requested', 'withdrawal-behavior-1'
);

INSERT INTO referrals.withdrawal_items(
  id, withdrawal_request_id, reward_id, amount, status
) VALUES (
  '00000000-0000-0000-0000-000000002009',
  '00000000-0000-0000-0000-000000002008',
  '00000000-0000-0000-0000-000000002007',
  40, 'reserved'
);

UPDATE referrals.rewards
   SET status = 'locked',
       withdrawal_request_id = '00000000-0000-0000-0000-000000002008'
 WHERE id = '00000000-0000-0000-0000-000000002007';

-- Second open request for the same beneficiary must fail.
DO $test$
BEGIN
  BEGIN
    INSERT INTO referrals.withdrawal_requests(
      id, beneficiary_profile_id, amount, currency, status, idempotency_key
    ) VALUES (
      '00000000-0000-0000-0000-000000002010',
      '00000000-0000-0000-0000-000000002002',
      500, 'KES', 'requested', 'withdrawal-behavior-2'
    );
    RAISE EXCEPTION 'expected one-open-withdrawal conflict';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;
END;
$test$;

-- A second active reservation of the same reward must fail.
DO $test$
BEGIN
  BEGIN
    INSERT INTO referrals.withdrawal_items(
      id, withdrawal_request_id, reward_id, amount, status
    ) VALUES (
      '00000000-0000-0000-0000-000000002011',
      '00000000-0000-0000-0000-000000002008',
      '00000000-0000-0000-0000-000000002007',
      40, 'reserved'
    );
    RAISE EXCEPTION 'expected duplicate reservation conflict';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE NOT IN ('23505', '55000') THEN
      RAISE;
    END IF;
  END;
END;
$test$;

-- Approval must carry the verified recipient and Finance obligation.
DO $test$
BEGIN
  BEGIN
    UPDATE referrals.withdrawal_requests
       SET status = 'approved',
           version = version + 1
     WHERE id = '00000000-0000-0000-0000-000000002008';
    RAISE EXCEPTION 'expected approval precondition failure';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END;
$test$;

UPDATE referrals.withdrawal_requests
   SET status = 'approved',
       finance_obligation_id = '00000000-0000-0000-0000-000000002005',
       recipient_entity_id = '00000000-0000-0000-0000-000000002004',
       recipient_verified_at = now(),
       recipient_verification = '{"method":"test"}'::jsonb,
       mpesa_receipt = 'TESTRECEIPT1',
       version = version + 1
 WHERE id = '00000000-0000-0000-0000-000000002008';

-- Failed payout must release the item and the reward automatically.
UPDATE referrals.withdrawal_requests
   SET status = 'failed',
       version = version + 1
 WHERE id = '00000000-0000-0000-0000-000000002008';

DO $test$
DECLARE
  v_item_status text;
  v_reward_status text;
  v_reward_request uuid;
BEGIN
  SELECT status INTO v_item_status
    FROM referrals.withdrawal_items
   WHERE id = '00000000-0000-0000-0000-000000002009';

  SELECT status, withdrawal_request_id
    INTO v_reward_status, v_reward_request
    FROM referrals.rewards
   WHERE id = '00000000-0000-0000-0000-000000002007';

  IF v_item_status <> 'released' THEN
    RAISE EXCEPTION 'expected released item, found %', v_item_status;
  END IF;
  IF v_reward_status <> 'eligible' OR v_reward_request IS NOT NULL THEN
    RAISE EXCEPTION 'expected released reward, found %/%', v_reward_status, v_reward_request;
  END IF;
END;
$test$;

-- Duplicate manual M-Pesa receipt must fail.
DO $test$
BEGIN
  BEGIN
    INSERT INTO referrals.withdrawal_requests(
      id, beneficiary_profile_id, amount, currency, status, idempotency_key, mpesa_receipt
    ) VALUES (
      '00000000-0000-0000-0000-000000002012',
      '00000000-0000-0000-0000-000000002003',
      500, 'KES', 'requested', 'withdrawal-behavior-3', 'TESTRECEIPT1'
    );
    RAISE EXCEPTION 'expected duplicate M-Pesa receipt conflict';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;
END;
$test$;

-- Append-only Finance outbox.
INSERT INTO finance.events(
  id, event_type, source_type, source_id, idempotency_key, payload
) VALUES (
  '00000000-0000-0000-0000-000000002020',
  'finance.subscription.initial_annual.settled',
  'finance.obligation',
  '00000000-0000-0000-0000-000000002005',
  'event-behavior-1',
  '{}'::jsonb
);

DO $test$
BEGIN
  BEGIN
    UPDATE finance.events SET event_type = 'changed'
     WHERE id = '00000000-0000-0000-0000-000000002020';
    RAISE EXCEPTION 'expected finance.events immutability failure';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    NULL;
  END;
END;
$test$;

-- Append-only reward event history.
INSERT INTO referrals.reward_events(
  id, reward_id, event_type
) VALUES (
  '00000000-0000-0000-0000-000000002021',
  '00000000-0000-0000-0000-000000002007',
  'test_event'
);

DO $test$
BEGIN
  BEGIN
    UPDATE referrals.reward_events SET event_type = 'changed'
     WHERE id = '00000000-0000-0000-0000-000000002021';
    RAISE EXCEPTION 'expected reward_events immutability failure';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    NULL;
  END;
END;
$test$;

ROLLBACK;

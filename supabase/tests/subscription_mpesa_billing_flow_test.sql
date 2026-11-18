-- ============================================================================
-- subscription_mpesa_billing_flow_test.sql
-- ----------------------------------------------------------------------------
-- LOCAL-ONLY behavior test for the subscription -> Finance M-Pesa bridge.
--
-- Covers:
--   * Finance obligation creation/reuse
--   * payment-attempt linkage to the subscription obligation
--   * successful verified M-Pesa finalization -> subscription activation
--   * failed payment does not activate
--   * repeated confirmation is idempotent
--   * Nairobi midnight UTC conversion and exclusive end boundary
--   * no duplicate payment/ledger truth
--
-- Run only against a disposable local database with the captured Finance
-- schema and subscription migrations applied. Never run against production.
-- ============================================================================

BEGIN;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000008001', 'Subscription Rail Testland', 'KE', 'KEN', '254');

INSERT INTO users.profiles(id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
  ('00000000-0000-0000-0000-000000008002', '00000000-0000-0000-0000-000000008102', 'Rail Subscriber', '00000000-0000-0000-0000-000000008001', true, 'active'),
  ('00000000-0000-0000-0000-000000008003', '00000000-0000-0000-0000-000000008103', 'Other Subscriber', '00000000-0000-0000-0000-000000008001', true, 'active'),
  ('00000000-0000-0000-0000-000000008004', '00000000-0000-0000-0000-000000008104', 'Platform Owner', '00000000-0000-0000-0000-000000008001', true, 'active');

INSERT INTO core.user_roles(id, name, type, is_active)
SELECT '00000000-0000-0000-0000-000000008201', 'owner', 'system', true
WHERE NOT EXISTS (
    SELECT 1 FROM core.user_roles
     WHERE lower(name) = 'owner' AND type = 'system' AND is_active
);

INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata)
VALUES
  ('00000000-0000-0000-0000-000000008005', 'Rail Subscriber Entity', 'individual_pro', '00000000-0000-0000-0000-000000008002', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000008006', 'Other Subscriber Entity', 'individual_pro', '00000000-0000-0000-0000-000000008003', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000008007', 'Subscription Rail Platform', 'trading_company', '00000000-0000-0000-0000-000000008004', true, '{"platform_entity":"true","purpose":"platform_administration"}'::jsonb);

INSERT INTO core.entity_members(entity_id, profile_id, role_id, can_manage, membership_status, is_active)
SELECT entity_id, profile_id,
       (SELECT id FROM core.user_roles
         WHERE lower(name) = 'owner' AND type = 'system' AND is_active
         ORDER BY id LIMIT 1),
       true, 'active', true
  FROM (VALUES
    ('00000000-0000-0000-0000-000000008005'::uuid, '00000000-0000-0000-0000-000000008002'::uuid),
    ('00000000-0000-0000-0000-000000008006'::uuid, '00000000-0000-0000-0000-000000008003'::uuid)
  ) AS members(entity_id, profile_id);

INSERT INTO system.billing_accounts(id, entity_id, profile_id, account_type, status, currency)
VALUES
  ('00000000-0000-0000-0000-000000008008', '00000000-0000-0000-0000-000000008005', '00000000-0000-0000-0000-000000008002', 'individual', 'active', 'KES'),
  ('00000000-0000-0000-0000-000000008009', '00000000-0000-0000-0000-000000008006', '00000000-0000-0000-0000-000000008003', 'individual', 'active', 'KES');

INSERT INTO finance.ledger_accounts(
    entity_id, account_code, account_name, account_type,
    normal_balance, currency, is_active
) VALUES
  ('00000000-0000-0000-0000-000000008007', '1000', 'Rail Test M-Pesa Clearing', 'asset', 'debit', 'KES', true),
  ('00000000-0000-0000-0000-000000008007', '2200', 'Rail Test Deferred Subscription Revenue', 'liability', 'credit', 'KES', true);

INSERT INTO finance.accounting_periods(entity_id, start_date, end_date, status)
VALUES (
  '00000000-0000-0000-0000-000000008007',
  '2026-01-01',
  '2026-12-31',
  'open'
);

DO $test$
DECLARE
    v_plan_id uuid;
    v_cycle_id uuid;
    v_retry_cycle_id uuid;
    v_active_id uuid;
    v_invoice_id uuid;
    v_obligation_id uuid;
    v_attempt_id uuid;
    v_retry_attempt_id uuid;
    v_event_id uuid;
    v_payment_id uuid;
    v_confirm record;
    v_retry_confirm record;
    v_start timestamptz;
    v_end timestamptz;
    v_payment_count bigint;
    v_journal_count bigint;
    v_settlement_count bigint;
    v_failed_cycle_id uuid;
    v_failed_attempt_id uuid;
    v_failed_event_id uuid;
    v_rejected boolean := false;
BEGIN
    SELECT plan_id INTO v_plan_id
      FROM system.create_annual_subscription_plan(
        'subscription-rail-test-plan',
        'Subscription Rail Test Annual',
        12000,
        NULL,
        '{}'::jsonb
      );

    -- Purchase and idempotent reuse: one obligation and one cycle.
    SELECT subscription_cycle_id, active_subscription_id, invoice_id, obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000008008',
        v_plan_id,
        'RAIL-INV-1',
        'rail-purchase-1',
        '2026-12-31',
        NULL
      );

    SELECT subscription_cycle_id INTO v_retry_cycle_id
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000008008',
        v_plan_id,
        'RAIL-INV-1',
        'rail-purchase-1',
        '2026-12-31',
        NULL
      );

    IF v_retry_cycle_id <> v_cycle_id THEN
        RAISE EXCEPTION 'purchase retry returned a different subscription cycle';
    END IF;

    SELECT count(*) INTO v_payment_count
      FROM finance.obligations
     WHERE metadata->>'subscription_cycle_id' = v_cycle_id::text;
    IF v_payment_count <> 1 THEN
        RAISE EXCEPTION 'purchase retry created duplicate Finance obligations';
    END IF;

    -- Nairobi local midnight -> UTC, inclusive start / exclusive end.
    SELECT start_date, end_date INTO v_start, v_end
      FROM system.active_subscriptions WHERE id = v_active_id;
    IF v_start IS DISTINCT FROM '2026-12-30 21:00:00+00'::timestamptz THEN
        RAISE EXCEPTION 'Nairobi start boundary was %, expected 2026-12-30 21:00 UTC', v_start;
    END IF;
    IF v_end IS DISTINCT FROM '2027-12-30 21:00:00+00'::timestamptz THEN
        RAISE EXCEPTION 'Nairobi exclusive end boundary was %, expected 2027-12-30 21:00 UTC', v_end;
    END IF;

    PERFORM set_config(
        'request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000008102',
        true
    );

    -- Start/reuse the payment attempt for this exact cycle obligation.
    SELECT payment_attempt_id INTO v_attempt_id
      FROM finance.request_annual_subscription_mpesa_attempt(
        v_cycle_id,
        '254700000000',
        'rail-attempt-1'
      );

    SELECT payment_attempt_id INTO v_retry_attempt_id
      FROM finance.request_annual_subscription_mpesa_attempt(
        v_cycle_id,
        '254700000000',
        'rail-attempt-1'
      );

    IF v_retry_attempt_id <> v_attempt_id THEN
        RAISE EXCEPTION 'payment-attempt retry returned a different attempt';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM finance.payment_attempts
         WHERE id = v_attempt_id
           AND obligation_id = v_obligation_id
           AND provider = 'mpesa'
           AND amount = 12000
           AND currency = 'KES'
           AND status = 'created'
    ) THEN
        RAISE EXCEPTION 'payment attempt is not linked to the subscription obligation';
    END IF;

    -- A different subscriber cannot start payment for this cycle.
    PERFORM set_config(
        'request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000008103',
        true
    );
    BEGIN
        PERFORM finance.request_annual_subscription_mpesa_attempt(
            v_cycle_id,
            '254700000000',
            'rail-attempt-other'
        );
        RAISE EXCEPTION 'expected non-owner attempt rejection';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
    PERFORM set_config(
        'request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000008102',
        true
    );

    -- Existing generic M-Pesa lifecycle binds checkout and verified evidence.
    PERFORM finance.claim_mpesa_attempt_safe(v_attempt_id);
    PERFORM finance.complete_mpesa_initiation(
        v_attempt_id,
        'RAIL-CHECKOUT-1',
        NULL,
        NULL
    );

    v_event_id := finance.record_mpesa_verification_evidence(
        v_attempt_id,
        'RAIL-EVENT-1',
        'RAIL-RECEIPT-1',
        12000,
        'KES',
        '{"Body":{"stkCallback":{"ResultCode":0,"ResultDesc":"Success","CheckoutRequestID":"RAIL-CHECKOUT-1","CallbackMetadata":{"Item":[{"Name":"MpesaReceiptNumber","Value":"RAIL-RECEIPT-1"},{"Name":"Amount","Value":12000}]}}}}'::jsonb,
        '{"ResponseCode":"0","ResultCode":"0","ResultDesc":"Success","CheckoutRequestID":"RAIL-CHECKOUT-1"}'::jsonb,
        '2026-12-31 10:00:00+00'::timestamptz
    );

    -- Atomic finalize + activation.
    SELECT * INTO v_confirm
      FROM finance.confirm_annual_subscription_payment(
        v_attempt_id,
        v_event_id
      );

    IF v_confirm.status <> 'active' THEN
        RAISE EXCEPTION 'successful payment did not activate subscription';
    END IF;
    IF v_confirm.subscription_cycle_id <> v_cycle_id
       OR v_confirm.active_subscription_id <> v_active_id THEN
        RAISE EXCEPTION 'confirmation returned the wrong subscription identity';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM system.active_subscriptions
         WHERE id = v_active_id
           AND status = 'active'
           AND start_date = '2026-12-30 21:00:00+00'::timestamptz
           AND end_date = '2027-12-30 21:00:00+00'::timestamptz
    ) THEN
        RAISE EXCEPTION 'active subscription entitlement was not activated with stored boundaries';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM system.invoices
         WHERE id = v_invoice_id
           AND status = 'paid'
           AND paid_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'subscription invoice was not marked paid';
    END IF;

    SELECT count(*) INTO v_payment_count
      FROM finance.payments
     WHERE payment_attempt_id = v_attempt_id;
    SELECT count(*) INTO v_settlement_count
      FROM finance.obligation_settlements
     WHERE obligation_id = v_obligation_id;
    SELECT count(*) INTO v_journal_count
      FROM finance.journals
     WHERE source_id = v_confirm.payment_id;
    IF v_payment_count <> 1 OR v_settlement_count <> 1 OR v_journal_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one payment, settlement and journal; found %/%/%',
            v_payment_count, v_settlement_count, v_journal_count;
    END IF;

    -- Duplicate confirmation is idempotent.
    SELECT * INTO v_retry_confirm
      FROM finance.confirm_annual_subscription_payment(
        v_attempt_id,
        v_event_id
      );
    IF v_retry_confirm.payment_id <> v_confirm.payment_id
       OR v_retry_confirm.event_id <> v_confirm.event_id
       OR v_retry_confirm.status <> 'active' THEN
        RAISE EXCEPTION 'duplicate confirmation returned different truth';
    END IF;

    SELECT count(*) INTO v_payment_count FROM finance.payments
     WHERE payment_attempt_id = v_attempt_id;
    SELECT count(*) INTO v_settlement_count FROM finance.obligation_settlements
     WHERE obligation_id = v_obligation_id;
    SELECT count(*) INTO v_journal_count FROM finance.journals
     WHERE source_id = v_confirm.payment_id;
    IF v_payment_count <> 1 OR v_settlement_count <> 1 OR v_journal_count <> 1 THEN
        RAISE EXCEPTION 'duplicate confirmation duplicated payment truth';
    END IF;

    -- Failed payment must not activate a second cycle.
    SELECT subscription_cycle_id, active_subscription_id, invoice_id, obligation_id
      INTO v_failed_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM finance.create_annual_subscription(
        '00000000-0000-0000-0000-000000008008',
        v_plan_id,
        'RAIL-INV-2',
        'rail-purchase-2',
        NULL,
        NULL
      );

    SELECT payment_attempt_id INTO v_failed_attempt_id
      FROM finance.request_annual_subscription_mpesa_attempt(
        v_failed_cycle_id,
        '254700000000',
        'rail-attempt-failed'
      );
    PERFORM finance.claim_mpesa_attempt_safe(v_failed_attempt_id);
    PERFORM finance.complete_mpesa_initiation(
        v_failed_attempt_id,
        'RAIL-CHECKOUT-FAILED',
        NULL,
        NULL
    );
    v_failed_event_id := finance.record_mpesa_definitive_failure(
        v_failed_attempt_id,
        'RAIL-EVENT-FAILED',
        'RAIL-CHECKOUT-FAILED',
        '1032',
        'Request cancelled by user',
        '{"Body":{"stkCallback":{"ResultCode":1032,"ResultDesc":"Request cancelled by user","CheckoutRequestID":"RAIL-CHECKOUT-FAILED","CallbackMetadata":{"Item":[]}}}}'::jsonb,
        '{"ResponseCode":"0","ResultCode":"1032","ResultDesc":"Request cancelled by user","CheckoutRequestID":"RAIL-CHECKOUT-FAILED"}'::jsonb,
        true,
        '2026-12-31 10:05:00+00'::timestamptz
    );

    BEGIN
        PERFORM finance.confirm_annual_subscription_payment(
            v_failed_attempt_id,
            v_failed_event_id
        );
        RAISE EXCEPTION 'expected failed-payment confirmation rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        v_rejected := true;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'failed payment was not rejected';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM finance.subscription_cycles
         WHERE id = v_failed_cycle_id AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'failed payment changed the subscription cycle';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM system.active_subscriptions
         WHERE id = v_active_id AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'failed payment activated the subscription';
    END IF;
END;
$test$;

ROLLBACK;

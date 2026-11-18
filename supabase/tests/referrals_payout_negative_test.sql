-- ============================================================================
-- referrals_payout_negative_test.sql
-- LOCAL-ONLY negative payout reconciliation tests.
-- ============================================================================
BEGIN;

UPDATE referrals.program_settings SET foundation_activation_enabled=true;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('60000000-0000-4000-8000-000000000001', 'Payout Negative Testland', 'ZZ', 'ZZZ', '999', true);
INSERT INTO users.profiles (id, first_name, last_name, email, phone, country_id, is_active, account_status)
VALUES
 ('60000000-0000-4000-8000-000000000002', 'Payout', 'Amount', 'payout-negative-amount@example.invalid', '+254733000002', '60000000-0000-4000-8000-000000000001', true, 'active'),
 ('60000000-0000-4000-8000-000000000004', 'Payout', 'Currency', 'payout-negative-currency@example.invalid', '+254733000004', '60000000-0000-4000-8000-000000000001', true, 'active'),
 ('60000000-0000-4000-8000-000000000005', 'Payout', 'Uncertain', 'payout-negative-uncertain@example.invalid', '+254733000005', '60000000-0000-4000-8000-000000000001', true, 'active'),
 ('60000000-0000-4000-8000-000000000008', 'Payout', 'Admin', 'payout-negative-admin@example.invalid', '+254733000008', '60000000-0000-4000-8000-000000000001', true, 'active');

INSERT INTO core.user_roles (name, type, description, is_active)
SELECT 'Admin', 'administration',
       'Existing platform administration role used by Refer & Earn tests', true
WHERE NOT EXISTS (SELECT 1 FROM core.user_roles WHERE name='Admin');

INSERT INTO core.entity_roles (profile_id, entity_id, role_id, assigned_by, is_active)
SELECT '60000000-0000-4000-8000-000000000008',
       '00000000-0000-4000-8000-000000000104', id,
       '00000000-0000-4000-8000-000000000103', true
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (profile_id, entity_id, role_id) DO NOTHING;

INSERT INTO core.entity_members (entity_id, profile_id, role_id, is_active, membership_status)
SELECT '00000000-0000-4000-8000-000000000104',
       '60000000-0000-4000-8000-000000000008', id, true, 'active'
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (entity_id, profile_id) DO UPDATE
SET role_id = EXCLUDED.role_id, is_active = true, membership_status = 'active';

UPDATE users.profiles SET auth_user_id='70000000-0000-4000-8000-000000000008'
 WHERE id='60000000-0000-4000-8000-000000000008';
SELECT set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000008',true);
INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, metadata)
VALUES
 ('60000000-0000-4000-8000-000000000003', 'Payout Amount Entity', 'individual_pro', '60000000-0000-4000-8000-000000000002', true, '{}'::jsonb),
 ('60000000-0000-4000-8000-000000000006', 'Payout Currency Entity', 'individual_pro', '60000000-0000-4000-8000-000000000004', true, '{}'::jsonb),
 ('60000000-0000-4000-8000-000000000007', 'Payout Uncertain Entity', 'individual_pro', '60000000-0000-4000-8000-000000000005', true, '{}'::jsonb);

DO $wrong_amount$
DECLARE
    v_obligation uuid := '60000000-0000-4000-8000-000000000010';
    v_request uuid := '60000000-0000-4000-8000-000000000011';
    v_rejected boolean := false;
BEGIN
    INSERT INTO finance.obligations (id, payer_entity_id, payee_entity_id, obligation_type, status, amount, currency, idempotency_key, metadata)
    VALUES (v_obligation, '00000000-0000-4000-8000-000000000104', '60000000-0000-4000-8000-000000000003',
            'other', 'open', 500, 'KES', 'neg-wrong-amount-obligation', '{"finance_charge_code":"referral_withdrawal"}'::jsonb);
    INSERT INTO referrals.withdrawal_requests (
        id, beneficiary_profile_id, amount, currency, status, finance_obligation_id,
        recipient_entity_id, recipient_verified_at, idempotency_key, version
    ) VALUES (
        v_request, '60000000-0000-4000-8000-000000000002', 520, 'KES', 'approved', v_obligation,
        '60000000-0000-4000-8000-000000000003', now(), 'neg-wrong-amount-request', 1
    );
    BEGIN
        PERFORM referrals.record_manual_payout(v_request, 'NEG-AMOUNT-1', '{}'::jsonb, now());
    EXCEPTION WHEN SQLSTATE '23514' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'wrong payout amount was not rejected'; END IF;
    IF (SELECT status FROM finance.obligations WHERE id=v_obligation) <> 'open' THEN
        RAISE EXCEPTION 'wrong amount falsely settled obligation';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.payments WHERE obligation_id=v_obligation) THEN
        RAISE EXCEPTION 'wrong amount created a payment';
    END IF;
END;
$wrong_amount$;

DO $wrong_currency$
DECLARE
    v_obligation uuid := '60000000-0000-4000-8000-000000000020';
    v_request uuid := '60000000-0000-4000-8000-000000000021';
    v_rejected boolean := false;
BEGIN
    INSERT INTO finance.obligations (id, payer_entity_id, payee_entity_id, obligation_type, status, amount, currency, idempotency_key, metadata)
    VALUES (v_obligation, '00000000-0000-4000-8000-000000000104', '60000000-0000-4000-8000-000000000006',
            'other', 'open', 520, 'USD', 'neg-wrong-currency-obligation', '{"finance_charge_code":"referral_withdrawal"}'::jsonb);
    INSERT INTO referrals.withdrawal_requests (
        id, beneficiary_profile_id, amount, currency, status, finance_obligation_id,
        recipient_entity_id, recipient_verified_at, idempotency_key, version
    ) VALUES (
        v_request, '60000000-0000-4000-8000-000000000004', 520, 'KES', 'approved', v_obligation,
        '60000000-0000-4000-8000-000000000006', now(), 'neg-wrong-currency-request', 1
    );
    BEGIN
        PERFORM referrals.record_manual_payout(v_request, 'NEG-CURRENCY-1', '{}'::jsonb, now());
    EXCEPTION WHEN SQLSTATE '23514' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'wrong payout currency was not rejected'; END IF;
    IF (SELECT status FROM finance.obligations WHERE id=v_obligation) <> 'open' THEN
        RAISE EXCEPTION 'wrong currency falsely settled obligation';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.payments WHERE obligation_id=v_obligation) THEN
        RAISE EXCEPTION 'wrong currency created a payment';
    END IF;
END;
$wrong_currency$;

DO $uncertain_failed$
DECLARE
    v_obligation uuid := '60000000-0000-4000-8000-000000000030';
    v_request uuid := '60000000-0000-4000-8000-000000000031';
    v_rejected boolean := false;
BEGIN
    INSERT INTO finance.obligations (id, payer_entity_id, payee_entity_id, obligation_type, status, amount, currency, idempotency_key, metadata)
    VALUES (v_obligation, '00000000-0000-4000-8000-000000000104', '60000000-0000-4000-8000-000000000007',
            'other', 'open', 520, 'KES', 'neg-uncertain-obligation', '{"finance_charge_code":"referral_withdrawal"}'::jsonb);
    INSERT INTO referrals.withdrawal_requests (
        id, beneficiary_profile_id, amount, currency, status, finance_obligation_id,
        recipient_entity_id, recipient_verified_at, idempotency_key, version
    ) VALUES (
        v_request, '60000000-0000-4000-8000-000000000005', 520, 'KES', 'uncertain', v_obligation,
        '60000000-0000-4000-8000-000000000007', now(), 'neg-uncertain-request', 1
    );
    BEGIN
        PERFORM referrals.record_manual_payout(v_request, 'NEG-UNCERTAIN-1', '{}'::jsonb, now());
    EXCEPTION WHEN SQLSTATE '55000' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'uncertain payout was not rejected'; END IF;
    IF (SELECT status FROM finance.obligations WHERE id=v_obligation) <> 'open' THEN
        RAISE EXCEPTION 'uncertain payout settled obligation';
    END IF;
    IF (SELECT status FROM referrals.withdrawal_requests WHERE id=v_request) <> 'uncertain' THEN
        RAISE EXCEPTION 'uncertain payout changed request state';
    END IF;
    IF EXISTS (SELECT 1 FROM finance.payments WHERE obligation_id=v_obligation) THEN
        RAISE EXCEPTION 'uncertain payout created a payment';
    END IF;
END;
$uncertain_failed$;

ROLLBACK;

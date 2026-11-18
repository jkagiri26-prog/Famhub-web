-- ============================================================================
-- referrals_foundation_activation_gate_test.sql
-- LOCAL-ONLY Release 1 activation-gate positive and negative tests.
-- ============================================================================
BEGIN;

INSERT INTO users.profiles (id,auth_user_id,first_name,country_id,is_active,account_status)
VALUES
 ('71000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001','Gate Admin',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('71000000-0000-4000-8000-000000000002','72000000-0000-4000-8000-000000000002','Gate User',
  (SELECT id FROM core.countries LIMIT 1),true,'active');

INSERT INTO core.user_roles (name,type,description,is_active)
SELECT 'Admin','administration','Existing platform administration role',true
WHERE NOT EXISTS (SELECT 1 FROM core.user_roles WHERE name='Admin');

INSERT INTO core.entity_roles (profile_id,entity_id,role_id,assigned_by,is_active)
SELECT '71000000-0000-4000-8000-000000000001',
       '00000000-0000-4000-8000-000000000104', id,
       '00000000-0000-4000-8000-000000000103', true
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (profile_id,entity_id,role_id) DO NOTHING;

INSERT INTO core.entity_members (entity_id,profile_id,role_id,is_active,membership_status)
SELECT '00000000-0000-4000-8000-000000000104',
       '71000000-0000-4000-8000-000000000001', id, true, 'active'
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (entity_id,profile_id) DO UPDATE
SET role_id=EXCLUDED.role_id,is_active=true,membership_status='active';

INSERT INTO referrals.referrals (id,referrer_profile_id,referred_profile_id,referral_code,attribution_method,status)
VALUES ('73000000-0000-4000-8000-000000000001',
        '71000000-0000-4000-8000-000000000001',
        '71000000-0000-4000-8000-000000000002',
        'GATE-TEST','code','attributed');

DO $gate$
DECLARE
    v_event uuid;
    v_request uuid;
    v_rejected boolean;
BEGIN
    IF referrals.foundation_activation_enabled() IS NOT FALSE THEN
        RAISE EXCEPTION 'foundation gate did not default to disabled';
    END IF;

    -- Direct reward insert must fail closed.
    v_rejected := false;
    BEGIN
        INSERT INTO referrals.rewards (
            referral_id, beneficiary_profile_id, amount, currency, status
        ) VALUES (
            '73000000-0000-4000-8000-000000000001',
            '71000000-0000-4000-8000-000000000001', 40, 'KES', 'eligible'
        );
    EXCEPTION WHEN SQLSTATE '55000' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'reward insert bypassed disabled gate'; END IF;

    -- Direct withdrawal request insert must fail closed.
    v_rejected := false;
    BEGIN
        INSERT INTO referrals.withdrawal_requests (
            id, beneficiary_profile_id, amount, currency, status, version, idempotency_key
        ) VALUES (
            gen_random_uuid(), '71000000-0000-4000-8000-000000000001',
            500, 'KES', 'requested', 1, 'gate-disabled-withdrawal'
        );
    EXCEPTION WHEN SQLSTATE '55000' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'withdrawal insert bypassed disabled gate'; END IF;

    -- Consumer invocation reaches event_consumptions, which is gated.
    INSERT INTO finance.events (event_type,source_type,source_id,idempotency_key,payload)
    VALUES ('finance.subscription.annual.activated','finance.subscription_cycle',
            gen_random_uuid(), 'gate-disabled-event', '{}'::jsonb)
    RETURNING id INTO v_event;
    v_rejected := false;
    BEGIN
        PERFORM referrals.consume_finance_event(v_event);
    EXCEPTION WHEN SQLSTATE '55000' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'consumer bypassed disabled gate'; END IF;

    -- Ordinary authenticated user cannot enable the gate.
    PERFORM set_config('request.jwt.claim.sub','72000000-0000-4000-8000-000000000002',true);
    v_rejected := false;
    BEGIN
        PERFORM referrals.set_foundation_activation(true);
    EXCEPTION WHEN SQLSTATE '42501' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'ordinary user enabled foundation gate'; END IF;

    -- Active Admin can enable it.
    PERFORM set_config('request.jwt.claim.sub','72000000-0000-4000-8000-000000000001',true);
    PERFORM referrals.set_foundation_activation(true);
    IF referrals.foundation_activation_enabled() IS NOT TRUE THEN
        RAISE EXCEPTION 'Admin could not enable foundation gate';
    END IF;

    -- Create a request while enabled, then disable and prove admin action is blocked.
    INSERT INTO referrals.withdrawal_requests (
        id, beneficiary_profile_id, amount, currency, status, version, idempotency_key
    ) VALUES (
        gen_random_uuid(), '71000000-0000-4000-8000-000000000001',
        500, 'KES', 'requested', 1, 'gate-enabled-fixture'
    ) RETURNING id INTO v_request;
    PERFORM referrals.set_foundation_activation(false);

    v_rejected := false;
    BEGIN
        PERFORM referrals.reject_withdrawal(v_request, 'must be blocked');
    EXCEPTION WHEN SQLSTATE '55000' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'withdrawal action bypassed disabled gate'; END IF;
    IF (SELECT status FROM referrals.withdrawal_requests WHERE id=v_request) <> 'requested' THEN
        RAISE EXCEPTION 'gated withdrawal action changed state';
    END IF;

    IF referrals.foundation_activation_enabled() IS NOT FALSE THEN
        RAISE EXCEPTION 'foundation gate did not fail closed after disable';
    END IF;
END;
$gate$;

ROLLBACK;

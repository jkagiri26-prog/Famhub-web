-- ============================================================================
-- referrals_finance_worker_test.sql
-- LOCAL-ONLY tests for the proposed Finance-event worker gateway and lifecycle.
-- Requires local application of:
--   supabase/proposed/20261114000007_referrals_finance_event_worker.sql
--   supabase/proposed/20261114000008_fix_referrals_consumer_failure_ambiguity.sql
--   supabase/proposed/20261114000009_system_referral_worker_gateway.sql
-- No production/staging access.
-- ============================================================================
BEGIN;

INSERT INTO users.profiles (id,auth_user_id,first_name,country_id,is_active,account_status)
VALUES
 ('71000000-0000-4000-8000-000000000101','72000000-0000-4000-8000-000000000101','Worker Admin',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('71000000-0000-4000-8000-000000000102','72000000-0000-4000-8000-000000000102','Worker Nonadmin',
  (SELECT id FROM core.countries LIMIT 1),true,'active');

INSERT INTO core.user_roles (name,type,description,is_active)
SELECT 'Admin','administration','Existing platform administration role',true
WHERE NOT EXISTS (SELECT 1 FROM core.user_roles WHERE name='Admin');

INSERT INTO core.entity_roles (profile_id,entity_id,role_id,assigned_by,is_active)
SELECT '71000000-0000-4000-8000-000000000101',
       '00000000-0000-4000-8000-000000000104', id,
       '00000000-0000-4000-8000-000000000103', true
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (profile_id,entity_id,role_id) DO NOTHING;

INSERT INTO core.entity_members (entity_id,profile_id,role_id,is_active,membership_status)
SELECT '00000000-0000-4000-8000-000000000104',
       '71000000-0000-4000-8000-000000000101', id, true, 'active'
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (entity_id,profile_id) DO UPDATE
SET role_id=EXCLUDED.role_id,is_active=true,membership_status='active';

UPDATE referrals.program_settings SET foundation_activation_enabled=false;

-- Disabled gate: no event claim and no consumption.
INSERT INTO finance.events (id,event_type,source_type,source_id,idempotency_key,payload)
VALUES ('76000000-0000-4000-8000-000000000001',
        'finance.subscription.annual.activated','finance.subscription_cycle',
        gen_random_uuid(),'worker-disabled-event','{}'::jsonb);

DO $disabled$
DECLARE v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5);
    IF v_result.gate_enabled IS NOT FALSE
       OR v_result.selected_count <> 0
       OR v_result.processed_count <> 0
       OR v_result.failed_count <> 0 THEN
        RAISE EXCEPTION 'worker did not fail closed when gate disabled: %', row_to_json(v_result);
    END IF;
    IF EXISTS (SELECT 1 FROM referrals.event_consumptions
                WHERE finance_event_id='76000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'disabled worker consumed event';
    END IF;
END;
$disabled$;

-- Enable gate for local worker tests only.
UPDATE referrals.program_settings SET foundation_activation_enabled=true;

-- Consumer exception path must retain the real processing error, not the
-- former ambiguous finance_event_id SQL error.
DO $first_attempt$
DECLARE v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5);
    IF v_result.gate_enabled IS NOT TRUE OR v_result.selected_count <> 1 OR v_result.failed_count <> 1 THEN
        RAISE EXCEPTION 'worker did not process malformed event once: %', row_to_json(v_result);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.event_consumptions
                    WHERE finance_event_id='76000000-0000-4000-8000-000000000001'
                      AND status='failed' AND attempts=1
                      AND last_error ILIKE '%Activated subscription cycle not found%') THEN
        RAISE EXCEPTION 'real consumer failure was not retained';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.event_failures
                    WHERE finance_event_id='76000000-0000-4000-8000-000000000001'
                      AND last_error NOT ILIKE '%ambiguous%') THEN
        RAISE EXCEPTION 'failure evidence missing or contains ambiguity error';
    END IF;
END;
$first_attempt$;

-- Immediate duplicate call is skipped by backoff.
DO $backoff$
DECLARE v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5);
    IF v_result.selected_count <> 0 THEN
        RAISE EXCEPTION 'failed event was retried before backoff';
    END IF;
END;
$backoff$;

-- Expire backoff and retry once.
UPDATE referrals.event_consumptions
   SET updated_at = now() - interval '10 minutes'
 WHERE finance_event_id='76000000-0000-4000-8000-000000000001';
DO $retry$
DECLARE v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5);
    IF v_result.selected_count <> 1 OR v_result.failed_count <> 1 THEN
        RAISE EXCEPTION 'failed event was not retried after backoff: %', row_to_json(v_result);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.event_consumptions
                    WHERE finance_event_id='76000000-0000-4000-8000-000000000001'
                      AND attempts=2) THEN
        RAISE EXCEPTION 'retry attempts were not recorded';
    END IF;
END;
$retry$;

-- Maximum-attempt exhaustion creates a dead letter and stops further claims.
INSERT INTO finance.events (id,event_type,source_type,source_id,idempotency_key,payload)
VALUES ('76000000-0000-4000-8000-000000000003',
        'finance.subscription.annual.activated','finance.subscription_cycle',
        gen_random_uuid(),'worker-deadletter-event','{}'::jsonb);
DO $deadletter$
DECLARE v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5, 1);
    IF v_result.selected_count <> 1 OR v_result.failed_count <> 1 THEN
        RAISE EXCEPTION 'dead-letter event was not selected once: %', row_to_json(v_result);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.event_consumptions
                    WHERE finance_event_id='76000000-0000-4000-8000-000000000003'
                      AND attempts=1 AND dead_lettered_at IS NOT NULL) THEN
        RAISE EXCEPTION 'maximum-attempt event was not dead-lettered';
    END IF;
    SELECT * INTO v_result FROM system.process_referral_finance_events(5, 1);
    IF v_result.selected_count <> 0 THEN
        RAISE EXCEPTION 'dead-letter event was reclaimed';
    END IF;
END;
$deadletter$;

-- Unauthorized replay is denied; Admin replay is recorded.
DO $replay_auth$
DECLARE v_rejected boolean := false;
BEGIN
    PERFORM set_config('request.jwt.claim.sub','72000000-0000-4000-8000-000000000102',true);
    BEGIN
        PERFORM system.replay_referral_finance_event(
            '76000000-0000-4000-8000-000000000003', 'unauthorized replay');
    EXCEPTION WHEN SQLSTATE '42501' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'non-admin replayed dead-letter event'; END IF;

    PERFORM set_config('request.jwt.claim.sub','72000000-0000-4000-8000-000000000101',true);
    PERFORM system.replay_referral_finance_event(
        '76000000-0000-4000-8000-000000000003', 'authorized replay');
    IF NOT EXISTS (SELECT 1 FROM referrals.event_consumptions
                    WHERE finance_event_id='76000000-0000-4000-8000-000000000003'
                      AND status='pending' AND attempts=0
                      AND dead_lettered_at IS NULL AND replay_count=1) THEN
        RAISE EXCEPTION 'Admin replay did not reset dead-letter state';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.audit_events
                    WHERE entity_id='76000000-0000-4000-8000-000000000003'
                      AND event_type='finance_event_replayed'
                      AND actor_profile_id='71000000-0000-4000-8000-000000000101') THEN
        RAISE EXCEPTION 'Admin replay was not audited';
    END IF;
END;
$replay_auth$;

-- Stale processing recovery.
INSERT INTO finance.events (id,event_type,source_type,source_id,idempotency_key,payload)
VALUES ('76000000-0000-4000-8000-000000000004',
        'finance.subscription.annual.activated','finance.subscription_cycle',
        gen_random_uuid(),'worker-stale-event','{}'::jsonb);
INSERT INTO referrals.event_consumptions (
    finance_event_id,event_type,status,attempts,last_error,updated_at
) VALUES (
    '76000000-0000-4000-8000-000000000004',
    'finance.subscription.annual.activated','processing',1,'stale claim',
    now() - interval '11 minutes'
);
DO $stale$
DECLARE v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5);
    IF v_result.selected_count <> 1 THEN
        RAISE EXCEPTION 'stale processing event was not reclaimed';
    END IF;
END;
$stale$;

-- Processed events are never reclaimed.
INSERT INTO finance.events (id,event_type,source_type,source_id,idempotency_key,payload)
VALUES ('76000000-0000-4000-8000-000000000005',
        'finance.subscription.annual.activated','finance.subscription_cycle',
        gen_random_uuid(),'worker-processed-event','{}'::jsonb);
INSERT INTO referrals.event_consumptions (
    finance_event_id,event_type,status,attempts,processed_at
) VALUES (
    '76000000-0000-4000-8000-000000000005',
    'finance.subscription.annual.activated','processed',1,now()
);
DO $processed$
DECLARE v_result record;
BEGIN
    SELECT * INTO v_result FROM system.process_referral_finance_events(5);
    IF v_result.selected_count <> 0 THEN
        RAISE EXCEPTION 'processed event was reclaimed';
    END IF;
END;
$processed$;

-- Internal RPC boundary checks.
DO $grants$
BEGIN
    IF NOT has_function_privilege('service_role',
        'system.process_referral_finance_events(integer,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'service role lacks worker gateway grant';
    END IF;
    IF has_function_privilege('authenticated',
        'system.process_referral_finance_events(integer,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated can call worker gateway';
    END IF;
    IF has_function_privilege('anon',
        'system.process_referral_finance_events(integer,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'anon can call worker gateway';
    END IF;
    IF has_function_privilege('service_role',
        'referrals.process_pending_finance_events(integer,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'service role can bypass system gateway';
    END IF;
    IF has_function_privilege('authenticated',
        'referrals.admin_replay_finance_event(uuid,text,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated can call internal replay';
    END IF;
    IF has_function_privilege('service_role',
        'referrals.consume_finance_event_core(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'service role can call private consumer core';
    END IF;
    IF NOT has_function_privilege('authenticated',
        'system.replay_referral_finance_event(uuid,text,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated admin replay gateway missing';
    END IF;
END;
$grants$;

ROLLBACK;

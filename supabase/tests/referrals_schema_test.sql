-- ============================================================================
-- referrals_schema_test.sql
-- ----------------------------------------------------------------------------
-- Structural assertions for the first Refer & Earn migrations.
--
-- This test is intended for a local Supabase database after applying
-- migrations. It is NOT run against the linked production project.
--
-- Run pattern (local only):
--   supabase db reset
--   psql "$LOCAL_DB_URL" -f supabase/tests/referrals_schema_test.sql
-- ============================================================================

BEGIN;

DO $test$
DECLARE
    v_reward numeric;
    v_minimum numeric;
BEGIN
    IF to_regclass('finance.subscription_cycles') IS NULL THEN
        RAISE EXCEPTION 'finance.subscription_cycles is missing';
    END IF;

    IF to_regclass('finance.events') IS NULL THEN
        RAISE EXCEPTION 'finance.events is missing';
    END IF;

    IF to_regclass('system.subscription_event_consumptions') IS NULL THEN
        RAISE EXCEPTION 'system.subscription_event_consumptions is missing';
    END IF;

    IF to_regclass('system.subscription_event_failures') IS NULL THEN
        RAISE EXCEPTION 'system.subscription_event_failures is missing';
    END IF;

    IF to_regclass('referrals.referrals') IS NULL THEN
        RAISE EXCEPTION 'referrals.referrals is missing';
    END IF;

    IF to_regclass('referrals.rewards') IS NULL THEN
        RAISE EXCEPTION 'referrals.rewards is missing';
    END IF;

    IF to_regclass('referrals.event_consumptions') IS NULL THEN
        RAISE EXCEPTION 'referrals.event_consumptions is missing';
    END IF;

    IF to_regclass('referrals.event_failures') IS NULL THEN
        RAISE EXCEPTION 'referrals.event_failures is missing';
    END IF;

    IF to_regclass('referrals.withdrawal_requests') IS NULL THEN
        RAISE EXCEPTION 'referrals.withdrawal_requests is missing';
    END IF;

    IF to_regclass('referrals.withdrawal_items') IS NULL THEN
        RAISE EXCEPTION 'referrals.withdrawal_items is missing';
    END IF;

    IF to_regclass('referrals.withdrawal_events') IS NULL THEN
        RAISE EXCEPTION 'referrals.withdrawal_events is missing';
    END IF;

    SELECT reward_amount, minimum_withdrawal
      INTO v_reward, v_minimum
      FROM referrals.program_settings
     WHERE id = true;

    IF v_reward IS DISTINCT FROM 40 THEN
        RAISE EXCEPTION 'reward_amount must be 40, found %', v_reward;
    END IF;

    IF v_minimum IS DISTINCT FROM 500 THEN
        RAISE EXCEPTION 'minimum_withdrawal must be 500, found %', v_minimum;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_indexes
         WHERE schemaname = 'referrals'
           AND indexname = 'referrals_referred_profile_id_key'
    ) THEN
        RAISE EXCEPTION 'one-referral-per-referred-profile uniqueness is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_indexes
         WHERE schemaname = 'referrals'
           AND indexname = 'withdrawal_items_active_reward_key'
    ) THEN
        RAISE EXCEPTION 'active reward reservation uniqueness is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_indexes
         WHERE schemaname = 'referrals'
           AND indexname = 'withdrawal_requests_one_open_per_beneficiary_key'
    ) THEN
        RAISE EXCEPTION 'one-open-withdrawal-per-beneficiary uniqueness is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_indexes
         WHERE schemaname = 'referrals'
           AND indexname = 'withdrawal_requests_mpesa_receipt_key'
    ) THEN
        RAISE EXCEPTION 'manual M-Pesa receipt uniqueness is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'referrals.rewards'::regclass
           AND conname = 'rewards_referral_id_key'
    ) THEN
        RAISE EXCEPTION 'one-reward-per-referral uniqueness is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'finance.events'::regclass
           AND conname = 'finance_events_source_event_key'
    ) THEN
        RAISE EXCEPTION 'finance outbox source-event idempotency is missing';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM information_schema.columns
         WHERE table_schema = 'finance'
           AND table_name = 'events'
           AND column_name IN ('processed_at', 'processing_error')
    ) THEN
        RAISE EXCEPTION 'finance.events must stay immutable; consumer state belongs in inboxes';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM information_schema.columns
         WHERE table_schema = 'referrals'
           AND table_name = 'event_failures'
           AND column_name = 'resolved_at'
    ) THEN
        RAISE EXCEPTION 'append-only event_failures must not expose a mutable resolution field';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'finance.events'::regclass
           AND tgname = 'finance_events_append_only'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'finance.events append-only trigger is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'finance.subscription_cycles'::regclass
           AND tgname = 'subscription_cycles_no_delete'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'subscription_cycles delete guard is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'finance.events'::regclass
           AND tgname = 'finance_events_no_truncate'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'finance.events truncate guard is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'referrals.reward_events'::regclass
           AND tgname = 'reward_events_append_only'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'reward_events append-only trigger is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'referrals.audit_events'::regclass
           AND tgname = 'audit_events_append_only'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'audit_events append-only trigger is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'referrals.withdrawal_events'::regclass
           AND tgname = 'withdrawal_events_append_only'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'withdrawal_events append-only trigger is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'referrals.event_failures'::regclass
           AND tgname = 'event_failures_append_only'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'event_failures append-only trigger is missing';
    END IF;

    IF to_regprocedure('referrals.guard_withdrawal_item_mutation()') IS NULL THEN
        RAISE EXCEPTION 'withdrawal item guard function is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'referrals.withdrawal_items'::regclass
           AND tgname = 'withdrawal_items_release_reward'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'withdrawal item release trigger is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgrelid = 'referrals.withdrawal_requests'::regclass
           AND tgname = 'withdrawal_requests_release_items'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'withdrawal request release trigger is missing';
    END IF;

    IF to_regprocedure('referrals.guard_withdrawal_request_mutation()') IS NULL THEN
        RAISE EXCEPTION 'withdrawal request guard function is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_class
         WHERE oid = 'referrals.referrals'::regclass
           AND relrowsecurity
    ) THEN
        RAISE EXCEPTION 'RLS is not enabled on referrals.referrals';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_class
         WHERE oid = 'finance.events'::regclass
           AND relrowsecurity
    ) THEN
        RAISE EXCEPTION 'RLS is not enabled on finance.events';
    END IF;

    IF has_table_privilege('authenticated', 'referrals.referrals', 'SELECT')
       OR has_table_privilege('authenticated', 'referrals.referrals', 'INSERT')
       OR has_table_privilege('authenticated', 'referrals.referrals', 'UPDATE')
       OR has_table_privilege('authenticated', 'referrals.referrals', 'DELETE') THEN
        RAISE EXCEPTION 'authenticated must not have direct referrals.referrals table privileges';
    END IF;

    IF has_table_privilege('anon', 'referrals.referrals', 'SELECT')
       OR has_table_privilege('anon', 'referrals.referrals', 'INSERT')
       OR has_table_privilege('anon', 'referrals.referrals', 'UPDATE')
       OR has_table_privilege('anon', 'referrals.referrals', 'DELETE') THEN
        RAISE EXCEPTION 'anon must not have direct referrals.referrals table privileges';
    END IF;

    IF has_table_privilege('service_role', 'finance.events', 'UPDATE')
       OR has_table_privilege('service_role', 'finance.events', 'DELETE')
       OR has_table_privilege('service_role', 'finance.events', 'TRUNCATE') THEN
        RAISE EXCEPTION 'finance.events must be immutable even for service_role';
    END IF;

    IF has_table_privilege('service_role', 'referrals.reward_events', 'UPDATE')
       OR has_table_privilege('service_role', 'referrals.reward_events', 'DELETE')
       OR has_table_privilege('service_role', 'referrals.reward_events', 'TRUNCATE') THEN
        RAISE EXCEPTION 'reward_events must be append-only even for service_role';
    END IF;
END;
$test$;

ROLLBACK;

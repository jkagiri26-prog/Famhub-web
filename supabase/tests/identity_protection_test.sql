-- ============================================================================
-- identity_protection_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE regression test for identity protection.
--
-- DO NOT RUN AGAINST PRODUCTION: Part B performs write attempts inside a
-- transaction that is rolled back, to prove the fail-closed trigger contract.
-- Production validation must remain read-only.
--
-- Contract under test (see supabase/migrations/20261127000001_*):
--   * Human Personal Entity (individual_pro, not platform) is immutable.
--   * Platform administrative identity (metadata platform_entity=true AND
--     purpose=platform_administration) is immutable and cannot be minted or
--     converted into by application users.
--   * Non-protected entities (e.g. trading_company) remain manageable.
--   * Platform admin authorization and commerce.add_owner_entity_role grants
--     are unchanged.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Part A — catalog and contract assertions (safe read-only checks)
-- ----------------------------------------------------------------------------
DO $test$
DECLARE
    v_personal uuid := '01a091cd-1677-7e48-a1ef-7557de117251';
    v_platform uuid := '01a091e6-f283-70b5-9393-813acf541c09';
    v_profile uuid := '01a03733-ce44-7f82-ba8d-d12d97025346';
    v_trading uuid := '01a0b7e4-7057-7d5a-b35a-e2ea70763018';
    v_legacy_farm uuid := '01a09098-2d39-7d09-8030-66ba0ce2d722';
    v_n integer;
BEGIN
    -- Helpers classify identities correctly.
    IF NOT EXISTS (SELECT 1 FROM core.entities WHERE id = v_personal AND core.is_protected_identity(entity_type, metadata)) THEN
        RAISE EXCEPTION 'TEST FAILED: personal entity not classified protected';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core.entities WHERE id = v_platform AND core.is_protected_identity(entity_type, metadata)) THEN
        RAISE EXCEPTION 'TEST FAILED: platform identity not classified protected';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core.entities WHERE id = v_platform AND core.is_platform_administration_identity(metadata)) THEN
        RAISE EXCEPTION 'TEST FAILED: platform metadata contract not recognised';
    END IF;
    IF EXISTS (SELECT 1 FROM core.entities WHERE id = v_trading AND core.is_protected_identity(entity_type, metadata)) THEN
        RAISE EXCEPTION 'TEST FAILED: trading_company wrongly classified protected';
    END IF;
    IF EXISTS (SELECT 1 FROM core.entities WHERE id = v_legacy_farm AND core.is_protected_identity(entity_type, metadata)) THEN
        RAISE EXCEPTION 'TEST FAILED: legacy farm entity wrongly classified protected';
    END IF;

    -- Explicit command-specific RLS policies replace the broad FOR ALL policy.
    IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'core.entities'::regclass AND polname = 'entity_access') THEN
        RAISE EXCEPTION 'TEST FAILED: broad entity_access policy still present';
    END IF;
    SELECT count(*) INTO v_n FROM pg_policy WHERE polrelid = 'core.entities'::regclass AND polname IN
        ('entity_select_access','entity_insert_owner','entity_update_access','entity_delete_access');
    IF v_n <> 4 THEN
        RAISE EXCEPTION 'TEST FAILED: expected 4 explicit entity policies, found %', v_n;
    END IF;
    SELECT count(*) INTO v_n FROM pg_policy WHERE polrelid = 'core.entities'::regclass AND polcmd = '*';
    IF v_n <> 0 THEN
        RAISE EXCEPTION 'TEST FAILED: a FOR ALL policy remains on core.entities';
    END IF;

    -- Protection trigger present and enabled.
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid = 'core.entities'::regclass
          AND tgname = 'trg_protect_identity_entities'
          AND tgenabled = 'O'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: protection trigger missing or disabled';
    END IF;

    -- Platform admin authorization intact.
    IF NOT core.is_platform_admin(v_profile) THEN
        RAISE EXCEPTION 'TEST FAILED: core.is_platform_admin no longer recognises the platform identity';
    END IF;

    -- Platform identity remains active with its metadata, Admin membership and workspace mapping.
    IF NOT EXISTS (
        SELECT 1 FROM core.entities
        WHERE id = v_platform
          AND is_active IS TRUE
          AND metadata->>'platform_entity' = 'true'
          AND metadata->>'purpose' = 'platform_administration'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: platform identity metadata/state changed';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM core.entity_members
        WHERE entity_id = v_platform AND profile_id = v_profile
          AND is_active IS TRUE AND membership_status = 'active'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: platform Admin membership missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM users.user_workspace_entity_contexts c
        JOIN users.user_workspaces uw ON uw.id = c.user_workspace_id
        JOIN system.workspaces w ON w.id = uw.workspace_id
        WHERE c.entity_id = v_platform AND w.key = 'admin' AND c.mode = 'admin' AND c.is_active IS TRUE
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: platform admin workspace mapping missing';
    END IF;

    -- Owner-role helper remains revoked from client roles.
    IF has_function_privilege('anon', 'commerce.add_owner_entity_role(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'commerce.add_owner_entity_role(uuid)', 'EXECUTE')
       OR has_function_privilege('service_role', 'commerce.add_owner_entity_role(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'TEST FAILED: commerce.add_owner_entity_role EXECUTE is not fully revoked';
    END IF;
END
$test$;

-- ----------------------------------------------------------------------------
-- Part B — behavioural contract (write attempts, all rolled back)
-- Disposable environments only. Production: do not run this section.
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'bc2099bb-0030-4ff4-8951-a34cfcf104dc';
SET LOCAL request.jwt.claim.role = 'authenticated';

DO $test$
DECLARE
    v_personal uuid := '01a091cd-1677-7e48-a1ef-7557de117251';
    v_platform uuid := '01a091e6-f283-70b5-9393-813acf541c09';
    v_trading uuid := '01a0b7e4-7057-7d5a-b35a-e2ea70763018';
BEGIN
    -- Personal Entity: rename blocked.
    BEGIN
        UPDATE core.entities SET name = 'renamed' WHERE id = v_personal;
        RAISE EXCEPTION 'TEST FAILED: personal entity rename permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Personal Entity: deactivation blocked.
    BEGIN
        UPDATE core.entities SET is_active = false WHERE id = v_personal;
        RAISE EXCEPTION 'TEST FAILED: personal entity deactivation permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Personal Entity: entity_type change blocked.
    BEGIN
        UPDATE core.entities SET entity_type = 'trading_company' WHERE id = v_personal;
        RAISE EXCEPTION 'TEST FAILED: personal entity type change permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Personal Entity: delete blocked.
    BEGIN
        DELETE FROM core.entities WHERE id = v_personal;
        RAISE EXCEPTION 'TEST FAILED: personal entity delete permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Platform identity: rename blocked.
    BEGIN
        UPDATE core.entities SET name = 'renamed' WHERE id = v_platform;
        RAISE EXCEPTION 'TEST FAILED: platform identity rename permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Platform identity: deactivation blocked.
    BEGIN
        UPDATE core.entities SET is_active = false WHERE id = v_platform;
        RAISE EXCEPTION 'TEST FAILED: platform identity deactivation permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Platform identity: delete blocked.
    BEGIN
        DELETE FROM core.entities WHERE id = v_platform;
        RAISE EXCEPTION 'TEST FAILED: platform identity delete permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Platform metadata contract removal blocked.
    BEGIN
        UPDATE core.entities SET metadata = metadata - 'platform_entity' WHERE id = v_platform;
        RAISE EXCEPTION 'TEST FAILED: platform metadata contract removal permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Conversion of a non-platform entity into the platform identity blocked.
    BEGIN
        UPDATE core.entities
           SET metadata = metadata || '{"platform_entity": true, "purpose": "platform_administration"}'::jsonb
         WHERE id = v_trading;
        RAISE EXCEPTION 'TEST FAILED: conversion into platform identity permitted';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Non-protected entity management remains possible.
    UPDATE core.entities SET name = name || ' (managed)' WHERE id = v_trading;
    IF NOT EXISTS (SELECT 1 FROM core.entities WHERE id = v_trading AND name LIKE '% (managed)') THEN
        RAISE EXCEPTION 'TEST FAILED: legitimate non-protected entity management blocked';
    END IF;
END
$test$;

ROLLBACK;

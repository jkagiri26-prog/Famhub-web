-- ============================================================================
-- 20261127000001_protect_identity_entities
-- ----------------------------------------------------------------------------
-- Vunio identity protection — minimal hardening of the two protected identity
-- classes. No identity data, IDs, roles, mappings, finance references, or
-- metadata are modified by this migration.
--
-- 1. A HUMAN PERSONAL ENTITY is immutable/protected:
--      entity_type = 'individual_pro'
--      AND metadata->>'platform_entity' IS DISTINCT FROM 'true'
--    Application users must not be able to rename it, change its entity_type,
--    deactivate it, or delete it.
--
-- 2. The PLATFORM ADMINISTRATIVE IDENTITY is a documented system exception:
--      metadata->>'platform_entity' = 'true'
--      AND metadata->>'purpose' = 'platform_administration'
--    It is the platform's administrative/accounting identity (see
--    core.is_platform_admin, finance/referral platform-entity lookups,
--    finance.referral_account_settings, platform ledger accounts). It must
--    remain active with its metadata contract, Admin membership and admin
--    workspace mapping intact. Application users must not rename, retype,
--    deactivate, delete, or remove its metadata contract.
--
-- 3. `individual_pro` ALONE is NOT proof that an entity represents a human:
--    production contains this platform identity using entity_type
--    'individual_pro' as a schema workaround (there is no system type yet).
--    Protection therefore distinguishes the metadata contract.
--
-- 4. This migration intentionally does NOT enforce the one-Personal-Entity-
--    per-owner unique index yet (the existing platform identity shares the
--    owner). Uniqueness remains a separately reviewed step.
--
-- Trusted maintenance (service_role JWT, or postgres/supabase_admin and
-- SECURITY DEFINER internal paths) remains possible. The BEFORE trigger is the
-- authoritative fail-closed protection layer; RLS is split into explicit
-- command policies preserving existing access, not used as a silent filter for
-- protected deletes.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Helpers (pure predicates; no table access)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.is_platform_administration_identity(
    p_metadata jsonb
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path TO 'pg_catalog'
AS $fn$
  SELECT COALESCE(p_metadata->>'platform_entity', '') = 'true'
     AND COALESCE(p_metadata->>'purpose', '') = 'platform_administration';
$fn$;

COMMENT ON FUNCTION core.is_platform_administration_identity(jsonb) IS
  'Established platform-administration metadata contract (platform_entity=true AND purpose=platform_administration). Do not change.';

CREATE OR REPLACE FUNCTION core.is_protected_identity(
    p_entity_type text,
    p_metadata jsonb
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path TO 'pg_catalog', 'core'
AS $fn$
  SELECT
    -- Human Personal Entity: individual_pro that is not the platform identity.
    (
      p_entity_type = 'individual_pro'
      AND COALESCE(p_metadata->>'platform_entity', 'false') <> 'true'
    )
    -- Platform identity (any entity_type carrying the platform marker).
    OR COALESCE(p_metadata->>'platform_entity', 'false') = 'true';
$fn$;

COMMENT ON FUNCTION core.is_protected_identity(text, jsonb) IS
  'True for protected identities: human Personal Entities and the platform administrative identity.';

-- ----------------------------------------------------------------------------
-- Fail-closed protection trigger
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.enforce_protected_identity_immutability()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'core'
AS $fn$
DECLARE
  v_actor_role text := COALESCE(auth.role(), '');
  v_old_is_platform boolean;
  v_old_is_protected boolean;
  v_new_is_platform boolean;
  v_identity_label text;
BEGIN
  -- Trusted maintenance paths: service_role JWT, or non-PostgREST roles
  -- (postgres/supabase_admin, including SECURITY DEFINER internal calls whose
  -- current_user is the function owner).
  IF v_actor_role = 'service_role'
     OR current_user NOT IN ('authenticated', 'anon') THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Application users may not mint a platform administrative identity.
    IF (NEW.metadata->>'platform_entity') = 'true'
       OR (NEW.metadata->>'purpose') = 'platform_administration' THEN
      RAISE EXCEPTION
        'VUNIO_PROTECTED_IDENTITY: the platform administration identity is system-managed and cannot be created by application users.'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  v_old_is_platform := core.is_platform_administration_identity(OLD.metadata);
  v_old_is_protected := core.is_protected_identity(OLD.entity_type, OLD.metadata);
  v_identity_label := CASE
    WHEN v_old_is_platform THEN 'platform administration'
    ELSE 'personal'
  END;

  IF TG_OP = 'DELETE' THEN
    IF v_old_is_protected THEN
      RAISE EXCEPTION
        'VUNIO_PROTECTED_IDENTITY: % is a protected % identity and cannot be deleted.',
        OLD.name, v_identity_label
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;

  -- UPDATE
  IF v_old_is_protected THEN
    IF NEW.name IS DISTINCT FROM OLD.name THEN
      RAISE EXCEPTION
        'VUNIO_PROTECTED_IDENTITY: % is a protected % identity; renaming is not permitted.',
        OLD.name, v_identity_label
        USING ERRCODE = '42501';
    END IF;

    IF NEW.entity_type IS DISTINCT FROM OLD.entity_type THEN
      RAISE EXCEPTION
        'VUNIO_PROTECTED_IDENTITY: % is a protected % identity; changing entity_type is not permitted.',
        OLD.name, v_identity_label
        USING ERRCODE = '42501';
    END IF;

    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      RAISE EXCEPTION
        'VUNIO_PROTECTED_IDENTITY: % is a protected % identity; changing is_active is not permitted.',
        OLD.name, v_identity_label
        USING ERRCODE = '42501';
    END IF;

    IF v_old_is_platform THEN
      -- Platform metadata contract is immutable.
      IF (NEW.metadata->>'platform_entity') IS DISTINCT FROM (OLD.metadata->>'platform_entity')
         OR (NEW.metadata->>'purpose') IS DISTINCT FROM (OLD.metadata->>'purpose') THEN
        RAISE EXCEPTION
          'VUNIO_PROTECTED_IDENTITY: % is a protected % identity; the platform metadata contract is immutable.',
          OLD.name, v_identity_label
          USING ERRCODE = '42501';
      END IF;
    ELSE
      -- Personal Entity cannot be converted into the platform identity.
      IF (NEW.metadata->>'platform_entity') = 'true'
         OR (NEW.metadata->>'purpose') = 'platform_administration' THEN
        RAISE EXCEPTION
          'VUNIO_PROTECTED_IDENTITY: an application user may not convert an entity into the platform administration identity.'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  ELSE
    v_new_is_platform := core.is_platform_administration_identity(NEW.metadata);
    IF v_new_is_platform
       OR (NEW.metadata->>'platform_entity') = 'true'
       OR (NEW.metadata->>'purpose') = 'platform_administration' THEN
      RAISE EXCEPTION
        'VUNIO_PROTECTED_IDENTITY: an application user may not convert an entity into the platform administration identity.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION core.enforce_protected_identity_immutability() IS
  'Fail-closed immutability guard for human Personal Entities and the platform administrative identity.';

DROP TRIGGER IF EXISTS trg_protect_identity_entities ON core.entities;
CREATE TRIGGER trg_protect_identity_entities
BEFORE INSERT OR UPDATE OR DELETE ON core.entities
FOR EACH ROW
EXECUTE FUNCTION core.enforce_protected_identity_immutability();

COMMENT ON TRIGGER trg_protect_identity_entities ON core.entities IS
  'Protects Personal Entities and the platform administrative identity from app-level rename/retype/deactivation/deletion. Service-role and internal maintenance bypass.';

-- ----------------------------------------------------------------------------
-- RLS: replace the broad FOR ALL policy with explicit command policies.
-- Semantics preserved for legitimate access:
--   SELECT  — active members (unchanged)
--   INSERT  — caller owns the new row (unchanged WITH CHECK)
--   UPDATE  — active members, owner_id pinned (unchanged)
--   DELETE  — active members (unchanged); the BEFORE trigger is the
--             authoritative fail-closed layer for protected identities.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS entity_access ON core.entities;
DROP POLICY IF EXISTS entity_select_access ON core.entities;
DROP POLICY IF EXISTS entity_insert_owner ON core.entities;
DROP POLICY IF EXISTS entity_update_access ON core.entities;
DROP POLICY IF EXISTS entity_delete_access ON core.entities;

CREATE POLICY entity_select_access
ON core.entities
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM core.entity_members em
    JOIN users.profiles p ON p.id = em.profile_id
    WHERE em.entity_id = entities.id
      AND p.auth_user_id = (SELECT auth.uid())
      AND em.is_active = true
      AND em.membership_status = 'active'
  )
);

CREATE POLICY entity_insert_owner
ON core.entities
FOR INSERT
TO authenticated
WITH CHECK (
  owner_id = (
    SELECT p.id
    FROM users.profiles p
    WHERE p.auth_user_id = (SELECT auth.uid())
    LIMIT 1
  )
);

CREATE POLICY entity_update_access
ON core.entities
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM core.entity_members em
    JOIN users.profiles p ON p.id = em.profile_id
    WHERE em.entity_id = entities.id
      AND p.auth_user_id = (SELECT auth.uid())
      AND em.is_active = true
      AND em.membership_status = 'active'
  )
)
WITH CHECK (
  owner_id = (
    SELECT p.id
    FROM users.profiles p
    WHERE p.auth_user_id = (SELECT auth.uid())
    LIMIT 1
  )
);

CREATE POLICY entity_delete_access
ON core.entities
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM core.entity_members em
    JOIN users.profiles p ON p.id = em.profile_id
    WHERE em.entity_id = entities.id
      AND p.auth_user_id = (SELECT auth.uid())
      AND em.is_active = true
      AND em.membership_status = 'active'
  )
);

COMMIT;

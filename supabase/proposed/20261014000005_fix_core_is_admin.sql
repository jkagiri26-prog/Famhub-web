-- ============================================================================
-- 20261014000005_fix_core_is_admin
-- Phase 0B / SEPARATE -- PREPARED, REQUIRES EXPLICIT APPROVAL BEFORE APPLYING
-- ----------------------------------------------------------------------------
-- WHY THIS IS NOT IN BATCH 1
--   `core.is_admin(uuid)` is referenced by 4 RLS policies on users.profiles.
--   Repairing it changes what those policies allow, so it must be reviewed and
--   approved on its own, separately from the pure-REVOKe batch.
--
-- PROBLEM 1 -- `core.is_admin()` (no argument) trusts client-controlled data
--   Current body:
--       SELECT EXISTS (SELECT 1 FROM auth.users u
--                      WHERE u.id = core.auth_user_id()
--                        AND (u.raw_user_meta_data->>'role') = 'admin');
--   Properties: invoker-rights (prosecdef = false), search_path NOT pinned.
--   `raw_user_meta_data` is set by the client at sign-up / account update, so
--   any authenticated user can self-assert the admin flag.
--   RLS dependants: NONE. pg_policies contains no policy that calls the
--   no-argument form. Therefore redefining it cannot change any access decision.
--
-- PROBLEM 2 -- `core.is_admin(user_uuid uuid)` is dead code that always fails
--   Current body probes for a table `core.roles`, which does not exist, and
--   immediately returns false. It is SECURITY DEFINER with NO search_path pin,
--   so it is also a search-path hijack surface.
--   RLS dependants: exactly 4, all on users.profiles, all formed as
--       (auth_user_id = auth_user_id()) OR is_admin(auth_user_id())
--   i.e. "own row, or the caller is an admin".
--
-- FIX
--   Both overloads delegate to `core.has_permission('admin.overview')`, which
--   is SECURITY DEFINER with a pinned search_path and resolves the role via
--   core.entity_context_sessions -> core.entity_members -> core.role_permissions
--   -> core.entity_role_scopes. It never reads client-writable metadata.
--   The uuid overload additionally requires the supplied uid to be the caller,
--   preserving the "own row" semantics the 4 policies already express.
--
-- IMPACT MEASUREMENT (captured 2026-10-14)
--   users.profiles rows                        : 2 (2 active)
--   core.entity_context_sessions               : 1 active, 274 expired
--   active sessions whose role is "Admin"       : 0
--   -> `has_permission('admin.overview')` is currently false for every user,
--      so this migration changes NO effective access today. It removes the
--      escalation primitive and makes admin provisioning possible later.
--
-- AFFECTED OBJECTS
--   core.is_admin()            -- no dependents
--   core.is_admin(uuid)        -- 4 policies on users.profiles
--   users.profiles.profiles_select_admin
--   users.profiles.profiles_select_owner_admin
--   users.profiles.profiles_update_owner_admin
--   users.profiles.profiles_delete_owner_admin
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION core.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core', 'users', 'auth'
AS $function$
  SELECT core.has_permission('admin.overview');
$function$;

CREATE OR REPLACE FUNCTION core.is_admin(user_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core', 'users', 'auth'
AS $function$
  SELECT user_uuid IS NOT NULL
     AND user_uuid = core.auth_user_id()
     AND core.has_permission('admin.overview');
$function$;

COMMIT;

-- ============================================================================
-- ROLLBACK -- restores the exact prior bodies
-- ============================================================================
-- CREATE OR REPLACE FUNCTION core.is_admin()
-- RETURNS boolean LANGUAGE sql STABLE
-- AS $function$
--   SELECT EXISTS (
--       SELECT 1
--           FROM auth.users u
--               WHERE u.id = core.auth_user_id()
--                     AND (u.raw_user_meta_data->>'role') = 'admin'
--                       );
--                       $function$;
--
-- CREATE OR REPLACE FUNCTION core.is_admin(user_uuid uuid)
-- RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
-- AS $function$
-- DECLARE
--   exists_roles boolean;
--   is_admin boolean := false;
-- BEGIN
--   SELECT EXISTS (
--     SELECT 1 FROM information_schema.tables
--     WHERE table_schema = 'core' AND table_name = 'roles'
--   ) INTO exists_roles;
--   IF NOT exists_roles THEN RETURN false; END IF;
--   BEGIN
--     SELECT EXISTS (
--       SELECT 1 FROM core.roles r
--       WHERE r.user_id = user_uuid AND (r.level IS NOT NULL AND r.level >= 80)
--     ) INTO is_admin;
--   EXCEPTION WHEN undefined_column OR undefined_table THEN
--     RETURN false;
--   END;
--   RETURN is_admin;
-- END; $function$;

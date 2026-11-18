-- ============================================================================
-- 20261114000004_finance_reporting_active_profile_guard
-- ----------------------------------------------------------------------------
-- Ensure Finance reporting requires both:
--   * an active entity membership; and
--   * an active, non-suspended, non-blocked profile.
--
-- The helper remains narrowly scoped and SECURITY DEFINER. Authenticated users
-- still receive no direct access to core.entity_members.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION finance.user_can_read_entity(p_entity_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core', 'users'
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM core.entity_members AS em
      JOIN users.profiles AS p ON p.id = em.profile_id
     WHERE em.entity_id = p_entity_id
       AND em.profile_id = core.current_profile_id()
       AND em.is_active IS TRUE
       AND em.membership_status = 'active'
       AND p.is_active IS TRUE
       AND p.account_status = 'active'
  );
$function$;

REVOKE ALL ON FUNCTION finance.user_can_read_entity(uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION finance.user_can_read_entity(uuid) TO "authenticated", "service_role";

COMMIT;

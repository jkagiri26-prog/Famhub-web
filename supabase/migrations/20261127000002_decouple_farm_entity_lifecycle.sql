-- ============================================================================
-- 20261127000002_decouple_farm_entity_lifecycle
-- ----------------------------------------------------------------------------
-- Removes ONLY the Farm Operation -> Entity lifecycle coupling.
--
-- A Farm is an Operation; deactivating/soft-deleting a Farm must not
-- deactivate the Entity under which it operates. This migration:
--
--   1. drops the trigger tr_sync_farm_entity_status on farm_management.farms;
--   2. drops the now-unreferenced trigger function
--      farm_management.sync_entity_status().
--
-- This migration intentionally does NOT:
--   * modify farm_management.farms data;
--   * modify core.entities data;
--   * change RLS policies or grants;
--   * change Marketplace, Finance or Reputation;
--   * touch farm_add_owner_entity_trigger (unrelated owner-consistency trigger);
--   * touch the legacy entity_type = 'farm' entity;
--   * change any baseline or historical migration.
--
-- No CASCADE is used: if any unexpected dependency on the function exists,
-- the migration fails safely instead of dropping additional objects.
-- Idempotent: both drops use IF EXISTS.
-- ============================================================================

BEGIN;

DROP TRIGGER IF EXISTS tr_sync_farm_entity_status ON farm_management.farms;

DROP FUNCTION IF EXISTS farm_management.sync_entity_status();

COMMIT;

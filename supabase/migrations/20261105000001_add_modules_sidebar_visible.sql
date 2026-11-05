-- ============================================================================
-- 20261105000001_add_modules_sidebar_visible
-- ----------------------------------------------------------------------------
-- The desktop primary sidebar reads system.modules through:
--   ModuleService.getActiveModules -> SystemModule.fromMap
--     -> sidebarNavItemsProvider (nav_config.dart)
-- and filters with:
--   if (forSidebar && !module.sidebarVisible) continue;
--
-- `system.modules` never had a `sidebar_visible` column, so
-- SystemModule.fromMap defaulted it to false for every row and the
-- desktop sidebar contained only the static Dashboard item.
--
-- This migration:
--   * adds `sidebar_visible` (default false), and
--   * backfills it to true only for modules the existing workspace catalog
--     (WorkspaceDashboardCatalog) already promotes into a workspace and
--     that are currently enabled.
--
-- It does NOT change is_enabled, dashboard_visible, maintenance_mode,
-- subscription, role or any other existing column, and does NOT insert
-- module rows. Ordering stays on the existing `sort_order` column; the
-- model maps it via a display_order -> sort_order fallback.
--
-- `commerce` is the current backend identity of the Trader workspace module
-- (registered in the app as `trader`). It is included here so it becomes
-- visible once the separate commerce -> trader nav identity fix lands; until
-- then it remains filtered out by workspace scoping.
-- ============================================================================

BEGIN;

ALTER TABLE system.modules
    ADD COLUMN IF NOT EXISTS sidebar_visible boolean NOT NULL DEFAULT false;

UPDATE system.modules
SET sidebar_visible = true
WHERE is_enabled = true
  AND module_key IN (
    -- Farmer workspace promotions
    'farm_management',
    'finance',
    'logistics',
    'extension_services',
    'knowledge',
    'agri_connect',
    -- Shared (workspace-agnostic) modules
    'marketplace',
    'traceability',
    -- Trader workspace (backend key; pending identity canonicalisation)
    'commerce',
    -- Admin workspace
    'admin_console'
  );

COMMIT;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- ALTER TABLE system.modules DROP COLUMN IF EXISTS sidebar_visible;

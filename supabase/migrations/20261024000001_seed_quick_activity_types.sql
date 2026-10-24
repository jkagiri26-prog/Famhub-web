-- ============================================================================
-- 20261024000001_seed_quick_activity_types
-- ----------------------------------------------------------------------------
-- The Record Activity quick form hardcodes activity chips whose keys must
-- resolve to a real farm_management.activity_types row (create_activity
-- rejects unknown/inactive types). The live catalog was missing every
-- catch-all and several standard rows, so submitting those chips failed
-- with "Unknown activity type: other|general|planting|inspection|..."
--
-- Adds the missing rows idempotently (activity_types.name is UNIQUE).
-- Categories are aligned with the client-side scope filter
-- (crop | livestock | general):
--   * 'Crop'        → offered only for crop activities
--   * 'general'     → offered for both crop and livestock activities
-- Existing rows are left untouched.
-- ============================================================================

BEGIN;

INSERT INTO farm_management.activity_types (name, category, description, is_active)
VALUES
  ('General',    'general', 'Catch-all for everyday farm activities', true),
  ('Planting',   'Crop',    'Sowing seeds or transplanting seedlings', true),
  ('Inspection', 'general', 'Scouting or checking crop/livestock condition', true),
  ('Transport',  'general', 'Moving produce, supplies, or animals', true),
  ('Maintenance','general', 'Equipment, infrastructure, or facility upkeep', true),
  ('Other',      'general', 'Any activity that does not fit another type', true)
ON CONFLICT (name) DO NOTHING;

COMMIT;

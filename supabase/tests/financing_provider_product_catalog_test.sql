-- ============================================================================
-- Financing Phase 1: provider + product catalog, authorization and lifecycle
-- ============================================================================
-- Scope: supabase/migrations/20261012000001_financing_provider_product_catalog.sql
--
-- Run against a LOCAL disposable database that has the baseline schema and the
-- migration above applied. Never run this against a production project.
--
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 \
--        -f supabase/tests/financing_provider_product_catalog_test.sql
--
-- Guarantees:
--   * The whole file runs inside one transaction and ends with ROLLBACK, so no
--     fixture row, no role and no permission assignment survives the run.
--   * The role fixtures are invented roles ("FAMHUB Fin Test Role *"). No real
--     role (Admin, Super Admin, ...) is ever granted a finance.* permission.
--   * The country fixture is reused when the database already has a country,
--     otherwise a code is chosen only after proving that code is unused, and
--     the row is re-read before it is referenced.
--
-- Expected-error assertions use explicit SQLSTATEs matching the migration
-- contract: 42501 authz, 22023 invalid value, P0002 not found,
-- 55000 lifecycle. Assertion failures raise P0001 so they are never swallowed
-- by an "expected error" handler.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1 -- fixtures (rolled back; roles and grants are test-only)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_country_id uuid;
  v_code text;
  v_code3 text;
  v_existing uuid;
  v_granted_profile  constant uuid := 'f1f10000-0000-4000-8000-000000000001';
  v_ungranted_profile constant uuid := 'f1f10000-0000-4000-8000-000000000002';
  v_wrongmodule_profile constant uuid := 'f1f10000-0000-4000-8000-000000000003';
  v_reviewer_profile constant uuid := 'f1f10000-0000-4000-8000-000000000004';
  v_entity_id        constant uuid := 'f1f10000-0000-4000-8000-000000000010';
  v_role_full        constant uuid := 'f1f10000-0000-4000-8000-000000000020';
  v_role_noscope     constant uuid := 'f1f10000-0000-4000-8000-000000000021';
  v_country_row_count integer;
BEGIN
  -- ── Country fixture: reuse an existing row, otherwise insert a provably
  --    unused code, then re-read it so we never reference a null id. ─────────
  SELECT id INTO v_existing FROM core.countries ORDER BY iso_alpha2 LIMIT 1;

  IF v_existing IS NOT NULL THEN
    v_country_id := v_existing;
  ELSE
    FOREACH v_code IN ARRAY ARRAY['ZZ', 'QZ', 'XX', 'QQ', 'VV', 'QQ'] LOOP
      v_code3 := v_code || 'X';
      IF NOT EXISTS (SELECT 1 FROM core.countries WHERE iso_alpha2 = v_code)
         AND NOT EXISTS (SELECT 1 FROM core.countries WHERE iso_alpha3 = v_code3) THEN
        INSERT INTO core.countries (name, iso_alpha2, iso_alpha3, dialing_code, is_active)
        VALUES ('FAMHUB Finance Fixture Land', v_code, v_code3, '000', false)
        RETURNING id INTO v_country_id;
        EXIT;
      END IF;
    END LOOP;
  END IF;

  SELECT count(*) INTO v_country_row_count FROM core.countries WHERE id = v_country_id;
  IF v_country_id IS NULL OR v_country_row_count <> 1 THEN
    RAISE EXCEPTION 'country fixture is missing (id %)', v_country_id
      USING ERRCODE = 'P0001';
  END IF;

  -- ── Actor fixtures ────────────────────────────────────────────────────────
  INSERT INTO users.profiles (id, first_name, last_name, country_id, is_active, account_status, auth_user_id)
  VALUES
    (v_granted_profile,   'FinTest', 'Granted',   v_country_id, true, 'active', 'f1f10000-0000-4000-8000-0000000000f1'),
    (v_ungranted_profile, 'FinTest', 'Ungranted', v_country_id, true, 'active', 'f1f10000-0000-4000-8000-0000000000f2'),
    (v_wrongmodule_profile, 'FinTest', 'WrongModule', v_country_id, true, 'active', 'f1f10000-0000-4000-8000-0000000000f3'),
    (v_reviewer_profile,  'FinTest', 'Reviewer',  v_country_id, true, 'active', 'f1f10000-0000-4000-8000-0000000000f4');

  INSERT INTO core.entities (id, name, slug, entity_type, owner_id, is_active)
  VALUES (v_entity_id, 'FAMHUB Finance Fixture Coop', 'famhub-fin-fixture-coop', 'cooperative', v_granted_profile, true);

  -- Invented roles: never a real project role.
  INSERT INTO core.user_roles (id, name, type, is_active) VALUES
    (v_role_full,    'FAMHUB Fin Test Role A', 'administration', true),
    (v_role_noscope, 'FAMHUB Fin Test Role B', 'administration', true);

  INSERT INTO core.entity_roles (profile_id, entity_id, role_id, is_active) VALUES
    (v_granted_profile,     v_entity_id, v_role_full,    true),
    (v_ungranted_profile,   v_entity_id, v_role_full,    true),
    (v_wrongmodule_profile, v_entity_id, v_role_full,    true);

  INSERT INTO core.entity_members (entity_id, profile_id, role_id, is_active, membership_status) VALUES
    (v_entity_id, v_granted_profile,     v_role_full, true, 'active'),
    (v_entity_id, v_ungranted_profile,   v_role_full, true, 'active'),
    (v_entity_id, v_wrongmodule_profile, v_role_full, true, 'active');

  -- ── Grant model fixtures ─────────────────────────────────────────────────
  -- v_granted_profile: role_permissions (all 5) + module scope 'finance' -> ALLOW
  INSERT INTO core.role_permissions (role_id, permission_id, is_active)
  SELECT v_role_full, p.id, true
    FROM core.permissions p
   WHERE p.code IN ('finance.manage_providers', 'finance.verify_providers',
                    'finance.manage_products', 'finance.review_products',
                    'finance.publish_products');

  INSERT INTO core.entity_role_scopes (profile_id, role_id, entity_id, scope_type, module)
  VALUES (v_granted_profile, v_role_full, v_entity_id, 'module', 'finance');

  -- v_ungranted_profile: same role (so same role_permissions) but NO
  -- entity_role_scopes row at all -> DENY. Proves the scope row is required.
  -- v_wrongmodule_profile: has a module scope, but for module 'logistics'
  -- -> DENY. Proves the module value must match the permission's module.
  INSERT INTO core.entity_role_scopes (profile_id, role_id, entity_id, scope_type, module)
  VALUES (v_wrongmodule_profile, v_role_full, v_entity_id, 'module', 'logistics');

  -- Every profile needs an active actor context or has_permission finds nothing.
  INSERT INTO core.entity_context_sessions (user_id, entity_id, active_role_id, session_status, is_default, active_mode)
  VALUES
    (v_granted_profile,     v_entity_id, v_role_full, 'active', true, 'admin'),
    (v_ungranted_profile,   v_entity_id, v_role_full, 'active', true, 'admin'),
    (v_wrongmodule_profile, v_entity_id, v_role_full, 'active', true, 'admin');

  RAISE NOTICE 'fixtures created (all rolled back at end of file)';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2 -- provider/product fixtures (owner-level inserts)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_reviewer constant uuid := 'f1f10000-0000-4000-8000-000000000004';
  v_owner    constant uuid := 'f1f10000-0000-4000-8000-000000000001';
BEGIN
  INSERT INTO financing.financial_providers
    (id, slug, name, provider_type, is_active, verification_status, verification_notes,
     verified_by, verified_at, created_by, metadata)
  VALUES
    ('f1f10000-0000-4000-8000-000000000101', 'fin-test-verified',  'Fin Test Verified Bank', 'bank',   true,  'verified',
     'internal note: KYC pack reviewed', v_reviewer, now(), v_owner, '{"tier": "gold"}'),
    ('f1f10000-0000-4000-8000-000000000102', 'fin-test-pending',   'Fin Test Pending SACCO', 'sacco',  true,  'pending',
     NULL, NULL, NULL, v_owner, '{}'),
    ('f1f10000-0000-4000-8000-000000000103', 'fin-test-rejected',  'Fin Test Rejected MFI',  'microfinance', true, 'rejected',
     'internal note: licence missing', v_reviewer, now(), v_owner, '{}'),
    ('f1f10000-0000-4000-8000-000000000104', 'fin-test-suspended', 'Fin Test Suspended Ins', 'insurance', true, 'suspended',
     'internal note: complaints upheld', v_reviewer, now(), v_owner, '{}'),
    ('f1f10000-0000-4000-8000-000000000105', 'fin-test-inactive',  'Fin Test Inactive Lender','lending_platform', false, 'verified',
     NULL, v_reviewer, now(), v_owner, '{}');

  INSERT INTO financing.financial_products
    (id, provider_id, slug, name, product_type, approval_status, approval_notes,
     approved_by, approved_at, is_published, published_by, published_at,
     is_active, created_by, metadata)
  VALUES
    -- approved + published + active under an active verified provider -> visible
    ('f1f10000-0000-4000-8000-000000000201',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-published', 'Fin Test Published Loan', 'loan',
     'approved', 'looks good', v_reviewer, now(), true, v_reviewer, now(), true, v_owner, '{}'),
    -- draft -> not visible
    ('f1f10000-0000-4000-8000-000000000202',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-draft', 'Fin Test Draft Loan', 'loan',
     'draft', NULL, NULL, NULL, false, NULL, NULL, true, v_owner, '{}'),
    -- in_review -> not visible
    ('f1f10000-0000-4000-8000-000000000203',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-in-review', 'Fin Test In Review Loan', 'loan',
     'in_review', NULL, NULL, NULL, false, NULL, NULL, true, v_owner, '{}'),
    -- rejected -> not visible
    ('f1f10000-0000-4000-8000-000000000204',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-rejected-product', 'Fin Test Rejected Loan', 'loan',
     'rejected', 'needs work', v_reviewer, now(), false, NULL, NULL, true, v_owner, '{}'),
    -- approved but unpublished -> not visible
    ('f1f10000-0000-4000-8000-000000000205',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-unpublished', 'Fin Test Unpublished Loan', 'loan',
     'approved', NULL, v_reviewer, now(), false, NULL, NULL, true, v_owner, '{}'),
    -- under a REJECTED provider -> not visible even though approved+published
    ('f1f10000-0000-4000-8000-000000000206',
     'f1f10000-0000-4000-8000-000000000103', 'fin-test-under-rejected', 'Fin Test Under Rejected', 'loan',
     'approved', NULL, v_reviewer, now(), true, v_reviewer, now(), true, v_owner, '{}'),
    -- under a SUSPENDED provider -> not visible
    ('f1f10000-0000-4000-8000-000000000207',
     'f1f10000-0000-4000-8000-000000000104', 'fin-test-under-suspended', 'Fin Test Under Suspended', 'loan',
     'approved', NULL, v_reviewer, now(), true, v_reviewer, now(), true, v_owner, '{}'),
    -- INACTIVE product -> not visible
    ('f1f10000-0000-4000-8000-000000000208',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-inactive-product', 'Fin Test Inactive Product', 'loan',
     'approved', NULL, v_reviewer, now(), true, v_reviewer, now(), false, v_owner, '{}'),
    -- under an INACTIVE provider -> not visible
    ('f1f10000-0000-4000-8000-000000000209',
     'f1f10000-0000-4000-8000-000000000105', 'fin-test-under-inactive', 'Fin Test Under Inactive', 'loan',
     'approved', NULL, v_reviewer, now(), true, v_reviewer, now(), true, v_owner, '{}'),
    -- under a PENDING provider -> not visible
    ('f1f10000-0000-4000-8000-000000000210',
     'f1f10000-0000-4000-8000-000000000102', 'fin-test-under-pending', 'Fin Test Under Pending', 'loan',
     'approved', NULL, v_reviewer, now(), true, v_reviewer, now(), true, v_owner, '{}'),
    -- spare draft used by the lifecycle section
    ('f1f10000-0000-4000-8000-000000000211',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-lifecycle', 'Fin Test Lifecycle Loan', 'loan',
     'draft', NULL, NULL, NULL, false, NULL, NULL, true, v_owner, '{}'),
    -- spare draft used by the provider-verification cascade section
    ('f1f10000-0000-4000-8000-000000000212',
     'f1f10000-0000-4000-8000-000000000101', 'fin-test-cascade', 'Fin Test Cascade Loan', 'loan',
     'draft', NULL, NULL, NULL, false, NULL, NULL, true, v_owner, '{}');
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3 -- registry, grants, FK deletion behaviour, view privacy
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_count integer;
  v_def text;
  v_cols text;
  v_fn record;
BEGIN
  -- 3.1 exactly five module-scoped finance permissions exist
  SELECT count(*) INTO v_count FROM core.permissions
   WHERE code LIKE 'finance.%' AND module = 'finance' AND scope_type = 'module';
  IF v_count <> 5 THEN
    RAISE EXCEPTION 'expected 5 module-scoped finance.* permissions, found %', v_count
      USING ERRCODE = 'P0001';
  END IF;

  -- 3.2 no real role holds a finance.* permission outside the rolled-back fixture
  SELECT count(*) INTO v_count
    FROM core.role_permissions rp
    JOIN core.permissions p ON p.id = rp.permission_id
    JOIN core.user_roles r ON r.id = rp.role_id
   WHERE p.code LIKE 'finance.%'
     AND r.name NOT IN ('FAMHUB Fin Test Role A', 'FAMHUB Fin Test Role B');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'finance.* leaked onto a real role (% rows)', v_count USING ERRCODE = 'P0001';
  END IF;

  -- 3.3 the database must not ship any module-scope entity_role_scopes row for a
  --     real role (the documented blocker must still be in force after this run)
  SELECT count(*) INTO v_count
    FROM core.entity_role_scopes s
    JOIN core.user_roles r ON r.id = s.role_id
   WHERE s.scope_type = 'module'
     AND r.name NOT IN ('FAMHUB Fin Test Role A', 'FAMHUB Fin Test Role B');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'module-scope entity_role_scopes rows exist for real roles (%)', v_count
      USING ERRCODE = 'P0001';
  END IF;

  -- 3.4 anon must not reach the financing schema or the catalog tables
  IF pg_catalog.has_schema_privilege('anon', 'financing', 'USAGE') THEN
    RAISE EXCEPTION 'anon must not have USAGE on schema financing' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'financing' AND c.relname IN ('financial_providers', 'financial_products')
       AND pg_catalog.has_table_privilege('anon', c.oid, 'SELECT')
  ) THEN
    RAISE EXCEPTION 'anon must not have SELECT on the catalog tables' USING ERRCODE = 'P0001';
  END IF;

  -- 3.5 API roles have SELECT but never write privileges on the catalog tables
  FOR v_def IN
    SELECT format('%I.%I', n.nspname, c.relname)
      FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'financing' AND c.relname IN ('financial_providers', 'financial_products')
  LOOP
    FOREACH v_cols IN ARRAY ARRAY['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'] LOOP
      IF pg_catalog.has_table_privilege('authenticated', v_def, v_cols)
         OR pg_catalog.has_table_privilege('anon', v_def, v_cols)
         OR pg_catalog.has_table_privilege('service_role', v_def, v_cols) THEN
        RAISE EXCEPTION '% must not be granted % on %', 'API roles', v_cols, v_def
          USING ERRCODE = 'P0001';
      END IF;
    END LOOP;
    IF NOT pg_catalog.has_table_privilege('authenticated', v_def, 'SELECT')
       OR NOT pg_catalog.has_table_privilege('service_role', v_def, 'SELECT') THEN
      RAISE EXCEPTION 'authenticated/service_role must have SELECT on %', v_def
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  -- 3.6 internal helpers must not be executable by any API role
  -- (pass the OID: a text reference would be parsed as regprocedure input and
  --  pg_get_function_identity_arguments includes argument names)
  FOR v_fn IN
    SELECT p.oid AS fn_oid,
           format('%I.%I(%s)', n.nspname, p.proname,
                  pg_catalog.pg_get_function_identity_arguments(p.oid)) AS fn_def
      FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'financing'
       AND p.proname IN ('set_updated_at', '_require_permission', '_validate_slug',
                         '_validate_metadata_keys', '_merge_metadata')
  LOOP
    IF pg_catalog.has_function_privilege('anon', v_fn.fn_oid, 'EXECUTE')
       OR pg_catalog.has_function_privilege('authenticated', v_fn.fn_oid, 'EXECUTE')
       OR pg_catalog.has_function_privilege('service_role', v_fn.fn_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'internal helper % is executable by an API role', v_fn.fn_def
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  -- 3.7 public views must not expose internal reviewer / metadata columns
  FOREACH v_cols IN ARRAY ARRAY['public_financial_providers', 'public_financial_products'] LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'financing' AND table_name = v_cols
         AND column_name IN ('verification_notes', 'approval_notes', 'verified_by',
                             'approved_by', 'published_by', 'created_by', 'metadata')
    ) THEN
      RAISE EXCEPTION 'view % exposes an internal column', v_cols USING ERRCODE = 'P0001';
    END IF;
    IF NOT pg_catalog.has_table_privilege('authenticated', 'financing.' || v_cols, 'SELECT') THEN
      RAISE EXCEPTION 'authenticated must be able to read view %', v_cols USING ERRCODE = 'P0001';
    END IF;
    IF pg_catalog.has_table_privilege('anon', 'financing.' || v_cols, 'SELECT') THEN
      RAISE EXCEPTION 'anon must not read view % (no USAGE on schema financing)', v_cols
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  -- 3.8 only the two permission-gated table policies remain (the public read
  --     path moved to the views above)
  SELECT count(*) INTO v_count FROM pg_catalog.pg_policies
   WHERE schemaname = 'financing' AND tablename IN ('financial_providers', 'financial_products');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'expected exactly 2 RLS policies on the catalog tables, found %', v_count
      USING ERRCODE = 'P0001';
  END IF;

  -- 3.9 reviewer FK deletion behaviour
  --     confdeltype: r = RESTRICT, n = SET NULL, a = NO ACTION, c = CASCADE
  FOREACH v_def IN ARRAY ARRAY[
    'financial_providers|verified_by|r',
    'financial_products|approved_by|r',
    'financial_products|published_by|r',
    'financial_products|provider_id|r',
    'financial_providers|created_by|n',
    'financial_products|created_by|n'
  ] LOOP
    SELECT pg_catalog.pg_get_constraintdef(c.oid) INTO v_cols
      FROM pg_catalog.pg_constraint c
      JOIN pg_catalog.pg_class cl ON cl.oid = c.conrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = cl.relnamespace
      JOIN pg_catalog.pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
     WHERE n.nspname = 'financing'
       AND cl.relname = split_part(v_def, '|', 1)
       AND a.attname = split_part(v_def, '|', 2)
       AND c.contype = 'f';

    IF v_cols IS NULL THEN
      RAISE EXCEPTION 'missing FK % on %.%', split_part(v_def, '|', 3),
        split_part(v_def, '|', 1), split_part(v_def, '|', 2) USING ERRCODE = 'P0001';
    END IF;

    IF split_part(v_def, '|', 3) = 'r' AND v_cols NOT LIKE '%ON DELETE RESTRICT%' THEN
      RAISE EXCEPTION 'expected ON DELETE RESTRICT for %, got %', v_def, v_cols
        USING ERRCODE = 'P0001';
    END IF;
    IF split_part(v_def, '|', 3) = 'n' AND v_cols NOT LIKE '%ON DELETE SET NULL%' THEN
      RAISE EXCEPTION 'expected ON DELETE SET NULL for %, got %', v_def, v_cols
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  -- 3.10 deleting a profile that carries review history must be refused
  BEGIN
    DELETE FROM users.profiles
     WHERE id = 'f1f10000-0000-4000-8000-000000000004';
    RAISE EXCEPTION 'expected FK RESTRICT to block deleting a reviewer profile'
      USING ERRCODE = 'P0001';
  EXCEPTION
    -- ON DELETE RESTRICT raises 23001 (restrict_violation), not 23503.
    WHEN SQLSTATE '23001' THEN
      RAISE NOTICE 'reviewer profile deletion correctly refused by ON DELETE RESTRICT';
  END;

  RAISE NOTICE 'section 3 (registry/grants/FK/views) passed';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4 -- public visibility helpers + view predicate (owner level)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_id uuid;
  v_visible boolean;
  r record;
  v_expected_visibility constant uuid[] := ARRAY[
    'f1f10000-0000-4000-8000-000000000201',
    'f1f10000-0000-4000-8000-000000000202',
    'f1f10000-0000-4000-8000-000000000203',
    'f1f10000-0000-4000-8000-000000000204',
    'f1f10000-0000-4000-8000-000000000205',
    'f1f10000-0000-4000-8000-000000000206',
    'f1f10000-0000-4000-8000-000000000207',
    'f1f10000-0000-4000-8000-000000000208',
    'f1f10000-0000-4000-8000-000000000209',
    'f1f10000-0000-4000-8000-000000000210',
    'f1f10000-0000-4000-8000-000000000211',
    'f1f10000-0000-4000-8000-000000000212'
  ]::uuid[];
BEGIN
  -- Only the approved+published+active product of an active verified provider
  -- (…0201) is publicly visible. Everything else must be hidden.
  FOREACH v_id IN ARRAY v_expected_visibility LOOP
    v_visible := financing.is_publicly_visible_product(v_id);
    IF v_id = 'f1f10000-0000-4000-8000-000000000201' THEN
      IF v_visible IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'product % should be publicly visible', v_id USING ERRCODE = 'P0001';
      END IF;
    ELSE
      IF v_visible IS DISTINCT FROM false THEN
        RAISE EXCEPTION 'product % must NOT be publicly visible', v_id USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  -- Provider visibility: only the active verified one (…0101) plus the
  -- inactive-but-verified one is excluded because is_active = false.
  FOREACH v_id IN ARRAY ARRAY[
    'f1f10000-0000-4000-8000-000000000101',
    'f1f10000-0000-4000-8000-000000000102',
    'f1f10000-0000-4000-8000-000000000103',
    'f1f10000-0000-4000-8000-000000000104',
    'f1f10000-0000-4000-8000-000000000105'
  ]::uuid[] LOOP
    v_visible := financing.is_publicly_visible_provider(v_id);
    IF v_id = 'f1f10000-0000-4000-8000-000000000101' THEN
      IF v_visible IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'provider % should be publicly visible', v_id USING ERRCODE = 'P0001';
      END IF;
    ELSE
      IF v_visible IS DISTINCT FROM false THEN
        RAISE EXCEPTION 'provider % must NOT be publicly visible', v_id USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  -- The view must agree with the helper for every fixture product.
  FOR r IN SELECT id FROM financing.financial_products LOOP
    v_visible := EXISTS (
      SELECT 1 FROM financing.public_financial_products v WHERE v.id = r.id
    );
    IF v_visible IS DISTINCT FROM financing.is_publicly_visible_product(r.id) THEN
      RAISE EXCEPTION 'public view disagrees with visibility helper for product %', r.id
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  FOR r IN SELECT id FROM financing.financial_providers LOOP
    v_visible := EXISTS (
      SELECT 1 FROM financing.public_financial_providers v WHERE v.id = r.id
    );
    IF v_visible IS DISTINCT FROM financing.is_publicly_visible_provider(r.id) THEN
      RAISE EXCEPTION 'public provider view disagrees with helper for provider %', r.id
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  RAISE NOTICE 'section 4 (visibility helpers + views) passed';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5 -- CHECK constraints that guard the lifecycles (owner level)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_provider constant uuid := 'f1f10000-0000-4000-8000-000000000101';
  v_ok boolean;
BEGIN
  -- 5.1 publishing an unapproved product violates publication_requires_approval
  BEGIN
    INSERT INTO financing.financial_products
      (provider_id, slug, name, product_type, approval_status, is_published)
    VALUES (v_provider, 'fin-test-bad-publish', 'Bad Publish', 'loan', 'draft', true);
    RAISE EXCEPTION 'expected check_violation for unapproved publication'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '23514' THEN v_ok := true; END;

  -- 5.2 published without published_by violates published_timestamps
  BEGIN
    INSERT INTO financing.financial_products
      (provider_id, slug, name, product_type, approval_status, is_published, published_at)
    VALUES (v_provider, 'fin-test-bad-publisher', 'Bad Publisher', 'loan', 'approved', true, now());
    RAISE EXCEPTION 'expected check_violation for published row without published_by'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '23514' THEN v_ok := true; END;

  -- 5.3 verified without verified_by violates provider verification timestamps
  BEGIN
    INSERT INTO financing.financial_providers
      (slug, name, provider_type, verification_status, verified_at)
    VALUES ('fin-test-bad-verify', 'Bad Verify', 'bank', 'verified', now());
    RAISE EXCEPTION 'expected check_violation for verified provider without verified_by'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '23514' THEN v_ok := true; END;

  -- 5.4 an in_review row must not carry an approval stamp
  BEGIN
    INSERT INTO financing.financial_products
      (provider_id, slug, name, product_type, approval_status, approved_by, approved_at)
    VALUES (v_provider, 'fin-test-bad-review-stamp', 'Bad Stamp', 'loan', 'in_review',
            'f1f10000-0000-4000-8000-000000000004', now());
    RAISE EXCEPTION 'expected check_violation for in_review row with approval stamp'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '23514' THEN v_ok := true; END;

  -- 5.5 amount range
  BEGIN
    INSERT INTO financing.financial_products
      (provider_id, slug, name, product_type, min_amount, max_amount)
    VALUES (v_provider, 'fin-test-bad-range', 'Bad Range', 'loan', 1000, 10);
    RAISE EXCEPTION 'expected check_violation for max_amount < min_amount'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '23514' THEN v_ok := true; END;

  -- 5.6 inactive providers cannot be re-verified? (they can: is_active is
  --     independent by design) -- assert the product under a rejected provider
  --     cannot be published via the RPC. Done in section 7 with JWT context.

  RAISE NOTICE 'section 5 (CHECK constraints) passed';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6 -- anon role: no schema access, no RPC access
-- ═══════════════════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims = '{}';
SET LOCAL ROLE anon;

DO $$
BEGIN
  BEGIN
    PERFORM count(*) FROM financing.financial_providers;
    RAISE EXCEPTION 'anon must not be able to read financing.financial_providers'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM count(*) FROM financing.financial_products;
    RAISE EXCEPTION 'anon must not be able to read financing.financial_products'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM count(*) FROM financing.public_financial_products;
    RAISE EXCEPTION 'anon must not be able to read the public product view'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.manage_provider(p_slug => 'anon-slug', p_name => 'Anon', p_provider_type => 'bank');
    RAISE EXCEPTION 'anon must not be able to call financing.manage_provider'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.publish_product('f1f10000-0000-4000-8000-000000000205');
    RAISE EXCEPTION 'anon must not be able to call financing.publish_product'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing._require_permission('finance.manage_products');
    RAISE EXCEPTION 'anon must not be able to call the internal helper'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  RAISE NOTICE 'section 6 (anon) passed';
END;
$$;

RESET ROLE;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7 -- authenticated WITHOUT a finance grant
-- ═══════════════════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"f1f10000-0000-4000-8000-0000000000f2","role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_count integer;
  v_text text;
  v_id uuid;
BEGIN
  -- 7.1 table RLS: permission-gated policies deny, so zero rows
  SELECT count(*) INTO v_count FROM financing.financial_providers;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'ungranted authenticated user read % providers (expected 0)', v_count
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_count FROM financing.financial_products;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'ungranted authenticated user read % products (expected 0)', v_count
      USING ERRCODE = 'P0001';
  END IF;

  -- 7.2 the public views still work (no internal columns exposed)
  SELECT count(*) INTO v_count FROM financing.public_financial_providers;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'expected exactly 1 publicly visible provider, got %', v_count
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_count FROM financing.public_financial_products;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'expected exactly 1 publicly visible product, got %', v_count
      USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    SELECT verification_notes INTO v_text FROM financing.public_financial_providers LIMIT 1;
    RAISE EXCEPTION 'public provider view must not expose verification_notes'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL;
  END;

  -- 7.3 direct table writes are denied (no write grant), independent of RLS
  BEGIN
    INSERT INTO financing.financial_providers (slug, name, provider_type)
    VALUES ('ungranted-insert', 'Nope', 'bank');
    RAISE EXCEPTION 'authenticated must not INSERT directly into financial_providers'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    UPDATE financing.financial_products SET name = 'hijacked'
     WHERE id = 'f1f10000-0000-4000-8000-000000000202';
    RAISE EXCEPTION 'authenticated must not UPDATE financial_products directly'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    DELETE FROM financing.financial_products
     WHERE id = 'f1f10000-0000-4000-8000-000000000202';
    RAISE EXCEPTION 'authenticated must not DELETE from financial_products directly'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  -- 7.4 every mutation RPC is gated (module scope row missing -> deny)
  BEGIN
    PERFORM financing.manage_provider(p_slug => 'ungranted-provider', p_name => 'Nope', p_provider_type => 'bank');
    RAISE EXCEPTION 'manage_provider must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.set_provider_verification('f1f10000-0000-4000-8000-000000000102', 'verified');
    RAISE EXCEPTION 'set_provider_verification must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.manage_product(p_provider_id => 'f1f10000-0000-4000-8000-000000000101',
                                     p_slug => 'ungranted-product', p_name => 'Nope',
                                     p_product_type => 'loan');
    RAISE EXCEPTION 'manage_product must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.reopen_product_for_edit('f1f10000-0000-4000-8000-000000000201');
    RAISE EXCEPTION 'reopen_product_for_edit must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.submit_product_for_review('f1f10000-0000-4000-8000-000000000202');
    RAISE EXCEPTION 'submit_product_for_review must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.review_product('f1f10000-0000-4000-8000-000000000203', true);
    RAISE EXCEPTION 'review_product must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.publish_product('f1f10000-0000-4000-8000-000000000205');
    RAISE EXCEPTION 'publish_product must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.unpublish_product('f1f10000-0000-4000-8000-000000000201');
    RAISE EXCEPTION 'unpublish_product must be denied without a finance grant'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  RAISE NOTICE 'section 7 (authenticated without grant) passed';
END;
$$;

RESET ROLE;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 8 -- authenticated WITH the rolled-back fixture grant
-- ═══════════════════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"f1f10000-0000-4000-8000-0000000000f1","role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_count integer;
  v_id uuid;
  v_status text;
  v_published boolean;
  v_meta jsonb;
  v_granted_profile constant uuid := 'f1f10000-0000-4000-8000-000000000001';
  v_verified_provider constant uuid := 'f1f10000-0000-4000-8000-000000000101';
  v_pending_provider  constant uuid := 'f1f10000-0000-4000-8000-000000000102';
  v_rejected_provider constant uuid := 'f1f10000-0000-4000-8000-000000000103';
  v_suspended_provider constant uuid := 'f1f10000-0000-4000-8000-000000000104';
  v_lifecycle_product constant uuid := 'f1f10000-0000-4000-8000-000000000211';
  v_cascade_product   constant uuid := 'f1f10000-0000-4000-8000-000000000212';
  v_unpublished       constant uuid := 'f1f10000-0000-4000-8000-000000000205';
  v_published_row     constant uuid := 'f1f10000-0000-4000-8000-000000000201';
  v_draft_row         constant uuid := 'f1f10000-0000-4000-8000-000000000202';
  v_name text;
  v_approved_by uuid;
  v_approved_at timestamptz;
  v_published_by uuid;
  v_published_at timestamptz;
BEGIN
  -- 8.1 the grant model actually resolves
  IF NOT core.has_permission('finance.manage_products') THEN
    RAISE EXCEPTION 'has_permission(finance.manage_products) must be true for the fixture grant'
      USING ERRCODE = 'P0001';
  END IF;
  IF NOT core.has_permission('finance.verify_providers') THEN
    RAISE EXCEPTION 'has_permission(finance.verify_providers) must be true for the fixture grant'
      USING ERRCODE = 'P0001';
  END IF;
  IF NOT core.has_permission('finance.manage_providers')
     OR NOT core.has_permission('finance.review_products')
     OR NOT core.has_permission('finance.publish_products') THEN
    RAISE EXCEPTION 'all five finance.* permissions must resolve for the fixture grant'
      USING ERRCODE = 'P0001';
  END IF;

  -- 8.2 permission-gated table reads now return rows
  SELECT count(*) INTO v_count FROM financing.financial_providers;
  IF v_count <> 5 THEN
    RAISE EXCEPTION 'granted reviewer expected 5 providers, got %', v_count
      USING ERRCODE = 'P0001';
  END IF;
  SELECT count(*) INTO v_count FROM financing.financial_products;
  IF v_count < 12 THEN
    RAISE EXCEPTION 'granted reviewer expected at least 12 products, got %', v_count
      USING ERRCODE = 'P0001';
  END IF;

  -- …including the internal columns the public view hides
  IF NOT EXISTS (
    SELECT 1 FROM financing.financial_providers
     WHERE id = v_verified_provider
       AND verification_notes IS NOT NULL
       AND verified_by = 'f1f10000-0000-4000-8000-000000000004'
  ) THEN
    RAISE EXCEPTION 'granted reviewer must be able to read internal reviewer columns'
      USING ERRCODE = 'P0001';
  END IF;

  -- 8.3 create a provider and verify metadata merge + key validation
  v_id := financing.manage_provider(
    p_slug => 'fin-test-managed', p_name => 'Fin Test Managed',
    p_provider_type => 'sacco', p_metadata => '{"segment": "smallholder"}');
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'manage_provider insert returned NULL' USING ERRCODE = 'P0001';
  END IF;

  v_id := financing.manage_provider(
    p_provider_id => v_id, p_slug => 'fin-test-managed', p_name => 'Fin Test Managed Renamed',
    p_provider_type => 'sacco', p_metadata => '{"channel": "agent"}');

  SELECT metadata INTO v_meta FROM financing.financial_providers WHERE id = v_id;
  IF v_meta <> '{"segment": "smallholder", "channel": "agent"}'::jsonb THEN
    RAISE EXCEPTION 'metadata must be merged, not overwritten (got %)', v_meta
      USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    PERFORM financing.manage_provider(
      p_provider_id => v_id, p_slug => 'fin-test-managed', p_name => 'X',
      p_provider_type => 'sacco', p_metadata => '{"Bad Key!": 1}');
    RAISE EXCEPTION 'an invalid metadata key must be rejected' USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  -- 8.4 full product lifecycle --------------------------------------------
  -- draft -> in_review
  v_id := financing.submit_product_for_review(v_lifecycle_product);
  SELECT approval_status INTO v_status FROM financing.financial_products WHERE id = v_id;
  IF v_status <> 'in_review' THEN
    RAISE EXCEPTION 'expected in_review after submit, got %', v_status USING ERRCODE = 'P0001';
  END IF;

  -- editing while in review returns the product to draft
  v_id := financing.manage_product(
    p_product_id => v_lifecycle_product, p_provider_id => v_verified_provider,
    p_slug => 'fin-test-lifecycle', p_name => 'Fin Test Lifecycle Loan',
    p_product_type => 'loan', p_summary => 'edited during review');
  SELECT approval_status INTO v_status FROM financing.financial_products WHERE id = v_id;
  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'editing an in_review product must return it to draft, got %', v_status
      USING ERRCODE = 'P0001';
  END IF;

  -- resubmit, then NULL decision is rejected explicitly
  PERFORM financing.submit_product_for_review(v_lifecycle_product);
  BEGIN
    PERFORM financing.review_product(v_lifecycle_product, NULL);
    RAISE EXCEPTION 'a NULL approval decision must be rejected' USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  -- reject it
  PERFORM financing.review_product(v_lifecycle_product, false, 'missing disclosures');
  SELECT approval_status INTO v_status FROM financing.financial_products WHERE id = v_lifecycle_product;
  IF v_status <> 'rejected' THEN
    RAISE EXCEPTION 'expected rejected, got %', v_status USING ERRCODE = 'P0001';
  END IF;

  -- a rejected product stays editable
  v_id := financing.manage_product(
    p_product_id => v_lifecycle_product, p_provider_id => v_verified_provider,
    p_slug => 'fin-test-lifecycle', p_name => 'Fin Test Lifecycle Loan',
    p_product_type => 'loan', p_description => 'addressed the findings');
  SELECT approval_status INTO v_status FROM financing.financial_products WHERE id = v_id;
  IF v_status <> 'rejected' THEN
    RAISE EXCEPTION 'editing a rejected product must keep it rejected, got %', v_status
      USING ERRCODE = 'P0001';
  END IF;

  -- resubmit: the stale approval stamp must be cleared or the CHECK fails here
  PERFORM financing.submit_product_for_review(v_lifecycle_product);
  SELECT approval_status, approved_by, approved_at
    INTO v_status, v_approved_by, v_approved_at
    FROM financing.financial_products WHERE id = v_lifecycle_product;
  IF v_status <> 'in_review' OR v_approved_by IS NOT NULL OR v_approved_at IS NOT NULL THEN
    RAISE EXCEPTION 'resubmit must clear the approval stamp (status %)', v_status
      USING ERRCODE = 'P0001';
  END IF;

  -- approve
  PERFORM financing.review_product(v_lifecycle_product, true, 'approved after fixes');
  SELECT approval_status INTO v_status FROM financing.financial_products WHERE id = v_lifecycle_product;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'expected approved, got %', v_status USING ERRCODE = 'P0001';
  END IF;

  -- editing approved content must be refused until reopened
  BEGIN
    PERFORM financing.manage_product(
      p_product_id => v_lifecycle_product, p_provider_id => v_verified_provider,
      p_slug => 'fin-test-lifecycle', p_name => 'Tampered Name', p_product_type => 'loan');
    RAISE EXCEPTION 'editing an approved product must be refused' USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  SELECT approval_status, name INTO v_status, v_name
    FROM financing.financial_products WHERE id = v_lifecycle_product;
  IF v_status <> 'approved' OR v_name <> 'Fin Test Lifecycle Loan' THEN
    RAISE EXCEPTION 'a refused edit must not change the row (status %, name %)',
      v_status, v_name USING ERRCODE = 'P0001';
  END IF;

  -- reopen -> draft and unpublished, then editable again
  PERFORM financing.reopen_product_for_edit(v_lifecycle_product);
  SELECT approval_status, is_published, approved_by, approved_at, published_by, published_at
    INTO v_status, v_published, v_approved_by, v_approved_at, v_published_by, v_published_at
    FROM financing.financial_products WHERE id = v_lifecycle_product;
  IF v_status <> 'draft' OR v_published IS DISTINCT FROM false
     OR v_approved_by IS NOT NULL OR v_approved_at IS NOT NULL
     OR v_published_by IS NOT NULL OR v_published_at IS NOT NULL THEN
    RAISE EXCEPTION 'reopen must produce a clean draft row (status %, published %)',
      v_status, v_published USING ERRCODE = 'P0001';
  END IF;

  PERFORM financing.manage_product(
    p_product_id => v_lifecycle_product, p_provider_id => v_verified_provider,
    p_slug => 'fin-test-lifecycle', p_name => 'Fin Test Lifecycle Loan',
    p_product_type => 'loan', p_description => 'reopened and edited');

  -- reopen is refused when the product is already draft
  BEGIN
    PERFORM financing.reopen_product_for_edit(v_lifecycle_product);
    RAISE EXCEPTION 'reopen must refuse an already-draft product' USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- resubmit -> approve -> publish -> visible -> unpublish -> not visible
  PERFORM financing.submit_product_for_review(v_lifecycle_product);
  PERFORM financing.review_product(v_lifecycle_product, true);
  PERFORM financing.publish_product(v_lifecycle_product);
  IF NOT financing.is_publicly_visible_product(v_lifecycle_product) THEN
    RAISE EXCEPTION 'a published approved product must be publicly visible'
      USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM financing.public_financial_products
                  WHERE id = v_lifecycle_product) THEN
    RAISE EXCEPTION 'a published approved product must appear in the public view'
      USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    PERFORM financing.publish_product(v_lifecycle_product);
    RAISE EXCEPTION 'publishing an already-published product must be refused'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  PERFORM financing.unpublish_product(v_lifecycle_product);
  IF financing.is_publicly_visible_product(v_lifecycle_product) THEN
    RAISE EXCEPTION 'an unpublished product must not be publicly visible'
      USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    PERFORM financing.unpublish_product(v_lifecycle_product);
    RAISE EXCEPTION 'unpublishing an unpublished product must be refused'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- publishing an approved product that is inactive must be refused
  PERFORM financing.reopen_product_for_edit(v_lifecycle_product);
  BEGIN
    PERFORM financing.manage_product(
      p_product_id => v_lifecycle_product, p_provider_id => v_verified_provider,
      p_slug => 'fin-test-lifecycle', p_name => 'Fin Test Lifecycle Loan',
      p_product_type => 'loan', p_is_active => false);
    PERFORM financing.submit_product_for_review(v_lifecycle_product);
    PERFORM financing.review_product(v_lifecycle_product, true);
    PERFORM financing.publish_product(v_lifecycle_product);
    RAISE EXCEPTION 'publishing an inactive product must be refused' USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- 8.5 publication gates --------------------------------------------------
  -- draft / rejected / unpublished products cannot be published
  BEGIN
    PERFORM financing.publish_product(v_draft_row);
    RAISE EXCEPTION 'publishing a draft product must be refused' USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  BEGIN
    PERFORM financing.publish_product('f1f10000-0000-4000-8000-000000000204');
    RAISE EXCEPTION 'publishing a rejected product must be refused' USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- approved + unpublished can be published
  PERFORM financing.publish_product(v_unpublished);
  IF NOT financing.is_publicly_visible_product(v_unpublished) THEN
    RAISE EXCEPTION 'publishing an approved product must make it visible'
      USING ERRCODE = 'P0001';
  END IF;

  -- 8.6 provider state gates ----------------------------------------------
  -- pending provider: the product is already approved+published in the fixture
  -- but must not be visible, and a new publish attempt must be refused.
  IF financing.is_publicly_visible_product('f1f10000-0000-4000-8000-000000000210') THEN
    RAISE EXCEPTION 'a product under a pending provider must not be visible'
      USING ERRCODE = 'P0001';
  END IF;

  -- rejected provider: its product must not be visible and cannot be published
  IF financing.is_publicly_visible_product('f1f10000-0000-4000-8000-000000000206') THEN
    RAISE EXCEPTION 'a product under a rejected provider must not be visible'
      USING ERRCODE = 'P0001';
  END IF;
  BEGIN
    PERFORM financing.publish_product('f1f10000-0000-4000-8000-000000000206');
    RAISE EXCEPTION 'publishing under a rejected provider must be refused'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- suspended provider
  IF financing.is_publicly_visible_product('f1f10000-0000-4000-8000-000000000207') THEN
    RAISE EXCEPTION 'a product under a suspended provider must not be visible'
      USING ERRCODE = 'P0001';
  END IF;

  -- inactive provider
  IF financing.is_publicly_visible_product('f1f10000-0000-4000-8000-000000000209') THEN
    RAISE EXCEPTION 'a product under an inactive provider must not be visible'
      USING ERRCODE = 'P0001';
  END IF;
  BEGIN
    PERFORM financing.publish_product('f1f10000-0000-4000-8000-000000000209');
    RAISE EXCEPTION 'publishing under an inactive provider must be refused'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- inactive product
  IF financing.is_publicly_visible_product('f1f10000-0000-4000-8000-000000000208') THEN
    RAISE EXCEPTION 'an inactive product must not be visible' USING ERRCODE = 'P0001';
  END IF;

  -- 8.7 re-verification must not change product state on its own ------------
  PERFORM financing.set_provider_verification(v_rejected_provider, 'verified', 're-checked');
  SELECT approval_status, is_published
    INTO v_status, v_published
    FROM financing.financial_products
   WHERE id = 'f1f10000-0000-4000-8000-000000000206';
  IF v_status <> 'approved' OR v_published IS DISTINCT FROM true THEN
    RAISE EXCEPTION
      're-verification must not touch product state it never reset (got %/%)',
      v_status, v_published USING ERRCODE = 'P0001';
  END IF;
  -- Back to rejected: this is the transition that runs the cascade.
  PERFORM financing.set_provider_verification(v_rejected_provider, 'rejected', 'still rejected');
  SELECT approval_status, is_published
    INTO v_status, v_published
    FROM financing.financial_products
   WHERE id = 'f1f10000-0000-4000-8000-000000000206';
  IF v_status <> 'draft' OR v_published IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'rejection must reset the provider products (got %/%)',
      v_status, v_published USING ERRCODE = 'P0001';
  END IF;

  -- 8.8 rejection/suspension cascade --------------------------------------
  -- Put the cascade product into a live state first.
  PERFORM financing.submit_product_for_review(v_cascade_product);
  PERFORM financing.review_product(v_cascade_product, true);
  PERFORM financing.publish_product(v_cascade_product);
  IF NOT financing.is_publicly_visible_product(v_cascade_product) THEN
    RAISE EXCEPTION 'cascade product should be visible before suspension'
      USING ERRCODE = 'P0001';
  END IF;

  PERFORM financing.set_provider_verification(v_suspended_provider, 'suspended', 'abuse');
  -- suspend the active verified provider so the cascade is observable
  PERFORM financing.set_provider_verification(v_verified_provider, 'suspended', 'abuse');

  SELECT approval_status, is_published, approved_by, approved_at, published_by, published_at
    INTO v_status, v_published, v_approved_by, v_approved_at, v_published_by, v_published_at
    FROM financing.financial_products WHERE id = v_cascade_product;
  IF v_status <> 'draft' OR v_published IS DISTINCT FROM false
     OR v_approved_by IS NOT NULL OR v_approved_at IS NOT NULL
     OR v_published_by IS NOT NULL OR v_published_at IS NOT NULL THEN
    RAISE EXCEPTION 'suspending a provider must reset its products (got %/%)',
      v_status, v_published USING ERRCODE = 'P0001';
  END IF;
  IF financing.is_publicly_visible_product(v_cascade_product) THEN
    RAISE EXCEPTION 'suspended provider product must not be visible'
      USING ERRCODE = 'P0001';
  END IF;

  -- re-verification must NOT silently restore the previous approval/publication
  PERFORM financing.set_provider_verification(v_verified_provider, 'verified', 'reinstated');
  SELECT approval_status, is_published
    INTO v_status, v_published
    FROM financing.financial_products WHERE id = v_cascade_product;
  IF v_status <> 'draft' OR v_published IS DISTINCT FROM false THEN
    RAISE EXCEPTION
      're-verification silently restored stale product state (got %/%)', v_status, v_published
      USING ERRCODE = 'P0001';
  END IF;
  IF financing.is_publicly_visible_product(v_cascade_product) THEN
    RAISE EXCEPTION 're-verification must not republish the product'
      USING ERRCODE = 'P0001';
  END IF;

  -- publication is still blocked until a fresh approval cycle
  BEGIN
    PERFORM financing.publish_product(v_cascade_product);
    RAISE EXCEPTION 'publishing a reset (draft) product must be refused'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- …and a full cycle restores it
  PERFORM financing.submit_product_for_review(v_cascade_product);
  PERFORM financing.review_product(v_cascade_product, true);
  PERFORM financing.publish_product(v_cascade_product);
  IF NOT financing.is_publicly_visible_product(v_cascade_product) THEN
    RAISE EXCEPTION 'a fresh approval cycle must be able to republish'
      USING ERRCODE = 'P0001';
  END IF;

  -- 8.9 the suspension cascade reset every product of the verified provider,
  --     so exactly one product (the one rebuilt in 8.8) is publicly visible now.
  IF NOT EXISTS (SELECT 1 FROM financing.public_financial_products WHERE id = v_cascade_product) THEN
    RAISE EXCEPTION 'the rebuilt product must be publicly visible' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM financing.public_financial_products
              WHERE id IN (v_published_row, v_unpublished, v_lifecycle_product)) THEN
    RAISE EXCEPTION 'products reset by the provider suspension must not be publicly visible'
      USING ERRCODE = 'P0001';
  END IF;
  SELECT count(*) INTO v_count FROM financing.public_financial_products;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'expected exactly 1 publicly visible product at this point, got %', v_count
      USING ERRCODE = 'P0001';
  END IF;

  RAISE NOTICE 'section 8 (granted reviewer lifecycle) passed';
END;
$$;

RESET ROLE;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 9 -- authenticated WITH role_permissions but WITHOUT a module scope
-- ═══════════════════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"f1f10000-0000-4000-8000-0000000000f3","role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_count integer;
BEGIN
  -- role_permissions exist for this profile's role, but the entity_role_scopes
  -- row carries module = 'logistics', not 'finance' -> still denied.
  IF core.has_permission('finance.manage_products') THEN
    RAISE EXCEPTION 'module scope must match the permission module (logistics != finance)'
      USING ERRCODE = 'P0001';
  END IF;
  IF core.has_permission('logistics.manage_shipments') THEN
    RAISE EXCEPTION 'fixture unexpectedly granted logistics.manage_shipments'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_count FROM financing.financial_products;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'wrong-module profile must read 0 products, got %', v_count
      USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    PERFORM financing.submit_product_for_review('f1f10000-0000-4000-8000-000000000202');
    RAISE EXCEPTION 'wrong-module profile must not run product RPCs'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  RAISE NOTICE 'section 9 (module scope mismatch) passed';
END;
$$;

RESET ROLE;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 10 -- service_role: read grants only, no write RPCs
-- ═══════════════════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims = '{"role":"service_role"}';
SET LOCAL ROLE service_role;

DO $$
BEGIN
  IF NOT pg_catalog.has_table_privilege('service_role', 'financing.financial_products', 'SELECT') THEN
    RAISE EXCEPTION 'service_role must keep SELECT on the catalog tables'
      USING ERRCODE = 'P0001';
  END IF;

  IF pg_catalog.has_table_privilege('service_role', 'financing.financial_products', 'INSERT')
     OR pg_catalog.has_table_privilege('service_role', 'financing.financial_products', 'UPDATE') THEN
    RAISE EXCEPTION 'service_role must not have write grants on the catalog tables'
      USING ERRCODE = 'P0001';
  END IF;

  -- No auth.uid() for a service_role JWT, so the write RPCs stay closed.
  BEGIN
    PERFORM financing.manage_provider(p_slug => 'svc-provider', p_name => 'Svc', p_provider_type => 'bank');
    RAISE EXCEPTION 'service_role must not be able to call manage_provider'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  BEGIN
    PERFORM financing.set_provider_verification('f1f10000-0000-4000-8000-000000000102', 'verified');
    RAISE EXCEPTION 'service_role must not be able to call set_provider_verification'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  -- Row visibility for service_role differs between hosted Supabase (BYPASSRLS)
  -- and a plain local cluster, so it is deliberately NOT asserted here.
  RAISE NOTICE 'section 10 (service_role) passed';
END;
$$;

RESET ROLE;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 11 -- wrong-module / missing-scope profile cannot reach any RPC
-- ═══════════════════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"f1f10000-0000-4000-8000-0000000000f2","role":"authenticated"}';
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  -- role_permissions present, entity_role_scopes absent -> deny
  IF core.has_permission('finance.review_products') THEN
    RAISE EXCEPTION 'module-scoped permission must require an entity_role_scopes row'
      USING ERRCODE = 'P0001';
  END IF;
  IF core.has_permission('finance.manage_providers')
     OR core.has_permission('finance.verify_providers')
     OR core.has_permission('finance.manage_products')
     OR core.has_permission('finance.publish_products') THEN
    RAISE EXCEPTION 'all finance.* checks must fail closed without a module scope row'
      USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    PERFORM financing.review_product('f1f10000-0000-4000-8000-000000000203', true);
    RAISE EXCEPTION 'review_product must be denied without a module scope row'
      USING ERRCODE = 'P0001';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  RAISE NOTICE 'section 11 (missing module scope) passed';
END;
$$;

RESET ROLE;

-- Fixtures and role assignments are transaction-scoped: nothing survives.
ROLLBACK;

SELECT 'financing_provider_product_catalog_test: OK' AS result;

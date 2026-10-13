-- ============================================================================
-- Financing Phase 1: financial_providers + financial_products
-- ============================================================================
--
-- WHAT THIS MIGRATION DOES
--   * Creates financing.financial_providers (verification lifecycle) and
--     financing.financial_products (approval + publication lifecycles).
--   * Registers five module-scoped permission codes in core.permissions.
--   * Exposes RPC-only writes (SECURITY DEFINER), permission-gated table reads,
--     and two column-limited public catalog views.
--
-- WHAT IT DELIBERATELY DOES NOT DO
--   * It does NOT modify financing.financial_accounts.
--   * It does NOT insert any core.role_permissions row.
--   * It does NOT insert any core.entity_role_scopes row.
--   * It does NOT assign finance.* to Admin, Super Admin, or any other role.
--   * It does NOT enable the Finance module in system.modules.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- PERMISSION MODEL (evidence-based; see "BLOCKER" below)
-- ─────────────────────────────────────────────────────────────────────────────
-- core.has_permission(p_permission) grants only when BOTH are true for the
-- caller's ACTIVE context (active session + active entity membership +
-- active entity_roles row + active user_roles row):
--
--   (1) core.role_permissions      (role_id, permission_id, is_active = true)
--   (2) core.entity_role_scopes    matching scope for that SAME (profile, role):
--         scope_type = 'global' -> entity_id IS NULL AND module IS NULL
--         scope_type = 'entity' -> entity_id = active entity AND module IS NULL
--         scope_type = 'module' -> entity_id = active entity AND module = permission.module
--
-- For a module-scoped permission (scope_type = 'module', module = 'finance'),
-- condition (2) therefore needs a row with scope_type = 'module',
-- entity_id = <the caller's active entity>, module = 'finance'.
--
-- Observed live state at the time of writing:
--   * core.entity_role_scopes contains ZERO rows with scope_type = 'module'.
--     Not even the knowledge.* module permissions are wired up this way.
--   * core.role_permissions has rows for knowledge.* (Admin, Super Admin and the
--     dedicated "Knowledge *" roles) but ZERO rows for logistics.*.
--     i.e. "registered but unassigned" already exists as a precedent.
--   * No admin RPC or UI exists that writes core.entity_role_scopes.
--
-- BLOCKER (unresolved by design):
--   Registering the codes below is sufficient to make them *grantable*, but
--   there is no safe, evidenced project convention for WHO should hold them.
--   Because (2) has no live precedent and no writer, seeding role_permissions
--   alone would grant nothing while still implying intent. This migration
--   therefore seeds only the permission registry. Until an operator makes an
--   explicit, reviewed decision, every finance.* permission evaluates to false
--   and every gated RPC raises 42501 (fail closed).
--
--   Operator recipe for granting finance.* to ONE profile inside ONE entity,
--   executed as a deliberate, audited change (NOT run by this migration):
--
--     -- 1. role -> permission
--     INSERT INTO core.role_permissions (role_id, permission_id, is_active)
--     SELECT r.id, p.id, true
--       FROM core.user_roles r
--       JOIN core.permissions p ON p.code IN (
--              'finance.manage_providers','finance.verify_providers',
--              'finance.manage_products','finance.review_products',
--              'finance.publish_products')
--      WHERE r.name = '<role name>'
--     ON CONFLICT DO NOTHING;
--
--     -- 2. profile+role -> module scope on the entity they act in
--     INSERT INTO core.entity_role_scopes (profile_id, role_id, entity_id, scope_type, module)
--     VALUES ('<profile uuid>', '<role uuid>', '<entity uuid>', 'module', 'finance')
--     ON CONFLICT DO NOTHING;
--
--     -- Both are required. Role membership alone is not enough.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- POST-MIGRATION STATUS (added 2026-10-13; supersedes the BLOCKER above)
-- ─────────────────────────────────────────────────────────────────────────────
-- Everything in this block is a READ-ONLY OBSERVATION of one production
-- database, recorded so the BLOCKER above is not mistaken for current state.
-- It is NOT created by this migration and NOT guaranteed by this migration in
-- any other environment. Applying this migration anywhere seeds the permission
-- registry only, exactly as described above; the grants, scopes, IDs and
-- module flags below are operator-created, are specific to that one deployment,
-- and will legitimately differ elsewhere.
--
-- The BLOCKER and the "observed live state" note above are retained verbatim
-- because they describe this migration and that database as they stood when
-- this file was written. They no longer describe that database.
--
-- OBSERVED in that production database as of 2026-10-13 (operator-applied, not
-- migration-applied):
--   * All five finance.* codes have active core.role_permissions grants on the
--     Admin role (60773165-412a-4d1b-98da-5c9f2e7fe307).
--   * A matching core.entity_role_scopes row exists with scope_type='module',
--     module='finance', for profile 01a03733-ce44-7f82-ba8d-d12d97025346
--     acting in entity 01a091e6-f283-70b5-9393-813acf541c09 (FAMHUB Platform
--     Administration).
--   * system.modules finance is is_enabled = true, maintenance_mode = false.
--   * "every finance.* permission evaluates to false" therefore no longer
--     holds for that role in that entity. It still holds, correctly, for any
--     other role or any other workspace — the grants are scoped, not global.
--
-- Nothing in this migration is changed by any of that. It remains true that
-- this migration seeds no grants and that granting is an operator decision.
--
-- ERROR ATTRIBUTION (correcting an earlier misreading):
--   core.has_permission(p_permission) returns boolean and contains no RAISE;
--     it cannot emit 42501. Denial is reported as false.
--   financing._require_permission is the only 42501 source on this feature's
--     write path. It raises 'Authentication required' when auth.uid() is NULL,
--     and 'Finance permission denied: <code>' when the profile cannot be
--     resolved or core.has_permission evaluates false.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA USAGE / financial_accounts SIDE EFFECT (documented exposure change)
-- ─────────────────────────────────────────────────────────────────────────────
-- financing.financial_accounts ALREADY carries table-level SELECT grants for
-- anon/authenticated/service_role, but anon/authenticated/service_role have
-- USAGE = false on schema "financing", so the table is unreachable today.
-- Adding USAGE for "authenticated" is REQUIRED for this feature and therefore
-- also makes financial_accounts reachable for authenticated callers. Its RLS is
-- owner-scoped (fin_accounts_select / fin_accounts_insert, both TO
-- authenticated, predicate profile_id = current_profile_id()), so an
-- authenticated caller can see only their own account rows. This is the
-- pre-existing intent of that table; no change is made to it here.
--
-- USAGE is intentionally NOT granted to "anon":
--   * Phase 1 has no guest-facing catalog client, so anon USAGE is not required.
--   * It keeps the existing financial_accounts exposure for anon unchanged.
--   * It guarantees anonymous callers cannot read reviewer notes, reviewer ids,
--     or internal metadata on the new tables.
-- If guest catalog read is wanted later, grant USAGE on schema "financing" to
-- anon plus SELECT on the two public_* views below, and re-test anon access to
-- financial_accounts first (its policies are TO authenticated only, so anon
-- should still see zero rows, but that must be verified, not assumed).
--
-- ─────────────────────────────────────────────────────────────────────────────
-- PRIVACY MODEL
-- ─────────────────────────────────────────────────────────────────────────────
--   anon            : no USAGE on schema "financing" -> no access at all.
--   authenticated   : table SELECT exists but BOTH table RLS policies are
--                     permission-gated, so an ordinary user sees ZERO rows.
--                     Public catalog read comes from the column-limited views.
--   reviewers/admins: full table SELECT via the permission-gated RLS policies,
--                     which is the only way to see verification_notes,
--                     approval_notes, reviewer ids and metadata.
--   service_role    : table SELECT + (in hosted Supabase) BYPASSRLS, so it can
--                     read every column. It still has NO write grants on these
--                     tables, and it cannot call the write RPCs because
--                     auth.uid() is NULL for a service_role JWT (42501).
--                     service_role is therefore READ-ONLY for this feature.
--                     No service-role bypass is added; there is no proven need.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- SQLSTATE CONTRACT (used by the client and by the tests)
--   42501  not authenticated, or finance.* not granted to this context
--   22023  invalid parameter value / invalid metadata key
--   P0002  referenced provider or product does not exist
--   55000  lifecycle state does not allow the operation
--
-- ROLLBACK IMPLICATIONS
--   The Supabase CLI runs this file inside one transaction, so a failure leaves
--   nothing behind. A deliberate rollback requires dropping, in this order:
--     views    financing.public_financial_products,
--              financing.public_financial_providers
--     policies fin_products_manage_select, fin_providers_manage_select
--     RPCs     all financing.* functions defined below
--     tables   financing.financial_products, financing.financial_providers
--     grants   REVOKE USAGE ON SCHEMA financing FROM authenticated, service_role
--     registry DELETE FROM core.permissions WHERE code LIKE 'finance.%'
--   Note: core.role_permissions / core.entity_role_scopes are untouched here,
--   so rollback cannot orphan an assignment -- there are none to orphan.
--
-- IDEMPOTENCY
--   Tables use CREATE TABLE IF NOT EXISTS followed by a drift guard that RAISES
--   if an existing table is missing an expected column (so a partial re-run
--   cannot silently paper over a mismatched schema). Functions use CREATE OR
--   REPLACE. Policies and triggers are DROP ... IF EXISTS then CREATE, so a
--   partial re-run is safe; this file is the authoritative definition for the
--   objects it owns.
--
-- Follows the knowledge-module pattern: RLS for reads, SECURITY DEFINER RPCs
-- for writes, no client-side table write grants.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS "financing";

GRANT USAGE ON SCHEMA "financing" TO "authenticated";
GRANT USAGE ON SCHEMA "financing" TO "service_role";
-- No USAGE for "anon": see header "SCHEMA USAGE / financial_accounts SIDE EFFECT".

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at trigger helper (internal: no client EXECUTE)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "financing"."set_updated_at"() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

ALTER FUNCTION "financing"."set_updated_at"() OWNER TO "postgres";

-- ─────────────────────────────────────────────────────────────────────────────
-- Provider catalog (verification lifecycle)
-- verification_status: pending -> verified | rejected | suspended
-- is_active is independent of verification (soft disable).
-- Reviewer FKs are ON DELETE RESTRICT so audit history survives profile deletion.
-- created_by keeps ON DELETE SET NULL (origin metadata, not a review record).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "financing"."financial_providers" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "slug" text NOT NULL,
    "name" text NOT NULL,
    "provider_type" text NOT NULL,
    "description" text,
    "logo_url" text,
    "website_url" text,
    "contact_email" text,
    "contact_phone" text,
    "country_code" text DEFAULT 'KE'::text NOT NULL,
    "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "verification_status" text DEFAULT 'pending'::text NOT NULL,
    "verification_notes" text,
    "verified_by" uuid,
    "verified_at" timestamp with time zone,
    "created_by" uuid,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "financial_providers_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "financial_providers_slug_key" UNIQUE ("slug"),
    CONSTRAINT "financial_providers_metadata_check" CHECK ((jsonb_typeof("metadata") = 'object'::text)),
    CONSTRAINT "financial_providers_provider_type_check" CHECK (("provider_type" = ANY (ARRAY[
      'bank'::text,
      'sacco'::text,
      'insurance'::text,
      'microfinance'::text,
      'lending_platform'::text,
      'mobile_money'::text
    ]))),
    CONSTRAINT "financial_providers_verification_status_check" CHECK (("verification_status" = ANY (ARRAY[
      'pending'::text,
      'verified'::text,
      'rejected'::text,
      'suspended'::text
    ]))),
    CONSTRAINT "financial_providers_slug_format_check" CHECK (("slug" ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)),
    CONSTRAINT "financial_providers_name_not_blank" CHECK ((btrim("name") <> ''::text)),
    CONSTRAINT "financial_providers_verification_timestamps_check" CHECK (
      (
        ("verification_status" = 'pending'::text)
        AND ("verified_at" IS NULL)
        AND ("verified_by" IS NULL)
      )
      OR
      (
        ("verification_status" <> 'pending'::text)
        AND ("verified_at" IS NOT NULL)
        AND ("verified_by" IS NOT NULL)
      )
    ),
    CONSTRAINT "financial_providers_verified_by_fkey" FOREIGN KEY ("verified_by")
      REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "financial_providers_created_by_fkey" FOREIGN KEY ("created_by")
      REFERENCES "users"."profiles"("id") ON DELETE SET NULL
);

ALTER TABLE "financing"."financial_providers" OWNER TO "postgres";

-- Drift guard: CREATE TABLE IF NOT EXISTS would otherwise hide a schema that
-- exists but does not match this migration.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'financing'
      AND table_name = 'financial_providers'
      AND column_name = 'verification_status'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42P07',
      MESSAGE = 'financing.financial_providers exists but is missing column verification_status; resolve the schema drift before re-running this migration';
  END IF;
END;
$$;

COMMENT ON TABLE "financing"."financial_providers" IS
  'Phase 1 financing partner catalog with a dedicated verification lifecycle (separate from product approval).';
COMMENT ON COLUMN "financing"."financial_providers"."verification_status" IS
  'pending | verified | rejected | suspended. Transitions only via financing.set_provider_verification. Rejection/suspension unpublishes and resets the provider products to draft.';
COMMENT ON COLUMN "financing"."financial_providers"."is_active" IS
  'Operational enablement independent of verification.';
COMMENT ON COLUMN "financing"."financial_providers"."verification_notes" IS
  'Internal reviewer note. Not present on the public catalog view; readable only through permission-gated table RLS.';
COMMENT ON COLUMN "financing"."financial_providers"."verified_by" IS
  'Internal reviewer id. ON DELETE RESTRICT preserves verification history.';

DROP TRIGGER IF EXISTS "tr_financial_providers_set_updated_at" ON "financing"."financial_providers";
CREATE TRIGGER "tr_financial_providers_set_updated_at"
  BEFORE UPDATE ON "financing"."financial_providers"
  FOR EACH ROW
  EXECUTE FUNCTION "financing"."set_updated_at"();

CREATE INDEX IF NOT EXISTS "idx_financial_providers_public_catalog"
  ON "financing"."financial_providers" ("verification_status", "is_active")
  WHERE ("is_active" = true AND "verification_status" = 'verified'::text);

CREATE INDEX IF NOT EXISTS "idx_financial_providers_type"
  ON "financing"."financial_providers" ("provider_type");

-- ─────────────────────────────────────────────────────────────────────────────
-- Product catalog (approval + publication lifecycles)
-- approval_status: draft -> in_review -> approved | rejected
-- publication: separate is_published flag; publish requires approved + active
-- product + verified active provider.
-- approved_by / published_by are ON DELETE RESTRICT so audit history survives
-- profile deletion.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "financing"."financial_products" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "provider_id" uuid NOT NULL,
    "slug" text NOT NULL,
    "name" text NOT NULL,
    "product_type" text NOT NULL,
    "summary" text,
    "description" text,
    "currency" text DEFAULT 'KES'::text NOT NULL,
    "min_amount" numeric,
    "max_amount" numeric,
    "interest_rate" numeric,
    "interest_rate_type" text,
    "min_tenure_days" integer,
    "max_tenure_days" integer,
    "requires_collateral" boolean DEFAULT false NOT NULL,
    "requirements" text[] DEFAULT '{}'::text[] NOT NULL,
    "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "approval_status" text DEFAULT 'draft'::text NOT NULL,
    "approval_notes" text,
    "approved_by" uuid,
    "approved_at" timestamp with time zone,
    "is_published" boolean DEFAULT false NOT NULL,
    "published_by" uuid,
    "published_at" timestamp with time zone,
    "created_by" uuid,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "financial_products_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "financial_products_provider_slug_key" UNIQUE ("provider_id", "slug"),
    CONSTRAINT "financial_products_metadata_check" CHECK ((jsonb_typeof("metadata") = 'object'::text)),
    CONSTRAINT "financial_products_product_type_check" CHECK (("product_type" = ANY (ARRAY[
      'loan'::text,
      'insurance'::text,
      'savings'::text,
      'asset_financing'::text,
      'input_financing'::text,
      'mobile_money'::text
    ]))),
    CONSTRAINT "financial_products_approval_status_check" CHECK (("approval_status" = ANY (ARRAY[
      'draft'::text,
      'in_review'::text,
      'approved'::text,
      'rejected'::text
    ]))),
    CONSTRAINT "financial_products_interest_rate_type_check" CHECK (
      ("interest_rate_type" IS NULL)
      OR ("interest_rate_type" = ANY (ARRAY[
        'fixed'::text,
        'reducing_balance'::text,
        'flat'::text,
        'variable'::text
      ]))
    ),
    CONSTRAINT "financial_products_slug_format_check" CHECK (("slug" ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)),
    CONSTRAINT "financial_products_name_not_blank" CHECK ((btrim("name") <> ''::text)),
    CONSTRAINT "financial_products_amount_range_check" CHECK (
      ("min_amount" IS NULL OR "min_amount" >= 0)
      AND ("max_amount" IS NULL OR "max_amount" >= 0)
      AND (
        "min_amount" IS NULL
        OR "max_amount" IS NULL
        OR "max_amount" >= "min_amount"
      )
    ),
    CONSTRAINT "financial_products_tenure_range_check" CHECK (
      ("min_tenure_days" IS NULL OR "min_tenure_days" > 0)
      AND ("max_tenure_days" IS NULL OR "max_tenure_days" > 0)
      AND (
        "min_tenure_days" IS NULL
        OR "max_tenure_days" IS NULL
        OR "max_tenure_days" >= "min_tenure_days"
      )
    ),
    CONSTRAINT "financial_products_approval_timestamps_check" CHECK (
      (
        ("approval_status" NOT IN ('approved'::text, 'rejected'::text))
        AND ("approved_at" IS NULL)
        AND ("approved_by" IS NULL)
      )
      OR
      (
        ("approval_status" IN ('approved'::text, 'rejected'::text))
        AND ("approved_at" IS NOT NULL)
        AND ("approved_by" IS NOT NULL)
      )
    ),
    CONSTRAINT "financial_products_publication_requires_approval_check" CHECK (
      ("is_published" = false)
      OR ("approval_status" = 'approved'::text)
    ),
    CONSTRAINT "financial_products_published_timestamps_check" CHECK (
      (
        ("is_published" = false)
        AND ("published_at" IS NULL)
        AND ("published_by" IS NULL)
      )
      OR
      (
        ("is_published" = true)
        AND ("published_at" IS NOT NULL)
        AND ("published_by" IS NOT NULL)
      )
    ),
    CONSTRAINT "financial_products_provider_id_fkey" FOREIGN KEY ("provider_id")
      REFERENCES "financing"."financial_providers"("id") ON DELETE RESTRICT,
    CONSTRAINT "financial_products_approved_by_fkey" FOREIGN KEY ("approved_by")
      REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "financial_products_published_by_fkey" FOREIGN KEY ("published_by")
      REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "financial_products_created_by_fkey" FOREIGN KEY ("created_by")
      REFERENCES "users"."profiles"("id") ON DELETE SET NULL
);

ALTER TABLE "financing"."financial_products" OWNER TO "postgres";

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'financing'
      AND table_name = 'financial_products'
      AND column_name = 'approval_status'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42P07',
      MESSAGE = 'financing.financial_products exists but is missing column approval_status; resolve the schema drift before re-running this migration';
  END IF;
END;
$$;

COMMENT ON TABLE "financing"."financial_products" IS
  'Phase 1 financing product catalog with independent approval and publication lifecycles.';
COMMENT ON COLUMN "financing"."financial_products"."approval_status" IS
  'draft | in_review | approved | rejected. Transitions only via financing RPCs. Editing an in_review product returns it to draft; editing an approved/published product requires financing.reopen_product_for_edit first.';
COMMENT ON COLUMN "financing"."financial_products"."is_published" IS
  'Publication gate. Public visibility also requires approved status, an active product and an active verified provider.';
COMMENT ON COLUMN "financing"."financial_products"."approval_notes" IS
  'Internal reviewer note. Not present on the public catalog view.';
COMMENT ON COLUMN "financing"."financial_products"."approved_by" IS
  'Internal reviewer id. ON DELETE RESTRICT preserves approval history.';

DROP TRIGGER IF EXISTS "tr_financial_products_set_updated_at" ON "financing"."financial_products";
CREATE TRIGGER "tr_financial_products_set_updated_at"
  BEFORE UPDATE ON "financing"."financial_products"
  FOR EACH ROW
  EXECUTE FUNCTION "financing"."set_updated_at"();

CREATE INDEX IF NOT EXISTS "idx_financial_products_public_catalog"
  ON "financing"."financial_products" ("provider_id", "approval_status", "is_published", "is_active")
  WHERE ("is_active" = true AND "is_published" = true AND "approval_status" = 'approved'::text);

CREATE INDEX IF NOT EXISTS "idx_financial_products_type"
  ON "financing"."financial_products" ("product_type");

-- ─────────────────────────────────────────────────────────────────────────────
-- Permission codes (core.has_permission framework)
-- Registry only: no role_permissions / entity_role_scopes rows are created.
-- See the header BLOCKER section for why and for the operator recipe.
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO "core"."permissions" ("code", "description", "module", "scope_type")
VALUES
  ('finance.manage_providers', 'Create and edit financing provider catalog records', 'finance', 'module'),
  ('finance.verify_providers', 'Approve, reject, or suspend financing providers', 'finance', 'module'),
  ('finance.manage_products', 'Create and edit financing product catalog records', 'finance', 'module'),
  ('finance.review_products', 'Approve or reject financing products in review', 'finance', 'module'),
  ('finance.publish_products', 'Publish or unpublish approved financing products', 'finance', 'module')
ON CONFLICT ("code") DO NOTHING;

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM core.permissions
  WHERE code LIKE 'finance.%'
    AND module = 'finance'
    AND scope_type = 'module';

  IF v_count <> 5 THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = format('expected 5 module-scoped finance.* permissions, found %s', v_count);
  END IF;

  SELECT count(*) INTO v_count
  FROM core.role_permissions rp
  JOIN core.permissions p ON p.id = rp.permission_id
  WHERE p.code LIKE 'finance.%';

  IF v_count = 0 THEN
    RAISE NOTICE 'finance.* permissions are registered but unassigned by design; no core.role_permissions and no core.entity_role_scopes rows were created (see migration header BLOCKER). All finance.* checks currently fail closed.';
  END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Public visibility helpers (read-only, no side effects)
-- Public products require: product active + approved + published
-- AND provider active + verified.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "financing"."is_publicly_visible_product"("p_product_id" uuid)
RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM financing.financial_products AS fp
    JOIN financing.financial_providers AS fpr
      ON fpr.id = fp.provider_id
    WHERE fp.id = p_product_id
      AND fp.is_active = true
      AND fp.approval_status = 'approved'::text
      AND fp.is_published = true
      AND fpr.is_active = true
      AND fpr.verification_status = 'verified'::text
  );
$$;

ALTER FUNCTION "financing"."is_publicly_visible_product"(uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "financing"."is_publicly_visible_provider"("p_provider_id" uuid)
RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM financing.financial_providers AS fpr
    WHERE fpr.id = p_provider_id
      AND fpr.is_active = true
      AND fpr.verification_status = 'verified'::text
  );
$$;

ALTER FUNCTION "financing"."is_publicly_visible_provider"(uuid) OWNER TO "postgres";

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- These carry NO client EXECUTE grant: only SECURITY DEFINER functions owned by
-- postgres invoke them, and those run with postgres as the current role.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "financing"."_require_permission"("p_permission" text)
RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Authentication required';
  END IF;

  v_actor := core.current_profile_id();
  IF v_actor IS NULL OR NOT core.has_permission(p_permission) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = format('Finance permission denied: %s', p_permission);
  END IF;

  RETURN v_actor;
END;
$$;

ALTER FUNCTION "financing"."_require_permission"(text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "financing"."_validate_slug"("p_slug" text, "p_field" text DEFAULT 'slug'::text)
RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO ''
    AS $$
DECLARE
  v_slug text := btrim(coalesce(p_slug, ''));
BEGIN
  IF v_slug = '' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = format('%s is required', p_field);
  END IF;
  IF v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = format('%s must be lowercase alphanumeric words separated by hyphens', p_field);
  END IF;
  RETURN v_slug;
END;
$$;

ALTER FUNCTION "financing"."_validate_slug"(text, text) OWNER TO "postgres";

-- Permitted metadata keys: lowercase snake_case, starting with a letter,
-- 1..64 characters. Anything else is rejected rather than silently stored.
CREATE OR REPLACE FUNCTION "financing"."_validate_metadata_keys"("p_metadata" jsonb)
RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO ''
    AS $$
DECLARE
  v_key text;
BEGIN
  IF p_metadata IS NULL OR jsonb_typeof(p_metadata) <> 'object' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'metadata must be a JSON object';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_metadata)
  LOOP
    IF v_key !~ '^[a-z][a-z0-9_]{0,63}$' THEN
      RAISE EXCEPTION USING ERRCODE = '22023',
        MESSAGE = format('metadata key "%s" is not permitted: keys must match ^[a-z][a-z0-9_]{0,63}$', v_key);
    END IF;
  END LOOP;

  RETURN p_metadata;
END;
$$;

ALTER FUNCTION "financing"."_validate_metadata_keys"(jsonb) OWNER TO "postgres";

-- Shallow merge: caller-provided keys win, every other existing key is kept.
CREATE OR REPLACE FUNCTION "financing"."_merge_metadata"("p_existing" jsonb, "p_incoming" jsonb)
RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    SET search_path TO ''
    AS $$
  SELECT coalesce(p_existing, '{}'::jsonb) || coalesce(p_incoming, '{}'::jsonb);
$$;

ALTER FUNCTION "financing"."_merge_metadata"(jsonb, jsonb) OWNER TO "postgres";

-- ─────────────────────────────────────────────────────────────────────────────
-- Provider lifecycle RPCs
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "financing"."manage_provider"(
    "p_provider_id" uuid DEFAULT NULL,
    "p_slug" text DEFAULT NULL,
    "p_name" text DEFAULT NULL,
    "p_provider_type" text DEFAULT NULL,
    "p_description" text DEFAULT NULL,
    "p_logo_url" text DEFAULT NULL,
    "p_website_url" text DEFAULT NULL,
    "p_contact_email" text DEFAULT NULL,
    "p_contact_phone" text DEFAULT NULL,
    "p_country_code" text DEFAULT 'KE'::text,
    "p_metadata" jsonb DEFAULT '{}'::jsonb,
    "p_is_active" boolean DEFAULT true
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_id uuid;
  v_slug text;
  v_name text;
  v_type text;
  v_metadata jsonb;
BEGIN
  v_actor := financing._require_permission('finance.manage_providers');
  v_slug := financing._validate_slug(p_slug, 'slug');
  v_name := nullif(btrim(coalesce(p_name, '')), '');
  v_type := nullif(btrim(coalesce(p_provider_type, '')), '');
  v_metadata := financing._validate_metadata_keys(coalesce(p_metadata, '{}'::jsonb));

  IF v_name IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'name is required';
  END IF;
  IF v_type IS NULL OR v_type NOT IN ('bank', 'sacco', 'insurance', 'microfinance', 'lending_platform', 'mobile_money') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'provider_type is invalid';
  END IF;

  IF p_provider_id IS NULL THEN
    INSERT INTO financing.financial_providers (
      slug, name, provider_type, description, logo_url, website_url,
      contact_email, contact_phone, country_code, metadata, is_active, created_by
    )
    VALUES (
      v_slug, v_name, v_type, nullif(btrim(coalesce(p_description, '')), ''), nullif(btrim(coalesce(p_logo_url, '')), ''),
      nullif(btrim(coalesce(p_website_url, '')), ''), nullif(btrim(coalesce(p_contact_email, '')), ''),
      nullif(btrim(coalesce(p_contact_phone, '')), ''), coalesce(nullif(btrim(coalesce(p_country_code, '')), ''), 'KE'),
      v_metadata, coalesce(p_is_active, true), v_actor
    )
    RETURNING id INTO v_id;
  ELSE
    -- Metadata is merged, not replaced: a partial update must not drop keys.
    UPDATE financing.financial_providers
    SET
      slug = v_slug,
      name = v_name,
      provider_type = v_type,
      description = nullif(btrim(coalesce(p_description, description)), ''),
      logo_url = nullif(btrim(coalesce(p_logo_url, logo_url)), ''),
      website_url = nullif(btrim(coalesce(p_website_url, website_url)), ''),
      contact_email = nullif(btrim(coalesce(p_contact_email, contact_email)), ''),
      contact_phone = nullif(btrim(coalesce(p_contact_phone, contact_phone)), ''),
      country_code = coalesce(nullif(btrim(coalesce(p_country_code, country_code)), ''), country_code),
      metadata = financing._merge_metadata(metadata, v_metadata),
      is_active = coalesce(p_is_active, is_active)
    WHERE id = p_provider_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial provider not found';
    END IF;
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "financing"."manage_provider"(uuid, text, text, text, text, text, text, text, text, text, jsonb, boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "financing"."set_provider_verification"(
    "p_provider_id" uuid,
    "p_verification_status" text,
    "p_notes" text DEFAULT NULL
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_status text := nullif(btrim(coalesce(p_verification_status, '')), '');
  v_id uuid;
  v_reset integer;
BEGIN
  v_actor := financing._require_permission('finance.verify_providers');

  IF v_status IS NULL OR v_status NOT IN ('verified', 'rejected', 'suspended') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'verification_status must be verified, rejected, or suspended';
  END IF;

  UPDATE financing.financial_providers
  SET
    verification_status = v_status,
    verification_notes = nullif(btrim(coalesce(p_notes, verification_notes)), ''),
    verified_by = v_actor,
    verified_at = now()
  WHERE id = p_provider_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial provider not found';
  END IF;

  -- Rejection/suspension must not leave live content behind, and re-verification
  -- must not silently resurrect it. Reset the whole product lifecycle to draft,
  -- so a later "verified" transition requires a fresh approval + publication.
  -- The "verified" branch deliberately changes nothing: nothing is restored.
  IF v_status IN ('rejected', 'suspended') THEN
    UPDATE financing.financial_products
    SET
      approval_status = 'draft',
      approval_notes = NULL,
      approved_by = NULL,
      approved_at = NULL,
      is_published = false,
      published_by = NULL,
      published_at = NULL
    WHERE provider_id = v_id
      AND (approval_status <> 'draft' OR is_published = true);

    GET DIAGNOSTICS v_reset = ROW_COUNT;
    IF v_reset > 0 THEN
      RAISE NOTICE 'provider % transitioned to %: reset % product(s) to draft and unpublished them',
        v_id, v_status, v_reset;
    END IF;
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "financing"."set_provider_verification"(uuid, text, text) OWNER TO "postgres";

-- ─────────────────────────────────────────────────────────────────────────────
-- Product lifecycle RPCs (approval and publication are separate)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "financing"."manage_product"(
    "p_product_id" uuid DEFAULT NULL,
    "p_provider_id" uuid DEFAULT NULL,
    "p_slug" text DEFAULT NULL,
    "p_name" text DEFAULT NULL,
    "p_product_type" text DEFAULT NULL,
    "p_summary" text DEFAULT NULL,
    "p_description" text DEFAULT NULL,
    "p_currency" text DEFAULT 'KES'::text,
    "p_min_amount" numeric DEFAULT NULL,
    "p_max_amount" numeric DEFAULT NULL,
    "p_interest_rate" numeric DEFAULT NULL,
    "p_interest_rate_type" text DEFAULT NULL,
    "p_min_tenure_days" integer DEFAULT NULL,
    "p_max_tenure_days" integer DEFAULT NULL,
    "p_requires_collateral" boolean DEFAULT false,
    "p_requirements" text[] DEFAULT '{}'::text[],
    "p_metadata" jsonb DEFAULT '{}'::jsonb,
    "p_is_active" boolean DEFAULT true
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_id uuid;
  v_slug text;
  v_name text;
  v_type text;
  v_provider_id uuid;
  v_metadata jsonb;
  v_product_type text;
  v_rate_type text;
  v_current_status text;
  v_current_published boolean;
BEGIN
  v_actor := financing._require_permission('finance.manage_products');
  v_slug := financing._validate_slug(p_slug, 'slug');
  v_name := nullif(btrim(coalesce(p_name, '')), '');
  v_type := nullif(btrim(coalesce(p_product_type, '')), '');
  v_metadata := financing._validate_metadata_keys(coalesce(p_metadata, '{}'::jsonb));
  v_rate_type := nullif(btrim(coalesce(p_interest_rate_type, '')), '');

  -- Lifecycle guard: approved or published content is frozen until an explicit
  -- reopen. This runs before any mutation so a failed guard changes nothing.
  IF p_product_id IS NOT NULL THEN
    SELECT approval_status, is_published
      INTO v_current_status, v_current_published
      FROM financing.financial_products
     WHERE id = p_product_id
     FOR UPDATE;

    IF v_current_status IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial product not found';
    END IF;

    IF v_current_status = 'approved' OR v_current_published THEN
      RAISE EXCEPTION USING ERRCODE = '55000', MESSAGE =
        'Approved or published products cannot be edited directly; call financing.reopen_product_for_edit first, then edit, resubmit and re-review';
    END IF;
  END IF;

  v_provider_id := coalesce(p_provider_id, (
    SELECT provider_id FROM financing.financial_products WHERE id = p_product_id
  ));

  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'provider_id is required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM financing.financial_providers WHERE id = v_provider_id
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'provider_id is unknown';
  END IF;
  IF v_name IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'name is required';
  END IF;
  IF v_type IS NULL OR v_type NOT IN ('loan', 'insurance', 'savings', 'asset_financing', 'input_financing', 'mobile_money') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'product_type is invalid';
  END IF;
  IF v_rate_type IS NOT NULL AND v_rate_type NOT IN ('fixed', 'reducing_balance', 'flat', 'variable') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'interest_rate_type is invalid';
  END IF;
  IF p_min_amount IS NOT NULL AND p_min_amount < 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'min_amount must be >= 0';
  END IF;
  IF p_max_amount IS NOT NULL AND p_max_amount < 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'max_amount must be >= 0';
  END IF;
  IF p_min_amount IS NOT NULL AND p_max_amount IS NOT NULL AND p_max_amount < p_min_amount THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'max_amount must be >= min_amount';
  END IF;
  IF p_min_tenure_days IS NOT NULL AND p_min_tenure_days <= 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'min_tenure_days must be > 0';
  END IF;
  IF p_max_tenure_days IS NOT NULL AND p_max_tenure_days <= 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'max_tenure_days must be > 0';
  END IF;
  IF p_min_tenure_days IS NOT NULL AND p_max_tenure_days IS NOT NULL AND p_max_tenure_days < p_min_tenure_days THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'max_tenure_days must be >= min_tenure_days';
  END IF;

  IF p_product_id IS NULL THEN
    INSERT INTO financing.financial_products (
      provider_id, slug, name, product_type, summary, description, currency,
      min_amount, max_amount, interest_rate, interest_rate_type,
      min_tenure_days, max_tenure_days, requires_collateral, requirements,
      metadata, is_active, created_by
    )
    VALUES (
      v_provider_id, v_slug, v_name, v_type,
      nullif(btrim(coalesce(p_summary, '')), ''), nullif(btrim(coalesce(p_description, '')), ''),
      coalesce(nullif(btrim(coalesce(p_currency, '')), ''), 'KES'),
      p_min_amount, p_max_amount, p_interest_rate, v_rate_type,
      p_min_tenure_days, p_max_tenure_days, coalesce(p_requires_collateral, false),
      coalesce(p_requirements, '{}'::text[]), v_metadata, coalesce(p_is_active, true), v_actor
    )
    RETURNING id INTO v_id;
  ELSE
    -- Editing content while under review invalidates the review: fall back to
    -- draft so the reviewer sees exactly what will ship. (Guard above already
    -- rejected approved/published rows.)
    UPDATE financing.financial_products
    SET
      provider_id = v_provider_id,
      slug = v_slug,
      name = v_name,
      product_type = v_type,
      summary = nullif(btrim(coalesce(p_summary, summary)), ''),
      description = nullif(btrim(coalesce(p_description, description)), ''),
      currency = coalesce(nullif(btrim(coalesce(p_currency, currency)), ''), currency),
      min_amount = coalesce(p_min_amount, min_amount),
      max_amount = coalesce(p_max_amount, max_amount),
      interest_rate = coalesce(p_interest_rate, interest_rate),
      interest_rate_type = coalesce(v_rate_type, interest_rate_type),
      min_tenure_days = coalesce(p_min_tenure_days, min_tenure_days),
      max_tenure_days = coalesce(p_max_tenure_days, max_tenure_days),
      requires_collateral = coalesce(p_requires_collateral, requires_collateral),
      requirements = coalesce(p_requirements, requirements),
      metadata = financing._merge_metadata(metadata, v_metadata),
      approval_status = CASE WHEN approval_status = 'in_review' THEN 'draft' ELSE approval_status END,
      is_active = coalesce(p_is_active, is_active)
    WHERE id = p_product_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial product not found';
    END IF;
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "financing"."manage_product"(
  uuid, uuid, text, text, text, text, text, text, numeric, numeric, numeric,
  text, integer, integer, boolean, text[], jsonb, boolean
) OWNER TO "postgres";

-- Explicit re-entry point for editing approved/published content. Returns the
-- product to a reviewable state instead of letting manage_product mutate it.
CREATE OR REPLACE FUNCTION "financing"."reopen_product_for_edit"("p_product_id" uuid)
RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_id uuid;
  v_status text;
BEGIN
  v_actor := financing._require_permission('finance.manage_products');

  UPDATE financing.financial_products
  SET
    approval_status = 'draft',
    approved_by = NULL,
    approved_at = NULL,
    is_published = false,
    published_by = NULL,
    published_at = NULL
  WHERE id = p_product_id
    AND (approval_status <> 'draft' OR is_published = true)
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT id, approval_status INTO v_id, v_status
    FROM financing.financial_products
    WHERE id = p_product_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial product not found';
    END IF;

    RAISE EXCEPTION USING ERRCODE = '55000',
      MESSAGE = format('Product is already in draft (current: %s)', v_status);
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "financing"."reopen_product_for_edit"(uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "financing"."submit_product_for_review"("p_product_id" uuid)
RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_id uuid;
  v_status text;
BEGIN
  v_actor := financing._require_permission('finance.manage_products');

  -- A rejected product carries approved_by/approved_at from its last decision.
  -- Submitting must clear them, otherwise financial_products_approval_timestamps_check
  -- rejects 'in_review' with a stale approval stamp.
  UPDATE financing.financial_products
  SET
    approval_status = 'in_review',
    approved_by = NULL,
    approved_at = NULL
  WHERE id = p_product_id
    AND approval_status IN ('draft', 'rejected')
  RETURNING id, approval_status INTO v_id, v_status;

  IF v_id IS NULL THEN
    SELECT id, approval_status INTO v_id, v_status
    FROM financing.financial_products
    WHERE id = p_product_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial product not found';
    END IF;

    RAISE EXCEPTION USING ERRCODE = '55000',
      MESSAGE = format('Only draft or rejected products can be submitted for review (current: %s)', v_status);
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "financing"."submit_product_for_review"(uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "financing"."review_product"(
    "p_product_id" uuid,
    "p_approved" boolean,
    "p_notes" text DEFAULT NULL
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_id uuid;
  v_next_status text;
BEGIN
  v_actor := financing._require_permission('finance.review_products');

  -- NULL is an ambiguous decision: reject it explicitly instead of coercing it
  -- into a rejection, which would record a reviewer verdict nobody made.
  IF p_approved IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'p_approved must be explicitly true or false; NULL is not a valid review decision';
  END IF;

  IF p_approved THEN
    v_next_status := 'approved';
  ELSE
    v_next_status := 'rejected';
  END IF;

  UPDATE financing.financial_products
  SET
    approval_status = v_next_status,
    approval_notes = nullif(btrim(coalesce(p_notes, approval_notes)), ''),
    approved_by = v_actor,
    approved_at = now()
  WHERE id = p_product_id
    AND approval_status = 'in_review'
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT id INTO v_id
    FROM financing.financial_products
    WHERE id = p_product_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial product not found';
    END IF;

    RAISE EXCEPTION USING ERRCODE = '55000', MESSAGE = 'Only in_review products can be reviewed';
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "financing"."review_product"(uuid, boolean, text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "financing"."publish_product"("p_product_id" uuid)
RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_id uuid;
  v_provider_active boolean;
  v_provider_verification text;
  v_approval_status text;
  v_is_published boolean;
  v_product_active boolean;
BEGIN
  v_actor := financing._require_permission('finance.publish_products');

  SELECT
    fp.id,
    fpr.is_active,
    fpr.verification_status,
    fp.approval_status,
    fp.is_published,
    fp.is_active
  INTO v_id, v_provider_active, v_provider_verification, v_approval_status, v_is_published, v_product_active
  FROM financing.financial_products AS fp
  JOIN financing.financial_providers AS fpr
    ON fpr.id = fp.provider_id
  WHERE fp.id = p_product_id
  FOR UPDATE OF fp;

  IF v_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial product not found';
  END IF;

  IF NOT v_provider_active OR v_provider_verification <> 'verified' THEN
    RAISE EXCEPTION USING ERRCODE = '55000',
      MESSAGE = 'Only products from active verified providers can be published';
  END IF;

  IF NOT v_product_active THEN
    RAISE EXCEPTION USING ERRCODE = '55000',
      MESSAGE = 'Inactive products cannot be published';
  END IF;

  IF v_approval_status <> 'approved' OR v_is_published THEN
    RAISE EXCEPTION USING ERRCODE = '55000',
      MESSAGE = format(
        'Only approved unpublished products can be published (approval_status: %s, is_published: %s)',
        v_approval_status,
        v_is_published
      );
  END IF;

  UPDATE financing.financial_products
  SET
    is_published = true,
    published_by = v_actor,
    published_at = now()
  WHERE id = p_product_id;

  RETURN p_product_id;
END;
$$;

ALTER FUNCTION "financing"."publish_product"(uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "financing"."unpublish_product"("p_product_id" uuid)
RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_actor uuid;
  v_id uuid;
BEGIN
  v_actor := financing._require_permission('finance.publish_products');

  UPDATE financing.financial_products
  SET
    is_published = false,
    published_by = NULL,
    published_at = NULL
  WHERE id = p_product_id
    AND is_published = true
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT id INTO v_id
    FROM financing.financial_products
    WHERE id = p_product_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Financial product not found';
    END IF;

    RAISE EXCEPTION USING ERRCODE = '55000', MESSAGE = 'Product is not published';
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "financing"."unpublish_product"(uuid) OWNER TO "postgres";

-- ─────────────────────────────────────────────────────────────────────────────
-- Function grants
--   public RPCs        : EXECUTE to authenticated + service_role, never anon.
--   internal helpers   : NO client EXECUTE at all (see below).
-- anon is excluded from every financing function because it has no USAGE on
-- the schema; the explicit revokes below keep the intent visible even if USAGE
-- is added later.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  fn text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'financing.is_publicly_visible_product(uuid)',
    'financing.is_publicly_visible_provider(uuid)',
    'financing.manage_provider(uuid,text,text,text,text,text,text,text,text,text,jsonb,boolean)',
    'financing.set_provider_verification(uuid,text,text)',
    'financing.manage_product(uuid,uuid,text,text,text,text,text,text,numeric,numeric,numeric,text,integer,integer,boolean,text[],jsonb,boolean)',
    'financing.reopen_product_for_edit(uuid)',
    'financing.submit_product_for_review(uuid)',
    'financing.review_product(uuid,boolean,text)',
    'financing.publish_product(uuid)',
    'financing.unpublish_product(uuid)'
  ]
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', fn);
  END LOOP;

  -- Internal helpers: no API role may execute them directly.
  FOREACH fn IN ARRAY ARRAY[
    'financing.set_updated_at()',
    'financing._require_permission(text)',
    'financing._validate_slug(text,text)',
    'financing._validate_metadata_keys(jsonb)',
    'financing._merge_metadata(jsonb,jsonb)'
  ]
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role', fn);
  END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Table grants
-- Tables are read-only for API roles: no INSERT/UPDATE/DELETE grant exists for
-- anon, authenticated or service_role, so direct table writes fail with 42501
-- regardless of RLS. Writes are RPC-only.
-- anon gets no grant at all (it has no USAGE on the schema either).
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON TABLE "financing"."financial_providers" FROM PUBLIC, anon;
REVOKE ALL ON TABLE "financing"."financial_products" FROM PUBLIC, anon;

GRANT SELECT ON TABLE "financing"."financial_providers" TO authenticated, service_role;
GRANT SELECT ON TABLE "financing"."financial_products" TO authenticated, service_role;

ALTER TABLE "financing"."financial_providers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "financing"."financial_products" ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS policies
-- Only permission-gated reads remain. The former public table policies are
-- dropped so a partial re-run cannot leave an unprivileged read path behind;
-- public catalog read is provided by the views below instead, which expose a
-- curated column set.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "fin_providers_public_select" ON "financing"."financial_providers";
DROP POLICY IF EXISTS "fin_products_public_select" ON "financing"."financial_products";
DROP POLICY IF EXISTS "fin_providers_manage_select" ON "financing"."financial_providers";
DROP POLICY IF EXISTS "fin_products_manage_select" ON "financing"."financial_products";

-- Providers: managers/reviewers can read the full catalog including internal
-- reviewer columns. Everyone else (including ordinary authenticated users and,
-- via the absence of any policy, anon) reads zero rows.
CREATE POLICY "fin_providers_manage_select"
  ON "financing"."financial_providers"
  FOR SELECT
  TO "authenticated"
  USING (
    core.has_permission('finance.manage_providers'::text)
    OR core.has_permission('finance.verify_providers'::text)
  );

-- Products: catalog managers/reviewers can read all product rows including
-- approval_notes, approved_by and published_by.
CREATE POLICY "fin_products_manage_select"
  ON "financing"."financial_products"
  FOR SELECT
  TO "authenticated"
  USING (
    core.has_permission('finance.manage_products'::text)
    OR core.has_permission('finance.review_products'::text)
    OR core.has_permission('finance.publish_products'::text)
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- Public catalog views
-- Column-limited read surface for ordinary callers. They deliberately omit
-- verification_notes, verification/created ids, approval_notes, approval/
-- publication actor ids and metadata, which is exactly the set an unprivileged
-- caller must never see.
--
-- The views are owned by postgres, so they do not re-check table RLS; the hard
-- WHERE clause below is the predicate, and it is the same predicate the
-- (now removed) public table policies used. DML is revoked, so the views are
-- read-only for API roles.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW "financing"."public_financial_providers" AS
SELECT
  "id",
  "slug",
  "name",
  "provider_type",
  "description",
  "logo_url",
  "website_url",
  "country_code",
  "is_active",
  "verification_status",
  "created_at",
  "updated_at"
FROM "financing"."financial_providers"
WHERE "is_active" = true
  AND "verification_status" = 'verified'::text;

CREATE OR REPLACE VIEW "financing"."public_financial_products" AS
SELECT
  "id",
  "provider_id",
  "slug",
  "name",
  "product_type",
  "summary",
  "description",
  "currency",
  "min_amount",
  "max_amount",
  "interest_rate",
  "interest_rate_type",
  "min_tenure_days",
  "max_tenure_days",
  "requires_collateral",
  "requirements",
  "is_active",
  "is_published",
  "created_at",
  "updated_at"
FROM "financing"."financial_products"
WHERE "is_active" = true
  AND "approval_status" = 'approved'::text
  AND "is_published" = true
  AND EXISTS (
    SELECT 1
    FROM "financing"."financial_providers" AS "fpr"
    WHERE "fpr"."id" = "financial_products"."provider_id"
      AND "fpr"."is_active" = true
      AND "fpr"."verification_status" = 'verified'::text
  );

ALTER VIEW "financing"."public_financial_providers" OWNER TO "postgres";
ALTER VIEW "financing"."public_financial_products" OWNER TO "postgres";

COMMENT ON VIEW "financing"."public_financial_providers" IS
  'Public provider catalog. Excludes verification_notes, verified_by, created_by and metadata.';
COMMENT ON VIEW "financing"."public_financial_products" IS
  'Public product catalog. Excludes approval_notes, approved_by, published_by, created_by and metadata.';

REVOKE ALL ON "financing"."public_financial_providers" FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON "financing"."public_financial_products" FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON "financing"."public_financial_providers" TO authenticated;
GRANT SELECT ON "financing"."public_financial_products" TO authenticated;
-- service_role reads the underlying tables directly (it bypasses RLS in hosted
-- Supabase), so it does not need the views; see the header PRIVACY MODEL.

-- ─────────────────────────────────────────────────────────────────────────────
-- Post-registration verification
-- Fails the migration if the API surface does not match the contract above.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'financing'
    AND p.proname IN (
      'set_updated_at', '_require_permission', '_validate_slug',
      '_validate_metadata_keys', '_merge_metadata'
    )
    AND pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE');

  IF v_count <> 0 THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = format('internal financing helpers must not be executable by anon (%s leaked)', v_count);
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'financing'
    AND p.proname IN (
      'set_updated_at', '_require_permission', '_validate_slug',
      '_validate_metadata_keys', '_merge_metadata'
    )
    AND pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_count <> 0 THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = format('internal financing helpers must not be executable by authenticated (%s leaked)', v_count);
  END IF;

  IF pg_catalog.has_schema_privilege('anon', 'financing', 'USAGE') THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'schema financing must not be usable by anon (see header SCHEMA USAGE section)';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_tables
    WHERE schemaname = 'financing'
      AND tablename IN ('financial_providers', 'financial_products')
      AND has_table_privilege('anon', schemaname || '.' || tablename, 'SELECT')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'anon must not have SELECT on the financing catalog tables';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'financing'
      AND table_name IN ('public_financial_providers', 'public_financial_products')
      AND column_name IN ('verification_notes', 'approval_notes', 'verified_by',
                          'approved_by', 'published_by', 'created_by', 'metadata')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'public catalog views must not expose internal reviewer or metadata columns';
  END IF;
END;
$$;

-- ============================================================================
-- 20261012_minimal_subscription_foundation.sql
-- ----------------------------------------------------------------------------
-- STAGING-ONLY MINIMAL BASELINE — NOT A MIGRATION
--
-- Scope:
--   Minimal core/users/system/commerce baseline required to apply the
--   subscription and Refer & Earn foundation migrations on an empty
--   disposable Supabase staging project.
--
-- This file is intentionally outside supabase/migrations and must not be
-- treated as a historical migration. It contains no production business data
-- and no production project identifiers.
--
-- Excluded by design:
--   marketplace, financing, farm_management, assistant, stock/fulfillment,
--   M-Pesa processing, production accounting, and unrelated commerce objects.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Prerequisite checks
-- ----------------------------------------------------------------------------
DO $prereq$
BEGIN
    IF to_regprocedure('auth.uid()') IS NULL THEN
        RAISE EXCEPTION 'Missing Supabase prerequisite: auth.uid()';
    END IF;
    IF to_regprocedure('auth.role()') IS NULL THEN
        RAISE EXCEPTION 'Missing Supabase prerequisite: auth.role()';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        RAISE EXCEPTION 'Missing Supabase role: anon';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        RAISE EXCEPTION 'Missing Supabase role: authenticated';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        RAISE EXCEPTION 'Missing Supabase role: service_role';
    END IF;
END;
$prereq$;

-- ----------------------------------------------------------------------------
-- Schemas
-- ----------------------------------------------------------------------------
CREATE SCHEMA "core";
CREATE SCHEMA "users";
CREATE SCHEMA "system";
CREATE SCHEMA "commerce";

-- ----------------------------------------------------------------------------
-- Public UUID helper
-- Required by baseline and captured Finance defaults.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."uuid_generate_v7"() RETURNS uuid
LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN encode(overlay(set_bit(set_bit(uuid_send(gen_random_uuid()), 52, 1), 53, 1)
         placing substring(int8send(floor(extract(epoch from clock_timestamp()) * 1000)::bigint) from 3) from 1 for 6), 'hex')::uuid;
END;
$function$;

-- ----------------------------------------------------------------------------
-- Core / users tables
-- ----------------------------------------------------------------------------
CREATE TABLE "core"."countries" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "name" character varying(100) NOT NULL,
    "iso_alpha2" character(2) NOT NULL,
    "iso_alpha3" character(3) NOT NULL,
    "dialing_code" character varying(10) NOT NULL,
    "is_active" boolean DEFAULT false,
    CONSTRAINT "countries_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "users"."profiles" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "first_name" character varying NOT NULL,
    "last_name" character varying,
    "email" text,
    "phone" text,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now(),
    "country_id" uuid NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now(),
    "auth_user_id" uuid,
    "account_status" text DEFAULT 'active'::text,
    "is_phone_verified" boolean DEFAULT false NOT NULL,
    "is_email_verified" boolean DEFAULT false NOT NULL,
    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "profiles_auth_user_id_key" UNIQUE ("auth_user_id"),
    CONSTRAINT "profiles_email_key" UNIQUE ("email"),
    CONSTRAINT "profiles_phone_key" UNIQUE ("phone"),
    CONSTRAINT "profiles_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "core"."countries"("id"),
    CONSTRAINT "profiles_account_status_check" CHECK ("account_status" = ANY (ARRAY['active'::text, 'suspended'::text, 'blocked'::text]))
);

CREATE TABLE "core"."user_roles" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "name" text NOT NULL,
    "type" text NOT NULL,
    "description" text,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    "metadata" jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "roles_name_key" UNIQUE ("name")
);

CREATE OR REPLACE FUNCTION "core"."current_profile_id"() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog', 'users'
AS $function$
  SELECT p.id
  FROM users.profiles AS p
  WHERE p.auth_user_id = auth.uid()
  LIMIT 1
$function$;

CREATE OR REPLACE FUNCTION "core"."auth_user_id"() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
  SELECT auth.uid()
$function$;

CREATE TABLE "core"."entities" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "name" text NOT NULL,
    "slug" text,
    "entity_type" text NOT NULL,
    "owner_id" uuid DEFAULT core.current_profile_id() NOT NULL,
    "is_active" boolean DEFAULT true,
    "metadata" jsonb DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now(),
    "verification_status" text DEFAULT 'pending'::text,
    "legal_owner_type" text DEFAULT 'individual'::text,
    "primary_contact_profile_id" uuid,
    CONSTRAINT "entities_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "entities_slug_key" UNIQUE ("slug"),
    CONSTRAINT "entities_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"."profiles"("id"),
    CONSTRAINT "fk_entities_primary_contact" FOREIGN KEY ("primary_contact_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "entities_entity_type_check" CHECK ("entity_type" = ANY (ARRAY['farm'::text, 'trading_company'::text, 'service_provider'::text, 'cooperative'::text, 'individual_pro'::text, 'agrovet'::text])),
    CONSTRAINT "entities_legal_owner_type_check" CHECK ("legal_owner_type" = ANY (ARRAY['individual'::text, 'business'::text, 'cooperative'::text, 'organization'::text])),
    CONSTRAINT "entities_verification_status_check" CHECK ("verification_status" = ANY (ARRAY['pending'::text, 'verified'::text, 'rejected'::text, 'suspended'::text]))
);

CREATE TABLE "core"."entity_members" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "entity_id" uuid NOT NULL,
    "profile_id" uuid NOT NULL,
    "role_id" uuid NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT now(),
    "is_active" boolean DEFAULT true,
    "can_sell" boolean DEFAULT false,
    "can_manage" boolean DEFAULT false,
    "can_receive_payments" boolean DEFAULT false,
    "membership_status" text DEFAULT 'active'::text,
    CONSTRAINT "entity_members_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "entity_members_entity_id_profile_id_key" UNIQUE ("entity_id", "profile_id"),
    CONSTRAINT "entity_members_entity_id_fkey" FOREIGN KEY ("entity_id") REFERENCES "core"."entities"("id"),
    CONSTRAINT "entity_members_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "users"."profiles"("id"),
    CONSTRAINT "entity_members_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "core"."user_roles"("id"),
    CONSTRAINT "entity_members_membership_status_check" CHECK ("membership_status" = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'revoked'::text]))
);

CREATE TABLE "core"."entity_roles" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "profile_id" uuid NOT NULL,
    "entity_id" uuid NOT NULL,
    "role_id" uuid NOT NULL,
    "assigned_by" uuid DEFAULT core.current_profile_id(),
    "assigned_at" timestamp with time zone DEFAULT now(),
    "is_active" boolean DEFAULT true,
    "updated_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT now(),
    "metadata" jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT "profile_roles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "entity_roles_profile_id_entity_id_role_id_key" UNIQUE ("profile_id", "entity_id", "role_id"),
    CONSTRAINT "entity_roles_assigned_by_fkey" FOREIGN KEY ("assigned_by") REFERENCES "users"."profiles"("id"),
    CONSTRAINT "entity_roles_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "users"."profiles"("id") ON DELETE CASCADE,
    CONSTRAINT "entity_roles_user_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "core"."user_roles"("id") ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION "core"."ensure_entity_for_profile"("p_profile_id" uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog', 'auth', 'core', 'users'
AS $function$
DECLARE
  v_auth_user_id uuid;
  v_profile_id uuid;
  v_entity_id uuid;
  v_owner_role_id uuid;
  v_first_name text;
  v_service_role boolean;
BEGIN
  v_service_role := auth.uid() IS NULL AND auth.role() = 'service_role';

  IF auth.uid() IS NULL AND NOT v_service_role THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  IF v_service_role AND p_profile_id IS NULL THEN
    RAISE EXCEPTION 'profile id required for service role' USING ERRCODE = '42501';
  END IF;

  SELECT p.id, p.auth_user_id, p.first_name
    INTO v_profile_id, v_auth_user_id, v_first_name
  FROM users.profiles p
  WHERE p.is_active = true
    AND p.account_status = 'active'
    AND (
      (v_service_role AND p.id = p_profile_id)
      OR
      (NOT v_service_role AND p.auth_user_id = auth.uid()
       AND (p_profile_id IS NULL OR p.id = p_profile_id))
    )
  FOR UPDATE;

  IF v_profile_id IS NULL OR
     (NOT v_service_role AND v_auth_user_id IS DISTINCT FROM auth.uid()) THEN
    RAISE EXCEPTION 'active profile not found' USING ERRCODE = '42501';
  END IF;

  SELECT r.id
    INTO v_owner_role_id
  FROM core.user_roles r
  WHERE lower(r.name) = 'owner'
    AND r.type = 'system'
    AND r.is_active = true
  ORDER BY r.id
  LIMIT 1;

  IF v_owner_role_id IS NULL THEN
    RAISE EXCEPTION 'missing active system owner role';
  END IF;

  SELECT e.id
    INTO v_entity_id
  FROM core.entities e
  WHERE e.owner_id = v_profile_id
    AND e.entity_type = 'individual_pro'
    AND e.is_active = true
  ORDER BY e.created_at, e.id
  LIMIT 1
  FOR UPDATE;

  IF v_entity_id IS NULL THEN
    INSERT INTO core.entities (
      name, entity_type, owner_id, is_active, metadata,
      primary_contact_profile_id, legal_owner_type
    ) VALUES (
      'Entity for ' || coalesce(nullif(v_first_name, ''), 'user'),
      'individual_pro', v_profile_id, true, '{}'::jsonb,
      v_profile_id, 'individual'
    )
    RETURNING id INTO v_entity_id;
  END IF;

  INSERT INTO core.entity_members (
    entity_id, profile_id, role_id, can_sell, can_manage,
    can_receive_payments, membership_status, is_active
  ) VALUES (
    v_entity_id, v_profile_id, v_owner_role_id, false, true,
    false, 'active', true
  )
  ON CONFLICT (entity_id, profile_id) DO UPDATE
  SET role_id = EXCLUDED.role_id,
      membership_status = 'active',
      is_active = true,
      can_manage = true;

  INSERT INTO core.entity_roles (
    entity_id, profile_id, role_id, assigned_by, is_active
  ) VALUES (
    v_entity_id, v_profile_id, v_owner_role_id, v_profile_id, true
  )
  ON CONFLICT (profile_id, entity_id, role_id) DO UPDATE
  SET assigned_by = coalesce(core.entity_roles.assigned_by, EXCLUDED.assigned_by),
      is_active = true,
      updated_at = now();
END;
$function$;

-- ----------------------------------------------------------------------------
-- System tables
-- ----------------------------------------------------------------------------
CREATE TABLE "system"."modules" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "module_key" text NOT NULL,
    "module_name" text NOT NULL,
    "module_description" text,
    "is_enabled" boolean DEFAULT true NOT NULL,
    "is_public" boolean DEFAULT true NOT NULL,
    "is_beta" boolean DEFAULT false NOT NULL,
    "is_premium" boolean DEFAULT false NOT NULL,
    "maintenance_mode" boolean DEFAULT false NOT NULL,
    "dashboard_visible" boolean DEFAULT true NOT NULL,
    "required_subscription" text,
    "required_roles" text[] DEFAULT '{}'::text[],
    "icon" text,
    "version" text DEFAULT '1.0.0'::text,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "modules_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "modules_module_key_key" UNIQUE ("module_key")
);

CREATE OR REPLACE FUNCTION "system"."update_updated_at_column"() RETURNS trigger
LANGUAGE plpgsql
AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$;

CREATE TRIGGER "trg_modules_updated_at"
BEFORE UPDATE ON "system"."modules"
FOR EACH ROW EXECUTE FUNCTION "system"."update_updated_at_column"();

CREATE TABLE "system"."billing_accounts" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "entity_id" uuid,
    "profile_id" uuid,
    "account_type" text NOT NULL,
    "currency" text DEFAULT 'KES'::text NOT NULL,
    "status" text DEFAULT 'active'::text NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "billing_accounts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "uq_billing_account_entity_profile" UNIQUE ("entity_id", "profile_id"),
    CONSTRAINT "billing_accounts_entity_id_fkey" FOREIGN KEY ("entity_id") REFERENCES "core"."entities"("id") ON DELETE SET NULL,
    CONSTRAINT "billing_accounts_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "billing_accounts_account_type_check" CHECK ("account_type" = ANY (ARRAY['individual'::text, 'business'::text, 'cooperative'::text, 'supplier'::text, 'partner'::text, 'platform_internal'::text])),
    CONSTRAINT "billing_accounts_status_check" CHECK ("status" = ANY (ARRAY['active'::text, 'suspended'::text, 'closed'::text, 'restricted'::text]))
);

CREATE TABLE "system"."subscription_plans" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "plan_key" text NOT NULL,
    "plan_name" text NOT NULL,
    "module_key" text,
    "billing_cycle" text NOT NULL,
    "amount" numeric(18,2) DEFAULT 0 NOT NULL,
    "currency" text DEFAULT 'KES'::text NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "features_json" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "subscription_plans_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "subscription_plans_plan_key_key" UNIQUE ("plan_key"),
    CONSTRAINT "subscription_plans_module_key_fkey" FOREIGN KEY ("module_key") REFERENCES "system"."modules"("module_key") ON DELETE SET NULL,
    CONSTRAINT "subscription_plans_billing_cycle_check" CHECK ("billing_cycle" = ANY (ARRAY['once'::text, 'monthly'::text, 'quarterly'::text, 'yearly'::text]))
);

CREATE TABLE "system"."active_subscriptions" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "billing_account_id" uuid NOT NULL,
    "plan_id" uuid NOT NULL,
    "status" text DEFAULT 'active'::text NOT NULL,
    "start_date" timestamp with time zone DEFAULT now() NOT NULL,
    "end_date" timestamp with time zone,
    "auto_renew" boolean DEFAULT false NOT NULL,
    "payment_reference" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "active_subscriptions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "active_subscriptions_billing_account_id_fkey" FOREIGN KEY ("billing_account_id") REFERENCES "system"."billing_accounts"("id") ON DELETE CASCADE,
    CONSTRAINT "active_subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "system"."subscription_plans"("id") ON DELETE RESTRICT,
    CONSTRAINT "active_subscriptions_status_check" CHECK ("status" = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text, 'pending'::text, 'suspended'::text]))
);

CREATE TABLE "system"."invoices" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "billing_account_id" uuid NOT NULL,
    "invoice_number" text NOT NULL,
    "module_name" text NOT NULL,
    "reference_table" text,
    "reference_id" uuid,
    "status" text DEFAULT 'pending'::text NOT NULL,
    "total_amount" numeric(18,2) NOT NULL,
    "currency" text DEFAULT 'KES'::text NOT NULL,
    "due_date" timestamp with time zone,
    "paid_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "invoices_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "invoices_invoice_number_key" UNIQUE ("invoice_number"),
    CONSTRAINT "invoices_billing_account_id_fkey" FOREIGN KEY ("billing_account_id") REFERENCES "system"."billing_accounts"("id") ON DELETE RESTRICT,
    CONSTRAINT "invoices_status_check" CHECK ("status" = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'cancelled'::text, 'overdue'::text, 'refunded'::text]))
);

CREATE TABLE "system"."invoice_items" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "invoice_id" uuid NOT NULL,
    "item_type" text NOT NULL,
    "description" text NOT NULL,
    "quantity" numeric(18,2) DEFAULT 1 NOT NULL,
    "unit_price" numeric(18,2) DEFAULT 0 NOT NULL,
    "total_amount" numeric(18,2) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "invoice_items_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "invoice_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "system"."invoices"("id") ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- Minimal commerce support
-- business_profiles is copied from the production baseline. orders is a
-- reduced staging projection because production orders has unrelated
-- marketplace/listings and core.units dependencies outside this scope.
-- ----------------------------------------------------------------------------
CREATE TABLE "commerce"."business_profiles" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "entity_type" text NOT NULL,
    "primary_contact_id" uuid,
    "supplier_name" text NOT NULL,
    "contact_person" text,
    "phone" text,
    "email" text,
    "county_id" uuid,
    "subcounty_id" uuid,
    "ward_id" uuid,
    "physical_address" text,
    "business_reg_no" text,
    "kra_pin" text,
    "id_number" text,
    "license_no" text,
    "verification_status" text DEFAULT 'pending'::text NOT NULL,
    "verification_notes" text,
    "verified_by" uuid,
    "verified_at" timestamp with time zone,
    "rating" numeric,
    "user_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    "deleted_at" timestamp with time zone,
    "is_active" boolean DEFAULT true,
    "metadata" jsonb DEFAULT '{}'::jsonb,
    "entity_id" uuid NOT NULL,
    "ownership_scope" text DEFAULT 'organizational'::text,
    CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "business_profiles_entity_id_fkey" FOREIGN KEY ("entity_id") REFERENCES "core"."entities"("id"),
    CONSTRAINT "business_profiles_profile_id_fkey" FOREIGN KEY ("primary_contact_id") REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "business_profiles_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "users"."profiles"("id"),
    CONSTRAINT "business_profiles_ownership_scope_check" CHECK ("ownership_scope" = ANY (ARRAY['personal'::text, 'organizational'::text])),
    CONSTRAINT "individual_user_check" CHECK ((("entity_type" = 'individual'::text) AND ("primary_contact_id" IS NOT NULL)) OR ("entity_type" <> 'individual'::text)),
    CONSTRAINT "suppliers_supplier_type_check" CHECK ("entity_type" = ANY (ARRAY['individual'::text, 'company'::text, 'agrovet'::text, 'cooperative'::text, 'trader'::text])),
    CONSTRAINT "suppliers_verification_status_check" CHECK ("verification_status" = ANY (ARRAY['pending'::text, 'verified'::text, 'rejected'::text, 'suspended'::text]))
);

CREATE TABLE "commerce"."orders" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "buyer_id" uuid NOT NULL,
    "supplier_id" uuid NOT NULL,
    "total_amount" numeric(15,2) NOT NULL,
    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- ----------------------------------------------------------------------------
-- Minimal grants for staging API verification.
-- No client DML is granted. Service-role access is required by the harness
-- for fixture seeding and readback.
-- ----------------------------------------------------------------------------
REVOKE ALL ON SCHEMA "core", "users", "system", "commerce" FROM PUBLIC, "anon", "authenticated";
GRANT USAGE ON SCHEMA "core", "users", "system", "commerce" TO "service_role";
GRANT USAGE ON SCHEMA "system" TO "authenticated";

REVOKE ALL ON TABLE "core"."countries", "users"."profiles" FROM PUBLIC, "anon", "authenticated";
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "core"."countries", "users"."profiles" TO "service_role";

REVOKE ALL ON TABLE "core"."user_roles", "core"."entities", "core"."entity_members", "core"."entity_roles" FROM PUBLIC, "anon", "authenticated";
GRANT SELECT ON TABLE "core"."user_roles", "core"."entities", "core"."entity_members", "core"."entity_roles" TO "service_role";

REVOKE ALL ON TABLE "system"."modules", "system"."billing_accounts", "system"."subscription_plans", "system"."active_subscriptions", "system"."invoices", "system"."invoice_items" FROM PUBLIC, "anon", "authenticated";
GRANT SELECT ON TABLE "system"."modules", "system"."billing_accounts", "system"."subscription_plans", "system"."active_subscriptions", "system"."invoices", "system"."invoice_items" TO "service_role";

REVOKE ALL ON TABLE "commerce"."business_profiles", "commerce"."orders" FROM PUBLIC, "anon", "authenticated";
GRANT SELECT ON TABLE "commerce"."business_profiles", "commerce"."orders" TO "service_role";

-- ----------------------------------------------------------------------------
-- Minimum seed configuration
-- ----------------------------------------------------------------------------
INSERT INTO "core"."countries" ("id", "name", "iso_alpha2", "iso_alpha3", "dialing_code", "is_active")
VALUES ('00000000-0000-4000-8000-000000000101', 'Staging Testland', 'ZZ', 'ZZZ', '999', true);

INSERT INTO "core"."user_roles" ("id", "name", "type", "description", "is_active")
VALUES ('00000000-0000-4000-8000-000000000102', 'owner', 'system', 'Staging owner role', true);

INSERT INTO "users"."profiles" (
    "id", "first_name", "last_name", "email", "country_id",
    "is_active", "account_status", "is_phone_verified", "is_email_verified"
) VALUES (
    '00000000-0000-4000-8000-000000000103',
    'Staging Platform Owner',
    'Owner',
    'staging-platform-owner@example.invalid',
    '00000000-0000-4000-8000-000000000101',
    true,
    'active',
    false,
    false
);

INSERT INTO "core"."entities" (
    "id", "name", "slug", "entity_type", "owner_id", "is_active", "metadata",
    "verification_status", "legal_owner_type", "primary_contact_profile_id"
) VALUES (
    '00000000-0000-4000-8000-000000000104',
    'Staging Platform Administration',
    'staging-platform-administration',
    'individual_pro',
    '00000000-0000-4000-8000-000000000103',
    true,
    '{"platform_entity":true,"purpose":"platform_administration"}'::jsonb,
    'verified',
    'individual',
    '00000000-0000-4000-8000-000000000103'
);

INSERT INTO "core"."entity_members" (
    "id", "entity_id", "profile_id", "role_id", "is_active",
    "can_sell", "can_manage", "can_receive_payments", "membership_status"
) VALUES (
    '00000000-0000-4000-8000-000000000105',
    '00000000-0000-4000-8000-000000000104',
    '00000000-0000-4000-8000-000000000103',
    '00000000-0000-4000-8000-000000000102',
    true,
    false,
    true,
    false,
    'active'
);

INSERT INTO "core"."entity_roles" (
    "id", "profile_id", "entity_id", "role_id", "assigned_by", "is_active"
) VALUES (
    '00000000-0000-4000-8000-000000000106',
    '00000000-0000-4000-8000-000000000103',
    '00000000-0000-4000-8000-000000000104',
    '00000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000103',
    true
);

-- ----------------------------------------------------------------------------
-- Final verification
-- ----------------------------------------------------------------------------
DO $verify$
DECLARE
    v_count bigint;
BEGIN
    IF to_regclass('public.uuid_generate_v7') IS NULL
       AND to_regprocedure('public.uuid_generate_v7()') IS NULL THEN
        RAISE EXCEPTION 'uuid_generate_v7 missing';
    END IF;
    IF to_regprocedure('core.ensure_entity_for_profile(uuid)') IS NULL THEN
        RAISE EXCEPTION 'core.ensure_entity_for_profile missing';
    END IF;
    IF to_regclass('system.billing_accounts') IS NULL
       OR to_regclass('system.subscription_plans') IS NULL
       OR to_regclass('system.active_subscriptions') IS NULL
       OR to_regclass('system.invoices') IS NULL
       OR to_regclass('system.invoice_items') IS NULL THEN
        RAISE EXCEPTION 'required system table missing';
    END IF;
    SELECT count(*) INTO v_count FROM core.entities
     WHERE metadata->>'platform_entity' = 'true'
       AND metadata->>'purpose' = 'platform_administration';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one platform administration entity, found %', v_count;
    END IF;
    SELECT count(*) INTO v_count FROM core.user_roles
     WHERE lower(name) = 'owner' AND type = 'system' AND is_active = true;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one active owner system role, found %', v_count;
    END IF;
    SELECT count(*) INTO v_count FROM users.profiles
     WHERE id = '00000000-0000-4000-8000-000000000103';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'staging platform owner profile missing';
    END IF;
    SELECT count(*) INTO v_count FROM system.billing_accounts;
    IF v_count <> 0 THEN RAISE EXCEPTION 'billing_accounts is not empty'; END IF;
    SELECT count(*) INTO v_count FROM system.subscription_plans;
    IF v_count <> 0 THEN RAISE EXCEPTION 'subscription_plans is not empty'; END IF;
    SELECT count(*) INTO v_count FROM system.active_subscriptions;
    IF v_count <> 0 THEN RAISE EXCEPTION 'active_subscriptions is not empty'; END IF;
    SELECT count(*) INTO v_count FROM system.invoices;
    IF v_count <> 0 THEN RAISE EXCEPTION 'invoices is not empty'; END IF;
    SELECT count(*) INTO v_count FROM system.invoice_items;
    IF v_count <> 0 THEN RAISE EXCEPTION 'invoice_items is not empty'; END IF;
END;
$verify$;

COMMIT;

-- Reputation Phase 1 — canonical subject foundation.
--
-- Scope:
--   * one reputation schema;
--   * one typed subject registry;
--   * canonical subject identities only.
--
-- Explicitly out of scope:
--   * reviews, revisions, engagements, evidence, verification;
--   * eligibility, moderation, responses, reports, appeals, aggregates;
--   * service/service-provider and extension-provider subjects;
--   * business_profile subjects;
--   * public Reputation read interfaces;
--   * Flutter Reputation code.
--
-- Historical-retention rule:
--   A canonical identity referenced by a Reputation subject must remain
--   referenceable. All canonical FKs therefore use ON DELETE RESTRICT.
--   Subject retirement is the Reputation lifecycle mechanism.
--
--   core.item_variants.item_id already uses ON DELETE CASCADE. A Reputation
--   variant subject using RESTRICT intentionally prevents deletion of the
--   parent item through that cascade once the variant has reputation history.

-- Accepted pre-existing dependency:
--   item/product Reputation subjects reference canonical core.items.
--   core.items currently has RLS disabled and broad client DML grants.
--   Phase 1 deliberately does NOT modify core.items security or privileges;
--   this is an accepted Phase 1 dependency, not a new Reputation exception.
--   Public product Reputation remains blocked pending separate Core item
--   security remediation/approval.
--
-- Future-object creator:
--   Reputation migrations and future Reputation objects are created by the
--   postgres role. The default-privilege sections below therefore protect
--   objects created by postgres. No other creator role is supported in
--   Phase 1 and none is granted privileges here.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Reputation schema and ownership/security boundary.
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS "reputation";

ALTER SCHEMA "reputation" OWNER TO postgres;

REVOKE ALL ON SCHEMA "reputation"
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT USAGE ON SCHEMA "reputation" TO "service_role";

-- ---------------------------------------------------------------------------
-- 2. Canonical subject registry.
-- ---------------------------------------------------------------------------
CREATE TABLE "reputation"."subjects" (
    "id" uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    "subject_type" text NOT NULL,
    "subject_role" text NOT NULL,
    "profile_id" uuid,
    "entity_id" uuid,
    "listing_id" uuid,
    "item_id" uuid,
    "variant_id" uuid,
    "status" text NOT NULL DEFAULT 'active',
    "created_at" timestamptz NOT NULL DEFAULT clock_timestamp(),
    "updated_at" timestamptz NOT NULL DEFAULT clock_timestamp(),
    "retired_at" timestamptz,
    CONSTRAINT "reputation_subjects_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "reputation"."subjects" OWNER TO postgres;

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_profile_id_fkey"
    FOREIGN KEY ("profile_id") REFERENCES users.profiles("id")
    ON DELETE RESTRICT;

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_entity_id_fkey"
    FOREIGN KEY ("entity_id") REFERENCES core.entities("id")
    ON DELETE RESTRICT;

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_listing_id_fkey"
    FOREIGN KEY ("listing_id") REFERENCES marketplace.listings("id")
    ON DELETE RESTRICT;

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_item_id_fkey"
    FOREIGN KEY ("item_id") REFERENCES core.items("id")
    ON DELETE RESTRICT;

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_variant_id_fkey"
    FOREIGN KEY ("variant_id") REFERENCES core.item_variants("id")
    ON DELETE RESTRICT;

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_one_identity_check"
    CHECK (
        num_nonnulls(
            "profile_id",
            "entity_id",
            "listing_id",
            "item_id",
            "variant_id"
        ) = 1
    );

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_type_identity_check"
    CHECK (
        ("subject_type" = 'profile' AND "profile_id" IS NOT NULL)
        OR ("subject_type" = 'entity' AND "entity_id" IS NOT NULL)
        OR ("subject_type" = 'listing' AND "listing_id" IS NOT NULL)
        OR ("subject_type" = 'item' AND "item_id" IS NOT NULL)
        OR ("subject_type" = 'variant' AND "variant_id" IS NOT NULL)
    );

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_role_type_check"
    CHECK (
        ("subject_type" = 'profile'
            AND "subject_role" IN ('farmer', 'person', 'seller'))
        OR ("subject_type" = 'entity'
            AND "subject_role" IN ('entity', 'seller'))
        OR ("subject_type" = 'listing'
            AND "subject_role" = 'listing')
        OR ("subject_type" = 'item'
            AND "subject_role" = 'product')
        OR ("subject_type" = 'variant'
            AND "subject_role" = 'product_variant')
    );

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_status_check"
    CHECK ("status" IN ('active', 'retired'));

ALTER TABLE "reputation"."subjects"
    ADD CONSTRAINT "reputation_subjects_retirement_check"
    CHECK (
        ("status" = 'active' AND "retired_at" IS NULL)
        OR ("status" = 'retired' AND "retired_at" IS NOT NULL)
    );

CREATE UNIQUE INDEX "reputation_subjects_profile_role_uidx"
    ON "reputation"."subjects" ("profile_id", "subject_role")
    WHERE "profile_id" IS NOT NULL;

CREATE UNIQUE INDEX "reputation_subjects_entity_role_uidx"
    ON "reputation"."subjects" ("entity_id", "subject_role")
    WHERE "entity_id" IS NOT NULL;

CREATE UNIQUE INDEX "reputation_subjects_listing_uidx"
    ON "reputation"."subjects" ("listing_id")
    WHERE "listing_id" IS NOT NULL;

CREATE UNIQUE INDEX "reputation_subjects_item_uidx"
    ON "reputation"."subjects" ("item_id")
    WHERE "item_id" IS NOT NULL;

CREATE UNIQUE INDEX "reputation_subjects_variant_uidx"
    ON "reputation"."subjects" ("variant_id")
    WHERE "variant_id" IS NOT NULL;

ALTER TABLE "reputation"."subjects" ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 3. Immutability and delete-prevention guards.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "reputation"."guard_subject_identity"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    IF NEW."id" IS DISTINCT FROM OLD."id"
       OR NEW."subject_type" IS DISTINCT FROM OLD."subject_type"
       OR NEW."subject_role" IS DISTINCT FROM OLD."subject_role"
       OR NEW."profile_id" IS DISTINCT FROM OLD."profile_id"
       OR NEW."entity_id" IS DISTINCT FROM OLD."entity_id"
       OR NEW."listing_id" IS DISTINCT FROM OLD."listing_id"
       OR NEW."item_id" IS DISTINCT FROM OLD."item_id"
       OR NEW."variant_id" IS DISTINCT FROM OLD."variant_id"
       OR NEW."created_at" IS DISTINCT FROM OLD."created_at" THEN
        RAISE EXCEPTION 'Reputation subject identity and creation time are immutable'
            USING ERRCODE = '23514';
    END IF;

    -- The only valid status transition is active -> retired.
    IF OLD."status" = 'retired' AND NEW."status" IS DISTINCT FROM 'retired' THEN
        RAISE EXCEPTION 'Retired Reputation subject cannot be reactivated'
            USING ERRCODE = '23514';
    END IF;

    -- Once retired, the retirement timestamp is historical evidence and must
    -- not be rewritten by direct DML.
    IF OLD."status" = 'retired'
       AND NEW."retired_at" IS DISTINCT FROM OLD."retired_at" THEN
        RAISE EXCEPTION 'Retired Reputation subject timestamp is immutable'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION "reputation"."guard_subject_identity"() OWNER TO postgres;

CREATE OR REPLACE FUNCTION "reputation"."prevent_subject_delete"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    RAISE EXCEPTION 'Reputation subjects cannot be deleted; retire the subject instead'
        USING ERRCODE = '42501';
END;
$function$;

ALTER FUNCTION "reputation"."prevent_subject_delete"() OWNER TO postgres;

CREATE TRIGGER "trg_reputation_subjects_identity_immutable"
    BEFORE UPDATE ON "reputation"."subjects"
    FOR EACH ROW
    EXECUTE FUNCTION "reputation"."guard_subject_identity"();

CREATE TRIGGER "trg_reputation_subjects_no_delete"
    BEFORE DELETE ON "reputation"."subjects"
    FOR EACH ROW
    EXECUTE FUNCTION "reputation"."prevent_subject_delete"();

-- ---------------------------------------------------------------------------
-- 4. Trusted registration and retirement functions.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "reputation"."register_subject"(
    p_subject_type text,
    p_subject_role text,
    p_identity_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users', 'marketplace'
AS $function$
DECLARE
    v_subject_type text := lower(btrim(COALESCE(p_subject_type, '')));
    v_subject_role text := lower(btrim(COALESCE(p_subject_role, '')));
    v_existing "reputation"."subjects"%ROWTYPE;
    v_subject_id uuid;
BEGIN
    IF v_subject_type = '' OR v_subject_role = '' OR p_identity_id IS NULL THEN
        RAISE EXCEPTION 'subject_type, subject_role and identity_id are required'
            USING ERRCODE = '22023';
    END IF;

    IF NOT (
        (v_subject_type = 'profile' AND v_subject_role IN ('farmer', 'person', 'seller'))
        OR (v_subject_type = 'entity' AND v_subject_role IN ('entity', 'seller'))
        OR (v_subject_type = 'listing' AND v_subject_role = 'listing')
        OR (v_subject_type = 'item' AND v_subject_role = 'product')
        OR (v_subject_type = 'variant' AND v_subject_role = 'product_variant')
    ) THEN
        RAISE EXCEPTION 'unsupported Reputation subject type/role: %/%',
            v_subject_type, v_subject_role
            USING ERRCODE = '22023';
    END IF;

    -- Serialize registration for this identity and role. Unique indexes remain
    -- the final duplicate guard.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            'reputation.subjects:' || v_subject_type || ':' || v_subject_role || ':' || p_identity_id::text,
            0
        )
    );

    SELECT *
      INTO v_existing
      FROM "reputation"."subjects" AS s
     WHERE s."subject_type" = v_subject_type
       AND s."subject_role" = v_subject_role
       AND (
           (v_subject_type = 'profile' AND s."profile_id" = p_identity_id)
           OR (v_subject_type = 'entity' AND s."entity_id" = p_identity_id)
           OR (v_subject_type = 'listing' AND s."listing_id" = p_identity_id)
           OR (v_subject_type = 'item' AND s."item_id" = p_identity_id)
           OR (v_subject_type = 'variant' AND s."variant_id" = p_identity_id)
       );

    IF FOUND THEN
        IF v_existing."status" = 'retired' THEN
            RAISE EXCEPTION 'Reputation subject is retired and cannot be re-registered'
                USING ERRCODE = 'P0001';
        END IF;
        RETURN v_existing."id";
    END IF;

    IF v_subject_type = 'profile' THEN
        IF NOT EXISTS (
            SELECT 1
              FROM "users"."profiles" AS p
             WHERE p."id" = p_identity_id
               AND p."deleted_at" IS NULL
        ) THEN
            RAISE EXCEPTION 'Canonical profile identity not found or deleted'
                USING ERRCODE = 'P0002';
        END IF;
    ELSIF v_subject_type = 'entity' THEN
        IF NOT EXISTS (
            SELECT 1
              FROM "core"."entities" AS e
             WHERE e."id" = p_identity_id
        ) THEN
            RAISE EXCEPTION 'Canonical entity identity not found'
                USING ERRCODE = 'P0002';
        END IF;
    ELSIF v_subject_type = 'listing' THEN
        IF NOT EXISTS (
            SELECT 1
              FROM "marketplace"."listings" AS l
             WHERE l."id" = p_identity_id
        ) THEN
            RAISE EXCEPTION 'Canonical listing identity not found'
                USING ERRCODE = 'P0002';
        END IF;
    ELSIF v_subject_type = 'item' THEN
        IF NOT EXISTS (
            SELECT 1
              FROM "core"."items" AS i
             WHERE i."id" = p_identity_id
        ) THEN
            RAISE EXCEPTION 'Canonical item identity not found'
                USING ERRCODE = 'P0002';
        END IF;
    ELSIF v_subject_type = 'variant' THEN
        IF NOT EXISTS (
            SELECT 1
              FROM "core"."item_variants" AS v
             WHERE v."id" = p_identity_id
        ) THEN
            RAISE EXCEPTION 'Canonical variant identity not found'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;

    INSERT INTO "reputation"."subjects" (
        "subject_type",
        "subject_role",
        "profile_id",
        "entity_id",
        "listing_id",
        "item_id",
        "variant_id"
    )
    VALUES (
        v_subject_type,
        v_subject_role,
        CASE WHEN v_subject_type = 'profile' THEN p_identity_id END,
        CASE WHEN v_subject_type = 'entity' THEN p_identity_id END,
        CASE WHEN v_subject_type = 'listing' THEN p_identity_id END,
        CASE WHEN v_subject_type = 'item' THEN p_identity_id END,
        CASE WHEN v_subject_type = 'variant' THEN p_identity_id END
    )
    RETURNING "id" INTO v_subject_id;

    RETURN v_subject_id;
END;
$function$;

ALTER FUNCTION "reputation"."register_subject"(text, text, uuid)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION "reputation"."retire_subject"(
    p_subject_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_subject "reputation"."subjects"%ROWTYPE;
BEGIN
    IF p_subject_id IS NULL THEN
        RAISE EXCEPTION 'subject_id is required' USING ERRCODE = '22023';
    END IF;

    SELECT *
      INTO v_subject
      FROM "reputation"."subjects" AS s
     WHERE s."id" = p_subject_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reputation subject not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_subject."status" = 'retired' THEN
        RETURN v_subject."id";
    END IF;

    UPDATE "reputation"."subjects"
       SET "status" = 'retired',
           "retired_at" = clock_timestamp(),
           "updated_at" = clock_timestamp()
     WHERE "id" = p_subject_id;

    RETURN p_subject_id;
END;
$function$;

ALTER FUNCTION "reputation"."retire_subject"(uuid)
    OWNER TO postgres;

-- ---------------------------------------------------------------------------
-- 5. Function, table and schema privileges.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION "reputation"."register_subject"(text, text, uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION "reputation"."retire_subject"(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION "reputation"."guard_subject_identity"()
    FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION "reputation"."prevent_subject_delete"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT EXECUTE ON FUNCTION "reputation"."register_subject"(text, text, uuid)
    TO "service_role";
GRANT EXECUTE ON FUNCTION "reputation"."retire_subject"(uuid)
    TO "service_role";

REVOKE ALL ON TABLE "reputation"."subjects"
    FROM PUBLIC, "anon", "authenticated", "service_role";

REVOKE ALL ON SCHEMA "reputation"
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT USAGE ON SCHEMA "reputation" TO "service_role";

-- ---------------------------------------------------------------------------
-- 6. Default-deny posture for future Reputation objects.
-- ---------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "reputation"
    REVOKE ALL ON TABLES
    FROM PUBLIC, "anon", "authenticated", "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "reputation"
    REVOKE ALL ON SEQUENCES
    FROM PUBLIC, "anon", "authenticated", "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA "reputation"
    REVOKE EXECUTE ON FUNCTIONS
    FROM PUBLIC, "anon", "authenticated", "service_role";

-- ---------------------------------------------------------------------------
-- 7. Documentation.
-- ---------------------------------------------------------------------------
COMMENT ON SCHEMA "reputation" IS
    'Canonical Vunio reputation domain. Phase 1 contains only the subject registry.';

COMMENT ON TABLE "reputation"."subjects" IS
    'Historical reputation subject identities. Subjects are retired, never normally deleted. Canonical identity FKs use RESTRICT to preserve history.';

COMMENT ON COLUMN "reputation"."subjects"."subject_type" IS
    'Canonical subject category. Phase 1 supports profile, entity, listing, item and variant only.';

COMMENT ON COLUMN "reputation"."subjects"."subject_role" IS
    'Reputation role within the subject type. Phase 1 supports farmer/person/seller for profiles, entity/seller for entities, listing, product and product_variant.';

COMMENT ON COLUMN "reputation"."subjects"."status" IS
    'Reputation lifecycle: active or retired. Retirement preserves canonical identity history.';

COMMENT ON FUNCTION "reputation"."register_subject"(text, text, uuid) IS
    'Service-role-only idempotent registration of a canonical Phase 1 Reputation subject. Existing active subjects are returned; retired subjects are rejected.';

COMMENT ON FUNCTION "reputation"."retire_subject"(uuid) IS
    'Service-role-only retirement of an existing Reputation subject. Identity references and historical row are preserved.';

COMMENT ON FUNCTION "reputation"."guard_subject_identity"() IS
    'Rejects updates to Reputation subject identity, type or role. Does not replace database-owner governance.';

COMMENT ON FUNCTION "reputation"."prevent_subject_delete"() IS
    'Rejects ordinary deletion of Reputation subjects. Does not replace database-owner governance.';

COMMIT;

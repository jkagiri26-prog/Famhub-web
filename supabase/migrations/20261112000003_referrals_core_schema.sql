-- ============================================================================
-- 20261112000003_referrals_core_schema
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Create the referrals schema and its core records:
--     * programme settings
--     * attribution sessions and assisted-registration audit
--     * effective-dated Vunio employee exclusions
--     * referrals and rewards
--     * duplicate/self-referral review cases
--     * append-only audit and reward event history
--
-- APPROVED RULES ENCODED HERE
--   * KSh 40 reward default, KES, KSh 500 minimum withdrawal.
--   * One referral per referred profile.
--   * One reward per referral.
--   * Vunio employee exclusions are effective-dated. Partner employees are not
--     entered here and remain eligible.
--
-- SCOPE
--   Schema and defaults only. No attribution, eligibility, reward accrual or
--   payout function is implemented in this migration.
--
-- ROLLBACK
--   DROP SCHEMA IF EXISTS referrals CASCADE;
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS "referrals";

GRANT USAGE ON SCHEMA "referrals" TO "authenticated", "service_role";
REVOKE CREATE ON SCHEMA "referrals" FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION "referrals"."reject_append_only_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
    RAISE EXCEPTION '% is append-only', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."reject_append_only_mutation"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION "referrals"."reject_delete_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
    RAISE EXCEPTION '% cannot be deleted or truncated', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."reject_delete_mutation"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

-- ----------------------------------------------------------------------------
-- Programme settings (singleton).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."program_settings" (
    "id" boolean NOT NULL DEFAULT true,
    "reward_amount" numeric(20,4) NOT NULL DEFAULT 40,
    "currency" text NOT NULL DEFAULT 'KES',
    "minimum_withdrawal" numeric(20,4) NOT NULL DEFAULT 500,
    "qualification_rule" text NOT NULL DEFAULT 'initial_personal_annual_full_settlement',
    "updated_by" uuid,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "program_settings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "program_settings_singleton_check" CHECK ("id" = true),
    CONSTRAINT "program_settings_reward_amount_check" CHECK ("reward_amount" = 40),
    CONSTRAINT "program_settings_minimum_withdrawal_check" CHECK ("minimum_withdrawal" = 500),
    CONSTRAINT "program_settings_currency_check" CHECK ("currency" = 'KES'),
    CONSTRAINT "program_settings_qualification_rule_check"
        CHECK ("qualification_rule" = 'initial_personal_annual_full_settlement'),
    CONSTRAINT "program_settings_updated_by_fkey"
        FOREIGN KEY ("updated_by") REFERENCES "users"."profiles"("id") ON DELETE SET NULL
);

INSERT INTO "referrals"."program_settings" (
    "id", "reward_amount", "currency", "minimum_withdrawal", "qualification_rule"
) VALUES (
    true, 40, 'KES', 500, 'initial_personal_annual_full_settlement'
)
ON CONFLICT ("id") DO NOTHING;

ALTER TABLE "referrals"."program_settings" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."program_settings"
    FROM PUBLIC, "anon", "authenticated";
REVOKE DELETE, TRUNCATE ON TABLE "referrals"."program_settings"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "program_settings_no_delete" ON "referrals"."program_settings";
CREATE TRIGGER "program_settings_no_delete"
    BEFORE DELETE ON "referrals"."program_settings"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "program_settings_no_truncate" ON "referrals"."program_settings";
CREATE TRIGGER "program_settings_no_truncate"
    BEFORE TRUNCATE ON "referrals"."program_settings"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

COMMENT ON TABLE "referrals"."program_settings"
    IS 'Singleton Refer & Earn programme settings. KSh 40 reward, KSh 500 minimum withdrawal.';

-- ----------------------------------------------------------------------------
-- Pre-signup attribution capture for links, codes, QR and assisted signup.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."attribution_sessions" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "referral_code" text NOT NULL,
    "method" text NOT NULL,
    "normalized_phone_hash" text,
    "staff_profile_id" uuid,
    "consent_reference" text,
    "expires_at" timestamp with time zone,
    "consumed_profile_id" uuid,
    "status" text NOT NULL DEFAULT 'pending',
    "metadata" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "attribution_sessions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "attribution_sessions_staff_profile_id_fkey"
        FOREIGN KEY ("staff_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "attribution_sessions_consumed_profile_id_fkey"
        FOREIGN KEY ("consumed_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "attribution_sessions_referral_code_check"
        CHECK (length(btrim("referral_code")) > 0),
    CONSTRAINT "attribution_sessions_method_check"
        CHECK ("method" = ANY (ARRAY['link'::text, 'code'::text, 'qr'::text, 'assisted'::text])),
    CONSTRAINT "attribution_sessions_status_check"
        CHECK ("status" = ANY (ARRAY['pending'::text, 'consumed'::text, 'expired'::text, 'cancelled'::text])),
    CONSTRAINT "attribution_sessions_metadata_check"
        CHECK (jsonb_typeof("metadata") = 'object')
);

CREATE INDEX IF NOT EXISTS "attribution_sessions_code_idx"
    ON "referrals"."attribution_sessions" ("referral_code", "created_at" DESC);

CREATE INDEX IF NOT EXISTS "attribution_sessions_phone_idx"
    ON "referrals"."attribution_sessions" ("normalized_phone_hash")
    WHERE "normalized_phone_hash" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "attribution_sessions_pending_idx"
    ON "referrals"."attribution_sessions" ("status", "created_at")
    WHERE "status" = 'pending';

ALTER TABLE "referrals"."attribution_sessions" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."attribution_sessions"
    FROM PUBLIC, "anon", "authenticated";

-- ----------------------------------------------------------------------------
-- Assisted-registration audit.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."assisted_registrations" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "attribution_session_id" uuid NOT NULL,
    "staff_profile_id" uuid NOT NULL,
    "target_phone_hash" text,
    "target_profile_id" uuid,
    "consent_reference" text,
    "consent_at" timestamp with time zone,
    "status" text NOT NULL DEFAULT 'started',
    "notes" text,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "completed_at" timestamp with time zone,
    CONSTRAINT "assisted_registrations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "assisted_registrations_attribution_session_id_key"
        UNIQUE ("attribution_session_id"),
    CONSTRAINT "assisted_registrations_attribution_session_id_fkey"
        FOREIGN KEY ("attribution_session_id")
        REFERENCES "referrals"."attribution_sessions"("id") ON DELETE RESTRICT,
    CONSTRAINT "assisted_registrations_staff_profile_id_fkey"
        FOREIGN KEY ("staff_profile_id") REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "assisted_registrations_target_profile_id_fkey"
        FOREIGN KEY ("target_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "assisted_registrations_status_check"
        CHECK ("status" = ANY (ARRAY['started'::text, 'completed'::text, 'cancelled'::text, 'rejected'::text]))
);

CREATE INDEX IF NOT EXISTS "assisted_registrations_staff_idx"
    ON "referrals"."assisted_registrations" ("staff_profile_id", "created_at" DESC);

ALTER TABLE "referrals"."assisted_registrations" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."assisted_registrations"
    FROM PUBLIC, "anon", "authenticated";
REVOKE DELETE, TRUNCATE ON TABLE "referrals"."assisted_registrations"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "assisted_registrations_no_delete" ON "referrals"."assisted_registrations";
CREATE TRIGGER "assisted_registrations_no_delete"
    BEFORE DELETE ON "referrals"."assisted_registrations"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "assisted_registrations_no_truncate" ON "referrals"."assisted_registrations";
CREATE TRIGGER "assisted_registrations_no_truncate"
    BEFORE TRUNCATE ON "referrals"."assisted_registrations"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

-- ----------------------------------------------------------------------------
-- Effective-dated Vunio employee exclusion registry.
-- Partner company / cooperative employees are not entered here and remain
-- eligible. No hard delete: use status/revocation and effective dates.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."employee_exclusions" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "profile_id" uuid,
    "normalized_phone_hash" text,
    "normalized_email_hash" text,
    "employer_entity_id" uuid NOT NULL,
    "employment_start_at" timestamp with time zone NOT NULL,
    "employment_end_at" timestamp with time zone,
    "reason" text NOT NULL,
    "effective_from" timestamp with time zone NOT NULL DEFAULT now(),
    "effective_to" timestamp with time zone,
    "status" text NOT NULL DEFAULT 'active',
    "created_by" uuid NOT NULL,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "revoked_by" uuid,
    "revoked_at" timestamp with time zone,
    CONSTRAINT "employee_exclusions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "employee_exclusions_profile_id_fkey"
        FOREIGN KEY ("profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "employee_exclusions_employer_entity_id_fkey"
        FOREIGN KEY ("employer_entity_id") REFERENCES "core"."entities"("id") ON DELETE RESTRICT,
    CONSTRAINT "employee_exclusions_created_by_fkey"
        FOREIGN KEY ("created_by") REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "employee_exclusions_revoked_by_fkey"
        FOREIGN KEY ("revoked_by") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "employee_exclusions_identifier_check"
        CHECK ("profile_id" IS NOT NULL OR "normalized_phone_hash" IS NOT NULL OR "normalized_email_hash" IS NOT NULL),
    CONSTRAINT "employee_exclusions_reason_check"
        CHECK (length(btrim("reason")) > 0),
    CONSTRAINT "employee_exclusions_employment_dates_check"
        CHECK ("employment_end_at" IS NULL OR "employment_end_at" >= "employment_start_at"),
    CONSTRAINT "employee_exclusions_effective_dates_check"
        CHECK ("effective_to" IS NULL OR "effective_to" >= "effective_from"),
    CONSTRAINT "employee_exclusions_status_check"
        CHECK ("status" = ANY (ARRAY['active'::text, 'revoked'::text]))
);

CREATE UNIQUE INDEX IF NOT EXISTS "employee_exclusions_profile_employer_start_key"
    ON "referrals"."employee_exclusions" ("profile_id", "employer_entity_id", "employment_start_at")
    WHERE "profile_id" IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "employee_exclusions_phone_employer_start_key"
    ON "referrals"."employee_exclusions" ("normalized_phone_hash", "employer_entity_id", "employment_start_at")
    WHERE "normalized_phone_hash" IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "employee_exclusions_email_employer_start_key"
    ON "referrals"."employee_exclusions" ("normalized_email_hash", "employer_entity_id", "employment_start_at")
    WHERE "normalized_email_hash" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "employee_exclusions_profile_idx"
    ON "referrals"."employee_exclusions" ("profile_id", "status", "employment_start_at");

CREATE INDEX IF NOT EXISTS "employee_exclusions_phone_idx"
    ON "referrals"."employee_exclusions" ("normalized_phone_hash", "status")
    WHERE "normalized_phone_hash" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "employee_exclusions_email_idx"
    ON "referrals"."employee_exclusions" ("normalized_email_hash", "status")
    WHERE "normalized_email_hash" IS NOT NULL;

ALTER TABLE "referrals"."employee_exclusions" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."employee_exclusions"
    FROM PUBLIC, "anon", "authenticated";
REVOKE DELETE, TRUNCATE ON TABLE "referrals"."employee_exclusions"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "employee_exclusions_no_delete" ON "referrals"."employee_exclusions";
CREATE TRIGGER "employee_exclusions_no_delete"
    BEFORE DELETE ON "referrals"."employee_exclusions"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "employee_exclusions_no_truncate" ON "referrals"."employee_exclusions";
CREATE TRIGGER "employee_exclusions_no_truncate"
    BEFORE TRUNCATE ON "referrals"."employee_exclusions"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

COMMENT ON TABLE "referrals"."employee_exclusions"
    IS 'Effective-dated Vunio employee exclusions only. Partner company/cooperative employees are not entered and remain eligible.';

-- ----------------------------------------------------------------------------
-- Referral attribution record.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."referrals" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "referrer_profile_id" uuid NOT NULL,
    "referred_profile_id" uuid NOT NULL,
    "referral_code" text NOT NULL,
    "attribution_method" text NOT NULL,
    "attribution_session_id" uuid,
    "assisted_by_profile_id" uuid,
    "status" text NOT NULL DEFAULT 'attributed',
    "qualifying_cycle_id" uuid,
    "qualifying_invoice_id" uuid,
    "qualifying_obligation_id" uuid,
    "qualifying_finance_event_id" uuid,
    "earned_at" timestamp with time zone,
    "qualified_at" timestamp with time zone,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "referrals_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "referrals_referrer_profile_id_fkey"
        FOREIGN KEY ("referrer_profile_id") REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "referrals_referred_profile_id_fkey"
        FOREIGN KEY ("referred_profile_id") REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "referrals_attribution_session_id_fkey"
        FOREIGN KEY ("attribution_session_id")
        REFERENCES "referrals"."attribution_sessions"("id") ON DELETE SET NULL,
    CONSTRAINT "referrals_assisted_by_profile_id_fkey"
        FOREIGN KEY ("assisted_by_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "referrals_qualifying_cycle_id_fkey"
        FOREIGN KEY ("qualifying_cycle_id")
        REFERENCES "finance"."subscription_cycles"("id") ON DELETE RESTRICT,
    CONSTRAINT "referrals_qualifying_invoice_id_fkey"
        FOREIGN KEY ("qualifying_invoice_id")
        REFERENCES "system"."invoices"("id") ON DELETE RESTRICT,
    CONSTRAINT "referrals_qualifying_obligation_id_fkey"
        FOREIGN KEY ("qualifying_obligation_id")
        REFERENCES "finance"."obligations"("id") ON DELETE RESTRICT,
    CONSTRAINT "referrals_qualifying_finance_event_id_fkey"
        FOREIGN KEY ("qualifying_finance_event_id")
        REFERENCES "finance"."events"("id") ON DELETE RESTRICT,
    CONSTRAINT "referrals_distinct_profiles_check"
        CHECK ("referrer_profile_id" <> "referred_profile_id"),
    CONSTRAINT "referrals_referral_code_check"
        CHECK (length(btrim("referral_code")) > 0),
    CONSTRAINT "referrals_attribution_method_check"
        CHECK ("attribution_method" = ANY (ARRAY['link'::text, 'code'::text, 'qr'::text, 'assisted'::text])),
    CONSTRAINT "referrals_status_check"
        CHECK ("status" = ANY (ARRAY[
            'attributed'::text,
            'review_required'::text,
            'qualified'::text,
            'ineligible'::text,
            'void'::text
        ]))
);

CREATE UNIQUE INDEX IF NOT EXISTS "referrals_referred_profile_id_key"
    ON "referrals"."referrals" ("referred_profile_id");

CREATE UNIQUE INDEX IF NOT EXISTS "referrals_qualifying_cycle_id_key"
    ON "referrals"."referrals" ("qualifying_cycle_id")
    WHERE "qualifying_cycle_id" IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "referrals_qualifying_obligation_id_key"
    ON "referrals"."referrals" ("qualifying_obligation_id")
    WHERE "qualifying_obligation_id" IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "referrals_qualifying_finance_event_id_key"
    ON "referrals"."referrals" ("qualifying_finance_event_id")
    WHERE "qualifying_finance_event_id" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "referrals_referrer_status_idx"
    ON "referrals"."referrals" ("referrer_profile_id", "status", "created_at" DESC);

ALTER TABLE "referrals"."referrals" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."referrals"
    FROM PUBLIC, "anon", "authenticated";

COMMENT ON TABLE "referrals"."referrals"
    IS 'One referral per referred profile. Exact same-profile self-referral is rejected by constraint; other duplicate signals require manual review.';

-- ----------------------------------------------------------------------------
-- One reward per referral (therefore one reward globally per referred person).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."rewards" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "referral_id" uuid NOT NULL,
    "beneficiary_profile_id" uuid NOT NULL,
    "amount" numeric(20,4) NOT NULL,
    "currency" text NOT NULL DEFAULT 'KES',
    "status" text NOT NULL DEFAULT 'pending',
    "earned_at" timestamp with time zone,
    "eligible_at" timestamp with time zone,
    "accrual_journal_id" uuid,
    "accrued_at" timestamp with time zone,
    "withdrawal_request_id" uuid,
    "paid_at" timestamp with time zone,
    "reversed_at" timestamp with time zone,
    "recovery_obligation_id" uuid,
    "source_finance_event_id" uuid,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "rewards_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "rewards_referral_id_key" UNIQUE ("referral_id"),
    CONSTRAINT "rewards_referral_id_fkey"
        FOREIGN KEY ("referral_id") REFERENCES "referrals"."referrals"("id") ON DELETE RESTRICT,
    CONSTRAINT "rewards_beneficiary_profile_id_fkey"
        FOREIGN KEY ("beneficiary_profile_id") REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "rewards_accrual_journal_id_fkey"
        FOREIGN KEY ("accrual_journal_id") REFERENCES "finance"."journals"("id") ON DELETE RESTRICT,
    CONSTRAINT "rewards_source_finance_event_id_fkey"
        FOREIGN KEY ("source_finance_event_id") REFERENCES "finance"."events"("id") ON DELETE RESTRICT,
    CONSTRAINT "rewards_recovery_obligation_id_fkey"
        FOREIGN KEY ("recovery_obligation_id") REFERENCES "finance"."obligations"("id") ON DELETE RESTRICT,
    CONSTRAINT "rewards_amount_check" CHECK ("amount" > 0),
    CONSTRAINT "rewards_currency_check" CHECK ("currency" = 'KES'),
    CONSTRAINT "rewards_status_check"
        CHECK ("status" = ANY (ARRAY[
            'pending'::text,
            'review_required'::text,
            'eligible'::text,
            'locked'::text,
            'paid'::text,
            'reversed'::text,
            'void'::text,
            'accrual_failed'::text
        ]))
);

CREATE UNIQUE INDEX IF NOT EXISTS "rewards_source_finance_event_id_key"
    ON "referrals"."rewards" ("source_finance_event_id")
    WHERE "source_finance_event_id" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "rewards_beneficiary_status_idx"
    ON "referrals"."rewards" ("beneficiary_profile_id", "status", "created_at" DESC);

CREATE INDEX IF NOT EXISTS "rewards_withdrawal_request_idx"
    ON "referrals"."rewards" ("withdrawal_request_id")
    WHERE "withdrawal_request_id" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "rewards_recovery_obligation_idx"
    ON "referrals"."rewards" ("recovery_obligation_id")
    WHERE "recovery_obligation_id" IS NOT NULL;

ALTER TABLE "referrals"."rewards" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."rewards"
    FROM PUBLIC, "anon", "authenticated";

COMMENT ON TABLE "referrals"."rewards"
    IS 'Exactly one reward per referral. KSh 40 default is driven by referrals.program_settings.';

-- ----------------------------------------------------------------------------
-- Duplicate/self-referral/employee/assisted review cases.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."review_cases" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "referral_id" uuid NOT NULL,
    "case_type" text NOT NULL,
    "status" text NOT NULL DEFAULT 'open',
    "notes" text,
    "assigned_to" uuid,
    "resolved_by" uuid,
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "review_cases_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "review_cases_referral_id_fkey"
        FOREIGN KEY ("referral_id") REFERENCES "referrals"."referrals"("id") ON DELETE RESTRICT,
    CONSTRAINT "review_cases_assigned_to_fkey"
        FOREIGN KEY ("assigned_to") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "review_cases_resolved_by_fkey"
        FOREIGN KEY ("resolved_by") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "review_cases_case_type_check"
        CHECK ("case_type" = ANY (ARRAY[
            'self_referral'::text,
            'duplicate_human'::text,
            'employee_exclusion'::text,
            'assisted_registration'::text,
            'other'::text
        ])),
    CONSTRAINT "review_cases_status_check"
        CHECK ("status" = ANY (ARRAY['open'::text, 'cleared'::text, 'rejected'::text]))
);

CREATE UNIQUE INDEX IF NOT EXISTS "review_cases_open_referral_type_key"
    ON "referrals"."review_cases" ("referral_id", "case_type")
    WHERE "status" = 'open';

CREATE INDEX IF NOT EXISTS "review_cases_status_idx"
    ON "referrals"."review_cases" ("status", "created_at");

ALTER TABLE "referrals"."review_cases" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."review_cases"
    FROM PUBLIC, "anon", "authenticated";

-- ----------------------------------------------------------------------------
-- Append-only event and audit trails.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "referrals"."reward_events" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "reward_id" uuid NOT NULL,
    "event_type" text NOT NULL,
    "actor_profile_id" uuid,
    "amount" numeric(20,4),
    "from_status" text,
    "to_status" text,
    "journal_id" uuid,
    "metadata" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "reward_events_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "reward_events_reward_id_fkey"
        FOREIGN KEY ("reward_id") REFERENCES "referrals"."rewards"("id") ON DELETE RESTRICT,
    CONSTRAINT "reward_events_actor_profile_id_fkey"
        FOREIGN KEY ("actor_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "reward_events_journal_id_fkey"
        FOREIGN KEY ("journal_id") REFERENCES "finance"."journals"("id") ON DELETE RESTRICT,
    CONSTRAINT "reward_events_event_type_check"
        CHECK (length(btrim("event_type")) > 0),
    CONSTRAINT "reward_events_metadata_check"
        CHECK (jsonb_typeof("metadata") = 'object')
);

CREATE INDEX IF NOT EXISTS "reward_events_reward_idx"
    ON "referrals"."reward_events" ("reward_id", "created_at");

ALTER TABLE "referrals"."reward_events" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."reward_events"
    FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE TABLE IF NOT EXISTS "referrals"."audit_events" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "entity_type" text NOT NULL,
    "entity_id" uuid NOT NULL,
    "event_type" text NOT NULL,
    "actor_profile_id" uuid,
    "reason" text,
    "before_state" jsonb,
    "after_state" jsonb,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "audit_events_actor_profile_id_fkey"
        FOREIGN KEY ("actor_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "audit_events_entity_type_check"
        CHECK (length(btrim("entity_type")) > 0),
    CONSTRAINT "audit_events_event_type_check"
        CHECK (length(btrim("event_type")) > 0)
);

CREATE INDEX IF NOT EXISTS "audit_events_entity_idx"
    ON "referrals"."audit_events" ("entity_type", "entity_id", "created_at" DESC);

ALTER TABLE "referrals"."audit_events" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."audit_events"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "reward_events_append_only" ON "referrals"."reward_events";
CREATE TRIGGER "reward_events_append_only"
    BEFORE UPDATE OR DELETE ON "referrals"."reward_events"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

DROP TRIGGER IF EXISTS "reward_events_no_truncate" ON "referrals"."reward_events";
CREATE TRIGGER "reward_events_no_truncate"
    BEFORE TRUNCATE ON "referrals"."reward_events"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

DROP TRIGGER IF EXISTS "audit_events_append_only" ON "referrals"."audit_events";
CREATE TRIGGER "audit_events_append_only"
    BEFORE UPDATE OR DELETE ON "referrals"."audit_events"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

DROP TRIGGER IF EXISTS "audit_events_no_truncate" ON "referrals"."audit_events";
CREATE TRIGGER "audit_events_no_truncate"
    BEFORE TRUNCATE ON "referrals"."audit_events"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

-- Core referral and reward rows are mutable for status changes but must never
-- be deleted or truncated. This preserves the permanent audit chain.
REVOKE DELETE, TRUNCATE ON TABLE "referrals"."referrals"
    FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE DELETE, TRUNCATE ON TABLE "referrals"."rewards"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "referrals_no_delete" ON "referrals"."referrals";
CREATE TRIGGER "referrals_no_delete"
    BEFORE DELETE ON "referrals"."referrals"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "referrals_no_truncate" ON "referrals"."referrals";
CREATE TRIGGER "referrals_no_truncate"
    BEFORE TRUNCATE ON "referrals"."referrals"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "rewards_no_delete" ON "referrals"."rewards";
CREATE TRIGGER "rewards_no_delete"
    BEFORE DELETE ON "referrals"."rewards"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "rewards_no_truncate" ON "referrals"."rewards";
CREATE TRIGGER "rewards_no_truncate"
    BEFORE TRUNCATE ON "referrals"."rewards"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

COMMIT;

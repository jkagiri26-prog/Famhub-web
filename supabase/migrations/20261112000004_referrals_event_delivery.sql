-- ============================================================================
-- 20261112000004_referrals_event_delivery
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Referral-side consumer inbox and dead-letter storage for the durable
--   Finance event outbox created in 20261112000002.
--
--   Each Finance event is consumed at most once by the referral consumer, but
--   each consumer has independent retry state. Finance settlement is never
--   rolled back because referral processing fails.
--
-- SCOPE
--   Schema only. The worker function and Edge Function are implemented in a
--   later migration after the referral eligibility handler exists.
--
-- ROLLBACK
--   DROP TABLE IF EXISTS referrals.event_failures;
--   DROP TABLE IF EXISTS referrals.event_consumptions;
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS "referrals"."event_consumptions" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "finance_event_id" uuid NOT NULL,
    "event_type" text NOT NULL,
    "status" text NOT NULL DEFAULT 'pending',
    "attempts" integer NOT NULL DEFAULT 0,
    "last_error" text,
    "processed_at" timestamp with time zone,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "event_consumptions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "event_consumptions_finance_event_id_key"
        UNIQUE ("finance_event_id"),
    CONSTRAINT "event_consumptions_finance_event_id_fkey"
        FOREIGN KEY ("finance_event_id")
        REFERENCES "finance"."events"("id") ON DELETE RESTRICT,
    CONSTRAINT "event_consumptions_status_check"
        CHECK ("status" = ANY (ARRAY['pending'::text, 'processing'::text, 'processed'::text, 'failed'::text])),
    CONSTRAINT "event_consumptions_attempts_check"
        CHECK ("attempts" >= 0)
);

CREATE INDEX IF NOT EXISTS "event_consumptions_pending_idx"
    ON "referrals"."event_consumptions" ("status", "created_at");

CREATE INDEX IF NOT EXISTS "event_consumptions_event_type_idx"
    ON "referrals"."event_consumptions" ("event_type", "created_at" DESC);

ALTER TABLE "referrals"."event_consumptions" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."event_consumptions"
    FROM PUBLIC, "anon", "authenticated";

COMMENT ON TABLE "referrals"."event_consumptions"
    IS 'Referral consumer inbox. Unique finance_event_id makes processing idempotent and independent from the billing consumer.';

CREATE TABLE IF NOT EXISTS "referrals"."event_failures" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "finance_event_id" uuid NOT NULL,
    "event_type" text NOT NULL,
    "attempts" integer NOT NULL DEFAULT 0,
    "last_error" text NOT NULL,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "event_failures_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "event_failures_finance_event_id_key"
        UNIQUE ("finance_event_id"),
    CONSTRAINT "event_failures_finance_event_id_fkey"
        FOREIGN KEY ("finance_event_id")
        REFERENCES "finance"."events"("id") ON DELETE RESTRICT,
    CONSTRAINT "event_failures_attempts_check"
        CHECK ("attempts" > 0),
    CONSTRAINT "event_failures_last_error_check"
        CHECK (length(btrim("last_error")) > 0)
);

CREATE INDEX IF NOT EXISTS "event_failures_created_idx"
    ON "referrals"."event_failures" ("created_at");

ALTER TABLE "referrals"."event_failures" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."event_failures"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "event_failures_append_only" ON "referrals"."event_failures";
CREATE TRIGGER "event_failures_append_only"
    BEFORE UPDATE OR DELETE ON "referrals"."event_failures"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

DROP TRIGGER IF EXISTS "event_failures_no_truncate" ON "referrals"."event_failures";
CREATE TRIGGER "event_failures_no_truncate"
    BEFORE TRUNCATE ON "referrals"."event_failures"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

COMMIT;

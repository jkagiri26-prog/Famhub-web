-- ============================================================================
-- 20261112000002_finance_events_outbox
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Durable Finance outbox and the billing-side consumer inbox for durable,
--   retryable, idempotent subscription event processing.
--
--   Finance settlement commits financial truth and inserts an event row in the
--   SAME transaction. Subscription activation and referral processing are
--   independent consumers and must not run inside the Finance transaction.
--
-- SCOPE
--   Schema only. No settlement, activation, invoice update or referral reward
--   is performed here.
--
-- ROLLBACK
--   DROP TABLE IF EXISTS system.subscription_event_failures;
--   DROP TABLE IF EXISTS system.subscription_event_consumptions;
--   DROP TABLE IF EXISTS finance.events;
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS "finance"."events" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "event_sequence" bigserial,
    "event_type" text NOT NULL,
    "source_type" text NOT NULL,
    "source_id" uuid NOT NULL,
    "idempotency_key" text NOT NULL,
    "payload" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "finance_events_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "finance_events_event_sequence_key" UNIQUE ("event_sequence"),
    CONSTRAINT "finance_events_idempotency_key_key" UNIQUE ("idempotency_key"),
    CONSTRAINT "finance_events_source_event_key"
        UNIQUE ("event_type", "source_type", "source_id"),
    CONSTRAINT "finance_events_idempotency_key_check"
        CHECK (length(btrim("idempotency_key")) > 0),
    CONSTRAINT "finance_events_event_type_check"
        CHECK (length(btrim("event_type")) > 0),
    CONSTRAINT "finance_events_source_type_check"
        CHECK (length(btrim("source_type")) > 0),
    CONSTRAINT "finance_events_payload_check"
        CHECK (jsonb_typeof("payload") = 'object')
);

CREATE INDEX IF NOT EXISTS "finance_events_event_type_idx"
    ON "finance"."events" ("event_type", "created_at" DESC);

CREATE INDEX IF NOT EXISTS "finance_events_source_idx"
    ON "finance"."events" ("source_type", "source_id");

CREATE OR REPLACE FUNCTION "finance"."reject_event_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
    RAISE EXCEPTION '% is append-only', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION "finance"."reject_event_mutation"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

ALTER TABLE "finance"."events" ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE "finance"."events"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "finance_events_append_only" ON "finance"."events";
CREATE TRIGGER "finance_events_append_only"
    BEFORE UPDATE OR DELETE ON "finance"."events"
    FOR EACH ROW EXECUTE FUNCTION "finance"."reject_event_mutation"();

DROP TRIGGER IF EXISTS "finance_events_no_truncate" ON "finance"."events";
CREATE TRIGGER "finance_events_no_truncate"
    BEFORE TRUNCATE ON "finance"."events"
    FOR EACH STATEMENT EXECUTE FUNCTION "finance"."reject_event_mutation"();

COMMENT ON TABLE "finance"."events"
    IS 'Immutable durable Finance outbox. Settlement commits financial truth plus this event atomically; independent consumers track their own progress.';

COMMENT ON COLUMN "finance"."events"."event_sequence"
    IS 'Monotonic ordering for consumers. Outbox rows are never updated.';

-- ----------------------------------------------------------------------------
-- Billing-side consumer inbox. One row per Finance event, independently
-- retryable from the referral consumer.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "system"."subscription_event_consumptions" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "finance_event_id" uuid NOT NULL,
    "event_type" text NOT NULL,
    "status" text NOT NULL DEFAULT 'pending',
    "attempts" integer NOT NULL DEFAULT 0,
    "last_error" text,
    "processed_at" timestamp with time zone,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "subscription_event_consumptions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "subscription_event_consumptions_finance_event_id_key"
        UNIQUE ("finance_event_id"),
    CONSTRAINT "subscription_event_consumptions_finance_event_id_fkey"
        FOREIGN KEY ("finance_event_id")
        REFERENCES "finance"."events"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_event_consumptions_status_check"
        CHECK ("status" = ANY (ARRAY['pending'::text, 'processing'::text, 'processed'::text, 'failed'::text])),
    CONSTRAINT "subscription_event_consumptions_attempts_check"
        CHECK ("attempts" >= 0)
);

CREATE INDEX IF NOT EXISTS "subscription_event_consumptions_pending_idx"
    ON "system"."subscription_event_consumptions" ("status", "created_at");

ALTER TABLE "system"."subscription_event_consumptions" ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE "system"."subscription_event_consumptions"
    FROM PUBLIC, "anon", "authenticated";

CREATE TABLE IF NOT EXISTS "system"."subscription_event_failures" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "finance_event_id" uuid NOT NULL,
    "event_type" text NOT NULL,
    "attempts" integer NOT NULL DEFAULT 0,
    "last_error" text NOT NULL,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "subscription_event_failures_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "subscription_event_failures_finance_event_id_key"
        UNIQUE ("finance_event_id"),
    CONSTRAINT "subscription_event_failures_finance_event_id_fkey"
        FOREIGN KEY ("finance_event_id")
        REFERENCES "finance"."events"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_event_failures_attempts_check"
        CHECK ("attempts" > 0)
);

CREATE INDEX IF NOT EXISTS "subscription_event_failures_created_idx"
    ON "system"."subscription_event_failures" ("created_at");

ALTER TABLE "system"."subscription_event_failures" ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE "system"."subscription_event_failures"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "subscription_event_failures_append_only"
    ON "system"."subscription_event_failures";
CREATE TRIGGER "subscription_event_failures_append_only"
    BEFORE UPDATE OR DELETE ON "system"."subscription_event_failures"
    FOR EACH ROW EXECUTE FUNCTION "finance"."reject_event_mutation"();

DROP TRIGGER IF EXISTS "subscription_event_failures_no_truncate"
    ON "system"."subscription_event_failures";
CREATE TRIGGER "subscription_event_failures_no_truncate"
    BEFORE TRUNCATE ON "system"."subscription_event_failures"
    FOR EACH STATEMENT EXECUTE FUNCTION "finance"."reject_event_mutation"();

COMMIT;

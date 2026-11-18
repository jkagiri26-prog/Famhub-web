-- ============================================================================
-- 20261112000001_finance_subscription_cycles
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Add permanent annual subscription-cycle history, separate from
--   system.active_subscriptions (which remains the current access/entitlement
--   projection).
--
--   Each row records one purchased annual period and is linked to:
--     * system.invoices
--     * finance.obligations
--     * the current system.active_subscriptions row (nullable link)
--
-- SCOPE
--   Schema only. No invoice, obligation, payment, journal or subscription row
--   is created here.
--
-- ROLLBACK
--   DROP TABLE IF EXISTS finance.subscription_cycles;
--   (No other object is modified by this migration.)
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS "finance"."subscription_cycles" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "billing_account_id" uuid NOT NULL,
    "subscriber_profile_id" uuid NOT NULL,
    "entity_id" uuid NOT NULL,
    "plan_id" uuid NOT NULL,
    "active_subscription_id" uuid,
    "annual_sequence" integer NOT NULL,
    "cycle_type" text NOT NULL,
    "previous_cycle_id" uuid,
    "period_start" date NOT NULL,
    "period_end" date NOT NULL,
    "invoice_id" uuid NOT NULL,
    "obligation_id" uuid NOT NULL,
    "amount" numeric(20,4) NOT NULL,
    "currency" text NOT NULL DEFAULT 'KES',
    "status" text NOT NULL DEFAULT 'pending',
    "settled_at" timestamp with time zone,
    "activated_at" timestamp with time zone,
    "ended_at" timestamp with time zone,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "subscription_cycles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "subscription_cycles_billing_account_id_fkey"
        FOREIGN KEY ("billing_account_id")
        REFERENCES "system"."billing_accounts"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_cycles_subscriber_profile_id_fkey"
        FOREIGN KEY ("subscriber_profile_id")
        REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_cycles_entity_id_fkey"
        FOREIGN KEY ("entity_id")
        REFERENCES "core"."entities"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_cycles_plan_id_fkey"
        FOREIGN KEY ("plan_id")
        REFERENCES "system"."subscription_plans"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_cycles_active_subscription_id_fkey"
        FOREIGN KEY ("active_subscription_id")
        REFERENCES "system"."active_subscriptions"("id") ON DELETE SET NULL,
    CONSTRAINT "subscription_cycles_previous_cycle_id_fkey"
        FOREIGN KEY ("previous_cycle_id")
        REFERENCES "finance"."subscription_cycles"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_cycles_invoice_id_fkey"
        FOREIGN KEY ("invoice_id")
        REFERENCES "system"."invoices"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_cycles_obligation_id_fkey"
        FOREIGN KEY ("obligation_id")
        REFERENCES "finance"."obligations"("id") ON DELETE RESTRICT,
    CONSTRAINT "subscription_cycles_annual_sequence_check"
        CHECK ("annual_sequence" > 0),
    CONSTRAINT "subscription_cycles_cycle_type_check"
        CHECK ("cycle_type" = ANY (ARRAY['initial_annual'::text, 'renewal_annual'::text])),
    CONSTRAINT "subscription_cycles_initial_sequence_check"
        CHECK (
            ("cycle_type" = 'initial_annual' AND "annual_sequence" = 1)
            OR ("cycle_type" = 'renewal_annual' AND "annual_sequence" > 1)
        ),
    CONSTRAINT "subscription_cycles_renewal_lineage_check"
        CHECK (
            ("cycle_type" = 'initial_annual' AND "previous_cycle_id" IS NULL)
            OR ("cycle_type" = 'renewal_annual' AND "previous_cycle_id" IS NOT NULL)
        ),
    CONSTRAINT "subscription_cycles_previous_cycle_not_self_check"
        CHECK ("previous_cycle_id" IS NULL OR "previous_cycle_id" <> "id"),
    CONSTRAINT "subscription_cycles_period_check"
        CHECK ("period_end" >= "period_start"),
    CONSTRAINT "subscription_cycles_status_check"
        CHECK ("status" = ANY (ARRAY[
            'pending'::text,
            'paid'::text,
            'active'::text,
            'expired'::text,
            'cancelled'::text,
            'refunded'::text,
            'reversed'::text
        ])),
    CONSTRAINT "subscription_cycles_amount_check"
        CHECK ("amount" > 0),
    CONSTRAINT "subscription_cycles_currency_check"
        CHECK ("currency" ~ '^[A-Z]{3}$')
);

CREATE UNIQUE INDEX IF NOT EXISTS "subscription_cycles_invoice_id_key"
    ON "finance"."subscription_cycles" ("invoice_id");

CREATE UNIQUE INDEX IF NOT EXISTS "subscription_cycles_obligation_id_key"
    ON "finance"."subscription_cycles" ("obligation_id");

CREATE UNIQUE INDEX IF NOT EXISTS "subscription_cycles_subscriber_sequence_key"
    ON "finance"."subscription_cycles" ("subscriber_profile_id", "annual_sequence");

CREATE UNIQUE INDEX IF NOT EXISTS "subscription_cycles_billing_plan_period_key"
    ON "finance"."subscription_cycles" ("billing_account_id", "plan_id", "period_start");

CREATE INDEX IF NOT EXISTS "subscription_cycles_subscriber_status_idx"
    ON "finance"."subscription_cycles" ("subscriber_profile_id", "status");

CREATE INDEX IF NOT EXISTS "subscription_cycles_billing_account_idx"
    ON "finance"."subscription_cycles" ("billing_account_id", "period_start" DESC);

CREATE INDEX IF NOT EXISTS "subscription_cycles_active_subscription_idx"
    ON "finance"."subscription_cycles" ("active_subscription_id")
    WHERE "active_subscription_id" IS NOT NULL;

ALTER TABLE "finance"."subscription_cycles" ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE "finance"."subscription_cycles"
    FROM PUBLIC, "anon", "authenticated";
REVOKE DELETE, TRUNCATE ON TABLE "finance"."subscription_cycles"
    FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION "finance"."reject_subscription_cycle_delete"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
    RAISE EXCEPTION '% cannot be deleted or truncated', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION "finance"."reject_subscription_cycle_delete"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "subscription_cycles_no_delete" ON "finance"."subscription_cycles";
CREATE TRIGGER "subscription_cycles_no_delete"
    BEFORE DELETE ON "finance"."subscription_cycles"
    FOR EACH ROW EXECUTE FUNCTION "finance"."reject_subscription_cycle_delete"();

DROP TRIGGER IF EXISTS "subscription_cycles_no_truncate" ON "finance"."subscription_cycles";
CREATE TRIGGER "subscription_cycles_no_truncate"
    BEFORE TRUNCATE ON "finance"."subscription_cycles"
    FOR EACH STATEMENT EXECUTE FUNCTION "finance"."reject_subscription_cycle_delete"();

COMMENT ON TABLE "finance"."subscription_cycles"
    IS 'Permanent annual subscription-cycle history linked to invoice and Finance obligation; system.active_subscriptions remains current access.';

COMMENT ON COLUMN "finance"."subscription_cycles"."annual_sequence"
    IS 'Annual cycle number per subscriber profile. 1 is the initial annual cycle.';

COMMENT ON COLUMN "finance"."subscription_cycles"."active_subscription_id"
    IS 'Optional link to the current system.active_subscriptions access row. History is never stored only there.';

COMMIT;

-- ============================================================================
-- 20261112000007_subscription_cycle_idempotency
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Add a caller idempotency key to permanent annual subscription-cycle
--   purchases so invoice/obligation/cycle creation can be retried safely.
--
-- SCOPE
--   Additive only. No existing cycle is modified. No invoice, plan or
--   obligation is created. No accounting period is opened.
--
-- ROLLBACK
--   DROP INDEX IF EXISTS finance.subscription_cycles_idempotency_key_key;
--   ALTER TABLE finance.subscription_cycles DROP CONSTRAINT IF EXISTS subscription_cycles_idempotency_key_check;
--   ALTER TABLE finance.subscription_cycles DROP COLUMN IF EXISTS idempotency_key;
-- ============================================================================

BEGIN;

ALTER TABLE "finance"."subscription_cycles"
    ADD COLUMN IF NOT EXISTS "idempotency_key" text;

CREATE UNIQUE INDEX IF NOT EXISTS "subscription_cycles_idempotency_key_key"
    ON "finance"."subscription_cycles" ("idempotency_key")
    WHERE "idempotency_key" IS NOT NULL;

DO $function$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'finance.subscription_cycles'::regclass
           AND conname = 'subscription_cycles_idempotency_key_check'
    ) THEN
        ALTER TABLE "finance"."subscription_cycles"
            ADD CONSTRAINT "subscription_cycles_idempotency_key_check"
            CHECK ("idempotency_key" IS NULL OR length(btrim("idempotency_key")) > 0);
    END IF;
END;
$function$;

COMMENT ON COLUMN "finance"."subscription_cycles"."idempotency_key"
    IS 'Caller-supplied idempotency key for the annual subscription purchase operation.';

COMMIT;

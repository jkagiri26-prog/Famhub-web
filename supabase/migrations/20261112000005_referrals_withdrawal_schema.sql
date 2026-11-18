-- ============================================================================
-- 20261112000005_referrals_withdrawal_schema
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Withdrawal request, reward reservation and append-only payout audit
--   structures.
--
-- APPROVED RULES ENCODED HERE
--   * KSh 500 minimum withdrawal.
--   * Entire eligible balance is reserved by the withdrawal function.
--   * One Finance payout obligation per withdrawal request (unique link).
--   * Reward reservations are historical and releasable after failure.
--
-- SCOPE
--   Schema only. Withdrawal calculation, approval, payout recording and
--   reconciliation functions are implemented later after live Finance payout
--   behaviour and account IDs are verified.
--
-- ROLLBACK
--   ALTER TABLE referrals.rewards DROP CONSTRAINT IF EXISTS rewards_withdrawal_request_id_fkey;
--   DROP TABLE IF EXISTS referrals.withdrawal_events;
--   DROP TABLE IF EXISTS referrals.withdrawal_items;
--   DROP TABLE IF EXISTS referrals.withdrawal_requests;
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS "referrals"."withdrawal_requests" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "beneficiary_profile_id" uuid NOT NULL,
    "amount" numeric(20,4) NOT NULL,
    "currency" text NOT NULL DEFAULT 'KES',
    "status" text NOT NULL DEFAULT 'requested',
    "finance_obligation_id" uuid,
    "recipient_entity_id" uuid,
    "recipient_verified_at" timestamp with time zone,
    "recipient_verification" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "idempotency_key" text NOT NULL,
    "version" integer NOT NULL DEFAULT 1,
    "requested_at" timestamp with time zone NOT NULL DEFAULT now(),
    "reviewed_by" uuid,
    "reviewed_at" timestamp with time zone,
    "approved_at" timestamp with time zone,
    "paid_at" timestamp with time zone,
    "mpesa_receipt" text,
    "payout_evidence" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "decision_notes" text,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "withdrawal_requests_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "withdrawal_requests_beneficiary_profile_id_fkey"
        FOREIGN KEY ("beneficiary_profile_id") REFERENCES "users"."profiles"("id") ON DELETE RESTRICT,
    CONSTRAINT "withdrawal_requests_reviewed_by_fkey"
        FOREIGN KEY ("reviewed_by") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "withdrawal_requests_finance_obligation_id_fkey"
        FOREIGN KEY ("finance_obligation_id") REFERENCES "finance"."obligations"("id") ON DELETE RESTRICT,
    CONSTRAINT "withdrawal_requests_recipient_entity_id_fkey"
        FOREIGN KEY ("recipient_entity_id") REFERENCES "core"."entities"("id") ON DELETE RESTRICT,
    CONSTRAINT "withdrawal_requests_idempotency_key_key" UNIQUE ("idempotency_key"),
    CONSTRAINT "withdrawal_requests_idempotency_key_check"
        CHECK (length(btrim("idempotency_key")) > 0),
    CONSTRAINT "withdrawal_requests_amount_check" CHECK ("amount" >= 500),
    CONSTRAINT "withdrawal_requests_currency_check" CHECK ("currency" = 'KES'),
    CONSTRAINT "withdrawal_requests_version_check" CHECK ("version" > 0),
    CONSTRAINT "withdrawal_requests_status_check"
        CHECK ("status" = ANY (ARRAY[
            'requested'::text,
            'approved'::text,
            'uncertain'::text,
            'paid'::text,
            'failed'::text,
            'rejected'::text,
            'cancelled'::text,
            'reversed'::text
        ])),
    CONSTRAINT "withdrawal_requests_requested_obligation_check"
        CHECK ("status" <> 'requested' OR "finance_obligation_id" IS NULL),
    CONSTRAINT "withdrawal_requests_approved_obligation_check"
        CHECK ("status" <> 'approved' OR "finance_obligation_id" IS NOT NULL),
    CONSTRAINT "withdrawal_requests_obligation_state_check"
        CHECK ("status" IN ('requested', 'rejected', 'cancelled') OR "finance_obligation_id" IS NOT NULL),
    CONSTRAINT "withdrawal_requests_recipient_state_check"
        CHECK ("status" IN ('requested', 'rejected', 'cancelled') OR "recipient_entity_id" IS NOT NULL),
    CONSTRAINT "withdrawal_requests_recipient_verification_state_check"
        CHECK ("status" IN ('requested', 'rejected', 'cancelled') OR "recipient_verified_at" IS NOT NULL),
    CONSTRAINT "withdrawal_requests_mpesa_receipt_check"
        CHECK ("mpesa_receipt" IS NULL OR length(btrim("mpesa_receipt")) > 0),
    CONSTRAINT "withdrawal_requests_payout_evidence_check"
        CHECK (jsonb_typeof("payout_evidence") = 'object'),
    CONSTRAINT "withdrawal_requests_recipient_verification_check"
        CHECK (jsonb_typeof("recipient_verification") = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS "withdrawal_requests_finance_obligation_id_key"
    ON "referrals"."withdrawal_requests" ("finance_obligation_id")
    WHERE "finance_obligation_id" IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "withdrawal_requests_mpesa_receipt_key"
    ON "referrals"."withdrawal_requests" ("mpesa_receipt")
    WHERE "mpesa_receipt" IS NOT NULL AND btrim("mpesa_receipt") <> '';

CREATE INDEX IF NOT EXISTS "withdrawal_requests_beneficiary_status_idx"
    ON "referrals"."withdrawal_requests" ("beneficiary_profile_id", "status", "requested_at" DESC);

CREATE INDEX IF NOT EXISTS "withdrawal_requests_admin_queue_idx"
    ON "referrals"."withdrawal_requests" ("status", "requested_at")
    WHERE "status" = 'requested';

-- At most one active withdrawal per beneficiary. This prevents two concurrent
-- requests from splitting the entire eligible balance across reservations.
CREATE UNIQUE INDEX IF NOT EXISTS "withdrawal_requests_one_open_per_beneficiary_key"
    ON "referrals"."withdrawal_requests" ("beneficiary_profile_id")
    WHERE "status" IN ('requested', 'approved', 'uncertain');

ALTER TABLE "referrals"."withdrawal_requests" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."withdrawal_requests"
    FROM PUBLIC, "anon", "authenticated";

COMMENT ON TABLE "referrals"."withdrawal_requests"
    IS 'Withdrawal request. KSh 500 minimum, one Finance payout obligation per request.';

REVOKE DELETE, TRUNCATE ON TABLE "referrals"."withdrawal_requests"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "withdrawal_requests_no_delete" ON "referrals"."withdrawal_requests";
CREATE TRIGGER "withdrawal_requests_no_delete"
    BEFORE DELETE ON "referrals"."withdrawal_requests"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "withdrawal_requests_no_truncate" ON "referrals"."withdrawal_requests";
CREATE TRIGGER "withdrawal_requests_no_truncate"
    BEFORE TRUNCATE ON "referrals"."withdrawal_requests"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

CREATE TABLE IF NOT EXISTS "referrals"."withdrawal_items" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "withdrawal_request_id" uuid NOT NULL,
    "reward_id" uuid NOT NULL,
    "amount" numeric(20,4) NOT NULL,
    "status" text NOT NULL DEFAULT 'reserved',
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "released_at" timestamp with time zone,
    CONSTRAINT "withdrawal_items_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "withdrawal_items_withdrawal_request_id_fkey"
        FOREIGN KEY ("withdrawal_request_id")
        REFERENCES "referrals"."withdrawal_requests"("id") ON DELETE RESTRICT,
    CONSTRAINT "withdrawal_items_reward_id_fkey"
        FOREIGN KEY ("reward_id") REFERENCES "referrals"."rewards"("id") ON DELETE RESTRICT,
    CONSTRAINT "withdrawal_items_request_reward_key"
        UNIQUE ("withdrawal_request_id", "reward_id"),
    CONSTRAINT "withdrawal_items_amount_check" CHECK ("amount" > 0),
    CONSTRAINT "withdrawal_items_status_check"
        CHECK ("status" = ANY (ARRAY['reserved'::text, 'released'::text, 'paid'::text, 'reversed'::text]))
);

CREATE UNIQUE INDEX IF NOT EXISTS "withdrawal_items_active_reward_key"
    ON "referrals"."withdrawal_items" ("reward_id")
    WHERE "status" = 'reserved';

CREATE INDEX IF NOT EXISTS "withdrawal_items_request_idx"
    ON "referrals"."withdrawal_items" ("withdrawal_request_id");

ALTER TABLE "referrals"."withdrawal_items" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."withdrawal_items"
    FROM PUBLIC, "anon", "authenticated";

COMMENT ON TABLE "referrals"."withdrawal_items"
    IS 'Transactional reward reservations. A released reservation can be re-reserved by a later request; historical rows remain.';

REVOKE DELETE, TRUNCATE ON TABLE "referrals"."withdrawal_items"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "withdrawal_items_no_delete" ON "referrals"."withdrawal_items";
CREATE TRIGGER "withdrawal_items_no_delete"
    BEFORE DELETE ON "referrals"."withdrawal_items"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

DROP TRIGGER IF EXISTS "withdrawal_items_no_truncate" ON "referrals"."withdrawal_items";
CREATE TRIGGER "withdrawal_items_no_truncate"
    BEFORE TRUNCATE ON "referrals"."withdrawal_items"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_delete_mutation"();

CREATE TABLE IF NOT EXISTS "referrals"."withdrawal_events" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "withdrawal_request_id" uuid NOT NULL,
    "event_type" text NOT NULL,
    "actor_profile_id" uuid,
    "from_status" text,
    "to_status" text,
    "amount" numeric(20,4),
    "mpesa_receipt" text,
    "evidence" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "notes" text,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "withdrawal_events_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "withdrawal_events_withdrawal_request_id_fkey"
        FOREIGN KEY ("withdrawal_request_id")
        REFERENCES "referrals"."withdrawal_requests"("id") ON DELETE RESTRICT,
    CONSTRAINT "withdrawal_events_actor_profile_id_fkey"
        FOREIGN KEY ("actor_profile_id") REFERENCES "users"."profiles"("id") ON DELETE SET NULL,
    CONSTRAINT "withdrawal_events_event_type_check"
        CHECK (length(btrim("event_type")) > 0),
    CONSTRAINT "withdrawal_events_evidence_check"
        CHECK (jsonb_typeof("evidence") = 'object')
);

CREATE INDEX IF NOT EXISTS "withdrawal_events_request_idx"
    ON "referrals"."withdrawal_events" ("withdrawal_request_id", "created_at");

ALTER TABLE "referrals"."withdrawal_events" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "referrals"."withdrawal_events"
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "withdrawal_events_append_only" ON "referrals"."withdrawal_events";
CREATE TRIGGER "withdrawal_events_append_only"
    BEFORE UPDATE OR DELETE ON "referrals"."withdrawal_events"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

DROP TRIGGER IF EXISTS "withdrawal_events_no_truncate" ON "referrals"."withdrawal_events";
CREATE TRIGGER "withdrawal_events_no_truncate"
    BEFORE TRUNCATE ON "referrals"."withdrawal_events"
    FOR EACH STATEMENT EXECUTE FUNCTION "referrals"."reject_append_only_mutation"();

-- ----------------------------------------------------------------------------
-- State guards.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "referrals"."guard_withdrawal_request_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.beneficiary_profile_id IS DISTINCT FROM OLD.beneficiary_profile_id
       OR NEW.amount IS DISTINCT FROM OLD.amount
       OR NEW.currency IS DISTINCT FROM OLD.currency
       OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
       OR NEW.requested_at IS DISTINCT FROM OLD.requested_at
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Withdrawal request identity and amount are immutable'
            USING ERRCODE = '23514';
    END IF;

    IF OLD.finance_obligation_id IS NOT NULL
       AND NEW.finance_obligation_id IS DISTINCT FROM OLD.finance_obligation_id THEN
        RAISE EXCEPTION 'Finance payout obligation link is immutable once set'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.status = 'requested' AND NEW.finance_obligation_id IS NOT NULL THEN
        RAISE EXCEPTION 'A requested withdrawal cannot have a Finance payout obligation'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.status = 'approved' AND NEW.finance_obligation_id IS NULL THEN
        RAISE EXCEPTION 'An approved withdrawal requires a Finance payout obligation'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.version IS DISTINCT FROM OLD.version + 1 THEN
        RAISE EXCEPTION 'Withdrawal request version must increment by exactly one'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
        (OLD.status = 'requested' AND NEW.status IN ('approved', 'rejected', 'cancelled'))
        OR (OLD.status = 'approved' AND NEW.status IN ('uncertain', 'paid', 'failed', 'cancelled'))
        OR (OLD.status = 'uncertain' AND NEW.status IN ('paid', 'failed', 'cancelled'))
        OR (OLD.status = 'paid' AND NEW.status = 'reversed')
    ) THEN
        RAISE EXCEPTION 'Invalid withdrawal request status transition: % -> %',
            OLD.status, NEW.status USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."guard_withdrawal_request_mutation"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "withdrawal_requests_status_guard" ON "referrals"."withdrawal_requests";
CREATE TRIGGER "withdrawal_requests_status_guard"
    BEFORE UPDATE ON "referrals"."withdrawal_requests"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."guard_withdrawal_request_mutation"();

CREATE OR REPLACE FUNCTION "referrals"."release_items_on_request_close"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals
AS $function$
BEGIN
    UPDATE "referrals"."withdrawal_items"
       SET "status" = 'released',
           "released_at" = COALESCE("released_at", now())
     WHERE "withdrawal_request_id" = NEW."id"
       AND "status" = 'reserved';
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."release_items_on_request_close"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "withdrawal_requests_release_items" ON "referrals"."withdrawal_requests";
CREATE TRIGGER "withdrawal_requests_release_items"
    AFTER UPDATE OF "status" ON "referrals"."withdrawal_requests"
    FOR EACH ROW
    WHEN (NEW."status" IN ('failed', 'rejected', 'cancelled'))
    EXECUTE FUNCTION "referrals"."release_items_on_request_close"();

CREATE OR REPLACE FUNCTION "referrals"."guard_withdrawal_item_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals
AS $function$
DECLARE
    v_request referrals.withdrawal_requests%ROWTYPE;
    v_reward referrals.rewards%ROWTYPE;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT * INTO v_request
          FROM "referrals"."withdrawal_requests"
         WHERE id = NEW.withdrawal_request_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Withdrawal request does not exist'
                USING ERRCODE = '23503';
        END IF;
        IF v_request.status <> 'requested' THEN
            RAISE EXCEPTION 'Withdrawal items can only be reserved while the request is requested'
                USING ERRCODE = '55000';
        END IF;

        SELECT * INTO v_reward
          FROM "referrals"."rewards"
         WHERE id = NEW.reward_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Reward does not exist'
                USING ERRCODE = '23503';
        END IF;
        IF v_reward.status <> 'eligible' THEN
            RAISE EXCEPTION 'Reward is not eligible for reservation (status=%)', v_reward.status
                USING ERRCODE = '55000';
        END IF;
        IF v_reward.withdrawal_request_id IS NOT NULL THEN
            RAISE EXCEPTION 'Reward is already linked to a withdrawal request'
                USING ERRCODE = '23505';
        END IF;
        IF v_reward.beneficiary_profile_id <> v_request.beneficiary_profile_id THEN
            RAISE EXCEPTION 'Reward beneficiary does not match the withdrawal beneficiary'
                USING ERRCODE = '23514';
        END IF;
        IF v_reward.currency <> v_request.currency THEN
            RAISE EXCEPTION 'Reward currency does not match the withdrawal currency'
                USING ERRCODE = '23514';
        END IF;
        IF NEW.amount IS DISTINCT FROM v_reward.amount OR NEW.amount <= 0 THEN
            RAISE EXCEPTION 'Withdrawal item amount must equal the reward amount'
                USING ERRCODE = '23514';
        END IF;
        IF NEW.status <> 'reserved' THEN
            RAISE EXCEPTION 'New withdrawal item must start reserved'
                USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.withdrawal_request_id IS DISTINCT FROM OLD.withdrawal_request_id
       OR NEW.reward_id IS DISTINCT FROM OLD.reward_id
       OR NEW.amount IS DISTINCT FROM OLD.amount THEN
        RAISE EXCEPTION 'Withdrawal item identity and amount are immutable'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
        (OLD.status = 'reserved' AND NEW.status IN ('released', 'paid', 'reversed'))
        OR (OLD.status = 'paid' AND NEW.status = 'reversed')
    ) THEN
        RAISE EXCEPTION 'Invalid withdrawal item status transition: % -> %',
            OLD.status, NEW.status USING ERRCODE = '23514';
    END IF;

    IF NEW.status = 'released' AND NEW.released_at IS NULL THEN
        NEW.released_at := clock_timestamp();
    END IF;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."guard_withdrawal_item_mutation"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

-- The future withdrawal RPC must insert withdrawal_items before setting
-- rewards.withdrawal_request_id = the request id; the insert guard requires the
-- reward to be eligible and not yet linked.
DROP TRIGGER IF EXISTS "withdrawal_items_mutation_guard" ON "referrals"."withdrawal_items";
CREATE TRIGGER "withdrawal_items_mutation_guard"
    BEFORE INSERT OR UPDATE ON "referrals"."withdrawal_items"
    FOR EACH ROW EXECUTE FUNCTION "referrals"."guard_withdrawal_item_mutation"();

CREATE OR REPLACE FUNCTION "referrals"."release_reward_on_item_release"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals
AS $function$
BEGIN
    UPDATE "referrals"."rewards"
       SET "status" = 'eligible',
           "withdrawal_request_id" = NULL,
           "updated_at" = now()
     WHERE "id" = NEW."reward_id"
       AND "withdrawal_request_id" = NEW."withdrawal_request_id"
       AND "status" = 'locked';
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."release_reward_on_item_release"()
    FROM PUBLIC, "anon", "authenticated", "service_role";

DROP TRIGGER IF EXISTS "withdrawal_items_release_reward" ON "referrals"."withdrawal_items";
CREATE TRIGGER "withdrawal_items_release_reward"
    AFTER UPDATE OF "status" ON "referrals"."withdrawal_items"
    FOR EACH ROW
    WHEN (OLD."status" = 'reserved' AND NEW."status" = 'released')
    EXECUTE FUNCTION "referrals"."release_reward_on_item_release"();

-- Link rewards to the latest withdrawal request without coupling table
-- creation order. The reward row remains the financial-eligibility record;
-- withdrawal_items remains the historical reservation record.
DO $function$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'rewards_withdrawal_request_id_fkey'
          AND conrelid = 'referrals.rewards'::regclass
    ) THEN
        ALTER TABLE "referrals"."rewards"
            ADD CONSTRAINT "rewards_withdrawal_request_id_fkey"
            FOREIGN KEY ("withdrawal_request_id")
            REFERENCES "referrals"."withdrawal_requests"("id") ON DELETE SET NULL;
    END IF;
END;
$function$;

COMMIT;

-- ============================================================================
-- 20261109000001_capture_finance_schema
-- Captures the deployed finance schema that was missing from the repository.
-- Requires 20261109000000_capture_finance_dependencies for
-- commerce.commercial_orders and the private RLS helper functions.
-- Schema-only: no customer, payment, ledger, or journal rows are included.
-- Captured from the linked Supabase project on 2026-11-09.
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS "finance";
CREATE SCHEMA IF NOT EXISTS "extensions";
CREATE EXTENSION IF NOT EXISTS "btree_gist" WITH SCHEMA "extensions";

-- The finance functions and policies rely on these schemas being resolvable.
SET search_path = pg_catalog, finance, core, users, public, commerce, marketplace, extensions, auth;
SET check_function_bodies = false;

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "finance"."accounting_periods" (
    "id" uuid DEFAULT gen_random_uuid(),
    "entity_id" uuid,
    "start_date" date,
    "end_date" date,
    "status" text DEFAULT 'open'::text,
    "created_at" timestamp with time zone DEFAULT clock_timestamp(),
    "created_by" uuid,
    "closed_at" timestamp with time zone,
    "closed_by" uuid
);

CREATE TABLE IF NOT EXISTS "finance"."journal_lines" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "journal_id" uuid,
    "entity_id" uuid,
    "currency" text,
    "line_number" integer,
    "account_id" uuid,
    "debit_amount" numeric(20,4) DEFAULT 0,
    "credit_amount" numeric(20,4) DEFAULT 0,
    "description" text,
    "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "finance"."journals" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "entity_id" uuid,
    "journal_date" date DEFAULT CURRENT_DATE,
    "currency" text,
    "status" text DEFAULT 'draft'::text,
    "description" text,
    "source_type" text,
    "source_id" uuid,
    "idempotency_key" text,
    "reversal_of_journal_id" uuid,
    "created_at" timestamp with time zone DEFAULT now(),
    "posted_at" timestamp with time zone,
    "posted_by" text
);

CREATE TABLE IF NOT EXISTS "finance"."ledger_accounts" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "entity_id" uuid,
    "account_code" text,
    "account_name" text,
    "account_type" text,
    "normal_balance" text,
    "currency" text,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "finance"."obligation_settlements" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "obligation_id" uuid,
    "payment_id" uuid,
    "currency" text,
    "amount" numeric(20,4),
    "settled_at" timestamp with time zone DEFAULT now(),
    "idempotency_key" text,
    "metadata" jsonb DEFAULT '{}'::jsonb,
    "journal_id" uuid
);

CREATE TABLE IF NOT EXISTS "finance"."obligations" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "payer_entity_id" uuid,
    "payee_entity_id" uuid,
    "commercial_order_id" uuid,
    "legacy_order_id" uuid,
    "obligation_type" text,
    "status" text DEFAULT 'open'::text,
    "amount" numeric(20,4),
    "currency" text,
    "due_at" timestamp with time zone,
    "description" text,
    "idempotency_key" text,
    "metadata" jsonb DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "finance"."payment_attempts" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "obligation_id" uuid,
    "payer_entity_id" uuid,
    "payment_method_id" uuid,
    "provider" text,
    "method_type" text,
    "amount" numeric(20,4),
    "currency" text,
    "status" text DEFAULT 'created'::text,
    "provider_request_ref" text,
    "idempotency_key" text,
    "failure_code" text,
    "failure_message" text,
    "metadata" jsonb DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now(),
    "completed_at" timestamp with time zone
);

CREATE TABLE IF NOT EXISTS "finance"."payment_methods" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "entity_id" uuid,
    "provider" text,
    "method_type" text,
    "provider_token_ref" text,
    "display_details" jsonb DEFAULT '{}'::jsonb,
    "is_default" boolean DEFAULT false,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "finance"."payments" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "obligation_id" uuid,
    "payment_attempt_id" uuid,
    "payer_entity_id" uuid,
    "payee_entity_id" uuid,
    "payment_method_id" uuid,
    "provider" text,
    "provider_reference" text,
    "amount" numeric(20,4),
    "currency" text,
    "verified_at" timestamp with time zone DEFAULT now(),
    "verification_metadata" jsonb DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "finance"."provider_events" (
    "id" uuid DEFAULT uuid_generate_v7(),
    "provider" text,
    "provider_event_id" text,
    "payment_attempt_id" uuid,
    "event_type" text,
    "signature_verified" boolean DEFAULT false,
    "payload" jsonb DEFAULT '{}'::jsonb,
    "received_at" timestamp with time zone DEFAULT now(),
    "processed_at" timestamp with time zone,
    "processing_error" text,
    "verification_method" text,
    "callback_authentication_succeeded" boolean,
    "provider_query_succeeded" boolean,
    "provider_query_result" jsonb,
    "provider_verified_at" timestamp with time zone,
    "verified_provider_reference" text,
    "verified_amount" numeric(20,4),
    "verified_currency" text
);

-- ----------------------------------------------------------------------------
-- Constraints
-- ----------------------------------------------------------------------------
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_closed_by_fkey" FOREIGN KEY (closed_by) REFERENCES profiles(id);
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_closure_metadata" CHECK (status = 'open'::text AND closed_at IS NULL AND closed_by IS NULL OR status = 'closed'::text AND closed_at IS NOT NULL AND closed_by IS NOT NULL);
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_entity_id_fkey" FOREIGN KEY (entity_id) REFERENCES entities(id);
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_no_overlap" EXCLUDE USING gist (entity_id WITH =, daterange(start_date, end_date, '[]'::text) WITH &&);
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_valid_dates" CHECK (end_date >= start_date);
ALTER TABLE ONLY "finance"."accounting_periods" ADD CONSTRAINT "accounting_periods_valid_status" CHECK (status = ANY (ARRAY['open'::text, 'closed'::text]));
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_account_id_entity_id_fkey" FOREIGN KEY (account_id, entity_id) REFERENCES finance.ledger_accounts(id, entity_id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_check" CHECK (debit_amount > 0::numeric AND credit_amount = 0::numeric OR credit_amount > 0::numeric AND debit_amount = 0::numeric);
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_credit_amount_check" CHECK (credit_amount >= 0::numeric);
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_currency_check" CHECK (currency ~ '^[A-Z]{3}$'::text);
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_debit_amount_check" CHECK (debit_amount >= 0::numeric);
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_journal_id_entity_id_currency_fkey" FOREIGN KEY (journal_id, entity_id, currency) REFERENCES finance.journals(id, entity_id, currency) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_journal_id_line_number_key" UNIQUE (journal_id, line_number);
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_line_number_check" CHECK (line_number > 0);
ALTER TABLE ONLY "finance"."journal_lines" ADD CONSTRAINT "journal_lines_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_check" CHECK (status = 'draft'::text AND posted_at IS NULL OR status = 'posted'::text AND posted_at IS NOT NULL);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_currency_check" CHECK (currency ~ '^[A-Z]{3}$'::text);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_description_check" CHECK (length(btrim(description)) > 0);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_entity_id_fkey" FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_id_entity_id_currency_key" UNIQUE (id, entity_id, currency);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_idempotency_key_check" CHECK (length(btrim(idempotency_key)) > 0);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_idempotency_key_key" UNIQUE (idempotency_key);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_reversal_of_journal_id_fkey" FOREIGN KEY (reversal_of_journal_id) REFERENCES finance.journals(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_reversal_of_journal_id_key" UNIQUE (reversal_of_journal_id);
ALTER TABLE ONLY "finance"."journals" ADD CONSTRAINT "journals_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'posted'::text]));
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_account_code_check" CHECK (length(btrim(account_code)) > 0);
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_account_name_check" CHECK (length(btrim(account_name)) > 0);
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_account_type_check" CHECK (account_type = ANY (ARRAY['asset'::text, 'liability'::text, 'equity'::text, 'revenue'::text, 'expense'::text]));
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_currency_check" CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'::text);
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_entity_id_account_code_key" UNIQUE (entity_id, account_code);
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_entity_id_fkey" FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_id_entity_id_key" UNIQUE (id, entity_id);
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_normal_balance_check" CHECK (normal_balance = ANY (ARRAY['debit'::text, 'credit'::text]));
ALTER TABLE ONLY "finance"."ledger_accounts" ADD CONSTRAINT "ledger_accounts_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_amount_check" CHECK (amount > 0::numeric);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_currency_check" CHECK (currency ~ '^[A-Z]{3}$'::text);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_id_obligation_id_currency_key" UNIQUE (id, obligation_id, currency);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_idempotency_key_check" CHECK (length(btrim(idempotency_key)) > 0);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_idempotency_key_key" UNIQUE (idempotency_key);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_journal_id_fkey" FOREIGN KEY (journal_id) REFERENCES finance.journals(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_journal_id_key" UNIQUE (journal_id);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_metadata_check" CHECK (jsonb_typeof(metadata) = 'object'::text);
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_obligation_id_fkey" FOREIGN KEY (obligation_id) REFERENCES finance.obligations(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_payment_id_obligation_id_currency_fkey" FOREIGN KEY (payment_id, obligation_id, currency) REFERENCES finance.payments(id, obligation_id, currency) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."obligation_settlements" ADD CONSTRAINT "obligation_settlements_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_amount_check" CHECK (amount > 0::numeric);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_check" CHECK (payer_entity_id <> payee_entity_id);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_check1" CHECK (commercial_order_id IS NULL OR legacy_order_id IS NULL);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_commercial_order_id_fkey" FOREIGN KEY (commercial_order_id) REFERENCES commercial_orders(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_currency_check" CHECK (currency ~ '^[A-Z]{3}$'::text);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_idempotency_key_check" CHECK (length(btrim(idempotency_key)) > 0);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_idempotency_key_key" UNIQUE (idempotency_key);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_legacy_order_id_fkey" FOREIGN KEY (legacy_order_id) REFERENCES orders(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_metadata_check" CHECK (jsonb_typeof(metadata) = 'object'::text);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_obligation_type_check" CHECK (obligation_type = ANY (ARRAY['order'::text, 'subscription'::text, 'fee'::text, 'payout'::text, 'refund'::text, 'other'::text]));
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_payee_entity_id_fkey" FOREIGN KEY (payee_entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_payer_entity_id_fkey" FOREIGN KEY (payer_entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."obligations" ADD CONSTRAINT "obligations_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'open'::text, 'partially_settled'::text, 'settled'::text, 'cancelled'::text, 'void'::text]));
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_amount_check" CHECK (amount > 0::numeric);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_currency_check" CHECK (currency ~ '^[A-Z]{3}$'::text);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_id_obligation_id_key" UNIQUE (id, obligation_id);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_idempotency_key_check" CHECK (length(btrim(idempotency_key)) > 0);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_idempotency_key_key" UNIQUE (idempotency_key);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_metadata_check" CHECK (jsonb_typeof(metadata) = 'object'::text);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_method_type_check" CHECK (method_type = ANY (ARRAY['mpesa'::text, 'bank'::text, 'card'::text, 'wallet'::text, 'cash'::text, 'other'::text]));
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_obligation_id_fkey" FOREIGN KEY (obligation_id) REFERENCES finance.obligations(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_payer_entity_id_fkey" FOREIGN KEY (payer_entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_payment_method_id_check" CHECK (payment_method_id IS NULL OR payment_method_id IS NOT NULL);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_payment_method_id_fkey" FOREIGN KEY (payment_method_id) REFERENCES finance.payment_methods(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_provider_check" CHECK (length(btrim(provider)) > 0);
ALTER TABLE ONLY "finance"."payment_attempts" ADD CONSTRAINT "payment_attempts_status_check" CHECK (status = ANY (ARRAY['created'::text, 'pending'::text, 'processing'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text, 'expired'::text]));
ALTER TABLE ONLY "finance"."payment_methods" ADD CONSTRAINT "payment_methods_display_details_check" CHECK (jsonb_typeof(display_details) = 'object'::text);
ALTER TABLE ONLY "finance"."payment_methods" ADD CONSTRAINT "payment_methods_entity_id_fkey" FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payment_methods" ADD CONSTRAINT "payment_methods_id_entity_id_key" UNIQUE (id, entity_id);
ALTER TABLE ONLY "finance"."payment_methods" ADD CONSTRAINT "payment_methods_method_type_check" CHECK (method_type = ANY (ARRAY['mpesa'::text, 'bank'::text, 'card'::text, 'wallet'::text, 'cash'::text, 'other'::text]));
ALTER TABLE ONLY "finance"."payment_methods" ADD CONSTRAINT "payment_methods_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."payment_methods" ADD CONSTRAINT "payment_methods_provider_check" CHECK (length(btrim(provider)) > 0);
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_amount_check" CHECK (amount > 0::numeric);
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_currency_check" CHECK (currency ~ '^[A-Z]{3}$'::text);
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_id_obligation_id_currency_key" UNIQUE (id, obligation_id, currency);
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_obligation_id_fkey" FOREIGN KEY (obligation_id) REFERENCES finance.obligations(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_payee_entity_id_fkey" FOREIGN KEY (payee_entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_payer_entity_id_fkey" FOREIGN KEY (payer_entity_id) REFERENCES entities(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_payment_attempt_id_key" UNIQUE (payment_attempt_id);
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_payment_attempt_id_obligation_id_fkey" FOREIGN KEY (payment_attempt_id, obligation_id) REFERENCES finance.payment_attempts(id, obligation_id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_payment_method_id_fkey" FOREIGN KEY (payment_method_id) REFERENCES finance.payment_methods(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_provider_check" CHECK (length(btrim(provider)) > 0);
ALTER TABLE ONLY "finance"."payments" ADD CONSTRAINT "payments_verification_metadata_check" CHECK (jsonb_typeof(verification_metadata) = 'object'::text);
ALTER TABLE ONLY "finance"."provider_events" ADD CONSTRAINT "provider_events_event_type_check" CHECK (length(btrim(event_type)) > 0);
ALTER TABLE ONLY "finance"."provider_events" ADD CONSTRAINT "provider_events_payload_check" CHECK (jsonb_typeof(payload) = 'object'::text);
ALTER TABLE ONLY "finance"."provider_events" ADD CONSTRAINT "provider_events_payment_attempt_id_fkey" FOREIGN KEY (payment_attempt_id) REFERENCES finance.payment_attempts(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "finance"."provider_events" ADD CONSTRAINT "provider_events_pkey" PRIMARY KEY (id);
ALTER TABLE ONLY "finance"."provider_events" ADD CONSTRAINT "provider_events_provider_check" CHECK (length(btrim(provider)) > 0);
ALTER TABLE ONLY "finance"."provider_events" ADD CONSTRAINT "provider_events_provider_event_id_check" CHECK (length(btrim(provider_event_id)) > 0);
ALTER TABLE ONLY "finance"."provider_events" ADD CONSTRAINT "provider_events_provider_provider_event_id_key" UNIQUE (provider, provider_event_id);

-- ----------------------------------------------------------------------------
-- Indexes
-- ----------------------------------------------------------------------------
CREATE INDEX accounting_periods_closed_by_idx ON finance.accounting_periods USING btree (closed_by);
CREATE INDEX accounting_periods_created_by_idx ON finance.accounting_periods USING btree (created_by);
CREATE INDEX accounting_periods_entity_status_dates_idx ON finance.accounting_periods USING btree (entity_id, status, start_date, end_date);
CREATE INDEX journal_lines_account_entity_idx ON finance.journal_lines USING btree (account_id, entity_id);
CREATE INDEX journal_lines_account_idx ON finance.journal_lines USING btree (account_id, journal_id);
CREATE INDEX journal_lines_journal_entity_currency_idx ON finance.journal_lines USING btree (journal_id, entity_id, currency);
CREATE INDEX journal_lines_journal_idx ON finance.journal_lines USING btree (journal_id, line_number);
CREATE INDEX journals_draft_entity_date_idx ON finance.journals USING btree (entity_id, journal_date) WHERE (status = 'draft'::text);
CREATE INDEX journals_entity_date_idx ON finance.journals USING btree (entity_id, journal_date DESC);
CREATE INDEX journals_source_idx ON finance.journals USING btree (source_type, source_id) WHERE (source_id IS NOT NULL);
CREATE INDEX ledger_accounts_entity_active_idx ON finance.ledger_accounts USING btree (entity_id, is_active);
CREATE INDEX obligation_settlements_journal_idx ON finance.obligation_settlements USING btree (journal_id) WHERE (journal_id IS NOT NULL);
CREATE INDEX obligation_settlements_obligation_settled_idx ON finance.obligation_settlements USING btree (obligation_id, settled_at DESC);
CREATE INDEX obligation_settlements_payment_idx ON finance.obligation_settlements USING btree (payment_id);
CREATE INDEX settlements_payment_obligation_currency_idx ON finance.obligation_settlements USING btree (payment_id, obligation_id, currency);
CREATE INDEX obligations_commercial_order_idx ON finance.obligations USING btree (commercial_order_id) WHERE (commercial_order_id IS NOT NULL);
CREATE INDEX obligations_legacy_order_idx ON finance.obligations USING btree (legacy_order_id) WHERE (legacy_order_id IS NOT NULL);
CREATE INDEX obligations_payee_entity_idx ON finance.obligations USING btree (payee_entity_id);
CREATE INDEX obligations_payer_entity_idx ON finance.obligations USING btree (payer_entity_id);
CREATE INDEX payment_attempts_obligation_created_idx ON finance.payment_attempts USING btree (obligation_id, created_at DESC);
CREATE UNIQUE INDEX payment_attempts_one_active_mpesa_per_obligation ON finance.payment_attempts USING btree (obligation_id) WHERE ((lower(provider) = 'mpesa'::text) AND (status = ANY (ARRAY['created'::text, 'pending'::text, 'processing'::text])));
CREATE INDEX payment_attempts_payer_entity_idx ON finance.payment_attempts USING btree (payer_entity_id);
CREATE INDEX payment_attempts_payment_method_idx ON finance.payment_attempts USING btree (payment_method_id) WHERE (payment_method_id IS NOT NULL);
CREATE UNIQUE INDEX payment_attempts_provider_request_ref_uidx ON finance.payment_attempts USING btree (provider, provider_request_ref) WHERE (provider_request_ref IS NOT NULL);
CREATE INDEX payment_attempts_status_created_idx ON finance.payment_attempts USING btree (status, created_at);
CREATE INDEX payment_methods_entity_active_idx ON finance.payment_methods USING btree (entity_id, is_active);
CREATE UNIQUE INDEX payment_methods_one_default_per_entity ON finance.payment_methods USING btree (entity_id) WHERE (is_default AND is_active);
CREATE INDEX payments_attempt_obligation_idx ON finance.payments USING btree (payment_attempt_id, obligation_id) WHERE (payment_attempt_id IS NOT NULL);
CREATE INDEX payments_obligation_verified_idx ON finance.payments USING btree (obligation_id, verified_at DESC);
CREATE INDEX payments_party_verified_idx ON finance.payments USING btree (payer_entity_id, payee_entity_id, verified_at DESC);
CREATE INDEX payments_payee_entity_idx ON finance.payments USING btree (payee_entity_id);
CREATE INDEX payments_payment_method_idx ON finance.payments USING btree (payment_method_id) WHERE (payment_method_id IS NOT NULL);
CREATE UNIQUE INDEX payments_provider_reference_uidx ON finance.payments USING btree (provider, provider_reference) WHERE (provider_reference IS NOT NULL);
CREATE INDEX provider_events_attempt_received_idx ON finance.provider_events USING btree (payment_attempt_id, received_at DESC);
CREATE UNIQUE INDEX provider_events_mpesa_verified_reference_uidx ON finance.provider_events USING btree (verified_provider_reference) WHERE ((provider = 'mpesa'::text) AND (verified_provider_reference IS NOT NULL));

-- ----------------------------------------------------------------------------
-- Row level security
-- ----------------------------------------------------------------------------
ALTER TABLE "finance"."accounting_periods" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."journal_lines" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."journals" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."ledger_accounts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."obligation_settlements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."obligations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."payment_attempts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."payment_methods" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."payments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "finance"."provider_events" ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- Functions
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION finance.claim_mpesa_attempt(p_payment_attempt_id uuid)
 RETURNS finance.payment_attempts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'core', 'auth'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
  v_obligation finance.obligations%ROWTYPE;
  v_profile_id uuid;
  v_platform_entity_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authenticated payer entity membership is required' USING ERRCODE = '42501';
  END IF;
  v_profile_id := core.current_profile_id();
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Authenticated profile is not mapped to a profile record' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO STRICT v_attempt
    FROM finance.payment_attempts
   WHERE id = p_payment_attempt_id
   FOR UPDATE;
  IF lower(v_attempt.provider) <> 'mpesa' THEN
    RAISE EXCEPTION 'Attempt is not an M-Pesa attempt' USING ERRCODE = '22023';
  END IF;
  IF v_attempt.status <> 'created' THEN
    RAISE EXCEPTION 'M-Pesa attempt is not claimable; provider outcome may already be unknown' USING ERRCODE = '55000';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM core.entity_members em
     WHERE em.entity_id = v_attempt.payer_entity_id
       AND em.profile_id = v_profile_id
       AND em.is_active IS TRUE
       AND em.membership_status = 'active'
       AND em.can_manage IS TRUE
  ) THEN
    RAISE EXCEPTION 'Caller cannot manage the attempt payer entity' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO STRICT v_obligation
    FROM finance.obligations
   WHERE id = v_attempt.obligation_id
   FOR SHARE;
  SELECT id INTO STRICT v_platform_entity_id
    FROM core.entities
   WHERE is_active IS TRUE
     AND metadata->>'platform_entity' = 'true'
     AND metadata->>'purpose' = 'platform_administration';
  IF v_obligation.payer_entity_id IS DISTINCT FROM v_attempt.payer_entity_id
     OR v_obligation.payee_entity_id IS DISTINCT FROM v_platform_entity_id
     OR v_attempt.currency <> 'KES'
     OR v_obligation.currency <> 'KES'
     OR v_obligation.legacy_order_id IS NOT NULL
     OR v_obligation.status NOT IN ('open','partially_settled')
     OR v_obligation.metadata->>'tax_treatment' IS DISTINCT FROM 'not_applicable'
     OR v_attempt.metadata->>'finance_charge_code' IS DISTINCT FROM v_obligation.metadata->>'finance_charge_code'
     OR NOT (
       (v_obligation.obligation_type = 'subscription' AND v_obligation.metadata->>'finance_charge_code' = 'subscription')
       OR (v_obligation.obligation_type = 'fee' AND v_obligation.metadata->>'finance_charge_code' IN ('contact_unlock','other_platform_charge'))
     ) THEN
    RAISE EXCEPTION 'M-Pesa initiation is restricted to eligible KES platform-owned obligations';
  END IF;

  UPDATE finance.payment_attempts
     SET status = 'processing', updated_at = clock_timestamp()
   WHERE id = v_attempt.id AND status = 'created'
   RETURNING * INTO v_attempt;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'M-Pesa attempt was already claimed' USING ERRCODE = '55000';
  END IF;
  RETURN v_attempt;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.claim_mpesa_attempt_safe(p_payment_attempt_id uuid)
 RETURNS TABLE(payment_attempt_id uuid, attempt_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'core', 'auth'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
  v_obligation finance.obligations%ROWTYPE;
  v_profile_id uuid;
  v_platform_entity_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authenticated payer entity membership is required' USING ERRCODE = '42501';
  END IF;
  v_profile_id := core.current_profile_id();
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Authenticated profile is not mapped to a profile record' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO STRICT v_attempt
    FROM finance.payment_attempts
   WHERE id = p_payment_attempt_id
   FOR UPDATE;
  IF lower(v_attempt.provider) <> 'mpesa' THEN
    RAISE EXCEPTION 'Attempt is not an M-Pesa attempt' USING ERRCODE = '22023';
  END IF;
  IF v_attempt.status <> 'created' THEN
    RAISE EXCEPTION 'M-Pesa attempt is not claimable; provider outcome may already be unknown' USING ERRCODE = '55000';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM core.entity_members em
     WHERE em.entity_id = v_attempt.payer_entity_id
       AND em.profile_id = v_profile_id
       AND em.is_active IS TRUE
       AND em.membership_status = 'active'
       AND em.can_manage IS TRUE
  ) THEN
    RAISE EXCEPTION 'Caller cannot manage the attempt payer entity' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO STRICT v_obligation
    FROM finance.obligations
   WHERE id = v_attempt.obligation_id
   FOR SHARE;
  SELECT id INTO STRICT v_platform_entity_id
    FROM core.entities
   WHERE is_active IS TRUE
     AND metadata->>'platform_entity' = 'true'
     AND metadata->>'purpose' = 'platform_administration';
  IF v_obligation.payer_entity_id IS DISTINCT FROM v_attempt.payer_entity_id
     OR v_obligation.payee_entity_id IS DISTINCT FROM v_platform_entity_id
     OR v_attempt.currency <> 'KES'
     OR v_obligation.currency <> 'KES'
     OR v_obligation.legacy_order_id IS NOT NULL
     OR v_obligation.status NOT IN ('open','partially_settled')
     OR v_obligation.metadata->>'tax_treatment' IS DISTINCT FROM 'not_applicable'
     OR v_attempt.metadata->>'finance_charge_code' IS DISTINCT FROM v_obligation.metadata->>'finance_charge_code'
     OR NOT (
       (v_obligation.obligation_type = 'subscription' AND v_obligation.metadata->>'finance_charge_code' = 'subscription')
       OR (v_obligation.obligation_type = 'fee' AND v_obligation.metadata->>'finance_charge_code' IN ('contact_unlock','other_platform_charge'))
     ) THEN
    RAISE EXCEPTION 'M-Pesa initiation is restricted to eligible KES platform-owned obligations';
  END IF;

  UPDATE finance.payment_attempts
     SET status = 'processing', updated_at = clock_timestamp()
   WHERE id = v_attempt.id AND status = 'created'
   RETURNING * INTO v_attempt;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'M-Pesa attempt was already claimed' USING ERRCODE = '55000';
  END IF;
  payment_attempt_id := v_attempt.id;
  attempt_status := v_attempt.status;
  RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.close_accounting_period(p_period_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  v_period finance.accounting_periods%ROWTYPE;
  v_profile_id uuid;
BEGIN
  IF p_period_id IS NULL THEN
    RAISE EXCEPTION 'Accounting period id is required' USING ERRCODE = '22023';
  END IF;

  SELECT p.id
    INTO v_profile_id
    FROM users.profiles AS p
   WHERE p.auth_user_id = auth.uid()
     AND p.is_active IS TRUE
     AND p.account_status = 'active';

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'An active authenticated profile is required' USING ERRCODE = '42501';
  END IF;

  SELECT ap.*
    INTO v_period
    FROM finance.accounting_periods AS ap
   WHERE ap.id = p_period_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Accounting period not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM core.entities AS e
     WHERE e.id = v_period.entity_id
       AND e.is_active IS TRUE
       AND (
         e.owner_id = v_profile_id
         OR EXISTS (
           SELECT 1
             FROM core.entity_members AS em
            WHERE em.entity_id = e.id
              AND em.profile_id = v_profile_id
              AND em.is_active IS TRUE
              AND em.membership_status = 'active'
              AND em.can_manage IS TRUE
         )
       )
  ) THEN
    RAISE EXCEPTION 'Insufficient authority to close this accounting period' USING ERRCODE = '42501';
  END IF;

  IF v_period.status = 'closed' THEN
    RETURN v_period.id;
  END IF;

  IF EXISTS (
    SELECT 1
      FROM finance.journals AS j
     WHERE j.entity_id = v_period.entity_id
       AND j.journal_date BETWEEN v_period.start_date AND v_period.end_date
       AND j.status = 'draft'
  ) THEN
    RAISE EXCEPTION 'Cannot close an accounting period while draft journals remain' USING ERRCODE = '55000';
  END IF;

  UPDATE finance.accounting_periods
     SET status = 'closed',
         closed_at = clock_timestamp(),
         closed_by = v_profile_id
   WHERE id = v_period.id;

  RETURN v_period.id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.complete_mpesa_initiation(p_payment_attempt_id uuid, p_checkout_request_id text DEFAULT NULL::text, p_failure_code text DEFAULT NULL::text, p_failure_message text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'auth'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
  v_checkout text := nullif(btrim(p_checkout_request_id),'');
  v_failure text := nullif(btrim(p_failure_code),'');
  v_message text := left(coalesce(p_failure_message,''),500);
BEGIN
  SELECT * INTO STRICT v_attempt
    FROM finance.payment_attempts
   WHERE id = p_payment_attempt_id
   FOR UPDATE;
  IF lower(v_attempt.provider) <> 'mpesa' THEN
    RAISE EXCEPTION 'Attempt is not an M-Pesa attempt';
  END IF;

  IF v_failure IS NOT NULL THEN
    IF v_attempt.status = 'failed' THEN
      IF v_attempt.failure_code IS DISTINCT FROM v_failure
         OR v_attempt.failure_message IS DISTINCT FROM v_message THEN
        RAISE EXCEPTION 'Attempt already failed with different failure data';
      END IF;
      RETURN;
    END IF;
    IF v_attempt.status <> 'processing' THEN
      RAISE EXCEPTION 'Only a processing attempt with a definitive provider rejection can be marked failed';
    END IF;
    UPDATE finance.payment_attempts
       SET status = 'failed', failure_code = v_failure,
           failure_message = v_message,
           completed_at = clock_timestamp(), updated_at = clock_timestamp()
     WHERE id = v_attempt.id;
    RETURN;
  END IF;

  IF v_checkout IS NULL THEN
    IF v_attempt.status = 'processing' THEN
      RETURN; -- Unknown/network outcome: deliberately retain processing for reconciliation.
    END IF;
    RAISE EXCEPTION 'CheckoutRequestID is required to complete a known successful initiation' USING ERRCODE = '22023';
  END IF;
  IF v_attempt.provider_request_ref IS NOT NULL
     AND v_attempt.provider_request_ref <> v_checkout THEN
    RAISE EXCEPTION 'Attempt already has a different provider request reference';
  END IF;
  IF v_attempt.status = 'pending' THEN
    RETURN;
  END IF;
  IF v_attempt.status <> 'processing' THEN
    RAISE EXCEPTION 'Only a processing attempt can complete provider initiation';
  END IF;

  UPDATE finance.payment_attempts
     SET provider_request_ref = v_checkout,
         status = 'pending', updated_at = clock_timestamp()
   WHERE id = v_attempt.id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.create_accounting_period(p_entity_id uuid, p_start_date date, p_end_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  v_profile_id uuid;
  v_period_id uuid;
BEGIN
  IF p_entity_id IS NULL OR p_start_date IS NULL OR p_end_date IS NULL OR p_end_date < p_start_date THEN
    RAISE EXCEPTION 'A valid entity and inclusive period date range are required' USING ERRCODE = '22023';
  END IF;

  SELECT p.id
    INTO v_profile_id
    FROM users.profiles AS p
   WHERE p.auth_user_id = auth.uid()
     AND p.is_active IS TRUE
     AND p.account_status = 'active';

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'An active authenticated profile is required' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM core.entities AS e
     WHERE e.id = p_entity_id
       AND e.is_active IS TRUE
       AND (
         e.owner_id = v_profile_id
         OR EXISTS (
           SELECT 1
             FROM core.entity_members AS em
            WHERE em.entity_id = e.id
              AND em.profile_id = v_profile_id
              AND em.is_active IS TRUE
              AND em.membership_status = 'active'
              AND em.can_manage IS TRUE
         )
       )
  ) THEN
    RAISE EXCEPTION 'Insufficient authority to manage accounting periods for this entity' USING ERRCODE = '42501';
  END IF;

  INSERT INTO finance.accounting_periods (entity_id, start_date, end_date, created_by)
  VALUES (p_entity_id, p_start_date, p_end_date, v_profile_id)
  RETURNING id INTO v_period_id;

  RETURN v_period_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.create_obligation(p_payer_entity_id uuid, p_payee_entity_id uuid, p_amount numeric, p_currency text, p_idempotency_key text, p_obligation_type text DEFAULT 'other'::text, p_commercial_order_id uuid DEFAULT NULL::uuid, p_legacy_order_id uuid DEFAULT NULL::uuid, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_description text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_id uuid;
  v_currency text := upper(btrim(p_currency));
BEGIN
  IF p_payer_entity_id IS NULL OR p_payee_entity_id IS NULL OR p_payer_entity_id = p_payee_entity_id THEN
    RAISE EXCEPTION 'Distinct payer and payee entities are required';
  END IF;
  IF coalesce(btrim(p_idempotency_key), '') = '' THEN
    RAISE EXCEPTION 'A non-empty idempotency key is required';
  END IF;
  IF p_commercial_order_id IS NOT NULL AND p_legacy_order_id IS NOT NULL THEN
    RAISE EXCEPTION 'Specify at most one Commerce order reference';
  END IF;
  IF p_commercial_order_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM commerce.commercial_orders o
    WHERE o.id = p_commercial_order_id
      AND o.buyer_entity_id = p_payer_entity_id
      AND o.seller_entity_id = p_payee_entity_id
      AND o.currency = v_currency
      AND o.total_amount = p_amount
  ) THEN
    RAISE EXCEPTION 'Canonical order parties, currency, and total must match the obligation';
  END IF;
  IF p_legacy_order_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM commerce.orders o
    JOIN commerce.business_profiles bp ON bp.id = o.supplier_id
    WHERE o.id = p_legacy_order_id
      AND bp.entity_id = p_payee_entity_id
      AND o.total_amount = p_amount
      AND v_currency = 'KES'
      AND (EXISTS (SELECT 1 FROM core.entities e WHERE e.id = p_payer_entity_id AND e.owner_id = o.buyer_id)
           OR EXISTS (SELECT 1 FROM core.entity_members em WHERE em.entity_id = p_payer_entity_id AND em.profile_id = o.buyer_id AND em.is_active AND em.membership_status = 'active'))
  ) THEN
    RAISE EXCEPTION 'Legacy order parties or total cannot be mapped to the specified entities';
  END IF;

  INSERT INTO finance.obligations AS o (
    payer_entity_id, payee_entity_id, commercial_order_id, legacy_order_id,
    obligation_type, amount, currency, due_at, description, idempotency_key, metadata
  ) VALUES (
    p_payer_entity_id, p_payee_entity_id, p_commercial_order_id, p_legacy_order_id,
    p_obligation_type, p_amount, v_currency, p_due_at, p_description, btrim(p_idempotency_key),
    coalesce(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (idempotency_key) DO UPDATE SET id = o.id
  WHERE o.payer_entity_id = EXCLUDED.payer_entity_id
    AND o.payee_entity_id = EXCLUDED.payee_entity_id
    AND o.amount = EXCLUDED.amount AND o.currency = EXCLUDED.currency
    AND o.obligation_type = EXCLUDED.obligation_type
    AND o.commercial_order_id IS NOT DISTINCT FROM EXCLUDED.commercial_order_id
    AND o.legacy_order_id IS NOT DISTINCT FROM EXCLUDED.legacy_order_id
    AND o.due_at IS NOT DISTINCT FROM EXCLUDED.due_at
    AND o.description IS NOT DISTINCT FROM EXCLUDED.description
    AND o.metadata IS NOT DISTINCT FROM EXCLUDED.metadata
  RETURNING o.id INTO v_id;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Idempotency key already exists with different obligation data';
  END IF;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.create_payment_attempt(p_obligation_id uuid, p_provider text, p_method_type text, p_amount numeric, p_idempotency_key text, p_payment_method_id uuid DEFAULT NULL::uuid, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_obligation finance.obligations%ROWTYPE;
  v_paid numeric(20,4);
  v_id uuid;
BEGIN
  SELECT * INTO STRICT v_obligation FROM finance.obligations WHERE id = p_obligation_id FOR UPDATE;
  IF v_obligation.status NOT IN ('open','partially_settled') THEN
    RAISE EXCEPTION 'Obligation is not payable';
  END IF;
  IF coalesce(btrim(p_idempotency_key), '') = '' OR coalesce(btrim(p_provider), '') = '' THEN
    RAISE EXCEPTION 'Provider and idempotency key are required';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > v_obligation.amount THEN
    RAISE EXCEPTION 'Attempt amount must be positive and no greater than the obligation';
  END IF;
  SELECT coalesce(sum(p.amount), 0) INTO v_paid
    FROM finance.payments p WHERE p.obligation_id = v_obligation.id;
  IF p_amount > v_obligation.amount - v_paid THEN
    RAISE EXCEPTION 'Attempt amount exceeds the outstanding obligation balance';
  END IF;

  INSERT INTO finance.payment_attempts AS a (
    obligation_id, payer_entity_id, payment_method_id, provider, method_type,
    amount, currency, idempotency_key, metadata
  ) VALUES (
    v_obligation.id, v_obligation.payer_entity_id, p_payment_method_id,
    btrim(p_provider), p_method_type, p_amount, v_obligation.currency,
    btrim(p_idempotency_key), coalesce(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (idempotency_key) DO UPDATE SET id = a.id
  WHERE a.obligation_id = EXCLUDED.obligation_id
    AND a.payer_entity_id = EXCLUDED.payer_entity_id
    AND a.payment_method_id IS NOT DISTINCT FROM EXCLUDED.payment_method_id
    AND a.provider = EXCLUDED.provider AND a.method_type = EXCLUDED.method_type
    AND a.amount = EXCLUDED.amount AND a.currency = EXCLUDED.currency
  RETURNING a.id INTO v_id;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Idempotency key already exists with different attempt data';
  END IF;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.enforce_obligation_immutability_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.payer_entity_id IS DISTINCT FROM OLD.payer_entity_id
     OR NEW.payee_entity_id IS DISTINCT FROM OLD.payee_entity_id
     OR NEW.amount IS DISTINCT FROM OLD.amount
     OR NEW.currency IS DISTINCT FROM OLD.currency
     OR NEW.obligation_type IS DISTINCT FROM OLD.obligation_type
     OR NEW.commercial_order_id IS DISTINCT FROM OLD.commercial_order_id
     OR NEW.legacy_order_id IS DISTINCT FROM OLD.legacy_order_id
     OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
     OR NEW.due_at IS DISTINCT FROM OLD.due_at
     OR NEW.description IS DISTINCT FROM OLD.description
     OR NEW.metadata IS DISTINCT FROM OLD.metadata
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Obligation identity and terms are immutable'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.finalize_mpesa_payment(p_payment_attempt_id uuid, p_provider_event_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'core', 'commerce', 'auth'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
  v_obligation finance.obligations%ROWTYPE;
  v_event finance.provider_events%ROWTYPE;
  v_platform_entity uuid;
  v_revenue_code text;
  v_credit_account_id uuid;
  v_clearing_account_id uuid;
  v_payment_id uuid;
  v_journal_id uuid;
  v_settlement_id uuid;
  v_journal_key text;
  v_existing_payment uuid;
  v_payment_count bigint;
  v_paid numeric(20,4);
  v_unlock_rows integer;
  v_metadata jsonb;
  v_contact_listing_id uuid;
  v_unlock_completed boolean;
BEGIN
  SELECT * INTO STRICT v_event FROM finance.provider_events WHERE id=p_provider_event_id FOR UPDATE;
  SELECT * INTO STRICT v_attempt FROM finance.payment_attempts WHERE id=p_payment_attempt_id FOR UPDATE;
  IF v_attempt.provider <> 'mpesa' OR v_event.provider <> 'mpesa'
     OR v_event.payment_attempt_id IS DISTINCT FROM v_attempt.id
     OR v_event.signature_verified IS NOT FALSE
     OR v_event.verification_method IS DISTINCT FROM 'callback_secret_plus_daraja_stk_query'
     OR v_event.callback_authentication_succeeded IS NOT TRUE
     OR v_event.provider_query_succeeded IS NOT TRUE
     OR v_event.provider_verified_at IS NULL
     OR v_event.verified_provider_reference IS NULL
     OR v_event.verified_amount IS DISTINCT FROM v_attempt.amount
     OR v_event.verified_currency IS DISTINCT FROM v_attempt.currency THEN
    RAISE EXCEPTION 'Trusted M-Pesa verification evidence does not validate this attempt';
  END IF;
  IF v_attempt.provider_request_ref IS NULL THEN
    RAISE EXCEPTION 'Attempt has no Daraja CheckoutRequestID';
  END IF;
  SELECT * INTO STRICT v_obligation FROM finance.obligations WHERE id=v_attempt.obligation_id FOR UPDATE;
  SELECT id INTO STRICT v_platform_entity FROM core.entities
   WHERE is_active IS TRUE AND metadata->>'platform_entity'='true' AND metadata->>'purpose'='platform_administration';
  IF v_obligation.payee_entity_id IS DISTINCT FROM v_platform_entity OR v_attempt.currency <> 'KES' THEN
    RAISE EXCEPTION 'Central M-Pesa finalization is restricted to KES platform-owned obligations';
  END IF;
  IF v_obligation.legacy_order_id IS NOT NULL THEN
    RAISE EXCEPTION 'Central platform finalization rejects legacy Commerce order references';
  END IF;
  IF v_obligation.metadata->>'tax_treatment' IS DISTINCT FROM 'not_applicable' THEN
    RAISE EXCEPTION 'Finalization is blocked until approved tax treatment is recorded';
  END IF;
  IF v_attempt.metadata->>'finance_charge_code' IS DISTINCT FROM v_obligation.metadata->>'finance_charge_code' THEN
    RAISE EXCEPTION 'Attempt charge classification does not match its obligation';
  END IF;
  v_revenue_code := CASE
    WHEN v_obligation.obligation_type='subscription' AND v_obligation.metadata->>'finance_charge_code'='subscription' THEN '2200'
    WHEN v_obligation.obligation_type='fee' AND v_obligation.metadata->>'finance_charge_code'='contact_unlock' THEN '4100'
    WHEN v_obligation.obligation_type='fee' AND v_obligation.metadata->>'finance_charge_code'='other_platform_charge' THEN '4300'
    ELSE NULL END;
  IF v_revenue_code IS NULL THEN
    RAISE EXCEPTION 'Obligation type or platform charge classification has no approved account mapping';
  END IF;
  IF v_event.verified_currency <> v_obligation.currency
     OR v_event.verified_provider_reference IS NULL OR v_event.verified_amount IS DISTINCT FROM v_attempt.amount THEN
    RAISE EXCEPTION 'Verified provider reference, amount, or currency does not match the obligation';
  END IF;
  IF v_attempt.status NOT IN ('created','pending','processing','succeeded') THEN
    RAISE EXCEPTION 'Attempt status is not eligible for finalization';
  END IF;

  SELECT id INTO v_existing_payment FROM finance.payments WHERE payment_attempt_id=v_attempt.id;
  IF v_obligation.obligation_type='fee' AND v_obligation.metadata->>'finance_charge_code'='contact_unlock' THEN
    IF v_obligation.legacy_order_id IS NOT NULL
       OR v_attempt.amount IS DISTINCT FROM v_obligation.amount THEN
      RAISE EXCEPTION 'Contact unlock finalization requires the full obligation amount and no legacy order';
    END IF;
    SELECT cu.listing_id,
           coalesce(cu.payment_status = 'completed' AND cu.unlocked IS TRUE, false)
      INTO v_contact_listing_id, v_unlock_completed
      FROM marketplace.contact_unlocks cu
     WHERE cu.id::text = v_obligation.metadata->>'contact_unlock_id'
       AND cu.finance_obligation_id = v_obligation.id
       AND cu.entity_id = v_obligation.payer_entity_id
       AND cu.amount = v_obligation.amount
       AND cu.currency = v_obligation.currency
       AND cu.listing_id::text = v_obligation.metadata->>'listing_id'
     FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Matching contact unlock is missing or inconsistent';
    END IF;
    IF NOT v_unlock_completed THEN
      PERFORM marketplace.assert_contact_unlock_listing_eligible(v_contact_listing_id);
    END IF;
    SELECT count(*), coalesce(sum(p.amount),0)
      INTO v_payment_count, v_paid
      FROM finance.payments p
     WHERE p.obligation_id = v_obligation.id;
    IF v_existing_payment IS NULL THEN
      IF v_payment_count <> 0 OR v_paid <> 0 OR v_obligation.status <> 'open' THEN
        RAISE EXCEPTION 'Contact unlock cannot finalize after any payment or settlement has been recorded';
      END IF;
    ELSE
      IF v_payment_count <> 1 OR v_paid IS DISTINCT FROM v_obligation.amount
         OR NOT EXISTS (
           SELECT 1 FROM finance.payments p
           WHERE p.id = v_existing_payment
             AND p.obligation_id = v_obligation.id
             AND p.payment_attempt_id = v_attempt.id
             AND p.amount = v_obligation.amount
             AND p.payer_entity_id = v_obligation.payer_entity_id
             AND p.payee_entity_id = v_platform_entity
         )
         OR v_obligation.status <> 'settled' THEN
        RAISE EXCEPTION 'Existing contact-unlock payment is not a complete, idempotently finalized payment';
      END IF;
    END IF;
  ELSIF v_existing_payment IS NULL AND v_obligation.status NOT IN ('open','partially_settled') THEN
    RAISE EXCEPTION 'Obligation is not open for payment';
  END IF;

  IF EXISTS (SELECT 1 FROM finance.payments p WHERE lower(p.provider)='mpesa'
             AND p.provider_reference=v_event.verified_provider_reference
             AND p.payment_attempt_id IS DISTINCT FROM v_attempt.id) THEN
    RAISE EXCEPTION 'Provider receipt has already been applied to another attempt' USING ERRCODE='23505';
  END IF;

  v_metadata := jsonb_build_object(
    'verification_method',v_event.verification_method,
    'callback_authentication_succeeded',v_event.callback_authentication_succeeded,
    'provider_query_succeeded',v_event.provider_query_succeeded,
    'provider_verified_at',v_event.provider_verified_at,
    'provider_event_id',v_event.id,
    'signature_verified',false
  );
  v_payment_id := finance.record_verified_payment_internal(
    v_attempt.id,v_event.id,v_event.verified_provider_reference,
    v_event.verified_amount,v_event.verified_currency,v_metadata
  );

  SELECT id INTO STRICT v_clearing_account_id FROM finance.ledger_accounts
   WHERE entity_id=v_platform_entity AND account_code='1000' AND account_type='asset'
     AND normal_balance='debit' AND currency='KES' AND is_active IS TRUE;
  SELECT id INTO STRICT v_credit_account_id FROM finance.ledger_accounts
   WHERE entity_id=v_platform_entity AND account_code=v_revenue_code
     AND currency='KES' AND is_active IS TRUE;
  v_journal_key := 'platform-payment:'||v_payment_id::text;
  SELECT id INTO v_journal_id FROM finance.journals WHERE idempotency_key=v_journal_key FOR UPDATE;
  IF v_journal_id IS NULL THEN
    INSERT INTO finance.journals(entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
    VALUES(v_platform_entity,v_event.provider_verified_at::date,'KES','draft','Verified M-Pesa platform fee payment','payment',v_payment_id,v_journal_key)
    RETURNING id INTO v_journal_id;
    INSERT INTO finance.journal_lines(journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    VALUES
      (v_journal_id,v_platform_entity,'KES',1,v_clearing_account_id,v_attempt.amount,0,'M-Pesa platform collection received'),
      (v_journal_id,v_platform_entity,'KES',2,v_credit_account_id,0,v_attempt.amount,'Platform charge earned or subscription deferred');
    PERFORM finance.post_journal(v_journal_id);
  ELSE
    IF NOT EXISTS (SELECT 1 FROM finance.journals j WHERE j.id=v_journal_id AND j.status='posted'
                   AND j.entity_id=v_platform_entity AND j.currency='KES' AND j.source_type='payment'
                   AND j.source_id=v_payment_id) THEN
      RAISE EXCEPTION 'Existing payment journal is inconsistent or unposted';
    END IF;
  END IF;

  v_settlement_id := finance.settle_payment(
    v_payment_id,v_attempt.amount,'payment-settlement:'||v_payment_id::text,v_journal_id,
    jsonb_build_object('source','mpesa_finalization','provider_event_id',v_event.id)
  );

  IF v_obligation.obligation_type='fee' AND v_obligation.metadata->>'finance_charge_code'='contact_unlock' THEN
    IF NOT v_unlock_completed THEN
      PERFORM marketplace.assert_contact_unlock_listing_eligible(v_contact_listing_id);
    END IF;
    UPDATE marketplace.contact_unlocks
       SET payment_status = 'completed', unlocked = true, valid_until = NULL
     WHERE finance_obligation_id = v_obligation.id
       AND entity_id = v_obligation.payer_entity_id
       AND amount = v_obligation.amount
       AND currency = v_obligation.currency
       AND payment_status = 'pending'
       AND unlocked IS FALSE;
    GET DIAGNOSTICS v_unlock_rows = ROW_COUNT;
    IF v_unlock_rows = 0 AND NOT EXISTS (
      SELECT 1 FROM marketplace.contact_unlocks cu
      WHERE cu.finance_obligation_id = v_obligation.id
        AND cu.entity_id = v_obligation.payer_entity_id
        AND cu.amount = v_obligation.amount
        AND cu.currency = v_obligation.currency
        AND cu.payment_status = 'completed'
        AND cu.unlocked IS TRUE
    ) THEN
      RAISE EXCEPTION 'Financial finalization succeeded but no matching pending unlock could be activated';
    END IF;
  END IF;

  RETURN v_payment_id;
END
$function$;

CREATE OR REPLACE FUNCTION finance.guard_journal_line_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_old_journal_id uuid;
  v_new_journal_id uuid;
  v_parent record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_new_journal_id := NEW.journal_id;
  ELSIF TG_OP = 'DELETE' THEN
    v_old_journal_id := OLD.journal_id;
  ELSE
    v_old_journal_id := OLD.journal_id;
    v_new_journal_id := NEW.journal_id;
  END IF;

  -- Acquire all affected parent locks in a stable order before inspecting status.
  FOR v_parent IN
    SELECT j.id, j.status
    FROM finance.journals AS j
    WHERE j.id = v_old_journal_id OR j.id = v_new_journal_id
    ORDER BY j.id
    FOR UPDATE
  LOOP
    IF v_parent.status = 'posted' THEN
      RAISE EXCEPTION 'Lines of a posted journal are immutable';
    END IF;
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.guard_journal_state()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_line_count bigint;
  v_debits numeric;
  v_credits numeric;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status = 'posted' THEN
      RAISE EXCEPTION 'Posted journals are immutable';
    END IF;
    RETURN OLD;
  ELSIF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'draft' OR NEW.posted_at IS NOT NULL THEN
      RAISE EXCEPTION 'Journals must be created as drafts';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'posted' THEN
    RAISE EXCEPTION 'Posted journals are immutable';
  END IF;

  IF NEW.status = 'posted' THEN
    IF current_setting('finance.posting', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'Use finance.post_journal to post a journal';
    END IF;

    SELECT count(*), COALESCE(sum(l.debit_amount), 0), COALESCE(sum(l.credit_amount), 0)
      INTO v_line_count, v_debits, v_credits
      FROM finance.journal_lines AS l
     WHERE l.journal_id = NEW.id;

    IF v_line_count < 2 THEN
      RAISE EXCEPTION 'A journal requires at least two lines';
    END IF;
    IF v_debits <= 0 OR v_debits <> v_credits THEN
      RAISE EXCEPTION 'Journal is unbalanced: debits %, credits %', v_debits, v_credits;
    END IF;
    IF EXISTS (
      SELECT 1
      FROM finance.journal_lines AS l
      JOIN finance.ledger_accounts AS a
        ON a.id = l.account_id AND a.entity_id = l.entity_id
      WHERE l.journal_id = NEW.id
        AND (a.is_active IS NOT TRUE OR (a.currency IS NOT NULL AND a.currency <> NEW.currency))
    ) THEN
      RAISE EXCEPTION 'Journal contains an inactive or currency-incompatible ledger account';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.guard_payment_attempt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_payer uuid;
  v_currency text;
  v_method_entity uuid;
  v_method_provider text;
  v_method_type text;
  v_method_active boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT o.payer_entity_id, o.currency INTO v_payer, v_currency
      FROM finance.obligations o WHERE o.id = NEW.obligation_id;
    IF v_payer IS NULL OR NEW.payer_entity_id <> v_payer OR NEW.currency <> v_currency THEN
      RAISE EXCEPTION 'Attempt payer or currency must match its obligation';
    END IF;
    IF lower(NEW.provider) = 'mpesa' AND (NEW.status <> 'created' OR NEW.provider_request_ref IS NOT NULL) THEN
      RAISE EXCEPTION 'New M-Pesa attempts must begin created without a provider reference';
    END IF;
    IF NEW.payment_method_id IS NOT NULL THEN
      SELECT m.entity_id, m.provider, m.method_type, m.is_active
        INTO v_method_entity, v_method_provider, v_method_type, v_method_active
        FROM finance.payment_methods m WHERE m.id = NEW.payment_method_id;
      IF v_method_entity IS DISTINCT FROM NEW.payer_entity_id
         OR lower(v_method_provider) <> lower(NEW.provider)
         OR v_method_type <> NEW.method_type OR v_method_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Payment method is inactive or does not match the attempt';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.obligation_id IS DISTINCT FROM OLD.obligation_id
     OR NEW.payer_entity_id IS DISTINCT FROM OLD.payer_entity_id
     OR NEW.payment_method_id IS DISTINCT FROM OLD.payment_method_id
     OR NEW.provider IS DISTINCT FROM OLD.provider
     OR NEW.method_type IS DISTINCT FROM OLD.method_type
     OR NEW.amount IS DISTINCT FROM OLD.amount
     OR NEW.currency IS DISTINCT FROM OLD.currency
     OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key THEN
    RAISE EXCEPTION 'Payment attempt identity and amount are immutable';
  END IF;
  IF OLD.status IN ('succeeded','failed','cancelled','expired') AND NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION 'Terminal payment attempt status cannot be changed';
  END IF;

  IF lower(OLD.provider) = 'mpesa' THEN
    IF OLD.provider_request_ref IS NOT NULL AND NEW.provider_request_ref IS DISTINCT FROM OLD.provider_request_ref THEN
      RAISE EXCEPTION 'M-Pesa provider request reference is immutable once bound';
    END IF;
    IF NEW.provider_request_ref IS NOT NULL AND NEW.status = 'created' THEN
      RAISE EXCEPTION 'M-Pesa provider reference cannot be bound before processing';
    END IF;
    IF NEW.status = 'pending' AND coalesce(btrim(NEW.provider_request_ref),'') = '' THEN
      RAISE EXCEPTION 'M-Pesa pending status requires a durable CheckoutRequestID';
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
      (OLD.status = 'created' AND NEW.status IN ('processing','cancelled','expired')) OR
      (OLD.status = 'processing' AND NEW.status IN ('pending','failed','cancelled','expired')) OR
      (OLD.status = 'pending' AND NEW.status IN ('succeeded','failed','cancelled','expired'))
    ) THEN
      RAISE EXCEPTION 'Invalid M-Pesa attempt status transition: % -> %', OLD.status, NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
    (OLD.status = 'created' AND NEW.status IN ('pending','processing','succeeded','failed','cancelled','expired')) OR
    (OLD.status = 'pending' AND NEW.status IN ('processing','succeeded','failed','cancelled','expired')) OR
    (OLD.status = 'processing' AND NEW.status IN ('succeeded','failed','cancelled','expired'))
  ) THEN
    RAISE EXCEPTION 'Invalid payment attempt status transition: % -> %', OLD.status, NEW.status;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.guard_provider_event()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Provider events are append-only';
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF lower(NEW.provider) = 'mpesa' AND NEW.signature_verified IS TRUE THEN
      RAISE EXCEPTION 'M-Pesa callback-secret authentication and STK Query are not cryptographic signature verification';
    END IF;
    IF NEW.verification_method IS NOT NULL
       AND current_setting('finance.recording_mpesa_evidence', true) IS DISTINCT FROM 'on'
       AND current_setting('finance.recording_mpesa_failure_evidence', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'Accepted M-Pesa verification evidence must be recorded through a Finance verification RPC';
    END IF;
    IF NEW.verification_method IS NOT NULL
       AND current_setting('finance.recording_mpesa_failure_evidence', true) = 'on' THEN
      IF lower(NEW.provider) <> 'mpesa'
         OR NEW.event_type <> 'stk_push_definitive_failure'
         OR NEW.verification_method <> 'callback_auth_plus_daraja_stk_query_definitive_failure'
         OR NEW.signature_verified IS NOT FALSE
         OR NEW.callback_authentication_succeeded IS NOT TRUE
         OR NEW.provider_query_succeeded IS NOT TRUE
         OR NEW.provider_verified_at IS NULL
         OR NEW.verified_provider_reference IS NOT NULL
         OR NEW.verified_amount IS NOT NULL
         OR NEW.verified_currency IS NOT NULL
         OR NEW.provider_query_result IS NULL
         OR jsonb_typeof(NEW.provider_query_result) <> 'object' THEN
        RAISE EXCEPTION 'M-Pesa definitive-failure evidence is incomplete or inconsistent';
      END IF;
    ELSIF NEW.verification_method IS NOT NULL AND (
      lower(NEW.provider) <> 'mpesa' OR NEW.signature_verified IS NOT FALSE
      OR NEW.callback_authentication_succeeded IS NOT TRUE
      OR NEW.provider_query_succeeded IS NOT TRUE
      OR NEW.provider_verified_at IS NULL
      OR coalesce(btrim(NEW.verified_provider_reference),'') = ''
      OR NEW.verified_amount IS NULL OR NEW.verified_amount <= 0
      OR NEW.verified_currency IS DISTINCT FROM upper(btrim(NEW.verified_currency))
      OR NEW.verified_currency !~ '^[A-Z]{3}$'
      OR NEW.provider_query_result IS NULL
      OR jsonb_typeof(NEW.provider_query_result) <> 'object'
    ) THEN
      RAISE EXCEPTION 'M-Pesa successful verification evidence is incomplete or inconsistent';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.provider IS DISTINCT FROM OLD.provider
     OR NEW.provider_event_id IS DISTINCT FROM OLD.provider_event_id
     OR NEW.payment_attempt_id IS DISTINCT FROM OLD.payment_attempt_id
     OR NEW.event_type IS DISTINCT FROM OLD.event_type
     OR NEW.signature_verified IS DISTINCT FROM OLD.signature_verified
     OR NEW.payload IS DISTINCT FROM OLD.payload
     OR NEW.received_at IS DISTINCT FROM OLD.received_at
     OR NEW.verification_method IS DISTINCT FROM OLD.verification_method
     OR NEW.callback_authentication_succeeded IS DISTINCT FROM OLD.callback_authentication_succeeded
     OR NEW.provider_query_succeeded IS DISTINCT FROM OLD.provider_query_succeeded
     OR NEW.provider_query_result IS DISTINCT FROM OLD.provider_query_result
     OR NEW.provider_verified_at IS DISTINCT FROM OLD.provider_verified_at
     OR NEW.verified_provider_reference IS DISTINCT FROM OLD.verified_provider_reference
     OR NEW.verified_amount IS DISTINCT FROM OLD.verified_amount
     OR NEW.verified_currency IS DISTINCT FROM OLD.verified_currency THEN
    RAISE EXCEPTION 'Provider event evidence is immutable';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.post_journal(p_journal_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_journal finance.journals%ROWTYPE;
  v_line_count bigint;
  v_debits numeric(30,4);
  v_credits numeric(30,4);
  v_period_id uuid;
BEGIN
  SELECT * INTO STRICT v_journal
    FROM finance.journals
   WHERE id = p_journal_id
   FOR UPDATE;

  IF v_journal.status = 'posted' THEN
    RETURN v_journal.id;
  END IF;

  -- Lock the period before changing journal state; closure takes the same row lock.
  SELECT ap.id
    INTO v_period_id
    FROM finance.accounting_periods AS ap
   WHERE ap.entity_id = v_journal.entity_id
     AND ap.status = 'open'
     AND v_journal.journal_date BETWEEN ap.start_date AND ap.end_date
   FOR UPDATE;

  IF v_period_id IS NULL THEN
    RAISE EXCEPTION 'No open accounting period covers this journal entity and date' USING ERRCODE = '55000';
  END IF;

  SELECT count(*), COALESCE(sum(debit_amount), 0), COALESCE(sum(credit_amount), 0)
    INTO v_line_count, v_debits, v_credits
    FROM finance.journal_lines
   WHERE journal_id = v_journal.id;

  IF v_line_count < 2 THEN
    RAISE EXCEPTION 'A journal requires at least two lines';
  END IF;
  IF v_debits <= 0 OR v_debits <> v_credits THEN
    RAISE EXCEPTION 'Journal is unbalanced: debits %, credits %', v_debits, v_credits;
  END IF;
  IF EXISTS (
    SELECT 1
      FROM finance.journal_lines l
      JOIN finance.ledger_accounts a ON a.id = l.account_id AND a.entity_id = l.entity_id
     WHERE l.journal_id = v_journal.id
       AND (a.is_active IS NOT TRUE OR (a.currency IS NOT NULL AND a.currency <> v_journal.currency))
  ) THEN
    RAISE EXCEPTION 'Journal contains an inactive or currency-incompatible ledger account';
  END IF;

  PERFORM set_config('finance.posting', 'on', true);
  UPDATE finance.journals
     SET status = 'posted', posted_at = clock_timestamp(), posted_by = current_user
   WHERE id = v_journal.id;
  RETURN v_journal.id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.recognize_platform_subscription_revenue(p_obligation_id uuid, p_amount numeric, p_idempotency_key text, p_recognition_date date DEFAULT CURRENT_DATE)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'core', 'auth'
AS $function$
DECLARE
  v_obligation finance.obligations%ROWTYPE;
  v_entity_id uuid;
  v_unearned_id uuid;
  v_revenue_id uuid;
  v_journal_id uuid;
  v_available numeric(20,4);
  v_key text := nullif(btrim(p_idempotency_key),'');
  v_description text;
BEGIN
  IF p_amount IS NULL OR p_amount<=0 OR v_key IS NULL OR length(v_key)>200 OR p_recognition_date IS NULL THEN
    RAISE EXCEPTION 'Positive recognition amount, idempotency key, and date are required' USING ERRCODE='22023';
  END IF;
  SELECT * INTO STRICT v_obligation FROM finance.obligations WHERE id=p_obligation_id FOR UPDATE;
  SELECT id INTO STRICT v_entity_id FROM core.entities
   WHERE is_active IS TRUE AND metadata->>'platform_entity'='true' AND metadata->>'purpose'='platform_administration';
  IF v_obligation.payee_entity_id IS DISTINCT FROM v_entity_id OR v_obligation.obligation_type<>'subscription'
     OR v_obligation.metadata->>'finance_charge_code'<>'subscription'
     OR v_obligation.metadata->>'tax_treatment' IS DISTINCT FROM 'not_applicable'
     OR v_obligation.currency<>'KES' THEN
    RAISE EXCEPTION 'Only approved KES platform subscription obligations can be recognized';
  END IF;
  v_description := 'Subscription revenue recognition obligation='||p_obligation_id::text||' amount='||p_amount::text;
  SELECT id INTO v_journal_id FROM finance.journals WHERE idempotency_key=v_key FOR UPDATE;
  IF v_journal_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM finance.journals WHERE id=v_journal_id AND status='posted' AND source_type='subscription_revenue_recognition' AND source_id=p_obligation_id AND entity_id=v_entity_id AND currency='KES' AND description=v_description) THEN
      RAISE EXCEPTION 'Recognition idempotency key already exists with different data';
    END IF;
    RETURN v_journal_id;
  END IF;
  SELECT id INTO STRICT v_unearned_id FROM finance.ledger_accounts WHERE entity_id=v_entity_id AND account_code='2200' AND account_type='liability' AND currency='KES' AND is_active IS TRUE;
  SELECT id INTO STRICT v_revenue_id FROM finance.ledger_accounts WHERE entity_id=v_entity_id AND account_code='4200' AND account_type='revenue' AND currency='KES' AND is_active IS TRUE;
  SELECT coalesce(sum(l.credit_amount-l.debit_amount),0) INTO v_available
    FROM finance.journal_lines l
    JOIN finance.journals j ON j.id=l.journal_id AND j.status='posted'
    LEFT JOIN finance.payments p ON j.source_type='payment' AND p.id=j.source_id
   WHERE l.account_id=v_unearned_id AND j.entity_id=v_entity_id
     AND ((j.source_type='payment' AND p.obligation_id=p_obligation_id)
       OR (j.source_type='subscription_revenue_recognition' AND j.source_id=p_obligation_id));
  IF p_amount>v_available THEN
    RAISE EXCEPTION 'Revenue recognition exceeds the posted unearned subscription balance';
  END IF;
  INSERT INTO finance.journals(entity_id,journal_date,currency,status,description,source_type,source_id,idempotency_key)
  VALUES(v_entity_id,p_recognition_date,'KES','draft',v_description,'subscription_revenue_recognition',p_obligation_id,v_key)
  RETURNING id INTO v_journal_id;
  INSERT INTO finance.journal_lines(journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
  VALUES
    (v_journal_id,v_entity_id,'KES',1,v_unearned_id,p_amount,0,'Earn subscription revenue as service is delivered'),
    (v_journal_id,v_entity_id,'KES',2,v_revenue_id,0,p_amount,'Recognized subscription revenue');
  PERFORM finance.post_journal(v_journal_id);
  RETURN v_journal_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.record_mpesa_bank_receipt(p_settlement_reference text, p_bank_reference text, p_bank_amount numeric, p_effective_date date DEFAULT CURRENT_DATE)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'core', 'auth'
AS $function$
DECLARE
  v_entity_id uuid;
  v_transit_id uuid;
  v_bank_id uuid;
  v_transfer_id uuid;
  v_journal_id uuid;
  v_ref text := nullif(btrim(p_settlement_reference),'');
  v_bank_ref text := nullif(btrim(p_bank_reference),'');
  v_net numeric(20,4);
  v_key text;
  v_description text;
BEGIN
  IF v_ref IS NULL OR length(v_ref)>160 OR v_bank_ref IS NULL OR length(v_bank_ref)>160
     OR p_bank_amount IS NULL OR p_bank_amount<=0 OR p_effective_date IS NULL THEN
    RAISE EXCEPTION 'Valid settlement reference, bank reference, amount, and date are required' USING ERRCODE='22023';
  END IF;
  v_key := 'mpesa-settlement-bank:'||v_ref;
  v_description := 'M-Pesa bank receipt settlement='||v_ref||' bank='||v_bank_ref||' amount='||p_bank_amount::text;
  PERFORM pg_advisory_xact_lock(hashtextextended('finance:mpesa-settlement-transfer:'||v_ref,0));
  SELECT id INTO STRICT v_entity_id FROM core.entities
   WHERE is_active IS TRUE AND metadata->>'platform_entity'='true' AND metadata->>'purpose'='platform_administration';
  SELECT id INTO STRICT v_transit_id FROM finance.ledger_accounts WHERE entity_id=v_entity_id AND account_code='1020' AND account_type='asset' AND currency='KES' AND is_active IS TRUE;
  SELECT id INTO STRICT v_bank_id FROM finance.ledger_accounts WHERE entity_id=v_entity_id AND account_code='1010' AND account_type='asset' AND currency='KES' AND is_active IS TRUE;
  SELECT id INTO STRICT v_transfer_id FROM finance.journals WHERE idempotency_key='mpesa-settlement-transfer:'||v_ref AND status='posted' AND entity_id=v_entity_id FOR SHARE;
  SELECT coalesce(sum(l.debit_amount-l.credit_amount),0) INTO v_net
    FROM finance.journal_lines l WHERE l.journal_id=v_transfer_id AND l.account_id=v_transit_id;
  IF v_net<=0 OR v_net IS DISTINCT FROM p_bank_amount THEN
    RAISE EXCEPTION 'Bank receipt amount must equal the posted M-Pesa settlement-in-transit amount';
  END IF;

  SELECT id INTO v_journal_id FROM finance.journals WHERE idempotency_key=v_key FOR UPDATE;
  IF v_journal_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM finance.journals WHERE id=v_journal_id AND status='posted' AND source_type='mpesa_bank_receipt' AND entity_id=v_entity_id AND currency='KES' AND description=v_description) THEN
      RAISE EXCEPTION 'Settlement already has a bank receipt with different details';
    END IF;
    RETURN v_journal_id;
  END IF;
  INSERT INTO finance.journals(entity_id,journal_date,currency,status,description,source_type,idempotency_key)
  VALUES(v_entity_id,p_effective_date,'KES','draft',v_description,'mpesa_bank_receipt',v_key)
  RETURNING id INTO v_journal_id;
  INSERT INTO finance.journal_lines(journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
  VALUES
    (v_journal_id,v_entity_id,'KES',1,v_bank_id,p_bank_amount,0,'Confirmed platform bank settlement receipt'),
    (v_journal_id,v_entity_id,'KES',2,v_transit_id,0,p_bank_amount,'Clear M-Pesa settlement in transit');
  PERFORM finance.post_journal(v_journal_id);
  RETURN v_journal_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.record_mpesa_definitive_failure(p_payment_attempt_id uuid, p_provider_event_id text, p_checkout_request_id text, p_failure_code text, p_failure_description text, p_callback_payload jsonb, p_provider_query_result jsonb, p_callback_authentication_succeeded boolean, p_provider_verified_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
  v_event finance.provider_events%ROWTYPE;
  v_event_id uuid;
  v_event_key text := nullif(btrim(p_provider_event_id), '');
  v_checkout text := nullif(btrim(p_checkout_request_id), '');
  v_failure_code text := nullif(btrim(p_failure_code), '');
  v_failure_description text := nullif(btrim(p_failure_description), '');
  v_callback jsonb;
  v_callback_checkout text;
  v_callback_code text;
  v_callback_description text;
  v_query_checkout text;
  v_query_response_code text;
  v_query_result_code text;
  v_query_description text;
  v_rows integer;
BEGIN
  IF v_event_key IS NULL OR length(v_event_key) > 250
     OR v_checkout IS NULL
     OR v_failure_code IS NULL
     OR v_failure_description IS NULL
     OR length(v_failure_description) > 5000
     OR p_callback_payload IS NULL OR jsonb_typeof(p_callback_payload) <> 'object'
     OR p_provider_query_result IS NULL OR jsonb_typeof(p_provider_query_result) <> 'object'
     OR p_callback_authentication_succeeded IS DISTINCT FROM TRUE
     OR p_provider_verified_at IS NULL THEN
    RAISE EXCEPTION 'Required authenticated callback and independent provider-query evidence is missing or invalid' USING ERRCODE = '22023';
  END IF;

  v_callback := coalesce(p_callback_payload #> '{Body,stkCallback}', p_callback_payload->'stkCallback');
  v_callback_checkout := coalesce(v_callback->>'CheckoutRequestID', v_callback->>'checkoutRequestID');
  v_callback_code := coalesce(v_callback->>'ResultCode', v_callback->>'resultCode');
  v_callback_description := coalesce(v_callback->>'ResultDesc', v_callback->>'resultDesc');
  v_query_checkout := coalesce(p_provider_query_result->>'CheckoutRequestID', p_provider_query_result->>'checkoutRequestID');
  v_query_response_code := coalesce(p_provider_query_result->>'ResponseCode', p_provider_query_result->>'responseCode');
  v_query_result_code := coalesce(p_provider_query_result->>'ResultCode', p_provider_query_result->>'resultCode');
  v_query_description := coalesce(p_provider_query_result->>'ResultDesc', p_provider_query_result->>'resultDesc');

  IF v_callback IS NULL OR jsonb_typeof(v_callback) <> 'object'
     OR v_callback_checkout IS DISTINCT FROM v_checkout
     OR v_query_checkout IS DISTINCT FROM v_checkout
     OR v_query_response_code IS DISTINCT FROM '0'
     OR v_query_result_code IS DISTINCT FROM v_failure_code
     OR v_callback_code IS DISTINCT FROM v_failure_code
     OR v_query_description IS DISTINCT FROM v_failure_description
     OR v_callback_description IS DISTINCT FROM v_failure_description
     OR v_failure_code NOT IN ('1', '1032', '2001') THEN
    RAISE EXCEPTION 'Provider query does not establish a matching, allowlisted definitive failure for this CheckoutRequestID';
  END IF;

  -- The allowlist intentionally excludes 1037 (Daraja timeout) and all unknown outcomes.
  PERFORM pg_advisory_xact_lock(hashtextextended('finance:mpesa:event:' || v_event_key, 0));
  SELECT * INTO STRICT v_attempt
    FROM finance.payment_attempts
   WHERE id = p_payment_attempt_id
   FOR UPDATE;

  IF lower(v_attempt.provider) <> 'mpesa' THEN
    RAISE EXCEPTION 'Attempt is not an M-Pesa attempt';
  END IF;
  IF v_attempt.provider_request_ref IS DISTINCT FROM v_checkout THEN
    RAISE EXCEPTION 'CheckoutRequestID does not exactly match the value stored on the attempt';
  END IF;
  IF v_attempt.status = 'succeeded' THEN
    RAISE EXCEPTION 'A succeeded attempt cannot be transitioned to failed';
  END IF;

  SELECT * INTO v_event
    FROM finance.provider_events
   WHERE provider = 'mpesa' AND provider_event_id = v_event_key
   FOR UPDATE;
  IF FOUND THEN
    IF v_event.payment_attempt_id IS DISTINCT FROM v_attempt.id
       OR v_event.event_type IS DISTINCT FROM 'stk_push_definitive_failure'
       OR v_event.signature_verified IS DISTINCT FROM FALSE
       OR v_event.verification_method IS DISTINCT FROM 'callback_auth_plus_daraja_stk_query_definitive_failure'
       OR v_event.callback_authentication_succeeded IS DISTINCT FROM TRUE
       OR v_event.provider_query_succeeded IS DISTINCT FROM TRUE
       OR v_event.provider_query_result IS DISTINCT FROM p_provider_query_result
       OR v_event.provider_verified_at IS DISTINCT FROM p_provider_verified_at
       OR v_event.payload IS DISTINCT FROM p_callback_payload
       OR v_event.verified_provider_reference IS NOT NULL
       OR v_event.verified_amount IS NOT NULL
       OR v_event.verified_currency IS NOT NULL THEN
      RAISE EXCEPTION 'Provider event ID already exists with conflicting evidence' USING ERRCODE = '23505';
    END IF;
    v_event_id := v_event.id;
  ELSE
    IF EXISTS (
      SELECT 1 FROM finance.provider_events pe
       WHERE pe.provider = 'mpesa'
         AND pe.payment_attempt_id = v_attempt.id
         AND pe.event_type = 'stk_push_definitive_failure'
    ) THEN
      RAISE EXCEPTION 'Attempt already has different definitive-failure evidence' USING ERRCODE = '23505';
    END IF;
  END IF;

  IF v_attempt.status = 'failed' THEN
    IF v_event_id IS NOT NULL
       AND v_attempt.failure_code IS NOT DISTINCT FROM v_failure_code
       AND v_attempt.failure_message IS NOT DISTINCT FROM v_failure_description THEN
      RETURN v_event_id;
    END IF;
    RAISE EXCEPTION 'Failed attempt has different or missing definitive-failure evidence' USING ERRCODE = '23505';
  END IF;
  IF v_attempt.status <> 'pending' THEN
    RAISE EXCEPTION 'Only a pending M-Pesa attempt can be marked failed from verified callback evidence';
  END IF;

  IF v_event_id IS NULL THEN
    PERFORM set_config('finance.recording_mpesa_failure_evidence', 'on', true);
    INSERT INTO finance.provider_events (
      provider, provider_event_id, payment_attempt_id, event_type, signature_verified,
      payload, verification_method, callback_authentication_succeeded,
      provider_query_succeeded, provider_query_result, provider_verified_at,
      verified_provider_reference, verified_amount, verified_currency
    ) VALUES (
      'mpesa', v_event_key, v_attempt.id, 'stk_push_definitive_failure', false,
      p_callback_payload, 'callback_auth_plus_daraja_stk_query_definitive_failure', true,
      true, p_provider_query_result, p_provider_verified_at,
      NULL, NULL, NULL
    ) RETURNING id INTO v_event_id;
    PERFORM set_config('finance.recording_mpesa_failure_evidence', 'off', true);
  END IF;

  UPDATE finance.payment_attempts
     SET status = 'failed',
         failure_code = v_failure_code,
         failure_message = v_failure_description,
         completed_at = clock_timestamp(),
         updated_at = clock_timestamp()
   WHERE id = v_attempt.id AND status = 'pending';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'Attempt state changed while recording definitive failure';
  END IF;
  RETURN v_event_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.record_mpesa_settlement_transfer(p_settlement_reference text, p_gross_amount numeric, p_provider_fee numeric DEFAULT 0, p_effective_date date DEFAULT CURRENT_DATE)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'core', 'auth'
AS $function$
DECLARE
  v_entity_id uuid;
  v_clearing_id uuid;
  v_transit_id uuid;
  v_fee_id uuid;
  v_journal_id uuid;
  v_ref text := nullif(btrim(p_settlement_reference),'');
  v_fee numeric(20,4) := coalesce(p_provider_fee,0);
  v_net numeric(20,4);
  v_key text;
  v_description text;
BEGIN
  IF v_ref IS NULL OR length(v_ref)>160 OR p_gross_amount IS NULL OR p_gross_amount<=0
     OR v_fee<0 OR v_fee>=p_gross_amount OR p_effective_date IS NULL THEN
    RAISE EXCEPTION 'Valid settlement reference, gross amount, fee, and date are required' USING ERRCODE='22023';
  END IF;
  v_net := p_gross_amount-v_fee;
  v_key := 'mpesa-settlement-transfer:'||v_ref;
  v_description := 'M-Pesa settlement transfer ref='||v_ref||' gross='||p_gross_amount::text||' fee='||v_fee::text;
  PERFORM pg_advisory_xact_lock(hashtextextended('finance:'||v_key,0));
  SELECT id INTO STRICT v_entity_id FROM core.entities
   WHERE is_active IS TRUE AND metadata->>'platform_entity'='true' AND metadata->>'purpose'='platform_administration';
  SELECT id INTO STRICT v_clearing_id FROM finance.ledger_accounts WHERE entity_id=v_entity_id AND account_code='1000' AND account_type='asset' AND currency='KES' AND is_active IS TRUE;
  SELECT id INTO STRICT v_transit_id FROM finance.ledger_accounts WHERE entity_id=v_entity_id AND account_code='1020' AND account_type='asset' AND currency='KES' AND is_active IS TRUE;
  SELECT id INTO STRICT v_fee_id FROM finance.ledger_accounts WHERE entity_id=v_entity_id AND account_code='5100' AND account_type='expense' AND currency='KES' AND is_active IS TRUE;

  SELECT id INTO v_journal_id FROM finance.journals WHERE idempotency_key=v_key FOR UPDATE;
  IF v_journal_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM finance.journals WHERE id=v_journal_id AND status='posted' AND source_type='mpesa_settlement_transfer' AND entity_id=v_entity_id AND currency='KES' AND description=v_description) THEN
      RAISE EXCEPTION 'Settlement reference already exists with different transfer data';
    END IF;
    RETURN v_journal_id;
  END IF;

  INSERT INTO finance.journals(entity_id,journal_date,currency,status,description,source_type,idempotency_key)
  VALUES(v_entity_id,p_effective_date,'KES','draft',v_description,'mpesa_settlement_transfer',v_key)
  RETURNING id INTO v_journal_id;
  INSERT INTO finance.journal_lines(journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
  VALUES
    (v_journal_id,v_entity_id,'KES',1,v_transit_id,v_net,0,'M-Pesa settlement in transit');
  IF v_fee>0 THEN
    INSERT INTO finance.journal_lines(journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    VALUES(v_journal_id,v_entity_id,'KES',2,v_fee_id,v_fee,0,'Confirmed M-Pesa processing fee');
    INSERT INTO finance.journal_lines(journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    VALUES(v_journal_id,v_entity_id,'KES',3,v_clearing_id,0,p_gross_amount,'Gross M-Pesa collection transferred');
  ELSE
    INSERT INTO finance.journal_lines(journal_id,entity_id,currency,line_number,account_id,debit_amount,credit_amount,description)
    VALUES(v_journal_id,v_entity_id,'KES',2,v_clearing_id,0,p_gross_amount,'Gross M-Pesa collection transferred');
  END IF;
  PERFORM finance.post_journal(v_journal_id);
  RETURN v_journal_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.record_mpesa_verification_evidence(p_payment_attempt_id uuid, p_provider_event_id text, p_verified_provider_reference text, p_verified_amount numeric, p_verified_currency text, p_callback_payload jsonb, p_provider_query_result jsonb, p_provider_verified_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'auth'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
  v_event finance.provider_events%ROWTYPE;
  v_event_id uuid;
  v_match_count integer;
  v_event_key text := nullif(btrim(p_provider_event_id),'');
  v_reference text := nullif(btrim(p_verified_provider_reference),'');
  v_currency text := upper(btrim(p_verified_currency));
  v_stk_callback jsonb;
  v_callback_items jsonb;
  v_callback_reference text;
  v_callback_amount numeric;
  v_callback_checkout_id text;
  v_callback_result text;
  v_query_result text;
  v_query_checkout_id text;
BEGIN
  IF v_event_key IS NULL OR length(v_event_key) > 250
     OR v_reference IS NULL OR p_verified_amount IS NULL
     OR p_callback_payload IS NULL OR jsonb_typeof(p_callback_payload) <> 'object'
     OR p_provider_query_result IS NULL OR jsonb_typeof(p_provider_query_result) <> 'object'
     OR p_provider_verified_at IS NULL THEN
    RAISE EXCEPTION 'Required callback and independent provider-query evidence is missing or invalid' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('finance:mpesa:event:'||v_event_key,0));
  PERFORM pg_advisory_xact_lock(hashtextextended('finance:mpesa:receipt:'||v_reference,0));

  SELECT * INTO STRICT v_attempt
    FROM finance.payment_attempts
   WHERE id = p_payment_attempt_id
   FOR UPDATE;
  IF lower(v_attempt.provider) <> 'mpesa'
     OR p_verified_amount IS DISTINCT FROM v_attempt.amount
     OR v_currency IS DISTINCT FROM v_attempt.currency THEN
    RAISE EXCEPTION 'M-Pesa attempt, amount, or currency does not match the evidence';
  END IF;

  v_stk_callback := coalesce(p_callback_payload #> '{Body,stkCallback}', p_callback_payload->'stkCallback');
  v_callback_result := coalesce(v_stk_callback->>'ResultCode', v_stk_callback->>'resultCode');
  v_callback_checkout_id := coalesce(v_stk_callback->>'CheckoutRequestID', v_stk_callback->>'checkoutRequestID');
  v_callback_items := coalesce(v_stk_callback #> '{CallbackMetadata,Item}', v_stk_callback #> '{callbackMetadata,item}', '[]'::jsonb);
  IF jsonb_typeof(v_callback_items) <> 'array' THEN
    RAISE EXCEPTION 'Daraja callback metadata items are missing';
  END IF;
  SELECT item->>'Value' INTO v_callback_reference
    FROM jsonb_array_elements(v_callback_items) item
   WHERE coalesce(item->>'Name',item->>'name') IN ('MpesaReceiptNumber','mpesaReceiptNumber')
   LIMIT 1;
  SELECT (item->>'Value')::numeric INTO v_callback_amount
    FROM jsonb_array_elements(v_callback_items) item
   WHERE coalesce(item->>'Name',item->>'name') IN ('Amount','amount')
   LIMIT 1;
  v_query_result := coalesce(p_provider_query_result->>'ResultCode',p_provider_query_result->>'resultCode');
  v_query_checkout_id := coalesce(p_provider_query_result->>'CheckoutRequestID',p_provider_query_result->>'checkoutRequestID');

  IF coalesce(btrim(v_attempt.provider_request_ref),'') = ''
     OR v_callback_result IS DISTINCT FROM '0'
     OR v_callback_checkout_id IS DISTINCT FROM v_attempt.provider_request_ref
     OR v_callback_reference IS DISTINCT FROM v_reference
     OR v_callback_amount IS DISTINCT FROM p_verified_amount THEN
    RAISE EXCEPTION 'Daraja callback receipt, amount, result, or CheckoutRequestID does not match the attempt';
  END IF;
  IF v_query_result IS DISTINCT FROM '0'
     OR coalesce(btrim(v_query_checkout_id),'') = ''
     OR v_query_checkout_id IS DISTINCT FROM v_attempt.provider_request_ref THEN
    RAISE EXCEPTION 'Independent Daraja STK Query does not confirm this checkout as successful';
  END IF;

  SELECT count(*) INTO v_match_count
    FROM finance.provider_events
   WHERE provider = 'mpesa'
     AND (provider_event_id = v_event_key OR verified_provider_reference = v_reference);
  IF v_match_count > 1 THEN
    RAISE EXCEPTION 'Provider event id and receipt reference resolve to conflicting evidence' USING ERRCODE = '23505';
  ELSIF v_match_count = 1 THEN
    SELECT * INTO STRICT v_event
      FROM finance.provider_events
     WHERE provider = 'mpesa'
       AND (provider_event_id = v_event_key OR verified_provider_reference = v_reference)
     FOR UPDATE;
    IF v_event.payment_attempt_id IS NOT DISTINCT FROM v_attempt.id
       AND v_event.event_type = 'stk_push_callback'
       AND v_event.signature_verified IS FALSE
       AND v_event.payload = p_callback_payload
       AND v_event.verification_method = 'callback_secret_plus_daraja_stk_query'
       AND v_event.callback_authentication_succeeded IS TRUE
       AND v_event.provider_query_succeeded IS TRUE
       AND v_event.provider_query_result = p_provider_query_result
       AND v_event.verified_provider_reference = v_reference
       AND v_event.verified_amount IS NOT DISTINCT FROM p_verified_amount
       AND v_event.verified_currency IS NOT DISTINCT FROM v_currency THEN
      RETURN v_event.id;
    END IF;
    RAISE EXCEPTION 'Provider event id or receipt reference already exists with conflicting security evidence' USING ERRCODE = '23505';
  END IF;

  IF v_attempt.status NOT IN ('pending','processing') THEN
    RAISE EXCEPTION 'New provider evidence is not accepted after attempt finalization or terminalization';
  END IF;

  PERFORM set_config('finance.recording_mpesa_evidence','on',true);
  INSERT INTO finance.provider_events (
    provider, provider_event_id, payment_attempt_id, event_type, signature_verified,
    payload, verification_method, callback_authentication_succeeded,
    provider_query_succeeded, provider_query_result, provider_verified_at,
    verified_provider_reference, verified_amount, verified_currency
  ) VALUES (
    'mpesa', v_event_key, v_attempt.id, 'stk_push_callback', false,
    p_callback_payload, 'callback_secret_plus_daraja_stk_query', true,
    true, p_provider_query_result, p_provider_verified_at,
    v_reference, p_verified_amount, v_currency
  ) RETURNING id INTO v_event_id;
  RETURN v_event_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.record_verified_payment(p_payment_attempt_id uuid, p_provider_event_id uuid, p_provider_reference text, p_confirmed_amount numeric, p_confirmed_currency text, p_verification_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
    DECLARE v_charge_code text;
    BEGIN
      SELECT o.metadata->>'finance_charge_code' INTO v_charge_code
        FROM finance.payment_attempts a JOIN finance.obligations o ON o.id = a.obligation_id
       WHERE a.id = p_payment_attempt_id;
      IF v_charge_code = 'contact_unlock' THEN
        RAISE EXCEPTION 'Contact-unlock payments must be recorded by finance.finalize_mpesa_payment';
      END IF;
      RETURN finance.record_verified_payment_internal(
        p_payment_attempt_id, p_provider_event_id, p_provider_reference,
        p_confirmed_amount, p_confirmed_currency, p_verification_metadata
      );
    END;
    $function$;

CREATE OR REPLACE FUNCTION finance.record_verified_payment_internal(p_payment_attempt_id uuid, p_provider_event_id uuid, p_provider_reference text, p_confirmed_amount numeric, p_confirmed_currency text, p_verification_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
  v_obligation finance.obligations%ROWTYPE;
  v_event finance.provider_events%ROWTYPE;
  v_existing uuid;
  v_receipt_payment uuid;
  v_prior numeric(20,4);
  v_payment_id uuid;
  v_reference text := nullif(btrim(p_provider_reference),'');
  v_currency text := upper(btrim(p_confirmed_currency));
BEGIN
  SELECT * INTO STRICT v_event FROM finance.provider_events WHERE id = p_provider_event_id FOR UPDATE;
  SELECT * INTO STRICT v_attempt FROM finance.payment_attempts WHERE id = p_payment_attempt_id FOR UPDATE;
  IF v_event.payment_attempt_id IS DISTINCT FROM v_attempt.id
     OR lower(v_attempt.provider) <> lower(v_event.provider) THEN
    RAISE EXCEPTION 'Provider event does not match the payment attempt';
  END IF;
  IF lower(v_attempt.provider) = 'mpesa' THEN
    IF v_event.signature_verified IS NOT FALSE
       OR v_event.verification_method IS DISTINCT FROM 'callback_secret_plus_daraja_stk_query'
       OR v_event.callback_authentication_succeeded IS NOT TRUE
       OR v_event.provider_query_succeeded IS NOT TRUE
       OR v_event.provider_verified_at IS NULL
       OR v_event.verified_provider_reference IS DISTINCT FROM v_reference
       OR v_event.verified_amount IS DISTINCT FROM p_confirmed_amount
       OR v_event.verified_currency IS DISTINCT FROM v_currency THEN
      RAISE EXCEPTION 'Accepted M-Pesa callback authentication and independent provider-query evidence is required';
    END IF;
  ELSIF v_event.signature_verified IS NOT TRUE THEN
    RAISE EXCEPTION 'A signature-verified provider event is required for this non-M-Pesa provider';
  END IF;
  IF v_reference IS NULL THEN
    RAISE EXCEPTION 'Verified provider reference is required';
  END IF;
  IF p_confirmed_amount IS DISTINCT FROM v_attempt.amount OR v_currency IS DISTINCT FROM v_attempt.currency THEN
    RAISE EXCEPTION 'Verified provider amount or currency does not match the attempt';
  END IF;

  SELECT id INTO v_existing FROM finance.payments WHERE payment_attempt_id = v_attempt.id;
  IF v_existing IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM finance.payments p WHERE p.id=v_existing AND lower(p.provider)=lower(v_attempt.provider)
                   AND p.provider_reference=v_reference AND p.amount=p_confirmed_amount AND p.currency=v_currency) THEN
      RAISE EXCEPTION 'Attempt already has a payment with different provider data';
    END IF;
    UPDATE finance.provider_events SET processed_at=coalesce(processed_at,clock_timestamp()), processing_error=NULL WHERE id=v_event.id;
    RETURN v_existing;
  END IF;
  IF lower(v_attempt.provider) = 'mpesa' AND v_attempt.status <> 'pending' THEN
    RAISE EXCEPTION 'M-Pesa payment finalization requires a pending attempt with a bound CheckoutRequestID';
  ELSIF lower(v_attempt.provider) <> 'mpesa' AND v_attempt.status NOT IN ('created','pending','processing') THEN
    RAISE EXCEPTION 'Attempt status is not eligible for payment verification';
  END IF;
  SELECT id INTO v_receipt_payment FROM finance.payments
   WHERE lower(provider)=lower(v_attempt.provider) AND provider_reference=v_reference;
  IF v_receipt_payment IS NOT NULL THEN
    RAISE EXCEPTION 'Provider receipt has already been applied to another Finance payment' USING ERRCODE='23505';
  END IF;

  SELECT * INTO STRICT v_obligation FROM finance.obligations WHERE id=v_attempt.obligation_id FOR UPDATE;
  IF v_obligation.status NOT IN ('open','partially_settled') THEN
    RAISE EXCEPTION 'Obligation is not open for payment';
  END IF;
  SELECT coalesce(sum(p.amount),0) INTO v_prior FROM finance.payments p WHERE p.obligation_id=v_obligation.id;
  IF v_attempt.amount > v_obligation.amount-v_prior THEN
    RAISE EXCEPTION 'Verified payment would exceed the obligation amount';
  END IF;
  INSERT INTO finance.payments (
    obligation_id,payment_attempt_id,payer_entity_id,payee_entity_id,payment_method_id,
    provider,provider_reference,amount,currency,verification_metadata
  ) VALUES (
    v_obligation.id,v_attempt.id,v_obligation.payer_entity_id,v_obligation.payee_entity_id,
    v_attempt.payment_method_id,v_attempt.provider,v_reference,v_attempt.amount,v_attempt.currency,
    coalesce(p_verification_metadata,'{}'::jsonb)
  ) RETURNING id INTO v_payment_id;
  UPDATE finance.payment_attempts SET status='succeeded',completed_at=clock_timestamp(),updated_at=clock_timestamp() WHERE id=v_attempt.id;
  UPDATE finance.provider_events SET processed_at=clock_timestamp(),processing_error=NULL WHERE id=v_event.id;
  RETURN v_payment_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.reject_immutable_finance_row()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
BEGIN
  RAISE EXCEPTION '% rows are append-only', TG_TABLE_NAME;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.request_mpesa_attempt(p_obligation_id uuid, p_amount numeric, p_phone text, p_idempotency_key text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance', 'core', 'auth', 'marketplace'
AS $function$
DECLARE
  v_obligation finance.obligations%ROWTYPE;
  v_platform_entity_id uuid;
  v_profile_id uuid;
  v_active_entity uuid;
  v_attempt finance.payment_attempts%ROWTYPE;
  v_existing finance.payment_attempts%ROWTYPE;
  v_paid numeric(20,4);
  v_payment_count bigint;
  v_id uuid;
  v_charge_code text;
  v_contact_unlock_listing_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authenticated payer entity membership is required' USING ERRCODE = '42501';
  END IF;
  v_profile_id := core.current_profile_id();
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Authenticated profile is not mapped to a profile record' USING ERRCODE = '42501';
  END IF;
  IF coalesce(btrim(p_idempotency_key),'') = '' OR length(p_idempotency_key) > 200
     OR coalesce(btrim(p_phone),'') = '' OR length(btrim(p_phone)) > 40
     OR p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Valid amount, phone, and idempotency key are required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO STRICT v_platform_entity_id
    FROM core.entities
   WHERE is_active IS TRUE
     AND metadata->>'platform_entity' = 'true'
     AND metadata->>'purpose' = 'platform_administration';

  SELECT * INTO STRICT v_obligation
    FROM finance.obligations
   WHERE id = p_obligation_id
   FOR UPDATE;

  IF NOT EXISTS (
    SELECT 1 FROM core.entity_members em
     WHERE em.entity_id = v_obligation.payer_entity_id
       AND em.profile_id = v_profile_id
       AND em.is_active IS TRUE
       AND em.membership_status = 'active'
       AND em.can_manage IS TRUE
  ) THEN
    RAISE EXCEPTION 'Caller cannot manage the obligation payer entity' USING ERRCODE = '42501';
  END IF;
  IF v_obligation.payee_entity_id <> v_platform_entity_id THEN
    RAISE EXCEPTION 'Central M-Pesa collection is restricted to platform-owned obligations';
  END IF;
  IF v_obligation.currency <> 'KES' THEN
    RAISE EXCEPTION 'Central M-Pesa collection is configured for KES obligations only';
  END IF;
  IF v_obligation.legacy_order_id IS NOT NULL THEN
    RAISE EXCEPTION 'Central platform collection does not accept legacy Commerce order obligations';
  END IF;
  IF v_obligation.status NOT IN ('open','partially_settled') THEN
    RAISE EXCEPTION 'Obligation is not open for payment';
  END IF;
  v_charge_code := v_obligation.metadata->>'finance_charge_code';
  IF NOT (
    (v_obligation.obligation_type = 'subscription' AND v_charge_code = 'subscription')
    OR (v_obligation.obligation_type = 'fee' AND v_charge_code IN ('contact_unlock','other_platform_charge'))
  ) THEN
    RAISE EXCEPTION 'Obligation is missing an approved platform charge classification';
  END IF;
  IF v_obligation.metadata->>'tax_treatment' IS DISTINCT FROM 'not_applicable' THEN
    RAISE EXCEPTION 'Payment initiation is blocked until an approved tax treatment is recorded';
  END IF;

  IF v_obligation.obligation_type = 'fee' AND v_charge_code = 'contact_unlock' THEN
    v_active_entity := core.get_active_entity();
    IF v_active_entity IS DISTINCT FROM v_obligation.payer_entity_id
       OR NOT EXISTS (
         SELECT 1 FROM core.entities e
         WHERE e.id = v_obligation.payer_entity_id
           AND e.is_active IS TRUE
           AND e.entity_type = 'individual_pro'
           AND e.owner_id = v_profile_id
       ) THEN
      RAISE EXCEPTION 'Contact-unlock payer must be the authenticated buyer''s active individual entity' USING ERRCODE = '42501';
    END IF;
    SELECT cu.listing_id INTO v_contact_unlock_listing_id
      FROM marketplace.contact_unlocks cu
     WHERE cu.finance_obligation_id = v_obligation.id
       AND cu.entity_id = v_obligation.payer_entity_id
       AND cu.amount = v_obligation.amount
       AND cu.currency = v_obligation.currency
       AND cu.payment_status = 'pending'
       AND cu.unlocked IS FALSE
       AND cu.id::text = v_obligation.metadata->>'contact_unlock_id'
     FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'A matching pending contact unlock is required';
    END IF;
    PERFORM marketplace.assert_contact_unlock_listing_eligible(v_contact_unlock_listing_id);
  END IF;

  SELECT count(*), coalesce(sum(p.amount),0)
    INTO v_payment_count, v_paid
    FROM finance.payments p
   WHERE p.obligation_id = v_obligation.id;

  IF v_obligation.obligation_type = 'fee' AND v_charge_code = 'contact_unlock' THEN
    IF v_obligation.status <> 'open' OR v_payment_count <> 0 THEN
      RAISE EXCEPTION 'Contact unlock requires an unpaid, open obligation with no recorded payments';
    END IF;
    IF p_amount IS DISTINCT FROM v_obligation.amount THEN
      RAISE EXCEPTION 'Contact unlock payment must equal the full obligation amount; partial payments are not accepted';
    END IF;
  ELSIF p_amount > v_obligation.amount - v_paid THEN
    RAISE EXCEPTION 'Attempt exceeds the remaining obligation balance';
  END IF;

  SELECT * INTO v_existing
    FROM finance.payment_attempts
   WHERE idempotency_key = btrim(p_idempotency_key)
   FOR UPDATE;
  IF FOUND THEN
    IF v_existing.obligation_id = v_obligation.id
       AND lower(v_existing.provider) = 'mpesa'
       AND v_existing.amount = p_amount
       AND v_existing.currency = v_obligation.currency
       AND v_existing.metadata->>'phone' = btrim(p_phone) THEN
      RETURN v_existing.id;
    END IF;
    RAISE EXCEPTION 'Idempotency key was already used for different attempt data' USING ERRCODE = '23505';
  END IF;

  SELECT * INTO v_attempt
    FROM finance.payment_attempts
   WHERE obligation_id = v_obligation.id
     AND lower(provider) = 'mpesa'
     AND status IN ('created','pending','processing')
   ORDER BY created_at DESC, id
   LIMIT 1
   FOR UPDATE;
  IF FOUND THEN
    IF v_attempt.amount = p_amount
       AND v_attempt.currency = v_obligation.currency
       AND v_attempt.metadata->>'phone' = btrim(p_phone) THEN
      RETURN v_attempt.id;
    END IF;
    RAISE EXCEPTION 'An active M-Pesa attempt already exists for this obligation with different payment details' USING ERRCODE = '23505';
  END IF;

  INSERT INTO finance.payment_attempts (
    obligation_id, payer_entity_id, payment_method_id, provider, method_type,
    amount, currency, status, idempotency_key, metadata
  ) VALUES (
    v_obligation.id, v_obligation.payer_entity_id, NULL, 'mpesa', 'mpesa',
    p_amount, v_obligation.currency, 'created', btrim(p_idempotency_key),
    jsonb_build_object('phone', btrim(p_phone), 'finance_charge_code', v_charge_code)
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.reverse_journal(p_journal_id uuid, p_idempotency_key text, p_description text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_original finance.journals%ROWTYPE;
  v_reversal_id uuid;
BEGIN
  IF coalesce(btrim(p_idempotency_key), '') = '' THEN
    RAISE EXCEPTION 'A non-empty reversal idempotency key is required';
  END IF;
  SELECT * INTO STRICT v_original
    FROM finance.journals WHERE id = p_journal_id FOR UPDATE;
  IF v_original.status <> 'posted' THEN
    RAISE EXCEPTION 'Only a posted journal may be reversed';
  END IF;

  SELECT id INTO v_reversal_id
    FROM finance.journals WHERE reversal_of_journal_id = v_original.id;
  IF v_reversal_id IS NOT NULL THEN
    RETURN v_reversal_id;
  END IF;

  INSERT INTO finance.journals (
    entity_id, journal_date, currency, description, source_type, source_id,
    idempotency_key, reversal_of_journal_id
  ) VALUES (
    v_original.entity_id, CURRENT_DATE, v_original.currency,
    coalesce(nullif(btrim(p_description), ''), 'Reversal of journal ' || v_original.id::text),
    'journal_reversal', v_original.id, p_idempotency_key, v_original.id
  ) RETURNING id INTO v_reversal_id;

  INSERT INTO finance.journal_lines (
    journal_id, entity_id, currency, line_number, account_id,
    debit_amount, credit_amount, description
  )
  SELECT v_reversal_id, l.entity_id, l.currency, l.line_number, l.account_id,
         l.credit_amount, l.debit_amount, l.description
    FROM finance.journal_lines l
   WHERE l.journal_id = v_original.id
   ORDER BY l.line_number;

  PERFORM finance.post_journal(v_reversal_id);
  RETURN v_reversal_id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.set_payment_attempt_provider_request_ref(p_payment_attempt_id uuid, p_provider_request_ref text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_attempt finance.payment_attempts%ROWTYPE;
BEGIN
  IF coalesce(btrim(p_provider_request_ref), '') = '' THEN
    RAISE EXCEPTION 'Provider request reference is required';
  END IF;
  SELECT * INTO STRICT v_attempt FROM finance.payment_attempts WHERE id = p_payment_attempt_id FOR UPDATE;
  IF v_attempt.provider_request_ref IS NOT NULL THEN
    IF v_attempt.provider_request_ref = btrim(p_provider_request_ref) THEN RETURN v_attempt.id; END IF;
    RAISE EXCEPTION 'Payment attempt already has a different provider request reference';
  END IF;
  IF v_attempt.status NOT IN ('created','pending','processing') THEN
    RAISE EXCEPTION 'Cannot attach a provider reference to a terminal attempt';
  END IF;
  UPDATE finance.payment_attempts
     SET provider_request_ref = btrim(p_provider_request_ref), updated_at = clock_timestamp()
   WHERE id = v_attempt.id;
  RETURN v_attempt.id;
END;
$function$;

CREATE OR REPLACE FUNCTION finance.settle_payment(p_payment_id uuid, p_amount numeric, p_idempotency_key text, p_journal_id uuid, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'finance'
AS $function$
DECLARE
  v_payment finance.payments%ROWTYPE;
  v_obligation finance.obligations%ROWTYPE;
  v_journal finance.journals%ROWTYPE;
  v_existing finance.obligation_settlements%ROWTYPE;
  v_payment_settled numeric(20,4);
  v_obligation_settled numeric(20,4);
  v_id uuid;
BEGIN
  SELECT * INTO v_existing FROM finance.obligation_settlements WHERE idempotency_key = btrim(p_idempotency_key);
  IF FOUND THEN
    IF v_existing.payment_id = p_payment_id AND v_existing.amount = p_amount AND v_existing.journal_id = p_journal_id THEN
      RETURN v_existing.id;
    END IF;
    RAISE EXCEPTION 'Idempotency key already exists with different settlement data';
  END IF;
  IF coalesce(btrim(p_idempotency_key), '') = '' OR p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Positive settlement amount and idempotency key are required';
  END IF;
  SELECT * INTO STRICT v_payment FROM finance.payments WHERE id = p_payment_id FOR UPDATE;
  SELECT * INTO STRICT v_obligation FROM finance.obligations WHERE id = v_payment.obligation_id FOR UPDATE;
  SELECT * INTO STRICT v_journal FROM finance.journals WHERE id = p_journal_id FOR SHARE;
  IF v_journal.status <> 'posted' OR v_journal.entity_id <> v_payment.payee_entity_id
     OR v_journal.currency <> v_payment.currency OR v_journal.source_type <> 'payment'
     OR v_journal.source_id <> v_payment.id THEN
    RAISE EXCEPTION 'Settlement requires a posted payee journal sourced to this payment in the same currency';
  END IF;
  IF v_obligation.status NOT IN ('open','partially_settled') THEN
    RAISE EXCEPTION 'Obligation is not available for settlement';
  END IF;
  SELECT coalesce(sum(s.amount), 0) INTO v_payment_settled
    FROM finance.obligation_settlements s WHERE s.payment_id = v_payment.id;
  SELECT coalesce(sum(s.amount), 0) INTO v_obligation_settled
    FROM finance.obligation_settlements s WHERE s.obligation_id = v_obligation.id;
  IF p_amount > v_payment.amount - v_payment_settled
     OR p_amount > v_obligation.amount - v_obligation_settled THEN
    RAISE EXCEPTION 'Settlement exceeds remaining payment or obligation balance';
  END IF;

  INSERT INTO finance.obligation_settlements (
    obligation_id, payment_id, currency, amount, idempotency_key, journal_id, metadata
  ) VALUES (
    v_obligation.id, v_payment.id, v_payment.currency, p_amount,
    btrim(p_idempotency_key), v_journal.id, coalesce(p_metadata, '{}'::jsonb)
  ) RETURNING id INTO v_id;

  UPDATE finance.obligations
     SET status = CASE WHEN v_obligation_settled + p_amount >= v_obligation.amount THEN 'settled' ELSE 'partially_settled' END,
         updated_at = clock_timestamp()
   WHERE id = v_obligation.id;
  RETURN v_id;
END;
$function$;



-- ----------------------------------------------------------------------------
-- Triggers
-- ----------------------------------------------------------------------------
CREATE TRIGGER journal_lines_immutable_posted BEFORE INSERT OR DELETE OR UPDATE ON finance.journal_lines FOR EACH ROW EXECUTE FUNCTION finance.guard_journal_line_mutation();
CREATE TRIGGER journals_immutable_posted BEFORE INSERT OR DELETE OR UPDATE ON finance.journals FOR EACH ROW EXECUTE FUNCTION finance.guard_journal_state();
CREATE TRIGGER obligation_settlements_append_only BEFORE DELETE OR UPDATE ON finance.obligation_settlements FOR EACH ROW EXECUTE FUNCTION finance.reject_immutable_finance_row();
CREATE TRIGGER obligations_immutable_terms_before_update BEFORE UPDATE ON finance.obligations FOR EACH ROW EXECUTE FUNCTION finance.enforce_obligation_immutability_guard();
CREATE TRIGGER payment_attempts_guard BEFORE INSERT OR UPDATE ON finance.payment_attempts FOR EACH ROW EXECUTE FUNCTION finance.guard_payment_attempt();
CREATE TRIGGER payments_append_only BEFORE DELETE OR UPDATE ON finance.payments FOR EACH ROW EXECUTE FUNCTION finance.reject_immutable_finance_row();
CREATE TRIGGER provider_events_evidence_guard BEFORE INSERT OR DELETE OR UPDATE ON finance.provider_events FOR EACH ROW EXECUTE FUNCTION finance.guard_provider_event();

-- ----------------------------------------------------------------------------
-- Views (all captured with security_invoker=true)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW "finance"."v_account_balances" WITH (security_invoker='true') AS
WITH posted_account_currency_totals AS (
         SELECT jl.entity_id,
            jl.account_id,
            jl.currency,
            sum(jl.debit_amount) AS posted_debits,
            sum(jl.credit_amount) AS posted_credits
           FROM finance.journal_lines jl
             JOIN finance.journals j ON j.id = jl.journal_id AND j.entity_id = jl.entity_id AND j.currency = jl.currency AND j.status = 'posted'::text
          GROUP BY jl.entity_id, jl.account_id, jl.currency
        )
 SELECT a.id AS account_id,
    a.entity_id,
    a.account_code,
    a.account_name,
    a.account_type,
    a.normal_balance,
    COALESCE(pt.currency, a.currency) AS currency,
    COALESCE(pt.posted_debits, 0::numeric) AS posted_debits,
    COALESCE(pt.posted_credits, 0::numeric) AS posted_credits,
        CASE
            WHEN a.normal_balance = 'debit'::text THEN COALESCE(pt.posted_debits, 0::numeric) - COALESCE(pt.posted_credits, 0::numeric)
            ELSE COALESCE(pt.posted_credits, 0::numeric) - COALESCE(pt.posted_debits, 0::numeric)
        END AS closing_balance
   FROM finance.ledger_accounts a
     LEFT JOIN posted_account_currency_totals pt ON pt.account_id = a.id AND pt.entity_id = a.entity_id;

CREATE OR REPLACE VIEW "finance"."v_obligation_balances" WITH (security_invoker='true') AS
WITH settlement_totals AS (
         SELECT obligation_settlements.obligation_id,
            obligation_settlements.currency,
            sum(obligation_settlements.amount) AS total_settlements,
            count(*) AS settlement_count
           FROM finance.obligation_settlements
          GROUP BY obligation_settlements.obligation_id, obligation_settlements.currency
        )
 SELECT o.id AS obligation_id,
    o.payer_entity_id,
    o.payee_entity_id,
    o.commercial_order_id,
    o.legacy_order_id,
    o.obligation_type,
    o.status AS obligation_status,
    o.currency,
    o.amount AS obligation_amount,
    COALESCE(st.total_settlements, 0::numeric) AS total_settlements,
    o.amount - COALESCE(st.total_settlements, 0::numeric) AS outstanding_balance,
    COALESCE(st.settlement_count, 0::bigint) AS settlement_count,
    o.due_at,
    o.created_at,
    o.updated_at
   FROM finance.obligations o
     LEFT JOIN settlement_totals st ON st.obligation_id = o.id AND st.currency = o.currency;

CREATE OR REPLACE VIEW "finance"."v_payment_attempt_monitoring" WITH (security_invoker='true') AS
SELECT id AS payment_attempt_id,
    obligation_id,
    payer_entity_id,
    provider,
    method_type,
    amount,
    currency,
    status AS attempt_status,
    failure_code,
    failure_message,
    created_at,
    updated_at,
    completed_at,
    status = 'pending'::text AND updated_at < (now() - '00:15:00'::interval) AS is_stale_pending_15m,
    status = 'processing'::text AND updated_at < (now() - '00:30:00'::interval) AS is_stale_processing_30m
   FROM finance.payment_attempts pa;

CREATE OR REPLACE VIEW "finance"."v_platform_revenue_summary" WITH (security_invoker='true') AS
WITH posted_account_totals AS (
         SELECT jl.entity_id,
            jl.currency,
            jl.account_id,
            la.account_type,
            la.account_code,
            la.normal_balance,
            sum(jl.debit_amount) AS debits,
            sum(jl.credit_amount) AS credits
           FROM finance.journal_lines jl
             JOIN finance.journals j ON j.id = jl.journal_id AND j.entity_id = jl.entity_id AND j.currency = jl.currency AND j.status = 'posted'::text
             JOIN finance.ledger_accounts la ON la.id = jl.account_id AND la.entity_id = jl.entity_id
          GROUP BY jl.entity_id, jl.currency, jl.account_id, la.account_type, la.account_code, la.normal_balance
        )
 SELECT entity_id,
    currency,
    sum(
        CASE
            WHEN account_type = 'revenue'::text THEN
            CASE
                WHEN normal_balance = 'credit'::text THEN credits - debits
                ELSE debits - credits
            END
            ELSE 0::numeric
        END) AS recognized_revenue,
    sum(
        CASE
            WHEN account_type = 'liability'::text AND account_code = '2200'::text THEN
            CASE
                WHEN normal_balance = 'credit'::text THEN credits - debits
                ELSE debits - credits
            END
            ELSE 0::numeric
        END) AS unearned_subscription_revenue_balance,
    sum(
        CASE
            WHEN account_type = 'expense'::text THEN
            CASE
                WHEN normal_balance = 'debit'::text THEN debits - credits
                ELSE credits - debits
            END
            ELSE 0::numeric
        END) AS expenses
   FROM posted_account_totals
  GROUP BY entity_id, currency;

CREATE OR REPLACE VIEW "finance"."v_verified_payment_collections" WITH (security_invoker='true') AS
SELECT id AS payment_id,
    provider,
    provider_reference,
    amount,
    currency,
    payer_entity_id,
    payee_entity_id,
    verified_at,
    created_at,
    'verified_payment_record'::text AS collection_record_status,
    'not_established_by_payment_record'::text AS bank_settlement_status
   FROM finance.payments p
  WHERE verified_at IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Policies
-- ----------------------------------------------------------------------------
CREATE POLICY accounting_periods_entity_member_read ON finance.accounting_periods FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = accounting_periods.entity_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY journal_lines_active_entity_guard ON finance.journal_lines FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = journal_lines.entity_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY journal_lines_entity_read ON finance.journal_lines FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = journal_lines.entity_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY journals_entity_read ON finance.journals FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = journals.entity_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY ledger_accounts_entity_read ON finance.ledger_accounts FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = ledger_accounts.entity_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY settlements_party_read ON finance.obligation_settlements FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (finance.obligations o
     JOIN entity_members em ON (((em.entity_id = o.payer_entity_id) OR (em.entity_id = o.payee_entity_id))))
  WHERE ((o.id = obligation_settlements.obligation_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY obligations_party_read ON finance.obligations FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = ANY (ARRAY[obligations.payer_entity_id, obligations.payee_entity_id])) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY payment_attempts_payer_read ON finance.payment_attempts FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = payment_attempts.payer_entity_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY payment_methods_entity_read ON finance.payment_methods FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = payment_methods.entity_id) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));
CREATE POLICY payments_party_read ON finance.payments FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM entity_members em
  WHERE ((em.entity_id = ANY (ARRAY[payments.payer_entity_id, payments.payee_entity_id])) AND (em.profile_id = ( SELECT current_profile_id() AS current_profile_id)) AND (em.is_active IS TRUE) AND (em.membership_status = 'active'::text)))));

-- ----------------------------------------------------------------------------
-- Privileges
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA "finance" TO "authenticated", "service_role";

REVOKE ALL PRIVILEGES ON TABLE "finance"."accounting_periods" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."journal_lines" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."journals" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."ledger_accounts" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."obligation_settlements" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."obligations" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."payment_attempts" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."payment_methods" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."payments" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."provider_events" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."v_account_balances" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."v_obligation_balances" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."v_payment_attempt_monitoring" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."v_platform_revenue_summary" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON TABLE "finance"."v_verified_payment_collections" FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."claim_mpesa_attempt"(p_payment_attempt_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."claim_mpesa_attempt_safe"(p_payment_attempt_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."claim_mpesa_attempt_safe"(p_payment_attempt_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."close_accounting_period"(p_period_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."close_accounting_period"(p_period_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."complete_mpesa_initiation"(p_payment_attempt_id uuid, p_checkout_request_id text, p_failure_code text, p_failure_message text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."complete_mpesa_initiation"(p_payment_attempt_id uuid, p_checkout_request_id text, p_failure_code text, p_failure_message text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."create_accounting_period"(p_entity_id uuid, p_start_date date, p_end_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."create_accounting_period"(p_entity_id uuid, p_start_date date, p_end_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."create_obligation"(p_payer_entity_id uuid, p_payee_entity_id uuid, p_amount numeric, p_currency text, p_idempotency_key text, p_obligation_type text, p_commercial_order_id uuid, p_legacy_order_id uuid, p_due_at timestamp with time zone, p_description text, p_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."create_obligation"(p_payer_entity_id uuid, p_payee_entity_id uuid, p_amount numeric, p_currency text, p_idempotency_key text, p_obligation_type text, p_commercial_order_id uuid, p_legacy_order_id uuid, p_due_at timestamp with time zone, p_description text, p_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."create_payment_attempt"(p_obligation_id uuid, p_provider text, p_method_type text, p_amount numeric, p_idempotency_key text, p_payment_method_id uuid, p_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."create_payment_attempt"(p_obligation_id uuid, p_provider text, p_method_type text, p_amount numeric, p_idempotency_key text, p_payment_method_id uuid, p_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."enforce_obligation_immutability_guard"() FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."finalize_mpesa_payment"(p_payment_attempt_id uuid, p_provider_event_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."finalize_mpesa_payment"(p_payment_attempt_id uuid, p_provider_event_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."guard_journal_line_mutation"() FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."guard_journal_state"() FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."guard_payment_attempt"() FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."guard_provider_event"() FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."post_journal"(p_journal_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."post_journal"(p_journal_id uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."recognize_platform_subscription_revenue"(p_obligation_id uuid, p_amount numeric, p_idempotency_key text, p_recognition_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."recognize_platform_subscription_revenue"(p_obligation_id uuid, p_amount numeric, p_idempotency_key text, p_recognition_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_bank_receipt"(p_settlement_reference text, p_bank_reference text, p_bank_amount numeric, p_effective_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_bank_receipt"(p_settlement_reference text, p_bank_reference text, p_bank_amount numeric, p_effective_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_definitive_failure"(p_payment_attempt_id uuid, p_provider_event_id text, p_checkout_request_id text, p_failure_code text, p_failure_description text, p_callback_payload jsonb, p_provider_query_result jsonb, p_callback_authentication_succeeded boolean, p_provider_verified_at timestamp with time zone) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_definitive_failure"(p_payment_attempt_id uuid, p_provider_event_id text, p_checkout_request_id text, p_failure_code text, p_failure_description text, p_callback_payload jsonb, p_provider_query_result jsonb, p_callback_authentication_succeeded boolean, p_provider_verified_at timestamp with time zone) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_settlement_transfer"(p_settlement_reference text, p_gross_amount numeric, p_provider_fee numeric, p_effective_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_settlement_transfer"(p_settlement_reference text, p_gross_amount numeric, p_provider_fee numeric, p_effective_date date) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_verification_evidence"(p_payment_attempt_id uuid, p_provider_event_id text, p_verified_provider_reference text, p_verified_amount numeric, p_verified_currency text, p_callback_payload jsonb, p_provider_query_result jsonb, p_provider_verified_at timestamp with time zone) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_mpesa_verification_evidence"(p_payment_attempt_id uuid, p_provider_event_id text, p_verified_provider_reference text, p_verified_amount numeric, p_verified_currency text, p_callback_payload jsonb, p_provider_query_result jsonb, p_provider_verified_at timestamp with time zone) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_verified_payment"(p_payment_attempt_id uuid, p_provider_event_id uuid, p_provider_reference text, p_confirmed_amount numeric, p_confirmed_currency text, p_verification_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_verified_payment"(p_payment_attempt_id uuid, p_provider_event_id uuid, p_provider_reference text, p_confirmed_amount numeric, p_confirmed_currency text, p_verification_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."record_verified_payment_internal"(p_payment_attempt_id uuid, p_provider_event_id uuid, p_provider_reference text, p_confirmed_amount numeric, p_confirmed_currency text, p_verification_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."reject_immutable_finance_row"() FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."request_mpesa_attempt"(p_obligation_id uuid, p_amount numeric, p_phone text, p_idempotency_key text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."request_mpesa_attempt"(p_obligation_id uuid, p_amount numeric, p_phone text, p_idempotency_key text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."reverse_journal"(p_journal_id uuid, p_idempotency_key text, p_description text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."reverse_journal"(p_journal_id uuid, p_idempotency_key text, p_description text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."set_payment_attempt_provider_request_ref"(p_payment_attempt_id uuid, p_provider_request_ref text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."set_payment_attempt_provider_request_ref"(p_payment_attempt_id uuid, p_provider_request_ref text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."settle_payment"(p_payment_id uuid, p_amount numeric, p_idempotency_key text, p_journal_id uuid, p_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL PRIVILEGES ON FUNCTION "finance"."settle_payment"(p_payment_id uuid, p_amount numeric, p_idempotency_key text, p_journal_id uuid, p_metadata jsonb) FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT SELECT ON TABLE "finance"."accounting_periods" TO "authenticated";
GRANT SELECT ON TABLE "finance"."accounting_periods" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."journal_lines" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."journal_lines" TO "service_role";
GRANT SELECT ON TABLE "finance"."journal_lines" TO "authenticated";
GRANT SELECT ON TABLE "finance"."journal_lines" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."journals" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."journals" TO "service_role";
GRANT SELECT ON TABLE "finance"."journals" TO "authenticated";
GRANT SELECT ON TABLE "finance"."journals" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."ledger_accounts" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."ledger_accounts" TO "service_role";
GRANT SELECT ON TABLE "finance"."ledger_accounts" TO "authenticated";
GRANT SELECT ON TABLE "finance"."ledger_accounts" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."obligation_settlements" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."obligation_settlements" TO "service_role";
GRANT SELECT ON TABLE "finance"."obligation_settlements" TO "authenticated";
GRANT SELECT ON TABLE "finance"."obligation_settlements" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."obligations" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."obligations" TO "service_role";
GRANT SELECT ON TABLE "finance"."obligations" TO "authenticated";
GRANT SELECT ON TABLE "finance"."obligations" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."payment_attempts" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."payment_attempts" TO "service_role";
GRANT SELECT ON TABLE "finance"."payment_attempts" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."payment_methods" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."payment_methods" TO "service_role";
GRANT SELECT ON TABLE "finance"."payment_methods" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."payments" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."payments" TO "service_role";
GRANT SELECT ON TABLE "finance"."payments" TO "service_role";
GRANT MAINTAIN ON TABLE "finance"."provider_events" TO "service_role";
GRANT REFERENCES ON TABLE "finance"."provider_events" TO "service_role";
GRANT SELECT ON TABLE "finance"."provider_events" TO "service_role";
GRANT SELECT ON TABLE "finance"."v_account_balances" TO "authenticated";
GRANT SELECT ON TABLE "finance"."v_obligation_balances" TO "authenticated";
GRANT SELECT ON TABLE "finance"."v_platform_revenue_summary" TO "authenticated";
GRANT SELECT ON TABLE "finance"."v_verified_payment_collections" TO "authenticated";

GRANT SELECT ("id") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("obligation_id") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("amount") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("currency") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("status") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("created_at") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("updated_at") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("completed_at") ON TABLE "finance"."payment_attempts" TO "authenticated";
GRANT SELECT ("id") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("entity_id") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("provider") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("method_type") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("is_default") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("is_active") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("created_at") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("updated_at") ON TABLE "finance"."payment_methods" TO "authenticated";
GRANT SELECT ("id") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("obligation_id") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("payment_attempt_id") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("payer_entity_id") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("payee_entity_id") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("payment_method_id") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("provider") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("provider_reference") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("amount") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("currency") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("verified_at") ON TABLE "finance"."payments" TO "authenticated";
GRANT SELECT ("created_at") ON TABLE "finance"."payments" TO "authenticated";

GRANT EXECUTE ON FUNCTION "finance"."claim_mpesa_attempt_safe"(p_payment_attempt_id uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "finance"."close_accounting_period"(p_period_id uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION "finance"."complete_mpesa_initiation"(p_payment_attempt_id uuid, p_checkout_request_id text, p_failure_code text, p_failure_message text) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."create_accounting_period"(p_entity_id uuid, p_start_date date, p_end_date date) TO "authenticated";
GRANT EXECUTE ON FUNCTION "finance"."create_obligation"(p_payer_entity_id uuid, p_payee_entity_id uuid, p_amount numeric, p_currency text, p_idempotency_key text, p_obligation_type text, p_commercial_order_id uuid, p_legacy_order_id uuid, p_due_at timestamp with time zone, p_description text, p_metadata jsonb) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."create_payment_attempt"(p_obligation_id uuid, p_provider text, p_method_type text, p_amount numeric, p_idempotency_key text, p_payment_method_id uuid, p_metadata jsonb) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."finalize_mpesa_payment"(p_payment_attempt_id uuid, p_provider_event_id uuid) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."post_journal"(p_journal_id uuid) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."recognize_platform_subscription_revenue"(p_obligation_id uuid, p_amount numeric, p_idempotency_key text, p_recognition_date date) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."record_mpesa_bank_receipt"(p_settlement_reference text, p_bank_reference text, p_bank_amount numeric, p_effective_date date) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."record_mpesa_definitive_failure"(p_payment_attempt_id uuid, p_provider_event_id text, p_checkout_request_id text, p_failure_code text, p_failure_description text, p_callback_payload jsonb, p_provider_query_result jsonb, p_callback_authentication_succeeded boolean, p_provider_verified_at timestamp with time zone) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."record_mpesa_settlement_transfer"(p_settlement_reference text, p_gross_amount numeric, p_provider_fee numeric, p_effective_date date) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."record_mpesa_verification_evidence"(p_payment_attempt_id uuid, p_provider_event_id text, p_verified_provider_reference text, p_verified_amount numeric, p_verified_currency text, p_callback_payload jsonb, p_provider_query_result jsonb, p_provider_verified_at timestamp with time zone) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."record_verified_payment"(p_payment_attempt_id uuid, p_provider_event_id uuid, p_provider_reference text, p_confirmed_amount numeric, p_confirmed_currency text, p_verification_metadata jsonb) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."request_mpesa_attempt"(p_obligation_id uuid, p_amount numeric, p_phone text, p_idempotency_key text) TO "authenticated";
GRANT EXECUTE ON FUNCTION "finance"."reverse_journal"(p_journal_id uuid, p_idempotency_key text, p_description text) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."set_payment_attempt_provider_request_ref"(p_payment_attempt_id uuid, p_provider_request_ref text) TO "service_role";
GRANT EXECUTE ON FUNCTION "finance"."settle_payment"(p_payment_id uuid, p_amount numeric, p_idempotency_key text, p_journal_id uuid, p_metadata jsonb) TO "service_role";

RESET check_function_bodies;
RESET search_path;

COMMIT;

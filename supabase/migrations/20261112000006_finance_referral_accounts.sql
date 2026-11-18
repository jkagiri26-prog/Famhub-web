-- ============================================================================
-- 20261112000006_finance_referral_accounts
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Add the controlled Finance account setup for Refer & Earn:
--     * Referral Reward Expense account code 5200.
--     * A dedicated referral rewards payable liability account.
--     * A per-platform-entity account mapping.
--
-- LIVE FACTS THIS MIGRATION RESPECTS
--   * Account 5200 does not exist yet.
--   * No referral rewards payable account exists yet.
--   * No accounting periods are open.
--   * The platform entity ID is NOT hardcoded.
--   * The payable account code is NOT invented; it is supplied by the
--     authorized Finance administrator after inspecting the live chart.
--
-- OPERATIONAL PROCEDURE (do not automate periods)
--   1. Inspect finance.ledger_accounts for the platform administration entity.
--   2. Choose an unused payable account code and a name.
--   3. Invoke finance.ensure_referral_accounts as service_role with:
--        platform entity id, payable account code, payable account name.
--   4. Verify the returned mapping and account rows.
--   5. Separately, an authorized Finance administrator opens the required
--      accounting period using the existing Finance period procedure.
--      This migration never opens a period.
--
-- SCOPE
--   No ledger rows are inserted by the migration itself. No accounting period
--   is opened. No journal is posted.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS finance.ensure_referral_accounts(uuid, text, text);
--   DROP TABLE IF EXISTS finance.referral_account_settings;
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS "finance"."referral_account_settings" (
    "platform_entity_id" uuid NOT NULL,
    "expense_account_id" uuid NOT NULL,
    "payable_account_id" uuid NOT NULL,
    "currency" text NOT NULL DEFAULT 'KES',
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "referral_account_settings_pkey" PRIMARY KEY ("platform_entity_id"),
    CONSTRAINT "referral_account_settings_platform_entity_id_fkey"
        FOREIGN KEY ("platform_entity_id")
        REFERENCES "core"."entities"("id") ON DELETE RESTRICT,
    CONSTRAINT "referral_account_settings_expense_account_id_fkey"
        FOREIGN KEY ("expense_account_id")
        REFERENCES "finance"."ledger_accounts"("id") ON DELETE RESTRICT,
    CONSTRAINT "referral_account_settings_payable_account_id_fkey"
        FOREIGN KEY ("payable_account_id")
        REFERENCES "finance"."ledger_accounts"("id") ON DELETE RESTRICT,
    CONSTRAINT "referral_account_settings_currency_check"
        CHECK ("currency" = 'KES'),
    CONSTRAINT "referral_account_settings_distinct_accounts_check"
        CHECK ("expense_account_id" <> "payable_account_id")
);

ALTER TABLE "finance"."referral_account_settings" ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE "finance"."referral_account_settings"
    FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE DELETE, TRUNCATE ON TABLE "finance"."referral_account_settings"
    FROM PUBLIC, "anon", "authenticated", "service_role";

COMMENT ON TABLE "finance"."referral_account_settings"
    IS 'Controlled per-platform-entity mapping for Refer & Earn expense and payable ledger accounts. No period opening.';

CREATE OR REPLACE FUNCTION "finance"."ensure_referral_accounts"(
    "p_platform_entity_id" uuid,
    "p_payable_account_code" text,
    "p_payable_account_name" text DEFAULT 'Referral Rewards Payable'
)
RETURNS TABLE (
    "platform_entity_id" uuid,
    "expense_account_id" uuid,
    "payable_account_id" uuid,
    "expense_account_code" text,
    "payable_account_code" text,
    "currency" text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, finance, core
AS $function$
DECLARE
    v_platform_entity core.entities%ROWTYPE;
    v_account finance.ledger_accounts%ROWTYPE;
    v_mapping finance.referral_account_settings%ROWTYPE;
    v_payable_code text := nullif(btrim(p_payable_account_code), '');
    v_payable_name text := nullif(btrim(p_payable_account_name), '');
    v_expense_account_id uuid;
    v_payable_account_id uuid;
BEGIN
    SELECT * INTO STRICT v_platform_entity
      FROM core.entities
     WHERE id = p_platform_entity_id
       AND is_active IS TRUE
       AND metadata->>'platform_entity' = 'true'
       AND metadata->>'purpose' = 'platform_administration';

    IF v_payable_code IS NULL OR v_payable_name IS NULL THEN
        RAISE EXCEPTION 'A non-empty payable account code and name are required'
            USING ERRCODE = '22023';
    END IF;
    IF v_payable_code = '5200' THEN
        RAISE EXCEPTION 'The payable account code cannot be 5200'
            USING ERRCODE = '22023';
    END IF;

    -- Referral Reward Expense: fixed approved code 5200.
    INSERT INTO finance.ledger_accounts (
        entity_id, account_code, account_name, account_type,
        normal_balance, currency, is_active
    ) VALUES (
        p_platform_entity_id, '5200', 'Referral Reward Expense', 'expense',
        'debit', 'KES', true
    )
    ON CONFLICT (entity_id, account_code) DO NOTHING
    RETURNING id INTO v_expense_account_id;

    IF v_expense_account_id IS NULL THEN
        SELECT * INTO STRICT v_account
          FROM finance.ledger_accounts
         WHERE entity_id = p_platform_entity_id
           AND account_code = '5200';
        IF v_account.account_type <> 'expense'
           OR v_account.normal_balance <> 'debit'
           OR v_account.currency <> 'KES'
           OR v_account.is_active IS NOT TRUE THEN
            RAISE EXCEPTION 'Existing account 5200 is not an active KES debit expense account'
                USING ERRCODE = '55000';
        END IF;
        v_expense_account_id := v_account.id;
    END IF;

    -- Dedicated payable account. The code is supplied; it is never invented.
    INSERT INTO finance.ledger_accounts (
        entity_id, account_code, account_name, account_type,
        normal_balance, currency, is_active
    ) VALUES (
        p_platform_entity_id, v_payable_code, v_payable_name, 'liability',
        'credit', 'KES', true
    )
    ON CONFLICT (entity_id, account_code) DO NOTHING
    RETURNING id INTO v_payable_account_id;

    IF v_payable_account_id IS NULL THEN
        SELECT * INTO STRICT v_account
          FROM finance.ledger_accounts
         WHERE entity_id = p_platform_entity_id
           AND account_code = v_payable_code;
        IF v_account.account_type <> 'liability'
           OR v_account.normal_balance <> 'credit'
           OR v_account.currency <> 'KES'
           OR v_account.is_active IS NOT TRUE THEN
            RAISE EXCEPTION 'Existing account % is not an active KES credit liability account', v_payable_code
                USING ERRCODE = '55000';
        END IF;
        v_payable_account_id := v_account.id;
    END IF;

    INSERT INTO finance.referral_account_settings (
        platform_entity_id, expense_account_id, payable_account_id, currency
    ) VALUES (
        p_platform_entity_id, v_expense_account_id, v_payable_account_id, 'KES'
    )
    ON CONFLICT ON CONSTRAINT "referral_account_settings_pkey" DO NOTHING;

    SELECT m.* INTO STRICT v_mapping
      FROM finance.referral_account_settings AS m
     WHERE m.platform_entity_id = p_platform_entity_id;

    IF v_mapping.expense_account_id <> v_expense_account_id
       OR v_mapping.payable_account_id <> v_payable_account_id THEN
        RAISE EXCEPTION 'Referral account mapping already exists with different accounts'
            USING ERRCODE = '55000';
    END IF;

    RETURN QUERY
    SELECT
        v_mapping.platform_entity_id,
        v_mapping.expense_account_id,
        v_mapping.payable_account_id,
        '5200'::text,
        v_payable_code,
        v_mapping.currency;
END;
$function$;

REVOKE ALL ON FUNCTION "finance"."ensure_referral_accounts"(uuid, text, text)
    FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "finance"."ensure_referral_accounts"(uuid, text, text)
    TO "service_role";

COMMENT ON FUNCTION "finance"."ensure_referral_accounts"(uuid, text, text)
    IS 'Controlled Finance setup: creates/validates 5200 expense, a supplied payable account, and the mapping. Never opens accounting periods.';

COMMIT;

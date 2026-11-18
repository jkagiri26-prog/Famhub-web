-- ============================================================================
-- 20261112000010_individual_billing_accounts
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Provide the smallest authenticated, self-scoped path for creating/reusing
--   one individual billing account for the caller.
--
-- LIVE FACTS RESPECTED
--   * system.billing_accounts currently has no rows.
--   * No repository or live database function creates billing accounts.
--   * core.entities.owner_id references users.profiles(id).
--   * core.ensure_entity_for_profile is the canonical individual_pro entity
--     creation/reuse procedure.
--
-- GUARANTEES
--   * No arbitrary profile_id or entity_id is accepted.
--   * Caller identity comes from auth.uid().
--   * The canonical individual_pro entity is resolved through existing
--     identity semantics.
--   * Exactly one individual/KES/active billing account is reused or created
--     for the caller's profile/entity pair.
--   * Business/cooperative/supplier/platform accounts are never created here.
--   * Existing non-individual, non-KES or inactive account state is rejected,
--     not silently mutated.
--
-- SCOPE
--   Function only. No row is created by the migration. No plan, invoice,
--   subscription, obligation or accounting period is touched.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS system.ensure_individual_billing_account();
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION "system"."ensure_individual_billing_account"()
RETURNS TABLE (
    "billing_account_id" uuid,
    "entity_id" uuid,
    "profile_id" uuid,
    "account_type" text,
    "currency" text,
    "status" text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auth, system, core, users
AS $function$
DECLARE
    v_auth_user_id uuid := auth.uid();
    v_profile_id uuid;
    v_entity_id uuid;
    v_account_id uuid;
    v_account system.billing_accounts%ROWTYPE;
BEGIN
    IF v_auth_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    SELECT p.id INTO v_profile_id
      FROM users.profiles AS p
     WHERE p.auth_user_id = v_auth_user_id
       AND p.is_active IS TRUE
       AND p.account_status = 'active';

    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Active authenticated profile not found'
            USING ERRCODE = '42501';
    END IF;

    -- Canonical identity semantics: reuse/create the owner individual_pro entity.
    PERFORM core.ensure_entity_for_profile(v_profile_id);

    SELECT e.id INTO v_entity_id
      FROM core.entities AS e
     WHERE e.owner_id = v_profile_id
       AND e.entity_type = 'individual_pro'
       AND e.is_active IS TRUE
     ORDER BY e.created_at, e.id
     LIMIT 1;

    IF v_entity_id IS NULL THEN
        RAISE EXCEPTION 'Canonical individual_pro entity not found'
            USING ERRCODE = '55000';
    END IF;

    -- Serialize account creation per profile and rely on the live unique
    -- constraint (entity_id, profile_id) as the final guard.
    PERFORM pg_advisory_xact_lock(
        hashtextextended('individual-billing-account:' || v_profile_id::text, 0)
    );

    SELECT * INTO v_account
      FROM system.billing_accounts AS ba
     WHERE ba.entity_id = v_entity_id
       AND ba.profile_id = v_profile_id
     FOR UPDATE;

    IF FOUND THEN
        IF v_account.account_type <> 'individual'
           OR v_account.currency <> 'KES'
           OR v_account.status <> 'active' THEN
            RAISE EXCEPTION 'Existing billing account is not an active KES individual account'
                USING ERRCODE = '55000';
        END IF;

        RETURN QUERY
        SELECT v_account.id, v_account.entity_id, v_account.profile_id,
               v_account.account_type, v_account.currency, v_account.status;
        RETURN;
    END IF;

    INSERT INTO system.billing_accounts (
        entity_id, profile_id, account_type, currency, status
    ) VALUES (
        v_entity_id, v_profile_id, 'individual', 'KES', 'active'
    )
    ON CONFLICT ON CONSTRAINT "uq_billing_account_entity_profile" DO NOTHING
    RETURNING id INTO v_account_id;

    IF v_account_id IS NULL THEN
        SELECT * INTO v_account
          FROM system.billing_accounts AS ba
         WHERE ba.entity_id = v_entity_id
           AND ba.profile_id = v_profile_id;

        IF NOT FOUND
           OR v_account.account_type <> 'individual'
           OR v_account.currency <> 'KES'
           OR v_account.status <> 'active' THEN
            RAISE EXCEPTION 'Concurrent billing account is not an active KES individual account'
                USING ERRCODE = '55000';
        END IF;

        RETURN QUERY
        SELECT v_account.id, v_account.entity_id, v_account.profile_id,
               v_account.account_type, v_account.currency, v_account.status;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT v_account_id, v_entity_id, v_profile_id,
           'individual'::text, 'KES'::text, 'active'::text;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."ensure_individual_billing_account"()
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."ensure_individual_billing_account"()
    TO "authenticated";

COMMENT ON FUNCTION "system"."ensure_individual_billing_account"()
    IS 'Self-scoped idempotent creation/reuse of exactly one individual KES billing account. No arbitrary profile/entity IDs.';

COMMIT;

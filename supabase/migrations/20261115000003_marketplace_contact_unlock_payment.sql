-- ============================================================================
-- 20261115000003_marketplace_contact_unlock_payment
-- ----------------------------------------------------------------------------
-- Contact-unlock payment lifecycle on top of the shared Finance engine.
--
-- Adds:
--   * authenticated request of the Finance payment attempt;
--   * authenticated read of contact-unlock/payment status;
--   * service-role confirmation boundary delegating to Finance finalization.
--
-- No new ledger, payment state, table, or scheduler is introduced.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Request payment for a contact unlock.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION marketplace.request_contact_unlock_payment(
    p_listing_id uuid,
    p_phone text,
    p_idempotency_key text
)
RETURNS TABLE(
    obligation_id uuid,
    payment_attempt_id uuid,
    amount numeric,
    currency text,
    unlock_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'marketplace', 'finance', 'core', 'auth'
AS $function$
DECLARE
    v_obligation_id uuid;
    v_obligation finance.obligations%ROWTYPE;
    v_attempt_id uuid;
    v_buyer_entity uuid;
    v_amount numeric;
    v_currency text;
    v_payment_status text;
    v_unlocked boolean;
BEGIN
    v_obligation_id := marketplace.unlock_contact(p_listing_id);

    IF v_obligation_id IS NULL THEN
        v_buyer_entity := core.get_active_entity();
        SELECT cu.finance_obligation_id, cu.amount, cu.currency,
               cu.payment_status, cu.unlocked
          INTO v_obligation_id, v_amount, v_currency,
               v_payment_status, v_unlocked
          FROM marketplace.contact_unlocks cu
         WHERE cu.listing_id = p_listing_id
           AND cu.entity_id = v_buyer_entity
           AND cu.payment_status = 'completed'
           AND cu.unlocked IS TRUE
         ORDER BY cu.created_at DESC, cu.id DESC
         LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Contact unlock is complete but no completed unlock row was found'
                USING ERRCODE = '55000';
        END IF;

        RETURN QUERY
        SELECT v_obligation_id, NULL::uuid, v_amount, v_currency,
               'already_unlocked'::text;
        RETURN;
    END IF;

    SELECT * INTO STRICT v_obligation
      FROM finance.obligations
     WHERE id = v_obligation_id;

    v_attempt_id := finance.request_mpesa_attempt(
        v_obligation_id,
        v_obligation.amount,
        p_phone,
        p_idempotency_key
    );

    RETURN QUERY
    SELECT v_obligation_id, v_attempt_id, v_obligation.amount,
           v_obligation.currency, 'payment_pending'::text;
END;
$function$;

ALTER FUNCTION marketplace.request_contact_unlock_payment(uuid, text, text)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION marketplace.request_contact_unlock_payment(uuid, text, text)
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT EXECUTE ON FUNCTION marketplace.request_contact_unlock_payment(uuid, text, text)
    TO "authenticated";

-- ----------------------------------------------------------------------------
-- Read current contact-unlock/payment status for the active buyer.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION marketplace.contact_unlock_status(p_listing_id uuid)
RETURNS TABLE(
    obligation_id uuid,
    payment_attempt_id uuid,
    amount numeric,
    currency text,
    payment_status text,
    unlocked boolean,
    attempt_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'marketplace', 'finance', 'core', 'auth'
AS $function$
    SELECT cu.finance_obligation_id,
           pa.id,
           cu.amount,
           cu.currency,
           cu.payment_status,
           cu.unlocked,
           pa.status
      FROM marketplace.contact_unlocks cu
      LEFT JOIN LATERAL (
          SELECT a.id, a.status
            FROM finance.payment_attempts a
           WHERE a.obligation_id = cu.finance_obligation_id
           ORDER BY a.created_at DESC, a.id DESC
           LIMIT 1
      ) pa ON TRUE
     WHERE cu.listing_id = p_listing_id
       AND cu.entity_id = core.get_active_entity()
     ORDER BY cu.created_at DESC, cu.id DESC
     LIMIT 1;
$function$;

ALTER FUNCTION marketplace.contact_unlock_status(uuid)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION marketplace.contact_unlock_status(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT EXECUTE ON FUNCTION marketplace.contact_unlock_status(uuid)
    TO "authenticated";

-- ----------------------------------------------------------------------------
-- Service-role confirmation boundary. Finance remains authoritative for
-- verification evidence, finalization, settlement, and journal posting.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION marketplace.confirm_contact_unlock_payment(
    p_payment_attempt_id uuid,
    p_provider_event_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'marketplace', 'finance'
AS $function$
DECLARE
    v_charge_code text;
    v_payment_id uuid;
BEGIN
    SELECT o.metadata->>'finance_charge_code'
      INTO v_charge_code
      FROM finance.payment_attempts a
      JOIN finance.obligations o ON o.id = a.obligation_id
     WHERE a.id = p_payment_attempt_id;

    IF v_charge_code IS DISTINCT FROM 'contact_unlock' THEN
        RAISE EXCEPTION
            'Payment attempt is not a contact-unlock payment'
            USING ERRCODE = '22023';
    END IF;

    v_payment_id := finance.finalize_mpesa_payment(
        p_payment_attempt_id,
        p_provider_event_id
    );

    RETURN v_payment_id;
END;
$function$;

ALTER FUNCTION marketplace.confirm_contact_unlock_payment(uuid, uuid)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION marketplace.confirm_contact_unlock_payment(uuid, uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT EXECUTE ON FUNCTION marketplace.confirm_contact_unlock_payment(uuid, uuid)
    TO "service_role";

COMMIT;

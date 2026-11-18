-- ============================================================================
-- 20261115000002_marketplace_contact_unlock_functions
-- ----------------------------------------------------------------------------
-- Repository-only restoration of the deployed production contact-unlock
-- functions.
--
-- Requires:
--   * 20261115000001_marketplace_contact_unlock_prerequisites.sql
--   * marketplace.listings.quantity_offered and nullable stock_id
--   * marketplace.contact_unlocks.finance_obligation_id
--
-- This migration creates/replaces only these two functions and restores their
-- production EXECUTE boundaries. It does not alter tables, indexes, RLS,
-- policies, buyer_pricing, payments, or data.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- marketplace.assert_contact_unlock_listing_eligible(uuid)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION marketplace.assert_contact_unlock_listing_eligible(p_listing_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'marketplace', 'core', 'commerce'
AS $function$
    DECLARE
      v_entity_id uuid; v_status text; v_stock_id uuid; v_quantity_offered numeric;
      v_stock_entity_id uuid; v_stock_status text; v_quantity numeric; v_reserved_quantity numeric;
    BEGIN
      SELECT l.entity_id, l.status, l.stock_id, l.quantity_offered
        INTO v_entity_id, v_status, v_stock_id, v_quantity_offered
        FROM marketplace.listings l WHERE l.id = p_listing_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Listing not found'; END IF;
      IF v_status IS DISTINCT FROM 'active' THEN
        RAISE EXCEPTION 'Listing is not eligible for contact unlocking: listing must be active';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM core.entities e WHERE e.id = v_entity_id AND e.is_active IS TRUE) THEN
        RAISE EXCEPTION 'Listing is not eligible for contact unlocking: seller entity is inactive';
      END IF;
      IF v_stock_id IS NOT NULL THEN
        SELECT s.entity_id, s.status, s.quantity, s.reserved_quantity
          INTO v_stock_entity_id, v_stock_status, v_quantity, v_reserved_quantity
          FROM commerce.stock_registry s WHERE s.id = v_stock_id FOR UPDATE;
        IF NOT FOUND OR v_stock_entity_id IS DISTINCT FROM v_entity_id
           OR v_stock_status IS DISTINCT FROM 'active'
           OR coalesce(v_quantity, 0) - coalesce(v_reserved_quantity, 0) <= 0 THEN
          RAISE EXCEPTION 'Listing is not eligible for contact unlocking: stock is inactive, unavailable, or inconsistent';
        END IF;
      ELSIF v_quantity_offered IS NULL OR v_quantity_offered <= 0 THEN
        RAISE EXCEPTION 'Listing is not eligible for contact unlocking: offered quantity is unavailable';
      END IF;
      RETURN v_entity_id;
    END;
    $function$;

ALTER FUNCTION marketplace.assert_contact_unlock_listing_eligible(uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION marketplace.assert_contact_unlock_listing_eligible(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

-- ----------------------------------------------------------------------------
-- Preserve an existing UUID-returning unlock_contact; drop only the old void
-- signature so CREATE OR REPLACE can establish the production return type.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_return_type oid;
BEGIN
    SELECT p.prorettype
      INTO v_return_type
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'marketplace'
       AND p.proname = 'unlock_contact'
       AND p.pronargs = 1
       AND p.proargtypes[0] = 'uuid'::regtype;

    IF v_return_type = 'void'::regtype THEN
        DROP FUNCTION marketplace.unlock_contact(uuid);
    ELSIF v_return_type IS NOT NULL
          AND v_return_type <> 'uuid'::regtype THEN
        RAISE EXCEPTION
            'Unexpected return type for marketplace.unlock_contact(uuid)';
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- marketplace.unlock_contact(uuid)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION marketplace.unlock_contact(p_listing_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'auth', 'core', 'marketplace', 'users', 'finance'
AS $function$
DECLARE
  v_profile_id uuid;
  v_buyer_entity uuid;
  v_listing_seller uuid;
  v_platform_entity uuid;
  v_price_id uuid;
  v_price numeric;
  v_currency text;
  v_unlock_id uuid;
  v_obligation_id uuid;
  v_existing_obligation finance.obligations%ROWTYPE;
  v_unlock_status text;
  v_unlocked boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required to request a contact unlock' USING ERRCODE = '42501';
  END IF;

  SELECT p.id INTO STRICT v_profile_id
  FROM users.profiles p
  WHERE p.auth_user_id = auth.uid()
    AND p.is_active IS TRUE
    AND p.account_status = 'active';

  v_buyer_entity := core.get_active_entity();
  IF v_buyer_entity IS NULL OR NOT EXISTS (
    SELECT 1 FROM core.entities e
    WHERE e.id = v_buyer_entity
      AND e.is_active IS TRUE
      AND e.entity_type = 'individual_pro'
      AND e.owner_id = v_profile_id
  ) THEN
    RAISE EXCEPTION 'The active payer must be the authenticated buyer''s active individual entity' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM core.entity_members em
    WHERE em.entity_id = v_buyer_entity
      AND em.profile_id = v_profile_id
      AND em.is_active IS TRUE
      AND em.membership_status = 'active'
      AND em.can_manage IS TRUE
  ) THEN
    RAISE EXCEPTION 'Active can_manage membership for the buyer entity is required' USING ERRCODE = '42501';
  END IF;

  SELECT l.entity_id INTO v_listing_seller
  FROM marketplace.listings l
  WHERE l.id = p_listing_id;
  IF v_listing_seller IS NULL THEN
    RAISE EXCEPTION 'Listing not found';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('marketplace-contact-unlock:' || v_buyer_entity::text || ':' || p_listing_id::text, 0)
  );
  PERFORM marketplace.assert_contact_unlock_listing_eligible(p_listing_id);

  SELECT cu.id, cu.finance_obligation_id, cu.payment_status, cu.unlocked
    INTO v_unlock_id, v_obligation_id, v_unlock_status, v_unlocked
  FROM marketplace.contact_unlocks cu
  WHERE cu.listing_id = p_listing_id
    AND cu.entity_id = v_buyer_entity
  FOR UPDATE;

  IF FOUND THEN
    IF v_unlock_status = 'completed' AND v_unlocked IS TRUE THEN
      RETURN NULL;
    END IF;
    IF v_obligation_id IS NOT NULL THEN
      SELECT * INTO STRICT v_existing_obligation
      FROM finance.obligations o
      WHERE o.id = v_obligation_id;
      IF v_existing_obligation.payer_entity_id IS DISTINCT FROM v_buyer_entity
         OR v_existing_obligation.obligation_type IS DISTINCT FROM 'fee'
         OR v_existing_obligation.metadata->>'finance_charge_code' IS DISTINCT FROM 'contact_unlock'
         OR v_existing_obligation.metadata->>'contact_unlock_id' IS DISTINCT FROM v_unlock_id::text THEN
        RAISE EXCEPTION 'Existing contact-unlock Finance linkage is inconsistent';
      END IF;
      RETURN v_obligation_id;
    END IF;
  ELSE
    v_unlock_id := gen_random_uuid();
  END IF;

  SELECT bp.id, bp.amount, upper(bp.currency)
    INTO v_price_id, v_price, v_currency
  FROM marketplace.buyer_pricing bp
  WHERE bp.action = 'contact_unlock'
    AND bp.active IS TRUE
    AND (bp.effective_from IS NULL OR bp.effective_from <= clock_timestamp()::timestamp)
  ORDER BY bp.effective_from DESC NULLS LAST, bp.id
  LIMIT 1;

  IF v_price_id IS NULL OR v_price IS NULL OR v_price <= 0
     OR v_currency IS NULL OR v_currency !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'No valid active contact-unlock price is configured in marketplace.buyer_pricing';
  END IF;

  SELECT e.id INTO STRICT v_platform_entity
  FROM core.entities e
  WHERE e.is_active IS TRUE
    AND e.metadata->>'platform_entity' = 'true'
    AND e.metadata->>'purpose' = 'platform_administration';

  IF v_unlock_status IS NULL THEN
    INSERT INTO marketplace.contact_unlocks (
      id, listing_id, amount, currency, payment_status, unlocked, valid_until, entity_id
    ) VALUES (
      v_unlock_id, p_listing_id, v_price, v_currency, 'pending', false, NULL, v_buyer_entity
    );
  ELSE
    UPDATE marketplace.contact_unlocks
       SET amount = v_price,
           currency = v_currency,
           payment_status = 'pending',
           unlocked = false,
           valid_until = NULL
     WHERE id = v_unlock_id
       AND finance_obligation_id IS NULL;
  END IF;

  v_obligation_id := finance.create_obligation(
    v_buyer_entity,
    v_platform_entity,
    v_price,
    v_currency,
    'marketplace-contact-unlock:' || v_buyer_entity::text || ':' || p_listing_id::text,
    'fee',
    NULL,
    NULL,
    NULL,
    'Platform contact unlock fee',
    jsonb_build_object(
      'finance_charge_code', 'contact_unlock',
      'tax_treatment', 'not_applicable',
      'contact_unlock_id', v_unlock_id,
      'listing_id', p_listing_id,
      'buyer_entity_id', v_buyer_entity,
      'buyer_pricing_id', v_price_id
    )
  );

  UPDATE marketplace.contact_unlocks
     SET finance_obligation_id = v_obligation_id
   WHERE id = v_unlock_id
     AND entity_id = v_buyer_entity
     AND listing_id = p_listing_id
     AND payment_status = 'pending'
     AND unlocked IS FALSE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unable to attach Finance obligation to pending contact unlock';
  END IF;

  RETURN v_obligation_id;
END;
$function$;

ALTER FUNCTION marketplace.unlock_contact(uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION marketplace.unlock_contact(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT EXECUTE ON FUNCTION marketplace.unlock_contact(uuid)
    TO "authenticated";

COMMIT;

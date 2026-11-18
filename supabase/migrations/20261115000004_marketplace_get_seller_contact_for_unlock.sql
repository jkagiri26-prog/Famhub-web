-- ============================================================================
-- 20261115000004_marketplace_get_seller_contact_for_unlock
-- ----------------------------------------------------------------------------
-- Captures the deployed seller-contact reveal RPC required by the
-- contact-unlock flow. The function independently verifies that the active
-- buyer has a completed, unexpired contact unlock before returning contact
-- details.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION marketplace.get_seller_contact_for_unlock(p_listing_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'core', 'marketplace', 'users', 'commerce'
AS $function$
DECLARE
  v_buyer_entity uuid;
  v_buyer_unlock marketplace.contact_unlocks%ROWTYPE;
  v_listing marketplace.listings%ROWTYPE;
  v_profile users.profiles%ROWTYPE;
  v_business commerce.business_profiles%ROWTYPE;
  v_now timestamptz := now();
BEGIN
  v_buyer_entity := core.get_active_entity();
  IF v_buyer_entity IS NULL THEN
    RAISE EXCEPTION 'No active entity for caller';
  END IF;

  SELECT *
    INTO v_listing
  FROM marketplace.listings
  WHERE id = p_listing_id;

  IF v_listing.id IS NULL THEN
    RAISE EXCEPTION 'Listing not found';
  END IF;

  SELECT cu.*
    INTO v_buyer_unlock
  FROM marketplace.contact_unlocks cu
  WHERE cu.listing_id = p_listing_id
    AND cu.entity_id = v_buyer_entity
    AND cu.payment_status = 'completed'
    AND cu.unlocked = true
    AND (
      cu.valid_until IS NULL
      OR cu.valid_until > v_now
    )
  ORDER BY cu.created_at DESC
  LIMIT 1;

  IF v_buyer_unlock.id IS NULL THEN
    RAISE EXCEPTION 'Unlock not available or expired';
  END IF;

  SELECT *
    INTO v_profile
  FROM users.profiles p
  JOIN core.entities e ON e.primary_contact_profile_id = p.id
  WHERE e.id = v_listing.entity_id
  LIMIT 1;

  SELECT *
    INTO v_business
  FROM commerce.business_profiles bp
  WHERE bp.entity_id = v_listing.entity_id
  LIMIT 1;

  RETURN jsonb_build_object(
    'seller_entity_id', v_listing.entity_id,
    'contact_person', COALESCE(v_business.contact_person, v_profile.first_name || ' ' || v_profile.last_name),
    'email', v_business.email,
    'phone', COALESCE(v_business.phone, v_profile.phone),
    'business_name', v_business.supplier_name,
    'physical_address', v_business.physical_address
  );
END;
$function$;

ALTER FUNCTION marketplace.get_seller_contact_for_unlock(uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION marketplace.get_seller_contact_for_unlock(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT EXECUTE ON FUNCTION marketplace.get_seller_contact_for_unlock(uuid)
    TO "anon", "authenticated", "service_role";

COMMIT;

-- ============================================================================
-- 20261124000002_marketplace_public_seller_authorized_manager
-- ----------------------------------------------------------------------------
-- Replace the public seller identity projection with an authorized-manager
-- resolution. Seller identity remains listing-scoped and public-safe.
--
-- Manager precedence:
--   1. the entity's canonical primary contact, only when they are an active
--      authorized Owner/Manager member;
--   2. the entity's canonical owner, only when they are an active authorized
--      Owner/Manager member.
--
-- If neither canonical profile is an active authorized manager, no manager
-- first name is returned. The function never falls back to an arbitrary
-- profile, listing creator, current user or raw owner_id.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION marketplace.get_public_listing_sellers(
    p_listing_ids uuid[]
)
RETURNS TABLE (
    listing_id uuid,
    seller_entity_id uuid,
    seller_entity_name text,
    seller_public_first_name text,
    seller_kind text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core', 'users', 'marketplace', 'commerce'
AS $function$
  SELECT
    l.id AS listing_id,
    l.entity_id AS seller_entity_id,
    CASE
      WHEN e.entity_type = 'individual_pro' THEN NULL
      ELSE e.name
    END AS seller_entity_name,
    manager.first_name AS seller_public_first_name,
    CASE
      WHEN e.entity_type = 'individual_pro' THEN 'individual'
      ELSE 'entity'
    END AS seller_kind
  FROM marketplace.listings AS l
  JOIN core.entities AS e
    ON e.id = l.entity_id
  LEFT JOIN LATERAL (
    SELECT p.first_name
    FROM core.entity_roles AS er
    JOIN core.user_roles AS r
      ON r.id = er.role_id
     AND r.is_active = true
     AND lower(r.name) IN ('owner', 'manager')
    JOIN core.entity_members AS em
      ON em.entity_id = er.entity_id
     AND em.profile_id = er.profile_id
     AND em.role_id = er.role_id
     AND em.is_active = true
     AND em.membership_status = 'active'
     AND em.can_manage = true
    JOIN users.profiles AS p
      ON p.id = er.profile_id
     AND p.is_active = true
     AND p.account_status = 'active'
    WHERE er.entity_id = e.id
      AND er.is_active = true
      AND er.profile_id IN (e.primary_contact_profile_id, e.owner_id)
    ORDER BY
      CASE
        WHEN er.profile_id = e.primary_contact_profile_id THEN 0
        ELSE 1
      END,
      CASE WHEN lower(r.name) = 'owner' THEN 0 ELSE 1 END,
      er.assigned_at NULLS LAST,
      er.id
    LIMIT 1
  ) AS manager ON true
  WHERE l.id = ANY (COALESCE(p_listing_ids, ARRAY[]::uuid[]))
    AND cardinality(COALESCE(p_listing_ids, ARRAY[]::uuid[]))
        BETWEEN 1 AND 200
    AND (
      l.status = 'active'
      OR commerce.can_access_stock(l.entity_id)
    );
$function$;

ALTER FUNCTION marketplace.get_public_listing_sellers(uuid[])
    OWNER TO postgres;

REVOKE ALL ON FUNCTION marketplace.get_public_listing_sellers(uuid[])
    FROM PUBLIC, "anon", "authenticated", "service_role";

GRANT EXECUTE ON FUNCTION marketplace.get_public_listing_sellers(uuid[])
    TO "anon", "authenticated", "service_role";

COMMENT ON FUNCTION marketplace.get_public_listing_sellers(uuid[]) IS
    'Read-only public listing seller identity. Returns canonical entity name and the first name of an active authorized Owner/Manager only; never contact data or full canonical profile names.';

COMMIT;

-- ============================================================================
-- 20261124000001_marketplace_public_seller_identity
-- ----------------------------------------------------------------------------
-- Controlled public read contract for Marketplace seller presentation identity.
--
-- Canonical identity remains in users.profiles + core.entities. Those tables are
-- intentionally private. This SECURITY DEFINER function returns only the safe
-- display fields needed by public Marketplace listings and is scoped by the
-- caller-supplied listing ids. It never exposes contact details, full names,
-- auth ids, membership rows or arbitrary entity/profile lookup by id.
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
    p.first_name AS seller_public_first_name,
    CASE
      WHEN e.entity_type = 'individual_pro' THEN 'individual'
      ELSE 'entity'
    END AS seller_kind
  FROM marketplace.listings AS l
  JOIN core.entities AS e
    ON e.id = l.entity_id
  LEFT JOIN users.profiles AS p
    ON p.id = COALESCE(e.primary_contact_profile_id, e.owner_id)
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
    'Read-only public seller presentation identity for Marketplace listings. Returns only seller entity name, public first name and seller kind; never contact or canonical full-name data.';

COMMIT;

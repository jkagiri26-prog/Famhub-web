-- ============================================================================
-- 20261116000007_premium_capability_assertion
-- ----------------------------------------------------------------------------
-- Reusable server-side assertion over the existing canonical entitlement
-- resolver. No new entitlement table, cache, or capability registry.
--
-- A future premium Edge Function/RPC can call this with the caller JWT:
--   system.assert_subscription_capability('farm_analytics')
--
-- The caller identity and entity authorization remain owned by the existing
-- resolver. UI visibility is not a security boundary.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION "system"."has_subscription_capability"(
    "p_capability" text,
    "p_entity_id" uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, system, auth
AS $function$
DECLARE
    v_capability text := lower(btrim(coalesce(p_capability, '')));
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    IF v_capability = '' THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
          FROM system.resolve_my_subscription_entitlements(p_entity_id) AS entitlement
         WHERE entitlement.is_active IS TRUE
           AND v_capability = ANY (entitlement.capabilities)
    );
END;
$function$;

REVOKE ALL ON FUNCTION "system"."has_subscription_capability"(text, uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."has_subscription_capability"(text, uuid)
    TO "authenticated";

CREATE OR REPLACE FUNCTION "system"."assert_subscription_capability"(
    "p_capability" text,
    "p_entity_id" uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, system, auth
AS $function$
BEGIN
    IF NOT system.has_subscription_capability(p_capability, p_entity_id) THEN
        RAISE EXCEPTION 'Required subscription capability is not available'
            USING ERRCODE = '42501';
    END IF;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."assert_subscription_capability"(text, uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."assert_subscription_capability"(text, uuid)
    TO "authenticated";

COMMENT ON FUNCTION "system"."has_subscription_capability"(text, uuid)
    IS 'Returns true only when the authenticated caller has an active subscription granting the exact canonical capability. Uses the existing entitlement resolver.';

COMMENT ON FUNCTION "system"."assert_subscription_capability"(text, uuid)
    IS 'Raises 42501 unless the authenticated caller has the required canonical capability. Intended for premium server-service boundaries invoked with the caller JWT.';

COMMIT;

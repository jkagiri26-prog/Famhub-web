-- ============================================================================
-- 20261116000004_subscription_entitlement_resolver
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Canonical, backend-authoritative subscription capability resolver.
--
-- USES EXISTING CANONICAL DATA
--   system.subscription_plans.features_json
--   system.billing_accounts
--   finance.subscription_cycles
--   system.active_subscriptions
--   system.plan_capabilities(...)
--
-- SECURITY
--   * Caller is derived from auth.uid().
--   * Entity access requires active entity membership with can_manage.
--   * No plan id, price, status, or entitlement is accepted from the client.
--   * Capabilities are granted only while the active subscription is active
--     and now() is inside its inclusive start / exclusive end boundaries.
--   * No internal Finance ids, invoices, obligations, or ledger data returned.
-- ============================================================================

BEGIN;

-- Canonical extraction from the existing plan metadata. Supported shapes:
--   {"capabilities": ["farm.management", "marketplace.listings"]}
--   {"capabilities": {"farm.management": true}}
--   {"features": {"farm.management": true}}
--   {"farm.management": true}
CREATE OR REPLACE FUNCTION "system"."plan_capabilities"(
    "p_features" jsonb
)
RETURNS SETOF text
LANGUAGE sql
IMMUTABLE
AS $function$
    SELECT DISTINCT lower(btrim(capability))
      FROM (
        SELECT value AS capability
          FROM jsonb_array_elements_text(
              CASE
                WHEN jsonb_typeof(p_features->'capabilities') = 'array'
                  THEN p_features->'capabilities'
                ELSE '[]'::jsonb
              END
          )
        UNION ALL
        SELECT key
          FROM jsonb_each(p_features)
         WHERE jsonb_typeof(value) = 'boolean' AND value = 'true'::jsonb
        UNION ALL
        SELECT key
          FROM jsonb_each(
              CASE
                WHEN jsonb_typeof(p_features->'capabilities') = 'object'
                  THEN p_features->'capabilities'
                ELSE '{}'::jsonb
              END
          )
         WHERE jsonb_typeof(value) = 'boolean' AND value = 'true'::jsonb
        UNION ALL
        SELECT key
          FROM jsonb_each(
              CASE
                WHEN jsonb_typeof(p_features->'features') = 'object'
                  THEN p_features->'features'
                ELSE '{}'::jsonb
              END
          )
         WHERE jsonb_typeof(value) = 'boolean' AND value = 'true'::jsonb
      ) AS capabilities
     WHERE capability IS NOT NULL AND btrim(capability) <> '';
$function$;

REVOKE ALL ON FUNCTION "system"."plan_capabilities"(jsonb)
    FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION "system"."resolve_my_subscription_entitlements"(
    "p_entity_id" uuid DEFAULT NULL
)
RETURNS TABLE (
    "entity_id" uuid,
    "billing_account_id" uuid,
    "billing_owner_type" text,
    "subscription_cycle_id" uuid,
    "plan_id" uuid,
    "plan_key" text,
    "plan_name" text,
    "billing_cycle" text,
    "cycle_status" text,
    "active_status" text,
    "period_start" date,
    "period_end" date,
    "start_date" timestamp with time zone,
    "end_date" timestamp with time zone,
    "is_active" boolean,
    "is_future" boolean,
    "is_expired" boolean,
    "capabilities" text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, system, finance, core, users, auth
AS $function$
DECLARE
    v_profile_id uuid;
    v_entity_id uuid;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    SELECT p.id INTO v_profile_id
      FROM users.profiles AS p
     WHERE p.auth_user_id = auth.uid()
       AND p.is_active IS TRUE
       AND p.account_status = 'active';

    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Active authenticated profile not found'
            USING ERRCODE = '42501';
    END IF;

    v_entity_id := COALESCE(p_entity_id, core.get_active_entity());

    IF v_entity_id IS NULL THEN
        SELECT e.id INTO v_entity_id
          FROM core.entities AS e
         WHERE e.owner_id = v_profile_id
           AND e.entity_type = 'individual_pro'
           AND e.is_active IS TRUE
         ORDER BY e.created_at, e.id
         LIMIT 1;
    END IF;

    IF v_entity_id IS NULL THEN
        RAISE EXCEPTION 'No active entity context is available'
            USING ERRCODE = '55000';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM core.entities AS e
         WHERE e.id = v_entity_id
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
        RAISE EXCEPTION 'Caller cannot access this entity subscription'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT ba.entity_id,
           ba.id,
           CASE
             WHEN ba.account_type = 'individual' THEN 'individual'
             ELSE 'entity'
           END,
           cycle.id,
           plan.id,
           plan.plan_key,
           plan.plan_name,
           plan.billing_cycle,
           cycle.status,
           active.status,
           cycle.period_start,
           cycle.period_end,
           active.start_date,
           active.end_date,
           (
             cycle.status = 'active'
             AND active.status = 'active'
             AND active.start_date <= now()
             AND (active.end_date IS NULL OR now() < active.end_date)
           ),
           (
             cycle.status = 'active'
             AND active.status = 'active'
             AND active.start_date > now()
           ),
           (
             active.status = 'expired'
             OR (active.end_date IS NOT NULL AND active.end_date <= now())
           ),
           CASE
             WHEN cycle.status = 'active'
               AND active.status = 'active'
               AND active.start_date <= now()
               AND (active.end_date IS NULL OR now() < active.end_date)
               THEN ARRAY(SELECT system.plan_capabilities(plan.features_json))
             ELSE ARRAY[]::text[]
           END
      FROM system.billing_accounts AS ba
      JOIN finance.subscription_cycles AS cycle
        ON cycle.billing_account_id = ba.id
      JOIN system.subscription_plans AS plan
        ON plan.id = cycle.plan_id
      JOIN system.active_subscriptions AS active
        ON active.id = cycle.active_subscription_id
     WHERE ba.entity_id = v_entity_id
       AND ba.status = 'active'
       AND (
             (
               ba.account_type = 'individual'
               AND ba.profile_id = v_profile_id
             )
             OR
             (
               ba.account_type <> 'individual'
               AND EXISTS (
                   SELECT 1
                     FROM core.entity_members AS em
                    WHERE em.entity_id = ba.entity_id
                      AND em.profile_id = v_profile_id
                      AND em.is_active IS TRUE
                      AND em.membership_status = 'active'
                      AND em.can_manage IS TRUE
               )
             )
           )
     ORDER BY cycle.created_at DESC, cycle.id DESC;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."resolve_my_subscription_entitlements"(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."resolve_my_subscription_entitlements"(uuid)
    TO "authenticated";

COMMENT ON FUNCTION "system"."resolve_my_subscription_entitlements"(uuid)
    IS 'Backend-authoritative capabilities for the caller individual/entity subscription. Uses actual active subscription timestamps; no annual-duration assumption and no client plan/status input.';

COMMIT;

-- ============================================================================
-- 20261116000006_subscription_centre_state_frequency
-- ----------------------------------------------------------------------------
-- Adds the canonical plan billing frequency to the existing customer-safe
-- Subscription Centre read RPC. Read-only; no Finance/payment/entitlement
-- state is changed.
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS "system"."get_my_subscription_centre"();

CREATE FUNCTION "system"."get_my_subscription_centre"()
RETURNS TABLE (
    "billing_account_id" uuid,
    "billing_owner_type" text,
    "plan_id" uuid,
    "plan_key" text,
    "plan_name" text,
    "billing_cycle" text,
    "amount" numeric,
    "currency" text,
    "subscription_cycle_id" uuid,
    "cycle_status" text,
    "period_start" date,
    "period_end" date,
    "settled_at" timestamp with time zone,
    "active_status" text,
    "active_start" timestamp with time zone,
    "active_end" timestamp with time zone,
    "is_active" boolean,
    "is_pending" boolean,
    "payment_attempt_status" text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, system, finance, core, users, auth
AS $function$
DECLARE
    v_profile_id uuid;
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

    RETURN QUERY
    SELECT ba.id,
           CASE
             WHEN ba.account_type = 'individual' THEN 'individual'
             ELSE 'entity'
           END,
           plan.id, plan.plan_key, plan.plan_name, plan.billing_cycle,
           cycle.amount, cycle.currency,
           cycle.id, cycle.status, cycle.period_start, cycle.period_end,
           cycle.settled_at,
           active.status, active.start_date, active.end_date,
           (
             active.status = 'active'
             AND active.start_date <= now()
             AND (active.end_date IS NULL OR now() < active.end_date)
           ),
           (
             cycle.status = 'pending'
             AND (active.id IS NULL OR active.status = 'pending')
           ),
           latest_attempt.status
      FROM system.billing_accounts AS ba
      JOIN finance.subscription_cycles AS cycle
        ON cycle.billing_account_id = ba.id
      JOIN system.subscription_plans AS plan
        ON plan.id = cycle.plan_id
      LEFT JOIN system.active_subscriptions AS active
        ON active.id = cycle.active_subscription_id
      LEFT JOIN LATERAL (
          SELECT pa.status
            FROM finance.payment_attempts AS pa
           WHERE pa.obligation_id = cycle.obligation_id
           ORDER BY pa.created_at DESC, pa.id DESC
           LIMIT 1
      ) AS latest_attempt ON TRUE
     WHERE (
             ba.account_type = 'individual'
             AND ba.profile_id = v_profile_id
           )
        OR (
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
     ORDER BY cycle.created_at DESC, cycle.id DESC;
END;
$function$;

REVOKE ALL ON FUNCTION "system"."get_my_subscription_centre"()
    FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "system"."get_my_subscription_centre"()
    TO "authenticated";

COMMENT ON FUNCTION "system"."get_my_subscription_centre"()
    IS 'Authenticated customer-safe subscription status/history with canonical plan billing frequency. No internal Finance ids or ledger data.';

COMMIT;

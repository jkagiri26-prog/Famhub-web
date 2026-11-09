-- ============================================================================
-- 20261109000000_capture_finance_dependencies
-- Captures the minimum deployed dependency required by the Finance schema:
--   * private.is_active_commercial_member(uuid, boolean)
--   * private.can_access_commercial_entities(uuid, uuid)
--   * commerce.commercial_orders
--
-- Scope note:
--   The deployed backend also contains the wider commercial-order engine
--   (commercial_order_items, commercial_stock_reservations, fulfillments,
--   fulfillment_items, and related commerce routines). Those objects are NOT
--   captured here. This migration captures only what Finance requires.
--
-- Schema-only: no customer, order, payment, ledger, or journal rows.
-- Captured from the linked Supabase project on 2026-11-09.
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS "private";
GRANT USAGE ON SCHEMA "private" TO "authenticated";

-- ----------------------------------------------------------------------------
-- Private authorization helpers used by commerce.commercial_orders RLS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.is_active_commercial_member(
  p_entity_id uuid,
  p_seller_action boolean DEFAULT false
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM users.profiles p
    JOIN core.entity_members em ON em.profile_id = p.id
    JOIN core.entities e ON e.id = em.entity_id
    WHERE p.auth_user_id = auth.uid() AND p.is_active IS TRUE AND p.account_status = 'active'
      AND e.id = p_entity_id AND e.is_active IS TRUE
      AND em.is_active IS TRUE AND em.membership_status = 'active'
      AND (NOT p_seller_action OR em.can_sell IS TRUE OR em.can_manage IS TRUE)
  );
$function$;

CREATE OR REPLACE FUNCTION private.can_access_commercial_entities(
  p_buyer_entity_id uuid,
  p_seller_entity_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.is_active_commercial_member(p_buyer_entity_id, false)
      OR private.is_active_commercial_member(p_seller_entity_id, false);
$function$;

REVOKE ALL ON FUNCTION private.is_active_commercial_member(uuid, boolean)
  FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION private.can_access_commercial_entities(uuid, uuid)
  FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION private.is_active_commercial_member(uuid, boolean)
  TO "authenticated";
GRANT EXECUTE ON FUNCTION private.can_access_commercial_entities(uuid, uuid)
  TO "authenticated";

-- ----------------------------------------------------------------------------
-- Commerce commercial orders (minimum Finance dependency)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "commerce"."commercial_orders" (
    "id" uuid DEFAULT public.uuid_generate_v7() NOT NULL,
    "buyer_entity_id" uuid NOT NULL,
    "seller_entity_id" uuid NOT NULL,
    "status" text DEFAULT 'placed'::text NOT NULL,
    "currency" text NOT NULL,
    "subtotal_amount" numeric(20,4) NOT NULL,
    "discount_amount" numeric(20,4) DEFAULT 0 NOT NULL,
    "tax_amount" numeric(20,4) DEFAULT 0 NOT NULL,
    "shipping_amount" numeric(20,4) DEFAULT 0 NOT NULL,
    "total_amount" numeric(20,4) NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    "confirmed_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "created_by" uuid,
    "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "idempotency_key" text NOT NULL,
    "request_hash" text NOT NULL,
    CONSTRAINT "commercial_orders_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "commercial_orders_buyer_idempotency_key_key" UNIQUE ("buyer_entity_id", "idempotency_key"),
    CONSTRAINT "commercial_orders_buyer_entity_id_fkey" FOREIGN KEY ("buyer_entity_id") REFERENCES "core"."entities"("id"),
    CONSTRAINT "commercial_orders_seller_entity_id_fkey" FOREIGN KEY ("seller_entity_id") REFERENCES "core"."entities"("id"),
    CONSTRAINT "commercial_orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"."profiles"("id"),
    CONSTRAINT "commercial_orders_currency_check" CHECK ("currency" ~ '^[A-Z]{3}$'::text),
    CONSTRAINT "commercial_orders_discount_amount_check" CHECK ("discount_amount" >= 0::numeric),
    CONSTRAINT "commercial_orders_discount_within_subtotal" CHECK ("discount_amount" <= "subtotal_amount"),
    CONSTRAINT "commercial_orders_metadata_check" CHECK (jsonb_typeof("metadata") = 'object'::text),
    CONSTRAINT "commercial_orders_not_same_entity" CHECK ("buyer_entity_id" <> "seller_entity_id"),
    CONSTRAINT "commercial_orders_shipping_amount_check" CHECK ("shipping_amount" >= 0::numeric),
    CONSTRAINT "commercial_orders_status_check" CHECK ("status" = ANY (ARRAY['draft'::text, 'placed'::text, 'confirmed'::text, 'cancelled'::text, 'completed'::text])),
    CONSTRAINT "commercial_orders_subtotal_amount_check" CHECK ("subtotal_amount" >= 0::numeric),
    CONSTRAINT "commercial_orders_tax_amount_check" CHECK ("tax_amount" >= 0::numeric),
    CONSTRAINT "commercial_orders_total_amount_check" CHECK ("total_amount" >= 0::numeric),
    CONSTRAINT "commercial_orders_total_check" CHECK ("total_amount" = ("subtotal_amount" - "discount_amount" + "tax_amount" + "shipping_amount"))
);

ALTER TABLE "commerce"."commercial_orders" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "commercial_orders_member_read" ON "commerce"."commercial_orders";
CREATE POLICY "commercial_orders_member_read"
  ON "commerce"."commercial_orders"
  FOR SELECT
  TO "authenticated"
  USING (private.can_access_commercial_entities("buyer_entity_id", "seller_entity_id"));

REVOKE ALL PRIVILEGES ON TABLE "commerce"."commercial_orders" FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT SELECT ON TABLE "commerce"."commercial_orders" TO "authenticated";
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
  ON TABLE "commerce"."commercial_orders" TO "service_role";

COMMIT;

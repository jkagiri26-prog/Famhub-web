-- Marketplace order shipping/delivery lifecycle.
--
-- confirmed -> shipped   seller
-- shipped   -> delivered buyer
--
-- Stock was physically consumed exactly once at accepted -> confirmed.
-- Shipping and delivery are status-only transitions and must not touch
-- commerce.stock_registry, commerce.stock_movements or stock_reservations.
-- Payment/Finance remains independent.

ALTER TABLE commerce.orders
  ADD COLUMN IF NOT EXISTS shipped_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

COMMENT ON COLUMN commerce.orders.shipped_at IS
  'When the seller marked the confirmed order shipped.';
COMMENT ON COLUMN commerce.orders.delivered_at IS
  'When the buyer confirmed delivery of a shipped order.';

CREATE OR REPLACE FUNCTION commerce.ship_listing_order(
  p_order_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS commerce.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_profile_id uuid;
  v_entity_id uuid;
  v_order commerce.orders%ROWTYPE;
  v_reason text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  v_profile_id := core.current_profile_id();
  IF v_profile_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM users.profiles AS p
    WHERE p.id = v_profile_id
      AND p.is_active = true
      AND p.account_status = 'active'
      AND p.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'active seller profile required' USING ERRCODE = '42501';
  END IF;

  v_entity_id := core.get_active_entity();
  IF v_entity_id IS NULL THEN
    RAISE EXCEPTION 'active seller entity required' USING ERRCODE = '42501';
  END IF;

  SELECT *
    INTO v_order
  FROM commerce.orders AS o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_entity_id IS DISTINCT FROM v_order.seller_entity_id
     OR NOT commerce.can_access_stock(v_order.seller_entity_id) THEN
    RAISE EXCEPTION 'not authorized to ship this order' USING ERRCODE = '42501';
  END IF;

  IF v_order.status = 'shipped' THEN
    RETURN v_order;
  END IF;

  IF v_order.status <> 'confirmed' THEN
    RAISE EXCEPTION 'order cannot be shipped from status %', v_order.status
      USING ERRCODE = '22023';
  END IF;

  v_reason := NULLIF(btrim(COALESCE(p_reason, '')), '');

  UPDATE commerce.orders
  SET status = 'shipped',
      shipped_at = now(),
      status_changed_by_profile_id = v_profile_id,
      status_reason = v_reason,
      updated_at = now()
  WHERE id = v_order.id
  RETURNING * INTO v_order;

  RETURN v_order;
END;
$function$;

COMMENT ON FUNCTION commerce.ship_listing_order(uuid, text) IS
  'Seller marks a confirmed order shipped. Status-only: no stock or payment mutation.';

REVOKE ALL ON FUNCTION commerce.ship_listing_order(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.ship_listing_order(uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION commerce.confirm_listing_order_delivery(
  p_order_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS commerce.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'users'
AS $function$
DECLARE
  v_profile_id uuid;
  v_entity_id uuid;
  v_order commerce.orders%ROWTYPE;
  v_reason text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  v_profile_id := core.current_profile_id();
  IF v_profile_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM users.profiles AS p
    WHERE p.id = v_profile_id
      AND p.is_active = true
      AND p.account_status = 'active'
      AND p.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'active buyer profile required' USING ERRCODE = '42501';
  END IF;

  v_entity_id := core.get_active_entity();
  IF v_entity_id IS NULL THEN
    RAISE EXCEPTION 'active buyer entity required' USING ERRCODE = '42501';
  END IF;

  SELECT *
    INTO v_order
  FROM commerce.orders AS o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_profile_id IS DISTINCT FROM v_order.buyer_id
     OR v_entity_id IS DISTINCT FROM v_order.buyer_entity_id THEN
    RAISE EXCEPTION 'not authorized to confirm delivery for this order'
      USING ERRCODE = '42501';
  END IF;

  IF v_order.status = 'delivered' THEN
    RETURN v_order;
  END IF;

  IF v_order.status <> 'shipped' THEN
    RAISE EXCEPTION 'order cannot be delivered from status %', v_order.status
      USING ERRCODE = '22023';
  END IF;

  v_reason := NULLIF(btrim(COALESCE(p_reason, '')), '');

  UPDATE commerce.orders
  SET status = 'delivered',
      delivered_at = now(),
      delivery_date = now(),
      status_changed_by_profile_id = v_profile_id,
      status_reason = v_reason,
      updated_at = now()
  WHERE id = v_order.id
  RETURNING * INTO v_order;

  RETURN v_order;
END;
$function$;

COMMENT ON FUNCTION commerce.confirm_listing_order_delivery(uuid, text) IS
  'Buyer confirms delivery of a shipped order. Status-only: no stock or payment mutation.';

REVOKE ALL ON FUNCTION commerce.confirm_listing_order_delivery(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.confirm_listing_order_delivery(uuid, text)
  TO authenticated;

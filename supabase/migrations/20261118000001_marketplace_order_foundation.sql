-- Marketplace order foundation.
--
-- Scope:
--   * extends the canonical commerce.orders / commerce.order_items foundation;
--   * adds a buyer order-creation RPC that trusts only the authenticated
--     session and canonical marketplace/commerce rows;
--   * reuses the existing stock reservation trigger and stock_reservations;
--   * deliberately does not implement payment, M-Pesa, Finance accounting, or
--     seller fulfilment actions.
--
-- Lifecycle:
--   pending -> confirmed (accepted) -> delivered (fulfilled)
--   terminal alternatives already supported by commerce.orders:
--   cancelled, returned.
--   payment_status is explicitly NOT the order lifecycle.

-- ---------------------------------------------------------------------------
-- 1. Canonical order identity, currencies and idempotency.
-- ---------------------------------------------------------------------------
ALTER TABLE commerce.orders
  ADD COLUMN IF NOT EXISTS buyer_entity_id uuid REFERENCES core.entities(id),
  ADD COLUMN IF NOT EXISTS seller_entity_id uuid REFERENCES core.entities(id),
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'KES',
  ADD COLUMN IF NOT EXISTS idempotency_key text;

ALTER TABLE commerce.orders
  DROP CONSTRAINT IF EXISTS orders_distinct_parties_check;
ALTER TABLE commerce.orders
  ADD CONSTRAINT orders_distinct_parties_check
  CHECK (
    buyer_entity_id IS NULL
    OR seller_entity_id IS NULL
    OR buyer_entity_id <> seller_entity_id
  ) NOT VALID;

COMMENT ON COLUMN commerce.orders.buyer_entity_id IS
  'Buyer entity derived by the backend from the authenticated active entity context.';
COMMENT ON COLUMN commerce.orders.seller_entity_id IS
  'Seller entity derived by the backend from marketplace.listings.entity_id.';
COMMENT ON COLUMN commerce.orders.currency IS
  'Authoritative listing currency captured at order creation.';
COMMENT ON COLUMN commerce.orders.idempotency_key IS
  'Buyer-scoped idempotency key for safe order-creation retries; never client financial data.';

CREATE UNIQUE INDEX IF NOT EXISTS orders_buyer_idempotency_key_uidx
  ON commerce.orders (buyer_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS orders_buyer_entity_order_date_idx
  ON commerce.orders (buyer_entity_id, order_date DESC);
CREATE INDEX IF NOT EXISTS orders_seller_entity_order_date_idx
  ON commerce.orders (seller_entity_id, order_date DESC);
CREATE INDEX IF NOT EXISTS orders_listing_id_idx
  ON commerce.orders (listing_id);

-- Order creation is server-owned. Direct table writes by browser roles cannot
-- be allowed to supply buyer/seller/price/currency/stock values.
REVOKE INSERT ON commerce.orders FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON commerce.order_items FROM anon, authenticated;

DROP POLICY IF EXISTS "Supplier creates order and picks buyer"
  ON commerce.orders;

-- The legacy creation helpers predate buyer/seller/listing validation and are
-- not a safe client entry point. Keep service_role access only.
REVOKE EXECUTE ON FUNCTION commerce.create_order(uuid, numeric)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION commerce.create_order_with_reservation(uuid, numeric)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Secure buyer order creation.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commerce.create_listing_order(
  p_listing_id uuid,
  p_quantity numeric,
  p_idempotency_key text
)
RETURNS commerce.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'commerce', 'core', 'marketplace', 'users'
AS $function$
DECLARE
  v_profile_id uuid;
  v_buyer_entity_id uuid;
  v_key text;
  v_listing marketplace.listings%ROWTYPE;
  v_stock commerce.stock_registry%ROWTYPE;
  v_supplier_id uuid;
  v_supplier_count integer;
  v_existing commerce.orders%ROWTYPE;
  v_order commerce.orders%ROWTYPE;
  v_total numeric(15,2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_listing_id IS NULL THEN
    RAISE EXCEPTION 'listing_id is required' USING ERRCODE = '22023';
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'quantity must be greater than zero' USING ERRCODE = '22023';
  END IF;

  IF p_quantity <> round(p_quantity, 2) THEN
    RAISE EXCEPTION 'quantity must have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  v_key := btrim(COALESCE(p_idempotency_key, ''));
  IF v_key = '' THEN
    RAISE EXCEPTION 'idempotency_key is required' USING ERRCODE = '22023';
  END IF;

  v_profile_id := core.current_profile_id();
  IF v_profile_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM users.profiles AS p
    WHERE p.id = v_profile_id
      AND p.is_active = true
      AND p.account_status = 'active'
      AND p.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'active buyer profile required' USING ERRCODE = '42501';
  END IF;

  v_buyer_entity_id := core.get_active_entity();
  IF v_buyer_entity_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM core.entities AS e
    WHERE e.id = v_buyer_entity_id
      AND e.is_active = true
  ) THEN
    RAISE EXCEPTION 'active buyer entity required' USING ERRCODE = '42501';
  END IF;

  -- Serialize retries for the same buyer/key. This is the duplicate-order
  -- boundary; different buyers and different keys proceed independently.
  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      'commerce.create_listing_order:' || v_profile_id::text || ':' || v_key,
      0
    )
  );

  SELECT *
    INTO v_existing
  FROM commerce.orders AS o
  WHERE o.buyer_id = v_profile_id
    AND o.idempotency_key = v_key;

  IF FOUND THEN
    IF v_existing.listing_id <> p_listing_id
       OR v_existing.quantity <> p_quantity THEN
      RAISE EXCEPTION 'idempotency key reused with different order data'
        USING ERRCODE = '22023';
    END IF;
    RETURN v_existing;
  END IF;

  -- Listing, price, currency, seller and stock identity are all read from the
  -- canonical row. The request supplies only listing id, quantity and a retry
  -- key.
  SELECT *
    INTO v_listing
  FROM marketplace.listings AS l
  WHERE l.id = p_listing_id
  FOR SHARE;

  IF NOT FOUND OR v_listing.status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'listing not found or inactive' USING ERRCODE = 'P0002';
  END IF;

  IF v_listing.price_per_unit IS NULL OR v_listing.price_per_unit <= 0 THEN
    RAISE EXCEPTION 'listing price is invalid' USING ERRCODE = 'P0002';
  END IF;

  IF v_listing.currency IS NULL OR btrim(v_listing.currency) = '' THEN
    RAISE EXCEPTION 'listing currency is invalid' USING ERRCODE = 'P0002';
  END IF;

  IF v_listing.stock_id IS NULL THEN
    RAISE EXCEPTION 'listing has no managed stock' USING ERRCODE = 'P0002';
  END IF;

  IF v_buyer_entity_id = v_listing.entity_id THEN
    RAISE EXCEPTION 'buyer cannot order own listing' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM core.entities AS e
    WHERE e.id = v_listing.entity_id
      AND e.is_active = true
      AND COALESCE(e.verification_status, 'pending')
          NOT IN ('suspended', 'rejected')
  ) THEN
    RAISE EXCEPTION 'seller is inactive' USING ERRCODE = 'P0002';
  END IF;

  SELECT count(*)::integer
    INTO v_supplier_count
  FROM commerce.business_profiles AS bp
  WHERE bp.entity_id = v_listing.entity_id
    AND bp.is_active = true
    AND bp.user_active = true
    AND bp.deleted_at IS NULL
    AND bp.verification_status = 'verified';

  IF v_supplier_count = 0 THEN
    RAISE EXCEPTION 'seller has no active verified business profile'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_supplier_count > 1 THEN
    RAISE EXCEPTION 'seller business profile is ambiguous' USING ERRCODE = 'P0002';
  END IF;

  SELECT bp.id
    INTO v_supplier_id
  FROM commerce.business_profiles AS bp
  WHERE bp.entity_id = v_listing.entity_id
    AND bp.is_active = true
    AND bp.user_active = true
    AND bp.deleted_at IS NULL
    AND bp.verification_status = 'verified'
  ORDER BY bp.id
  LIMIT 1;

  SELECT *
    INTO v_stock
  FROM commerce.stock_registry AS sr
  WHERE sr.id = v_listing.stock_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing stock not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_stock.entity_id <> v_listing.entity_id
     OR (v_stock.variant_id IS DISTINCT FROM v_listing.variant_id) THEN
    RAISE EXCEPTION 'listing stock identity is inconsistent' USING ERRCODE = 'P0002';
  END IF;

  IF v_stock.status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'listing stock is not active' USING ERRCODE = 'P0002';
  END IF;

  IF COALESCE(v_stock.quantity, 0) - COALESCE(v_stock.reserved_quantity, 0)
     < p_quantity THEN
    RAISE EXCEPTION 'insufficient available stock' USING ERRCODE = 'P0002';
  END IF;

  v_total := round(p_quantity * v_listing.price_per_unit, 2);
  IF v_total <= 0 THEN
    RAISE EXCEPTION 'order total is invalid' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO commerce.orders (
    buyer_id,
    listing_id,
    supplier_id,
    quantity,
    total_amount,
    status,
    payment_status,
    entity_id,
    buyer_entity_id,
    seller_entity_id,
    currency,
    idempotency_key,
    order_kind,
    unit_id
  )
  VALUES (
    v_profile_id,
    p_listing_id,
    v_supplier_id,
    p_quantity,
    v_total,
    'pending',
    'pending',
    v_listing.entity_id,
    v_buyer_entity_id,
    v_listing.entity_id,
    v_listing.currency,
    v_key,
    'stock',
    v_listing.unit_id
  )
  RETURNING * INTO v_order;

  -- The existing AFTER INSERT trigger commerce.reserve_stock() performs the
  -- stock_registry.reserved_quantity update and raises on insufficient stock.
  -- Do not also update reserved_quantity here.
  INSERT INTO commerce.order_items (
    order_id,
    listing_id,
    product_id,
    quantity,
    price_per_unit,
    stock_id,
    variant_id,
    unit_id
  )
  VALUES (
    v_order.id,
    p_listing_id,
    v_stock.product_id,
    p_quantity,
    v_listing.price_per_unit,
    v_listing.stock_id,
    v_listing.variant_id,
    v_listing.unit_id
  );

  -- Canonical reservation record used by the existing cancellation/payment
  -- release paths. It intentionally does not mutate stock a second time.
  INSERT INTO commerce.stock_reservations (
    order_id,
    stock_id,
    listing_id,
    quantity,
    status
  )
  VALUES (
    v_order.id,
    v_listing.stock_id,
    p_listing_id,
    p_quantity,
    'reserved'
  );

  RETURN v_order;
END;
$function$;

COMMENT ON FUNCTION commerce.create_listing_order(uuid, numeric, text) IS
  'Buyer order creation from an active marketplace listing. Derives buyer, seller, price, currency, stock identity and totals server-side; reserves via the existing stock trigger.';

REVOKE ALL ON FUNCTION commerce.create_listing_order(uuid, numeric, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION commerce.create_listing_order(uuid, numeric, text)
  TO authenticated;

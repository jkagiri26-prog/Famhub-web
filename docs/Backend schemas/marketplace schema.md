-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE marketplace.markets (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  name text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  location_id uuid,
  CONSTRAINT markets_pkey PRIMARY KEY (id)
);
CREATE TABLE marketplace.buyer_pricing (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  action text CHECK (action = 'contact_unlock'::text),
  amount numeric NOT NULL,
  currency text DEFAULT 'KES'::text,
  active boolean DEFAULT true,
  effective_from timestamp without time zone DEFAULT now(),
  CONSTRAINT buyer_pricing_pkey PRIMARY KEY (id)
);
CREATE TABLE marketplace.listings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  unit_id uuid,
  price_per_unit numeric NOT NULL,
  currency text NOT NULL DEFAULT 'KES'::text,
  location_id uuid NOT NULL,
  status text DEFAULT 'active'::text,
  contact_visibility text DEFAULT 'locked'::text CHECK (contact_visibility = ANY (ARRAY['locked'::text, 'open'::text])),
  is_promoted boolean DEFAULT false,
  promoted_until timestamp with time zone,
  images jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  stock_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  CONSTRAINT listings_pkey PRIMARY KEY (id),
  CONSTRAINT listings_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT listings_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id),
  CONSTRAINT fk_listing_location FOREIGN KEY (location_id) REFERENCES core.locations(id),
  CONSTRAINT fk_listing_unit FOREIGN KEY (unit_id) REFERENCES core.units(id),
  CONSTRAINT listings_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES commerce.stock_registry(id)
);
CREATE TABLE marketplace.contact_unlocks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL,
  amount numeric NOT NULL,
  currency text DEFAULT 'KES'::text,
  payment_status text DEFAULT 'pending'::text CHECK (payment_status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'refunded'::text])),
  unlocked boolean DEFAULT false,
  valid_until timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  entity_id uuid NOT NULL,
  CONSTRAINT contact_unlocks_pkey PRIMARY KEY (id),
  CONSTRAINT fk_unlock_listing FOREIGN KEY (listing_id) REFERENCES marketplace.listings(id),
  CONSTRAINT contact_unlocks_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE marketplace.market_prices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  location_id uuid,
  price numeric NOT NULL,
  unit_id uuid,
  recorded_on date DEFAULT CURRENT_DATE,
  created_at timestamp with time zone DEFAULT now(),
  market_id uuid,
  variant_id uuid NOT NULL,
  CONSTRAINT market_prices_pkey PRIMARY KEY (id),
  CONSTRAINT fk_price_location FOREIGN KEY (location_id) REFERENCES core.locations(id),
  CONSTRAINT fk_market_price_market FOREIGN KEY (market_id) REFERENCES marketplace.markets(id),
  CONSTRAINT market_prices_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
CREATE TABLE marketplace.daily_market_prices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  location_id uuid,
  market_id uuid,
  avg_price numeric NOT NULL,
  min_price numeric,
  max_price numeric,
  unit_id uuid,
  recorded_on date DEFAULT CURRENT_DATE,
  created_at timestamp with time zone DEFAULT now(),
  variant_id uuid NOT NULL,
  CONSTRAINT daily_market_prices_pkey PRIMARY KEY (id),
  CONSTRAINT daily_market_prices_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES core.units(id),
  CONSTRAINT fk_daily_location FOREIGN KEY (location_id) REFERENCES core.locations(id),
  CONSTRAINT fk_daily_market FOREIGN KEY (market_id) REFERENCES marketplace.markets(id),
  CONSTRAINT daily_market_prices_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
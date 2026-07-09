-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE core.unlocks_expiry_log (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  unlock_type text NOT NULL CHECK (unlock_type = ANY (ARRAY['buyer'::text, 'seller'::text])),
  supplier_id uuid,
  buyer_id uuid,
  amount numeric,
  currency text,
  expired_at timestamp with time zone DEFAULT now(),
  notes text,
  contact_unlock_id uuid,
  listing_id uuid,
  CONSTRAINT unlocks_expiry_log_pkey PRIMARY KEY (id)
);
CREATE TABLE core.user_roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  type text NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT user_roles_pkey PRIMARY KEY (id)
);
CREATE TABLE core.countries (
  name character varying NOT NULL,
  iso_alpha2 character NOT NULL UNIQUE,
  iso_alpha3 character NOT NULL UNIQUE,
  dialing_code character varying NOT NULL,
  is_active boolean DEFAULT false,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT countries_pkey PRIMARY KEY (id)
);
CREATE TABLE core.entity_roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  entity_id uuid NOT NULL,
  role_id uuid NOT NULL,
  assigned_by uuid DEFAULT core.auth_user_id(),
  assigned_at timestamp with time zone DEFAULT now(),
  is_active boolean DEFAULT true,
  updated_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT entity_roles_pkey PRIMARY KEY (id),
  CONSTRAINT entity_roles_user_role_id_fkey FOREIGN KEY (role_id) REFERENCES core.user_roles(id),
  CONSTRAINT entity_roles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id),
  CONSTRAINT entity_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES users.profiles(id)
);
CREATE TABLE core.entity_invitations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  email character varying NOT NULL,
  role_id uuid NOT NULL,
  invited_by uuid,
  invite_token text NOT NULL,
  expires_at timestamp with time zone,
  accepted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT entity_invitations_pkey PRIMARY KEY (id),
  CONSTRAINT entity_invitations_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT entity_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES users.profiles(id),
  CONSTRAINT entity_invitations_role_id_fkey FOREIGN KEY (role_id) REFERENCES core.user_roles(id)
);
CREATE TABLE core.geography_levels (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  level_name text NOT NULL,
  level_order integer NOT NULL,
  country_id uuid,
  CONSTRAINT geography_levels_pkey PRIMARY KEY (id),
  CONSTRAINT geo_levels_country_fk FOREIGN KEY (country_id) REFERENCES core.countries(id)
);
CREATE TABLE core.locations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  level_id uuid,
  parent_id uuid,
  code bigint,
  population bigint,
  area_km2 bigint,
  density double precision,
  farming_activities ARRAY,
  soil_type text,
  agro_zone text,
  altitude text,
  temp_range text,
  rainfall_mm text,
  local_languages ARRAY,
  gps text,
  geometry USER-DEFINED,
  created_at timestamp with time zone DEFAULT '2026-02-24 21:06:36.42648+00'::timestamp with time zone,
  updated_at timestamp with time zone DEFAULT '2026-02-24 21:08:55.588526+00'::timestamp with time zone,
  country_id uuid NOT NULL,
  admin_type text,
  CONSTRAINT locations_pkey PRIMARY KEY (id),
  CONSTRAINT locations_level_id_fkey FOREIGN KEY (level_id) REFERENCES core.geography_levels(id),
  CONSTRAINT locations_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES core.locations(id),
  CONSTRAINT locations_country_id_fkey FOREIGN KEY (country_id) REFERENCES core.countries(id)
);
CREATE TABLE core.infrastructure (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  location_id uuid,
  name text NOT NULL,
  description text,
  capacity text,
  geom USER-DEFINED,
  accuracy_level text DEFAULT 'approximate'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  type_id uuid,
  is_active boolean DEFAULT true,
  slug text,
  ownership_type_id uuid,
  entity_id uuid,
  status text DEFAULT 'Operational'::text CHECK (status = ANY (ARRAY['Operational'::text, 'Under Construction'::text, 'Planned'::text, 'Inactive'::text])),
  capacity_value numeric,
  capacity_unit text,
  service_radius_km numeric,
  contact_phone text,
  email text,
  is_verified boolean DEFAULT false,
  is_physical boolean DEFAULT true,
  CONSTRAINT infrastructure_pkey PRIMARY KEY (id),
  CONSTRAINT facilities_location_id_fkey FOREIGN KEY (location_id) REFERENCES core.locations(id),
  CONSTRAINT infrastructure_type_id_fkey FOREIGN KEY (type_id) REFERENCES core.infrastructure_types(id),
  CONSTRAINT infrastructure_ownership_type_id_fkey FOREIGN KEY (ownership_type_id) REFERENCES core.ownership_types(id)
);
CREATE TABLE core.infrastructure_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT infrastructure_types_pkey PRIMARY KEY (id)
);
CREATE TABLE core.ownership_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ownership_types_pkey PRIMARY KEY (id)
);
CREATE TABLE core.infrastructure_service_areas (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  infrastructure_id uuid NOT NULL,
  location_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT infrastructure_service_areas_pkey PRIMARY KEY (id),
  CONSTRAINT infrastructure_service_areas_infrastructure_id_fkey FOREIGN KEY (infrastructure_id) REFERENCES core.infrastructure(id),
  CONSTRAINT infrastructure_service_areas_location_id_fkey FOREIGN KEY (location_id) REFERENCES core.locations(id)
);
CREATE TABLE core.commodities (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  name text NOT NULL UNIQUE,
  category text NOT NULL,
  default_unit text,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  scientific_name text,
  hs_code text,
  shelf_life_days bigint,
  is_perishable boolean,
  CONSTRAINT commodities_pkey PRIMARY KEY (id)
);
CREATE TABLE core.infrastructure_commodities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  infrastructure_id uuid NOT NULL,
  commodity_id uuid NOT NULL,
  capacity_value numeric,
  capacity_unit text,
  is_primary boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT infrastructure_commodities_pkey PRIMARY KEY (id),
  CONSTRAINT infrastructure_commodities_infrastructure_id_fkey FOREIGN KEY (infrastructure_id) REFERENCES core.infrastructure(id),
  CONSTRAINT infrastructure_commodities_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES core.commodities(id)
);
CREATE TABLE core.domains (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT domains_pkey PRIMARY KEY (id)
);
CREATE TABLE core.categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  domain_id uuid,
  name text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categories_pkey PRIMARY KEY (id),
  CONSTRAINT categories_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES core.domains(id)
);
CREATE TABLE core.items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  category_id uuid,
  name text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT items_pkey PRIMARY KEY (id),
  CONSTRAINT items_category_id_fkey FOREIGN KEY (category_id) REFERENCES core.categories(id)
);
CREATE TABLE core.attribute_registry (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  name text NOT NULL UNIQUE,
  data_type text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  unit_id uuid,
  attribute_level text CHECK (attribute_level = ANY (ARRAY['category'::text, 'item'::text, 'variant'::text, 'record'::text, 'module'::text])),
  CONSTRAINT attribute_registry_pkey PRIMARY KEY (id),
  CONSTRAINT fk_attribute_unit FOREIGN KEY (unit_id) REFERENCES core.units(id)
);
CREATE TABLE core.category_attribute_map (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  category_id uuid,
  attribute_id uuid,
  is_required boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT category_attribute_map_pkey PRIMARY KEY (id),
  CONSTRAINT category_attribute_map_category_id_fkey FOREIGN KEY (category_id) REFERENCES core.categories(id),
  CONSTRAINT category_attribute_map_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id)
);
CREATE TABLE core.item_attributes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  item_id uuid,
  attribute_id uuid,
  value_text text,
  value_number numeric,
  value_boolean boolean,
  value_json jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT item_attributes_pkey PRIMARY KEY (id),
  CONSTRAINT item_attributes_item_id_fkey FOREIGN KEY (item_id) REFERENCES core.items(id),
  CONSTRAINT item_attributes_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id)
);
CREATE TABLE core.attribute_enum_values (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  attribute_id uuid,
  value text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT attribute_enum_values_pkey PRIMARY KEY (id),
  CONSTRAINT attribute_enum_values_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id)
);
CREATE TABLE core.units (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  symbol text,
  created_at timestamp with time zone DEFAULT now(),
  unit_type text CHECK (unit_type = ANY (ARRAY['count'::text, 'time'::text, 'mass'::text, 'volume'::text, 'area'::text, 'length'::text, 'power'::text, 'currency'::text])),
  CONSTRAINT units_pkey PRIMARY KEY (id)
);
CREATE TABLE core.record_attributes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  record_id uuid,
  attribute_id uuid,
  value_text text NOT NULL,
  value_number numeric NOT NULL,
  value_boolean boolean NOT NULL,
  value_json jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  enum_value_id uuid,
  CONSTRAINT record_attributes_pkey PRIMARY KEY (id),
  CONSTRAINT record_attributes_record_id_fkey FOREIGN KEY (record_id) REFERENCES core.records(id),
  CONSTRAINT fk_record_attr_enum FOREIGN KEY (enum_value_id) REFERENCES core.attribute_enum_values(id),
  CONSTRAINT record_attributes_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id)
);
CREATE TABLE core.item_variants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL,
  name text NOT NULL,
  CONSTRAINT item_variants_pkey PRIMARY KEY (id),
  CONSTRAINT item_variants_item_id_fkey FOREIGN KEY (item_id) REFERENCES core.items(id)
);
CREATE TABLE core.variant_attributes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  variant_id uuid NOT NULL,
  attribute_id uuid NOT NULL,
  value_number numeric,
  value_text text,
  value_boolean boolean,
  value_date date,
  enum_value_id uuid,
  is_required boolean DEFAULT false,
  CONSTRAINT variant_attributes_pkey PRIMARY KEY (id),
  CONSTRAINT variant_attributes_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id),
  CONSTRAINT variant_attributes_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id)
);
CREATE TABLE core.records (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  domain_id uuid NOT NULL,
  category_id uuid NOT NULL,
  item_id uuid,
  variant_id uuid,
  module text,
  status text NOT NULL DEFAULT 'active'::text,
  is_deleted boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  activity_type_id uuid,
  entity_id uuid NOT NULL,
  created_by uuid DEFAULT core.auth_user_id(),
  CONSTRAINT records_pkey PRIMARY KEY (id),
  CONSTRAINT fk_records_entity FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT records_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id),
  CONSTRAINT fk_records_domain FOREIGN KEY (domain_id) REFERENCES core.domains(id),
  CONSTRAINT fk_records_category FOREIGN KEY (category_id) REFERENCES core.categories(id),
  CONSTRAINT fk_records_item FOREIGN KEY (item_id) REFERENCES core.items(id),
  CONSTRAINT fk_records_variant FOREIGN KEY (variant_id) REFERENCES core.item_variants(id),
  CONSTRAINT records_created_by_fkey FOREIGN KEY (created_by) REFERENCES users.profiles(id)
);
CREATE TABLE core.item_unit_map (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  is_default boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT item_unit_map_pkey PRIMARY KEY (id),
  CONSTRAINT fk_item_unit_item FOREIGN KEY (item_id) REFERENCES core.items(id),
  CONSTRAINT fk_item_unit_unit FOREIGN KEY (unit_id) REFERENCES core.units(id)
);
CREATE TABLE core.item_variant_unit_map (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  variant_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  is_default boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT item_variant_unit_map_pkey PRIMARY KEY (id),
  CONSTRAINT fk_variant_unit_variant FOREIGN KEY (variant_id) REFERENCES core.item_variants(id),
  CONSTRAINT fk_variant_unit_unit FOREIGN KEY (unit_id) REFERENCES core.units(id)
);
CREATE TABLE core.unit_conversions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  from_unit_id uuid NOT NULL,
  to_unit_id uuid NOT NULL,
  conversion_factor numeric NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT unit_conversions_pkey PRIMARY KEY (id),
  CONSTRAINT fk_from_unit FOREIGN KEY (from_unit_id) REFERENCES core.units(id),
  CONSTRAINT fk_to_unit FOREIGN KEY (to_unit_id) REFERENCES core.units(id)
);
CREATE TABLE core.entities (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  name text NOT NULL,
  slug text UNIQUE,
  entity_type text NOT NULL CHECK (entity_type = ANY (ARRAY['farm'::text, 'trading_company'::text, 'service_provider'::text, 'cooperative'::text, 'individual_pro'::text, 'agrovet'::text])),
  owner_id uuid NOT NULL DEFAULT core.auth_user_id(),
  is_active boolean DEFAULT true,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  verification_status text DEFAULT 'pending'::text CHECK (verification_status = ANY (ARRAY['pending'::text, 'verified'::text, 'rejected'::text, 'suspended'::text])),
  legal_owner_type text DEFAULT 'individual'::text CHECK (legal_owner_type = ANY (ARRAY['individual'::text, 'business'::text, 'cooperative'::text, 'organization'::text])),
  primary_contact_profile_id uuid,
  CONSTRAINT entities_pkey PRIMARY KEY (id),
  CONSTRAINT entities_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES users.profiles(id),
  CONSTRAINT fk_entities_primary_contact FOREIGN KEY (primary_contact_profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE core.entity_members (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  entity_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  role_id uuid NOT NULL,
  assigned_at timestamp with time zone DEFAULT now(),
  is_active boolean DEFAULT true,
  can_sell boolean DEFAULT false,
  can_manage boolean DEFAULT false,
  can_receive_payments boolean DEFAULT false,
  membership_status text DEFAULT 'active'::text CHECK (membership_status = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'revoked'::text])),
  CONSTRAINT entity_members_pkey PRIMARY KEY (id),
  CONSTRAINT entity_members_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT entity_members_role_id_fkey FOREIGN KEY (role_id) REFERENCES core.user_roles(id),
  CONSTRAINT entity_members_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE core.entity_context_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  entity_id uuid NOT NULL,
  session_status text DEFAULT 'active'::text CHECK (session_status = ANY (ARRAY['active'::text, 'expired'::text, 'revoked'::text])),
  is_default boolean DEFAULT false,
  last_switched_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  active_mode text DEFAULT 'farmer'::text CHECK (active_mode = ANY (ARRAY['farmer'::text, 'trader'::text, 'buyer'::text, 'business_rep'::text, 'supplier'::text, 'admin'::text, 'agrovet'::text])),
  business_profile_id uuid,
  active_role_id uuid,
  CONSTRAINT entity_context_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT entity_context_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users.profiles(id),
  CONSTRAINT entity_context_sessions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT fk_context_business_profile FOREIGN KEY (business_profile_id) REFERENCES commerce.business_profiles(id),
  CONSTRAINT fk_context_active_role FOREIGN KEY (active_role_id) REFERENCES core.user_roles(id)
);
CREATE TABLE core.permissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  description text,
  module text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT permissions_pkey PRIMARY KEY (id)
);
CREATE TABLE core.role_permissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT role_permissions_pkey PRIMARY KEY (id),
  CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES core.user_roles(id),
  CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES core.permissions(id)
);
CREATE TABLE core.entity_role_scopes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  role_id uuid NOT NULL,
  scope_type text DEFAULT 'entity'::text CHECK (scope_type = ANY (ARRAY['entity'::text, 'global'::text, 'module'::text])),
  module text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT entity_role_scopes_pkey PRIMARY KEY (id),
  CONSTRAINT entity_role_scopes_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT entity_role_scopes_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id),
  CONSTRAINT entity_role_scopes_role_id_fkey FOREIGN KEY (role_id) REFERENCES core.user_roles(id)
);
CREATE TABLE core.permission_overrides (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid,
  entity_id uuid,
  permission_code text,
  allow boolean NOT NULL,
  reason text,
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT permission_overrides_pkey PRIMARY KEY (id)
);
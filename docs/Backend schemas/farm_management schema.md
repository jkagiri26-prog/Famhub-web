-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE farm_management.activity_types (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  name text NOT NULL UNIQUE,
  category text,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_types_pkey PRIMARY KEY (id)
);
CREATE TABLE farm_management.farms (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  farm_name text NOT NULL,
  description text,
  size numeric,
  unit uuid,
  county_id uuid NOT NULL,
  sub_county_id uuid NOT NULL,
  ward_id uuid NOT NULL,
  geo_coordinates text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  village text,
  entity_id uuid NOT NULL DEFAULT core.auth_user_id(),
  is_verified boolean DEFAULT false,
  verified_by uuid,
  irrigation_water boolean,
  ownership text,
  CONSTRAINT farms_pkey PRIMARY KEY (id),
  CONSTRAINT fk_farms_entity FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT farms_county_id_fkey FOREIGN KEY (county_id) REFERENCES core.locations(id),
  CONSTRAINT farms_sub_county_id_fkey FOREIGN KEY (sub_county_id) REFERENCES core.locations(id),
  CONSTRAINT farms_ward_id_fkey FOREIGN KEY (ward_id) REFERENCES core.locations(id),
  CONSTRAINT farms_unit_fkey FOREIGN KEY (unit) REFERENCES core.units(id)
);
CREATE TABLE farm_management.fields (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  farm_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  size numeric,
  field_type text,
  soil_type text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  unit_id uuid,
  CONSTRAINT fields_pkey PRIMARY KEY (id),
  CONSTRAINT fields_farm_id_fkey FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id),
  CONSTRAINT fields_unit_fk FOREIGN KEY (unit_id) REFERENCES core.units(id)
);
CREATE TABLE farm_management.farm_inputs (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  brand text,
  quantity numeric,
  date_applied date NOT NULL,
  cost numeric,
  created_at timestamp with time zone DEFAULT now(),
  input_type_name text NOT NULL,
  unit_id uuid,
  asset_id uuid,
  CONSTRAINT farm_inputs_pkey PRIMARY KEY (id),
  CONSTRAINT farm_inputs_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES farm_management.assets(id),
  CONSTRAINT fk_input_type_name FOREIGN KEY (input_type_name) REFERENCES farm_management.input_types(name),
  CONSTRAINT farm_inputs_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES core.units(id)
);
CREATE TABLE farm_management.farm_reports (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  report_type text NOT NULL,
  amount numeric,
  description text,
  report_date date NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  unit_id uuid,
  asset_id uuid,
  CONSTRAINT farm_reports_pkey PRIMARY KEY (id),
  CONSTRAINT farm_reports_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES farm_management.assets(id),
  CONSTRAINT farm_reports_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES core.units(id)
);
CREATE TABLE farm_management.input_types (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  name text NOT NULL UNIQUE,
  category text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT input_types_pkey PRIMARY KEY (id)
);
CREATE TABLE farm_management.farm_aggregates (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  farm_id uuid NOT NULL UNIQUE,
  total_income numeric DEFAULT 0,
  total_expense numeric DEFAULT 0,
  total_yield numeric DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT farm_aggregates_pkey PRIMARY KEY (id),
  CONSTRAINT farm_aggregates_farm_id_fkey FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id)
);
CREATE TABLE farm_management.labour_attributes (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  labour_type text,
  number_required integer,
  skills ARRAY,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  variant_id uuid,
  CONSTRAINT labour_attributes_pkey PRIMARY KEY (id),
  CONSTRAINT labour_variant_fk FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
CREATE TABLE farm_management.land_attributes (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  land_size numeric,
  land_type text,
  location text,
  suitability text,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  variant_id uuid,
  CONSTRAINT land_attributes_pkey PRIMARY KEY (id),
  CONSTRAINT land_variant_fk FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
CREATE TABLE farm_management.input_attributes (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  input_type text,
  application_method text,
  recommended_dosage text,
  crop_target ARRAY,
  livestock_target ARRAY,
  active_ingredients ARRAY,
  safety_notes text,
  storage_requirements text,
  organic_certified boolean,
  manufacturer text,
  expiry_date date,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  variant_id uuid,
  CONSTRAINT input_attributes_pkey PRIMARY KEY (id),
  CONSTRAINT input_attr_variant_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
CREATE TABLE farm_management.production_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now() CHECK (created_at <= now()),
  updated_at timestamp with time zone DEFAULT now(),
  farm_id uuid NOT NULL,
  activity_id uuid,
  variant_id uuid,
  quantity numeric CHECK (quantity IS NULL OR quantity >= 0::numeric),
  unit_id uuid,
  entity_id uuid NOT NULL DEFAULT core.auth_user_id(),
  category_id uuid,
  asset_id uuid,
  field_id uuid,
  source_type USER-DEFINED,
  record_id uuid,
  activity_ref uuid,
  output_commodity_id uuid,
  CONSTRAINT production_records_pkey PRIMARY KEY (id),
  CONSTRAINT production_records_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT production_farm_fkey FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id),
  CONSTRAINT production_activity_fkey FOREIGN KEY (activity_id) REFERENCES farm_management.activities(id),
  CONSTRAINT production_variant_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id),
  CONSTRAINT production_unit_fkey FOREIGN KEY (unit_id) REFERENCES core.units(id),
  CONSTRAINT production_records_category_id_fkey FOREIGN KEY (category_id) REFERENCES core.categories(id),
  CONSTRAINT production_record_fk FOREIGN KEY (record_id) REFERENCES core.records(id),
  CONSTRAINT production_output_commodity_fkey FOREIGN KEY (output_commodity_id) REFERENCES core.commodities(id),
  CONSTRAINT production_records_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES farm_management.assets(id),
  CONSTRAINT production_records_field_id_fkey FOREIGN KEY (field_id) REFERENCES farm_management.fields(id)
);
CREATE TABLE farm_management.item_activity_map (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  item_id uuid NOT NULL,
  activity_type_id uuid NOT NULL,
  is_default boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT item_activity_map_pkey PRIMARY KEY (id),
  CONSTRAINT item_activity_map_item_id_fkey FOREIGN KEY (item_id) REFERENCES core.items(id),
  CONSTRAINT item_activity_map_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id)
);
CREATE TABLE farm_management.item_variant_activity_map (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  variant_id uuid NOT NULL,
  activity_type_id uuid NOT NULL,
  is_enabled boolean DEFAULT true,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT item_variant_activity_map_pkey PRIMARY KEY (id),
  CONSTRAINT item_variant_activity_map_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id),
  CONSTRAINT item_variant_activity_map_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id)
);
CREATE TABLE farm_management.activity_templates (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  activity_type_id uuid NOT NULL,
  item_id uuid,
  variant_id uuid,
  name text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_templates_pkey PRIMARY KEY (id),
  CONSTRAINT activity_templates_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id),
  CONSTRAINT activity_templates_item_id_fkey FOREIGN KEY (item_id) REFERENCES core.items(id),
  CONSTRAINT activity_templates_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
CREATE TABLE farm_management.activity_template_values (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  template_id uuid NOT NULL,
  attribute_id uuid NOT NULL,
  value_text text,
  value_number numeric,
  value_boolean boolean,
  enum_value_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_template_values_pkey PRIMARY KEY (id),
  CONSTRAINT activity_template_values_template_id_fkey FOREIGN KEY (template_id) REFERENCES farm_management.activity_templates(id),
  CONSTRAINT activity_template_values_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id),
  CONSTRAINT activity_template_values_enum_value_id_fkey FOREIGN KEY (enum_value_id) REFERENCES core.attribute_enum_values(id)
);
CREATE TABLE farm_management.activity_workflow (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  item_id uuid,
  activity_type_id uuid NOT NULL,
  previous_activity_id uuid,
  stage_order integer,
  is_required boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_workflow_pkey PRIMARY KEY (id),
  CONSTRAINT activity_workflow_previous_activity_fkey FOREIGN KEY (previous_activity_id) REFERENCES farm_management.activity_workflow(id),
  CONSTRAINT activity_workflow_item_id_fkey FOREIGN KEY (item_id) REFERENCES core.items(id),
  CONSTRAINT activity_workflow_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id)
);
CREATE TABLE farm_management.farm_members (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  farm_id uuid NOT NULL,
  profile_id uuid,
  organization_id uuid,
  role text NOT NULL DEFAULT 'worker'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT farm_members_pkey PRIMARY KEY (id),
  CONSTRAINT farm_members_farm_id_fkey FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id),
  CONSTRAINT farm_members_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE farm_management.activities (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  activity_type_id uuid NOT NULL,
  performed_at timestamp with time zone NOT NULL DEFAULT now() CHECK (performed_at <= now()),
  notes text,
  entity_id uuid NOT NULL DEFAULT core.auth_user_id(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  asset_id uuid,
  plan_id uuid,
  updated_at timestamp with time zone DEFAULT now(),
  is_deleted boolean DEFAULT false,
  deleted_at timestamp with time zone,
  CONSTRAINT activities_pkey PRIMARY KEY (id),
  CONSTRAINT activities_plan_fk FOREIGN KEY (plan_id) REFERENCES farm_management.plans(id),
  CONSTRAINT fk_activities_entity FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT activities_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id),
  CONSTRAINT activities_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES farm_management.assets(id)
);
CREATE TABLE farm_management.activity_values (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  activity_id uuid NOT NULL,
  attribute_id uuid NOT NULL,
  value_text text,
  value_number numeric,
  value_boolean boolean,
  enum_value_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_values_pkey PRIMARY KEY (id),
  CONSTRAINT activity_values_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES farm_management.activities(id),
  CONSTRAINT activity_values_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id),
  CONSTRAINT activity_values_enum_value_id_fkey FOREIGN KEY (enum_value_id) REFERENCES core.attribute_enum_values(id)
);
CREATE TABLE farm_management.activity_attribute_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  activity_type_id uuid NOT NULL,
  attribute_id uuid NOT NULL,
  is_required boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_attribute_rules_pkey PRIMARY KEY (id),
  CONSTRAINT fk_attribute FOREIGN KEY (attribute_id) REFERENCES core.attribute_registry(id),
  CONSTRAINT fk_activity_type FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id)
);
CREATE TABLE farm_management.activity_stock_rules (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  activity_type_id uuid NOT NULL UNIQUE,
  stock_direction text NOT NULL CHECK (stock_direction = ANY (ARRAY['IN'::text, 'OUT'::text, 'ADJUSTMENT'::text])),
  quantity_multiplier numeric DEFAULT 1,
  affects_product boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_stock_rules_pkey PRIMARY KEY (id),
  CONSTRAINT fk_activity_type FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id)
);
CREATE TABLE farm_management.farm_kpis (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  farm_id uuid NOT NULL UNIQUE,
  total_production numeric DEFAULT 0,
  total_sales numeric DEFAULT 0,
  total_consumption numeric DEFAULT 0,
  total_income numeric DEFAULT 0,
  total_expense numeric DEFAULT 0,
  profit numeric DEFAULT 0,
  total_yield numeric DEFAULT 0,
  avg_yield_per_crop numeric DEFAULT 0,
  last_updated timestamp with time zone DEFAULT now(),
  avg_cost_per_unit numeric DEFAULT 0,
  productivity_score numeric DEFAULT 0,
  stock_value numeric DEFAULT 0,
  CONSTRAINT farm_kpis_pkey PRIMARY KEY (id),
  CONSTRAINT fk_farm FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id)
);
CREATE TABLE farm_management.financial_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL DEFAULT core.auth_user_id(),
  farm_id uuid NOT NULL,
  activity_id uuid,
  record_type text NOT NULL,
  amount numeric NOT NULL,
  description text,
  recorded_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  is_deleted boolean DEFAULT false,
  deleted_at timestamp with time zone,
  CONSTRAINT financial_records_pkey PRIMARY KEY (id),
  CONSTRAINT financial_records_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES farm_management.activities(id),
  CONSTRAINT financial_records_farm_id_fkey FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id),
  CONSTRAINT financial_records_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE farm_management.assets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL DEFAULT core.auth_user_id(),
  farm_id uuid NOT NULL,
  asset_type text NOT NULL,
  variant_id uuid NOT NULL,
  field_id uuid,
  status text NOT NULL DEFAULT 'active'::text,
  acquired_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  quantity numeric DEFAULT '1'::numeric,
  unit_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT assets_pkey PRIMARY KEY (id),
  CONSTRAINT farm.assets_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT farm.assets_field_id_fkey FOREIGN KEY (field_id) REFERENCES farm_management.fields(id),
  CONSTRAINT farm.assets_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id),
  CONSTRAINT farm.assets_farm_id_fkey FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id),
  CONSTRAINT farm.assets_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES core.units(id)
);
CREATE TABLE farm_management.plans (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  entity_id uuid NOT NULL DEFAULT core.auth_user_id(),
  farm_id uuid NOT NULL,
  asset_id uuid NOT NULL,
  activity_type_id uuid NOT NULL,
  template_id uuid,
  variant_id uuid,
  plan_name text,
  description text,
  start_date date NOT NULL,
  end_date date,
  schedule jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text DEFAULT 'pending'::text,
  priority text DEFAULT 'normal'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT plans_pkey PRIMARY KEY (id),
  CONSTRAINT plans_entity_fk FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT plans_farm_fk FOREIGN KEY (farm_id) REFERENCES farm_management.farms(id),
  CONSTRAINT plans_asset_fk FOREIGN KEY (asset_id) REFERENCES farm_management.assets(id),
  CONSTRAINT plans_activity_type_fk FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id),
  CONSTRAINT plans_template_fk FOREIGN KEY (template_id) REFERENCES farm_management.activity_templates(id),
  CONSTRAINT plans_variant_fk FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
CREATE TABLE farm_management.classifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  variant_id uuid NOT NULL UNIQUE,
  model jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT classifications_pkey PRIMARY KEY (id),
  CONSTRAINT classifications_variant_fk FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);

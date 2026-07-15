-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE spatial.spatial_assets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  asset_type text NOT NULL CHECK (asset_type = ANY (ARRAY['farm'::text, 'field'::text, 'block'::text, 'carbon_zone'::text, 'forest'::text, 'woodlot'::text, 'water_body'::text, 'wetland'::text, 'pasture'::text, 'orchard'::text, 'greenhouse'::text, 'other'::text])),
  name text,
  area_ha numeric DEFAULT 0,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  parent_asset_id uuid,
  CONSTRAINT spatial_assets_pkey PRIMARY KEY (id),
  CONSTRAINT spatial_assets_parent_asset_id_fkey FOREIGN KEY (parent_asset_id) REFERENCES spatial.spatial_assets(id)
);
CREATE TABLE spatial.spatial_capture_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  asset_id uuid,
  status text DEFAULT 'active'::text,
  started_at timestamp with time zone DEFAULT now(),
  completed_at timestamp with time zone,
  mode text DEFAULT 'manual'::text,
  CONSTRAINT spatial_capture_sessions_pkey PRIMARY KEY (id)
);
CREATE TABLE spatial.spatial_capture_points (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  latitude double precision NOT NULL CHECK (latitude >= '-90'::integer::double precision AND latitude <= 90::double precision),
  longitude double precision NOT NULL CHECK (longitude >= '-180'::integer::double precision AND longitude <= 180::double precision),
  accuracy_meters double precision,
  sequence_no integer NOT NULL,
  recorded_at timestamp with time zone DEFAULT now(),
  CONSTRAINT spatial_capture_points_pkey PRIMARY KEY (id),
  CONSTRAINT spatial_capture_points_session_id_fkey FOREIGN KEY (session_id) REFERENCES spatial.spatial_capture_sessions(id)
);
CREATE TABLE spatial.spatial_boundaries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL,
  geometry USER-DEFINED NOT NULL,
  accuracy_level text DEFAULT 'gps'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT spatial_boundaries_pkey PRIMARY KEY (id),
  CONSTRAINT spatial_boundaries_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES spatial.spatial_assets(id)
);
CREATE TABLE spatial.spatial_overlaps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  asset_a uuid NOT NULL,
  asset_b uuid NOT NULL,
  overlap_type text DEFAULT 'boundary'::text,
  overlap_area_sq_m numeric,
  overlap_percentage numeric,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT spatial_overlaps_pkey PRIMARY KEY (id),
  CONSTRAINT spatial_overlaps_asset_a_fkey FOREIGN KEY (asset_a) REFERENCES spatial.spatial_assets(id),
  CONSTRAINT spatial_overlaps_asset_b_fkey FOREIGN KEY (asset_b) REFERENCES spatial.spatial_assets(id)
);
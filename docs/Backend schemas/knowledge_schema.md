-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE knowledge.resource_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_types_pkey PRIMARY KEY (id)
);
CREATE TABLE knowledge.topics (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  parent_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT topics_pkey PRIMARY KEY (id),
  CONSTRAINT topics_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES knowledge.topics(id)
);
CREATE TABLE knowledge.resources (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_type_id uuid NOT NULL,
  title text NOT NULL,
  slug text NOT NULL UNIQUE,
  summary text,
  status text NOT NULL DEFAULT 'draft'::text CHECK (status = ANY (ARRAY['draft'::text, 'review'::text, 'approved'::text, 'published'::text, 'archived'::text])),
  visibility text NOT NULL DEFAULT 'public'::text CHECK (visibility = ANY (ARRAY['public'::text, 'restricted'::text, 'private'::text])),
  is_featured boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  owned_by_entity_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  published_at timestamp with time zone,
  archived_at timestamp with time zone,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT resources_pkey PRIMARY KEY (id),
  CONSTRAINT resources_resource_type_id_fkey FOREIGN KEY (resource_type_id) REFERENCES knowledge.resource_types(id),
  CONSTRAINT resources_created_by_fkey FOREIGN KEY (created_by) REFERENCES users.profiles(id),
  CONSTRAINT resources_owned_by_entity_id_fkey FOREIGN KEY (owned_by_entity_id) REFERENCES core.entities(id)
);
CREATE TABLE knowledge.resource_versions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  version_number integer NOT NULL,
  status text NOT NULL DEFAULT 'draft'::text CHECK (status = ANY (ARRAY['draft'::text, 'review'::text, 'approved'::text, 'published'::text, 'superseded'::text, 'rejected'::text])),
  title text,
  summary text,
  change_summary text,
  created_by uuid,
  reviewed_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  reviewed_at timestamp with time zone,
  published_at timestamp with time zone,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT resource_versions_pkey PRIMARY KEY (id),
  CONSTRAINT resource_versions_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES users.profiles(id),
  CONSTRAINT resource_versions_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES users.profiles(id)
);
CREATE TABLE knowledge.sections (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_version_id uuid NOT NULL,
  title text NOT NULL,
  slug text,
  section_order integer NOT NULL DEFAULT 0,
  summary text,
  is_required boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT sections_pkey PRIMARY KEY (id),
  CONSTRAINT sections_resource_version_id_fkey FOREIGN KEY (resource_version_id) REFERENCES knowledge.resource_versions(id)
);
CREATE TABLE knowledge.content_blocks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  section_id uuid NOT NULL,
  block_type text NOT NULL,
  block_order integer NOT NULL DEFAULT 0,
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT content_blocks_pkey PRIMARY KEY (id),
  CONSTRAINT content_blocks_section_id_fkey FOREIGN KEY (section_id) REFERENCES knowledge.sections(id)
);
CREATE TABLE knowledge.resource_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  item_id uuid NOT NULL,
  relationship_type text NOT NULL DEFAULT 'primary'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_items_pkey PRIMARY KEY (id),
  CONSTRAINT resource_items_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES core.items(id)
);
CREATE TABLE knowledge.resource_variants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  relationship_type text NOT NULL DEFAULT 'primary'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_variants_pkey PRIMARY KEY (id),
  CONSTRAINT resource_variants_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_variants_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES core.item_variants(id)
);
CREATE TABLE knowledge.resource_commodities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  commodity_id uuid NOT NULL,
  relationship_type text NOT NULL DEFAULT 'primary'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_commodities_pkey PRIMARY KEY (id),
  CONSTRAINT resource_commodities_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_commodities_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES core.commodities(id)
);
CREATE TABLE knowledge.resource_locations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  location_id uuid NOT NULL,
  relationship_type text NOT NULL DEFAULT 'applicable'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_locations_pkey PRIMARY KEY (id),
  CONSTRAINT resource_locations_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES core.locations(id)
);
CREATE TABLE knowledge.resource_activities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  activity_type_id uuid NOT NULL,
  relationship_type text NOT NULL DEFAULT 'applicable'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_activities_pkey PRIMARY KEY (id),
  CONSTRAINT resource_activities_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_activities_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES farm_management.activity_types(id)
);
CREATE TABLE knowledge.resource_topics (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  topic_id uuid NOT NULL,
  relationship_type text NOT NULL DEFAULT 'primary'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_topics_pkey PRIMARY KEY (id),
  CONSTRAINT resource_topics_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_topics_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES knowledge.topics(id)
);
CREATE TABLE knowledge.sources (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  source_type text NOT NULL CHECK (source_type = ANY (ARRAY['institution'::text, 'research'::text, 'government'::text, 'extension'::text, 'expert'::text, 'book'::text, 'article'::text, 'website'::text, 'internal'::text, 'other'::text])),
  organization_name text,
  author_name text,
  title text,
  url text,
  citation text,
  published_at timestamp with time zone,
  is_verified boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT sources_pkey PRIMARY KEY (id)
);
CREATE TABLE knowledge.resource_sources (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  source_id uuid NOT NULL,
  source_role text NOT NULL DEFAULT 'reference'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_sources_pkey PRIMARY KEY (id),
  CONSTRAINT resource_sources_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_sources_source_id_fkey FOREIGN KEY (source_id) REFERENCES knowledge.sources(id)
);
CREATE TABLE knowledge.resource_relations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL,
  related_resource_id uuid NOT NULL,
  relationship_type text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT resource_relations_pkey PRIMARY KEY (id),
  CONSTRAINT resource_relations_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES knowledge.resources(id),
  CONSTRAINT resource_relations_related_resource_id_fkey FOREIGN KEY (related_resource_id) REFERENCES knowledge.resources(id)
);
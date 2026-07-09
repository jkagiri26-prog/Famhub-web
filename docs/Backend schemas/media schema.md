-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE media.files (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  bucket text NOT NULL,
  path text NOT NULL,
  entity_id uuid NOT NULL,
  context_type text NOT NULL,
  context_id uuid NOT NULL,
  file_type text NOT NULL CHECK (file_type = ANY (ARRAY['image'::text, 'video'::text, 'document'::text, 'thumbnail'::text, 'system'::text])),
  mime_type text,
  extension text,
  size_bytes bigint NOT NULL,
  width integer,
  height integer,
  duration_seconds integer,
  is_processed boolean DEFAULT false,
  has_thumbnail boolean DEFAULT false,
  is_original_stored boolean DEFAULT false,
  is_public boolean DEFAULT false,
  is_deleted boolean DEFAULT false,
  expires_at timestamp with time zone,
  egress_count bigint DEFAULT 0,
  last_accessed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid DEFAULT auth.uid(),
  thumbnail_path text,
  preview_path text,
  CONSTRAINT files_pkey PRIMARY KEY (id)
);
CREATE TABLE media.file_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  file_id uuid NOT NULL,
  event_type text NOT NULL CHECK (event_type = ANY (ARRAY['upload'::text, 'view'::text, 'download'::text, 'delete'::text])),
  entity_id uuid,
  context_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT file_events_pkey PRIMARY KEY (id),
  CONSTRAINT file_events_file_id_fkey FOREIGN KEY (file_id) REFERENCES media.files(id)
);
CREATE TABLE media.file_versions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  file_id uuid NOT NULL,
  version integer NOT NULL,
  path text NOT NULL,
  size_bytes bigint,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT file_versions_pkey PRIMARY KEY (id),
  CONSTRAINT file_versions_file_id_fkey FOREIGN KEY (file_id) REFERENCES media.files(id)
);
CREATE TABLE media.context_access (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  context_type text NOT NULL,
  context_id uuid NOT NULL,
  entity_id uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['viewer'::text, 'editor'::text, 'owner'::text])),
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT context_access_pkey PRIMARY KEY (id)
);
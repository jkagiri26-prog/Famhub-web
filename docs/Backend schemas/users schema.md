-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE users.profiles (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  first_name character varying NOT NULL,
  last_name character varying NOT NULL,
  email text NOT NULL UNIQUE,
  phone text UNIQUE,
  profile_image text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  country_id uuid NOT NULL,
  level_2_location_id uuid,
  level_3_location_id uuid,
  level_4_location_id uuid,
  middle_name text,
  user_type character varying NOT NULL CHECK (user_type::text = ANY (ARRAY['farmer'::character varying, 'trader'::character varying, 'stakeholder'::character varying]::text[])),
  verified boolean DEFAULT false,
  is_complete boolean DEFAULT false,
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  deleted_at timestamp with time zone,
  role_id uuid,
  profile_status text DEFAULT 'Pending'::text CHECK (profile_status = ANY (ARRAY['Pending'::text, 'Verified'::text, 'Suspended'::text])),
  date_of_birth date,
  gender text CHECK (gender = ANY (ARRAY['Male'::text, 'Female'::text, 'Other'::text])),
  bio text,
  social_links jsonb,
  notification_opt_in boolean DEFAULT true,
  kyc_documents jsonb,
  referral_code text UNIQUE,
  auth_user_id uuid UNIQUE,
  kyc_status text DEFAULT 'pending'::text CHECK (kyc_status = ANY (ARRAY['pending'::text, 'submitted'::text, 'verified'::text, 'rejected'::text])),
  verification_level integer DEFAULT 0,
  account_status text DEFAULT 'active'::text CHECK (account_status = ANY (ARRAY['active'::text, 'suspended'::text, 'blocked'::text])),
  level_5_location_id uuid,
  level_6_location_id uuid,
  level_7_location_id uuid,
  location_path text CHECK (location_path IS NULL OR location_path ~ '^[0-9a-fA-F-]+(\\|[0-9a-fA-F-]+)*$'::text),
  is_phone_verified boolean NOT NULL DEFAULT false,
  is_email_verified boolean NOT NULL DEFAULT false,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_level_4_location_id_fkey FOREIGN KEY (level_4_location_id) REFERENCES core.locations(id),
  CONSTRAINT profiles_country_id_fkey FOREIGN KEY (country_id) REFERENCES core.countries(id),
  CONSTRAINT fk_profiles_created_by FOREIGN KEY (created_by) REFERENCES users.profiles(id)
);


CREATE TABLE users.alerts (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  profile_id uuid,
  alert_type text,
  payload jsonb,
  is_dismissed boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT alerts_pkey PRIMARY KEY (id),
  CONSTRAINT alerts_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id)
);



CREATE TABLE users.otp (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  phone text NOT NULL,
  otp text NOT NULL,
  user_id uuid,
  used boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL,
  metadata jsonb,
  CONSTRAINT otp_pkey PRIMARY KEY (id)
);
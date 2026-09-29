-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE weather.weather_observations (
  id uuid NOT NULL DEFAULT uuid_generate_v7(),
  location_id uuid,
  observed_at timestamp with time zone NOT NULL,
  temperature numeric,
  rainfall numeric CHECK (rainfall IS NULL OR rainfall >= 0::numeric),
  wind_speed numeric CHECK (wind_speed IS NULL OR wind_speed >= 0::numeric),
  payload jsonb,
  record_kind text NOT NULL DEFAULT 'observation'::text CHECK (record_kind = ANY (ARRAY['observation'::text, 'current'::text, 'hourly_forecast'::text, 'daily_forecast'::text])),
  feels_like_temperature numeric,
  precipitation_probability numeric CHECK (precipitation_probability IS NULL OR precipitation_probability >= 0::numeric AND precipitation_probability <= 100::numeric),
  humidity numeric CHECK (humidity IS NULL OR humidity >= 0::numeric AND humidity <= 100::numeric),
  wind_direction numeric CHECK (wind_direction IS NULL OR wind_direction >= 0::numeric AND wind_direction <= 360::numeric),
  provider text NOT NULL CHECK (btrim(provider) <> ''::text),
  provider_external_id text,
  fetched_at timestamp with time zone NOT NULL DEFAULT now(),
  latitude numeric CHECK (latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric),
  longitude numeric CHECK (longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric),
  CONSTRAINT weather_observations_pkey PRIMARY KEY (id),
  CONSTRAINT weather_observations_location_id_fkey FOREIGN KEY (location_id) REFERENCES core.locations(id)
);
CREATE TABLE weather.weather_cache (
  cache_key text NOT NULL CHECK (btrim(cache_key) <> ''::text),
  location_id uuid,
  latitude numeric CHECK (latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric),
  longitude numeric CHECK (longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric),
  response jsonb NOT NULL,
  provider text NOT NULL CHECK (btrim(provider) <> ''::text),
  fetched_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL,
  CONSTRAINT weather_cache_pkey PRIMARY KEY (cache_key),
  CONSTRAINT weather_cache_location_id_fkey FOREIGN KEY (location_id) REFERENCES core.locations(id)
);
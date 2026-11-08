-- NightWise DB schema (plan §8) — PostgreSQL 16 + PostGIS 3.4

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         CITEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name  TEXT,
  role          TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','moderator','admin')),
  device_hash   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
  id         BIGSERIAL PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);
CREATE INDEX idx_refresh_user ON refresh_tokens(user_id);

CREATE TABLE data_sources (
  id             SERIAL PRIMARY KEY,
  key            TEXT UNIQUE NOT NULL,
  name           TEXT NOT NULL,
  trust_rank     INT NOT NULL DEFAULT 1,
  update_freq    TEXT,
  last_synced_at TIMESTAMPTZ,
  last_row_count INT,
  last_status    TEXT,
  meta           JSONB
);

CREATE TABLE roads (
  id          BIGSERIAL PRIMARY KEY,
  osm_way_id  BIGINT NOT NULL UNIQUE,
  name        TEXT,
  class       TEXT NOT NULL,
  oneway      BOOLEAN DEFAULT FALSE,
  foot_access TEXT,
  lit_tag     TEXT,
  geom        GEOMETRY(LineString,4326) NOT NULL,
  props       JSONB
);
CREATE INDEX idx_roads_geom ON roads USING GIST (geom);

CREATE TABLE road_segments (
  id                  BIGSERIAL PRIMARY KEY,
  road_id             BIGINT NOT NULL REFERENCES roads(id) ON DELETE CASCADE,
  seq                 INT NOT NULL,
  geom                GEOMETRY(LineString,4326) NOT NULL,
  length_m            DOUBLE PRECISION NOT NULL,
  highway_class       TEXT NOT NULL,
  est_lit_prior       DOUBLE PRECISION,
  est_lit_prior_conf  DOUBLE PRECISION DEFAULT 0.25,
  est_activity_prior  JSONB,
  lit_tag             TEXT,
  foot_access         TEXT
);
CREATE INDEX idx_segments_geom ON road_segments USING GIST (geom);
CREATE INDEX idx_segments_road ON road_segments(road_id, seq);
CREATE INDEX idx_segments_class ON road_segments(highway_class);

CREATE TABLE shops (
  id                BIGSERIAL PRIMARY KEY,
  source            TEXT NOT NULL,
  source_id         TEXT NOT NULL,
  name              TEXT,
  category          TEXT NOT NULL,
  hours_known       BOOLEAN NOT NULL DEFAULT FALSE,
  hours             JSONB,
  verified          BOOLEAN NOT NULL DEFAULT FALSE,
  trust_rank        INT NOT NULL DEFAULT 1,
  source_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  geom              GEOMETRY(Point,4326) NOT NULL,
  UNIQUE (source, source_id)
);
CREATE INDEX idx_shops_geom ON shops USING GIST (geom);
CREATE INDEX idx_shops_cat ON shops(category);
CREATE INDEX idx_shops_cat_hours ON shops(category, hours_known);

CREATE TABLE streetlights (
  id                BIGSERIAL PRIMARY KEY,
  source            TEXT NOT NULL,
  source_id         TEXT,
  class             TEXT,
  verified          BOOLEAN NOT NULL DEFAULT FALSE,
  source_updated_at TIMESTAMPTZ,
  geom              GEOMETRY(Point,4326) NOT NULL
);
CREATE INDEX idx_lights_geom ON streetlights USING GIST (geom);

CREATE TABLE emergency_locations (
  id       BIGSERIAL PRIMARY KEY,
  type     TEXT NOT NULL CHECK (type IN ('police','hospital','fire','pharmacy_24h','cctv','bus_stop_lit')),
  name     TEXT,
  contact  TEXT,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  source   TEXT,
  geom     GEOMETRY(Point,4326) NOT NULL
);
CREATE INDEX idx_emergency_geom ON emergency_locations USING GIST (geom);
CREATE INDEX idx_emergency_type ON emergency_locations(type);

CREATE TABLE safety_reports (
  id           BIGSERIAL PRIMARY KEY,
  user_id      UUID REFERENCES users(id),
  reporter_fp  TEXT, -- HMAC-hashed device fingerprint, never raw
  kind         TEXT NOT NULL CHECK (kind IN ('harassment','poor_lighting','unsafe_isolated','no_footpath','construction','crowd_safe','other')),
  severity     INT NOT NULL CHECK (severity BETWEEN 1 AND 5),
  note         TEXT,
  status       TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','published','rejected')),
  trust_score  DOUBLE PRECISION DEFAULT 0.5,
  conflict_flag BOOLEAN DEFAULT FALSE,
  geom         GEOMETRY(Point,4326) NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_score_at TIMESTAMPTZ
);

CREATE INDEX idx_reports_geom ON safety_reports USING GIST (geom);
CREATE INDEX idx_reports_status ON safety_reports(status, created_at);

-- NOTE (plan §8): deliberately NO route_history table in MVP.
CREATE TABLE saved_routes (
  id         BIGSERIAL PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label      TEXT,
  mode       TEXT NOT NULL,
  origin     GEOMETRY(Point,4326) NOT NULL,
  destination GEOMETRY(Point,4326) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE route_score_cache (
  cache_key  TEXT PRIMARY KEY,
  payload    JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE places_cache (
  place_id   TEXT PRIMARY KEY,
  category   TEXT,
  name       TEXT,
  hours      JSONB,
  fetched_at TIMESTAMPTZ NOT NULL,
  geom       GEOMETRY(Point,4326) NOT NULL
);

-- Normalized-hours evaluator (plan §6.2): hours = [{"days":[0-6],"from":"HH:MM","to":"HH:MM"}] or [{"always":true}]
CREATE OR REPLACE FUNCTION hours_open_at(rules jsonb, at timestamptz)
RETURNS boolean AS $$
DECLARE r jsonb; d int; tfrom time; tto time; day_idx int;
BEGIN
  IF rules IS NULL THEN RETURN NULL; END IF; -- unknown stays unknown (FR-202)
  FOR r IN SELECT * FROM jsonb_array_elements(rules) LOOP
    IF (r ? 'always') THEN RETURN true; END IF;
    day_idx := EXTRACT(dow FROM at)::int;      -- 0=Sun
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(r->'days') dd
      WHERE dd::int = day_idx
    ) THEN CONTINUE; END IF;
    tfrom := (r->>'from')::time;
    tto   := (r->>'to')::time;
    IF tfrom <= tto THEN
      IF at::time >= tfrom AND at::time < tto THEN RETURN true; END IF;
    ELSE
      IF at::time >= tfrom OR at::time < tto THEN RETURN true; END IF;
    END IF;
  END LOOP;
  RETURN false;
END;
$$ LANGUAGE plpgsql;

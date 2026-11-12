-- Phase 3 completion: user preference defaults, community report votes,
-- and durable route-detail archival (plan §11.1 deferred endpoints).

-- FR-402 defaults live server-side so a reinstall keeps the user's choices.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS prefs JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Confirm/deny signals from signed-in users. Votes never publish a report on
-- their own; they only nudge the moderation trust score (plan §9.4, §15.4).
CREATE TABLE IF NOT EXISTS safety_report_votes (
  report_id  BIGINT NOT NULL REFERENCES safety_reports(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vote       SMALLINT NOT NULL CHECK (vote IN (-1, 1)),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (report_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_report_votes_user ON safety_report_votes(user_id);

-- Route detail payloads outlive the 10-minute Redis recommendation cache.
CREATE TABLE IF NOT EXISTS route_details (
  route_id   TEXT PRIMARY KEY,
  user_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  payload    JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_route_details_expiry ON route_details(expires_at);

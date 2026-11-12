/** Users repository — only place that touches user tables' SQL. */
import { getPool } from '../db/pool.js';
import type { UserSettings } from '../api/schemas/index.js';

export interface UserRow {
  id: string;
  email: string;
  password_hash: string;
  display_name: string | null;
  role: 'user' | 'moderator' | 'admin';
}

export async function findByEmail(email: string): Promise<UserRow | null> {
  const res = await getPool().query('SELECT * FROM users WHERE email = $1', [email]);
  return (res.rows[0] as UserRow) ?? null;
}

export async function findById(id: string): Promise<UserRow | null> {
  const res = await getPool().query('SELECT id, email, display_name, role FROM users WHERE id = $1', [id]);
  return (res.rows[0] as UserRow) ?? null;
}

export async function insert(input: {
  email: string;
  passwordHash: string;
  displayName: string | null;
  deviceHash: string | null;
}): Promise<UserRow> {
  const res = await getPool().query(
    `INSERT INTO users (email, password_hash, display_name, device_hash)
     VALUES ($1, $2, $3, $4) RETURNING id, email, display_name, role`,
    [input.email, input.passwordHash, input.displayName, input.deviceHash],
  );
  return res.rows[0] as UserRow;
}

export async function insertRefreshToken(userId: string, tokenHash: string, expiresAt: Date): Promise<void> {
  await getPool().query(
    'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)',
    [userId, tokenHash, expiresAt],
  );
}

export async function findValidRefreshToken(tokenHash: string): Promise<{ id: number; user_id: string; token_hash: string } | null> {
  const res = await getPool().query(
    `SELECT id, user_id, token_hash FROM refresh_tokens
     WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()`,
    [tokenHash],
  );
  return (res.rows[0] as typeof findValidRefreshToken extends () => Promise<infer R> ? R : never) ?? null;
}

export async function revokeRefreshTokenFamily(tokenHash: string): Promise<void> {
  await getPool().query(
    'UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 OR user_id = (SELECT user_id FROM refresh_tokens WHERE token_hash = $1)',
    [tokenHash],
  );
}

export interface ProfileDto {
  userId: string;
  email: string;
  displayName: string | null;
  role: string;
  createdAt: string;
  settings: Record<string, unknown>;
  stats: { reportsSubmitted: number; votesCast: number; savedRoutes: number };
  savedRoutes: SavedRouteDto[];
}

export interface SavedRouteDto {
  id: number;
  label: string | null;
  mode: string;
  origin: { lat: number; lng: number };
  destination: { lat: number; lng: number };
  createdAt: string;
}

export async function getProfile(userId: string): Promise<ProfileDto | null> {
  const pool = getPool();
  const user = await pool.query(
    `SELECT id, email, display_name, role, created_at, prefs
     FROM users WHERE id = $1`,
    [userId],
  );
  if (user.rowCount === 0) return null;
  const u = user.rows[0] as {
    id: string; email: string; display_name: string | null; role: string;
    created_at: Date; prefs: Record<string, unknown> | null;
  };
  const recentReports = await pool.query(
    'SELECT count(*)::int AS n FROM safety_reports WHERE user_id = $1',
    [userId],
  );
  const votes = await pool.query(
    'SELECT count(*)::int AS n FROM safety_report_votes WHERE user_id = $1',
    [userId],
  );
  const saved = await listSavedRoutes(userId);
  return {
    userId: u.id,
    email: u.email,
    displayName: u.display_name,
    role: u.role,
    createdAt: new Date(u.created_at).toISOString(),
    settings: u.prefs ?? {},
    stats: {
      reportsSubmitted: Number(recentReports.rows[0]?.n ?? 0),
      votesCast: Number(votes.rows[0]?.n ?? 0),
      savedRoutes: saved.length,
    },
    savedRoutes: saved,
  };
}

/** Shallow-merge so a PATCH only changes the keys it names. */
export async function updateSettings(
  userId: string,
  patch: UserSettings,
): Promise<Record<string, unknown> | null> {
  const res = await getPool().query(
    `UPDATE users
     SET prefs = COALESCE(prefs, '{}'::jsonb) || $2::jsonb
     WHERE id = $1
     RETURNING prefs`,
    [userId, JSON.stringify(patch)],
  );
  return res.rowCount === 0 ? null : (res.rows[0].prefs as Record<string, unknown>);
}

export async function listSavedRoutes(userId: string): Promise<SavedRouteDto[]> {
  const res = await getPool().query(
    `SELECT id, label, mode, created_at,
            ST_Y(origin::geometry) AS origin_lat, ST_X(origin::geometry) AS origin_lng,
            ST_Y(destination::geometry) AS dest_lat, ST_X(destination::geometry) AS dest_lng
     FROM saved_routes
     WHERE user_id = $1
     ORDER BY created_at DESC`,
    [userId],
  );
  return res.rows.map((r: Record<string, unknown>) => ({
    id: Number(r.id),
    label: (r.label as string | null) ?? null,
    mode: String(r.mode),
    origin: { lat: Number(r.origin_lat), lng: Number(r.origin_lng) },
    destination: { lat: Number(r.dest_lat), lng: Number(r.dest_lng) },
    createdAt: new Date(r.created_at as string).toISOString(),
  }));
}

export async function insertSavedRoute(
  userId: string,
  input: { label: string; mode: string; origin: { lat: number; lng: number }; destination: { lat: number; lng: number } },
): Promise<SavedRouteDto> {
  const pool = getPool();
  // FR-402 caps saved routes at two per account. Enforce atomically.
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const count = await client.query(
      'SELECT count(*)::int AS n FROM saved_routes WHERE user_id = $1',
      [userId],
    );
    if (Number(count.rows[0]?.n ?? 0) >= 2) {
      throw Object.assign(new Error('Saved route limit reached (2)'), { code: 'CONFLICT', status: 409 });
    }
    const res = await client.query(
      `INSERT INTO saved_routes (user_id, label, mode, origin, destination)
       VALUES ($1, $2, $3,
               ST_SetSRID(ST_MakePoint($5, $4), 4326),
               ST_SetSRID(ST_MakePoint($7, $6), 4326))
       RETURNING id, label, mode, created_at`,
      [userId, input.label, input.mode, input.origin.lat, input.origin.lng,
       input.destination.lat, input.destination.lng],
    );
    await client.query('COMMIT');
    const r = res.rows[0] as Record<string, unknown>;
    return {
      id: Number(r.id),
      label: (r.label as string | null) ?? null,
      mode: String(r.mode),
      origin: input.origin,
      destination: input.destination,
      createdAt: new Date(r.created_at as string).toISOString(),
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function deleteSavedRoute(userId: string, id: number): Promise<boolean> {
  const res = await getPool().query(
    'DELETE FROM saved_routes WHERE id = $1 AND user_id = $2',
    [id, userId],
  );
  return (res.rowCount ?? 0) > 0;
}

export async function deleteUserData(userId: string): Promise<void> {
  // hard delete per plan §15.2 (GDPR-style); reports anonymize
  const pool = getPool();
  await pool.query('UPDATE safety_reports SET user_id = NULL, reporter_fp = md5(random()::text) WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM saved_routes WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM users WHERE id = $1', [userId]);
}

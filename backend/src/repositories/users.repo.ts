/** Users repository — only place that touches user tables' SQL. */
import { getPool } from '../db/pool.js';

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

export async function deleteUserData(userId: string): Promise<void> {
  // hard delete per plan §15.2 (GDPR-style); reports anonymize
  const pool = getPool();
  await pool.query('UPDATE safety_reports SET user_id = NULL, reporter_fp = md5(random()::text) WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM saved_routes WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM users WHERE id = $1', [userId]);
}

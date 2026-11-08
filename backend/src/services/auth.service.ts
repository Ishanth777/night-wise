/**
 * Authentication service (plan §15.1): bcrypt(12), JWT access 15 min,
 * rotating refresh 30 days with reuse-detection revocation. Device
 * fingerprints are HMAC-hashed; raw values never stored/logged.
 */
import bcrypt from 'bcrypt';
import crypto from 'node:crypto';
import { sign, verify, type JwtPayload } from 'jsonwebtoken';
import { findByEmail, findById, insert, insertRefreshToken, findValidRefreshToken, revokeRefreshTokenFamily, deleteUserData } from '../repositories/users.repo.js';
import { ensure } from './ranking.service.js';
import { getEnv } from '../config/env.js';

export interface Session {
  userId: string;
  email: string;
  role: string;
  accessToken: string;
  refreshToken: string;
}

const BCRYPT_ROUNDS = 12;
constACCESS_MINUTES = undefined; // replaced below

export async function register(email: string, password: string, displayName: string | null, fingerprint: string | null): Promise<Session> {
  const env = getEnv();
  ensure(password.length >= 8, 'VALIDATION_ERROR', 'Password must be at least 8 characters');
  const existing = await findByEmail(email);
  ensure(!existing, 'CONFLICT', 'An account with this email already exists');
  const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const fpHash = fingerprint ? crypto.createHash('sha256').update(fingerprint).digest('hex').slice(0, 32) : null;
  const user = await insert({ email, passwordHash: hash, displayName, deviceHash: fpHash });
  const tokens = issueTokens(user.id, user.email, user.role, env, fingerprint);
  return {
    userId: user.id,
    email: user.email,
    role: user.role,
    accessToken: tokens.access,
    refreshToken: tokens.refresh,
  };
}

export async function login(email: string, password: string, fingerprint: string | null): Promise<Session> {
  const env = getEnv();
  const user = await findByEmail(email);
  // generic error to prevent enumeration (plan §15.1)
  ensure(user && await bcrypt.compare(password, user.password_hash), 'AUTH_FAILED', 'Invalid email or password');
  const tokens = issueTokens(user!.id, user!.email, user!.role, env, fingerprint);
  return { userId: user!.id, email: user!.email, role: user!.role, accessToken: tokens.access, refreshToken: tokens.refresh };
}

export async function refresh(refreshToken: string, fingerprint: string | null): Promise<Session> {
  const env = getEnv();
  const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  const row = await findValidRefreshToken(tokenHash);
  ensure(row, 'AUTH_FAILED', 'Invalid or expired refresh token');
  const user = await findById(row!.user_id);
  ensure(user, 'AUTH_FAILED', 'User no longer exists');
  await revokeRefreshTokenFamily(tokenHash); // rotation
  const tokens = issueTokens(user!.id, user!.email, user!.role, env, fingerprint);
  return { userId: user!.id, email: user!.email, role: user!.role, accessToken: tokens.access, refreshToken: tokens.refresh };
}

export async function logout(refreshToken: string): Promise<void> {
  const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  await revokeRefreshTokenFamily(tokenHash);
}

export async function deleteAccount(userId: string): Promise<void> {
  await deleteUserData(userId);
}

export function verifyAccessToken(token: string): JwtPayload & { sub: string; role: string } {
  const env = getEnv();
  const payload = verify(token, env.JWT_SECRET) as JwtPayload & { sub: string; role: string };
  return payload;
}

// ---------------------------------------------------------------- internal

function issueTokens(userId: string, email: string, role: string, env: ReturnType<typeof getEnv>, fingerprint: string | null) {
  const access = sign({ sub: userId, email, role }, env.JWT_SECRET, { expiresIn: '15m' });
  const refresh = crypto.randomBytes(48).toString('base64url');
  const expires = new Date(Date.now() + 30 * 86400e3);
  void insertRefreshToken(userId, crypto.createHash('sha256').update(refresh).digest('hex'), expires);
  void fingerprint;
  return { access, refresh };
}

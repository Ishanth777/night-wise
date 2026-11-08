import { RateLimiterRedis } from 'rate-limiter-flexible';
import { getRedis } from '../../lib/cache.js';
import { getEnv } from '../../config/env.js';
import type { NextFunction, Request, Response } from 'express';

const limiterCache: Record<string, RateLimiterRedis | null> = {};

function limiter(name: string, points: number, duration: number): RateLimiterRedis | null {
  const redis = getRedis();
  if (!redis || redis.status !== 'ready') return null;
  limiterCache[name] ??= new RateLimiterRedis({
    storeClient: redis as never,
    keyPrefix: `rl_${name}`,
    points,
    duration,
  });
  return limiterCache[name]!;
}

function clientKey(req: Request): string {
  return req.ip ?? 'unknown';
}

async function consume(
  name: string, key: string, points: number, duration: number, res: Response,
): Promise<boolean> {
  const rl = limiter(name, points, duration);
  if (!rl) return true; // degraded: no redis → allow through (fail-open documented)
  try {
    await rl.consume(key, 1);
    return true;
  } catch (err) {
    const e = err as { msBeforeNext?: number };
    const retry = Math.ceil((e.msBeforeNext ?? 1000) / 1000);
    res.set('Retry-After', String(retry));
    return false;
  }
}

export async function rateLimitGlobal(req: Request, res: Response, next: NextFunction): Promise<void> {
  const ok = await consume('global', clientKey(req), getEnv().RATE_LIMIT_GLOBAL_PER_HOUR, 3600, res);
  if (ok) next();
  else res.status(429).json({ error: { code: 'RATE_LIMITED', message: 'Too many requests — slow down and try again shortly.' } });
}

export async function recommendRateLimit(req: Request, res: Response, next: NextFunction): Promise<void> {
  const env = getEnv();
  const user = (req as { user?: { sub?: string } }).user?.sub;
  const ipOk = await consume('rec_ip', clientKey(req), env.RATE_LIMIT_RECOMMEND_PER_HOUR_IP, 3600, res);
  const userOk = user
    ? await consume('rec_user', user, env.RATE_LIMIT_RECOMMEND_PER_HOUR_USER, 3600, res)
    : true;
  if (ipOk && userOk) next();
  else res.status(429).json({ error: { code: 'RATE_LIMITED', message: 'Too many route checks from this device — try again shortly.' } });
}

export async function reportsRateLimit(req: Request, res: Response, next: NextFunction): Promise<void> {
  const env = getEnv();
  const user = (req as { user?: { sub?: string } }).user?.sub;
  const ok = await consume(
    'reports',
    user ?? clientKey(req),
    user ? env.RATE_LIMIT_REPORTS_PER_DAY_USER : 3, 86400, res,
  );
  if (ok) next();
  else res.status(429).json({ error: { code: 'RATE_LIMITED', message: 'Report limit reached — reports are rate-limited to protect data quality.' } });
}

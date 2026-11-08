import { Redis } from 'ioredis';
import log from './logger.js';

let redis: Redis | null = null;

export function getRedis(): Redis | null {
  if (redis) return redis;
  if (!process.env.REDIS_URL) return null;
  redis = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: 2, lazyConnect: true });
  redis.connect().catch((err) => log.error({ err }, 'redis connect failed — running degraded without cache'));
  return redis;
}

// graceful degradation: every cache op is best-effort (plan §15.3)
export async function cacheGet(key: string): Promise<string | null> {
  try {
    const r = getRedis();
    if (!r) return null;
    return r.status === 'ready' ? await r.get(key) : null;
  } catch {
    return null;
  }
}

export async function cacheSet(key: string, value: string, ttlSeconds: number): Promise<void> {
  try {
    const r = getRedis();
    if (r && r.status === 'ready') await r.set(key, value, 'EX', ttlSeconds);
  } catch { /* degrade silently */ }
}

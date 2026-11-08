import pg from 'pg';
import log from '../lib/logger.js';

let pool: pg.Pool | null = null;

export function getPool(): pg.Pool {
  if (pool) return pool;
  // Lazy connect (plan §13: fail graceful at boot if DB is briefly unavailable)
  pool = new pg.Pool({
    connectionString: process.env.DATABASE_URL,
    max: 10,
    idleTimeoutMillis: 30_000,
    ssl: /sslmode=require/.test(process.env.DATABASE_URL ?? '')
      ? { rejectUnauthorized: false }
      : undefined,
  });
  pool.on('error', (err) => log.error({ err }, 'postgres pool error'));
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) await pool.end();
  pool = null;
}

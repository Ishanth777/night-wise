/** Durable route-detail archive (plan §11.1 `GET /routes/:routeId`). */
import { getPool } from '../db/pool.js';
import type { RouteOptionDto } from '../services/ranking.service.js';

export interface RouteDetailPayload {
  route: RouteOptionDto;
  mode: string;
  computedFor: string;
  requestId: string;
  disclaimer: string;
  dataHealth: Record<string, unknown>;
}

const TTL_HOURS = 24;

export async function archiveRouteDetails(
  routes: RouteOptionDto[],
  meta: { userId: string | null; mode: string; computedFor: string; requestId: string; disclaimer: string; dataHealth: Record<string, unknown> },
): Promise<void> {
  if (routes.length === 0) return;
  const values: unknown[] = [];
  const tuples: string[] = [];
  routes.forEach((route, i) => {
    const base = i * 3;
    tuples.push(`($${base + 1}, $${base + 2}, $${base + 3}::jsonb, now() + interval '${TTL_HOURS} hours')`);
    const payload: RouteDetailPayload = {
      route,
      mode: meta.mode,
      computedFor: meta.computedFor,
      requestId: meta.requestId,
      disclaimer: meta.disclaimer,
      dataHealth: meta.dataHealth,
    };
    values.push(route.routeId, meta.userId, JSON.stringify(payload));
  });
  await getPool().query(
    `INSERT INTO route_details (route_id, user_id, payload, expires_at)
     VALUES ${tuples.join(', ')}
     ON CONFLICT (route_id) DO UPDATE
       SET payload = EXCLUDED.payload, expires_at = EXCLUDED.expires_at`,
    values,
  );
}

export async function getRouteDetail(routeId: string): Promise<RouteDetailPayload | null> {
  const pool = getPool();
  const res = await pool.query(
    `SELECT payload FROM route_details
     WHERE route_id = $1 AND expires_at > now()`,
    [routeId],
  );
  if (res.rowCount === 0) return null;
  return res.rows[0].payload as RouteDetailPayload;
}

/** Opportunistic cleanup; failures are non-fatal for request handling. */
export async function pruneExpiredRouteDetails(): Promise<void> {
  await getPool().query("DELETE FROM route_details WHERE expires_at < now() - interval '1 day'");
}

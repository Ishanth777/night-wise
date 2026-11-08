/** Emergency services repo — plan §6.5, FR-301. */
import { getPool } from '../db/pool.js';

export interface EmergencyDto {
  id: number;
  type: string;
  name: string | null;
  contact: string | null;
  verified: boolean;
  distanceM: number;
  lat: number;
  lng: number;
}

export async function nearby(
  lat: number, lng: number, radiusM: number, type?: string,
): Promise<EmergencyDto[]> {
  const res = await getPool().query(
    `SELECT id, type, name, contact, verified,
            ST_Distance(geom::geography, ST_SetSRID(ST_MakePoint($3, $2),4326)::geography) AS dist_m,
            ST_Y(geom) AS lat, ST_X(geom) AS lng
     FROM emergency_locations
     WHERE ($4::text IS NULL OR type = $4)
       AND ST_DWithin(geom, ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography, $1::float)
     ORDER BY dist_m ASC LIMIT 30`,
    [radiusM, lat, lng, type ?? null],
  );
  return (res.rows as Array<Record<string, unknown>>).map((r) => ({
    id: Number(r.id),
    type: String(r.type),
    name: r.name as string | null,
    contact: r.contact as string | null,
    verified: Boolean(r.verified),
    distanceM: Math.round(Number(r.dist_m ?? 0)),
    lat: Number(r.lat),
    lng: Number(r.lng),
  }));
}

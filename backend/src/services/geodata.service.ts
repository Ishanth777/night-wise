/**
 * Geospatial Data Service (plan §7.1): corridor pulls for a candidate route.
 * One round-trip set of batched GiST-backed ST_DWithin queries per route.
 * Maps raw rows onto scoring/SegmentInput with explicit provenance.
 */
import type { PoolClient, Pool } from 'pg';
import { getPool } from '../db/pool.js';
import { HOUR_ACTIVITY_FACTOR, type Mode, type RoadClass } from '../config/scoring.js';
import {
  cellId, haversineM,
} from '../lib/geo.js';
import type {
  ActivityObservation, EmergencyObservation, LightObservation, ReportObservation, SegmentInput, ShopsObservation, ShopObservation,
} from '../scoring/types.js';
import log from '../lib/logger.js';

const SEG_SAMPLE_POINTS = 25;

export interface CorridorRequest {
  mode: Mode;
  /** ISO time string — evaluated in IST for open/closed (plan: IST wall clock) */
  at: Date;
  /** per-segment GeoJSON LineString coordinate arrays */
  segments: number[][][];
  lightRadiusM: number;
  corridorM: number;
}

export async function corridorData(req: CorridorRequest): Promise<SegmentInput[]> {
  const pool = getPool();
  const client = await pool.connect();
  try {
    const segs = req.segments.map((c) => ({
      geojson: JSON.stringify({ type: 'LineString', coordinates: c }),
    }));

    // 1 - batch insert segments + critical road class (majority intersecting road class)
    await client.query('CREATE TEMP TABLE seg_idx (i int primary key, g geometry(LineString,4326), hw text) ON COMMIT DROP', []);
    for (let i = 0; i < segs.length; i++) {
      await client.query(
        `INSERT INTO seg_idx (i, g, hw)
         VALUES ($1,
           ST_GeomFromGeoJSON($2),
           COALESCE((SELECT r.class FROM roads r
             WHERE ST_Intersects(r.geom, ST_GeomFromGeoJSON($2))
             ORDER BY ST_Length(ST_Intersection(r.geom, ST_GeomFromGeoJSON($2))) DESC
             LIMIT 1), 'unknown'))`,
        [i, segs[i].geojson],
      );
    }

    const [lights, shops, reports, emergency, hwRows] = await Promise.all([
      lightsQuery(client, req),
      shopsQuery(client, req),
      reportsQuery(client, req),
      emergencyQuery(client, req),
      (async () => {
        const res = await client.query(`SELECT i, hw FROM seg_idx`, []);
        const m: Record<number, string> = {};
        for (const r of res.rows as Array<{ i: string; hw: string }>) m[Number(r.i)] = r.hw;
        return m;
      })(),
    ]);

    return buildSegmentInputs(segs, req, lights, shops, reports, emergency, hwRows);
  } finally {
    client.release();
  }
}

// ------------------------------------------------------------- lights

interface LightsRows {
  [i: number]: { count: number; verified: number; covered: number; sampled: number; maxGapM: number | null; provenance: 'verified' | 'osm' | 'model_est'; maxAgeDays: number | null };
}

/**
 * NOTE (plan §6.3 truth): streetlights table may be EMPTY (no public Bengaluru
 * dataset verified yet). This query then yields coverage 0.0 with provenance
 * 'model_est' and the engine falls back to class priors at low confidence —
 * honestly labeled via the decision trace (§9.8).
 */
async function lightsQuery(client: PoolClient, req: CorridorRequest): Promise<LightsRows> {
  const rad = req.lightRadiusM;
  const res = await client.query(
    `WITH s AS (SELECT i, g FROM seg_idx),
      per AS (
        SELECT s.i,
         (SELECT count(*) FROM streetlights l WHERE ST_DWithin(l.geom, s.g, $1)) AS cnt,
         (SELECT count(*) FROM streetlights l WHERE ST_DWithin(l.geom, s.g, $1) AND l.verified) AS verified,
         (SELECT min(EXTRACT(epoch FROM (now() - l.source_updated_at)) / 86400.0)
            FROM streetlights l WHERE ST_DWithin(l.geom, s.g, $1) AND l.source_updated_at IS NOT NULL) AS max_age,
         (SELECT coalesce(max(gap),0) * ST_Length(s.g::geography) FROM (
            SELECT ST_LineLocatePoint(s.g, l.geom)
              - lag(ST_LineLocatePoint(s.g, l.geom)) OVER (ORDER BY ST_LineLocatePoint(s.g, l.geom)) AS gap
            FROM streetlights l WHERE ST_DWithin(l.geom, s.g, $1)
          ) gaps) AS max_gap,
         (SELECT count(*) FROM (
            SELECT (SELECT EXISTS (SELECT 1 FROM streetlights l
                     WHERE ST_DWithin(l.geom, ST_LineInterpolatePoint(s.g, f.f), $1))) AS lit
            FROM generate_series(0, $2, 1.0 / $2) AS f(f)
          ) q WHERE q.lit) AS covered
        FROM s
      )
     SELECT i, cnt, verified, max_gap, covered, max_age FROM per`,
    [rad, SEG_SAMPLE_POINTS - 1],
  );

  const out: LightsRows = {};
  for (const row of res.rows as Array<Record<string, unknown>>) {
    const i = Number(row.i);
    const cnt = Number(row.cnt ?? 0);
    out[i] = {
      count: cnt,
      verified: Number(row.verified ?? 0),
      covered: cnt > 0 ? Math.round(Number(row.covered ?? 0)) : 0,
      sampled: SEG_SAMPLE_POINTS,
      maxGapM: cnt >= 2 && row.max_gap ? Number(row.max_gap) : null,
      provenance: cnt > 0
        ? (Number(row.verified ?? 0) > 0 ? 'verified' : 'model_est')
        : 'model_est',
      maxAgeDays: row.max_age != null ? Number(row.max_age) : null,
    };
  }
  // Fallback: partial fake-free estimate via OSM lit=yes tags on the covered way
  // (plan §6.3 layer 1): if the road tagged lit=yes and no point dataset exists,
  // we produce a conservative estimate — coverage prior — provenance 'osm'.
  const tagRes = await client.query(
    `SELECT s.i, r.lit_tag FROM seg_idx s
     JOIN roads r ON ST_Intersects(r.geom, s.g)
     WHERE r.lit_tag IS NOT NULL LIMIT 200`,
    [],
  );
  for (const row of tagRes.rows as Array<Record<string, unknown>>) {
    const i = Number(row.i);
    if (out[i]) continue;
    if (String(row.lit_tag) === 'yes' || String(row.lit_tag) === '24/7') {
      out[i] = {
        count: 0, verified: 0, covered: Math.round(SEG_SAMPLE_POINTS * 0.7),
        sampled: SEG_SAMPLE_POINTS, maxGapM: null,
        provenance: 'osm', maxAgeDays: null,
      };
    }
  }
  return out;
}

// ---------------------------------------------------------------- shops

interface ShopsRows {
  [i: number]: { items: ShopObservation[]; total: number; hoursKnownCount: number; unknownCount: number; nearestOpenM: number | null };
}

async function shopsQuery(client: PoolClient, req: CorridorRequest): Promise<ShopsRows> {
  const atIso = req.at.toISOString();
  const res = await client.query(
    `SELECT s.i, sh.id, sh.name, sh.category, sh.hours_known, sh.hours,
            sh.source, sh.verified, sh.trust_rank,
            ST_Distance(sh.geom::geography, s.g::geography) AS dist_m,
            CASE WHEN sh.hours_known THEN hours_open_at(sh.hours, $2) ELSE NULL END AS open_now
     FROM seg_idx s
     JOIN LATERAL (
       SELECT * FROM shops x
       WHERE ST_DWithin(x.geom, s.g, $1)
       ORDER BY ST_Distance(x.geom, s.g) DESC LIMIT 40
     ) sh ON true`,
    [req.corridorM, atIso],
  );

  const out: ShopsRows = {};
  for (const row of res.rows as Array<Record<string, unknown>>) {
    const i = Number(row.i);
    out[i] ??= { items: [], total: 0, hoursKnownCount: 0, unknownCount: 0, nearestOpenM: null };
    const openNow = row.open_now;
    const hoursKnown = Boolean(row.hours_known);
    out[i].items.push({
      category: String(row.category),
      open: hoursKnown ? (openNow === true ? true : openNow === false ? false : null) : null,
      hoursProvenance: hoursKnown ? (row.source === 'google' ? 'google' : 'osm') : 'model_est',
      weight: 1,
      distanceToRouteM: Number(row.dist_m ?? 0),
    });
    out[i].total += 1;
    if (hoursKnown) {
      out[i].hoursKnownCount += 1;
      if (openNow === true) {
        const d = Number(row.dist_m);
        out[i].nearestOpenM = out[i].nearestOpenM == null ? d : Math.min(out[i].nearestOpenM, d);
      }
    } else {
      out[i].unknownCount += 1;
    }
  }
  return out;
}

// -------------------------------------------------------------- reports

interface ReportsRows {
  [i: number]: ReportObservation[];
}

async function reportsQuery(client: PoolClient, req: CorridorRequest): Promise<ReportsRows> {
  const res = await client.query(
    `SELECT s.i, r.severity, r.trust_score, r.created_at,
            ST_SnapToGrid(r.geom, 0.0009)::text AS cell
     FROM seg_idx s
     JOIN safety_reports r ON ST_DWithin(r.geom, s.g, 60)
     WHERE r.status = 'published'
       AND r.created_at >= now() - interval '90 days'`,
    [],
  );
  const out: ReportsRows = {};
  const now = Date.now();
  for (const row of res.rows as Array<Record<string, unknown>>) {
    const i = Number(row.i);
    out[i] ??= [];
    out[i].push({
      severity: Number(row.severity ?? 3),
      trust: Number(row.trust_score ?? 0.5),
      ageHours: (now - Date.parse(String(row.created_at))) / 3600e3,
      cell: String(row.cell).slice(0, 24),
    });
  }
  return out;
}

// ------------------------------------------------------------ emergency

interface EmergencyRows {
  [i: number]: EmergencyObservation;
}

async function emergencyQuery(client: PoolClient, req: CorridorRequest): Promise<EmergencyRows> {
  const res = await client.query(
    `SELECT s.i,
            min(ST_Distance(e.geom::geography, s.g::geography)) FILTER (WHERE e.type='police') AS police_m,
            min(ST_Distance(e.geom::geography, s.g::geography)) FILTER (WHERE e.type='hospital') AS hospital_m
     FROM seg_idx s
     JOIN emergency_locations e ON ST_DWithin(e.geom, s.g, 2000)
     GROUP BY s.i`,
    [],
  );
  const out: EmergencyRows = {};
  for (const row of res.rows as Array<Record<string, unknown>>) {
    out[Number(row.i)] = {
      nearestPoliceM: row.police_m != null ? Math.round(Number(row.police_m)) : null,
      nearestHospitalM: row.hospital_m != null ? Math.round(Number(row.hospital_m)) : null,
      provenance: 'osm',
    };
  }
  return out;
}

// ------------------------------------------------------------- assemble

function buildSegmentInputs(
  segs: Array<{ geojson: string }>,
  req: CorridorRequest,
  lights: LightsRows,
  shops: ShopsRows,
  reports: ReportsRows,
  emergency: EmergencyRows,
  hwByIndex: Record<number, string> = {},
): SegmentInput[] {
  const hour = istHour(req.at);
  const out: SegmentInput[] = [];
  let running = 0;
  for (let i = 0; i < segs.length; i++) {
    const coords = req.segments[i];
    const lengthM = polylineLengthM(coords);
    const lightObs: LightObservation | null = lights[i]
      ? {
          count: lights[i].count,
          verifiedCount: lights[i].verified,
          estCount: Math.max(0, lights[i].count - lights[i].verified),
          sampledPoints: lights[i].sampled,
          coveredPoints: lights[i].covered,
          maxGapM: lights[i].maxGapM,
          provenance: lights[i].provenance,
          maxAgeDays: lights[i].maxAgeDays,
        }
      : null;
    const shopsObs: ShopsObservation | null = shops[i] ?? null;
    const activity: ActivityObservation = {
      // model prior (plan §6.4 estimate-plane; honest provenance)
      prior: Math.min(1, 0.5 * (HOUR_ACTIVITY_FACTOR[hour] ?? 0.5)),
      conf: 0.45,
      provenance: 'model_est',
    };
    const reportsObs: ReportObservation[] = reports[i] ?? [];
    const emergencyObs: EmergencyObservation | null = emergency[i] ?? null;

    out.push({
      id: `seg_${i}_${Math.round(running)}`,
      index: i,
      lengthM: Math.round(lengthM),
      highwayClass: (hwByIndex[i] as RoadClass) ?? 'unknown',
      lights: lightObs,
      shops: shopsObs,
      activity,
      reports: reportsObs,
      emergency: emergencyObs,
      roadQuality: null,
    });
    running += lengthM;
  }
  return out;
}

/** IST local hour (plan: business hours compare IST wall-clock). */
export function istHour(at: Date): number {
  const ist = new Date(at.getTime() + (330 - at.getTimezoneOffset()) * 60e3);
  return ist.getHours();
}

function polylineLengthM(coords: number[][]): number {
  let d = 0;
  for (let i = 1; i < coords.length; i++) {
    d += haversineM([coords[i - 1][1], coords[i - 1][0]], [coords[i][1], coords[i][0]]);
  }
  return d;
}

let poolRef: Pool | null = null;
void poolRef;

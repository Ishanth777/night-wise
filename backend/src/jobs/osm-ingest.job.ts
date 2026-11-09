/**
 * Phase 2 data ingestion (plan §6): OSM extract → roads, road_segments,
 * shops (with parsed hours), emergency_locations.
 *
 * Principles (non-negotiable):
 *  - Only REAL OSM data is imported. Model estimates are stored explicitly
 *    as `est_*_prior` / `est_*_conf` columns and marked `model_est` provenance.
 *  - Streetlights are NOT fabricated: streetlights table stays empty unless a
 *    verified/civic source or crowd data exists (plan §6.3). Where OSM tags
 *    `lit=yes` exist they inform road_segments.lit_tag, provenance 'osm'.
 *  - Unknown opening hours stay unknown (hours_known=false, hours=null).
 */
import { execFileSync } from 'node:child_process';
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';
import path from 'node:path';
import log from '../lib/logger.js';
import { getPool } from '../db/pool.js';
import { parseOpeningHours, type HoursRules } from '../lib/openhours.js';

const OSMIUM_IMAGE = process.env.OSMIUM_IMAGE ?? 'krizleebear/docker-osmium-tool:v1.19.1';
const PBF_PATH = path.resolve(process.env.OSM_PBF_PATH ?? 'data/bengaluru-latest.osm.pbf');

export interface IngestResult {
  roads: number;
  segments: number;
  shops: number;
  emergency: number;
  poiHoursKnown: number;
}

const ROAD_CLASS_MAP: Record<string, string> = {
  motorway: 'trunk', motorway_link: 'trunk', trunk: 'trunk', trunk_link: 'trunk',
  primary: 'primary', primary_link: 'primary',
  secondary: 'secondary', secondary_link: 'secondary',
  tertiary: 'tertiary', tertiary_link: 'tertiary',
  unclassified: 'residential', residential: 'residential', living_street: 'residential',
  service: 'service', track: 'service',
  footway: 'footway', path: 'path', pedestrian: 'footway', steps: 'footway', cycleway: 'path',
};

const CATEGORY_MAP: Record<string, string> = {
  convenience: 'kirana', supermarket: 'grocery', greengrocer: 'grocery', general: 'kirana',
  department_store: 'grocery', bakery: 'bakery', pharmacy: 'pharmacy', chemist: 'pharmacy',
  restaurant: 'restaurant', fast_food: 'fast_food', cafe: 'cafe', atm: 'atm',
  bank: 'bank', fuel: 'fuel', clinic: 'clinic', police: 'police', hospital: 'hospital',
  food_court: 'restaurant', tea: 'tea_stall', ice_cream: 'cafe', clothes: 'other',
  office: 'office', company: 'office', ngo: 'office', government: 'office',
};

interface OsmFeature {
  id: string;
  properties: Record<string, string>;
  geometry: { type: string; coordinates: unknown };
}

export async function ingestOsmExtract(): Promise<IngestResult> {
  const started = Date.now();
  log.info(`ingest: extracting from ${PBF_PATH}`);
  await osmium(['tags-filter', '--overwrite', `/data/${path.basename(PBF_PATH)}`,
    'w/highway', '-o', '/data/_filtered_roads.osm.pbf']);
  await osmium(['export', '-f', 'geojsonseq', '--overwrite', '/data/_filtered_roads.osm.pbf',
    '-o', '/data/_roads.geojsonseq', '--add-unique-id=type_id']);
  await osmium(['tags-filter', '--overwrite', `/data/${path.basename(PBF_PATH)}`,
    'n/shop', 'n/amenity', 'n/office', 'w/shop', 'w/amenity', '-o', '/data/_filtered_pois.osm.pbf']);
  await osmium(['export', '-f', 'geojsonseq', '--overwrite', '/data/_filtered_pois.osm.pbf',
    '-o', '/data/_pois.geojsonseq', '--add-unique-id=type_id']);

  const result = await importAll();

  await stampDataSources(result);
  log.info({ ...result, ms: Date.now() - started }, 'ingest complete');
  return result;
}

function osmium(args: string[]): void {
  execFileSync('docker', [
    'run', '--rm',
    '-v', `${path.dirname(PBF_PATH)}:/data`,
    OSMIUM_IMAGE,
    'osmium', ...args,
  ], { stdio: ['ignore', 'ignore', 'inherit'] });
}

async function importAll(): Promise<IngestResult> {
  const pool = getPool();
  const client = await pool.connect();
  const stats: IngestResult = { roads: 0, segments: 0, shops: 0, emergency: 0, poiHoursKnown: 0 };
  try {
    await client.query('BEGIN');
    await client.query('TRUNCATE road_segments, roads');
    await client.query(`DELETE FROM shops WHERE source='osm'`);
    await client.query(`DELETE FROM emergency_locations WHERE source='osm'`);

    stats.roads = await importRoads(client);
    stats.segments = await buildSegments(client);
    const p = await importPois(client);
    stats.shops = p.shops;
    stats.emergency = p.emergency;
    stats.poiHoursKnown = p.hoursKnown;
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
  return stats;
}

// ------------------------------------------------------------------ roads

async function importRoads(client: PoolClient): Promise<number> {
  let count = 0;
  const BATCH = 500;
  let batch: Array<{
    id: number; name: string | null; cls: string; oneway: boolean;
    foot: string | null; lit: string | null; props: string; wkt: string;
  }> = [];

  const flush = async () => {
    if (batch.length === 0) return;
    await client.query(
      `INSERT INTO roads (osm_way_id, name, class, oneway, foot_access, lit_tag, props, geom)
       SELECT u.id, u.name, u.cls, u.oneway, u.foot, u.lit, u.props::jsonb,
              ST_GeomFromEWKT('SRID=4326;' || u.wkt)
       FROM UNNEST($1::bigint[], $2::text[], $3::text[], $4::boolean[], $5::text[], $6::text[], $7::text[], $8::text[])
         AS u(id, name, cls, oneway, foot, lit, props, wkt)
       ON CONFLICT (osm_way_id) DO NOTHING`,
      [
        batch.map((r) => r.id), batch.map((r) => r.name), batch.map((r) => r.cls),
        batch.map((r) => r.oneway), batch.map((r) => r.foot), batch.map((r) => r.lit),
        batch.map((r) => r.props), batch.map((r) => r.wkt),
      ],
    );
    count += batch.length;
    batch = [];
  };

  await eachNdjsonFeature('data/_roads.geojsonseq', async (f) => {
    if (f.geometry.type !== 'LineString') return;
    const p = f.properties;
    // osmium --add-unique-id=type_id produces ids like "w123456" / "n42"
    const osmId = Number(String(f.id).replace(/\D/g, ''));
    if (!osmId) return;
    const hw = p.highway ?? 'road';
    batch.push({
      id: osmId,
      name: p.name ?? null,
      cls: ROAD_CLASS_MAP[hw] ?? 'unknown',
      oneway: p.oneway === 'yes',
      foot: p.foot ?? null,
      lit: p.lit ?? null,
      props: safePropsJson(p),
      wkt: `LINESTRING(${coordsToWkt(f.geometry.coordinates as number[][])})`,
    });
    if (batch.length >= BATCH) await flush();
  });
  await flush();
  return count;
}

// -------------------------------------------------------------- segments

/**
 * Split roads into ≤250 m segments in SQL (plan §8), attach estimated
 * lighting/activity priors per road class (ESTIMATE provenance conf=0.25).
 */
async function buildSegments(client: PoolClient): Promise<number> {
  const res = await client.query(`
    WITH bounds AS (
      SELECT id,
             (ST_Length(ST_Transform(geom, 3857))::numeric) AS len_3857,
             ST_Transform(geom, 3857) AS g3857
      FROM roads
    ), chunks AS (
      SELECT b.id, gs.i,
             ST_LineSubstring(b.g3857,
               (gs.i * 250.0) / GREATEST(b.len_3857, 1),
               LEAST(((gs.i + 1) * 250.0) / b.len_3857, 1.0)) AS seg3857
      FROM bounds b
      CROSS JOIN LATERAL generate_series(0, LEAST(GREATEST(FLOOR(b.len_3857 / 250)::int, 0), 500)) gs(i)
      WHERE ((gs.i * 250.0) / GREATEST(b.len_3857, 1)) < 1.0
    )
    INSERT INTO road_segments (road_id, seq, geom, length_m, highway_class,
                               est_lit_prior, est_lit_prior_conf, lit_tag, foot_access)
    SELECT c.id, c.i,
           ST_Transform(c.seg3857, 4326),
           ST_Length(c.seg3857)::double precision,
           r.class,
           CASE r.class
             WHEN 'trunk' THEN 0.75 WHEN 'primary' THEN 0.75
             WHEN 'secondary' THEN 0.65 WHEN 'tertiary' THEN 0.55
             WHEN 'residential' THEN 0.35 WHEN 'service' THEN 0.25
             WHEN 'footway' THEN 0.30 WHEN 'path' THEN 0.15
             ELSE 0.35 END,
           0.25,
           r.lit_tag, r.foot_access
    FROM chunks c JOIN roads r ON r.id = c.id
  `);
  return res.rowCount ?? 0;
}

type PoolClient = import("pg").PoolClient;

// -------------------------------------------------------------- POIs

async function importPois(client: PoolClient): Promise<{
  shops: number; emergency: number; hoursKnown: number;
}> {
  const stats = { shops: 0, emergency: 0, hoursKnown: 0 };
  await eachNdjsonFeature('data/_pois.geojsonseq', async (f) => {
    const p = f.properties ?? {};
    const tags = p; // osmium export: tags land as flat properties
    const pt = centroid(f);
    if (!pt) return;

    // emergency stations (plan §6.5)
    if (tags.amenity === 'police' || tags.amenity === 'hospital') {
      await client.query(
        `INSERT INTO emergency_locations (type, name, contact, verified, source, geom)
         VALUES ($1, $2, $3, false, 'osm', ST_MakePoint($4, $5))`,
        [tags.amenity, tags.name ?? null, tags.phone ?? tags['contact:phone'] ?? null, pt[1], pt[0]],
      );
      stats.emergency += 1;
      return;
    }

    const category = poiCategory(tags);
    if (!category) return;
    const parsed = parseOpeningHours(tags.opening_hours);
    await client.query(
      `INSERT INTO shops (source, source_id, name, category, hours_known, hours, verified, geom)
       VALUES ('osm', $1, $2, $3, $4, $5, false, ST_MakePoint($6, $7))
       ON CONFLICT (source, source_id) DO UPDATE
         SET hours_known = $4, hours = $5, source_updated_at = now(), geom = ST_MakePoint($6, $7)`,
      [f.id, tags.name ?? null, category, parsed.known, unpackHours(parsed.hours), pt[1], pt[0]],
    );
    if (parsed.known) stats.hoursKnown += 1;
    stats.shops += 1;
  });
  return stats;
}

function poiCategory(tags: Record<string, string>): string | null {
  if (tags.shop) return CATEGORY_MAP[tags.shop] ?? 'other';
  if (tags.amenity) {
    if (tags.amenity === 'police' || tags.amenity === 'hospital') return null; // handled above
    return CATEGORY_MAP[tags.amenity] ?? 'other';
  }
  if (tags.office) return 'office';
  return null;
}

function unpackHours(hours: HoursRules | null): string | null {
  return hours ? JSON.stringify(hours) : null;
}

// ---------------------------------------------------------------- helpers

async function eachNdjsonFeature(
  rel: string,
  fn: (f: OsmFeature) => Promise<void>,
): Promise<void> {
  const file = path.join(path.dirname(PBF_PATH), path.basename(rel));
  const rl = createInterface({ input: createReadStream(file, 'utf8'), crlfDelay: Infinity });
  for await (const line of rl) {
    // osmium geojsonseq prepends an RS (0x1e) byte per record — strip before parse
    const json = line.replace(/^\u001e/, '');
    if (!json) continue;
    let f: OsmFeature | null = null;
    try { f = JSON.parse(json); } catch { continue; }
    if (f) await fn(f);
  }
}

function coordsToWkt(coords: number[][]): string {
  return coords.map((c) => `${c[0]} ${c[1]}`).join(',');
}

function safePropsJson(p: Record<string, string>): string {
  return JSON.stringify(p);
}

function centroid(f: OsmFeature): [number, number] | null {
  const g = f.geometry as { type: string; coordinates: number[] | number[][] | number[][][] };
  const c = g?.coordinates;
  if (!c) return null;
  switch (g.type) {
    case 'Point': return [c[1] as number, c[0] as number];
    case 'LineString': {
      const pts = c as number[][];
      const mid = pts[Math.floor(pts.length / 2)];
      return mid ? [mid[1], mid[0]] : null;
    }
    case 'Polygon': {
      const ring = (c as number[][][])[0];
      if (!ring?.length) return null;
      let sx = 0, sy = 0;
      for (const pt of ring) { sx += pt[0]; sy += pt[1]; }
      return [sy / ring.length, sx / ring.length];
    }
    default: return null;
  }
}

async function stampDataSources(r: IngestResult): Promise<void> {
  const pool = getPool();
  await pool.query(
    `INSERT INTO data_sources (key, name, trust_rank, update_freq, last_synced_at, last_status, meta)
     VALUES ('osm_pbf', 'OpenStreetMap Bengaluru extract (Geofabrik southern-zone → bbox)', 2, 'monthly', now(), 'ok', $1),
            ('osm_poi', 'OSM POIs (shops/amenities/offices, Bengaluru extract)', 2, 'monthly', now(), 'ok', $2)
     ON CONFLICT (key) DO UPDATE
       SET last_synced_at = now(), last_status='ok',
           meta = EXCLUDED.meta`,
    [
      JSON.stringify({ roads: r.roads, segments: r.segments }),
      JSON.stringify({ pois: r.shops, hoursKnown: r.poiHoursKnown, emergency: r.emergency }),
    ],
  );
}

// ------------------------------------------------------------------- main

if (process.argv[1]?.endsWith('osm-ingest.job.ts')) {
  ingestOsmExtract()
    .then((r) => { console.log('INGEST OK', r); process.exit(0); })
    .catch((e) => { console.error('INGEST FAILED', e); process.exit(1); });
}

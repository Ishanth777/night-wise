/**
 * Route Ranking Service (plan §10.2 pipeline):
 *  geocode/validate → Valhalla candidates → segmentize ≤250 m → corridor data
 *  → pure scoring engine → prune (detour budget, near-duplicates)
 *  → label (safest/fastest/balanced) → payload (plan §11.2 shape).
 */
import { createHash } from 'node:crypto';
import { modeConfig } from '../config/scoring.js';
import { getValhallaAlternates, type ValhallaRouteCandidate } from '../integrations/valhalla.js';
import { corridorData } from './geodata.service.js';
import { scoreRoute } from '../scoring/engine.js';
import { grade, type Mode, type RouteScoreOutput } from '../scoring/types.js';
import { cacheGet, cacheSet } from '../lib/cache.js';
import log from '../lib/logger.js';
import type { RecommendRequest } from '../api/schemas/index.js';

const DISCLAIMER =
  'NightWise safety scores are environmental estimates based on available indicators, not guarantees of personal safety.';

interface Evaluated {
  idx: number;
  candidate: ValhallaRouteCandidate;
  scored: RouteScoreOutput;
}

export interface RouteOptionDto {
  routeId: string;
  label: 'safest' | 'fastest' | 'balanced' | 'alternative';
  summary: {
    distanceM: number;
    durationS: number;
    safetyScore: number;
    confidence: number;
    safetyGrade: 'good' | 'moderate' | 'poor';
    tradeOff: string;
  };
  geometry: { type: 'LineString'; coordinates: number[][] };
  indicators: Record<string, unknown>;
  segments: Array<Record<string, unknown>>;
  warnings: string[];
  dataHealth: { streetlightProvenance: string; notes: string };
}

export interface RecommendationPayload {
  requestId: string;
  mode: Mode;
  computedFor: string;
  routes: RouteOptionDto[];
  dataHealth: Record<string, unknown>;
  disclaimer: string;
  meta: { took: number; cache: 'HIT' | 'MISS'; version: string };
}

export async function recommend(req: RecommendRequest): Promise<RecommendationPayload> {
  const t0 = Date.now();
  const at = new Date(req.departureTime); // zod returns string; scoring uses Date
  const cacheKey = recCacheKey(req, at);

  const cachedRaw = await cacheGet(cacheKey);
  if (cachedRaw) {
    const payload = JSON.parse(cachedRaw) as RecommendationPayload;
    payload.meta = { ...payload.meta, cache: 'HIT' };
    return payload;
  }

  const candidates = await getValhallaAlternates(
    { lat: req.origin.lat, lon: req.origin.lng },
    { lat: req.destination.lat, lon: req.destination.lng },
    { mode: req.mode, vehicleType: req.vehicleType, time: at },
  );
  ensure(candidates.length > 0, 'ROUTING_UNAVAILABLE', 'Valhalla returned no candidate routes');

  // score every candidate
  const evaluated: Evaluated[] = [];
  for (let i = 0; i < candidates.length; i++) {
    const cfg = modeConfig(req.mode);
    const segments = await corridorForCandidate(candidates[i], req.mode, {
      lightRadiusM: cfg.coverageRadius,
      corridorM: cfg.corridor,
    }, at);
    const scored = scoreRoute(segments, { mode: req.mode, at, darkHours: isDark(at) });
    evaluated.push({ idx: i, candidate: candidates[i], scored });
  }

  // prune near-identical geometries (plan §10.2 step 6)
  const unique = dedupeByIdentity(evaluated);

  // detour budget (plan §9.6 / Appendix A); always keep the engine's fastest (idx 0)
  const fastestS = Math.min(...unique.map((e) => e.candidate.durationS));
  const cfg = modeConfig(req.mode);
  const budgetS = Math.min(cfg.detour.maxExtraMin * 60, cfg.detour.maxFactor * fastestS);
  const within = unique.filter((e) => e.candidate.durationS <= fastestS + budgetS || e.idx === 0);
  const usable = within.length >= Math.min(3, unique.length) ? within : unique.slice(0, 3);

  const dtos = usable.map((e) => buildRouteDto(e, usable));

  // labelling (plan §11.2)
  const fastestIdx = usable.reduce((best, e, i) => (e.candidate.durationS < usable[best].candidate.durationS ? i : best), 0);
  const safestIdx = dtos.reduce((best, d, i) => (d.summary.safetyScore > dtos[best].summary.safetyScore ? i : best), 0);
  const slider = req.userPrefs.safetyVsTime;
  const dMin = Math.min(...usable.map((e) => e.candidate.durationS));
  const dMax = Math.max(...usable.map((e) => e.candidate.durationS));
  const balancedIdx = dtos.reduce((best, d, i) => {
    const u = (slider * d.summary.safetyScore) / 100 - (1 - slider) * norm(usable[i].candidate.durationS, dMin, dMax);
    const ub = (slider * dtos[best].summary.safetyScore) / 100 - (1 - slider) * norm(usable[best].candidate.durationS, dMin, dMax);
    return u > ub ? i : best;
  }, 0);

  const routes: RouteOptionDto[] = dtos.map((dto, i) => ({
    ...dto,
    label: (i === safestIdx ? 'safest' : i === fastestIdx ? 'fastest' : i === balancedIdx ? 'balanced' : 'alternative') as RouteOptionDto['label'],
    summary: {
      ...dto.summary,
      tradeOff: buildTradeOff(dto, dtos[fastestIdx], dtos[safestIdx]),
    },
  }));

  const payload: RecommendationPayload = {
    requestId: `rw_${createHash('sha256').update(cacheKey).digest('hex').slice(0, 10)}`,
    mode: req.mode,
    computedFor: at.toISOString(),
    routes: routes as RouteOptionDto[],
    dataHealth: buildDataHealth(routes),
    disclaimer: DISCLAIMER,
    meta: { took: Date.now() - t0, cache: 'MISS', version: '1.0' },
  };

  // plan §11.2: identical (mode+OD rounded+time bucket) requests collapse
  await cacheSet(cacheKey, JSON.stringify({ ...payload, meta: { ...payload.meta, took: 0 } }), 600);
  log.info({ took: payload.meta.took, n: payload.routes.length }, 'recommend complete');
  return payload;
}

// ----------------------------------------------------------- internals

async function corridorForCandidate(
  c: ValhallaRouteCandidate,
  mode: Mode,
  params: { lightRadiusM: number; corridorM: number },
  at: Date,
) {
  const coords = c.geometry.map((p) => [Number(p[0]), Number(p[1])]);
  const segments = splitAt250(coords);
  return corridorData({
    mode,
    at,
    segments,
    lightRadiusM: params.lightRadiusM,
    corridorM: params.corridorM,
  });
}

function splitAt250(coords: number[][]): number[][][] {
  const segs: number[][][] = [];
  let cur: number[][] = [coords[0]];
  let len = 0;
  for (let i = 1; i < coords.length; i++) {
    const step = haversineM(coords[i - 1], coords[i]);
    if (cur.length >= 2 && len + step > 250) {
      segs.push(cur);
      cur = [coords[i - 1]];
      len = 0;
    }
    cur.push(coords[i]);
    len += step;
  }
  if (cur.length >= 2) segs.push(cur);
  return segs;
}

function haversineM(a: number[], b: number[]): number {
  const R = 6371000, rad = Math.PI / 180;
  const dLat = (b[1] - a[1]) * rad;
  const dLng = (b[0] - a[0]) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a[1] * rad) * Math.cos(b[1] * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function isDark(at: Date): boolean {
  // IST night-time heuristics (plan FR-105) — lighting matters 18:00–06:00 IST
  const istHour = (at.getTime() + 5.5 * 3600e3) % 86400e3 / 3600e3;
  const h = Math.floor(istHour);
  return h >= 18 || h < 6;
}

function norm(v: number, min: number, max: number): number {
  return max > min ? (v - min) / (max - min) : 0;
}

function dedupeByIdentity(evaluated: Evaluated[]): Evaluated[] {
  const kept: Evaluated[] = [];
  for (const e of evaluated) {
    const dup = kept.some((k) => sharedEndsRatio(k.candidate.geometry, e.candidate.geometry) > 0.85);
    if (!dup) kept.push(e);
  }
  return kept;
}

/** fraction of sampled anchor vertices that lie within ~20 m of the other geometry */
function sharedEndsRatio(a: number[][], b: number[][]): number {
  const sample = [a[Math.floor(a.length * 0.25)] ?? a[0], a[Math.floor(a.length * 0.75)] ?? a[0]];
  const hit = sample.filter((p) => b.some((q) => haversineM(p, q) < 20)).length;
  return hit / sample.length;
}

function buildRouteDto(e: Evaluated, byIndex: Evaluated[]): RouteOptionDto {
  const o = e.scored;
  const indicatorOutput: Record<string, unknown> = {};
  const keys = Object.keys(o.segments[0]?.indicators ?? {});
  const totalLen = Math.max(1, o.segments.reduce((s, x) => s + x.lengthM, 0));
  for (const k of keys) {
    const lengthWeighted = o.segments.reduce(
      (acc, seg) => acc + (seg.indicators[k as keyof typeof seg.indicators]?.score ?? 0) * seg.lengthM, 0) / totalLen;
    const base = ind(o.segments[0], k);
    indicatorOutput[k] = {
      ...jsonClone(base.details ?? {}),
      score: Math.round(lengthWeighted) ?? 0,
      status: base.status,
      basis: base.basis,
      minLengthScore: Math.min(...o.segments.map((seg) => ind(seg, k)?.score ?? 0)),
      avgConfidence: round2(o.segments.reduce((s, seg) => s + (ind(seg, k)?.conf ?? 0), 0) / o.segments.length),
    };
  }

  const fastest = byIndex.reduce((f, x) => (x.candidate.durationS < f.candidate.durationS ? x : f));

  return {
    routeId: `rt_${e.idx}_${hashGeometry(e)}`,
    label: 'alternative',
    summary: {
      distanceM: Math.round(e.candidate.lengthKm * 1000),
      durationS: Math.round(e.candidate.durationS),
      safetyScore: o.score,
      confidence: o.confidence,
      safetyGrade: grade(o.score),
      tradeOff: fastestSum(e, fastest),
    },
    geometry: { type: 'LineString', coordinates: e.candidate.geometry as number[][] },
    indicators: indicatorOutput,
    segments: o.segments.map((seg) => ({
      segId: seg.index + 1,
      startM: seg.startM,
      endM: seg.endM,
      score: seg.score,
      confidence: seg.confidence,
      indicators: seg.indicators,
      warnings: seg.warnings,
    })),
    warnings: o.warnings,
    dataHealth: {
      streetlightProvenance: mostCommonLightsProvenance(o),
      notes: 'Per-segment data provenance and decision traces in route details.',
    },
  };
}

function fastestSum(e: Evaluated, fastest: Evaluated): string {
  const extraS = Math.max(0, e.candidate.durationS - fastest.candidate.durationS);
  if (extraS < 30) return 'is among the fastest options';
  return `+${Math.round(extraS / 60)} min vs fastest`;
}

function buildTradeOff(dto: RouteOptionDto, fastest: RouteOptionDto, safest: RouteOptionDto): string {
  const extra = Math.max(0, dto.summary.durationS - fastest.summary.durationS);
  const delta = dto.summary.safetyScore - fastest.summary.safetyScore;
  let text = '';
  if (extra > 30) text += `+${Math.round(extra / 60)} min over fastest`;
  if (delta !== 0) {
    text += text ? ', ' : '';
    text += `${delta > 0 ? '+' : ''}${delta} safety points vs fastest`;
  }
  if (dto === safest) text += text ? ' — safest option' : 'safest option';
  return text;
}

function mostCommonLightsProvenance(o: RouteScoreOutput): string {
  const counts: Record<string, number> = { verified: 0, osm_tag: 0, model_est: 0 };
  for (const seg of o.segments) {
    const basis = String(seg.indicators.lights?.basis ?? 'light_model_est');
    if (basis.includes('verified')) counts.verified++;
    else if (basis.endsWith('light_osm')) counts.osm_tag++;
    else counts.model_est++;
  }
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
  return top?.[0] ?? 'model_est';
}

function buildDataHealth(routes: Array<RouteOptionDto>): Record<string, unknown> {
  const prov = routes[0]?.dataHealth.streetlightProvenance ?? 'model_est';
  return {
    streetlightCoverage:
      prov === 'verified'
        ? 'verified lamp-post data on these routes'
        : 'partial — no verified lamp-post dataset confirmed for Bengaluru yet (plan §6.3); OSM lit tags and class priors used where available',
    poiHourCoverage: 'OSM opening_hours + category priors; Google Places augmentation not configured (no API key)',
    notes:
      'Unknown or unverified data lowers score confidence; it is never treated as closed or dangerous (plan FR-202). ' +
      'Long zero-data stretches are capped honestly (plan §9.8).',
  };
}

function recCacheKey(req: RecommendRequest, at: Date): string {
  const round = (p: { lat: number; lng: number }) => `${p.lat.toFixed(4)},${p.lng.toFixed(4)}`;
  const ist = new Date(at.getTime() + 5.5 * 3600e3);
  const bucket = `${Math.floor(ist.getTime() / 86400e3)}:${Math.floor((ist.getUTCHours() * 60 + ist.getUTCMinutes()) / 10)}`;
  return `rec:${req.mode}:${round(req.origin)}:${round(req.destination)}:${bucket}:${req.userPrefs.safetyVsTime}`;
}

function hashGeometry(e: Evaluated): string {
  return createHash('sha256').update(JSON.stringify(e.candidate.geometry.slice(0, 1))).digest('hex').slice(0, 6);
}

function ind(seg: RouteScoreOutput['segments'][number], k: string) {
  return (seg.indicators as Record<string, import('../scoring/types.js').IndicatorOutput>)[k];
}

function jsonClone<T>(v: T): T {
  return v == null ? v : (JSON.parse(JSON.stringify(v)) as T);
}

function round2(x: number): number {
  return Math.round(x * 100) / 100;
}

/** typed error helper used across services (plan error matrix §11.2) */
export function ensure(cond: unknown, code: string, message: string): asserts cond {
  if (!cond) {
    throw Object.assign(new Error(message), { code });
  }
}

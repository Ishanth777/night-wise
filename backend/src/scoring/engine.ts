import { modeConfig } from '../config/scoring.js';
import {
  activityPrior, communityPrior, emergencyPrior, lightsPrior, roadQualityPrior, shopsPrior,
} from './priors.js';
import { aggregateRoute } from './aggregate.js';
import {
  normalizeActivity, normalizeEmergency, normalizeLights, normalizeReports, normalizeRoadQuality, normalizeShops,
} from './normalizers/index.js';
import type {
  IndicatorKey, IndicatorOutput, RouteScoreOutput, ScoringContext, SegmentInput, SegmentOutput,
} from './types.js';
import { SCORING } from '../config/scoring.js';
import { clamp01 } from './util.js';

/**
 * Safety Scoring Engine (plan §9) — PURE module, zero I/O, zero DB.
 * Inputs are prepared corridor data; output is scores + decision trace.
 * Unit-tested against golden fixtures (plan §9.5 + Appendix B).
 */
export function scoreSegments(input: SegmentInput[], ctx: ScoringContext): {
  segments: SegmentOutput[];
  lightCoverage: number[];
} {
  const cfg = SCORING.modes[ctx.mode];
  // Business hours and activity priors are IST wall-clock (plan FR-105).
  const hour = new Date(ctx.at.getTime() + 5.5 * 3600e3).getUTCHours();
  const segments: SegmentOutput[] = [];
  const lightCoverage: number[] = [];
  let startM = 0;

  for (const seg of input) {
    const keys: IndicatorKey[] = ['lights', 'shops', 'activity', 'community', 'emergency', 'road_quality'];

    // --- normalize each indicator from raw data ---
    const lightsN = normalizeLights(seg.lights, { verified: seg.lights?.provenance === 'verified' });
    const shopsN = normalizeShops(seg.shops, {
      corridor: cfg.corridor, saturation: cfg.saturation, hour,
    }, (cat, h) => categoryOpenPrior(cat, h));
    const activityN = normalizeActivity(seg.activity);
    const reportsN = normalizeReports(seg.reports, {
      now: ctx.at, tauDays: SCORING.decline.reportTauDays, capRaw: SCORING.decline.reportCapRaw,
    });
    const emergencyN = normalizeEmergency(seg.emergency);
    const roadQN = ctx.mode === 'vehicle' ? normalizeRoadQuality(seg.roadQuality) : null;

    const raw = {
      lights: lightsN, shops: shopsN, activity: activityN,
      community: reportsN, emergency: emergencyN, road_quality: roadQN,
    };

    // --- confidence blending toward priors (plan §9.2) ---
    const indicators: Partial<Record<IndicatorKey, IndicatorOutput>> = {};
    const usedPriors: Record<string, number> = {};
    const confidences: Record<string, number> = {};
    const rawCounts: Record<string, number> = {
      segments: 1,
      lights: seg.lights?.count ?? 0,
      shops: seg.shops?.total ?? 0,
      reports: seg.reports?.length ?? 0,
    };

    for (const k of keys) {
      const cfgWeight = cfg.weights[k];
      if (!cfgWeight || cfgWeight <= 0) continue;

      const priorVal = priorFor(k, ctx.mode, seg.highwayClass, hour);
      const n = raw[k];
      if (!n) continue;
      const conf = clamp01(n.conf);
      const blended = conf * n.value + (1 - conf) * priorVal;

      indicators[k] = {
        score: Math.round(blended),
        raw: n.value,
        conf,
        prior: Math.round(priorVal),
        status: conf < 0.35 && n.value === 0 ? 'limited_data' : n.status,
        basis: n.basis,
        details: n.details,
      };
      usedPriors[k] = priorVal;
      confidences[k] = conf;
    }

    // --- effective weight re-normalization (plan §9.2) ---
    let wSum = 0;
    const weighted: Array<{ k: IndicatorKey; w: number; s: number }> = [];
    for (const k of keys) {
      const w = cfg.weights[k];
      if (!w || !(k in indicators)) continue;
      const conf = confidences[k];
      const eff = w * conf + 0.10 * (1 - conf);
      weighted.push({ k, w: eff, s: indicators[k]!.score });
      wSum += eff;
    }
    let score = 0;
    if (wSum > 0) {
      for (const e of weighted) score += (e.w / wSum) * e.s;
    }

    const coverageRatio = (indicators.lights?.details?.coverageRatio as number | undefined) ?? 0;
    lightCoverage.push(coverageRatio);

    const segScore = Math.round(score);
    const segConf = weighted.length > 0 && wSum > 0
      ? weighted.reduce((acc, e) => acc + (e.w / wSum) * confidences[e.k], 0)
      : 0;

    segments.push({
      id: seg.id,
      index: seg.index,
      startM,
      endM: startM + seg.lengthM,
      lengthM: seg.lengthM,
      score: segScore,
      confidence: Number(segConf.toFixed(2)),
      indicators,
      warnings: buildSegmentWarnings(seg, indicators, segScore),
      trace: { rawCounts, usedPriors, confidences },
    });
    startM += seg.lengthM;
  }
  return { segments, lightCoverage };
}

export function scoreRoute(input: SegmentInput[], ctx: ScoringContext): RouteScoreOutput {
  const { segments, lightCoverage } = scoreSegments(input, ctx);

  const agg = aggregateRoute(segments, { mode: ctx.mode, lightCoverageBySegment: lightCoverage });

  // ---- confidence: length-weighted mean of segment confidences ----
  const totalLen = segments.reduce((s, x) => s + x.lengthM, 0) || 1;
  const confidence = Number(
    (segments.reduce((s, x) => s + x.confidence * x.lengthM, 0) / totalLen).toFixed(2),
  );

  // ---- warnings aggregation ----
  const warnings = new Set<string>();
  for (const s of segments) for (const w of s.warnings) warnings.add(w);

  // ---- low-data cap (plan §9.8): silence ≠ safety ----
  let cappedByLowData = false;
  const relevant = segments.filter((s) => s.indicators.lights?.conf === 0 && s.indicators.shops?.conf === 0);
  const voidLen = relevant.reduce((s, x) => s + x.lengthM, 0);
  const fraction = voidLen / totalLen;
  if (fraction >= SCORING.caps.lowDataMinFraction) {
    cappedByLowData = true;
    warnings.add('low_data_void_stretch');
    if (agg.score > SCORING.caps.lowDataCapScore) {
      agg.score = SCORING.caps.lowDataCapScore;
    }
  }

  return {
    baseScore: agg.baseScore,
    riskPenalty: agg.riskPenalty,
    darkPenalty: agg.darkPenalty,
    endpointPenalty: agg.endpointPenalty,
    cappedByLowData,
    score: agg.score,
    confidence: Math.min(confidence, cappedByLowData ? 0.5 : 1),
    segments,
    warnings: [...warnings],
  };
}

function priorFor(
  k: IndicatorKey, mode: Parameters<typeof lightsPrior>[0], roadClass: SegmentInput['highwayClass'], hour: number,
): number {
  switch (k) {
    case 'lights': return lightsPrior(mode, roadClass, hour);
    case 'shops': return shopsPrior(mode, roadClass, hour);
    case 'activity': return activityPrior(mode, roadClass, hour);
    case 'community': return communityPrior(mode, roadClass, hour);
    case 'emergency': return emergencyPrior(mode, roadClass);
    case 'road_quality': return roadQualityPrior(mode, roadClass);
  }
}

function categoryOpenPrior(cat: string, hour: number): number {
  const entry = SCORING.shops.categoryOpenPrior[cat];
  if (!entry) return SCORING.shops.categoryOpenPrior.other?.default ?? 0.35;
  const byHour = entry.byHour;
  if (byHour && byHour[hour] != null) return byHour[hour];
  return entry.default;
}

export function isOpenPriorCategoryBound(cat: string): boolean {
  // A category is "strongly hour-bound" when its closed-hours prior is very high
  const entry = SCORING.shops.categoryOpenPrior[cat];
  if (!entry) return true;
  return (entry.default ?? 0) < 0.45;
}

function buildSegmentWarnings(
  seg: SegmentInput,
  indicators: Partial<Record<IndicatorKey, IndicatorOutput>>,
  score: number,
): string[] {
  const warnings: string[] = [];
  const lights = indicators.lights;
  const shops = indicators.shops;

  if (lights) {
    const coverage = Number((lights.details?.coverageRatio as number | undefined) ?? 0);
    if (coverage <= 0.3 && seg.lengthM >= 150) {
      const darkLen = Math.round(seg.lengthM * (1 - coverage));
      warnings.push(darkLen >= 150 ? `dark_stretch_${darkLen}m` : 'dark_stretch');
    }
  }
  if (lights && lights.conf < 0.5) warnings.push('unverified_lighting');
  if (shops && shops.conf < 0.4) warnings.push('low_shop_data_confidence');
  if (seg.lights == null && seg.shops == null) warnings.push('low_data_confidence');
  if (score < 35) warnings.push('low_safety_segment');
  return warnings;
}

import type { Mode } from '../config/scoring.js';
import { SCORING } from '../config/scoring.js';
import type { RouteScoreOutput, SegmentOutput } from './types.js';
import { clamp } from './util.js';

/**
 * Route aggregation (plan §9.3) — risk-dominant, NOT a plain average:
 *
 *   base          = length-weighted mean of segment scores
 *   tail          = "85th-percentile-worst" value (worst-tail threshold; the score
 *                   below which 85% of the route's segment *risk mass* lies,
 *                   computed nearest-rank over ascending scores, matching §9.5)
 *   risk_penalty  = γ · (base − tail)
 *   dark_max      = max over segments of (1 − light_coverage) · (len/300), capped 0.5
 *   endpoint      = +5 if first or last segment is in the lowest quartile
 *   score         = clamp(base − risk_penalty − 12·dark_max − endpoint, 0, 100)
 */
export function aggregateRoute(
  segments: SegmentOutput[],
  ctx: { mode: Mode; lightCoverageBySegment: number[] },
): Pick<RouteScoreOutput, 'baseScore' | 'riskPenalty' | 'darkPenalty' | 'endpointPenalty' | 'score'> {
  const agg = SCORING.aggregate;
  const gamma = SCORING.modes[ctx.mode].gamma;

  const totalLen = segments.reduce((s, x) => s + x.lengthM, 0) || 1;
  const base = totalLen > 0
    ? segments.reduce((s, x) => s + x.score * x.lengthM, 0) / totalLen
    : 0;

  // Worst-tail value: nearest-rank percentile of ascending scores at p = worstTailPercentile of "risk mass"
  // Interpretation consistent with plan §9.5: this is the 15th-percentile score (bad tail).
  const sorted = [...segments].sort((a, b) => a.score - b.score);
  let tail = sorted[0]?.score ?? base;
  const p = 1 - agg.worstTailPercentile; // 0.15
  if (sorted.length > 1) {
    const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil(p * sorted.length) - 1));
    tail = sorted[idx].score;
  }
  const riskPenalty = gamma * Math.max(0, base - tail);

  const darkMax = segments.reduce((mx, seg, i) => {
    const coverage = ctx.lightCoverageBySegment[i] ?? 0;
    return Math.max(mx, Math.min(0.5, (1 - clamp(coverage, 0, 1)) * (seg.lengthM / 300)));
  }, 0);
  const darkPenalty = agg.darkMaxLengthPenalty * darkMax;

  let endpointPenalty = 0;
  if (segments.length >= 2) {
    const scores = segments.map((s) => s.score).sort((a, b) => a - b);
    const q1Idx = Math.max(0, Math.ceil(0.25 * scores.length) - 1);
    const q1 = scores[q1Idx];
    const first = segments[0].score, last = segments[segments.length - 1].score;
    if (first <= q1 || last <= q1) endpointPenalty = agg.endpointPenalty;
  }

  const score = clamp(
    Math.round(base - riskPenalty - darkPenalty - endpointPenalty),
    0, 100,
  );

  return { baseScore: Math.round(base * 10) / 10, riskPenalty: Math.round(riskPenalty * 10) / 10, darkPenalty: Math.round(darkPenalty * 10) / 10, endpointPenalty, score };
}

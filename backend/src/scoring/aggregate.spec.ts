import { describe, it, expect } from 'vitest';
import { aggregateRoute } from './aggregate.js';
import type { SegmentOutput } from './types.js';

/**
 * GOLDEN TEST — plan §9.5 worked example / Appendix B scenario 1.
 *
 * The plan documents the worked example in terms of segment scores
 * (Route A: 79/27/80 over 500/350/750 m; Route B: ~82/78/85 over 1.9 km)
 * and asserts aggregate outcomes: A ≈ 44 ± 2, B ≈ 79 ± 2.
 * We therefore pin the *aggregation formula* against those exact segment
 * scores — the engine's data-driven pipeline is tested separately.
 */

function seg(id: string, index: number, score: number, len: number, coverage: number): SegmentOutput {
  return {
    id, index, startM: 0, endM: len, lengthM: len,
    score, confidence: 0.7,
    indicators: {},
    warnings: [],
    trace: { rawCounts: {}, usedPriors: {}, confidences: {} },
  };
}

const routeA = [
  seg('A1', 0, 79, 500, 0.90),  // main road
  seg('A2', 1, 27, 350, 0.08),  // dark service lane (the risky stretch)
  seg('A3', 2, 80, 750, 0.88),
];
const routeB = [
  seg('B1', 0, 82, 650, 0.90),  // boutique street, lit, active
  seg('B2', 1, 78, 600, 0.90),
  seg('B3', 2, 85, 650, 0.90),
];

describe('aggregateRoute — plan §9.5 golden example', () => {
  it('Route A (fastest, via dark service lane) scores ≈ 44 ± 2', () => {
    const agg = aggregateRoute(routeA, { mode: 'walk', lightCoverageBySegment: [0.9, 0.08, 0.88] });
    // base = (500·79+350·27+750·80)/1600 = 68.09
    expect(agg.baseScore).toBeCloseTo(68.1, 1);
    // worst-tail = lowest score (27); risk_penalty = 0.45·(68.09−27) = 18.5
    expect(agg.riskPenalty).toBeCloseTo(18.5, 1);
    // dark service lane caps dark_max at 0.5 → 6.0
    expect(agg.darkPenalty).toBeCloseTo(6.0, 1);
    expect(agg.endpointPenalty).toBe(0);
    expect(agg.score).toBeGreaterThanOrEqual(42);
    expect(agg.score).toBeLessThanOrEqual(46);
  });

  it('Route B (safest, lit commercial street) scores ≈ 79 ± 2', () => {
    const agg = aggregateRoute(routeB, { mode: 'walk', lightCoverageBySegment: [0.9, 0.9, 0.9] });
    expect(agg.baseScore).toBeCloseTo(81.8, 1);
    expect(agg.riskPenalty).toBeCloseTo(1.7, 0);
    expect(agg.endpointPenalty).toBe(0);
    expect(agg.score).toBeGreaterThanOrEqual(77);
    expect(agg.score).toBeLessThanOrEqual(81);
  });

  it('a well-lit middle cannot compensate a badly-lit stretch (risk dominance)', () => {
    const good = [...routeA];
    good[0] = seg('A1', 0, 100, 500, 1.0);
    good[2] = seg('A3', 2, 100, 750, 1.0);
    const agg = aggregateRoute(good, { mode: 'walk', lightCoverageBySegment: [1, 0.05, 1] });
    // Perfect except the 350m dark stretch — must stay well below 80
    expect(agg.score).toBeLessThan(55);
  });

  it('endpoint penalty triggers when origin/destination segment is in the lowest quartile', () => {
    const s = [
      seg('E1', 0, 60, 400, 0.8), // origin segment is the bad stretch
      seg('E2', 1, 80, 400, 0.8),
      seg('E3', 2, 85, 400, 0.8),
    ];
    const agg = aggregateRoute(s, { mode: 'walk', lightCoverageBySegment: [0.8, 0.8, 0.8] });
    expect(agg.endpointPenalty).toBe(5);
  });

  it('vehicle mode applies a softer risk-dominance factor (γ=0.30)', () => {
    const walk = aggregateRoute(routeA, { mode: 'walk', lightCoverageBySegment: [0.9, 0.08, 0.88] });
    const veh = aggregateRoute(routeA, { mode: 'vehicle', lightCoverageBySegment: [0.9, 0.08, 0.88] });
    expect(veh.riskPenalty).toBeLessThan(walk.riskPenalty);
    expect(veh.score).toBeGreaterThan(walk.score);
  });
});

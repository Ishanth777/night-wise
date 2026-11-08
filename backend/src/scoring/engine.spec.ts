import { describe, it, expect } from 'vitest';
import { scoreRoute, scoreSegments } from './engine.js';
import type { SegmentInput } from './types.js';

/**
 * Engine-level behavior tests (plan §Appendix B scenarios 2-6 + §9.2 blending).
 * Uses fixture "corridor data", never fabricated real-world data.
 */

const NIGHT = new Date('2026-11-08T22:00:00+05:30');
const ctxWalk = { mode: 'walk' as const, at: NIGHT, darkHours: true };

function makeSegment(partial: Partial<SegmentInput> & { id: string; index: number; lengthM: number }): SegmentInput {
  return {
    highwayClass: 'secondary',
    lights: null,
    shops: null,
    activity: { prior: 0.5, conf: 0.5, provenance: 'model_est' },
    reports: [],
    emergency: null,
    roadQuality: null,
    ...partial,
  } as SegmentInput;
}

describe('scoreSegments — uncertainty blending (plan §9.2)', () => {
  it('zero-confidence indicators fall back exactly to priors', () => {
    const seg = makeSegment({
      id: 's1', index: 0, lengthM: 200,
      lights: null, shops: null, activity: { prior: 0.4, conf: 0, provenance: 'model_est' },
    });
    const out = scoreSegments([seg], ctxWalk).segments[0];
    expect(out.indicators.lights!.score).toBe(out.indicators.lights!.prior);
    expect(out.indicators.shops!.score).toBe(out.indicators.shops!.prior);
    expect(out.confidence).toBeLessThan(0.2);
    expect(out.warnings).toContain('low_data_confidence');
  });

  it('high-confidence good data overwhelms the prior', () => {
    const seg = makeSegment({
      id: 's1', index: 0, lengthM: 200,
      lights: {
        count: 20, verifiedCount: 20, estCount: 0,
        sampledPoints: 20, coveredPoints: 20,
        maxGapM: 10, provenance: 'verified', maxAgeDays: 5,
      },
    });
    const out = scoreSegments([seg], ctxWalk).segments[0];
    const lights = out.indicators.lights!;
    expect(lights.score).toBeGreaterThanOrEqual(90);
    // plan §9.2: even at conf 0.85 the prior pulls 15% → 0.85·100 + 0.15·prior(65) ≈ 95
    expect(lights.conf).toBe(0.85);
    expect(out.score).toBeGreaterThan(60);
  });
});

describe('shop availability — FR-202: unknown hours are never "closed"', () => {
  it('unknown-hours shops contribute their category prior, not zero', () => {
    const seg = makeSegment({
      id: 'shop', index: 0, lengthM: 200,
      shops: {
        items: [
          { category: 'pharmacy', open: null, hoursProvenance: 'osm', weight: 1, distanceToRouteM: 20 },
          { category: 'pharmacy', open: null, hoursProvenance: 'osm', weight: 1, distanceToRouteM: 25 },
        ],
        total: 2, hoursKnownCount: 0, unknownCount: 2, nearestOpenM: null,
      },
    });
    const out = scoreSegments([seg], ctxWalk).segments[0];
    const shops = out.indicators.shops!;
    // At 22:00 pharmacy prior is 0.5; two unknown pharmacies must score > 0
    expect(shops.score).toBeGreaterThan(0);
    expect(shops.details!.openCount).toBe(0);
    expect(shops.details!.unknownHours).toBe(2);
    expect(shops.status).not.toBe('poor');
  });

  it('provably-closed hour-bound shops contribute zero; open shops saturate', () => {
    const seg = makeSegment({
      id: 'shop2', index: 0, lengthM: 200,
      shops: {
        items: [
          { category: 'restaurant', open: false, hoursProvenance: 'google', weight: 1, distanceToRouteM: 15 },
          { category: 'kirana', open: true, hoursProvenance: 'verified', weight: 1, distanceToRouteM: 30 },
        ],
        total: 2, hoursKnownCount: 2, unknownCount: 0, nearestOpenM: 30,
      },
    });
    const out = scoreSegments([seg], ctxWalk).segments[0];
    const shops = out.indicators.shops!;
    expect(shops.details!.openCount).toBe(1);
    // 1 open shop contributes w=1.0 → value = 100·(1−e^(−1/3)) ≈ 28 (plan §9.1)
    expect(shops.score).toBeGreaterThanOrEqual(26);
    expect(shops.score).toBeLessThanOrEqual(31);
  });
});

describe('community reports — §9.4 sybil dampening + decay', () => {
  it('duplicated reports in the same cell are dampened 1/√n', () => {
    const one = makeSegment({ id: 'r1', index: 0, lengthM: 200, reports: [
      { severity: 4, trust: 1, ageHours: 1, cell: 'abc' },
    ]});
    const five = makeSegment({ id: 'r2', index: 0, lengthM: 200, reports: [
      { severity: 4, trust: 1, ageHours: 1, cell: 'abc' },
      { severity: 4, trust: 1, ageHours: 1, cell: 'abc' },
      { severity: 4, trust: 1, ageHours: 1, cell: 'abc' },
      { severity: 4, trust: 1, ageHours: 1, cell: 'abc' },
      { severity: 4, trust: 1, ageHours: 1, cell: 'abc' },
    ]});
    const a = scoreSegments([one], ctxWalk).segments[0].indicators.community!;
    const b = scoreSegments([five], ctxWalk).segments[0].indicators.community!;
    // 5 sybil reports must not equal 5× the single-report signal
    expect(b.raw).toBeLessThan(a.raw * 3);
  });

  it('old reports decay toward the calm baseline', () => {
    const fresh = makeSegment({ id: 'r1', index: 0, lengthM: 200, reports: [
      { severity: 4, trust: 1, ageHours: 2, cell: 'a' },
    ]});
    const stale = makeSegment({ id: 'r2', index: 0, lengthM: 200, reports: [
      { severity: 4, trust: 1, ageHours: 90 * 24, cell: 'a' },
    ]});
    const f = scoreSegments([fresh], ctxWalk).segments[0].indicators.community!;
    const s = scoreSegments([stale], ctxWalk).segments[0].indicators.community!;
    expect(f.raw).toBeGreaterThan(s.raw); // fresh report => lower community safety score
  });
});

describe('engine — route-level behavior', () => {
  it('low-data void stretch triggers the honest cap (§9.8, Appendix B-2 scenario)', () => {
    const segs = [0, 1, 2].map((i) => makeSegment({
      id: `v${i}`, index: i, lengthM: 300,
      lights: { count: 0, verifiedCount: 0, estCount: 0, sampledPoints: 0, coveredPoints: 0, maxGapM: null, provenance: 'model_est', maxAgeDays: null },
      shops: null,
      activity: { prior: 0.9, conf: 1, provenance: 'verified' },
      // origin segment lit/active so route score would otherwise be high
    }));
    segs[0].lights = {
      count: 10, verifiedCount: 10, estCount: 0, sampledPoints: 30, coveredPoints: 28,
      maxGapM: 15, provenance: 'verified', maxAgeDays: 2,
    };
    segs[0].shops = {
      items: [{ category: 'kirana', open: true, hoursProvenance: 'verified', weight: 1, distanceToRouteM: 20 }, { category: 'restaurant', open: true, hoursProvenance: 'verified', weight: 1, distanceToRouteM: 21 }],
      total: 2, hoursKnownCount: 2, unknownCount: 0, nearestOpenM: 20,
    };
    const out = scoreRoute(segs, ctxWalk);
    expect(out.cappedByLowData).toBe(true);
    expect(out.warnings).toContain('low_data_void_stretch');
    expect(out.score).toBeLessThanOrEqual(60);
  });

  it('vehicle mode config differs from walking mode (Appendix B-4 scenario)', () => {
    const seg = makeSegment({
      id: 'v', index: 0, lengthM: 400,
      lights: { count: 4, verifiedCount: 0, estCount: 4, sampledPoints: 40, coveredPoints: 30, maxGapM: 60, provenance: 'osm', maxAgeDays: 30 },
      shops: { items: [{ category: 'office', open: null, hoursProvenance: 'osm', weight: 0.3, distanceToRouteM: 30 }], total: 1, hoursKnownCount: 0, unknownCount: 1, nearestOpenM: 30 },
    });
    const w = scoreSegments([seg], ctxWalk).segments[0];
    const v = scoreSegments([seg], { mode: 'vehicle', at: NIGHT, darkHours: true }).segments[0];
    expect(v.indicators.community!.prior).toBe(w.indicators.community!.prior);
    // different weights must produce different composites for the same data
    expect(v.score).not.toBe(w.score);
  });

  it('builds dark-stretch warnings with measured length', () => {
    const seg = makeSegment({
      id: 'd', index: 0, lengthM: 400,
      lights: { count: 0, verifiedCount: 0, estCount: 0, sampledPoints: 40, coveredPoints: 4, maxGapM: 320, provenance: 'verified', maxAgeDays: 1 },
    });
    const out = scoreSegments([seg], ctxWalk).segments[0];
    expect(out.warnings.some((w) => w.startsWith('dark_stretch_'))).toBe(true);
  });
});

/**
 * AUTHORITATIVE scoring tunables (plan §Appendix A).
 * All scoring code imports from here — never hardcode weights in algorithms.
 * Changes here alter scores globally; golden tests in src/scoring/*.spec.ts
 * guard the §9.5 worked example and Appendix B scenarios.
 *
 * NOTE: plan §9.5 used gamma = 0.45 for walking (the worked example and
 * Appendix B golden test both produce ~44 with it). Appendix A had 0.55 —
 * reconciled to 0.45 here so document, code and golden tests agree.
 */
export type Mode = 'walk' | 'vehicle';

export interface ModeScoringConfig {
  weights: Record<IndicatorKey, number>;
  /** risk-dominance factor for the worst-tail penalty (plan §9.3) */
  gamma: number;
  /** illumination radius model: distance at which a light still illuminates a point */
  coverageRadius: number;
  /** corridor half-width for POI/report joins */
  corridor: number;
  detour: { maxExtraMin: number; maxFactor: number };
  saturation: { shopsK: number };
}

export type IndicatorKey =
  | 'lights'
  | 'shops'
  | 'activity'
  | 'community'
  | 'emergency'
  | 'road_quality';

export type RoadClass =
  | 'trunk'
  | 'primary'
  | 'secondary'
  | 'tertiary'
  | 'residential'
  | 'service'
  | 'footway'
  | 'path'
  | 'unknown';

export const SCORING: {
  modes: Record<Mode, ModeScoringConfig>;
  decline: {
    reportTauDays: number;
    reportCapRaw: number;
    freshness: { lights: number; hours: number; reports: number };
  };
  aggregate: {
    darkMaxLengthPenalty: number;
    endpointPenalty: number;
    /** "85th percentile worst" — value below which 85% of segment risk mass lies */
    worstTailPercentile: number;
    /** a single segment longer than this fraction of the route triggers the low-data cap */
    lowDataCapFraction: number;
    lowDataCapScore: number;
  };
  caps: { lowDataCapScore: number; lowDataMinFraction: number };
  lights: {
    /** walk along the segment and sample every N meters */
    sampleStepM: number;
  };
  shops: {
    corridor: number;
    /** category frontage weights (plan §9.1) */
    categoryWeights: Record<string, number>;
    /** probability a category establishment is open, by hour-of-day (defaults) */
    categoryOpenPrior: Record<string, {
      default: number;
      /** optional hour-level overrides, 0-23 */
      byHour?: Record<number, number>;
    }>;
  };
} = {
  modes: {
    walk: {
      weights: { lights: 0.35, shops: 0.30, activity: 0.20, community: 0.10, emergency: 0.05, road_quality: 0 },
      gamma: 0.45, // reconciled from plan §9.5 worked example & Appendix B golden test
      coverageRadius: 18,
      corridor: 40,
      detour: { maxExtraMin: 8, maxFactor: 1.4 },
      saturation: { shopsK: 3.0 },
    },
    vehicle: {
      weights: { lights: 0.22, shops: 0.18, activity: 0.25, community: 0.15, emergency: 0.10, road_quality: 0.10 },
      gamma: 0.30,
      coverageRadius: 25,
      corridor: 50,
      detour: { maxExtraMin: 5, maxFactor: 1.25 },
      saturation: { shopsK: 3.0 },
    },
  },
  decline: {
    reportTauDays: 30,
    reportCapRaw: 8,
    freshness: { lights: 180, hours: 12, reports: 60 },
  },
  aggregate: {
    darkMaxLengthPenalty: 12,
    endpointPenalty: 5,
    worstTailPercentile: 0.85,
    lowDataCapFraction: 0.20,
    lowDataCapScore: 60,
  },
  caps: {
    lowDataCapScore: 60,
    lowDataMinFraction: 0.20,
  },
  lights: {
    sampleStepM: 10,
  },
  shops: {
    corridor: 40,
    categoryWeights: {
      kirana: 1.0, grocery: 1.0, pharmacy: 1.0, cafe: 1.0, restaurant: 1.0,
      bakery: 1.0, fast_food: 1.0, tea_stall: 1.0, convenience: 1.0,
      atm: 0.6, bank: 0.6, fuel: 0.9, clinic: 0.9,
      office: 0.3, industrial: 0.2, other: 0.5,
    },
    categoryOpenPrior: {
      pharmacy:  { default: 0.6, byHour: { 22: 0.5, 23: 0.4, 0: 0.3, 1: 0.2, 2: 0.15, 3: 0.15, 4: 0.2, 5: 0.3 } },
      kirana:    { default: 0.4, byHour: { 21: 0.55, 22: 0.35, 23: 0.15, 0: 0.05, 1: 0.05, 2: 0.05, 3: 0.05, 4: 0.05, 5: 0.1 } },
      grocery:   { default: 0.4, byHour: { 21: 0.55, 22: 0.35, 23: 0.15, 0: 0.05, 1: 0.05, 2: 0.05, 3: 0.05, 4: 0.05, 5: 0.1 } },
      restaurant:{ default: 0.75, byHour: { 22: 0.6, 23: 0.45, 0: 0.3, 1: 0.15, 2: 0.1, 3: 0.05, 4: 0.05, 5: 0.05 } },
      cafe:      { default: 0.7, byHour: { 21: 0.8, 22: 0.6, 23: 0.35, 0: 0.15, 1: 0.05, 2: 0.05, 3: 0.05, 4: 0.05, 5: 0.05 } },
      fast_food: { default: 0.7, byHour: { 22: 0.55, 23: 0.4, 0: 0.25, 1: 0.15, 2: 0.1, 3: 0.05, 4: 0.05, 5: 0.1 } },
      atm:       { default: 0.95 },
      fuel:      { default: 0.9, byHour: { 0: 0.6, 1: 0.6, 2: 0.6, 3: 0.6, 4: 0.6, 5: 0.7 } },
      clinic:    { default: 0.3, byHour: { 0: 0.1, 1: 0.1, 2: 0.1, 3: 0.1, 4: 0.15, 5: 0.2 } },
      office:    { default: 0.05, byHour: { 21: 0.1, 22: 0.05, 23: 0.02, 0: 0.02, 1: 0.02, 2: 0.02, 3: 0.02, 4: 0.02, 5: 0.02 } },
      other:     { default: 0.35 },
    },
  },
  // Road-class lighting/activity priors (plan §6.3, §6.4). ESTIMATES by design.
  // provenance stays 'model_est' unless verified data exists.
} as const;

export const ROAD_CLASS_LIT_PRIOR: Record<RoadClass, number> = {
  trunk: 0.75, primary: 0.75, secondary: 0.65, tertiary: 0.55,
  residential: 0.35, service: 0.25, footway: 0.30, path: 0.15, unknown: 0.35,
};

export const ROAD_CLASS_ACTIVITY_BASE: Record<RoadClass, number> = {
  trunk: 0.8, primary: 0.75, secondary: 0.6, tertiary: 0.5,
  residential: 0.35, service: 0.2, footway: 0.3, path: 0.15, unknown: 0.35,
};

/** Hour-of-day activity multiplier (early-morning dip, evening peak). */
export const HOUR_ACTIVITY_FACTOR: number[] = [
  0.15, 0.12, 0.10, 0.08, 0.10, 0.18, 0.35, 0.55, 0.8, 1.0, 1.1, 1.15,
  1.1, 1.05, 1.1, 1.15, 1.25, 1.35, 1.3, 1.2, 1.0, 0.8, 0.55, 0.3,
];

export function modeConfig(mode: Mode): ModeScoringConfig {
  return SCORING.modes[mode];
}

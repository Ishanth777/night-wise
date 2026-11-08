import type { IndicatorKey, Mode, RoadClass } from '../config/scoring.js';

/** Provenance of a data point — plan §: verified > official > OSM > crowd > model_est */
export type Provenance = 'verified' | 'official' | 'osm' | 'google' | 'crowd' | 'model_est';

export interface LightObservation {
  /** total lights within segment corridor radius */
  count: number;
  /** lights with verified provenance (official/crowd-verified datasets) */
  verifiedCount: number;
  /** lights inferred from OSM lit=yes tags/priors (estimate) */
  estCount: number;
  /** segment illumination sampling results (computed by ingest/snapshot or on the fly) */
  sampledPoints: number;
  coveredPoints: number;
  /** longest gap between consecutive lights along the segment (m) or null if none */
  maxGapM: number | null;
  /** aggregate provenance of the best available info */
  provenance: Provenance;
  /** source_updated_at max age in days, null if unknown */
  maxAgeDays: number | null;
}

export interface ShopObservation {
  category: string;
  /** true=open now, false=provably closed now (known hours + hour-bound category), null=hours unknown */
  open: boolean | null;
  /** provenance of the hours if known */
  hoursProvenance: Provenance;
  weight: number;
  distanceToRouteM: number;
}

export interface ShopsObservation {
  items: ShopObservation[];
  total: number;
  hoursKnownCount: number;
  unknownCount: number;
  nearestOpenM: number | null;
}

export interface ActivityObservation {
  /** 0..1 estimated activity prior at the requested hour */
  prior: number;
  conf: number;
  provenance: Provenance;
}

export interface ReportObservation {
  severity: number;
  trust: number;
  ageHours: number;
  /** geohash cell for sybil discounting */
  cell: string;
}

export interface EmergencyObservation {
  nearestPoliceM: number | null;
  nearestHospitalM: number | null;
  provenance: Provenance;
}

export interface RoadQualityObservation {
  /** survey/OSM-derived quality for vehicle mode: surface, footpath conflicts etc. */
  score: number;
  conf: number;
  provenance: Provenance;
}

/** Raw data one segment carries into the scoring engine. */
export interface SegmentInput {
  id: string;
  index: number;
  lengthM: number;
  highwayClass: RoadClass;
  lights: LightObservation | null;
  shops: ShopsObservation | null;
  activity: ActivityObservation | null;
  reports: ReportObservation[];
  emergency: EmergencyObservation | null;
  roadQuality: RoadQualityObservation | null;
}

export interface ScoringContext {
  mode: Mode;
  /** ISO timestamp the route is computed for (affects hours + lighting model) */
  at: Date;
  /** is it dark enough that streetlights matter? */
  darkHours: boolean;
}

export type IndicatorStatus = 'good' | 'moderate' | 'poor' | 'limited_data' | 'unknown';

export interface IndicatorOutput {
  /** normalized 0–100 after confidence blending toward prior */
  score: number;
  /** raw normalized value before blending (for the decision trace) */
  raw: number;
  conf: number;
  prior: number;
  status: IndicatorStatus;
  basis: string;
  /** engine-computed extras consumed by UI */
  details?: Record<string, unknown>;
  evidence?: Record<string, unknown>;
}

export interface SegmentOutput {
  id: string;
  index: number;
  startM: number;
  endM: number;
  lengthM: number;
  score: number;
  confidence: number;
  indicators: Partial<Record<IndicatorKey, IndicatorOutput>>;
  warnings: string[];
  trace: {
    rawCounts: Record<string, number>;
    usedPriors: Record<string, number>;
    confidences: Record<string, number>;
  };
}

export interface RouteScoreOutput {
  baseScore: number;
  riskPenalty: number;
  darkPenalty: number;
  endpointPenalty: number;
  cappedByLowData: boolean;
  score: number;
  confidence: number;
  segments: SegmentOutput[];
  warnings: string[];
}

export const SCORE_GRADE = {
  good: { min: 70 },
  moderate: { min: 45 },
  poor: { min: 0 },
} as const;

export function grade(score: number): 'good' | 'moderate' | 'poor' {
  if (score >= SCORE_GRADE.good.min) return 'good';
  if (score >= SCORE_GRADE.moderate.min) return 'moderate';
  return 'poor';
}

/** Common shape returned by every indicator normalizer. */
export interface Normalized {
  value: number;      // 0..100
  conf: number;       // 0..1
  status: 'good' | 'moderate' | 'poor' | 'limited_data' | 'unknown';
  basis: string;
  details?: Record<string, unknown>;
}

export type { IndicatorKey, Mode, RoadClass } from '../config/scoring.js';

import type { ActivityObservation, EmergencyObservation, Normalized, ReportObservation, RoadQualityObservation } from '../types.js';
import { SCORING } from '../../config/scoring.js';
import { clamp, clamp01 } from '../util.js';

/**
 * Activity/popularity (plan §9.1): a precomputed per-segment 24×7 ESTIMATE.
 * Label is always 'model_est' at MVP; confidence carried in the observation.
 */
export function normalizeActivity(obs: ActivityObservation | null): Normalized {
  if (!obs) {
    return { value: 0, conf: 0, status: 'unknown', basis: 'no_activity_data' };
  }
  const value = Math.round(clamp01(obs.prior) * 100);
  const status = value >= 60 ? 'good' : value >= 35 ? 'moderate' : value >= 15 ? 'poor' : 'unknown';
  return {
    value,
    conf: clamp01(obs.conf),
    status: obs.provenance === 'model_est' ? 'limited_data' : status,
    basis: `activity_${obs.provenance}`,
    details: { prior: Number(obs.prior.toFixed(2)), hourDependent: true },
  };
}

/**
 * Community reports (plan §9.1 §9.4):
 *   R_raw = Σ severityᵢ · trustⱼ · decay(adHours), decay = exp(−age/τ), τ=30d
 *   sybil dampening: reports after the first in the same 100 m cell within 24h → 1/√n
 *   R_norm = 100 · clamp(R_raw / 8, 0, 1)
 */
export function normalizeReports(
  reports: ReportObservation[],
  ctx: { now: Date; tauDays: number; capRaw: number },
): Normalized {
  if (!reports || reports.length === 0) {
    // Absence of reports is fairly reliable information about absence of signals
    return {
      value: 85, conf: 0.8, status: 'good', basis: 'no_user_reports',
      details: { recentReports: 0 },
    };
  }
  const tauH = ctx.tauDays * 24;
  const byCell = new Map<string, number>();
  let rRaw = 0;
  for (const r of reports) {
    const decay = Math.exp(-r.ageHours / tauH);
    const n = (byCell.get(r.cell) ?? 0) + 1;
    byCell.set(r.cell, n);
    const sybil = n === 1 ? 1 : 1 / Math.sqrt(n);
    rRaw += r.severity * clamp(r.trust, 0.3, 1.5) * decay * sybil;
  }
  const conf = Math.min(0.8, 0.55 + 0.05 * Math.min(5, reports.length));
  const value = Math.round(clamp(rRaw / ctx.capRaw, 0, 1) * 100);
  const status = value >= 80 ? 'good' : value >= 55 ? 'moderate' : value >= 30 ? 'poor' : 'poor';
  return {
    value,
    conf,
    status,
    basis: `user_reports_${reports.length}`,
    details: { rawWeighted: Number(rRaw.toFixed(2)), distinctCells: byCell.size, recentReports: reports.length },
  };
}

/**
 * Emergency proximity (plan FR-205): nearest police ≤ 1km and hospital ≤ 2km.
 * Soft score: police 0.7 weight, hospital 0.3.
 */
export function normalizeEmergency(obs: EmergencyObservation | null): Normalized {
  if (!obs || (obs.nearestPoliceM == null && obs.nearestHospitalM == null)) {
    return { value: 0, conf: 0, status: 'unknown', basis: 'no_emergency_data' };
  }
  const cl = clamp(obs.nearestPoliceM ?? 3000, 0, 3000);
  const police = clamp01(1 - (cl - 150) / 850); // 150m→1.0, 1km→0
  const ho = clamp01(1 - ((obs.nearestHospitalM ?? 4000) - 300) / 3700);
  const value = Math.round(100 * (0.7 * police + 0.3 * ho));
  const conf = obs.provenance === 'verified' || obs.provenance === 'official' ? 0.9 : 0.55;
  const status = value >= 60 ? 'good' : value >= 35 ? 'moderate' : 'poor';
  return {
    value, conf, status,
    basis: `emergency_${obs.provenance}`,
    details: { nearestPoliceM: obs.nearestPoliceM, nearestHospitalM: obs.nearestHospitalM },
  };
}

export function normalizeRoadQuality(obs: RoadQualityObservation | null): Normalized {
  if (!obs) {
    return { value: 0, conf: 0, status: 'unknown', basis: 'no_road_quality_data' };
  }
  return {
    value: Math.round(clamp01(obs.score) * 100),
    conf: clamp01(obs.conf),
    status: obs.score >= 0.6 ? 'good' : obs.score >= 0.35 ? 'moderate' : 'poor',
    basis: `road_quality_${obs.provenance}`,
  };
}

export function reportTauHours(): number {
  return SCORING.decline.reportTauDays * 24;
}
export { normalizeLights } from './lights.js';
export { normalizeShops } from './shops.js';

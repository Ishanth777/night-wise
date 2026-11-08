import { clamp01 } from '../util.js';
import type { LightObservation, Normalized, Provenance } from '../types.js';
/**
 * Streetlight coverage normalization (plan §9.1).
 * coverage_ratio = fraction of 10 m sample points within `r` of >=1 light.
 */

const CONF_BY_PROV: Record<Provenance, number> = {
  verified: 0.85, official: 0.80, osm: 0.65, google: 0.75, crowd: 0.55, model_est: 0.25,
};

export function normalizeLights(
  obs: LightObservation | null,
  opts: { verified: boolean },
): Normalized {
  if (!obs || obs.sampledPoints === 0) {
    return {
      value: 0, conf: 0, status: 'unknown',
      basis: 'no_streetlight_data',
      details: { sampledPoints: obs?.sampledPoints ?? 0 },
    };
  }
  const coverage = clamp01(obs.coveredPoints / obs.sampledPoints);
  const value = Math.round(coverage * 100);

  let conf = CONF_BY_PROV[obs.provenance] ?? 0.25;
  if (obs.maxAgeDays != null && obs.maxAgeDays > 180) {
    const decay = Math.min(0.4, ((obs.maxAgeDays - 180) / 10) * 0.02);
    conf = Math.max(0.25, conf - decay);
  }
  // Mixed provenance (verified + est) reads as somewhat less certain than pure verified
  if (obs.verifiedCount > 0 && (obs.verifiedCount / obs.count) < 0.5) {
    conf = Math.min(conf, 0.55);
  }

  const status = value >= 70 ? 'good' : value >= 40 ? 'moderate' : value > 0 ? 'poor' : 'unknown';
  return {
    value,
    conf,
    status: obs.provenance === 'model_est' && value === 0 ? 'limited_data' : status,
    basis: `light_${obs.provenance}`,
    details: {
      coverageRatio: Number(coverage.toFixed(3)),
      lights: obs.count,
      verifiedLights: obs.verifiedCount,
      maxGapM: obs.maxGapM,
    },
  };
}

import {
  ROAD_CLASS_ACTIVITY_BASE,
  ROAD_CLASS_LIT_PRIOR,
  HOUR_ACTIVITY_FACTOR,
  type Mode,
  type RoadClass,
} from '../config/scoring.js';

/**
 * Priors (plan §9.1/§9.2): the neutral value an indicator takes when its own
 * confidence is low, given mode + road class + hour. These are ESTIMATES —
 * they are always exposed as such in the decision trace and UI basis fields.
 *
 * Values are starting hypotheses to be recalibrated in Phase 7 field audits.
 */

export function lightsPrior(mode: Mode, roadClass: RoadClass, hour: number): number {
  let base = ROAD_CLASS_LIT_PRIOR[roadClass] ?? ROAD_CLASS_LIT_PRIOR.residential;
  // Deep-night: depletion only if class is unmaintained; arterial roads stay lit all night.
  if (mode === 'walk') {
    //ندی no adjustment: night-time lit coverage is the same as evening coverage
  }
  return base * 100;
}

export function shopsPrior(mode: Mode, roadClass: RoadClass, hour: number): number {
  const base = ROAD_CLASS_ACTIVITY_BASE[roadClass] ?? 0.35;
  // Commercial-frontage-rich classes carry more expected shops
  const classMul = roadClass === 'trunk' || roadClass === 'primary' ? 1.4
    : roadClass === 'secondary' || roadClass === 'tertiary' ? 1.2
    : roadClass === 'service' || roadClass === 'path' ? 0.6 : 1.0;
  const hourFactor = hour >= 9 && hour <= 21 ? 1.0 : hour >= 22 || hour <= 1 ? 0.55 : 0.25;
  return 100 * (1 - Math.exp(-(base * classMul * hourFactor * 3.0) / 3.0));
}

export function activityPrior(mode: Mode, roadClass: RoadClass, hour: number): number {
  const base = ROAD_CLASS_ACTIVITY_BASE[roadClass] ?? 0.35;
  const hourMul = HOUR_ACTIVITY_FACTOR[hour] ?? 0.5;
  const modeDamp = mode === 'walk' ? 0.85 : 1.0;
  return Math.min(100, 100 * base * hourMul * modeDamp);
}

export function communityPrior(_mode: Mode, _roadClass: RoadClass, _hour: number): number {
  // Absence of reports in a sparsely-reported area should not read as danger:
  // reports are rare events; prior is a calm baseline.
  return 85;
}

export function emergencyPrior(_mode: Mode, _roadClass: RoadClass): number {
  return 60;
}

export function roadQualityPrior(mode: Mode, roadClass: RoadClass): number {
  if (mode !== 'vehicle') return 50;
  const q: Record<RoadClass, number> = {
    trunk: 90, primary: 85, secondary: 75, tertiary: 65,
    residential: 55, service: 40, footway: 10, path: 5, unknown: 50,
  };
  return q[roadClass] ?? 50;
}

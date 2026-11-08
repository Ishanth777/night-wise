import type { ShopsObservation, Normalized } from '../types.js';
import { clamp01 } from '../util.js';
import { SCORING } from '../../config/scoring.js';

const CONF_HOURS_BY_PROV: Record<string, number> = {
  verified: 0.85, official: 0.8, osm: 0.7, crowd: 0.6, model_est: 0.45, google: 0.8,
};

/**
 * Shop availability normalization (plan §9.1):
 *   A_raw = Σ w(cat) · open_i, open_i ∈ {1 open, prior(cat,hour) if hours unknown,
 *   0 provably closed (known hours + hour-bound category)}
 *   S_norm = 100 · (1 − exp(−A_raw / k)), k = 3.0 (plan Appendix A)
 *
 * CRITICAL (plan FR-202): unknown hours are NOT closed. They contribute the
 * category's open-at-this-hour probability and reduce confidence instead.
 */
export function normalizeShops(
  obs: ShopsObservation | null,
  ctx: { corridor: number; saturation: { shopsK: number }; hour: number },
  openPrior: (cat: string, hour: number) => number,
): Normalized {
  if (!obs || obs.total === 0) {
    return {
      value: 0, conf: 0, status: 'unknown', basis: 'no_poi_data',
      details: { corridor: ctx.corridor },
    };
  }

  let aRaw = 0;
  let openNow = 0;
  let provWeightSum = 0;
  let provWeightedConf = 0;

  for (const item of obs.items) {
    const w = weighting(item.category);
    let openVal: number;
    let hoursConf: number;
    if (item.open === true) {
      openVal = 1;
      hoursConf = CONF_HOURS_BY_PROV[item.hoursProvenance] ?? 0.6;
      openNow += 1;
    } else if (item.open === null) {
      openVal = openPrior(item.category, ctx.hour);
      hoursConf = (CONF_HOURS_BY_PROV[item.hoursProvenance] ?? 0.5) * 0.6;
    } else {
      openVal = 0; // provably closed at this time
      hoursConf = CONF_HOURS_BY_PROV[item.hoursProvenance] ?? 0.6;
    }
    aRaw += w * openVal;
    provWeightSum += w;
    provWeightedConf += hoursConf * w;
  }

  const conf = provWeightSum > 0 ? clamp01(provWeightedConf / provWeightSum) : 0;
  const countConf = 1 - Math.exp(-obs.total / 6);
  const confAdj = clamp01(conf * (0.4 + 0.6 * countConf));

  const value = Math.round(100 * (1 - Math.exp(-aRaw / ctx.saturation.shopsK)));
  const status = value >= 60 ? 'good' : value >= 25 ? 'moderate' : value > 0 ? 'poor' : 'unknown';
  return {
    value,
    conf: confAdj,
    status: value === 0 && obs.total > 0 ? 'limited_data' : status,
    basis: `shop_hours_${obs.hoursKnownCount > 0 ? 'partial' : 'unknown'}`,
    details: {
      aRaw: Number(aRaw.toFixed(2)),
      openCount: openNow,
      hoursKnownCount: obs.hoursKnownCount,
      unknownHours: obs.unknownCount,
      nearestOpenM: obs.nearestOpenM,
    },
  };
}

function weighting(cat: string): number {
  return SCORING.shops.categoryWeights[cat] ?? 0.5;
}


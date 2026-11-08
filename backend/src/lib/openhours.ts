/**
 * Opening-hours handling (plan §6.2, FR-202).
 *
 * Parses the human-readable OSM opening_hours subset (via simple-opening-hours)
 * into a normalized JSONB model:
 *   [{ days:[0..6], from:"HH:MM", to:"HH:MM" }]        (IST wall-clock; overnight supported)
 *   [{ always: true }]                                  (24/7)
 *
 * Unparseable/absent values return known:false — the DB layer then uses the
 * category open-prior, NEVER a fabricated "closed".
 */
import { SimpleOpeningHours } from 'simple-opening-hours';

export interface HoursRule {
  days: number[];          // 0=Sun .. 6=Sat
  from: string;            // "HH:MM"
  to: string;              // "HH:MM" (> from ⇒ overnight window)
}
export type HoursRules = HoursRule[] | [{ always: true }];

const DAY_INDEX: Record<string, number> = {
  su: 0, mo: 1, tu: 2, we: 3, th: 4, fr: 5, sa: 6, ph: 0, sh: 0,
};

export function parseOpeningHours(raw: string | null | undefined): {
  known: boolean;
  hours: HoursRules | null;
  isAlways: boolean;
} {
  if (!raw || raw.trim().length === 0) return { known: false, hours: null, isAlways: false };
  const value = raw.trim();
  if (value === '24/7') return { known: true, hours: [{ always: true }], isAlways: true };

  try {
    const parsed = new SimpleOpeningHours(value);
    const table = parsed.getTable() as Record<string, string[]>; // keyed by day abbrev
    const rules: HoursRule[] = [];
    let totalIntervals = 0;

    for (const [day, intervals] of Object.entries(table)) {
      const dayIdx = DAY_INDEX[day.toLowerCase()];
      if (dayIdx == null) continue;
      for (const interval of intervals ?? []) {
        const [from, to] = interval.split('-');
        if (!from || !to) continue;
        // normalize 24:00 → 00:00 (example table uses 00:00-24:00 for always-open)
        const f = from === '24:00' ? '00:00' : from;
        const t = to === '24:00' ? '00:00' : to;
        if (f === t) continue;
        rules.push({ days: [dayIdx], from: f, to: t });
        totalIntervals += 1;
      }
    }
    if (totalIntervals === 0) return { known: false, hours: null, isAlways: false };
    return { known: true, hours: rules, isAlways: false };
  } catch {
    return { known: false, hours: null, isAlways: false };
  }
}

/** Merge rules with identical windows across contiguous day sets (cosmetic; not required). */
export function summarize(rules: HoursRules): string {
  if (!rules) return 'unknown';
  if ('always' in rules[0]) return '24/7';
  return `${rules.length} windows`;
}

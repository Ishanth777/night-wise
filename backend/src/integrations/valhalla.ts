/**
 * Valhalla HTTP client (plan §5.3, §12): the ONLY route source of truth.
 * Circuit breaker prevents hammering a fallen router (plan §15.3).
 */
import CircuitBreaker from 'opossum';

export interface ValhallaLocation { lat: number; lon: number }

export interface ValhallaRouteCandidate {
  /** primary trip followed by alternates, all normalized */
  geometry: number[][]; // [[lng, lat], ...] GeoJSON order
  lengthKm: number;
  durationS: number;
}

interface ValhallaTrip {
  summary?: { length: number; time: number };
  legs?: Array<{ shape?: string; summary?: { length: number; time: number } }>;
}

interface ValhallaRaw {
  trip?: ValhallaTrip;
  alternates?: Array<{ trip?: ValhallaTrip }>;
}

const TIMEOUT_MS = 8000;

function breaker() {
  const state = new CircuitBreaker<ValhallaRaw>(async (payload: string): Promise<ValhallaRaw> => {
    const res = await fetch(`${process.env.VALHALLA_URL ?? 'http://localhost:8002'}/route`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: payload,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`valhalla_${res.status}: ${body.slice(0, 300)}`);
    }
    return (await res.json()) as ValhallaRaw;
  }, { timeout: TIMEOUT_MS, errorThresholdPercentage: 60, resetTimeout: 15_000 });
  return state;
}

const breakerSingleton = (() => {
  let b: CircuitBreaker<ValhallaRaw> | null = null;
  return () => (b ??= breaker());
})();

export async function getValhallaAlternates(
  from: ValhallaLocation,
  to: ValhallaLocation,
  opts: { mode: 'walk' | 'vehicle'; vehicleType?: 'car' | 'two_wheeler' | null; time?: Date },
): Promise<ValhallaRouteCandidate[]> {
  // vehicleType: plan maps two-wheeler to bicycle-ish motorbike costing; MVP: auto for both
  const costing = opts.mode === 'walk'
    ? 'pedestrian'
    : 'auto';
  const payload: Record<string, unknown> = {
    locations: [from, to],
    costing,
    alternates: 3,
    language: 'en-IN',
    units: 'kilometers',
    costing_options: {
      [costing]: {
        // prefer well-lit/arterial corridors at night for pedestrians (plan §10.3)
        ...(opts.mode === 'walk' ? { use_lit: 0.6, walking_speed: 4.8 } : {}),
        ...(opts.time ? { } : {}),
      },
    },
  };
  const raw = await breakerSingleton().fire(JSON.stringify(payload));
  const trips: ValhallaTrip[] = [raw.trip, ...(raw.alternates ?? []).map((a) => a.trip)]
    .filter((t): t is ValhallaTrip => Boolean(t));
  return trips
    .map((t) => ({
      geometry: tripGeometry(t),
      lengthKm: Number(t.summary?.length ?? 0),
      durationS: Number(t.summary?.time ?? 0),
    }))
    .filter((c) => c.geometry.length >= 2);
}

/** Concatenate per-leg encoded shapes into one GeoJSON [lng,lat] polyline. */
function tripGeometry(trip: ValhallaTrip): number[][] {
  const coords: number[][] = [];
  for (const leg of trip.legs ?? []) {
    if (!leg.shape) continue;
    const decoded = decodePolyline(leg.shape);
    // legs share a joint vertex — drop the duplicate
    const start = coords.length > 0 ? 1 : 0;
    for (let i = start; i < decoded.length; i++) coords.push(decoded[i]);
  }
  return coords;
}

// polyline6 decoder inlined (avoid circular import with lib/geo)
export function decodePolyline(encoded: string): number[][] {
  const coords: number[][] = [];
  let lat = 0, lng = 0, idx = 0;
  while (idx < encoded.length) {
    let result = 0, shift = 0, b: number;
    do {
      b = encoded.charCodeAt(idx++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += result & 1 ? ~(result >> 1) : result >> 1;
    result = 0; shift = 0;
    do {
      b = encoded.charCodeAt(idx++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += result & 1 ? ~(result >> 1) : result >> 1;
    coords.push([lng * 1e-6, lat * 1e-6]); // GeoJSON order [lng, lat]
  }
  return coords;
}

export function breakerStatus(): { open: boolean } {
  return { open: breakerSingleton().open };
}

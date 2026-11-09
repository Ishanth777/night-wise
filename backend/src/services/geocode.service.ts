/**
 * Geocode service — Photon (self-hosted) when reachable, else public Nominatim
 * with a distinct UA + caching (plan §5.3, §11). Results cached 24 h in Redis.
 * If neither is reachable the endpoint fails honestly (GEOCODER_UNCONFIGURED /
 * EXTERNAL_DATA_ERROR) rather than inventing coordinates.
 */
import { cacheGet, cacheSet } from '../lib/cache.js';
import log from '../lib/logger.js';

export interface PlaceResult {
  id: string;
  name: string;
  lat: number;
  lng: number;
  type: string;
}

export async function searchPlaces(q: string, near?: { lat: number; lng: number }): Promise<PlaceResult[]> {
  const key = `geo:${q.toLowerCase()}:${near ? `${near.lat.toFixed(2)},${near.lng.toFixed(2)}` : ''}`;
  const cached = await cacheGet(key);
  if (cached) return JSON.parse(cached) as PlaceResult[];

  const errors: string[] = [];

  if (process.env.PHOTON_URL) {
    try {
      const out = await fetchPhoton(q, near);
      if (out.length > 0) {
        await cacheSet(key, JSON.stringify(out), 86400);
        return out;
      }
    } catch (err) {
      errors.push(`photon: ${(err as Error).message}`);
      log.debug({ err }, 'photon geocoder unreachable — falling back to Nominatim');
    }
  }

  if (process.env.NOMINATIM_URL) {
    try {
      const out = await fetchNominatim(q, near);
      if (out.length > 0) {
        await cacheSet(key, JSON.stringify(out), 86400);
        return out;
      }
      return [];
    } catch (err) {
      errors.push(`nominatim: ${(err as Error).message}`);
    }
  }

  throw Object.assign(
    new Error(
      errors.length
        ? `Geocoding unavailable (${errors.join(' | ')}). Set PHOTON_URL to a self-hosted Photon instance or check outbound network access for NOMINATIM_URL.`
        : 'No geocoder configured. Set PHOTON_URL or NOMINATIM_URL (see docs/SETUP.md).',
    ),
    { code: errors.length ? 'EXTERNAL_DATA_ERROR' : 'GEOCODER_UNCONFIGURED' },
  );
}

async function fetchPhoton(q: string, near?: { lat: number; lng: number }): Promise<PlaceResult[]> {
  const base = process.env.PHOTON_URL!;
  const url = `${base}/api?q=${encodeURIComponent(q)}&limit=8${near ? `&lat=${near.lat}&lon=${near.lng}` : ''}`;
  const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const raw = (await res.json()) as { features?: Array<Record<string, unknown>> };
  return (raw.features ?? []).map((f, i) => {
    const props = (f.properties ?? {}) as Record<string, unknown>;
    const geo = (f.geometry ?? {}) as { coordinates?: number[] };
    return {
      id: `photon_${String(props.osm_id ?? i)}`,
      name: String(props.name ?? props.street ?? q),
      lat: Number(geo.coordinates?.[1]),
      lng: Number(geo.coordinates?.[0]),
      type: String(props.osm_value ?? ''),
    };
  }).filter(valid);
}

async function fetchNominatim(q: string, near?: { lat: number; lng: number }): Promise<PlaceResult[]> {
  const base = process.env.NOMINATIM_URL!;
  const viewbox = near
    ? `&viewbox=${near.lng - 0.08},${near.lat + 0.08},${near.lng + 0.08},${near.lat - 0.08}&bounded=1`
    : '';
  const url = `${base}/search?q=${encodeURIComponent(q)}&format=jsonv2&limit=8${viewbox}`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': `${process.env.NOMINATIM_APP_NAME ?? 'nightwise'}/1.0 (safety-navigation; contact: ops@nightwise.app)`,
      'Accept-Language': 'en',
    },
    signal: AbortSignal.timeout(6000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const raw = (await res.json()) as Array<Record<string, unknown>>;
  return raw.map((r, i) => ({
    id: `osm_${String(r.osm_type ?? 'x')}_${String(r.osm_id ?? i)}`,
    name: String(r.display_name ?? q),
    lat: Number(r.lat),
    lng: Number(r.lon),
    type: String(r.type ?? ''),
  })).filter(valid);
}

function valid(p: PlaceResult): boolean {
  return Number.isFinite(p.lat) && Number.isFinite(p.lng);
}

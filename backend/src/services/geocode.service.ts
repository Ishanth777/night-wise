/**
 * Geocode service — Photon (self-hosted) if configured, else public Nominatim
 * with a distinct UA and strict rate-limit awareness (plan §5.3, §11).
 * Nominatim results are cached in Redis for 24h.
 */
import { getRedis, cacheSet, cacheGet } from '../lib/cache.js';
import { ensure, type LatLng } from './ranking.service.js';

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

  const base = process.env.PHOTON_URL ?? process.env.NOMINATIM_URL;
  ensure(base, 'GEOCODER_UNCONFIGURED', 'No geocoder configured (PHOTON_URL or NOMINATIM_URL)');
  const isPhoton = Boolean(process.env.PHOTON_URL);
  const url = isPhoton
    ? `${base}/api?q=${encodeURIComponent(q)}&limit=8${near ? `&lat=${near.lat}&lon=${near.lng}` : ''}`
    : `${base}/search?q=${encodeURIComponent(q)}&format=jsonv2&limit=8${near ? `&viewbox=${near.lng - 0.05},${near.lat + 0.05},${near.lng + 0.05},${near.lat - 0.05}&bounded=1` : ''}`;

  const res = await fetch(url, {
    headers: { 'User-Agent': 'NightWise/1.0 (backend geocoder)' },
    signal: AbortSignal.timeout(4000),
  });
  if (!res.ok) throw Object.assign(new Error(`geocoder_${res.status}`), { code: 'EXTERNAL_DATA_ERROR' });
  const raw = (await res.json()) as Array<Record<string, unknown>>;

  const out = raw.map((r, i) => {
    const lat = Number(r.lat ?? (r.geometry as { y?: number } | undefined)?.y ?? NaN);
    const lng = Number(r.lon ?? (r.geometry as { x?: number } | undefined)?.x ?? NaN);
    const label = String(
      isPhoton
        ? r.label ?? r.name ?? q
        : (r.display_name as string | undefined) ?? q,
    );
    return { id: `g_${i}`, name: label, lat, lng, type: String(r.type ?? '') };
  }).filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng)) as LatLng[] as unknown as PlaceResult[];

  await cacheSet(key, JSON.stringify(out), 86400);
  void getRedis;
  return out;
}

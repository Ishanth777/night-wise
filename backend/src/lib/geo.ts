/**
 * Minimal geo utilities (no external geo deps; deterministic + testable).
 * World scale: haversine (plan §8: geography math up to ~500 km is fine).
 */

export type LatLng = [lat: number, lng: number];

const R = 6371000; // meters
const D2R = Math.PI / 180;

export function haversineM(a: LatLng, b: LatLng): number {
  const dLat = (b[0] - a[0]) * D2R;
  const dLng = (b[1] - a[1]) * D2R;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a[0] * D2R) * Math.cos(b[0] * D2R) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

/** Polyline encoding precision 6 (Valhalla default). */
export function decodePolyline6(encoded: string): LatLng[] {
  const coords: LatLng[] = [];
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
    coords.push([lat * 1e-6, lng * 1e-6]);
  }
  return coords;
}

/** Chop a polyline into segments of roughly ≤ maxLenM (splitting at vertices). */
export function splitPolylineByDistance(
  coords: LatLng[],
  maxLenM: number,
): Array<{ coords: LatLng[]; lengthM: number }> {
  const parts: Array<{ coords: LatLng[]; lengthM: number }> = [];
  if (coords.length < 2) return parts;
  let cur: LatLng[] = [coords[0]];
  let curLen = 0;
  for (let i = 1; i < coords.length; i++) {
    const step = haversineM(coords[i - 1], coords[i]);
    if (cur.length >= 2 && curLen + step > maxLenM) {
      parts.push({ coords: cur, lengthM: curLen });
      cur = [coords[i - 1]];
      curLen = 0;
    }
    cur.push(coords[i]);
    curLen += step;
  }
  if (cur.length >= 2) parts.push({ coords: cur, lengthM: curLen });
  return parts;
}

export function inBbox(
  p: LatLng,
  bbox: { w: number; e: number; s: number; n: number },
): boolean {
  return (
    p[1] >= bbox.w && p[1] <= bbox.e && p[0] >= bbox.s && p[0] <= bbox.n
  );
}

export function roundedToMeters(p: LatLng, meters: number): LatLng {
  // ~111,320 m per degree latitude; longitude shrinks by cos(lat)
  const latStep = meters / 111_320;
  const lngStep = meters / (111_320 * Math.cos(p[0] * D2R) || 1);
  return [
    Math.round(p[0] / latStep) * latStep,
    Math.round(p[1] / lngStep) * lngStep,
  ];
}

/** Cheap geohash-like cell id for sybil dampening (plan §9.4). Similar purpose, simpler impl. */
export function cellId(p: LatLng, meters = 100): string {
  const r = roundedToMeters(p, meters);
  return `c${r[0].toFixed(5)}_${r[1].toFixed(5)}`;
}

export function bearingDeg(a: LatLng, b: LatLng): number {
  const y = Math.sin((b[1] - a[1]) * D2R) * Math.cos(b[0] * D2R);
  const x =
    Math.cos(a[0] * D2R) * Math.sin(b[0] * D2R) -
    Math.sin(a[0] * D2R) * Math.cos(b[0] * D2R) * Math.cos((b[1] - a[1]) * D2R);
  return (Math.atan2(y, x) * 180) / Math.PI;
}

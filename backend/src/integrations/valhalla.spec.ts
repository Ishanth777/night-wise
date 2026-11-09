import { describe, expect, it } from 'vitest';
import { decodePolyline } from './valhalla.js';

/**
 * Regression test for the Valhalla polyline6 decoder. A previous implementation
 * mis-decoded multi-byte chunks, placing Bengaluru routes near 0°0′ and silently
 * collapsing every corridor query to "no data".
 */
describe('Valhalla polyline6 decoding', () => {
  // Real Valhalla pedestrian shape: MG Road (12.9756, 77.6040) -> Cubbon Park (12.9763, 77.5925)
  const shape =
    'i_~vWsbq_sCnEj@yBtLdAbAtHvA\\HaBnKqCxQ}BhOb@J`@HE\\gAxHa@nCuA~JeI~f@[pB}AzCu`@zc@j@t@p@x@i@fAc@|@m@lAs@fC_@lNkCp_A|AbB@HBL\\fCp@xCJH[lA@fBMLiB|BmCfD_E`F]YmEpPuCvNiD|BPb@?l@uAhLIpr@rErb@}@nS}AzWMtLt@pI\\fAnFfRp@vAn\\d_@vAzAFn@Cj@A~@LhA\\bAXh@n@n@r@^hBTbBAh@QfBtAiMtMz@|GNnCvA~Db@lFu@rFaChE_DnGeGra@uBpN';

  it('keeps coordinates in Bengaluru and matches the endpoints', () => {
    const points = decodePolyline(shape);
    expect(points.length).toBeGreaterThan(50);
    const first = points[0];
    const last = points[points.length - 1];
    expect(first[0]).toBeCloseTo(77.603898, 4);
    expect(first[1]).toBeCloseTo(12.975621, 4);
    expect(last[0]).toBeCloseTo(77.592544, 4);
    expect(last[1]).toBeCloseTo(12.976478, 4);
    for (const point of points) {
      expect(point[0]).toBeGreaterThan(77.5);
      expect(point[0]).toBeLessThan(77.7);
      expect(point[1]).toBeGreaterThan(12.9);
      expect(point[1]).toBeLessThan(13.1);
    }
  });

  it('produces GeoJSON order [lng, lat]', () => {
    const [lng, lat] = decodePolyline(shape)[0];
    // Longitude ~77.6, latitude ~12.98 — ensure the axes are not swapped.
    expect(lng).toBeGreaterThan(70);
    expect(lat).toBeLessThan(20);
  });
});

/**
 * End-to-end integration tests against a live stack (plan §13 test strategy).
 *
 * These tests are skipped by default because they need the Docker services,
 * real OSM data and Valhalla running:
 *
 *   docker compose -f infra/docker-compose.yml up -d
 *   ./scripts/migrate.sh
 *   RUN_INTEGRATION=1 npm run test:integration
 *
 * They create and delete a throwaway account, and they never invent geography:
 * every assertion checks that data returned belongs to the Bengaluru bbox.
 */
import type { Express } from 'express';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

const RUN = process.env.RUN_INTEGRATION === '1';
const RUN_NETWORK = process.env.RUN_NETWORK_TESTS === '1';

const MG_ROAD = { lat: 12.9756, lng: 77.6040 };
const CUBBON_PARK = { lat: 12.9763, lng: 77.5925 };
const DELHI = { lat: 28.6139, lng: 77.2090 };

const BBOX = { w: 77.3, e: 77.9, s: 12.7, n: 13.25 };

interface Session {
  userId: string;
  email: string;
  role: string;
  accessToken: string;
  refreshToken: string;
}

/** ISO 8601 for IST wall-clock time (+05:30), as the API requires. */
function istIso(date: Date): string {
  const shifted = new Date(date.getTime() + 5.5 * 3600e3);
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${shifted.getUTCFullYear()}-${pad(shifted.getUTCMonth() + 1)}-${pad(shifted.getUTCDate())}` +
    `T${pad(shifted.getUTCHours())}:${pad(shifted.getUTCMinutes())}:00+05:30`
  );
}

describe.skipIf(!RUN)('NightWise API integration', () => {
  let app: Express;
  let closePool: (() => Promise<void>) | null = null;
  let pool: typeof import('../../db/pool.js').getPool | null = null;

  const email = `it_${Date.now()}_${Math.floor(Math.random() * 1e6)}@nightwise.test`;
  const password = 'integration-pass-123';
  let session: Session;
  let reportId: string | null = null;
  let walkRouteId: string | null = null;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    // Import after the env is set so getEnv() validation sees test values.
    const { createApp } = await import('../../api/app.js');
    const poolModule = await import('../../db/pool.js');
    pool = poolModule.getPool;
    closePool = poolModule.closePool;
    app = createApp();
  });

  afterAll(async () => {
    // Best-effort cleanup so repeated runs do not accumulate accounts.
    try {
      if (session?.accessToken) {
        await request(app)
          .delete('/api/auth/account')
          .set('Authorization', `Bearer ${session.accessToken}`);
      }
    } catch {
      /* already deleted or stack down */
    }
    await closePool?.();
  });

  it('serves the health probe', async () => {
    const res = await request(app).get('/api/health').expect(200);
    expect(res.body.ok).toBe(true);
  });

  it('rejects unauthenticated route requests', async () => {
    const res = await request(app)
      .post('/api/routes/recommend')
      .send({
        origin: MG_ROAD,
        destination: CUBBON_PARK,
        mode: 'walk',
        departureTime: istIso(new Date(Date.now() + 3600e3)),
      })
      .expect(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('validates request bodies honestly', async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ email, password })
      .expect(201);
    session = reg.body.data as Session;
    expect(session.accessToken).toBeTruthy();
    expect(session.refreshToken).toBeTruthy();

    const res = await request(app)
      .post('/api/routes/recommend')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ origin: MG_ROAD, mode: 'teleport' })
      .expect(400);
    expect(res.body.error.code).toBe('INVALID_BODY');
  });

  it('rejects points outside the Bengaluru service area', async () => {
    const res = await request(app)
      .post('/api/routes/recommend')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({
        origin: DELHI,
        destination: MG_ROAD,
        mode: 'walk',
        departureTime: istIso(new Date(Date.now() + 2 * 3600e3)),
      })
      .expect(422);
    expect(res.body.error.code).toBe('OUT_OF_SERVICE_AREA');
  });

  it('returns real walk routes with scores, provenance and geometry', async () => {
    const res = await request(app)
      .post('/api/routes/recommend')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({
        origin: MG_ROAD,
        destination: CUBBON_PARK,
        mode: 'walk',
        departureTime: istIso(new Date(Date.now() + 3 * 3600e3)),
        userPrefs: { safetyVsTime: 0.8 },
      })
      .expect(200);

    const data = res.body.data;
    expect(data.mode).toBe('walk');
    expect(data.routes.length).toBeGreaterThanOrEqual(1);
    expect(data.disclaimer).toMatch(/environmental estimates/i);
    expect(['HIT', 'MISS']).toContain(data.meta.cache);

    walkRouteId = data.routes[0].routeId;
    for (const route of data.routes) {
      expect(route.routeId).toMatch(/^rt_/);
      expect(['safest', 'fastest', 'balanced', 'alternative']).toContain(route.label);
      expect(route.summary.safetyScore).toBeGreaterThanOrEqual(0);
      expect(route.summary.safetyScore).toBeLessThanOrEqual(100);
      expect(route.summary.confidence).toBeGreaterThanOrEqual(0);
      expect(route.summary.confidence).toBeLessThanOrEqual(1);
      expect(route.summary.distanceM).toBeGreaterThan(0);
      expect(route.summary.durationS).toBeGreaterThan(0);

      // Geometry must be a real Bengaluru GeoJSON LineString in [lng, lat] order.
      expect(route.geometry.type).toBe('LineString');
      expect(route.geometry.coordinates.length).toBeGreaterThan(2);
      for (const [lng, lat] of route.geometry.coordinates) {
        expect(lng).toBeGreaterThan(BBOX.w);
        expect(lng).toBeLessThan(BBOX.e);
        expect(lat).toBeGreaterThan(BBOX.s);
        expect(lat).toBeLessThan(BBOX.n);
      }

      // Segments must tile the route without gaps.
      expect(route.segments.length).toBeGreaterThan(0);
      let cursor = 0;
      for (const segment of route.segments) {
        expect(segment.startM).toBeCloseTo(cursor, 4);
        expect(segment.endM).toBeGreaterThan(segment.startM);
        cursor = segment.endM;
      }

      for (const key of ['lights', 'shops', 'activity', 'community', 'emergency']) {
        expect(route.indicators[key]).toBeDefined();
        expect(route.indicators[key].status).toBeTruthy();
        expect(route.indicators[key].basis).toBeTruthy();
      }
    }
  });

  it('serves the archived route detail by id', async () => {
    expect(walkRouteId).toBeTruthy();
    const res = await request(app)
      .get(`/api/routes/${walkRouteId}`)
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(200);
    expect(res.body.data.route.routeId).toBe(walkRouteId);
    expect(res.body.data.mode).toBe('walk');
    expect(res.body.data.route.segments.length).toBeGreaterThan(0);
    expect(res.body.data.disclaimer).toMatch(/environmental estimates/i);

    await request(app)
      .get('/api/routes/rt_00000000000000000000')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(404);
  });

  it('returns vehicle routes for a longer trip', async () => {
    const res = await request(app)
      .post('/api/routes/recommend')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({
        origin: { lat: 12.9352, lng: 77.6245 },
        destination: CUBBON_PARK,
        mode: 'vehicle',
        vehicleType: 'car',
        departureTime: istIso(new Date(Date.now() + 4 * 3600e3)),
        userPrefs: { safetyVsTime: 0.7 },
      })
      .expect(200);

    const data = res.body.data;
    expect(data.mode).toBe('vehicle');
    expect(data.routes.length).toBeGreaterThanOrEqual(1);
    for (const route of data.routes) {
      expect(route.summary.distanceM).toBeGreaterThan(3000);
      expect(route.summary.safetyScore).toBeGreaterThanOrEqual(0);
    }
  });

  it('lists real emergency services near the route', async () => {
    const res = await request(app)
      .get('/api/emergency/nearby')
      .query({ lat: MG_ROAD.lat, lng: MG_ROAD.lng, radiusM: 3000 })
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(200);

    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);
    for (const place of res.body.data) {
      expect(['police', 'hospital', 'clinic', 'pharmacy']).toContain(place.type);
      expect(place.distanceM).toBeGreaterThanOrEqual(0);
      expect(place.distanceM).toBeLessThanOrEqual(3000);
      expect(place.lat).toBeGreaterThan(BBOX.s);
      expect(place.lat).toBeLessThan(BBOX.n);
      expect(place.lng).toBeGreaterThan(BBOX.w);
      expect(place.lng).toBeLessThan(BBOX.e);
    }
  });

  it('accepts a pseudonymous community report and returns it nearby', async () => {
    const res = await request(app)
      .post('/api/reports')
      .set('X-Device-Fingerprint', 'it-device-fingerprint')
      .send({ kind: 'poor_lighting', severity: 3, lat: MG_ROAD.lat, lng: MG_ROAD.lng })
      .expect(201);

    reportId = String(res.body.data.id);
    expect(reportId).toBeTruthy();
    expect(res.body.data.status).toBe('pending');
    expect(res.body.meta.moderationNotice).toMatch(/moderated/i);

    const nearby = await request(app)
      .get('/api/reports/nearby')
      .query({ lat: MG_ROAD.lat, lng: MG_ROAD.lng, radiusM: 800 })
      .expect(200);
    expect(Array.isArray(nearby.body.data)).toBe(true);
  });

  it.skipIf(!RUN_NETWORK)('geocodes a landmark through the configured geocoder', async () => {
    const res = await request(app)
      .get('/api/places/search')
      .query({ q: 'MG Road Metro Station Bengaluru', lat: MG_ROAD.lat, lng: MG_ROAD.lng })
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    for (const place of res.body.data) {
      expect(place.name).toBeTruthy();
      expect(Number.isFinite(place.lat)).toBe(true);
      expect(Number.isFinite(place.lng)).toBe(true);
    }
  });

  it('exposes and updates profile preferences with a two-route cap', async () => {
    const profile = await request(app)
      .get('/api/me/profile')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(200);
    expect(profile.body.data.email).toBe(email.toLowerCase());
    expect(profile.body.data.stats.savedRoutes).toBe(0);

    const patched = await request(app)
      .patch('/api/me/settings')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ safetyVsTime: 0.9, defaultMode: 'vehicle', avoidSteps: true })
      .expect(200);
    expect(patched.body.data.settings.safetyVsTime).toBe(0.9);
    expect(patched.body.data.settings.defaultMode).toBe('vehicle');
    expect(patched.body.data.settings.avoidSteps).toBe(true);

    const empty = await request(app)
      .patch('/api/me/settings')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({})
      .expect(400);
    expect(empty.body.error.code).toBe('INVALID_BODY');

    for (let i = 0; i < 2; i++) {
      await request(app)
        .post('/api/me/saved-routes')
        .set('Authorization', `Bearer ${session.accessToken}`)
        .send({ label: `Home ${i}`, mode: 'walk', origin: MG_ROAD, destination: CUBBON_PARK })
        .expect(201);
    }
    const capped = await request(app)
      .post('/api/me/saved-routes')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ label: 'Third', mode: 'walk', origin: MG_ROAD, destination: CUBBON_PARK })
      .expect(409);
    expect(capped.body.error.code).toBe('CONFLICT');

    const listed = await request(app)
      .get('/api/me/saved-routes')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(200);
    expect(listed.body.data).toHaveLength(2);

    const removed = await request(app)
      .delete(`/api/me/saved-routes/${listed.body.data[0].id}`)
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(204);
    expect(removed.body).toEqual({});
  });

  it('accepts confirm/deny votes on a published report but not on your own', async () => {
    // Anonymous reports have no owner, so create one while signed in to prove
    // the self-vote guard. There is no public moderator endpoint for good
    // reason, so the test publishes the fixture directly.
    const created = await request(app)
      .post('/api/reports')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ kind: 'unsafe_isolated', severity: 4, lat: MG_ROAD.lat, lng: MG_ROAD.lng })
      .expect(201);
    const ownedId = String(created.body.data.id);
    await pool!().query("UPDATE safety_reports SET status = 'published' WHERE id = $1", [ownedId]);

    const own = await request(app)
      .post(`/api/reports/${ownedId}/vote`)
      .set('Authorization', `Bearer ${session.accessToken}`)
      .send({ vote: 'confirm' })
      .expect(403);
    expect(own.body.error.code).toBe('FORBIDDEN');

    const voterEmail = `voter_${Date.now()}@nightwise.test`;
    const voter = await request(app)
      .post('/api/auth/register')
      .send({ email: voterEmail, password })
      .expect(201);
    const voterToken = (voter.body.data as Session).accessToken;

    const voted = await request(app)
      .post(`/api/reports/${ownedId}/vote`)
      .set('Authorization', `Bearer ${voterToken}`)
      .send({ vote: 'confirm' })
      .expect(200);
    expect(voted.body.data.confirmations).toBe(1);
    expect(voted.body.data.myVote).toBe('confirm');
    expect(voted.body.data.trustScore).toBeGreaterThan(0.5);

    const nearby = await request(app)
      .get('/api/reports/nearby')
      .query({ lat: MG_ROAD.lat, lng: MG_ROAD.lng, radiusM: 800 })
      .set('Authorization', `Bearer ${voterToken}`)
      .expect(200);
    const row = nearby.body.data.find((r: { id: number }) => String(r.id) === ownedId);
    expect(row).toBeTruthy();
    expect(row.confirmations).toBe(1);
    expect(row.myVote).toBe('confirm');

    // Duplicate votes update in place rather than stacking.
    const denied = await request(app)
      .post(`/api/reports/${ownedId}/vote`)
      .set('Authorization', `Bearer ${voterToken}`)
      .send({ vote: 'deny' })
      .expect(200);
    expect(denied.body.data.confirmations).toBe(0);
    expect(denied.body.data.denials).toBe(1);

    await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${voterToken}`)
      .expect(204);
  });

  it('rotates refresh tokens and revokes the account', async () => {
    const refreshed = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(200);
    const next = refreshed.body.data as Session;
    expect(next.accessToken).toBeTruthy();
    expect(next.refreshToken).not.toBe(session.refreshToken);

    await request(app)
      .post('/api/auth/logout')
      .send({ refreshToken: next.refreshToken })
      .expect(204);

    // The old refresh token was rotated; it must no longer work.
    await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(401);

    session = next;
    await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(204);

    await request(app)
      .post('/api/auth/login')
      .send({ email, password })
      .expect(401);

    session = { ...session, accessToken: '', refreshToken: '' };
  });
});

import { Router } from 'express';
import { validate, asyncWrap } from '../middleware/validate.js';
import { requireAuth } from '../middleware/auth.js';
import { RecommendRequestSchema, RouteIdSchema } from '../schemas/index.js';
import { recommendRateLimit } from '../middleware/ratelimit.js';
import { recommend } from '../../services/ranking.service.js';
import { getRouteDetail } from '../../repositories/routes.repo.js';
import { getEnv } from '../../config/env.js';
import { breakerStatus } from '../../integrations/valhalla.js';
import { HttpError } from '../middleware/errors.js';

export const routeRoutes = Router();

/** POST /api/routes/recommend — the core endpoint (plan §11.2). */
routeRoutes.post('/recommend', requireAuth, recommendRateLimit,
  validate([{ schema: RecommendRequestSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const routeReq = req.body as unknown as Parameters<typeof recommend>[0];
    // service area guard (plan §11.2 OUT_OF_SERVICE_AREA)
    const bbox = getEnv().serviceBbox;
    const inService = (p: { lat: number; lng: number }) =>
      p.lat >= bbox.s && p.lat <= bbox.n && p.lng >= bbox.w && p.lng <= bbox.e;
    if (!inService(routeReq.origin) || !inService(routeReq.destination)) {
      throw new HttpError(422, 'OUT_OF_SERVICE_AREA',
        'NightWise is currently Bengaluru-only — this point is outside our mapped area');
    }
    const userId = (req as { user?: { sub: string } }).user?.sub ?? null;
    const payload = await recommend(routeReq, userId);
    res.json({ data: payload });
  }));

/**
 * GET /routes/upstream-health — routing engine circuit-breaker status,
 * consumed by the dashboard; cheap for ops (plan §17 observability).
 */
routeRoutes.get('/upstream-health', (_req, res) => {
  res.json({ data: { routingEngine: breakerStatus() } });
});

/**
 * GET /routes/:routeId — full segment payload for a route generated in the
 * last 24 hours (plan §11.1). The recommend response already embeds this, so
 * this endpoint is for share/reload flows.
 */
routeRoutes.get('/:routeId', requireAuth,
  validate([{ schema: RouteIdSchema, source: 'params' }]),
  asyncWrap(async (req, res) => {
    const { routeId } = req.params as { routeId: string };
    const detail = await getRouteDetail(routeId);
    if (!detail) {
      throw new HttpError(404, 'NOT_FOUND',
        'Route not found or expired. Request a new recommendation.');
    }
    res.set('Cache-Control', 'private, max-age=300');
    res.json({ data: detail });
  }));

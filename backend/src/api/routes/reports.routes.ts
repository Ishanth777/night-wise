import { Router } from 'express';
import { validate, asyncWrap } from '../middleware/validate.js';
import { requireAuth, optionalAuth, attachDeviceHash } from '../middleware/auth.js';
import { CreateReportSchema, ModerateReportSchema, NearbySchema, VoteReportSchema } from '../schemas/index.js';
import { reportsRateLimit } from '../middleware/ratelimit.js';
import { createReport, nearbyReports, listPending, moderate, vote } from '../../repositories/reports.repo.js';
import { HttpError } from '../middleware/errors.js';

export const reportRoutes = Router();
reportRoutes.use(attachDeviceHash);

/** POST /api/reports — anonymous-capable, pseudonymous, rate-limited (plan §15.4). */
reportRoutes.post('/', reportsRateLimit, optionalAuth,
  validate([{ schema: CreateReportSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const input = req.body as Parameters<typeof createReport>[0];
    const user = (req as { user?: { sub: string } }).user ?? null;
    const out = await createReport(input, user?.sub ?? null, (res.locals as { deviceHash?: string }).deviceHash ?? null);
    res.status(201).json({
      data: out,
      meta: { moderationNotice: 'Reports are moderated before publishing. Reports are anonymous; we store only a hashed device fingerprint.' },
    });
  }));

/**
 * GET /api/reports/nearby — published reports only. When a valid token is
 * supplied, each row carries the caller's own vote so the client can show a
 * pressed state without a second request.
 */
reportRoutes.get('/nearby', optionalAuth,
  validate([{ schema: NearbySchema, source: 'query' }]),
  asyncWrap(async (req, res) => {
    const q = req.query as unknown as { lat: number; lng: number; radiusM: number };
    const user = (req as { user?: { sub: string } }).user ?? null;
    res.json({ data: await nearbyReports(q.lat, q.lng, q.radiusM, user?.sub ?? null) });
  }));

/** POST /api/reports/:id/vote — confirm/deny a published report (plan §11.1). */
reportRoutes.post('/:id/vote', requireAuth,
  validate([{ schema: VoteReportSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid report id');
    }
    const user = (req as { user?: { sub: string } }).user!;
    const body = req.body as { vote: 'confirm' | 'deny' };
    const result = await vote(id, user.sub, body.vote === 'confirm');
    res.json({ data: { reportId: id, ...result } });
  }));

// ---- moderation (admin) ----
reportRoutes.get('/pending', requireAuth,
  asyncWrap(async (req, res) => {
    const user = (req as { user?: { role?: string } }).user;
    if (user?.role !== 'moderator' && user?.role !== 'admin') {
      res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Moderator role required' } });
      return;
    }
    res.json({ data: await listPending(50) });
  }));

reportRoutes.post('/:id/moderate', requireAuth,
  validate([{ schema: ModerateReportSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const { decision, note } = req.body as { decision: 'published' | 'rejected'; note?: string };
    const user = (req as { user?: { role?: string } }).user;
    if (user?.role !== 'moderator' && user?.role !== 'admin') {
      res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Moderator role required' } });
      return;
    }
    await moderate(Number(req.params.id), decision, note);
    res.status(204).end();
  }));

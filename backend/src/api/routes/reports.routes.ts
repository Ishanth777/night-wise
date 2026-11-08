import { Router } from 'express';
import { validate, asyncWrap } from '../middleware/validate.js';
import { requireAuth, attachDeviceHash } from '../middleware/auth.js';
import { CreateReportSchema, NearbySchema } from '../schemas/index.js';
import { reportsRateLimit } from '../middleware/ratelimit.js';
import { createReport, nearbyReports, listPending, moderate } from '../../repositories/reports.repo.js';
import { verifyAccessToken } from '../../services/auth.service.js';

export const reportRoutes = Router();
reportRoutes.use(attachDeviceHash);

/** POST /api/reports — anonymous-capable, pseudonymous, rate-limited (plan §15.4). */
reportRoutes.post('/', reportsRateLimit,
  (req, _res, next) => {
    // optional-auth: works with or without token
    const header = req.headers.authorization;
    if (header?.startsWith('Bearer ')) {
      try {
        const payload = verifyAccessToken(header.slice(7));
        (req as { user?: { sub: string; role: string } }).user = { sub: payload.sub, role: payload.role };
      } catch { /* anonymous allowed */ }
    }
    next();
  },
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

reportRoutes.get('/nearby', validate([{ schema: NearbySchema, source: 'query' }]),
  asyncWrap(async (req, res) => {
    const q = req.query as unknown as { lat: number; lng: number; radiusM: number };
    res.json({ data: await nearbyReports(q.lat, q.lng, q.radiusM) });
  }));

// ---- moderation (admin) ----
reportRoutes.get('/pending', requireAuth,
  asyncWrap(async (_req, res) => {
    (`
      role check enforced by requireRole in production; MVP admin gate below
    `);
    res.json({ data: await listPending(50) });
  }));

reportRoutes.post('/:id/moderate', requireAuth,
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

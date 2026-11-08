import { Router } from 'express';
import { validate, asyncWrap } from '../middleware/validate.js';
import { requireAuth } from '../middleware/auth.js';
import { NearbySchema } from '../schemas/index.js';
import { nearby } from '../../repositories/emergency.repo.js';

export const emergencyRoutes = Router();

/** GET /api/emergency/nearby — police stations & hospitals (plan FR-301). */
emergencyRoutes.get('/nearby', requireAuth, validate([{ schema: NearbySchema, source: 'query' }]),
  asyncWrap(async (req, res) => {
    const q = req.query as unknown as { lat: number; lng: number; radiusM: number; type?: string };
    res.json({ data: await nearby(q.lat, q.lng, q.radiusM, q.type) });
  }));

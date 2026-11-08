import { Router } from 'express';
import { validate, asyncWrap } from '../middleware/validate.js';
import { requireAuth } from '../middleware/auth.js';
import { SearchPlacesSchema } from '../schemas/index.js';
import { searchPlaces } from '../../services/geocode.service.js';

export const placeRoutes = Router();

/** GET /api/places/search — geocode/search for the destination picker (plan §12.3). */
placeRoutes.get('/search', requireAuth, validate([{ schema: SearchPlacesSchema, source: 'query' }]),
  asyncWrap(async (req, res) => {
    const q = req.query as unknown as { q: string; lat?: number; lng?: number };
    const results = await searchPlaces(q.q, q.lat != null && q.lng != null ? { lat: q.lat, lng: q.lng } : undefined);
    res.json({ data: results });
  }));

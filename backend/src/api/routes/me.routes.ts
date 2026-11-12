/** `/api/me` — profile, preference defaults and saved routes (plan §11.1, FR-402). */
import { Router } from 'express';
import type { Request } from 'express';
import { validate, asyncWrap } from '../middleware/validate.js';
import { requireAuth } from '../middleware/auth.js';
import { SavedRouteSchema, UserSettingsSchema } from '../schemas/index.js';
import {
  deleteSavedRoute,
  getProfile,
  insertSavedRoute,
  updateSettings,
} from '../../repositories/users.repo.js';
import { HttpError } from '../middleware/errors.js';

export const meRoutes = Router();
meRoutes.use(requireAuth);

function userId(req: Request): string {
  const id = (req as { user?: { sub: string } }).user?.sub;
  if (!id) throw new HttpError(401, 'UNAUTHENTICATED', 'Sign in required');
  return id;
}

meRoutes.get('/profile', asyncWrap(async (req, res) => {
  const profile = await getProfile(userId(req));
  if (!profile) throw new HttpError(404, 'NOT_FOUND', 'Profile not found');
  res.json({ data: profile });
}));

/**
 * PATCH /api/me/settings — merge a subset of preference defaults. These are
 * defaults for the client, never a hidden change to server-side scoring.
 */
meRoutes.patch('/settings', validate([{ schema: UserSettingsSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const settings = await updateSettings(userId(req), req.body as Parameters<typeof updateSettings>[1]);
    if (!settings) throw new HttpError(404, 'NOT_FOUND', 'Profile not found');
    res.json({ data: { settings } });
  }));

meRoutes.get('/saved-routes', asyncWrap(async (req, res) => {
  const profile = await getProfile(userId(req));
  if (!profile) throw new HttpError(404, 'NOT_FOUND', 'Profile not found');
  res.json({ data: profile.savedRoutes });
}));

meRoutes.post('/saved-routes', validate([{ schema: SavedRouteSchema, source: 'body' }]),
  asyncWrap(async (req, res) => {
    const route = await insertSavedRoute(userId(req), req.body as Parameters<typeof insertSavedRoute>[1]);
    res.status(201).json({ data: route });
  }));

meRoutes.delete('/saved-routes/:id', asyncWrap(async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid saved route id');
  }
  const removed = await deleteSavedRoute(userId(req), id);
  if (!removed) throw new HttpError(404, 'NOT_FOUND', 'Saved route not found');
  res.status(204).end();
}));

import type { NextFunction, Request, Response } from 'express';
import { verifyAccessToken } from '../../services/auth.service.js';
import { HttpError } from './errors.js';

export function attachDeviceHash(req: Request, res: Response, next: NextFunction): void {
  (res.locals as { deviceHash?: string }).deviceHash =
    (req.headers['x-device-fingerprint'] as string)?.slice(0, 128) ?? null;
  next();
}

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    next(new HttpError(401, 'UNAUTHENTICATED', 'Sign in required'));
    return;
  }
  try {
    const payload = verifyAccessToken(header.slice(7));
    (req as { user?: { sub: string; role: string; email: string } }).user = {
      sub: payload.sub, role: payload.role, email: typeof payload.email === 'string' ? payload.email : '',
    };
    next();
  } catch {
    next(new HttpError(401, 'UNAUTHENTICATED', 'Invalid or expired access token'));
  }
}

export function requireRole(...roles: string[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const user = (req as { user?: { role?: string } }).user;
    if (!user || !roles.includes(user.role ?? '')) {
      next(new HttpError(403, 'FORBIDDEN', 'Insufficient privileges'));
      return;
    }
    next();
  };
}

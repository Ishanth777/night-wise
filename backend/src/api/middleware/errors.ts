import type { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import log from '../../lib/logger.js';

export class HttpError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
  }
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: `No route for ${req.method} ${req.path}` } });
}

/** Error matrix (plan §11.2). Never leaks internals; Sentry/log ref id surfaced. */
export function errorHandler(err: unknown, req: Request, res: Response, next: NextFunction): void {
  if (res.headersSent) {
    next(err);
    return;
  }
  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: 'INVALID_BODY',
        message: 'Request validation failed',
        details: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
      },
    });
    return;
  }
  const e = err as { code?: string; status?: number; message?: string };
  const statusByCode: Record<string, number> = {
    AUTH_FAILED: 401, UNAUTHENTICATED: 401, FORBIDDEN: 403,
    NOT_FOUND: 404, CONFLICT: 409, VALIDATION_ERROR: 400,
    RATE_LIMITED: 429, OUT_OF_SERVICE_AREA: 422, ROUTING_UNAVAILABLE: 503,
    EXTERNAL_DATA_ERROR: 502, GEOCODER_UNCONFIGURED: 501,
  };
  const status = e.status ?? (e.code ? statusByCode[e.code] ?? 500 : 500);
  log.error({ err: e, path: req.path }, 'request failed');
  res.status(status).json({
    error: {
      code: e.code ?? 'INTERNAL_ERROR',
      message: status >= 500 ? 'An internal error occurred' : e.message ?? 'Request failed',
    },
  });
}

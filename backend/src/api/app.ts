/** Express app factory (plan §13): transport layer only — zero business logic. */
import express, { type Express } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { pinoHttp } from 'pino-http';
import { getEnv } from '../config/env.js';
import log from '../lib/logger.js';
import { authRoutes } from './routes/auth.routes.js';
import { routeRoutes } from './routes/routes.routes.js';
import { reportRoutes } from './routes/reports.routes.js';
import { emergencyRoutes } from './routes/emergency.routes.js';
import { placeRoutes } from './routes/places.routes.js';
import { errorHandler, notFoundHandler } from './middleware/errors.js';
import { rateLimitGlobal } from './middleware/ratelimit.js';

export function createApp(): Express {
  const env = getEnv();
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(cors({
    origin: env.NODE_ENV === 'production'
      ? (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean)
      : true,
    credentials: true,
  }));
  app.use(express.json({ limit: '100kb' }));
  app.use(pinoHttp({ logger: log, redact: ['req.headers.authorization'] }));
  app.use(rateLimitGlobal);

  app.get('/api/health', (_req, res) => {
    res.json({ ok: true, version: '1.0', time: new Date().toISOString() });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/routes', routeRoutes);
  app.use('/api/reports', reportRoutes);
  app.use('/api/emergency', emergencyRoutes);
  app.use('/api/places', placeRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

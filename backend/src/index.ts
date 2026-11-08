import { createApp } from './api/app.js';
import { getEnv } from './config/env.js';
import { closePool } from './db/pool.js';
import log from './lib/logger.js';

const env = getEnv();
const app = createApp();

const server = app.listen(env.PORT, () => {
  log.info({ port: env.PORT, env: env.NODE_ENV, places: env.placesConfigured }, 'nightwise API listening');
});

async function shutdown(): Promise<void> {
  log.info('shutting down');
  server.close(() => { /* drain */ });
  await closePool();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

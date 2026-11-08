import { z } from 'zod';

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().default(3000),
  LOG_LEVEL: z.string().default('info'),

  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  REDIS_URL: z.string().default('redis://localhost:6379'),

  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be set (openssl rand -hex 32)'),
  JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET must be set'),

  VALHALLA_URL: z.string().default('http://localhost:8002'),
  PHOTON_URL: z.string().optional(),
  NOMINATIM_URL: z.string().default('https://nominatim.openstreetmap.org'),
  NOMINATIM_APP_NAME: z.string().default('nightwise'),

  SERVICE_BBOX_W: z.coerce.number().default(77.30),
  SERVICE_BBOX_E: z.coerce.number().default(77.90),
  SERVICE_BBOX_S: z.coerce.number().default(12.70),
  SERVICE_BBOX_N: z.coerce.number().default(13.25),

  GOOGLE_PLACES_API_KEY: z.string().optional(),
  PLACES_ENABLED: z.coerce.boolean().default(false),
  PLACES_MONTHLY_BUDGET_CAP_USD: z.coerce.number().default(20),

  RATE_LIMIT_GLOBAL_PER_HOUR: z.coerce.number().default(240),
  RATE_LIMIT_RECOMMEND_PER_HOUR_USER: z.coerce.number().default(120),
  RATE_LIMIT_RECOMMEND_PER_HOUR_IP: z.coerce.number().default(30),
  RATE_LIMIT_REPORTS_PER_DAY_USER: z.coerce.number().default(5),

  OSM_PBF_PATH: z.string().optional(),
});

export type Env = z.infer<typeof EnvSchema> & {
  placesConfigured: boolean;
  serviceBbox: { w: number; e: number; s: number; n: number };
};

let cached: Env | null = null;

export function getEnv(): Env {
  if (cached) return cached;
  const parsed = EnvSchema.safeParse(process.env);
  if (!parsed.success) {
    // Fail fast at boot (plan §13: env validation)
    const issues = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid environment configuration -> ${issues}`);
  }
  const env = parsed.data as Env;
  env.placesConfigured = Boolean(env.GOOGLE_PLACES_API_KEY) && env.PLACES_ENABLED;
  env.serviceBbox = {
    w: env.SERVICE_BBOX_W,
    e: env.SERVICE_BBOX_E,
    s: env.SERVICE_BBOX_S,
    n: env.SERVICE_BBOX_N,
  };
  cached = env;
  return env;
}

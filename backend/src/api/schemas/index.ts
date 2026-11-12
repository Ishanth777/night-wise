import { z } from 'zod';

export const ModeSchema = z.enum(['walk', 'vehicle']);
export type ApiMode = z.infer<typeof ModeSchema>;

export const LatSchema = z.number().min(-90).max(90);
export const LngSchema = z.number().min(-180).max(180);

export const RecommendRequestSchema = z.object({
  origin: z.object({ lat: LatSchema, lng: LngSchema }),
  destination: z.object({ lat: LatSchema, lng: LngSchema }),
  mode: ModeSchema,
  vehicleType: z.enum(['car', 'two_wheeler']).nullable().optional(),
  /** required: scoring is time-of-day (plan FR-105) — ISO 8601 with offset, within ±24h */
  departureTime: z
    .string()
    .datetime({ offset: true })
    .refine((s) => Math.abs(Date.parse(s) - Date.now()) < 24 * 3600e3, 'departureTime ±24h'),
  userPrefs: z
    .object({
      safetyVsTime: z.number().min(0).max(1).default(0.8),
    })
    .default({ safetyVsTime: 0.8 }),
});

export type RecommendRequest = z.infer<typeof RecommendRequestSchema>;

export const ReportKindSchema = z.enum([
  'harassment', 'poor_lighting', 'unsafe_isolated', 'no_footpath', 'construction', 'crowd_safe', 'other',
]);
export const CreateReportSchema = z.object({
  kind: ReportKindSchema,
  severity: z.number().int().min(1).max(5),
  lat: LatSchema,
  lng: LngSchema,
  note: z.string().max(500).optional(),
});
export type CreateReport = z.infer<typeof CreateReportSchema>;

export const ModerateReportSchema = z.object({
  decision: z.enum(['published', 'rejected']),
  note: z.string().max(500).optional(),
});

/** Confirm/deny an existing published report (moderation signal only). */
export const VoteReportSchema = z.object({
  vote: z.enum(['confirm', 'deny']),
});
export type VoteReport = z.infer<typeof VoteReportSchema>;

export const UserSettingsSchema = z.object({
  safetyVsTime: z.number().min(0).max(1).optional(),
  defaultMode: ModeSchema.optional(),
  vehicleType: z.enum(['car', 'two_wheeler']).nullable().optional(),
  avoidSteps: z.boolean().optional(),
}).refine((value) => Object.keys(value).length > 0, {
  message: 'Provide at least one setting',
});
export type UserSettings = z.infer<typeof UserSettingsSchema>;

export const SavedRouteSchema = z.object({
  label: z.string().min(1).max(80),
  mode: ModeSchema,
  origin: z.object({ lat: LatSchema, lng: LngSchema }),
  destination: z.object({ lat: LatSchema, lng: LngSchema }),
});

export const RouteIdSchema = z.object({
  routeId: z.string().regex(/^rt_[a-f0-9]{16,}$/i, 'Invalid route id'),
});

export const RegisterSchema = z.object({
  email: z.string().email().max(320),
  password: z.string().min(8).max(72),
  displayName: z.string().min(1).max(80).optional(),
});
export const LoginSchema = RegisterSchema.pick({ email: true, password: true });

export const NearbySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radiusM: z.coerce.number().int().min(50).max(3000).default(1000),
});
export type NearbyQuery = z.infer<typeof NearbySchema>;

export const SearchPlacesSchema = z.object({
  q: z.string().min(2).max(120),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});

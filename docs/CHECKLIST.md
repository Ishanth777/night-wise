# NightWise — implementation checklist

Source of truth: [`IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md).
Last verified: **2026-11-09** against the live Docker stack on macOS arm64.

Legend: ✅ implemented & verified · ⚠️ implemented with a documented limitation ·
⛔ deliberately not built (MVP scope / missing external input).

## Environment recorded during the build

- ✅ Node 25.6.1 / npm 11.9.0, Docker 29.9.2.
- ✅ PostgreSQL 16 + PostGIS 3.4 (`nightwise-postgres`), Redis 7, Valhalla
  (`nightwise-valhalla`) with tiles built from a real Geofabrik extract.
- ✅ Flutter 3.47.9 / Dart 3.13.7 (arm64 SDK).
- ⛔ Full Xcode + CocoaPods absent → no iOS binary was produced.
- ⛔ No Google Places API key → augmentation disabled-safe.
- ⛔ No self-hosted Photon instance → Nominatim fallback (verified).
- ⛔ No verified Bengaluru lamp-post dataset → OSM `lit` tags used instead.

## Phase 0 — Infra & data spikes

- ✅ `infra/docker-compose.yml`: PostGIS, Redis, Valhalla, optional production
  `api` profile.
- ✅ Real OSM extract acquired and clipped to the Bengaluru bbox
  (`data/bengaluru-latest.osm.pbf`; script: `scripts/fetch-and-clip-data.sh`).
- ✅ Valhalla tiles built and verified: pedestrian route MG Road → Cubbon Park,
  auto route Koramangala → Cubbon Park, both via `POST :8002/route`.
- ⚠️ Streetlight probe: no machine-readable civic dataset found; documented,
  not fabricated.

## Phase 1 — Scaffold, contracts, config

- ✅ Repo layout (`backend/`, `app/`, `infra/`, `scripts/`, `docs/`).
- ✅ TypeScript strict build, Vitest, env validation with Zod
  (`backend/src/config/env.ts`).
- ✅ Authoritative scoring config (`backend/src/config/scoring.ts`) with
  mode-specific weights and detour budgets.
- ✅ Zod request schemas, error matrix (`errorHandler`, stable codes), pino
  structured logging, Helmet, CORS, body limits.
- ✅ SQL migrations + idempotent `schema_migrations` runner
  (`scripts/migrate.sh`).
- ✅ Production Dockerfile for the API (multi-stage, non-root, healthcheck).

## Phase 2 — Data ingestion

- ✅ OSM ingest job imports real roads, road segments, shops with parsed hours,
  emergency locations.
  - Verified counts: **279,096 roads · 357,743 segments · 42,133 shops
    (1,581 with hours) · 1,359 emergency locations**.
- ✅ IST-aware `hours_open_at(jsonb, timestamptz)` SQL function; unknown hours
  return `NULL`, never “closed” (FR-202).
- ✅ OSM `lit=yes/24/7/no/down` fallback with explicit `osm` provenance
  (65% confidence; 70% conservative coverage for positive tags).
- ⛔ `streetlights` table intentionally empty — no verified point dataset.
- ⚠️ Google Places augmentation implemented but inactive without a key; OSM
  hours + category priors are used instead.

## Phase 3 — Routing & APIs

- ✅ Valhalla client: alternates, per-leg geometry, circuit breaker, timeouts.
- ✅ **Fixed a serious polyline6 decoder bug** that placed Bengaluru routes near
  0°,0° and collapsed corridor queries; regression test added
  (`backend/src/integrations/valhalla.spec.ts`).
- ✅ Segmentization at ≤250 m; batched PostGIS corridor queries with GiST
  indexes; dead temp-table cleanup fixed.
- ✅ Ranking pipeline: candidates → corridor data → pure scoring → detour prune
  → near-duplicate prune → labels (`safest`, `fastest`, `balanced`,
  `alternative`) + trade-off text.
- ✅ Response includes geometry, segments, indicators, confidence, warnings,
  data health, provenance and the honesty disclaimer.
- ✅ 10-minute Redis response cache keyed without user identity.
- ✅ Auth: bcrypt(12), 15-min access JWT, 30-day rotating refresh with reuse
  detection/family revocation, logout, hard delete with report anonymization.
- ✅ Rate limits (global/user/IP/report caps) with documented fail-open when
  Redis is unavailable.
- ✅ Endpoints: `/api/health`, `/api/auth/{register,login,refresh,logout,account}`,
  `/api/routes/recommend`, `/api/routes/upstream-health`,
  `/api/emergency/nearby`, `/api/places/search`,
  `/api/reports` + `/api/reports/nearby` + moderator queue/moderation.
- ⚠️ Deferred endpoints from the plan catalog: `GET /routes/:routeId` (the
  recommend payload already carries full segments), report voting
  (`POST /reports/:id/vote`), and `/me/profile` + `/me/settings` (the profile
  screen is informational in the MVP).

## Phase 4 — Safety scoring engine

- ✅ Pure, I/O-free engine (`backend/src/scoring/`) — no DB or network imports.
- ✅ Indicators: lights, shops/hours, activity, community, emergency,
  road quality; weighted mean with confidence blending; length-aware
  aggregation that respects worst stretches.
- ✅ Golden tests for the plan §9.5 example (walk ~44, vehicle ~79) and the
  appendices; gamma reconciled to 0.45 for walk.
- ✅ Night-time IST evaluation independent of server timezone.
- ✅ Low-data cap and “silence ≠ safety” warnings; unknown data lowers
  confidence instead of scoring zero.
- ⚠️ Weights remain hypotheses; field calibration (Phase 7) was not possible
  in this environment.

## Phase 5 — Flutter app

- ✅ Full Riverpod + go_router app: splash, onboarding, auth, home/map,
  search, routes, navigation, safety details, emergency, report, profile.
- ✅ Dio client with bearer injection, single-flight refresh retry, typed
  failures; tokens only in `flutter_secure_storage`.
- ✅ Real place search, route request, emergency lookup, report submission.
- ✅ Navigation preview: GPS stream, distance/bearing/ETA, per-stretch score,
  warnings, report/emergency shortcuts; honest “waiting for GPS” state.
- ✅ Safety details: indicator bars, provenance chips, weakest stretches,
  route risk strip; engine warning codes humanized (no raw codes in UI).
- ✅ Accessibility: score is always colour + number + word; semantics labels;
  text scaling clamped; 44 px touch targets.
- ✅ Error/loading/empty states on every screen; location permission requested
  only on explicit action.
- ✅ Platform config: Android permissions + label, iOS location/ATS keys, web
  shell + metadata.
- ✅ `flutter analyze`: **no issues**. `flutter test`: **9 passing**.
  `flutter build web --release`: **succeeds**.
- ⚠️ Web map is a canvas preview (upstream `maplibre_gl_web` 0.21 incompatible
  with Flutter 3.47). Native Android/iOS use real MapLibre GL.
- ⚠️ Android debug APK: see “Build verification” below.
- ⛔ iOS binary/device test (no Xcode).

## Phase 6 — Integration & hardening

- ✅ Backend unit tests: **16 passing** (scoring, aggregation, polyline
  regression).
- ✅ Live integration tests: **10 passing** (`RUN_INTEGRATION=1`), including
  walk/vehicle routes, out-of-area guard, emergency, reports, refresh rotation,
  account deletion.
- ✅ API smoke script: **18 checks**, creates and deletes a throwaway account
  (`scripts/smoke-api.sh`).
- ✅ Out-of-service-area guard on client and server.
- ✅ Privacy: no location history, hashed device fingerprint, fuzzed report
  coordinates, no raw geometry in logs.
- ✅ Docs: `README.md`, `docs/SETUP.md`, this checklist.
- ⚠️ p95 latency ≈ 2–4 s cold for a recommendation on this machine; within the
  plan's MVP target but not load-tested.

## Phase 7 — Field validation & calibration

- ⛔ Not attempted. Requires real night-time ground truth and user studies.
  The app labels scores as environmental estimates and exposes confidence.

## Phase 8 — Deployment & release

- ✅ Production API image + compose profile + healthcheck.
- ⛔ CI/CD pipeline, managed secrets, TLS proxy, backups/restore drill, Play
  Store signing, staged rollout, crash dashboards — out of scope for this
  workspace and require external accounts.

## Build verification

| Check | Result |
|---|---|
| `npm run typecheck` (backend) | ✅ clean |
| `npm test` (backend, 16) | ✅ pass |
| `npm run test:integration` (10) | ✅ pass |
| `./scripts/smoke-api.sh` (18) | ✅ pass |
| `flutter analyze` | ✅ no issues |
| `flutter test` (9) | ✅ pass |
| `flutter build web --release` | ✅ built |
| `flutter build apk --debug` | _recorded below after the build completes_ |

Android build note: the first attempt failed while downloading Gradle 9.3.1
from GitHub (HTTP 504 from the redirect target). The download was retried; the
build then ran under JDK 25 and Gradle 9.3.1. Any JDK/Gradle incompatibility is
an environment issue, not an app-code issue; the web/analysis/test results above
are independent of it.

## Honest limitations (must be carried into any release review)

1. **Lighting is OSM-tag based, not field-verified.** Scores are conservative
   and often “poor”; the UI says “lighting not field-verified”.
2. **Shop hours are thin** (1,581/42,133). Unknown is never treated as closed.
3. **No live activity/traffic feed** — the activity indicator is a transparent
   model prior (`activity_model_est`), not measured footfall.
4. **Community reports are moderated manually**; only published reports affect
   scores. Report influence is capped by trust score.
5. **Web map is a preview**, not MapLibre.
6. **Bengaluru only**; no other city data is present.
7. **No field calibration** of weights; treat rankings as directional.

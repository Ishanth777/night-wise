# NightWise

Safety-aware night navigation for Bengaluru. NightWise generates real walking and
vehicle routes, then re-ranks them by environmental safety signals — street
lighting, open businesses, street activity, community reports and emergency
access — instead of choosing on speed alone.

> NightWise safety scores are environmental estimates based on available
> indicators, not guarantees of personal safety. Missing data is shown as
> missing; it is never replaced with a fabricated value.

## What is in this repository

| Part | Stack | Location |
|---|---|---|
| Mobile app | Flutter 3.47 / Dart 3.13, Riverpod, go_router, Dio, MapLibre GL | `app/` |
| API | Node 20+ / Express 4 / TypeScript, Zod, JWT + rotating refresh tokens | `backend/` |
| Data | PostgreSQL 16 + PostGIS 3.4, OSM ingest, IST-aware opening-hours evaluator | `backend/src/db`, `backend/src/jobs` |
| Routing | Self-hosted Valhalla (pedestrian + auto) with a custom re-ranking pipeline | `infra/`, `backend/src/services/ranking.service.ts` |
| Scoring | Pure, I/O-free engine with golden tests | `backend/src/scoring/` |
| Ops | Docker Compose, production API image, migration + smoke scripts | `infra/`, `backend/Dockerfile`, `scripts/` |

## Verified end-to-end behaviour

The stack was built against a real OpenStreetMap Southern-Zone extract clipped
to the Bengaluru service area, and verified on this machine:

- **279,096 roads**, **357,743 road segments**, **42,133 shops** (1,581 with
  parsed opening hours), **1,359 police stations / hospitals / clinics**.
- Walking and vehicle route recommendations return real Valhalla geometry with
  per-250 m segments, per-indicator scores, a confidence value, warnings,
  provenance and an honest data-health block.
- Emergency lookup, community report intake + confirm/deny voting, geocoding
  (Photon → Nominatim fallback), route-detail reload by id, profile/settings,
  saved routes, registration, login, refresh-token rotation, logout and hard
  account deletion all work against the live database.
- 16 backend unit tests, 12 live integration tests, Flutter tests, plus a
  26-check API smoke script.

## Architecture

```
Flutter app (Android / iOS; web canvas preview)
        │ HTTPS/JSON
        ▼
Express API ──► auth, rate limits, validation, error matrix
        │
        ├──► Valhalla ── candidate routes (pedestrian / auto)
        ├──► PostgreSQL + PostGIS ── corridor data, OSM, reports, cache
        ├──► Redis ── response cache + rate limiting
        └──► Photon (optional) / Nominatim ── place search
                 │
                 ▼
        Pure scoring engine ── indicators → weighted segment scores
                 │            → length-aware aggregation → labels
                 ▼
        Safest / Fastest / Balanced / Alternative
```

The recommendation pipeline is `geocode → Valhalla candidates → split at ≤250 m
→ batched corridor queries → pure scoring → prune by detour budget → label`.
Weights live in `backend/src/config/scoring.ts`; the scoring engine has no I/O.

## Quick start

Prerequisites: Docker, Node.js 20+, and Flutter 3.22+ (Android/iOS tooling only
needed to run the app). See [docs/SETUP.md](docs/SETUP.md) for full details,
data rebuild steps and the Android emulator URL.

```bash
# 1. Infrastructure (Postgres/PostGIS, Redis, Valhalla with prebuilt tiles)
docker compose -f infra/docker-compose.yml up -d

# 2. API configuration
cp backend/.env.example backend/.env
# edit JWT_SECRET / JWT_REFRESH_SECRET before any shared deployment

# 3. Database migrations (repo SQL migrations, tracked in schema_migrations)
./scripts/migrate.sh

# 4. Run the API
cd backend && npm install && npm run dev
```

Then, in another terminal:

```bash
cd app
flutter pub get
flutter run                     # Android emulator reaches the host at 10.0.2.2
# physical device / custom host:
flutter run --dart-define=NIGHTWISE_API_URL=http://192.168.1.10:3000/api
```

The API is at `http://localhost:3000`; `GET /api/health` should return
`{"ok":true}`.

### Web preview

If no Android/iOS toolchain is available, the release web build is a supported
fallback. It uses the same API and shows an honest "Map preview (web)" canvas
instead of native MapLibre:

```bash
cd app && flutter build web --release
cd .. && python3 scripts/serve_web.py 8080
# open http://127.0.0.1:8080
```

### Rebuilding geodata (only needed on a fresh machine)

The repository ships the clipped Bengaluru PBF (44 MB) and Valhalla tiles
(100 MB). To rebuild:

```bash
cd backend
OSM_PBF_PATH=../data/bengaluru-latest.osm.pbf npm run ingest:osm
cd .. && ./scripts/build-valhalla-tiles.sh
```

The ingest job reads **only** real OSM data. Streetlights are not fabricated:
the `streetlights` table stays empty until a verified civic/crowd source exists.
Where a road is tagged `lit=yes`/`24/7`, that real tag is used as an honest,
lower-confidence (`osm`, 65% confidence) lighting signal; `lit=no`/`down` yields
0% coverage.

## Tests

```bash
# Backend: pure scoring + polyline regression (no services required)
cd backend && npm test

# Backend: live API integration (DB + Redis + Valhalla required)
cd backend && npm run test:integration

# API smoke test — registers and deletes a throwaway account
./scripts/smoke-api.sh
./scripts/smoke-api.sh --with-places   # also exercises the external geocoder

# Flutter: analysis, unit tests, web build
cd app && flutter analyze && flutter test && flutter build web --release
```

## Honest limitations

- **No verified lamp-post dataset.** Lighting is derived from OSM `lit` tags and
  is labelled `osm` / "not field-verified"; confidence is reduced. Scores are
  often in the 30–45 range as a result — this is deliberate honesty, not a bug.
- **Shop hours are sparse.** 1,581 of 42,133 shops have parseable OSM hours;
  unknown hours are never treated as closed (FR-202). Google Places augmentation
  is supported but disabled without an API key (budget cap is enforced when on).
- **Web map is a preview.** `maplibre_gl_web` 0.21 does not compile on Flutter
  3.47 (it still uses `ui.platformViewRegistry`). Native Android/iOS use real
  MapLibre; web draws route geometry on a dark canvas. See
  `app/packages/maplibre_gl_web_stub/README.md`.
- **Bengaluru only.** Both client and server reject points outside the mapped
  bounding box (`OUT_OF_SERVICE_AREA`).
- **iOS/Android builds** require the platform toolchains; the web release build
  and Flutter tests pass in this environment. Android/iOS binary status is
  recorded in [docs/CHECKLIST.md](docs/CHECKLIST.md).

## Documentation

- [docs/SETUP.md](docs/SETUP.md) — install, run, rebuild data, configure keys.
- [docs/API_KEYS_AND_DATA.md](docs/API_KEYS_AND_DATA.md) — every required/optional
  API key and dataset, with local defaults and verification commands.
- [docs/CHECKLIST.md](docs/CHECKLIST.md) — plan phase status and known gaps.
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) — the authoritative product
  and engineering blueprint.

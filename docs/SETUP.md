# NightWise setup

Everything below is what was actually used to build and verify the app on
macOS (arm64). Commands assume the repository root (`nightwise/`).

## Prerequisites

| Tool | Version used | Notes |
|---|---|---|
| Docker Desktop | 29.x | Postgres/PostGIS, Redis, Valhalla, osmium |
| Node.js | 25.6.1 | `>=20` required; `npm` 11.x |
| Flutter | 3.47.9 stable | Dart 3.13.7; `>=3.22` for the MapLibre plugin |
| Android SDK | platform 36/37 | only needed to build/run Android |
| Xcode + CocoaPods | not available here | required for iOS builds |

No paid API keys are required. Google Places and a self-hosted Photon geocoder
are optional enhancements (see [Credentials](#optional-credentials)).

## 1. Start infrastructure

```bash
cd nightwise
docker compose -f infra/docker-compose.yml up -d
docker ps --format '{{.Names}}\t{{.Status}}'
```

Expected containers: `nightwise-postgres` (healthy), `nightwise-redis`,
`nightwise-valhalla`. The Valhalla container mounts the prebuilt tiles in
`tiles/` and the config in `data/valhalla/`.

Check Valhalla directly:

```bash
curl -s http://localhost:8002/status
```

## 2. Configure the backend

```bash
cp backend/.env.example backend/.env
```

Defaults work for local development. Before any shared/deployed environment,
generate real secrets:

```bash
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 32   # JWT_REFRESH_SECRET
```

Keep `DATABASE_URL`, `REDIS_URL` and `VALHALLA_URL` pointing at `localhost`
when the API runs on the host. The production compose profile overrides them
with service names.

## 3. Apply database migrations

```bash
./scripts/migrate.sh
```

This creates `schema_migrations`, then applies every `backend/src/db/migrations/*.sql`
in filename order exactly once. Migrations are plain SQL (PostGIS extension,
tables, GiST indexes, the IST-aware `hours_open_at` function).

> The script talks to the `nightwise-postgres` container with `docker exec`.
> If you renamed the container, edit `scripts/migrate.sh` or run the SQL with
> `psql "$DATABASE_URL" -f file.sql`.

## 4. Geodata

The repo already contains the clipped extract (`data/bengaluru-latest.osm.pbf`,
44 MB) and Valhalla tiles (`tiles/`, 100 MB), so you can skip this section on a
fresh checkout of this workspace.

To rebuild from source:

```bash
./scripts/fetch-and-clip-data.sh      # Geofabrik Southern Zone → Bengaluru bbox
cd backend
OSM_PBF_PATH=../data/bengaluru-latest.osm.pbf npm run ingest:osm
cd ..
./scripts/build-valhalla-tiles.sh
```

The ingest job imports real OSM roads, road segments, shops with parsed hours,
and emergency locations. Expect roughly:

```
roads 279,096 | segments 357,743 | shops 42,133 | shops with hours 1,581 | emergency 1,359
```

Streetlights are **not** fabricated; the `streetlights` table remains empty
until a verified source exists. OSM `lit=yes/24/7/no/down` tags are used as a
real, lower-confidence fallback.

## 5. Run the API

```bash
cd backend
npm install
npm run dev            # tsx watch, listens on :3000
```

Verify:

```bash
curl -s http://localhost:3000/api/health
# {"ok":true,"version":"1.0","time":"..."}
```

Logs are structured JSON (pino). `npm run build && npm start` runs the compiled
output from `dist/`.

## 6. Run the Flutter app

```bash
cd app
flutter pub get
flutter devices
flutter run
```

The API base URL is selected at runtime:

| Target | Default URL |
|---|---|
| Android emulator | `http://10.0.2.2:3000/api` |
| iOS simulator / desktop | `http://localhost:3000/api` |
| Web | `http://localhost:3000/api` |

For a physical phone on the same Wi-Fi, pass your machine's LAN address:

```bash
flutter run --dart-define=NIGHTWISE_API_URL=http://192.168.1.10:3000/api
```

Android permits cleartext HTTP for local development (`usesCleartextTraffic`);
use HTTPS and remove that flag for a real deployment.

### Web note

`flutter build web --release` works, but the web map is a **canvas preview**
(dark background, route geometry, endpoints, tap-to-drop). Why:
`maplibre_gl_web 0.21` still calls `ui.platformViewRegistry`, removed from the
current Flutter web engine. The app uses a conditional export in
`app/lib/widgets/night_map.dart`; native builds use the real MapLibre GL plugin.
A local no-op plugin (`app/packages/maplibre_gl_web_stub/`) is wired through
`dependency_overrides` so the web build does not register the broken backend.

### iOS / Android

- Android manifest includes `INTERNET`, `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`. Build with `flutter build apk --debug`.
- iOS `Info.plist` includes `NSLocationWhenInUseUsageDescription` and local
  networking ATS allowance. A full Xcode install + CocoaPods is required to
  build iOS; that was not available in this environment, so no iOS binary was
  produced or device-tested.

## 7. Tests

```bash
# Backend pure tests (fast, no services)
cd backend && npm test

# Backend integration against the running stack
cd backend && npm run test:integration

# Full API smoke test (creates + deletes a throwaway account)
./scripts/smoke-api.sh
./scripts/smoke-api.sh --with-places   # adds a live Nominatim request

# Flutter
cd app
flutter analyze
flutter test
flutter build web --release
```

The integration suite is skipped unless `RUN_INTEGRATION=1`; the geocoder test
inside it additionally requires `RUN_NETWORK_TESTS=1`. Both are set by
`npm run test:integration` (network test stays opt-in).

## 8. Production container

```bash
# Apply migrations first (see step 3)
JWT_SECRET="$(openssl rand -hex 32)" \
JWT_REFRESH_SECRET="$(openssl rand -hex 32)" \
ALLOWED_ORIGINS="https://app.example.com" \
docker compose -f infra/docker-compose.yml --profile api up -d --build
```

`backend/Dockerfile` is a multi-stage Node 22 image running as the unprivileged
`node` user, with a `/api/health` healthcheck. The API is exposed on port 3000.
Put TLS, gzip and auth-independent rate limiting in front (Caddy/nginx).

## Optional credentials

| Feature | Variable | Without it |
|---|---|---|
| Google Places hours augmentation | `GOOGLE_PLACES_API_KEY`, `PLACES_ENABLED=true` | Uses OSM hours + category priors; feature degrades safely. Budget cap `PLACES_MONTHLY_BUDGET_CAP_USD` is enforced when enabled. |
| Self-hosted Photon geocoder | `PHOTON_URL` | Falls back to public Nominatim (`NOMINATIM_URL`). If both fail, `/places/search` returns an honest error — it never invents coordinates. |
| Sentry | `SENTRY_DSN` | Errors are logged with pino only. |

Nominatim's usage policy requires a real contact in the User-Agent; set
`NOMINATIM_APP_NAME` and update `backend/src/services/geocode.service.ts` if you
deploy publicly.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Invalid or expired access token` | Access tokens live 15 minutes. The Flutter client refreshes automatically; curl scripts must log in again. |
| `OUT_OF_SERVICE_AREA` | Both endpoints must be inside `77.30–77.90 E, 12.70–13.25 N` (Bengaluru). |
| Recommendations take ~2–4 s | Expected: Valhalla alternates + batched PostGIS corridor queries. Responses are cached for 10 minutes. |
| Scores cluster around 30–45 | Honest effect of sparse lighting/hours data, not an outage. See the data-health block on the routes screen. |
| `docker: Error response ... port is already allocated` | Another Postgres/Redis/Valhalla is running. Stop it or change the host ports. |
| Android build stuck downloading Gradle | The wrapper downloads Gradle 9.3.1 on first use. Network issues can produce a 504; retry, or pre-seed `~/.gradle/wrapper/dists`. |
| Flutter web map is blank/dark | Expected canvas preview on web. Use an Android/iOS build for the MapLibre map. |

## Security notes

- `JWT_SECRET`/`JWT_REFRESH_SECRET` defaults are dev-only. Rotate them for any
  deployment; changing them invalidates all sessions.
- Refresh tokens are stored hashed and rotate on every use, with family
  revocation on reuse.
- Reports accept anonymous submissions; only a SHA-256 hash of the device
  fingerprint is stored. Coordinates are fuzzed ~50 m at read time.
- No location history is stored. Route cache keys use rounded coordinates and a
  time bucket, not user identity.
- Rate limits are enforced in Redis: global 240/h/IP, recommendations 120/h/user
  and 30/h/IP, reports per user/IP day cap. If Redis is down the limiter fails
  open (documented degradation) rather than taking the API down.

# API keys & data checklist

Everything NightWise needs to run locally is already in this repository except
two JWT secrets. This page lists every external dependency, which ones are
optional, and what to fill in before a shared deployment.

## 1. Required configuration

Copy `backend/.env.example` to `backend/.env` and set:

| Variable | Required | What it is | Local default |
|---|---|---|---|
| `DATABASE_URL` | ✅ | PostgreSQL 16 + PostGIS connection | `postgres://nightwise:nightwise@localhost:5432/nightwise` |
| `REDIS_URL` | ✅ | Response cache + rate limiting | `redis://localhost:6379` |
| `VALHALLA_URL` | ✅ | Self-hosted routing engine | `http://localhost:8002` |
| `JWT_SECRET` | ✅ | Access-token signing key | **generate** |
| `JWT_REFRESH_SECRET` | ✅ | Reserved for refresh-token signing | **generate** |
| `OSM_PBF_PATH` | only for ingest | Clipped Bengaluru extract | `../data/bengaluru-latest.osm.pbf` |
| `PORT` | optional | API port | `3000` |
| `NODE_ENV` | optional | `development` / `production` | `development` |
| `LOG_LEVEL` | optional | pino level | `debug` |

Generate secrets with:

```bash
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 32   # JWT_REFRESH_SECRET
```

### Flutter client

| Define | Required | Default |
|---|---|---|
| `NIGHTWISE_API_URL` | only for physical devices / custom hosts | `http://localhost:3000/api` (web/desktop), `http://10.0.2.2:3000/api` (Android emulator) |

Example:

```bash
flutter run --dart-define=NIGHTWISE_API_URL=http://192.168.1.10:3000/api
```

## 2. Required data (already committed)

| Data | Location | Notes |
|---|---|---|
| OpenStreetMap Bengaluru extract | `data/bengaluru-latest.osm.pbf` | 44 MB, clipped to the service bbox |
| Valhalla routing tiles | `tiles/` + `tiles/valhalla.json` | Built from the extract; mounted read-only by Compose |
| PostGIS schema | `backend/src/db/migrations/*.sql` | Run `./scripts/migrate.sh` |
| OSM roads/segments/shops/emergency rows | PostgreSQL | Populated by `npm run ingest:osm`; verified counts below |

Verified database contents on this machine:

- **279,096 roads**
- **357,743 road segments**
- **42,133 shops** (1,581 with parseable opening hours)
- **1,359 police stations / hospitals / clinics**
- **0 streetlights** — intentional; no verified lamp-post dataset was available

Rebuild only when the PBF or tiles are missing:

```bash
cd backend && OSM_PBF_PATH=../data/bengaluru-latest.osm.pbf npm run ingest:osm
cd .. && ./scripts/build-valhalla-tiles.sh
```

## 3. Optional external services (no key required to run)

| Service | Variable(s) | Behaviour without it |
|---|---|---|
| **Photon** geocoder | `PHOTON_URL` | Falls back to public Nominatim |
| **Nominatim** geocoder | `NOMINATIM_URL`, `NOMINATIM_APP_NAME` | Required for place search unless Photon is set; public instance needs a descriptive app name and low request rate |
| **Google Places** | `GOOGLE_PLACES_API_KEY`, `PLACES_ENABLED=true`, `PLACES_MONTHLY_BUDGET_CAP_USD` | Disabled-safe: OSM opening hours + category priors are used; data-health text says so |
| **Allowed browser origins** (production) | `ALLOWED_ORIGINS` | Development allows all origins; production needs a comma-separated list |

No payment or account is needed for the app to run. There is currently **no
verified Bengaluru streetlight API/dataset**; the `streetlights` table stays
empty and OSM `lit=*` tags are used with reduced confidence instead.

## 4. External APIs consumed at runtime

| Purpose | Endpoint | Requires |
|---|---|---|
| Walking/vehicle candidates | `POST {VALHALLA_URL}/route` | local Valhalla container |
| Place search | `GET /api/places/search` → Photon or Nominatim | network (unless Photon/local) |
| Shop-hours augmentation | Google Places (optional, behind budget cap) | key + `PLACES_ENABLED=true` |
| Map tiles (native map) | OSM raster tiles configured in the app | network |

## 5. Service ports

| Service | Port |
|---|---|
| API | `3000` |
| PostgreSQL | `5432` |
| Redis | `6379` |
| Valhalla | `8002` |
| Flutter web preview (optional) | `8080` |

## 6. Verification

```bash
docker compose -f infra/docker-compose.yml up -d postgres redis valhalla
./scripts/migrate.sh
cd backend && npm run dev
curl -s http://localhost:3000/api/health          # {"ok":true,...}
./scripts/smoke-api.sh                            # 26 checks
RUN_INTEGRATION=1 npm run test:integration        # 12 checks
# optional web preview
cd ../app && flutter build web --release
cd .. && python3 scripts/serve_web.py 8080
```

The smoke script creates and deletes a throwaway account. It never fabricates
geography; every coordinate is inside the Bengaluru service area.

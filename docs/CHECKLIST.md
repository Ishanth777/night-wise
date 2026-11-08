# NightWise — Implementation Checklist

Source of truth: `docs/IMPLEMENTATION_PLAN.md`. This file tracks execution. Update as work completes.

## Environment notes (recorded at build start)
- ✅ Node v25.6.1, npm 11.9.0, Docker 29.9.2 (daemon started manually), psql client 18
- ❌ **Flutter SDK not installed** — Flutter/Dart code is written in full but cannot be built/run on this machine. See `docs/SETUP.md` § Flutter.
- ❌ Google Places API key missing → Places augmentation disabled-safe (falls back to OSM hours + priors). Documented.
- ❓ Valhalla tiles: being built from a real Geofabrik Karnataka PBF extracted to the Bengaluru bbox (district polygon t.b.d. — bbox per plan §11.2 bounds).

## Phase 0 — Infra & spikes
- [x] Git repo initialized
- [ ] docker-compose for postgres+postgis, redis, valhalla, tileserver
- [ ] Bengaluru OSM extract downloaded+clipped
- [ ] Valhalla tiles built from extract; pedestrian/auto routes verified via curl

## Phase 1 — Backend scaffold & constants (Weeks 2–4)
- [x] Repo layout per plan §13
- [ ] package.json, tsconfig, vitest, env validation (config/env.ts)
- [ ] config/scoring.ts (authoritative tunables, Appendix A)
- [ ] DB migrations (plan §8 schema)
- [ ] OpenAPI/zod schemas as single contract

## Phase 4-priority — Safety scoring engine (pure, testable first)
- [ ] normalizers: lights/shops/activity/reports/emergency
- [ ] priors (per mode/road-class/hour), confidence blending
- [ ] aggregate.ts: length-weighted + risk-dominant + dark_max + endpoint penalty
- [ ] engine.ts with decision trace, warnings, caps
- [ ] Golden tests: plan §9.5 worked example ±2, App.B scenarios 1–7 (pure ones)

## Phase 2 — Data ingestion
- [ ] OSM PBF → road_segments import (imposm/osm2pgsql or custom osmium+pg job)
- [ ] POI (shop/amenity) import + opening_hours parser
- [ ] Emergency locations from OSM
- [ ] data_sources stamps; lit/estimations flagged as model_est — no fabricated streetlights

## Phase 3 — Routing & APIs
- [x] Valhalla client routes confirmed via curl
- [ ] segmentizer (geometry → ≤250m segments snapped to road graph)
- [ ] geodata.service corridor pulls (ST_DWithn buffers) against real tables
- [ ] ranking.service (detour budget, labels, dedupe)
- [ ] REST APIs: auth, recommend, emergency, reports, search
- [ ] Middleware: auth JWT, zod validation, rate-limit (Redis), errors, request logs
- [ ] Integration tests against real containers

## Phase 5 — Flutter app
- [x] Folder structure per plan §12
- [ ] Theme/hight-safety colors, MapLibre integration, Riverpod wiring
- [ ] Screens: splash/onboard/auth/home/search/mode/routes/nav/safety/emergency/report/profile
- [ ] API client from OpenAPI shape; GPS handling; score visualization
- [ ] Widget tests

## Phase 6–8 — Integration, deployment, release
- [ ] e2e curl smoke: server → real Valhalla → real PostGIS → scored response
- [ ] README/SETUP docs with missing-credential sections
- [ ] Deployment files (Dockerfile, compose prod profile)

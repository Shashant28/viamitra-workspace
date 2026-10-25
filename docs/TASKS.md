# Tasks

Rules: one task per session/branch. Each task lists Files (scope fence), Depends, and Done-when (must be verifiable by a command).
Status: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (reason in PROGRESS.md)
Paths are relative to the workspace root. Since 2026-10-26 code lives in three git repos (`viamitra-backend`, `viamitra-mobile`, `viamitra-web`); branch and commit inside each repo a task touches. Paths in done tasks were rewritten to where those files live now.

## Phase 0 — Setup

- [x] **T0.1 Monorepo skeleton**
  Files (now split; `turbo.json` dropped): `viamitra-mobile/` and `viamitra-web/` each: `package.json`, `pnpm-workspace.yaml`, `packages/config/**`, `.gitignore` · `viamitra-backend/.env.example`
  Depends: —
  Done-when: `pnpm install` succeeds; `pnpm -r typecheck` runs (even with zero packages).

- [x] **T0.2 Backend skeleton + health endpoint**
  Files: `viamitra-backend/backend/**`
  Depends: T0.1
  Done-when: `cd viamitra-backend/backend && uv run pytest` passes a test hitting `GET /health` → 200.

- [x] **T0.3 Local infra**
  Files: `viamitra-backend/infra/docker-compose.yml`, `viamitra-backend/infra/emqx/**`, `viamitra-backend/infra/postgres/**`
  Depends: T0.1
  Done-when: `docker compose -f viamitra-backend/infra/docker-compose.yml up -d` brings up postgres (PostGIS + TimescaleDB extensions enabled), Redis, and EMQX healthy.

- [x] **T0.4 DB schema v1 + RLS**
  Files: `viamitra-backend/backend/app/models/**`, `viamitra-backend/backend/alembic/**`, `viamitra-backend/backend/alembic.ini`, `viamitra-backend/backend/tests/test_rls.py`, `viamitra-backend/backend/pyproject.toml`, `viamitra-backend/backend/uv.lock`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T0.2, T0.3
  Done-when: migration applies cleanly; a test proves org A cannot read org B rows.

- [!] **T0.5 GPS spike (driver app)**
  Files: `viamitra-mobile/apps/driver/**`
  Depends: T0.1
  Done-when: dev build on a real Android phone records points with screen off for 15 min; notes on battery + OEM (Xiaomi/Samsung) behaviour written in PROGRESS.md.

- [ ] **T0.6 CI pipeline** (approved by human 2026-10-25)
  Files: `viamitra-backend/.github/workflows/**`, `viamitra-mobile/.github/workflows/**`, `viamitra-web/.github/workflows/**`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T0.3, T0.4
  Done-when: each repo has a GitHub Actions workflow that runs its own `scripts/check.sh` with `CHECK_NO_SKIPS=1` (the workspace `scripts/verify.sh` is not in any repo). The backend workflow uses Postgres (PostGIS + TimescaleDB), Redis and EMQX service containers; every secret is generated per run (none stored in the repo or as fixed values); `backend/tests/test_health.py` and the DB tests run against those services with 0 skipped. Each workflow passes on a PR.

## Phase 1 — MVP

- [x] **T1.1 OTP auth (backend)** — Files: `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/app/services/auth*`, tests · Depends: T0.4 · Done-when: tests cover send, verify, rate-limit, refresh rotation.
- [x] **T1.2 API client generation** — Files (now split): `viamitra-backend/backend/scripts/export_openapi.py`, `viamitra-backend/openapi.json`, `viamitra-mobile/packages/api-client/**`, `viamitra-web/packages/api-client/**`, `gen:api` script in each JS repo's `package.json` · Depends: T1.1 · Done-when: `pnpm gen:api` regenerates with no diff on second run.
- [x] **T1.3 Driver login + today's trip** — Files: `viamitra-mobile/apps/driver/**`, `viamitra-backend/backend/tests/test_route_auth*` · Depends: T1.2, T1.4j
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_route_auth.py` walks every route on `app.main.app` and fails if any route not on an explicit public allowlist (e.g. `/health`, `/auth/*`) lacks a `require_role` dependency, with a case proving an unguarded probe route makes it fail; `./scripts/verify.sh` passes with 0 skipped. (Added by human 2026-10-26 from the T1.4j security review.) Only the route-guard test was done here; the driver work moved to T1.3a–T1.3d (human decision 2026-10-26).
- [x] **T1.3a Backend: `GET /trips/today` for drivers** (approved by human 2026-10-26)
  Files: `viamitra-backend/backend/app/api/trips*`, `viamitra-backend/backend/app/main.py` (router include only), `viamitra-backend/backend/app/services/trips*`, `viamitra-backend/backend/app/schemas/trips*`, `viamitra-backend/backend/app/models/entities.py` (Trip `service_date` only), `viamitra-backend/backend/alembic/versions/*_trip_service_date.py` (next free revision), `viamitra-backend/backend/tests/test_trips_today.py`, `viamitra-backend/backend/tests/test_ingest_db.py` (trip insert sets `service_date`; added by human 2026-10-26), `viamitra-backend/backend/tests/test_route_auth.py` (allowlist untouched; only if the walk needs adjusting), `viamitra-backend/openapi.json`, `viamitra-mobile/packages/api-client/**`, `viamitra-web/packages/api-client/**`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3
  Note: `trips` has no date column today (`backend/app/models/entities.py:176-198`), so this task adds `service_date` (date, not null) with a migration. Which timezone defines "today" isn't decided yet (no ADR); the task proposes one (e.g. Asia/Kolkata) and waits for approval.
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_trips_today.py` passes against the real test DB and proves:
    - a driver token gets 200 with only trips where `driver_id` is the caller and `service_date` is today; another driver's trips in the same org and every trip in another org are absent;
    - parent, org_admin and super_admin tokens get 403; missing or invalid tokens get 401;
    - org scoping comes from the verified token via `get_tenant_session`, never from the request.
  Also: `uv run pytest -q tests/test_route_auth.py` passes with the route not on the public allowlist; `openapi.json` is re-exported and `pnpm gen:api` in both JS repos shows no diff on a second run; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.3b Expo driver app scaffold** (approved by human 2026-10-26)
  Files: `viamitra-mobile/apps/driver/**` (except generated `android/`, `ios/`), `viamitra-mobile/pnpm-lock.yaml`, `viamitra-mobile/pnpm-workspace.yaml` (only if needed), `viamitra-mobile/scripts/check.sh` (only to include the app's checks), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3
  Rule: before installing anything, propose each dependency with its version verified by `npm view <pkg> version` (and Expo SDK compatibility), then wait for the human's approval. Pin exact versions.
  Done-when: `apps/driver` is an Expo Router app with TypeScript strict, configured for a dev build through `app.config.ts` (never Expo Go). It imports `@viamitra/api-client` (or the package's actual name in `packages/api-client/package.json`) and calls a typed client against `GET /health`. The base URL comes from a non-secret `EXPO_PUBLIC_` variable, documented in `.env.example`. `cd viamitra-mobile && pnpm --filter driver typecheck && pnpm --filter driver lint && pnpm --filter driver test` pass, with at least one test exercising the client wiring. A dev build installs and launches on an Android emulator via `expo run:android` (a manual step, noted in PROGRESS.md). `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.3c Driver OTP login screen** (approved by human 2026-10-26)
  Files: `viamitra-mobile/apps/driver/**` (except generated `android/`, `ios/`), `viamitra-mobile/pnpm-lock.yaml` (only for `expo-secure-store`, version approved first), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3b
  Done-when: the login flow (phone number → OTP) calls the existing `/auth/otp/send`, `/auth/otp/verify` and `/auth/refresh` through the generated client. Access and refresh tokens are stored only in `expo-secure-store`; AsyncStorage is never used for tokens. A refresh failure returns the user to login. `cd viamitra-mobile && pnpm --filter driver test` covers: successful login stores both tokens via secure-store (mocked); a wrong code shows an error and stores nothing; logout deletes both keys; a non-driver role in the token is rejected client-side; no token value or phone number is logged. `grep -rn "AsyncStorage" apps/driver/src apps/driver/app` finds nothing. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.3d Driver "today's trip" screen** (approved by human 2026-10-26)
  Files: `viamitra-mobile/apps/driver/**` (except generated `android/`, `ios/`), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3a, T1.3c
  Done-when: after login, the driver sees today's trips from `GET /trips/today` via the generated client, with loading, empty ("no trip today"), error and 401 states (a 401 triggers one refresh, then logout). No child PII is logged. `cd viamitra-mobile && pnpm --filter driver test` covers each state with a mocked client. `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.4 Location ingest (MQTT → Redis → Timescale)** — Files: `viamitra-backend/backend/app/workers/ingest*`, `viamitra-backend/backend/pyproject.toml`, `viamitra-backend/backend/uv.lock`, `viamitra-backend/.env.example`, `viamitra-backend/infra/emqx/acl*`, tests · Depends: T0.4
- [x] **T1.4a Ingest worker reconnects to EMQX or exits non-zero on disconnect**
  Files: `viamitra-backend/backend/app/workers/ingest*`, `viamitra-backend/backend/tests/test_ingest*`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_ingest_worker_lifecycle.py` passes, proving that after `docker exec infra-emqx-1 emqx ctl clients kick viamitra-ingest` (and after a simulated queue-put timeout) the worker either resubscribes and ingests a new publish within 10 s or `run_ingest` exits with a non-zero status within 10 s; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4b Per-device rate limit on location publishes**
  Files: `viamitra-backend/infra/emqx/base.hocon`, `viamitra-backend/backend/app/workers/ingest*`, `viamitra-backend/backend/tests/test_ingest*`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_ingest_broker.py -k rate_limit` shows a device publishing above the configured per-client rate is throttled or disconnected by EMQX; `uv run pytest -q tests/test_ingest.py -k min_interval` shows the worker drops points for the same trip closer than the minimum interval; `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.4c Persistent EMQX user provisioning that survives container recreate**
  Files: `viamitra-backend/infra/docker-compose.yml`, `viamitra-backend/infra/emqx/**`, `viamitra-backend/scripts/dev-setup.sh`, `viamitra-backend/backend/tests/test_ingest_broker.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4
  Done-when: `docker rm -f infra-emqx-1 && bash viamitra-backend/scripts/dev-setup.sh` (and `docker compose -p infra down && bash viamitra-backend/scripts/dev-setup.sh`) recreate EMQX with no manual steps, then `./scripts/verify.sh` passes with 0 skipped (broker tests log in with the existing accounts); `git -C viamitra-backend status --short` shows no file containing broker credentials.
- [ ] **T1.4d Redis latest-position key expires shortly after trip end**
  Files: `viamitra-backend/backend/app/workers/ingest*`, `viamitra-backend/backend/tests/test_ingest*`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_ingest.py -k latest_ttl` proves the `trip:{id}:location` TTL is at most 300 s and is refreshed on each accepted point; against local Redis, `redis-cli TTL trip:<id>:location` after one ingested point returns a value ≤ 300; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4e Migration passwords never logged**
  Files: `viamitra-backend/backend/alembic/versions/0010_*` (next number after current head; `down_revision = "0009_trip_service_date"`, decided by human 2026-10-25, renumbered by human 2026-10-26 after T1.3a took 0009), `viamitra-backend/backend/scripts/**`, `viamitra-backend/backend/tests/test_role_passwords.py`, `viamitra-backend/.env.example`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_role_passwords.py` sets role passwords against postgres-test with `log_statement = 'all'` and `log_min_duration_statement = 0`, then asserts the password string does not appear in `docker logs infra-postgres-test-1`; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4f Redelivered points older than the freshness window still reach history**
  Files: `viamitra-backend/backend/app/workers/ingest*`, `viamitra-backend/backend/tests/test_ingest*`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4a
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_ingest.py -k stale_redelivery` proves a point older than `MAX_LOCATION_AGE` from an authorized active trip is written to history but does not update the Redis latest position or publish; `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.4g API connects as the restricted runtime role, not the DB owner**
  Files: `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/app/services/**`, `viamitra-backend/backend/tests/**`, `viamitra-backend/.env.example`, `viamitra-backend/scripts/dev-setup.sh`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4c
  Done-when: the API reads a runtime-role URL (`viamitra_runtime`) separate from the migration/owner `DATABASE_URL`; a test asserts the API's connection role has neither `rolsuper` nor `rolbypassrls`; `bash viamitra-backend/scripts/dev-setup.sh` adds the new variable; `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.4h Verified-token tenant dependency + fail-fast DB role check** (from T1.4g reviews; approved by human 2026-10-25)
  Files: `viamitra-backend/backend/app/main.py`, `viamitra-backend/backend/app/api/deps*`, `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/app/services/db.py`, `viamitra-backend/backend/alembic/versions/*_auth_lookup_minimal.py` (next free revision number; T1.4e claims 0007), `viamitra-backend/backend/tests/test_api_db_role.py`, `viamitra-backend/backend/tests/test_auth_flow.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4g
  Done-when: a FastAPI dependency verifies the access-token signature/expiry and sets `app.org_id` from the verified claim only; a FastAPI `lifespan` hook runs the RLS-escape check so a bad `RUNTIME_DATABASE_URL` stops startup; with `APP_ENV=prod` the API refuses to start if `DATABASE_URL` is set (test); `auth_lookup_user` returns only the minimum login needs and no other-org data beyond that, via a new migration, with a test asserting its result columns; the org A/B test in `tests/test_api_db_role.py` uses `app.main.app` and that dependency (no unsigned decode) and adds a forged-token case returning 401; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4i Harden `viamitra-backend/scripts/dev-setup.sh` (from T1.4c security review)** (approved by human 2026-10-25)
  Files: `viamitra-backend/scripts/dev-setup.sh`, `viamitra-backend/infra/docker-compose.yml`, `viamitra-backend/.gitignore`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4c
  Done-when: role-password sync rejects values not matching `^[0-9a-f]{32}$` and suppresses server-side statement logging for that session; an EXIT/INT/TERM trap removes the EMQX bootstrap CSV; the EMQX marker stores a hash of the provisioned accounts and re-provisions on change; `set +x` at the top; `.gitignore` append uses `grep -qxF` and newline-safe append; EMQX node cookie and dashboard password are generated (key names verified against EMQX 6.3.2 docs); Redis healthcheck uses `REDISCLI_AUTH`, not `-a`; `bash viamitra-backend/scripts/dev-setup.sh` twice + `./scripts/verify.sh` pass with 0 skipped.
- [x] **T1.4j Role-based access dependency** (from T1.4h security review L4; approved by human 2026-10-25)
  Files: `viamitra-backend/backend/app/api/deps*`, `viamitra-backend/backend/tests/test_roles*`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4h
  Done-when: `require_role(...)` (roles: driver, parent, org_admin, super_admin) builds on `get_access_claims` and returns 403 for a validly signed token whose role is not allowed (401 behaviour for missing/invalid tokens unchanged); tests mount one route per role on `app.main.app` and assert each role gets 2xx on its own route and 403 on every other role's route; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4k Separate signing keys per purpose** (from T1.4h security review L2; low priority; approved by human 2026-10-25)
  Files: `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/tests/test_auth_flow.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4h
  Done-when: access-token signing, OTP hashing and rate-limit key hashing each use a distinct key (derived per purpose from `AUTH_TOKEN_SECRET`, or separate env vars documented in `viamitra-backend/.env.example` if a new ADR chooses that); a test shows a value produced for one purpose does not verify or match for another; existing auth tests still pass; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4l API docs routes only in dev** (from T1.3 security review; do right after T1.3a; approved by human 2026-10-26)
  Files: `viamitra-backend/backend/app/main.py`, `viamitra-backend/backend/tests/test_docs_routes.py`, `viamitra-backend/backend/tests/test_route_auth.py` (docs allowlist entries made conditional on `APP_ENV`), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3a
  Done-when: `/openapi.json`, `/docs`, `/docs/oauth2-redirect` and `/redoc` are served only when `APP_ENV == "dev"`; unset, `prod` or any other value disables them (the same "unset means prod" rule as `app/services/auth.py` and `app/services/db.py`). `cd viamitra-backend/backend && uv run pytest -q tests/test_docs_routes.py` proves those four paths return 404 with `APP_ENV` unset and with `prod`, and 200 with `dev`. `uv run python scripts/export_openapi.py` still produces an unchanged `openapi.json` in every mode. `tests/test_route_auth.py` passes in both modes with no stale allowlist entries. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4m Location only for today's trips; stale active trips auto-closed** (from T1.3a security review; priority: before pilot; approved by human 2026-10-26)
  Files: `viamitra-backend/backend/app/workers/ingest*`, `viamitra-backend/backend/app/workers/trip_close*`, `viamitra-backend/backend/alembic/versions/*_ingest_service_date.py` (next free revision after T1.4e's `0010_*`, or renumber both if done first), `viamitra-backend/backend/tests/test_ingest*`, `viamitra-backend/backend/tests/test_trip_close*`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3a, T1.4
  Rule: before implementing, propose how the auto-close runs (Celery is not installed; any new dependency or scheduler is approved first) and which DB role performs it. `viamitra_ingest` keeps read-only, column-level access to `trips` (add `SELECT (service_date)` only).
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_ingest.py -k service_date` proves a point for an `active` trip whose `service_date` is not today in Asia/Kolkata (ADR-013) is rejected: not written to history, not written to Redis, not published. A point for today's active trip is still accepted. `uv run pytest -q tests/test_trip_close.py` proves `active` (and `scheduled`) trips with `service_date` before today are closed (`completed`/`cancelled` with `ended_at` set, as proposed and approved), today's trips are untouched, and the close is scoped per org under RLS. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.5 WebSocket live position** — Files: `viamitra-backend/backend/app/api/ws*`, tests · Depends: T1.4
- [ ] **T1.6 Parent live map + ETA** — Files: `viamitra-mobile/apps/parent/**` · Depends: T1.5
- [ ] **T1.7 Geofence events + push** — Files: `viamitra-backend/backend/app/services/events/**`, `viamitra-backend/backend/app/workers/notify*`, tests with GPS fixtures · Depends: T1.4
- [ ] **T1.8 Dashboard: orgs, buses, routes, stops, students CRUD** — Files: `viamitra-web/apps/dashboard/**` · Depends: T1.2
- [ ] **T1.9 Dashboard live fleet map** — Files: `viamitra-web/apps/dashboard/app/(org)/live/**` · Depends: T1.5, T1.8
- [ ] **T1.10 Pickup/drop marking + SOS** — Files: `viamitra-mobile/apps/driver/**`, `viamitra-backend/backend/app/api/trips*` · Depends: T1.3, T1.7

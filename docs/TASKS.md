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
- [x] **T0.7 Local migration script `scripts/db-migrate.sh`** (from T1.4p: the agent couldn't redo an edited migration because the guard hook blocks loading `infra/local.env`; approved by human 2026-10-27)
  Files: `viamitra-backend/scripts/db-migrate.sh` (new), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T0.3
  Rule:
  - Usage: `bash scripts/db-migrate.sh <upgrade|downgrade> <rev> <dev|test|both>`. The script loads `infra/local.env` itself, like `scripts/dev-setup.sh` does. It runs `uv run alembic <upgrade|downgrade> <rev>` in `backend/`, using `DATABASE_URL` for dev and `TEST_ADMIN_DATABASE_URL` for test (the variables `dev-setup.sh` writes).
  - It refuses to run, with a non-zero exit and nothing changed, unless `APP_ENV=dev` and the host of every target URL is `127.0.0.1` or `localhost`.
  - It never prints a URL, password or any other env value. Error messages name the variable only.
  - It prints `alembic current` for each target afterwards, like `dev-setup.sh`.
  - No changes to `.claude/` or the guard hooks.
  Done-when:
  - `bash scripts/db-migrate.sh downgrade <head-1> both` then `bash scripts/db-migrate.sh upgrade head both` leaves both DBs at head.
  - With `APP_ENV` other than `dev`, or a non-local host (shown by overriding the variable in the environment for that run), the script exits non-zero before calling alembic.
  - Its output contains no value from `infra/local.env`. Check this by grepping the output for each password variable's value, inside the script's own self-test mode or by the human.
  - `./scripts/verify.sh` passes with 0 skipped.

- [ ] **T0.8 Production run config for the API** (from the T1.5 security review M1; priority: before pilot; approved by human 2026-10-27)
  Files: `viamitra-backend/backend/Dockerfile` (new), `viamitra-backend/backend/.dockerignore` (new), `viamitra-backend/backend/tests/test_run_config.py` (new), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T0.2, T1.4n, T1.5
  Why: no production start command exists, so uvicorn runs with its defaults. Those defaults are a 16 MiB `ws_max_size` and per-message deflate on, which lets an unauthenticated socket make the server buffer up to 16 MiB before the 4 KB frame check in `app/api/ws.py` runs.
  Rule:
  - The start command is exec form: `uvicorn app.main:app` with `--ws-max-size 16384` and `--ws-per-message-deflate false`.
  - No dev flags: no `--reload`, no `APP_ENV=dev`, no `--proxy-headers`/`--forwarded-allow-ips` (those stay out until the deploy topology is known, as in T1.4q).
  - The image runs as a non-root user.
  - Dependencies come from `uv sync --frozen --no-dev`.
  - No secrets or `.env*` files in the image: `.dockerignore` excludes `.env*`, `.venv`, tests and caches. Configuration is read only from the runtime environment.
  - Propose the exact base image (pinned tag, verified to exist) and how uv is installed in the image before implementing. Any new tool or dependency needs approval.
  Done-when:
  - `cd viamitra-backend/backend && uv run pytest -q tests/test_run_config.py` parses the Dockerfile and proves:
    - the final `CMD` is exec form and runs `uvicorn app.main:app` with `--ws-max-size 16384` and `--ws-per-message-deflate false`;
    - there is no `--reload` and no `APP_ENV=dev`;
    - the last `USER` is not root or 0;
    - `.dockerignore` excludes `.env*`.
  - `docker build -t viamitra-api:check viamitra-backend/backend` succeeds.
  - `docker run --rm --entrypoint id viamitra-api:check -u` prints a non-zero uid.
  - `./scripts/verify.sh` passes with 0 skipped.

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
- [x] **T1.3b Expo driver app scaffold** (approved by human 2026-10-26)
  Files: `viamitra-mobile/apps/driver/**` (except generated `android/`, `ios/`), `viamitra-mobile/pnpm-lock.yaml`, `viamitra-mobile/pnpm-workspace.yaml` (only if needed), `viamitra-mobile/scripts/check.sh` (only to include the app's checks), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3
  Rule: before installing anything, propose each dependency with its version verified by `npm view <pkg> version` (and Expo SDK compatibility), then wait for the human's approval. Pin exact versions.
  Done-when: `apps/driver` is an Expo Router app with TypeScript strict, configured for a dev build through `app.config.ts` (never Expo Go). It imports `@viamitra/api-client` (or the package's actual name in `packages/api-client/package.json`) and calls a typed client against `GET /health`. The base URL comes from a non-secret `EXPO_PUBLIC_` variable, documented in `.env.example`. `cd viamitra-mobile && pnpm --filter driver typecheck && pnpm --filter driver lint && pnpm --filter driver test` pass, with at least one test exercising the client wiring. A dev build installs and launches on an Android emulator via `expo run:android` (a manual step, noted in PROGRESS.md). `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.3c Driver OTP login screen** (approved by human 2026-10-26)
  Files: `viamitra-mobile/apps/driver/**` (except generated `android/`, `ios/`), `viamitra-mobile/pnpm-lock.yaml` (only for `expo-secure-store`, version approved first), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3b
  Done-when: the login flow (phone number → OTP) calls the existing `/auth/otp/send`, `/auth/otp/verify` and `/auth/refresh` through the generated client. Access and refresh tokens are stored only in `expo-secure-store`; AsyncStorage is never used for tokens. A refresh failure returns the user to login. `cd viamitra-mobile && pnpm --filter driver test` covers: successful login stores both tokens via secure-store (mocked); a wrong code shows an error and stores nothing; logout deletes both keys; a non-driver role in the token is rejected client-side; no token value or phone number is logged. `grep -rn "AsyncStorage" apps/driver/src apps/driver/app` finds nothing. `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.3d Driver "today's trip" screen** (approved by human 2026-10-26)
  Files: `viamitra-mobile/apps/driver/**` (except generated `android/`, `ios/`), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3a, T1.3c
  Done-when: after login, the driver sees today's trips from `GET /trips/today` via the generated client, with loading, empty ("no trip today"), error and 401 states (a 401 triggers one refresh, then logout). No child PII is logged. `cd viamitra-mobile && pnpm --filter driver test` covers each state with a mocked client. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.3e Bump TypeScript to the Expo SDK 58 expected version** (from T1.3b; approved by human 2026-10-26)
  Files: `viamitra-mobile/package.json`, `viamitra-mobile/apps/driver/package.json`, `viamitra-mobile/packages/**/package.json` (only the `typescript` pin), `viamitra-mobile/pnpm-lock.yaml`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3b
  Rule: take the version from `pnpm --filter driver exec expo install --check` (currently `~6.0.3`), confirm the exact patch with `npm view typescript@<range> version`, and get approval before installing. Pin exactly. viamitra-mobile only.
  Done-when: `pnpm --filter driver exec expo install --check` reports no outdated packages; `cd viamitra-mobile && pnpm --filter driver typecheck && pnpm --filter driver lint && pnpm --filter driver test` pass; `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.3f iOS: clear driver tokens left in the Keychain after a reinstall** (from T1.3c security review L3; low priority; approved by human 2026-10-26)
  Files: `viamitra-mobile/apps/driver/**` (except generated `android/`, `ios/`), `viamitra-mobile/pnpm-lock.yaml` (only if a storage dependency is approved), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3c
  Rule: the "installed" marker must live in storage that an uninstall wipes, and it holds no token or PII. Propose the mechanism and any dependency (exact version) and get approval before installing.
  Done-when: on first launch after install, with no marker present, the driver app deletes both secure-store token keys before restoring a session, then writes the marker; later launches keep the session. `cd viamitra-mobile && pnpm --filter driver test` covers first launch (tokens cleared) and a later launch (tokens kept). `grep -rn "AsyncStorage" apps/driver/src apps/driver/app` finds nothing unless an approved marker store needs it, and then never for tokens. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.3g Driver secure-storage robustness** (from the T1.4o mobile security review, lows (a)–(c) in its PROGRESS entry; priority: low, before pilot; approved by human 2026-10-27)
  Files: `viamitra-mobile/apps/driver/src/features/auth/**`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4o, T1.3i
  Rule: no new dependency. (d) and (e) were added by the human on 2026-10-27 from the T1.3i open questions; server-side revoke stays as is. (a) Every keystore write, clear and read-then-clear in `token-store.ts`/`auth.ts` (`saveTokens`, `clearTokens`, `clearIfStillStored`, logout's read+clear) runs through one module-level promise queue, so two saves never interleave; `clearIfStillStored` compares both tokens. (b) When `clearTokens` fails at logout, retry the delete once, then overwrite both keys with an empty value (which `loadTokens` treats as absent) so the next start can't restore the session; keep the existing "attempt both deletes" behaviour. (c) Logout reads `REFRESH_TOKEN_KEY` directly for the server revoke, so a failed `loadTokens` or a lone refresh key still gets `POST /auth/logout`. (d) Persist the first-send time of an unanswered refresh (T1.3i's `unanswered` marker) in `expo-secure-store`, tied to the refresh token it belongs to, so after an app relaunch the 7 s re-send cutoff still applies. The persisted time must survive a relaunch (wall-clock epoch ms; a monotonic clock restarts with the process). Write, clear and read it through the (a) queue; clear it whenever the in-memory marker is cleared, and at logout. (e) Check whether global `performance.now()` works at runtime on RN 0.88 in the driver dev build (on the device, not only from the types). If it does, use it for the in-process cutoff clock; if not, keep the current clock. Record the result in the PROGRESS entry. No token, phone or child PII in any error or log.
  Done-when: `cd viamitra-mobile && pnpm --filter driver test` proves:
  - two overlapping `saveTokens` calls end with one driver's matching pair, never a mix;
  - a stale refresh save that lands after a new login's save doesn't clear or replace the new tokens;
  - a failing delete at logout leaves `loadTokens()` returning null;
  - logout with only the refresh key stored, or with `loadTokens` throwing, still sends `POST /auth/logout` with that token;
  - after a simulated relaunch (module state reset, secure store kept), a persisted marker at or past the cutoff means the token isn't sent and the keys are cleared, while a marker inside the cutoff still allows a re-send of the same token;
  - a marker belonging to a different refresh token is ignored, and a backend-handled response or logout removes the persisted marker.

  `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.3h Render tests for driver auth and screens** (from T1.3d/T1.4o verifier notes; approved by human 2026-10-27)
  Files: `viamitra-mobile/apps/driver/package.json` (devDependencies only), `viamitra-mobile/pnpm-lock.yaml`, `viamitra-mobile/apps/driver/jest.setup.*` (only if the library needs one), `viamitra-mobile/apps/driver/src/features/auth/__tests__/**`, `viamitra-mobile/apps/driver/src/features/trips/__tests__/**`, `viamitra-mobile/apps/driver/app/__tests__/**`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4o, T1.3i
  Rule: propose the exact dev-dependency versions, re-checked with `npm view` on the day, and get approval before installing; pin exactly. Candidates seen on npm 2026-10-27:
  - `@testing-library/react-native@14.1.0` (latest). Its peers are `react >=19.0.0`, `react-native >=0.78`, `jest >=29.0.0` and `test-renderer ^1.0.0`; the repo has RN 0.88.0, React 19.3.0 and Jest 30.5.2.
  - `test-renderer@1.3.1` (latest). Its peer is `react ^19.0.0`.

  Confirm they work with `jest-expo@58.0.12` before choosing. No `react-test-renderer` (deprecated in React 19). Tests mock `expo-secure-store` and `fetch` like the existing ones, and mock `expo-router` navigation; no production code changes unless a test exposes a bug (then stop and ask).
  Done-when: `cd viamitra-mobile && pnpm --filter driver test` includes render tests for:
  - `auth-context.tsx`: restore with no tokens → signed-out; restore with a valid refresh → signed-in; `signOut` → signed-out even when the keystore clear throws; a late `refresh()`/`signOut()` that settles after `markSignedIn` doesn't sign the new driver out.
  - the login screen (`app/login.tsx`): invalid number error, OTP step, wrong-code error, and success navigating to today's trips.
  - the today's-trip screen (`app/index.tsx`): loading, trips list, empty, error with Retry, and the redirect to login after logout with no previous trips shown.

  Also a manual check on the `Pixel_9` emulator with the driver dev build (added by human 2026-10-27; record the steps and result in the PROGRESS entry):
  - kill the backend while a refresh is in flight: the driver goes to the login screen after about 7 s (T1.3i cutoff);
  - with the backend up, a normal refresh still works and the driver stays signed in.

  `pnpm audit` adds no new high/critical finding, and `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.3i Driver refresh request timeout below the 10 s grace window** (from the T1.4p proposal; priority: before pilot; approved by human 2026-10-27)
  Files: `viamitra-mobile/apps/driver/src/features/auth/**`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4p
  Why: since T1.4p (ADR-017), presenting a rotated refresh token more than 10 s after its rotation revokes the whole login chain. `runRefresh` (`apps/driver/src/features/auth/auth.ts:97-101`) has no timeout, and an `'unavailable'` result keeps the old token for a later retry. So after a lost response, a retry usually lands outside the window, signs the driver out and leaves a false reuse audit entry.
  Rule: the `/auth/refresh` request aborts after a timeout under 8 s. A refresh token whose request may have reached the server is never re-sent once 10 s have passed since that request started: treat it as `'rejected'` instead (clear the keys and go back to login). Propose the exact timeout before implementing.
  Done-when: `cd viamitra-mobile && pnpm --filter driver test` proves the refresh request aborts at the timeout, a retry within the window re-sends the same token, and a token whose request started more than 10 s earlier is never re-sent. `./scripts/verify.sh` passes with 0 skipped.
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
- [x] **T1.4l API docs routes only in dev** (from T1.3 security review; do right after T1.3a; approved by human 2026-10-26)
  Files: `viamitra-backend/backend/app/main.py`, `viamitra-backend/backend/tests/test_docs_routes.py`, `viamitra-backend/backend/tests/test_route_auth.py` (docs allowlist entries made conditional on `APP_ENV`), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3a
  Done-when: `/openapi.json`, `/docs`, `/docs/oauth2-redirect` and `/redoc` are served only when `APP_ENV == "dev"`; unset, `prod` or any other value disables them (the same "unset means prod" rule as `app/services/auth.py` and `app/services/db.py`). `cd viamitra-backend/backend && uv run pytest -q tests/test_docs_routes.py` proves those four paths return 404 with `APP_ENV` unset and with `prod`, and 200 with `dev`. `uv run python scripts/export_openapi.py` still produces an unchanged `openapi.json` in every mode. `tests/test_route_auth.py` passes in both modes with no stale allowlist entries. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4m Location only for today's trips; stale active trips auto-closed** (from T1.3a security review; priority: before pilot; approved by human 2026-10-26)
  Files: `viamitra-backend/backend/app/workers/ingest*`, `viamitra-backend/backend/app/workers/trip_close*`, `viamitra-backend/backend/alembic/versions/*_ingest_service_date.py` (next free revision after T1.4e's `0010_*`, or renumber both if done first), `viamitra-backend/backend/tests/test_ingest*`, `viamitra-backend/backend/tests/test_trip_close*`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3a, T1.4
  Rule: before implementing, propose how the auto-close runs (Celery is not installed; any new dependency or scheduler is approved first) and which DB role performs it. `viamitra_ingest` keeps read-only, column-level access to `trips` (add `SELECT (service_date)` only).
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_ingest.py -k service_date` proves a point for an `active` trip whose `service_date` is not today in Asia/Kolkata (ADR-013) is rejected: not written to history, not written to Redis, not published. A point for today's active trip is still accepted. `uv run pytest -q tests/test_trip_close.py` proves `active` (and `scheduled`) trips with `service_date` before today are closed (`completed`/`cancelled` with `ended_at` set, as proposed and approved), today's trips are untouched, and the close is scoped per org under RLS. `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.4n Backend `uv run uvicorn` works** (found in T1.3b; approved by human 2026-10-26)
  Files: `viamitra-backend/backend/pyproject.toml`, `viamitra-backend/backend/uv.lock`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T0.4
  Rule: propose the exact `uvicorn` version (verified with `pip index versions uvicorn`) and wait for approval before adding it. Pin it exactly.
  Done-when: from a shell with an unrelated `VIRTUAL_ENV` active, `cd viamitra-backend/backend && uv run uvicorn app.main:app --port 8000` starts the API from the project env (not a global/Anaconda `uvicorn`), and `curl -s localhost:8000/health` answers 200. `uv run pip-audit` shows no new high/critical finding. `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.4o `POST /auth/logout` revokes the refresh token server-side** (from T1.3c security review M3; priority: before pilot; approved by human 2026-10-26)
  Files: `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/alembic/versions/*_auth_logout.py` (only if a new SQL function is needed; next free revision), `viamitra-backend/backend/tests/test_auth_flow.py`, `viamitra-backend/backend/tests/test_route_auth.py` (public allowlist entry), `viamitra-backend/openapi.json`, `viamitra-mobile/packages/api-client/src/schema.d.ts`, `viamitra-web/packages/api-client/src/schema.d.ts`, `viamitra-mobile/apps/driver/src/features/auth/**`, `viamitra-mobile/apps/driver/src/features/trips/**` and `viamitra-mobile/apps/driver/app/index.tsx` (T1.3d security L1/L2 folded in, human 2026-10-27), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.3c
  Rule: the endpoint takes the refresh token in the body (rate-limited like `/auth/refresh`, unknown fields rejected) and sets `revoked_at` on that session only. It answers the same status whether or not the token was valid, so it can't be used to probe tokens. Propose separately (don't implement unasked) whether reusing an already-revoked refresh token should revoke the whole session family.
  Status 2026-10-27: done. Backend `a499a35`, web `ede1429`, mobile `a760626` (driver logout + T1.3d security L1/L2), all on `main`.
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_auth_flow.py -k logout` proves that after logout the same refresh token gets 401 at `/auth/refresh`, other sessions of the same user still refresh, and an unknown token gets the same response as a valid one. The driver `logout()` calls `/auth/logout` best-effort (a network failure still clears both keys), and `cd viamitra-mobile && pnpm --filter driver test` covers both paths. `openapi.json` and both generated clients are current. `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.4p Refresh-token reuse detection revokes the whole session chain** (from T1.4o security review; priority: before pilot; approved by human 2026-10-27)
  Status 2026-10-27: done. Backend `c8f3217` on `main` (migration `0011_refresh_reuse`). Contract unchanged; no client regen.
  Files: `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/app/models/*` (refresh session columns only), `viamitra-backend/backend/alembic/versions/*_refresh_reuse.py` (next free revision), `viamitra-backend/backend/tests/test_auth_flow.py`, `viamitra-backend/openapi.json`, `viamitra-mobile/packages/api-client/src/schema.d.ts` and `viamitra-web/packages/api-client/src/schema.d.ts` (only if the contract changes), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4o (backend part), ADR-017 added to `docs/DECISIONS.md` by the human
  ADR-017 draft (human adds to DECISIONS.md): `| ADR-017 | Refresh tokens form a chain per login (family_id). Presenting a refresh token that was already rotated away revokes every session in its chain and is audited; the caller still gets the same 401. A token revoked by logout does not trigger this, and a short grace window (≤10 s) tolerates a client retrying the same token after a network failure. /auth/logout stays single-session. | Reuse of a rotated token is the standard sign of a stolen token (OAuth 2.0 Security BCP); without this, whoever refreshes first keeps the live chain |`
  Rule: propose the exact grace window, the audit record (no token, phone or child PII in it), and how a retry inside the window is answered before implementing. Existing rows get a `family_id` backfill in the migration.
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_auth_flow.py -k reuse` proves that after A→B rotation, presenting A again (outside the grace window) gets 401 and B then also gets 401; another login's chain for the same user still refreshes; a token revoked by `/auth/logout` and presented again revokes nothing else; the 401 body is identical to an unknown token's; and the event is audited. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4q Per-token rate limits for `/auth/refresh` and `/auth/logout`** (from T1.4o mobile security review; priority: before pilot; approved by human 2026-10-27)
  Files: `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/alembic/versions/*_auth_rate_keys.py` (only if the rate-limit SQL function must change; next free revision), `viamitra-backend/backend/tests/test_auth_flow.py`, `viamitra-backend/openapi.json` (only if the contract changes), `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4o
  Why: `_enforce_rate_limit` (`app/api/auth.py:165`) keys every bucket on `request.client.host` only. On mobile carrier CGNAT many drivers share one IP, so one busy IP can 429 everyone's refresh/logout. The driver app ignores a 429 at logout, which leaves that refresh session live until it expires.
  Rule: refresh and logout get a bucket keyed on the hash of the presented refresh token (never the raw token), so each device/session has its own limit. A looser per-IP bucket stays as a flood guard. A 429 must look the same whether or not the token is valid (no probing). Propose the exact limits/windows and whether the per-IP bucket is kept for logout before implementing. Proxy-aware client IP (`--proxy-headers`/`--forwarded-allow-ips`) stays out of scope until the deploy topology is known.
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_auth_flow.py -k rate` proves that two different refresh tokens from the same IP each get their own refresh and logout budget, one token exceeding its budget gets 429 while another token from the same IP still succeeds, the per-IP flood guard still trips, and an unknown token's 429 matches a valid token's. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4r `auth_audit_events` table** (from the T1.4p proposal; prerequisite for any `/admin` audit view; approved by human 2026-10-27)
  Files: `viamitra-backend/backend/app/models/*` (the new table only), `viamitra-backend/backend/alembic/versions/*_auth_audit_events.py` (next free revision), `viamitra-backend/backend/app/api/auth*`, `viamitra-backend/backend/tests/test_auth_flow.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4p
  Why: since T1.4p, a refresh-token reuse is recorded only as `refresh_sessions.reuse_detected_at` / `revoked_reason='reuse'` plus one `refresh_token_reuse` WARNING log line. There's no queryable audit trail for an admin view, and those columns go away if session rows are ever purged.
  Rule: a tenant-scoped table (`org_id` + RLS) with an event type, the time, and ids only (`user_id`, `family_id`, sessions revoked). No token, hash, phone, IP or child PII. `auth_rotate_refresh_token` writes the reuse event in the same transaction. Propose the columns, which other auth events to record, and the retention before implementing.
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_auth_flow.py -k audit` proves a refresh-token reuse writes exactly one event row in the caller's org that holds no token, hash or phone, and another org's runtime role can't read it. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.4s Notify org admins on `refresh_token_reuse`** (from the T1.4p review; priority: low, after the admin dashboard exists; approved by human 2026-10-27)
  Files: to be scoped when picked up (expected: `viamitra-backend/backend/app/workers/notify*`, `viamitra-web/apps/dashboard/**`)
  Depends: T1.4r, T1.8
  Rule: org admins are told that a driver's or parent's session chain was revoked for suspected token theft. The message holds no token, phone or child PII. Propose the channel (dashboard notice and/or push) before implementing.
  Done-when: to be defined when scoped.
- [ ] **T1.4t Logout racing an in-window refresh retry leaves the new token live** (from the T1.4p task-verifier; priority: low; approved by human 2026-10-27)
  Files: `viamitra-backend/backend/alembic/versions/*_logout_retry_race.py` (next free revision), `viamitra-backend/backend/tests/test_auth_flow.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.4p
  Why: a refresh rotates A to B. The client then sends `/auth/logout` with B while a retry of A is still in the 10 s grace window. If the retry rotates B to C first, the logout waits on B's row lock, finds B already rotated, and answers 204. C stays live until it is used or expires (30 days), although the user logged out.
  Rule: `auth_revoke_refresh_token` takes the same family root lock as `auth_rotate_refresh_token`. If the presented token was rotated by an in-window retry, the logout also revokes the live successor it led to (single chain only, never the whole family, per ADR-017). The response stays 204 for every input. Propose the exact rule before implementing.
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_auth_flow.py -k logout` proves, with two connections, that a logout of B racing a retry of A leaves no live session in that family, and that another login's session is untouched. `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.5 WebSocket live position** — Files: `viamitra-backend/backend/app/api/ws*`, tests · Depends: T1.4
  Status 2026-10-27: done. Backend `aa8d724` on `main`. Contract unchanged (WebSocket routes are not in OpenAPI); no client regen.
  Scope extended (approved by human 2026-10-27): `viamitra-backend/backend/app/services/live*.py`, `viamitra-backend/backend/app/main.py`, `viamitra-backend/backend/app/api/auth.py` (`AccessClaims.expires_at` only), `viamitra-backend/backend/pyproject.toml` + `uv.lock` (`websockets==17.3`), `viamitra-backend/backend/tests/test_ws_live.py`, `viamitra-backend/backend/tests/test_route_auth.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Done-when: `cd viamitra-backend/backend && uv run pytest -q tests/test_ws_live.py` against real Postgres and Redis proves: no auth message within the timeout closes with 4408; a bad or expired token closes with 4401; driver and super_admin close with 4403; a token in the query string is refused. A parent gets the snapshot and live points for a trip on their child's route (consent recorded, not dated in the future) and the same `not_available` frame for another route's trip, another org's trip, a missing trip, yesterday's trip and a completed trip; a child whose consent is dated in the future, or who has no stop, gives `not_available`; the DB rejects a student without `consent_at`. An org_admin sees any of today's trips in their own org and none in another. Only an `active` trip gets a snapshot. Without re-auth the socket closes with 4401 at `exp`; a re-auth keeps it open; a re-auth as another user closes with 4403; a re-auth after the child is moved off the route sends `unsubscribed` / `access_revoked`. Two app instances, each with its own hub, both deliver one PUBLISH, and the last socket leaving drops the Redis subscription. A user's 6th concurrent connection on one process closes with 4429. `./scripts/verify.sh` passes with 0 skipped.
- [x] **T1.5a `GET /parent/trips/today`** (from T1.5: a parent needs trip ids to subscribe; before T1.6; approved by human 2026-10-27)
  Status 2026-10-27: done. Backend `15d339c`, mobile `5138967`, web `35d6122` on `main`. Response fields (approved by human): `service_date`; per trip `id`, `status`, `started_at`, `route_id`, `route_name`, `shift`, `bus_reg_no`, `student_ids`.
  Files: `viamitra-backend/backend/app/api/parent*`, `viamitra-backend/backend/app/services/live*.py` or `app/services/trips.py` (shared access rule), `viamitra-backend/backend/app/schemas/*`, `viamitra-backend/backend/app/main.py` (include router), tests, `viamitra-backend/openapi.json`, both generated `api-client/src/schema.d.ts`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.5
  Rule: `require_role("parent")`, org-scoped through the tenant session. Lists today's (ADR-013) trips on the routes of the caller's own children whose consent is recorded, using the same rule as the WebSocket subscribe check (one shared query, not a copy). No child PII beyond what the parent already owns; propose the response fields before implementing. Trip ids are not added to the WS `ready` frame.
  Done-when: `uv run pytest -q tests/test_parent_trips.py` proves a parent sees exactly the trips the WS would let them subscribe to (own child's route, today, consent recorded), nothing from another route, org or day, and that other roles get 403. `openapi.json` and both clients are current. `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.5b Trip status frames on the WebSocket** (from T1.5: subscribers only learn a trip ended at their next re-auth; before T1.6; approved by human 2026-10-27)
  Files: to be scoped when picked up (expected: the code that starts/ends trips, `viamitra-backend/backend/app/services/live*.py`, `viamitra-backend/backend/app/api/ws*`, tests)
  Depends: T1.5
  Rule: when a trip starts or ends, publish its status on `trip:{id}:status`; the WS hub forwards it to that trip's watchers as a `trip_status` frame and, on end, drops the subscription. Propose the payload and who publishes before implementing.
  Done-when: to be defined when scoped.
- [ ] **T1.5c Cross-instance WebSocket connection cap per user** (from T1.5; priority: low; approved by human 2026-10-27)
  Files: to be scoped when picked up (expected: `viamitra-backend/backend/app/services/live*.py`, `viamitra-backend/backend/app/api/ws*`, tests)
  Depends: T1.5
  Why: T1.5 caps each user at 5 concurrent connections per API process, so N instances allow 5×N.
  Rule: a Redis-backed count with expiry so a crashed instance cannot leak slots. Propose the key scheme and limit before implementing.
  Done-when: to be defined when scoped.
- [ ] **T1.5d API hardening: hidden SQL parameters, no query strings in logs, WS re-auth rate** (from the T1.5 security review L3/L4/L6; priority: before pilot; approved by human 2026-10-27)
  Files: `viamitra-backend/backend/app/services/db.py`, `viamitra-backend/backend/app/services/logging*.py` (new; the log filter), `viamitra-backend/backend/app/main.py` (install the filter), `viamitra-backend/backend/app/api/ws*`, `viamitra-backend/backend/tests/test_db_errors.py` (new), `viamitra-backend/backend/tests/test_log_redaction.py` (new), `viamitra-backend/backend/tests/test_ws_live.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
  Depends: T1.5
  Why:
  - (a) A SQLAlchemy error message includes `[parameters: …]`, so ids leak into tracebacks and logs.
  - (b) uvicorn logs the full path with its query string, so a token a client wrongly puts in a URL lands in the server logs even though `/ws/live` refuses it. HTTP requests are logged on `uvicorn.access`. WebSocket handshakes are logged on `uvicorn.error` (`uvicorn/protocols/websockets/websockets_sansio_impl.py:440-482`, via `get_path_with_query_string`).
  - (c) Re-auth runs one access query each time, and nothing limits how often a client sends it.
  Rule:
  - (a) `create_async_engine(..., hide_parameters=True)` in `services/db.py`.
  - (b) A `logging.Filter` that removes everything from `?` onward in the request path of records on both the `uvicorn.access` and `uvicorn.error` loggers. It is installed by the app itself, so it holds however uvicorn is started (T0.8 or locally). It never drops a record; it only rewrites the path argument. Propose how the path argument is identified in each logger's record before implementing.
  - (c) On a socket, a re-auth within 30 s of the previous successful auth closes with 4429. The first auth and a re-auth 30 s or more later are accepted. The 30 s value is a module constant so tests can lower it.
  Done-when:
  - `cd viamitra-backend/backend && uv run pytest -q tests/test_db_errors.py tests/test_log_redaction.py tests/test_ws_live.py -k "hide_parameters or redact or reauth_rate"` proves:
    - (a) a failing query's `SQLAlchemyError` text does not contain the bound value;
    - (b) with `caplog`, a real uvicorn server leaves no query string and no `token=` value in any captured record: neither from `GET /health?token=secret-value`, nor from a refused `/ws/live?token=secret-value` handshake. The records still name the path.
    - (c) a second auth within the window closes with 4429, and one after the (lowered) window keeps the socket open.
  - `./scripts/verify.sh` passes with 0 skipped.
- [ ] **T1.6 Parent live map + ETA** — Files: `viamitra-mobile/apps/parent/**` · Depends: T1.5
- [ ] **T1.7 Geofence events + push** — Files: `viamitra-backend/backend/app/services/events/**`, `viamitra-backend/backend/app/workers/notify*`, tests with GPS fixtures · Depends: T1.4
- [ ] **T1.8 Dashboard: orgs, buses, routes, stops, students CRUD** — Files: `viamitra-web/apps/dashboard/**` · Depends: T1.2
- [ ] **T1.9 Dashboard live fleet map** — Files: `viamitra-web/apps/dashboard/app/(org)/live/**` · Depends: T1.5, T1.8
- [ ] **T1.10 Pickup/drop marking + SOS** — Files: `viamitra-mobile/apps/driver/**`, `viamitra-backend/backend/app/api/trips*` · Depends: T1.3, T1.7

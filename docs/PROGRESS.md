# Progress log
## 2026-10-26 — T1.3a Backend `GET /trips/today` for drivers — done, committed, not pushed
- Committed on each repo's `main` (fast-forward merge; task branches deleted):
  - viamitra-backend `250316c`
  - viamitra-mobile `d6c343e`
  - viamitra-web `24cb348`
- ADR-013 applied: "today" is the Asia/Kolkata date; timestamps stay UTC.
- Changed (viamitra-backend):
  - `backend/alembic/versions/0009_trip_service_date.py` (new). Adds `trips.service_date date NOT NULL` and an index on `(org_id, driver_id, service_date)`.
    - Existing rows get the IST day they started, or the migration day if they never started.
    - The default is used only for that backfill and then dropped (human decision), so every new trip must name its day.
    - Note: the UPDATE only reaches rows if the migrating owner bypasses RLS (a superuser does). Otherwise the migration-day fill stands.
  - `backend/app/models/entities.py`: `Trip.service_date` (no default) and the index.
  - `backend/app/services/trips.py` (new):
    - `service_date_at()` gets the IST date from Postgres (`timezone('Asia/Kolkata', $1)::date`), so the API doesn't depend on host tz data.
    - `list_driver_trips_today()` filters by the token's `org_id`, `driver_id` and today, joins route and bus on `org_id`, and puts the morning shift first.
  - `backend/app/schemas/trips.py` (new; `app/schemas` has no `__init__.py`, so it's a namespace package): `DriverTrip` has trip id, status, start/end, route id/name/shift and bus id/reg_no. No child data.
  - `backend/app/api/trips.py` (new): `GET /trips/today` with `require_role("driver")` + `get_tenant_session`.
  - `backend/app/main.py`: router include only.
  - `openapi.json`: re-exported.
- Tests: `backend/tests/test_trips_today.py` (new, 10 tests, real test DB). They cover:
  - own trips only: yesterday, tomorrow, another driver in the same org, and org B are all absent;
  - exact response shape and order;
  - spoofed `org_id`/`driver_id`/`service_date` query values and an `X-Org-Id` header change nothing;
  - a token whose org claim is wrong gets `[]`;
  - an RLS-only case: the service's filter points at org B while the tenant session is org A, which returns `[]` (with a control, and a check that the role has neither `rolsuper` nor `rolbypassrls`);
  - an empty list for a driver with no trip;
  - 403 for parent, org_admin and super_admin;
  - 401 for missing, malformed, wrong-secret, tampered, `alg:none` and expired tokens;
  - the route has no request params and reaches the DB only via `get_tenant_session`;
  - the IST boundary at 18:29:59 vs 18:30 UTC;
  - `service_date` is NOT NULL with no default.
  - Also changed: `backend/tests/test_ingest_db.py`, whose trip insert now sets `service_date` (Files widened by human).
- viamitra-mobile and viamitra-web: `packages/api-client/src/schema.d.ts` regenerated. A second `pnpm gen:api` run gave identical output.
- Migrations: both dev and test DBs are at `0009_trip_service_date (head)`. The human ran the downgrade to 0008 once to replace an earlier draft of 0009 that kept the default, then `dev-setup.sh` re-applied it.
- Reviews:
  - `task-verifier`: READY, no FAIL.
  - `security-reviewer`: no Critical or High.
    - Fixed: permanent default (Medium; now backfill-only); no RLS-only proof (Medium; test added).
    - Logged, accepted by human: a revoked or re-roled driver keeps access until the access token expires (≤15 min, within the JWT rule).
    - Logged: T1.4e's migration number clash, resolved below.
    - Logged as the new task T1.4m: ingest doesn't check `service_date`.
- Verify: `./scripts/verify.sh` passes for all three repos. Backend 77 passed, 0 skipped (was 67).
- `docs/TASKS.md`:
  - T1.3a ticked; its Files gained `tests/test_ingest_db.py`.
  - T1.4e renumbered to `0010_*` with `down_revision = "0009_trip_service_date"`.
  - New T1.4m (before pilot): ingest rejects points for trips whose `service_date` isn't today in IST, and stale active trips are auto-closed. The mechanism and DB role are proposed first, since Celery isn't installed.
- Next: T1.4l (docs routes only in dev), as the human decided. T1.3b (driver scaffold) can start in parallel.
- Open questions:
  - T1.4m: how the auto-close is scheduled (new dependency?) and which role performs the UPDATE.
  - T1.4m's migration must come after T1.4e's `0010` (or both renumbered), whichever lands first.
## 2026-10-26 — T1.3 Route-guard test (Done-when only) — done, committed, not pushed
- Committed as `cb4e033` on viamitra-backend `main` (fast-forward merge; the task branch is deleted).
- Scope (human decision this session): only T1.3's Done-when, the route-guard test. The driver work in the title ("Driver login + today's trip") is NOT done. `viamitra-mobile/apps/driver` doesn't exist yet (T0.5 is blocked), and there's no trips endpoint (that needs `backend/app/api/trips*`, outside T1.3's Files). T1.3 is ticked because its Done-when is met; the driver work needs its own task (see open questions).
- Changed (viamitra-backend): `backend/tests/test_route_auth.py` (new, 14 tests). No app code changed.
  - `route_auth_problems(app)` walks every route via `fastapi.routing.iter_route_contexts`, including included routers with their prefixes and include-level dependencies. A route passes only if:
    - every one of its methods is on `PUBLIC_ROUTES`, keyed by `(path, method)` and pinned to the expected handler (`module.qualname`); or
    - its dependency tree (nested, router-level, include-level) contains a `require_role` checker, matched by the closure's shared `__code__`.
  - The check also reports:
    - `frontend()` groups without a guard (read from FastAPI 0.162's private `_low_priority_routes` / `effective_low_priority_routes()`, with a comment saying why);
    - any `dependency_overrides`;
    - any middleware;
    - Mounts and other routes that have no dependant.
  - `stale_public_routes` fails on any allowlisted `(path, method)` pair that no route serves.
  - It runs on `app.main.app` both at import time and inside the real lifespan, with `APP_ENV=prod` and `dev`, against `TEST_DATABASE_URL`. This catches routes registered at startup.
  - Probe cases:
    - an unguarded route added to `app.main.app` makes the check fail (the Done-when case);
    - a route with a token but no role check is flagged;
    - direct, nested and router-level guards pass;
    - an extra method, or a different handler, on a public path is flagged;
    - a Mount is flagged;
    - frontend groups: guarded passes, unguarded is flagged;
    - an override or middleware is reported;
    - stale allowlist pairs are reported.
- Reviews:
  - `task-verifier`: READY, no FAIL. Its one gap, frontend routes, is fixed.
  - `security-reviewer`: no critical findings. Fixed: frontend routes (High), overrides (Medium), routes added at startup (Medium), middleware (Medium), handler pinning plus stale check by `(path, method)` pairs (Low), probe-route leak on a failed assert (Low).
  - Not fixed, outside Files: docs routes are public in prod (Low; see open questions).
  - Scope note: the test proves that some role is required, not that it's the right role, and it doesn't cover org or child-link (IDOR) scoping. Per-router tests still have to cover those.
- Verify: `./scripts/verify.sh` passes for all three repos. Backend 67 passed, 0 skipped (was 53).
- Next: T1.3a (`GET /trips/today`), then T1.4l (docs routes only in dev).
- Human decisions (2026-10-26):
  - The driver work is split into T1.3a (backend `GET /trips/today`), T1.3b (Expo driver scaffold; every dependency proposed with a verified version and approved first), T1.3c (OTP login with tokens in `expo-secure-store`) and T1.3d (today's-trip screen).
  - Docs routes become dev-only as T1.4l, done right after T1.3a.
  - All of these are added to `docs/TASKS.md`.
- Open question: T1.3a needs a `service_date` column on `trips` (none exists today) and a decision on which timezone defines "today" (no ADR yet; Asia/Kolkata is the likely proposal).

## 2026-10-26 — T1.4j Role-based access dependency — done, committed, not pushed
- `/next-task T1.4` asked for T1.4, which was already `[x]`. The human chose T1.4j instead.
- Committed as `4a8de75` on viamitra-backend `main` (fast-forward merge; the task branch is deleted).
- Changed (viamitra-backend):
  - `backend/app/api/deps.py`: new `require_role(*roles)`. It builds on `get_access_claims`, so a missing or invalid token still gets 401 with `WWW-Authenticate: Bearer`. A verified token whose role isn't allowed gets 403. An empty role list, or a name not in `USER_ROLES`, raises `ValueError` when the route is defined.
  - `backend/tests/test_roles.py` (new, 9 tests): one probe route per role on `app.main.app`.
    - Each role gets 200 on its own route and 403 on the others, and handlers behind a 403 never run.
    - On a guarded route, these all get 401 and the handler never runs: no token, garbage, a bad signature, a signed token with an unknown role, and an expired token.
    - Also covered: a route that allows several roles, and rejection of unknown or empty role names.
- Reviews:
  - `task-verifier`: READY, all checks PASS.
  - `security-reviewer`: no critical, high or medium findings. Its three low test-gap findings are fixed (unknown-role and expired tokens through HTTP, a route-identity assert, handler-not-run checks).
- Verify: `./scripts/verify.sh` passes for all three repos. Backend 53 passed, 0 skipped (was 44).
- Next: the human commits and pushes, then T1.3 (its dependencies T1.2 and T1.4j are now done) or T0.6.
- Human decision (2026-10-26): the route-guard test from the security review is now part of T1.3's Done-when: `tests/test_route_auth.py` fails on any route that isn't on the public allowlist and has no `require_role`. T1.3's Files now include `viamitra-backend/backend/tests/test_route_auth*`.
## 2026-10-26 — Re-verified the three-repo split after the human re-baselined the protected files (no task ID) — done, not pushed
- No code changed. Checked again:
  - Each repo has one identity, `Shashant <24953709+Shashant28@users.noreply.github.com>` (the id matches api.github.com/users/Shashant28).
  - `security-reviewer.md` paths are updated.
  - `infra/local.env` is ignored (`.gitignore:10`).
  - No Claude or Anthropic text in files or commit messages.
  - No tracked `.pem`, `.p8` or `.p12` files.
  - Remotes are set.
- Verify:
  - `dev-setup.sh` exit 0; DBs at `0008_auth_lookup_minimal (head)`.
  - `./scripts/verify.sh`: all three PASS; backend 44 passed / 0 skipped.
- Not run by the agent: the `git ls-files | grep` check for env-file names. `guard-bash.sh` blocks any command that contains `.env`, so the human runs it.
- Next: the human pushes, then T0.6 or T1.4j.
## 2026-10-26 — Split the monorepo into three git repos (human-requested restructure, no task ID) — done, not pushed
- **Action for anyone working locally:** the workspace root is no longer a git repo. Branch and commit inside `viamitra-backend`, `viamitra-mobile` or `viamitra-web`. Run `bash viamitra-backend/scripts/dev-setup.sh` for local infra. Run `./scripts/verify.sh` for all checks, or `bash scripts/check.sh` inside one repo.
- Changed:
  - Created `main` at `e9cf0c0` (it never existed; history was linear). Backup at `../viamitra-backup-20261026`. The old monorepo `.git` is at `../viamitra-old-git`, with every task branch kept. The old root copies (backend, infra, packages, root JS files, venv, node_modules) are in `../viamitra-old-monorepo-files`.
  - Each repo was built from a fresh clone with `git filter-repo` (2.47.0, Homebrew), keeping the history of its own files only. `Co-Authored-By: Claude…` and `Claude-Session:` lines were stripped from commit messages.
    - `viamitra-backend`: 13 commits. `backend/`, `infra/`, `scripts/dev-setup.sh`, `.env.example`, and `openapi.json` (moved from `packages/api-client/`).
    - `viamitra-mobile` / `viamitra-web`: 4 commits each. pnpm workspace files, `packages/api-client` (TS only), `packages/config`. No app code exists yet, and `turbo.json` was dropped as unused.
  - API contract:
    - `viamitra-backend/backend/scripts/export_openapi.py` writes `openapi.json`; with `--check` it fails if the file is stale.
    - New `backend/tests/test_openapi_contract.py` also fails when it is stale.
    - The JS repos' `pnpm gen:api` reads `../viamitra-backend/openapi.json` (override with `OPENAPI_PATH`) and produces no diff.
  - Each repo has `scripts/check.sh`, a `.gitignore` and a README. Backend `check.sh` fails on skipped tests when `CHECK_NO_SKIPS=1`.
  - The workspace `scripts/verify.sh`, `.claude/settings.json` and `.claude/protected-paths.txt` were replaced from `_proposed/` by the human. `CLAUDE.md` and the `.claude/rules/*.md` paths were updated. `docs/TASKS.md` paths now point into the repos, and T0.6 CI now runs one workflow per repo.
  - Attribution off: `~/.claude/settings.json` sets `attribution` to `{"commit": "", "pr": "", "sessionUrl": false}`, and each repo has a local (uncommitted) `.git/hooks/commit-msg` that deletes those trailers.
  - Remotes: `origin` = `https://github.com/Shashant28/viamitra-{backend,mobile,web}.git`. Nothing pushed.
  - Commit identity:
    - Every commit's author and committer in all three repos was rewritten to `Shashant <24953709+Shashant28@users.noreply.github.com>` (GitHub id from the public API) with `git filter-repo --force`.
    - The same identity is set in global git config and in each repo.
    - Pre-rewrite bundles are in the session scratchpad.
  - `.claude/agents/security-reviewer.md`: the paths in its description now point into the repos, and it reviews the diff per repo (the workspace root is not a repo).
  - The Stop hook flagged the protected files. The human replaced `.claude/settings.json`, `.claude/protected-paths.txt` and `scripts/verify.sh`. The three `scripts/check.sh` files were written before they became protected. Nothing was restored.
- Verify:
  - `bash viamitra-backend/scripts/dev-setup.sh` OK; dev and test DBs at `0008_auth_lookup_minimal (head)`; EMQX accounts kept.
  - `./scripts/verify.sh`: PASS for all three repos. Backend: ruff, mypy, 44 passed / 0 skipped, OpenAPI current, pip-audit. Mobile and web: typecheck, lint, tests, audit.
  - `git log --format=%B | grep -i claude` and `git grep -i -e claude -e anthropic` print nothing in all three repos.
- Next: the human pushes the three repos. Then T0.6 (CI per repo) or T1.4j.
- Open questions:
  1. JS lint and tests are no-ops, because no package defines those scripts yet. Adding eslint needs a dependency approval.
  2. `.claude/hooks/lib.sh` (protected) still prunes `./apps/*/android/build`, which no longer matches the nested paths. Only the protected-file scan is slower.
  3. `_proposed/` can be deleted now that it is applied.

## 2026-10-25 — T1.4h Verified-token tenant dependency + fail-fast startup checks — done
- **Action for anyone running the API locally:** run `bash scripts/dev-setup.sh` once to apply migration `0008_auth_lookup_minimal` (done on this machine; dev and test DBs at head). The API now refuses to start unless `AUTH_TOKEN_SECRET` and a valid `RUNTIME_DATABASE_URL` are set, and refuses `DATABASE_URL` unless `APP_ENV=dev`.
- Changed:
  - `api/auth.py`: `verify_access_token()` returns `AccessClaims`. It checks the signature first (constant-time, on the canonical base64url string), then requires the exact `{"alg":"HS256","typ":"JWT"}` header, int `iat`/`exp` with lifetime ≤ `ACCESS_TOKEN_TTL` and `iat` ≤ now+60 s, an unexpired `exp`, a known role and UUID `sub`/`org_id`. `ensure_signing_secret()` is for startup. `_find_user` reads only `user_id, org_id`; `verify_otp` reads `role` from `users` under RLS after the tenant is set.
  - New `api/deps.py`: `get_access_claims` (HTTPBearer, `auto_error=False`) maps a missing or invalid token to 401. `get_tenant_session` sets `app.org_id` from the verified claim only, transaction-local, via a SQLAlchemy `after_begin` listener (signature verified at `sqlalchemy/orm/events.py:2012`), so the setting is re-applied after every commit. It raises if the session already has an open transaction.
  - `services/db.py`: `database_lifespan()` refuses `DATABASE_URL` unless `APP_ENV=dev` (unset or unknown counts as prod), opens one connection so the RLS-escape check runs at startup, and disposes the engine on shutdown.
  - `main.py`: `FastAPI(lifespan=...)` checks the signing secret, then runs `database_lifespan`.
  - Migration `0008_auth_lookup_minimal`: recreates the SECURITY DEFINER `auth_lookup_user` returning `(user_id uuid, org_id uuid)` with the same owner and grants. Downgrade restores `role`.
- Tests:
  - `test_api_db_role.py`:
    - Startup is refused for `APP_ENV` = prod, unset and "production" when `DATABASE_URL` is set, and when `AUTH_TOKEN_SECRET` is missing.
    - Prod starts with the runtime role only and `/health` returns 200.
    - The superuser, BYPASSRLS-member and table-owner roles now fail at startup, as well as per request.
    - The org A/B test runs on `app.main.app` with the real `get_access_claims`/`get_tenant_session` on a temporary probe route. It covers org A's read, a commit inside the handler, and a cross-org UPDATE, which updates 0 rows. Forged tokens get 401: wrong secret, swapped payload, alg none, expired, garbage, and a missing header. A validly signed org B token cannot reach org A.
  - `test_auth_flow.py`:
    - A token unit test covers the round trip, a tampered or padded signature, a truncated token, expiry, an unknown role, a far-future `exp`, a missing `iat`, and a rotated secret.
    - `auth_lookup_user` returns exactly `["user_id","org_id"]` (and `pg_get_function_result`) for two orgs, as the runtime role.
    - The token issued by the flow carries `role=parent`, read under RLS.
- Files: `backend/app/main.py`, `backend/app/api/auth.py`, `backend/app/api/deps.py` (new), `backend/app/services/db.py`, `backend/alembic/versions/0008_auth_lookup_minimal.py` (new), `backend/tests/test_api_db_role.py`, `backend/tests/test_auth_flow.py`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → all PASS, 43 passed, 0 skipped. No OpenAPI or response-schema change (no new routes), so no `pnpm gen:api` was needed.
- Reviews:
  - task-verifier: all Done-when PASS, scope PASS.
  - security-reviewer: no critical or high findings. Fixed here: M1 (prod guard failed open for unset or unknown `APP_ENV`), L1 (secret not checked at startup), L3 (`iat` and lifetime not checked), and a loose test `match`.
  - Not fixed, proposed follow-ups:
    - L2: one HMAC key is used for access tokens, OTP hashes and rate-limit keys. Derive per-purpose keys. Not exploitable today.
    - L4: no role-gating dependency yet. Add `require_role(...)` before the first tenant router uses `get_tenant_session`.
- Open questions:
  1. **Migration chain:** 0008 revises 0006 because T1.4e's 0007 doesn't exist yet. T1.4e should set its 0007 `down_revision = "0008_auth_lookup_minimal"`; otherwise Alembic gets two heads. A non-sequential order is harmless.
  2. `tests/test_health.py` (outside Files, unchanged) now runs the lifespan, so it needs a reachable runtime DB and `AUTH_TOKEN_SECRET`. It passes under verify (env from `infra/local.env`), but would fail in a DB-less CI. Should it move to a lifespan-free check or get a DB fixture? That needs a task.
- Next: T1.4b (per-device rate limit), or T1.4i.
## 2026-10-25 — T1.4g API connects as the restricted runtime role — done
- **Action for anyone running the API locally:** re-run `bash scripts/dev-setup.sh` once; it adds `RUNTIME_DATABASE_URL` (done on this machine). The API no longer reads `DATABASE_URL`; that stays the owner role for Alembic only.
- Changed: new `backend/app/services/db.py` owns the API engine/session (moved out of `api/auth.py`). It reads only `RUNTIME_DATABASE_URL` and registers a SQLAlchemy `connect` event (`AdaptedConnection.run_async`, verified at `sqlalchemy/engine/interfaces.py:3632`) that refuses every new pooled connection whose role is superuser, BYPASSRLS or CREATEROLE, is a member of (or can SET ROLE to) such a role, owns/inherits ownership of any `public` table, or has CREATE on `public`. Applies in dev, tests and prod (no separate prod config exists yet). `.env.example` documents both URLs.
- Tests (`backend/tests/test_api_db_role.py`): API does not fall back to `DATABASE_URL`; API session role is `viamitra_runtime` with `rolsuper`/`rolbypassrls` false; real `/auth/otp/send` raises for the superuser, for a login role granted `viamitra_auth_owner`, and for a role owning a table; org A user logs in via real `/auth/otp/send` + `/auth/otp/verify`, and its token's org drives a test-only read route on the real `get_db_session` that queries `buses`/`users`/`organizations` with no org filter → only org A rows, cross-tenant UPDATE affects 0 rows. `test_auth_flow.py` now sets `RUNTIME_DATABASE_URL`.
- Files: `backend/app/services/db.py` (new), `backend/app/api/auth.py`, `backend/tests/test_api_db_role.py` (new), `backend/tests/test_auth_flow.py`, `scripts/dev-setup.sh`, `.env.example`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `bash scripts/dev-setup.sh` → "Added to infra/local.env: RUNTIME_DATABASE_URL", both DBs at `0006_ingest_role (head)`. `./scripts/verify.sh` → all PASS, 36 passed, 0 skipped. Test DB has 0 leftover `t14g_*` roles/tables.
- Reviews: task-verifier → all Done-when PASS; noted the org A/B test proves RLS behind the real DB dependency but not a production token→tenant path (none exists yet). security-reviewer (T1.4g) → no critical/high; M1 (guard missed inherited BYPASSRLS / ownership) and L1 (guard tied to engine identity, not per connection) fixed here; L2 (lazy check, `/health` stays green) → T1.4h; L3 (owner + runtime URLs in the same local.env) and L4 (`auth_lookup_user` SECURITY DEFINER is a cross-tenant lookup by phone, pre-existing) noted, not fixed. security-reviewer (T1.4c, commit 99418cc) → no critical/high; 3 medium (unescaped passwords in psql SQL can reach Postgres error logs; EMQX bootstrap CSV left behind if the script dies; EMQX passwords never re-synced after local.env changes) + 5 low → proposed T1.4i.
- Limitation: the guard hook blocks sourcing `infra/local.env` ad hoc, so the dev-DB role was not checked separately; `dev-setup.sh` writes it with `viamitra_runtime`, and the connect check refuses anything else.
- Next: T1.4b (per-device rate limit), unless the human prioritises T1.4h/T1.4i.
- Human decisions (2026-10-25): T1.4h and T1.4i approved. T1.4h also covers: `auth_lookup_user` returns the minimum needed for login (with test), and with `APP_ENV=prod` the API refuses to start if `DATABASE_URL` is set. T1.4h Files now include `api/auth*`, `test_auth_flow.py` and a new migration (number after T1.4e's 0007).

## 2026-10-25 — T1.4c Persistent EMQX provisioning + dev setup script — done
- **After a reboot (or any time), just run `bash scripts/dev-setup.sh`.** It starts colima if needed, fills missing values in `infra/local.env` (prints names only), brings all services up healthy, provisions EMQX accounts if missing, syncs DB role passwords to `infra/local.env`, and migrates the dev and test DBs to head.
- Changed: EMQX now has a fixed node name (`EMQX_NODE_NAME=emqx@emqx.local`) and a named `emqx-data` volume. Before this, accounts lived in an anonymous volume under an IP-derived node name and were lost on recreate. New `scripts/dev-setup.sh` (bash 3.2, idempotent, approved by human before first run). EMQX accounts come from the built-in DB bootstrap CSV, streamed into the container, imported on restart, then deleted; a marker in the `emqx-data` volume skips re-provisioning. The dev DB is now migrated 0004 → 0006 (`alembic current` → `0006_ingest_role (head)` on dev and test).
- Files: `scripts/dev-setup.sh` (new), `infra/docker-compose.yml`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: first run added `AUTH_TOKEN_SECRET DATABASE_URL INGEST_DATABASE_URL`. `docker compose -p infra down && bash scripts/dev-setup.sh` → all containers recreated, "EMQX accounts already provisioned", both DBs at head. `docker rm -f infra-emqx-1 && bash scripts/dev-setup.sh` → new container id, accounts kept. `./scripts/verify.sh` → all PASS, 30 passed, 0 skipped. `git status --short` shows no credential files.
- Corrected Done-when (my mistake when writing T1.4c): `docker compose -f infra/docker-compose.yml up/down` fails without the password variables, because the compose file marks them required (`${VAR:?}`). Use `docker compose -p infra down` to stop, and `bash scripts/dev-setup.sh` to start. Files list now names `scripts/dev-setup.sh` (human-authorized) instead of `infra/scripts/**`.
- Note: `DATABASE_URL` is the owner role (needed by Alembic) and the API also reads it, so the API run locally would bypass RLS → T1.4g. security-reviewer was not run on T1.4c.
- Next: T1.4b (per-device rate limit).
- Questions for human: should `.env.example` list `POSTGRES_PASSWORD`, `REDIS_PASSWORD` and `TEST_ADMIN_DATABASE_URL`? (The guard blocks me from staging it.)

## 2026-10-25 — T1.4a Ingest worker exits non-zero on disconnect — done
- Changed: The worker treats any MQTT disconnect it did not start (broker kick, network loss, or its own disconnect after a 10 s queue-put stall) as fatal. It drains and flushes with timeouts, then raises so `main()` exits non-zero for a supervisor restart; the persistent session redelivers unacked messages. Auto-reconnect is disabled (`reconnect_on_failure=False`), so acks never go out on a new session. Review fixes: out-of-range timestamps (e.g. `0001-01-01T00:00:00+05:00`) raised `OverflowError` past validation and killed the consumer, causing an endless redelivery/restart loop. They are now a `ValueError` and rejected. A message that fails with a data error (`ValueError`/`TypeError`/`ArithmeticError`/`LookupError`/`AttributeError`) is logged by type only and acked. The worker exits immediately if the consumer or flush task dies. `main()` configures INFO logging; one INFO line after subscribe.
- Files: `backend/app/workers/ingest.py`, `backend/tests/test_ingest.py`, `backend/tests/test_ingest_worker_lifecycle.py` (new), `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → all PASS; pytest 30 passed, 0 skipped. Lifecycle tests: kicked subprocess exits non-zero with "EMQX connection lost" on stderr; stalled consumer raises within 10 s; data-error messages are acked and the worker keeps running and then stops cleanly on SIGTERM. Tests discard the ingest session afterwards (`emqx ctl clients show viamitra-ingest` → Not Found). task-verifier: code and Done-when PASS (its scope FAIL was the human's `verify.sh`/`.env.example` edits, since committed in `b5c0baf`). security-reviewer: HIGH (poison-message restart loop) fixed; LOW reconnect overlap fixed.
- Decisions: the catch-all suggested by the reviewer became a list of specific data-error types, because ruff BLE001 forbids `except Exception` and the rules forbid disabling lint without approval. Other exception types still end the consumer, and the worker then exits immediately. `RuntimeError` is deliberately excluded, so a failed history flush is never acked before commit.
- Not done / follow-ups: points redelivered after more than 2 min of downtime fail the freshness check and are dropped from history → T1.4f. `scripts/verify.sh` exports every local secret to all verify subprocesses (reviewer MEDIUM; human-owned file). A sustained device flood now causes repeated restarts → T1.4b.
- Next: T1.4c (committed separately).
- Questions for human: keep "exit on disconnect", or prefer in-process reconnect with resubscribe?

## 2026-10-25 — T1.4 Location ingest — done
- Changed: Restricted DB role `viamitra_ingest` via migration 0006 (INSERT on locations; column SELECT on locations conflict key, trips(id, org_id, driver_id, status), users(id, org_id, role)); 0006 also sets `viamitra_ingest`/`viamitra_runtime` passwords from env when present. Worker now uses `INGEST_DATABASE_URL`, connects with client ID = username, selects only `Trip.id`, and rejects non-canonical UUID topics. EMQX: `cinfo` authenticator denies clientid ≠ username (fixes session takeover of the ingest worker, security-review HIGH); ACL device regex now strict canonical UUIDs. Disposable `postgres-test` compose service (127.0.0.1:5433) because Postgres roles are cluster-wide and 0001's `CREATE ROLE` cannot run twice on the dev cluster. Fixed latent T0.4 bug exposed once DB tests stopped skipping: auth advisory lock passed a UUID to a text param (`backend/app/api/auth.py:208`).
- Files: `backend/alembic/versions/0006_ingest_role.py`, `backend/app/workers/ingest.py`, `backend/app/api/auth.py` (outside T1.4 list, one line), `backend/tests/test_ingest.py`, `backend/tests/test_ingest_broker.py`, `backend/tests/test_ingest_db.py`, `infra/docker-compose.yml`, `infra/emqx/acl.conf`, `infra/emqx/base.hocon`, `.env.example`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → all PASS; pytest 25 passed, 0 skipped (run with test env exported). Broker (EMQX 6.3.2, MQTT v5): own-topic QoS1 publish delivered to ingest; other-trip, bare trip_id, other-suffix, retained publishes → 0x87; QoS0 not delivered; all device subscribes → 0x87; ingest publish and `trips/#` subscribe → 0x87; wrong password and clientid ≠ username rejected. DB as `viamitra_ingest`: batch insert + duplicate redelivery OK; cross-org insert fails RLS; trips RLS-filtered; `locations.point` and `users.phone` unreadable. Migration 0006 downgrade/upgrade round-trip OK.
- Local provisioning: EMQX users `viamitra-ingest` + one test device created via built-in DB bootstrap CSV (streamed into container, imported on restart, CSV deleted). Users live in the container's EMQX data; recreating the container requires re-provisioning. Credentials generated outside the repo; human must append them to `infra/local.env` (Bash guard blocks Claude from touching that file).
- Not done: dev DB (`infra-postgres-1`) is still at 0004; run `alembic upgrade head` there with `INGEST_DB_PASSWORD`/`RUNTIME_DB_PASSWORD` exported.
- Follow-ups (security review, medium/low, not fixed): (M) on queue-put timeout the worker calls `disconnect()` and never reconnects or exits — add `on_disconnect` → stop/exit + liveness; (M) no per-device rate limit — add EMQX per-client rate limit and per-trip min interval in worker; (L) migration password could appear in server logs if statement/parameter logging is on — consider `SET LOCAL log_statement='none'` or ops-side SCRAM verifier; (L) Redis latest-position key TTL is 7 days — shorten / delete on trip end.
- Next: T1.5 WebSocket live position. Driver app (T1.3/T1.10) must connect with MQTT client ID equal to its `org.driver.trip` username.
- Questions for human: Production secret provisioning for EMQX and DB role passwords; production TLS listener; whether rate limiting belongs in T1.4 follow-up or T1.5.

## 2026-10-25 — T1.4 Location ingest — blocked pending runtime checks
- Changed: Added typed location ingestion from EMQX to Redis latest-position/pub-sub and batched Timescale history. Added trip/org/driver/status and driver-role validation under tenant RLS; strict location payload bounds; QoS 1 manual acknowledgements after history commit; persistent MQTT session; bounded/retryable batching; Redis monotonic timestamp updates and seven-day TTL; deny-by-default trip-scoped broker ACL.
- Files: `backend/app/workers/ingest.py`, `backend/tests/test_ingest.py`, `backend/pyproject.toml`, `backend/uv.lock`, `.env.example`, `infra/emqx/acl.conf`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS typecheck/lint/tests/audit, Ruff, mypy, pytest (13 passed, 2 skipped), pip-audit (no known vulnerabilities). Focused ingest tests → 8 passed. `uv lock --check` passed. Live local Redis Lua check → newer point accepted, older point rejected, stored timestamp present. `docker exec infra-emqx-1 emqx check_config` succeeded. Task-verifier confirmed code-level shutdown finding resolved; security-reviewer found no additional code-level flaw.
- Not tested: EMQX authenticated authorization behavior (the built-in `viamitra-ingest` broker user and device credentials are not provisioned in the task-scoped files); PostgreSQL ingest authorization/location insert under `viamitra_runtime` because `TEST_DATABASE_URL` is unset. EMQX config syntax validation is not a substitute for runtime ACL authorization testing.
- Next: Provision `viamitra-ingest` and test valid subscription, valid own-trip QoS 1 publish, and denied wrong-topic/retained/wrong-QoS publishes. Set `TEST_DATABASE_URL` to a migrated test database and exercise active-driver trip authorization plus location batch insert under the restricted runtime role. Then rerun `./scripts/verify.sh` and both reviewers before changing T1.4 to `[x]`.
- Questions for human: Which approved secret/config provisioning path should be used for the EMQX ingest account and production TLS listener?

---

## 2026-10-25 — T1.2 API client generation — done
- Changed: Added in-process FastAPI OpenAPI export and deterministic TypeScript schema generation with a typed `openapi-fetch` client. Pinned `openapi-typescript@7.13.0` and compatible `typescript@5.9.3`; overrode vulnerable transitive `js-yaml` to `4.3.2`.
- Files: `packages/api-client/**`, `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: Node 22.22.0 `pnpm gen:api` twice → byte-identical; strict workspace TypeScript check passed; `./scripts/verify.sh` → PASS JS checks/audit, Ruff, mypy, pytest (5 passed, 2 skipped).
- Not tested: Python dependency audit skipped (`pip-audit` not installed); PostgreSQL-backed tests remain skipped without `TEST_DATABASE_URL`.
- Next: Use `@viamitra/api-client` in T1.3.
- Questions for human: none

---

## 2026-10-25 — T1.1 OTP auth (backend) — done
- Changed: Added provider interface with fixed OTP available only in `APP_ENV=dev`; MSG91 remains a replaceable unconfigured adapter. Added OTP send/verify, account and client rate limits, hashed challenges/refresh tokens, short-lived access JWTs, atomic refresh rotation, tenant RLS migration, and phone-enumeration-resistant send responses.
- Files: `backend/app/api/auth.py`, `backend/app/services/auth.py`, `backend/app/models/**`, `backend/alembic/versions/0005_otp_auth.py`, `backend/tests/test_auth_*.py`, `.env.example`, `infra/local.env`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS checks/audit, Ruff, mypy, pytest (5 passed, 2 skipped); offline Alembic upgrade SQL generated; security-reviewer → no blocking findings. `pip-audit` skipped (not installed).
- Not tested: PostgreSQL-backed auth/RLS integration because `TEST_DATABASE_URL` is unset; actual MSG91 delivery is intentionally not implemented; live migration upgrade/downgrade not run.
- Next: Configure `AUTH_TOKEN_SECRET` and `DATABASE_URL`; run migrated PostgreSQL integration tests. Implement MSG91 sender before production OTP rollout.
- Questions for human: none

---

## 2026-10-25 — T0.4 DB schema v1 + RLS — done
- Changed: User approved `sqlalchemy==2.1.6`, `alembic==1.20.1`, `asyncpg==0.32.0`, and scope updates. Added the initial tenant schema, RLS policies, a separate restricted runtime role, retention accounting for hourly chunks/scheduler cadence, and tenant-isolation read/write coverage.
- Files: `backend/app/models/**`, `backend/alembic/**`, `backend/alembic.ini`, `backend/tests/test_rls.py`, `backend/pyproject.toml`, `backend/uv.lock`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: Four Alembic revisions applied to local Postgres; live `TEST_DATABASE_URL` RLS read/write test as `viamitra_runtime` → 1 passed; hourly chunks and 6d22h30m retention cutoff verified; upgrade/downgrade SQL generation passed; `./scripts/verify.sh` → PASS JS checks/audit, Ruff, mypy, pytest (1 passed, 1 DB test skipped without URL); transient `uv run --with pip-audit pip-audit` → no known vulnerabilities.
- Not tested: Seven-day expiry over elapsed time or during a Timescale scheduler outage; deployment-time runtime-role password provisioning; live destructive downgrade.
- Next: Configure the production secret manager with a password for the non-superuser `viamitra_runtime`; ensure request transactions set `app.org_id` from verified token claims.
- Questions for human: none

---

## 2026-10-25 — T0.3 Local infra — done
- Changed: Installed Homebrew Docker CLI, Docker Compose, and Colima; started Colima (2 CPU, 4 GiB, aarch64); switched Postgres to the verified pinned TimescaleDB HA image; created local-only secrets in `infra/local.env`; confirmed PostGIS and TimescaleDB are enabled.
- Files: `infra/docker-compose.yml`, `infra/local.env`, `.gitignore`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: Docker 29.9.2, Compose 5.6.1, `hello-world` passed; Postgres, Redis, and EMQX healthy; `\\dx` lists PostGIS 3.6.4 and TimescaleDB 2.31.0. `./scripts/verify.sh` → PASS JS typecheck/lint/tests/audit, Ruff, mypy, pytest (1 passed); pip-audit skipped (not installed).
- Not tested: Reboot persistence; Colima is manually started.
- Next: After reboot run `colima start`; keep `infra/local.env` local and untracked.
- Questions for human: none

---


Newest entry on top. Claude adds one entry at the end of every session. Keep each entry under ~15 lines; older than 30 days → move to `docs/progress-archive.md`.

Template:

## YYYY-MM-DD — <Task ID> <title> — <done | in progress | blocked>
- Changed: <one line per meaningful change>
- Files: <paths>
- Verify: `./scripts/verify.sh` → <pass/fail + key numbers>
- Not tested: <devices / cases you couldn't check>
- Next: <exact next step>
- Questions for human: <or "none">

---

## 2026-10-24 — T0.3 Local infra — blocked
- Changed: Verified the repo-level checks succeed; confirmed the local infra stack is scoped to Postgres/Timescale/PostGIS, Redis, and EMQX with localhost-only bindings and fail-closed MQTT authz. The runtime acceptance check remains blocked because Docker is unavailable in this environment.
- Files: `infra/docker-compose.yml`, `infra/postgres/init.sql`, `infra/emqx/acl.conf`, `infra/emqx/base.hocon`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS typecheck/lint/tests/audit, Ruff, mypy, pytest (1 passed); `docker compose -f infra/docker-compose.yml up -d` → FAIL with `zsh: command not found: docker`.
- Not tested: Actual PostgreSQL extension activation, Redis healthcheck, and EMQX service startup; no Docker runtime available here.
- Next: Run this on a Docker-capable machine with `POSTGRES_PASSWORD` and `REDIS_PASSWORD` exported, then execute `docker compose -f infra/docker-compose.yml up -d` and confirm all services are healthy before marking T0.3 done.
- Questions for human: none

---

## 2026-10-24 — T0.4 DB schema v1 + RLS — blocked
- Changed: Confirmed the backend has no ORM/migration setup; did not add dependencies or schema code pending approval.
- Files: `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS typecheck/lint/tests/audit, Ruff, mypy, pytest (1 passed); pip-audit skipped.
- Not tested: Migration application and org-isolation test; Docker/Postgres unavailable.
- Next: Approve `sqlalchemy==2.1.6`, `alembic==1.20.1`, and `asyncpg==0.32.0` (versions confirmed on the package index); confirm the supported DB runtime, then verify package/API compatibility before implementation. Provide a runnable PostgreSQL instance; T0.3 remains blocked.
- Questions for human: May I add those pinned database dependencies, and can Docker/Postgres be made available for migration and RLS verification?

---

## 2026-10-24 — T0.5 GPS spike (driver app) — blocked
- Changed: Reviewed the approved background-location package metadata and device/build prerequisites; no app code added because there is no driver app skeleton or Android device/toolchain to execute the spike.
- Files: `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS checks/audit, Ruff, mypy, pytest (1 passed); pip-audit skipped. No GPS acceptance test possible in this environment.
- Not tested: 15-minute screen-off tracking, battery drain, and Xiaomi/OEM behavior; no `adb`, EAS CLI, or connected Android phone. Xiaomi model/version also unknown.
- Next: Provide a Xiaomi Android device model/version and Android build environment; scaffold driver app and run the licensed module's debug dev build, then record actual GPS and battery observations.
- Questions for human: Which Xiaomi or Samsung model/Android version will be used, and can that phone be made available for the 15-minute test?

---

## 2026-10-24 — T0.3 Local infra — blocked
- Changed: Added local TimescaleDB/PostGIS, Redis, and EMQX Compose config with healthchecks, required DB/cache passwords, loopback-only ports, and fail-closed MQTT authz; added first-init SQL for PostGIS/TimescaleDB.
- Files: `infra/docker-compose.yml`, `infra/postgres/init.sql`, `infra/emqx/acl.conf`, `infra/emqx/base.hocon`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS checks/audit, Ruff, mypy, pytest (1 passed); pip-audit skipped. Static YAML/config checks passed.
- Not tested: Docker Compose startup/health and extension presence; no Docker/container runtime is installed.
- Next: Install/start Docker, provide `POSTGRES_PASSWORD` and `REDIS_PASSWORD` in the shell, run Compose, confirm all services healthy and both PostgreSQL extensions enabled, then unblock T0.3.
- Questions for human: none

---

## 2026-10-24 — T0.2 Backend skeleton + health endpoint — done
- Changed: Added Python 3.12 FastAPI skeleton, GET /health endpoint, HTTP test, pinned runtime/dev tools, and uv lockfile.
- Files: `backend/**`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS typecheck/lint/tests/audit, Ruff, mypy, pytest (1 passed); pip-audit skipped (not installed).
- Not tested: Database-backed behavior is out of scope for the health endpoint.
- Next: T0.3 Local infra.
- Questions for human: Git baseline unavailable to independently attribute earlier untracked scaffold files; no T0.2 files outside backend were changed except bookkeeping.

---

## 2026-10-24 — T0.1 Monorepo skeleton — done
- Changed: Added pnpm workspace, Node 22/pnpm 12.15.0 pins, shared TypeScript config, Turbo task config, ignore rules, env example, and lockfile.
- Files: `package.json`, `pnpm-workspace.yaml`, `turbo.json`, `packages/config/tsconfig.base.json`, `.gitignore`, `.env.example`, `pnpm-lock.yaml`, `docs/TASKS.md`, `docs/PROGRESS.md`
- Verify: `./scripts/verify.sh` → PASS JS typecheck, lint, tests, audit; no known vulnerabilities.
- Not tested: Future workspace packages (none exist yet).
- Next: T0.2 Backend skeleton + health endpoint.
- Questions for human: none

---

## 2026-10-24 — Kickoff — not started
- Changed: steering files, guardrails, knowledge base added
- Next: T0.1 Monorepo skeleton
- Questions for human: none

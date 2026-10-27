# ViaMitra

School/staff bus route + live tracking platform (India, Delhi NCR first).
The workspace root is its own git repo (`viamitra-workspace`, which gitignores the three code repos). It holds three independent git repos: `viamitra-backend` (Python FastAPI + infra), `viamitra-mobile` (2 Expo apps: driver, parent), `viamitra-web` (Next.js dashboard: org admin + super admin). Workspace files (`CLAUDE.md`, `.claude/`, `docs/`, `scripts/verify.sh`) are committed only in the workspace repo, never in the three code repos.
Spec: `docs/PRD.md` · Architecture: `docs/ARCHITECTURE.md` · Locked decisions: `docs/DECISIONS.md`
Read those only when the current task needs them. Don't load them all by default.

## Session protocol (every session)
1. Read the top entry of `docs/PROGRESS.md` and the ONE task you're working on in `docs/TASKS.md`.
2. Work on exactly one task. If none is named, pick the first `[ ]` task whose dependencies are `[x]`, state its ID, then start.
3. Before ending: run `./scripts/verify.sh`, tick the task, and add a dated handoff entry at the TOP of `docs/PROGRESS.md` (what changed, files touched, verify result, next step, open questions). Then commit the `docs/` changes in the workspace repo (`docs: <ID> ...`). Never push.
4. Auto-merge (standing rule, set by the human 2026-10-27): when `./scripts/verify.sh` passes with 0 skipped and both `task-verifier` and `security-reviewer` report no critical/high/medium issues, commit each touched code repo (Conventional Commits), fast-forward merge its task branch into `main` and delete the branch (`git branch -d`), without asking. Still never push. Still ask before new dependencies, scope extensions, or anything in `docs/DECISIONS.md`.

## Golden rules (non-negotiable)
- IMPORTANT: Never invent APIs, packages, config keys, env vars, CLI flags or file paths. Verify every library API from the installed package's types (`node_modules/<pkg>/**/*.d.ts`, Python source/stubs) or official docs before using it. If you can't verify, write "UNVERIFIED" and ask.
- Before adding a dependency: confirm it exists (`npm view <pkg> version` / `pip index versions <pkg>`), say why it's needed, wait for approval. Pin exact versions.
- Stay inside the task's **Files** list. Need anything else? Stop and ask.
- Never modify paths in `.claude/protected-paths.txt` (design assets, brand, guardrails, secrets) by ANY means: no Edit/Write, no `cp`/`mv`/`sed -i`/scripts/renames. Hooks block and audit this. Don't try to work around them.
- Never contradict `docs/DECISIONS.md`. If a decision looks wrong, propose a new ADR and wait.
- When describing existing code, cite `path:line`. Don't describe code you haven't read this session.
- "Done" = `./scripts/verify.sh` passes and you paste the summary. Never claim tests pass without running them. Never skip, weaken or delete a test to make it pass.
- Fix root causes. No `@ts-ignore`, `any`, `# type: ignore`, bare `except:`, or disabled lint rules without a comment and user approval.
- Failed the same fix twice? Stop, summarize what you tried, ask.

## Toolchain
- Claude's shell doesn't read `~/.zshrc`, and `/Users/apple/.local/bin/node` (v26) shadows Node 22. Run every Node/pnpm/Expo/adb command with `PATH=/opt/homebrew/opt/node@22/bin:/Users/apple/Library/Android/sdk/platform-tools:/Users/apple/Library/Android/sdk/emulator:$PATH ANDROID_HOME=/Users/apple/Library/Android/sdk`. Check `node -v` shows v22 before installing.

## Commands
- Install: `cd viamitra-backend/backend && uv sync` · `cd viamitra-mobile && pnpm install` · `cd viamitra-web && pnpm install`
- Verify everything (all three repos): `./scripts/verify.sh` · one repo: `bash scripts/check.sh` inside it
- Local dev bootstrap (env file, infra, EMQX accounts, migrations): `bash viamitra-backend/scripts/dev-setup.sh`
- Apps: in `viamitra-mobile`: `pnpm --filter driver start` · `pnpm --filter parent start` · in `viamitra-web`: `pnpm --filter dashboard dev`
- Backend: `cd viamitra-backend/backend && uv run uvicorn app.main:app --reload`
- Local infra (Postgres+PostGIS, Redis, EMQX, OSRM): `docker compose -f viamitra-backend/infra/docker-compose.yml up -d`
- Migration: `cd viamitra-backend/backend && uv run alembic revision --autogenerate -m "<msg>"` then `uv run alembic upgrade head`
- After a backend schema change: `cd viamitra-backend/backend && uv run python scripts/export_openapi.py` (commit `openapi.json`), then `pnpm gen:api` in `viamitra-mobile` and `viamitra-web` (reads `../viamitra-backend/openapi.json`; override with `OPENAPI_PATH`)

## Layout
- `viamitra-backend/backend/app` — `api/` routers · `services/` logic · `models/` SQLAlchemy · `schemas/` Pydantic · `workers/` Celery
- `viamitra-backend/infra/` — docker-compose, EMQX ACL, OSRM config · `viamitra-backend/openapi.json` — the API contract (committed; tests fail if stale)
- `viamitra-mobile/apps/driver`, `viamitra-mobile/apps/parent` — Expo dev build (never Expo Go), Expo Router, TypeScript strict
- `viamitra-mobile/packages/ui` — shared RN components
- `viamitra-web/apps/dashboard` — Next.js App Router, Tailwind, shadcn/ui
- `viamitra-mobile/packages/api-client`, `viamitra-web/packages/api-client` — GENERATED from `openapi.json`; never hand-edit
- `viamitra-*/packages/config` — eslint/tsconfig (each JS repo keeps its own copy)

## Conventions
- TypeScript strict; no default exports except Expo Router / Next.js route files.
- Every backend query is scoped by `org_id` (multi-tenant). See `.claude/rules/security.md`.
- `apps/*/android` and `apps/*/ios` are generated by prebuild. Change native config only via `app.config.ts` + config plugins.
- Conventional Commits (`feat(driver): ...`). Branch per task inside each repo the task touches, from that repo's `main`: `task/<ID>-short-name`. Never push or force-push; the human pushes.
- No AI attribution anywhere in the three repos: no `Co-Authored-By`/`Claude-Session` trailers, and no mention of Claude or Anthropic in committed files or commit messages.

## Context hygiene
- Use the Explore subagent for broad searches; keep main context for implementation.
- When compacting, preserve: current task ID, files modified, last verify result, open questions.

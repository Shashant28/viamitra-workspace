---
paths:
  - "viamitra-backend/**"
---

# Backend rules (FastAPI)

- Layers: router (`api/`) → service (`services/`) → repository/model (`models/`). Routers hold no business logic.
- Every schema change ships with an Alembic migration in the same task. Never edit an applied migration; add a new one.
- Async SQLAlchemy sessions via dependency injection. No global sessions.
- Live location: driver → EMQX → ingestion worker → Redis (latest position + pub/sub) → WebSocket. Do not write every GPS point to Postgres synchronously; batch into TimescaleDB.
- Geofence/ETA logic lives in `services/events/` and is unit-tested with recorded GPS fixtures in `backend/tests/fixtures/`.
- Notifications go through the Celery queue. Push (FCM) is the default; WhatsApp only for templates listed in `docs/DECISIONS.md`.
- After changing any Pydantic request/response schema, run `uv run python scripts/export_openapi.py` (from `backend/`) and commit `openapi.json`, then run `pnpm gen:api` in viamitra-mobile and viamitra-web and commit the regenerated clients in the same task.
- Tests: pytest + httpx AsyncClient against a real Postgres (docker compose), not SQLite.

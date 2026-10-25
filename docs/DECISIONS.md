# Locked decisions (ADRs)

Human-edited only. Claude proposes a new ADR in chat; it never edits this file.

| ID | Decision | Why |
|---|---|---|
| ADR-001 | Mobile: React Native + Expo (dev build, no Expo Go), TypeScript strict | One language across apps + dashboard; config plugins for native modules |
| ADR-002 | Background GPS: Transistor `react-native-background-geolocation` (licensed for Android release) | Battle-tested background tracking, offline buffering |
| ADR-003 | Dashboard: Next.js App Router + Tailwind + shadcn/ui | Org Admin and Super Admin in one codebase, role-based |
| ADR-004 | Backend: Python FastAPI + SQLAlchemy async + Alembic + Celery | OR-Tools/geo libs native in Python |
| ADR-005 | Realtime: EMQX (MQTT) ingest, Redis pub/sub, WebSocket fan-out | Weak-network friendly ingest, cheap fan-out |
| ADR-006 | DB: PostgreSQL + PostGIS + TimescaleDB, RLS on tenant tables | Geo queries + time-series + tenant isolation |
| ADR-007 | Maps: Google Maps SDK for display; OSRM self-hosted for ETA; Google Routes only for paid traffic ETA | Cost control |
| ADR-008 | Notifications: FCM push default; WhatsApp only for 1 utility template ("bus ~5 min away") in v1 | Cost control |
| ADR-009 | Auth: phone OTP via MSG91, short-lived JWT + rotating refresh | Indian users, no passwords |
| ADR-010 | Infra: AWS ap-south-1, Docker; no Kubernetes before 500 schools | Data residency, simplicity |
| ADR-011 | Location history retention: 7 days | DPDP minimisation |
| ADR-012 | Monorepo: pnpm workspaces + Turborepo; Python via uv | Shared types, one CI |
| ADR-013 | "Today" and all service dates use Asia/Kolkata; timestamps stored in UTC | Pilot is in Delhi NCR; one business timezone avoids off-by-one-day bugs |

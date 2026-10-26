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
| ADR-016 | Mobile audit ignores GHSA-86w9-cpqp-85rv (node-forge) and GHSA-mrhx-c7xc-m3w5 (zod 3) only | Both come solely via @expo/cli (dev tooling, not shipped in the app) with no compatible fix; recheck on every Expo SDK/CLI upgrade and remove when fixed |
| ADR-014 | Mobile app IDs (Android `package` and iOS `bundleIdentifier`): driver `com.viamitra.driver`, parent `com.viamitra.parent` | Store identity can't change after first release; one naming scheme for both apps |
| ADR-015 | Mobile apps read the API base URL from `EXPO_PUBLIC_API_BASE_URL`; it holds only the public API URL, never a secret | `EXPO_PUBLIC_` values are bundled into the app and readable by anyone |
| ADR-017 | Refresh tokens form a chain per login (family_id). Presenting a refresh token that was already rotated away revokes every session in its chain and is audited; the caller still gets the same 401. A token revoked by logout does not trigger this, and a short grace window (≤10 s) tolerates a client retrying the same token after a network failure. /auth/logout stays single-session. | Reuse of a rotated token is the standard sign of a stolen token (OAuth 2.0 Security BCP); without this, whoever refreshes first keeps the live chain |

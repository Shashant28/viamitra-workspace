# Security rules (always loaded)

## Secrets
- Secrets live only in environment variables / secret manager. Never hardcode, log, or commit them.
- Never read `.env*` files. Use `.env.example` (keys only, no values) to learn variable names.
- In Expo, anything prefixed `EXPO_PUBLIC_` is bundled into the app and is PUBLIC. Never put API secrets, MQTT passwords or service keys there.
- Mobile tokens go in `expo-secure-store`, never AsyncStorage.

## Multi-tenancy
- Every table holding customer data has `org_id`. Every query filters by the caller's `org_id` taken from the verified token, never from the request body or query string.
- Postgres Row-Level Security stays enabled on tenant tables as a second layer.
- Super-admin endpoints live under `/admin/*`, require the `super_admin` role, and are audited.

## AuthN / AuthZ
- Phone OTP login → short-lived access JWT (≤15 min) + rotating refresh token stored hashed.
- Role checks (driver, parent, org_admin, super_admin) happen in a FastAPI dependency, not inside handlers.
- A parent can only see trips of buses their own child is assigned to. A driver can only publish to their own trip.

## Location & child data (DPDP Act 2023)
- Location is collected only while a trip is active. Trip location history auto-deletes after the retention window set in `docs/DECISIONS.md`.
- No child PII (name, photo, stop) in logs, analytics events, push payload text, or error reports.
- Parental consent is recorded before a child profile is created.

## MQTT
- Each driver device authenticates with its own credentials. EMQX ACL lets it publish only to `trips/{own_trip_id}/location`. Parents never connect to MQTT.

## Input & output
- Validate all input with Pydantic schemas; reject unknown fields.
- Rate-limit OTP send/verify and all auth endpoints.
- No raw SQL string building; use SQLAlchemy parameters.

## Dependencies
- `pnpm audit` and `uv run pip-audit` are part of `scripts/verify.sh`. A new high/critical finding blocks "done".

# Architecture

## Live tracking path
Driver App --(MQTT, QoS 1)--> EMQX --> Ingestion worker (FastAPI/async) --> Redis (latest position, pub/sub) --> WebSocket server --> Parent App / Dashboard
Ingestion also batches points into TimescaleDB (history, auto-deleted after retention window).

## Alerts path
Redis stream --> Event engine (geofence + ETA via OSRM) --> Celery queue --> FCM push (WhatsApp later)

## Management path
Dashboard (Next.js) --> REST API (FastAPI) --> PostgreSQL + PostGIS. Route ordering via OR-Tools.

## Core data model (initial)
- organizations(id, name, plan, created_at)
- users(id, org_id, phone, role[driver|parent|org_admin|super_admin])
- buses(id, org_id, reg_no, capacity)
- routes(id, org_id, name, shift[morning|evening])
- stops(id, org_id, route_id, seq, name, location geography(Point), geofence_m)
- students(id, org_id, name, stop_id, parent_user_id, consent_at)
- trips(id, org_id, route_id, bus_id, driver_id, status, started_at, ended_at)
- trip_events(id, org_id, trip_id, type, stop_id, student_id, at)
- locations (Timescale hypertable: trip_id, org_id, at, point, speed, accuracy)

## Repo layout
See CLAUDE.md → Layout.

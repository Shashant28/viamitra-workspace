# ViaMitra — Product Spec (MVP)

## Problem
Parents don't know where the school bus is or when it will reach their stop. Schools have no live view of their fleet and no safety alerts.

## Users & apps
| Role | App | MVP scope |
|---|---|---|
| Driver | Expo app (Android-first) | OTP login, today's route, start/end trip, turn-by-turn to next stop, mark student picked/dropped, SOS |
| Parent | Expo app (Android + iOS) | OTP login, live bus on map, ETA to own stop, push alerts (trip started, ~5 min away, arrived, dropped), mark child absent, trip history (7 days) |
| Org Admin | Next.js dashboard | Manage buses, drivers, routes, stops, students; live fleet map; alerts; basic reports |
| Super Admin | Next.js dashboard (`/admin`) | Organizations, plans, billing status, support, feature flags |

## Core flows
1. Admin creates route with ordered stops → OR-Tools suggests order → admin confirms.
2. Driver starts trip → GPS every 5–10 s via MQTT → parents see live position.
3. Bus enters geofence of a stop → event → parent alert.
4. Driver marks pickup/drop → parent alert.
5. Trip ends → tracking stops immediately.

## Out of scope for MVP
Payments in app, WhatsApp alerts, traffic-aware ETA, route auto-optimization without admin confirm, corporate/staff transport, family location sharing, iOS driver app polish.

## Success criteria for pilot
- 1 bus runs 1 school week with zero driver-app crashes and <2% dropped GPS points.
- Parent ETA within ±3 minutes for 80% of stops.
- 3 schools willing to pay after pilot.

## Non-functional
- Location delay driver→parent p95 < 5 s.
- Driver app battery drain < 8%/hour while tracking (measure on a mid-range Android).
- Data stays in AWS ap-south-1. DPDP Act 2023 compliant (see `.claude/rules/security.md`).

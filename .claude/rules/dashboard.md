---
paths:
  - "viamitra-web/**"
---

# Dashboard rules (Next.js)

- App Router. Server components by default; `"use client"` only where interaction needs it.
- Org Admin routes under `app/(org)/`, Super Admin under `app/(admin)/`. Route groups enforce role checks in their layout.
- All data via `packages/api-client`. Never call the database or internal services directly from Next.js.
- UI from shadcn/ui components already in `components/ui/`. Don't restyle or regenerate them; don't touch `public/` assets.
- Maps: Google Maps JS API loaded once in a client component; API key is a restricted browser key from env.

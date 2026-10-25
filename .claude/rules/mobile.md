---
paths:
  - "viamitra-mobile/**"
---

# Mobile rules (Expo / React Native)

- Expo dev build only. Native modules are added through config plugins in `app.config.ts`; never edit `android/` or `ios/` directly.
- Background location in the driver app uses `react-native-background-geolocation` (Transistor). Read its installed type definitions before calling any API; its config options changed between major versions.
- Driver app must work offline: buffer locations locally, flush in order when network returns. Never drop points silently.
- Show the persistent tracking notification whenever location is being collected. Stop tracking the moment the trip ends.
- Use colours, spacing and typography only from `packages/ui/tokens` and `packages/ui/theme`. Never hardcode hex values or font sizes; never add or change tokens or assets.
- Screens in `app/` (Expo Router) stay thin: data via hooks in `src/features/<feature>/`, API calls only through `packages/api-client`.
- Test on Android first (most drivers). Note in PROGRESS.md which device/OS you could not test.

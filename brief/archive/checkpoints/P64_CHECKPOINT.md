# P6.4 checkpoint, 2026-09-22

The server-backed admin directory and bilingual account detail/action UI are implemented locally. Item 1 remains PARTIAL because the SQL migration and pgTAP probes could not run.

- Flutter: 446 tests pass, including 7 new directory tests; analyzer 0 issues.
- SQL: one new migration, 23 new pgTAP probes, all UNVERIFIED-STATIC. No production or Supabase push operations.
- Browser: Chrome launches/builds. Interactive welcome, guest, feed, Settings guard and map checks used the in-app browser. Fixed observed Arabic tab/search localization defects; final Arabic browser recheck is incomplete.
- Android: Pixel_9_Pro detected; debug build/install and rendered welcome verified. Debug connection dropped; remaining flow unverified. No physical-device evidence.
- Docker: inference-manager socket failure survived a normal recovery attempt. Left stopped after successful force-stop. No factory reset or data deletion. Optional Model Runner disable was attempted but not confirmed.
- Unsupported operations remain explicit: account deletion and Auth-session revocation. Personal streamer/verification revocation preserves organization roles and permissions.
- No phase commit: database verification is outstanding. Changes remain scoped and reviewable in the working tree; no stashes altered.

Live closing budget was 67% five-hour after a window rollover and 89% weekly. The weekly guard is 90%. The full evidence and next actions are in the last RESUME block in LEDGER.md. No release-readiness claim.

# P5 offline hardening worktree

Isolated branch `codex/p5-offline-hardening` starts at `22c6560`. The original P5 worktree and main checkout were not edited. P6 physical-device testing remains with the owner.

## Checkpoint 1: reachability

The app now probes the configured backend every 15 seconds while foregrounded, even when Wi-Fi or mobile transport is unchanged. The probe times out after 2 seconds. Hidden, paused and detached states stop scheduled probes; resume checks immediately. A revision counter discards results from older probes and transport states. Manual Retry remains available between scheduled checks.

Focused verification: `flutter test --no-pub test/connectivity_service_test.dart --reporter expanded` passed 7 tests. Fake-clock tests cover unchanged-Wi-Fi backend loss and recovery, background pause/resume, and stale probe completion. Flutter tooling required normal SDK-cache access; the first sandboxed run could not start. `flutter pub get` only configured this worktree, and its unrelated generated Windows files were restored. No physical network, Web CORS, or real backend was tested.

Weekly usage: 28% at entry, 29% after checkpoint 1. Suggested stop is before 34%. No reset used.

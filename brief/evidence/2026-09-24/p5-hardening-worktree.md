# P5 offline hardening worktree

Isolated branch `codex/p5-offline-hardening` starts at `22c6560`. The original P5 worktree and main checkout were not edited. P6 physical-device testing remains with the owner.

## Checkpoint 1: reachability

The app now probes the configured backend every 15 seconds while foregrounded, even when Wi-Fi or mobile transport is unchanged. The probe times out after 2 seconds. Hidden, paused and detached states stop scheduled probes; resume checks immediately. A revision counter discards results from older probes and transport states. Manual Retry remains available between scheduled checks.

Focused verification: `flutter test --no-pub test/connectivity_service_test.dart --reporter expanded` passed 7 tests. Fake-clock tests cover unchanged-Wi-Fi backend loss and recovery, background pause/resume, and stale probe completion. Flutter tooling required normal SDK-cache access; the first sandboxed run could not start. `flutter pub get` only configured this worktree, and its unrelated generated Windows files were restored. No physical network, Web CORS, or real backend was tested.

Weekly usage: 28% at entry, 29% after checkpoint 1. Suggested stop is before 34%. No reset used.

## Checkpoint 2: live room lifecycle

The offline view unmounts the player and now also disposes the room's chat controller and viewer presence service, stops their subscriptions and timers, and releases wakelock. On recovery the screen waits for a successful fresh catalog and a confirmed live row before creating one new player/chat/presence set. Its player callbacks carry a room generation so a late callback from the old player cannot claim LIVE. The selected tab, typed chat draft, pause and mute preferences remain in screen state; media starts as `initializing` after a clean restart. A fresh non-live row keeps the room unavailable. The phone publisher and moderation rules were not changed.

Focused verification: the whole-room widget test stubs player, chat, presence and catalog responses, then checks disposal, confirmed restart and non-live recovery. `flutter test --no-pub test/offline_experience_test.dart test/live_stream_test.dart --reporter compact` passed 19 tests. The first test version exposed overlapping catalog requests; checkpoint 3 will coordinate those requests. Native WebView audio and physical-device behavior remain unverified.

Weekly usage after checkpoint 2: 29%.

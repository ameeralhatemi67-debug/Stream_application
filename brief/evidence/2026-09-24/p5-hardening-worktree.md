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

## Checkpoint 3: catalog recovery

The provider now shares an in-flight public streamer request within one connectivity epoch. An outage invalidates older requests, so a late pre-outage result cannot restore cached LIVE state or overwrite a newer fetch. Recovery and banner Retry join the same request; a failed request leaves the cached/unavailable state visible and a later Retry can start another request. Category loading also shares one request, ignores stale results, and permits retry after failure. The duplicate startup streamer fetch through `refreshAdminData` was removed. The room Retry now requests a fresh catalog when the probe says the backend is reachable.

Focused verification: `offline_experience_test.dart` passed 9 tests, including backend outage, old request completion, failed recovery, repeated banner Retry, successful fresh fetch, category coalescing, and whole-room restart. The connecting overlay became visible during clean restart and exposed an inherited 1.65:1 subtitle contrast defect; changing it to the media text token made all 38 `rendered_contrast_test.dart` cases pass. `flutter analyze --no-pub` finished with 0 issues. The final full `flutter test --no-pub --reporter expanded` passed **549 tests**; its log is in this worktree's ignored `project/.dart_tool/p5-full-final.log`.

One root `node brief/tools/gates.mjs` run exited 0 and reported G6=565 as its only failing gate. G6 is the inherited broad English-literal regex scanner issue pending the separate G6 branch; all other failure-target gates passed. G10b=2 and G10e=3 are inherited INFO findings. `git diff --check` passed. No SQL changed, so no SQL suite ran.

Weekly usage after checkpoint 3 and gates: 30% (entry 28%, suggested stop before 34%). No reset was redeemed. No merge, push, deploy, production access, phone, account, stream key, owner P6 evidence, or stash was used.

Physical-device acceptance still needs airplane-mode cold start with a prior public snapshot, backend outage and recovery on unchanged Wi-Fi/mobile, background/resume timing, Arabic layout, live-room audio stop/restart and exit/re-entry, and repeated Retry while a backend request is slow or failing. The owner is handling P6 phone testing separately. P5, P6 and P6S remain unaccepted.

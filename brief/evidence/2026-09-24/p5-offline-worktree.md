# P5.1–P5.3 local evidence

Branch `codex/p5-offline` starts at local `master` `345cfbd`. This note lives only in the isolated worktree. No hosted project, phones, Google account, stream key, linked command, SQL suite, deploy, push, or main-checkout evidence was used.

| Milestone | Commit | Local proof | Limit |
| --- | --- | --- | --- |
| P5.1 | `7997f0d` | Four `connectivity_service_test.dart` cases prove offline skips the probe, attached transport can be degraded, a timed-out injected probe degrades, and rapid transport events debounce to the last state. All endpoints are injected and local. | No captive-portal, Web CORS, background, or physical-network transition test. |
| P5.2 | `cdb2224` | Three `public_catalog_cache_test.dart` cases prove version/timestamp, public streamer and organization/category round trip, removal of live ID/status/viewer count, offline provider cold-start restore, and refusal of an unknown schema. The existing map tests also passed. | No device storage eviction or real backend fetch. Snapshot contents are an explicit public-field allowlist; there is no account/session data. |
| P5.3 | `ef67a5a` | Six `offline_experience_test.dart` cases cover English and Arabic banner/RTL retry, degraded-to-online UI recovery using an injected probe, stale LIVE badge suppression, degraded room feedback, and wizard text surviving a connection change. The adjacent Feed/Map/live/wizard focused run passed 57 tests. | The room view is locally checked only. Chat and publisher code was not changed; real playback, reconnect, form upload failures, and two-phone behavior need owner acceptance. |

Stable checkpoint: `flutter analyze --no-pub` passed with 0 issues after removing a redundant import. One full `flutter test --no-pub --reporter compact` run passed **543 tests**. One `node brief/tools/gates.mjs` run returned G6=566 (the base evidence at this checkout reports 565; the added match is a localized `Text('offline_experience.*'.tr())` key counted by the broad regex). All other failure-target gates passed, including G7 key symmetry and G11a=0 in this isolated worktree. The INFO findings G10b=2 and G10e=3 are inherited. No SQL changed, so no SQL suite ran.

Usage readings: entry 27% weekly used; after P5.1 27%, after P5.2 27%, after P5.3 28%, after gates 28%. No reset was redeemed. The suggested stop point was 35%.

Likely integration conflict points if the owner's P6 retest produces fixes are `app_provider.dart` and `live_broadcast_screen.dart`; P6 form or feed repairs could also touch `streamer_apply_screen.dart` or `discovery_feed_screen.dart`. Reconcile those hunks against the P6 fixes before merging. Device acceptance still needs an airplane-mode cold start with a previously loaded catalog, physical reconnect and backend outage/degraded transitions, Arabic layout, live-room exit/re-entry, and form retry on two phones. P5.4/P5.5 and P6S/P7/P8B are outside this branch.

# Handoff: P5 three-city map upgrade (session paused 2026-09-26)

**Status: NEEDS WORK. Paused mid repair round.** Critic round 1 (on `53a6b9d`) scored Functionality 7, Accessibility/platform 6, Integration 7 and Ease of use 7, with one high-severity defect (D1). The repair commit `d11e9f2` addresses D1–D8, D11 and D12. It has **not** had its browser re-check or critic round 2. Nothing is merged, pushed or deployed. P5 is not accepted.

## Where things are

| Item | Value |
|---|---|
| Worktree | `C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app` (reused; the old branch `codex/p5-basemap-spike` at `86068e8` is untouched) |
| Branch / tip | `codex/tricity-map-upgrade` at `d11e9f2` (baseline `7b54cb5`) |
| Commits | `78e1369` map, `41cf23d` picker, `47ed6f8` web fail-safe, `e821e1e` gates, `0162d75` licensing + ADR-008, `5e10678` 90-day advisory + directions test, `53a6b9d` evidence, `d11e9f2` round-1 repairs |
| Checks at `d11e9f2` | `flutter analyze` 0 issues; full `flutter test` **732 passed**; `gates.mjs` 0 failing. A web release build of `d11e9f2` sits in `project/build/web` and has not been exercised. |
| Uncommitted | `brief/evidence/.../CRITIC_REVIEW.md` (the round-1 review plus "Rounds used: 1 of 3"), this file, and `SESSION_HANDOFF_PROMPT.md`. The `project/windows/flutter/generated_plugin*` files differ only in line endings: never commit them. |
| Main checkout / stashes | Untouched. It was read-only throughout; stashes `d646b945` and `d53c178e` are intact. |
| Temporary checkout | `C:/Users/User/.codex/worktrees/tricity-baseline-7b54cb5`, detached, only for the APK baseline. Remove it with `git worktree remove` when it is no longer needed. |
| Critic rounds used | **1 of 3** |

## Remaining work, in order

1. **Browser re-check of the repairs** (the evidence for round 1's D1 fix).
   - Start from a fresh Chrome profile on a short path (long profile paths break CacheStorage on Windows). The tooling is in `raw/chrome_driver.js` and `raw/spa_server.py`; serve `project/build/web`.
   - Onboard in English and open the map. Call `performance.clearResourceTimings()` and make more than 300 same-origin fetches, to simulate a long session.
   - Confirm the new "Use this map without internet?" prompt appears, then tap **Save**. It should reach ready.
   - Confirm the cache holds `main.dart.js`, `flutter_bootstrap.js`, the CanvasKit JS and wasm, Roboto, Noto Sans Arabic and the map pack.
   - Stop the server, relaunch the same profile with `--host-resolver-rules=MAP * ~NOTFOUND`, cold-start the app and switch to Arabic. Labels must be joined, not boxes.
   - Also capture: the Arabic layout with the buttons on the left (overview framing, D6), the single Retry when offline (D12), the picker's crosshair and "Pin the map centre" button, and "no pinned location" directions.
   - Optionally re-run the Windows integration render: `flutter test integration_test/map_render_test.dart -d windows --dart-define=MAP_RENDER_OUT=<evidence>/screenshots/windows`.
2. **Evidence updates.**
   - D10: relabel ACCEPTANCE_RESULTS rows A01 (Chrome cell = web equivalent only), A04, A09 and A13 as PARTIAL, because their Android cells are NOT RUN.
   - Soften ADR-008's "work offline on first native launch" to "designed to; unverified on hardware".
   - Record the new results in VERIFICATION.md, REPORT.md (commits, 732 tests, repairs, the D8 area disclosure) and ACCEPTANCE_RESULTS.md.
   - Commit using explicit file lists.
3. **Critic round 2.** Use an independent subagent with the same prompt as round 1 (see CRITIC_REVIEW.md), reviewing the new tip. Stop if all four categories score 8 or more and no high defect remains. Otherwise do one more repair pass and round 3 (the last).
4. **Final handoff update** of this file with the scores and the reason each category is below 10.

## Delivered (verified on Chrome/Windows and by tests; the phone is unverified)

- A bundled, hash-verified vector map pack: 11,919,559 B, SHA-256 `1deb87ea…6a87`. All 8,298 tiles decode.
- flutter_map 8.3.2 with flutter_map_vector_tiles 2.9.0, fed by a bounded local range client (no server, fork or parser).
- Backend-independent streets and labels, and a single viewport policy for every camera path (max zoom 18, no rotation, feasible canvas).
- The venue domain filter; unsourced polygons and Saudi-wide presets removed.
- Compact OSM credit, offline details and notices, a connection chip, honest pack-failure states.
- Web offline preparation behind a service worker: staging cache, hash check, network timeout, eviction reporting.
- A truthful location picker: exact point only, legacy out-of-area points kept, no invented coordinates.
- Arabic labels fixed on web by rebuilding the layer when fonts load.
- APK delta +12.3 to 13.7 MB (target is 40 MB or less).
- Reproducible tooling in `project/tool/maps` and the ADR-008 draft.

## Unmet, pending or needing an owner decision

- **A11 accurate city outlines: NOT MET.** No licensed municipal geometry exists. It needs an owner-authorized data request (Balady, Eastern Province Municipality or GEOSA).
- **SM-S936B physical runs are all pending.** See OWNER_RETEST_SCRIPT.md (first-use offline, reboot, rotation, TalkBack, text size, frame and memory, mini-player, map → live → map).
- **Backend-current runs** (A14, A15, A17, A19 live) need an authorized non-production backend.
- **D8 venue area:** the rectangle includes Qatif, Saihat and Ras Tanura. The owner must decide whether to keep it or narrow it.
- **Pre-existing issues seen, not changed:**
  - Approval hard-codes `cityEn: 'Al Khobar'` and a placeholder `youtubeVideoId` (`app_provider.dart` around line 4420).
  - VenueNavigationSheet shows a distance from a fixed Al Khobar point.
  - The app has no in-app licences screen.
  - The credit wording still needs counsel sign-off.
- **Platform limits (documented):** labels use platform default fonts, not IBM Plex. A browser that has never visited the site cannot start offline. Web storage can be evicted. Only Chrome was tested on the web.

## Not authorized

Merge, push, deploy, hosted database changes, production credentials, installing over the owner's app, reading `dart_define.local.json`.

---
type: audit
project: Streamer_app
phase: 5 of 8
created: 2026-08-20
status: complete
supersedes-check-of: "doc/Performance, Rendering & Resource Optimization Report.md (Aug 2026)"
---

# ⚡ Phase 5 — Performance & Optimization: Re-Verification Against Current Code

Same method as Phase 1: your existing Performance report already did the deep profiling-style analysis. I re-read the actual files it names to confirm what's still true today, correct anything that's changed, and add the exact call sites where the report was more general.

**Bottom line: every major finding is still open. One is worse than described (the "safe" image wrapper adds zero caching), one turned out to be partially fixed already (video statistics batching exists, just not for the thing that matters most), and one claim is wrong and should be dropped (the orphaned HTML file doesn't actually bloat the shipped app).**

---

## 1. Verification table

| Finding | Original Severity | **Current Status** | Evidence |
|---|---|---|---|
| Root shell (`app_router.dart`) rebuilds the entire app on every `notifyListeners()` | P0 Critical | 🔴 **Still open, unchanged** | `app_router.dart:170` still calls `context.watch<AppProvider>()` at the top of `ResponsiveScaffoldWithNestedNavigation.build()`, which wraps the whole `StatefulNavigationShell` + nav rail + mini-player. |
| `context.select` / `Selector` used 0 times anywhere | P0 Critical | 🔴 **Still exactly 0** | Searched the whole `lib/` tree for `context.select` and `Selector<` — zero matches. Meanwhile `context.watch<AppProvider>()` is used in **7 separate screens** (`app_router.dart`, `spatial_map_screen.dart`, `discovery_feed_screen.dart`, `notification_center_sheet.dart`, `settings_screen.dart`, `org_management_view.dart`, `admin_hub_screen.dart`) — so it's not just the root shell, it's the dominant pattern across the entire app. Every one of these screens rebuilds in full on any unrelated provider change (a chat message, a bookmark toggle, a 60-second viewer-count tick). |
| High-resolution bitmaps decoded without `cacheWidth`/`cacheHeight` | P0 Critical | 🟠 **Confirmed, and worse than described** | The two oversized source images are still exactly as reported: `amir_person_pic.jpg` = **5.23 MB** (5,359,538 bytes, unchanged), `amir_card_pic.jpg` = **2.52 MB** (2,581,994 bytes, unchanged). More importantly: `safe_image_provider.dart` — the shared helper the app uses specifically to render these avatars/banners safely — does zero downsampling. It returns a bare `NetworkImage`, `AssetImage`, or `FileImage` with no `cacheWidth`/`cacheHeight` parameter and doesn't wrap anything in `ResizeImage`. So the "safety" wrapper solves crash-safety but not the memory problem the original report described — and its own `defaultAsset` fallback *is* the 5.23 MB file, meaning any broken/missing avatar image anywhere in the app decodes the largest asset in the project at full resolution. |
| Spatial map: O(N² × 10) pairwise collision resolution on the UI thread | P1 High | 🔴 **Still open, unchanged, confirmed to run inside `build()`** | `spatial_map_screen.dart:235-269` — a literal triple-nested loop (`for iter in 10` × `for i` × `for j`), computing `sqrt`, `cos`, `sin` per pair, sits directly inside the map layer's builder callback. It reruns on every rebuild the map widget goes through (which, combined with the `context.watch` finding above, may be more often than just pan/zoom). |
| Unbatched YouTube API polling for live viewer counts | P2 Medium (originally) | 🔴 **Still open — and I'd raise this to Medium-High given what I found** | Found the exact call site: `app_provider.dart:171-186` (`_pollLiveViewers()`), on a `Timer.periodic` firing every 60 seconds (`_liveViewerPollInterval`). It does `for (final streamer in liveStreamers) { await _youTubeService.fetchLiveConcurrentViewers(streamer.youtubeVideoId); }` — one HTTP request **per live streamer, awaited sequentially, one at a time**. With N concurrent live broadcasts, that's N sequential round-trips every single minute, and quota-wise, N `liveStreamingDetails` reads instead of 1. The fix is available in the same file, unused for this purpose: `fetchVideoViewCounts()` (see next row) already demonstrates the exact batching pattern (`videos?part=...&id=id1,id2,...` up to 50 IDs) — `liveStreamingDetails` supports the same comma-separated multi-ID pattern, so this is a same-file, same-technique fix, not a new one to design. |
| **Correction to the original report:** "no batching anywhere" | — | 🟡 **Partially already fixed — just not where it matters most** | `fetchVideoViewCounts()` (`youtube_api_service.dart:366-400`) already batches up to 50 IDs per call with proper chunking for **VOD view-count statistics**. So batching *has* been implemented once as a pattern in this codebase — it just hasn't been applied yet to the live-viewer-count polling loop above, which is the one running every 60 seconds and therefore the one with the real recurring cost. Worth noting so whoever picks up this fix knows there's already a working example to copy in the same file rather than building the batching logic from scratch. |
| Unclosed controllers / native image handles / animation controller leaks | P1 High (originally) | 🟡 **Not independently re-verified this pass** | Confirming this properly means checking every `TextEditingController`/`AnimationController` declaration against its `dispose()` in every relevant widget — didn't do a full sweep this pass given time. Carrying forward as open per the original report; recommend confirming during Phase 6 when the specific screens (modals, application wizard) get opened anyway. |
| **Correction to the original report:** orphaned `Ahmed_Amer_YouTube.html` (4.43 MB) bloats the app bundle | P2 Medium (originally) | 🟢 **Claim doesn't hold up — should be dropped, not fixed** | The file exists on disk (confirmed: `assets/Ahmed_Amer_YouTube.html`, 4.53 MB) but `pubspec.yaml`'s `assets:` list only declares `assets/map/...`, `assets/i18n/...`, and four specific `assets/images/<name>/` folders — it does **not** declare this file or its parent directory as a whole. Flutter's asset bundler only packages paths explicitly listed in `pubspec.yaml`, so this file is repo clutter sitting in your working tree, not something that ships inside the APK/IPA. Worth deleting for repo hygiene, but it is not contributing to the "13.8 MB → target 2.2 MB" bundle-size problem the original report described — that gap needs to be explained by the two oversized JPGs and other declared assets instead. |
| Cold startup 2,150–3,400ms | P1 High (originally) | 🟡 **Not independently re-verified this pass** | Requires an actual profiled run on a device/emulator, which wasn't done this pass — carrying forward as open, flagging that this is the one finding in the whole report that genuinely needs a device, not just a code read, to confirm. |

---

## 2. Why this matters for a public launch specifically (not just "feels laggy in dev")

Two of these compound each other in a way worth being explicit about: the `context.watch<AppProvider>()` pattern means the 60-second live-viewer poll (finding 4 above) doesn't just cost N sequential HTTP calls — each time `_pollLiveViewers()` finds a changed count and calls `notifyListeners()`, it re-triggers a full rebuild of every screen using `context.watch<AppProvider>()`, including the map's O(N²) collision engine (finding 3) if the map happens to be the active tab. On a mid-tier Android device — the device profile most of your actual Saudi audience will be using, not a flagship test phone — this is the kind of thing that shows up as visible jank during a live lecture specifically, which is the core use case of the app. This isn't a "nice to have polish" list; it's the difference between the map/feed feeling smooth or stuttering during exactly the moment (a live broadcast) the app is supposed to shine.

---

## 3. Priority order (feeds Phase 8)

1. **Batch the live-viewer polling loop** — smallest fix on this list relative to impact; the pattern already exists in the same file.
2. **Add `cacheWidth`/`cacheHeight` (or `ResizeImage`) to `safe_image_provider.dart`** — one shared function, used everywhere avatars/banners render, so one fix propagates app-wide. Also compress or replace the two oversized source JPGs regardless (5.23 MB and 2.52 MB have no reason to exist as shipped assets even with caching in place).
3. **Scope `context.watch<AppProvider>()` down to `context.select`/`Selector`** across the 7 identified screens — larger refactor, biggest structural win, best done as its own focused pass rather than piecemeal.
4. **Move the map collision resolution off the synchronous build path** (memoize between actual pan/zoom changes, or move to a compute isolate) — real fix, but lower urgency than #1–3 since it only bites when the map tab is active with multiple nearby streamers.
5. **Delete the orphaned HTML file** for repo hygiene — not a performance fix, just cleanup, downgraded from the original report's framing.
6. **Confirm controller-disposal leaks and cold-start timing on a real device** before Phase 8's final checklist closes this phase out.

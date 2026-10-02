# Performance, Runtime & Caching Audit — Hadayah Live (`project/`)

- **Date:** 2026-09-28
- **Scope:** `project/` (Flutter app: `lib/`, `web/`, `pubspec.yaml`, assets), plus the few backend/hosting facts the app's runtime cost depends on (`supabase/migrations`, `vercel.json`, `scripts/build_vercel_web.sh`).
- **Focus:** runtime smoothness on low-end phones and on laptops (web + Windows), rebuild/flow cost, network polling, caching (memory, disk, HTTP, CDN, service worker), images/assets, map rendering, live room, build/packaging.
- **Fix pass 2026-10-02:** see [`2026-10-02_AUDIT_FIX_LOG.md`](2026-10-02_AUDIT_FIX_LOG.md). It supersedes the "nothing is done" status in §12 below: about two thirds of the findings are fixed or partly fixed, the rest are listed there with reasons.
- **Revision 2026-10-02:** status of every finding re-checked against the code (new **§12**), and additional findings from the Organization V1 work and the hosted Supabase advisors added (new **§13**, IDs `DB-*`, `NET-11/12`, `WEB-03..05`, `RT-10`). The original findings below are unchanged.
- **Mode:** read-only. **No file in the codebase was changed.** One behaviour was verified in a throwaway sandbox in the session scratchpad (see Appendix A); it has been stopped and removed from the browser pane.
- **Method:** full read of `AppProvider`, router, discovery feed, spatial map, map pack, live room, chat, presence, YouTube service, DB service hot paths, web shell/service worker; targeted greps across all 162 Dart files; package source check (`provider 6.1.5+1`); asset measurement; local Android debug build output (`build/flutter_assets`).

> Line numbers refer to the working tree on 2026-09-28 (uncommitted changes included). The request-rate figures are **estimates derived from the timers in the code**, not measured traffic. Every item says what evidence backs it.

---

## 0. Executive summary

The app is functionally careful (truthful data, race guards, offline fallbacks), but its **runtime cost model is "poll everything, notify everyone, rebuild everything"**. Three structural issues drive most of the jank and backend load:

1. **One giant `ChangeNotifier` + selectors that never compare equal.** `AppProvider` has 147 `notifyListeners()` call sites. The main screens use `context.select`, but they select *freshly allocated lists* (and in the feed, a Dart record holding lists). `provider` compares with `DeepCollectionEquality`, `StreamerModel` has no `==`, and records fall back to `==` — so the **Discovery feed rebuilds on every single provider notification**, and the map rebuilds on every catalog reload. The live room uses `context.watch` and additionally `setState`s the whole 2,500‑line screen on every chat message. GoRouter's `refreshListenable` is the same provider, so every notification also re-runs route parsing + redirect.
2. **Aggressive client polling with no shared freshness strategy.** An idle viewer on the feed reloads the *entire* public catalog (two full-table selects, plus a sweep RPC every minute) about every 30 s; a viewer in a live room does it every 20 s, plus a presence heartbeat (20 s), a count poll (15 s), a connectivity probe (15 s) and viewer counts (30 s). **Every client, including guests, also polls the YouTube Data API once per live stream per minute**, for a number only the broadcaster studio shows — this alone can exhaust the shared 10,000-unit daily quota with a handful of open clients.
3. **No image downsampling and a bloated bundle.** No image in the app sets `cacheWidth`/`cacheHeight`; 4000‑px JPEGs (48 MB and 36 MB decoded) are used as default avatars; 17 MB of unused logo PNG/SVG ship inside the app (`flutter_assets` = 41 MB). Uploaded banners are 3× PNG screenshots with the default 1‑hour cache.

And one **verified web reliability bug**: the custom service worker aborts *any* intercepted response that takes longer than 4 s in total (verified: 12 MB over 8 s → `AbortError` at 4.0 s). On a slower connection the 12 MB map pack (and, on repeat visits, large engine/app files) fails to load.

### Findings at a glance

Severity: **P0** = breaks something or scales badly now · **P1** = visible jank / heavy waste · **P2** = meaningful, fix when touching the area · **P3** = polish.

| ID | Sev | Area | One-line finding |
|---|---|---|---|
| RT-01 | P0 | Rebuilds | `context.select` on fresh lists/records never compares equal → feed rebuilds on every notify, map on every catalog load |
| RT-02 | P1 | Rebuilds | Live room: `context.watch` + full-screen `setState` per chat message / slow-mode tick / presence update |
| RT-03 | P1 | Rebuilds | GoRouter `refreshListenable: provider` → route parse + redirect on every one of 147 notify sites |
| RT-04 | P1 | Rebuilds | 20 s device heartbeat → Realtime echo → re-read → provider-wide `notifyListeners()` for every approved broadcaster |
| RT-05 | P2 | Rebuilds | Other whole-provider watchers (mini-player in the shell, profile, settings sections, apply step 3) |
| RT-06 | P2 | Rebuilds | 38 `MediaQuery.of(context)` sites (incl. the app shell) rebuild on keyboard/inset changes |
| RT-07 | P2 | CPU | `filteredStreamers` recomputed in selectors on every notify; search has no debounce; `getStreamerById` is a lowercase linear scan |
| RT-08 | P2 | Rebuilds | Phone studio: encoder bitrate event (~1/s) → whole 2,300-line studio `setState` while the phone is encoding |
| NET-01 | P0 | Polling | Every client polls YouTube `videos.list` per live stream per minute → shared quota exhaustion |
| NET-02 | P0 | Polling | Full public catalog re-downloaded every 20–30 s per client; liveness has no cheap endpoint |
| NET-03 | P1 | Polling | Live room runs 4 independent pollers (catalog 20 s, heartbeat 20 s, count 15 s, probe 15 s) |
| NET-04 | P1 | Flow | Catalog read waits up to 2 s for a stale-flag sweep RPC; the two catalog queries run in series |
| NET-05 | P1 | Flow | Startup and sign-in are long chains of serial round-trips (admin data loaded for guests too) |
| NET-06 | P1 | Flow | Chat `start()` makes 8 serial calls before the room subscribes |
| NET-07 | P1 | Flow | Live room fires a Supabase query from `build()` when a streamer has no custom card (negative result never cached) |
| NET-08 | P2 | Realtime | Chat DELETE subscription is unfiltered → every viewer receives every stream's deletes |
| NET-09 | P2 | Polling | Connectivity probe: new `http.Client` (new TLS handshake) every 15 s |
| NET-10 | P2 | Admin | Audit logs / applications / reports loaded unbounded, reloaded on many Realtime events; tag usage is N+1 |
| CA-01 | P1 | Cache | Catalog + marker snapshots JSON-encoded and written to SharedPreferences after *every* successful load (~every 20–30 s) |
| CA-02 | P1 | Cache | Uploaded images: no `cacheControl` (Supabase default 1 h) although paths are immutable |
| CA-03 | P2 | Cache | Network images use `NetworkImage` (memory only) — no disk cache on Android/Windows; `cached_network_image` is a dependency but used in one unused-looking widget |
| CA-04 | P2 | Cache | YouTube channel lookups (`fetchChannelDetails`) uncached; profile open clears and refetches |
| CA-05 | P2 | Cache | Vercel serves everything `max-age=0, must-revalidate` (no headers configured) |
| IMG-01 | P0 | Memory | No `cacheWidth/cacheHeight` anywhere: avatars/banners decode at full resolution |
| IMG-02 | P1 | Memory | 4000‑px default avatars (48 MB + 36 MB decoded) in the apply flow and admin hub |
| IMG-03 | P1 | Uploads | Broadcaster avatar/banner picked without `maxWidth`, re-encoded as 3× **PNG** |
| IMG-04 | P3 | CPU | `File.existsSync()` inside `build` (image resolver) |
| AS-01 | P1 | Bundle | `assets/logo/` bundles 17 MB of unused PNG/SVG; Amir JPEGs add 8 MB; `flutter_assets` = 41 MB |
| AS-02 | P2 | Bundle | Web build uses `--no-tree-shake-icons` (no dynamic `IconData` found) → full icon font shipped |
| MAP-01 | P1 | Map | Markers re-clustered and rebuilt on **every camera frame**, although clustering only depends on zoom |
| MAP-02 | P2 | Map | One repeating `AnimationController` per live marker; RepaintBoundary outside the animation |
| MAP-03 | P2 | Map | Tile caches sized 24 MB + 96 MB regardless of device class |
| MAP-04 | P2 | Map | 12 MB archive kept resident forever and re-hashed on every cold open; web downloads all 12 MB up front |
| LIVE-01 | P1 | Chat | `_messages` unbounded; `messages` getter filters + copies the whole list on every access (≥3×/notify) |
| LIVE-02 | P2 | Overlay | Floating reactions: no cap, `Opacity` + blurred shadow per particle over a platform view |
| LIVE-03 | P3 | Overlay | `BackdropFilter` blur (σ 14–16) in the studio sheet over camera/WebView |
| WEB-01 | P0 | Web | Service worker aborts intercepted downloads after 4 s total and buffers every body (**verified**) |
| WEB-02 | P2 | Web | No first-paint loading UI in `index.html`; consider `--wasm` renderer |
| ST-01 | P3 | Startup | `await Supabase.initialize()` before `runApp`; ThemeData rebuilt per locale build |
| LOG-01 | P3 | Runtime | 178 `debugPrint` calls stay active in release, some on per-rebuild paths |

---

## 1. Request-rate model (estimated from code timers)

Per **idle signed-out viewer with the Feed tab visited** (and Map visited once):

| Source | Interval | Calls |
|---|---|---|
| Feed + Map `_catalogFreshnessTimer` → `refreshCatalogIfOlderThan(30 s)` | ~30 s | 2 full selects (`streamer_public_profiles`, `organization_public_profiles`) |
| `sweep_stale_live_flags` RPC (inside the catalog load) | 60 s | 1 RPC |
| Connectivity probe `GET /rest/v1/` | 15 s | 1 HTTPS request, new connection each |
| Viewer counts `get_viewer_counts` (only if something is live) | 30 s | 1 RPC |
| YouTube `videos.list` per live stream (`_pollLiveViewers`) | 60 s | 1 external call **per live stream** |

≈ **11–13 Supabase requests/min per idle client**, plus YouTube calls.

Per **viewer inside a live room** (same client, room open): the room's own 20 s catalog reload, presence heartbeat (20 s), presence count (15 s), probe (15 s), viewer counts (30 s) → ≈ **20 requests/min/viewer ≈ 0.33 req/s**, each catalog read returning the *whole* public catalog. At 1,000 concurrent viewers that is ~330 req/s, ~100 of which are full-catalog reads, just to learn whether one stream is still live.

Per **approved broadcaster** add: device heartbeat (20 s) + the Realtime-triggered `device_sessions` re-read (20 s).

---

## 2. State management & rebuilds

### RT-01 — Selectors that never compare equal (P0)

**Where:**
- `lib/core/providers/app_provider.dart:2485` `streamers => List.unmodifiable(_streamers)`; `:2486` `liveStreamers` (`.where().toList()`); `:4232` `filteredStreamers` (`.where().toList()`); `:175` `cachedMapMarkers`; `:2473` `pendingApplications`; and every other `List.unmodifiable(...)` getter.
- `lib/features/discovery/presentation/discovery_feed_screen.dart:166-195` selects a **record** `(String, List, List, bool, bool, BroadcastType, int, String)`.
- `lib/features/map/presentation/spatial_map_screen.dart:547-568` selects `filteredStreamers`, `streamers`, `cachedMapMarkers`.
- Admin views: `org_admin_screen.dart:34`, `academic_categories_view.dart:472`, `banned_accounts_view.dart:203`, `chat_moderation_view.dart:260,378`, `role_permission_management_view.dart:137,211`, `tag_moderation_view.dart:106`.

**What happens (verified in package source):** `provider 6.1.5+1` `SelectContext.select` (`inherited_provider.dart:~295`) re-runs the selector on every notification and rebuilds when `!DeepCollectionEquality().equals(new, old)`.
- A **record** is not a collection, so it falls through to `==`; record `==` compares fields with `==`; `List ==` is identity; the getters allocate a new list every call → **the feed's selector is unequal on every notification** → the entire feed (hero, horizontal list, category chips, and the full streamer grid, see RT-09) rebuilds for every `notifyListeners()` anywhere in the app: heartbeats, notifications, toasts, mini-player, chat-report events, device sessions, viewer counts…
- For plain lists, deep equality compares elements with `==`; `StreamerModel` and `MapMarkerModel` do **not** override `==` (grep: no `operator ==` in `streamer_models.dart`/`map_models.dart`), and every catalog load builds brand-new instances → **the map screen rebuilds on every catalog load** (every 20–30 s, see NET-02), and `cachedMapMarkers` are also re-instantiated on every persist (`app_provider.dart:2363`).
- The code comments claim the opposite ("only rebuilds when contents actually change", `discovery_feed_screen.dart:159-164`, `spatial_map_screen.dart:543-546`). They are wrong for records and for model lists.
- Selector cost itself: each notification runs `filteredStreamers` (full filter with lowercasing, see RT-07) for the feed *and* the map, then a deep comparison.

Offstage branches of `StatefulShellRoute.indexedStack` still rebuild (Offstage skips paint, not build), so the hidden tab pays this too.

**Phones:** each rebuild re-lays out the whole non-virtualized grid → dropped frames while scrolling, typing, or while a live stream plays underneath. **Laptops:** less visible but constant CPU wake-ups.

**Fix direction:**
1. Give `StreamerModel`/`MapMarkerModel` value equality (or a cheap `revision`/`updatedAt` field) *or* keep list identity stable: cache derived lists in the provider and only replace them when inputs change (memoize `filteredStreamers` on `(_streamers identity, category, tag, query, visibility)`).
2. Never select records containing collections; select primitives (`successfulCatalogRevision`, counts) plus stable list instances, or split into several `select` calls.
3. Longer term: split `AppProvider` into focused notifiers (Auth/Session, Catalog, Broadcast/Device, Notifications, Admin) so unrelated changes do not reach catalog screens at all. Riverpod/`ValueListenable`s are both viable; the smallest step is multiple `ChangeNotifier`s behind `MultiProvider`.

### RT-02 — Live room rebuilds the world (P1)

**Where:** `lib/features/live_stream/presentation/live_broadcast_screen.dart`
- `:741` `context.watch<AppProvider>()` in `build` — the room rebuilds on *every* provider notification (including the catalog reload the room itself triggers every 20 s, `:335`).
- `:473-477` `_handleChatConnectionChange` → `setState(() {})` on **every chat controller notification** (each message, edit, delete, status change, and the 1 s slow-mode tick `live_chat_controller.dart:311-313`). The chat tab already has a scoped `ListenableBuilder` (`:1358`), so this `setState` defeats it and rebuilds the video viewport, header and tab panel as well.
- `:374-376` presence count change → full `setState`.
- `:1418` `_chatController.messages.reversed.toList()` — a third full copy per build (see LIVE-01).
- `:231` the room also `addListener`s the provider (`_syncRoomConnection`), doing catalog lookups on every notification.

**Impact:** on a phone the player is a WebView platform view; rebuilding/relayouting the surrounding tree on every chat message during a busy lecture is the most likely source of "chat makes the stream stutter" reports. On laptops it inflates CPU while watching.

**Fix:** replace `watch` with narrow `select`s of primitives (streamer by id + `successfulCatalogRevision`, `isLoggedInStreamer`, `isStreamerModeEnabled`, `streamReloadCount`); remove the `setState` in `_handleChatConnectionChange` (keep only the unread counter update, and rebuild just the "new messages" pill via a `ValueNotifier`); wrap the viewport in a `RepaintBoundary`; presence count via `ValueListenableBuilder`.

### RT-03 — Router refreshes on every notification (P1)

**Where:** `lib/core/routing/app_router.dart:54` `refreshListenable: provider`.

GoRouter re-parses the current location and re-runs `redirect` (`:55-134`) on each of the 147 notify sites (heartbeats, chat reports, toasts…). The redirect only reads ~8 auth/role/ban fields.

**Fix:** expose a dedicated `Listenable` (e.g. a `ValueNotifier<AuthRouteState>` updated only when `isLoggedInStreamer`, `authHydrating`, `hasCompletedRoleSelection`, `isApprovedStreamer`, `isAdminUser`, `adminRoleLoading`, `isPermittedAdmin`, `isCurrentUserBanned`, `myApplication != null` change) and pass that instead.

### RT-04 — Device heartbeat echo (P1)

**Where:** `app_provider.dart:915-916` heartbeat every 20 s → `device_heartbeat` RPC does `UPDATE device_sessions SET last_active_at` (`supabase/migrations/20260920120000_guarded_broadcast_sessions.sql:66`); `device_sessions` is in the Realtime publication → `watchDevices` re-selects the rows (`admin_database_service.dart:2974-2983`) → `applyDeviceSessions` → `notifyListeners()` (`app_provider.dart:1043`) **every 20 s** even though nothing changed.

Combined with RT-01/RT-03 this is a guaranteed full feed rebuild + router refresh every 20 s for every approved broadcaster, plus 2 extra requests/20 s.

**Fix:** in `applyDeviceSessions`, compute the new `(primaryDeviceId, isPrimary, remote)` tuple and return early when unchanged; optionally filter Realtime to `UPDATE`s that change `is_primary_broadcaster` (or stop publishing `last_active_at`-only updates by moving the heartbeat timestamp to a separate unpublished table).

### RT-05 — Other whole-provider watchers (P2)

`context.watch<AppProvider>()`/`Provider.of(context)` in: `core/widgets/floating_stream_mini_player.dart:50` (mounted in the **app shell** on every tab, `app_router.dart:496`), `profile/presentation/broadcaster_profile_screen.dart:71`, `settings/*_section.dart` (4 sections), `auth/role_select_screen.dart:14`, `auth/screens/account_banned_screen.dart:25`, `discovery/widgets/tags_filter_bottom_sheet.dart:25`, `live_stream/widgets/rtmp_ip_dialog.dart:680,1404`, `phone_broadcast_screen.dart:1080,1919`, `admin/widgets/custom_placeholder_review_view.dart:148`, `profile/widgets/join_org_modal_sheet.dart:96`, `profile/widgets/custom_stream_cards_section.dart:156`, `auth/steps/apply_step_3_professional.dart:543,574,582` (three `watch` calls **inside `.where` lambdas**), `discovery_feed_screen.dart:470`, `spatial_map_screen.dart:631`.

The mini-player one matters most: it returns `SizedBox.shrink()` when inactive, but still rebuilds on every notification on every screen. Use `select` for `isMiniPlayerActive`, title, audio flag.

### RT-06 — `MediaQuery.of(context)` (P2)

38 call sites (grep). `MediaQuery.of` subscribes to *every* MediaQuery field, so opening the on-screen keyboard (viewInsets change, animated per frame) rebuilds those widgets each frame. Most important: the app shell `app_router.dart:300` (rebuilds the shell and bottom nav during keyboard animation on phones), `spatial_map_screen.dart:564`, `live_broadcast_screen.dart:786`, `floating_stream_mini_player.dart:53`. Replace with `MediaQuery.sizeOf`, `paddingOf`, `viewInsetsOf`, `orientationOf`, `accessibleNavigationOf`.

### RT-07 — CPU in hot getters (P2)

- `filteredStreamers` (`app_provider.dart:4232-4293`): per element it lowercases 5+ strings, evaluates `currentUserStreamerId` (walks `_myApplication`/session) and may call `currentUserHandle`; it is re-run by two selectors on every notification (RT-01).
- Search: `discovery_feed_screen.dart:328` `onChanged → setSearchQuery` → `notifyListeners()` on **every keystroke**, i.e. a full-app notify per character. Debounce (~250 ms) and keep the query local to the feed.
- `getStreamerById` (`app_provider.dart:2803-2815`) is a linear scan that lowercases and `replaceAll`s every streamer's handle per call; it is called from builds (live room `_findStreamer`, profile, markers, `_closeMiniPlayerIfBroadcastEnded`). Keep `Map<String, StreamerModel>` indexes by id / activeStreamId / normalized handle, rebuilt once per catalog load.
- `enhancedNotifications`, `notifications`, `unreadNotificationsCount` (`:2588-2609`) mutate state (`removeWhere`) inside getters that selectors call on every notification.

### RT-08 — Phone studio rebuilds on every encoder sample (P2)

`rtmp_publish_engine.dart:542-544` notifies on each `bitrate` event (~1/s; `audioLevel` events would be far more frequent when the native side starts emitting them, `:546-556`) → `phone_broadcast_screen.dart:462-469` `setState(() {})` on the entire 2,325-line studio, while the same phone is encoding camera video (thermal/CPU-sensitive). Also `:91` provider `addListener` and `:159` chat `setState`. Expose bitrate/level as `ValueListenable`s and rebuild only the stats chip.

### RT-09 — Feed grid is not virtualized (P1, phones)

`discovery_feed_screen.dart:295` uses `ListView(children: [...])` and the grid is a `Table` (`:530-558`) with one `TableRow` per row of cards. Every card (and its banner/avatar image) is built, laid out and decoded up front, and **again on every rebuild** (RT-01). With a growing catalog this is O(n) work per notification. Use `CustomScrollView` + `SliverGrid`/`SliverList.builder` (with a fixed `childAspectRatio` or `SliverGrid` with `mainAxisExtent`), keep the header widgets as slivers.

---

## 3. Network, polling & flows

### NET-01 — Every client polls the YouTube Data API (P0)

**Where:** `main.dart:62` → `ensureLivePollingActive()` for **every** client; `app_provider.dart:2192-2200` 60 s `Timer.periodic`; `:2413-2433` loops live streamers **sequentially**, one `videos?part=liveStreamingDetails&id=…` per stream (`youtube_api_service.dart:379-383`). The only consumer is the broadcaster's own studio (`phone_broadcast_screen.dart:1547`).

**Cost:** 1 unit/call × 1,440 min/day × live streams × open clients. One 24/7 stream (the code references an always-on Quran stream, `app_provider.dart:4072-4079`) with 7 clients open all day = 10,080 units = the whole default daily quota. When the shared key is exhausted, broadcaster-facing features that depend on it fail too (`findMyLiveBroadcast` 100 units, `verifyWatchLink`, channel validation during applications).

**Fix:** poll only in the broadcaster studio, only for the broadcaster's own stream, only while it is visible; batch ids (`videos.list` accepts 50 ids per call); better, move it server-side (one scheduled Edge Function writing a column) so N clients cost 1 call.

### NET-02 — Full catalog as the liveness signal (P0)

**Where:** `discovery_feed_screen.dart:48-55` (15 s timer, 30 s age), `spatial_map_screen.dart:97-103` (same), `live_broadcast_screen.dart:335-340` (20 s, unconditional), `:298-312` lookup backoff; `app_provider.dart:1933-2011`; `admin_database_service.dart:1370-1552` does `select()` of **all columns** (bios in two languages, tags, banners…) with **no limit/pagination**, for both tables.

The comment at `app_provider.dart:1919-1922` explains why: profiles RLS means other accounts' live changes never arrive over Realtime. The consequence is that liveness is learned by re-downloading the directory.

**Fix (in order of effort):**
1. Add a tiny public RPC/view `live_now()` returning only `(id, is_live, broadcast_type, active_stream_id, live_session_id, ingest_state, updated_at)` for live rows; poll *that* every 20–30 s and patch `_streamers` in place; reload the full catalog only on app start, pull-to-refresh, resume after >5 min, or when `live_now` shows an unknown id.
2. Better: publish liveness through a Realtime **broadcast** channel (`live_state`) from `start/end_broadcast_session` (server-side `realtime.send`/trigger), which bypasses the RLS limitation without exposing rows. Keep a slow (2–5 min) poll as a safety net.
3. Select explicit columns; add `updated_at` and use `If-None-Match`/`gt('updated_at', last)` delta reads.
4. Pause these timers when the tab is not visible (`TickerMode.valuesOf(context).enabled`), when a pushed route covers the shell, and when the app is backgrounded.

### NET-03 — Live room pollers (P1)

`viewer_presence_service.dart:33-34`: heartbeat every 20 s + count every 15 s as two separate RPCs, plus the room's 20 s catalog reload (NET-02) and the global 15 s probe (NET-09). Merge into **one** `viewer_heartbeat` RPC that returns `{count, is_live, live_session_id}`; that single 20 s call can replace the room's catalog poll for the end-of-broadcast check (`_syncRoomConnection`).

### NET-04 — Catalog critical path (P1)

`app_provider.dart:1960-1973`: once a minute the catalog read **waits up to 2 s** for `sweep_stale_live_flags` before it starts; then `admin_database_service.dart:1380` and `:1471` run the two table reads **in series**. Run the sweep fire-and-forget (or server-side via `pg_cron`, which removes it from every client), and `Future.wait` the two selects. On high-latency mobile links this halves time-to-content.

### NET-05 — Serial chains at startup and sign-in (P1)

- `_initAdminDatabase` (`app_provider.dart:2123-2132`): catalog → `refreshAdminData` (5 **sequential** awaits: applications, terms, analytics, audit logs, affiliation requests, `:2173-2187`) → categories → tags. This runs for **every client including guests**; RLS returns empty sets but each is still a round-trip, and categories/tags (needed by the feed chips and map filter) wait behind all of them. Gate admin loads on `isAdminUser`, parallelize with `Future.wait`, and load categories concurrently with the catalog.
- `_applySessionUser` (`:548-625`): ensureProfileRow → prefs → consent → admin RPCs → permitted orgs → ban status → library (2 sequential selects, `:4203-4204`) → application/profile status (3 sequential selects, `:1612-1614`, **which itself reloads the catalog** `:1734`) → admin data → device claim. ≈ 12–15 serial round-trips before `authHydrating` clears, and the router holds the user on `/splash` while it is true (`app_router.dart:58-64`). Only role/ban are needed to route; run the rest in parallel after routing.
- `onAppResumed` (`:1289-1303`): ban → status (+catalog) → heartbeat → catalog again.

### NET-06 — Chat start latency (P1)

`live_chat_controller.dart:385-411`: block list → app flags → hidden messages → `chat_can_moderate` → settings → `is_current_user_banned` → `chat_is_muted` → last 100 messages, **all sequential**, and only then `_subscribe()`. On a 150 ms RTT link that is >1 s before the first message and before live inserts are received (inserts during that window are also missed). Subscribe first, then `Future.wait` the reads; merge the three self-status RPCs into one.

### NET-07 — Query from `build()` with no negative cache (P1)

`live_broadcast_screen.dart:561-576` calls `ensureApprovedPlaceholderLoaded` from a post-frame callback scheduled **inside `build`** whenever no custom card URL is cached. `app_provider.dart:5497-5515` only caches hits; a miss leaves the key absent (the doc comment says the opposite), so **every rebuild of the room issues another Supabase query** for streamers without artwork — and the room rebuilds on every chat message (RT-02). Cache misses (e.g. store `''` or a `Set` of checked keys) and trigger the load once from `initState`/state transitions.

### NET-08 — Unfiltered DELETE subscription (P2)

`live_chat_controller.dart:682-687` subscribes to `chat_messages` DELETE events **without a filter** (because the table is not `REPLICA IDENTITY FULL`). Every viewer of every stream receives every delete on the platform. Options: make the table `REPLICA IDENTITY FULL` and filter by `stream_id`; or switch deletions to soft-delete (`UPDATE deleted_at`) which the existing filtered UPDATE subscription already carries; or send a Realtime broadcast on the stream's channel from the delete trigger.

### NET-09 — Connectivity probe (P2)

`core/services/connectivity_service.dart:22` probes every 15 s while foregrounded; `:83-90` creates and closes a new `http.Client` per probe → new TCP+TLS handshake every 15 s (radio wake-ups on phones, battery). Reuse one client (keep-alive), use `HEAD`, back off to 60 s while stable, and skip the probe when any Supabase request succeeded in the last interval.

### NET-10 — Admin data volume (P2, admin devices)

`admin_database_service.dart:601-608` `audit_logs` select with **no limit**; `:156-162` applications no limit; chat reports, banned users, moderators likewise. `refreshAdminData` reloads all five on each `profiles`/`organizations`/`broadcaster_applications` Realtime event for admins (`app_provider.dart:1845-1870`) — an admin's device re-downloads the whole audit history whenever any profile changes. `_refreshTags` (`:5186-5202`) issues one count query **per approved tag** (N+1). Paginate (`range`), debounce Realtime-triggered refreshes (e.g. 2 s), aggregate tag counts in one RPC/view.

---

## 4. Caching

### What already works (keep it)

- Catalog load de-duplication with a single follow-up read (`app_provider.dart:1933-1954`); `refreshCatalogIfOlderThan`.
- Public catalog + marker snapshots on disk for offline cold start (`public_catalog_cache.dart`, `_loadMapMarkerCacheFromDisk`).
- Categories loaded once per session; viewer counts throttled to 30 s; ingest reports de-duplicated (`:1165-1168`).
- YouTube VOD/playlist results cached in memory per `streamerId:handle` (`youtube_api_service.dart:59-60`).
- Map pack: vector-tile decoded/raster caches keyed by pack hash; no second disk copy.

### CA-01 — Snapshot writes on every load (P1)

`app_provider.dart:2004-2007`: after **every** successful catalog load (every 20–30 s, NET-02) both `_persistPublicCatalogIfReady` (`public_catalog_cache.dart:24-34`, full catalog incl. bios → `jsonEncode` → `SharedPreferences.setString`) and `_persistMapMarkerCache` (`:2347-2370`, `jsonEncode` + two `setString`s + re-decode of every marker) run. On Android, SharedPreferences rewrites the whole XML file; on web, `localStorage.setItem` is **synchronous on the UI thread**; `jsonEncode` of a large catalog is main-isolate work. Write only when a content hash changed, and at most every few minutes; move encoding to `compute` for large catalogs; consider a single store (the marker cache can be derived from the catalog snapshot, as `restorePublicCatalogFromDisk` already does).

### CA-02 — Storage objects cached for 1 hour only (P1)

`admin_database_service.dart:219-222` `uploadBinary(... FileOptions(contentType, upsert: true))` with no `cacheControl` → Supabase's default `max-age=3600`. Paths already embed a timestamp (`streamer_asset_path.dart`), so objects are immutable: set `cacheControl: '31536000'` (and drop `upsert` for new paths). This lets browsers/CDN and Flutter's HTTP stack reuse avatars and banners across sessions instead of revalidating hourly. Also note `contentType` defaults to `'image/jpeg'` while the cropper produces **PNG** (IMG-03).

### CA-03 — No disk image cache on native (P2)

`NetworkImage`/`Image.network` (27 sites; `safe_image_provider.dart:21,56`, `spatial_streamer_marker.dart:116`, `discovery_feed_screen.dart:636,725,826`, …) keep images only in the in-memory `ImageCache` (default 100 MB / 1,000 images). On Android/Windows every cold start re-downloads every avatar/banner/marker image. `cached_network_image` is already a dependency but is only used in `map_discovery_channel_card_marker.dart`, which nothing else in `lib/` or `test/` references (dead code). Route all remote images through one resolver that returns `CachedNetworkImageProvider` on native (with `maxWidth/maxHeight` hints) and `NetworkImage` on web (browser cache), wrapped in `ResizeImage` (IMG-01).

### CA-04 — YouTube lookups (P2)

`fetchChannelDetails` (`youtube_api_service.dart:70-81`) is never cached; it runs on every profile open (`broadcaster_profile_screen.dart:39-49` → `app_provider.dart:2830-2861`, which also **clears** the VOD/playlist cache first so the tabs flash empty), twice in `validateChannelConfiguration`, again in `verifyWatchLink` → `_resolveChannelId`. Cache handle→channelId (it never changes) in memory and SharedPreferences; keep VOD/playlist lists with a TTL (e.g. 10 min) instead of clearing on entry; show cached lists while refreshing.

### CA-05 — Hosting cache headers (P2, web)

`vercel.json` defines only a rewrite, so every file is served with Vercel's default `cache-control: public, max-age=0, must-revalidate` → every asset (fonts, i18n, SVGs, 12 MB map pack, `main.dart.js`) costs a revalidation round-trip on each visit. Add `headers`: long `max-age` + `immutable` for `/canvaskit/*` and content-addressed assets; short `max-age` with `stale-while-revalidate` for `/assets/*` (they are not content-hashed) and `no-cache` for `index.html`, `flutter_bootstrap.js`, `version.json`, the service worker.

---

## 5. Images & assets

### IMG-01 — Full-resolution decode everywhere (P0 on low-RAM phones)

`grep cacheWidth|cacheHeight|ResizeImage|memCacheWidth` → **0 hits**. A 36 px avatar (`StreamerAvatar`, `core/widgets/streamer_avatar.dart:40-53`), a 30 px map marker (`spatial_streamer_marker.dart:102-137`) or a card banner decodes the source at full size. Profile photos from Google/phones are routinely 1–12 MP → 4–48 MB each in the image cache; a feed of 30 cards can push low-end devices into cache thrash (images flicker/re-decode on scroll) or OOM, especially next to a WebView player and the 120 MB map tile budget (MAP-03).

**Fix:** one central helper that wraps providers in `ResizeImage.resizeIfNeeded(cacheWidth: (logicalSize * devicePixelRatio).round(), …)`; use it in `StreamerAvatar`, `StreamerIdentityCard`, markers, hero/horizontal cards, VOD tiles. Optionally lower `PaintingBinding.instance.imageCache.maximumSizeBytes` on low-memory devices.

### IMG-02 — Huge default avatars (P1)

`assets/images/Amir_Alhatemi/amir_person_pic.jpg` is 4000×3000 (5.4 MB file, **48 MB decoded**), `amir_card_pic.jpg` 4000×2252 (2.6 MB, **36 MB decoded**). They are defaults in `streamer_apply_screen.dart:40`, `apply_step_2_media.dart:172,233`, `apply_step_5_review.dart:198,204`, `apply_step_3_5_org_speakers.dart:43`, `admin_hub_screen.dart:1227,1616,1652,1989`, `broadcaster_application_model.dart:282-284`. Opening the apply flow allocates ~84 MB of decoded pixels for two placeholders. Resize to ≤512 px (avatar) / ≤1280 px (card) — or, consistent with the P2 "truthful data" direction, replace them with the neutral placeholders already in `assets/images/avatars/`.

### IMG-03 — Uploads are oversized PNGs (P1)

- `apply_step_2_media.dart:44-47,70-73` pick broadcaster avatar/banner with `imageQuality: 90` but **no `maxWidth/maxHeight`** (unlike `viewer_setup_screen.dart:49-50` and `viewer_profile_editor_dialog.dart:67-68`, which use 512). If the user skips cropping (`cropped ?? rawBytes`) the full camera original is uploaded.
- The cropper `image_arrange_modal.dart:104-105` renders `toImage(pixelRatio: 3.0)` and encodes **PNG** → multi-MB banners that every viewer downloads on every card, uploaded with `contentType: 'image/jpeg'`.

Target 512×512 avatars and ≤1280-wide banners as JPEG/WebP (~80 quality); set the correct content type. (Existing large uploads remain until re-uploaded; a one-off server-side resize job or Supabase Image Transformations `?width=` URLs would cover them.)

### IMG-04 — Sync file IO in build (P3)

`core/widgets/safe_image_provider.dart:24-27,57-61` call `File(...).existsSync()` during `build` for local paths (native). Cheap per call but it's disk IO on the UI thread on every rebuild of every avatar with a local path. Resolve once when the path is set.

### AS-01 — Bundle bloat (P1)

Measured in `project/build/flutter_assets` (Android debug build, 2026-09-27): **41 MB** total — `assets/logo` **17 MB**, `assets/maps` 12 MB, `assets/images` 8.2 MB, fonts 1 MB.
- `pubspec.yaml` lists the whole `assets/logo/` directory. Code only uses `assets/logo/colored.svg` and `black.svg` (`core/widgets/app_logo.dart:12-13`). Unused but bundled: `cercal.png` 6.1 MB, `square.png` 6.1 MB, `colored.png` 2.5 MB, `black.png` 1.9 MB, `logoInkscapeMaker.svg` 1.1 MB, plus `cercal.svg`/`square.svg`. List the two SVGs explicitly instead of the directory.
- `assets/images/Amir_Alhatemi/` 8 MB (IMG-02).
- The debug APK is 150 MB (debug builds include JIT/all ABIs; not representative), but the ~25 MB of removable assets carries straight into the release AAB and the per-install download. Also consider `--split-per-abi`/App Bundle (already default for Play) and checking `assets/Ahmed_Amer_YouTube.html` stays out of `pubspec` (it currently is out — good).

### AS-02 — Icon tree-shaking disabled on web (P2)

`scripts/build_vercel_web.sh:29` passes `--no-tree-shake-icons`. No dynamic `IconData(...)`/`codePoint` use exists in `lib/` (grep), so the full MaterialIcons font (~1.6 MB) is shipped instead of a few-KB subset. Remove the flag after a quick build to confirm no package needs it.

---

## 6. Spatial map

### MAP-01 — Re-cluster and rebuild markers every camera frame (P1)

`spatial_map_screen.dart:672-681` bumps `_cameraRevision` on every `onPositionChanged` (every pan/zoom/animation frame). Both marker layers are `ValueListenableBuilder`s on it (`:443-482`, `:998-1068`) and on each frame: run `clusterMapPoints` (projection of every venue + map/sort, `map_cluster_layout.dart:23-53`), rebuild every `Marker`/`SpatialStreamerMarker`, and re-translate each marker's semantics label (`spatial_streamer_marker.dart:182-186`, `.tr()` with named args).

`camera.projectAtZoom` projects to **absolute** world pixels at the current zoom, so the grid cells — and therefore the clusters — depend only on **zoom**, not on pan. Panning (the most common gesture) re-does identical work every frame.

**Fix:** memoize the clusters keyed by `(catalog revision, selected id, zoom quantized to e.g. 0.25)`; drive the layer from a `ValueNotifier<double>` of quantized zoom instead of `_cameraRevision`; `MarkerLayer` already repositions markers on pan by itself. Build marker widgets once per cluster result.

### MAP-02 — Per-marker animation controllers (P2)

`spatial_streamer_marker.dart:42-45,72-81`: every live (or selected) marker owns a repeating 1.8 s `AnimationController`; the `RepaintBoundary` (`:163`) wraps the `AnimatedBuilder`, so the whole marker (shadowed ring + image clip) repaints each frame, and the outer `AnimatedBuilder` runs even for non-selected live markers (scale stays 1). With many live venues this is N tickers + N repaints per frame on top of the vector map. Share one ticker for all pulses (a single `Animation` passed down), put the `RepaintBoundary` around only the pulse ring, and skip the outer builder when not selected. (Reduced-motion and `TickerMode` handling is already correct — keep it.)

### MAP-03 — Tile cache budgets not device-aware (P2)

`tricity_basemap_layer.dart:20-21`: `memoryCacheBytes = 24 MB`, `rasterCacheBytes = 96 MB`. The comment says "bounded so the map stays modest beside video playback", but 120 MB of tile caches plus the 12 MB resident archive (MAP-04) plus full-size images (IMG-01) is heavy on 2–3 GB phones (common low-end Android). Scale by device class / screen size (e.g. 32–48 MB raster on phones), and release caches when the map tab is left for a while.

### MAP-04 — Pack residency and verification (P2)

`map_pack_controller.dart:245-253`: on every cold open the 12 MB archive is loaded into memory and SHA-256'd; on native `Isolate.run` (`map_pack_platform_io.dart:9-10`) copies the 12 MB buffer into the isolate to hash it. The archive then stays resident for the process lifetime (by design, `:127-136`). Options: verify once per app build (store `packSha256 + appBuildId` in prefs after a successful check); on native, read ranges from the asset file instead of holding it all (or accept residency but only after the map is actually opened — it is lazy today, keep it that way).

On **web**, the whole 12 MB file is fetched before the first street renders, even though PMTiles is designed for HTTP range reads. Serving the pack as a normal static file and letting the PMTiles reader issue range requests (Vercel supports `Range`) would show the first tiles after a few hundred KB — and would sidestep WEB-01's timeout for this file.

---

## 7. Live room, chat & overlays

### LIVE-01 — Unbounded chat list and repeated copies (P1)

`live_chat_controller.dart:761` appends forever; there is no cap on `_messages`. `messages` (`:208-212`) filters blocked/hidden senders and copies the whole list **on every access**; per notification it is read at least three times (`_trackChatArrivals` `live_broadcast_screen.dart:1654`, the build `:1418` which then `.reversed.toList()`s a third copy, plus the tab badge). `_nextSendAllowedAt` (`:268-279`) scans all messages every time `composerState` is read (every build, and every second during slow mode). In a 2–3 hour busy lecture this grows into thousands of items and O(n) work per message.

**Fix:** cap at e.g. 300–500 messages (drop oldest); maintain the filtered, newest-first view incrementally (or memoize by a revision counter); track `lastOwnMessageAt` in a field.

### LIVE-02 — Unbounded floating reactions (P2)

`floating_reactions_overlay.dart:80-133` creates one `AnimationController` per incoming reaction, with no cap or coalescing; each particle uses `Opacity` (compositing layer) and a blurred `BoxShadow` (`:153-171`), drawn over the YouTube platform view. A burst of reactions from a large audience (they arrive by Realtime broadcast, `live_chat_controller.dart:719-726`) can mean dozens to hundreds of simultaneous animated layers. Cap concurrent particles (~15–20), coalesce bursts, use `FadeTransition`/`ScaleTransition` (no `Opacity` rebuild), drop the blur, add a `RepaintBoundary`.

### LIVE-03 — Backdrop blur over media (P3)

`rtmp_ip_dialog.dart:75-76,265-266` `BackdropFilter(ImageFilter.blur(σ 14/16))`. Backdrop blurs are among the most expensive effects on mobile GPUs, especially above a camera preview/WebView. Use a solid/translucent scrim on low-end devices or when media is behind.

---

## 8. Web platform

### WEB-01 — Service worker aborts downloads that take more than 4 s (P0, **verified**)

**Where:** `project/web/streamer_offline_sw.js:5` `NETWORK_TIMEOUT_MS = 4000`; `:21-29` `boundedFetch` aborts the request **and the body read** after 4 s and buffers the entire body (`arrayBuffer()`) before responding; `:80-125` every same-origin or `gstatic.com`/`fonts.gstatic.com` `GET` that is not `cache: 'reload'` goes through it (navigations and subresources).

**Evidence (Appendix A):** running the worker's own `boundedFetch` source against a throttled local server: 2 MB over 2 s → OK; **12 MB over 8 s → `AbortError` after 4,011 ms**; **7 MB over 6 s → `AbortError` after 4,003 ms**. (The built-in browser pane refused to register service workers, so the function was exercised with Node 22's WHATWG `fetch`/`AbortController`; interception scope is from code reading.)

**Impact:**
- The 12 MB `basemap.pmtiles` is fetched via `rootBundle.load` when the map opens; once the worker controls the page (it calls `clients.claim()` on activate, so also during the first visit), any connection slower than ~24 Mbit/s fails it → the map shows "missing asset".
- After a deploy, `main.dart.js` and other changed files on a slow connection can hit the same limit; CanvasKit from `gstatic` (≈7 MB wasm) too if not in HTTP cache.
- Even when it succeeds, buffering the whole body disables streaming compilation of wasm/JS and delays first byte to the page.

**Fix:** apply the timeout only to the time-to-headers (clear the timer when `fetch` resolves) and stream the body (`return response` directly); never intercept large immutable assets (pmtiles, canvaskit) or pass them through untouched when no offline generation is active; keep the offline-generation lookup for when the network fails.

### WEB-02 — First paint & renderer (P2)

- `web/index.html` shows nothing until Flutter's first frame (no inline splash/spinner); on slow phones that is several seconds of white screen. Add a lightweight inline HTML/CSS splash removed on `flutter-first-frame`.
- The build uses the default JS+CanvasKit renderer. `flutter build web --wasm` (skwasm, with automatic JS fallback) typically gives faster frames and startup on Chromium browsers; worth an A/B check given the map's vector rendering load. Requires cross-origin isolation headers on Vercel for multi-threaded skwasm.
- The `PerformanceObserver` in `index.html` (`:37-56`) tracks up to 3,000 resource URLs with an O(n) `indexOf` per entry — negligible, keep in mind if resource counts grow.

---

## 9. Startup & miscellaneous

- **ST-01 (P3):** `main.dart:19-24` awaits `Supabase.initialize` before `runApp`. It is usually fast (local session restore), but measure on a cold Android start; if it shows, render the splash first and initialize in parallel. `AppTheme.forLocale` (`app_theme.dart:92`) builds a new `ThemeData` (with `buildTextTheme`) on every `MaterialApp` build; cache one per locale.
- **LOG-01 (P3):** 178 `debugPrint` calls remain active in release (only rate-limited). Some sit on paths that repeat per rebuild or per failing image. Gate with `kDebugMode` or route through a logger that is silent in release.
- `_hashPlaceholderBytes` (`app_provider.dart:5543-5552`) loops over every byte of an upload on the UI isolate; on web the multiplication exceeds 2^53 so the result is also not a stable FNV hash (correctness side-note). Use `crypto` (already a dependency) in `compute`.
- `StreamDecayEngine`, `WatchSessionTracker` and the private-stream simulation code paths were not found to be hot at runtime.

---

## 10. Recommended plan (ordered by payoff ÷ effort)

**Wave 1 — quick, high payoff (≈1–2 days)**
1. NET-01: stop global YouTube polling (studio-only, own stream, batched).
2. WEB-01: service-worker timeout → headers only, stream bodies, bypass pmtiles/canvaskit.
3. RT-01 (minimal): memoize `filteredStreamers`/`liveStreamers`/`streamers` views on a catalog revision; select primitives in the feed instead of the record.
4. RT-02: remove the full-screen `setState` on chat notifications; replace `watch` with `select`s in the live room.
5. NET-07: cache placeholder misses; move the load out of `build`.
6. RT-04: early-return in `applyDeviceSessions` when nothing changed.
7. AS-01/IMG-02: bundle only the two logo SVGs; shrink/replace the 4000‑px defaults.
8. CA-02: `cacheControl` one year on uploads.

**Wave 2 — structural (≈1 week)**
9. NET-02/NET-03: `live_now` lightweight endpoint or Realtime broadcast for liveness; merge presence heartbeat+count+liveness; pause pollers when the tab/app is not visible.
10. IMG-01/CA-03: central image resolver with `ResizeImage` + disk cache on native.
11. RT-09: sliver-based virtualized feed grid.
12. MAP-01/MAP-02: zoom-keyed clustering; shared pulse ticker.
13. NET-04/NET-05/NET-06: parallelize startup, sign-in and chat start; gate admin loads to admins.
14. RT-03: dedicated router refresh listenable.
15. CA-01: write snapshots only on change.

**Wave 3 — hardening**
16. Split `AppProvider` into domain notifiers; LIVE-01 chat cap; LIVE-02 reaction cap; MAP-03/MAP-04 device-aware budgets and range-read pack on web; CA-04/CA-05 caching headers and YouTube lookup cache; RT-06 `MediaQuery.*Of`; IMG-03 upload sizing; AS-02; WEB-02; LOG-01.

---

## 11. How to measure before/after

- **Rebuild counts:** run `flutter run --profile` and use DevTools → *Performance* → "Track widget builds" while idle on the feed for 60 s; today expect feed rebuilds at least every 20–30 s (catalog), plus every heartbeat/notification. Target: zero rebuilds while idle.
- **Frame timing:** DevTools *Performance* on a low-end Android (2–3 GB RAM): scroll the feed, pan the map with ≥30 venues, and watch a live room with a chat bot posting 2 msgs/s. Track 90th-percentile raster/UI times (target < 16 ms).
- **Memory:** DevTools *Memory* → image cache size after opening the feed and the apply flow (IMG-01/IMG-02); expect a large drop after `ResizeImage`.
- **Network:** Supabase dashboard → API logs grouped by path per minute with N test clients idle / in a room; compare with Section 1.
- **YouTube quota:** Google Cloud console quota page over 24 h before/after NET-01.
- **Web:** Chrome DevTools, "Slow 4G" throttling, second visit with the service worker active: open the map and confirm the pack loads (WEB-01); Lighthouse for first paint (WEB-02).
- Keep `flutter analyze` at 0 and `flutter test` green; add widget tests that count builds (e.g. a build counter in a test wrapper) for the feed and live room so RT-01/RT-02 cannot regress.

---

## 12. Status check — what was done since 2026-09-28 (verified 2026-10-02)

Method: grep/read of the working tree at commit `5b4e991`. **Result: none of the performance findings has been implemented.** Everything above stands as written (the rest of the codebase moved on: Organization V1 added ~1,000 lines to `AppProvider` and more notify sites, but nothing here was fixed). Items marked *partial* have a small related change only.

| ID | Status | Evidence now |
|---|---|---|
| RT-01 … RT-09 | **Not done** | `AppProvider` is now 6,484 lines with **157** `notifyListeners()` (was 147); `refreshListenable: provider` still `app_router.dart:62`; live room still `context.watch<AppProvider>()` at `live_broadcast_screen.dart:778` |
| NET-01 | **Not done** | `ensureLivePollingActive()` still called for every client, `main.dart:67` |
| NET-02, NET-03 | **Not done** | no `live_now` RPC/view or broadcast channel exists (`grep live_now` only matches an unrelated drawer widget) |
| NET-04 | **Not done** | `sweep_stale_live_flags` still called from the client (`admin_database_service.dart:2937`, `admin_safety_backend.dart:151`) |
| NET-05 … NET-10 | **Not done** | not re-opened; no related commits |
| CA-01 … CA-05 | **Not done** | no `cacheControl` anywhere in `lib/`; `vercel.json` still has no `headers`; 29 `Image.network`/`NetworkImage` sites |
| IMG-01 | **Not done** | `cacheWidth/cacheHeight/ResizeImage` = **0 hits** in `lib/` |
| IMG-02 … IMG-04 | **Not done** | |
| AS-01 | **Not done (cosmetic change only)** | `pubspec.yaml:82-84` lists `assets/logo/` **and** the two SVGs — the directory line still bundles all of it; `assets/logo` is now **18 MB** |
| AS-02 | **Not done** | `--no-tree-shake-icons` still in `scripts/build_vercel_web.sh:37` |
| MAP-01 … MAP-04 | **Not done** | |
| LIVE-01 … LIVE-03 | **Not done** | `_messages.add` at `live_chat_controller.dart:761/854/1027` with no cap |
| **WEB-01** | **Not done — now matters more** | `streamer_offline_sw.js:5` still `NETWORK_TIMEOUT_MS = 4000`, still buffers via `arrayBuffer()` (`:26`). The site is now the live pilot URL, so real users will hit it |
| WEB-02, ST-01, LOG-01 | **Not done** | |

Because nothing is done, the **recommended plan in §10 is still the plan**; §13 adds items to slot into it.

---

## 13. Additional findings (2026-10-02)

Evidence: hosted Supabase **performance advisors** for `zkkmfjsjouqzibvnzkau` (read-only call, 2026-10-02 11:43 UTC), plus a read of the Organization V1 client/Edge/cron code and the web build. Note the hosted database is still on migration `20260930010000`; the V1 migrations (`20261001…`) are **not applied yet**, so the advisors below describe the pre-V1 schema and must be re-run after applying them.

### DB-01 — RLS policies re-evaluate `auth.uid()` per row (P1, backend)

Advisor `auth_rls_initplan`, **19 policies** call `auth.<fn>()` / `current_setting()` without the `(select …)` wrapper, so Postgres re-evaluates it for every row scanned instead of once per query. Tables: `chat_messages` (`insert_self`, `update_self`, `delete_self`, `respect_blocks`), `chat_user_blocks` (3), `chat_mute_audit_log` (2), `chat_reports`, `chat_muted_users`, `streamer_custom_placeholders` (3), `tags`, `stream_moderators`, `banned_users`, `device_sessions`, `application_review_events`. `chat_messages` is the hottest table in the app (the live room loads 100 rows per viewer), so this one compounds with NET-06.
**Fix:** one new migration that `alter policy`/recreates each with `(select auth.uid())` (mechanical, no behaviour change; the V1 migrations already follow this pattern). Re-run the advisor to confirm 0.

### DB-02 — 25 foreign keys without a covering index (P2, backend)

Advisor `unindexed_foreign_keys`. Most relevant for hot paths: `chat_messages.sender_id`, `broadcast_sessions.org_id`, `chat_reports.reporter_id / reported_sender_id`, `chat_muted_users.muted_profile_id / muted_by`, `chat_user_blocks.blocked_id`, `organizations.approved_application_id / active_live_venue`, `user_permissions.organization_id`, `schedule_reminder_deliveries.*`, `card_schedule_reminders.schedule_id`. The rest are `*_by`/`actor` audit columns (low priority; they only matter for cascading deletes of a profile, which is slow without them and is part of the account-deletion flow).
**Fix:** add `create index concurrently` for the first group now; the audit columns can wait.

### DB-03 — Multiple permissive policies on the same action (P2, backend)

Advisor `multiple_permissive_policies`, **14 cases** (e.g. `profiles` SELECT: `select_admin` + `select_own`; `profiles` UPDATE; `organizations`, `org_venues`, `org_speakers`, `tags`, `device_sessions`, `broadcaster_applications`, `user_roles` INSERT/UPDATE/DELETE, `chat_messages` DELETE). Postgres evaluates every permissive policy for each query. Merge each pair into one policy with `OR`. Low risk of behaviour change only if done carefully — the existing `supabase/tests/*.test.sql` suites cover most of these tables and must stay green.

### DB-04 — Unused indexes and Auth connection strategy (P3, backend)

21 `unused_index` INFO findings (`profiles_email_idx`, `profiles_is_streamer_idx`, `organizations_owner_idx`, `broadcast_sessions_stream`, `chat_reports_stream_created_idx`, `follows_target_idx`, …) and `auth_db_connections_absolute` (Auth capped at 10 connections, not a percentage). **Do not drop anything yet**: the hosted database has almost no traffic, so "unused" is meaningless until the pilot has generated real load; re-check after the three-show pilot. Switch Auth to a percentage strategy before any compute upgrade.

### DB-05 — Audit gap: V1 backend is unaudited on the hosted project (P1, process)

The V1 tables (`org_v1_*`, `broadcast_sessions` extensions, events) have only been checked in a disposable local database. After applying the migrations, re-run `get_advisors` (performance **and** security) and add a **load check** for: `org_v1_events` read path (called on sign-in, on every notification-center open and on the hub), `claim_org_v1_event_pushes`, `broadcast_reconcile_claim`. Confirm each has an index on its claim predicate (status + due time) — the V1 migrations create only five indexes in total.

### NET-11 — Per-profile 30 s polling of upcoming schedules (P2)

`upcoming_schedule_tab.dart:38-46` runs a 30 s `Timer.periodic` per open broadcaster profile that calls `loadUpcomingSchedules` (guarded by `TickerMode` and lifecycle, which is good). Schedules change rarely (hours/days). Poll at ≥ 5 min or refresh on resume/pull-to-refresh, and make the load a no-op unless the server `updated_at` changed. Also `refreshOrganizationEvents()` is triggered from four places (`app_provider.dart:806, 4377`, notification center, hub); it already has an in-flight guard, but add a minimum age (e.g. 60 s) so repeated opens do not each cost an RPC.

### NET-12 — Three per-minute cron jobs that mostly do nothing (P2)

`dispatch-upcoming-reminders` (`cron.sql`: `* * * * *`), plus the planned minute jobs for `reconcile-broadcasts` and `dispatch-organization-events` (hand-off step 2) = **~4,300 Edge Function invocations per day each**, ~13,000 total, while the pilot is idle. Each cold-starts a Deno isolate and a DB round-trip. **Fix:** let the cron SQL check cheaply first (`select … where exists (due rows)`) and only call `net.http_post` when there is work; or run the reconciler every minute only while a session is `live/starting` and every 5 minutes otherwise. The same `pg_cron` extension can also take over the client-called `sweep_stale_live_flags` (NET-04) at zero extra cost.

### WEB-03 — Vercel build downloads the Flutter SDK on every deploy (P2, DX/cost)

`scripts/build_vercel_web.sh:8-12` does a `git clone --depth 1` of Flutter 3.41.2 into `.vercel-flutter` whenever `flutter` is not on PATH, then `pub get` and a full release build — on Vercel's build machine with no persistent Flutter cache. Builds are therefore slow (minutes) and fail if GitHub/pub.dev is slow. **Fix:** build in GitHub Actions with a cached Flutter SDK + pub cache and deploy `build/web` with `vercel deploy --prebuilt`, or keep a pinned build image. Also add a build step that fails if `SUPABASE_URL`/`SUPABASE_ANON_KEY` are both empty on a production deploy (the previous production deployment silently shipped with **no backend**, see the handoff).

### WEB-04 — Web bundle size, no code splitting (P2)

Local release build: `main.dart.js` = **5.7 MB** (before brotli) and it now also carries `firebase_core/firebase_messaging`. The app uses **zero** `deferred as` imports, so the admin hub (2,715 lines), org management (1,355), phone broadcast studio (Android-only, but compiled into web), the application wizard and Firebase are all in the first download. **Fix:** `deferred` imports for admin/org-admin/phone-studio/Firebase routes (go_router builders can `await loadLibrary()`), and `kIsWeb` guards so the phone studio and RTMP bridge are not part of web at all. Pair with CA-05 (long-cache headers) so repeat visits skip the download.

### WEB-05 — Two service workers (P3)

`streamer_offline_sw.js` (scope `/`, the WEB-01 culprit) and `firebase-messaging-sw.js` (push). Confirm Firebase's worker registers under its own scope so the offline worker's `clients.claim()`/fetch interception never swallows push requests, and that a stale offline-worker generation cannot serve an old `firebase-messaging-sw.js`. Add this to the WEB-01 regression test (`tool/offline_worker.test.mjs`).

### RT-10 — `AppProvider` keeps growing (P1, structural)

`AppProvider` went from the audited size to **6,484 lines / 157 notify sites**; V1 added memberships, invitations, events and transfers, all as more fields on the same notifier, each of which re-triggers RT-01/RT-03. The Wave-3 split (Auth/Session, Catalog, Broadcast/Device, Notifications, Organization, Admin) should be **pulled forward** into Wave 2 — every further feature makes it more expensive. At minimum, put the new Organization V1 state (`_orgEvents`, invitations, memberships, transfer banners) in its own `ChangeNotifier` now, before more screens depend on it.

### Updated priorities

1. **Before wider use of the hosted pilot:** WEB-01 (service worker), NET-01 (YouTube quota), DB-01 (RLS initplan, one migration), DB-05 (advisors + load check after applying V1).
2. **Wave 1 additions:** NET-12 (cron guards), WEB-03 (build guard for missing Supabase config).
3. **Wave 2 additions:** RT-10 (split provider, pulled forward), WEB-04 (deferred imports), DB-02/DB-03 (indexes, merged policies), NET-11.
4. **After the pilot:** DB-04 (unused indexes), WEB-05.

---

## Appendix A — Sandbox verification of WEB-01

Throwaway files in the session scratchpad (`…/scratchpad/sw_test/`, not in the repo): an unmodified copy of `project/web/streamer_offline_sw.js`, a Node HTTP server streaming N MB over S seconds, and a script that extracts `NETWORK_TIMEOUT_MS` and `boundedFetch` **verbatim** from the worker source and runs them under Node 22:

```js
const src = fs.readFileSync('streamer_offline_sw.js','utf8');
const timeout = src.match(/const NETWORK_TIMEOUT_MS = (\d+);/)[0];
const fn = src.match(/async function boundedFetch\(request\) \{[\s\S]*?\n\}/)[0];
const boundedFetch = new Function(`${timeout}\n${fn}\nreturn boundedFetch;`)();
```

Output:

```
2 MB over 2 s -> OK 2097152 bytes in 2257 ms
12 MB over 8 s (map pack on ~12 Mbps) -> FAILED after 4011 ms: AbortError This operation was aborted
7 MB over 6 s (CanvasKit-size on ~9 Mbps) -> FAILED after 4003 ms: AbortError This operation was aborted
```

The server was stopped and the browser pane closed after the test. Nothing in the repository was touched.

## Appendix B — Asset measurements

| File | Pixels | File size | Decoded RGBA | Referenced by code |
|---|---|---|---|---|
| `images/Amir_Alhatemi/amir_person_pic.jpg` | 4000×3000 | 5.4 MB | 48 MB | yes (defaults) |
| `images/Amir_Alhatemi/amir_card_pic.jpg` | 4000×2252 | 2.6 MB | 36 MB | yes (defaults) |
| `logo/cercal.png` | 1232×1232 | 6.1 MB | 6 MB | **no** |
| `logo/square.png` | 1232×1232 | 6.1 MB | 6 MB | **no** |
| `logo/colored.png` | 837×731 | 2.5 MB | 2.4 MB | **no** |
| `logo/black.png` | 727×635 | 1.9 MB | 1.8 MB | **no** |
| `logo/logoInkscapeMaker.svg` | — | 1.1 MB | — | **no** |
| `maps/tricity/basemap.pmtiles` | — | 11.9 MB | resident in RAM when map opened | yes |
| `images/quran/Quran_banner.jpg` | 1280×716 | 193 KB | 3.7 MB | **no** (bundled, unreferenced in `lib/`) |

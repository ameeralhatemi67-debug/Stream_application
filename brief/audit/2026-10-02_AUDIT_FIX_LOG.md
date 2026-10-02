# Audit fix log — what was done, how, and why

- **Date:** 2026-10-02
- **Source audit:** [`2026-09-28_PERFORMANCE_AND_CACHING_AUDIT.md`](2026-09-28_PERFORMANCE_AND_CACHING_AUDIT.md) (findings and IDs are quoted from it).
- **Scope of this pass:** the client app (`project/`), hosting config (`vercel.json`, `scripts/`), and one backend migration. Nothing was deployed, and nothing was applied to the hosted Supabase project.
- **Result in one line:** about two thirds of the findings are fixed or partly fixed; the structural ones (provider split, live-state endpoint, virtualized feed) are deliberately left for their own work, with a design note for each (see "Not done").

## How to read this

Each entry has **What / How / Why**. Status is one of **Fixed**, **Partial** (some of the finding is addressed, the rest is named) or **Not done** (with the reason). Files are relative to the repository root.

## Verification

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` (full suite) | **975 passed, 0 failed** (968 before + 7 new in `test/audit_performance_fixes_test.dart`); one pre-existing date-dependent test was fixed along the way |
| Service-worker tests (`node tool/offline_worker.test.mjs`, `offline_page.test.mjs`) | pass (new regression assertion added) |
| Disposable SQL suites (`node brief/tools/organization_v1_db_check.mjs docker`) with the new migration applied | **155 / 155**, 0 `not ok` |
| New migration idempotency | applied twice to the disposable database; second run changed nothing; 0 unwrapped `auth.uid()` policies remain, 31 FK indexes created |
| `flutter build web --release` (without `--no-tree-shake-icons`) | builds; served locally, first frame renders and the splash is removed |

## Findings, one by one

### Web, hosting and bundle

**WEB-01 — service worker aborts downloads after 4 s — Fixed**
- *What:* `web/streamer_offline_sw.js` `boundedFetch` aborted the request **and** the body read after 4 s and buffered the whole body.
- *How:* the timeout now covers time-to-headers only (the timer is cleared as soon as `fetch` resolves) and the response is returned as-is, so the body streams. Added an assertion to `tool/offline_worker.test.mjs` that `boundedFetch` never buffers (`arrayBuffer`).
- *Why:* on a connection under ~24 Mbit/s the 12 MB map pack and, after a deploy, the app bundle failed to load. This is the live pilot site, so it affected real users first.

**CA-05 — no cache headers on Vercel — Fixed (needs a deploy to take effect)**
- *How:* `vercel.json` `headers`: `no-cache` for `index.html`, `flutter_bootstrap.js`, both service workers, `version.json`, `manifest.json`; `immutable` one-year for `/canvaskit/*`; one hour + `stale-while-revalidate` for `/assets/*` (not content-hashed, so not immutable); one day for `/icons/*`.
- *Why:* everything was served `max-age=0, must-revalidate`, i.e. a revalidation round-trip per file per visit. The service workers and entry files stay `no-cache` so a deploy is picked up.

**AS-01 — 17 MB of unused logo files bundled — Fixed**
- *How:* removed the `- assets/logo/` directory line from `project/pubspec.yaml`; only `colored.svg` and `black.svg` (the two the code uses) stay listed. The PNG/SVG masters remain on disk.
- *Why:* the directory line bundled `cercal.png`, `square.png`, `colored.png`, `black.png`, `logoInkscapeMaker.svg` etc. Verified in the web build that only the two SVGs ship.

**IMG-02 — 4000 px default avatars — Fixed**
- *How:* resized in place with Pillow: `amir_person_pic.jpg` 4000×3000 (5.4 MB, ~48 MB decoded) → 384×512, 18 KB; `amir_card_pic.jpg` 4000×2252 (2.6 MB) → 1280×721, 185 KB. Same file names, so no code changes. EXIF rotation was applied during the resize.
- *Why:* opening the apply flow allocated ~84 MB of decoded pixels for two placeholders.

**AS-02 — icon tree-shaking disabled on web — Fixed**
- *How:* removed `--no-tree-shake-icons` from `scripts/build_vercel_web.sh`. A release build confirms the icon font goes from 1,645,184 to 51,920 bytes (96.8 %).
- *Why:* the audit found no dynamic `IconData` use; the build proves it.

**WEB-02 — blank first paint — Partial**
- *How:* `web/index.html` now shows a plain white page with a small spinner (`#boot-splash`, honours `prefers-reduced-motion`) that is removed on Flutter's `flutter-first-frame` event.
- *Not done:* trying the `--wasm` renderer needs cross-origin-isolation headers and an A/B test; left as a measured experiment.

**WEB-03 — build config guard — Partial**
- *How:* `scripts/build_vercel_web.sh` now fails a **production** Vercel build when `SUPABASE_URL` is empty.
- *Why:* the Phase 3 production deploy silently shipped with no backend.
- *Not done:* the Flutter SDK is still cloned on every Vercel build; the fix is a CI build with a cached SDK and `vercel deploy --prebuilt`.

**WEB-04 — no code splitting — Partial**
- *How:* the router imports `AdminHubScreen` and `OrgAdminScreen` as `deferred`, via a small `_Deferred` wrapper (`lib/core/routing/app_router.dart`).
- *Result:* `main.dart.js` 5.72 MB → 5.49 MB (gzip 1.55 MB), plus three small part files. Modest, because most admin widgets are shared with other screens.
- *Not done:* deferring the phone studio and Firebase needs `kIsWeb` splits in more files.

### Rebuilds and state

**RT-01 — selectors that never compare equal — Partial**
- *How:* `discovery_feed_screen.dart` selected one record holding lists; a record compares with `==`, which falls back to list identity, so it never matched. It now selects each field separately; a bare `List` select uses deep equality, so the feed rebuilds only when streamers actually change.
- *Why:* every notification anywhere in the app rebuilt the whole (non-virtualized) feed.
- *Not done:* a catalog reload still creates new `StreamerModel` instances, so the map still rebuilds per reload (every 30 s while visible). Fix is value equality on the models or reusing instances for unchanged rows.

**RT-02 — live room rebuilds on every chat message — Partial**
- *How:* `_handleChatConnectionChange` used to call `setState` on the whole room per message and per slow-mode second. It now bumps a tiny `_ChatTick` notifier that only the chat tab listens to (arrival counting still runs first, so the "new messages" pill is never one behind). `messages.reversed.toList()` became a memoized `messagesNewestFirst`.
- *Not done:* the room still does `context.watch<AppProvider>()` at the top; it reads many provider fields (room choices, sessions, streamer lookup) and needs a careful split.

**RT-03 — router refreshes on every notification — Fixed**
- *How:* `refreshListenable` is now a `_RouteGate` that listens to the provider but notifies only when a field the `redirect` reads changes (login, hydrating, pending invitation, banned, role-selection, approved, admin, has-application, admin-role-loading, permitted-admin).
- *Why:* each of the ~157 notify sites re-parsed the location and re-ran the redirect.

**RT-04 — device heartbeat echo — Fixed**
- *How:* `applyDeviceSessions` skips `notifyListeners()` when neither this device's primary flag nor the remote primary device changed.
- *Why:* the 20 s heartbeat rewrites `last_active_at`, which echoed back over Realtime and caused a full notify (and, before RT-03, a router refresh) every 20 s per approved broadcaster. Test added.

**RT-05 — whole-provider watchers — Partial**
- *How:* the shell's mini-player now subscribes to the whole provider only while the chip is showing (it used to rebuild on every notification on every tab); the feed's and map's `academicCategories` use `select`; the three `watch` calls inside `.where` lambdas in `apply_step_3_professional.dart` use `select`.
- *Not done:* settings sections, profile screen, studio dialogs.

**RT-06 — `MediaQuery.of(context)` — Partial**
- *How:* 29 call sites of the form `MediaQuery.of(context).size/padding/viewInsets/orientation/devicePixelRatio/textScaler/viewPadding` became `MediaQuery.sizeOf/paddingOf/...`, including the app shell, so the keyboard animation no longer rebuilds them every frame. 7 sites that keep the whole object in a variable are unchanged.

**RT-07 — hot getters and search — Partial**
- *How:* feed search is debounced (250 ms) so a keystroke no longer notifies the whole app and re-filters the catalog twice.
- *Not done:* `getStreamerById` linear scan and `filteredStreamers` recomputation. Changing them needs an invalidation scheme because `_streamers` is mutated in place in ~40 places.

**RT-08 — studio rebuild per bitrate sample — Partial**
- *How:* `RtmpPublishEngine` now notifies for a bitrate sample only when the displayed kbit/s figure (rounded, as the badge shows it) changes.

**RT-09 — feed grid not virtualized — Not done.** The grid is a `Wrap` with a card-height equalization pass (the owner's recent design). Virtualizing it changes that design and the layout tests; it needs its own task.

**RT-10 — `AppProvider` keeps growing — Not done.** 6,500 lines, 157 notify sites. This is a multi-day refactor. Recommended first step: move the Organization V1 state (events, invitations, memberships, transfers) into its own `ChangeNotifier`.

### Network and polling

**NET-01 — every client polls the YouTube API — Fixed**
- *How:* `ensureLivePollingActive()` is now a documented no-op (kept so `main.dart` and the splash screen still compile). The viewer-count poll moved to `AppProvider.startStudioViewerPolling(streamerId)` / `stopStudioViewerPolling()`, called by the phone studio screen only (post-frame in `initState`, stopped in `dispose`), and only for that broadcaster's own stream.
- *Why:* the figure is only shown in the studio; it was burning the shared 10,000-unit daily YouTube quota for every open client. Existing viewer-presence test still passes.

**NET-02 — full catalog as the liveness signal — Partial**
- *How:* the feed's and map's catalog and viewer-count timers now pause while the tab is hidden behind another tab or a pushed route (`TickerMode`) or the app is in the background; the live room's 20 s poll also pauses in the background.
- *Not done (the real fix):* a tiny `live_now()` RPC or a Realtime broadcast for liveness. It also has to cover V1 broadcast sessions, which feed the catalog separately (`_sessionProjection`), so it should be designed with the V1 backend deployed. Sketch: `live_now()` returns `(id, is_live, broadcast_type, active_stream_id, live_session_id, ingest_state)` for live rows; the client patches `_streamers` and does a full reload only on app start, resume after 5 min, or an unknown id.

**NET-03 — four pollers in the live room — Not done.** Depends on a merged heartbeat+count RPC (backend change).

**NET-04 — catalog critical path — Fixed**
- *How:* the two public-table reads (`streamer_public_profiles`, `organization_public_profiles`) start together; the V1 broadcast-sessions read runs beside them; the stale-flag sweep no longer blocks the read (it was awaited for up to 2 s once a minute). `supabase/cron/sweep_stale_live_flags.sql` (optional, owner-run) schedules the sweep server-side so the client call can later be removed.
- *Why:* three sequential round-trips plus the sweep wait made every catalog load slow on high-latency links.

**NET-05 — serial startup chains — Partial**
- *How:* `_initAdminDatabase` runs catalog, admin data, categories and tags together; `refreshAdminData` issues its six reads together using a record `.wait`. Categories and tags no longer wait behind the admin loads.
- *Not done:* `_applySessionUser` (sign-in) is a 12–15 step chain with race guards; reordering it needs careful work with the auth tests. Gating admin loads on the admin role was **not** done because some of those reads (terms, own applications) are needed by non-admins.

**NET-06 — chat start latency — Fixed**
- *How:* `LiveChatController.start()` subscribes first, then runs the seven independent reads together. `_loadRecentMessages` now merges history with anything that arrived meanwhile (live inserts, pending local sends) instead of replacing the list.
- *Why:* seven sequential calls before subscribing meant over a second to first message on a slow link, and inserts in that window were missed.

**NET-07 — query from `build()` with no negative cache — Fixed**
- *How:* `ensureApprovedPlaceholderLoaded` now remembers misses (a set of looked-up keys); a failed lookup may retry at most once a minute.
- *Why:* every rebuild of the live room for a streamer without custom artwork issued another Supabase query.

**NET-08 — unfiltered chat DELETE subscription — Not done, on purpose.** The obvious fix (`REPLICA IDENTITY FULL` + a `stream_id` filter) makes Realtime deliver the **whole deleted row, including the message body**, to subscribers, which is a data-exposure change. The safe fix is soft-delete (`deleted_at` update, carried by the existing filtered UPDATE subscription) and needs product sign-off.

**NET-09 — connectivity probe — Partial**
- *How:* one `http.Client` is reused (keep-alive) and probes use `HEAD`; the client is dropped and recreated after a failed probe and closed when the provider is disposed.
- *Not done:* backing off to 60 s while stable (the existing tests inject timers with fixed durations).

**NET-10 — admin data volume — Partial**
- *How:* applications are limited to the newest 1000, audit logs to the newest 500, chat reports to the newest 500; Realtime-triggered refreshes (profiles, organizations, applications) are coalesced into one refresh after 1 s.
- *Not done:* the per-tag usage-count N+1 (needs a SQL aggregate), and proper pagination UI.

**NET-11 — 30 s upcoming-schedule polling — Fixed.** The profile tab polls every 5 minutes instead of every 30 s (opening the tab still loads fresh).

**NET-12 — three per-minute cron jobs — Not done.** Both claim functions have side effects (they materialize occurrences and emit reminders), so a cheap "is anything due" pre-check cannot replace them without redesign. Recommendation when setting up the V1 cron: keep the reminder job at one minute (reminders need that precision) and run the reconciler every minute only while a session is `preparing/live/ending`, otherwise every 5 minutes.

### Caching and images

**CA-01 — snapshot written after every load — Fixed**
- *How:* `PublicCatalogCache.save` computes a SHA-1 of the content and skips the write when unchanged, still refreshing the stored timestamp every 5 minutes; the map-marker snapshot does the same in `AppProvider._persistMapMarkerCache` (it also skips re-instantiating every marker). Test added.
- *Why:* on Android the whole SharedPreferences XML was rewritten and, on web, `localStorage.setItem` blocked the UI thread, about every 20–30 s.

**CA-02 — uploads cached for 1 hour — Fixed.** `uploadStreamerAsset` sends `cacheControl: '31536000'` (paths embed a timestamp, so objects are immutable).

**CA-03 — no disk image cache on native — Not done.** `cached_network_image` needs plugins that the widget-test harness does not provide, and the behaviour must be validated on a device. Plan: one resolver returning `CachedNetworkImageProvider` on native, `NetworkImage` on web.

**CA-04 — YouTube lookups — Partial.** `fetchChannelDetails` results are cached per handle for the session (copy-on-return; failures are not cached). Test added. The VOD/playlist TTL change on profile open was not done.

**IMG-01 — full-resolution decode — Partial**
- *How:* new `downscaledImage()` helper in `core/widgets/safe_image_provider.dart` (wraps `ResizeImage`). Applied in `StreamerAvatar` (decodes at `size × devicePixelRatio`), the feed's banner/avatar cards, the map markers, the chat avatars and the map drawer avatar.
- *Not done:* the other ~15 `NetworkImage` sites (admin views, org cards, profile).

**IMG-03 — oversized PNG uploads — Fixed (format change not done)**
- *How:* the avatar/banner pickers pass `maxWidth/maxHeight` (1024 / 1920); the cropper exports at most 512 px (avatar) or 1280 px (banner) wide instead of a fixed 3× pixel ratio; uploads detect PNG bytes and send `image/png` instead of mislabelling them `image/jpeg`.
- *Not done:* JPEG/WebP encoding (needs an encoder dependency). Existing large uploads remain until re-uploaded.

**IMG-04 — sync file IO in build — Not done** (low impact).

### Map, live room and misc

**MAP-01 — re-cluster on every camera frame — Fixed**
- *How:* the marker layers rebuild only when the **zoom** changes (clusters depend on zoom, not pan), and read the camera from the `MapController` instead of `MapCamera.of(context)`, which subscribed the builder to every pan frame. `MarkerLayer` still repositions markers on pan by itself.

**MAP-02 — per-marker animation controllers — Partial.** The outer scale animation only runs for the selected pin (live markers used to rebuild and repaint the whole marker each frame for a scale of 1); the radar ring has its own `RepaintBoundary`. A single shared ticker was not introduced.

**MAP-03 — tile caches not device-aware — Fixed.** Phones (shortest side < 600) get 12 MB / 48 MB instead of 24 MB / 96 MB.

**MAP-04 — pack residency / web range reads — Not done.**

**LIVE-01 — unbounded chat list — Fixed.** Rolling window of 500 messages (`maxRetainedMessages`); `messages` and `messagesNewestFirst` are memoized and invalidated by `notifyListeners`. Test added.

**LIVE-02 — unbounded reactions — Fixed.** At most 20 particles; the blurred shadow became a plain border; each particle has its own `RepaintBoundary`. Test added.

**LIVE-03 — backdrop blur over media — Not done.**

**ST-01 — startup — Partial.** `AppTheme.forLocale` caches one `ThemeData` per language. `Supabase.initialize` before `runApp` was left as is.

**LOG-01 — debugPrint in release — Fixed.** `main()` replaces `debugPrint` with a no-op in release builds.

### Backend (migration `supabase/migrations/20261002010000_audit_rls_initplan_and_fk_indexes.sql`)

**DB-01 — RLS `auth.uid()` per row — Fixed (migration written and tested locally; not applied to hosted)**
- *How:* a `DO` block reads every public-schema policy from `pg_policies`, wraps each bare `auth.uid()` / `auth.role()` as `(select auth.uid())`, and re-applies it with `ALTER POLICY`. It rewrites **whatever the current policy text is** rather than re-declaring known policies, so it stays correct on top of later migrations (the V1 migrations redefine some chat policies), and it is idempotent.
- *Gotchas found while testing:* Postgres regular expressions have no lookbehind, so already-wrapped forms are protected with a placeholder; and `pg_policies` deparses `auth.uid()` as `uid()` when the session search path includes `auth`, so the block pins `search_path` first.
- *Verified:* on the disposable database, 27 → 0 unwrapped policies; second run is a no-op; the SQL suites stay at 155 / 155.

**DB-02 — unindexed foreign keys — Fixed.** The same migration adds a btree index for every public foreign key without a covering index (31 created on the disposable DB, which includes the V1 tables). Plain `CREATE INDEX` (not `CONCURRENTLY`) because migrations run in a transaction; the tables are small.

**DB-03 — multiple permissive policies — Not done.** Merging them (`profiles`, `organizations`, `user_roles`, …) changes RLS on the most sensitive tables and needs per-table review plus the full SQL suites. A generic merge is not worth the risk in an automated pass.

**DB-04 — unused indexes / Auth connections — Not done on purpose.** Re-check after the pilot has produced real traffic.

**DB-05 — V1 backend unaudited on hosted — Not done (needs the owner).** Apply the V1 migrations plus the new one, then re-run the hosted performance **and** security advisors.

**WEB-05 — two service workers — Not done.** Needs a browser check that the Firebase worker registers under its own scope.

## Things that went wrong during this pass (and how they were handled)

1. **Silent no-op edits.** Several multi-line replacements in files with Windows (CRLF) line endings did nothing and reported success; the analyzer passed because nothing had changed. I noticed when a grep for a new symbol came back empty, re-applied them with a helper that asserts every replacement matches exactly once, and then re-checked **every** earlier edit with a grep. All edits are present.
2. **An accidental `git stash`** (a stray command at the end of a shell line) removed all uncommitted changes for a moment. It was popped immediately; the stash was dropped and the two original owner stashes were not touched. All edits were re-verified afterwards.
3. **A date-dependent test.** `test/organization_v1_journeys_test.dart` hard-coded an event timestamp of `2026-10-01`; the provider drops notifications older than 12 hours, so the test started failing on 2026-10-02 (not caused by this pass). The fixture now uses a time relative to now.

## What to do next (suggested order)

1. **Deploy and re-measure.** Push, then confirm the cache headers on the live site (`curl -I` on `/main.dart.js`, `/canvaskit/…`) and that the map loads on a throttled connection.
2. **Apply the migration** `20261002010000` together with the V1 migrations on the hosted project, then re-run the hosted advisors (DB-01/02/05).
3. **Live-state endpoint** (NET-02/03) with V1 deployed, then drop the client sweep call and add the optional cron.
4. **Provider split** (RT-10), starting with Organization V1 state, then the live room's whole-provider watch (RT-02).
5. **Virtualize the feed** (RT-09) if the catalog grows beyond a few dozen cards.
6. **Image pipeline** (CA-03, remaining IMG-01 sites, JPEG/WebP uploads).
7. **Soft-delete chat messages** (NET-08), then filter the Realtime subscription.

## Files touched

Application: `project/lib/core/providers/app_provider.dart`, `core/routing/app_router.dart`, `core/services/{admin_database_service,connectivity_service,public_catalog_cache,youtube_api_service}.dart`, `core/theme/app_theme.dart`, `core/widgets/{floating_stream_mini_player,safe_image_provider,streamer_avatar}.dart`, `main.dart`, `features/discovery/presentation/discovery_feed_screen.dart`, `features/map/presentation/{spatial_map_screen.dart,widgets/{spatial_streamer_marker,streamer_sliding_drawer,tricity_basemap_layer}.dart}`, `features/live_stream/{presentation/live_broadcast_screen.dart,presentation/screens/phone_broadcast_screen.dart,presentation/widgets/{floating_reactions_overlay,live_chat_widget}.dart,services/{live_chat_controller,rtmp_publish_engine}.dart}`, `features/auth/presentation/{steps/apply_step_2_media.dart,steps/apply_step_3_professional.dart,widgets/image_arrange_modal.dart}`, `features/profile/presentation/widgets/upcoming_schedule_tab.dart`, plus 26 files that only changed `MediaQuery.of(context).x` to `MediaQuery.xOf(context)`; `project/pubspec.yaml`, `project/web/{index.html,streamer_offline_sw.js}`, `project/assets/images/Amir_Alhatemi/*.jpg`.
Hosting and scripts: `vercel.json`, `scripts/build_vercel_web.sh`.
Backend: `supabase/migrations/20261002010000_audit_rls_initplan_and_fk_indexes.sql`, `supabase/cron/sweep_stale_live_flags.sql`.
Tests: `project/test/audit_performance_fixes_test.dart` (new), `project/test/organization_v1_journeys_test.dart` (date fix), `project/tool/offline_worker.test.mjs` (new assertion).

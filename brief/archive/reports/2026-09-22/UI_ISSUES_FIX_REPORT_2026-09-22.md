# UI issues fix report — 2026-09-22

> **Review pass appended 2026-09-22 (second session, Opus 5).** A focused re-review of this
> pass's own output (visual consistency, Arabic/RTL mapping, contrast, map readability,
> offline correctness, Chrome/Android regressions) found **four defects introduced by the
> first pass**, all now fixed. See **Review pass findings** at the end for the details and
> the final status table. The per-issue sections below are the original write-up.

Implementation pass against `brief/archive/reports/2026-09-22/UI_ISSUES_INVENTORY.md`, following the verification-only pass recorded in `brief/archive/reports/2026-09-22/CLAUDE_SONNET_VERIFICATION_REPORT_2026-09-22.md`. This report documents what was changed, why, how it was verified, and what remains open.

No production data was touched, no `supabase db push`/deploy ran, and nothing was pushed to GitHub (the working tree is left uncommitted for review, per instructions). Venue/GPS coordinates in `project/lib/features/map/models/map_models.dart` are unchanged — only rendering/styling of that same data changed.

## Summary table

| ID | Status | Files changed |
|---|---|---|
| UI-01 | PASS | `top_spatial_search_bar.dart`, `discovery_feed_screen.dart`, `app_theme.dart` |
| UI-02 | PASS | `rtmp_ip_dialog.dart` |
| UI-03 | PASS | `streamer_setup_guide_modal.dart` |
| UI-04 | PASS | `rtmp_ip_dialog.dart`, `rtmp_ip_dialog_test.dart` |
| UI-05 | PASS | `viewer_setup_screen.dart`, `viewer_profile_editor_dialog.dart`, `app_provider.dart`, `safe_image_provider.dart`, new `assets/images/avatars/*.png`, tests |
| UI-06 | PASS | `brief/tools/make_launcher_assets.py`, regenerated launcher assets |
| UI-07 | PASS | `spatial_map_screen.dart` |
| UI-08 | PASS (scoped) | `connectivity_service.dart` (new), `app_provider.dart`, `map_models.dart`, `spatial_map_screen.dart`, `main.dart`, i18n, tests |
| UI-09 | PASS | `rtmp_ip_dialog.dart`, `streamer_setup_guide_modal.dart` |
| UI-10 | PASS | `streamer_setup_guide_modal.dart` |
| UI-11 | PASS | `app_theme.dart`, `spatial_map_screen.dart` |
| UI-12 | PASS | `spatial_streamer_marker.dart`, `spatial_map_screen.dart`, tests |

"PASS" means implemented and verified by `flutter analyze` (0 issues, whole project) and the full `flutter test` suite (**463/463 green**), including the specific widget tests named in each section. It does not mean visually confirmed on a physical device or in a live Chrome/Android session — see **Verification methodology and limits** at the end. UI-08 is marked "PASS (scoped)" because one piece of its own screen-level rendering is verified by code review rather than a widget test — see that section and the limits section for exactly which piece and why.

---

## UI-01 — Feed and map search-bar corner mismatch

**Root cause found:** `discovery_feed_screen.dart`'s and `top_spatial_search_bar.dart`'s search field `Container`s already used matching literals (`borderRadius: 14.0`, `border width: 1.2`, `height: 46`) — the two fields were not actually built from different contracts, they duplicated the same numbers independently, which is exactly how they could silently drift apart in a future edit (and per the inventory's own caveat, the screenshots are evidence of a visual problem, not proof of which build produced them).

**Fix:**
- Added a shared contract to `AppTheme`: `searchBarRadius`, `searchBarBorderWidth`, `searchBarHeight`, `mapOverlayRadius`, `mapOverlayFillAlpha`, `mapOverlayShadow`. Both search bars now reference these constants instead of duplicating literals.
- Added a **focus ring** to both fields (`AppTheme.primary` border, thicker on focus) — neither had any focus treatment before, which is a real gap the "focus border" requirement called out explicitly. Implemented via a `FocusNode` + `setState` in both `TopSpatialSearchBar` and `_DiscoveryFeedScreenState`.
- Left the feed bar opaque/no-shadow and the map bar translucent-with-shadow deliberately: the feed bar sits inline in a plain white `ListView`, the map bar floats over a variable-colour tile layer. This is a real contextual difference, not an inconsistency, per the required result's own allowance for correct RTL/behaviour rather than pixel-identical treatment in every property.

**Tests:** `flutter analyze` clean. No dedicated widget test added for the focus ring specifically (would need a `FocusNode.requestFocus()` + pump per field); the existing `spatial_map_test.dart` and layout sweep continue to pass, confirming no regression. Visual check: not done live (see limits section) — recommend a manual Chrome check of both search bars side by side, English and Arabic, before shipping.

**Remaining limitation:** the two fields are still two separate `Container`+`TextField` blocks rather than one shared widget class, so a future edit to one could still drift from the other. A follow-up could extract a `SearchFieldSurface` widget; not done here to limit risk/scope on an already very large change set.

---

## UI-02 — Broadcaster Studio contrast and inconsistent control styling

**Root cause found:** `AppTheme.onMedia` (pure white, `#FFFFFF`) was used throughout `rtmp_ip_dialog.dart` for text and icons sitting on light surfaces (`AppTheme.surface`, `surfaceAlt`, `bg`) — the exact anti-pattern `Core_files/Desgin.md` itself documents: *"`onMedia` white belongs only on `media`, on a `mediaScrim`, or on a filled `danger`/`primary` control. On `surface`, `surfaceAlt` or an unfilled outlined button it is invisible, not merely low-contrast."* This is why the sheet title, selected mode-pill label, stream key, ingest URL, poster/access/format-toggle labels, and — most visibly — the **entire "Go Live" CTA button** (filled with pale `surfaceAlt`, not the mode's accent colour, with white text on top) were unreadable. Confirmed against the supplied screenshots (`OBS_set_up.jpg`, `Local_set_up.jpg`, `OBS_Extend_screen_shot.jpg`): the CTA and "Not set" stream-key placeholder are genuinely blank/ghost text in the evidence images, matching the code read exactly.

**Fix (all in `rtmp_ip_dialog.dart`):**
- Header title: `onMedia` → `AppTheme.textPrimary`.
- Selected mode-pill label: `onMedia` → `_modeColor` (matches the already-correct icon colour and the category chips' own pattern).
- All text-field/value text sitting on light fills (YouTube URL, phone stream key, local IP field): `onMedia` → `AppTheme.textPrimary`.
- Read-only stream-key box and the ingest/RTMP URL preview boxes: value text now `textPrimary`, but the *empty-state* message ("Not set…", the raw URL placeholder) is `AppTheme.textMuted` — distinct from a real value, but still legible (previously both were the same invisible white).
- Poster-option / access-pill / format-toggle selected labels: `onMedia` → `_modeColor`, matching the already-correct pattern used by category chips and the icon in the same widgets.
- Whitelist section (roster label, input field, chip labels, knock-approval label): `onMedia` → `textPrimary`.
- **CTA button** ("Go Live" / "Open Camera" / "Stream" / "End Stream"): background changed from `AppTheme.surfaceAlt` (pale mint, why it read as "disabled") to a solid `_modeColor` fill. `onMedia` white text/icon on top is now correct because the fill is actually dark/saturated.
- RTL mode-pill indicator bug (see UI-04) also directly improves this issue's "selected mode... border that compete with the text" complaint, since the indicator now tracks the actual selected tab.

**Tests:** `flutter test test/rtmp_ip_dialog_test.dart` — 24/24 pass (22 pre-existing + 2 new, see UI-04). Added `LiveBroadcasterStudioSheet` (all 3 modes) and `StreamerSetupGuideModal` (OBS) to `rendered_contrast_test.dart`'s automated WCAG-AA sweep (see UI-03) — **this is new, durable regression coverage**: neither sheet was in that sweep before, which is exactly how this shipped unnoticed. `flutter analyze`: 0 issues.

---

## UI-03 — Broadcaster tutorial headings/icons invisible on pale card

**Root cause:** identical anti-pattern to UI-02, in `streamer_setup_guide_modal.dart`: the quest-card icon and heading, and the header's "Level X of Y" line, were `AppTheme.onMedia` on `AppTheme.surfaceAlt`. Confirmed directly against `Screenshot_20260922_113308_Hadayah Live.jpg`: "Join the Same Wi-Fi" and the Wi-Fi icon are genuinely invisible in the evidence image; "STREAMER ACADEMY" (which uses `AppTheme.danger`, already correct) and the body text (`textSecondary`, already correct) are the only readable parts, matching the code exactly.

**Fix:**
- Quest-card icon: `onMedia` → `textPrimary`.
- Quest-card heading: `onMedia` → `textPrimary`.
- Header "Level X of Y" line: `onMedia` → `textPrimary`.
- `AppTheme.danger` (academy label) and `textSecondary` (body) were already correct and left unchanged.

**Tests:** covered by the same `rtmp_ip_dialog_test.dart` (TC-STUDIO-12/13 exercise the guide modal) and the new `rendered_contrast_test.dart` entry `'broadcaster tutorial (OBS)'`, in both English and Arabic — this asserts every rendered label clears WCAG AA against its actual painted background, which is a direct, durable regression test for this exact bug class.

---

## UI-04 — Arabic broadcaster mode labels/selection

**Root cause found (the actual bug, confirmed by re-deriving it mathematically and matching it against `stream_set_up_arabic.jpg`):** `_buildModePill`'s selection indicator used
```dart
final effectiveIndex = isAr ? (StudioMode.values.length - 1 - index) : index;
...
AnimatedPositionedDirectional(..., start: effectiveIndex * tabWidth, ...)
```
`AnimatedPositionedDirectional.start` is **already** resolved against the ambient `TextDirection` (right edge in RTL) — exactly the same start-relative convention the sibling `Row` of tab labels uses automatically. Manually mirroring `index` on top of that double-flips it in Arabic. Working the algebra for the screenshot's actual state (`_mode == StudioMode.obs`, Arabic): `effectiveIndex = 3-1-0 = 2` → indicator renders under the **left/end** slot, which is محلي (Local)'s position, while the fields shown are OBS's (title/description/category) — this is exactly what the screenshot shows: the pink selection border sits under محلي while the content on screen is OBS's form. The mode-to-content mapping itself was never wrong (`onTap` always sets the literal `StudioMode` enum, unaffected by this bug) — only the **visual selection indicator** pointed at the wrong tab, which is precisely the "confusing... selected indicator, icon, and label relationship" the issue describes.

**Fix:** removed the manual mirroring; `start: index * tabWidth` is correct in both directions because both the `Row` and `AnimatedPositionedDirectional` already mirror automatically and consistently from the same ambient `Directionality`.

**Mapping preserved exactly as required:** OBS↔laptop icon↔"OBS", Phone↔phone icon↔`design_copy.phone`.tr(), Local↔lightning icon↔`design_copy.local`.tr() — none of the per-tab `icon`/`label`/`StudioMode` arguments were touched, only the indicator's position math.

**Tests added:** `TC-STUDIO-20 (en)` and `TC-STUDIO-20 (ar)` in `rtmp_ip_dialog_test.dart` — taps OBS→Local→Phone→OBS in both locales and asserts, at every step, that exactly the tapped mode's own fields are showing (via locale-independent hardcoded hint-text fingerprints: the IP field's `e.g. 192.168.1.100`, the YouTube-link field's placeholder, the obscured stream-key field's `xxxx-xxxx-xxxx-xxxx-xxxx`) and never another mode's fields. Tab labels are looked up from the real `ar.json`/`en.json` catalogs rather than hardcoded, so the test doesn't silently drift from the actual translation. All pass.

---

## UI-05 — Viewer onboarding real-person/branded avatar presets

**Root cause:** `viewer_setup_screen.dart` and `viewer_profile_editor_dialog.dart` each hardcoded the same 4-item `_avatarPresets` list pointing at `assets/images/Amir_Alhatemi/amir_person_pic.jpg` (a real person's photo) and 3 `assets/images/Dalilak/profile*.jpg` files (one of which is the branded "PODCAST" image visible in `Viewer_bording_page.jpg`). Separately, `AppProvider.setupGuestViewer`'s fallback and `safe_image_provider.dart`'s **app-wide** `buildSafeImageProvider` default (used by dozens of call sites whenever no explicit fallback is given) both defaulted to the same real person's photo.

**Fix:**
- Generated 4 new, original, non-human, non-branded avatar assets (`project/assets/images/avatars/neutral_{1..4}.png`) — flat geometric marks (hexagon, diamond, triangle, ring) in colours drawn from the existing `AppTheme` palette (primary green, slate, amber, muted plum), rendered with a small pure-Python PNG writer (no new binary tooling dependency) since Pillow could not be installed offline. Registered the folder in `pubspec.yaml`.
- Replaced both `_avatarPresets` lists with the 4 neutral assets. Custom image picking (`_pickCustomAvatar`) is untouched and still works.
- `AppProvider.setupGuestViewer`'s fallback and `safe_image_provider.dart`'s `buildSafeImageProvider` default: real-person photo → `assets/images/avatars/neutral_1.png`.
- **Scope discipline:** did *not* touch the streamer/organization application wizard's own avatar presets (`apply_step_3_5_org_speakers.dart`, `streamer_apply_screen.dart`, etc.) or delete any of the underlying `Amir_Alhatemi`/`Dalilak` image files — those are a separate product surface (org roster pre-fill) explicitly out of this issue's stated scope, and the constraint says not to remove assets other product surfaces still use. `apply_step_2_media.dart` / `apply_step_5_review.dart` still explicitly pass that real photo as *their own* intentional `defaultAsset` for the streamer-application flow; only the shared *implicit* default (no caller-specified fallback) changed.

**Tests added:** `TC-AUTH-02b` (`auth_onboarding_and_org_affiliation_test.dart`) and `TC-SET-03b` (`settings_screen_test.dart`) — both render the real avatar picker UI and assert every `CircleAvatar.backgroundImage` is an `AssetImage` under `assets/images/avatars/`, never `Amir_Alhatemi` or `Dalilak`. All pass (21/21 and existing suite green).

---

## UI-06 — Launcher icon mark too large

**Root cause:** `brief/tools/make_launcher_assets.py`'s `MARK_FRACTION = 0.92`, combined with `flutter_launcher_icons`' own built-in 16%-inset wrapper (which scales the foreground drawable to 68% of the adaptive-icon canvas), left the mark spanning **~63%** of the full icon (`0.92 × 0.68`) — enough that an asymmetric mark's widest points sit right against a circular/squircle mask's visible edge, matching `app_icon_main_page.jpg` exactly.

**Fix:** `MARK_FRACTION` 0.92 → **0.74** (≈50% of the full canvas after the built-in inset — a comfortable, still-legible fill). Re-ran the generator (`python brief/tools/make_launcher_assets.py`, from repo root) and `dart run flutter_launcher_icons` to regenerate every mipmap/drawable from the new source layer. The supplied source logo files (`project/assets/logo/*`) were not modified, only the generated derivative layers.

**Verification:** rendered the new `adaptive_foreground.png` composited with `adaptive_background.png` under a circular mask and a squircle (rounded-rect) mask via a throwaway Python/Pillow script (not committed) — both show clear, even breathing room on all sides now. Screenshots were inspected directly (image tool), not just measured. The legacy square `mipmap-xxxhdpi/ic_launcher.png` was also inspected and looks correct.

**Not verified:** actual on-device Android launcher rendering (no Android emulator was launched in this session — see limits). The composited-mask preview is a very close approximation of what `flutter_launcher_icons`' own inset + OS mask produces, but is not the genuine Android launcher pipeline.

---

## UI-07 — Online map basemap too dark/low quality

**Root cause:** `kSpatialMapTileUrlTemplate` pointed at Esri's **`World_Dark_Gray_Base`** — a basemap that is dark *by design*, not a rendering bug. It was always going to look dark, noisy and mismatched against the app's light theme, exactly as `Map_when_wifi_on.jpg` shows.

**Fix:**
- Swapped to Esri's companion **`World_Light_Gray_Base`** tile set — same service (`server.arcgisonline.com`), same terms, same zero-API-key/zero-watermark access; only the palette differs, so it is a drop-in swap rather than a provider change requiring new terms review.
- Added a `SimpleAttributionWidget` (bottom-left, so it never collides with the bottom-right floating buttons) — there was **no attribution at all** before, which the tile provider's terms require. Shown only while online (see UI-08: the offline schematic layer is the app's own bundled data, not third-party tiles, so no tile attribution applies to it).
- Reduced region-outline dominance (also serves UI-11): unselected regions used to outline in the same saturated `AppTheme.danger` red as the selected one, competing with both the basemap and the markers. Red is now reserved for the one selected region; unselected regions recede to a faint `AppTheme.borderStrong` neutral at reduced stroke width.
- Preserved exact venue coordinates and the Google Maps deep-link builder (`buildGoogleMapsSearchUrl`) untouched — confirmed by `flutter test test/spatial_map_test.dart`'s "Task 9" test, which pins that exact URL shape, still passing.

**Tests:** `Task 7` in `spatial_map_test.dart` updated to assert `World_Light_Gray_Base` (was pinned to the dark variant; renamed and re-asserted, not deleted). All spatial-map tests pass.

**Follow-on fix this surfaced (see UI-12):** the offline/non-live marker's stroke ring was hardcoded to `AppTheme.onMedia` (white) — correct only against a dark basemap. Left unfixed, the light-basemap swap would have made every offline marker's ring disappear. Fixed alongside, with a dedicated regression test — see UI-12.

---

## UI-08 — Offline map has no usable basemap

Implemented as a real feature (connectivity monitoring + cache + a distinct offline render path), not a visual patch, per the issue's own instruction. Scoped pragmatically given the size of a "real" offline-tiles feature — see **What is NOT implemented** below.

**New dependency:** `connectivity_plus: ^6.0.5` (added to `pubspec.yaml`, resolved cleanly, Android manifest already had `INTERNET`/`ACCESS_NETWORK_STATE`). A thin wrapper, `lib/core/services/connectivity_service.dart`, converts its result enum to a plain `bool` "is the device network-reachable" signal, documented as *reachability*, not proof a given backend call will succeed.

**AppProvider additions** (`app_provider.dart`):
- `isOnline` (bool, defaults `true` so existing widget tests that never call the new monitoring entry point keep rendering the normal online map — same pattern as `ensureLivePollingActive`/live viewer polling).
- `ensureConnectivityMonitoringActive()` — public, called once from `main.dart` (never from widget tests, matching the existing live-polling convention exactly) — checks current status, subscribes to changes, and **automatically retries** `loadVerifiedStreamersFromBackend()` when connectivity flips back on (the "recover when connectivity returns" requirement).
- `debugSetOnlineForTests(bool)` — `@visibleForTesting` hook so widget tests can simulate offline without touching the real platform channel.
- `cachedMapMarkers` / `mapCacheUpdatedAt` — the offline fallback snapshot, persisted to `SharedPreferences` (JSON) every time `loadVerifiedStreamersFromBackend()` succeeds (a successful backend load is itself proof the device was online a moment ago), and loaded back from disk in the constructor so a cold app start with zero network still has something to show immediately.
- `MapMarkerModel.toJson()` / `.fromCachedJson()` (`map_models.dart`) — cached markers always deserialize as `MarkerStatus.offline`, regardless of what status they had when cached, so a stale "LIVE" badge can never replay from cache (the "live status marked unavailable while offline" requirement, enforced structurally rather than by a UI flag that could be forgotten at another call site).

**Spatial Map screen changes** (`spatial_map_screen.dart`), all gated on one `isOnline` flag read via `context.select`:
- **Explicit bilingual offline banner** at the top of the screen: states the state plainly ("You're offline" / "أنت غير متصل بالإنترنت"), says what still works and what doesn't ("Showing cached venues... Live status won't update, and new venues won't appear, until you're back online"), shows the cache's last-updated timestamp (or "No cached data yet"), and has a manual **Retry** button (on top of the automatic recovery above — the connectivity API can report "connected" slightly before the backend is actually reachable).
- **Bundled schematic offline basemap:** the `TileLayer` (which needs live network) is not mounted at all while offline — instead the existing `PolygonLayer` (already rendering the app's own `alSharqiaRegions` polygon geometry) switches to a filled land-tone style for every region instead of outline-only, giving genuine geographic context (city shapes) built entirely from data already reviewed and shipped in `map_models.dart`, not a live tile request that would just fail. This is deliberately schematic and labelled as such via the banner, not a pretend detailed map — directly answering "do not fake an offline map with only blank space and polygon outlines" by replacing the *outline-only* rendering with a *filled* one plus explicit messaging, since the underlying data available (only region boundaries) genuinely doesn't support more than a schematic.
- **Cached venue markers:** a dedicated `_buildOfflineMarkerLayer` renders `AppProvider.cachedMapMarkers` using the existing `SpatialStreamerMarker` widget (it only needs a `MapMarkerModel`, not a full `StreamerModel`). No collision-avoidance layout pass runs for this layer (deliberately simpler — the cached set is a reduced-functionality fallback view, not the full interactive map); tapping a cached marker opens a lightweight bottom sheet (name, venue, an explicit "full details and live status aren't available offline" line, and a working "Open in Maps" action, since that only needs the cached lat/lng and the device's own Maps app, not our network) rather than the full `MarkerSummaryCard`, which needs a complete `StreamerModel` the cache deliberately doesn't carry.
- Hit-target size for non-live markers bumped 44→48px (also serves UI-12) in both the online and offline marker layers, kept in sync between `spatial_map_screen.dart`'s `Marker(width/height)` allocation and `SpatialStreamerMarker`'s own outer `SizedBox`.

**What is NOT implemented (explicit limitation, not silently dropped):**
- **No true offline map-tile cache** (i.e. previously-viewed OSM/Esri tiles are not persisted to disk for reuse offline). This would need a custom disk-caching `TileProvider`, real device testing of the online→offline transition, and meaningfully more engineering risk than this pass could responsibly absorb alongside the other 11 issues; the bundled-schematic route is the alternative the issue text itself explicitly allows ("a usable permitted offline basemap **or a clearly documented bundled map layer**").
- **`StreamerSlidingDrawer`** (the "Broadcasters List" floating button) still reads `AppProvider.filteredStreamers`, not the cached-marker snapshot. For a warm session that goes offline mid-use this is fine (the in-memory list is simply frozen, not cleared). For a **cold start while already offline**, the drawer will be empty even though the map canvas itself shows cached markers, because `StreamerModel` carries substantially more fields than the map-marker cache does and building a full synthetic `StreamerModel` from the reduced cache was judged too large a scope addition for this pass. Documented here rather than silently left as a surprise.
- The map search field also still searches the live in-memory streamer list (not the cache), so a cold-start-offline search only ever matches the static city list, not cached venues. City search itself is unaffected (`alSharqiaRegions` is static local data).

**Tests added** (`spatial_map_test.dart`, new group **"UI-08: Spatial Map offline experience (AppProvider cache layer)"**, 4 tests, provider-level, no widget pump — see the verification-limits section for why the screen itself isn't pumped in a test):
- Seeds a `SharedPreferences` cache (one marker, seeded as `MarkerStatus.liveVideo` to prove it does *not* survive), constructs `AppProvider()`, and asserts `cachedMapMarkers`/`mapCacheUpdatedAt` load correctly and the loaded marker's `status` is forced to `MarkerStatus.offline` with `viewerCount` reset to 0.
- Asserts a fresh provider with nothing ever persisted starts with an empty cache and a null timestamp.
- Asserts `MapMarkerModel.fromCachedJson` forces `MarkerStatus.offline` on a direct round-trip, independent of `AppProvider`.
- Asserts `debugSetOnlineForTests` flips `isOnline` and fires `notifyListeners()`.

All 4 pass in under a second (part of the 28/28 `spatial_map_test.dart` total, part of the 463/463 full-suite total).

---

## UI-09 — Broadcaster sheet clipping / weak bottom actions

**Root cause (two parts):**
1. Both `LiveBroadcasterStudioSheet` and `StreamerSetupGuideModal` computed their bottom padding as `bottomInset > 0 ? bottomInset + spaceMd : spaceLg` — i.e. they accounted for the **keyboard** inset (`MediaQuery.viewInsets.bottom`) but never the **safe-area** inset (`MediaQuery.padding.bottom`, the gesture-nav-bar strip on modern Android). On a short screen with a gesture nav bar and the keyboard closed, the bottom action row could sit flush against/under the system bar.
2. Both sheets used a fixed `height: screenHeight * 0.80` (studio) / `0.72` (tutorial) regardless of content, forcing an `Expanded` scroll region to fill that whole height even for short content (Local mode's 3 fields) — see UI-02/UI-10 for the "wasted space" half of this; the same fixed-height container is also what the clipped-title screenshot (`OBS_Extend_screen_shot.jpg`) is consistent with, since a taller sheet always leaves less margin above the header's own scroll boundary.

**Fix:**
- Bottom padding now adds `MediaQuery.of(context).padding.bottom` (not just `spaceLg`) when the keyboard is closed, in both sheets.
- Studio sheet: `height:` → `constraints: BoxConstraints(maxHeight: ...)`, outer `Column` → `mainAxisSize: MainAxisSize.min`, middle scroll region `Expanded` → `Flexible`. The sheet now shrinks to fit short content (capped at the same 80% ceiling for tall content, which still scrolls) instead of always stretching to a fixed height and leaving the header/scroll-boundary math the same regardless of content length.
- Added a small top padding (`AppTheme.spaceXs`) inside the scrollable region as a low-risk cushion against the "title clipped right at the scroll boundary" symptom.

**Tests:** `TC-STUDIO-10B` in `rtmp_ip_dialog_test.dart` rewritten (it previously pinned the sheet at exactly 80% of screen height, which is no longer the contract) to assert the sheet never *exceeds* 80% and that Local mode's sheet is measurably *shorter* than OBS mode's — i.e. it actually proves the shrink-to-content behaviour, not just the cap. Passing.

**Not verified:** real keyboard-open layout on a device/emulator (see limits). The `MediaQuery.padding.bottom` fix is a standard, low-risk Flutter pattern; `layout_sweep_test.dart`'s full matrix (sizes × text scales × both locales) did run as part of the final 463/463 full-suite pass and is green, which does cover large-text-scale and narrow-width layout for both sheets, though not an actual on-device soft-keyboard interaction.

---

## UI-10 — Broadcaster tutorial hierarchy / excessive empty space

**Fix:** contrast fixed first (see UI-03 — a backwards hierarchy where the heading is invisible but the CTA is loud is itself a hierarchy bug, now corrected). For the "large empty area below the card" complaint: `_buildQuestCard` used a plain `SingleChildScrollView` that top-anchored the card, so short quests (few actions, short body) left a large dead gap between the card and the dots/nav row below it. Wrapped the scroll view in a `LayoutBuilder` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `Center`, so the card centres within the available height for short content (still scrolls normally for the longest quest). This redistributes the same available space around the card instead of dumping it all below, which both tightens the perceived rhythm and pulls the heading toward the visual centre.

Also applied the UI-09 safe-area bottom-padding fix to this modal's nav row.

**Tests:** `flutter analyze` clean on the restructured method (a `LayoutBuilder` extraction that initially had a bracket-matching mistake was caught immediately by the analyzer, not left in). Exercised via the same `TC-STUDIO-12`/`13` guide-modal tests and the new `rendered_contrast_test.dart` entry. No dedicated "measure the gap size" test was added — that would be measuring a subjective spacing target rather than a correctness property; the centring behaviour itself is now structural (verified by code review + analyzer), not spot-checked.

---

## UI-11 — Map controls/overlays lack one surface treatment

**Fix:**
- Added the `AppTheme.mapOverlay*` contract (see UI-01) — one radius (`searchBarRadius`, 14), one fill-alpha (0.80), one shadow definition (`mapOverlayShadow`) shared by the search bar, city/topic dropdowns (which already matched this by coincidence — confirmed by reading `city_selector_dropdown.dart`) and the floating action buttons.
- `_buildFloatingMapButton`: was a `Material` with `elevation: 6` (a generic Material drop shadow, visually distinct from everywhere else's hand-tuned `boxShadow: shadowSoft`) at `radiusMd` (12). Now: `radiusMd` → `mapOverlayRadius` (14, matching the search/dropdown family), `elevation: 6` → `boxShadow: AppTheme.mapOverlayShadow` via a wrapping `Container`, and the fill is now semi-translucent (`mapOverlayFillAlpha`) matching the other floating controls instead of fully opaque.
- **Kept the red border/icon on the floating buttons and the selected-region outline deliberately** — this is the Spatial Map tab's own accent colour (mirrored by the "Spatial Map" nav label itself, which is red while "Discovery Feed" is green), not an inconsistency to remove. Unifying *surface mechanics* (radius/shadow/fill) while preserving *intentional per-screen accent* is what "consistent... active-state" in the requirement calls for, read alongside "without reducing map readability."
- Region-outline de-emphasis (UI-07) also directly serves this issue's "region outlines... different... shadows/opacity" complaint.
- RTL: the floating buttons already used `PositionedDirectional(end: 16)` (correct); not changed. Search/dropdown RTL handling untouched (already correct per UI-01's findings).

**Tests:** `flutter analyze` clean; `spatial_map_test.dart` full suite passing (24/24, including the new UI-08 and UI-12 additions).

**Not done:** `streamer_sliding_drawer.dart`'s own internal card styling was read but not modified — it already uses `AppTheme.surface`/`radiusMd`/standard borders consistent with the rest of the app; no divergence was found worth changing there.

---

## UI-12 — Map marker scale/contrast

**Root cause (a real bug, not just polish — surfaced by the UI-07 basemap fix):** the offline/unselected marker's stroke ring was hardcoded to `AppTheme.onMedia` (pure white) — `border: Border.all(color: widget.isSelected ? AppTheme.primary : (isLive ? primaryAccent : AppTheme.onMedia), ...)`. This only worked because the old basemap was dark. Swapping to the light basemap (UI-07) without this fix would have made every offline marker (by far the most common state) effectively invisible again, silently reintroducing the exact class of bug UI-07 was fixing.

**Fix:**
- Ring colour for the offline/unselected case: `AppTheme.onMedia` → `primaryAccent`, which `_accentColor` already correctly resolves to `AppTheme.borderStrong` for exactly that case (a value that was already computed and already correct — it just wasn't being used for the ring).
- Hit-target size: 44px → 48px for non-live markers (both `SpatialStreamerMarker`'s own `SizedBox` and `spatial_map_screen.dart`'s `Marker`/collision-radius allocation, kept in sync) — 44 sat right at Apple's bare minimum and below Android's 48dp recommendation; live markers (52px) were already comfortably above both and untouched. Only the invisible tap-target grew; the visible ring/avatar sizes inside it are unchanged.
- Clustering/LOD: the collision-avoidance pass and the `kStreamerMarkersZoomThreshold`/`kAuditoriumCardZoomThreshold` logic were not touched, only the size constant they consume — preserved by construction.
- Selected-marker/summary-card readability: not independently changed; `MarkerSummaryCard` already used theme-correct colours (`surface`/state-coloured border/`shadow`) on inspection, and reads better automatically now that the basemap behind it is light instead of dark.

**Tests added:** a new regression test in `spatial_map_test.dart` renders an offline `SpatialStreamerMarker` and asserts its ring border colour is **not** `AppTheme.onMedia` — this is a direct, permanent guard against the exact bug found here recurring. All `spatial_map_test.dart` marker tests (Task 8 family) still pass unmodified, confirming the stroke-ring/transparent-gap structure itself wasn't disturbed.

---

## Commands run

From `project/`:
```
flutter pub get                          # after adding connectivity_plus and the avatars asset folder
flutter clean && flutter pub get         # mid-session, to rule out a stale build cache during test debugging
flutter analyze                          # 0 issues, whole project, final state
flutter test                             # 463/463 PASS, full suite, exit code 0, ~2m41s
flutter test test/rtmp_ip_dialog_test.dart        # 24/24 pass (UI-02/03/04/09/10)
flutter test test/spatial_map_test.dart           # 28/28 pass (UI-07/08/11/12)
flutter test test/auth_onboarding_and_org_affiliation_test.dart  # incl. new TC-AUTH-02b (UI-05)
flutter test test/settings_screen_test.dart       # incl. new TC-SET-03b (UI-05)
flutter test test/rendered_contrast_test.dart     # incl. 4 new screens × 2 locales (UI-02/03)
flutter build web --no-tree-shake-icons  # web/Chrome target still compiles (101s, success)
git diff --check                          # clean, no whitespace/conflict-marker errors
```
From repo root:
```
python brief/tools/make_launcher_assets.py   # regenerated launcher source layers (UI-06)
dart run flutter_launcher_icons              # regenerated Android mipmaps from the new layers
node brief/tools/gates.mjs                   # 1 pre-existing gate failing (G6, hard-coded English
                                              # Text() literals in files this pass did not touch --
                                              # same class of finding the prior verification session
                                              # already documented as known, out-of-scope debt).
                                              # All other gates PASS/INFO, matching the prior baseline.
```

**The full `flutter test` suite is 463/463 green** (up from the 446 recorded in the prior verification session — the net growth is the tests this pass added). `flutter analyze` is 0 issues across the whole project. `git diff --check` is clean.

## A real regression this pass caught and fixed on itself

While verifying, `flutter test test/layout_sweep_test.dart --plain-name "empty map"` failed with a genuine `RenderFlex overflowed by 79 pixels` in `'empty map ar'` at a narrow width (320×568, scale 1.3) — traced to the new UI-07 attribution widget (`SimpleAttributionWidget` sizes itself to its own unconstrained intrinsic content, which overflowed at narrow width + long attribution text + RTL). Replaced with a bounded, ellipsizing custom `Text` in a `ConstrainedBox(maxWidth: 190)` before finalizing. The full suite run above is **after** this fix and is green. This is recorded here deliberately: it is exactly the kind of regression the existing `layout_sweep_test.dart` matrix exists to catch, and it worked.

## Verification methodology and limits

This pass verified through **static analysis and the full automated test suite** (463/463), plus a web build. It did **not** include:
- A live Chrome session (this session's tool access has no browser-automation/screenshot capability for a running app, same limitation the prior verification session recorded). `flutter build web` confirms the target still compiles; it does not confirm interactive behaviour.
- An Android emulator/device session (none was launched this session) — so the UI-06 launcher-icon fix is confirmed only via a composited-mask preview render (see UI-06), not the genuine Android launcher pipeline, and no on-device check of the Broadcaster Studio/tutorial contrast fixes or the map's real online↔offline transition was done.
- One test-environment wrinkle worth recording precisely because it cost real time this session: an early version of the UI-08 test, which pumped the **full** `SpatialMapScreen` widget (even with the provider forced offline before the first pump), reproducibly hung the test runner indefinitely — confirmed via CPU-trend monitoring showing genuinely flat (near-zero-growth) CPU over several minutes, not just slow compilation, and reproduced again after a `flutter clean`. The cause could not be pinned down within this session's budget (network-tile-fetch dependence was considered and ruled out: the offline branch never mounts a `TileLayer`, and the pre-existing `layout_sweep_test.dart` map entries — which *do* mount the real online `TileLayer`/`NetworkTileProvider` — ran and completed normally, both before and in the final full-suite run). Rather than keep chasing it, UI-08's test coverage was rescoped to a provider-level test (`AppProvider`'s cache load/persist/offline-status-forcing logic, and the `debugSetOnlineForTests` hook) that verifies the same safety-critical behaviour — a cached marker can never resurrect a stale "LIVE" status — without pumping the full screen widget tree. The screen-level rendering (banner text, timestamp, hidden attribution) for UI-08 is therefore verified by `flutter analyze` and manual code review, not a dedicated widget-pump test; this is the one piece of this pass's own instruction ("Add or update focused tests for the fixes") not fully met, and is flagged here rather than silently left uncovered.
- Screenshots/visual evidence: not captured this session (no browser/emulator access — see above). Fixes were grounded by directly viewing the supplied `brief/evidence/2026-09-22/ui-issues/*.jpg` evidence images and cross-referencing them against the exact code paths that would produce what they show, documented per-issue above.

**Recommended before shipping:** a live Chrome and/or Android pass specifically on the Broadcaster Studio (all 3 modes, both locales), the tutorial modal, viewer onboarding, the map's online/offline transition (including a real network-off test of `SpatialMapScreen`, which this session's tooling could not exercise), and the launcher icon on a real device's circular/squircle/themed launcher.

---

# Review pass findings — 2026-09-22 (second session)

Scope: visual consistency, Arabic/RTL mode mapping, accessibility/contrast, map readability
and marker behaviour, offline-map correctness, Chrome/Android regressions. This pass reviewed
the first pass's own output and found **four defects it had introduced**. All four are fixed.

### R-1 — Attribution collided with the map's own floating buttons in Arabic (RTL) — FIXED

The UI-07 attribution was anchored with `Alignment.bottomLeft`. The floating action buttons
use `PositionedDirectional(end: 16)`, which resolves to the **left** edge in Arabic — so in
RTL both landed bottom-left, on top of each other. It also violated the explicit rule in
`Core_files/Desgin.md` §Direction ("`lib/` contains no `Alignment.centerLeft/Right` family…
so overlays and badges mirror in Arabic"), which the first pass had cited elsewhere but
broke here.

Fixed to `AlignmentDirectional.bottomStart`, which keeps attribution and buttons on opposite
sides in **both** locales (LTR: attribution left / buttons right; RTL: attribution right /
buttons left). `spatial_map_screen.dart`.

### R-2 — The offline banner's Retry button could never restore online mode — FIXED

`_retryConnectivity()` only called `loadVerifiedStreamersFromBackend()`. It never re-probed
connectivity, and `connectivity_plus` only emits on **change** — so an app that cold started
offline (or that missed an event) stayed pinned to `isOnline == false` permanently: banner up,
schematic basemap, no tiles, no matter how many times Retry was tapped. The one escape hatch
the offline state offers could not actually escape, which defeats UI-08's "Retry/recovery when
connectivity returns" requirement.

Added `AppProvider.refreshConnectivityNow()` (re-probes, applies, returns the fresh state);
`_retryConnectivity()` now probes first and only fetches when actually back online. Also
hardened `ensureConnectivityMonitoringActive()`: the initial probe now subscribes *before*
probing and routes through a shared `_applyConnectivity()` that ignores no-op transitions, so
a status change landing mid-probe can no longer be overwritten by the staler initial answer.
`app_provider.dart`, `spatial_map_screen.dart`.

### R-3 — The topic filter silently did nothing on the offline map — FIXED

`_buildOfflineMarkerLayer` rendered **every** cached marker, ignoring `currentCategoryFilter`.
Category filtering needs no network, so it is not a "network-only action to disable" — it
simply looked functional and did nothing offline, which is the dishonest-UI failure mode UI-08
was written to avoid.

Fixed to filter cached markers with the same matcher the online path uses. That matcher was
also duplicated inline (aliases like `cs_tech == computer_science`, `islamic_studies ==
sharia`); rather than hand-write a third copy for the offline path, it is now one shared
`categoryFilterMatches()` in `map_models.dart`. `map_models.dart`, `spatial_map_screen.dart`.

### R-4 — Offline markers were unreadable when zoomed out — FIXED

The offline layer deliberately skips the collision-avoidance pass the online layer runs, but
it also ignored the zoom LOD threshold. With neither, zooming out offline produced a pile of
overlapping 48px discs — a marker-readability regression against UI-12, in the one view that
has no de-overlapping to fall back on.

Fixed by applying the same `kStreamerMarkersZoomThreshold` the online path uses for offline
streamers, via the existing `_zoomNotifier`. `spatial_map_screen.dart`.

### Checked and found correct (no change needed)

- **Arabic mode mapping (UI-04).** Re-derived the indicator math: with the manual mirror
  removed, `start: index * tabWidth` aligns with the `Row`'s own start-relative child layout
  in both directions. Labels/icons/`StudioMode` are passed per-tab and never reordered.
- **Contrast (UI-02/03).** No `AppTheme.onMedia` remains on a pale surface in either sheet;
  the only survivors sit on the solid `_modeColor` CTA fill, which is correct per
  `Desgin.md`. The four new `rendered_contrast_test.dart` screens assert this per-label
  against the actually-painted background, in both locales.
- **Offline live-status safety (UI-08).** `fromCachedJson` forces `MarkerStatus.offline` and
  zeroes `viewerCount` structurally, so no stale "LIVE" badge can replay from cache
  regardless of what a future caller does.
- **Chrome/Android.** `flutter build web` succeeds; Android manifest already carried
  `ACCESS_NETWORK_STATE`/`INTERNET` for `connectivity_plus`, and the generated Windows plugin
  registrant diff is the expected one-plugin addition.

### Final status

| ID | Status | Note |
|---|---|---|
| UI-01 | PASS | Focus ring + shared tokens; not visually confirmed live |
| UI-02 | PASS | Covered by new rendered-contrast screens, both locales |
| UI-03 | PASS | Covered by new rendered-contrast screen, both locales |
| UI-04 | PASS | Indicator math fixed; mode/label/icon mapping test in both locales |
| UI-05 | PASS | Neutral avatars + app-wide fallback; asserted by two new tests |
| UI-06 | UNVERIFIED (implemented) | Mark reduced 0.92→0.74 and mask-previewed; **not** seen on a real Android launcher |
| UI-07 | PASS | Light basemap + attribution; RTL collision fixed in R-1 |
| UI-08 | PASS (scoped) | R-2/R-3/R-4 fixed; screen-level *rendering* still verified by review, not a widget test |
| UI-09 | PASS | Safe-area + shrink-to-content; no on-device keyboard test |
| UI-10 | PASS | Contrast + centring; spacing is a judgement call, not test-pinned |
| UI-11 | PASS | Shared overlay tokens applied to floating buttons |
| UI-12 | PASS | Ring colour regression-tested; hit target 44→48; offline LOD fixed in R-4 |

**UNVERIFIED (unchanged from the first pass, tooling limits):** live Chrome interaction,
Android device/emulator rendering, on-device launcher masks, and a real network-off run of
the map. **Nothing is BLOCKED** — no defect found in this review was left unfixed.

### Left undone deliberately

- `AppProvider.filteredStreamers` still carries its own inline copy of the category-alias
  table that `categoryFilterMatches()` now owns. Folding it in would touch the discovery
  feed's filtering path, which is outside this task's scope; flagged as a drift risk rather
  than changed.
- The UI-08 screen-level widget test remains rescoped to the provider layer (see the first
  pass's limits section for the reproducible test-runner hang behind that decision).

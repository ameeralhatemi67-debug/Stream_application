---
type: fix_log
tags:
  - streamer_app
  - bug_fixes
  - quick_tasks
created: 2026-08-31
updated: 2026-08-31
status: completed
---

# 🛠️ To Fix Log — Quick Tasks & Immediate Refinements

> [!info] Instructions
> Quick, self-contained fixes identified during testing passes and issue logs. Check off tasks with `- [x]` once implemented and verified.

---

## 🎬 Cluster 1: Live Stream Player, Audio & Viewport Enhancements

- [x] **Task QF-01: Fix Fullscreen Button Visibility on Audio-Only Broadcasts**
	- **Target File:** `lib/features/live_stream/presentation/widgets/live_player_overlay_controls.dart`
	- **Problem:** Fullscreen toggle button was wrapped under `if (controlsVisible && !widget.isAudioOnly)`, making it impossible for viewers to enter landscape mode during audio broadcasts.
	- **Solution:** Uncouple the fullscreen toggle button from the `isAudioOnly` check so it is always rendered on the bottom overlay bar for all broadcast types.
	- **Comments:** Fixed and verified via widget test `TC-FULLSCREEN-01`.

- [x] **Task QF-02: Compact Floating Picture-in-Picture Mini-Player Redesign**
	- **Target File:** `lib/core/widgets/floating_stream_mini_player.dart`
	- **Problem:** Current mini-player is a full-width bottom bar with play/pause controls that do not fit live streaming ergonomics.
	- **Solution:** 
		1. Redesigned into a floating, compact draggable card (`175x110px` mobile, `220x130px` desktop) with aspect ratio preview of streamer avatar/placeholder.
		2. Placed **Mute / Unmute** toggle button on the top-left overlay with `isMiniPlayerMuted` state.
		3. Placed **Close (`X`)** button on the top-right overlay.
		4. Removed the Pause button (live streams cannot be paused).
		5. Tapping card toggles overlay controls fade-in/fade-out; double-tap or tapping title expands to full broadcast room.
	- **Comments:** Fixed and verified via widget test `TC-PIP-02`.

---

## 👤 User Profiles, Roles & Navigation Gating

- [x] **Task QF-03: Suppress "My Profile" Navigation Tab for Non-Streamer Viewers**
	- **Target Files:** `lib/core/routing/app_router.dart`, `lib/core/providers/app_provider.dart`
	- **Problem:** Desktop sidebar and navigation hardcoded a "My Profile" tab pointing to a sample profile (`prof_alghamdi_01`) even when the user is an unverified viewer or guest.
	- **Solution:** Only show "Studio Profile" if `isStreamerModeEnabled`. For ordinary viewers and guests, only Discovery Hub, Spatial GIS Map, and Settings are displayed.
	- **Comments:** Fixed in `app_router.dart`.

---

## 🏷️ Academic Taxonomy & Database Error Resilience

- [x] **Task QF-04: Graceful Fallback for Missing Supabase Tables (PGRST205)**
	- **Target Files:** `lib/core/services/admin_database_service.dart`, `lib/core/providers/app_provider.dart`
	- **Problem:** `PostgrestException: Could not find the table 'public.academic_categories'` and `public.stream_moderators` crashes or alerts the user if remote database migrations have not been applied.
	- **Solution:** Wrapped database calls in `try-catch` blocks that catch `PostgrestException` (`PGRST205`) and safely degrade to local `AcademicCategoryModel.defaultPool` and return empty lists with clear logging instead of throwing uncaught exceptions.
	- **Comments:** Fixed and verified via unit test `TC-DB-RESILIENCE-01`.

- [x] **Task QF-05: Category Bilingual Input Validation & Icon Glyph Picker**
	- **Target File:** `lib/features/admin/presentation/widgets/academic_categories_view.dart`
	- **Problem:** Admins had to type icon names manually and could accidentally place Arabic text in the English field or English text in the Arabic field.
	- **Solution:** 
		1. Added regex validation detecting script mismatch (Arabic characters in English field / Latin characters in Arabic field) with helpful inline warning messages.
		2. Added a visual Material Icon Glyph selector modal (`kAvailableCategoryIcons`) so admins can select discipline icons with one tap.
		3. Optimized dialog layout sizing for desktop viewports (`maxWidth: 520px`).
	- **Comments:** Fixed and verified via unit test `TC-CATEGORY-VALIDATION-01`.

---

## 🔐 Authentication, Multi-Device Sessions & Stream Access Control (`issue_log.md`)

- [x] **Task QF-06: Multi-Device Session Collision & Device Selection Dialog**
	- **Target Files:** `lib/core/models/device_session_model.dart`, `lib/core/widgets/device_session_conflict_dialog.dart`, `lib/core/providers/app_provider.dart`
	- **Problem:** Logging in with the same email across 2 devices causes silent broadcast state collision with no option to manage or pick the active primary device.
	- **Solution:** Add device fingerprint tracking and show a device session conflict dialog on multi-device logins to pick the primary broadcaster device or continue as read-only viewer.
	- **Comments:** Implementation Plan: [[doc/Vault/Implementation_Plan_Issue_Log_Fixes.md]]. Verified via `test/issue_log_fixes_test.dart`.

- [x] **Task QF-07: Streamer vs. Viewer Login Isolation**
	- **Target Files:** `lib/core/providers/app_provider.dart`, `lib/features/profile/presentation/settings_screen.dart`
	- **Problem:** A user could enter the same streamer channel concurrently in both signed-in account and viewer mode without clear identity isolation.
	- **Solution:** Enforce strict session boundary transitions so viewer mode strips broadcast rights and streamer mode activates broadcaster verification.
	- **Comments:** Implementation Plan: [[doc/Vault/Implementation_Plan_Issue_Log_Fixes.md]]. Verified via `test/issue_log_fixes_test.dart`.

- [x] **Task QF-08: Post-Login Broadcaster Onboarding Prompt & Viewer Navigation Isolation**
	- **Target Files:** `lib/core/routing/app_router.dart`, `lib/features/auth/presentation/role_select_screen.dart`, `lib/features/profile/presentation/settings_screen.dart`
	- **Problem:** When a user signs in, they should be prompted to choose whether they want to become a streamer (starting onboarding) or stay a viewer. If they don't apply, they access settings as a viewer and have no "My Profile" tab.
	- **Solution:** Route fresh logins to `/role-select` (or display the onboarding banner) and ensure `isStreamerModeEnabled` is strictly false until verified.
	- **Comments:** Implementation Plan: [[doc/Vault/Implementation_Plan_Issue_Log_Fixes.md]]. Verified in `app_router.dart` and `role_select_screen.dart`.

- [x] **Task QF-09: Discovery Feed "Own Card" Crisp White Border Highlight**
	- **Target File:** `lib/features/discovery/presentation/widgets/streamer_grid_card.dart`
	- **Problem:** Broadcasters cannot easily spot their own channel card in the Discovery feed for testing and monitoring.
	- **Solution:** When `streamer.streamerId == appProvider.currentUserStreamerId` (or matching handle), render a thin white border (`Border.all(color: Colors.white, width: 1.8)`) and a subtle "Your Channel / قناتك" badge.
	- **Comments:** Implementation Plan: [[doc/Vault/Implementation_Plan_Issue_Log_Fixes.md]]. Verified via widget tests in `test/issue_log_fixes_test.dart`.

- [x] **Task QF-10: Cell Tower Broadcast Trigger Guard (Own Channel Only)**
	- **Target File:** `lib/features/profile/presentation/broadcaster_profile_screen.dart`
	- **Problem:** A signed-in streamer visiting another streamer's profile page saw the cell tower broadcast icon, allowing accidental broadcast triggers on other channels.
	- **Solution:** Only display the cell tower icon if the profile belongs to the signed-in streamer (`isOwnStreamerProfile`) or the user is an authorized platform/org admin.
	- **Comments:** Implementation Plan: [[doc/Vault/Implementation_Plan_Issue_Log_Fixes.md]]. Verified in `broadcaster_profile_screen.dart` and `test/issue_log_fixes_test.dart`.

- [x] **Task QF-11: Streamer Key Persistence & Stream Decay Engine Confirmation**
	- **Target Files:** `lib/core/providers/app_provider.dart`, `lib/features/live_stream/services/stream_decay_engine.dart`
	- **Problem:** Stream key credentials must be saved per account handle and the stream decay system confirmed so ghost streams are terminated.
	- **Solution:** Persist stream credentials in `SharedPreferences` keyed by user handle and enforce `StreamDecayEngine` idle timeouts.
	- **Comments:** Implementation Plan: [[doc/Vault/Implementation_Plan_Issue_Log_Fixes.md]]. Verified via `test/issue_log_fixes_test.dart`.

- [x] **Task QF-12: Private Stream Access Control & Guest Feed Filtering**
	- **Target Files:** `lib/core/providers/app_provider.dart`, `lib/features/discovery/presentation/discovery_feed_screen.dart`
	- **Problem:** Clarify and ensure that while Public streams are visible to all users, Private streams with whitelists/knock-gates are strictly hidden from unauthorized guest viewers across devices.
	- **Solution:** Enforce privacy filtering in `AppProvider` and feeds.
	- **Comments:** Implementation Plan: [[doc/Vault/Implementation_Plan_Issue_Log_Fixes.md]]. Verified via `test/issue_log_fixes_test.dart`.

---

## 📱 Mobile Camera Broadcasting & Spatial Map Visual Polish

- [x] **Task QF-13: Single Channel Ownership Rule & Duplicate Disambiguation Dialog**
	- **Target Files:** `lib/core/widgets/duplicate_channel_resolution_dialog.dart`, `lib/core/providers/app_provider.dart`, `lib/features/discovery/presentation/discovery_feed_screen.dart`
	- **Problem:** A single user/email could end up owning multiple streamer channels, creating confusion over which channel is primary.
	- **Solution:** Enforced strict single primary channel ownership per account (`primaryOwnedStreamerId`), built `DuplicateChannelResolutionDialog` prompting the broadcaster to choose which channel to keep, and permanently purged obsolete duplicate records.
	- **Comments:** Verified via `test/issue_log_fixes_test.dart`.

- [x] **Task QF-14: Spatial Map Basemap Zero-Watermark Migration (Esri Dark Gray Canvas)**
	- **Target Files:** `lib/features/map/presentation/spatial_map_screen.dart`, `test/spatial_map_test.dart`
	- **Problem:** The spatial GIS map showed an intrusive "API KEY REQUIRED carto.com/basemaps/apikey" watermark.
	- **Solution:** Switched the basemap to **Esri World Dark Gray Canvas** (`server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}`) with standard OSM fallback, completely eliminating the watermark while preserving the dark aesthetic.
	- **Comments:** Verified via `test/spatial_map_test.dart`.

- [x] **Task QF-15: Spatial Map Marker Stroke Ring & Transparent Gap**
	- **Target Files:** `lib/features/map/presentation/widgets/spatial_streamer_marker.dart`, `lib/features/map/presentation/widgets/offline_marker.dart`, `lib/features/map/presentation/widgets/pulsing_live_marker.dart`
	- **Problem:** Markers had a solid opaque fill behind the avatar.
	- **Solution:** Replaced solid white disc with a transparent interior gap (`color: Colors.transparent`) and a sleek outer stroke ring (`width: 1.8` - `2.2`) around the profile picture.
	- **Comments:** Verified via `test/spatial_map_test.dart`.

- [x] **Task QF-16: Unified Phone Camera Stream Page & Fixed Sensor Rotation / Aspect Ratio Stretching**
	- **Target Files:** `lib/features/live_stream/presentation/screens/phone_broadcast_screen.dart`, `android/app/src/main/kotlin/com/example/streamer_app/streaming/RtmpPublisherView.kt`, `android/app/src/main/kotlin/com/example/streamer_app/streaming/RtmpPublisherBridge.kt`, `lib/features/live_stream/services/rtmp_publish_engine.dart`
	- **Problem:** When broadcasting from the phone camera, the interface was an empty black screen missing the standard stream page features (chat, slides, venue, streamer header, viewer count). Additionally, the camera preview in portrait had letterbox voids, and in landscape it rotated 90 degrees sideways and stretched into a distorted box.
	- **Solution:**
		1. Rebuilt `PhoneBroadcastScreen` to share the exact same rich, unified architecture as `LiveBroadcastScreen` (16:9 player viewport in portrait, full landscape view in fullscreen, broadcaster header, tabs for Live Chat with ghost audience, lecture slides, venue details, and floating viewer reactions).
		2. Added integrated Broadcaster Control Bar directly below/over the player with **Mic Mute Toggle**, **Flip Camera (Front/Back)**, and **End Broadcast** red button.
		3. Fixed sensor rotation and texture stretching by setting `OpenGlView.setAspectRatioMode(AspectRatioMode.ADJUST)` in `RtmpPublisherView.kt`, and added `setOrientation` bridge calls forwarding rotation degrees to RootEncoder's `stream.setOrientation(degrees)` on orientation changes.
	- **Comments:** Verified via `flutter analyze` (0 issues) and full test suite `flutter test` (263/263 passing 100%).


notifications are most important. 
youtube cleaning 




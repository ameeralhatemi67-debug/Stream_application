# Implementation Plan: Cluster 1 Enhancements, Floating Mini-Player Redesign & Navigation Gating

This document outlines the concrete technical plan for resolving all issues identified in [`issue_log.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/issue_log.md) and [`testing_check_list.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/testing_check_list.md).

---

## User Review Required

> [!IMPORTANT]
> **Key Architecture Decisions:**
> 1. **Floating PiP Mini-Player Redesign:** The mini-player transitions from a full-width bottom bar to a compact floating card (`180x120px` draggable window) with **Mute** (top-left) and **Close** (top-right) buttons that fade in/out on tap, with the Pause button removed for live broadcasts.
> 2. **Viewer "My Profile" Suppression:** Regular viewers and guests will not have a "My Profile" tab in navigation or sidebars. Instead, they access Discovery, Spatial Map, and Settings (where a "Become a Broadcaster" application card is available).
> 3. **PGRST205 Supabase Resilience:** All queries to `academic_categories`, `tags`, and `stream_moderators` will catch `PostgrestException` (PGRST205) and fall back seamlessly to local default pools, preventing crashes when database migrations are pending.

---

## Proposed Changes

### 🎬 Component 1: Live Stream Player Viewport & Audio Controls

#### [MODIFY] [`live_player_overlay_controls.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/live_stream/presentation/widgets/live_player_overlay_controls.dart)
- Separate the Fullscreen toggle button from `if (controlsVisible && !widget.isAudioOnly)` so that fullscreen / landscape rotation is **always available** on both video and audio-only streams.
- Ensure the fullscreen button is positioned cleanly in the bottom-right corner without overlapping the audio stage status bar.

---

### 🪟 Component 2: Compact Picture-in-Picture Floating Mini-Player

#### [MODIFY] [`floating_stream_mini_player.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/widgets/floating_stream_mini_player.dart)
- Convert the mini-player into a compact, draggable floating card (`180x110px` mobile, `220x135px` desktop) with rounded corners and glowing border.
- **Top-Left Overlay:** Mute / Unmute toggle button (`Icons.volume_up_rounded` / `Icons.volume_off_rounded`).
- **Top-Right Overlay:** Close button (`Icons.close_rounded`).
- **Remove Pause Button:** Live streams cannot be paused; mute replaces pause.
- **Tap-to-Fade Controls:** Single tap on the card toggles overlay control buttons fade in/out (`AnimatedOpacity`).
- **Tap / Double-Tap Expand:** Restores full broadcast room via `context.push('/live/$streamId')`.

#### [MODIFY] [`app_provider.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/providers/app_provider.dart)
- Add `bool _isMiniPlayerMuted = false`, getter `isMiniPlayerMuted`, and method `toggleMiniPlayerMute()`.

---

### 👤 Component 3: Navigation & Role Gating

#### [MODIFY] [`app_router.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/routing/app_router.dart)
- Remove hardcoded `_DesktopNavItem` for "My Profile" pointing to `prof_alghamdi_01`.
- Conditionally render "Studio Profile / My Profile" **only** when `isLoggedInStreamer && isApprovedStreamer && isStreamerModeEnabled`.
- For viewers and guests, display only Discovery Hub, Spatial GIS Map, and Settings.

---

### 🗄️ Component 4: Database Error Resilience & Offline Fallbacks

#### [MODIFY] [`admin_database_service.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/services/admin_database_service.dart)
- In `loadAcademicCategories()`, `saveAcademicCategory()`, `deleteAcademicCategory()`, `loadAllTags()`, and `loadStreamModerators()`:
  - Wrap queries in `try-catch (e)` blocks.
  - Specifically catch `PostgrestException` with code `PGRST205` ("relation does not exist in schema cache") and log a clear warning while returning default pools / empty lists.

#### [MODIFY] [`app_provider.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/providers/app_provider.dart)
- Ensure `_refreshAcademicCategories()` falls back cleanly to `AcademicCategoryModel.defaultPool` without unhandled errors.

---

### 🏷️ Component 5: Category Validation & Icon Picker in Admin Hub

#### [MODIFY] [`academic_categories_view.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/admin/presentation/widgets/academic_categories_view.dart)
- **Script Mismatch Validation:** Add regex checks in category dialog:
  - Warn if Arabic text (`\u0600-\u06FF`) is entered in the English Name field.
  - Warn if English Latin text (`a-zA-Z`) is entered in the Arabic Name field.
- **Material Icon Glyph Selector Modal:** Add a "Pick Icon" button opening a visual grid dialog of common academic/discipline Material icons (`school`, `mosque`, `computer`, `engineering`, `medical_services`, `business_center`, `menu_book`, `science`, `psychology`, `architecture`, `palette`, `public`).
- **Desktop Sizing:** Expand dialog width on desktop (`maxWidth: 550px`) for comfortable editing.

---

## Verification Plan

### Automated Tests
- Create dedicated unit/widget test file: `test/cluster_1_and_feedback_fixes_test.dart`
  1. `TC-FULLSCREEN-01`: Verify fullscreen button renders and toggles orientation on audio-only streams.
  2. `TC-PIP-02`: Verify floating mini-player card dimensions, mute toggle, and tap-to-fade controls.
  3. `TC-NAV-01`: Verify "My Profile" tab is hidden for viewer/guest roles and visible only for approved streamers.
  4. `TC-DB-RESILIENCE-01`: Verify `loadAcademicCategories` and `loadStreamModerators` degrade gracefully on PGRST205 without throwing.
  5. `TC-CATEGORY-VALIDATION-01`: Verify script mismatch validation flags incorrect language input.

### Manual Verification
- Run `flutter analyze` inside `project/` $\rightarrow$ must report **0 issues**.
- Run `flutter test` $\rightarrow$ must pass **100% green**.
- Test audio live stream fullscreen button, test floating mini-player dragging/muting, test non-streamer navigation, and test Admin Hub category dialog.

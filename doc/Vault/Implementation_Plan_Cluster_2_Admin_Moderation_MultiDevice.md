# 🗺️ Implementation Plan: Cluster 2 Spatial Map, Admin Moderation Pipeline & Realtime Multi-Device Governance

This comprehensive technical specification is prepared for execution by **Claude Code**. It resolves all items in [`issue_log.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/issue_log.md), completes **Cluster 2 (Spatial Map & GIS)**, and addresses all feedback comments on **Tasks 4b, 11, 12, 13, 15, 16, and 18** from [`testing_check_list.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/testing_check_list.md).

---

## 🎯 Architecture Objectives & Scope

```mermaid
graph TD
    A[User Sign-In / Auth Session] --> B{Identity & Role Resolution}
    B -->|polkgvd2@gmail.com / Approved App| C[Verified Broadcaster / Channel Owner]
    B -->|Other Emails / No Application| D[Standard Viewer / Student]
    
    D --> E[Suppressed My Profile Tab]
    D --> F[Show Post-Login Broadcaster Onboarding Modal]
    D --> G[Viewer Profile Editor: Name/Avatar Only]
    
    C --> H[Discovery Feed: White Border + Your Channel Badge]
    C --> I[Own Profile Only: Cell Tower Go-Live Launcher]
    
    J[Multi-Device Sign-In] --> K{Active Remote Session?}
    K -->|Yes| L[DeviceSessionConflictDialog: Transfer Broadcaster vs Continue as Viewer]
    K -->|No| M[Register Active Local Session]
    
    N[Admin Hub Governance] --> O[Academic Categories: Bilingual Regex + Glyph Selector + Supabase Broadcast]
    N --> P[Tag Moderation: Active Tags List + Broadcaster Drill-Down + Rename/Merge]
    N --> Q[Chat Governance: Admin/Mod Badges + 3+ Report Threshold Alerts + Muted Chatters Audit]
    N --> R[Map Moderation: Resilient Map Visibility Toggle + Deletion Realtime Broadcast]
    N --> S[Placeholder Pipeline: Image Hash Auto-Approval Cache]
    
    T[Cluster 2 Spatial Map] --> U[CartoDB Dark Matter / OSM Tile Provider Resilience]
    T --> V[Marker White Circular Disc High-Contrast Backing]
    T --> W[One-Click Google Maps External Navigation Launcher]
```

---

## 📋 Detailed Task Breakdown & Code Modifications

---

### 🗺️ Part 1: Cluster 2 — Spatial Map & GIS Navigation Polish

#### 1. Task 7: Free Carto / OpenStreetMap Basemap Tiles (`lib/features/map/presentation/spatial_map_screen.dart`)
* **Problem:** Tiles occasionally failed to load or showed grey squares when raster subdomains or fallback providers were interrupted.
* **Requirements:**
  1. Ensure `kSpatialMapTileUrlTemplate` points to `'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png'` with `subdomains: ['a', 'b', 'c', 'd']` and custom `userAgentPackageName: 'sa.streamer.app'`.
  2. Implement automatic silent tile error fallback to `kSpatialMapTileFallbackUrl` (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
  3. Ensure max/min zoom bounds and camera bounds keep the viewport cleanly inside the Eastern Province / Saudi Arabia bounding box without crashing.

#### 2. Task 8: White Disc Background for Spatial Map Markers (`lib/features/map/presentation/widgets/spatial_streamer_marker.dart`, `offline_marker.dart`, `pulsing_live_marker.dart`)
* **Problem:** Avatars on the dark basemap blend into the background, making offline markers and subtle audio pulses hard to distinguish.
* **Requirements:**
  1. Wrap the avatar inside a clean white circular disc backing:
     ```dart
     Container(
       padding: const EdgeInsets.all(2.0),
       decoration: const BoxDecoration(
         color: Colors.white,
         shape: BoxShape.circle,
         boxShadow: [
           BoxShadow(
             color: Colors.black45,
             blurRadius: 6,
             offset: Offset(0, 2),
           ),
         ],
       ),
       child: CircleAvatar(
         radius: avatarRadius,
         backgroundImage: avatarImageProvider,
       ),
     )
     ```
  2. For Organization markers (`isOrganization == true`), apply the same white backing as a squircle / rounded rectangle (`borderRadius: BorderRadius.circular(10)`).

#### 3. Task 9: One-Click Google Maps Navigation Integration (`lib/features/map/presentation/widgets/venue_navigation_sheet.dart`, `marker_summary_card.dart`)
* **Problem:** Tapping "Open in Google Maps" must reliably open the Google Maps app or web directions with coordinates.
* **Requirements:**
  1. In `VenueNavigationSheet` and `MarkerSummaryCard`, format the navigation URL as:
     `https://www.google.com/maps/dir/?api=1&destination=${streamer.latitude},${streamer.longitude}`
  2. Call `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)` with try-catch and a fallback to browser mode.

---

### 🛡️ Part 2: Admin Moderation, Chat Governance & Taxonomy Enhancements

#### 4. Task 4b: Custom Streamer Placeholders & Auto-Approval Pipeline (`lib/features/admin/presentation/widgets/custom_placeholder_review_view.dart`, `lib/core/providers/app_provider.dart`)
* **Requirements:**
  1. Add an in-memory & SharedPreferences hash/URL cache `_approvedPlaceholderUrls = <String>{}`.
  2. When a streamer uploads/selects a placeholder card whose image URL or asset path has already been approved previously, mark its status immediately as `PlaceholderStatus.approved` without sending it to the admin review queue.
  3. In `CustomPlaceholderReviewView`, display both pending submissions and approved presets.

#### 5. Task 11: Academic Categories Management & Realtime Sync (`lib/features/admin/presentation/widgets/academic_categories_view.dart`, `lib/core/providers/app_provider.dart`, `lib/core/services/admin_database_service.dart`)
* **Requirements:**
  1. Ensure desktop dialogs have a wide, comfortable layout (`maxWidth: 580px`).
  2. Include the Material Icon Glyph Selector Modal (`kAvailableCategoryIcons`) for one-tap selection.
  3. Keep regex bilingual script validation active (detecting Arabic in English field / English in Arabic field).
  4. Ensure `try-catch` around `PostgrestException` (`PGRST205`) falls back cleanly to local state.
  5. In `AppProvider`, broadcast category updates across listeners and subscribe to Supabase realtime table changes on `academic_categories` so all running client instances update live without restarting.

#### 6. Task 12: Admin Controls on Tags & Broadcaster Drill-Down (`lib/features/admin/presentation/widgets/tag_moderation_view.dart`, `lib/core/providers/app_provider.dart`)
* **Requirements:**
  1. In `TagModerationView`, display the full list of **Active / Approved Tags** with streamer usage counts (e.g. `#ArtificialIntelligence (4 broadcasters)`).
  2. Add an interactive **"Inspect Broadcasters"** button/tap on each tag chip that opens a modal bottom sheet / dialog displaying all streamers currently tagged with that discipline.
  3. Support inline tag editing: Rename/Merge tag across all associated streamers with one confirmation tap.

#### 7. Task 13 & 15: Live Chat Governance, Admin/Mod Badges & Moderation Alert Thresholds (`lib/features/live_stream/presentation/widgets/live_chat_widget.dart`, `lib/features/admin/presentation/widgets/role_permission_management_view.dart`, `lib/core/providers/app_provider.dart`)
* **Requirements:**
  1. **Visual Chat Badges:**
     - Admin messages: Render a gold `👑 ADMIN / المشرف العام` badge with gold subtle border styling.
     - Moderator messages: Render a cyan `🛡️ MOD / مشرف البث` badge.
  2. **In-Stream Moderator Alert Threshold ($3+$ User Reports/Hides):**
     - Track local report/hide count per chatter ID in `AppProvider`.
     - When a user receives $\ge 3$ reports or hides within a stream, display a high-priority in-stream banner/toast *strictly to moderators and admins in the room*:
       *"⚠️ Chatter [User] has been reported/hidden by 3+ viewers. [Quick Mute] [Block]"*.
     - Tapping `[Quick Mute]` mutes the user for 10 minutes and removes their recent messages.
  3. **Muted Chatters Audit Table:**
     - In Admin Hub $\rightarrow$ Chat Moderation tab, add a dedicated section: **"Muted Chatters Audit Log"**, displaying:
       - User name / handle.
       - Total streams muted in.
       - Reason / trigger (e.g. "3+ viewer reports threshold", "Manual moderator action").
       - Last 3 messages sent prior to being muted.
  4. **Resilient Stream Moderators Table:**
     - Handle `public.stream_moderators` gracefully with local in-memory fallback to prevent `PostgrestException PGRST205`.

#### 8. Task 16: Account Ban Notification & Error Feedback (`lib/features/auth/presentation/welcome_screen.dart`, `lib/core/routing/app_router.dart`, `lib/features/admin/presentation/widgets/banned_accounts_view.dart`)
* **Requirements:**
  1. When a banned email attempts to sign in via Google OAuth or opens the app:
     - Show an explicit localized alert dialog or toast:
       *"⛔ Account Suspended: Your access has been suspended by administration. Reason: [Ban Reason]. Contact support@streamer.app for assistance."*
     - Ensure redirection to `/account-banned` displays the exact admin ban reason.

#### 9. Task 18: Streamer Map Visibility Moderation (`lib/features/admin/presentation/widgets/org_management_view.dart`, `lib/core/services/admin_database_service.dart`, `lib/core/providers/app_provider.dart`)
* **Requirements:**
  1. In `AdminDatabaseService.updateStreamerMapVisibility`, wrap the remote database call in a `try-catch` block.
  2. If the remote table is unavailable, update local `AppProvider` state (`s.copyWith(isTemporarilyHiddenFromMap: isHidden)`) and notify listeners immediately so the UI toggle succeeds with zero "Failed to update map visibility" errors.

---

### 🔐 Part 3: New Multi-Device, Identity Isolation & Onboarding Issues (`issue_log.md`)

#### 10. Strict Identity Isolation & Suppression of `prof_alghamdi_01` for Arbitrary Logins
* **Problem:** In previous tests, signing in with 3 different email accounts caused all 3 accounts to inherit the `Amir Al-Hatemi` / `prof_alghamdi_01` streamer channel.
* **Root Cause & Fix in `AppProvider`:**
  - `prof_alghamdi_01` was a sample mock streamer.
  - In `isOwnStreamerProfile(String streamerId)` and `currentUserStreamerId`:
    ```dart
    bool isOwnStreamerProfile(String streamerId) {
      if (streamerId.isEmpty) return false;
      final currentUserId = _authService.currentSession?.user.id;
      if (currentUserId != null && streamerId == currentUserId) return true;
      if (_myApplication != null && _myApplication!.applicantProfileId == streamerId) return true;
      if (_myApplication != null && _myApplication!.youtubeHandle.replaceAll('@', '').toLowerCase() == streamerId.toLowerCase()) return true;
      if (_selectedBroadcastOrgId != null && _selectedBroadcastOrgId == streamerId) return true;
      
      // ONLY polkgvd2@gmail.com (or explicit test mock) owns prof_alghamdi_01:
      final email = _googleUserEmail?.toLowerCase().trim();
      if (email == 'polkgvd2@gmail.com' && streamerId == 'prof_alghamdi_01') {
        return true;
      }
      return false;
    }
    ```
  - For any other signed-in email with no approved application, `isApprovedStreamer` is `false`, `isStreamerModeEnabled` is `false`, and `isOwnStreamerProfile` returns `false` for all existing channels.
  - The user has **ZERO** channels and is treated as a pure Viewer.

#### 11. Single Channel Ownership Rule
* **Requirements:**
  - An individual scholar account is strictly limited to owning at most **1** personal broadcaster channel.
  - Only authorized Organization Owners / Co-Owners can manage multiple campus/venue branches.

#### 12. Realtime Multi-Device Collision Prompt on Sign-In (`lib/core/widgets/device_session_conflict_dialog.dart`, `lib/core/providers/app_provider.dart`, `lib/features/auth/presentation/welcome_screen.dart`)
* **Requirements:**
  1. On app start / OAuth sign-in completion, `AppProvider.initDeviceSession()` checks if this account has an active broadcaster session recorded on a different device fingerprint.
  2. If an active session exists on another device, immediately display `DeviceSessionConflictDialog` on the top-level `NavigatorState` (or via `WelcomeScreen` / `AppRouter` callback), giving the user two clear choices:
     - **"Transfer Broadcaster to This Device"**: Transfers broadcast token to current device and demotes the other session.
     - **"Continue as Viewer"**: Keeps broadcaster on the first device and enters read-only viewer mode on this device.

#### 13. Post-Login Broadcaster Onboarding Prompt (`lib/features/auth/presentation/widgets/broadcaster_onboarding_dialog.dart`, `lib/features/discovery/presentation/discovery_feed_screen.dart`, `lib/core/routing/app_router.dart`)
* **Requirements:**
  1. When a user signs in for the first time (`!hasCompletedRoleSelection && !isApprovedStreamer`):
     - Automatically present the **Broadcaster Onboarding Prompt** (or bottom sheet) immediately upon entering the app:
       *"Welcome to Streamer App! Would you like to apply to become an Academic Broadcaster or explore live lectures as a Viewer?"*
     - If user selects **"Apply to Become a Broadcaster"**: Navigates to `/streamer-apply`.
     - If user selects **"Explore as Viewer"**: Sets `selectViewerRole()`, navigates to `/feed`.
  2. In `SettingsScreen`, non-verified viewers see a prominent **"Apply for Academic Broadcaster Verification"** action card in Section 1.5.

#### 14. Viewer Profile Editor vs. Broadcaster Application Separation (`lib/features/profile/presentation/settings_screen.dart`, `lib/features/profile/presentation/widgets/viewer_profile_editor_dialog.dart`)
* **Requirements:**
  1. Tapping "Edit Profile" as a non-verified viewer opens `ViewerProfileEditDialog` (allowing editing of Display Name EN/AR, Avatar) and **NEVER** opens `BroadcasterApplicationSheet`.
  2. The broadcaster application flow is strictly invoked from the dedicated "Apply for Verification" button or the post-login onboarding prompt.

#### 15. Absolute Cell Tower Visibility Restriction (Own Channel Only) (`lib/features/profile/presentation/broadcaster_profile_screen.dart`)
* **Requirements:**
  - Remove all admin override checks from the cell tower visibility condition.
  - The cell tower icon in `AppBar.actions` is rendered **ONLY** if:
    ```dart
    if (appProvider.isLoggedInStreamer &&
        appProvider.isApprovedStreamer &&
        appProvider.isOwnStreamerProfile(streamer.streamerId))
    ```
  - Admins, moderators, and other broadcasters visiting a channel will NEVER see the cell tower icon.

#### 16. Realtime Account Deletion Synchronization Across All Devices (`lib/core/providers/app_provider.dart`, `lib/core/services/admin_database_service.dart`)
* **Requirements:**
  1. When an admin deletes an application or streamer profile via `deleteBroadcasterApplication(id)`:
     - Remove the streamer from `_streamers` locally on the admin device.
     - Broadcast a Realtime channel broadcast event (`streamer_deleted`, payload: `streamerId`) via Supabase Realtime so that connected mobile devices, web clients, and desktops receive the event and immediately remove the streamer from their local `_streamers` list and notify listeners.

---

## 🧪 Verification Plan

### Automated Test Suite (`test/cluster_2_and_moderation_pipeline_test.dart`)
1. **Map Basemap & Marker Disc Tests:**
   - Verify `kSpatialMapTileUrlTemplate` contains valid CartoDB raster subdomains and fallback URL.
   - Verify `SpatialStreamerMarker` renders white disc backing behind avatar.
2. **Google Maps Launcher Tests:**
   - Verify `buildGoogleMapsSearchUrl` formats coordinates correctly.
3. **Academic Categories & Tag Drill-Down Tests:**
   - Verify category bilingual script validator rejects script mismatch.
   - Verify `TagModerationView` lists active tags and resolves associated broadcasters.
4. **Chat Moderation Alert Tests:**
   - Verify 3+ report threshold triggers moderator alert and mute action.
   - Verify Admin/Mod badges render on chat messages.
5. **Multi-Device & Identity Isolation Tests:**
   - Verify arbitrary email logins do not inherit `prof_alghamdi_01`.
   - Verify `isOwnStreamerProfile` strictly returns true only for the true owner.
   - Verify cell tower icon is strictly hidden for non-owners (including admins).

### Execution Commands
```bash
flutter analyze
flutter test
```
*Expected Result: 0 analysis errors, 100% tests passing green.*

---

## 🚀 Prompt for Claude Code

```text
Please implement the tasks specified in the implementation plan: "Implementation Plan: Cluster 2 Spatial Map, Admin Moderation Pipeline & Realtime Multi-Device Governance".

Key Focus Areas:
1. Spatial Map (Cluster 2): CartoDB Dark Matter basemap resilience, high-contrast white disc backing for streamer markers, and one-click Google Maps navigation launcher.
2. Admin Moderation & Governance:
   - Task 4b: Placeholder image hash auto-approval cache.
   - Task 11: Academic categories desktop layout, Material icon picker, bilingual regex validation, and Supabase realtime broadcast sync.
   - Task 12: Active tags list with streamer count badge, broadcaster drill-down modal, and tag rename/merge.
   - Tasks 13 & 15: Live chat Admin (👑) & Mod (🛡️) badges, 3+ report in-stream moderator alert threshold with 1-tap quick mute, muted chatters audit log, and resilient stream_moderators handling.
   - Task 16: Localized account suspension dialog/feedback on banned login attempt.
   - Task 18: Resilient streamer map visibility toggle with local state fallback.
3. New Multi-Device, Identity Isolation & Onboarding Fixes:
   - Fix Amir Al-Hatemi / prof_alghamdi_01 channel misattribution so arbitrary email logins default to pure Viewers with 0 channels.
   - Enforce 1-channel limit per scholar account.
   - Wire DeviceSessionConflictDialog into login flow for multi-device detection.
   - Add post-login onboarding prompt for first-time sign-ins.
   - Separate Viewer Profile Editor (name/avatar) from Broadcaster Application in Settings.
   - Restrict cell tower Go-Live button strictly to own channel (zero admin override).
   - Realtime broadcast synchronization for deleted accounts across devices.

Run `flutter analyze` and `flutter test` upon completion and ensure all tests pass cleanly.
```

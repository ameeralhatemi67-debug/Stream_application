# Implementation Plan: Account Permissions, Multi-Device Sessions, Onboarding & Feed Isolation (`issue_log.md`)

This implementation plan resolves the complete set of authentication, multi-device conflict resolution, streamer onboarding gating, cell-tower broadcaster trigger permissions, Discovery feed own-card visual highlighting, stream key decay persistence, and private stream access verification defined in [`issue_log.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/issue_log.md).

---

## User Review Required

> [!IMPORTANT]
> **Key Architecture Decisions for Review:**
> 1. **Multi-Device Conflict Resolution:** When a user signs into an existing account that already has an active registered device session, the app presents a glassmorphic **Device Session Conflict Dialog** allowing the user to either:
>    - *Switch & Set this Device as Primary Active Broadcaster* (invalidates/revokes previous device token).
>    - *Continue as Read-Only Viewer on this Device* (preserves previous device broadcaster rights).
> 2. **Cell Tower Broadcast Trigger Guard:** The `Icons.cell_tower_rounded` icon in the app bar will ONLY appear if:
>    - User is logged in as an approved streamer / admin, **AND**
>    - The profile screen being viewed belongs to the signed-in streamer themselves (`isOwnStreamerProfile`), or the user is an authorized Org Owner / Platform Admin. A broadcaster visiting another broadcaster's profile will never see the cell tower.
> 3. **Discovery Feed "Own Card" Highlight:** A streamer's own card in the Discovery Hub grid and list will feature a distinctive, crisp white border (`Border.all(color: Colors.white, width: 1.8)`) with a glowing badge reading *"Your Channel / قناتك"* so broadcasters can instantly locate their own live broadcast and card during QA and live streaming.
> 4. **Post-Login Role Gating & Onboarding:** Newly signed-in users who have not submitted a broadcaster application are routed to `/role-select` or shown the "Become a Verified Broadcaster" onboarding card in Settings. Their `isStreamerModeEnabled` is strictly `false` until approved, preventing unauthorized "My Profile" channel views.

---

## Proposed Changes

### Component 1: Multi-Device Session Management & Conflict Dialog
- **Target Files:**
  - `lib/core/models/device_session_model.dart` `[NEW]`
  - `lib/core/services/supabase_auth_service.dart` `[MODIFY]`
  - `lib/core/providers/app_provider.dart` `[MODIFY]`
  - `lib/core/widgets/device_session_conflict_dialog.dart` `[NEW]`
- **Details:**
  - Create `DeviceSessionModel` with `deviceId`, `deviceName`, `platform` (Web, Windows, iOS, Android), `lastActiveAt`, and `isPrimaryBroadcaster`.
  - When signing in, register the local device fingerprint in `SharedPreferences` and Supabase `device_sessions` table (or local cache).
  - If another active broadcaster device exists for this email, prompt with `DeviceSessionConflictDialog` to resolve primary broadcaster ownership.

---

### Component 2: Discovery Feed Streamer Card Self-Highlight
- **Target Files:**
  - `lib/features/discovery/presentation/widgets/streamer_grid_card.dart` `[MODIFY]`
  - `lib/core/providers/app_provider.dart` `[MODIFY]`
- **Details:**
  - Add `isOwnCard` check: compare `streamer.streamerId` with `appProvider.currentStreamerId` or `streamer.handle` with `appProvider.currentUserHandle`.
  - If `isOwnCard`:
    - Apply `borderColor = Colors.white`, `borderWidth = 1.8`.
    - Render a top-right corner pill: `✨ Your Channel` / `قناتك`.

---

### Component 3: Cell Tower Broadcaster Launcher Permission Boundaries
- **Target Files:**
  - `lib/features/profile/presentation/broadcaster_profile_screen.dart` `[MODIFY]`
  - `lib/core/providers/app_provider.dart` `[MODIFY]`
- **Details:**
  - Add helper method `bool isOwnStreamerProfile(String streamerId)` in `AppProvider`.
  - Gate the `Icons.cell_tower_rounded` button in `broadcaster_profile_screen.dart`:
    ```dart
    if (appProvider.isLoggedInStreamer &&
        appProvider.isStreamerModeEnabled &&
        (appProvider.isOwnStreamerProfile(streamer.streamerId) ||
         appProvider.isAdminUser ||
         appProvider.isPermittedAdminFor(streamer.streamerId)))
    ```

---

### Component 4: Post-Login Role Routing & Broadcaster Onboarding Gating
- **Target Files:**
  - `lib/core/routing/app_router.dart` `[MODIFY]`
  - `lib/core/providers/app_provider.dart` `[MODIFY]`
  - `lib/features/auth/presentation/role_select_screen.dart` `[MODIFY]`
  - `lib/features/profile/presentation/settings_screen.dart` `[MODIFY]`
- **Details:**
  - On fresh Google sign-in for users with no prior application:
    - If `!provider.hasCompletedRoleSelection`, redirect to `/role-select`.
    - Users can select **Viewer / Student** (routes to `/feed`, keeps `isStreamerModeEnabled = false`, no "My Profile" tab) or **Apply to Become Broadcaster** (routes to `/streamer-apply`).
  - In `SettingsScreen`, viewers see a prominent *"Apply for Broadcaster Verification"* banner with one-tap onboarding.

---

### Component 5: Stream Key Account Persistence & Stream Decay Confirmation
- **Target Files:**
  - `lib/core/providers/app_provider.dart` `[MODIFY]`
  - `lib/features/live_stream/services/stream_decay_engine.dart` `[NEW / REINFORCE]`
- **Details:**
  - Save `phoneBroadcastStreamKey`, `customLiveTitle`, and `customLiveCategory` in `SharedPreferences` keyed per user handle: `stream_key_${userHandle}`.
  - Implement `StreamDecayEngine`: If an active live stream receives no RTMP packets / health heartbeats for > 180 seconds, trigger auto-decay to prevent ghost streams.

---

### Component 6: Stream Privacy Filtering (Public vs Private Cross-Device Sync)
- **Target Files:**
  - `lib/core/providers/app_provider.dart` `[MODIFY]`
  - `lib/features/discovery/presentation/discovery_feed_screen.dart` `[MODIFY]`
- **Details:**
  - Enforce feed filtering:
    - **Public Streams:** Visible to all users (signed-in and guest viewers).
    - **Private Streams:** Filtered out of Discovery feed and Map unless the viewer's handle is explicitly present in `streamer.whitelistHandles` or admitted via knock-gate.

---

## Verification Plan

### Automated Tests
- Create [`test/issue_log_fixes_test.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/test/issue_log_fixes_test.dart) covering:
  - `TC-ISSUE-01`: Multi-device session conflict detection and resolution.
  - `TC-ISSUE-02`: Cell tower icon suppressed when visiting another streamer's profile.
  - `TC-ISSUE-03`: Streamer card renders crisp white border when `isOwnCard == true`.
  - `TC-ISSUE-04`: New user sign-in role routing and viewer profile tab suppression.
  - `TC-ISSUE-05`: Stream key persistence keyed by user handle.
  - `TC-ISSUE-06`: Private stream feed filtering for unauthorized guest viewers.
- Run `flutter analyze` (0 issues).
- Run `flutter test` (all 252+ tests passing).

### Manual Verification
- Launch app on desktop and verify streamer card border highlight in Discovery.
- Test viewing another streamer's channel and confirm cell tower icon is hidden.
- Sign in as a new user and confirm the role selection / onboarding flow.

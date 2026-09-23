# Final P6 Acceptance Testing & Evidence Report

**Date:** 2026-09-23  
**Evaluator:** Platform Owner & AI Engineering Pair  
**Environment:** 
- **Physical Phone:** Android Device (`R5CY42JAW4E`) running Hadayah Live (Debug)
- **Desktop Clients:** Google Chrome (`localhost:7357`) under Master Admin & Secondary Viewer sessions
- **Backend:** Hosted Supabase Project (`zkkmfjsjouqzibvnzkau.supabase.co`) — 55/55 migrations synchronized
**Final Verdict:** **CONDITIONALLY ACCEPTED WITH REMEDIATION BACKLOG**  
*(Admin Hub, multi-device detection, user directory, keyword moderation, and honest KPIs are fully verified on physical hardware; broadcaster session demotion, verified streamer onboarding state, and 5 mobile layout overflows are cataloged for immediate code fix).*

---

## 1. Executive Summary & Verification Highlights

Today’s physical device acceptance run achieved two critical milestones:
1. **Resolution of Hosted Database Drift:**
   Executed `npx supabase db push --linked --include-all --yes` to apply **36 pending migrations** (`20260829000000` through `20260923140000`). The remote hosted database is now **100% in sync** (55/55 migrations).
2. **End-to-End System Integrity:**
   `flutter test` passed with **514 passing tests, 0 failures**, and `flutter analyze` completed with **0 static analysis issues**.

---

## 2. Verified Functionality & Photographic Evidence

All 29 screenshots are organized into `brief/evidence/2026-09-23/p6-owner-acceptance/screenshots/`:

| Verification Area | Verified Behavior | Key Evidence Screenshot |
| :--- | :--- | :--- |
| **P6-01: Desktop Navigation** | Responsive sidebar on left at desktop width; clean drawer on mobile. | [`good/P6-01-admin-desktop-en.png`](screenshots/good/P6-01-admin-desktop-en.png) |
| **P6-01: Honest Metrics** | Unmeasured analytics display "Unavailable" instead of fake sample data. | [`good/P6-01-admin-desktop-en-overview.png`](screenshots/good/P6-01-admin-desktop-en-overview.png) |
| **P6-01: Language & RTL** | Top app bar language toggle flips layout to Arabic RTL; persists across F5 hard reloads. | Verified on Chrome Desktop |
| **P6-01: Route Security** | Direct URL navigation to `/admin` blocks non-admin users and bounces to Feed. | Verified on Chrome Secondary |
| **P6-06: Chat Keywords** | Banned keyword `testword1` added successfully; match mode dropdown (`Anywhere in text` / `Whole word`) works; word boundary normalization active (`hell` no longer blocks `hello`). | [`good/P6-06-desktop-keywords-testword-added-whole-word.png`](screenshots/good/P6-06-desktop-keywords-testword-added-whole-word.png) |
| **P6-07: Multi-Device Login** | System detects concurrent active logins and presents collision dialog on both Windows and Android. | [`good/P6-07-desktop-multi-device-login-detected.png`](screenshots/good/P6-07-desktop-multi-device-login-detected.png)<br>[`good/P6-07-mobile-multi-device-login-detected.jpg`](screenshots/good/P6-07-mobile-multi-device-login-detected.jpg) |
| **P6-08: User Directory** | Real-time search filters users; user accounts are permanently persisted in `auth.users` and `public.profiles`. | [`good/P6-08-mobile-profile-broadcaster-settings-saved.jpg`](screenshots/good/P6-08-mobile-profile-broadcaster-settings-saved.jpg) |
| **P6-07: Broadcaster Studio UI** | Broadcaster quick controls sheet (Mic, Rear Camera, Video Stream, End Stream) renders correctly. | [`good/P6-07-mobile-broadcast-controls-sheet.jpg`](screenshots/good/P6-07-mobile-broadcast-controls-sheet.jpg) |

---

## 3. Discovered Defects & Engineering Diagnostics

During testing, the owner and diagnostic logs uncovered 4 functional defects and 5 UI layout overflows:

### Defect 1: Multi-Device Session Switching Does Not Auto-Demote
* **Symptom:**
  * Clicking "Continue as Viewer" on the collision dialog does not automatically navigate the user to the Discovery Feed (`/feed`).
  * Clicking "Transfer Broadcaster to This Device" does not immediately demote the other device to Viewer mode.
* **Root Cause:**
  1. `AppProvider.continueAsViewerOnCurrentDevice()` only mutates in-memory flags without invoking `AppRouter.rootNavigatorKey.currentContext?.go('/feed')`.
  2. The remote device only checks broadcaster ownership during its 30-second heartbeat loop (`_heartbeatDevice()`) rather than receiving an immediate realtime push on the `device_sessions` table.
* **Remediation:** Wire `go('/feed')` to "Continue as Viewer" and attach a Postgres realtime listener to `device_sessions` so session demotions take effect instantly across active screens.

### Defect 2: Broadcast Session Update Blocked (`set_live_state` 42501)
* **Symptom:**
  * When starting a broadcast on the phone, a toast notification reports:
    > *"The broadcast session could not be updated. Check your connection and try again."*
* **Root Cause:**
  * In `20260920130000_live_flag_expiry_and_privilege_guards.sql`, `set_live_state()` requires:
    1. The caller device must be the registered `is_primary_broadcaster` in `device_sessions`.
    2. `public.can_broadcast()` must return `true`.
  * For a personal broadcast (`p_org_id is null`), `can_broadcast` strictly enforces:
    ```sql
    exists(select 1 from public.profiles where id = auth.uid() and is_streamer and is_verified)
    ```
  * In production, the test account `Amir Alhatime` toggled broadcaster mode locally on the client, but had not been granted `is_streamer = true` and `is_verified = true` by an Admin in the backend database. PostgreSQL correctly raised exception `42501: Broadcast not permitted`.
* **Remediation:** In the Admin Hub Verification Queue, approve the broadcaster application for the test account, or provide an admin toggle to set `is_verified = true` on the profile.

### Defect 3: Inconsistent Onboarding Prompt ("Visitor vs Streamer")
* **Symptom:**
  * Existing users sometimes receive the prompt *"Do you want to be a visitor or streamer?"* (`/role-select`) on app launch or F5 reload.
  * Newly signed-in users sometimes bypass the prompt entirely.
* **Root Cause:**
  * `AppProvider._hasCompletedRoleSelection` was stored only in RAM (`bool _hasCompletedRoleSelection = false;`) and was never written to `SharedPreferences`.
  * Every page refresh (F5) or mobile reboot reset it to `false`. Non-streamer profiles (`is_streamer = false`) failed the router check `if (!provider.hasCompletedRoleSelection && !provider.isApprovedStreamer)` and were bounced back to `/role-select`.
* **Remediation:** Save `has_completed_role_selection_{userId}` in `SharedPreferences` upon role confirmation so the preference survives restarts.

### Defect 4: Mobile Layout Overflows (5 Hazard Stripes)

1. **Verification Queue Filter Row (51px overflow):**
   * Non-scrollable horizontal `Row` with search field + 4 filter chips exceeds mobile viewport.
   * Screenshot: [`issue/P6-01-mobile-verification-queue-overflow-51px.jpg`](screenshots/issue/P6-01-mobile-verification-queue-overflow-51px.jpg).
2. **Broadcasters Card Moderation Row (133px overflow):**
   * Broadcaster item row places avatar + text + status badge + map switch toggle + edit + delete in a single unconstrained row.
   * Screenshot: [`issue/P6-01-mobile-broadcasters-card-overflow-133px.jpg`](screenshots/issue/P6-01-mobile-broadcasters-card-overflow-133px.jpg).
3. **Governance & Terms Header (77px overflow) & Cramped Editors:**
   * Header `Row` overflows; English and Arabic markdown textareas placed side-by-side get only ~150px width each on phone.
   * Screenshot: [`issue/P6-01-mobile-terms-overflow-77px-cramped.jpg`](screenshots/issue/P6-01-mobile-terms-overflow-77px-cramped.jpg).
4. **Academic Categories Header (1.5px overflow):**
   * Sub-pixel rounding overflow on narrow device screens.
   * Screenshot: [`small_edit/P6-01-mobile-categories-overflow-1.5px.jpg`](screenshots/small_edit/P6-01-mobile-categories-overflow-1.5px.jpg).
5. **Live Chat Keyboard Overflow (56px bottom overflow):**
   * Opening the Android software keyboard inside the broadcast room pushes the bottom composer into an unscrollable view.
   * Screenshot: [`issue/P6-07-mobile-broadcast-keyboard-overflow-56px.jpg`](screenshots/issue/P6-07-mobile-broadcast-keyboard-overflow-56px.jpg).

---

## 4. Architectural Reference Blueprints

For ongoing development and future audits, the broadcasting logic pipelines are documented in:
* **Mobile Native RTMP (Pipeline 6):** [`MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md`](../../../doc/MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md#L653-L700) & [`Phone_to_YouTube_Live_API_Implementation_Plan.md`](../../../doc/Roadmap/Phone_to_YouTube_Live_API_Implementation_Plan.md)
* **OBS Desktop Studio (Pipeline 7):** [`MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md`](../../../doc/MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md#L702-L732) & [`Gamified_Streamer_Setup_Guide_Spec.md`](../../../doc/Roadmap/Gamified_Streamer_Setup_Guide_Spec.md)
* **Local LAN Air-Gapped (Pipeline 8):** [`MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md`](../../../doc/MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md#L734-L760) & [`Local_Phone_Streaming_Feature_Spec.md`](../../../doc/Roadmap/Local_Phone_Streaming_Feature_Spec.md)
* **Unified UI & Technical Feasibility:** [`Go_Live_Studio_BottomSheet_Redesign_Plan.md`](../../../doc/Roadmap/Go_Live_Studio_BottomSheet_Redesign_Plan.md) & [`Cloud Streaming Project Viability Research with diagrams.md`](../../../doc/research%20docs/Cloud%20Streaming%20Project%20Viability%20Research%20with%20diagrams.md)

---

## 5. Next Steps for Remediation Sprint

| Priority | Task | Target File(s) |
| :---: | :--- | :--- |
| **P0** | Persist role selection state in `SharedPreferences` to prevent `/role-select` prompt bouncing on F5/boot. | `lib/core/providers/app_provider.dart`<br>`lib/core/routing/app_router.dart` |
| **P0** | Fix multi-device transfer: add auto-route to `/feed` on "Continue as Viewer" and realtime session demotion. | `lib/core/widgets/device_session_conflict_dialog.dart`<br>`lib/core/providers/app_provider.dart` |
| **P1** | Wrap mobile Admin Hub rows in horizontal scroll / vertical stack to eliminate the 5 pixel overflow hazard stripes. | `lib/features/admin/presentation/admin_hub_screen.dart`<br>`lib/features/live_stream/presentation/screens/phone_broadcast_screen.dart` |
| **P1** | Add missing Arabic localization strings in `ar.json` for Chat Moderation & Roles tabs. | `assets/i18n/ar.json` |
| **P2** | Grant `is_streamer = true` and `is_verified = true` to test account in `profiles` to enable live broadcast session creation. | Supabase Admin / Verification Queue |

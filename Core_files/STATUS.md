---
type: status
project: Streamer_app
updated: 2026-09-23
phase: release_hardening
health: release_blocked
---

# Project status: Streamer App

## Current release status (2026-09-23)

The app is not publish-ready. P6.4 directory and device access were locally verified in `1832b3e`. Commits `034aaf9` and `4f1dbda` added the weekly budget guard and audited account/session, app live-end/feed-removal, chat-block/report-validation and app-flag backend controls. The latest checkpoint passed 263 SQL assertions across 14 files, all 464 Flutter tests, and `flutter analyze` with 0 issues. The G6 localization scan still reports 528 matches.

P6 still needs client-side block persistence/sync, flag controls and availability UI, a dedicated live list, audit and keyword views, and deleted-account cache acceptance. Account deletion is locally tested, but real Auth HTTP, storage and issued-JWT behavior remain limits. P6S physical broadcast and access tests, P5, P7, P8B and P9 remain open. There is no signed release AAB or physical-device streaming acceptance. See `brief/README.md`, `brief/03_WORK_PLAN.md` and the latest RESUME block in `brief/LEDGER.md` for the active plan and evidence limits.

---

## Historical feature snapshot (2026-08-17)

The following feature and test inventory is historical. Its "Online" labels and older counts do not establish current release readiness; use the current release status above for that decision.

| Subsystem | Status | Details |
| :--- | :---: | :--- |
| **Flutter Map (GIS Engine)** | 🟢 Online | Crash-free `SpatialStreamerMarker`, 3 streaming states (Offline, Video Live, Audio Live), Organizations |
| **Top Map Controls** | 🟢 Online | Full-width search bar + side-by-side City & Topic dropdowns |
| **Arabic & RTL Localization**| 🟢 Online | 100% key symmetry in `ar.json` & `en.json`, Tajawal typography |
| **YouTube Streaming Engine**  | 🟢 Online | Live YouTube video sync, 16:9 sticky player, VOD playback, Audio-Only Stage |
| **Cinema Split-View Room**    | 🟢 Online | 4 interactive tabs (Live Chat, Slides PDF, Q&A, Venue RSVP), Audio Waveform Visualizer |
| **Floating Mini-Player (PiP)**| 🟢 Online | Global draggable overlay with play/pause and expand controls |
| **Discovery Feed Hub**        | 🟢 Online | Live Hero carousel, VOD grid, bookmarking, notifications, Audio Live badges |
| **Streamer Studio & Settings**| 🟢 Online | Google Broadcaster Auth, Format selector (Video vs Audio), Streamer/Viewer toggle |
| **Auth & Onboarding Wizard**  | 🟢 Online | Branded Welcome screen, Google Sign-In, Guest Setup, 5-Step Application Wizard |
| **Bi-directional Org System** | 🟢 Online | Broadcaster Join Org requests, Org Speaker Invites, Granular RBAC Permissions |
| **Admin Hub Dashboard**       | 🟢 Online | Desktop moderation workspace (`AdminHubScreen`), 6 core modules, live pending badge |
| **Multi-Account Super Admin** | 🟢 Online | Multi-account RBAC (`polkgvd2@gmail.com`, `ameeralhatemi67@gmail.com`, `amir.alhatemi@gmail.com`) |
| **Terms & Governance Viewer** | 🟢 Online | Dynamic live terms editor in Admin Hub + in-app viewer modal in Settings for all users |
| **Desktop / Responsive**      | 🟢 Online | NavigationRail sidebar on $\ge 900\text{px}$, Bottom Nav on mobile |

---

## 🎯 Completed: Auth, Onboarding, 5-Step Streamer Wizard & Dual Account Management

- 🔐 **Branded Welcome Landing (`welcome_screen.dart`):** Google Sign-In with mandatory account picker, Login, and lightweight Guest viewer entry.
- 👤 **Guest Viewer Setup (`viewer_setup_screen.dart`):** Custom name + avatar preset/upload from device.
- 🎭 **Role Selection (`role_select_screen.dart`):** Viewer/Student vs Streamer Application.
- 🧙 **Dynamic Streamer / Organization Wizard (`streamer_apply_screen.dart`):**
  - Step 1: Legal Name (dynamically populated from Google), Handle, Bio
  - Step 2: Any-ratio Avatar & Banner Upload with Interactive **Arrange & Reposition Modal** (`ImageArrangeModal`) and error diagnostics
  - Step 3: Affiliation, YouTube Link (proof checked), Custom Categories (up to 6 fields), Individual vs Org Toggle, Topic Tags
  - Step 3.5 (Org): Organization Multi-Streamer Roster with auto-fill from existing handles (`@handle`)
  - Step 4: Geographic hub dropdown, interactive **Spatial Map Pinpoint Picker** (`LocationPickerModal`), Saudi phone validator, and Multi-Branch locations
  - Step 5: Live Broadcaster Card Preview, dynamic clickable **Terms & Conditions Sheet** for Streamers/Organizations, and mandatory agreement checkbox
- 🏢 **Bi-Directional Organization Management:**
  - Individual Broadcasters can apply to join registered Organizations via `JoinOrgModalSheet`.
  - Organizations can review incoming applications in `OrgManagementView` with one-click Accept/Decline.
- 📊 **Real-time Admin Telemetry:** Live Google user and guest session tracking in Admin Hub.

---

## 🧪 Test Suite Health & Verification Metrics

- **Unit & Integration Suite:** `93/93 PASSING (100% Green)`
- **Static Analysis & Linting:** `0 issues (flutter analyze)`
- **Core Verification Suites:**
  - `auth_onboarding_and_org_affiliation_test.dart` (10/10 PASS)
  - `admin_hub_screen_test.dart` (5/5 PASS)
  - `organization_admin_and_go_live_test.dart` (6/6 PASS)
  - `organization_models_and_rbac_test.dart` (5/5 PASS)
  - `organization_profile_screen_test.dart` (5/5 PASS)
  - `live_multi_speaker_test.dart` (6/6 PASS)
  - `organization_admin_and_go_live_test.dart` (6/6 PASS)
  - `admin_database_service_test.dart` (7/7 PASS)
  - `admin_hub_screen_test.dart` (8/8 PASS)
  - `spatial_map_test.dart` (7/7 PASS)
  - `youtube_api_test.dart` (5/5 PASS)
  - `vod_archive_test.dart` (6/6 PASS)
  - `live_stream_test.dart` (5/5 PASS)

---

## 🧪 Quality & Test Metrics

- **Static Analysis:** `flutter analyze` $\rightarrow$ **0 issues (100% clean)**.
- **Automated Tests:** `flutter test` $\rightarrow$ **83/83 tests passing across all suites**.
- **Localization:** 100% symmetric JSON dictionaries (`ar.json` / `en.json`).

## 2026-09-23 checkpoint: weekly budget preflight repaired

The owner authorized weekly-only budgeting with a 5% absolute ceiling, aiming lower. Codex exposes a 10,080-minute weekly window and no five-hour window. The meter now classifies by duration, preserves 1% as 1%, rejects stale/missing weekly readings, and supports `--plan weekly --cap 5` with a 4% soft stop. Focused Node tests passed. Entry usage 1%, implementation entry 2%; no app/SQL/Flutter evidence added yet. P6.4 item 1 remains verified in `1832b3e`; P6 safety implementation is next and P6S remains blocked. Owner edits and both stashes are preserved. See brief/04_BUDGET_PROTOCOL.md section J. No push/deploy/production operations.

## 2026-09-23 checkpoint: P6 account/live controls and safety backend

Implemented authorized, audited directory account deletion/Auth-session revocation and app live end/feed removal. The server requires active admin sessions, protects self/master/admin targets, rejects deletion of organization/storage owners, and prevents forged success audits. Feed removal blocks the video ID from going live again in the app. Issued JWT expiry and external YouTube media remain explicit limits.

Also implemented backend own-row chat blocks, server report-reason/message validation and master-admin app flags enforced at chat/Auth INSERT. Client block persistence/cache sync and app-flag management/availability UI remain NOT DONE. Dedicated live list, audit viewer, keyword manager and global deleted-account cache acceptance remain open. P6S is not started.

Verification: 8 focused Flutter tests; 25 admin safety + 26 block/flag SQL assertions; GPT-6 Luna Medium analyzer 0 and full Flutter 464 passed. Parent fixed the intentional deny-all catalog allowlist and block-policy helper, then final SQL passed all 263 assertions across 14 files. Final gates retain known G6=528; security/secret gates passed. Only the named disposable local database was used. Existing owner edits and both stashes remain preserved. Evidence and next dependencies: `brief/evidence/2026-09-23/p6-safety.md`. Weekly usage measured 3% against the owner's 5% absolute ceiling; not all P6 work is complete.

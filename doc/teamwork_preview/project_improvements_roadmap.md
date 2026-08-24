# 🗺️ Master Project Improvement & Fixes Roadmap

> **Project:** Educational Cloud Streaming Platform (Streamer App)  
> **Team:** Multi-Agent Exploration Team (`teamwork_preview`)  
> **Status:** All 4 Specialist Audits Complete  
> **Output Folder:** [`teamwork_preview/`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/teamwork_preview)  

---

## 📊 Overview of Audit Deliverables

The multi-agent exploration team has completed a comprehensive audit across architecture, security, UI/GIS performance, and store compliance. All detailed reports are available in the [`teamwork_preview/`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/teamwork_preview) folder:

1. [`app_provider_analysis.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/teamwork_preview/app_provider_analysis.md) — `AppProvider` God Class analysis & 5-phase zero-breakage facade modularization plan.
2. [`security_and_auth_audit.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/teamwork_preview/security_and_auth_audit.md) — Deep Supabase RLS security audit identifying 3 critical/high/medium vulnerabilities and SQL patches.
3. [`performance_and_ui_insights.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/teamwork_preview/performance_and_ui_insights.md) — GIS map tile optimization, marker collision tuning, image memory downscaling, and string localization cleanup.
4. [`v0.9_readiness_and_roadmap.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/teamwork_preview/v0.9_readiness_and_roadmap.md) — Apple/Google Play account deletion compliance, Saudi PDPL right-to-erasure/data portability, and Settings screen cleanup.

---

## 🚨 Priority 1: Critical Security & Crash Fixes (Immediate Execution)

| # | Priority | Subsystem | Issue & Vulnerability | Action / Fix | Target File |
|---|:---:|:---:|---|---|---|
| **1** | 🔴 **CRITICAL** | Security / RLS | **Chat Moderation Hijacking:** `owns_stream()` checks `profiles.active_stream_id`, allowing any user to set their profile stream ID to target another stream and gain unauthorized chat deletion/mute rights. | Update `owns_stream()` SQL RPC to check `streamers.owner_profile_id` instead. | [`20260825090000_chat_moderation.sql`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations/20260825090000_chat_moderation.sql) |
| **2** | ⚠️ **HIGH** | Security / RLS | **Application Admin Field Overwrite:** Applicants updating pending applications can overwrite `admin_review_notes` or `reviewed_by`. | Add a BEFORE UPDATE trigger locking admin fields for non-admin callers. | [`20260828100000_broadcaster_applications_delete_admin.sql`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations/20260828100000_broadcaster_applications_delete_admin.sql) |
| **3** | ⚠️ **HIGH** | UI / Stability | **Runtime Crash in Navigation Sheet:** `venue_navigation_sheet.dart` uses `NetworkImage(avatarUrl)` on local asset paths, throwing `UriScheme` exceptions. | Replace `NetworkImage` with `buildSafeImageProvider()`. | [`venue_navigation_sheet.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/map/presentation/widgets/venue_navigation_sheet.dart#L153) |
| **4** | 🟡 **MEDIUM** | Security / RLS | **Chat Report Forgery:** `chat_reports_insert_self` policy does not verify if `reported_sender_id` matches `message_id`. | Update RLS policy to enforce message-sender foreign key validation. | [`20260824090000_chat_reports.sql`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations/20260824090000_chat_reports.sql) |

---

## 🏗️ Priority 2: Architectural Refactoring & Performance Optimizations

### 1. `AppProvider` Facade Modularization
- Transform `AppProvider` into a proxy/facade delegating state to domain providers (`AuthStateProvider`, `AdminStateProvider`, `DiscoveryStateProvider`, `StreamerStudioStateProvider`).
- Eliminate whole-screen rebuild cascades by replacing raw `context.watch<AppProvider>()` in [`live_broadcast_screen.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/live_stream/presentation/live_broadcast_screen.dart#L169), [`broadcaster_profile_screen.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/profile/presentation/broadcaster_profile_screen.dart#L65), and [`floating_stream_mini_player.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/widgets/floating_stream_mini_player.dart#L20) with granular domain selectors.

### 2. GIS Map & Memory Optimization
- Upgrade map tile engine to `CancellableNetworkTileProvider()` in [`spatial_map_screen.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/map/presentation/spatial_map_screen.dart#L159) to abort obsolete HTTP tile streams during fast gestures.
- Reduce tile memory buffer from `keepBuffer: 6` to `4` (cutting off-screen RAM footprint by ~40%).
- Wrap avatar and banner image providers in `ResizeImage.resizeIfNeeded()` to prevent high-res bitmap RAM bloat.

---

## 📜 Priority 3: Store Compliance & v0.9 Execution

### 1. Saudi PDPL & Store Account Deletion
- Apply migration `20260829090000_delete_user_account.sql` for atomic cascade user deletion with audit log anonymization.
- Add in-app "Delete My Account & Erase Data" dialog in `SettingsScreen`.
- Deploy hosted static web deletion request portal page at `https://streamerapp.sa/legal/account-deletion`.

### 2. Settings Cleanup & Developer Diagnostics Relocation
- Move experimental toggles (Pitch Director mode, RTMP IP configuration, notification triggers) from `SettingsScreen` into an Admin-only "Developer Diagnostics" tab in [`admin_hub_screen.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/admin/presentation/admin_hub_screen.dart).
- Implement role-tailored Settings sections: Viewer baseline $\rightarrow$ Streamer $\rightarrow$ Org Owner $\rightarrow$ Admin.

### 3. String Localization Remediation
- Replace ~25 hardcoded tooltips and button titles in `spatial_map_screen.dart`, `admin_hub_screen.dart`, `rtmp_ip_dialog.dart`, and `top_spatial_search_bar.dart` with localized `.tr()` keys.

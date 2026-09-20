# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Roadmap Status

- **v0.5 Backend Foundation**: ✅ Complete (Supabase Auth, PostgreSQL RLS, PII Security, Secret externalization).
- **v0.6 Live Chat & Engagement**: ✅ Complete (Realtime chat, floating reactions, role badges, server-enforced moderation, keyword filter, offline demo fallback).
- **v0.7 Mobile Streaming (Android)**: ✅ Complete (Checkpoints 1–4: spike, video broadcasting, audio-only + background survival, connection-drop detection/reconnect). Native encoder is `RtmpStream` (RootEncoder's generic pluggable-source class, migrated off the camera-only `RtmpCamera2` in Checkpoint 3 so the video source can swap to a static image for audio-only, and exposes the `StreamClient` Checkpoint 4's reconnect logic needs) plumbed through `RtmpPublisherBridge`. Checkpoint 4's own "optional polish" item — a real-device pass across multiple *physical* Android phones/network conditions — is still outstanding; all verification so far is emulator + a local RTMP test server, not real hardware.
- **v1.1 iOS Integration** (not started) is where iOS gets this same phone-streaming capability, per the roadmap's explicit platform-order decision (Android first, iOS bundled into its own version later) — not a v0.7 gap.
- **v0.8 Admin Upgrade**: ✅ Complete (Checkpoints 1–4). The tiered Master Admin / Admin / Permitted Admin (Org Owner & Co-Owner) hierarchy is real and RLS-enforced: `user_roles`/`user_permissions` hardened to the tier hierarchy with `has_permission()`, `org_owner` auto-derived from `organizations.owner_profile_id` (`org_co_owner` intentionally not auto-derived yet — no co-owner concept exists in the schema/app; see ADR-007 in `Core_files/decisions.md`). `AppProvider.isMasterAdmin` distinguishes Master Admin from plain Admin; the verification queue has multi-select batch approve/reject; a Master-Admin-only "Roles & Permissions" tab grants/revokes Admin/Master Admin and toggles capability checkboxes. A new `/org-admin` route + `OrgAdminScreen` gives Org Owners/Co-Owners a scoped `OrgManagementView`. An always-present "Chat Moderation" tab (any admin-tier viewer) surfaces the `chat_reports` queue platform-wide with dismiss/delete-message/mute-ban actions, all RLS-enforced (`chat_reports_delete_admin`, `chat_messages_delete_owner_or_admin`, `chat_muted_users_insert_owner_or_admin`) — confirmed via `npx supabase db advisors --linked --type security` that anon/lower-tier accounts have zero policy coverage on these tables (`to authenticated` + `is_admin_tier()` gates).
  - **👉 Current work (2026-09-20)**: v0.9 (Settings, Legal) and v0.95 (deep polish) are built. The app is in a security and truthfulness hardening run described in `brief/`: read the last RESUME block in `brief/LEDGER.md`, phases and gates in `brief/03_WORK_PLAN.md`, the budget rules in `brief/04_BUDGET_PROTOCOL.md`. Gantt charts: `Roadmap.md`. v1.0 Play Store release and v1.1 iOS follow the run.

## Workflow & Git Cadence

- **Branching**: Direct to `master` (no PRs, no feature branches).
- **Commits**: One commit at the end of each Phase following conventional commit format (`feat(streaming): ...`, `fix(security): ...`, `perf(state): ...`).
- **Push cadence**: Push `master` to GitHub at the kickoff of every Checkpoint.
- **Skills available**: `shadcn/improve` (`/improve`), `supabase/agent-skills`, `claude-flutter-skill`, `rls-audit`, `maestro-mcp`.

## Repo layout

This is a vault-style project folder, not a bare Flutter repo — the actual Flutter app lives one level down:

```
Streamer_app/               <-- repo root (this file, Core_files/, doc/, supabase/)
├── Core_files/              5 mandatory docs: README.md, STATUS.md, progres.md, decisions.md, Desgin.md
│   └── agents/               project-specific subagent personas (architecture, UI/UX, YouTube, GIS)
├── doc/Audit/                security/permissions/compliance/performance audit reports
├── doc/Roadmap/               versioned feature roadmap (v0.5 .. v1.1)
├── supabase/                  Supabase CLI project (migrations/, config.toml)
└── project/                 <-- Flutter app root — cd here for all flutter/dart commands
    ├── lib/core/               shared infra: config, providers, routing, services, theme, widgets
    ├── lib/features/           discovery, live_stream, map, auth, organization, admin, profile, notifications, splash
    ├── lib/spike_rtmp/         excluded from analysis (see analysis_options.yaml) — dead spike code, not built
    └── test/                   flutter_test widget/unit tests, one file per feature area
```

Always `cd project` before running Flutter/Dart tooling — `pubspec.yaml`, `analysis_options.yaml`, and `lib/` all live there, not at the repo root.

Read `Core_files/STATUS.md` and `Core_files/decisions.md` before large changes — they track what's currently working and the accepted architecture decisions (ADRs), and are more current than anything inferred from code alone.

## Commands

Run from `project/`:

```powershell
flutter pub get                     # install/update dependencies
flutter run -d chrome               # run in Chrome (primary dev loop; also `-d windows`, or a device id for Android)
flutter analyze                     # static analysis — must be 0 issues
flutter test                        # full test suite
flutter test test/live_stream_test.dart              # single test file
flutter test test/live_stream_test.dart -n "test name"  # single test by name
```

The app needs Supabase credentials via `--dart-define` to boot with a real backend; without them it starts in an unconfigured state (see `lib/core/config/supabase_config.dart`). For local dev, copy `project/dart_define.example.json` to `project/dart_define.local.json` (gitignored) and run:

```powershell
flutter run -d chrome --dart-define-from-file=dart_define.local.json
```

Supabase local stack (from repo root, not `project/`):

```powershell
npx supabase start                  # local Postgres/Auth/Storage via Docker
npx supabase db push                # apply supabase/migrations/*.sql
```

Migration files in `supabase/migrations/` are timestamp-ordered SQL; each layers RLS/schema changes on top of the previous one (e.g. `..._row_level_security.sql`, `..._restrict_pii_rls.sql`, `..._chat_moderation.sql`). Add new changes as a new migration file rather than editing an existing one.

## Architecture

**State Management & `AppProvider`:** `lib/core/providers/app_provider.dart` (`AppProvider`) is the app's global client-side state: auth/onboarding flags, streamer/org data, notifications, mini-player, admin/moderation state, and feature toggles.
- **Rebuild Optimization**: Feature screens MUST use granular `context.select<AppProvider, T>((p) => p.field)` to only subscribe to fields they render (refactored in v0.5 Checkpoint 4 to prevent whole-screen rebuild cascades). Event callbacks and mutation methods should use `context.read<AppProvider>()`.
- **Ephemeral & Stream-Scoped Lifecycles**: Stream-scoped interactive features (e.g. `LiveChatController`, `RtmpPublishEngine`) are dedicated standalone controllers created/disposed with their parent screens, rather than bloating the global `AppProvider`.

**Services are stateless helpers called by `AppProvider`**, not independent state holders: `SupabaseAuthService`, `AdminDatabaseService`, `YouTubeApiService`, `AutoTranslationService`, etc. live under `lib/core/services/`. `AppProvider` owns the instances and orchestrates calls into Supabase/YouTube; screens never call these services directly.

**Routing** (`lib/core/routing/app_router.dart`) uses `go_router` with a `StatefulShellRoute` (ADR-001) so the Discovery Feed and Spatial Map tabs keep independent navigator stacks and don't lose scroll/pan/zoom state on tab switch. The router is built once (`AppRouter.build(provider)`, called from `initState`, never per-build) with `refreshListenable: provider` so auth-state changes (OAuth completing, sign-out, role refresh) trigger route re-evaluation. Auth-guarded paths are listed explicitly in `_authGuardedPaths` (`/admin`, `/settings`, `/streamer-apply`, `/application-pending`) and redirect to `/welcome` when logged out; `/admin` additionally requires `provider.isAdminUser`.

**Admin/RBAC is backend-driven, not a hardcoded allowlist.** Admin status comes from the `user_roles` table via the `is_admin_tier()` Postgres RPC (see `_refreshAdminRoleFromBackend` in `AppProvider`), enforced again at the DB layer through RLS policies in `supabase/migrations/`. Don't reintroduce client-side email allowlists for privileged checks.

**Streaming is YouTube-first** (ADR-002): `youtube_player_iframe` embeds handle Live/VOD playback (`YouTubePlayerAdapter` under `lib/features/live_stream/presentation/adapters/`), using `youtube-nocookie.com` with strict-origin referrer policy to avoid YouTube's Error 150/152/153 embed rejections (ADR-006) — don't change the embed base URL or referrer meta/policy without re-reading ADR-006. Separately, `lib/features/live_stream/services/rtmp_publish_engine.dart` handles phone camera/mic → RTMP publishing so a streamer's own device can go live to a YouTube ingest URL/stream key (distinct from the viewer-facing YouTube watch/video-ID flow). `lib/spike_rtmp/` is a superseded prototype of that same idea, kept only for reference and excluded from `flutter analyze` and the build — don't add it to `pubspec.yaml` or wire it into `main.dart`.

**Localization** (ADR-003): `easy_localization` with parallel `assets/i18n/en.json` / `assets/i18n/ar.json` catalogs that must stay key-symmetric. RTL for Arabic is native `Directionality` mirroring, not per-widget conditionals — avoid hardcoding LTR-only layout assumptions (fixed left/right instead of start/end) in new widgets.

**Error handling favors graceful in-app overlays over crash surfaces** (ADR-005): unbuilt/unfinished actions route to `FeatureInProgressModal`; network/stream failures show a branded offline overlay rather than a raw exception screen. Follow this pattern for new incomplete features instead of leaving a dead button or letting an exception surface.

**Design system contract**: `Core_files/Desgin.md` plus `lib/core/theme/app_theme.dart` are the source of truth for colors/spacing/typography (dark-mode graphite + coral/cyan accents, Inter + Tajawal via `google_fonts`). UI changes should pull tokens from `AppTheme`, not introduce new literal colors/spacing.

## Testing conventions

Tests are widget/integration tests under `project/test/`, one file per feature area (e.g. `organization_admin_and_go_live_test.dart`, `spatial_map_test.dart`). The standard harness pattern (see any existing test file) wraps the widget under test in `EasyLocalization` with a `DirectJsonAssetLoader` that reads the real `en.json`/`ar.json` at test-init time (not the plugin's asset-bundle loader), plus a `ChangeNotifierProvider<AppProvider>.value` seeded with a fresh `AppProvider()` and any fixture data the test needs. Reuse this pattern for new tests rather than inventing a new harness. `flutter analyze` must stay at 0 issues and the full `flutter test` suite must stay green before considering a change done.

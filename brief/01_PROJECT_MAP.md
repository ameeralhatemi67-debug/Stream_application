# 01 — Project map (read this instead of exploring)

Snapshot: commit `485f5a3` (2026-09-17), `master`. Line numbers are approximate anchors for that commit; re-grep the symbol if the number has drifted. Everything here was verified by reading the repo on 2026-09-19 (static only: nothing was built or run).

## What the product is
Arabic/English (RTL) Flutter app for **live educational lectures in Saudi Arabia**: discovery feed + spatial map of streamers/organizations, YouTube-embedded live/VOD player, live chat, broadcaster onboarding with admin approval, organizations, admin hub. Backend = Supabase (Auth with Google OAuth, Postgres+RLS, Realtime, Storage). Android is the only shipping target now (Web/Windows shells exist; **no `ios/`**). 129 Dart files / ~53k LOC, 31 SQL migrations, 30 test files (~265 tests).

## Layout (repo root = `Streamer_app/`)
```
CLAUDE.md, AGENTS.md         conventions (already loaded). Commands are PowerShell-style; run Flutter from project/
project/                     Flutter app root (pubspec.yaml, lib/, test/, android/, web/, windows/, assets/)
supabase/migrations/*.sql    31 timestamped migrations. NEW changes = NEW files (never edit old ones)
Core_files/                  STATUS.md, decisions.md (ADR-001..007), Desgin.md (dark design contract -> must be rewritten for white theme)
doc/Audit, doc/Roadmap       historical audits/specs (partly stale, see 02 §5). Useful specs: doc/Roadmap/Settings_Page_Redesign_Spec.md
graft/                       per-file summary cards (gitignored, readable via Grep; graft/INDEX.md explains). Use before opening big files
brief/                       THIS run: prompt, docs, tools, ledger
```
Ignore: `project/build`, `project/scratch`, `graphify-out`, `_to_delete`, `doc/diagrams`, `assets/Ahmed_Amer_YouTube.html` (4.4 MB, not bundled), `lib/spike_rtmp/` (dead spike, excluded from analyze).

## Commands (from `project/`)
`flutter pub get` · `flutter analyze` (must be 0 issues) · `flutter test --reporter compact` (pipe through `tail -40`) · Supabase local stack from repo root: `npx supabase start` / `npx supabase db reset` (LOCAL only). Real backend needs `--dart-define-from-file=dart_define.local.json` (exists, gitignored — never print or commit its values).

## `project/lib` map (symbol -> file)
| Area | Files (all under `lib/`) | Notes |
|---|---|---|
| Entry/boot | `main.dart` (theme wiring :114-116 `ThemeMode.dark`; device session registration :67-87) | Supabase init is conditional on `SupabaseConfig.isConfigured` |
| Global state | `core/providers/app_provider.dart` (**4,867 lines — never read whole**) | Anchors below |
| Routing | `core/routing/app_router.dart` | go_router; `StatefulShellRoute` (Feed+Map); `_authGuardedPaths`; routes: `/splash /welcome /viewer-setup /role-select /streamer-apply /application-pending /onboarding /feed /map /profile/:id /live/:id /settings /admin /org-admin /account-banned /login-callback`; `/profile/:id` defaults id to `'prof_alghamdi_01'` (:204) |
| Theme | `core/theme/app_theme.dart` (196 lines) | Has `dark*` AND `light*` palettes but builds only a dark ThemeData; widgets use `AppTheme.darkSurface1` etc. directly (~1,550 refs) |
| Services (stateless) | `core/services/`: `supabase_auth_service.dart`, `admin_database_service.dart` (2,590 lines; ALL Supabase table calls), `youtube_api_service.dart`, `translation/*` | Screens must go through `AppProvider` |
| Device sessions | `core/models/device_session_model.dart`, `core/widgets/device_session_conflict_dialog.dart`, service calls in `admin_database_service.dart` :2528-2582 | Table `device_sessions` |
| Discovery | `features/discovery/presentation/discovery_feed_screen.dart` (842), `widgets/streamer_grid_card.dart`, `tags_filter_bottom_sheet.dart` | Viewer count text :598/:616 |
| Map | `features/map/presentation/spatial_map_screen.dart` (717), `widgets/*` (markers, drawer, search bar, city/topic dropdowns, venue sheet), `models/map_models.dart` | Tile URL const :20 (Esri dark); `NetworkTileProvider()` :171; camera box :138-150; O(N²) marker collision loop :262-296; search bar reads `mockStreamers` (`top_spatial_search_bar.dart`:75) |
| Live room | `features/live_stream/presentation/live_broadcast_screen.dart` (1,524), `screens/phone_broadcast_screen.dart` (1,982), `widgets/*` (chat, overlays, setup guide, RTMP dialog, private gate…), `adapters/*` (YouTube real; VLC/IVS/Web = dead), `services/` (`live_chat_controller.dart` 545, `rtmp_publish_engine.dart`, `youtube_live_service.dart` = SIMULATED, `stream_decay_engine.dart`, `ghost_chat_fallback_controller.dart` = fake chat) | `1240` fallback :354; ghost chat :164-179; play/pause state not wired to iframe :563-577 |
| Auth/onboarding | `features/auth/presentation/*` (welcome, viewer_setup, role_select, streamer_apply wizard `steps/apply_step_*`) | 5-step wizard, image arrange modal, location picker |
| Profile/Settings | `features/profile/presentation/settings_screen.dart` (**2,786**), `broadcaster_profile_screen.dart` (1,249), `widgets/*` (VOD, org modals, editors) | Settings cards listed in `build()` :142-275 |
| Admin | `features/admin/presentation/admin_hub_screen.dart` (2,754; tabs :329-340; `_buildTestingToolsTab` :699), `org_admin_screen.dart`, `widgets/*` (chat_moderation, org_management 1,359, roles, categories, tags, banned, custom placeholder review) | Tabs: overview, verification, streamers, viewers/analytics, terms, chat moderation, custom cards, categories, tags, banned, testing, roles(master), orgs |
| Organization | `features/organization/models/*` (permissions, speaker, venue branch, affiliation request, audit entry) | **No organization screens folder**; org UI lives in admin/profile/auth features |
| Notifications | `features/notifications/presentation/notification_center_sheet.dart`, queue in `app_provider.dart` :1620-1790, :3179+ | In-memory + simulator; no push |
| Shared widgets | `core/widgets/*` (consent dialog, toast overlay, safe_image_provider, mini-player, feature_in_progress_modal, language switcher) | |
| i18n | `assets/i18n/en.json`, `ar.json` (791 keys each, symmetric — keep it so) | `easy_localization`; RTL by `Directionality` |

### `app_provider.dart` anchors
`_streamers = List.from(mockStreamers)` :52 · Q&A seed :54-55 · consent :382-462 · role selection (memory only) :611-620 · **`primaryOwnedStreamerId` :623** and **`currentUserStreamerId` :714** (hard-coded dev email + `'prof_alghamdi_01'` fallbacks) · private-stream simulation :740-812 · Realtime subscriptions :998-1110 · YouTube viewer polling :1411-1462 · VOD getters w/ mock fallback :1855-1869 · notifications :1620-1790 · export :2353 · account deletion :2396 · go-live toggles :2601-2842 (local state only) · Q&A mutations :2865-2910 · filters :2971-3030 · tags/categories :3766.

## Supabase (supabase/migrations)
Tables: `profiles`, `organizations`, `org_venues`, `org_speakers`, `affiliation_requests`, `broadcaster_applications`, `user_roles`, `user_permissions`, `audit_logs`, `terms_and_conditions`, `platform_analytics`, `chat_messages`, `chat_reports`, `chat_muted_users`, `chat_mute_audit_log`, `chat_banned_keywords`, `stream_moderators`, `banned_users`, `academic_categories`, `tags`, `streamer_custom_placeholders`, `device_sessions`. Storage bucket `streamer-assets`. Views `streamer_public_profiles`, `organization_public_profiles` (anon-readable).
Helper functions: `is_admin_tier()`, `is_master_admin()`, `owns_organization(uuid)`, `is_org_member(uuid)`, `owns_stream(text)`, `chat_can_moderate(text)`, `log_audit_event(...)`, `delete_own_account()`. Style to copy: `security definer` + `set search_path = public`, `grant execute ... to authenticated`, one concern per migration, comments explaining why.
Live state columns live on `profiles`/`organizations` (`is_currently_live`, `broadcast_type`, `active_stream_id`, `active_viewer_count`) — **the client only reads them; nothing writes them** (see 02 §2).

## Android (`project/android`)
`app/build.gradle.kts` (namespace/applicationId `com.example.streamer_app`, `flutter.*` SDK versions, R8 on, signing falls back to debug if `key.properties` missing), `AndroidManifest.xml` (deep link `com.example.streamerapp://login-callback` must equal `SupabaseConfig.oauthRedirectUrl`), Kotlin under `src/main/kotlin/com/example/streamer_app/` (`MainActivity`, `streaming/Rtmp*` = RootEncoder 2.7.5 bridge + foreground service). Launcher/web icons are Flutter defaults.

## Tests (`project/test`)
One file per area; harness = `EasyLocalization` + `DirectJsonAssetLoader` + `ChangeNotifierProvider<AppProvider>.value` (copy it, see CLAUDE.md). Many tests import the mock fixtures being removed — move fixtures to `test/fixtures/` rather than deleting coverage.

## Invariants (do not break)
- ADR-006: don't change the YouTube embed base URL / referrer policy (`youtube-nocookie.com`, strict-origin).
- en.json / ar.json key symmetry (gate G7). Use `start/end`, not `left/right`.
- Screens use `context.select` on `AppProvider`; stream-scoped controllers stay out of `AppProvider`.
- New DB change = new migration file. No client-side email allow-lists for privileges.
- `streamer_custom_placeholder*`, `stream_state_placeholder_overlay`, `custom_placeholder_review_view` are a **real feature** (streamer-uploaded "Starting soon/Break/Ended" cards). Do NOT delete them when removing "placeholders".

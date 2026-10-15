# Launch work without owner inputs — 2026-10-15

Scope: `brief/launch/03_CLAUDE_REMAINING_WORK.md` sections 1, 3, 4 and 5 (records, data rights, release-scope cleanup, Android 16). Nothing was deployed: no hosted migration, function, push or install.

## Baseline before changes

- `flutter analyze`: 0 issues.
- `flutter test`: 1,085 passed, 0 failed.

## Data rights (section 3)

Migration `supabase/migrations/20261015090000_data_rights_export_and_deletion.sql`:

| Function | Behaviour |
|---|---|
| `export_my_data()` | Every user-linked table in one JSON document. Leaves out push tokens, OAuth credentials, invite token hashes and other people's identities (reviewers, granters, moderators, people the user reported). Fails as a whole. |
| `prepare_account_deletion()` | Returns `blocker` (`account_restricted`, `broadcast_active`, `organization_has_members` or null) and the Storage paths the client must remove first. |
| `delete_own_account()` | Re-checks blockers, refuses with `storage_cleanup_required` while owned files remain, redacts audit-log actor email/name, review-history applicant names/snapshots and actor name, speaker link email, invitations sent to the email, then deletes the auth user (cascade). |
| Storage policies | Owners may see and delete their own legacy flat-path uploads (`owner_id` match), so deletion never strands an old public avatar. |

Local test database: a copy of this project's disposable `org_v1_audit_20261001` schema in container `supabase_db_P6_accept_disposable`, brought to `20261008110548` (pg_cron cannot be created outside the `postgres` database, so only `pg_net` from `20261004152527` was applied), seeded with `app_flags` and the `streamer-assets` bucket. Two copies: `launch_base_20261015` (without the new migration) and `launch_rights_20261015` (with it).

`supabase/tests/data_rights.test.sql`: **39/39 ok** on `launch_rights_20261015`.

Whole SQL suite, same results with and without the migration (no regressions). Pre-existing failures that need their own repair pass (launch plan section 9):

| File | ok / not ok | First error |
|---|---|---|
| admin_safety_actions | 12 / 0 | Provider-confirmed session required |
| application_and_ban_guards | 3 / 0 | permission denied for table affiliation_requests |
| application_review_history | 4 / 0 | permission denied for function is_banned |
| broadcast_identity_boundaries | 0 / 0 | permission denied for function start_broadcast_session |
| broadcast_session_authority | 21 / 35 | Provider-confirmed session required |
| broadcast_session_fencing | 1 / 2 | permission denied for function start_broadcast_session |
| broadcast_sessions | 10 / 6 | Broadcast not permitted |
| broadcaster_device_claim_state | 13 / 3 | — |
| chat_blocks_and_app_flags | 24 / 2 | — |
| chat_keyword_filter | 18 / 12 | — |
| chat_moderation_authority | 0 / 0 | Provider-confirmed session required |
| chat_rate_limit | 3 / 8 | — |
| live_flag_expiry_and_privilege | 13 / 5 | — |
| organization_public_location | 0 / 0 | Organization applications are not open |
| profile_edit_review | 13 / 0 | Organization applications are not open |
| rls_catalog | 13 / 8 | — |
| upcoming_live_schedules | 5 / 0 | column reference "schedule_id" is ambiguous |
| viewer_presence | 9 / 5 | — |

Clean on both: admin_user_directory 33, application_city 13, asset_listing 5, audited_broadcaster_moderation 26, broadcaster_columns 9, chat_keyword_audit 19, follows_and_bookmarks 13, organization_v1_channels 24, organization_v1_client 25, organization_v1_events 48, organization_v1_memberships 22, organization_v1_sessions 36, streamer_assets 7, supported_broadcaster_location 7.

Most failures look like fixtures written before later authority changes (provider-confirmed sessions, organization application flags). The `upcoming_live_schedules` ambiguity may be a real defect in a reminders function and should be checked first.

App side: `AppProvider.exportMyData()` calls the RPC and returns null on failure; Settings saves a `hadayah-data-YYYY-MM-DD.json` file (share sheet on Android, download on web) or copies it. `AppProvider.deleteOwnAccount()` runs prepare → Storage removal → delete and returns a refusal code that Settings explains (English and Arabic). Test: `project/test/data_rights_test.dart`.

## Release-scope cleanup (section 4)

- Reminders: `AppProvider.remindersAvailable` is false in builds without the Firebase values; the profile bell, schedule-card reminder button/menu item and the reminder settings block are hidden. Tests opt in with `debugRemindersAvailable`; `organization_profile_screen_test.dart` checks the bell is hidden without push.
- Organization broadcasting: the studio's destinations now require `OrgMembership.v1Enabled` (flag or pilot). `/shows` and the organization hub already respected it.
- Unavailable modes confirmed in source: Local explains it is unavailable (`local_mode_unavailable_test.dart`), private streams off, front camera Coming Soon, no system PiP (manifest has no `supportsPictureInPicture`), no browser screen capture.
- Location: requested only on tap in `location_picker_modal.dart`, foreground only; only the confirmed venue point is saved. Fine location kept (a venue pin needs it). Recorded in `store/data_safety.md`.
- Test labels: "Hadayah Test" and `.wave4v2` apply only to a debug build with `-Pwave4v2TestApp=true`; release uses `@string/app_name` (Hadayah Live / منصة هدايه). Admin testing tools are `kDebugMode` only.

## Android 16 (section 5)

- New `project/test/android16_layout_test.dart`: feed, map, settings, live room, phone broadcast and studio sheet laid out at 412×915, 800×1280 and 1280×800 with a 32 px status bar and 48 px navigation bar; fails if a fixed tap target sits under a bar. Studio sheet also laid out at tablet portrait/landscape and 2× text in both languages. Manifest has no `android:screenOrientation`.
- Finding fixed: the map's attribution/list control row was pinned to `bottom: 0`, so on wide screens (no bottom tab bar) it sat under the navigation bar. It now uses the system bottom inset (unchanged on phones, where the tab bar takes that inset).
- Predictive back: the studio's `PopScope` routes system back through the end/leave confirmation (existing test "system Back while sending asks instead of silently ending"); `dispose` turns the wakelock off and disposes the camera engine. The live room stops its wakelock when the room stops.
- Not verified here: an actual Android 16 tablet or emulator rotation run, and gesture-navigation visuals. Those belong to the owner's device pass (02 section E).

## Final verification

After the changes: `flutter analyze` 0 issues; `flutter test` 1,103 passed, 0 failed (18 new). `node brief/tools/gates.mjs`: only the known G2d and G11a failures.

# Local SQL suite repair — 2026-10-15

Scope: `brief/launch/03_CLAUDE_REMAINING_WORK.md` section 9 / Roadmap 1.0.0.1.3. Starting point: the 18 failing files listed in `brief/evidence/2026-10-15/launch-unblocked/README.md`. Nothing was deployed: no hosted migration, function, push or install.

## Result

**33/33 files, 708 `ok`, 0 `not ok`, 0 errors**, every file's count equal to its plan.

Database: `sql_suite_final_20261015` in container `supabase_db_P6_accept_disposable`. It is a fresh copy of `launch_rights_20261015` (all migrations through `20261015090000`, `app_flags`, `streamer-assets` bucket) plus the four new migrations below, each recorded in `supabase_migrations.schema_migrations`.

One environment fix was needed in that copy: `chat_banned_keywords` was empty in the source database, although migration `20260826090000` seeds six keywords. The six rows were re-inserted exactly as the migration writes them. `chat_keyword_filter` tests that seed. It is a gap in how the disposable DB was built, not a test defect.

Control run: on a copy without the new migrations, the edited tests still fail exactly where each migration is needed. `upcoming_live_schedules` aborts on the ambiguity, `application_review_history` aborts on `is_banned`, `rls_catalog` fails R3a/R3c/R3d/R5a/R6b/R10/R11, and `broadcast_session_authority` fails "ban recorded".

`flutter analyze`: 0 issues. No Dart code changed.

| File | Before | After |
|---|---|---|
| admin_safety_actions | 12 / 0, aborted | 26 / 0 |
| application_and_ban_guards | 3 / 0, aborted | 11 / 0 |
| application_review_history | 4 / 0, aborted | 13 / 0 |
| broadcast_identity_boundaries | 0 / 0, aborted | 8 / 0 |
| broadcast_session_authority | 21 / 35, aborted | 69 / 0 |
| broadcast_session_fencing | 1 / 2, aborted | 36 / 0 |
| broadcast_sessions | 10 / 6, aborted | 22 / 0 |
| broadcaster_device_claim_state | 13 / 3 | 16 / 0 |
| chat_blocks_and_app_flags | 24 / 2 | 26 / 0 |
| chat_keyword_filter | 18 / 12 | 30 / 0 |
| chat_moderation_authority | 0 / 0, aborted | 24 / 0 |
| chat_rate_limit | 3 / 8 | 11 / 0 |
| live_flag_expiry_and_privilege | 13 / 5 | 18 / 0 |
| organization_public_location | 0 / 0, aborted | 10 / 0 |
| profile_edit_review | 13 / 0, aborted | 16 / 0 |
| rls_catalog | 13 / 8 | 21 / 0 |
| upcoming_live_schedules | 5 / 0, aborted | 11 / 0 |
| viewer_presence | 9 / 5 | 14 / 0 |

The other 15 files were already clean and are unchanged.

## Real defects: four new migrations (applied to hosted 2026-10-15, see the end of this file)

| Migration | Defect | Effect in production |
|---|---|---|
| `20261015174558_fix_reminder_claim_conflict_target.sql` | `claim_due_schedule_reminders()` returns a table with `schedule_id, token, occurrence_at` columns, which are PL/pgSQL variables. That makes its `on conflict (schedule_id, token, occurrence_at)` ambiguous (42702). | Every dispatcher call fails, so no schedule reminder has ever been claimed. Fix: `on conflict on constraint schedule_reminder_deliveries_pkey`. Body and grants otherwise unchanged. |
| `20261015174605_fix_review_history_read_policy.sql` | The `application_review_events` select policy calls `is_banned(uuid)`, which authenticated may not execute (revoked in `20260920110000`). | Every admin read of review history (`admin_database_service.dart:511`) fails with "permission denied for function is_banned". The fix uses `is_current_user_banned()`, which checks the same row. |
| `20261015174637_reconcile_post_hardening_grants.sql` | Tables created after the 2026-09-21/23 hardening (`upcoming_schedules`, reminder tables, `schedule_reminder_deliveries`, `application_review_events`) received the migrating role's default grants. On a stack migrated as `supabase_admin` that means anon SELECT/INSERT/TRUNCATE, and TRUNCATE skips RLS. `can_subscribe_upcoming` and `register_schedule_push_device` were executable by anon. Affiliation insert/update policies have been unreachable since `20261001095030`. Five reminder/push policies used `FOR ALL`. | It revokes everything beyond each creating migration's explicit GRANT. Where the hosted defaults were already narrow, this is a no-op. It also drops the four dead affiliation write policies and splits the `FOR ALL` policies into per-command policies with identical predicates. |
| `20261015174647_record_ban_as_broadcast_end_reason.sql` | `20261001111022` rewrote `sync_broadcast_session()` to take the end reason only from `app.broadcast_end_reason`, and `admin_update_account('ban')` never sets it. | A banned broadcaster's session ended as `ended` rather than `ban`, so `AppProvider` (`app_provider.dart:1467`) could not explain the end. The fix derives `ban` again when no explicit reason is set. |

Hosted note: checked during deployment. Hosted did have the leak in a narrower form: `anon` held SELECT/INSERT/UPDATE/DELETE (not TRUNCATE) on the reminder and review-history tables, and `authenticated` held full DML on `schedule_reminder_deliveries` and `application_review_events`. No anon policies existed, so RLS blocked those grants in practice. Applying the migration there is safe either way. The policy drops and splits are real changes on hosted and need the owner's approval with the other three.

## Stale fixtures and tests (updated, assertions not weakened)

**Provider-confirmed LIVE.** Since `20261001102758` (STREAM-D8), clients cannot call `start_broadcast_session`/`set_live_state`. Since `20261001111022`, a profile can only be LIVE through a live `broadcast_sessions` row, and chat and presence are keyed by the session id (`20261001114055`).
- **Chat and presence files** (`chat_blocks_and_app_flags`, `chat_rate_limit`, `chat_moderation_authority`, `viewer_presence`, `admin_safety_actions`): the fixture is now a live, accepted session inserted as superuser, with the room keyed by its id. Before this change, `chat_blocks_and_app_flags` "server hides blocked messages" passed only because every message was invisible.
- **Broadcast-authority files** (`broadcast_sessions`, `broadcast_session_authority`, `broadcast_session_fencing`, `broadcast_identity_boundaries`, `broadcaster_device_claim_state`, `live_flag_expiry_and_privilege`): ported onto the real start path. The presenter calls `broadcast_create_personal`, or `broadcast_save_schedule` plus `broadcast_accept_assignment`, then `broadcast_reserve_confirmed` from its primary device. A `pg_temp.confirm_live` helper drives `broadcast_provider_step` (stream_create, broadcast_create, bind, observe live, finish) the way the provider worker does. Each original assertion maps to its current equivalent:
  - invalid watch ID → `broadcast_create` rejects it (22023)
  - displaced or stale device cannot start → reserve refused, "Assigned primary presenter required"
  - org audio-only member cannot do video → scheduling refused, "Approved organization presenter and grant required"
  - two accounts cannot list one watch ID → still 23505, from `profiles_one_live_stream`
  - blocked watch ID cannot be relisted → provider confirmation refused, "Stream removed by moderation"
  - anon cannot read sessions → anon reads only public sessions, and none once hidden from discovery. Anon SELECT on public sessions is by design since `20261001111022`.
  - "owner sees the hide" → read from the owner's session row, which is what `broadcast_session.dart` uses. `my_broadcast_status()` no longer carries that key, and the app does not read it there.
  - "phone starts as sending" → the phone's first ingest report is recorded as sending. Ingest starts as `unknown` until the encoder reports.
- `admin_safety_actions` additionally settles provider termination before deleting the account, because `broadcast_guard_delete` refuses deletion while a session is ending, by design.

**Organization v1.** `application_and_ban_guards`: direct affiliation writes were revoked (`20261001095030`). The A6 assertions now expect 42501 on direct insert and update, and P5 approves through `org_v1_request_join`/`org_v1_resolve_request` with session claims. `organization_public_location` and `profile_edit_review` open the `organization_applications_open` launch switch (`20261001160000`) in their setup.

**Test bugs.**
- `organization_public_location` checked "rejected location edit preserves approved point" while the application was still switched to `individualScholar` by the previous assertion, so the check could never pass. The test now restores `organizationVenue`, as the version before commit `5b4e991` did.
- `application_review_history` inserted a second applicant's application while signed in as the admin. That applicant now submits their own application.

**Intent lists.** `rls_catalog` now documents the surfaces later migrations granted explicitly: `schedule_reminder_deliveries` as deny-all; `broadcast_sessions` as anon-readable; and `chat_moderator_since`, `broadcast_is_public`, `broadcast_list_sessions`, `broadcast_room`, `broadcast_chat_read`, `list_upcoming_schedules` and `can_publish_upcoming` as anon-executable. Each entry cites its migration.

## Findings for the owner (not changed here)

1. **A phone broadcast whose app is killed may stay LIVE.** The new `sweep_stale_live_flags()` ends phone sessions only after the app itself reports `interrupted` for 120 s. The heartbeat expiry was removed so that OBS is not ended by a closed management tab, which `organization_v1_sessions` asserts. Broadcasts are created with `enableAutoStop:false`. A phone that dies without reporting can therefore stay listed until someone ends it. Decide whether `phone_direct` should also expire on a stale primary-device heartbeat. `live_flag_expiry_and_privilege` now tests only the current ingest-loss rule.
2. `AdminDatabaseService.startBroadcastSession` still calls the revoked `start_broadcast_session`. It has no callers and is dead code.
3. The disposable test DB is built as `supabase_admin`, so it gets broader default privileges than a `postgres`-migrated project. `rls_catalog` now catches that drift, but a DB rebuilt from migrations as `postgres` would make the local suite closer to hosted.

## Run a file

```bash
docker exec -i supabase_db_P6_accept_disposable psql -XAt -U supabase_admin -d sql_suite_final_20261015 < supabase/tests/<file>
```

## Hosted deployment (owner approved, 2026-10-15)

Applied in order through the Supabase MCP connector to `zkkmfjsjouqzibvnzkau`; local files renamed to the stamped versions: `20261015174558` (reminder claim), `20261015174605` (review history policy), `20261015174637` (grants and per-command policies), `20261015174647` (ban end reason).

Preflight (catalog reads only): hosted `claim_due_schedule_reminders` and `sync_broadcast_session` were byte-identical (md5) to the local base at `20261008110548`, so the replacements change only the intended lines; the FOR ALL reminder policies on hosted had exactly the predicates the split recreates; no anon policies existed on the affected tables; guests read schedules through `list_upcoming_schedules`, which is unchanged.

After: both function md5s equal the repaired local database `sql_suite_final_20261015`; anon has no grants on the reminder/review tables and cannot execute `can_subscribe_upcoming`, `register_schedule_push_device` or `claim_due_schedule_reminders`; `authenticated` keeps SELECT only on `application_review_events` and nothing on `schedule_reminder_deliveries`; each reminder table has 4 per-command policies (`notification_push_preferences` 3); `affiliation_requests` keeps its select and delete policies.

Advisors: no new error or warning. Security: guest-executable SECURITY DEFINER warnings fell from 11 to 9. Performance: unchanged (no new multiple-permissive-policy finding).

Still open, outside these migrations: hosted `anon` holds SELECT/INSERT/UPDATE/DELETE on `affiliation_requests` (RLS has no anon policy, so it is blocked; revoke in a later grants pass), the phone-broadcast LIVE-expiry decision above, and `AdminDatabaseService.startBroadcastSession` calling a revoked function.


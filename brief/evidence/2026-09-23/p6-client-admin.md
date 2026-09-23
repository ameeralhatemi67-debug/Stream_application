# P6 client and admin checkpoint, 2026-09-23 (Claude Opus 5.5)

Continues `p6-safety.md`. Budget: §K owner override; no meter was run. Branch `p6-client-safety` in worktree `.claude/worktrees/p6-client`, started from `0aa6b06`.

## Implemented

- **Chat blocks** (`bb285c8`). `ChatBlockList` is the one app-wide list and the server's `chat_user_blocks` table is its source of truth. Block and unblock change local state only after the server accepts the write. Refusals are sorted into signed out, not permitted, deleted target and network, and each gets a localized toast; the sender stays visible. A duplicate insert counts as success. Each account has its own cache. If the server can't be reached, the last copy is marked stale and the list is never cleared. Switching accounts clears the previous account's blocks. Old device-only blocks are uploaded once, and the old prefs key is removed only after every upload succeeds. The list refreshes on room entry, when Settings opens, and on app resume. The new Settings › Blocked accounts sheet lists blocked accounts by name, unblocks one, and shows stale and empty states. Blocking across devices therefore relies on refresh plus the existing restrictive `chat_messages` read policy; there is no push from the server.
- **Report reasons** (`bb285c8`). `ChatReportReason` holds exactly the server's four codes and invalid codes are refused before any request. Server refusals (23505, 23514, 22023, 42501, network) map to localized messages instead of raw text. The admin queue shows coded reasons as labels and old free-text reasons as written.
- **App flags** (`1eb5d71`). `AppFlags` reads the public `app_flags` table. A failed read is reported as failed, never treated as off: the value falls back to on because the server enforces the switch anyway. Changes go only through `admin_set_app_flag` with a trimmed reason of 1–500 characters, then the table is re-read. Chat gains a `platformPaused` composer state that is second in precedence after `banned`, applies to moderators too (matching the insert trigger), and follows the switch live. The send refusal "Feature temporarily disabled" is not offered for retry. When `registrations_open` is off, Welcome shows a notice and disables Sign up; Log in stays enabled.
- **Admin Safety tab** (all admin tiers; Platform switches visible to Master Admin only):
  - Live now: runs `sweep_stale_live_flags`, lists admin-readable live `profiles`, and adds `get_viewer_counts`. A count that couldn't be read is shown as unavailable and left out of the total. End broadcast and Remove from feed require a reason and go through the existing audited `updateAdminAccount`.
  - Audit log: server pages of 50 with an action filter, localized labels for safety events, and error, empty and load-more states.
  - Keyword manager: add, change match mode, and remove with confirmation. Input is limited to 1–100 characters. A refused update or delete that affects zero rows is reported as a refusal.
  - Platform switches: a reason dialog, disabled while the current value is unknown.
- **Keyword audit (new migration `20260923130000_audit_chat_keyword_changes.sql`)**. An AFTER insert, update or delete trigger on `chat_banned_keywords` writes `chatKeywordAdded`, `chatKeywordUpdated` or `chatKeywordRemoved` in the same transaction; if the audit write fails, the keyword change is rejected. These three names are reserved and the public logger refuses them. A write with no `auth.uid()` can only come from a privileged database role, since anon has no grant or policy; it is audited with actor `system` instead of being refused.
- **Deleted-account cache**. After the server confirms a deletion, `AppProvider.purgeDeletedAccountFromCaches` removes the account from streamers, map markers, follows, reminders, chat reports, role assignments, stream moderators, banned users and the chat block list. It also closes the mini-player if it is showing that streamer's video, then reloads the streamer catalog. Force end and remove from feed also reload the catalog. A refused deletion leaves every cache unchanged.
- **Bug found by tests and fixed**: the reason dialog disposed its text controller while the dialog was still animating closed. The dialog is now a StatefulWidget that owns the controller.

## Evidence

- Focused: `test/chat_block_sync_test.dart` 19 passed; `test/admin_safety_console_test.dart` 21 passed; composer and settings neighbours 33 passed.
- `flutter analyze`: No issues found.
- SQL, fresh disposable project `P6_client_disposable` (copy at `brief/.runtime/p6-client-disposable-20260923`; seed disabled; bootstrap applied every migration through `20260923130000`): `supabase test db --local` returned `Files=15, Tests=278, Result: PASS`. The new `chat_keyword_audit.test.sql` covers viewer denial and blind reads, forged audit refusal, admin add, update and remove audits with actor and previous values, rollback when the audit fails, and system-actor maintenance writes. One intermediate run failed: `chat_keyword_filter.test.sql` seeds as `postgres` and hit the first trigger version's refusal of writes with no user. After the fix, the whole stack was stopped with `--no-backup` and bootstrapped again before this final run. After the tests, it was stopped with `backup=false`. No linked, remote or default-project command was run.
- Gates (`node brief/tools/gates.mjs`, exit 0): G6 **FAIL 552** (was 528). All +24 are localized `Text('key'.tr())` calls that the G6 regex also counts: 18 in `admin_safety_view.dart` and 6 in `blocked_accounts_sheet.dart`. A per-file check found zero new untranslated literals. Every other gate passed or is INFO, including G7 key symmetry, G10a/c/d and G11a/b/d/e/f.
- Full Flutter, run once on the stable code: `flutter test --reporter compact` returned `+504: All tests passed!` in 03:21 (464 before, plus 19 and 21 new).
- Logs (ignored): `brief/.runtime/p6-client-sql.log`, `p6-client-sql-final.log`, `p6-client-gates.log`, `p6-client-flutter-test.log`.

## Limits

- Cross-device block sync uses refresh on entry, Settings and resume; there is no server push. Nothing was verified on physical devices or in two real sessions.
- Live viewer counts are server presence (45 s window), not YouTube counts. End and remove act in the app only, not on YouTube.
- Deleted-account cleanup covers this admin's device. Other clients drop the account on their next catalog or directory reload. Issued access JWTs remain valid until they expire (previous limit).
- The audit viewer lists `audit_logs` only; `chat_mute_audit_log` stays in the Chat Moderation tab.
- The new migration has not been reviewed by the owner and has not been applied to any linked or production project.
- P6 safety acceptance as a whole still needs owner or physical review; P6S stays blocked.

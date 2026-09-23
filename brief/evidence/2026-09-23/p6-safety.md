# P6 safety checkpoint, 2026-09-23

## Implemented and locally verified

- Directory actions route deletion, Auth-session revocation, app live end and feed removal to `admin_auth_account_action`. Reasons are required, actions have bilingual confirmations, deletion closes/reloads the directory. The backend checks active Auth session, platform admin role, ban status and protected targets. Deletion refuses organization/storage owners. Sessions and refresh tokens are removed; account deletion cascades from auth.users.
- All four actions and new app-flag changes have atomic server audit records. Audit failure rolls back the mutation. The public logger cannot forge these reserved event names; its internal implementation has no client execute grant.
- Live end clears app live flags and primary broadcaster status. Feed removal also prevents the same video ID going live again through database triggers. No claim that this stops external YouTube ingest or playback.
- Backend viewer-owned block rows with restrictive message-read policy; report codes limited to spam/harassment/hate_speech/other for new writes, preserving historical free text. Report sender and stream must match the actual message.
- Master-admin/session-gated app flag RPC with required reason and atomic audit. Global chat INSERT and Auth user INSERT triggers enforce chat_enabled and registrations_open. Public can read availability; clients cannot write flags directly.

## Evidence

- `node --test brief/tools/budget_check.test.mjs`: 2 tests passed.
- Focused Flutter directory tests: 8 passed, including deletion confirmation and detail closure.
- Focused admin safety SQL: 25 passed, including role/session denial, protected targets, refresh-session deletion, permanent account deletion, force-end, feed republication denial, audit forgery and rollback.
- Focused blocks/flags SQL: 26 passed after fixing an RLS policy's call to server-only is_banned. It now uses is_current_user_banned.
- GPT-6 Luna at Medium ran consolidated verification: analyzer 0 issues; full Flutter suite 464 passed; initial full SQL 237 assertions with one catalog allowlist failure. Parent fixed the documented deny-all registry entry.
- Parent final full SQL after adding the backend safety slice: 14 files / 263 assertions, PASS. Parent final gates: known G6=528 failure unchanged; G10a/c/d and G11a/b/d/e/f PASS. Gate runner exit 0 does not mean all gates passed.
- `git diff --check`: passed. No broad Flutter rerun after the later SQL-only changes; no Dart file changed after Luna started.

Local database: `supabase_db_P64_item1_disposable`, project copy at `brief/.runtime/p64-item1-disposable-20260923`. Both new migrations were applied transactionally via `docker exec -i ... psql -U postgres -d postgres -v ON_ERROR_STOP=1`, not via linked/project migration commands. The block policy correction was applied locally before retesting. CLI migration-history rows for these two files were not added; do not blindly replay onto this backup. Use a fresh disposable project to verify an entire new bootstrap next time. No existing local project reset, production/linked connection, push or deployment.

Logs retained locally in ignored `brief/.runtime/p6-focused-flutter.log`, `p6-verify-{analyze,flutter-test,sql,gates}.log`, `p6-final-sql.log` and `p6-final-gates.log`.

## Limits and next dependency

P6 is not complete. The existing client Block action still uses local preferences and must be connected to chat_user_blocks, with server failure handling and cross-device/cache synchronization. App-flag administration and client availability UI remain to be built; the verified switches are currently backend RPCs. A dedicated live list/count view, audit viewer, keyword manager and global deleted-account cache handling remain. The directory itself reloads after deletion, but broader cache acceptance is unverified.

Issued access JWTs can remain usable until expiry outside paths that check auth.sessions. The new privileged RPC does check the caller's session. Real Auth HTTP refresh/sign-in, Storage deletion cases, physical broadcaster reaction to force-end and production behavior were not tested. No P6S work or release-ready claim. Owner review is required before any eventual production migration/deployment; no owner input is needed for the next local client implementation slice.

Weekly budget: entry 1%, implementation entry 2%, verification/closing 3% as measured; absolute ceiling 5%, soft 4%. These are account-wide integer readings, not precise per-phase cost estimates.

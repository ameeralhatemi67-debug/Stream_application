# OWNER ACTIONS — things only the owner can do

Claude Code appends specifics under each item (exact commands, file names, values). It never fakes, skips or "pretends done" any of these. Tick a box only when you did it.

## Before the app can be published
- [ ] **Design scheme + logo** — run `brief/DESIGN_PROMPT.md`, open `brief/assets/design_options/preview.html`, then write `DESIGN_CHOICE=A|B|C` in `brief/05_DECISIONS.md`. Check the font licences listed in its `NOTES.md` before publishing.
- [ ] **Arabic app name** — 05 has `منصة هدايه`; the standard spelling of "guidance" is `هداية` (with ta marbuta). Claude Code uses the value exactly as typed, so fix it in 05 if you want the standard spelling.
- [ ] **Support email** — `ameeralhatemi67@gmail.com` is a personal address and becomes public in the Play listing and privacy policy. Consider a dedicated address before publishing.
- [ ] **App identity** — fill `APP_ID`, `APP_NAME_EN`, `APP_NAME_AR`, `SUPPORT_EMAIL`, `PRIVACY_POLICY_URL` in `brief/05_DECISIONS.md` (or follow the rename procedure below if they were blank during the run). The package name is permanent after the first Play upload.
- [ ] **Upload keystore** — generate it yourself, create `project/android/key.properties` (never commit either). Release builds fail on purpose without it.
- [ ] **Play Console** — developer account and identity verification, Play App Signing, store listing assets and screenshots, content-rating questionnaire, Data-safety form, foreground-service declaration + demo video (draft text in `store/`).
- [ ] **Public pages** — host a privacy policy and an account-deletion page; put the URLs in the listing and in the app.
- [ ] **Lawyer review** — CST / GCAM licensing for a digital-content platform, PDPL texts and cross-border transfer, minors/age policy, Arabic Terms and Privacy (see `store/counsel_questions.md`). Nothing in this repo is a legal opinion.

## Backend (real Supabase project)
- [ ] **Review, then push migrations** — read the diff of every new file in `supabase/migrations/` first, then `npx supabase db push` yourself. Claude Code never touched the real project.
- [ ] **Supabase Auth URLs** — update Redirect URLs / Site URL for the final deep-link scheme.
- [ ] **Supabase region** — decide it (PDPL cross-border considerations).
- [ ] **Master admins** — choose the accounts; consider removing personal emails from `supabase/migrations/20260822090000_admin_role_bootstrap.sql` before the repo is ever shared.

## Keys and RLS (verify on the real project after you push)
- [ ] In the Supabase dashboard confirm RLS shows as enabled on every table and the Security Advisor has no errors.
- [ ] The service-role key lives only in server-side places (Edge Function secrets, your own scripts), never in Flutter, git, chat or CI logs.
- [ ] If `gates.mjs` (G11e/G11g) or `scan_build_secrets.mjs` ever reports a key: rotate it in the dashboard (Settings, API / JWT keys) and rebuild. History is not rewritten.
- [ ] If you run the job in Codex: do the set-up in `brief/04_BUDGET_PROTOCOL.md` §G (status-line items, rules file, `--probe`).

## Google
- [ ] **YouTube API key** — restrict it: Android package + SHA-1 of the upload key **and** the Play signing key + API restriction to YouTube Data API v3.
- [ ] **OAuth consent screen** — branding and verification for the final app name.

## After the run
- [ ] Run the DB probe files against a local stack (`supabase/tests/`) if Docker was not available during the run.
- [ ] Run the E4 scenarios from `brief/06_VERIFICATION.md` §3 on two real phones (multi-device, live viewer count, offline start, release build).
- [ ] Delete `_to_delete/` (stale git lock files) when convenient.

## Added by Claude Code during the run
(append below: item · exact command or value · why it must be the owner)

- [ ] P1 database runtime verification: execute broadcaster_columns.test.sql, streamer_assets.test.sql and application_and_ban_guards.test.sql using local Supabase tests. Docker was unavailable; all new SQL remains UNVERIFIED-STATIC.
- [ ] Legacy streamer-assets objects remain publicly readable. New uploads use UID prefixes. Existing flat paths require an admin to replace/delete; review and migrate legacy assets if needed.
- [ ] Do not apply this partial P1 set as a finished release: guarded live-state/device RPCs and remaining access-control work are still outstanding. Review the ledger before any production migration.

## Window 2 checkpoint, 2026-09-20
- Review 20260920120000_guarded_broadcast_sessions.sql before deployment: it intentionally ends all existing live sessions and primary claims because their old ownership flags were untrusted. Clients must claim again. No production command ran here.
- SQL/device acceptance remains UNVERIFIED-STATIC. Run broadcast_sessions.test.sql on the local Supabase stack. Then test two physical devices: A live; B sees conflict; explicit transfer to B stops A; A cannot restart; silent primary over 90 seconds is claimable; viewers receive no conflict; repeat with an audio-only org member and verify video denial. Test owner/non-owner chat moderation. Realtime/background RTMP and WebView navigation need real-device verification.
- Sign out other devices revokes refresh sessions; existing access JWTs remain usable until expiry. Review auth expiry settings before release. Restrict the YouTube API key to the final Android package, signing certificates and intended API.

## P1c (Claude Code Opus, 2026-09-20)
- Apply order matters: `20260920110000_is_banned_helper.sql` is timestamped BEFORE `20260920120000_guarded_broadcast_sessions.sql` because that migration calls `public.is_banned(uuid)`, which no migration ever defined. `can_broadcast` is a SQL-language function, so the guarded-sessions migration would fail while being applied. If any database already ran the 20260920 set successfully, tell the agent — that would contradict this reading.
- Durable live-flag expiry: `sweep_stale_live_flags()` is currently nudged by clients (at most once a minute, before a feed refresh). Schedule it server-side so a dead broadcaster's flag clears even when nobody opens the app: in the Supabase dashboard enable `pg_cron` and add `select cron.schedule('sweep-live-flags','* * * * *',$$select public.sweep_stale_live_flags()$$);`. Owner-only: it needs dashboard/extension privileges.
- `bootstrap_admin_role()` still grants master_admin to three hardcoded personal emails; it now also requires that Supabase Auth verified that address for that user id, which closes the spoof path but not the "personal emails in a shared repo" question. Decide whether those three addresses stay before the repo is shared (05 owner-only actions).
- Review `20260920140000_policy_quality.sql` before pushing: it drops and recreates the write policies on `user_roles`, `user_permissions` and `banned_users` (same authority, split per command) and revokes EXECUTE on helper/trigger functions from `public`/`anon`. If any external tool or dashboard SQL calls those functions as `anon`, it will stop working.

## P2 completion / P3 / P6.1 (Claude Code Opus, 2026-09-20, second session)
- Four new migrations to review before any push, in this order: `20260920150000_follows_and_bookmarks.sql`, `20260920160000_viewer_presence.sql`, `20260920170000_chat_rate_limit_and_settings.sql` (plus the P1c set already listed above). None was applied anywhere; Docker was unavailable again.
- Run the new pgTAP files on a local stack: `follows_and_bookmarks` (13 assertions), `viewer_presence` (14), `chat_rate_limit` (11), plus the P1c `live_flag_expiry_and_privilege` (18). Until then every claim about RLS and the RPCs is UNVERIFIED-STATIC.
- `viewer_heartbeat` and `get_viewer_counts` are granted to `anon` on purpose (guests are counted). That is the one place this app lets an anonymous caller write, and it writes only to the deny-all `stream_viewers` table through a definer function. Confirm you are comfortable with that before pushing.
- The default avatar/banner placeholder is still a real person's photograph (`assets/images/Amir_Alhatemi/...`, used by `buildSafeImageProvider` and several screens), and `assets/images/Amir_Alhatemi/` is 7.6 MB of the bundle. Replacing it needs a neutral placeholder image, which is design work reserved for Astra (05 D-27) -- it was deliberately not invented here.

## P1d (Claude Code Opus, 2026-09-21) — Docker worked; the SQL is now verified, and three things need your decision

**Read this section before any `supabase db push`.** Docker was available for
the first time, so the whole chain was applied to a local stack and the pgTAP
suite ran. That turned up faults no static review could have found. Nothing was
run against the linked production project (`zkkmfjsjouqzibvnzkau`).

1. **The migration chain could not be applied from scratch — at all.** Two
   migrations aborted it, so *nothing after `20260830170000` had ever reached
   any database*, including the entire `20260831*` and `20260920*` set. Earlier
   sessions recorded `UNVERIFIED-STATIC` and blamed Docker; Docker was only half
   the reason.
   - `20260830180000_map_visibility_toggle.sql` re-adds `latitude, longitude`
     into the middle of the `streamer_public_profiles` select list with
     `create or replace view`. PostgreSQL only allows appending columns, so this
     fails with `42P16`. Repaired by a new migration timestamped just before it,
     `20260830175000_realign_streamer_public_view.sql`.
   - `20260920140000_policy_quality.sql` revoked/granted
     `chat_sender_info(uuid[])`, a signature dropped back in `20260830160000`.
     `42883`. **This is the one existing migration file that was edited** — two
     dead statements removed. It is safe: the migration could never have applied
     anywhere, so no database can disagree with the edit.
   - **What this means for production.** Your production project must have been
     built some other way (dashboard SQL, or an earlier column order), because
     applying these files in order cannot have succeeded. Before pushing,
     compare the live schema with the local one — in particular whether
     `profiles.is_temporarily_hidden_from_map` exists and what columns
     `streamer_public_profiles` actually has. `20260830175000` carries an
     earlier timestamp than migrations you may already have applied, so
     `supabase db push` will normally skip it; that is the safe outcome, but it
     means production keeps whatever view shape it has today.

2. **DECISION NEEDED — exact GPS coordinates are public again (VULN-COMP-02).**
   `20260822140000_restrict_pii_rls.sql` deliberately removed
   `latitude`/`longitude` from the anon-readable `streamer_public_profiles`,
   because an individual broadcaster's self-declared venue can be their home;
   it explicitly deferred "how is a streamer's location shown publicly without
   exposing exact GPS (fuzzing/rounding, a radius query)". `20260830180000`
   silently put the columns back, and `admin_database_service.dart` now reads
   them for the map. Restoring them was unavoidable to make the chain apply, so
   **the exposure is live in the repo now**. This was not decided here because
   every option changes what the map shows. Pick one:
   - round in the view: `round(latitude::numeric, 2) as latitude` (~1.1 km) —
     one migration, markers land in the right neighbourhood, not on a doorstep;
   - keep full precision for organizations (public institutions) and round only
     for individual streamers;
   - keep exact coordinates and accept the risk, recorded as an ADR with your
     name and the date (05 D-21 / EXEC-12.4 require a named approver).

3. **DECISION NEEDED — the schema granted the API roles almost nothing.** Only
   four objects had ever been granted to `anon`/`authenticated`. Table
   privileges are checked *before* row-level security, so all 110 policies were
   unreachable: 7 of the 8 pgTAP files died on
   `42501 permission denied for table ...` against tables whose policies were
   correct. `20260921110000_table_grants_and_audit_scope.sql` adds the minimal
   grant set. **Your production project almost certainly does not have this
   problem** — `[api] auto_expose_new_tables` is unset in `config.toml`, which
   matches the *current* cloud default, while your project was created when new
   entities were auto-exposed. So this was a latent break (the schema could not
   be rebuilt from its own migrations) rather than a live outage. Before
   pushing, confirm the grants the migration adds match what production already
   has, so it is a no-op there:
   ```
   select table_name, privilege_type from information_schema.table_privileges
    where table_schema='public' and grantee='authenticated' order by 1,2;
   ```

4. **P6 bug, not fixed here: the chat filter blocks "Hello".**
   `chat_check_banned_keywords` matches bare substrings, and the starter
   blocklist in `20260826090000` contains `hell` — so `Hello` is rejected as
   profanity. Found the first time `chat_rate_limit.test.sql` actually ran. The
   test now uses `Salaam` so it tests the rate limiter instead. Fixing it means
   word-boundary matching plus the Arabic-aware normalisation already on the
   P6.1 remainder list; both are P6 scope.

5. **Still outstanding from P1c, unchanged:** schedule
   `sweep_stale_live_flags()` server-side with `pg_cron` (a dead broadcaster's
   live flag otherwise clears only when a client nudges it); decide whether the
   three hardcoded personal emails stay in `bootstrap_admin_role()`; review the
   `20260920` migration set before pushing. Applying `20260920120000` still
   wipes every current live flag.

## P6a (Claude Code Opus, 2026-09-21) — three new migrations to review before any push

Nothing was run against the linked production project. The P1d entries above still
stand, including the two decisions that block a push.

1. **`20260921140000_audit_moderation_actions.sql` changes a CHECK constraint on
   `audit_logs`.** It drops `audit_logs_action_check` and re-adds it with four
   extra values (`chatReportDismissed`, `chatMessageDeleted`, `chatSenderMuted`,
   `chatSenderBanned`). Without it, **every chat-moderation audit write is
   rejected with `23514` and silently swallowed**, because an audit write must
   never undo a mute that already took effect, so both call sites are
   best-effort. If production already holds moderation audit rows, or a differing
   constraint, check that before applying:
   ```
   select pg_get_constraintdef(oid) from pg_constraint
    where conname = 'audit_logs_action_check';
   ```
   Re-adding a CHECK validates every existing row, so it will fail rather than
   corrupt anything if production holds an action value this list omits.

2. **`20260921130000_chat_realtime_publication.sql` publishes two tables** to
   `supabase_realtime`: `chat_stream_settings` and `chat_reports`. Both keep
   their existing policies and Realtime applies RLS per subscriber, so no new
   data is exposed — `chat_stream_settings` is already world-readable by policy
   and `chat_reports` is already admin-only. `chat_muted_users` is deliberately
   NOT published; the migration comment says why (it would tell a muted account
   which moderator muted it).

3. **`20260921120000_chat_keyword_boundaries_and_normalization.sql` changes what
   the chat filter blocks, in both directions.** Decide whether you are happy
   with the trade before pushing:
   - No longer blocked: inflected forms. `stupidly` is not caught by `stupid`,
     and the Arabic `الغبي` is not caught by `غبي`, the same way `hells` is not
     caught by `hell`. This is the price of `Hello` no longer being blocked.
   - Newly blocked: decorated and elongated Arabic spellings that previously
     slipped past entirely (`غَبِيّ`, `غـــبي`), and every casing.
   - The table gains a `match_mode` column. Set a row to `'substring'` to get the
     old blunt behaviour for that one keyword:
     ```
     update public.chat_banned_keywords set match_mode = 'substring'
      where keyword = '<the one you want caught everywhere>';
     ```
   - There is no admin UI for this yet — the keyword manager is P6.4 item 4 and
     is not built. Until then the list and its match modes are SQL-only.

4. **Not a migration, but worth knowing for P6.4:** `device_sessions` has exactly
   one policy, `device_sessions_select_own`, so a platform admin cannot see
   another account's devices. The P6.4 user directory needs that, and it needs a
   new migration (an admin SELECT policy or a definer RPC). Admin-initiated
   account deletion also has no server path today; `delete_own_account()` is
   self-only.

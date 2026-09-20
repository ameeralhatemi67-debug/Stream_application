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

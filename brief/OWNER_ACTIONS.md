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

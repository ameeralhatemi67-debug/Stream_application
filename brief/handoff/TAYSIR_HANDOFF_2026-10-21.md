# Handoff: Taysir in Hadayah Live + green design removal (2026-10-21)

Owner request (verbatim intent): build the "Taysir in Hadayah Live" prototype
(artifact https://claude.ai/artifact/PPAvDrjpoiZBV5MbGm8tNc) fully into the app,
switched by tapping the app logo in Settings; delete the old green design so the
switch goes between the gold/black Hadayah Live and Taysir. Take Taysir's
features and some logic from `D:\Agents\main\projects\ideas\taysir`, but rebuild
and upgrade them on our Supabase. Background: `brief/research/taysir/2026-10-21_TAYSIR_DNA_HEALTH_AND_INTEGRATION.md`.

Rules that still apply: commit locally on master, never push (owner pushes);
no hosted Supabase change without the owner's explicit yes in chat; leave the
owner's unrelated working-tree changes alone (package-lock.json,
android/build/reports, logoInkscapeMaker.svg, skill-observations/log.md,
store/assets/icon_512.png, untracked brief/ and doc/ files).

## Done

### Phase 1, committed `efed22a`: green removed, logo is the experience switch
- Gold is the source tokens (`canopy_tokens.dart`, `app_theme.dart`); the runtime
  remap (`paletteColor` and friends, ~2,400 call sites) and `AppPalette.hidayah`
  are gone. `AppPalette` is now plain gold constants.
- `lib/core/providers/app_experience.dart`: `Experience.hadayah` (`/feed`) or
  `Experience.taysir` (`/taysir`), persisted per device; the old
  `hidayah_palette_enabled` key is deleted on start.
- Settings About card: tapping the logo toggles and navigates (`about_settings_section.dart`).
- Router: `/feed` redirects to `/taysir` when Taysir is chosen.
- Gold launcher icon on Android, iOS and web; splash on night slate; both
  Android launcher aliases kept (component state survives updates).
  `brief/tools/make_launcher_assets.py` now builds gold; the hidayah script was removed.
- Website layout is always on at >= 1024 px. Fixed overflows this exposed (live
  room identity row, studio header, quiet discovery panel, header wordmark,
  system-bar insets via SafeArea). Gold success colour darkened to `2D7647` for AA.
- Verified: analyzer 0; full Flutter suite 1,556 passed, 10 skipped, 0 failed.

### Phase 2-4, NOT YET COMMITTED when this file was written (see "Next" step 1)
- **Migration** `supabase/migrations/20261021142359_taysir_lessons_programme.sql`
  (not deployed anywhere hosted). 14 public tables + 2 private
  (`taysir_preacher_contacts`, `taysir_invites`), ~40 functions. Authority =
  `user_permissions` keys `activities.coordinate` / `activities.submit` via
  `has_permission()`; org leaders (owner/co-owner) coordinate implicitly; master
  admin enables Taysir per org (`taysir_organizations`). All writes through
  security-definer RPCs; viewers write only own reminders/follows/attendance/prefs.
  Phones private with logged reveal; single-use hashed invite tokens; public sees
  approved/cancelled lessons of enabled orgs, verified mosques, listed preachers.
  `export_my_data()` wrapped to add a `taysir` section (core moved to
  `private.export_my_data_core`).
- **SQL tests** `supabase/tests/taysir_lessons_programme.test.sql` 62/62 pass;
  `rls_catalog.test.sql` allowlist updated (only the 3 pre-existing
  `hidden_channel_content` failures remain). Whole suite on the Taysir DB:
  935 ok / 3 not ok (same 3 pre-existing), vs 873/3 before.
  Disposable DBs in container `supabase_db_P6_accept_disposable`:
  `taysir_base_20261021` (with migration), `taysir_pre_20261021` (without).
  Apply locally with `-U supabase_admin` (that is how those clones were built).
- **Dart** under `project/lib/features/taysir/`:
  `domain/` (vocab, models, prayer_times Umm al-Qura, dates + Hijri via `hijri`
  package, rules: clashes, series dates, filters, Excel-safe CSV),
  `data/` (repository interface, Supabase repo, Demo repo with the prototype's
  sample data and persona switch), `state/taysir_controller.dart` (provided in
  `main.dart` as a `ChangeNotifierProxyProvider<AppProvider, TaysirController>`;
  Demo repo when Supabase isn't configured),
  `presentation/` (kit, icons, widgets, modals, map on the tri-city pack, shell
  with phone tabs + website header/footer, screens: discover, lessons, detail
  (lesson/series/preacher/mosque), map, account (me/notifications/saved/
  permissions/claim), preacher (my lessons/submit wizard/report), console
  (overview/review/preachers/mosques/stats/audit/team)).
  Routes added in `app_router.dart` (`/taysir`, `/taysir/lessons[/:id]`,
  `/taysir/map`, `/taysir/me[...]`, `/taysir/submit`, `/taysir/report/:id`,
  `/taysir/claim/:token`, `/taysir/console[/:tab]`, `/taysir/permissions`,
  `/taysir/series|preachers|mosques/:id`, `/taysir/requests/:id`).
- ~780 EN/AR strings under `taysir.*` (key-symmetric; Arabic CLDR plurals).
- Verified so far: `flutter analyze` 0 issues; `test/taysir_domain_test.dart`
  (12) and `test/app_experience_test.dart` (5) pass.

## Update, later on 2026-10-21: steps 1-5 done

- Step 1: committed as `cb37376`.
- Step 2: `project/test/taysir_screens_test.dart`, 48 widget tests on the real
  `AppRouter` with `DemoTaysirRepository` personas (see STATUS for the list),
  including a 37-route layout sweep at 360/1280 px, ar/en, text 1x/2x.
- Fixes the tests and the browser found: controller notify during build;
  2x-text overflows (TSeg, wizard nav, prayer strip, weekly chart, team row);
  search-box inner outline; coordinator Me card's report count; language
  switch leaving tabs/app bar/banner stale (now `LanguageSwitcher.set`, which
  rebuilds the tree once and syncs push-reminder language).
- Steps 3-5: full suite, browser check (sample data) and docs (ADR-013,
  ADR-014, STATUS, LEDGER, CLAUDE.md). Results in the LEDGER RESUME block.
- Step 6 (hosted deploy) waits for the owner's yes in chat.

## Update, evening 2026-10-21: deployed; admins manage coordinators

- Owner said yes. Migration applied through the MCP connector and stamped
  `20261021142359` (local file renamed); hosted fingerprint-matches the tested
  clone. Owner chose not to grant a first coordinator: admins add, edit and
  remove coordinators themselves (`taysir_admin_coordinators`,
  `taysir_set_coordinator_orgs`, the "Coordinators" card in the console's
  Team tab; account search uses `admin_user_directory`).
- Hosted has **no organizations** yet. Next: the owner creates the Hidayah
  organization (the organization flow in `brief/launch/02_TESTING_PLAN.md` §A), then
  a master admin opens Taysir → Me → console → Team, switches Taysir on for
  it, and adds coordinators. The app changes reach users with the next build
  (web goes live when the owner pushes `master`).

Browser previews: `.claude/launch.json` has `app-web-sample-data` (port 8790)
and `app-web-hosted` (port 8792, `dart_define.local.json`), both
`flutter run -d web-server` in debug. Open `http://127.0.0.1:<port>/#/taysir`.

## Next (in order), as first written
1. If `git log -1` is not the Taysir commit, commit Phases 2-4 (stage only:
   the migration + 2 SQL test files, `project/lib`, `project/test`,
   `project/assets/i18n`, this handoff). Conventional message
   `feat(taysir): ...`, no push.
2. **Widget tests** for Taysir screens (none yet). Harness: `EasyLocalization`
   + `DirectJsonAssetLoader` (test/support/localized_app.dart) +
   `ChangeNotifierProvider<TaysirController>` with `DemoTaysirRepository(persona: ...)`,
   plus `AppProvider` (TaysirShell/channel lookups read it), and set
   `TaysirMap.debugPlaceholder = true`. Cover: discover (phone + 1280 web),
   lessons filters, lesson detail remind/share/cancel, submit wizard to
   "Send for review", console review approve/reject, roster reveal, claim flow,
   settings toggle -> `/taysir` route resolves. Run at en/ar and text scale 2
   (layout sweeps caught many overflows in Phase 1).
3. Run the full suite (`flutter test`, ~20 min, run in background) and fix.
4. Run it in Chrome without credentials (Demo data, persona switcher on the Me
   tab) and with `--dart-define-from-file=dart_define.local.json`; check
   phone width and 1280 width, AR and EN. Note the hosted DB lacks the migration
   until step 6, so configured runs show the Taysir "unavailable" state.
5. Docs: ADR in `Core_files/decisions.md` (gold-only design; Taysir module,
   permission keys, invite links instead of passwords), `Core_files/STATUS.md`,
   `brief/LEDGER.md` RESUME block, CLAUDE.md roadmap line.
6. Ask the owner before deploying the migration to hosted
   (`zkkmfjsjouqzibvnzkau`) via the Supabase MCP (rename the file to the
   stamped version afterwards, as in earlier deployments), then enable Taysir
   for the Hidayah organization and grant the first coordinator.

## Known gaps / decisions to raise with the owner
- Push reminders for Taysir: `taysir_reminders.remind_at` is stored, but the
  `dispatch-upcoming-reminders` Edge Function does not send them yet; the
  evening digest preference is stored only. In-app notifications work.
- Guests can't reach Settings, so the logo switch needs a signed-in account;
  shared `/taysir/...` links work for everyone.
- No QR code on the share card (would need a new dependency); post-lesson
  photos not implemented (prototype had them).
- Real Taysir data (43 preachers with phones) was deliberately not imported;
  coordinators can import CSV in the console. Live Taysir site still needs the
  security fixes listed in the research report section 6.1.
- `org_co_owner` follows existing conventions; coordinators must be org members.

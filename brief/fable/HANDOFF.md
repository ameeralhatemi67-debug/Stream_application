# Handoff 6: after the Lantern and Arch release (written 2026-11-12)

This file is for the next session (Claude Opus), which will fix faults and edit things with the owner. It is complete on its own: read it, then `CLAUDE.md`, then start.

**How to use it.** Open the session in the repository root, `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app`, and say: *read `brief/fable/HANDOFF.md` and continue with what I ask*. The owner decides what to fix and edit; section 4 lists what is already known.

## 0. Update, 2026-11-12 evening: the owner's phone notes

Done on `master` (one commit, pushed): Lantern and Arch is the default and gold & black is no longer offered (ADR-027; `AppSkin.gold` stays in code for Hedayah's shared screens); the notifications sheet has a settings button beside close that opens `/settings?section=notifications`; the phone broadcaster can hide the chat over the camera (swipe it down, or the switch in the tools); the hold-to-end button no longer turns into a solid gold block (the kit's focus ring was painted over controls, `LFocusRing` now draws it outside and only for the keyboard); with the camera off, Lantern shows the pattern and a live microphone level (Android now reports the level: `MicLevelEffect.kt`) with a red "microphone is off"; the quick tools sheet is a Lantern sheet (`lantern_broadcast_parts.dart`); linking or unlinking the personal YouTube channel first ends the studio's unused background preparation (`AppProvider.endUnusedPreparations`), which the server counted as an active show; the channel page's share, studio (now an icon) and settings sit in the phone's page bar; the map cards of Discover and Lessons show the real map on the website layout (`LanternMapPreview`) and the drawing on phones; the map credit on phones is a small chip in the bottom corner under the navigation.

Not checked on a device: the microphone level and the swipe on a real phone (tests and the emulator build only).

Second round the same day (commit after `6c53008`): the map cards of Discover and Lessons show the real map on phones too (`LanternMapPreview`, zoom fitted to the card width; `LessonsMap.overviewZoom`); channel cards on Discover are one height, with the tags, Watch and Follow on one line; mosque pins are an arched pin with a mosque, a count badge and a tail (`LanternMosqueMark`, also used by `MosqueArch` under Lantern); the channel page's website layout has About in the header between the name and the buttons (no side column) and the buttons at the end; on a phone the report flag ends the buttons row; the "several devices" dialog has a Lantern version (`lantern_device_conflict.dart`, devices named by kind); the Preachers & lessons admin area uses the platform area's frame (`LanternLessonsAdminFrame`, `LanternAdminNavItem` is now public).

## 1. The state today

- **Lantern and Arch is released.** It is a third design beside gold & black and Hedayah (since ADR-027 it is the default and gold & black is no longer offered), chosen in Settings → Design (ADR-026 in `Core_files/decisions.md`). It was built on the branch `fable/lantern-skin`, merged into `master` on 2026-11-12, pushed, and is live on https://live.hedayh.org.sa.
- **Live build:** commit `202df7f` (Vercel production `dpl_4jBMdhJ3aT81E7kEBT96AM3RNBwh`). The page's `hadayah-build` meta tag shows the commit that is live.
- **`master` here is one commit ahead of GitHub:** `fc6047a`, a documents-only release note. It was left unpushed on purpose, because every push to `master` redeploys the website. This file adds one more local documents commit.
- **Hosted database:** the migration `20261111120000_content_reports.sql` is applied (the table behind Report). Two older local migrations are deliberately not on hosted and must stay that way unless the owner says otherwise: `20261017213039_apple_account_deletion_revocation.sql` and `20261026120000_app_releases.sql`.
- **Checks on the released code:** `flutter analyze` 0 issues; full suite 2,478 passed, 0 failed, 65 skipped (the skipped ones are picture tests that run only on request); the web release build succeeds.
- **The owner's files left uncommitted on `master`, exactly as he had them. Do not commit, change or discard them unless he asks:** `package-lock.json`, `project/android/build/reports/problems/problems-report.html`, `project/assets/logo/logoInkscapeMaker.svg`, `skill-observations/log.md`, `store/assets/icon_512.png`. The git ref `refs/backup/owner-work-20261112` holds his whole uncommitted work as it was before the merge.

## 2. Rules that stay in force

- **Work directly on `master`** in the repository root (project rule: no feature branches, no pull requests). Run Flutter commands from `project/`.
- **Never push unless the owner asks in that conversation.** A push to `master` deploys the website.
- **Ask the owner before:** a push, applying a migration to hosted, deploying an edge function, deleting data, branches or worktrees, anything that costs money, any message to real people. Never create, print or commit keys or passwords. Do not sign in with a real account.
- **No new cost.** No paid service, plan upgrade, paid font or paid icon set.
- **Hedayah keeps its look** (gold & black is no longer offered, ADR-027). New screens and features go into Lantern only. The one approved exception is Report for a broadcast or a channel, which is in all three designs (owner, 2026-11-12). Any other visible change to the two older designs needs the owner's word first.
- **Before calling a change done:** `flutter analyze` reports 0 issues and the full `flutter test` suite passes. `en.json` and `ar.json` stay key-symmetric. Right-to-left layout comes from `Directionality`, not from left/right code.

## 3. How the Lantern design is built (what to know before editing it)

- Every Lantern widget implements the marker `LanternSkinWidget` and lives in a `lantern/` folder: the kit in `project/lib/core/widgets/lantern/` (its `README.md` is the build guide), tokens in `project/lib/core/theme/lantern/`, each feature's views in `project/lib/features/<feature>/presentation/lantern/`.
- An existing screen keeps its logic. At the top of `build` it hands over to its Lantern view when `context.isLanternSkin`. So a fix to behaviour usually belongs in the shared screen or controller, and a fix to looks belongs in the `lantern/` view (or in the older widgets, for the older designs).
- `project/test/lantern_isolation_test.dart` fails if a Lantern widget is built under an older design.
- The older kits (`ds/*`, the website kit, the Lessons kit) draw as Lantern pieces under Lantern (`lantern_compat.dart`), so a screen without its own Lantern view is still one design.
- **Layouts come in pairs.** Many screens have a phone layout and a separate website layout for wide screens (`context.usesHidayahWeb`), for example `ProfileWebHero` for the channel page and `LiveWebLayout` for the room. A change to one layout usually needs the same change in the other. This was missed once in the release (see section 4, item 2).
- **Strings:** add Lantern strings to a file in `brief/tools/lantern_i18n/NN_area.json`, then run `python brief/tools/merge_lantern_i18n.py` from the repository root. Never hand-merge the two catalogs.
- **Icons:** `brief/tools/lantern_icons.json`, then `node brief/tools/make_lantern_icons.mjs`.
- **A page that the router loads on demand** (`deferred as` in `project/lib/core/routing/app_router.dart`) must be added to `AppRouter.preloadDeferredPages()`. `project/test/flutter_test_config.dart` calls it before each test file; without it, tests of such a page stay on a loading frame. Do not run `dart format` on `app_router.dart` (it reformats the whole file).
- **Report:** the service is `project/lib/core/services/content_report_service.dart`; the provider methods are `submitContentReport`, `loadContentReports`, `dismissContentReport`. The older designs use `project/lib/features/moderation/presentation/content_report_sheet.dart` (the sheet and the admin list). Lantern uses `lantern/lantern_report_sheet.dart` and `lantern/lantern_reports_queue.dart`.

## 4. Known faults and open work

### Faults to fix

1. **A channel page opened directly from its link shows "0 recordings, 0 playlists".** Seen on the live site on 2026-11-12: `https://live.hedayh.org.sa/#/profile/<id>` as the first page shows 0; the same page opened from Discover shows the real numbers (14 and 10 for the channel checked). It is older than the release: the release changed no line of the recordings code. Where to look: `_channelArchiveKnown` and `loadYouTubeChannelData` in `project/lib/core/providers/app_provider.dart` (the set is filled in three places, one of them near line 2113), and `isChannelArchiveKnown` as read by `project/lib/features/profile/presentation/broadcaster_profile_screen.dart`. A likely cause is that the archive is marked "known" before the channel's YouTube handle has loaded on a cold start; confirm this before changing anything. The count must show nothing until the archive has really loaded (audit note P1-13 in that file).
2. **Check every screen that has two layouts for the same kind of gap as the Report button.** The Report button was first added to the phone layout only; the website layout of the channel page got it one push later (`202df7f`). The room's website layout has it. No other gap is known, but nobody has looked through every Lantern-era change with this in mind.

### Not checked by anyone yet

- Anything signed in, on the live site or on a device: Settings, the broadcast studio, the admin page (with the new list of reported broadcasts and channels at the top of the chat moderation tab), phone broadcasting, the owner's own studio change (`3d6f328`).
- A real report sent and then cleared by an admin. The table is empty.
- A live room and an audio room on a device (no channel was live during the checks).
- The Lantern design on the live site (it was checked on a local build and on the Android emulator).
- Safari and Firefox. Memory and frame times. "Use my location" on the map.

### Not built

- Screens that still draw the older widgets under Lantern, restyled by the shared kit: twelve admin tabs (registry, organizations management, analytics, terms, custom cards, categories, tags, banned accounts, roles, user directory, safety, testing tools), `/org-admin`, the organization invitation page and members list, the "my lessons" pages, the preacher application and link pages, the lessons admin, the viewer set-up, the phone camera screen.
- A corner player that keeps playing when a room is left.
- On the map: the locate button and the Now / Tonight / This week control. A dark map for the night look.
- A Report button for one recording (a recording is reported through its channel today).
- The data export does not include the reports a person filed.

### Small known weak points

- Some older handlers still show a plain message bar under Lantern (after deleting an account or exporting data).
- Small action buttons on admin cards are 36 px high, below the 44 px target.
- The schedule editor uses the system date and time pickers.
- On a phone, the room's title in the older designs has one button less of room since the Report button was added.

### Waiting for the owner

- **The Android upload key.** `project/android/key.properties` does not exist, so no signed app bundle can be built. He runs `brief\launch\make_upload_key.ps1` himself. The Play steps are in `brief/fable/ANDROID_PLAY_STATUS.md` and `brief/launch/`.
- **The open design questions**, with the default chosen for each: section 9 of `brief/fable/FINAL_REPORT.md`.
- **Clean-up he has not approved yet:** the worktrees under `.claude/worktrees/` (`fable-lantern`, `skin-proof-master`, six `agent-*`) and the branch `fable/lantern-skin`. All their work is in `master`. Do not remove them without his word.
- **Before the Play review** (from the report's suggestions): add the YouTube API Services statement to `privacy.html`; the audio stage draws over the YouTube player in all designs, which YouTube's terms do not allow; prepare and test the reviewer account from `store/reviewer_access.md`.

## 5. Where things are written down

| What | Where |
|---|---|
| The owner's report on the whole run | `brief/fable/FINAL_REPORT.md`; the same text is the private doc https://claude.ai/artifact/GTkLmFWtF5ggWM8vnTxW5E (edit both when the report changes) |
| The release, step by step | the last RESUME block of `brief/LEDGER.md` |
| What works today | `Core_files/STATUS.md` |
| Decisions | `Core_files/decisions.md` (ADR-026 is Lantern; ADR-013 gold; ADR-016 Hedayah; ADR-025 web speed) |
| Proof of what changed in the older designs | `brief/fable/skin_regression/RESULT.md` |
| Google Play requirements and status | `brief/fable/ANDROID_PLAY_STATUS.md`, `brief/launch/`, `store/` |
| The owner's original brief for the Lantern run | `brief/prompts/FABLE_LANTERN_SKIN_RELEASE_PROMPT.md` (untracked) |
| The approved design | `brief/design/lantern_and_arch/` (untracked; `source_parts/app_*` is the identity, `web_*` is the pages) |

## 6. Tools and traps

- **Whole suite**, from `project/`: `flutter test --reporter expanded 2>&1 | tr '\r' '\n' | grep -E "\[E\]$|tests passed|tests failed"`. It takes 7 to 10 minutes. Do not edit `lib/` while it runs. Start it in the background, because a foreground command stops at 10 minutes.
- **One test file:** `flutter test test/<file> --reporter expanded`. The test harness for the whole app in any design is `LanternApp.start(tester, skin: ..., location: ..., size: ...)` in `project/test/support/lantern_harness.dart`. Use `app.settle()` (a few frames), not `pumpAndSettle`, because some animations never end.
- **Proof that the older designs did not change:** `bash brief/tools/skin_proof.sh "<repo>/.claude/worktrees/skin-proof-master" "<absolute output folder>"`. It draws 38 pictures on a clean copy of the pre-release `master` and on the current code and compares them. Today's expected result is 28 same and 10 different (the Settings design tile, and the screens with the Report button). A new difference means an older design changed. The output folder must be an absolute path. Do not commit the pictures.
- **Lantern pictures:** `LANTERN_CAPTURE_DIR=<dir> flutter test test/lantern_capture_test.dart` (optional `LANTERN_CAPTURE_ONLY=map-,settings-`).
- **Some tests depend on the day and the hour** (sample lessons and the map are built around "now"). Never assume which lesson, preacher or pin a test will find.
- **Running the web app locally:** `flutter run -d chrome --dart-define-from-file=dart_define.local.json` from `project/` (real backend), or without the option for sample data. On the web, `?skin=lantern-arch`, `?skin=gold-black` or `?skin=hedayah-skin` before the `#` picks the design and saves it. Sample preacher links: `/#/preacher/demo-fahd`, `/#/preacher/demo-iqbal`.
- **The release web build** can be served with the preview entry `lantern-web-build` in `.claude/launch.json`. It serves the old worktree's `build/web`, so point it at `project/build/web` of the repository root, or add a new entry, before using it.
- **Hosted database:** the Supabase command-line tool is signed in and linked to the project `zkkmfjsjouqzibvnzkau` (`npx supabase migration list --linked`, `db query --linked "<sql>"`, `db advisors --linked`). The Supabase connector in the app is linked to a different account and cannot reach this project; do not touch the two projects it lists. To apply one new migration without the two held-back ones: copy `supabase/` (with `.temp/`, without those two files) to a scratch folder, run `npx supabase db push --linked --dry-run --workdir <copy>`, check that it lists only the new file, then run it without `--dry-run`. Only with the owner's approval.
- **A local test database:** port 54322 is held by an older disposable database, and Windows reserves ports 57228 to 58227. A copy of `supabase/` with its own `project_id` and ports 533xx starts cleanly with `npx supabase db start --workdir <copy>`; remove it afterwards with `npx supabase stop --no-backup --workdir <copy>`. Docker must be running.
- **Android emulator:** the SDK is on `D:\app\Android\Sdk`, the device is `Pixel_5`, and it allows `adb root`. A profile build needs no key: `flutter build apk --profile --target-platform android-x64 --dart-define-from-file=dart_define.local.json` (never print or copy that file). The design is the string `flutter.app_skin` in the app's `FlutterSharedPreferences.xml`, the language is `flutter.locale`, the Lantern look is `flutter.lantern_appearance`. Write the file with `cat new > file` so that its owner stays the app. A guest cannot open Settings. The app on the emulator is a guest named "Tester".
- **After a push**, wait about two minutes, then read the `hadayah-build` meta tag of the live page to confirm the new commit is live. Scan what is pushed for key files and key patterns first (`git diff origin/master master`).
- **Shell:** write long scripts to a file; a here-document with apostrophes in it fails in this shell. Use `git add <paths>`, never a whole folder. The three `project/windows/flutter/generated_*` files are generated: do not commit them.
- **Machine:** 15 GB of memory. One heavy job at a time (the full suite, a Gradle build, the emulator).
- **Lantern details:** `LLattice` is already a `Positioned.fill`. `LNightBand` gives night colours only to widgets built with a context inside it (use a `Builder`). `lanternToast` is a snack bar and does not show over an open sheet. White text on the night state colours fails contrast: use `LanternTokens.liveFill`, `okFill`, `audioFill` (`project/test/lantern_contrast_test.dart`).

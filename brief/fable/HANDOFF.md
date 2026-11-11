# Handoff 3: Lantern and Arch run, state on 2026-11-11 (second session)

This file is the state of the run. The owner's brief is the authority:
`brief/prompts/FABLE_LANTERN_SKIN_RELEASE_PROMPT.md` in the main checkout
(untracked there). To continue in a new session: paste that brief, then say
*read `brief/fable/HANDOFF.md` in the worktree `.claude/worktrees/fable-lantern`
and continue*.

Nothing was pushed. No hosted migration was applied. No edge function was
deployed. No key or secret was created or changed.

## 1. Where the work is

| Thing | Place |
|---|---|
| Work branch | `fable/lantern-skin` (from `master` `77bcff0`) |
| Worktree | `.claude/worktrees/fable-lantern` (Flutter app in `project/`) |
| Main checkout | on `master`, holds the owner's uncommitted studio work. **Do not touch it.** |
| Design source | main checkout, untracked: `brief/design/lantern_and_arch/source_parts/` |
| Build guide for the skin | `project/lib/core/widgets/lantern/README.md`; decision record ADR-026 in `Core_files/decisions.md` |
| Map of the old code | `brief/fable/scratch/CODE_MAP.md` |
| Play findings | `brief/fable/ANDROID_PLAY_STATUS.md` |
| Progress table | `brief/fable/PROGRESS.md` |

Always start shell commands with an absolute `cd` to the worktree. The shell
directory drifts.

## 2. Rules that stay in force (short form)

- No cost of any kind. Never push. Commit locally on `fable/lantern-skin` only.
- No hosted migration, no edge function deploy, no change to secrets, `.env` files, signing keys or store credentials. Never create, print or commit a key.
- Gold & black and Hedayah must look and behave exactly as on `master`.
- One screen never mixes widgets from two skins.
- Gates: `flutter analyze` 0 issues, full `flutter test` green, catalogs key-symmetric, RTL by `Directionality`, AA contrast, calm motion respected.
- Ask the owner before: push, deploy, hosted migration, deleting data or branches, anything that costs money, any message to real people.

## 3. Done and committed in this session

| Commit | Content | Tests |
|---|---|---|
| `435bc76` | Map: Lantern search, filters, layer chips, zoom, legend, list, connection line, credit and map details; 400 px side panel on the website layout; sheets open over the whole app; the failing test fixed (it tapped a pin under the search) | `lantern_map_test` 39 |
| `f321beb` | ADR-026, progress file, Play status header | |
| `937109c` | Helper A merged: the older kits (`ds/*`, website kit, lessons kit) draw as Lantern under Lantern (`lantern_compat.dart`) | `lantern_compat_test` 148 |
| `a94480f` to `8887d85` | Helper B merged: Lantern lessons home, calendar, lesson, preacher, mosque and series pages | `lantern_lessons_test` 38 |
| `4af19ce` | Broadcast studio: one night page, status card, three steps, hold to go live and hold to end | `lantern_studio_test` 13 |
| `b2bd83a` | **The surprise:** an invitation picture for a lesson (1080 x 1350, made on the device), from the lesson's share sheet | `lantern_poster_test` 5 |
| `f861945` | Report a broadcast or a channel: migration `20261111120000_content_reports.sql`, service, provider methods, Lantern report sheet, Report in the live room | `lantern_report_test` 12 |

Full suite after the studio: **2,238 passed, 0 failed** (54 skipped are picture
tests that need a folder). It has not been re-run after `b2bd83a` and
`f861945`; their own tests and the Lantern files pass.

## 4. Running when this was written

Two helpers (Opus), each in its own worktree created from `b2bd83a`. Their
briefs are in the session scratchpad and may be gone later; the scope is:

- **H1**: settings (category list, Appearance pane with day, night, follow the device, calm motion; delete account as press-and-hold), welcome and sign-in with the consent dialog, notifications drawer, bookmarks, page not found. Strings `30_account.json`, test `lantern_account_test.dart`.
- **H2**: channel page, then the broadcaster application with inline errors and its status page. Strings `40_channel.json`, `41_apply.json`, tests `lantern_channel_test.dart`, `lantern_apply_test.dart`.

If a new session finds them unmerged: `git worktree list`, look for the two
newest `agent-*` worktrees, read `git log d82e114..HEAD` there, cherry-pick
onto `fable/lantern-skin`, run `python brief/tools/merge_lantern_i18n.py`,
then the analyzer and the tests.

## 5. Still to do, in order

1. Merge H1 and H2 after reading their diffs. Add the Report action to the channel page (`showLanternReportSheet`, kind `channel`).
2. Admin hub (rail, KPI cards, batch bar, pipeline), organization hub, chat moderation dialogs, and a **queue for content reports** (the provider has `loadContentReports` and `dismissContentReport`; no screen reads them yet).
3. Lessons pages that still draw the older widgets under Lantern: `/lessons/me`, `/lessons/me/notifications`, `/lessons/me/saved`, `/lessons/apply`, `/lessons/me/preacher`. `PhoneBroadcastScreen` (the camera screen) has no Lantern view either.
4. Speed work for all skins with before and after numbers (ADR-025 round 2). Nothing measured yet.
5. Android: no signed AAB is possible (`project/android/key.properties` does not exist; the owner runs `brief\launch\make_upload_key.ps1`). Still to do: emulator pass in three skins (`Pixel_5`, SDK on `D:\app\Android\Sdk`), "use my location" after the manifest change, 16 KB check, version code.
6. Proof that the old skins did not change: run `SKIN_REGRESSION_DIR=<dir> flutter test test/skin_regression_capture_test.dart` on a `master` worktree and on the branch in the same minute, then `python brief/tools/compare_skin_captures.py <before> <after>`. Emulator pairs under `brief/fable/skin_regression/`.
7. Docs: `STATUS.md`, `LEDGER.md` RESUME block, a contrast test (`test/lantern_contrast_test.dart` is named in a comment but not written).
8. `brief/fable/FINAL_REPORT.md` and the private artifact.

## 6. Waiting for the owner

- **Migration `20261111120000_content_reports.sql`** is written but was not run anywhere: Docker was not running, so not even on a local stack. Until it is applied, the Report action answers "could not be sent".
- The data export function (`20261015172851`) does not yet include the reports a person filed in `content_reports`.
- Open design questions and the defaults chosen: day is the default appearance; the arch is the signature frame; drawn reactions; labelled role chips; no new font files; no speaking signal in audio rooms; no locate button and no Now / Tonight / This week control on the map; press-and-hold for go live (from a laptop), end a broadcast, and delete account.

## 7. Tools and traps

- Quiet test runner: `FT_TAIL=200 bash ../brief/fable/scratch/ft.sh test/<file>` from `project/`. With no file it runs the whole suite (about 6 minutes). Do not edit `lib/` while it runs.
- Lantern pictures: `LANTERN_CAPTURE_DIR=<dir> flutter test test/lantern_capture_test.dart` (optional `LANTERN_CAPTURE_ONLY=map-`). The studio and the poster write theirs from `lantern_studio_test.dart` and `lantern_poster_test.dart` with the same variable.
- Strings: add `brief/tools/lantern_i18n/NN_area.json`, then `python brief/tools/merge_lantern_i18n.py` from the worktree root. Never hand-merge the catalogs.
- Write long scripts with a file, not a shell heredoc (quotes break them).
- `git add <paths>`. Never `git add brief/fable` as a whole (`shots/` holds pictures). The three `project/windows/flutter/generated_*` files are generated: do not commit them.
- `LLattice` is already a `Positioned.fill`: put it straight into a `Stack`.
- A studio test needs the fixture `test/support/studio_fixture.dart` (a signed-in broadcaster on the device that holds the broadcast); without it the studio forgets the destination on every provider update.
- `lanternToast` is a snack bar: it does not show over an open sheet. Say a failure inside the sheet.
- Machine: 15 GB of memory. One heavy job at a time (full suite, Gradle, emulator); at most two helpers that run Flutter tools.

## 8. Known risks to report to the owner

- The owner's uncommitted studio work on `master` touches `app_provider.dart` and `rtmp_ip_dialog.dart`, which this branch also changes. Commit or set that work aside before a merge.
- The "mini player" only leaves a way back; playback stops. A corner player that keeps playing is not built.
- The audio stage draws over the YouTube player (also in the old skins): a YouTube terms risk.
- `privacy.html` has no YouTube API Services statement.
- For a new Play app Google makes its own signing key by default. The owner must choose "use your own key" before the first release if he wants his own.

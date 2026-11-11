# Handoff 5: Lantern and Arch run, checks finished on 2026-11-12

The run's own work is finished. What is left needs the owner (section 3) or is listed as not built (section 4). All work is committed locally on `fable/lantern-skin`. Nothing was pushed, deployed or applied to hosted Supabase. No key or secret was created or changed.

**To continue:** start a new session, paste the owner's brief (`brief/prompts/FABLE_LANTERN_SKIN_RELEASE_PROMPT.md` in the main checkout, untracked there), then say: *read `brief/fable/HANDOFF.md` in the worktree `.claude/worktrees/fable-lantern` and continue*. The brief is the authority. This file only adds the state.

## 1. Where the work is

| Thing | Place |
|---|---|
| Work branch | `fable/lantern-skin` (from `master` `77bcff0`), 47 commits |
| Worktree | `.claude/worktrees/fable-lantern` (Flutter app in `project/`) |
| Main checkout | on `master`, holds the owner's uncommitted studio work. **Do not touch it.** |
| Report for the owner | `brief/fable/FINAL_REPORT.md` (final); the same text is the private doc https://claude.ai/artifact/GTkLmFWtF5ggWM8vnTxW5E (edit both when the report changes) |
| Build guide, decision record | `project/lib/core/widgets/lantern/README.md`, ADR-026 in `Core_files/decisions.md` |
| Play findings | `brief/fable/ANDROID_PLAY_STATUS.md` |
| Proof for the older designs | `brief/fable/skin_regression/RESULT.md` |
| Design source | main checkout, untracked: `brief/design/lantern_and_arch/source_parts/` |

Always start shell commands with an absolute `cd` to the worktree. The shell directory drifts.

## 2. State on 2026-11-12

- Full suite on the tip: 2,456 passed, 0 failed, 65 skipped (picture tests). Analyzer: 0 issues.
- Speed change committed (`perf(web)`): twelve pages load on demand. Main web script 6,913 KB → 6,433 KB (1,944 → 1,814 KB compressed); `master` is 6,259 KB (1,771 KB).
- Older designs: 36 of 38 test pictures identical to `master`; the 2 others are the phone Settings page with the new design tile (intended). On the emulator Discover, map and lessons are pixel-identical.
- Android emulator (profile build, guest): all three designs start and run; no Flutter error in the device log. Cold start, middle of 7: `master` 5.28 s, branch 5.53 s. Compiled code 19.9 MB → 22.2 MB.

## 3. Waiting for the owner

- **Migration `supabase/migrations/20261111120000_content_reports.sql`** is not applied anywhere and was not run on a local stack (Docker is not running on this machine). Until it is applied, Report answers "could not be sent".
- **Report in the older designs.** Google's reviewer sees gold & black, the default, which has no Report for a broadcast or a channel. The owner's rule forbids new features there, so it was not built. It needs his decision.
- **Merge order.** His uncommitted work on `master` touches `app_provider.dart` and `rtmp_ip_dialog.dart`; this branch changes both.
- **The signing key.** `project/android/key.properties` does not exist; the owner runs `brief\launch\make_upload_key.ps1` himself. No signed bundle exists.
- The open design questions (section 9 of the report).
- Removing the worktrees listed in section 6.

## 4. Not built, not checked

Not built: twelve admin tabs, `/org-admin`, the organization invitation page and members list, the "my lessons" pages, the preacher application and link pages, the lessons admin, viewer set-up and the phone camera screen still draw the older widgets under Lantern (restyled by the shared kit). A corner player that keeps playing. The map's locate button and Now / Tonight / This week control. A dark map for the night look. The data export does not include filed content reports.

Not checked on a device: a signed release build; sign-in, Settings, the studio, the admin page and phone broadcasting (they need an account); a live room and an audio room (no channel was live); "use my location"; memory and frame times.

## 5. Tools and traps

- Whole suite, from `project/`: `flutter test --reporter expanded 2>&1 | tr '\r' '\n' | grep -E "\[E\]$|tests passed|tests failed"` (about 6 minutes; do not edit `lib/` while it runs). Single files: `FT_TAIL=200 bash ../brief/fable/scratch/ft.sh test/<file>`.
- A page loaded on demand in `app_router.dart` must be added to `AppRouter.preloadDeferredPages()`. `test/flutter_test_config.dart` calls it before each test file; without it, the second such page a test file opens stays on its loading frame. Do not use `dart format` on `app_router.dart` (it reformats the whole file).
- Old-design proof: `bash brief/tools/skin_proof.sh "<repo>/.claude/worktrees/skin-proof-master" "<absolute output folder>"`. The output folder must be an absolute path.
- Lantern pictures: `LANTERN_CAPTURE_DIR=<dir> flutter test test/lantern_capture_test.dart` (optional `LANTERN_CAPTURE_ONLY=map-,settings-`); the studio and the poster write theirs from their own test files with the same variable.
- Strings: add `brief/tools/lantern_i18n/NN_area.json`, then `python brief/tools/merge_lantern_i18n.py` from the worktree root. Never hand-merge the catalogs.
- Write long scripts to a file, not a shell heredoc. `git add <paths>`, never `git add brief/fable` as a whole (pictures stay uncommitted). The three `project/windows/flutter/generated_*` files are generated: do not commit them.
- `LLattice` is already a `Positioned.fill`. `LNightBand` gives night colours only to widgets built with a context inside it (use a `Builder`). `lanternToast` is a snack bar and does not show over an open sheet.
- White text on the night state colours fails AA: use `LanternTokens.liveFill`, `okFill`, `audioFill` (see `test/lantern_contrast_test.dart`).
- A studio test needs `test/support/studio_fixture.dart`. Map tests depend on the time of day: never assume a single pin is on screen.
- Emulator: SDK on `D:\app\Android\Sdk`, AVD `Pixel_5`, allows `adb root`. A profile build needs no key: `flutter build apk --profile --target-platform android-x64 --dart-define-from-file=<main checkout>/project/dart_define.local.json` (never print or copy that file). The design is the string `flutter.app_skin` (`gold-black`, `hedayah-skin`, `lantern-arch`) in the app's `FlutterSharedPreferences.xml`; the language is `flutter.locale`; the Lantern look is `flutter.lantern_appearance`. Write the file with `cat new > file` so its owner stays the app. A guest cannot open Settings (it sends to the welcome page). The lessons header has a language switch in the top corner: a stray tap there flips the language.
- Machine: 15 GB of memory. One heavy job at a time.

## 6. Left on disk

Worktrees under `.claude/worktrees/`: `agent-a042ac1f6af7bfaa3`, `agent-a4b85e7d6e6275098`, `agent-a9df4d30dc21a16a3`, `agent-a4177b3f1a2a45439`, `agent-aaeda783fc87b3ff3` (helpers, all merged) and `skin-proof-master` (a clean `master` with the capture test copied in, a web build and an Android build). Removing them needs the owner's word.

On the Pixel 5 emulator the app is the branch's profile build, in gold & black, entered as a guest named "Tester". One failed command during this run emptied the app's earlier stored settings there (guest state only, no account).

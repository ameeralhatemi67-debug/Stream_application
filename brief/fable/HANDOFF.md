# Handoff 4: Lantern and Arch run, stopped on 2026-11-11 at the owner's request

The owner stopped the run because the session was near its limits. Nothing is broken. All work is committed locally on `fable/lantern-skin`. Nothing was pushed, deployed or applied to hosted Supabase. No key or secret was created or changed.

**To continue:** start a new session, paste the owner's brief (`brief/prompts/FABLE_LANTERN_SKIN_RELEASE_PROMPT.md` in the main checkout, untracked there), then say: *read `brief/fable/HANDOFF.md` in the worktree `.claude/worktrees/fable-lantern` and continue*. The brief is the authority. This file only adds the state.

## 1. Where the work is

| Thing | Place |
|---|---|
| Work branch | `fable/lantern-skin` (from `master` `77bcff0`), about 45 commits |
| Worktree | `.claude/worktrees/fable-lantern` (Flutter app in `project/`) |
| Main checkout | on `master`, holds the owner's uncommitted studio work. **Do not touch it.** |
| Report for the owner | `brief/fable/FINAL_REPORT.md`: a **draft**, see section 4 |
| Build guide, decision record | `project/lib/core/widgets/lantern/README.md`, ADR-026 in `Core_files/decisions.md` |
| Play findings | `brief/fable/ANDROID_PLAY_STATUS.md` |
| Design source | main checkout, untracked: `brief/design/lantern_and_arch/source_parts/` |

Always start shell commands with an absolute `cd` to the worktree. The shell directory drifts.

## 2. Rules that stay in force (short form)

No cost of any kind. Never push. Commit locally on `fable/lantern-skin` only. No hosted migration, no edge function deploy, no change to secrets, signing keys or store credentials. Gold & black and Hedayah must look and behave exactly as on `master`. Ask the owner before: push, deploy, hosted migration, deleting data, branches or worktrees, anything that costs money, any message to real people.

## 3. What is done and committed

Lantern views exist for: opening screen, Discover, live and audio rooms, map (pins, place cards, all controls, side panel), lessons (home, calendar, lesson, preacher, mosque, series), broadcast studio, channel page, broadcaster application and its status page, settings (with the Appearance pane), welcome and consent, notifications, saved items, role choice, suspended account, page not found, admin frame with overview, verification queue and chat reports, organization home, shows and YouTube connections. The older kits draw as Lantern pieces under Lantern (`lantern_compat.dart`).

New under Lantern only: the invitation picture for a lesson (the surprise, `lantern_poster.dart`), Report for a broadcast or a channel (live room and channel page) with a queue in the admin moderation tab, hold-to-confirm for go live, end and delete account.

All three helpers of this session (H1 settings and sign-in, H2 channel and application, H3 admin and organizations) are merged. Their worktrees still exist and are no longer needed.

## 4. Open right now: do these first, in this order

1. **Run the full suite on the branch tip.** The last full run that passed was before the admin and organization merge: 2,390 passed, 0 failed (65 skipped are picture tests). After that merge the analyzer reports 0 issues and the helper's own tests passed in its worktree (`lantern_admin_test` 35, `lantern_org_test` 31), but **no clean full run was made**. A full run that also held an uncommitted router change failed 49 tests; 30 were in `lessons_screens_test.dart` and came from that router change; the other 19 were not identified. So expect either 0 failures or a small number from the last merge.
   From `project/`: `flutter test --reporter expanded 2>&1 | tr '\r' '\n' | grep -E "\[E\]$|tests passed|tests failed"` (about 6 minutes; do not edit `lib/` while it runs).
2. **Decide the speed change** in `brief/fable/pending/defer_routes.patch` (not applied). It loads five pages on demand in `app_router.dart`: settings, broadcaster application, organization home, shows, YouTube connections. Measured on commit `53034f0`: main web script 6,846 KB (1,942 KB compressed) without it, 6,518 KB (1,854 KB) with it; `master` is 6,259 KB (1,771 KB). Apply with `git apply brief/fable/pending/defer_routes.patch` from `project/`, run the full suite, commit as `perf(web)` only if it is green. A wider version (eleven pages, adding the "my lessons" pages, the preacher pages, viewer set-up and the invitation page) broke tests: a page loaded on demand shows a spinner that never settles under `pumpAndSettle`. Do not use `dart format` on `app_router.dart` (it reformats the whole file).
3. **Repeat the old-design proof on the tip.** `bash brief/tools/skin_proof.sh "<repo>/.claude/worktrees/skin-proof-master" <output folder>`. The clean `master` copy is already prepared there. The last proof (at `a0a007a`, before the three helper merges) gave 34 of 38 identical; the 4 others were the Settings design tile (intended) and one countdown minute on the map. Put the pairs under `brief/fable/skin_regression/` (do not commit the pictures; commit `result.txt`).
4. **Finish `brief/fable/FINAL_REPORT.md`.** It is complete except these markers: `TBD-SUITE` (twice), `TBD-ANDROID`, `TBD-PROOF`, `TBD-EMULATOR-PAIRS`, `TBD-WEB`, `TBD-WEBGZ`, `TBD-ANDROID-DETAIL`, `TBD-COMMITS`. Section 5 of the report describes the eleven-page change: correct it to what is finally committed (five pages, or none). Then publish it as a private artifact for the owner.
5. **Android emulator pass** in three designs (not started). No signed bundle is possible: `project/android/key.properties` does not exist and the owner must run `brief\launch\make_upload_key.ps1` himself. A debug build can use `--dart-define-from-file` pointing at the main checkout's `project/dart_define.local.json` (never print or copy that file). Emulator `Pixel_5`, SDK on `D:\app\Android\Sdk`; it allows `adb root`, so the design can be set by writing `flutter.app_skin` in the app's shared preferences. Do not sign in with a real account.
6. Docs: a RESUME block in `brief/LEDGER.md`; `Core_files/STATUS.md` already has a Lantern section (check its wording against the final numbers); `brief/fable/PROGRESS.md` is one step behind this file.

## 5. Waiting for the owner

- **Migration `supabase/migrations/20261111120000_content_reports.sql`** is not applied anywhere and was not run on a local stack (Docker was not running). Until it is applied, Report answers "could not be sent".
- **Report in the older designs.** Google's reviewer sees gold & black, the default, which has no Report for a broadcast or a channel. The owner's rule forbids new features there, so it was not built. It needs his decision.
- **Merge order.** His uncommitted work on `master` touches `app_provider.dart` and `rtmp_ip_dialog.dart`; this branch changes both.
- The signing key (above), and the open design questions (listed in section 9 of the report).

## 6. Not built

Twelve admin tabs, `/org-admin`, the organization invitation page and members list, the "my lessons" pages, the preacher application and link pages, the lessons admin, viewer set-up and the phone camera screen still draw the older widgets under Lantern (restyled by the shared kit). A corner player that keeps playing. The map's locate button and Now / Tonight / This week control. Speed work beyond the web script size. The data export does not include filed content reports.

## 7. Tools and traps

- Quiet runner for single files: `FT_TAIL=200 bash ../brief/fable/scratch/ft.sh test/<file>` from `project/`. For the whole suite use the command in section 4, because the quiet runner cuts off failure names.
- Lantern pictures: `LANTERN_CAPTURE_DIR=<dir> flutter test test/lantern_capture_test.dart` (optional `LANTERN_CAPTURE_ONLY=map-,settings-`); the studio and the poster write theirs from their own test files with the same variable.
- Strings: add `brief/tools/lantern_i18n/NN_area.json`, then `python brief/tools/merge_lantern_i18n.py` from the worktree root. Never hand-merge the catalogs.
- To merge a helper: cherry-pick its commits; on a catalog conflict take ours, run the merge tool, `git add` the two catalogs, `git cherry-pick --continue`.
- Write long scripts to a file, not a shell heredoc. `git add <paths>`, never `git add brief/fable` as a whole. The three `project/windows/flutter/generated_*` files are generated: do not commit them.
- `LLattice` is already a `Positioned.fill`. `LNightBand` gives night colours only to widgets built with a context inside it (use a `Builder`). `lanternToast` is a snack bar and does not show over an open sheet.
- White text on the night state colours fails AA: use `LanternTokens.liveFill`, `okFill`, `audioFill` (see `test/lantern_contrast_test.dart`).
- A studio test needs `test/support/studio_fixture.dart`. Map tests depend on the time of day: never assume a single pin is on screen.
- Machine: 15 GB of memory. One heavy job at a time; at most two or three helpers that run Flutter tools.

## 8. Left on disk

Worktrees under `.claude/worktrees/`: `agent-a042ac1f6af7bfaa3`, `agent-a4b85e7d6e6275098`, `agent-a9df4d30dc21a16a3`, `agent-a4177b3f1a2a45439`, `agent-aaeda783fc87b3ff3` (helpers, all merged) and `skin-proof-master` (a clean `master` with the capture test copied in and a web build). Removing them needs the owner's word.

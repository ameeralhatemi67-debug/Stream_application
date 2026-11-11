# Lantern and Arch run: progress

Run started 2026-11-11. Brief: `brief/prompts/FABLE_LANTERN_SKIN_RELEASE_PROMPT.md` (in the main checkout, untracked).
This file is the state of the run. Update it after each step. Remove notes that no longer apply.

## Where the work is

- Branch `fable/lantern-skin`, created from `master` at `77bcff0`.
- Worktree: `.claude/worktrees/fable-lantern` (inside the repository folder). The Flutter app is in its `project/` folder.
- The main checkout stays on `master`. It holds uncommitted studio changes that are not part of this run (`app_provider.dart`, `rtmp_ip_dialog.dart`, `broadcast_publishing_controller.dart`, `channel_connections_screen.dart`, one test). Do not touch them. The owner must commit or set them aside before merging this branch.
- The design source is untracked in the main checkout, not in this worktree: `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\brief\design\lantern_and_arch\` (`source_parts/app_*` is the identity, `web_*` is the pages, `web_js_85_notes.js` is the per-page Flutter notes, `web_js_86_handoff.js` is the handoff). The live artifact was read on 2026-11-11 and is identical to this copy.
- Session scratchpad (`C:\Users\User\AppData\Local\Temp\claude\8da5e3ba19bc3b8b\7c4e59e6-37a7-48e9-a72a-26ad2b7743e0\scratchpad`): `CODE_MAP.md` (map of the existing screens), `design.html` (the prototype with the right text encoding), `design_shots.mjs` (renders prototype pages to PNG with headless Chromium), `design_shots/` and `sheets/` (rendered pages, phone and laptop), `sheet.py`, `ft.sh` (quiet test runner for this worktree).
- A local preview server config `lantern-design` (port 8771) and `lantern-web-build` (port 8796) was added to the main checkout's `.claude/launch.json`.

## Machine limits

- 15 GB RAM. Run one heavy job at a time (full test suite, Gradle build, emulator). At most two or three helpers that run Flutter tools at the same time.
- Drive C has about 31 GB free. Android SDK is on `D:\app\Android\Sdk`. Emulator: `Pixel_5` (allows `adb root`).

## Rules that must hold

- Gold & black and Hedayah skins look and behave as on `master`. The one intended change: Settings → Design gains a third tile on a second row.
- New screens and features show only under the Lantern skin. Optimizations may reach all skins.
- No push, no hosted migration, no deploy, no new cost, no keys created or printed.
- `flutter analyze` 0 issues, full `flutter test` green, `en.json` and `ar.json` key-symmetric.

## How the skin is built (decisions)

- `AppSkin.lantern` (`lantern-arch`). Gold & black stays the default.
- Every Lantern widget implements the marker `LanternSkinWidget`. `test/lantern_isolation_test.dart` proves the older designs build none.
- An existing screen keeps its logic. At the top of `build` it hands over to a Lantern view when `context.isLanternSkin`. Guide: `project/lib/core/widgets/lantern/README.md`.
- The app-wide theme under Lantern is the day theme. A Lantern screen wraps itself in `LanternSurface`, which applies night when chosen. So a screen without a Lantern layout always stays readable.
- Day is the default look. Settings will offer day, night, follow the device, and calm motion (provider fields exist: `lanternAppearance`, `lanternCalmMotion`).
- Strings: `brief/tools/lantern_i18n/*.json`, merged under the `lantern` key by `python brief/tools/merge_lantern_i18n.py`. After merging a helper's branch, run the tool again instead of resolving `en.json` or `ar.json` by hand.
- Icons: `brief/tools/lantern_icons.json` → `node brief/tools/make_lantern_icons.mjs`.
- Fonts: Readex Pro and IBM Plex Sans Arabic 400 and 700, as already shipped. No new font files.
- Release signing is not set up (`project/android/key.properties` is missing and the build refuses a release without it). No key will be created in this run. The owner runs `brief\launch\make_upload_key.ps1`.

## Plan and status

| Step | Status |
|---|---|
| 1. Read docs, skin code, design spec | done |
| 2. Branch, worktree, progress file | done |
| 3. Baseline: analyze, full tests, capture of old skins | done |
| 4. Skin foundation (tokens, theme, icons, kit, frame, isolation tests) | done, commit `d64f8c5` |
| 5a. Opening screen | done, commit `b8c8aae` |
| 5a. Discover | done, commit `093b900` |
| 5a. Live and audio rooms (full screen) | in progress (main session): `lib/features/live_stream/presentation/lantern/` (`lantern_room_view.dart` written; stage and chat files next; then the hook `_buildLantern` in `live_broadcast_screen.dart`, strings in `12_room.json`, tests, capture) |
| 5a. Map (label-aware grouping, new place cards) | pending (main session) |
| 5b. Lessons home, calendar, lesson, preacher, mosque, application | helper running |
| 5c. Shared kits (`Ca*`, `Hidayah*`, `T*`) draw as Lantern under the Lantern skin | helper running |
| 6. Settings, notifications, bookmarks, welcome, states and 404 | pending |
| 7. Channel, studio, broadcaster application, admin hub, organization hub | pending |
| 8. Optimizations with before and after numbers | pending |
| 9. Play requirements check | done by helper, merged (`c1c2635`..`9761a7e`); status in `brief/fable/ANDROID_PLAY_STATUS.md` |
| 9. Release build, emulator pass in three skins | pending |
| 10. Proof that old skins did not change | pending (method below) |
| 11. Final report and artifact | pending |

## Helpers started (each in its own worktree and branch; merge by cherry-pick, then re-run the i18n tool, analyzer and tests)

- Shared kits under Lantern (Opus). Files: `lib/core/widgets/ds/*`, web kit and header, lessons kit and icons, new `lantern_compat.dart`.
- Lessons screens (Opus). Files: `lib/features/lessons/presentation/lantern/*`, hooks in the lessons screens and `lessons_shell.dart`, strings in `20_lessons.json`.
- Android and Play (Opus). Files: `project/android/**`, `store/**`, `project/web/delete-account.html`, `brief/launch/*`, writes `brief/fable/ANDROID_PLAY_STATUS.md`.

## Findings to act on or report

- Play (from the helper's check, 2026-11-11): only chat messages can be reported today. Google's user-content rule asks for reporting of content and users. A Report action is needed on the live room, channel and profile. It is planned for the Lantern rooms and channel page; for the two older designs it changes a screen, so prepare it as a separate commit the owner can choose to apply, and say so in the report.
- The helper turned Android backup off (session token was copied to backups) and removed geolocator's unused location foreground service from the merged manifest. Test "use my location" on the emulator.
- The existing "mini player" is a shortcut pill, and playback stops when the room closes (`live.minimize_tooltip`). A corner player that keeps playing needs its own player in the frame; YouTube's rules ask for a player of at least 200 by 200 px and nothing drawn over it.
- A reconnect of a phone broadcast with the screen locked may fail (the foreground service stops on disconnect). Needs a phone test.
- `privacy.html` does not name YouTube API Services. Version code for the first Play upload must be above every shared APK.

## Numbers measured

- Baseline on `master` (2026-11-11): analyzer 1 note (an unused import in a test, now removed); tests 1,886 passed, 12 skipped, 0 failed, 5 min 24 s.
- After the foundation: analyzer 0. New tests: `lantern_skin_test.dart` 23, `lantern_isolation_test.dart` 10, `lantern_discover_test.dart` 23, `lantern_opening_test.dart` 12. The full suite has not been re-run since the baseline.
- Pictures of Lantern screens: `LANTERN_CAPTURE_DIR=<dir> flutter test test/lantern_capture_test.dart` (optional `LANTERN_CAPTURE_ONLY=name-part`). Output so far in `brief/fable/shots/` (not committed).

## Proof that the old skins did not change

- `test/skin_regression_capture_test.dart` writes 38 pictures (19 screens × 2 skins) when `SKIN_REGRESSION_DIR` is set. `brief/tools/compare_skin_captures.py <before> <after>` compares them.
- A baseline from the untouched code is in `brief/fable/skin_regression/captures/before` (not committed yet).
- Lesson and map pictures show countdowns, so they change with the clock. For the final proof, run the capture on a checkout of `master` and on the branch at the same minute.
- After the foundation: 34 of 38 identical; `14-settings-phone-*` differ as intended (third tile); `10-map-laptop-*` differ only in countdown text.

## Android and Play facts (from the launch documents, 2026-11-11)

- AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, compileSdk 36, targetSdk 36, minSdk 24, NDK 28.2. Version `1.0.0+1`.
- Manifest permissions: INTERNET, ACCESS_NETWORK_STATE, CAMERA, RECORD_AUDIO, FOREGROUND_SERVICE, FOREGROUND_SERVICE_CAMERA, FOREGROUND_SERVICE_MICROPHONE, POST_NOTIFICATIONS, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION. One service: `RtmpForegroundService` (camera|microphone, not exported).
- Build commands (from `project/`): Play bundle `flutter build appbundle --release --dart-define-from-file=dart_define.local.json --dart-define=DISTRIBUTION=play`; website APK the same with `apk` and `DISTRIBUTION=apk`. Secret scan: `node brief/tools/scan_build_secrets.mjs <file>`.
- Open in `brief/launch/03_CLAUDE_REMAINING_WORK.md`: version bump, AAB build, secret scan, 16 KB check inside the AAB, bundletool smoke test, gates G2d, G3, G11a, clean `hs_err_pid*.log`.
- The web deletion page `project/web/delete-account.html` only opens an email. Play wants a working request path.
- Store drafts exist in `store/` (data safety, listing, permissions and foreground service declaration, reviewer access, moderation evidence).

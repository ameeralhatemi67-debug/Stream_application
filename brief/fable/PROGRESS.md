# Lantern and Arch run: progress

Run started 2026-11-11. Brief: `brief/prompts/FABLE_LANTERN_SKIN_RELEASE_PROMPT.md` (in the main checkout, untracked).
This file is the state of the run. Update it after each step. Remove notes that no longer apply.

## Where the work is

- Branch `fable/lantern-skin`, created from `master` at `77bcff0`.
- Worktree: `.claude/worktrees/fable-lantern` (inside the repository folder). The Flutter app is in its `project/` folder.
- The main checkout stays on `master`. It holds uncommitted studio changes that are not part of this run (`app_provider.dart`, `rtmp_ip_dialog.dart`, `broadcast_publishing_controller.dart`, `channel_connections_screen.dart`, one test). Do not touch them. The owner must commit or set them aside before merging this branch.
- The design source is untracked in the main checkout, not in this worktree: `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\brief\design\lantern_and_arch\` (`source_parts/app_*` is the identity, `web_*` is the pages, `web_js_85_notes.js` is the per-page Flutter notes, `web_js_86_handoff.js` is the handoff).
- Code map of the existing screens (written by a helper): scratchpad `CODE_MAP.md`.

## Machine limits

- 15 GB RAM, about 2 GB free at start. Run one heavy job at a time (full test suite, Gradle build, emulator). At most two helpers that run tools at the same time.
- Drive C has about 31 GB free. Android SDK is on `D:\app\Android\Sdk`. Emulator: `Pixel_5` (allows `adb root`).

## Rules that must hold

- Gold & black and Hedayah skins look and behave as on `master`. Only Settings → Design gains a third tile.
- New screens and features show only under the Lantern skin. Optimizations may reach all skins.
- No push, no hosted migration, no deploy, no new cost, no keys created or printed.
- `flutter analyze` 0 issues, full `flutter test` green, `en.json` and `ar.json` key-symmetric.

## Plan and status

| Step | Status |
|---|---|
| 1. Read docs, skin code, design spec | done |
| 2. Branch, worktree, progress file | done |
| 3. Baseline: analyze, full tests, capture of old skins | in progress |
| 4. Skin foundation (tokens, theme, icons, kit, shell, skin switch, isolation tests) | next |
| 5. Screens: opening screen, Discover, live and audio rooms, map, lessons | pending |
| 6. Screens: settings, notifications, bookmarks, welcome, states and 404 | pending |
| 7. Screens: channel, studio, application, admin hub, organization hub | pending |
| 8. Optimizations with before and after numbers | pending |
| 9. Play requirements check, release build, emulator pass in three skins | pending |
| 10. Proof that old skins did not change | pending |
| 11. Final report and artifact | pending |

## Decisions taken

- Work in a separate worktree so the uncommitted studio changes in the main checkout stay untouched.
- Release signing is not set up (`project/android/key.properties` is missing and the build refuses a release without it). No key will be created in this run. The owner runs `brief\launch\make_upload_key.ps1`.

## Numbers measured

(none yet)

## Android and Play facts (from the launch documents, 2026-11-11)

- AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, compileSdk 36, targetSdk 36, minSdk 24, NDK 28.2. Version `1.0.0+1`.
- Manifest permissions: INTERNET, ACCESS_NETWORK_STATE, CAMERA, RECORD_AUDIO, FOREGROUND_SERVICE, FOREGROUND_SERVICE_CAMERA, FOREGROUND_SERVICE_MICROPHONE, POST_NOTIFICATIONS, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION. One service: `RtmpForegroundService` (camera|microphone, not exported).
- Build commands (from `project/`): Play bundle `flutter build appbundle --release --dart-define-from-file=dart_define.local.json --dart-define=DISTRIBUTION=play`; website APK the same with `apk` and `DISTRIBUTION=apk`. Secret scan: `node brief/tools/scan_build_secrets.mjs <file>`.
- Open in `brief/launch/03_CLAUDE_REMAINING_WORK.md`: version bump, AAB build, secret scan, 16 KB check inside the AAB, bundletool smoke test, gates G2d, G3, G11a, clean `hs_err_pid*.log`.
- The web deletion page `project/web/delete-account.html` only opens an email. Play wants a working request path.
- `doc/Audit/07_Platform_Build_Readiness.md` is stale (old application id, old signing fallback). `proguard-rules.pro` still keeps VLC classes that are no longer a dependency.
- Store drafts exist in `store/` (data safety, listing, permissions and foreground service declaration, reviewer access, moderation evidence).
- Closed test rule in the documents: 12 testers opted in for 14 days in a row for personal accounts opened after 2023-11-13. Check the current rule on Google's page before relying on it.

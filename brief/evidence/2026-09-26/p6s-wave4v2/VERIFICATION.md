# Verification

Reviewed-source candidate: `5162addcc8a659d3c66dafde3f243565cc85acf7` on `codex/p6s-wave4v2-repair`, based on `7b54cb5e565011c33dcd03351735b7cc45a0926a`. Date 2026-09-26. This table records completed available checks and their limits. Physical E4 is NOT RUN.

Flutter/Dart commands run only from this worktree's `project/`, using `C:/Users/User/sru/flutter/bin/flutter.bat` (Flutter3.41.2/Dart3.11.0). Node22.19.0, Supabase CLI2.115.0; Android SDK actually used by Gradle is `D:/app/Android/Sdk`, API36, RootEncoder2.7.5. No dependency upgrade; pubspec.lock unchanged.

| Check / exact command | Actual outcome | Evidence |
|---|---|---|
| `flutter analyze --no-pub` | 0 issues, 13.9s | analyze-final.txt |
| `flutter test --no-pub --concurrency=1 --reporter=expanded` | 722 passed, 5m17s | full-tests-final.txt |
| `flutter test --no-pub test/wave4v2_recovery_and_channel_test.dart test/p6s_wave3_group5_test.dart test/phone_broadcast_engine_test.dart --concurrency=1 --reporter=expanded` | 54 passed | recovery-final.txt |
| `node brief/tools/gates.mjs --json` from root | 26 PASS, 5 INFO, 0 FAIL | gates-final.json |
| `supabase test db --workdir brief/.runtime/wave4v2 --local` from root | 21 files / 440 assertions PASS, new disposable stack | sql-candidate.txt |
| `flutter build apk --debug --no-pub` during integrated implementation | Kotlin/Android compile PASS; original package artifact, not for installation | build-native-resume.txt |
| `flutter build apk --debug --no-pub -t tool/wave4v2_native_probe.dart` | compile PASS, but environment-only test property did not change packaged ID; rejected as candidate | build-native-probe.txt |
| Explicit `--android-project-arg=wave4v2TestApp=true` native-probe build | PASS, test ID/label verified; installed only on fresh private AVD | build-native-probe-isolated.txt |
| Local no-key app APK + web | PASS (48.4s APK,96.0s web), diagnostic only | build-apk-final.txt, build-web-final.txt, apk-identity.txt, identity.json |
| Native emulator / real Chrome scenarios | Executed with limits; no physical acceptance implied | NATIVE_PROBE.md / BROWSER_PROBE.md |
| Real phones, OBS, real YouTube ingest/15-minute AV, TalkBack, real IME | NOT RUN | owner results remain blank |

No new migrations. `Streamer_wave4v2` is a new local-only stack with API `127.0.0.1:55921`, DB55922, container `supabase_db_Streamer_wave4v2`; preparation source is `brief/tools/prepare_wave4v2.ps1` and local-stack.toml. It copied the full committed migration chain, no linked metadata or production define file. Raw CLI credential output stays in ignored `brief/.runtime/wave4v2`. Google OAuth and a test YouTube API/ingest key are not provisioned, so the no-key build is diagnostic, not an end-to-end test candidate.

Current tests use mock native events/service clients where stated. The SQL suite exercises real local PostgreSQL policies/functions. A successful APK compile does not establish orientation, audible playback or recovery on hardware. Existing generated Windows plugin files have no semantic diff and are excluded from commits.

## Failed/intermediate runs

- G1 before-fix regression failed as expected on baseline (g1-before.txt); 43 targeted End tests then passed (targeted.txt).
- Original partial slice full suite had698pass/1 outdated ended-versus-uncertain expectation. That assertion was corrected, retaining disposal checks; the later716 and final722 suites supersede it.
- Resumed targeted runs exposed test-event envelopes, a fixture timer cleanup and changed mode/strict-parser expectations. Separate tests keep fail-closed no-live-write and disabled-mode assertions. A viewer toggle tap failed because the status row covered it; source hit regions were corrected and the regression passes.
- A preliminary full run was interrupted at a new fixture awaiting the second coalesced catalog request. The fixture now completes that request explicitly. This was not counted as a pass. Logs remain in full-tests-resume.txt and targeted-resume2.txt.
- Initial lint8 infos were corrected with the standard brace fix. The final analyzer result above is0.
- Initial environment-only package flag was not accepted as evidence of isolation; packaged APK inspection detected the original ID before installation. The reproducible invocation must pass the explicit Gradle property and verify the manifest.

## Limits and preserved state

G10 INFO rows retain the existing reviewed deny-all tables and anonymous public helper grants. G11 history and signed-release-artifact scans are not claimed. Build warnings and mock plugin warnings are distinct from test failures. Main/Opus checkouts, installed owner apps, stashes and historical Wave4 evidence are protected; STARTING_STATE.json is the baseline and PRESERVATION_CHECK.json records the final comparison.

The previous budget stop remains recorded in critic round1. The user explicitly authorized this continuation until four scores reach8 or three rounds are exhausted; no meter file was edited. The owner explicitly retained D8 as a release blocker.

## Final repair checks

Source `5162add`:70 focused tests passed in `round3-targeted-final.txt`; final analyzer0 and full722 above. The first focused run found a remaining original reconnect banner; its removal fixed the duplicate. The landscape Leave assertion was scoped to the recovery panel because the persistent exit also legitimately says Leave. The new channel test submits the actual sheet and verifies canonical stored identity. Three delayed-state tests prevent retries from reloading confirmed live/paused or unconfirmed native-control fallback.

Real Chrome version153.0.8010.54, actual native iframe Play/Pause, changed-ID error, remount and truthful unconfirmed label observed (BROWSER_PROBE.md). No measured audio/live broadcast or room-network recovery from that probe. Native source remains c292db3 (unchanged in5162add): receiver1280x720 H264/AAC,37.603s,48frames; System UI ANR. Resource shutdown observed, smooth/native/physical acceptance not established.

The old empty repair-worktree Git index.lock (19+ minutes old) was removed only after verifying the exact worktree metadata and absence of active Git processes. No source, checkout, stash or owner lock was removed. Read-only final preservation comparison confirms master7b54cb5 and all54 protected file hashes unchanged; both original stash hashes retained.

## Reproducible diagnostic artifacts

All app artifacts below contain source `5162addcc8a659d3c66dafde3f243565cc85acf7`; native-probe artifacts retain their separately recorded c292 source. Exact configuration, source, migration, lock and complete web file hashes are in identity.json. Local stack is stopped with backup; local-stop.txt confirms the exact project filter. No APK was installed on owner hardware. Web build emitted an inherited missing CupertinoIcons font-family warning; compilation and wasm dry run succeeded. This is not a visual icon audit.

| Artifact/config | SHA256 |
|---|---|
| `project/pubspec.lock` | `26b890254de0a91cc3f5487fdd8bdedf0cd0b7b6371ff81dd9db898d04721a4d` |
| `brief/.runtime/wave4v2/defines.no-key.json` | `e4b485f2caf7f1b9a0ed6231530543e53c4839a5e17ad8ca5863f25854ee6512` |
| `brief/.runtime/wave4v2/supabase/config.toml` | `c8d04b3f074040e0c5b7d392b48d8d125dea957d4654905d8ebc17020587cdbb` |
| `brief/.runtime/wave4v2/streamer-wave4v2-5162add-no-key.apk` | `171a0692efe65deb688f70e5670d49787e1ca580c185f88cf8ded241766dfd13` |
| `brief/.runtime/wave4v2/streamer-wave4v2-5162add-web-no-key.zip` | `492ad344b700058a631b06539d6073607a3712b58a8e5d0760ff782cda4250b6` |
| `project/build/web/main.dart.js` | `4ddbdb04e4da1a4a1ea8544c77db38fac0ca483da94d13192a02fa0855cab1d2` |
| `project/build/web/index.html` | `b2bb8407e0f7d697c16afde2191442157cc57e9e89ba536289737c72fb9dc8c2` |
| `brief/.runtime/wave4v2/native-probe.apk` | `18a88f8fc9c41b9a5b59ee56b314f86ed46e144ba34577e387932816195dcaad` |
| `brief/.runtime/wave4v2/native-received.mkv` | `07d27674a569cd1bc02bb57a96e3b6eb84ec6e8aed033935e18a7b0eb5d2b7f6` |

# Verification — camera follow-up

Source identity: `ddcb52178e126894e1b456aa06516a3d789cdac0`. Branch `codex/p6s-wave4v2-repair`. Commands ran from this worktree's `project/`, except gates from the repository root. No library, SQL, map or provider source changed in this follow-up.

| Check | Final result | Evidence / limit |
|---|---|---|
| Java camera geometry | PASS: 16 rotation combinations, 6 exact rectangles, 50 aspect/fit cases, invalid dimensions | `geometry.log`; real cameras still required |
| `flutter analyze --no-pub` | 0 issues | `analyze-final.log` |
| `flutter test --no-pub --concurrency=1 --reporter expanded` | 730 PASS (5m06s) | `flutter-test-final.log`; plugin/backend mocks are not hardware evidence |
| `node brief/tools/gates.mjs --json` | 26 PASS, 5 INFO, 0 FAIL | `gates.json`; no history scan or signed-release-artifact audit claimed |
| Isolated Android debug application | PASS (31.2 s) | `build-apk.log`, manifest identity and APK hash in identity.json |
| Web application | PASS (88.6 s); inherited CupertinoIcons font warning | `build-web.log`, archive hash in identity.json |
| Native local receiver | Limited rendering/lifecycle evidence, not native UX/performance acceptance | [NATIVE_PROBE](NATIVE_PROBE.md); 484 frames, 9.91 delivered fps, unresolved System UI ANR |
| SQL | Not rerun; no SQL changes or backend operation | September 26's 21 files / 440 assertions remain inherited evidence only |
| Physical phones / real YouTube / OBS | NOT RUN | Fresh results file; no historical PASS carried over |
| Independent critic | No review of this follow-up | Prior three-round allowance exhausted; old 8/7/7/7 does not apply |

Geometry reproduction (JDK 17+):

```powershell
javac -d ../brief/.runtime/camera-landscape android/app/src/main/java/sa/hadayah/streamer_app/streaming/CameraFraming.java tool/CameraFramingCheck.java
java -ea -cp ../brief/.runtime/camera-landscape CameraFramingCheck
```

Build commands, using the existing ignored local no-key diagnostic file (never the owner's production defines):

```powershell
$env:GRADLE_OPTS='-Dorg.gradle.workers.max=2 -Dorg.gradle.jvmargs=-Xmx3g'
flutter build apk --debug --no-pub --android-project-arg=wave4v2TestApp=true --dart-define-from-file=../brief/.runtime/wave4v2/defines.no-key.json
flutter build web --no-pub --dart-define-from-file=../brief/.runtime/wave4v2/defines.no-key.json
```

The tests exercise the shared edit/studio entry paths as well as chat composers, native preview tap routing, three sender controls and End placement, focus preservation, orientation unlock on entry, front-switch refusal without native restart, late settings completion after disposal, large text in en/ar, and unconfirmed viewer-toggle hit testing. Existing full-suite checks retain End/recovery/session/account/chat/provider regressions. Real AndroidView rendering and IME behavior need the physical script.

Earlier focused runs exposed and fixed a disposed edit-controller race, a stale orientation lock, an incomplete platform-view resize test mock, and a nested-list test matcher. Earlier native compilation alone missed Java packaging, and the first received-video probe exposed virtual-display rotation. Failed evidence is retained; only final-source logs are claimed here. No source changes are intended after the recorded final checks.

P6/P6S remain open. D8 remains HIGH and release-blocking; camera/background/resource limitations and mode/platform exclusions remain explicit. This pack supplies a reproducible source and diagnostic build, not provisioned end-to-end credentials or physical acceptance.

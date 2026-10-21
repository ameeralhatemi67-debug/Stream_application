# Manual Codemagic compile gates

2026-10-18, W22; toolchain pins updated 2026-10-21. Configuration and fake-tool
tests only. Neither workflow has run on macOS; no E2 claim exists. No paid Apple
enrollment is required for an unsigned compile. Once the Mac arrives, prefer
MAC_SETUP.md for device work.

## Click-by-click, viewer first

1. Review and push the intended local commit yourself. Codex never pushes.
2. Sign in to Codemagic. Open **Applications > Add application**, choose your
   Git provider and this repository, then choose **Flutter App** / YAML
   configuration when asked. For an already-connected app, open it from
   Applications. Confirm current machine availability and billing before a run.
3. Open the app, click **Start new build**, select branch **master** and
   configuration **codemagic.yaml**. Choose workflow **ios-compile-check**
   (display name **iOS viewer unsigned compile check**), then **Start new build**.
   Labels can vary slightly with Codemagic's UI version. There are no automatic
   triggers, so a push alone starts neither workflow.
4. Expand **Viewer checks and unsigned compile**. The working directory is
   `project`, Flutter is pinned to **3.41.9**, Xcode is pinned to **26.6** (see
   "Toolchain pins" below) and CocoaPods uses the image default. The script
   prints versions and rejects any Xcode or iOS SDK major below 26 before
   resolving dependencies.
5. This run resolves Flutter packages, runs `pod install`, analyzer and all
   tests, then `flutter build ios --release --no-codesign
   --dart-define-from-file=dart_define.example.json`. The publisher stays off.
6. Download the build/ci-logs/*.log artifacts. ios-clean must exit 0 for the
   targeted viewer files: Runner Info.plist, EN/AR InfoPlist.strings, entitlements,
   PrivacyInfo.xcprivacy and Podfile. publisher-project must find no
   A117000000000000000000, HaishinKit, Logboard, PublisherStrings,
   PublisherPrivacy or Info-Publisher in the pbxproj. publisher-flag must
   confirm Publisher.generated.xcconfig is absent. ios-diff-stat is
   informational; the first pod install may change the tracked project and
   workspace. Keep the commit SHA, run URL/date, actual versions, analyzer count,
   test counts, build exit and cleanup result. A .app artifact is unsigned.

## Experimental publisher, separate manual run

1. After reviewing the viewer result, return to **Start new build** for the same
   application and commit. Choose **ios-publisher-compile-check** (display name
   **iOS experimental publisher unsigned compile check**) and start it manually.
2. Expand **Enable publisher, compile and restore viewer**. The script runs
   `python3 ios/Publisher/configure.py --enable`, then `cd ios && pod install`,
   then `flutter build ios --release --no-codesign
   --dart-define-from-file=dart_define.example.json
   --dart-define=IOS_PHONE_PUBLISHING=true`.
3. The EXIT trap runs `configure.py --disable`, even after a failed compile,
   then runs the three targeted isolation checks described above and prints
   git diff --stat -- ios/ for information. Failed cleanup fails the
   workflow. Flutter plugins stay on CocoaPods; publisher packages use the
   existing opt-in Runner SwiftPM configuration.
4. Retain **enable**, **pods**, **build**, **disable**, **ios-clean**,
   **publisher-project**, **publisher-flag** and **ios-diff-stat** logs.
   This is a compile probe; it does not authorize a publisher release or prove
   capture, interruption recovery, background behavior or Apple authentication.

After the first successful viewer pod install on the Mac, review and commit
project/ios/Runner.xcodeproj/project.pbxproj and
project/ios/Runner.xcworkspace/contents.xcworkspacedata by explicit path, as in
MAC_SETUP.md. No Mac output is available for the Windows builder to commit.
The markerless cleanup fixtures are host simulations, not a CocoaPods/Xcode pass.
An unsuccessful build keeps its own exit code; cleanup failure changes success
to failure.

## Toolchain pins

Both workflows pin `flutter: 3.41.9` and `xcode: 26.6`; change them together.

- **Flutter 3.41.9** is the newest hotfix on the project's 3.41 line (checked
  against Flutter's CHANGELOG on 2026-10-21). Over 3.41.2 it adds iOS fixes for
  Xcode 26 simulator builds when a CocoaPod lacks arm support (3.41.4),
  physical-iPhone debug crashes with Xcode 26.4+ (3.41.7), a git
  multi-pack-index build failure (3.41.7) and profile-mode VM connection on
  devices (3.41.8). The same SDK builds Android/Play and web; 3.41.6 also
  fixes an Android 16 ANR.
- **Xcode 26.6** is Codemagic's default image (macOS 26.5.1, iOS 26.5 SDK) on
  the Mac mini M2. It meets Apple's upload rule: Xcode 26+ with an iOS 26+ SDK
  since April 28, 2026. Codemagic resolves `26.6` to that version's newest
  patch.
- **Why not `latest`:** Codemagic's `latest` follows the newest release Xcode
  and switches to a new major (Xcode 27 is already offered) on a date Codemagic
  announces. Xcode 27 is newer than Flutter 3.41. Flutter fixed an Xcode 27
  build failure (lipo verification) in 3.44.8, and no 3.41 hotfix carries that
  fix. A first compile on `latest` could fail for toolchain reasons instead of
  on the app's own native errors, which W13 needs to see.
- **Keep the guard.** ci_compile.sh still rejects any Xcode or iOS SDK major
  below 26, so a later edit cannot quietly drop under Apple's floor.

Move to Xcode 27 only together with a reviewed Flutter upgrade to a release
whose CHANGELOG covers Xcode 27: 3.44.8 or later; 3.47.4/3.47.5 add Xcode 27
and iOS 27 debug fixes. Plan that upgrade as soon as Apple announces an Xcode
27/iOS 27 SDK upload requirement: Codemagic schedules an Xcode version for
removal once App Store Connect stops accepting it, and announces the timeline
first. When the pins move, update both workflows, MAC_SETUP.md and
IOS_STATUS.md in one change. Flutter
3.44 changes the default iOS dependency manager to SwiftPM; the project's
pubspec already opts out, but that upgrade still needs its own review.

## When either run fails, paste this back to Claude

Both workflows invoke `ios/Publisher/ci_compile.sh`. A failing command prints up
to 150 lines, starting 30 lines before its first matching error (or the start
of the log). Download the full command log if the excerpt is inconclusive.
Do not repeatedly run the same failing source without a fix.

```text
Workflow / commit SHA:
Run URL / date:
Flutter / Dart / Xcode / iOS SDK / CocoaPods:
Failed command + exit:
First actual error and the printed 150-line context:
Analyzer and test passed / failed / skipped counts, if reached:
Publisher enable / disable / ios-clean results, if reached:
Full log artifact name:
```

Use only `dart_define.example.json`. Do not upload the local define file or add
signing integrations, certificates, profiles, Apple keys, secrets or publishing.
Review logs before sharing. Compile success can later support E2 only when a
real run and its logs exist; it proves no Simulator/iPhone behavior. W13 fixes
the first actual native error class, following the plan's iteration limits.

Sources checked through Context7: [software versions](https://docs.codemagic.io/codemagic-yaml-cheatsheet.html),
[working directory](https://docs.codemagic.io/yaml/yaml-getting-started),
[manual builds and triggers](https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically),
[Xcode update/deprecation policy](https://docs.codemagic.io/specs/xcode-update-policy).
Machine list checked 2026-10-21 (page dated 2026-09-06):
[Xcode 26.6 image](https://docs.codemagic.io/specs-macos/xcode-26-6/).
Apple has required Xcode 26+ with an iOS 26+ SDK for uploads since April 28, 2026:
[SDK minimum](https://developer.apple.com/news/upcoming-requirements/?id=04282026a);
Xcode 26.6 needs macOS Tahoe 26.2+ and ships the iOS 26.5 SDK:
[Xcode support table](https://developer.apple.com/support/xcode/).
Flutter hotfixes: [CHANGELOG](https://github.com/flutter/flutter/blob/stable/CHANGELOG.md).
The pin plus the explicit version check keeps that minimum; the logs still
record the actual image versions, which no run has observed yet.

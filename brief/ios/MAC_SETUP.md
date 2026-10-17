# Mac setup and first iOS run

Written on Windows, 2026-10-17. These commands have not been run on a Mac. Native evidence remains E0 until actual builds/runs. Use this runbook when the Mac is in the repo's reach; skip Codemagic then. Keep the existing viewer scope and paid-enrollment deferral (D4).

## 1. Owner: prepare the Mac and tools

Check the machine in Terminal:

```sh
uname -m
sw_vers
```

Apple's current upload requirement is Xcode 26+ with an iOS 26+ SDK (in force since April 28, 2026). The app's deployment target stays iOS 15.0; SDK and deployment target are different settings.

As of this source check, Apple's table lists stable Xcode 27.1 requiring macOS Tahoe 26.6+, with iOS 27.1 SDK and iOS 17+ device/simulator support. Install the current stable Xcode supported by the Mac that meets the upload requirement. If the Mac cannot run that version, Xcode 26.3 is listed for macOS 15.6+ with iOS 26.2 SDK and meets today's requirement. Recheck both Apple pages when the laptop arrives; do not assume a beta is required. The pinned Flutter 3.41.2/new-Xcode combination is not yet compiled.

Owner installs Xcode from Apple's official distribution, opens it once and completes component/license prompts. For an older compatible Xcode, use Apple's developer downloads with the owner's account. No account identifiers, signing keys or passwords go into the repository or chat.

Configure command-line tools (change the application path only if Xcode has another name/location):

```sh
xcode-select --install
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license
xcodebuild -downloadPlatform iOS
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
```

The owner reviews/accepts licenses and enters any system password locally. If command-line tools are already installed, the first command may say so; verify the selected full Xcode rather than reinstalling blindly.

Install Homebrew using the current official installer from brew.sh. Its documented command is:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow its printed shellenv/PATH instructions for this architecture (normally /opt/homebrew on Apple Silicon, /usr/local on Intel). Use a native-architecture Terminal. Then:

```sh
brew --version
brew --prefix
brew install cocoapods
pod --version
```

This repo deliberately uses CocoaPods with Flutter 3.41.2. Newer Flutter documentation may describe SwiftPM as default; do not upgrade Flutter or globally switch its package manager to make a build pass. Intel Homebrew support differs from Apple Silicon; use the installer/support page for the actual machine and record any genuine blocker.

## 2. Owner: Flutter 3.41.2 and repository

Download **stable Flutter 3.41.2** for the Mac's actual architecture from the official SDK archive. Extract its flutter folder into a new SDK directory, for example `$HOME/development/flutter-3.41.2` (that directory must contain bin/flutter). Do not copy Windows SDK binaries or caches and do not overwrite an existing SDK.

Set the path in this Terminal; add the same line to the owner's normal shell profile for future terminals:

```sh
export PATH="$HOME/development/flutter-3.41.2/bin:$PATH"
```

Before cloning, the owner pushes the intended local master commits. Also review/commit the manager-authored plan/prompt and pending manager ledger changes: some were untracked/unstaged in the Windows workspace and are not included automatically in builder commits. The Mac must receive IOS_PLAN_V2.md and the current decisions, not only app source. Do not include secrets or unrelated launch work in that push.

Use the owner's normal Git credential flow and a repository URL without embedded tokens:

```sh
mkdir -p "$HOME/development"
git clone 'OWNER_REPOSITORY_URL' "$HOME/development/Streamer_app"
cd "$HOME/development/Streamer_app"
git switch master
git status --short
git log -5 --oneline
```

If the repository already exists, use that checkout and inspect its state; do not reset, clean, overwrite or create another branch. Read the repository's required instructions and iOS plan/status/ledger before changes. The app is in project/; all Flutter/Dart commands below run there.

Owner copies dart_define.local.json **by hand** into project/ from their secure local source. Keep it ignored and do not open/print/stage it. M1 compiles without it; M2 passes its path to Flutter for real backend configuration. Do not copy signing material, Windows .dart_tool/build, Pods or caches into the repo.

## 3. Owner: install Codex and sign-in setup

Use the current official OpenAI desktop quickstart and its macOS download. Install/open the desktop app, sign in with the owner's ChatGPT account, select Codex for software work and open the cloned **repository root**, so AGENTS.md and the iOS mailbox are in scope. The current guide describes the ChatGPT desktop app with a Codex selection. If that installer is unavailable for the machine, follow the official Codex CLI guide; do not guess platform support or install a different product.

Resume the iOS builder with IOS_STATUS.md and IOS_PROGRESS.md. There is no usage cap or soft stop. Never run budget_check.mjs, push, edit supabase, inspect secrets/signing material or disturb brief/launch. Use local master commits and continue unblocked work; the ledger is the auditor mailbox.

In Xcode > Settings > Accounts, the owner signs in locally with their Apple account. A free personal team is sufficient for a cable Debug install; Simulator and unsigned compilation need no paid enrollment. Keep paid enrollment deferred. Never add Sign in with Apple, Associated Domains or APNs capabilities to Debug.

## 4. M1 — exact first build commands

From the cloned repository:

```sh
cd "$HOME/development/Streamer_app/project"
flutter --version
flutter doctor -v
flutter precache --ios
flutter pub get
flutter analyze
flutter test
```

Confirm Flutter is exactly 3.41.2. iOS-related doctor checks must be clean. An unused Android/desktop toolchain is not a prerequisite; do not disable checks or suppress warnings. Record actual versions/results. Native package failures follow W13, not a silent SDK upgrade/plugin removal.

Inspect only the non-secret settings relevant to the contract; do not dump all build settings or defines:

```sh
set -o pipefail
xcodebuild -project ios/Runner.xcodeproj -target Runner -configuration Debug -showBuildSettings |
  sed -nE '/^[[:space:]]*(CODE_SIGN_ENTITLEMENTS|PRODUCT_BUNDLE_IDENTIFIER|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY)[[:space:]]*=/p'
```

Expected: bundle sa.hadayah.streamerapp, deployment target 15.0, device family 1; Debug CODE_SIGN_ENTITLEMENTS absent/empty. Release/Profile alone reference Runner/Runner.entitlements. If Debug inherits a paid entitlement, fix that configuration before a free-team build.

Then run the plan's two native compile gates:

```sh
flutter build ios --simulator
flutter build ios --release --no-codesign
```

In the pinned Flutter source, the simulator command defaults to Debug. Neither command proves launch or playback. Record SHA/date, Xcode/SDK/Flutter/CocoaPods, exact command, exit status and sanitized first error. Success is E2 only. Keep useful native warnings in evidence.

For a failure, fix the first real error class, commit the explicit allowed paths, update the mailbox and rerun. First suspect remains path_provider_foundation/objective_c native assets. Stop/escalate after the same error class three times or six iterations without a new class. Do not remove plugins, suppress warnings, change backend or guess a signing workaround.

Before/after tooling, verify tracked Android/web diffs are empty and compare a fresh Mac SHA-256 inventory of their source files. Exclude keys, keystores, local defines and signing material; do not hash protected files. Windows absolute-path inventories are not portable. Record generated ignored files separately rather than mixing them into source proof. Do not commit generated caches or signing settings.

## 5. M2 — launch the real iOS app

Install an available iOS 17/18 simulator runtime in Xcode's Components settings when supported, plus an available small-screen iPhone. Also test the current runtime where practical. If a requested older runtime is unavailable, record that gap and test available rows; do not label an unrun runtime passed.

```sh
cd "$HOME/development/Streamer_app/project"
open -a Simulator
xcrun simctl list runtimes
xcrun simctl list devices available
flutter devices
```

Choose an actual listed iPhone ID, boot it in Simulator if needed, and run:

```sh
taskSimulatorId='REPLACE_WITH_A_LISTED_SIMULATOR_ID'
flutter run -d "$taskSimulatorId" --dart-define-from-file=dart_define.local.json
```

The owner handles provider/system account prompts locally. Do not print the define file or token-bearing auth URLs. Walk launch/fonts, consent/guest entry, Google cold/warm return, feed/channel/replay/live viewing, chat/report/block, map/venue/directions, profile/settings/deletion confirmation, Arabic RTL, safe areas, offline recovery and foreground restoration. Verify actual WebView playback/bridge acknowledgments, not just an iframe appearing.

Capture genuine screenshots under brief/evidence/<date>/ios-sim/ and record model/runtime/language/commit/fixture. A launch supports E2S for observed simulator-capable features only. Camera, microphone, push and background survival cannot receive E2S; they require physical-device E3. A missing paid Apple capability should show the standard sign-in error, with Google and guest paths still usable; it is not a successful Apple authentication test.

## 6. M3 — evidence matrix

Create brief/ios/DEVICE_MATRIX.md on the Mac with these columns:

```text
Test ID | feature | expected result | device/model/OS | language |
fixture | command/action | observed result | evidence path | E-level | owner hands needed
```

Run simulator-capable rows in both languages, including a small screen and the requested older/current runtimes that are actually available. Use the W10/W11 reachability tests as host regression coverage, not replacements for native rows. Mark unavailable/device-only/account-entry rows explicitly.

Include Google return from running/closed app; actual Live/VOD inline playback, mute/control bridge, orientation and foreground restoration; chat report/block/moderation with authorized test accounts; map/offline/directions; location/gallery prompts and refusal; privacy/support and deletion confirmation/failure; safe areas/keyboard; offline overlays; Firebase remaining inert; and viewer publishing/channel gates. A screenshot alone does not prove successful playback or a destructive operation.

For account deletion and moderation execution use disposable approved fixtures prepared by the owner. No production migration/settings change is authorized by this runbook. Keep ESC-2/ESC-3 open until their separately scoped work and evidence resolve them.

## 7. M4 — owner's iPhone, then later paid distribution

For a free-team cable install, owner connects/unlocks the iPhone, trusts the Mac and enables Developer Mode under Settings > Privacy & Security, including the restart/confirmation. The owner handles device passcode, Apple login, trust and keychain prompts locally.

Open the workspace from project/:

```sh
open ios/Runner.xcworkspace
flutter devices
```

In Runner > Signing & Capabilities, select the personal team for **Debug** and automatic signing, with the unchanged bundle ID. Confirm Debug has no entitlement file. Do not add paid capabilities to fix signing. Use the actual listed phone ID:

```sh
taskPhoneId='REPLACE_WITH_A_LISTED_IPHONE_ID'
flutter run --debug -d "$taskPhoneId" --dart-define-from-file=dart_define.local.json
```

Record the actual device/OS and observed feature results for E3; free-team signing is temporary and must be renewed as required by Xcode. This build does not test paid Apple sign-in, universal links or push. Do not commit team/account/provisioning material.

After M1–M3, tell the owner paid enrollment is now the critical path for Apple sign-in, signed distribution, TestFlight and App Store Connect (D4 remains their decision). Later paid Release/Profile activation and provider/deletion/legal steps are in OWNER_STEPS_IOS.md. A processed uploaded build supports E4; it is not a substitute for device testing.

Any Track B publisher remains experimental until its device matrix passes; do not ship it in the viewer release below E3. Push remains inert until the W18 backend/account scope is authorized.

## 8. M5 — owner submission

Resolve W11 blockers and all advertised feature gaps, prepare a signed archive with the owner's paid team, create the App Store record, upload/process, paste the W14 pack after final privacy/age/content-rights/export checks and attach genuine screenshots. Supply working review access only through App Store Connect. The owner reviews the final build and clicks Submit.

After every Mac work order/fix: analyzer 0, one full test suite, Android/web source integrity, explicit local master commit, STATUS overwrite, PROGRESS append. Claim only evidence actually obtained; never push. Account/secret/out-of-scope/hardware blockers are written down while unrelated work continues.

## Sources checked 2026-10-17

- [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup), [manual SDK install](https://docs.flutter.dev/install/manual), [SDK archive](https://docs.flutter.dev/install/archive) and [release guide](https://docs.flutter.dev/deployment/ios), fetched through Context7. Pinned local Flutter 3.41.2 build_ios.dart:957–959 confirms simulator defaults to Debug.
- [Apple upload requirements](https://developer.apple.com/news/upcoming-requirements/) and [Xcode system requirements](https://developer.apple.com/xcode/system-requirements), fetched from official pages. Recheck at setup/submission.
- [Homebrew installation](https://docs.brew.sh/Installation), fetched through Context7; use the actual architecture's installer guidance.
- [Official OpenAI quickstart](https://learn.chatgpt.com/docs/quickstart?setup=app) and [Codex CLI guide](https://learn.chatgpt.com/docs/codex/cli). The quickstart's Markdown was fetched directly after the web tool could not render that Markdown content type; install/sign-in/Codex selection were verified. No API key is needed for this documentation.


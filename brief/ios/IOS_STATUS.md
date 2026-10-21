# iOS build status

Updated 2026-10-18 after W23; toolchain and fresh checks refreshed 2026-10-21.
Contract: IOS_PLAN_V2.md sections 2, 3 and 12.
History and red-first evidence: IOS_PROGRESS.md. Manager verdicts: IOS_LEDGER.md.

## Snapshot

| Field | Current state |
|---|---|
| Work order | W23-1 to W23-4 complete locally, awaiting manager audit. Stop after the W23 commit. |
| Source | W22 base d35a29d; W23 local commit subject: fix(ios): address W22 audit findings |
| Track/evidence | Windows source/host E1; Swift/native E0. No Mac, CI, Simulator or iPhone run. No E2/E2S/E3/E4. |
| Toolchain | Flutter 3.41.9 / Dart 3.11.5, stable hotfix (was 3.41.2). Same pin locally (Windows SDK, also used for Android/Play), in both Codemagic workflows, the Vercel web build and MAC_SETUP.md. Codemagic Xcode pinned to 26.6 (default mac_mini_m2 image, iOS 26.5 SDK) instead of `latest`; ci_compile.sh still rejects Xcode/SDK majors below 26. Move to Xcode 27 only with a Flutter 3.44.8+ upgrade (CI_OWNER_STEPS.md "Toolchain pins"). No CI run has observed these versions yet. |
| Fresh checks | 2026-10-21 on Flutter 3.41.9: flutter analyze 0 issues (57.0s); full flutter test 1577 passed, 0 failed, 11 skipped (opt-in web design captures) (05:45), exit 0. pub get changed only the SDK-pinned matcher 0.12.18 → 0.12.19 and test_api 0.7.9 → 0.7.10 in pubspec.lock. W23 on 3.41.2: 1499 passed (05:37). |
| Host checks | 2026-10-21: configure 6/6; CI fixtures 6/6 using real temporary Git; ci_compile.sh Bash syntax passes. W23: doctor 6/6; Git Bash syntax 3/3; EN/AR 1,898 keys each, symmetric; viewer isolation and 65/65 Android/web byte hashes pass. |
| Publisher | Default off, unchanged. No generated xcconfig or opt-in package references in the viewer project; no camera/microphone/background purposes in viewer plist/strings. |
| Accounts | D4 paid enrollment deferred. No account, hosted backend, secret or signing access. Owner pushes. |

## W23 result

| Item | Source and host result |
|---|---|
| W23-1 / W22-1 | Stable ColoredBox/LayoutBuilder/Column/TabBarView keeps EditableText mounted. Screen insets are captured above Scaffold; only the existing segmented-header slot collapses. Eight real-font EN/AR, Android/iOS, two-size cases retain the input client, visibility and focus through a 336px keyboard without reconnecting; direct TestTextInput entry sends; composer controls clear the keyboard and chrome returns. |
| W23-2 / W22-2 | Composer Row is a TextFieldTapRegion. Send, reaction and raise hand retain focus/client and perform their actions. Native iOS outside tap dismisses; Android uses the framework touch default. Drag dismissal stays on both. CaInput uses the same platform gate; every caller is listed in IOS_UX_AUDIT.md, with related callback review and bilingual action checks. |
| W23-3 / W22-3 | Exactly six in-app support-limit sentences now qualify Apple-linked accounts, plus matching proposed text in PUBLIC_PAGES_GAPS.md. Following contact sentences are unchanged; privacy section 9 retains web deletion URL and email. Catalog/legal and existing deletion tests pass. |
| W23-4 / W22-4 | Markerless disable parses reserved publisher objects/list references, restores viewer paths, preserves unrelated Pods entries and refuses unknown shapes before writing. Intact-marker round trips remain byte-identical. CI logs targeted viewer resources/Podfile, publisher references and generated-flag checks; iOS diff stat is informational. Cleanup failure fails success; build failure keeps its own code. |
| W22-5/6/7/8 | Android regression owner step added; failed Apple revocation alone gets the EN/AR retry cue with exact tests; CupertinoPage uses the native-iOS gate and existing swipe-back tests pass. Ledger report appended; earlier verdict bytes preserved. |

## Shared-platform impact

Unchanged Android/web native folders do not mean shared Dart behavior is unchanged.

| Shared Dart behavior from W22/W23 | Android and web impact |
|---|---|
| Keyboard compaction and stable chat tree | Both use the compact player/header allocation and retain the composer through insets. |
| Mini-player body bounds and scaled height | Both inherit W22's bounds/height changes. |
| onDrag dismissal in feed, Settings and chat | Both inherit W22's drag behavior. |
| Welcome, support and deletion text colors | Both inherit the shared contrast changes. |
| Tap-outside after W23-2 | Custom unfocus is native-iOS-only in composer/CaInput. Android/web receive null and use Flutter's framework default; composer controls share its tap region. |
| Deletion copy | Shared catalogs/legal qualify the Apple-only limitation. Only the transient failed Apple-revocation message gains a retry suffix. |

## Preserved gates

- Native shell, sa.hadayah.streamerapp/iOS 15.0 and Debug without paid entitlements
  remain source-only. Neither Codemagic workflow has run. W13 must handle the
  first real CI/Mac build log before other work.
- Playback/referrer behavior, Google return, real Apple sign-in/private relay,
  native keyboard/selection, VoiceOver, Dynamic Type and gestures need native
  observation. Host touch/swipe tests do not prove device behavior.
- W17 publisher remains Swift E0 and mocked Dart E1, HaishinKit 2.2.5/Logboard
  2.6.0 opt-in SwiftPM with Flutter plugins on CocoaPods. W21-3 and recovery
  findings 4/5 need iPhone interruption, upstream-delivery and capture proof.
  Local audio submission is not upstream-delivery proof.
- W19 SQL/proof expiry/grants and 41 pgTAP assertions remain unexecuted.
  Deployment, real provider revocation and deletion acceptance are separately
  authorized owner work. No SQL/provider work was started in W23.
- Finding 3 support design remains open. Apple deletion guards are unchanged.
  Legal v1.1.0-ios-draft/public pages, hosted legal record and counsel approval
  remain open. Public source, store and Play launch files were not edited.
- Archive privacy report, resolved Pods/native assets, package_info_plus and
  required-reason checks need Mac packaging. Export/store answers, territories,
  audience/content rights, review fixtures and submission remain owner/counsel work.
- ESC-4 push is deferred. iOS Firebase/APNs and channel OAuth stay gated.
  Associated Domains/AASA and native invitation consumption stay deferred.

## Owner next steps

1. Manager audits W23; owner selects and pushes intended commits. Untracked
   manager plan/prompts, unrelated icon/observation log/drafts remain out.
2. Push, then start the Codemagic viewer workflow ios-compile-check by hand
   (Flutter 3.41.9, Xcode 26.6) per CI_OWNER_STEPS.md, or the Mac sequence in
   MAC_SETUP.md. After the first successful viewer pod install, review and
   commit the actual integrated pbxproj and workspace by explicit path. No Mac
   output was fabricated here.
3. Run the Simulator/iPhone matrices and the real Android phone chat typing/
   sending Play regression in OWNER_STEPS_IOS.md. Keep publishing off until
   its device/privacy gates pass.

W23 ends after one explicit-path local commit. No push, deploy, database
execution, hosted access, signing/secret inspection, Swift edit or dependency
change. No later work order starts automatically.

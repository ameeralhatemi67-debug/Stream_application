# iOS build status

Plan: `IOS_PLAN_V2.md`. History: `IOS_PROGRESS.md`. Decisions/verdicts: `IOS_LEDGER.md`.

## Snapshot

| Field | Value |
|---|---|
| Updated | 2026-10-17, Codex |
| Track | A, Windows; Mac not available |
| Resume | Phase 3, W9 |
| Progress | 8 / 18 work orders complete |
| Evidence | Native shell/configuration E0. iOS Firebase, Studio and channel guards have E1 Windows test proof. No iOS compile or runtime evidence. |
| Mac / iPhone | Mac arriving, ETA unknown; iPhone availability unknown |
| Apple enrollment | Deferred by owner, D4; Debug/free-team builds must exclude paid capabilities |
| Meter | 2026-10-17T21:45:00+03:00; weekly used 44%; resets in 6452 min |
| Latest checks | W8 final: flutter analyze 0 issues (20.3s); full flutter test 1,112 passed / 0 failed / 0 skipped (03:30), exit 0. Focused new tests 3/3 pass. Android/web SHA-256 90/90 unchanged. |

## Work orders

| WO | Title | Status | Commit selector or hash | Checkpoint |
|---|---|---|---|---|
| W1 | Generate ios/ | DONE | 5605451 | C1 |
| W2 | Identity | DONE | 88c65a0 | C1 |
| W3 | Info.plist | DONE | 3214951 | C2 |
| W4 | Privacy manifest | DONE | d6e6278 | C2 |
| W5 | URL scheme and deep links | DONE | 5c4dcbd | C2 |
| W6 | Firebase inert on iOS | DONE | 72802e5 | C2 |
| W7 | WKWebView / YouTube audit | DONE | 580dc75 | C2 |
| W8 | Branch audit and gating | DONE | master^{/gate iOS viewer broadcast actions} | C3 |
| W9 | Sign in with Apple | OPEN |  | C3 |
| W10 | iOS-override tests | OPEN |  | C3 |
| W11 | App Review compliance | OPEN |  | C3 |
| W12 | Codemagic config | OPEN |  | C4 |
| W13 | Compile-fix loop | WAITING for CI or Mac log |  | C4 |
| W14 | App Store pack | OPEN |  | C4 |
| W15 | Truth reconciliation | OPEN |  | C4 |
| W16 | Mac setup runbook | OPEN |  | C4 |
| W17 | Phone publisher | OPEN, Track B |  |  |
| W18 | Push spec | OPEN, Track B |  |  |
| M1–M5 | Mac track | WAITING for physical Mac | | C5/C6 |

Resolve a commit selector with `git rev-parse '<selector>'`.

## Evidence by feature

| Feature | Level claimed | Limit |
|---|---|---|
| iOS native shell | E0 | Implemented, not run on iOS; CocoaPods, bundle sa.hadayah.streamerapp, target 15.0, iPhone only. |
| iOS identity | E0 | Implemented, not run on iOS. Opaque 1024px icon; dark launch uses AppTheme.media #243536. |
| Discovery/watch/chat/map/profile shared Dart | E1 host baseline | Windows tests only; no iOS runtime proof. |
| WKWebView playback | E0 | Existing settings audited against official WKWebView 3.25.1 source. Inline/autoplay/JS/referrer/runtime behavior unverified on iOS. |
| Google redirect | E0 | Custom scheme registered; app_links owns auth callback. Hosted allowlist and cold/warm return unverified. |
| Sign in with Apple | none | W9 pending; paid capability deferred. |
| Phone publishing | E1 host availability gate; no iOS native publisher | Native iOS Studio entry shows FeatureInProgressModal before creating publishing state. Phone and OBS setup deferred. |
| Push | E1 host gate; E0 native audit | iOS support/configured false tested; Android support preserved. No Firebase iOS plist, APNs entitlement or background mode; native launch unverified. |
| Location and gallery permissions / native localization | E0 | Implemented, not run on iOS. Foreground location only; no camera/mic/background/ATS exceptions. |
| App privacy manifest | E0 | Implemented, not run on iOS. 11 linked data types for functionality; no tracking. App reasons CA92.1/C617.1. Packaged report unverified. |
| HTTPS organization invitations | Deferred | Open in browser. No Associated Domains entitlement or non-auth link consumer; future owner plan in OWNER_STEPS_IOS.md. |
| iOS channel connection | E1 host guard | UI notice plus service rejection before backend access. Android/web flow preserved; no iOS OAuth channel flow. |

## Blockers and owner actions

| ID | Who | Action |
|---|---|---|
| O1 | Owner | Paid Apple enrollment deferred (D4). Needed for Apple capability/device testing, TestFlight and App Store submission. |
| O2 | Owner | Provide Mac access when it arrives; iPhone availability remains unknown. |
| O3 | Owner / Claude | Before submission, reconcile the public privacy policy's Android/web wording with iOS and verify the packaged Xcode privacy report. No public page edited in this run. |
| O4 | Owner | Verify existing Supabase OAuth callback allowlist, later run cold/warm Google return; exact steps in OWNER_STEPS_IOS.md. No hosted settings changed. |
| O5 | Owner / scoped future work | After paid enrollment: host AASA, implement invite link consumer, attach Associated Domains only to paid builds and verify on device. Deferred per D4. |

Account-gated steps do not block unrelated Windows work.

## Next three steps

1. W9 native Apple sign-in and Release/Profile-only entitlement.
2. W10 iOS-override UI/platform tests, using body-finally cleanup.
3. W11 App Review compliance sweep.

## Audit notes and verification limits

- C1 (W1/W2) and C2 (W3–W7) await Claude audit. No iOS compilation or evidence promotion.
- Initial SHA-256 inventory was written to a sandbox temporary directory and could not be recovered after that process ended. Generation has a clean tracked Android/web diff; the persistent post-generation inventory covers 90 files (77 Android, 13 web). Do not claim a pre-generation SHA comparison.
- Flutter create also emitted an unrelated sample widget test and replaced web/Windows metadata entries. The new sample was removed and original metadata entries restored before testing.
- flutter_launcher_icons 0.14.4 rewrites unrelated asset-symbol settings in project.pbxproj. Restored to W1 during W2; inspect that diff after future regeneration.
- W8 widget tests must reset debugDefaultTargetPlatformOverride in the widget body finally, in addition to tearDown; Flutter verifies foundation invariants before ordinary tearDown. Keep this pattern in W9/W10.

## Open escalations

None.

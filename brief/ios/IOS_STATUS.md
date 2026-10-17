# iOS build status

Plan: `IOS_PLAN_V2.md`. History: `IOS_PROGRESS.md`. Decisions/verdicts: `IOS_LEDGER.md`.

## Snapshot

| Field | Value |
|---|---|
| Updated | 2026-10-17, Codex |
| Track | A, Windows; Mac not available |
| Resume | Phase 4, W13 build-log gate |
| Progress | 11 / 18 work orders complete |
| Evidence | Native shell/configuration and Apple entitlement E0. iOS auth exchange, Firebase and availability guards have E1 Windows test proof. No iOS build/runtime evidence. |
| Mac / iPhone | Mac arriving, ETA unknown; iPhone availability unknown |
| Apple enrollment | Deferred by owner, D4; Debug/free-team builds must exclude paid capabilities |
| Usage policy | No cap; owner update 2026-10-17. Historical meters are informational. |
| Latest checks | W12: YAML parses and invariant checks pass; flutter analyze 0 issues (28.3s); full flutter test 1,141 passed / 0 failed / 0 skipped (04:23), exit 0. Android/web SHA-256 90/90 unchanged. No cloud/iOS build run. |

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
| W8 | Branch audit and gating | DONE | 0123921 | C3 |
| W9 | Sign in with Apple | DONE | f715230 | C3 |
| W10 | iOS-override tests | DONE | 4fa027b | C3 |
| W11 | App Review compliance | PARTIAL — ESC-2/ESC-3 | 4923c13 | C3 |
| W12 | Codemagic config | DONE | master^{/add unsigned Codemagic compile gate} | C4 |
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
| Sign in with Apple | E1 host exchange tests; E0 native capability | Native button + nonce exchange implemented; Release/Profile entitlement only. Paid provider/device flow deferred; Debug has no entitlements. |
| Phone publishing | E1 host availability gate; no iOS native publisher | Native iOS Studio entry shows FeatureInProgressModal before creating publishing state. Phone and OBS setup deferred. |
| Push | E1 host gate; E0 native audit | iOS support/configured false tested; Android support preserved. No Firebase iOS plist, APNs entitlement or background mode; native launch unverified. |
| Location and gallery permissions / native localization | E0 | Implemented, not run on iOS. Foreground location only; no camera/mic/background/ATS exceptions. |
| App privacy manifest | E0 | Implemented, not run on iOS. 11 linked data types for functionality; no tracking. App reasons CA92.1/C617.1. Packaged report unverified. |
| HTTPS organization invitations | Deferred | Open in browser. No Associated Domains entitlement or non-auth link consumer; future owner plan in OWNER_STEPS_IOS.md. |
| iOS channel connection | E1 host guard | UI notice plus service rejection before backend access. Android/web flow preserved; no iOS OAuth channel flow. |
| iOS platform adaptation tests | E1 Windows target-platform override | Apple iOS/Android EN/AR matrix, consent/error/cancel/paused signup, channel UI guard, Apple Maps/fallback, actual provider ios identity path. No native plugin runtime proof. |
| App Review legal / UGC / deletion | E1 host UI; submission BLOCKED | iOS EN/AR privacy/deletion/report/block/mute reachability tested; support mail fallback added. Native behavior, hosted moderation/deletion and complete policy content unverified. ESC-2/ESC-3 open. |
| Pre-Mac compile workflow | E0 configuration; E1 Windows baseline | Manual-only Codemagic YAML, Flutter 3.41.2, unsigned release/example defines. No CI job, no E2 claim. |

## Blockers and owner actions

| ID | Who | Action |
|---|---|---|
| O1 | Owner | Paid Apple enrollment deferred (D4). Needed for Apple capability/device testing, TestFlight and App Store submission. |
| O2 | Owner | Provide Mac access when it arrives; iPhone availability remains unknown. |
| O3 | Owner / Claude | ESC-3: repair privacy/about SPA fallbacks and old deletion-page branding on the existing domain; publish complete EN/AR iOS-aware legal text and review the offline fallback and packaged privacy report. Exact acceptance checks in OWNER_STEPS_IOS.md. |
| O4 | Owner | Verify existing Supabase OAuth callback allowlist, later run cold/warm Google return; exact steps in OWNER_STEPS_IOS.md. No hosted settings changed. |
| O5 | Owner / scoped future work | After paid enrollment: host AASA, implement invite link consumer, attach Associated Domains only to paid builds and verify on device. Deferred per D4. |
| O6 | Owner, later paid activation | Apple App ID/capability and Supabase Apple provider setup; native bundle ID audience, optional browser Services ID/key/secret rotation. Exact deferred steps in OWNER_STEPS_IOS.md. |
| O7 | Owner / Claude, separate backend work | ESC-2: add and audit Apple token revocation during account deletion with server-held credentials; review current deletion restrictions. Apple activation/submission remains blocked. |
| O8 | Owner, optional before Mac | Push and manually run Codemagic ios-compile-check; supply non-secret first-error logs or successful native build evidence. CI_OWNER_STEPS.md and OWNER_STEPS_IOS.md contain exact steps. Skip if Mac available. |

Account-gated steps do not block unrelated Windows work.

## Next three steps

1. W13: record no real CI/Mac build log; do not invent a compile fix.
2. W14 viewer-first English/Arabic listing, privacy, age, review and screenshot drafts.
3. W15 truth reconciliation, then W16 Mac setup.

## Audit notes and verification limits

- C1 (W1/W2) and C2 (W3–W7) await Claude audit. No iOS compilation or evidence promotion.
- Initial SHA-256 inventory was written to a sandbox temporary directory and could not be recovered after that process ended. Generation has a clean tracked Android/web diff; the persistent post-generation inventory covers 90 files (77 Android, 13 web). Do not claim a pre-generation SHA comparison.
- Flutter create also emitted an unrelated sample widget test and replaced web/Windows metadata entries. The new sample was removed and original metadata entries restored before testing.
- flutter_launcher_icons 0.14.4 rewrites unrelated asset-symbol settings in project.pbxproj. Restored to W1 during W2; inspect that diff after future regeneration.
- W8 widget tests must reset debugDefaultTargetPlatformOverride in the widget body finally, in addition to tearDown; Flutter verifies foundation invariants before ordinary tearDown. Keep this pattern in W9/W10.
- Owner removed every usage cap and soft stop on 2026-10-17. Do not interpret older meter/cap text as a stop condition.
- Apple plugin 8.1.0 is the newest solver-compatible version for Flutter 3.41.2/Dart 3.11.0; only three new lockfile entries, no existing package updates. Native/plugin compilation remains pending.
- W10 found the Arabic Google button was 61px high. Apple is now 64px (AppTheme tokens); the EN/AR test checks it remains at least as tall and fully localized. Android auth UI remains unchanged.
- C3 scoped sweep is committed for audit; W11 remains PARTIAL because ESC-2/ESC-3 are real submission blockers. Continue unrelated Windows work.

## Open escalations

- ESC-2 (W11): Apple revocation requires owner credentials and separate backend scope; no backend edits.
- ESC-3 (W11): public document routing/branding and full privacy text need site/account changes and a scoped fallback follow-up.

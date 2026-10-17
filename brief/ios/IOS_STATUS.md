# iOS build status

Plan: `IOS_PLAN_V2.md`. History: `IOS_PROGRESS.md`. Decisions/verdicts: `IOS_LEDGER.md`.

## Snapshot

| Field | Value |
|---|---|
| Updated | 2026-10-17, Codex |
| Track | A, Windows; Mac not available |
| Resume | Phase 1, W2 |
| Progress | 1 / 18 work orders complete |
| Evidence | Native shell E0, implemented, not run on iOS. Shared Dart host checks pass. No iOS compile or runtime evidence |
| Mac / iPhone | Mac arriving, ETA unknown; iPhone availability unknown |
| Apple enrollment | Deferred by owner, D4; no paid-only capability configured |
| Meter | 43% weekly; cap 50%, soft stop 45%; resetsAt 1792649794. |
| Latest checks | W1: flutter analyze 0 issues (22.3s); full flutter test 1,107 passed / 0 failed / 0 skipped (03:52), exit 0. iOS configuration asserts passed. Android/web Git diff clean; 90/90 SHA-256 matches since post-generation inventory. |

## Work orders

| WO | Title | Status | Commit selector | Checkpoint |
|---|---|---|---|---|
| W1 | Generate ios/ | DONE | master^{/generate iOS platform project} | C1 |
| W2 | Identity | OPEN |  | C1 |
| W3 | Info.plist | OPEN |  | C2 |
| W4 | Privacy manifest | OPEN |  | C2 |
| W5 | URL scheme and deep links | OPEN |  | C2 |
| W6 | Firebase inert on iOS | OPEN |  | C2 |
| W7 | WKWebView / YouTube audit | OPEN |  | C2 |
| W8 | Branch audit and gating | OPEN |  | C3 |
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

Commit selectors avoid embedding a commit's own hash. Resolve with `git rev-parse '<selector>'`.

## Evidence by feature

| Feature | Level claimed | Limit |
|---|---|---|
| iOS native shell | E0 | Implemented, not run on iOS; CocoaPods, bundle sa.hadayah.streamerapp, target 15.0, iPhone only. |
| Discovery/watch/chat/map/profile shared Dart | E1 host baseline | Windows tests only; no iOS runtime proof. |
| WKWebView playback | E0 at best | Audit W7 pending; no iOS playback proof. |
| Google redirect | none | W5 pending. |
| Sign in with Apple | none | W9 pending; paid capability deferred. |
| Phone publishing | none on iOS | Android sender only; Track B. |
| Push | none on iOS | Deferred; W18 is spec only. |

## Blockers and owner actions

| ID | Who | Action |
|---|---|---|
| O1 | Owner | Paid Apple enrollment deferred (D4). Needed for Apple capability/device testing, TestFlight and App Store submission. |
| O2 | Owner | Provide Mac access when it arrives; iPhone availability remains unknown. |

No account is required for the next Windows work orders. Paid enrollment is deferred until the relevant Mac/device/store steps.

## Next three steps

1. W2 identity.
2. W3 permissions and localizations.
3. W4 privacy manifest.

## Audit notes and verification limits

- C1 awaits W2 and later Claude audit. Builder claims E0 for native config plus passing E1 host checks; no evidence level awarded.
- Initial SHA-256 inventory was written to a sandbox temporary directory and could not be recovered after that process ended. Generation has a clean tracked Android/web diff; the persistent post-generation inventory covers 90 files (77 Android, 13 web). Do not claim a pre-generation SHA comparison.
- Flutter create also emitted an unrelated sample widget test and replaced web/Windows metadata entries. The new sample was removed and original metadata entries restored before testing.

## Open escalations

None.

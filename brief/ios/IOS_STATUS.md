# iOS build status

Plan: `IOS_PLAN_V2.md`. History: `IOS_PROGRESS.md`. Decisions/verdicts: `IOS_LEDGER.md`.

## Snapshot

| Field | Value |
|---|---|
| Updated | 2026-10-18, Codex |
| Track | A, Windows; Mac not available |
| Resume | W17 default-off phone publisher, Dart and native commits kept separate |
| Progress | 17 / 20 work orders complete |
| Evidence | Native shell/configuration and Apple entitlement E0; E1 Windows auth/UI/config/availability tests. W18 E0 specification only. No E2, E2S, E3 or E4. |
| Mac / iPhone | Mac arriving, ETA unknown; iPhone availability unknown |
| Apple enrollment | Deferred by owner, D4; Debug/free-team builds must exclude paid capabilities |
| Usage policy | No cap; owner update 2026-10-17. Historical meters are informational. |
| Latest checks | W20: flutter analyze 0 issues (21.9s); full flutter test 1,153 passed / 0 failed / 0 skipped (03:36), exit 0; focused model/iOS readers 17/17; 1,895 EN/AR keys symmetric; Android/web SHA-256 90/90 unchanged. Legal text is a counsel-review draft, no publication. |

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
| W12 | Codemagic config | DONE | d35721d | C4 |
| W13 | Compile-fix loop | WAITING — real CI/Mac log | a3da856 | C4 |
| W14 | App Store pack | DONE | d9f33e2 | C4 |
| W15 | Truth reconciliation | DONE | 5f250f3 | C4 |
| W16 | Mac setup runbook | DONE | 6b667f4 | C4 |
| W17 | Phone publisher | OPEN — §12 unblocked | fa6a3f5 (research) | Track B |
| W18 | Push spec | DONE | bd442c8 | Track B |
| W19 | Apple deletion revocation | DONE | d5e4b6b | §12 |
| W20 | Legal drafts / public gaps | DONE | master^{/draft bilingual iOS legal notices and public gaps} | §12 |
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
| Push | E0 spec; E1 host exclusion | W18 spec complete, ESC-4 future backend migration. iOS Firebase remains disabled; no APNs/plist/background change and no native delivery proof. |
| Location and gallery permissions / native localization | E0 | Implemented, not run on iOS. Foreground location only; no camera/mic/background/ATS exceptions. |
| App privacy manifest | E0 | Implemented, not run on iOS. 11 linked data types for functionality; no tracking. App reasons CA92.1/C617.1. Packaged report unverified. |
| HTTPS organization invitations | Deferred | Open in browser. No Associated Domains entitlement or non-auth link consumer; future owner plan in OWNER_STEPS_IOS.md. |
| iOS channel connection | E1 host guard | UI notice plus service rejection before backend access. Android/web flow preserved; no iOS OAuth channel flow. |
| iOS platform adaptation tests | E1 Windows target-platform override | Apple iOS/Android EN/AR matrix, consent/error/cancel/paused signup, channel UI guard, Apple Maps/fallback, actual provider ios identity path. No native plugin runtime proof. |
| App Review legal / UGC / deletion | E1 host UI; submission BLOCKED | W19 revocation source E1 mocked; W20 complete bilingual legal draft/readers E1. Counsel approval, hosted legal record/public-page deployment, SQL/provider/device behavior and submission remain pending. |
| Pre-Mac compile workflow | E0 configuration; E1 Windows baseline | Manual-only Codemagic YAML, Flutter 3.41.2, unsigned release/example defines. No CI job, no E2 claim. |
| App Store pack | E0 drafts | Seven files: EN/AR copy, privacy mapping, age questionnaire, review notes and both requested screenshot size plans. No images, account form or upload; W11 blockers carried forward. |
| Mac handoff | E0 runbook | MAC_SETUP.md covers Xcode/SDK/deployment distinction, pinned SDK, owner hands, Debug entitlements, exact M1–M5 commands and evidence boundaries. No Mac available. |
| Apple deletion revocation | E1 host/mocked; SQL source only | W19 reauthorization → authenticated code exchange → verified identity/nonce → refresh revoke → private identity-version proof. Deletion guard, localized failures and non-Apple sequence implemented. No SQL/hosted/provider/iPhone proof. |

## Blockers and owner actions

| ID | Who | Action |
|---|---|---|
| O1 | Owner | Paid Apple enrollment deferred (D4). Needed for Apple capability/device testing, TestFlight and App Store submission. |
| O2 | Owner | Provide Mac access when it arrives and an iPhone when available; follow MAC_SETUP.md. Owner handles local account/license/trust/define-file steps. No paid enrollment needed for Simulator/unsigned build or free-team Debug device install. |
| O3 | Owner / Claude | W20 in-app draft complete at E1. Owner/counsel approve; Claude handles iOS public copy gaps and owner redeploys the existing committed pages (5991d38) before SPA fallback. PUBLIC_PAGES_GAPS.md and OWNER_STEPS_IOS.md have concrete deltas and content acceptance. No web edits/live access this round. |
| O4 | Owner | Verify existing Supabase OAuth callback allowlist, later run cold/warm Google return; exact steps in OWNER_STEPS_IOS.md. No hosted settings changed. |
| O5 | Owner / scoped future work | After paid enrollment: host AASA, implement invite link consumer, attach Associated Domains only to paid builds and verify on device. Deferred per D4. |
| O6 | Owner, later paid activation | Apple App ID/capability and Supabase Apple provider setup; native bundle ID audience, optional browser Services ID/key/secret rotation. Exact deferred steps in OWNER_STEPS_IOS.md. |
| O7 | Owner, backend deployment / later paid verification | W19 source complete; ESC-2 resolved at E1 mocked. Audit/deploy only the new function/secrets/migration, verify SQL guard/grants and real revocation/deletion with paid iPhone. OWNER_STEPS_IOS.md contains commands, secret names and ordered acceptance. |
| O8 | Owner, optional before Mac | Push and manually run Codemagic ios-compile-check; supply non-secret first-error logs or successful native build evidence. CI_OWNER_STEPS.md and OWNER_STEPS_IOS.md contain exact steps. Skip if Mac available. |
| O9 | Owner, at submission prep | Confirm actual privacy purposes/provider data, age/content answers, rights holder/content rights, hosted flags and review accounts; capture genuine iOS screenshots and enter metadata only after W11/native/paid gates. OWNER_STEPS_IOS.md and store/README.md have steps. |
| O11 | Owner / Claude, deferred Track B | ESC-4: decide separate push migration/implementation later. Both backend platform validations and both client registration labels need ios; APNs/Firebase setup needs paid owner action. IOS_PUSH_SPEC.md and OWNER_STEPS_IOS.md contain scope and acceptance tests. W18 spec is complete. |

Account-gated steps do not block unrelated Windows work.

## Next three steps

1. W17 default-off Dart gate/channel tests; preserve Android behavior and independent iOS channel OAuth gate.
2. W17 separate native SwiftPM/config/permissions/media commit with inactive privacy mapping, then self-review.
3. Tighten M1–M3 handoff if useful; actual compilation/runtime awaits Mac/real CI log. Owner handles W19 deployment and legal approval/public delivery.

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
- W13 has zero native compile attempts and no real failure log. It is waiting for O8 or Mac access; do not preemptively patch/remove native plugins or award E2.
- W15 withdrew ADR-006's universal iOS playback claim, corrected its WKWebView API description, labeled historical Dart/SQL evidence separately and added the HTTPS invite limitation in all four allowed documents. Native E0 remains.
- C4 Windows artifacts are ready for audit. W13 native compilation is still blocked; no E2 inferred from CI YAML, store copy, truth correction or runbook.
- 2026-10-18 round follows §12: W17's W11 dependency withdrawn; W19 backend source authorized only for Apple deletion; W20 legal fallback authorized; push migration remains forbidden.
- W19 fixed a test-fixture issue: installed PostgREST expects http.Response.request. Mock responses now carry request metadata. Unrelated AppProvider formatter churn was removed; only deletion logic/blocker names changed.
- ESC-2 resolved at E1 mocked/source scope. Database proof validity is ten minutes and tied to current identity version; SQL guard/grants are unexecuted and real provider/device behavior remains pending.
- W20 complete default terms/guidelines/privacy at v1.1.0-ios-draft, marked for counsel review. No unverified PDPL compliance/instant deletion/ad-free promises. Hosted legal content not overwritten; public source pages untouched.

## Open escalations

- ESC-3 public half: W20 in-app draft/source resolved at E1; Claude/owner handle copy review and deployment of existing public pages. Counsel/hosted approval pending.
- ESC-4 (W18): future push implementation needs a separately authorized backend migration plus owner APNs/Firebase setup; specification complete, no backend changes.

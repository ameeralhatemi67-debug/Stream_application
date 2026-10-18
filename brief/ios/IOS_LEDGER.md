# iOS ledger (mailbox between Codex, Opus and the owner)

Append only. Short rows. Formats are defined in `IOS_PLAN.md` §7. Newest entries at the bottom of each section.

## Run header

| Field | Value |
|---|---|
| Started | 2026-10-11 |
| CODEX_CAP | 20% weekly, owner authorized in chat 2026-10-11 |
| OPUS_SESSIONS | ____ (owner fills) |
| Baseline `flutter analyze` | PASS, 0 issues, 2026-10-11; 43.1 seconds |
| Baseline `flutter test` | PASS, 1,085 passed / 0 failed / 0 skipped, 2026-10-11; one full run, 5m 38s |
| Current phase | 0 |

## Decisions (owner)

| ID | Decision | Answer | Date |
|---|---|---|---|
| D1 | iOS bundle ID | `sa.hadayah.streamerapp` (recommended option a; owner proceeded without objection) | 2026-10-17 |
| D2 | iPhone on iOS 17+ available? | PARTIAL: owner has a Mac laptop arriving (date unknown). iPhone ownership still unanswered; E3 needs a real iPhone | 2026-10-17 |
| D3 | First iOS scope | (a) viewer-first; phone publishing (W17) and push (W18) are Track B extras after launch scope compiles | 2026-10-17 |
| D4 | Apple Developer Program enrollment timing | DEFERRED: owner will not enrol in the paid program for now ("focus on building the iOS version as fast as possible"). Build around it; free Apple ID for Simulator and cable installs. Revisit when M1 to M3 finish | 2026-10-17 |
| D5 | CI provider | Codemagic, only as a pre-Mac compile gate; skip it if the Mac arrives first | 2026-10-17 |
| D6 | Minimum iOS deployment target | iOS 15.0; device family iPhone only for v1 | 2026-10-17 |
| CAP | Codex weekly ceiling | 20% (2026-10-11), raised to 50% in plan v2, then REMOVED entirely by the owner later on 2026-10-17: NO CAP (X5 plan) | 2026-10-17 |
| PLAN | Active plan | `IOS_PLAN_V2.md` supersedes `IOS_PLAN.md`. Progress now lives in `IOS_STATUS.md` and `IOS_PROGRESS.md`; this ledger keeps decisions, escalations and verdicts only | 2026-10-17 |

G0 options (Opus, 2026-10-11). Owner writes the answer in the table above.

| ID | Options | Opus recommends |
|---|---|---|
| D1 | (a) `sa.hadayah.streamerapp`, identical to the existing OAuth scheme (build.gradle.kts:59); (b) `sa.hadayah.streamerApp` | (a): all lowercase, so no case mismatch in Apple, Firebase or Supabase allow-lists. Permanent once registered |
| D2 | (a) yes, model + iOS version; (b) no: E3 waits for a physical iPhone | Answer as fact. E3 needs a real iPhone; a simulator never counts |
| D3 | (a) viewer-first: discover, watch, chat, map, profile, sign-in; phone publishing and push stay off; channel connection gated; (b) (a) plus the studio's existing OBS-sender path | (a). Phone RTMP has no iOS publisher (rtmp_publish_engine.dart:207) and channel consent returns to the web |
| D4 | (a) enroll when WO-9 is written; (b) enroll now | (a). It also gates E3: without a Mac, TestFlight is the only install route, so enrollment is needed before G5 |
| D5 | (a) Codemagic; (b) GitHub Actions macOS runner | (a) for the guided Flutter setup; check the free minutes at signup. (b) if you want CI next to the repo |
| D6 | (a) iOS 15.0; (b) 13.0 (Flutter template) | (a). Firebase plugins require 15.0 (RECON §2); 13.0 would fail the build |

## Work order status

| WO | Phase | Status | Commit | E-level | Gate |
|---|---|---|---|---|---|
| WO-0 Recon | 0 | DONE, recon accepted | 095912c | E1 Windows baseline, awarded by Opus; no iOS level | G0 CONDITIONAL, owner decisions pending |
| WO-1 Generate ios/ | 1 | OPEN | | | G1 |
| WO-2 Icon, name, launch | 1 | OPEN | | | G1 |
| WO-3 Info.plist | 2 | OPEN | | | G2 |
| WO-4 PrivacyInfo | 2 | OPEN | | | G2 |
| WO-5 URL scheme / deep links | 2 | OPEN | | | G2 |
| WO-6 Firebase inert | 2 | OPEN | | | G2 |
| WO-7 WebView / YouTube | 2 | OPEN | | | G2 |
| WO-8 Branch audit and gating | 3 | OPEN | | | G3 |
| WO-9 Sign in with Apple | 3 | OPEN | | | G3 |
| WO-10 iOS-override tests | 3 | OPEN | | | G3 |
| WO-11 CI config | 4 | OPEN | | | G4 |
| WO-12 Compile-fix loop | 4 | OPEN | | | G4 |
| WO-13 Device matrix | 5 | OPEN | | | G5 |
| WO-14 Truth reconciliation | 5 | OPEN | | | G5 |

## Gate verdicts (Opus)

| Gate | Verdict | Findings (max 5) | Date |
|---|---|---|---|
| G0 | CONDITIONAL: recon PASS, gate closes when owner answers D1-D6 (WO-1 needs D1, D3, D6) | 1 (med) IOS_PLAN.md:102 D2 named a cloud simulator as an E3 route; corrected, simulators never award E3. 2 (med) path_provider_foundation 2.6.0 has no Package.swift/podspec, FFI via objective_c 9.5.0 (RECON §2): iOS compile unproven, first G4 suspect. 3 (low) channel consent returns to web on iOS (organization_broadcast_service.dart:106-107, channel-authorization/index.ts:15-20): WO-8 must gate channel connection on iOS. 4 (low) `ios` acceptance is repo-only (M/20260925100000...:270 spot-checked, confirmed); hosted DB not inspected. 5 (low) no Associated Domains: HTTPS org-invite links (app_router.dart:342-344) open the browser, not the app; out of scope, list in WO-14. E-level: WO-0 = E1 Windows baseline for shared code (095912c); no iOS level. Not verified: plugin cache files, test counts, Android hashes (Codex logs trusted). | 2026-10-11 |
| G1 | | | |
| G2 | | | |
| G3 | | | |
| G4 | | | |
| G5 | | | |

## Reports (Codex)

_none yet_

| WO | Status | Commit | E-level | Checks run + result | Files touched | Open questions |
|---|---|---|---|---|---|---|
| WO-0 | BLOCKED before recon, 2026-10-11 | none, work order incomplete | unassessed; no gate verdict | Live Codex weekly usage 3%; required meter with owner cap 20 returned UNKNOWN; analyze/test not run | brief/ios/RECON.md; brief/ios/IOS_LEDGER.md | ESC-1: required weekly helper rejects the owner's cap; backend `ios` acceptance remains uninspected |
| WO-0 | DONE, 2026-10-11 | `master^{/record WO-0 recon}`, local conventional commit | No level awarded by builder; Windows static baseline submitted for G0 | Analyze 0; full suite 1,085 pass / 0 fail / 0 skip, exit 0; Android SHA-256 77/77 unchanged; all nine recon items covered | brief/ios/RECON.md; brief/ios/IOS_LEDGER.md | G0/D1-D6 pending; known minimum iOS 15.0, objective_c native assets need CI; native channel consent returns web; simulator cannot satisfy E3 |

Commit selector resolves the WO-0 commit without embedding a self-referential hash: `git rev-parse 'master^{/record WO-0 recon}'`. Commit subject: `chore(ios): record WO-0 recon`.

## Escalations

_none yet_

| ID | WO | Blocker | Evidence | Options considered | Needed |
|---|---|---|---|---|---|
| ESC-1 | WO-0 | Required meter rejects owner-authorized 20% cap, so the unknown-budget rule prevents starting recon. | brief/tools/budget_check.mjs:232 rejects `cap > 5`; lines 236-238 emit UNKNOWN. `node brief/tools/budget_check.mjs --source codex --plan weekly --cap 20` returned `invalid_weekly_meter_or_cap`. Live Codex usage tool reported 3% weekly. IOS_PLAN.md §4 supersedes the old ceiling; §3 prohibits editing this helper. | A smaller cap would replace the owner's decision. Editing the helper exceeds Touch paths and is explicitly forbidden. Using the live usage tool as the governing meter needs an explicit replacement rule. | Opus or owner must authorize a governing meter route that supports 20%, including freshness handling, or amend scope and the helper prohibition for a separate fix. |
| ESC-1 resolution | WO-0 | RESOLVED, owner relayed Opus resolution 2026-10-11 | IOS_PLAN.md:66 now governs with live weekly readings; owner explicitly instructed no helper use/edit | Live meter used at start and phase boundary; cap 20 | No remaining budget blocker |

## RESUME block

_none yet_

### 2026-10-11, Codex budget stop

- Next step: resolve ESC-1 before starting WO-0. Once the governing budget check is valid, complete all nine recon items, prioritizing backend acceptance of `ios`, then stop at G0.
- Files in flight: RECON.md is a blocker record, not completed recon; IOS_LEDGER.md records the owner cap, REPORT and ESC-1. No local commit because WO-0 is incomplete.
- Commands: rerun the authorized budget check. The current required command is `node brief/tools/budget_check.mjs --source codex --plan weekly --cap 20`; it currently returns UNKNOWN. After resolution, run `flutter analyze` and one full `flutter test` from `project/` for the baseline.
- Evidence: no E-level established. No iOS build or device run. G0 and D1-D6 remain pending.
- Tree at kickoff: master; unrelated tracked modifications and untracked files already present. No application, Android, backend, secret, signing, or runtime files edited; no push or subagents.

### 2026-10-11, WO-0 resumed

ESC-1 resolution relayed by owner: IOS_PLAN.md §4 Codex paragraph now names the live weekly usage tool as the governing meter. Do not run or edit budget_check.mjs for iOS work.

METER | 2026-10-11T12:44:19.000+03:00 | weekly used 3% | resets in 9804 min | cap 20 | OK

METER | 2026-10-11T12:54:23.000+03:00 | weekly used 3% | resets in 9794 min | cap 20 | OK

### 2026-10-11, phase 0 boundary / G0 handoff

METER | 2026-10-11T13:02:33.000+03:00 | weekly used 3% | resets in 9786 min | cap 20 | OK

- REPORT: WO-0 DONE. Full recon in RECON.md; baseline header filled. Device-session RPC/table accepts ios in local migrations; reminder push independently excludes ios and is client-gated. No hosted DB probe.
- Next step: Opus/owner audits G0 from RECON.md and records D1-D6. Builder stops here; do not start WO-1 until authorized by the gate/decisions.
- Files in flight: only RECON.md and IOS_LEDGER.md belong to WO-0's local commit. No implementation changes or open builder escalation. Other pre-existing modifications/untracked files are outside this commit.
- Verification: flutter analyze 0; one full flutter test 1,085 passed, 0 failed, 0 skipped; Android 77 files byte-identical to session-start SHA-256 inventory. No re-run required for this documentation-only closeout.
- Evidence: Windows results submitted; no iOS CI/device evidence or E-level/gate promotion by builder. G0 remains pending. Commit resolves via `master^{/record WO-0 recon}`.
- Meter on resume: take a fresh live Codex weekly reading with reset time and append METER; cap 20, SOFT at 19, STOP at 20. Do not run/edit budget_check.mjs for iOS. No push, subagents, backend/signing/secret/runtime edits.

### 2026-10-11, G0 conditional / awaiting owner decisions

- Read G0 verdict and corrected IOS_PLAN.md:102. Opus awarded WO-0 E1 Windows baseline at 095912c; no iOS evidence level. Simulators never award E3.
- D1-D6 Answers remain blank. Wait for owner entries; WO-1 cannot start without D1, D3 and D6. On authorized resume, take/log a fresh live METER before WO-1/WO-2 and use the answered bundle ID/target; stop at G1.
- Carry forward: WO-8 must gate iOS channel connection at organization_broadcast_service.dart:106; G4 first suspect is path_provider_foundation/objective_c, without removing plugins to make CI green. G0 also assigns the out-of-scope native HTTPS invite limitation to WO-14.
- Include the owner's/auditor's IOS_PLAN.md and IOS_LEDGER.md edits in the next WO commit using explicit paths. Leave them uncommitted until then. No push; no WO-1 changes or new test run in this waiting handoff.

## ESCALATION | 2026-10-17 | W11 submission blockers

| ID | WO | Blocker | Evidence | Options considered | Needed |
|---|---|---|---|---|---|
| ESC-2 | W11 | Apple account deletion needs token revocation; backend/secret work is forbidden to builder. | Native Apple ID-token exchange has no server authorization-code exchange. app_provider.dart deleteOwnAccount and 20261015172851_data_rights_export_and_deletion.sql:87 delete app/auth data without Apple revocation. Apple's account-deletion guide and Sign in with Apple revoke-tokens API require provider access/refresh tokens and a server-held client secret. | Fresh Apple reauthorization on deletion followed by authenticated server exchange/revoke, or secure server-side provider-token retention; neither can be implemented safely as a client-only RPC tweak. Do not store Apple secrets in Flutter or remove a provider to pass review. | Owner/Claude authorize and audit a separate backend flow plus paid credentials. Review existing deletion restrictions. Keep Apple activation/submission blocked until verified. Exact steps in OWNER_STEPS_IOS.md; no supabase edits. |
| ESC-3 | W11 | Public legal/support delivery and privacy content are not ready for iOS; site/account edits exceed W11 scope. | Live privacy.html/about.html HTTP 200 bodies are SHA-identical to Flutter bootstrap /; delete-account.html title is old Dalilk. Default in-app policy is short and Google-only. Hosted legal record was not inspected. APP_REVIEW_CHECKLIST.md records hashes/source lines. | Use the functioning internal reader during development; do not label HTTP 200 as policy proof or silently rewrite backend policy text. Separate public-site delivery, branding, complete disclosures and legal-record/fallback updates. | Owner/Claude repair public documents on the existing domain, publish complete EN/AR iOS-aware legal text, and authorize the fallback-text follow-up. Preserve Play launch work; no web/site/hosted settings changed here. Exact acceptance checks in OWNER_STEPS_IOS.md. |

## ESCALATION | 2026-10-17 | W18 push backend scope

| ID | WO | Blocker | Evidence | Options considered | Needed |
|---|---|---|---|---|---|
| ESC-4 | W18 | Future iOS push needs a backend migration; supabase/ is read only and paid APNs setup is deferred. W18 itself is spec only and complete. | 20260930010000_upcoming_live_schedules.sql:125 table CHECK and :170 register_schedule_push_device validation allow only android/web. Both reminder_push_service.dart:57,85 call sites also label native devices android. Later hardening retains own-row/banned-user restrictions and does not admit ios. No hosted state inspected. | Keep iOS Firebase/push disabled under D3/D4. In a separate authorized task add exactly ios to both backend validations and fix both Dart registration labels; audit token ownership/transfer, hardened grants, both dispatchers and Android/web regression. Do not edit historical SQL or relax RLS to mask registration failures. | Owner/Claude decide/authorize the separate migration and implementation. Owner later supplies APNs/Firebase account setup privately after choosing paid enrollment. Exact scope, source citations and acceptance matrix: IOS_PUSH_SPEC.md; owner actions: OWNER_STEPS_IOS.md. No backend, native or Dart code edited in W18. |

## ESCALATION resolution | 2026-10-18 | W19

| ID | WO | Resolution | Evidence | Still unverified | Needed |
|---|---|---|---|---|---|
| ESC-2 resolution | W19 | RESOLVED at E1 mocked/source scope under section 12. Backend-source prohibition withdrawn for this feature. | New Edge Function authenticates bearer user, exchanges native Apple code, verifies signed identity/nonce/audience against DB-owned Apple subject, revokes refresh token, then service-only records identity-version proof. New migration guards auth.users deletion, including direct existing RPC calls; missing/failed revocation fails closed. EN/AR errors and unchanged non-Apple deletion sequence tested. 16 mocked Node/crypto tests, 12 Flutter deletion tests; Deno 2.9.6 production-index type check passed. Full Flutter gate recorded in IOS_PROGRESS.md. | SQL was not executed; no hosted access, secrets, deploy, paid Apple authorization, real revocation or real deletion. Guard/grants/identity-race behavior needs staging DB tests; native Apple flow needs paid iPhone proof. Existing banned/broadcast/organization/Storage restrictions still need owner compliance review. | Owner audits and deploys function/secrets/new migration in the documented order before client release, then staging and device acceptance. OWNER_STEPS_IOS.md has exact names/commands and proof lifetime. W17 independently unblocked by section 12; ESC-4 push migration remains forbidden. |

## ESCALATION partial resolution | 2026-10-18 | W20

| ID | WO | Resolution | Evidence | Remaining public-site work | Needed |
|---|---|---|---|---|---|
| ESC-3 Dart resolution | W20 | In-app text/source gap resolved at E1; text is a counsel-review draft, not approved legal advice/compliance. | v1.1.0-ios-draft includes complete EN/AR terms/guidelines/privacy, Apple relay/provider/data/retention/YouTube/location/deletion/contact disclosures. Consent summaries updated; 1,895 catalog keys symmetric. Serialization/readers pass; full suite/analyzer in IOS_PROGRESS.md. No hosted legal record changed. | The public delivery gap is deployment of already-committed project/web/privacy.html, about.html and delete-account.html (5991d38), which belongs to Claude/owner. PUBLIC_PAGES_GAPS.md lists current local Google/Android wording and iOS additions/claim corrections for Claude before publication; no web edits or live access by builder. | Owner/counsel approve both languages, operator/retention/provider/support terms; Claude handles public copy and owner redeploys existing pages/routes, then verifies actual content and publishes matching hosted legal record. W19 deployment/native review still gate submission; W17 source remains unblocked under section 12. |

## VERDICT | 2026-10-18 | Claude (manager) | Pre-push audit of d5e4b6b, a0ebf8d, 63b288f, c4c81c2, afd862d, 663aee8 | **CHANGES REQUIRED**

Scope: W19 Apple deletion revocation, W20 legal drafts and gap list, W17 default-off publisher, Mac sequence. Builder reports were treated as claims. Read-only audit: no source fixed, no push, no hosted access, no migration executed, no secrets or signing material read. No evidence level is promoted: everything below stays E0/E1 (host and mocked only). Swift, SQL execution, SDK resolution, real Apple revocation and background behaviour are unverified.

### Commands actually run (this audit, Windows host)

| Check | Result |
|---|---|
| `flutter analyze` (project/) | exit 0, 0 issues (30.1 s) |
| `flutter test` (full, default flags) | exit 0, 1,159 passed / 0 failed / 0 skipped (05:44). Matches the builder's count; it is a fresh run |
| `flutter test --dart-define=IOS_PHONE_PUBLISHING=true test/ios_phone_publisher_test.dart test/ios_platform_ui_test.dart` | 28 passed, 0 failed |
| Same three iOS files without the flag (publisher, apple deletion, platform UI) | 32 passed, 0 failed |
| `npm test` in supabase/functions/apple-account-revocation (Node 22.19, mocked HTTP, generated in-memory keys) | 16 passed, 0 failed. `deno check` not re-run: Deno is not installed here, builder's Deno 2.9.6 check is unverified by me |
| `python -B ios/Publisher/test_configure.py` (Python 3.13.7) | 3 passed (idempotent, byte-reversible, anchor rejection, unmanaged xcconfig refusal) |
| i18n key symmetry (en/ar) | 1,897 / 1,897 keys, empty symmetric difference |
| `git diff --stat 5605451^ HEAD -- project/android project/web` | empty: Android and web tracked files unchanged since the iOS run began |
| Secret scan of d5e4b6b^..HEAD (private-key blocks, JWT-shaped strings, sbp_/AKIA tokens) | no hits; `node_modules` is gitignored and untracked |
| Viewer pbxproj scan | 0 matches for HaishinKit, remote package reference, packageProductDependencies, publisher markers; no `Publisher.generated.xcconfig`; the three Swift files are wholly inside `#if IOS_PHONE_PUBLISHING`; `CODE_SIGN_ENTITLEMENTS` only in Profile and Release; Flutter 3.41.2 has SwiftPM off by default (docs: on by default only from 3.44) |
| SDK facts checked at HaishinKit 2.2.5 | Package.swift: iOS 15, tools 6.0, Logboard 2.6.0 to <2.7.0 (exact 2.6.0 is compatible); `mamimumVideoBitRate` spelling and one-second `.status` ticks confirmed |

### Push blockers (small source or process fixes; none needs a Mac)

**P1 (High): camera and microphone purpose strings ship in the default viewer build.** `project/ios/Runner/en.lproj/InfoPlist.strings:4-6` and `ar.lproj/InfoPlist.strings:4-6` (added in c4c81c2) define `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`. That variant group is in the viewer Resources phase (`project.pbxproj:11,239`). iOS merges localized InfoPlist.strings into the bundle's info dictionary, so the viewer declares purposes for hardware it never uses. This contradicts the stated invariant, IOS_PUBLISHER_HANDOFF.md:16-18 ("no base-plist camera/mic key"), W3's rule, and IOS_STATUS.md row "Location and gallery permissions". Required fix: remove both keys from the shared strings files; supply them only through an opt-in resource that `configure.py --enable` selects and `--disable` restores byte-for-byte (or put non-localized English values in `Info-Publisher.plist`); extend `test_configure.py` to fail if the disabled project's strings resources contain either key; correct the three documents. Validation: grep of the disabled tree shows no `NSCamera|NSMicrophone|UIBackgroundModes`; helper tests green; enable then disable restores bytes.

**P2 (Medium): unsupported compliance label still shown to users, and the W20 status claim is false.** `en.json:707,735` and `ar.json:707,735` ("Privacy Policy (Saudi PDPL Compliant)", "PDPL KSA regulatory compliance" and Arabic equivalents) are the consent-dialog title (`lib/core/widgets/consent_dialog.dart:52`) and the Settings legal row (`legal_settings_section.dart:49-50`). W20 changed only a neighbouring key, while the new draft says it is not a compliance certification, and IOS_STATUS.md says "No unverified PDPL compliance ... promises". Required fix: neutral labels ("Privacy Policy", "How your data is used") in both catalogs, then correct the status line. Validation: no `PDPL`/`متوافقة` string in user-visible catalog values; symmetry test; consent and settings widget tests.

**P3 (Process): manager documents are not in Git, so a clone on the Mac will not contain them.** `brief/ios/IOS_PLAN_V2.md` (referenced by AGENTS.md, STATUS and every WO), `IOS_PLAN.md`, `CODEX_PROMPT_V2/V3.md`, `CODEX_START_PROMPT.md`, `OPUS_START_PROMPT.md` are untracked. The committed `IOS_LEDGER.md` is the stale template (D1 to D6 blank, cap 20 %); the decisions and G0 verdict exist only in the working copy. Required: owner commits, by explicit paths only, `IOS_LEDGER.md` (with this verdict) and `IOS_PLAN_V2.md` (plus the prompts they want on the Mac). Do not stage `.claude/`, `.vscode/`, `Core_files/*` drafts, evidence folders or `store/assets/icon_512.png`.

### Findings by severity (including non-blockers)

| # | Sev | Where | Failure scenario | Required fix | Validation | Gate |
|---|---|---|---|---|---|---|
| 1 | High | 20261017213039_apple_account_deletion_revocation.sql:8,23,38,65 | The identity "version" is `auth.identities.updated_at`. GoTrue's repeat sign-in writes only `identity_data` and `last_sign_in_at` (`tx.UpdateOnly(identity, "identity_data", "last_sign_in_at")`, internal/api/external.go) and pop's column-restricted update does not touch `updated_at` unless it is named. A second Apple sign-in during the ten-minute proof window therefore probably leaves the proof valid although a newer, unrevoked refresh token exists. The migration comment "Identity updates invalidate proof" is unproven. | Include `last_sign_in_at` (and a hash of `identity_data`) in the version tuple in all three places. | Staging pgTAP: record proof, sign in with Apple again, delete must be refused. I could not run SQL | Deployment (not push) |
| 2 | Medium | supabase/tests/ | The trigger, grants, expiry and stale-proof rules have no SQL test. The repo has a 30-file pgTAP suite (`data_rights.test.sql` exercises the same RPCs) and the builder added none; OWNER_STEPS only lists manual staging steps. Existing `rls_catalog` and `data_rights` expectations look unaffected by static review (new public functions are anon-revoked and pin search_path; no-Apple deletion path unchanged) but were not run. | Add `apple_deletion_revocation.test.sql`: refusal without proof, valid, expired (>10 min), stale version, wrong subject, mixed Apple+Google user, anon/authenticated cannot execute the two RPCs or read the table, non-Apple delete unchanged. | `npx supabase test db` locally by owner | Deployment |
| 3 | Medium | same trigger; admin_auth_account_action (20260923110000:98, 20260925100000:400); legal text and delete-account page | The BEFORE DELETE trigger also blocks administrator and support deletions of Apple-linked accounts (and dashboard or `auth.admin.deleteUser`), because no one but the user can produce Apple proof. Texts tell users to "email support" for completion, but no technical completion path exists. Rollback is clean (single transaction), so this fails closed, but it is an operational dead end. | Decide a break-glass route (for example a service-only, audited support RPC that states "provider revocation not performed") or make the copy say plainly that Apple-linked accounts must be deleted in the app. | Staging: admin delete of an Apple-linked test user behaves as designed; copy matches | Before submission |
| 4 | Info | rtmp_publish_engine; HadayahRtmpPublisher.swift | no defect found in Dart (bounded recovery verified: 120 s window, 10 attempts, `_failRecovery`, user stop and dispose send plain `stopStream`; only the 8 s watchdog sends `{retry:true}`; `onCancel` also stops the pipeline). Native is E0 only. | n/a | E3 matrix | Mac/iPhone |
| 5 | Low | PublisherPipeline.swift:152, 245-247, 312 | After an audio interruption (call, Siri) `dropped()` pauses transport but keeps `capturing == true`; the retry path calls `capture()` only `if !capturing`, so the AVAudioSession and mixer are never re-activated and a retry can publish with dead audio. Separately, the 8 s upload watchdog depends on `StreamBitRateStrategy` callbacks arriving every second; if they do not, every stream is dropped at 8 s and the loop exhausts. | Re-activate the audio session and verify mixer running at `start()`; add a native liveness fallback. | E3 rows 4 and 5 of the handoff | Mac/iPhone |
| 6 | Low | supabase_auth_service.dart:~75-90 | The access token is captured before the Apple sheet opens; if the sheet stays open past expiry the function returns 401 and the user sees a generic failure. | Read the current session again after the sheet. | Unit test with a rotated session | Optional |
| 7 | Low | app_provider.dart (`appleLinked`) | Client-side identity list is OR-ed with the server flag; a stale client could force a revocation attempt that the server answers with a mismatch. Fail-closed, so only a usability issue. | Prefer the server flag when present. | Existing deletion tests | Optional |
| 8 | Low | terms_and_conditions_model.dart privacy §9 | Export is described as "Settings > Privacy"; the control is "Download My Data" in the privacy section. Support contact is the owner's personal Gmail (`AppIdentity.supportEmail`). Draft is also the default fallback for the Android build; it is explicitly marked draft. | Use the exact control name; owner decides the public support address before submission. | Counsel review | Counsel/owner |
| 9 | Low | MAC_SETUP.md M1-M3 script | `set -e` with `flutter doctor -v` aborts on any non-zero doctor row (for example a missing Android toolchain) although the comment says other platforms are independent. | `flutter doctor -v || true` plus an explicit iOS-row check. | Owner run on the Mac | Mac |
| 10 | Low | pubspec.yaml | `enable-swift-package-manager` is not pinned false. A Flutter 3.44+ upgrade would auto-migrate and `configure.py --enable` would refuse (fail-safe). | Pin or document. | none | Optional |

### Area summaries

**W19: fail-closed Apple revocation: sound in structure, two deployment gaps.** Verified by reading: bearer user authenticated through `auth.getUser`; Apple subjects come from `auth.identities` (DB-owned), never from the client; authorization-code exchange with ES256 client secret (issuer team, subject client id, audience Apple, 5-minute expiry); id_token checked for RS256 signature against Apple JWKS, issuer, audience, `exp`/`iat`/`nonce`, `maxTokenAge`; subject must equal a DB identity; refresh token revoked before proof is recorded; any thrown or non-200 provider response returns a fixed code with no upstream text; missing secrets give 503 before provider traffic. SQL: service-role-only RPCs, proof table fully revoked, advisory lock shared with the existing deletion lock, BEFORE DELETE trigger covers the existing `delete_own_account` and admin deletes so Dart bypass fails, whole transaction rolls back before any SQL data loss. Dart: revocation happens before Storage removal, account switches are re-checked on both sides, EN/AR messages exist. Honest limits: Apple revocation, Storage removal and SQL deletion are separate, documented in OWNER_STEPS item 9 and the legal text. Gaps: findings 1 to 3. The 16 Node tests assert real failure behaviour (call order, no Apple traffic on bad auth or config, sanitized errors); `index.ts` wiring and all SQL are untested.

**W20: legal drafts: consistent with the code, two exceptions.** Both languages are complete and key-symmetric, explicitly draft for counsel, no instant-erasure, retention-deadline, ad-free or security guarantees; Apple relay, Google, YouTube, location (no background location, matches the Android manifest), deletion and revocation limits match W19 and the source. Exceptions: P2 and finding 8. `project/web` was not touched in any of the six commits; `PUBLIC_PAGES_GAPS.md` line references and quoted claims (no advertising, immediate deletion, 30 days, "coming to Google Play") match the committed pages. Publication, counsel approval and redeployment remain owner/Claude work; source completion is not approval.

**W17: default-off isolation: holds except P1.** Dart flag defaults false; Android behaviour paths are unchanged; viewer pbxproj, Podfile and plist are clean apart from P1; Flutter plugins stay on CocoaPods; `configure.py` pins HaishinKit 2.2.5 and Logboard 2.6.0, selects alternate plist and privacy manifest (manifest adds exactly the AudioData row), never touches signing, refuses unmanaged state, is byte-reversible per test; Debug has no entitlement; native commit c4c81c2 is separable from Dart commits 63b288f and afd862d. Direct entry rejects before camera or microphone calls. Channel-OAuth and push gates are untouched. Swift was read for logic only; it has never been compiled.

### Gates, separated

* **Push blockers:** P1, P2, P3 above. After they are fixed, re-run analyze, full test, the helper test and the key-symmetry check.
* **Later, deployment (owner):** findings 1 to 3 before deploying the function and migration; secrets, staging SQL tests, real revocation and deletion with a paid iPhone.
* **Later, Mac and iPhone:** M1 to M3 viewer gates with the publisher off; then handoff matrix for W17 (findings 4, 5, 9); E2, E2S and E3 only with real evidence.
* **Later, counsel and submission:** counsel approval of both languages, hosted legal record, public-page edits by Claude and redeployment by the owner, support path (finding 3), paid Apple enrollment (D4), store pack and review notes. Paid enrollment is not needed to approve a source push.

## VERDICT follow-up | 2026-10-18 | Claude | P1 and P2 fixed on owner instruction (uncommitted, owner commits)

P1: camera/microphone purposes removed from `Runner/en.lproj` and `ar.lproj` InfoPlist.strings (restored to the pre-c4c81c2 three keys); the opt-in copies live in `Runner/PublisherStrings/{en,ar}.lproj/InfoPlist.strings`; `configure.py` swaps the two variant-group paths on `--enable`/`--disable`, validates both string sets, and `test_configure.py` gained a viewer-resource test (4 tests pass; enable then disable on the real tree restores project.pbxproj byte-for-byte, no Publisher xcconfig left). P2: `settings.view_privacy` and `view_privacy_subtitle` relabelled "Privacy Policy" / "How your data is used" (Arabic equivalents); `settings_screen_test.dart` updated. Re-run: analyze 0 issues; full `flutter test` 1,159 passed / 0 failed; flag-on iOS files 28 passed; catalogs 1,897 symmetric; viewer Info.plist and strings contain no NSCamera/NSMicrophone/UIBackgroundModes. P3 remains an owner action (commit IOS_PLAN_V2.md, the prompts you want on the Mac, and this ledger by explicit path). Findings 1 to 10 are unchanged and stay deployment/Mac/counsel gates. Verdict now: READY TO PUSH once P1/P2 changes and P3 documents are committed. Still E1 only; no level promoted.

## VERDICT | 2026-10-18 | Claude (manager) | Audit of W21 commit 50a9516 (on 6620467, d336e1f) | **CHANGES REQUIRED (one small copy item), otherwise ready**

Fresh host results (my runs, not reused): `flutter analyze` exit 0, 0 issues (26.9 s); full `flutter test` exit 0, 1,261 passed / 0 failed (05:05); `npm test` Edge 16/16; `python -B ios/Publisher/test_configure.py` 4/4; Android/web tracked diff since 663aee8 empty; viewer Info.plist and en/ar InfoPlist.strings contain no NSCamera/NSMicrophone/UIBackgroundModes; viewer pbxproj has no HaishinKit/remote package/PublisherStrings; no Publisher xcconfig. SQL, Swift, SDK resolution and doctor fixtures were not re-run by me. No evidence level promoted: Swift E0, everything else E1.

**Push blocker W21-1 (Medium): new deletion copy promises a support service that does not exist and is wrong for some users.** en/ar `delete_account_blocked_apple_revocation_*` promise support help to complete in-app deletion. No such process is designed or staffed (finding 3 is still open). `delete_account_blocked_account_restricted` now tells every user, including Android and non-Apple users, about Apple-linked accounts, and for a restricted (banned) Apple-linked account the in-app route is itself blocked by `account_restricted`, so the advice is a dead end. The same promise is in the terms/privacy draft sections 7 and 9 and PUBLIC_PAGES_GAPS.md. Fix: say only that an Apple-linked account is deleted inside the iOS app with fresh Apple authorization and that support can explain what is blocking; no promise of a support deletion service; keep the restricted message platform-neutral and add a separate Apple-specific sentence only where the account is Apple-linked.

Findings (non-blocking): W21-2 Low: shared strings changed for Android too (`delete_account_desc`, confirm button, phone broadcasting copy); grep store/ and brief/launch/ for the old wording and report stale screenshots or listing text (do not edit Play work). W21-3 Low (E3): the new audio-append watchdog fallback only guards stalls before the first network report; local audio continues during a dead connection, so it cannot detect an upstream stall; the new `startCapturing`/`isRunning`/`setActive` calls match the 2.2.5 MediaMixer source (actor `isRunning`, async `startRunning`, sync `startCapturing`) but behaviour after a real interruption is unproven. W21-4 Low: the 96-case sweep is genuine (real fonts, no suppressed errors, `takeException` null, EN/AR, scales 1.0/1.5, insets 59/34) but covers no landscape, no keyboard inset, no text scale above 1.5, no VoiceOver or tap-target guidelines, and only one pump at 300 ms. W21-5 Info: the API table and PRIVACY_MANIFEST_AUDIT.md are well sourced and correctly leave archive-level checks (package_info_plus empty SDK reasons, Firebase pods, native-assets packages) to the Mac; cited line numbers I spot-checked were accurate. W21-6 Process: IOS_LEDGER.md is still uncommitted; commit it with this verdict.

## W22 builder follow-up | 2026-10-18 | Codex | source/host only

W21-1 corrected: factual EN/AR Apple refusals, neutral restricted message and
conditional Apple-linked guidance, with provider/localized tests. No support
deletion service or break-glass function is promised. W21-2 impact report and
W21-4 layout/accessibility extension are committed in W22; W21-6 is addressed
by including this ledger and its pending manager verdicts. The obsolete literal
promise in the historical W21-1 paragraph is paraphrased; the finding is retained.

Final fresh checks: analyzer 0 (45.4s), full Flutter 1,463/1,463 (05:17), Edge
16/16, configure 4/4, CI host fixtures 3/3; catalog symmetry 1,898; viewer
isolation and 65 Android/web current-byte hashes pass. Detailed failures/fixes
and A-H evidence are in IOS_PROGRESS.md. This is a builder closeout, not a new
manager audit or native pass. Swift E0, Dart/host E1 only. W21-3, support design,
SQL/real provider acceptance and ESC-4 remain deferred. No push/deploy/hosted action.

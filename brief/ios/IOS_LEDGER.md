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
| D1 | iOS bundle ID | | |
| D2 | iPhone on iOS 17+ available? | | |
| D3 | First iOS scope | | |
| D4 | Apple Developer Program enrollment timing | | |
| D5 | CI provider | | |
| D6 | Minimum iOS deployment target | | |
| CAP | Codex weekly ceiling | 20%, owner reply: "use up to 20%" | 2026-10-11 |

## Work order status

| WO | Phase | Status | Commit | E-level | Gate |
|---|---|---|---|---|---|
| WO-0 Recon | 0 | DONE, awaits G0 | `master^{/record WO-0 recon}` | unawarded; G0 pending | G0 pending |
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
| G0 | | | |
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

## ESCALATION | 2026-10-17 | W11 submission blockers

| ID | WO | Blocker | Evidence | Options considered | Needed |
|---|---|---|---|---|---|
| ESC-2 | W11 | Apple account deletion needs token revocation; backend/secret work is forbidden to builder. | Native Apple ID-token exchange has no server authorization-code exchange. app_provider.dart deleteOwnAccount and 20261015172851_data_rights_export_and_deletion.sql:87 delete app/auth data without Apple revocation. Apple's account-deletion guide and Sign in with Apple revoke-tokens API require provider access/refresh tokens and a server-held client secret. | Fresh Apple reauthorization on deletion followed by authenticated server exchange/revoke, or secure server-side provider-token retention; neither can be implemented safely as a client-only RPC tweak. Do not store Apple secrets in Flutter or remove a provider to pass review. | Owner/Claude authorize and audit a separate backend flow plus paid credentials. Review existing deletion restrictions. Keep Apple activation/submission blocked until verified. Exact steps in OWNER_STEPS_IOS.md; no supabase edits. |
| ESC-3 | W11 | Public legal/support delivery and privacy content are not ready for iOS; site/account edits exceed W11 scope. | Live privacy.html/about.html HTTP 200 bodies are SHA-identical to Flutter bootstrap /; delete-account.html title is old Dalilk. Default in-app policy is short and Google-only. Hosted legal record was not inspected. APP_REVIEW_CHECKLIST.md records hashes/source lines. | Use the functioning internal reader during development; do not label HTTP 200 as policy proof or silently rewrite backend policy text. Separate public-site delivery, branding, complete disclosures and legal-record/fallback updates. | Owner/Claude repair public documents on the existing domain, publish complete EN/AR iOS-aware legal text, and authorize the fallback-text follow-up. Preserve Play launch work; no web/site/hosted settings changed here. Exact acceptance checks in OWNER_STEPS_IOS.md. |

## ESCALATION | 2026-10-17 | W18 push backend scope

| ID | WO | Blocker | Evidence | Options considered | Needed |
|---|---|---|---|---|---|
| ESC-4 | W18 | Future iOS push needs a backend migration; supabase/ is read only and paid APNs setup is deferred. W18 itself is spec only and complete. | 20260930010000_upcoming_live_schedules.sql:125 table CHECK and :170 register_schedule_push_device validation allow only android/web. Both reminder_push_service.dart:57,85 call sites also label native devices android. Later hardening retains own-row/banned-user restrictions and does not admit ios. No hosted state inspected. | Keep iOS Firebase/push disabled under D3/D4. In a separate authorized task add exactly ios to both backend validations and fix both Dart registration labels; audit token ownership/transfer, hardened grants, both dispatchers and Android/web regression. Do not edit historical SQL or relax RLS to mask registration failures. | Owner/Claude decide/authorize the separate migration and implementation. Owner later supplies APNs/Firebase account setup privately after choosing paid enrollment. Exact scope, source citations and acceptance matrix: IOS_PUSH_SPEC.md; owner actions: OWNER_STEPS_IOS.md. No backend, native or Dart code edited in W18. |

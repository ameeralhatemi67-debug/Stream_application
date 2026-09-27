# Hadayah manager task board

Snapshot observed 2026-09-27 at 10:31–10:32 +03:00, Asia/Riyadh. Refresh this board before making a dependency or release decision. A chat being idle/not loaded is not proof that its task finished. All repository-relative paths below are relative to `C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app` unless a worktree is named.

Takeover refresh: INT-01 completed at 2026-09-27T05:06:24+03:00, confirmed by its completed turn and final response, not inferred from idle status. Source `34d074a`, final evidence tip `8e28801`; no local master merge. Its combined Hadayah Test candidate is diagnostic. Physical testing remains paused. The prior 02:50 running snapshot is preserved in EVENT_LOG H13. Earlier core-document running statements describe that historical snapshot; use this board for current execution.

Owner confirmed the same final output at the 10:36 +03:00 refresh; INT-01 remains idle/completed and both Git tips are unchanged. Next recommended work is the focused CFG-01 setup and configured build, then W00 and smoke W02–W06. No task was dispatched. A master merge is not a prerequisite for testing the recorded integration candidate. Independent diagnostic offline-map checks are possible, but the full signed-in/streaming acceptance run remains paused. STREAM-D8 needs a separate focused follow-up before release; it does not prevent collecting otherwise valid configured smoke evidence.

At 10:47 +03:00 the owner reported opening the app on a phone and seeing no upgraded map. Installed build/package or launch source is unknown; this is not yet evidence of a regression in INT-01. Git confirms both source tips are ancestors of the integration branch, neither of master. Combined merge `c700589` has parents `818cc12` and `74157ba`; integration tip remains `8e28801`. Before any further owner testing, identify what is actually installed/launched and provide the combined candidate with its required configuration. Do not count this phone observation as a new combined-candidate test.

## Current dispatch and testing state

| ID | Owner / task | State and evidence | Branch / working location | Dependency and next action |
|---|---|---|---|---|
| INT-01 | Astra Xhigh: combined streaming/map audit, repair, integration and consolidated Wave4v2 pack | IMPLEMENTATION/LOCAL VERIFICATION COMPLETE; NOT MERGED; NOT ACCEPTED. Final handoff inspected. Source `34d074a`, tip `8e28801`; critic cycle 2 reached provisional 8/8/8/8. Reports 847 Flutter tests, analysis 0, 462 SQL assertions, 3 concurrency checks and builds passing. | `codex/hadayah-wave4v2-integration`; `C:/Users/User/.codex/worktrees/hadayah-wave4v2-integration/Streamer_app`; clean at refresh | CFG-01 then configured candidate W00/smoke. Preserve committed result; any local promotion needs owner-document reconciliation. No follow-up dispatched. |
| STR-02 | Astra: camera/landscape follow-up | IMPLEMENTATION COMPLETE; physical acceptance open. Source `ddcb521`, evidence tip `818cc12`; reported 730 tests, analysis 0, APK/web builds. Prior critic score does not cover this changed source. | `codex/p6s-wave4v2-repair`; `C:/Users/User/.codex/worktrees/p6s-wave4v2-repair/Streamer_app` | Already supplied to INT-01. Do not ask owner to test this separate candidate while integration is active. |
| MAP-01 | Opus: three-city offline map upgrade | IMPLEMENTATION COMPLETE / NEEDS WORK. Source `a57dda7`, tip `74157ba`; critic 8/7/8/8 after 3 rounds; reported 734 tests and analysis 0. Selected-card overflow remains in this branch. | `codex/tricity-map-upgrade`; `C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app` | INT-01 owns repair/audit. Opus is not currently running on this task. |
| TEST-02 | Owner: Wave4v2 physical acceptance | PAUSED by owner after camera/layout problems and build-identity confusion. All 36 combined candidate cases remain NOT RUN. | Historical sheets stay in STR-02 worktree. Combined `WAVE4V2_RETEST_SCRIPT.md` and results now delivered in INT-01 evidence pack. | CFG-01 and rebuilt identified candidate, then W00 and short smoke. Do not resume the old separate builds or treat diagnostic artifacts as configured acceptance. |
| TEST-01 | Owner: Wave 4 / E4 | RUN COMPLETED, with failures, qualifications and explicit scope deferrals. This was not checkpoint acceptance. | `brief/evidence/2026-09-26/p6s-astra-audit/E4_ACCEPTANCE_RESULTS.md` and `SCREENSHOTS_AUDIT.md` | Preserve exact owner text and images. Read observations beneath PASS headings. Link impacted cases into TEST-02. |
| STR-01 | Astra: original Wave4v2 repair | IMPLEMENTATION COMPLETE / NEEDS WORK. Source `5162add`, pack `23cfa66`; critic 8/7/7/7; reported 722 tests. | Ancestor of STR-02 on the same repair branch | Historical input; superseded by STR-02, then INT-01 when delivered. |
| BASE-01 | Astra: audit of Opus streaming wave 3 | LOCALLY MERGED into `master` at `7b54cb5`; not release approval. Recorded 695 tests, 440 SQL assertions, 3 concurrency cases, builds. | `master`, audit branch retained | Last confirmed main baseline. INT-01 may conditionally advance local master; verify current state before reporting it. |
| CFG-01 | Owner; setup follow-up unassigned | BLOCKED ON DEDICATED SETUP. INT-01 found no documented authorized acceptance configuration and delivered its README checklist. No provisioning performed by this manager. | [Actual owner reply](prompts/INT-01_CONFIG_REPLY.md); INT-01 README in its worktree | Dedicated Google OAuth/test users, YouTube test channel/event and restricted API key, local roles/redirects and phone routing; securely configure and rebuild from reviewed source. Never substitute production credentials. |
| MGR-02 | Codex: successor manager and testing companion; exact model/effort not independently exposed | ACTIVE management owner from 2026-09-27 10:32 +03:00. Takeover, current state and final response recorded. | Main checkout; chat `Resume Hadayah project management`, `01a0e1c5-0499-7c30-b811-3d06090da442`, host `local` | Maintain management records after meaningful events. Read-only review/documentation authority; no implementation, messaging, provisioning or merge assignment inferred. |

## INT-01 delivery and manager verification

- Assignment remains [the dispatched prompt](prompts/INT-01_ASTRA_INTEGRATION.md), dispatched 02:27:57 +03:00. [Exact final response and retrieval provenance](prompts/INT-01_FINAL_RESPONSE.md). Base `7b54cb5`; combined source merge `c700589`; tested source `34d074a5c577cd35944813f0a3db5315f4c85e96`; final `8e2880102a9369d4d42d9c25910a87f6ec641857`.
- File ownership covered combined streaming/native, map/offline, provider/application/localization, two additive migrations and its evidence pack under the existing prompt. No current implementation writer is confirmed. Opus completion remains owner/evidence-reported because no Opus chat ID is available. STR-02 completed turn was independently refreshed.
- Manager read README, HANDOFF, VERIFICATION, CRITIC_REVIEW, CLOSURE_MATRIX and Flutter summary. Recomputed APK SHA-256 `576ee96a860b5bcc1b5bde1c7875ee31f31943062c8cb6bd071482453c158b99` and web archive SHA-256 `720fa376cdc9a9f4a4b7c6b4fe50aa972bb0c9b84c217409bdb3feadfd709d57`, both matching delivery. Git project/supabase trees are identical between tested source and final tip. This is an evidence/identity review, not a new source audit or rerun of executable tests.
- Identity: Hadayah Test, package `sa.hadayah.streamer_app.wave4v2`, web build `34d074a-local-diag-1`; configuration is diagnostic with no Google provider/YouTube key. Disposable backend `Hadayah_integration_20260927`, API56021/DB56022, reported stopped with backup. No secret configuration file was read.
- Reported repairs include populated map-card/short-screen overflow, missing-location truthfulness, application/organization location persistence and application-versioned atomic offline updates. Source review used 2 of 3 allowed cycles; all scores remain provisional for physical/backend acceptance. Earlier failures and source-branch review scores remain historical.
- Local merge is pending because protected STATUS, LEDGER, issue log and skill log overlap incoming documentation. The integration agent reports preserving 1,214 files plus both stashes/source branches; this manager independently checked refs/stash IDs and current statuses, not all protected hashes. Source worktrees each retain three modified generated Windows plugin files; no cleanup performed.
- Delivery is complete, but closure of TEST-02/P5/P6/P6S still requires configured fresh evidence and explicit resolution of open requirements. STREAM-D8 stays HIGH. Physical media, ANR/performance, audio camera release/background behavior, accurate boundaries and unapproved mode/scope exclusions remain open.

## Chat identities

- INT-01: exact title **Integrate Hadayah streaming and map**, thread `01a0e00b-e1d8-7333-8fb1-b4086ea2677e`, host `local`. [Dispatched assignment](prompts/INT-01_ASTRA_INTEGRATION.md).
- STR-01/STR-02: exact title **Repair P6/P6S Wave 4v2**, thread `01a0df0d-277f-7762-a6ef-131678d0b20a`, host `local`; observed idle after completion.
- Previous manager: **Review Streamer app test status**, thread `01a0d4f9-d32c-73e2-8cf3-faebcd5ea0d5`, host `local`.
- Opus runs outside the observed Codex chat list. No verified Opus chat ID; use branch/evidence and owner reports, not an invented ID.

Use `wait_threads` with timeout 0 for a compact current snapshot; read a thread only for needed details. Record last checked time separately from reported completion time. Do not message other chats or start monitoring automations without owner authorization.

## Evidence locations to read when results arrive

- INT-01 delivered output, in its worktree: `brief/evidence/2026-09-27/hadayah-wave4v2-integration/`. Final pack at `8e28801`; start with README, then W00 only after configuration/build readiness.
- STR-02: `brief/evidence/2026-09-27/p6s-camera-landscape/` in its worktree. Read README, REPAIR_REPORT, NATIVE_PROBE, HANDOFF, VERIFICATION and P6_P6S_CLOSURE_MATRIX.
- STR-01: `brief/evidence/2026-09-26/p6s-wave4v2/` in that same worktree.
- MAP-01: `brief/evidence/2026-09-26/p5-tricity-map-upgrade/` in its worktree. Use its dated HANDOFF_TO_ASTRA.md. The worktree-root handoff is stale streaming material.
- Research, in main: `brief/research/p6s-streaming-architecture/` and `brief/research/p5-tricity-map-upgrade/`. Some documents are untracked and absent from isolated checkouts.
- Earlier manager review: `brief/evidence/2026-09-26/p6s-manager-review.md`. Its main-checkout G11a finding differs from the isolated audit's clean gates; do not conflate scopes.

## Integration issues to check in the final result

- Native upright output in both landscape directions, actual capture geometry and continuous session; poor emulator frames/System UI ANR are still unresolved evidence, not proven hardware failure or success.
- Three tap-toggle sender controls; landscape read-only chat/editing for every role; drafts retained; scrollable sheets; front-camera Coming Soon.
- Map selected-card overflow, touch targets and RTL/large text; no distance/directions to 0,0.
- Offline readiness tied to application version as well as pack; interrupted cache promotion, worker restart and concurrent tabs. Earlier manager findings were source risks, not reproduced runtime defects.
- Three-city scope, honest missing municipal boundaries, required attribution and real phone offline/performance evidence.
- Shared provider, channel application fields, en/ar catalogs and Gradle test identity. Check map/live interactions even where files do not overlap.
- One clearly labelled Hadayah Test build and a matching source/configuration/backend identity. Old `Streamer Wave4v2` and maptest builds are diagnostic history, not separate products.
- D8 YouTube server authorization remains HIGH and release-blocking. The integration assignment explicitly leaves this blocker open; source merge will not close it.

## Coordination protocol

For each new task assign a stable ID. Record agent/model, exact chat title/ID when known, prompt path/version, dispatch confirmation/time, scope and files owned, branch/base/tip/worktree, prerequisites, expected output, review count, allowed actions, response summary/evidence, last observed time, next action and closure condition. Use an explicit unknown where information is missing.

Track execution, review, integration and physical acceptance separately. A completed implementation may still need repairs; a merged branch may remain unaccepted. A prepared prompt is DRAFT until the owner or chat confirms it was sent. Update only the task addressed by new evidence; never mark other running tasks finished by implication.

Before assigning work, check for active writers and dependencies. Parallelize independent documentation/research or clearly isolated work; sequence edits to shared providers, native media, schema and translations when conflict risk outweighs the benefit. Commit/code freezes and test candidate identities must be explicit. Never silently change the build beneath an active owner test run.

Update this board plus [EVENT_LOG.md](EVENT_LOG.md) after every dispatch, question/reply, result, review, merge, testing start/pause/completion or scope decision. Use [RELEASE_SCOPE.md](RELEASE_SCOPE.md) for deferrals and gates. Archive exact new prompts and substantive replies under `prompts/`. Avoid copying giant build logs; link their evidence.

Only one manager should write these management records at a time. The owner has authorized the 2026-09-27 updates to main STATUS/progres/Roadmap/plan/ledger while INT-01 is running. These are intentional owner-directed documentation changes, not drift to erase when INT-01 checks preservation. Compare and retain them; do not waive unrelated hash changes.

## Protected baseline

At this snapshot master is `7b54cb5e565011c33dcd03351735b7cc45a0926a`. Stashes are `d646b945d0007d55ec52690f1ca085a3879ccab8` and `d53c178e116328e8c3d349f36af795733dc31ee4`. Main has pre-existing modified documents and untracked evidence. No source edits, branch moves, installs, DB operations or tests were performed by this management handoff.

Preserve owner files and active checkouts. No broad reset/clean/stash, production define-file reads, pushes, hosted operations or worktree cleanup by inference. Conditional local merge belongs to INT-01 under its dispatched prompt.

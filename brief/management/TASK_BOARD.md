# Hadayah manager task board

## Current UI adjustment, 2026-09-27

FIX-02: Owner screenshots show restored map pins and an open profile card; profile-editor retest remains unreported. Owner requests drawer control aligned with OpenStreetMap attribution, expand control hidden for now, and a consistent responsive card capped on desktop. Implemented directly on master after `0f7d474`. Usage baseline 54% of the weekly window; owner permits at most 3 additional percentage points (57% ceiling), checked through the app meter. No delegation or new branch. Card uses available width with 16px side margins and a 420px cap, fixed content order/full-width primary action, and scrolling in short viewports. Attribution and drawer share a row with wrapping credit. Analyzer is clean; expanded 280–1280px, en/ar, 1–2x text and all stream-state matrix passes; complete suite passed: 905 tests in eight disjoint file batches. [Verification](../evidence/2026-09-27/map-card-ui/VERIFICATION.md). Physical confirmation pending.

## Current repair, 2026-09-27

Owner is doing exploratory testing on the upgraded map and explicitly requested repairing missing map/drawer profiles and the Edit Account Profile `cs_tech` dropdown crash together. MGR-02 has implemented FIX-01 directly on main master, based on pushed snapshot `e820119`. No new branch, duplicate agent assignment or hosted data operation. The repaired source has passed fresh verification: 851 Flutter tests across all eight disjoint shards and analyzer zero issues. See [FIX-01 evidence and owner retest](../evidence/2026-09-27/map-profile-repair/README.md). Physical confirmation remains pending. P5/P6 remain NOT ACCEPTED and P6S INCOMPLETE / NOT ACCEPTED.

Owner clarified that every profile is missing from Spatial Map/drawer while Admin/Discovery still show them, and supplied two existing saved pins: `(26.3050, 50.1450)` and `(26.2172, 50.1971)`. The repair targets shared catalog eligibility, not those individual records. Code inspection shows the strict city-name filter excludes legacy blank-city records with valid pins; live backend rows have not been inspected, so whether this explains every reported profile remains to be confirmed in the owner retest. The dropdown failure is independently reproduced by a saved category absent from its fixed items.

## Previous integration and setup snapshots

Snapshot observed 2026-09-27 at 10:55 +03:00, Asia/Riyadh. **Local master now contains the full combined map/streaming work**, merge `c9e441f`, after owner preservation commit `571bcdd`. No new branch was created. Source exactly matches tested integration `34d074a` / final `8e28801`; both source tips are ancestors of master. MGR-02 performed the owner-requested local merge, with no new implementation. No implementation agent is running on this assignment.

TEST-02 remains paused pending a full rebuild/relaunch from main `project/` and configuration/build confirmation. The merge did not update the installed phone app, configure Google/YouTube or operate a backend. CFG-01 remains the next acceptance dependency. No push was performed. The earlier handoff and agent report accurately describe the state before this merge.

Owner explicitly keeps testing paused while repository/worktree confusion is explained. A read-only inventory after the merge reconciles the screenshot's 118 changes exactly: main has 102 untracked research/evidence/prompt files and zero modified tracked files; other checkouts have 12 generated Windows plugin files, 3 generated Android build reports and 1 untracked G11a review note. Repeated `Streamer_app` labels are folder names for separate worktrees, not duplicate branch names. Main is on master with the combined code; screenshot 1's active repository indicator is the old `p6-accept` / `p6-acceptance` checkout, so the editor context and actual launch target must not be assumed to be main. No worktree or branch cleanup authorized/performed in this explanation.

Owner subsequently authorized pushing master as a cloud reference before testing. On 2026-09-27 at approximately 11:12 +03:00, normal push to `https://github.com/ameeralhatemi67-debug/Stream_application.git` advanced remote master from `aedff5e` to `df763da`. No force, other-branch push or new deployment command. The 102 untracked files remain local and are not included. Test README/script now point to main master; their original diagnostic artifact identities remain historical. This documentation update will be pushed as a follow-up to the recorded snapshot. W00/configuration and actual installed-build readiness still gate testing.

## Current dispatch and testing state

2026-09-27 11:23 +03:00 update: owner reports Chrome launches; phone build fails before launch. BUILD-01 is a confirmed host-memory blocker, not an accepted/rejected physical app test. JVM fatal log identifies native memory exhaustion with 233 MiB RAM / 38 MiB system commit available at failure. Recovery requires freeing host memory and retrying; no successful Android rebuild is recorded. [Diagnosis](../evidence/2026-09-27/android-build-memory/DIAGNOSIS.md). Configuration/backend identity remains unverified; the owner's local configuration was not inspected.

| ID | Owner / task | State and evidence | Branch / working location | Dependency and next action |
|---|---|---|---|---|
| FIX-01 | MGR-02: missing map profiles and profile-editor crash; explicit owner repair request | LOCAL REPAIR VERIFIED / OWNER RETEST PENDING. 851 Flutter tests PASS; analyzer zero issues. Shared map eligibility preserves exact legacy pins in the existing overview without inventing city metadata; editor retains saved category IDs with unique dropdown entries. | Main master, base `e820119`; map catalog/models, application sheet and regression tests. No external dispatch; review cycle not commissioned. | Verification complete; owner restarts app from main and checks pin selection, drawer selection and Edit Account Profile. Closure requires owner confirmation; no acceptance PASS inferred. |
| BUILD-01 | MGR-02 diagnosis; owner host recovery | BLOCKED ON HOST MEMORY. JVM native allocation failure confirmed; no source defect assigned. | Main master `e820119`; phone SM-S936B; failure 11:20 +03:00 | Save/close unnecessary sessions or restart Windows, then retry Android build from main. Closure requires actual successful build/launch; no process termination or build-setting change performed. |
| INT-01 | Astra Xhigh: combined streaming/map audit, repair, integration and consolidated Wave4v2 pack | IMPLEMENTATION/LOCAL VERIFICATION COMPLETE; LOCALLY MERGED at `c9e441f`; NOT ACCEPTED. Final handoff inspected. Source `34d074a`, tip `8e28801`; critic cycle 2 reached provisional 8/8/8/8. Reports 847 Flutter tests, analysis 0, 462 SQL assertions, 3 concurrency checks and builds passing. | `codex/hadayah-wave4v2-integration`; `C:/Users/User/.codex/worktrees/hadayah-wave4v2-integration/Streamer_app`; clean at refresh | Local promotion completed by MGR-02 under the owner request. CFG-01 then a rebuild from master, W00/smoke. No agent follow-up dispatched. |
| STR-02 | Astra: camera/landscape follow-up | IMPLEMENTATION COMPLETE; physical acceptance open. Source `ddcb521`, evidence tip `818cc12`; reported 730 tests, analysis 0, APK/web builds. Prior critic score does not cover this changed source. | `codex/p6s-wave4v2-repair`; `C:/Users/User/.codex/worktrees/p6s-wave4v2-repair/Streamer_app` | Already supplied to INT-01. Do not ask owner to test this separate candidate while integration is active. |
| MAP-01 | Opus: three-city offline map upgrade | IMPLEMENTATION COMPLETE / NEEDS WORK. Source `a57dda7`, tip `74157ba`; critic 8/7/8/8 after 3 rounds; reported 734 tests and analysis 0. Selected-card overflow remains in this branch. | `codex/tricity-map-upgrade`; `C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app` | INT-01 owns repair/audit. Opus is not currently running on this task. |
| TEST-02 | Owner: Wave4v2 physical acceptance | PAUSED by owner after camera/layout problems and build-identity confusion. All 36 combined candidate cases remain NOT RUN. | Historical sheets stay in STR-02 worktree. Combined `WAVE4V2_RETEST_SCRIPT.md` and results now delivered in INT-01 evidence pack. | CFG-01 and rebuilt identified candidate, then W00 and short smoke. Do not resume the old separate builds or treat diagnostic artifacts as configured acceptance. |
| TEST-01 | Owner: Wave 4 / E4 | RUN COMPLETED, with failures, qualifications and explicit scope deferrals. This was not checkpoint acceptance. | `brief/evidence/2026-09-26/p6s-astra-audit/E4_ACCEPTANCE_RESULTS.md` and `SCREENSHOTS_AUDIT.md` | Preserve exact owner text and images. Read observations beneath PASS headings. Link impacted cases into TEST-02. |
| STR-01 | Astra: original Wave4v2 repair | IMPLEMENTATION COMPLETE / NEEDS WORK. Source `5162add`, pack `23cfa66`; critic 8/7/7/7; reported 722 tests. | Ancestor of STR-02 on the same repair branch | Historical input; superseded by STR-02, then INT-01 when delivered. |
| BASE-01 | Astra: audit of Opus streaming wave 3 | LOCALLY MERGED into `master` at `7b54cb5`; not release approval. Recorded 695 tests, 440 SQL assertions, 3 concurrency cases, builds. | `master`, audit branch retained | Last confirmed main baseline. INT-01 may conditionally advance local master; verify current state before reporting it. |
| CFG-01 | Owner; setup follow-up unassigned | BLOCKED ON DEDICATED SETUP. INT-01 found no documented authorized acceptance configuration and delivered its README checklist. No provisioning performed by this manager. | [Actual owner reply](prompts/INT-01_CONFIG_REPLY.md); INT-01 README in its worktree | Dedicated Google OAuth/test users, YouTube test channel/event and restricted API key, local roles/redirects and phone routing; securely configure and rebuild from reviewed source. Never substitute production credentials. |
| MGR-02 | Codex: successor manager and testing companion; exact model/effort not independently exposed | ACTIVE management owner from 2026-09-27 10:32 +03:00. Takeover, current state and final response recorded. | Main checkout; chat `Resume Hadayah project management`, `01a0e1c5-0499-7c30-b811-3d06090da442`, host `local` | Maintain management records after meaningful events. Owner explicitly authorized the local master merge this turn; completed. No messaging, provisioning, push or additional implementation inferred. |

## INT-01 delivery and manager verification

- Assignment remains [the dispatched prompt](prompts/INT-01_ASTRA_INTEGRATION.md), dispatched 02:27:57 +03:00. [Exact final response and retrieval provenance](prompts/INT-01_FINAL_RESPONSE.md). Base `7b54cb5`; combined source merge `c700589`; tested source `34d074a5c577cd35944813f0a3db5315f4c85e96`; final `8e2880102a9369d4d42d9c25910a87f6ec641857`.
- File ownership covered combined streaming/native, map/offline, provider/application/localization, two additive migrations and its evidence pack under the existing prompt. No current implementation writer is confirmed. Opus completion remains owner/evidence-reported because no Opus chat ID is available. STR-02 completed turn was independently refreshed.
- Manager read README, HANDOFF, VERIFICATION, CRITIC_REVIEW, CLOSURE_MATRIX and Flutter summary. Recomputed APK SHA-256 `576ee96a860b5bcc1b5bde1c7875ee31f31943062c8cb6bd071482453c158b99` and web archive SHA-256 `720fa376cdc9a9f4a4b7c6b4fe50aa972bb0c9b84c217409bdb3feadfd709d57`, both matching delivery. Git project/supabase trees are identical between tested source and final tip. This is an evidence/identity review, not a new source audit or rerun of executable tests.
- Identity: Hadayah Test, package `sa.hadayah.streamer_app.wave4v2`, web build `34d074a-local-diag-1`; configuration is diagnostic with no Google provider/YouTube key. Disposable backend `Hadayah_integration_20260927`, API56021/DB56022, reported stopped with backup. No secret configuration file was read.
- Reported repairs include populated map-card/short-screen overflow, missing-location truthfulness, application/organization location persistence and application-versioned atomic offline updates. Source review used 2 of 3 allowed cycles; all scores remain provisional for physical/backend acceptance. Earlier failures and source-branch review scores remain historical.
- Local merge completed at `c9e441f` after saving owner changes in `571bcdd` and reconciling STATUS, LEDGER, issue log and skill log. The integration agent reports preserving 1,214 files plus both stashes/source branches; this manager independently checked refs/stash IDs and current statuses, not all protected hashes. Source worktrees each retain three modified generated Windows plugin files; no cleanup performed.
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

Before the owner-requested merge, master was `7b54cb5e565011c33dcd03351735b7cc45a0926a`; the integrated source merge is `c9e441fc754789e26708d35b46dcfd22f926e80c`. Stashes are `d646b945d0007d55ec52690f1ca085a3879ccab8` and `d53c178e116328e8c3d349f36af795733dc31ee4`. Main has pre-existing modified documents and untracked evidence. This merge advanced only local master and reconciled documentation; fresh offline worker/page checks passed. No implementation edits, installs or DB operations occurred.

Preserve owner files and active checkouts. No broad reset/clean/stash, production define-file reads, pushes, hosted operations or worktree cleanup by inference. The owner subsequently authorized MGR-02 to perform the local master merge; this is now complete.

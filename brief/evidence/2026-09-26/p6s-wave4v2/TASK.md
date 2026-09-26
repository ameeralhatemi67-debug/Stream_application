# Astra repair task: P6/P6S Wave 4 follow-up and Wave 4v2 acceptance

## Objective

Repair the remaining issues found during the completed Wave 4 physical tests. Deliver an independently reviewed repair branch, a reproducible candidate build and an owner-friendly Wave 4v2 test pack. Aim to make the agreed P6/P6S release scope ready for physical acceptance. Do not mark either checkpoint accepted before the required owner results exist.

Repository: `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app`

Use GPT-6 Astra, reasoning effort Xhigh. This is implementation and verification work, not another research-only assignment. Read current code, reproduce, research the specific unresolved API behavior, fix, verify and produce the retest pack. Continue independent work while waiting for genuinely necessary input.

## Concurrent work and isolation

Opus is actively implementing the three-city map upgrade. Do not use Opus, send it work, edit its checkout, change its branch, stop its processes, reset its local services or install over its test app.

The manager observed master at `7b54cb5` and the active map branch `codex/tricity-map-upgrade` in `C:\Users\User\.codex\worktrees\p5-basemap-spike\Streamer_app`. These are a snapshot, not permission to assume they remain current. Inspect current worktrees and attached artifacts before choosing a checkout. Use a free suitable managed worktree or create one. Work on a separate branch named `codex/p6s-wave4v2-repair`, based on the appropriate current committed master. Never switch the main checkout for this task. This overrides the old repository direct-to-master cadence.

Record the starting commit, dirty files, relevant source hashes and existing stash identities. Preserve owner edits, screenshots, previous results and all stashes. The completed Wave 4 documents are currently untracked in the main checkout; read them there or copy only the required evidence into your isolated worktree. Do not assume a new worktree contains them. Do not sweep unrelated files into a commit.

Shared files such as `app_provider.dart`, English/Arabic catalogs and project status may also change on the map branch. Make focused edits only in your checkout and document likely integration conflicts. Do not merge/rebase against unfinished map work or opportunistically include map changes. Any later combined build will need a short integration regression run.

No push, merge, deployment, hosted database changes, purchases, production credential access or owner app-data deletion is authorized. Do not read `project/dart_define.local.json`. Wave 4 records owner-run hosted tests; that does not authorize you to operate that backend. Use a named disposable local backend and explicit safe test configuration. Do not replace an installed app without coordinating with the owner. Respect current applicable Codex budget instructions; Claude's meter waiver is not a Codex waiver. Surface a genuine unresolved budget conflict accurately instead of changing meter files or inventing permission.

## Required reading

Read the current AGENTS guidance, Core_files status/decisions/design, latest ledger RESUME and only the issue-name index before relevant troubleshooting sections. Treat older completion claims as historical when current source/evidence contradicts them.

Read these inputs from the main repository:

- `brief/evidence/2026-09-26/p6s-astra-audit/E4_ACCEPTANCE_RESULTS.md`
- `brief/evidence/2026-09-26/p6s-astra-audit/SCREENSHOTS_AUDIT.md`, and visually inspect all five referenced screenshots.
- The same folder's `E4_RETEST_SCRIPT.md`, `REPORT.md`, `VERIFICATION.md`, `ISSUE_RECORD_ADDENDUM.md` and relevant regression evidence.
- `brief/03_WORK_PLAN.md` and `brief/06_VERIFICATION.md`, especially separate P6 and P6S closure requirements.
- Relevant phone-media, playback and implementation research under `brief/research/p6s-streaming-architecture/`.

Use Context7 first for library/framework APIs and official documentation plus the installed version's source when necessary. Record concise source links for architecture-changing decisions. Do not repeat broad research whose answer is already supported by current evidence.

## Interpret the evidence correctly

Preserve Wave 4 as the owner's historical record. Add a new subcheck matrix rather than rewriting its observations. Several PASS headings contain unresolved failures. A successful subcheck does not erase its failing sibling.

Physically reported successes include direct phone and OBS audiovisual reception on independent viewers, admin End with role preservation, Hide/Show/End-and-block, device transfer, real viewer transport controls and viewer rotation/fullscreen. Preserve these as regressions.

Unresolved findings include ordinary sender End leaving an open viewer stale, network recovery, broadcaster orientation and landscape layout, channel input/handle consistency and evidence gaps. The screenshot audit names `RtmpStream`, but the baseline bridge actually uses `RtmpCamera2`. Its `handleSetOrientation` returns success without applying rotation. YouTube pillarboxing alone does not prove encoded dimensions or whether the bars are in the source. Verify the actual pipeline before selecting a fix.

## Repair groups

### G1. End state and viewer synchronization

Reproduce ordinary broadcaster End and compare it with the working admin-End path. Trace sender shutdown, server session transition, public room reads, selected watch/session identity, player disposal and feed/map refresh. Determine whether the defect is a missing write, missed invalidation, stale read, timer/lifecycle failure or display reconciliation. Fix the shared cause and every affected caller.

An already-open viewer must reach a truthful ended state without manual refresh/restart. Distinguish ending the app session from ending external YouTube/OBS media. Define and test a bounded healthy-network convergence time using the existing design: baseline room reads are roughly 20 seconds and discovery freshness roughly 30 seconds. Do not promise instant cross-account Realtime or weaken RLS to obtain it. Show honest network uncertainty while offline.

Retain session/actor/organization/device fences. Late End/Start/encoder callbacks must neither revive an ended stream nor stop its replacement, including same-watch-ID restarts. Preserve broadcaster approval/primary role after ordinary/admin End and the different transfer behavior. Add a regression that fails for the owner-reported ordinary-End case.

### G2. Automatic recovery after temporary connection loss

Implement bounded automatic recovery for the supported direct-phone sender and app viewer, with separate state handling for each. Use the owner's proposed default of about 3 seconds between attempts, at most 10 attempts per recovery episode, unless measured SDK/provider behavior requires a documented alternative. Reuse existing reconnect logic where adequate. Prevent concurrent retry loops, unlimited counter resets from callbacks and busy polling while offline. Record the total recovery deadline and its relationship to the server's existing ingest-loss/expiry window.

Show clear English/Arabic reconnecting, recovered and exhausted states with manual Retry/Leave where appropriate. Preserve viewer mute/pause intent. Do not let recovery start unwanted audio or require an app restart. Viewers must not retry an intentionally ended/unavailable session as though it were a network outage. For OBS, recover app listing/viewing appropriately; the app must not claim to restart or monitor the external encoder.

Before sender recovery, reconcile session ownership and authorization with the server. Never restart after manual End, admin End/block, transfer, revocation, sign-out, expiry, disposal or replacement by a newer session. Cancel queued work on every terminal transition and reject stale asynchronous results. A disconnected phone may not learn a remote End immediately, but must not resume sending after reconnection without checking authority.

Automatic recovery while the app is active is distinct from service-owned capture during Home/lock/background. Measure and report those lifecycle cases separately. Do not add or claim indefinite background broadcasting merely because a retry timer runs. If recovery requires a substantial native lifecycle change, implement the smallest supported change and verify resource ownership; do not conceal that dependency.

### G3. Broadcaster orientation and landscape usability

Fix native preview orientation and actual transmitted orientation independently. Inspect sensor/front-back behavior, encoder dimensions, rotation transforms and output aspect ratio. Prefer a stable encoded canvas with fitted orientation if it meets the required behavior and preserves the stream. This is a working technical choice to validate, not a claim that the owner already resolved every D7 option. Do not stretch/crop useful content, force every portrait view to fill 16:9, or rebuild the session on each device rotation. If a different design is necessary, present measured evidence and a concrete decision.

Implement the owner's rules for phone streamer and viewer landscape mode:

- Landscape chat is read-only; no composer, send button or chat microphone input. Preserve unsent text for portrait. If the keyboard is open during rotation, dismiss it and remove composer focus. Provide a localized prompt to return to portrait for typing. Prompting is the default; avoid forced orientation loops.
- Landscape fullscreen has no persistent telemetry/title header. Keep useful status available through the revealed controls/details.
- Tapping the media area hides/reveals overlay controls, including the sender End and fullscreen controls. Hidden controls must remain easy to reveal. Provide a discoverable, accessible End/Back path with confirmation, usable through TalkBack/keyboard where supported. Never hide focused controls or intercept player-native controls with a blanket gesture layer. Do not invent an auto-hide timer requirement from a tap-toggle rule.
- Make the landscape settings sheet usable at short heights, with safe-area support and scrolling/reflow as appropriate. Both reported 90px and 17px overflows must be covered by layout regressions.

Test portrait/landscape, actual software keyboard insets, large text, both locales, front/back cameras, chat open/closed, menus and End/transfer during transitions. Preserve the existing retained viewer player, confirmed transport state, YouTube privacy/referrer behavior and Chrome iframe input. Verify no duplicate audio, reconnect caused by layout alone, frozen dialog or leaked resource.

### G4. Channel configuration and explicit release scope

Trace every place channel URL/handle values are edited, saved, resolved and used. Restore early validation for the supported YouTube channel/handle formats without rejecting legitimate supported inputs. Prevent a stale handle silently contradicting an edited URL; show a specific correction path and normalize safely. Do not silently change an approved channel's identity or bypass existing approval rules.

Preserve fail-closed watch validation for missing key, API outage/quota, unresolvable channel, malformed watch data, ended/VOD and wrong-channel cases. Matching public metadata is not OAuth ownership proof. Assess the audit's known client-only validation bypass against the actual P6/P6S security gate. Add a bounded server-side repair if warranted and feasible in scope; otherwise name the unresolved release decision explicitly. Do not mark it secure because the normal UI refuses a link. Full OAuth coordination is a separate architecture/provisioning decision, not an assumed hidden task.

Honor explicit owner deferrals from Wave 4: organization broadcasting/identity switching/revocation scenarios, future upcoming-live management and return-chip polish are post-release work. Organization-broadcast entry points must show a clear future-feature state and must not start that mode through another visible route. Preserve unrelated organization features and existing backend protections. Do not remove negative guards for unsafe scheduled inputs merely because upcoming-live management is deferred.

Keep Local/private internet/direct unsupported laptop modes honestly unavailable. Do not build these transports or PiP in this repair pass. Record which release exclusions are already owner-approved and which decisions remain. Audio-only audibility is reported passed; inspect and record camera usage separately. Do not claim camera release, lock-screen survival, Auto quality, external-phone sender support or missing D1–D8 decisions complete without implementation/evidence or an explicit accepted scope decision. Duplicate-channel admin indicators and alerts are enhancement proposals unless a proven security defect makes a narrow related repair necessary.

## Verification and independent critique

Use meaningful targeted tests while editing; reproduce the bug before accepting the repair where possible. Run analyzer and the complete Flutter suite at the stable candidate, applicable gates and Android/web builds. New database changes must be new migrations and require the full disposable SQL suite plus relevant independent-session race regressions. Never weaken a gate or remove a test merely to get green. Record pre-existing failures and any concrete environment limitation separately.

Execute available native/browser scenarios against isolated configuration. Do not call a mock or successful APK build physical acceptance. Do not reset shared Docker stacks or run heavy suites/builds in parallel with each other; use a low-resource sequence while Opus is active. Do not kill another task's process.

Use one separate Astra critic subagent after the integrated source and available evidence are ready. This prompt authorizes that bounded delegation. The critic must independently read the diff, acceptance matrix, screenshots and actual results. It scores functionality, accessibility/platform compatibility, integration/connectivity and ease of use, each 0–10. At least 8 in every category is the code-review target, with no unresolved critical/high defect; missing essential physical evidence remains pending regardless of scores. Give reasons for every score below 10. Do not demand a desired score or average away a weak category.

Allow at most three total critic reviews across this repair task: review, focused fixes/recheck, and one final fixes/recheck if needed. Stop early when the review bar is met. Do not spend extra cycles turning an adequate 8/9 into 10. After three reviews, report remaining problems honestly and leave the branch reviewable. Never make an unreviewed source fix after the final review and retain its old scores. If independent review tooling is unavailable, provide a reviewer handoff and state the limitation.

## Required deliverables

Write new artifacts in your implementation worktree under:

`brief/evidence/<actual-date>/p6s-wave4v2/`

1. `README.md`: candidate commit/build identity, current status, document links and shortest owner starting path.
2. `REPAIR_REPORT.md`: each Wave 4 finding, reproduced cause, fix, tests, limitations and remaining decisions. Include concise Mermaid diagrams of session End/recovery and orientation/control states; validate them against implementation.
3. `VERIFICATION.md`: exact commands, outcomes, source/lock/build hashes, backend identity, migrations, device/runtime versions and actual evidence paths. Keep secrets out.
4. `CRITIC_REVIEW.md`: every review, reviewed commit, scores, findings, fixes and final shortcomings.
5. `WAVE4V2_RETEST_SCRIPT.md`: a practical owner-led test script with numbered actions, actor/device, expected result, timing/stop criteria and evidence to capture. Put setup once. Split short fix confirmation from mandatory regression/missing-evidence checks. Estimate hands-on time honestly, separating required stream duration.
6. `WAVE4V2_ACCEPTANCE_RESULTS.md`: a ready-to-fill template with all new cases initially NOT RUN; separate sender/server/viewer observations, actual timing, pass/fail/not-run/deferred and screenshot references. Link historical passes without copying them into new-build results.
7. `P6_P6S_CLOSURE_MATRIX.md`: map every current P6 and P6S requirement to implementation, automated evidence, historical physical evidence, fresh retest case, approved deferral or blocker. Review chat/moderation/account-state requirements as well as streaming. No blanket claim that passing the new streaming cases closes every P6 obligation.
8. `HANDOFF.md`: branch/worktree/tip, commits, candidate artifact locations, isolated test-build setup, proposed migration/rollout steps if any, likely conflicts with Opus's map work, and what remains before acceptance/merge.

Produce a reproducible Android test artifact and web build where toolchains permit, identifying exactly which source/configuration they contain. A no-credentials build is not a configured end-to-end test candidate. If safe test credentials/signing/backend access are missing, provide exact preparation steps and name the blocker without opening production files. Leave installation and any hosted migration to the owner or a separately authorized step.

## Wave 4v2 coverage that must be included

- Ordinary sender End with independent Android and Chrome viewers, measured convergence without refresh; admin End regression and role preservation.
- Brief drop, Wi-Fi/cellular change, prolonged outage through retry exhaustion, restoration and manual Retry for direct-phone sender and viewer. Record retry count/timing, mute intent, server state and media recovery.
- End/admin block/transfer during reconnect, stale callback after End, rapid same-watch restart and confirmation-dialog transitions. No automatic revival of a terminal session.
- Upright front/back preview and received media in portrait/landscape; repeated rotations/fullscreen transitions with one media instance, correct aspect ratio and uninterrupted session where promised.
- Read-only landscape chat on sender/viewer, rotate with an existing keyboard/draft, tap-toggle controls, accessible End/Back and scrollable landscape settings; English/Arabic and large text/TalkBack.
- Channel editing with matching/mismatched URL/handle, malformed input and account change; missing API key, lookup outage/quota and wrong-channel refusal using an isolated diagnostic configuration or controlled fixture.
- Real readiness-handshake failure while the iframe remains reachable; verify the timed fallback separately from ordinary successful loading. Real player Retry and mute/pause behavior.
- OBS and direct-phone audiovisual runs using changing visible/spoken identifiers on independent viewer identities. At least one run of each lasts 15 minutes with an interruption and start/end observations; record temperature and gaps.
- Audio-only reception and separate camera-indicator/resource observations; Home/lock behavior distinct from leaving the route or foreground reconnect.
- Working Hide/Show/End-and-block, relist denial/new permitted ID, device transfer, chat/report/mute/block/account-state regressions relevant to changes and any still-missing P6 acceptance rows.
- Unavailable/deferred modes and their explanatory UI; no accidental activation or unsupported promise.

Record device model/OS, WebView/Chrome/OBS versions, build hash, source commit, safe backend identity, network type and session/watch IDs without stream keys. Run essential sender/viewer/End checks with each physical Android phone taking the relevant role. Add precise fault-injection instructions for tests the owner cannot perform through normal UI. Do not make the owner guess how to simulate missing-key/readiness cases.

## Completion and checkpoint status

Use small coherent commits on the repair branch with explicit paths. Preserve incomplete work in that checkout with a resume note if blocked. Update current status only in your branch, preserving the owner's original Wave 4 record and unrelated work.

Before new owner testing, the strongest allowable status is READY FOR WAVE 4v2, subject to clearly listed setup/decision gates. If a critical/high defect or necessary decision remains, say NEEDS WORK or BLOCKED. Close P6 and P6S separately only after their closure matrices contain the required passing evidence and explicit approved scope decisions. Neither a critic score nor automated tests can substitute for this.

Do not merge, push or deploy. Finish with a concise summary of fixes, verification, critic outcomes, open items, candidate location and a direct link to the Wave 4v2 starting instructions. Leave the branch ready for review and owner testing.

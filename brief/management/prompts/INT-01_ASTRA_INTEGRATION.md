# INT-01: Astra integration assignment

Archived from the actual user message in Codex chat `Integrate Hadayah streaming and map`, thread `01a0e00b-e1d8-7333-8fb1-b4086ea2677e`. Retrieved 2026-09-27, Asia/Riyadh. This is the dispatched prompt, not a new assignment. Do not resend while INT-01 is running.

---

Act as the integration engineer and independent auditor for Hadayah.

Audit and combine Astra’s streaming repairs and Opus’s map upgrade, fix confirmed remaining defects, and deliver one clearly identified Hadayah test candidate with a consolidated Wave4v2 testing sheet.

Read the actual source and evidence before editing. Completion reports are claims to verify. Work through this task carefully; I authorize sustained work.

## 1. Repository and source branches

Main repository:

`C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app`

The Flutter application is inside `project/`.

Streaming work:

- Branch: `codex/p6s-wave4v2-repair`
- Latest known source commit: `ddcb521`
- Latest known branch tip, including evidence: `818cc12`
- Worktree: `C:/Users/User/.codex/worktrees/p6s-wave4v2-repair/Streamer_app`
- Latest evidence: `brief/evidence/2026-09-27/p6s-camera-landscape/`
- Earlier repair evidence: `brief/evidence/2026-09-26/p6s-wave4v2/`

Map work:

- Branch: `codex/tricity-map-upgrade`
- Latest known source commit: `a57dda7`
- Latest known branch tip: `74157ba`
- Worktree: `C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app`
- Correct handoff: `brief/evidence/2026-09-26/p5-tricity-map-upgrade/HANDOFF_TO_ASTRA.md`

The map worktree’s root `HANDOFF_TO_ASTRA.md` is an old streaming handoff. Use the dated map handoff above.

Main `master` was last checked at `7b54cb5`. Verify all current identities and working-tree states. Preserve any newer work.

Create `codex/hadayah-wave4v2-integration` in an isolated worktree. Use the managed worktree tool when available. Keep both source branches intact.

## 2. Authorization and preservation

You may audit, implement focused repairs, integrate the branches, run local verification, create commits, and conditionally merge the verified result into local `master`.

Do not push, deploy, operate a hosted database, publish a broadcast, change external accounts, or replace an installed owner app without the required existing authorization.

Preserve:

- Main checkout’s uncommitted files and untracked owner evidence.
- Both existing stashes.
- Original screenshots, results, source branches and runtime artifacts.
- Other worktrees and processes.

Record a baseline of protected file hashes, branch tips and stash identities; verify preservation at the end. Do not broadly stash, reset, clean or restore the main checkout.

Do not read or copy `project/dart_define.local.json`. Use dedicated test configuration. Keep secrets out of logs, screenshots and commits.

This instruction overrides AGENTS.md’s default of developing directly on master and pushing at checkpoint kickoff.

There is one product: **Hadayah**. Wave4v2 is a test round. Use a clearly distinguishable test label such as **Hadayah Test**. Avoid creating unnecessary additional test application identities.

## 3. Read and establish the current state

Read applicable AGENTS.md instructions, Core_files/STATUS.md, decisions.md, the latest LEDGER resume block, the relevant work plan, and the issue-name index in issue_encountered.md.

Read the handoffs, reports, verification, critic findings and acceptance matrices for both branches.

Also inspect these owner results in the main checkout:

- `brief/evidence/2026-09-26/p6s-astra-audit/E4_ACCEPTANCE_RESULTS.md`
- `brief/evidence/2026-09-26/p6s-astra-audit/SCREENSHOTS_AUDIT.md`

Read relevant research from:

- `brief/research/p6s-streaming-architecture/`
- `brief/research/p5-tricity-map-upgrade/`

Some research and owner evidence are untracked in the main checkout. Read them there; do not assume an isolated worktree contains them.

Build a concise requirement-to-code-to-test table. Separate implemented, independently verified, physically unverified, explicitly deferred and blocked items.

Use Context7 for library/API questions and official documentation or pinned dependency source when necessary. Cite sources for technical decisions.

## 4. Preserve and audit the streaming requirements

The latest owner instructions are authoritative:

- Portrait outgoing video is upright and fitted; side bars are acceptable.
- Both landscape directions produce upright outgoing landscape video, filling the encoded canvas without stretching.
- Preview and received video must each be checked. Preview correctness alone is insufficient.
- Rotation preserves the encoder/session and does not create duplicate audio or interrupt the stream.
- Camera handling uses actual device capture geometry. Do not blindly apply a fixed minus-90-degree correction.
- Normal landscape sender controls are only End at physical top-left, settings and chat at top-right. Video taps toggle them.
- No solid telemetry header, redundant fullscreen icon, bitrate badge or “Live from the phone” title.
- Preserve accessible End/Back behaviour and necessary failure/recovery messages.
- Landscape video chat and related editing cannot open a keyboard for streamer, viewer or admin. Portrait drafts survive rotation.
- Settings and action sheets fit short screens, Arabic and large text.
- Front-camera switching remains disabled with a localized Coming Soon explanation. It must not interrupt the broadcast.

Audit the native bridge, display rotation, capture-size selection, render transforms, resource lifecycle and all affected callers. Check portrait, both landscape directions, unsupported configurations, reconnect, Hide video and End.

The latest report includes poor emulator frame delivery and a System UI ANR. Investigate available traces. Distinguish an app defect from an emulator limitation using evidence. Do not mark this resolved because compilation or widget tests pass.

Preserve ordinary/admin End, session fencing, account and device authority, transfer, bounded reconnect, fail-closed watch validation, retained playback, actual player controls and mute/pause intent.

D8 server-side YouTube authorization remains an explicitly retained release blocker. Do not downgrade it or silently expand this task into a new OAuth architecture. Audio-only camera release, background survival, unavailable modes and other scope decisions must remain accurately recorded.

## 5. Audit and repair the map work

Fix the confirmed venue-card regression first:

- Its action row overflows narrow screens, particularly Arabic and larger text.
- Keep the main Watch/Listen/Profile action reachable.
- Preserve adequate touch targets, including Close.
- Test with a venue actually selected across 320–412 dp widths, English/Arabic, different card variants and large text. An empty map test does not cover this defect.

Inspect and repair related misleading behaviour where confirmed:

- No invented distance or directions to an absent/0,0 pin.
- Avoid offering a directions action that can only show “unavailable.”
- Offline Save messaging must reflect what can actually be saved.
- Preserve exact selected coordinates and existing legitimate locations.

Investigate these source-review concerns before calling browser offline readiness reliable:

1. Saved readiness appeared to use the map-pack hash without identifying the application build. Determine whether new streaming code can run against an old saved application.
2. Cache promotion appeared to overwrite the active copy file by file. Test failure during promotion, beyond interruption during download.
3. Check worker restart, hanging networks and concurrent tabs where they affect these paths.

Use the smallest robust correction supported by those checks. Verify offline Arabic fonts, required images, app startup, map assets and update behaviour together.

The owner’s requested focus is Al Khobar, Dhahran and Dammam. The map branch expanded coverage to nearby towns without an explicit approval. Treat the original three-city requirement as authoritative. Distinguish navigation padding from which venues the product includes. Do not invent municipal boundaries or silently rewrite saved venue data.

Accurate city outlines remain unmet because licensed, suitable geometry has not been obtained. Record that accurately. Do not claim such data does not exist globally, draw arbitrary polygons as official boundaries, or remove required attribution.

Do not rebuild the map architecture unless the audit establishes a concrete need.

## 6. Integrate behaviour, not only files

Recompute the branch overlap. Previously shared files included:

- `project/android/app/build.gradle.kts`
- `project/assets/i18n/en.json`
- `project/assets/i18n/ar.json`
- `project/lib/core/providers/app_provider.dart`
- `project/lib/features/auth/presentation/streamer_apply_screen.dart`

Resolve each conflict by preserving the intended behaviour of both changes. Do not wholesale choose “ours” or “theirs.”

Check interactions beyond overlapping files:

- Map → live room → map, retained position and playback.
- Ordinary/admin End propagating to room, feed and map.
- Moderation, hiding, transfer and revocation during recovery.
- Pinned/unpinned venues in live-room details and application flows.
- Combined map/player memory and lifecycle.
- Browser offline startup and updates after streaming code changes.
- Arabic catalogue symmetry and accessibility.
- Android test identity, signing/configuration and OAuth callback consistency.

Produce one build identity with source commit, artifact hash, package/label, configuration identity and backend identity. Do not expose configuration secrets.

## 7. Verification and independent critic

Run meaningful focused regressions, then the full required analyzer, Flutter tests, repository gates and Android/web builds on the combined candidate.

Use a disposable local database for required SQL/concurrency verification. Distinguish fresh results from inherited results. Do not operate a hosted backend.

Use an independent critic subagent for this new integration task. It must inspect the actual combined diff and evidence and challenge unsupported claims.

This task has a maximum of **three integration review cycles**. Earlier branches’ exhausted review cycles remain historical; do not alter them.

Score each category from 0–10:

1. Functionality.
2. Accessibility and supported-platform compatibility.
3. Integration and connectivity.
4. Ease of use.

Every category must reach at least 8 for the numerical target. Stop early when the target is met and no unresolved critical/high implementation defect remains, except the explicitly retained pre-existing D8 blocker, which must remain visible.

For a failing cycle, fix the root causes and verify before the next review. Do not make unreviewed source repairs after the final review and carry the old scores forward.

For each final score below 10, document the concrete reason, evidence and next action. State which scores remain provisional because physical/backend evidence is missing. Scores never establish physical acceptance.

If the third cycle still fails, preserve the candidate and report NEEDS WORK. Do not keep looping or conceal the failure.

## 8. Build readiness and consolidated Wave4v2 tests

The previous supplied builds lacked Google/YouTube test configuration. Do not hand me another diagnostic build as though it can complete acceptance.

Reuse authorized dedicated test configuration where available. If credentials or external provisioning are missing, complete all independent work and document the exact missing setup. Never fabricate credentials or bypass authorization.

Create the new evidence pack under:

`brief/evidence/2026-09-27/hadayah-wave4v2-integration/`

Include:

- `README.md`: start here, status, exact candidate identity and setup.
- `AUDIT_AND_REPAIRS.md`: findings, causes, changes, sources and unresolved issues.
- `VERIFICATION.md`: commands, outcomes, evidence and limitations.
- `CRITIC_REVIEW.md`: reviewed commits, rounds, scores and reasons below 10.
- `WAVE4V2_RETEST_SCRIPT.md`: one consolidated owner script.
- `WAVE4V2_ACCEPTANCE_RESULTS.md`: matching ready-to-fill results.
- `CLOSURE_MATRIX.md`: separate P5/map, P6 and P6S decisions.
- `HANDOFF.md`: merge state, remaining work and artifact locations.

Use concise Mermaid diagrams where they clarify camera-to-viewer flow, offline update behaviour or state propagation. Validate diagrams and links.

The testing script must start with build/configuration confirmation and a short smoke test:

- Correct installed Hadayah Test candidate.
- Upright portrait and both landscape directions on an independent receiver.
- Working landscape overlays, read-only chat and usable settings.
- Selected map card in Arabic at narrow width and large text.
- Real player controls and ordinary End.
- Basic map → live → map behaviour.

If smoke fails, tell me which dependent sections to stop and what evidence to capture. Avoid sending me through a long acceptance run on a visibly broken candidate.

After smoke, cover streaming, OBS, chat/admin/security, offline maps, Arabic/accessibility and cross-feature regressions. Include both physical phones and Chrome where applicable, cold offline starts, update/re-save failures, reconnect/transfer/revocation, long-duration runs and resource behaviour.

Give each case prerequisites, roles/devices, clear steps, expected results, evidence and realistic duration. Preserve historical results. Link old case IDs to new ones, remove duplicated actions, and explain which changed behaviours require retesting.

All new results start NOT RUN. Explicitly distinguish FAIL, BLOCKED, NOT RUN and approved deferral. Never copy an old PASS into the new candidate’s acceptance column.

## 9. Conditional local merge and final handoff

Merge into local master only after:

- Source audit and integration critic meet the requirements above.
- Required executable checks pass.
- No unresolved new critical/high implementation defect remains.
- Protected owner files and stashes can be preserved.
- The exact candidate and remaining physical/release blockers are documented.

Physical acceptance and release approval remain separate from source integration. An unavailable phone run is not a fabricated PASS.

If safe promotion would overwrite owner work or the integration criteria fail, leave the verified work committed on the integration branch and explain the precise blocker. Complete the test pack regardless.

After any local merge, verify the resulting source and preservation. Reuse earlier test results only when the tested source is demonstrably identical; otherwise rerun affected checks.

End with a concise report stating:

- Branch, source and final commit identities.
- Whether local master was merged.
- What was fixed and what remains unresolved.
- Final critic scores.
- Whether the candidate is diagnostic or configured for acceptance.
- The exact first test file to open.
- Separate P5, P6 and P6S acceptance status.

Do not declare a checkpoint accepted or release-ready while its required evidence or scope decisions remain open.


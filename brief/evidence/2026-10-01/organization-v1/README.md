# Organization V1 implementation

Owner-approved scope: the organization broadcasting V1 plan in this chat, 2026-10-01. Three independent public programs per organization; Android and OBS; personal and organization server authorization; presenter acceptance per occurrence; four leadership roles; seven-day account-bound invitations; two-party ownership transfer. No uploads, private media, payments, or iOS publishing.

Baseline: master `5c4bc7025f39f26232dc93a52c03d97883b2a42f`, with existing owner changes. Original touched files, status, HEAD and stash list are preserved under ignored `brief/.runtime/organization-v1/baseline/`. Never stage unrelated owner changes. No production migration or publication is authorized by this implementation checkpoint.

Budget: measured weekly usage 86%; owner authorizes ten additional percentage points. Soft stop 95%; absolute stop 96%, including verification and handoff. Use the live Codex usage tool at phase boundaries. Historical 5% absolute and 90% guards do not apply to this effort. No reset crossing or reset credit.

Shipping requires a configured test backend/channel, three real senders and real viewer playback. The owner selected `streamer_app` (`zkkmfjsjouqzibvnzkau`) and `@amiralhatime4831`. Read-only inspection confirms the hosted backend is healthy and has migrations through `20260930010000`; no V1 hosted changes or provider credentials have been accessed. Implementation and acceptance are separate.

## Progress

- Baseline static analysis: zero issues (25.7s).
- Local database: isolated `org_v1_audit_20261001` in `supabase_db_P6_accept_disposable`; schema only copied, all later migrations applied. Existing database untouched. Membership pgTAP: 22/22 passed. Focused Flutter regressions: 6 passed. New UI analysis pending.
- Phase 1 membership authority: implemented; local membership pgTAP 22/22, focused Flutter tests 6/6, zero-issue analysis. Owner source edits preserved separately from the phase commit. Later phase tests still need the full invitation and transfer matrix.
- Phase 2 channel authorization: implemented. Disposable SQL security checks: 24/24 passed, including callback races, expired state/session, duplicate destination ownership, private credentials, transfer fencing and secret cleanup. Provider boundary checks pass. OAuth Edge bundle passes in Supabase Edge Runtime v1.74.3. Client channel identity model and management screens are implemented. Real OAuth consent and channel pilot are not run; see `doc/organization-v1-owner-setup.md`.
- Phase 2 client verification: zero analysis issues (25.7s); seven focused Flutter checks passed. Weekly usage at the phase boundary: 88%. No public app deployment URL or configured Google OAuth web client was found in the repository; the owner does not know these values. They remain setup gates, not fabricated configuration.
- Phase 3 canonical sessions: implemented backend and typed contracts. Extends `broadcast_sessions` and existing Upcoming Live; Riyadh four-week materialization preserves immutable occurrence identity, acceptance, capacity, canonical summaries, provider reservations and private ingest credentials. Legacy start/live writes remain fenced. Provider helper checks pass for duplicate preparation, partial/ambiguous creation, encoder readiness, LIVE confirmation, end ordering and replay. Both session Edge Functions bundle. Flutter analysis: zero issues (22.2s), 13 focused contract/Upcoming checks passed. Studio and session-room wiring remain Phase 4.
- Phase 3 disposable SQL checks: 36/36 passed; combined membership/channel/session checks 82/82. Account/organization deletion waits for provider termination and feed retirement, with encrypted ingest-secret cleanup. This phase includes the existing Upcoming migration/model and shared loading widget as required dependencies; other owner work remains unstaged. Budget still 88% at the measured boundary.
- Phase 4 client/notifications/recovery: started, then archived at the owner's requested safe stop. Nine unfinished source files are preserved with hashes and a guarded restore script in ignored `brief/.runtime/organization-v1/phase4-handoff/`; active source is restored to the tested Phase 3 working copies. See `brief/handoff/ORGANIZATION_V1_HANDOFF.md` for remaining work and known draft defects.
- Fresh stop verification: zero analysis issues (19.6s), 13 focused Flutter checks passed, 82/82 disposable organization SQL checks passed, both provider check scripts passed. Full Flutter suite and real pilot are not acceptance evidence for this checkpoint. Weekly usage measured 88%; stop requested by owner after compaction, not budget exhaustion. Completed phases are pushed through `cb1c10f`; owner edits and both stashes remain preserved.
- Real-channel pilot: NOT RUN. Release remains blocked.

## Resumed Phase 4 checkpoint — 2026-10-01, budget cutoff

The owner asked to resume the handoff. The archive was validated/restored, its retry/authority defects repaired, and canonical studio/shows, phone publishing session checks, direct session rooms/replay, concurrent cards and scoped chat/report/presence policies were added. New implementation stopped at the measured **95%** weekly ceiling; remaining work is explicit in the updated handoff. Phase 4 remains **partial, active, uncommitted and disabled for rollout**.

Final local evidence:

- `flutter analyze`: **0 issues**, 18.4s.
- Full `flutter test`: **912 passed / 23 failed**, 3m26s. **21 failures reproduce in the exact saved entry source**. Two new failures are old expected error keys in `organization_admin_and_go_live_test.dart` and `v04_core_architect_settings_test.dart`: unprepared canonical publishing returns `organization_v1.assignment_required`; they expect `broadcast_primary_required`. Denial remains enforced. No full-suite green claim.
- Isolated baseline: 966 passed / 22 failed. One extra failure was a missing sibling `brief/assets/design_options/tokens_A.json` fixture in the comparison copy. After copying it, both typography tests pass. This leaves 21 reproduced source failures. Obsolete manual-key/studio tests were replaced with canonical preparation, retry, confirmation, authority and sheet tests; raw test counts are not a like-for-like regression metric.
- Disposable SQL: **107/107 passed**, 22 memberships + 24 channels + 36 sessions + 25 client/moderation/presence/badge checks. Database `org_v1_audit_20261001` only; draft rebuild did not reset the original database.
- Both provider check scripts pass. Hidden canonical room → processing → available read-only replay regression passes, including exact chat IDs and no discovery listing. Full suite includes the bilingual narrow/2x studio and phone End/recovery checks.
- Final Android debug APK builds (95.3s). RootEncoder TLS hostname checking is compiled. No install, hosted credentials or real ingest test. APK identity is in `continuation-verification.json`.
- Gates: **22 PASS / 5 INFO / 4 FAIL**. New G6 studio Android label needs localization. Existing G2d gradients and G3 emojis remain; G11a reports secret-bearing artifacts in unrelated nested worktrees. No secret value was printed, packaged, changed or deleted. These are open findings, not a release pass.
- Web build, current Edge bundling, hosted security advisors, real OAuth, physical Android and real three-show pilot remain unverified.

Raw logs: `brief/.runtime/organization-v1/{analyze-final.txt,flutter-final.txt,flutter-baseline-resume.txt,baseline-fixture-check.txt,sql-final.txt,gates-final.json,android-final.txt,replay-check.txt}`. Summary: `continuation-verification.json`. Current source/hash recovery copy: `brief/.runtime/organization-v1/resume-final/`. These ignored snapshots are local only and include owner changes; do not stage them as feature patches.

Master/origin remain `cb1c10f`; both original stashes are unchanged. No phase commit, push, hosted mutation, deployment or publication occurred in this continuation. Notifications, onboarding/feature-flag wiring and complete invitation/transfer journeys remain the next implementation work after the small verification findings are settled under a new authorized budget.

## Phase 4 completion — 2026-10-01 (Claude continuation)

The owner asked to finish the handoff. Implemented: durable organization events and push dispatch (`20261001160000_organization_v1_notifications.sql`, `dispatch-organization-events`), the Organizations hub and invitation/transfer journeys, rollout availability (pilot list, `organization_applications_open`), hash-route fixes for consent return and invitation links, Shows-screen error/availability states, and repair of the 21 older test failures (tests used the offline write fallback Phase 1 removed). Details: `brief/handoff/ORGANIZATION_V1_HANDOFF.md`, ADR-009 Phase 4 notes.

Fresh local evidence:

- `flutter analyze`: **0 issues** (`analyze-claude-final.txt`).
- Full `flutter test`: **968 passed, 0 failed** (3m38s, `flutter-claude-final.txt`). Previous continuation: 912 passed / 23 failed.
- `test/organization_v1_journeys_test.dart`: 33 passed (hub, invitations, transfer, membership panel, Shows, consent return, application switch; en/ar; 320 px with 2× text caught and fixed an overflow in the owner setup steps).
- Disposable SQL `org_v1_audit_20261001`: **155/155** — memberships 22, channels 24, sessions 36, client 25, **events 48** (`events-sql.txt`). No other database touched.
- `brief/tools/youtube_broadcast_check.mjs`, `broadcast_control_check.mjs`, new `org_event_text_check.mjs` (30 renderings): pass.
- Edge Runtime v1.74.3 bundles: dispatch-organization-events, channel-authorization, broadcast-control, reconcile-broadcasts (`bundle-*.txt`, `*.eszip`).
- Release web build with `PUBLIC_APP_URL=https://stream-application-ten.vercel.app` (`web-build-claude.txt`); served locally, `/#/org-invite/<id>?token=…` opened the invitation screen with no console errors.
- Android debug APK built (`android-claude.txt`), sha256 `42020ef527d1d3d1a23acbdf314a44caa428a3d77ea26db562e89f72b6742624`; not installed.
- Gates: **23 PASS / 5 INFO / 3 FAIL** (`gates-claude.json`). G6 now passes. Remaining G2d/G3 are in uncommitted owner work (welcome/entry gradients; LIVE-03 raised-hand glyphs); G11a lists secret-bearing files in old nested worktrees, not read or modified.

Deployed site check: https://stream-application-ten.vercel.app serves build `cb1c10f…-20261001114047` (Phase 3) compiled without Supabase settings, so it has no backend yet.

Not verified: hosted migrations/functions, hosted security advisors, real Google OAuth, real FCM delivery, physical Android, the real three-show pilot. Nothing was deployed, pushed or changed on a hosted service. Phase 4 is committed locally (not pushed) with its owner-work dependencies, as the owner chose: 98 paths, verified in an isolated copy of HEAD + those files (analyzer 0, 952 tests passed, 0 failed; `isolated-commit-tests.txt`, `isolated-commit-analyze.txt`, path list `phase4-commit-paths.txt`). See the handoff for the path list rationale.

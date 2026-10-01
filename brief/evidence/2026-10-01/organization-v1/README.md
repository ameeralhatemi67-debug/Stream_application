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
- Phase 4 client/notifications/recovery: not started.
- Real-channel pilot: NOT RUN. Release remains blocked.

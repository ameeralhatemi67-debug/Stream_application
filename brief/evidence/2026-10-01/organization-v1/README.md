# Organization V1 implementation

Owner-approved scope: the organization broadcasting V1 plan in this chat, 2026-10-01. Three independent public programs per organization; Android and OBS; personal and organization server authorization; presenter acceptance per occurrence; four leadership roles; seven-day account-bound invitations; two-party ownership transfer. No uploads, private media, payments, or iOS publishing.

Baseline: master `5c4bc7025f39f26232dc93a52c03d97883b2a42f`, with existing owner changes. Original touched files, status, HEAD and stash list are preserved under ignored `brief/.runtime/organization-v1/baseline/`. Never stage unrelated owner changes. No production migration or publication is authorized by this implementation checkpoint.

Budget: measured weekly usage 86%; owner authorizes ten additional percentage points. Soft stop 95%; absolute stop 96%, including verification and handoff. Use the live Codex usage tool at phase boundaries. Historical 5% absolute and 90% guards do not apply to this effort. No reset crossing or reset credit.

Shipping requires a dedicated configured test backend/channel, three real senders and real viewer playback. No hosted project or provider credential has been accessed. Implementation and acceptance are separate.

## Progress

- Baseline static analysis: zero issues (25.7s).
- Local database: isolated `org_v1_audit_20261001` in `supabase_db_P6_accept_disposable`; schema only copied, all later migrations applied. Existing database untouched. Membership pgTAP: 22/22 passed. Focused Flutter regressions: 6 passed. New UI analysis pending.
- Phase 1 membership authority: implemented; local membership pgTAP 22/22, focused Flutter tests 6/6, zero-issue analysis. Owner source edits preserved separately from the phase commit. Later phase tests still need the full invitation and transfer matrix.
- Phase 2 channel authorization: in progress. Channel/Vault migration applies locally; owner OAuth function and legacy-start fence are written. Provider boundary checks pass. Real OAuth consent and channel pilot are not run.
- Phase 3 canonical sessions: not started.
- Phase 4 client/notifications/recovery: not started.
- Real-channel pilot: NOT RUN. Release remains blocked.

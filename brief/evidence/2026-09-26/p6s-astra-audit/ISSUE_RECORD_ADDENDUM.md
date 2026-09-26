# Audit issue addendum

The main checkout's `issue_encountered.md` and `skill-observations/log.md` already contain owner work. This task preserves them byte-for-byte. These entries are supplied for a later deliberate consolidation instead of appending to those dirty files.

## Stale broadcast End clears a newer session

Status: FIXED locally.
Observed: a waiting End cleared a replacement session with either a different or identical watch ID.
Cause: session snapshot was read before acquiring the common broadcast writer lock.
Fix: take the shared advisory transaction lock before reading the session; use the session identity and terminal state under that lock.
Verification: independent psql connections observed the wait; both cases failed before and pass after `ecc992b`. Physical end/stop timing remains E4.
Evidence: race-before.txt, concurrency-final.txt and brief/tools/broadcast_session_concurrency.mjs.

## Broadcast expiry snapshot clears a replacement

Status: FIXED locally.
Observed: the sweep selected an expired profile before a simultaneous heartbeat/new Start committed, then expired the new session after a row-lock wait.
Cause: sweep and live writers used different advisory locks.
Fix: acquire the common writer lock before selecting; skip a busy sweep. Ingest uses the same lock ordering.
Verification: separate-connection before/after regression, `f83c8dd`.
Evidence: sweep-before.txt and concurrency-final.txt.

## Organization moderation follows a reused watch ID

Status: FIXED locally.
Observed: same-watch org switching retained old session affiliation; revoking a stale organization could end an unrelated account reusing its watch ID.
Cause: session replacement and moderation selected by watch ID rather than owner/org session identity.
Fix: replace sessions on org/device identity change and scope organization revocation to its live session owners.
Verification: seven boundary assertions, including simultaneous reuse denial and sequential reuse, pass in the complete fresh SQL suite.
Evidence: identity-before.txt, identity-after.txt and broadcast_identity_boundaries.test.sql.

## Chrome watch change leaves connecting cover visible

Status: FIXED locally.
Observed: changing the real web adapter's watch ID kept the app loading cover over the iframe indefinitely.
Cause: the web plugin sets iframe.src but does not supply the page-finished callback used by the native code.
Fix: clear the cover after each web source assignment and leave playback state unconfirmed.
Verification: real Chrome before/after probe, actual iframe Play response, source commit `6c0e7c9`.
Evidence: BROWSER_PROBE.md.

## Parallel Flutter verification exhausts memory

Status: RECOVERED locally; no application defect attributed.
Observed: a full-suite rerun ended with PowerShell “Out of memory” while build/browser work also ran; it had no successful completion result.
Cause: concurrent verification exceeded available machine memory; precise allocator attribution was not established.
Fix: stop the audit-owned disposable stack and orphan test worker, finish builds, then run `flutter test --no-pub --concurrency=1 --reporter expanded` separately.
Verification: all 695 tests passed in 5m21s. The failed parallel run is not counted as a pass.
Evidence: flutter-tests.txt, local full log hash, VERIFICATION.md.

## Skill/workflow observation for later review

Status: OPEN.
Type: workflow improvement; defer action.
Issue: an audit that inherits broad mocked UI coverage can still miss a real platform loading/command boundary. Concurrent test/build activity can also exhaust a desktop's memory and obscure the verification result.
Improvement: in future audit instructions, require one bounded real-platform probe for each changed external-media boundary, then run memory-heavy builds and the full test suite sequentially on constrained desktops.
Principle: preserve the distinction between a mocked contract, a running integration and physical media acceptance; resource failure is not a test pass.

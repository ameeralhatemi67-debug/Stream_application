# Budget forecast stop: release work incomplete

P0 completed. P1 has a partial source checkpoint: privileged-column guards, owner-scoped asset writes, application/affiliation review guards, direct-write ban policies and secret-file ignores. No production changes were made. The app is not release-ready.

Last meter: `OK plan=split window=1 used_5h=44 cap=70 soft=64 headroom=26 weekly=7 resets_in_min=20 snapshot_age_s=71`. This is an early forecast stop, not a meter STOP. The next coupled live-state/device step needs an estimated25-35 points, exceeding the26-point hard margin minus3 reserve and20-point soft margin. One window used; no waiting or second-window work. Phase measurements exclude closing bookkeeping.

| Phase | Estimate | Actual account delta | Ratio / status |
|---|---:|---:|---|
| P0 | 1-2 | 13, from9 to22 | 6.5-13x; complete |
| P1 | 12-16 full phase | 22, from22 to44 | 1.4-1.8x; partial |
| P2/P3 | 6-8 / 4-6 | Not started | Pending |
| P4/P8A | 24-30 / 6-9 | Not started | Pending |
| P6/P5/P7 | 9-12 / 10-14 / 9-12 | Not started | Pending |
| P8B/P9 | 4-6 / 3-4 | Not started | Pending |

The three largest measured intervals were P1 implementation/checkpoint22 points, P0 baseline/tooling11 points, and meter/settings restoration2 points. P1 involved four migrations,27 SQL assertions, upload-path code/tests and security documentation. P0 required SDK permission recovery and baseline tests. These are account-wide intervals, not exact per-command costs. The file meter lagged at22 while live account usage reached37/40/44; the higher live reading governed work, and the file meter later caught up. No meter code or caps were changed.

Evidence: final analyzer0 issues; full suite266 passed, up from264 baseline; import-lint correction followed by analyzer and focused2/2 tests. Static gates17 failing versus18 baseline; G10a-e and G11a-g all0, including history scan. All new SQL is UNVERIFIED-STATIC because Docker is unavailable. No runtime RLS proof, release AAB scan, hardware scenario or store/legal acceptance is claimed. Existing caught provider-disposal warnings remain in test logs.

Remaining order: finish P1.2/1.7 together25-35 points, then P1.6/1.8/1.9/1.10 and RPC ban audit10-15 more; then P2,P3,P4,P8A,P6,P5,P7,P8B,P9. Later phases retain their uncalibrated75-101-point estimate, so remaining total is110-151. P0-P3/P9 are pending where unfinished, not cut. Owner-only actions and legacy-asset handling are in OWNER_ACTIONS.md.

Safe checkpoint: application changes and each migration are complete files; git diff --check passed. P0 commit is3ba0eb7; the following local P1 commit holds the partial implementation and this report. [SUPERSEDED: the owner files were restored and committed as cd0b698; never apply, pop or drop the stashes.] Run `node brief/tools/budget_check.mjs --plan split` without --new-run. Resume from the LEDGER RESUME block in a fresh window2 session, cap60/soft54, never a third window.

## Bonus attempt
Owner authorized40 more points; live usage read55% five-hour/8% weekly.
Owner bonus/settings files committed as cd0b698. No application work started.
Bonus meter returned STOP using a17431-second-old snapshot:1% five-hour/98% weekly, incorrectly initializing cap41. This contradicts live usage; actual weekly exhaustion is not established.
Stopped under the binding STOP rule; extra spend unmeasured. Prior analyzer0/tests266 baseline unchanged, not rerun.
Settings are committed; do not restore the old stashes. Resolve meter freshness before continuing; see LEDGER RESUME block.

## Bonus retry, 30-point request
Settings already committed; no application item started and neither stash touched.
Meter STOP used a17657-second-old snapshot,1%/98%, cap41; live usage was64%/10%.
Only5min remained before reset, leaving1min under the required buffer. Stopped without tests/builds; implementation spend0, account bookkeeping spend unmeasured.
All pending work and the corrected window2 resume instructions remain in LEDGER.md.

## Supervisor note (Claude, 2026-09-20 after the stale-meter stops)
Checked against the repo: commits 3ba0eb7 and 95b97fc, the 4 migrations and the 27 pgTAP assertions (9+7+11) match the report; the tree was clean; both stashes are historical (their files are contained in HEAD). Not re-run by the supervisor: analyzer, the 266 tests, SQL (no Docker). The stale-reading STOP reproduces with synthetic logs on the old `budget_check.mjs` (weekly guard ran before the staleness check); the meter is now fixed (04 §I, `--live-*`, `--cap`). Whether the real Codex log lags is still unverified. Window 1 is over; the next session is split window 2 with `OWNER_CAP=90`.

## Window 2 forecast stop, 2026-09-20
Completed source steps P1.2/1.7 and P1.8/1.9; P1 remains partial. Final verification: analyzer0, full268 passed, gates16 versus17 at entry, G7/G9/G10a-e/G11a-g0, diff-check clean. SQL22 new assertions and physical-device scenarios are UNVERIFIED-STATIC. No production deployment, release build or push.
Meter at closing: plan=split window=2 used_5h=83 cap=90 cap_source=owner soft=84 weekly=23. Two windows used. Early closing began at70; remaining identity/RPC/RLS work requires25-40 points versus14 to soft. No third window is allowed.
| Phase slice | Estimate | Actual delta | Ratio |
|---|---|---|---|
| Baseline | not estimated | 14 (3-17) | n/a |
| P1.2/1.7 |25-35|37 (17-54)|1.06-1.48x|
| P1.8/1.9 |8-15|16 (54-70)|1.07-2x|
| Closing/checkpoint |6 reserve|13 (70-83)|2.17x|
Largest consumers: paired RPC/client lifecycle implementation37; private/debug/navigation cleanup16; baseline recovery14. Closing cost13 included full-suite discovery of simulation expectations missed by focused searches and test updates. These are account-wide observations, not isolated command charges.
Remaining priority: P1.6/RPC-ban audit/P1.10 estimated25-40; then P2 6-8, P3 4-6, P4 24-30, P8A6-9, P6 9-12, P5 10-14, P7 9-12, P8B4-6, P9 3-4. Later estimates remain uncalibrated. Safe source checkpoint is one local commit; both owner stashes are retained. See LEDGER RESUME and OWNER_ACTIONS for commands and runtime probes. Owner authorization for a new run is required; this split run cannot resume into window3.
- Final meter: BUDGET status=SOFT harness=codex plan=split window=2 used_5h=85.0 cap=90 cap_source=owner soft=84 headroom=5.0 weekly=23.0 reason=used>=soft(84). Closing delta15 including bookkeeping, total window2 session delta82. Post-commit status clean; both historical stashes unchanged. These final numbers supersede the pre-commit83 reading above.

## Supervisor note 2 (Claude, after window 2)
Checked against the repo: commit b61b3f7 (24 files) matches the report; `gates.mjs` re-run by the supervisor gives 16 failing with G7/G9/G10a-e/G11a-g at 0; `broadcast_sessions.test.sql` has plan(22) and 22 assertions; no secret-shaped strings in the diff; ADR-006 embed base and referrer untouched (only a navigation allowlist was added). Not re-run by the supervisor: analyzer, the 268 tests, any SQL. Static read of the new migration found no syntax or grant errors (policy name and `broadcast_type` values match the older migrations) but one design gap, live flags with no server-side expiry: see the LEDGER RESUME block. Split plan is finished (two windows); the next run is `MODE: NEW_BUDGET`, `OWNER_CAP=90`, after the window resets.

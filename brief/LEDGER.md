# LEDGER

## Run header
- Started: 2026-09-20 Asia/Riyadh; inherited model/effort unchanged.
- Plan: SPLIT, detailed binding caps 70/60 and soft 64/54; introductory 80/80 conflicts, so use the stricter detailed rules and unchanged meter.
- Initial meter: used_5h=9.0, weekly=1.0, resets_in_min=34, cache_ttl=30m assumed. Old checked-in meter forced single; restored owner's exact stash updates, then split check OK at 11.0. --new-run was invoked only once; restored meter retains started_window_at_used=1.0.
- Baselines pending: analyze/tests; gates 18 failing, G10a-e all 0, G11a-c/e-g all 0, G11d=3.
- Tooling: Docker/graft unavailable on PATH; use rg; DB acceptance UNVERIFIED-STATIC. Supabase version probe blocked by telemetry filesystem permission; Flutter probe pending.

## Budget log
| Step | Window | Used 5h | Weekly | Status |
|---|---|---|---|---|
| Initial meter | 1 | 9 | 1 | OK, old meter forced single |
| Restored meter / P0 | 1 | 11 | 1 | OK split cap70 soft64 |

## Phase log
P0 in progress; estimate 1-2%, measured since entry 2 points so far. No implementation phase started.

## Decisions
- Resolve conflicting cap text conservatively using detailed budget rules; no meter edits.
- Restore named pre-existing stash before execution; keep original stash as backup and exclude its five paths from phase commits.
- D-24: graft missing, use rg and anchored line ranges.
- D-14: Docker missing, all DB behavior remains UNVERIFIED-STATIC until owner executes local probes.

## Evidence
- Meter --probe chose codex, primary 11%, secondary 1%, recent snapshot.
- gates --history: 18 failing gates; G10a-e=0; G11a-c/e-g=0; G11d=3 missing ignore coverage. No secret values emitted.

## NOT DONE
All implementation phases P1-P9; P0 baseline in progress.

## RESUME block
- Next: finish P0 tooling/baseline, then P1 in 03.
- Pre-existing five brief modifications restored; backup stash preexisting-before-budget-stop-2026-09-20 retained.
- First command: node brief/tools/budget_check.mjs --plan split. Never repeat --new-run this run.
- Last meter: 11% five-hour, 1% weekly, window1 OK.

## P0 checkpoint
- Flutter 3.41.2 / Dart 3.11.0; Supabase CLI 2.115.0; pub get succeeded; flutter analyze: 0 issues; flutter test: 264 passed, 0 failed. Existing test logs include caught provider-after-dispose/unconfigured-Supabase errors; suite passes.
- gates --history: 18 failing, G10a-e=0, G11a-c/e-g=0, G11d=3. Local tag pre-hardening-2026-09-19 created. No dependency file changes.
- P0 complete at E1 for app baseline; database acceptance UNVERIFIED-STATIC. Next P1.1 column guards. The previous OVERRUN_REPORT describes the earlier aborted run and will be replaced at this run's stop.

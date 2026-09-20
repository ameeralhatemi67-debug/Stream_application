# LEDGER

## Run header
- Started 2026-09-20, Asia/Riyadh. Inherited model/effort unchanged; no subagents.
- SPLIT. Detailed caps70/60 and soft64/54 take precedence over conflicting introductory80/80. Meter/caps not edited.
- Entry used_5h9, weekly1, resets_in_min34, cache_ttl30m assumed. First mandated command used --new-run once; checked-in old meter forced single. Restored owner's exact stashed updates; subsequent checks correctly reported split. Retained runtime started_window_at_used1; actual run deltas below start at observed9.
- Baseline: Flutter3.41.2/Dart3.11.0, Supabase CLI2.115.0, analyze0 issues, tests264 passed/0 failed, gates18 failing. Docker/graft unavailable on PATH; rg fallback; DB acceptance UNVERIFIED-STATIC.

## Budget log
| Step | Window | 5h used | Weekly | Result |
|---|---|---|---|---|
| Entry | 1 | 9 | 1 | OK, old meter forced single |
| Restore owner meter / P0 | 1 | 11 | 1 | OK split |
| P0 checkpoint / P1 start | 1 | 22 | 3 | OK |
| Live usage cross-check | 1 | 37 | 5 | File snapshot still22; use higher live value |
| Before P1 checkpoint | 1 | 40 | 6 | OK per live usage |
| P1 checkpoint | 1 | 44 | 7 | File meter caught up; OK, headroom26, soft margin20 |

## Phase log
| Phase | Estimate % | Observed start/end | Actual delta | Ratio | Result |
|---|---|---|---|---|---|
| P0 | 1-2 | 9/22 | 13 | 6.5-13x | Complete, commit3ba0eb7 |
| P1 partial | 12-16 for full phase | 22/44 | 22 | 1.4-1.8x full estimate already | Complete file changes for1.1/1.3/1.4 and direct-write1.5; source portion1.11; runtime DB UNVERIFIED |
| P2-P9 | 75-101 combined | not started | not measurable | N/A | Pending |

## Decisions
- Use detailed70/60 split caps unchanged, no push, no production Supabase operations.
- D-24: graft missing; anchored rg and line-range reads. D-14: Docker missing; write local probes, label SQL UNVERIFIED-STATIC.
- D-21: trigger functions stay SECURITY INVOKER so current_user distinguishes ordinary API writes from trusted owner-executed RPCs. Protect org ownership and lifetime counters too.
- Corrected03 P1.4 status anchor to accepted at initial_schema.sql:216. Invitee can accept an orgToStreamer invite only with unchanged owner-assigned permissions; requester cannot self-approve streamerToOrg.
- Use live account usage when file snapshots lag, without changing meter tools. Last file check caught up to44.
- Forecast stop before SOFT: next coupled live-state/device step estimated25-35 points, exceeding26 hard headroom minus3 reserve and20 soft margin. Do not start an incomplete RPC/client migration. Neither consecutive-step delta exceeded25.

## Evidence
- E1: full flutter test266 passed/0 failed; final flutter analyze0 issues. New namespace tests cover traversal and invalid identity. Corrected an import lint, then reran analyze and focused tests2/2.
- E2 static only: gates --history17 failing versus18 baseline; G10a-e0 and G11a-g0. Release artifact secret scan UNVERIFIED because no AAB built.
- UNVERIFIED-STATIC: four transactional new migrations;27 pgTAP assertions in broadcaster_columns.test.sql9, streamer_assets.test.sql7, application_and_ban_guards.test.sql11. Not executed without Docker.
- git diff --check clean. No app identity/theme/YouTube embedding changes. Existing custom card behavior retained; upload namespace and ban authorization hardened.
- Existing full-suite logs contain caught unconfigured-Supabase/provider-after-dispose errors; these were present at baseline, no test failures.

## NOT DONE
- P1.2/1.7 live-state and device RPCs/client integration,25-35 points estimated; P1.6/1.8/1.9/1.10 and RPC ban audit,10-15 more. P1.11 final AAB scan awaits P8A.
- P2 6-8, P3 4-6, P4 24-30, P8A6-9, P6 9-12, P5 10-14, P7 9-12, P8B4-6, P9 3-4 points remain original uncalibrated estimates. Remaining total110-151; actual burn may exceed these.
- No claim of release readiness, complete security/RLS, device/offline behavior, legal approval or Android store acceptance. No production migrations applied.

## Bonus attempt: 2026-09-20
- Owner authorized up to40 additional points. Live account reading at entry: five-hour55%, weekly8%. Six owner-provided bonus/settings files committed as cd0b698; neither stash applied or dropped.
- Required bonus-start returned STOP: used_5h1, weekly98, cap41, soft35, snapshot_age17431s, resets_in_min9. This contradicts the fresh live reading and initialized the allowance from stale data. Actual weekly exhaustion is NOT established.
- No application item started; no analyzer/tests rerun. Prior analyzer0/full266 passing baseline remains unchanged. Extra-spend delta unmeasured; only settings and stop bookkeeping changed. Meter source/caps were not edited by the agent.
- Budget-tool STOP is binding; bonus application work remains not started. P1.8/1.9/1.6/RPC audit/1.10 are still pending.

## Bonus retry, 30-point request
- Budget/phase row: 2026-09-20, window1, live start64% five-hour/10% weekly; meter start1%/98%, cap41, STOP, snapshot17657s old, reset5min. No application item started; implementation delta0, account bookkeeping delta unmeasured, duration under2min.
- The six owner settings files were already committed as cd0b698; tree was clean. Neither stash touched. Requested30-point allowance was not correctly initialized; no meter/cap edits attempted.
- NOT DONE unchanged: P1.8,1.9,1.6,RPC ban audit,1.10 and P1.2/1.7 remain pending. Analyzer0/full266 passing are prior-checkpoint evidence only; no tests, gates or builds rerun in this retry.

## RESUME block
- Next: P1.2 together with 1.7 (live-state + multi-device RPCs and client), then P1.8, 1.9, 1.6, the RPC ban audit, 1.10; then P2, P3, then later phases in plan order only if the forecast fits. FRESH session with `brief/RESUME_PROMPT.md`, `MODE: CONTINUE_SPLIT`, `OWNER_CAP=90` (owner-approved for window 2: cap 90, soft 84; never a third window; weekly >= 90 stops).
- Window 1 is over. Tree is clean at the latest commit. The two owner stashes are historical (content already committed): never apply, pop or drop them.
- Meter (fixed 2026-09-20, see 04 §I): first command `node brief/tools/budget_check.mjs --plan split --cap 90` (never `--new-run`), expect window=2 cap=90 soft=84; pass `--cap 90` on every check. A stale log reading is UNKNOWN, not STOP: read usage from the Codex display and add `--live-used N --live-weekly W --live-resets-in-min R`.
- Baseline (Astra-reported, not re-run by the supervisor): analyzer 0, 266 tests, gates 17 failing vs 18 baseline. New SQL is UNVERIFIED-STATIC.
- Bookkeeping: append short rows, do not rewrite documents; leave at least 6 points under the cap for the closing pass.

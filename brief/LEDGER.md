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

## NOT DONE (window-1 view, SUPERSEDED by the last RESUME block)
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

## RESUME block (window 1, SUPERSEDED by the last RESUME block)
- Next: P1.2 together with 1.7 (live-state + multi-device RPCs and client), then P1.8, 1.9, 1.6, the RPC ban audit, 1.10; then P2, P3, then later phases in plan order only if the forecast fits. FRESH session with `brief/RESUME_PROMPT.md`, `MODE: CONTINUE_SPLIT`, `OWNER_CAP=90` (owner-approved for window 2: cap 90, soft 84; never a third window; weekly >= 90 stops).
- Window 1 is over. Tree is clean at the latest commit. The two owner stashes are historical (content already committed): never apply, pop or drop them.
- Meter (fixed 2026-09-20, see 04 §I): first command `node brief/tools/budget_check.mjs --plan split --cap 90` (never `--new-run`), expect window=2 cap=90 soft=84; pass `--cap 90` on every check. A stale log reading is UNKNOWN, not STOP: read usage from the Codex display and add `--live-used N --live-weekly W --live-resets-in-min R`.
- Baseline (Astra-reported, not re-run by the supervisor): analyzer 0, 266 tests, gates 17 failing vs 18 baseline. New SQL is UNVERIFIED-STATIC.
- Bookkeeping: append short rows, do not rewrite documents; leave at least 6 points under the cap for the closing pass.

## Window 2 checkpoint, 2026-09-20
| Step | Estimate | Observed usage | Delta | Result |
|---|---|---|---|---|
| Resume baseline | unestimated | 3 to 17 | 14 | analyzer0; 265 pass/1 timing failure; gates17 |
| P1.2 + P1.7 | 25-35 | 17 to 54 | 37 | source checkpoint; SQL/device runtime unverified |
| P1.8 + P1.9 | 8-15 | 54 to 70 | 16 | private disabled; debug tools; navigation allowlist |
| Closing verification | reserve | 70 to 83 | 13 | analyzer0; full268 passed; gates16; diff-check clean |
- Fresh account readings override lagging logs. Window2, cap90 owner, soft84, weekly23 at used83. No meter/cap edits, no push, no stash changes. Initial stale UNKNOWN recovered from the Codex usage tool.
- Decisions: canonical live ownership is the caller profile, mirrored to the selected verified org; one global transaction lock serializes claims/live changes. Migration clears untrusted prior live/primary flags. Optional org ID and explicit force flag support org permission checks and confirmed transfer. Non-primary/unconfigured clients fail closed; prior simulation-success tests now assert denial. SQL has22 new pgTAP assertions, UNVERIFIED-STATIC without Docker. YouTube embed base/referrer unchanged; blank initialization plus HTTPS YouTube hosts allowed.
- Baseline timing failure: issue_log_fixes_test.dart, StreamDecayEngine monitors heartbeats and decays on timeout. Passed focused and final full runs. Startup stalled until --no-version-check --suppress-analytics and --no-pub; Flutter/Dart needed SDK/cache access. One late meter call used project/ incorrectly and failed to locate the script; immediately reran from repo root. No reading inferred from that failure.
- Final evidence: flutter --no-version-check --suppress-analytics analyze --no-pub:0 issues; test --no-pub --reporter compact:268 pass; gates.mjs --history:16 failures, G7/G9/G10a-e/G11a-g0; git diff --check clean. New native/realtime behavior and local SQL remain unverified. Test logs in the OS temp directory. No release build.
- Forecast stop: remaining P1.6 + RPC-ban audit + P1.10 now estimated25-40 points, exceeding14 points to soft at closing start70. P2 onward retains prior uncalibrated estimates. P1 is NOT complete.

## RESUME block (window 2, SUPERSEDED by the last RESUME block)
- Next: P1.6 dev-identity removal, then RPC-ban audit and P1.10 policy matrix/catalog/privilege review; P1.11 release artifact scan remains deferred to P8A. Then P2, P3, P4, P8A, P6, P5, P7, P8B, P9 in plan order. P1.2/1.7 source changes and P1.8/1.9 are checkpointed; do not claim runtime acceptance until local SQL and real-device probes pass.
- SPLIT window2 used83 at closing checkpoint, cap90 owner, soft84; never enter window3. This run is stopping, not waiting. Owner must authorize any subsequent run; CONTINUE_SPLIT cannot grant a third window. No --new-run in this run.
- Files in flight: none after the single local checkpoint commit. Both historical owner stashes remain untouched. No production Supabase operations or push.
- Re-run baseline from project/: flutter --no-version-check --suppress-analytics analyze --no-pub; flutter --no-version-check --suppress-analytics test --no-pub --reporter compact. From root: node brief/tools/gates.mjs --history. Use SDK/cache permissions if needed; meter checks always from root with --plan split --cap90 spelled as --cap 90.
- Post-commit meter: SOFT plan=split window=2 used_5h=85 cap=90 cap_source=owner soft=84 weekly=23. Tree clean; both owner stashes unchanged. Closing delta15 (70-85); total session delta82 (3-85). No further work.
- Next session (owner-authorized): `MODE: NEW_BUDGET`, `OWNER_CAP=90`, one fresh window. Meter: `node brief/tools/budget_check.mjs --plan single --new-run --cap 90` once at Step 0, then `--plan single --cap 90` on every check (still one window only; weekly >= 90 stops).
- Entry baseline: do not re-run the full suite at entry (it cost 14 points last time, mostly SDK/cache startup). The evidence at commit b61b3f7 is the baseline (analyzer 0, 268 tests, gates 16); run analyze plus the tests you touch, and the full suite at each phase checkpoint, with the flutter flags above.
- Supervisor follow-ups from a static read of `20260920120000_guarded_broadcast_sessions.sql` (not run): (1) a live flag has no server-side expiry: if the broadcaster's phone dies, the profile/org stays live, and `set_live_state` needs a fresh primary heartbeat even to end. Add after P1.10: viewer-facing reads count a stream as live only while the owner's primary device heartbeat is under 90 s old, or a scheduled sweep clears it. (2) `claim_broadcaster_device` evaluates `can_broadcast` for every organization per call: fine now, revisit at scale. (3) the migration wipes all live flags when applied (already in OWNER_ACTIONS).
- Harness note (supervisor): the next session may be Claude Code (Opus, `OWNER_CAP=85`, `--source claude`, see `brief/OPUS_PROMPT.md`) or Astra (`OWNER_CAP=90`, `--source codex`). The paste prompt's harness and cap govern; the RESUME steps above still apply. Run one harness at a time on this repo.
- Design scope (owner, 05 D-27): P4 and P8A (redesign, logo, icon) are reserved for Astra and wait for `DESIGN_CHOICE`; a Claude Code (Opus) session stops after P3, or continues only with P6, P5, P7, P8B, and never starts P4, P8A or P9.

## P1c — Claude Code Opus, window 1 (2026-09-20)
- Harness: Claude Code Opus, high effort, MODE WORK_LIVE, OWNER_CAP=80, owner reading at entry 2% 5h / 22% 7d. No meter calls this session (owner instruction); pacing by judgement. Docker absent (`docker ps` fails) so no `supabase start`/`test db`: all SQL is UNVERIFIED-STATIC.
- Decisions logged: (1) admin seed rows that fabricated a pending review queue were removed here rather than in P2, because they were the same lines as the dev-identity removal; coverage moved to `project/test/fixtures/admin_applications.dart`. (2) `is_banned(uuid)` ships as `20260920110000`, timestamped BEFORE the migration that calls it — that migration cannot have applied anywhere, since `can_broadcast` is SQL-language and its body is parsed at creation. (3) `release_broadcaster_device` keeps no ban check: stopping a broadcast is de-escalation. (4) `delete_own_account` keeps no ban check: PDPL erasure is not a privilege. (5) Three `for all` privilege tables split per command; the other seven `for all` policies and the pre-20260920 policies missing `to authenticated` are recorded as open in the matrix, not silently left. (6) A banned-user ban probe (`is_banned(uuid)`) is granted to no client role.
- Evidence: `flutter analyze --no-pub` 0 issues; `flutter test --no-pub` 269 passed / 0 failed (268 at baseline + 1 new P1.6 test); `node brief/tools/gates.mjs` 16 failing = baseline 16, with G1c 13->6, G7/G9/G10a/G10c/G10d/G11a-f at 0; `git diff --check` clean; commit e94fb13, tree clean, both owner stashes untouched.
- SQL added, UNVERIFIED-STATIC: 3 migrations (`20260920110000`, `20260920130000`, `20260920140000`) and 18 new pgTAP assertions in `supabase/tests/live_flag_expiry_and_privilege.test.sql`. Nothing was applied to any database.
- NOT DONE in P1c: G1c is 6, not 0 — the rest is P2 fixture data (`vod_models`, `map_models`, `streamer_models`, `protectedStreamerIds`, `triggerSimulatedNotification`). P1.10(b) policy splits for the remaining seven `for all` tables and the missing `to authenticated` clauses. `log_audit_event` still accepts any `p_organization_id` (P7). P1.11 release-artifact scan still waits on P8A. No real-device or live-database verification of any of this.

## P2 — Claude Code Opus, window 1 (2026-09-20)
- Two commits: d646053 (catalog starts empty; RTMP spike and VLC deleted) and 8ecba34 (simulated chat, VOD archive, Q&A pool, stand-in counts and venue presets deleted).
- Decisions logged: (1) fixtures moved to `project/test/fixtures/` (`streamer_fixtures`, `vod_fixtures`, `qa_fixtures`, `admin_applications`) with `seedStreamerFixtures()` and a new `setStreamerMediaForTests()` seam, so coverage is kept rather than deleted (D-17). (2) The offline chat fallback was deleted, not flag-gated: a banner over invented conversation is still invented conversation, and G1e counts the code itself. (3) The client-side "protected streamer" id list was removed — deleting a real channel is an RLS decision, not a client list. (4) `getAuditoriumInfoForStreamer` keeps its generic default branch (capacity/gate wording) — real venue data is P5, logged as open. (5) IVS and Web player adapters were kept: unused but not simulated content, and removing them narrows a public enum.
- Evidence: `flutter analyze --no-pub` 0 issues; `flutter test --no-pub` 267 passed / 0 failed (269 before; the 2 retired tests covered the deleted simulated-chat pool); `node brief/tools/gates.mjs` 10 failing versus 16 at baseline, with G1a/G1c/G1d/G1e/G5a/G5b newly at 0 and G7/G9/G10a/c/d/G11a-f still at 0; `git diff --check` clean.
- NOT DONE in P2: G1b (3 `FeatureInProgressModal` sites), G5c (the GADM map asset), the 8.1 MB fixture image folders and their pubspec entries, follows/bookmarks persistence (D-07), play/pause/mute wired to the iframe controller, RSVP/raise-hand/slides/multi-speaker flags, and `startQuickPhoneBroadcast`. P3 (true viewer count) was not started.

## RESUME block (2026-09-20, Claude Code Opus window 1)
- Harness this session: Claude Code Opus 5, high effort, MODE WORK_LIVE, OWNER_CAP=80, no meter calls (owner instruction). The next session may be Astra with `--source codex`, or Claude Code with `--source claude`; whichever runs, restore the meter first (`brief/04` §A) — this run had none.
- Next: finish P2 (G1b modal sites, G5c GADM asset, fixture image folders, D-07 follows/bookmarks, play/pause/mute), then P3 (true viewer count: `stream_viewers` + `viewer_heartbeat`/`get_viewer_counts` + `ViewerPresenceService`). Only then P6, P5, P7, P8B. Never P4, P8A, P9 (Astra, 05 D-27).
- State: tree clean at commit 8ecba34 on master; nothing pushed; both owner stashes untouched. Commits this session: e94fb13 (P1c), d646053 and 8ecba34 (P2).
- Baseline for the next session: analyzer 0, `flutter test` 267 passed, gates 10 failing. Run from `project/` with `flutter --no-version-check --suppress-analytics ... --no-pub`; gates from the repo root.
- Docker was unavailable (`docker ps` fails), so every migration and all 18 new pgTAP assertions in `supabase/tests/live_flag_expiry_and_privilege.test.sql` are UNVERIFIED-STATIC. Nothing was applied to any database.
- Read before touching SQL: `supabase/tests/policy_matrix.md` (access matrix + 4 open items) and the P1c entries in `brief/OWNER_ACTIONS.md` — especially that `20260920110000_is_banned_helper.sql` must apply before `20260920120000`.
- P1 is still not complete: P1.10(b) policy splits for seven `for all` tables, the missing `to authenticated` clauses, `log_audit_event`'s organization check (P7), and P1.11's release-artifact scan (waits on P8A).

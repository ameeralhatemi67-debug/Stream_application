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
- Next: P1.2 together with 1.7 (live-state + multi-device RPCs and client), then P1.8, 1.9, 1.6, the RPC ban audit, 1.10; then P2, P3, then later phases in plan order only if the forecast fits. FRESH session with `brief/archive/prompts/RESUME_PROMPT.md`, `MODE: CONTINUE_SPLIT`, `OWNER_CAP=90` (owner-approved for window 2: cap 90, soft 84; never a third window; weekly >= 90 stops).
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
- Harness note (supervisor): the next session may be Claude Code (Opus, `OWNER_CAP=85`, `--source claude`, see `brief/archive/prompts/OPUS_PROMPT.md`) or Astra (`OWNER_CAP=90`, `--source codex`). The paste prompt's harness and cap govern; the RESUME steps above still apply. Run one harness at a time on this repo.
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

## RESUME block (2026-09-20, Claude Code Opus window 1, SUPERSEDED by the last RESUME block)
- Harness this session: Claude Code Opus 5, high effort, MODE WORK_LIVE, OWNER_CAP=80, no meter calls (owner instruction). The next session may be Astra with `--source codex`, or Claude Code with `--source claude`; whichever runs, restore the meter first (`brief/04` §A) — this run had none.
- Next: finish P2 (G1b modal sites, G5c GADM asset, fixture image folders, D-07 follows/bookmarks, play/pause/mute), then P3 (true viewer count: `stream_viewers` + `viewer_heartbeat`/`get_viewer_counts` + `ViewerPresenceService`). Only then P6, P5, P7, P8B. Never P4, P8A, P9 (Astra, 05 D-27).
- State: tree clean at commit 8ecba34 on master; nothing pushed; both owner stashes untouched. Commits this session: e94fb13 (P1c), d646053 and 8ecba34 (P2).
- Baseline for the next session: analyzer 0, `flutter test` 267 passed, gates 10 failing. Run from `project/` with `flutter --no-version-check --suppress-analytics ... --no-pub`; gates from the repo root.
- Docker was unavailable (`docker ps` fails), so every migration and all 18 new pgTAP assertions in `supabase/tests/live_flag_expiry_and_privilege.test.sql` are UNVERIFIED-STATIC. Nothing was applied to any database.
- Read before touching SQL: `supabase/tests/policy_matrix.md` (access matrix + 4 open items) and the P1c entries in `brief/OWNER_ACTIONS.md` — especially that `20260920110000_is_banned_helper.sql` must apply before `20260920120000`.
- P1 is still not complete: P1.10(b) policy splits for seven `for all` tables, the missing `to authenticated` clauses, `log_audit_event`'s organization check (P7), and P1.11's release-artifact scan (waits on P8A).

## P2 completion, P3, P6.1 — Claude Code Opus, second session (2026-09-20)
- Mode WORK_LIVE, no meter calls (owner instruction; owner reported ~51% five-hour at entry with ~45 points authorized). Docker still absent, so all SQL stays UNVERIFIED-STATIC. Commits: d83bd4a (P2 complete), 18d7b82 (P3), 298db4b (P6.1 slice).
- P2 decisions: the three `FeatureInProgressModal` sites became real actions (bookmark, two share_plus shares) and the modal plus its i18n block were deleted; `YouTubeLiveService`/`startQuickPhoneBroadcast` deleted outright (no production caller, minted fake broadcast ids and stream keys); venue RSVP hidden behind `kVenueRsvpEnabled=false` while the real venue address stays; raise-hand wired to the existing Realtime reaction channel instead of being hidden, since that backend exists; backend row mappers stopped inventing avatars, verification, coordinates and a 'dQw4w9WgXcQ' video id; `extractYouTubeId` returns '' instead of that id; the applicant wizard no longer offers real people's photographs as adoptable avatars.
- P3 decisions: `stream_viewers` is deny-all (RLS on, zero policies) with the intent in `comment on table`; `viewer_heartbeat` keys signed-in viewers by `auth.uid()` whatever the client sends, refuses non-live streams and the broadcaster's own account; `get_viewer_counts` returns a row per requested id; unknown counts render "—" everywhere; YouTube's concurrent figure was moved out of `activeViewerCount` into its own map, shown only in the studio labelled "on YouTube".
- P6.1 decisions: `chat_enforce_rate_limit` is SECURITY INVOKER per D-21 so `current_user` still distinguishes trusted RPC writes; the 1.2 s floor applies to moderators too (flood guard), slow mode does not (a broadcaster must be able to answer); `chat_reports` already had `unique(message_id, reporter_id)`, so that P6.1 item needed nothing.
- Evidence: `flutter analyze --no-pub` 0 issues; `flutter test --no-pub` 264 passed / 0 failed; `node brief/tools/gates.mjs` 8 failing, down from 16 at the b61b3f7 baseline, with **G1a-G1e and G5a/G5b/G5c all at 0** and G7/G9/G10a/c/d/G11a-f at 0; G10b lists only `stream_viewers` (the intended deny-all table) and G10e the two documented anon grants; `git diff --check` clean. The 8 remaining gates are G2a/G2b/G2d, G3, G4a/G4b, G6, G8 — all design scope, reserved for Astra (05 D-27).
- Test count moved 267 -> 260 -> 264: 7 tests retired with the simulated broadcast service they covered (documented in place), 4 new presence tests added.
- NOT DONE: P6.2 composer UX, P6.3 admin linkage, P6.4 admin tools; Arabic-aware normalisation in the keyword trigger and a report-reason enum (P6.1 remainder); the default avatar placeholder is still a real person's photo and `assets/images/Amir_Alhatemi/` is still 7.6 MB (needs a neutral asset = Astra's scope); P5, P7, P8B untouched; P1.10(b) policy splits for the seven remaining `for all` tables and the missing `to authenticated` clauses; `log_audit_event` organization check (P7).

## RESUME block (2026-09-20, Claude Code Opus session 2)
- HEAD is 298db4b on master, tree clean, nothing pushed, both historical owner stashes untouched (never apply, pop or drop them).
- Completed this session: **P2 in full** (G1a-e and G5a/b/c at 0), **P3 true viewer count**, and a **P6.1 slice** (server-side chat rate limit, slow mode, chat-off). P1 remains partial — see the P1c NOT DONE row above.
- Verification at close: analyzer 0 issues, `flutter test` 264 passed / 0 failed, gates 8 failing (16 at baseline), `git diff --check` clean. Run from `project/` with `flutter --no-version-check --suppress-analytics ... --no-pub`; gates from the repo root.
- SQL status: **UNVERIFIED-STATIC**. Docker was unavailable both sessions, so none of the 7 new migrations has been applied and none of the 56 new pgTAP assertions has run. `20260920110000_is_banned_helper.sql` must apply before `20260920120000`.
- Exact next step: P6.2 (composer states for muted/slow-mode/offline/banned, guest read-only, report/block action sheet) and P6.3 (reports reaching the admin queue live), then P6.4 admin tools in the order listed in 03. After P6: P5, P7, P8B.
- Read first next session: this block, `supabase/tests/policy_matrix.md`, and the P1c + second-session entries in `brief/OWNER_ACTIONS.md`.
- Design remains reserved for Astra (05 D-27): P4, P8A and P9 are not to be started by a Claude Code session, and the 8 failing gates are all design gates. Do not chase them.

## P1d — Claude Code Opus, 2026-09-21: Docker worked, and the SQL is verified for the first time

- Mode P1_POLICY_QUALITY, owner cap supplied in-session, no meter calls. Entry checks: `git --no-optional-locks status` clean apart from the pre-existing `Roadmap.md` edit and untracked `skill-observations/`; `git stash list` shows the two historical owner stashes, untouched all session; **`docker ps` succeeded**. The local stack was started with the heavy services excluded (`-x studio,imgproxy,inbucket,mailpit,edge-runtime,logflare,vector,supavisor,pgbouncer`). Nothing was run against the linked production project.
- **The real reason the SQL was UNVERIFIED was not only Docker: the migration chain could not be applied at all.** It aborted twice, so nothing after `20260830170000` had ever reached any database — the whole `20260831*` and `20260920*` set included.
  1. `20260830180000_map_visibility_toggle.sql` re-adds `latitude, longitude` into the middle of the `streamer_public_profiles` select list with `create or replace view`; PostgreSQL only appends columns, so `42P16: cannot change name of view column "youtube_handle" to "latitude"`. Repaired by the new `20260830175000_realign_streamer_public_view.sql` (D-29).
  2. `20260920140000_policy_quality.sql` revoked/granted `chat_sender_info(uuid[])`, dropped back in `20260830160000` in favour of `chat_sender_info(uuid[], text default null)`: `42883`. Two dead statements removed from that file — the only edit to an existing migration this session, safe because the migration provably could never have applied (D-28).
- **Biggest finding: 110 RLS policies over tables that granted the API roles no DML.** Once the chain ran, 7 of 8 pgTAP files died on `42501 permission denied for table ...` against tables whose policies were correct. Only 4 objects had ever been granted to `anon`/`authenticated`. Privileges are checked before RLS, so every policy was unreachable and a schema rebuilt from these migrations cannot read or write anything. Latent rather than a live outage: `[api] auto_expose_new_tables` is unset, matching the current cloud default, while the production project predates that change. Fixed by `20260921110000` with a minimal per-table grant set derived from the commands that actually have a policy (D-30, D-31).
- P1 scope completed: the 7 remaining `for all` policies are split per command (R6b asserts none remain); all 32 policies that omitted a role clause were dropped and recreated with an explicit `to authenticated` (R6a asserts none is addressed to PUBLIC), predicates copied from the live catalog rather than retyped, with `auth.uid()` rewritten as `(select auth.uid())`; `terms_select_public` and the renamed `streamer_assets_select_public` are the two deliberate `anon` reads; `stream_viewers` deny-all is now reinforced with `revoke all`; `log_audit_event()` refuses an organization the caller neither belongs to nor administers (D-32); `search_path` pinned on the two SECURITY INVOKER functions that lacked it.
- New verification artifact: `supabase/tests/rls_catalog.test.sql`, the 06 §2b R-probes (20 assertions, R1-R8) plus **R10/R11**, which assert privileges and policies agree in both directions — the regression guard for the bug above.
- Four pgTAP fixes, three of them harness defects the first real run exposed (D-34, D-35): `viewer_presence` and `follows_and_bookmarks` now `throws_ok` on `42501` where a revoke turned an empty read into an error; `streamer_assets` asserts `can_write_streamer_asset()` instead of a direct `delete from storage.objects`, which the storage schema's `protect_objects_delete` trigger refuses before RLS and which cannot be disabled (`postgres` is not a member of `supabase_storage_admin`); `chat_rate_limit` uses `Salaam` instead of `Hello`.
- **Real product bug found, left for P6:** `chat_check_banned_keywords` matches bare substrings and the seeded blocklist contains `hell`, so the message **`Hello` is rejected as profanity**. Recorded as owner action 4 and open item 6 in the matrix; not fixed here because word-boundary matching plus Arabic-aware normalisation is P6 scope.
- **NOT DONE, needs the owner (D-33):** `streamer_public_profiles` exposes individual broadcasters' exact `latitude`/`longitude` to `anon`, reopening VULN-COMP-02 that `20260822140000` had closed. Restoring the columns was forced by the chain repair. Every remedy changes what the map shows, so owner action 2 lists the three options with the SQL for the rounding one rather than choosing.

### Evidence (P1d)
| Check | Command | Result |
|---|---|---|
| Migrations | `npx supabase db reset --local` | all **45 apply, exit 0** (first time ever) |
| Database probes | `npx supabase test db --local` | **9 files, 125 tests, all pass, exit 0** (was 8 files / 60 tests attempted, 7 files failing) |
| Linter | `npx supabase db advisors --local --type security` | **2 ERRORs, both the documented `security_definer_view` exceptions**; nothing else |
| Analyzer | `flutter --no-version-check --suppress-analytics analyze --no-pub` | **0 issues** |
| Full suite | `flutter --no-version-check --suppress-analytics test --no-pub --reporter compact` | **264 passed / 0 failed** (identical to baseline; no Dart changed) |
| Static gates | `node brief/tools/gates.mjs` | **8 failing = baseline 8**, all design scope (G2a/G2b/G2d, G3, G4a/G4b, G6, G8). G10a/c/d = 0, G11a-f = 0, G7/G9 = 0. G10b = `stream_viewers` only. G10e = 3, all `execute` on the documented anon functions (`viewer_heartbeat`, `get_viewer_counts`, `chat_sender_info`); no anon write grant exists (R3c asserts it) |

- **SQL evidence tier moves from `UNVERIFIED-STATIC` to E2.** Still unverified: anything needing real hardware or the production database — RTMP on physical phones, multi-device scenarios, and whether production's live schema matches this chain.

## RESUME block (2026-09-21, Claude Code Opus, P1d)
- HEAD is the single P1d commit on master, tree clean, **nothing pushed**, both historical owner stashes untouched (never apply, pop or drop them). No production Supabase operation was performed.
- **Docker works on this machine.** Start the stack with `npx supabase start -x studio,imgproxy,inbucket,mailpit,edge-runtime,logflare,vector,supavisor,pgbouncer` (only `postgres:16` was cached at entry, so the first pull took a few minutes; the images are cached now). Then `npx supabase db reset --local`, `npx supabase test db --local`, `npx supabase db advisors --local --type security`. Always pass `--local`: the project is linked to `zkkmfjsjouqzibvnzkau`.
- Baseline for the next session: analyzer 0, `flutter test` **264 passed**, gates **8 failing** (all design), pgTAP **125 passing across 9 files**, advisors 2 justified ERRORs. Run Flutter from `project/` with `flutter --no-version-check --suppress-analytics ... --no-pub`; gates and Supabase from the repo root.
- P1 status: the policy-quality and audit-scope work is **done and verified**. What remains under P1 is not policy work — `log_audit_event`'s per-capability organization model (P7) and P1.11's release-artifact secret scan (waits on P8A).
- Exact next step: **P6.2** (composer states for muted / slow-mode / offline / banned, guest read-only, report+block action sheet), then **P6.3** (reports reaching the admin queue live), then **P6.4** admin tools, in the order in `03_WORK_PLAN.md`. Fold the `Hello`/`hell` substring bug and the Arabic-aware normalisation into P6. After P6: P5, P7, P8B.
- Read first next session: this block, the P1d section above, `supabase/tests/policy_matrix.md` (now E2, with 6 open items — items 5 and 6 are real findings, not shape), and the **P1d entries in `brief/OWNER_ACTIONS.md`** — three of them need an owner decision before any `db push`.
- Design stays reserved for Astra (05 D-27): P4, P8A and P9 are not to be started by a Claude Code session, and all 8 failing gates are design gates. Do not chase them.

## P6a — Claude Code Opus, 2026-09-21: keyword filter, P6.2 composer, P6.3 audit + live queue

- Mode CONTINUE_HARDENING_P6, owner cap 75% of the current five-hour window. Entry: tree clean apart from the owner's `Roadmap.md` edit and untracked `skill-observations/` (neither touched); both historical owner stashes untouched all session; `docker ps` healthy with the local stack already up from P1d, so it was reused rather than restarted. Nothing was run against the linked production project.
- **Budget note.** `budget_check.mjs --plan single --cap 75` returned `status=STOP reason=window_rolled_under_single_plan` at entry, with `used_5h=3.0 weekly=24.0 headroom=71.0 soft=69`. That STOP is the *previous* run's "one window only" bookkeeping objecting to a rolled window, not a budget breach — the owner's paste authorises this window at cap 75, which is the authorisation the tool reported missing. Work proceeded, paced against `used_5h`; no budget file, snapshot or cap was edited and `--new-run` was never passed. `used_5h` was 4.0 at the close, `weekly` 25.0.
- Three commits: `7540fb4` (keyword filter), `448f253` (P6.2 composer), `e43b1aa` (P6.3 audit + live queue).

### A — the keyword filter matched bare substrings (`7540fb4`)
- The filter was `body ilike '%' || keyword || '%'` and the seeded blocklist contains `hell`, so **`Hello` was rejected as profanity** — with `shell`, `Michelle` and `hello there`. Found in P1d the first time `chat_rate_limit.test.sql` ran against a database.
- Matching is now word-bounded: message and keyword are normalized, non-word runs collapse to a single space, both are padded, and the test is a plain substring search for `' keyword '` in `' body '`. No regex is built from admin-supplied text (so `.`, `*`, `[` in a keyword are data, not a pattern, and cannot backtrack), and multi-word phrases on the seeded list (`shut up`, `kill yourself`) still match, which a per-word check would miss.
- The trade, decided and documented rather than hidden: an inflected form is a different word, so `stupidly` is no longer caught by `stupid`. `chat_banned_keywords` therefore gains a per-row `match_mode`; an admin can set one keyword back to `'substring'` where catching every inflection matters more than false positives. Nothing became an allowlist — every listed keyword still blocks, and a `'substring'` row behaves exactly as the whole filter did before.
- Arabic normalization, which the old `ilike` did not do at all: tashkeel and tatweel stripped, alef / alif-maqsura / ta-marbuta / hamza-carrier variants unified, Latin case folded. The word-boundary limit in Arabic is documented — an attached clitic (`الغبي`) is a different word, same as `hells`.
- `chat_first_banned_keyword()` is revoked from every client role: it would otherwise be an oracle for enumerating the blocklist one guess at a time. `chat_normalize_text` and `chat_boundary_form` are revoked too — **EXECUTE on a new function defaults to PUBLIC**, which R5a in `rls_catalog.test.sql` caught on the first run. The P1d probe paid for itself inside a day.

### B — P6.2 composer (`448f253`)
- The composer was always enabled. A guest, a muted account, a banned account, someone in a chat the broadcaster had turned off, and someone inside a slow-mode window could all type and only learn it was impossible when the insert was refused. Every one of those rules was already enforced server-side by P6.1 and none was visible.
- `LiveChatController` now derives one `ChatComposerState` from the real rules, highest precedence first: `banned`, `guest`, `chatDisabled`, `muted`, `offline`, `slowMode`, `ready`. Precedence is the point — a banned account is never told to wait out a countdown. Moderators are exempt from `chatDisabled` and `slowMode` so a broadcaster can still explain why chat is off.
- A refused send no longer drops what the viewer typed: the optimistic echo stays, marked failed, with the server's own reason, and offers Retry **only where a second attempt could succeed**. A banned keyword or a closed chat will be refused identically forever, so those offer Discard only rather than a button that lies.
- Also: empty state (an empty room stays empty, 05 D-03), a New-messages pill so a busy chat never yanks the list from under someone reading back, and `_currentUserId` now tolerates an uninitialized Supabase so an unconfigured build renders a read-only room instead of throwing.
- `chat_stream_settings` and `chat_reports` joined the realtime publication (`20260921130000`). `chat_muted_users` deliberately did **not**: a muted account reading its own row would learn which moderator muted it, which is a harassment vector. `chat_is_muted()` is already SECURITY DEFINER, so the client asks instead — on start, after any refused send, and when one of its own messages is deleted.

### C — P6.3 admin linkage (`e43b1aa`)
- No moderation action was ever audited. Dismiss, delete-and-resolve, mute-and-resolve, the platform-wide ban and the two in-room moderator actions now all write `log_audit_event` at platform scope (null organization, which the P1d guard accepts precisely because moderating a message belongs to no organization). Deleting your own message is not audited — that is not moderation.
- **And those writes would all have failed silently.** `audit_logs.action` carries a CHECK constraint enumerating the 19 `OrgAuditAction` values, every one an organization action. The chat action names are not among them, so each insert would be rejected `23514` — and because an audit write must never undo a mute that already took effect, the call sites are best-effort try/catch, so the rejection would have been swallowed and the moderation audit trail would have been uniformly empty with nothing reporting a problem. `20260921140000` extends the constraint with the four chat values rather than dropping it (an open `action` column would let a typo become a permanent, unqueryable category). Found by calling `log_audit_event` as a real API role in pgTAP, not by reading the call sites.
- The report queue was polling; `chat_reports` is now published, so `AppProvider` subscribes and a report reaches an open admin queue without a reload. Its SELECT policy is admin-tier only, so a non-admin subscriber receives nothing even though any client can open the channel — Realtime applies RLS per subscriber; the subscription is delivery, the policy is enforcement.
- Fixed a latent crash in `LiveChatController.deleteMessage`: it resolved the target with `firstWhere` and would have thrown for a message not in this client's list — the normal case for an admin acting from the queue.

### Evidence (P6a close)
| Check | Command | Result |
|---|---|---|
| Migrations | `npx supabase db reset --local` | all **48 apply, exit 0** |
| Database probes | `npx supabase test db --local` | **11 files, 179 tests, all pass, exit 0** (155 at P1d; +30 keyword filter, +24 moderation authority, minus plan adjustments) |
| Linter | `npx supabase db advisors --local --type security` | **2 ERRORs, both the documented `security_definer_view` exceptions**; nothing new |
| Analyzer | `flutter --no-version-check --suppress-analytics analyze --no-pub` | **0 issues** |
| Full suite | `flutter --no-version-check --suppress-analytics test --no-pub --reporter compact` | **287 passed / 0 failed** (264 at P1d; +23 in `chat_composer_state_test.dart`) |
| Static gates | `node brief/tools/gates.mjs` | **8 failing = baseline 8**, all design scope (G2a/G2b/G2d, G3, G4a/G4b, G6, G8). G7 = 0 (en/ar symmetric, 132 `live.*` keys each), G9 = 0, G10a/c/d = 0, G11a-f = 0 |
- G6 moved 467 → 471. Its regex is `Text\(\s*'[A-Za-z][^'$]{3,}'`, which also matches `Text('live.chat_empty_title'.tr())` — it counted the new **correctly localized** keys, not new hard-coded English. Recorded so nobody later reads it as a regression.
- SQL evidence tier stays **E2**. Unverified still: real hardware, multi-device, and whether production's schema matches this chain.

### NOT DONE
- **P6.4 (D) was not started.** It is the remaining bulk of P6 and was left at a clean boundary rather than half-built, because a partially finished privileged admin tool is the worst outcome for a hardening run. Survey findings for whoever picks it up:
  - (1) **User directory** is genuinely missing. The existing "Viewers" admin tab is a KPI/analytics panel, not a directory. `profiles_select_admin` already lets an admin read every profile, and `banned_users` / `chat_reports` admin reads exist, so search and most of the detail sheet are client work — **but `device_sessions` has exactly one policy, `device_sessions_select_own`**, so an admin cannot read another account's devices. That needs a new admin SELECT policy or a definer RPC in a new migration. Admin-initiated account deletion also has no path today (`delete_own_account()` is self-only).
  - (2) Live controls, (3) audit-log viewer, (4) keyword manager, (5) `app_flags` kill switches (no such table yet), (6) stale deleted-account visibility via realtime DELETE — all untouched.
  - (4) is now more valuable than it was: word-boundary matching means admins need a UI to add inflected variants and to flip a keyword to `match_mode = 'substring'`.
- P6.1 remainder that is now closed: Arabic-aware normalisation in the keyword trigger (done here). Still open from P6.1: a report-reason enum (the four reason codes are still client-side constants in `chat_message_actions_sheet.dart`), and `chat_user_blocks` server-side viewer blocks (D-09) — blocking is still per-device `SharedPreferences`.
- P5, P7, P8B untouched. The GPS/VULN-COMP-02 owner decision from P1d is **still unresolved and was not touched**, as instructed.

## RESUME block (2026-09-21, Claude Code Opus, P6a)
- HEAD is `e43b1aa` on master, tree clean, **nothing pushed**, both historical owner stashes untouched (never apply, pop or drop them). The owner's `Roadmap.md` edit and `skill-observations/` are still uncommitted and were deliberately left alone. No production Supabase operation was performed.
- **Docker works and the local stack is running.** Reuse it: `npx supabase db reset --local`, `npx supabase test db --local`, `npx supabase db advisors --local --type security`. Always `--local` — the project is linked to `zkkmfjsjouqzibvnzkau`. To start it cold: `npx supabase start -x studio,imgproxy,inbucket,mailpit,edge-runtime,logflare,vector,supavisor,pgbouncer`.
- Baseline for the next session: analyzer 0, `flutter test` **287 passed**, gates **8 failing** (all design), pgTAP **179 passing across 11 files**, advisors 2 justified ERRORs. Flutter from `project/` with `flutter --no-version-check --suppress-analytics ... --no-pub`; gates and Supabase from the repo root. Do not re-run the full suite at entry.
- Exact next step: **P6.4 item 1, the server-backed user directory**, starting with the `device_sessions` admin-read gap above (new migration only — the exception that allowed editing `20260920140000` in P1d is closed and must not be reused). Then items 2-6 in the order in `03_WORK_PLAN.md`. After P6: P5, P7, P8B.
- Read first next session: this block, the P6a section above, the P1d section, and the **P1d + P6a entries in `brief/OWNER_ACTIONS.md`** — the GPS decision and the production-schema comparison still block any `db push`.
- Design stays reserved for Astra (05 D-27): P4, P8A and P9 are not to be started by a Claude Code session, and all 8 failing gates are design gates. Do not chase them.

## Full design and release pass, 2026-09-21, Codex Astra
- Owner authorizes SINGLE window 1, cap 90, continuing past soft 84. Entry used_5h=0, weekly=37, resets_in_min=300, cache_ttl=30m assumed. No subagents, plugins, pushes or production SQL. Roadmap and skill observations remain owner-owned. Both historical stashes preserved.
- P4 starts with scheme A, selected explicitly by owner. Supplied colored.svg replaces the earlier concept; black.svg is monochrome. All nine source assets visually inspected, including rendered SVGs. Inkscape source sheet is not a runtime asset. Upstream IBM Plex fonts and OFL files downloaded for offline bundling.

## RESUME block (2026-09-21, Codex Astra, partial P4)
- Scheme A implemented in part; read brief/archive/reports/2026-09-22/OVERRUN_REPORT.md for coverage and gaps. AppLogo uses supplied colored.svg and black.svg. Fonts bundled with OFL files.
- Analyzer0, full Flutter305 passed; subsequent real-font layout sweep16 passed across8 screens x7 sizes x3 scales x2 locales. Contrast passed. Gates4 failing: G4a14/G4b5/G6 478/G8 1. SQL unchanged, inherited179 tests/11 files and48 migrations; not rerun.
- Entry usage0, checkpoint85, hard cap90. Higher live usage used when snapshots lagged. No reset wait.
- Exact next phase: finish P4 screen/media/RTL/localization/responsive/Settings extraction/documentation gaps, then P8A. P8A/P6.4/P5/P7/P8B/P9 not started. No release readiness claim.
- Nothing pushed; no SQL or production changes. Owner Roadmap and skill-observations untouched, both historical stashes unchanged. Local phase commit follows.

## RESUME block (2026-09-21, Codex Astra, P4 responsive continuation)
- P4 PARTIAL. Analyzer 0 issues; full Flutter suite 369 passed, including 80 real-font layout tests covering 40 screen/state variants x 7 sizes x 3 scales x 2 locales. Focused playlist/contrast run 6 passed. Gates unchanged in classification: G4a14/G4b5/G6 505/G8 1. G6 includes translated calls and real untranslated literals; not all false positives.
- Fixed populated feed/map, all admin tabs, organization wizard, consent and notification layouts. Extracted privacy/language/about Settings widgets; added content-width helper; moved 97 bilingual literal occurrences into symmetric catalogs, plus five new translation pairs; semantic shades and design docs updated.
- Remaining P4: live room with stubbed player, broader populated dialog/sheet coverage, full Settings extraction and scrolling/consent-withdrawal review, remaining literal and media-contrast audit. Arabic phone preview visibly retains English preset labels and missing live.broadcast_from_phone key. Screenshot-mode tests failed with MissingPluginException for native setOrientation; ordinary layout matrix passes. No emulator/device verification.
- P8A/P6.4/P5/P7/P8B/P9 not started. SQL unchanged, inherited 48 migrations and 179 pgTAP tests across 11 files, not rerun. No push or production operations. Owner Roadmap.md, skill-observations and both stashes untouched.
- Budget entry0, closing89, single window cap90. Stop here. Next session finish P4, then P8A only after acceptance. No release readiness claim.

## P4 completion, 2026-09-22, Claude Code Opus

Owner authorised this session to run without the budget meter and accepted
responsibility for the usage. `budget_check.mjs` returns
`UNKNOWN reason=no_snapshot`: the session was launched from another project's
directory, so the status line that writes `brief/.runtime/usage_snapshot.json`
was never configured. No budget file, snapshot or cap was edited. Recorded
here because every other entry in this ledger carries meter numbers and this
one cannot.

### Verified results
- Analyzer: **0 issues** (`brief/analyzer-p4-final.txt`).
- Full suite: **439 passed, 0 failed** (was 369) — `brief/full-test-p4-close.txt`.
- Layout sweep: **120 passed** (was 80), 60 screen/state variants x 2 locales
  x 7 sizes x 3 scales. Also **green in screenshot mode**, so all 120 preview
  PNGs under `brief/evidence/2026-09-21/screenshots/` come from a passing run.
- Rendered contrast: **30 passed**, 15 screens x 2 locales (new test).
- Theme contrast: **2 passed**. Focused live/settings/broadcast files: 9 files,
  all green (`brief/focused-p4-close.txt`).
- Gates: **4 failing, unchanged in number** (`brief/gates-p4-close.txt`).
  G4a=14, G4b=5, G8=1 are P8A identity and signing. **G6=505 is entirely false
  positives**: the gate regex matches `Text('key'.tr())`. 493 are plain `.tr()`
  and 12 are `.tr(args:)`/`.tr(namedArgs:)`, each of the 12 read by hand. Real
  untranslated `Text('...')` literals: **0** (was 3 at session start).
- SQL untouched: 48 migrations and 179 pgTAP tests across 11 files inherited,
  not re-run. No Supabase command of any kind was issued.

### What the new coverage found
The live room had never been pumped by any test: every player adapter builds a
`WebViewController`, which asserts with no `WebViewPlatform`. A test-only
factory seam on `AbstractVideoPlayer` plus `test/support/stub_video_player.dart`
made it layoutable, and the eight variants immediately found six overflow sites
in the room and the audio stage. Populated dialog and sheet coverage found nine
more. Full list is in the two commit messages.

21 labels were rendering **white on white** — not low contrast, invisible —
left by the scheme A migration in the VOD, playlist and speaker sheets, the
broadcaster profile, two outlined buttons and the permission dialog title.
`theme_contrast_test` could not see them because the tokens themselves are
sound; `rendered_contrast_test` resolves each label against the background
actually painted behind it and does.

Two scrims had been flattened from a transparent-to-dark gradient into an
**opaque** media fill, hiding the feed card banner and every VOD thumbnail
completely. `AppGradients.mediaScrim` replaces them.

Six copies of an unguarded image helper built `NetworkImage('')` for any
streamer without an avatar: HTTP 400 on every rebuild, blank circle. One
guarded resolver and `StreamerAvatar` replace all of them.

Eleven i18n keys were referenced but absent from **both** catalogs, so they
rendered as raw key text to every user in both languages, including the
`live.broadcast_from_phone` the last session flagged. Catalogs are symmetric
at 1056 entries.

`RtmpPublishEngine.setOrientation` caught `PlatformException` but not
`MissingPluginException`, which is not a subclass of it. That is what the last
session recorded as a screenshot-mode limitation; it is a real fault on any
build without the native RTMP side registered, and it is now guarded rather
than worked around.

### Device and native verification limits
Still no emulator or physical device run: all evidence is widget-level. The
120 preview PNGs are renders at 360x640 scale 1.0, not device screenshots. The
native RTMP path is exercised only through its Dart channel wrapper. Nothing
here establishes real-device streaming or release readiness.

### Commits
- `94c6508` live room, dialogs and sheets, rendered contrast, localization,
  image handling.
- `cf0f9e7` settings extraction, consent record, semantic colour, RTL
  direction, screenshot mode, design documentation.

Owner `Roadmap.md`, `brief/evidence/2026-09-22/logs/layout-p4-results.txt`, `skill-observations/` and
both historical stashes untouched. Nothing pushed.

## RESUME block (2026-09-22, Claude Code Opus, P4 complete)
- **P4 is COMPLETE.** HEAD `cf0f9e7` on master, tree clean apart from the three
  owner-owned paths above. Nothing pushed. Both historical stashes untouched.
- Baseline for the next session: analyzer 0, `flutter test` **439 passed**,
  layout sweep 120 (green in screenshot mode too), rendered contrast 30, gates
  **4 failing — G4a 14, G4b 5, G8 1 (all P8A), G6 505 (all false positives,
  0 real)**. pgTAP 179 across 11 files, inherited, not re-run. Do not re-run
  the full suite at entry.
- Exact next step: **P8A**, per `brief/03_WORK_PLAN.md`. In order: launcher and
  adaptive icon from the supplied `square.svg` / `cercal.svg`, splash and web
  favicon, identity rename off `com.example` (G4a/G4b), signing fail-closed
  (G8), Android permission cleanup, target SDK and 16 KB page-size check
  against current Play requirements, then an AAB **only if signing inputs
  exist** followed by `node brief/tools/scan_build_secrets.mjs <aab>`.
- Never create or commit a keystore. Record missing owner inputs in
  `brief/OWNER_ACTIONS.md` rather than inventing them.
- The GPS / VULN-COMP-02 owner decision is still unresolved and was not
  touched. P6.4, P5, P7, P8B and P9 remain not started.

## P8A, 2026-09-22, Claude Code Opus

### Verified results
- Gates: **1 failing**, down from 4. G4a 14 -> **0**, G4b 5 -> **0**, G8 1 ->
  **0**. G6 remains 505 and is entirely false positives (translated `.tr()`
  calls); real untranslated `Text('...')` literals: 0.
- Analyzer: 0 issues. Full suite: **439 passed**.
- Debug APK builds after the Kotlin package move, which is the evidence that
  the native side still compiles under the new namespace.
- Release fail-closed verified by running it: `flutter build appbundle
  --release` stops in 3 s with the keytool instructions, no artifact produced.

### Play requirements, checked not assumed (2026-09-22)
- Target API: `flutter.targetSdkVersion` = 36. Google Play has required API 36
  for new apps and updates since 31 August 2026.
  https://developer.android.com/google/play/requirements/target-sdk
  A Gradle configuration check now fails the build if it ever drops below 36.
- 16 KB page size, required for apps targeting Android 15+ since 1 November
  2025: https://developer.android.com/guide/practices/page-sizes
  All 10 `.so` files in the APK are stored uncompressed at 16384-byte
  boundaries, and every arm64 LOAD segment has `p_align` >= 16384
  (libflutter 65536, libdartjni 16384, libdatastore_shared_counter 16384,
  libVkLayer_khronos_validation 65536 - the last is debug-only). AGP is 8.11.1,
  above the 8.5.1 that makes alignment automatic.

### Permissions
Merged manifest now declares exactly eight, all in use: INTERNET,
ACCESS_NETWORK_STATE, CAMERA, RECORD_AUDIO, FOREGROUND_SERVICE,
FOREGROUND_SERVICE_CAMERA, FOREGROUND_SERVICE_MICROPHONE, POST_NOTIFICATIONS.
READ_EXTERNAL_STORAGE and READ_MEDIA_IMAGES were removed after checking that
`image_picker_android` declares no storage permission of its own and uses the
photo picker, which grants per-item URIs. Verified by reading the merged
manifest of a built APK, not by assumption.

### Icons and splash
Layers derived by `brief/tools/make_launcher_assets.py` from the supplied logo;
`project/assets/logo/` is read-only and unchanged. A first pass inset the mark
in the source as well as letting `flutter_launcher_icons` apply its 16% inset,
which put the mark at ~39% of the icon; caught by rendering the masked result
and looking at it, then corrected to 92% in the source. Evidence:
`brief/assets/launcher_icon_check.png`, 192/96/48 px under circular and
squircle masks plus the themed silhouette.

The launch window was black on a dark-mode device and flashed to the white UI,
because `values-night/` used `Theme.Black` and `drawable-v21` used
`?android:colorBackground` while the app ships one light theme. Both now render
white with the mark.

### Not done, and why
- **No AAB.** `key.properties` does not exist and a keystore must never be
  created by the agent, so no release artifact, no size figure, no release
  smoke test.
- **No release secret scan.** A debug APK was scanned as the nearest available
  evidence: `brief/evidence/2026-09-22/logs/scan-p8a-debug-apk.txt`. It reports LEAK; all 7 hits were
  traced to PEM header constants in a crypto dependency's key parser and to the
  literal prefix `sb_secret_` declared in `supabase-2.16.1/lib/src/api_key.dart`
  matched across a kernel constant-pool boundary. No secret is in the build. The
  scanner was not modified.
- **No device verification of anything in P4 or P8A.**
- PRIVACY_POLICY_URL still blank; GPS decision still unresolved.

### Commit
`7bcec29`.

## RESUME block (2026-09-22, Claude Code Opus, P4 complete and P8A complete)
- **P4 and P8A are both COMPLETE.** HEAD `7bcec29` on master. Tree clean apart
  from the owner-owned `Roadmap.md`, `brief/evidence/2026-09-22/logs/layout-p4-results.txt` and
  `skill-observations/`, all untouched. Both historical stashes untouched.
  **Nothing pushed.** No Supabase command was run in this session.
- Baseline for the next session: analyzer 0, `flutter test` **439 passed**,
  layout sweep 120 (green in screenshot mode too), rendered contrast 30, gates
  **1 failing — G6 505, all false positives**. pgTAP 179 across 11 files,
  inherited, not re-run. Do not re-run the full suite at entry.
- Exact next step: **P6.4 item 1, the server-backed user directory**, starting
  from the `device_sessions` admin-read gap recorded in the P6a section and in
  OWNER_ACTIONS item 4 (new migration only). Then P6.4 items 2-6, then P5, P7,
  P8B, P9.
- Before any release work resumes, the owner must supply the keystore and the
  privacy URL: `brief/OWNER_ACTIONS.md`, P8A section. Until then the release
  build is expected to fail, by design.
- The GPS / VULN-COMP-02 decision remains unresolved and untouched.

## RESUME block (2026-09-22, Codex, device preflight blocked)
- Owner scope: verify Chrome and Pixel_9_Pro core flow before P6.4 item 1. No production operations, Supabase push, Git push, stash changes or keystores.
- Entry HEAD 3939de4. Preserved existing changes: Roadmap.md, brief/05_DECISIONS.md, brief/OWNER_ACTIONS.md, project/lib/core/config/app_identity.dart; untracked health audit, layout results, skill-observations and 20260922100000_document_public_venue_coordinates.sql.
- `flutter devices` succeeded with SDK access outside the workspace: Chrome 153.0.8010.53 and emulator-5554, Android 17/API 37. `adb -s emulator-5554 emu avd name` returned Pixel_9_Pro. Initial sandboxed Flutter device query did not return.
- `flutter run -d chrome --web-port=7357 --no-pub` successfully compiled and connected to the debug service. Chrome window title was Hadayah Live. Run intentionally omitted backend credentials to avoid production access. Logs confirmed Supabase was unconfigured; realtime/auth setup printed caught initialization assertions.
- BLOCKER: first Chrome UI inspection via Computer Use was rejected by the tool: "Computer Use has been stopped for this turn because it could not determine the current browser URL on Windows with enough confidence to enforce policy. Stop your work and send a final message noting why Computer Use ended." No UI automation workaround attempted.
- Launch was verified at the process/debug-service level only. Welcome, guest entry, feed, map, venue marker, Google Maps action, settings and login were NOT interactively verified. Android detection succeeded, but no Android app run occurred. No physical-device verification.
- No application code, migrations or signing configuration changed in this session. No targeted tests, analyzer or full test suite rerun because the required device-flow check was blocked before code work. Prior 439 tests/analyzer baseline is inherited, not new evidence.
- P6.4 item 1 NOT STARTED. Next: restore a browser-control connection that can verify the current Chrome URL, finish Chrome flow, then Pixel_9_Pro debug flow. Use local fixtures/backend for populated venue/account checks; do not connect to production. Then implement server-backed directory and device_sessions admin read with server authorization/auditing and bilingual tests.
- Current owner decisions supersede older notes: public self-disclosed venue coordinates remain exact; venue availability is intended open by default but is not claimed implemented; privacy URL https://ameeralhatemi67-debug.github.io/privacy/; Arabic name منصة هدايه; retain only the three specified bootstrap emails.
- Budget: live entry usage 8% five-hour / 69% weekly; latest live reading before the blocker 17% / 70%. Stopped for the tool's browser policy enforcement blocker, not remaining budget. No release-readiness claim.

## RESUME block (2026-09-22, Codex, P6.4 directory implemented; DB verification blocked)
- Owner explicitly authorized proceeding to P6.4 if browser testing remained blocked. Changes are local and uncommitted because item 1 is not fully verified. No push, production connection, supabase db push, stash operation, release signing change or keystore creation.
- Implemented admin directory tab with server-side literal name/email/YouTube-handle search and 25-row pagination; detail sheet shows roles, personal streamer/verification status, organizations, broadcaster device records, report count and ban record. English/Arabic keys and narrow-screen RTL tests included. Screens call AppProvider, which delegates to AdminDatabaseService. Reads/writes fail explicitly without a backend; no fake success.
- New migration 20260922110000_admin_user_directory.sql adds device_sessions SELECT for non-banned platform admins, directory/detail RPCs and atomic account actions plus audit writes. Authenticated non-admin/banned callers are rejected, self/master-admin targets protected, plain admins cannot mutate admin targets. Supported actions: permanent ban, unban, revoke personal streamer access, revoke personal verification. Revocation clears current live state and primary device status. It deliberately preserves org roles/permissions and does not delete organizations. Account deletion and Auth-session revocation are not implemented or implied. Existing legacy moderation paths were not refactored.
- New supabase/tests/admin_user_directory.test.sql has 23 pgTAP assertions. UNVERIFIED-STATIC: no new migration or probe was executed against any database. Existing migrations were not edited. The pending public venue coordinate comment migration remains owner-owned.
- Reproduced an Arabic navigation defect in the in-app browser: bottom tabs stayed English and search placeholder stayed English after changing language. Replaced hardcoded bottom labels with nav catalog keys and changed search hint to context.tr to subscribe to locale changes. Rebuilt Chrome successfully. Post-fix in-app browser showed the new English Discovery Feed label; final Arabic recheck was inconclusive because browser state/screenshot capture stopped responding. Do not claim final Arabic browser verification.
- Browser evidence: native Chrome 153 launch/debug-service connection succeeded at ports 7357 and 7358 without Supabase credentials. UI interaction used the URL-aware Codex in-app browser, not native Chrome automation. Verified welcome, local guest consent/setup, name validation, guest feed with 0 broadcasters, guest Settings redirect to welcome, map render, initial language switch/RTL and exact Arabic product title منصة هدايه. Login entry was visible; OAuth was not attempted. No populated venue marker or Google Maps action could be verified with the unconfigured catalog. No production credentials used.
- Android evidence: flutter devices detected emulator-5554 Android 17/API 37, adb confirmed Pixel_9_Pro. Debug APK built and installed, native Flutter loaded, then Flutter lost its debug connection. App process remained present; crash-buffer query empty. Android screencap confirmed the rendered welcome screen (brief/evidence/2026-09-22/screenshots/android-launch.png). A guest-entry tap did not yield a verified transition. Native Windows capture failed because the emulator crop was outside its monitor; ADB screenshot was used. Remaining emulator flow is unverified. No physical device run, no RTMP or release verification.
- Verification: 7/7 new targeted tests passed (brief/evidence/2026-09-22/logs/test-p64-directory.txt); full Flutter suite 446/446 passed in 6m47s (brief/evidence/2026-09-22/logs/full-test-p64.txt); flutter analyze 0 issues (brief/evidence/2026-09-22/logs/analyzer-p64.txt); git diff --check clean for changed app/catalog files. Gates retain one failure, G6=523; the new directory Text calls are translated or server-provided data, and the regex still flags translated expressions. Other gates unchanged in classification (brief/evidence/2026-09-22/logs/gates-p64.txt). No new release-readiness claim.
- Docker blocker and recovery: installed CLI was only available outside sandbox at AppData/Local/Programs/DockerDesktop/resources/bin. Started installed Docker Desktop hidden for local SQL tests; backend failed on dockerInference Unix socket binding. Normal restart stalled; supported force-stop succeeded; clean start reproduced the same error in host logs at 07:14:40 UTC. Attempted supported `docker desktop disable model-runner`, but it did not confirm success. Final `docker desktop stop --force --timeout 30` succeeded. No factory reset, pruning, volume/container deletion, socket deletion, WSL shutdown, config rewrite, diagnostic upload or credential changes. Docker remains STOPPED and unresolved; verify its inference setting on recovery rather than assuming the disable command succeeded.
- Budget: resumed at live 26% five-hour / 72% weekly. Five-hour window rolled over during implementation; final live reading 67% in the new window / 89% weekly. Closing near the brief's weekly guard, with DB runtime blocker. No meter/cap files edited.
- Next steps: recover Docker non-destructively; review/apply pending migrations only to local Supabase and run all SQL probes, extending protection/audit-rollback cases as needed. Finish directory actions against the local backend, populated venue/Google Maps checks, and emulator navigation. Do not start P5/P7/P8B/P9 while item 1 remains unverified. Account deletion requires a separately designed admin-authorized backend path. Keep existing owner changes, stashes and three bootstrap emails intact.

## Documentation checkpoint (2026-09-23)
- Consolidated the release sequence and P6S broadcast/access/playback/lifecycle acceptance into `brief/03_WORK_PLAN.md`, now the sole canonical release plan. The four-day schedule is conditional; it does not promise publication.
- Added `brief/README.md` as the entry point; aligned verification and owner actions with the later supplied privacy URL and D-33 exact public-venue-coordinate decision. Neither privacy-page availability nor account-deletion URL was checked here.
- Archived the superseded release addendum, model prompts, dated reports/checkpoint, raw logs and screenshots under `brief/archive/` and `brief/evidence/`; contents were preserved and links repaired. `brief/tools/` remains in place. No application code, migrations, external services, remotes, push or commit changed.
- Current blockers remain P6.4 item 1's recorded local SQL/test defects; incomplete P6/P6S/P5/P7/P8B/P9 work; no physical-device streaming evidence; disabled private mode with no enforceable invite/access path; URL-only Local mode; no real-media mini-player; web Phone platform error; and no signed AAB. Latest broad UI evidence is 463 tests / analyzer 0 / web build, dated 2026-09-22, not rerun for this docs-only checkpoint.
- Exact next engineering task: recover local Supabase/Docker without destructive cleanup, repair the `20260922110000_admin_user_directory.sql` access-policy regression and malformed `admin_user_directory.test.sql` quoting, then rerun the local DB tests and directory authorization/audit cases. Do not begin dependent release phases until this passes.
- Follow-up documentation only: reconcile `Roadmap.md`, `AGENTS.md`, `Core_files/STATUS.md`, `Core_files/progres.md` and relevant `Core_files/` records against this plan; they were not edited in this pass.

## RESUME block (2026-09-23, Codex, P6.4 item 1 SQL repair blocked on local DB)

- Scope: P6.4 item 1 only. No P6S or later work, production Supabase access, push, deploy, stash operation, or Flutter client edit.
- Before editing, `git status --short --branch` showed `master` ahead of `origin/master` by 20 commits and Luna's uncommitted `brief/` reorganization. A file-by-file `git ls-tree`/`git show` comparison found all 191 displaced files at new paths: 163 byte-identical, 28 text files changed during reorganization, none missing. A relative Markdown-link scan checked 43 links and found 0 broken. `git diff --cached --check -- brief` passed. Staged only explicit changed `brief/` paths and committed the separate documentation checkpoint as `d659b95 docs(brief): preserve release evidence in archive`; SQL was not part of that commit.
- Read the original `device_sessions` policies and their later removal of `device_sessions_write_own`, `is_admin_tier()`, `is_current_user_banned()`, and the revoked `is_banned(uuid)` helper. New migration `supabase/migrations/20260923100000_admin_device_sessions_read_guard.sql` drops/recreates the own and admin SELECT policies. Ordinary authenticated, unbanned users retain own-row reads; active admin-tier users can read other rows; a banned caller gets no device-session rows. The migration does not change the committed `20260922110000_admin_user_directory.sql`.
- Fixed all five malformed dollar-quoted statements in `supabase/tests/admin_user_directory.test.sql`. Expanded from 23 to 33 planned pgTAP assertions, adding ordinary-user denial, master-admin protection and access, banned-admin detail/mutation and own-device denial, and audit coverage for unban and both revocations. Removed test-side direct calls to the revoked `is_banned(uuid)` helper. A Python static check counted 33 pgTAP calls, confirmed `plan(33)`, balanced `$$` pairs, no single-dollar `$select`, two replacement SELECT policies, and no `is_banned(uuid)` call in the new migration. `git diff --check` passed. These are source checks, not database evidence.
- Tooling commands/results: `npx --no-install supabase --version` with `DO_NOT_TRACK=1` returned `2.115.0`; the installed Docker CLI at `C:\Users\User\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe` reported client `29.6.2` but no server. `docker desktop start` and a later `docker desktop start --timeout 60` failed. `%LOCALAPPDATA%\Docker\backend.error.json` recorded `starting services: initializing Inference manager` and the `dockerInference` Unix socket bind collision on both starts. `docker desktop stop --force --timeout 30` succeeded. `docker desktop disable model-runner` could not reach `dockerBackendApiServer`. A backed-up, one-flag `EnableDockerAI=false` trial did not change the error; the exact original settings file was restored and Desktop stopped. No socket file, container, volume, WSL distribution or Docker data was removed. `issue_encountered.md` records details and the user-supplied error text.
- Exact attempted local pgTAP command: `npx --no-install supabase test db --local supabase/tests/admin_user_directory.test.sql supabase/tests/broadcast_sessions.test.sql supabase/tests/application_and_ban_guards.test.sql supabase/tests/rls_catalog.test.sql` (with `DO_NOT_TRACK=1`). Exit 1 before any assertion: `LegacyDbConnectError`, `ECONNREFUSED 127.0.0.1:54322`. `npx --no-install supabase status` likewise failed its local Docker health check because `dockerDesktopLinuxEngine` was absent. No disposable local database was available, so no migration reset/apply or pgTAP suite completed. The 33 directory assertions and related RLS assertions remain unverified.
- The SQL repair is deliberately **uncommitted** because the required local database checks did not pass. Do not mark P6.4 item 1 complete. On recovery, start a disposable local Supabase stack, apply the new migration locally, run the full directory file through `finish()` plus the relevant RLS files, inspect every assertion, and record actual authorization, self/master protection, ban, revocation and audit results before a separate P6.4 repair commit. Flutter checks were not rerun because no client code changed; the older UI evidence remains dated 2026-09-22.

## RESUME block (2026-09-23, Codex, P6.4 item 1 verified locally)

- Scope stayed at P6.4 item 1's server-backed directory and device-session policy repair. No linked/production database command, push, deploy, P6.4 item 2, P6S, account deletion, or Auth-session revocation. The existing `AGENTS.md`, `Core_files/README.md`, and both stashes were preserved and excluded from the repair commit. Luna's reorganization remains in its separate `d659b95` documentation commit.
- Budget checkpoint: `node brief/tools/budget_check.mjs --source codex --plan split` reported `status=OK`, `window=2`, `used_5h=1.0`, `cap=60`, `weekly=1.0` before SQL tests and after the >2-minute Flutter run. These were tool readings, not a manual estimate; observed phase burn rounded to 0.0 points at this precision. No meter/cap/runtime files were edited.
- Docker recovery was external to this session. Read-only `docker version --format '{{.Client.Version}} | {{.Server.Version}}'` returned `29.6.2 | 29.6.2`. `npx --no-install supabase status` for the repository root found no `supabase_db_Streamer_app` container. `npx --no-install supabase start` restored the existing local project from backup; `npx --no-install supabase stop` immediately preserved that backup (`backup=true`). No reset was run against it.
- Disposable test environment: copied repository `supabase/config.toml`, `migrations/`, and `tests/` into ignored `brief/.runtime/p64-item1-disposable-20260923/supabase/`, changed only its `project_id` to `P64_item1_disposable` and disabled its missing `seed.sql` in the copy. Ran `npx --no-install supabase start --workdir brief/.runtime/p64-item1-disposable-20260923` with `DO_NOT_TRACK=1`; exit 0. Fresh initialization applied every migration, including `20260922110000_admin_user_directory.sql` followed by `20260923100000_admin_device_sessions_read_guard.sql`. `npx --no-install supabase migration list --local --workdir brief/.runtime/p64-item1-disposable-20260923` listed `20260923100000` in the local database; `docker ps` showed `supabase_db_P64_item1_disposable` and only that project's Supabase containers. After tests, `npx --no-install supabase stop --workdir brief/.runtime/p64-item1-disposable-20260923` exited 0 with `project_id_filter=P64_item1_disposable, backup=true`. No `db push`, `--linked`, or remote project access.
- From the disposable project root, `npx --no-install supabase test db --local supabase/tests/admin_user_directory.test.sql supabase/tests/broadcast_sessions.test.sql supabase/tests/application_and_ban_guards.test.sql supabase/tests/rls_catalog.test.sql` returned `All tests successful. Files=4, Tests=86, Result: PASS`. `npx --no-install supabase test db --local supabase/tests/admin_user_directory.test.sql` separately returned `Files=1, Tests=33, Result: PASS`; the file reached `finish()` rather than stopping after the first assertions. Its checks cover ordinary-user own access and cross-account denial, admin and master-admin reads, banned-admin directory/detail/mutation and device denial, self/master protection, ban/unban, streamer and verification revocation, and all four action audit records. `npx --no-install supabase test db --local` passed all 12 files and 212 assertions. No assertion failed, so no further SQL changes or retries were needed.
- Phase checkpoint from `project/`: `flutter analyze` returned `No issues found! (ran in 13.9s)`; `flutter test --reporter compact` returned `+463: All tests passed!` (02:20 elapsed, log in ignored disposable runtime folder). Root `node brief/tools/gates.mjs` exited 0 and reported one gate failure, G6=528 translated-expression/English Text literal scan, outside this SQL repair; G10a/c/d and G11a/b/d/e/f were 0/PASS. `git diff --check` passed. No Flutter client code changed in this repair.
- Status: the P6.4 item 1 server-backed directory repair is locally verified for its implemented actions and ready for a separate explicit-path repair commit. Account deletion/Auth-session revocation remain unimplemented and outside this repair. Later P6 and release gates remain open; local SQL evidence is not production or physical-device release evidence.

## 2026-09-23 checkpoint: weekly budget preflight repaired

The owner authorized weekly-only budgeting with a 5% absolute ceiling, aiming lower. Codex exposes a 10,080-minute weekly window and no five-hour window. The meter now classifies by duration, preserves 1% as 1%, rejects stale/missing weekly readings, and supports `--plan weekly --cap 5` with a 4% soft stop. Focused Node tests passed. Entry usage 1%, implementation entry 2%; no app/SQL/Flutter evidence added yet. P6.4 item 1 remains verified in `1832b3e`; P6 safety implementation is next and P6S remains blocked. Owner edits and both stashes are preserved. See brief/04_BUDGET_PROTOCOL.md section J. No push/deploy/production operations.

## 2026-09-23 checkpoint: P6 account/live controls and safety backend

Implemented authorized, audited directory account deletion/Auth-session revocation and app live end/feed removal. The server requires active admin sessions, protects self/master/admin targets, rejects deletion of organization/storage owners, and prevents forged success audits. Feed removal blocks the video ID from going live again in the app. Issued JWT expiry and external YouTube media remain explicit limits.

Also implemented backend own-row chat blocks, server report-reason/message validation and master-admin app flags enforced at chat/Auth INSERT. Client block persistence/cache sync and app-flag management/availability UI remain NOT DONE. Dedicated live list, audit viewer, keyword manager and global deleted-account cache acceptance remain open. P6S is not started.

Verification: 8 focused Flutter tests; 25 admin safety + 26 block/flag SQL assertions; GPT-6 Luna Medium analyzer 0 and full Flutter 464 passed. Parent fixed the intentional deny-all catalog allowlist and block-policy helper, then final SQL passed all 263 assertions across 14 files. Final gates retain known G6=528; security/secret gates passed. Only the named disposable local database was used. Existing owner edits and both stashes remain preserved. Evidence and next dependencies: `brief/evidence/2026-09-23/p6-safety.md`. Weekly usage measured 3% against the owner's 5% absolute ceiling; not all P6 work is complete.

## RESUME block (2026-09-23, Codex, P6 safety slices locally verified)

- Budget checkpoint committed as `034aaf9`; owner superseded old caps with absolute weekly 5%, aim lower. Use `node brief/tools/budget_check.mjs --source codex --plan weekly --cap 5`. Known duration 10,080 minutes, no five-hour window. Final observed weekly 3%; implementation delta from 2% to 3%, rounded account-wide. Do not reset runtime state or invent five-hour numbers.
- Implemented and verified scope/evidence: `brief/evidence/2026-09-23/p6-safety.md`. New directory deletion/session/live moderation UI plus authorized atomic RPC/audits; server block/report/flag foundations. Final analyzer 0, Flutter 464, SQL 263/14 files. Known gate failure G6=528 remains. No new Dart edits after Luna's consolidated run began. Later backend changes received focused and final full SQL checks; no repeated broad Flutter suite.
- Next local slice: connect existing LiveChatController blockUser/_loadBlockedUsers to chat_user_blocks with authoritative server success/cache synchronization; expose master-admin app flags and client availability states; verify failure and stale-token handling. Then dedicated live-stream list/counts, audit viewer, keyword manager and deleted-account cache invalidation. P6 safety remains incomplete; DO NOT begin P6S.
- Disposable DB used only: P64_item1_disposable. New SQL applied directly with psql, not CLI migration history. Use a new disposable bootstrap or account for already-applied SQL when resuming; do not replay CREATE statements blindly. No linked/production operations, push/deploy, default-project reset, secret or stash operations.
- Owner edits AGENTS.md and Core_files/README.md and the two named pre-existing stashes remain untouched. Owner action for eventual release remains migration review, signing/legal/store/device/test-channel tasks; no owner decision blocks the next local P6 implementation.

## 2026-09-23 workflow checkpoint: Claude Opus meter waived by owner

Two Opus sessions stopped before P6 edits with `BUDGET status=UNKNOWN reason=no_snapshot`; no Claude usage snapshot was available. The owner explicitly removed meter and percentage-cap requirements for Claude Opus 5.5 and requested efficient continuation. `brief/04_BUDGET_PROTOCOL.md` §K now governs Opus; §J's 5% weekly ceiling remains Codex-only. The meter tools and runtime state were not changed. No P6 implementation or verification evidence was added by the blocked sessions. Next task remains client chat-block synchronization and master-admin flag UI, followed by the remaining P6 admin views. The existing owner edits and stashes remain protected; P6S is still blocked.

## 2026-09-23 checkpoint: P6 client blocks, app flags and admin safety console

Claude Opus 5.5 under the §K owner override; no meter was run. Work is on branch `p6-client-safety` (worktree `.claude/worktrees/p6-client`, based on `0aa6b06`) in commits `bb285c8` (server-owned chat blocks, report-reason alignment) and `1eb5d71` (app flags, availability states, admin Safety tab, keyword audit migration `20260923130000`, deleted-account cache cleanup). Chat block and unblock now wait for server confirmation and have failure states, a stale cache, a one-time upload of old device-only blocks, refresh on room entry, Settings and resume, and a Settings unblock list. The Safety tab covers live now, the audit log, keyword management, and Master-Admin-only platform switches.

Verification: focused 19 + 21 new Flutter tests; `flutter analyze` 0 issues; full Flutter `+504: All tests passed!`; SQL on a fresh `P6_client_disposable` bootstrap `Files=15, Tests=278, Result: PASS`; gates exit 0 with G6 FAIL 552 (was 528, +24 all localized `Text('key'.tr())` calls counted by the regex; zero new untranslated literals). All other gates PASS or INFO. Evidence and limits: `brief/evidence/2026-09-23/p6-client-admin.md`. Cross-device block sync works by refresh, not push. There is no physical-device or two-session evidence. The new migration needs owner review before any production use. P6 acceptance is still open; P6S remains blocked. Owner edits and both stashes were preserved; no push, deploy, or linked/production operation.

## RESUME block (2026-09-23, Claude Opus 5.5, P6 client and admin slices locally verified)

- Code is on branch `p6-client-safety` (worktree `.claude/worktrees/p6-client`), commits `bb285c8` and `1eb5d71` plus this docs commit, all based on `0aa6b06`. It is not merged to `master`: the background session had to work isolated. The owner can fast-forward `master` with `git merge --ff-only p6-client-safety` from the main checkout. Owner edits to `AGENTS.md` and `Core_files/README.md` and both named stashes were not touched.
- Implemented all the requested P6 client and admin scope: server-owned chat blocks with failure handling and cache and cross-device sync by refresh; report reasons aligned with server validation; `AppFlags` availability (platform chat pause, sign-ups paused); Master Admin switch controls; the Safety tab (live list with presence counts, audit viewer, keyword manager); a keyword-change audit trigger; deleted-account cache cleanup. Details: `brief/evidence/2026-09-23/p6-client-admin.md`.
- Evidence: full Flutter 504 passed; analyzer 0; SQL 15 files and 278 assertions on the fresh disposable project `P6_client_disposable` (stopped with backup=false afterwards); gates exit 0 with G6=552 (explained +24 localized calls), everything else PASS or INFO.
- Next: owner review of migration `20260923130000_audit_chat_keyword_changes.sql` and of the Safety tab UX. P6 safety acceptance means a two-device or real-session check of block sync, flag pauses and admin live actions. Only then does P6S start. Remaining limits: no server push for blocks; other clients drop deleted accounts on their next reload; issued JWT expiry; YouTube media is not stopped by app-side end or remove.
- DO NOT start P6S until P6 safety acceptance passes. No linked/production Supabase, push or deploy.

## RESUME block (2026-09-23, P6 client/admin branch integrated)

- Fast-forwarded `p6-client-safety` into `master` at `0d6b7a1` with `git merge --ff-only p6-client-safety`. `AGENTS.md`, `Core_files/README.md`, and both stashes were untouched. No push, production database access, or deploy.
- The branch's local evidence remains 504 passing Flutter tests, analyzer 0 issues, 278 SQL assertions across 15 files, and G6=552 (24 additional translated calls). The merge added no code changes beyond the already verified branch; tests were not rerun for this documentation checkpoint.
- Next: independent review of `supabase/migrations/20260923130000_audit_chat_keyword_changes.sql` and focused P6 safety acceptance with two real signed-in sessions/devices. Record exact pass/fail evidence and any remaining owner action. Do not mark P6 accepted or start P6S until those checks pass.

## 2026-09-23 checkpoint: P6 migration review and real-session acceptance attempt

Branch `p6-acceptance` (from `f581329`): reviewed migration `20260923130000` (packet: `brief/evidence/2026-09-23/p6-keyword-audit-migration-review.md`; recommendation: apply together with the new `20260923140000`, which revokes TRUNCATE/TRIGGER/REFERENCES that anon/authenticated held on 27 of 29 public tables and audits privileged keyword truncates). A local real-session run (four GoTrue users with password-grant sessions, separate browser origins, disposable `P6_accept_disposable`) passed in the UI: blocking, blocked-sender filtering, a second device honouring the block, unblocking from Settings on the second device, and the first device resyncing on re-entry; the Master Admin chat pause and resume with audit rows; the paused composer. It passed through the API with real sessions: server refusal of paused chat including for the stream owner, sign-ups pause and reopen, force end, remove from feed with the video barred and a new video allowed, and permission denials, all audited to the actor. Fixed two defects found in the run: room history displayed newest-first (postgrest `order` defaults to descending), and an open room stayed paused after chat resumed (now re-reads `app_flags` every 30 s while paused). Verification: full Flutter `+506: All tests passed!`, analyzer 0, SQL on a fresh bootstrap `Files=15, Tests=283, Result: PASS`, gates exit 0 with G6=552 unchanged. **P6 is NOT accepted**: Chrome became hidden, so the Welcome sign-ups notice, the Safety end/remove buttons, the audit and keyword views and both fixes were not seen on screen, and no physical devices were used; owner steps are in `brief/evidence/2026-09-23/p6-acceptance-sessions.md`. Also found, not fixed: the admin Overview KPIs are hard-coded samples (`ViewerAnalyticsModel.createDefault`), and a `/admin` deep link redirects before the role loads.

## RESUME block (2026-09-23, Claude Opus 5.5, P6 acceptance prepared, not accepted)

- Branch `p6-acceptance` (worktree `.claude/worktrees/p6-client/.claude/worktrees/p6-accept`), based on `f581329`. Integrate from the main checkout with `git merge --ff-only p6-acceptance`. `AGENTS.md`, `Core_files/README.md` and both stashes are untouched. No push, deploy or linked/production access.
- New migration `20260923140000_revoke_api_truncate_trigger_references.sql` must ship with `20260923130000`. The owner decides on production after the pre-push checks in the review packet.
- Evidence and owner steps: `brief/evidence/2026-09-23/p6-acceptance-sessions.md`. Each result is labelled UI, API, SQL or widget.
- Next: the owner runs acceptance steps 1–5 on real devices or accounts (local or staging with both migrations) and records pass/fail here. Only then mark P6 accepted and start P6S. Separate follow-ups: real admin KPI sources (sample numbers in `ViewerAnalyticsModel.createDefault`), `/admin` deep-link timing, and whether `is_admin_tier()` should exclude banned admins.

## 2026-09-23 checkpoint: P6 branch integrated, pause instruction corrected, guided acceptance prepared

`p6-acceptance` was reviewed and fast-forwarded into `master` at `6e63f5d` (`git merge --ff-only`; owner edits to `AGENTS.md` and `Core_files/README.md` and both stashes preserved). Follow-up `1ed891c`: refused chat sends no longer toast an "Exception:" prefix; a misplaced doc comment was fixed; and a test pins that pause polling runs only while a room is paused. The earlier owner step promising that an open, enabled room notices a pause within 30 s was wrong and has been corrected: such a room learns of it from its next refused send (verified on screen: failed message with Discard only, then the paused notice), from re-entry, or from app resume. Browser-session evidence (separate origins in one desktop Chrome, real local GoTrue sessions) confirmed history oldest-first and a paused room recovering without reload. Focused tests `+60` across the three affected files and analyzer 0; the full suite (506) was not repeated because only those files exercise the changed send path. A disposable acceptance environment (`P6_accept_disposable`, both migrations, four test users, caster live) and a guided checklist G1–G6 are in `brief/evidence/2026-09-23/p6-acceptance-sessions.md`. **P6 remains NOT accepted and P6S remains blocked** until the owner completes the on-screen checklist and the physical-device steps (a phone broadcaster reacting to force end, two phones with real Google accounts). **P2 truthful data is reopened:** the admin Overview KPIs come from hard-coded samples in `ViewerAnalyticsModel.createDefault()` (1420 guests, 185 users, 365 RSVPs, 342 live viewers) and were found seeded in a fresh `platform_analytics` row. No launch date is committed.

## RESUME block (2026-09-23, Claude Opus 5.5, guided P6 acceptance in progress)

- `master` = `6e63f5d` (p6-acceptance fast-forwarded). Branch `p6-acceptance` is ahead with `1ed891c` (toast prefix fix) plus this docs commit; integrate with `git merge --ff-only p6-acceptance` from the main checkout.
- The local environment runs from this session: the stack `P6_accept_disposable`, static servers on 127.0.0.1:8081–8085 and a caster heartbeat. Session files and the login helper sit in the ignored `project/build/web`. Stop with `npx supabase stop --no-backup --workdir brief/.runtime/p6-accept-disposable-20260923` and delete `project/build/web/p6s_*.json` and `p6-login.html` when finished.
- Evidence labels: UI (browser sessions in desktop Chrome, not devices), API (real sessions), tests. No physical-device evidence exists for P6.
- Next: the owner runs G1–G5 (G6 optional) and the physical-device steps, and records pass/fail here. Only then mark P6 accepted and unblock P6S. Reopened P2: admin KPI samples. Separate follow-ups: `/admin` deep-link timing, `is_admin_tier()` and bans, desktop discoverability of the message action sheet.
- No launch date is committed.

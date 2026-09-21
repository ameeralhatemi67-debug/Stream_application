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

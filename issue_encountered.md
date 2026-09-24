# Issues encountered during release hardening

Updated: 2026-09-24. This is a local troubleshooting record, not proof that the database tests passed.

## Issue-name index — scan this list first

Agents: when investigating an error, scan only these short names for a match. If one matches, read that entry's section; do not reread the whole file by default. When you fix a new issue, append a concise entry under a clear heading and add its short, searchable error name here. Record the fix and how it was verified; label it `UNVERIFIED` if runtime confirmation is pending. Do not mark an unresolved issue fixed, and update an existing entry instead of creating a duplicate.

- **Docker Inference manager `dockerInference` socket bind collision** — currently operational; earlier root cause unresolved.
- **Supabase CLI telemetry temp-file `EPERM`** — workaround: `DO_NOT_TRACK=1`.
- **Weekly-only budget window mislabeled five-hour** — FIXED with owner-authorized weekly mode and focused tests.
- **Claude Opus budget `no_snapshot` stopped P6** — workflow override recorded; Opus continuation not yet verified.
- **Git `.git/index.lock` access denied** — resolved by approved staging outside the sandbox.
- **`device_sessions` SELECT permission denied for `is_banned(uuid)`** — FIXED; disposable local SQL suite passed.
- **Malformed single-dollar pgTAP quoting in `admin_user_directory.test.sql`** — FIXED; all 33 assertions passed locally.

- **Admin direct link redirects before backend role loading** — FIXED locally; router regression and browser session passed.
- **Role choice repeats or leaks across accounts** — FIXED locally; account-scoped hydration and generation tests pass.
- **Phone landscape ParentData crash and preview disposal** — layout crash FIXED locally; native lifecycle compiled, physical camera retest open.
- **Phone LIVE before encoder/server confirmation** — FIXED locally; native-event and RPC denial tests pass, real ingest unverified.
- **Windows STL1011 in permission_handler_windows** — UNRESOLVED compiler/plugin compatibility; reproduced without flag changes.
- **Realtime initial snapshot precedes first channel join** — FIXED locally for device sessions (read after join); physical timing check open.
- **Device conflict dialog removed by splash navigation** — FIXED locally; router-level test and two-client probe pass, two phones open.
- **Studio errors hidden behind the bottom sheet** — FIXED locally; in-sheet errors, studio tests pass, device retest open.
- **Map visibility false success and unaudited revocation** — FIXED locally; audited RPCs, 26 SQL assertions, owner retest open.
- **Filtered Realtime DELETE not delivered (unban)** — WORKAROUND: poll while banned; ban INSERT delivered.
- **Application status screen had no way back** — FIXED locally; router test passes, device retest open.
- **Supabase CLI `start` crashes (Bun) in the sandbox** — workaround: wrapper from the worktree root, unsandboxed, relative `--workdir`.
- **Restarting the local Realtime container breaks joins until Kong restarts** — workaround: restart the local Kong container too.
- **Signed-in long-lived Chrome reload hang** — UNRESOLVED, not reproduced; capture steps in the 2026-09-24 repair note.
- **Live-room connecting subtitle fails contrast** — FIXED locally; initializing overlay uses media text color.
- **Spatial map pairwise marker displacement scales quadratically** — FIXED locally with bounded grid clusters; phone paint timing open.
- **Map search and cached pins outlive catalog refresh** — FIXED locally for current provider snapshots; offline revocation timing open.
- **Offline map pins disappear without a public catalog snapshot** — FIXED locally with vetted marker-only cache fallback; phone cold start open.

## Recording format

Use one entry per distinct root cause. Keep it searchable and actionable:

```text
## <Simple error name>
Status: FIXED | UNRESOLVED | UNVERIFIED
Observed: exact error or symptom, plus platform/tool/version when relevant.
Cause: confirmed root cause; say “suspected” if not confirmed.
Fix/workaround: concrete change or safe recovery steps.
Verification: command/scenario and result; state what was not verified.
Evidence: relevant local path or link, if available.
```

Add resolved issues to the index using the same simple error name. Keep the index brief; details belong in the matching section below. Never record secrets, tokens, private keys, or credentials.

## Live-room connecting subtitle fails contrast
Status: FIXED locally.
Observed: The English and Arabic `rendered_contrast_test.dart` live-room cases measured the connecting subtitle at 1.65:1 against the media background after offline recovery exposed the initializing state.
Cause: The placeholder used `AppTheme.textSecondary`, a dark foreground token, over `AppTheme.media`.
Fix/workaround: Use `AppTheme.onMedia` for placeholder subtitle and error detail.
Verification: The focused 38-case rendered contrast suite passed. Physical-device display and real WebView playback remain unverified.
Evidence: `brief/evidence/2026-09-24/p5-hardening-worktree.md`.

## Spatial map pairwise marker displacement scales quadratically
Status: FIXED locally; device timing UNVERIFIED.
Observed: The map ran ten pairwise collision passes on every camera update, so layout comparisons grew quadratically with visible markers.
Cause: Marker positions were displaced against every other marker in `spatial_map_screen.dart`.
Fix/workaround: Group projected markers into 72-pixel grid cells with stable member-based IDs; cluster taps zoom and then offer a member list at maximum zoom.
Verification: The P5.5 focused test projected 1,000 dense points exactly 1,000 times, checked stable identity after reorder, and checked sparse/removed points. Final full Flutter suite passed 557 tests. Physical paint timing remains unmeasured.
Evidence: `brief/evidence/2026-09-24/p5-5-map-presentation.md`.

## Map search and cached pins outlive catalog refresh
Status: FIXED for current provider snapshots; offline revocation timing UNVERIFIED.
Observed: Search results were retained from the last keystroke and cached pins were rendered without matching them to the current public catalog.
Cause: Search stored a result list, while the cached-marker layer trusted its separate persisted list.
Fix/workaround: Derive results on each build from verified, visible provider records and intersect cached pins with current eligible streamer IDs. Clear selection when its record leaves the visible catalog.
Verification: Focused tests cover unverified/hidden removal and refreshed search results; `flutter analyze` reports zero issues and the final 557-test suite passes. A disconnected device cannot know about a revocation made after its last successful sync.
Evidence: `brief/evidence/2026-09-24/p5-5-map-presentation.md`.

## Docker Inference manager `dockerInference` socket bind collision

Status: **UNRESOLVED ROOT CAUSE; CURRENTLY OPERATIONAL**.

Docker is installed at `C:\Users\User\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe`, but that directory is not on the shell PATH. Use the full path to invoke the installed CLI. The first sandboxed invocation failed with `Access is denied`; an approved unsandboxed read was able to run the CLI.

The CLI reported client version 29.6.2, but no server. The local Linux engine pipe `npipe:////./pipe/dockerDesktopLinuxEngine` did not exist. `docker desktop start` launched Docker Desktop processes, but the command did not return promptly and the engine remained unavailable.

Docker Desktop displayed this error:

> Docker Desktop encountered an unexpected error and needs to close.
> Search our [troubleshooting documentation](https://docs.docker.com/desktop/troubleshoot/overview/?utm_source=docker_desktop_error_dialog) to find a solution or workaround. Alternatively, you can gather a diagnostics report and submit a support request or GitHub issue.
> starting services: initializing Inference manager: listening on unix://C:/Users/User/AppData/Local/Docker/run/dockerInference: listen unix C:/Users/User/AppData/Local/Docker/run/dockerInference: bind: Only one usage of each socket address (protocol/network address/port) is normally permitted. (listener: The filename, directory name, or volume label syntax is incorrect.)

`C:\Users\User\AppData\Local\Docker\backend.error.json` recorded the same inference-manager socket bind failure on both start attempts. `wsl --list --verbose` showed `docker-desktop` stopped. The supported `docker desktop stop --force --timeout 30` stopped the failed startup. The supported `docker desktop disable model-runner` failed because `dockerBackendApiServer` was unavailable. I backed up `%APPDATA%\Docker\settings-store.json` to `%APPDATA%\Docker\settings-store.p64-backup.json`, changed only `EnableDockerAI` from `true` to `false`, and retried `docker desktop start --timeout 60`. It still failed with the same inference socket error. I force-stopped Desktop and restored the exact original settings file from the backup; `EnableDockerAI` is again `true`. No Docker volumes, containers, or run-socket files were deleted. The visible `%LOCALAPPDATA%\Docker\run` directory had no `dockerInference` file after stop. **Unresolved as of this entry.**

The earlier local-only command `npx --no-install supabase test db --local supabase/tests/admin_user_directory.test.sql supabase/tests/broadcast_sessions.test.sql supabase/tests/application_and_ban_guards.test.sql supabase/tests/rls_catalog.test.sql` failed before any assertion with `ECONNREFUSED 127.0.0.1:54322`. No migration reset or local test run occurred in that session. The required database run succeeded in the follow-up below. Do not use `--linked` or production credentials to work around a local failure.

2026-09-23 follow-up: the user reported Docker Desktop running. The installed CLI returned both client and server version `29.6.2`. A fresh disposable Supabase project (`P64_item1_disposable`) started and completed its migration chain, and the local SQL suite passed. The earlier socket collision did not recur. This confirms usable tooling now; it does not identify which external action repaired Docker Desktop.

## Supabase CLI telemetry permission

Status: **WORKAROUND VERIFIED** (`DO_NOT_TRACK=1` permits the version query); normal telemetry write remains permission-blocked in the sandbox.

`npx supabase --version` initially failed because its telemetry writer could not create `C:\Users\User\.supabase\telemetry.json.tmp...` inside the sandbox (`EPERM`). Setting `DO_NOT_TRACK=1` allowed `npx --no-install supabase --version` to return `2.115.0`. An approved unsandboxed `npx --no-install supabase status` then reached its local Docker health check but failed because the Docker engine pipe was unavailable. The status command printed linked-project metadata; it did not access or modify the linked project.

## Git index permission

Status: **RESOLVED FOR THAT CHECKPOINT** (explicit-path staging succeeded in an approved unsandboxed call).

The sandbox could read Git state but could not create `.git/index.lock` for staging. An approved unsandboxed `git add` using the exact changed `brief/` paths succeeded. A first retry with `-c core.excludesfile=NUL` failed because Git rejected `NUL` as an exclude file; removing that override resolved the staging command. The documentation checkpoint was committed as `d659b95` before any SQL edits.

## SQL defects found in prior verification

Status: **FIXED AND VERIFIED ON A DISPOSABLE LOCAL DATABASE**.

### `device_sessions` SELECT permission denied for `is_banned(uuid)`

The 2026-09-22 verification report recorded that `device_sessions_select_admin` called the revoked `is_banned(uuid)` function directly in an RLS policy. An authenticated SELECT raised `permission denied for function is_banned`, including ordinary users reading their own devices. The new `20260923100000_admin_device_sessions_read_guard.sql` migration replaces the own and admin SELECT policies with the client-callable `is_current_user_banned()` check. On the disposable project, `supabase test db --local` passed the directory file (33 assertions), the four targeted files (86 assertions), and the complete 12-file SQL suite (212 assertions). The directory file checks own-row access, admin cross-account reads, and banned-admin denial.

2026-09-23 P6 continuation recurrence: the new block INSERT policy initially called the same server-only helper. Focused pgTAP caught permission denial and a missing block. Changed the not-yet-committed migration to use `is_current_user_banned()`; all 26 block/flag assertions and the final 263-assertion SQL suite passed.

### Malformed single-dollar pgTAP quoting in `admin_user_directory.test.sql`

Five assertions in `supabase/tests/admin_user_directory.test.sql` used malformed single-dollar strings. They now use `$$...$$`. The expanded file has 33 pgTAP calls, matching `plan(33)`, and covers authorization, self/Master Admin protection, ban, revocation, and audit cases. Its full `finish()` run passed on the disposable local database: `Files=1, Tests=33, Result: PASS`.

## Weekly-only budget window mislabeled five-hour

Status: FIXED. Codex primary duration was 10,080 minutes with no secondary window, but the meter treated primary as five-hour. With explicit owner authorization, classify known durations correctly, preserve percentage-valued 1 as 1%, and add weekly-only mode with cap 5 / soft 4. Two Node tests cover thresholds, stale readings and missing weekly data. The live check returned weekly=3, cap=5, status=OK. No five-hour data was invented.

## Claude Opus budget `no_snapshot` stopped P6

Status: UNVERIFIED workflow override; no P6 code changed in the blocked sessions.
Observed: `budget_check.mjs --source claude --plan single` returned `status=UNKNOWN reason=no_snapshot` twice because `brief/.runtime/usage_snapshot.json` was absent.
Cause: the Claude status-line snapshot had not been written in those sessions; whether Claude's status line would later provide usage was not established.
Fix/workaround: the owner explicitly removed Claude Opus 5.5 usage-meter and percentage-cap requirements in `brief/04_BUDGET_PROTOCOL.md` §K. Opus can resume the P6 task without a snapshot while following the unchanged repository safety and technical verification rules. The Codex 5% weekly cap remains in §J.
Verification: policy and project instructions were updated; a new Opus session has not yet tested the continuation. Do not claim that the meter itself was repaired.
Evidence: the two reported `UNKNOWN reason=no_snapshot` readings and `brief/04_BUDGET_PROTOCOL.md` §K.

## Admin direct link redirects before backend role loading
Status: FIXED locally.
Observed: /admin redirected to the feed while its authenticated role lookup was still pending. A first loading-screen implementation stayed on its spinner because a router refresh did not rebuild the same route.
Cause: the redirect interpreted an unresolved role as a denied role; the route builder did not subscribe to loading state.
Fix: AppProvider exposes role-loading state, the redirect waits, and the route observes loading before building the role-gated Hub.
Verification: focused router regression, 514 full Flutter tests, analyzer zero, visible local GoTrue Master Admin direct-link browser load. No physical-device or production evidence.
Evidence: brief/evidence/2026-09-23/admin-hub/README.md.

2026-09-23 owner-remediation follow-up: the router now also waits for full auth/profile/device hydration and preserves the requested path through splash. Per-account role choice and account-generation guards prevent a stale session from making the routing decision. Final Flutter suite: 530 passed; analyzer 0. Real Google/admin deep-link acceptance remains open.

## Role choice repeats or leaks across accounts
Status: FIXED locally.
Observed: existing viewers were sent back to role selection, while fresh users could bypass it after OAuth; late profile loads could cross account boundaries.
Cause: memory-only role choice, routing before hydration, incomplete account clearing and stale asynchronous results.
Fix: account-keyed preference, hydration routing gate, clearing account-owned fields and auth-generation guards (including sign-out/back-in to the same account). Duplicate refresh does not reclaim a displaced device.
Verification: owner_acceptance_regression_test.dart covers restart, A-to-B and same-account races; final full suite 530 passed. Real Google/F5 remains an owner check.
Evidence: brief/evidence/2026-09-23/p6-owner-acceptance/REMEDIATION_2026-09-23.md.

## Phone landscape ParentData crash and preview disposal
Status: layout crash FIXED locally; physical preview UNVERIFIED.
Observed: landscape widget test reproduced incorrect ParentDataWidget use; owner screenshots showed black portrait/landscape preview.
Cause: PositionedDirectional nested below AnimatedOpacity/IgnorePointer instead of directly under Stack; native preview-view disposal also destroyed the encoder.
Fix: correct Stack positioning; detach GL offscreen on surface loss, reattach replacement view, keep encoder destruction under explicit engine disposal.
Verification: en/ar portrait/landscape/keyboard widget tests and Android debug compilation pass. No attached physical phone or real ingest was tested; screenshots alone do not prove the native cause on that device.
Evidence: dated owner remediation addendum.

## Phone LIVE before encoder/server confirmation
Status: FIXED locally; external ingest UNVERIFIED.
Observed: phone looked LIVE while server/feed were offline and Studio had no incoming encoder data.
Cause: optimistic client live flag and treating the native start command return as a connection acknowledgement; phone chat also used a different fabricated room ID.
Fix: wait for actual native live event, then successful set_live_state RPC; serialize start/stop updates, fail closed, stop on ownership loss, use the actual watch ID for chat. Phone studio collects watch link plus private ingest key separately.
Verification: native-event/error/dispose and server-denial tests; local two-session transfer clears server live and denies displaced restart. Real YouTube ingest remains an owner-authorized physical test.
Evidence: dated owner remediation addendum.

## Windows STL1011 in permission_handler_windows
Status: UNRESOLVED environment/dependency compatibility.
Observed: flutter build windows --debug --no-pub failed under MSVC 14.51.36231 with C2338 / STL1011 in experimental/coroutine, building permission_handler_windows_plugin.vcxproj.
Cause: the installed compiler rejects the plugin's deprecated /await experimental coroutine path. This is a build failure before app launch, not a demonstrated Dart runtime defect.
Fix/workaround: none applied. Confirm a supported upstream plugin/toolchain resolution; do not add suppression/compiler flags speculatively.
Verification: reproduced once with no backend defines. Android and web builds are separate evidence and do not resolve Windows.
Evidence: brief/.runtime/owner-windows-build.log (ignored); sanitized verification.txt in the remediation folder.

## Realtime initial snapshot precedes first channel join
Status: FIXED locally for `device_sessions` (2026-09-24); other `.stream()` users unchanged. Physical timing UNVERIFIED.
Observed: local device-transfer probe got the initial rows, transferred immediately, then timed out waiting for that Realtime event. After waiting for the same channel to join, transfer delivery and server denials passed. 2026-09-24 two-client probe: old `stream()` did not deliver an early transfer within 25 s.
Cause: installed supabase 2.16.1 stream builder fetches initial HTTP data before channel join and re-fetches on subsequent joins only. Initial data is not proof that Realtime is subscribed.
Fix/workaround: `AdminDatabaseService.watchDevices` subscribes first and reads the rows after every (re)join and change event; only the newest read is emitted. The 20-second heartbeat remains as a second line, and app resume heartbeats immediately. The owner must still measure the initial-join and active-publisher stop paths on two phones.
Verification: two local password sessions, same stream primary keys/filter as the app; publication exists; joined transfer delivered, displaced heartbeat false, live cleared and restart denied 42501. No E4 evidence.
Evidence: dated owner remediation addendum and verification.txt; 2026-09-24 probe: early transfer seen after 35 ms with read-after-join (`brief/evidence/2026-09-24/p6-retest-repair/README.md`).

## Device conflict dialog removed by splash navigation
Status: FIXED locally (2026-09-24); two-phone retest open.
Observed: P6-R02 on two physical phones and phone+laptop: signing the same approved broadcaster into a second device showed no "Multiple Device Login Detected" dialog.
Cause: reproduced with the real router: the conflict is detected inside sign-in hydration while `/splash` is showing. The dialog, a pageless route on that page, was removed when the router replaced the page (`dialog shown at /splash hydrating=true` → `completed choice=null at /feed`). Contributing: a primary silent for 90 s (frozen Android app, throttled tab) was taken over with no prompt; the client read then claimed in two steps and treated a failed read as "no conflict".
Fix/workaround: `DeviceSessionPresenter` presents after hydration and off `/splash`, and re-presents if navigation removes it. `claim_broadcaster_device_state` (20260924100000) claims or reports the primary device, fresh or stale, in one locked transaction.
Verification: `test/device_session_presenter_test.dart` 6 passed; SQL 16 passed; local two-client probe passed. No physical-device evidence.
Evidence: `brief/evidence/2026-09-24/p6-retest-repair/README.md`.

## Studio errors hidden behind the bottom sheet
Status: FIXED locally (2026-09-24); device retest open.
Observed: P6-R06/R08/S01: OBS "Go Live", Phone "Open Camera" and Local "Stream" appeared to do nothing.
Cause: reproduced: refusals (missing watch link, non-primary device, approval, server refusal) were SnackBars on the page's ScaffoldMessenger, painted underneath the modal studio sheet. Local only saved an `rtmp://` address; no transport exists.
Fix/workaround: errors render inside the sheet with preflight for approval, primary device (with a "use this device" action), key, watch link and platform; double-tap guard; OBS reports server-confirmed app listing only; Local is shown as unavailable.
Verification: `test/broadcaster_studio_entry_test.dart` 12 passed, older studio/contrast tests 60 passed. Real ingest UNVERIFIED.
Evidence: `brief/evidence/2026-09-24/p6-retest-repair/README.md`.

## Map visibility false success and unaudited revocation
Status: FIXED locally (2026-09-24); owner retest and hosted migration open.
Observed: P6-R09: hide-from-map and streamer revocation missing from the audit log; older checklist "Failed to update map visibility".
Cause: the provider caught backend failures, changed local state and returned success; the service wrote the flag directly. The registry "Delete Streamer" removed the row locally, then made unaudited multi-table writes and deleted the user's organizations.
Fix/workaround: `admin_moderate_broadcaster` (20260924110000) with a guard trigger against direct API writes of the flag; personal revocation through audited `admin_update_account('revoke_streamer')`; client changes state only after server success; UI requires a reason and says revocation is not deletion.
Verification: SQL 26 passed (including forced audit failure → no change); `test/admin_broadcaster_moderation_test.dart` 4 passed; local API probe passed.
Evidence: `brief/evidence/2026-09-24/p6-retest-repair/README.md`.

## Filtered Realtime DELETE not delivered (unban)
Status: WORKAROUND (2026-09-24).
Observed: ban/unban took effect only after app restart.
Cause: ban state was read only at sign-in. Realtime delivered a filtered `banned_users` INSERT in ~0.45 s locally, but 0 events for the filtered DELETE of an unban.
Fix/workaround: subscribe to the account's `banned_users` row; while banned, re-read every 20 s; re-read on resume.
Verification: local API probe. Device timing UNVERIFIED.
Evidence: `brief/.runtime/r09-probe.log` (ignored), summarized in the 2026-09-24 repair note.

## Application status screen had no way back
Status: FIXED locally (2026-09-24).
Observed: P6-R09 note: "Apply to Stream (5-Step Form)" left the user without a back button.
Cause: Settings used `context.go()` and sent any existing application, including rejected/revoked, to the pending screen, which had no app bar. The wizard back arrow only stepped backwards.
Fix/workaround: push by status (pending → status screen, otherwise wizard); back action on the status screen; wizard close action from any step.
Verification: `test/p6_retest_navigation_and_avatar_test.dart` passed. Device retest open.
Evidence: `brief/evidence/2026-09-24/p6-retest-repair/README.md`.

## Supabase CLI `start` crashes (Bun) in the sandbox
Status: WORKAROUND.
Observed: `supabase start` via the npm wrapper crashed with a Bun panic (stack overflow / illegal instruction) in the sandbox; `supabase-go.exe` alone does not know `start`.
Cause: suspected sandbox restriction on the Bun wrapper; not confirmed.
Fix/workaround: run `node_modules\.bin\supabase.cmd start --workdir <relative path>` from the worktree root, unsandboxed, with `DO_NOT_TRACK=1` and Docker on PATH.
Verification: disposable stack `P6_retest_repair_20260924` started and applied all migrations.
Evidence: this session.

## Restarting the local Realtime container breaks joins until Kong restarts
Status: WORKAROUND (local tooling only).
Observed: after `docker restart` of the local Realtime container, channel joins timed out although the container reported healthy.
Cause: suspected stale upstream in the local Kong gateway; not confirmed.
Fix/workaround: restart the local Kong container as well.
Verification: probe joins recovered after the Kong restart.
Evidence: this session.

## Signed-in long-lived Chrome reload hang
Status: UNRESOLVED; not reproduced.
Observed: owner P6-R04 note: in long-lived tabs, reload occasionally fails to fetch or hangs until refreshed fresh.
Cause: unknown. Code facts only: `main()` awaits `Supabase.initialize` (session recovery) before the first frame, and hydration awaits several network calls without timeouts while `/splash` shows. No cause assigned.
Fix/workaround: none (no speculative fix).
Verification: not attempted in a signed-in browser in this session (browser selection needed the owner).
Evidence: capture steps in `brief/evidence/2026-09-24/p6-retest-repair/README.md`, step 10.

## Offline map pins disappear without a public catalog snapshot
Status: FIXED locally; physical cold start UNVERIFIED.
Observed: P5.5 filtered all cached pins against the current public catalog, which can be absent on a cold start even when the independently saved marker cache exists.
Cause: an absent catalog and an authoritative empty catalog were both represented by an empty ID set.
Fix/workaround: distinguish those states; retain marker-only pins until a catalog is available, then filter by its visible IDs. Version the marker cache to v2 and save only verified, map-visible pins; older unvetted cache entries are ignored.
Verification: focused map/catalog tests passed, combined Flutter suite 587 passed, analyzer 0. Physical airplane-mode cold start remains open.
Evidence: local P5/P6 merge checkpoint in `brief/LEDGER.md`.

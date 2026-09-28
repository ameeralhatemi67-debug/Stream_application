# Issues encountered during release hardening

Updated: 2026-09-27. This is a local troubleshooting record, not proof that the database tests passed.

## Issue-name index — scan this list first

- **Desktop identity cards remain phone width** — Settings and channel use context-specific laptop widths; owner retest pending.
- **Desktop map shows permanent list and dims on drawer open** — side panel removed; existing drawer opens from top control without scrim; owner retest pending.
- **Sparse Discovery cards center on laptop** — desktop grid starts at physical left in both languages; owner retest pending.

- **Expanded profile details overflow empty tabs** — empty states made scrollable; enlarged en/ar card checks pass, physical retest pending.

- **Selected map pin disappears at close zoom** — source suppression removed; selected pin retained and pulses, device confirmation pending.

- **Spatial Map and drawer hide legacy profiles with saved pins** — shared city filter repaired locally; owner confirmation pending.
- **Edit Account Profile dropdown crashes for cs_tech** — saved category retained exactly once; editor/save regression passes.
- **Gradle daemon disappears with native memory exhaustion** — confirmed Windows memory exhaustion before Android launch; recovery/rebuild pending.

Agents: when investigating an error, scan only these short names for a match. If one matches, read that entry's section; do not reread the whole file by default. When you fix a new issue, append a concise entry under a clear heading and add its short, searchable error name here. Record the fix and how it was verified; label it `UNVERIFIED` if runtime confirmation is pending. Do not mark an unresolved issue fixed, and update an existing entry instead of creating a duplicate.

- **Profile edits unnecessarily resubmit verification or report cached success** — separate server-reviewed edit path; descriptive edits publish, sensitive revisions await approval; hosted migration and owner retest pending.
- **Selected venue card overflows Arabic narrow screen** — responsive layout updated; populated 280–1280dp matrix, physical acceptance pending.
- **Offline save mixes application generations or loses page pins** — immutable publication, build identity and acknowledged durable client pins; local browser/worker faults verified.
- **Organization reload invents a venue and application city fails constraint** — approved public application projection and all existing city choices; local SQL/privacy tests pass.
- **Flutter test shard loses lazy organization branch** — test pixel ratio leaked; reset and scroll to verify the last branch.
- **Chrome Cache.put InvalidAccessError in long test profile path** — short isolated profile works; precise browser filesystem cause unconfirmed.

- **Phone retry loses authority or mute intent** — bounded fresh-authority recovery and native generation/intent guards; physical recovery pending.
- **Viewer controls toggle covered by status row** — confirmed and unconfirmed states repaired; physical hit testing pending.
- **Native emulator ANR and sparse output** — unresolved; not a native UX pass.
- **Channel URL contradicts stale handle** — shared parser/save guard; ownership proof remains a release blocker.

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
- **Windows STL1011 in permission_handler_windows** — FIXED locally with plugin-only MSVC compatibility definition; debug build passes.
- **Android generated plugin registrant missing** — RECOVERED locally after Flutter cache regeneration; exact phone launch passes, root cause unconfirmed.
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
- **Transferred broadcaster keeps stale LIVE card** — UNRESOLVED on receiving physical phone; server/viewer state differed until restart.
- **Viewer room plays unrelated YouTube video** — UNVERIFIED cause; supplied screenshot does not show the phone broadcast.

- **Live room stays uncertain after End during viewer outage** — source regression repaired; physical convergence pending.
- **Landscape chat and settings overflow at large text** — synthetic en/ar layouts pass; physical IME/TalkBack pending.
- **Camera rotation follows Flutter virtual display** — actual Activity display ID fixes unchanged portrait framing; physical uprightness pending.
- **Java helper missing from Android APK** — move Java source to src/main/java; runtime receive path verified.
- **Custom viewport defeats video mute** — clear stream viewport while hidden; received black frame verified.

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
Status: FIXED locally for the installed toolchain; upstream plugin modernization remains open.
Observed: flutter build windows --debug --no-pub failed under MSVC 14.51.36231 with C2338 / STL1011 in experimental/coroutine, building permission_handler_windows_plugin.vcxproj.
Cause: the installed compiler rejects the plugin's deprecated /await experimental coroutine path. This is a build failure before app launch, not a demonstrated Dart runtime defect.
Fix/workaround: `project/windows/CMakeLists.txt` sets `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` only on `permission_handler_windows_plugin`. An attempted `/await:strict` override was rejected because the plugin also passes `/await`; it was removed. Track an upstream move to standard C++20 coroutines rather than broadening this compatibility definition.
Verification: `flutter build windows --debug --no-pub` succeeded and produced `streamer_app.exe` with MSVC 14.51. App launch and signed-in behavior remain untested.
Evidence: brief/.runtime/owner-windows-build.log (ignored); sanitized verification.txt in the remediation folder.

## Android generated plugin registrant missing
Status: RECOVERED locally; original intermittent cause UNVERIFIED.
Observed: owner Android runs reported `Error when reading '.dart_tool/flutter_build/dart_plugin_registrant.dart': The system cannot find the file specified` during `compileFlutterBuildDebug`.
Cause: unconfirmed; the generated file existed when inspected. Stale or competing generated build state remains a possibility, not an established cause.
Fix/workaround: `flutter clean` removed `.dart_tool`, then normal `flutter run` regenerated the registrant. Run one Flutter build at a time from this checkout. If the error recurs, capture verbose build evidence and generated-file state before another clean. The phone's real-config debug APK was rebuilt and installed without launching it.
Verification: `flutter run` built, installed and launched on SM M307FN without defines; on SM S936B, a normal run with a placeholder define file built, installed and launched before and after `flutter clean`. The clean run took about 115 s for Gradle. `flutter build apk --debug --target-platform android-arm64 --no-pub --dart-define-from-file=dart_define.local.json` then passed, and `adb install -r` on SM S936B returned `Success`. The real-config app was not launched by Codex, so signed-in or hosted behavior remains unverified.
Owner retry: the real-config APK is installed on SM S936B (`R5CY42JAW4E`). Open it on the phone, or run `flutter run -d R5CY42JAW4E --dart-define-from-file=dart_define.local.json` from `project/` with no other Flutter build from this checkout in progress. The package-update notices and discontinued-package notice did not stop these builds and do not call for a dependency upgrade as part of this recovery.

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

## Transferred broadcaster keeps stale LIVE card
Status: UNRESOLVED; owner observed on physical devices in wave 3.
Observed: after Phone 2 took broadcaster ownership from a live Phone 1, Phone 1's encoder stopped and viewers saw offline, but Phone 2 kept showing LIVE until a full restart.
Cause: unknown. The server-side forced claim clears live state; device ownership and public streamer models refresh through separate client paths. The missed path has not been reproduced in a controlled trace.
Fix/workaround: restart cleared the display in the owner's run; this is not acceptance. Capture server profile state, both clients and Realtime/catalog refresh at transfer, then fix and add a focused regression.
Verification: owner two-phone observation only; no new automated test or repair in this review.
Evidence: `brief/evidence/2026-09-24/p6-retest-repair/REPAIR_RETEST_RESULTS.md` and `brief/evidence/2026-09-24/p6-wave3-review.md`.

## Viewer room plays unrelated YouTube video
Status: UNVERIFIED cause; matched playback remains open.
Observed: the attached paused-chat viewer-room image visibly plays a YouTube Developers video while the owner reports a separate phone broadcast reaching YouTube Studio.
Cause: unknown. The entered watch ID, public catalog row and Studio event were not compared.
Fix/workaround: check that all three refer to the same broadcast ID, then test video and audio on an independent viewer.
Verification: screenshot inspection only; no code defect assigned or fix made.
Evidence: `brief/evidence/2026-09-24/p6-retest-repair/screenshots/good/R06-viewer-in-live-room-chat-paused.png` and `brief/evidence/2026-09-24/p6-wave3-review.md`.

## Live room stays uncertain after End during viewer outage
Cause: recovery required a live entry before End reconciliation, discarded polling with room services, and did not fence same-watch replacement sessions. Fix: retain original actor/watch/session, reconcile successful fresh catalog first and keep polling through interruption. Verification: new baseline regression failed; targeted suite43 passed. Healthy-network owner timing still needs physical reproduction; polling is20s with2s optional sweep/5s public-read timeouts; healthy room target30s/discovery40s. See Wave4v2 evidence.

## Landscape chat and settings overflow at large text
Cause: composer stayed present on rotation; sheet did not scroll; connection status could exceed narrow chat header. Fix: read-only landscape, screen-owned sender draft, scrollable safe-area sheet, flexible header labels and readable sheet colors. Verification:740x360/190px synthetic inset/2x/en-ar tests17 pass; initial new tests exposed71/87px overflow. Actual90/17px screenshot device cases remain NOT RUN.

2026-09-27 follow-up: own-message Edit and studio opened from video could still offer text entry in landscape. Both now show a portrait-edit prompt while retaining drafts. Dialog controllers are disposed after route completion, fixing a disposed-controller error caught by the rotation/cancel test. Message action/report sheets scroll. Sender settings checks include 568x240, 740x360 and 1366x768 at 2x text in en/ar. The obsolete sender fullscreen lock was removed so physical rotation owns layout; AndroidView ignores pointers so the media tap reaches Flutter. See `brief/evidence/2026-09-27/p6s-camera-landscape/VERIFICATION.md`; real IME/TalkBack pending.

## Phone retry loses authority or mute intent

Cause: native retry could reconnect without checking current server ownership; callback flapping and watchdog shutdown could reset bounds or lose native mute. Fix: one Dart-owned 3s/10-attempt/60s episode, fresh session/device/permission RPC checks, native generation fence and explicit mute/camera flags per start. SDK rotation moves to RtmpStream with independent fitted preview and stable output dimensions. Verify native/received video separately; mock/compile results are not physical acceptance.

## Viewer controls toggle covered by status row

New toggle was initially behind the full-width header hit region. A widget tap regression reproduced it. Reserve a separate 48dp slot; media pointer observer does not claim the native gesture arena. Confirmed-state regression passes. Final review5162add found a full-width unconfirmed notice above the eye toggle: text intercepted its normal tap center. The owner-requested 2026-09-27 follow-up reserves that space and exercises the actual unconfirmed-state tap. Source fix verified in widget tests; physical/TalkBack checks remain pending. No fourth critic review or score applies to the follow-up.

## Channel URL contradicts stale handle

Cause: independent fields and permissive legacy path stripping saved conflicting identities. Fix: shared syntactic parser, pair validation before save, authoritative resolution for mixed references, canonical pending application. Vanity /c URLs require a current handle/UC URL. No ownership claim: D8 server/OAuth coordination remains explicitly release-blocking. Physical form/account checks pending.

## Native emulator ANR and sparse output

Status: UNRESOLVED. Fresh private Android16/API36 emulator with synthetic cameras produced H2641280x720/AAC and stopped resources, but only48frames over37.603s; preview screenshot shows System UI ANR. Cause unestablished; low-resource emulator is not a smooth/native/physical pass. Evidence: Wave4v2 NATIVE_PROBE.md and native screenshots. Real received-video orientation, recovery, long-duration/thermal and Home/lock tests remain required.

2026-09-27 final local probe: 484 frames over 48.742 s video timestamp span (9.91 delivered fps, largest gap 1 s); both landscape framing changes and a black Hide-video frame observed, camera/service release confirmed. System UI ANR still visible; cause remains unestablished. This is not a native UX/performance pass. See `brief/evidence/2026-09-27/p6s-camera-landscape/NATIVE_PROBE.md`.

## Camera rotation follows Flutter virtual display
Status: fixed in local receive probe; physical orientation UNVERIFIED.
Observed: UI rotates but transmitted frames stay portrait despite a display listener.
Cause: Flutter hosts the preview SurfaceView on a virtual display whose rotation stays zero.
Fix/workaround: pass the Activity display ID into the bridge; use DisplayManager for that display. Apply inverse display rotation after the camera texture's sensor transform, then fit portrait/crop landscape using actual advertised capture dimensions. Do not add a fixed -90 degree transform or restart the encoder on rotation.
Verification: local H.264 received frames show portrait, both landscape rotations, then portrait; geometry assertions cover 16 sensor/display combinations and different ratios. The emulator's fixed house scene does not prove real-world uprightness. Two-phone TOP-arrow checks remain required.
Evidence: `brief/evidence/2026-09-27/p6s-camera-landscape/NATIVE_PROBE.md`.

## Java helper missing from Android APK
Status: FIXED.
Observed: new CameraFraming helper compiled but runtime failed with NoClassDefFoundError.
Cause: Java file placed under src/main/kotlin was available to Kotlin compilation but omitted from the packaged Java classes.
Fix/workaround: place it under src/main/java with the matching package; keep Kotlin bridge/source under src/main/kotlin.
Verification: rebuilt isolated probe executes the helper during successful local capture/rotation. Compilation alone did not catch the defect.
Evidence: `brief/evidence/2026-09-27/p6s-camera-landscape/native-packaging-failure.txt` and final native events.

## Custom viewport defeats video mute
Status: FIXED locally; physical Hide/Show acceptance pending.
Observed: inspection of RootEncoder 2.7.5 shows a custom stream viewport takes precedence over muteVideo's zero-sized draw viewport.
Cause: the new custom fit/crop geometry could override the SDK's video-hide mechanism.
Fix/workaround: setStreamViewPort(null) while audioOnly is true, including rotation/resize/reconnect synchronization. Restore framing when showing video.
Verification: final native receiver gets a black frame after Hide video. Camera remains active by existing design; this does not prove resource release while hidden.
Evidence: `brief/evidence/2026-09-27/p6s-camera-landscape/received-final-49.png`.

## Selected venue card overflows Arabic narrow screen
Status: FIXED locally; physical acceptance pending.
Observed: Row actions/badges and fixed popup size clipped selected venue actions at narrow widths and large text.
Cause/fix: Wrap actions/badges;48dp targets and a scrollable selected overlay. Related short End/failure surfaces scroll.
Verification:72 populated en/ar card combinations,320/360/384/412dp,1/1.6/2x; integration evidence pack. Not an empty-map or phone PASS.
2026-09-27 FIX-02: Owner requested the drawer beside attribution and expand hidden. Removed the card-side control gutter, capped responsive width at 420dp with 16dp phone margins, stabilized the primary-action row and retained bounded scrolling. Attribution wraps beside the drawer. Expanded regression matrix: 126 combinations, widths 280 through 1280, short landscape, en/ar and up to 2x text; owner-device confirmation pending. See brief/evidence/2026-09-27/map-card-ui/VERIFICATION.md.

## Offline save mixes application generations or loses page pins
Status: FIXED in local verified paths; browser eviction and five-minute reserved-client grace remain explicit limits.
Observed: Map-only readiness missed app updates, file-wise promotion could mix generations, worker restart/first claim/pruning lost page identity.
Fix: Build+pack identity, hashed app files, immutable generations/atomic pointer, bounded fetch, Web Locks, durable pins, page-build acknowledgement and controllerchange retry. Failed Dart callbacks settle JS lock promises before rethrowing.
Verification: Real Chrome publication/download faults, cold Arabic startup,52-file inventory, worker restart/hang/multi-tab; deterministic actual-worker and HTML-script regressions. See integration VERIFICATION for artifact scope.

## Organization reload invents a venue and application city fails constraint
Status: FIXED locally; configured owner flow pending.
Observed: Public reader assigned every organization Khobar coordinates; four offered application cities failed a new three-city constraint.
Fix: Persist all existing application city choices separately from map scope. Organization public location comes only from a linked approved organization application with matching owner. Unknown remains unknown; private branch rows stay private and unchanged; no0,0 directions in branch sheet.
Verification: Application/HTTP catalog regressions and fresh SQL including foreign/pending/individual links, combined owner/reference attack and exact-coordinate retention.

## Flutter test shard loses lazy organization branch
Status: FIXED test isolation.
Observed: TC-ORG-UI-04 failed alone/in shard5 because a previous test left devicePixelRatio altered and the assertion expected an offscreen lazy row.
Fix: Reset pixel ratio in teardown; scroll to third branch, retaining all three names/seating assertions.
Verification: Full six-test organization profile file passes independently; final full-suite results in integration evidence. Separate host JIT OOM attempts remain failed logs.

## Chrome Cache.put InvalidAccessError in long test profile path
Status: UNRESOLVED precise cause; working isolated-profile alternative verified.
Observed: Every put, including unrelated fresh-cache keys, failed in the deeply nested disposable integration profile. Identical candidate passed in a short temporary profile.
Action: Preserve failed profile; use short dedicated test profile and capture Chromium filesystem diagnostics if repeated. Do not patch app behavior or clear owner caches to hide it.
Verification: Initial-page acknowledgement and all52 offline assets pass under the short profile. Path/profile-related explanation is an inference, not proven Chromium root cause.

## Gradle daemon disappears with native memory exhaustion
Status: UNRESOLVED recovery; immediate cause confirmed.
Observed: Android run on SM-S936B failed at assembleDebug with daemon pid 39724 disappearing, 2026-09-27 11:20 +03:00. Owner reports Chrome run works.
Cause: JVM fatal log confirms native malloc failure for 1,519,776 bytes. Windows had 233 MiB free physical memory and 38 MiB available system commit capacity. Gradle allowed an 8 GiB heap / 4 GiB metaspace; these are maximum limits, not proof of actual allocation. At failure its resident size was about 450 MiB, so this was system-wide pressure, not evidence of an app memory leak. Follow-up at 11:23 had only about 468 MiB physical memory available and 2.48 GiB commit headroom.
Fix/workaround: save work and close unnecessary applications/build sessions, or restart Windows and reopen only the main project plus the required phone connection. Retry the same owner command after memory is available. Do not upgrade packages or clear project caches based on this error. No processes stopped, system settings changed, or credentials read by the manager.
Verification: fatal-log header and memory counters inspected; current OS memory checked read-only. Android rebuild/install/reception NOT RUN. Chrome success is owner-reported and does not establish physical acceptance. If it repeats after freeing memory, inspect the new crash log and consider measured Gradle heap/worker limits; reducing heap alone is not a proven fix for this system-wide exhaustion.
Evidence: ignored local `project/android/hs_err_pid39724.log`; sanitized summary in `brief/evidence/2026-09-27/android-build-memory/DIAGNOSIS.md`.

## Spatial Map and drawer hide legacy profiles with saved pins
Status: REPAIRED locally; confirmation against the owner's live profiles pending.
Observed: Owner reports zero profiles in Spatial Map or its drawer while Admin/Discovery retain them, with the new basemap visible. Two example pins are 26.3050/50.1450 and 26.2172/50.1971.
Cause: The shared visibleMapStreamers catalog required a recognized city label as well as valid coordinates. Older backend records may have blank city fields; these disappear before markers, search, cards and drawer receive them. This cause is reproduced in local fixtures; live backend rows were not inspected, so it is not proof that every reported profile has this cause.
Fix: Shared isTricityMapVenue allows blank-city exact pins within the existing core overview; explicit other-city records and invalid/out-of-area pins stay excluded. No coordinates or city names are fabricated. Cached markers follow the same eligibility and retain Arabic-only city metadata. Verification/hidden-profile checks and current-catalog cache revocation remain intact. Accurate municipal geometry remains an open requirement; the overview is a product extent only.
Verification: Catalog/cache tests cover both reported locations plus a third location and negative cases. Widget regression taps the marker and drawer entry and verifies the profile card opens. Full regression evidence and owner retest instructions: brief/evidence/2026-09-27/map-profile-repair/README.md. Owner runtime confirmation pending.

## Edit Account Profile dropdown crashes for cs_tech
Status: REPAIRED locally; owner retest pending.
Observed: BroadcasterApplicationSheet throws DropdownButton's exactly-one-item assertion when the stored category is cs_tech.
Cause: Registration/legacy/custom category IDs can differ from the editor's five hardcoded DropdownMenuItem values. The editor restored the saved value without including it in the available items.
Fix: Combine existing choices and provider categories, deduplicate by ID, and include the saved category even if legacy/custom/inactive. Keep the original saved ID unless the user changes it; no forced category migration.
Verification: Widget tests open and submit the sheet for computer_science, cs_tech and custom_subject, assert exactly one matching item, no widget error and unchanged submitted category. Full verification evidence: brief/evidence/2026-09-27/map-profile-repair/README.md. No hosted backend write or device acceptance claimed.


## Selected map pin disappears at close zoom
Status: REPAIRED locally; owner device retest pending.
Observed: Owner reports a profile pin disappears after selection while its summary card remains.
Cause: The live marker builder skipped selected markers at zoom >=13.5, assuming an anchored card would replace them. The actual summary card is a separate bottom overlay.
Fix: Always retain the selected marker at its exact coordinates and exclude it from cluster membership while selected. Reuse its animation controller for a 1.0–1.16 size pulse; reset when deselected, TickerMode is inactive or reduced motion is requested. Clear map selection when its tab is hidden, so returning does not restart a stale selection.
Verification: Widget regression selects overlapping profiles, checks the selected marker/card remain together, observes scale change, zooms out and leaves/returns to the map. The 143-test map file passes, including the existing card-size matrix. Full result is recorded in brief/evidence/2026-09-27/studio-pin/VERIFICATION.md. Device playback is not claimed; the supplied MP4 could not be opened by the browser's file-URL policy.

### Expanded profile details overflow empty tabs

2026-09-27, DES-01. A long expanded profile header leaves little or no height for the nested tab body. The empty archive/playlist/upcoming states used a centered non-scrollable Column, producing a vertical RenderFlex overflow. These three empty states now scroll. Automated en/ar layout and card interaction cases pass; physical confirmation remains pending. See `brief/evidence/2026-09-27/unified-streamer-cards/VERIFICATION.md`.

## Profile edits unnecessarily resubmit verification or report cached success

2026-09-27 — FIX-04. Settings reused the initial application sheet submission for approved accounts. Every save attempted pending status on the existing application, although owner RLS only permits pending-row edits; database failures could then become cached success. Separate editing mode now calls `save_broadcaster_profile`, which checks ownership/approval/bans and classifies fields on the server. Safe edits publish immediately; sensitive edits use a pending revision, with atomic publication on approval and no revocation on rejection. Direct writes cannot bypass contact/location/YouTube review. Existing approved channel data remains the broadcasting source. Local SQL regression passes; analyzer clean; final Flutter result is in `brief/evidence/2026-09-27/profile-edit-card-polish/VERIFICATION.md`. Hosted migration and physical acceptance remain pending.

## Desktop identity cards remain phone width
Status: REPAIRED locally; owner laptop retest pending.
Observed: DESK-01 Settings identity and DESK-02 streamer profile header stayed about 420px wide in owner laptop screenshots while surrounding sections/grid used more space.
Cause: The shared identity card capped all contexts at 420px, with a second 420px cap around the Settings card. The profile header used the same cap and separate desktop AppBar controls.
Fix: Keep the shared 420px default for phone, Map and Discovery. Settings uses its existing content rail; the desktop streamer header fills its available width, anchors actions left and overlays fixed-position controls. Phone paths retain their previous layout.
Verification: Focused 45-case card tests pass, including en/ar, large text, fixed desktop corners and 1–4 Discovery columns. Analyzer and full-suite result are recorded in `brief/evidence/2026-09-28/laptop-layout-batch/VERIFICATION.md`. No new owner build launched.

## Desktop map shows permanent list and dims on drawer open
Status: REPAIRED locally; owner laptop retest pending.
Observed: DESK-03 owner screenshot shows an always-visible 380px venue panel beside the map; the existing burger opens a separate dimming drawer.
Cause: The map built a desktop-only side panel in addition to `StreamerSlidingDrawer`. Scaffold supplied its default modal scrim.
Fix: Remove the side panel; use the existing drawer from a top-right laptop control and a transparent desktop scrim. Keep the phone control and drawer behavior.
Verification: The 144-case map widget file passes, including drawer open/closed state and 280–1280px selected-card matrix. Physical and browser retest pending.

## Sparse Discovery cards center on laptop
Status: REPAIRED locally; owner laptop retest pending.
Observed: DESK-04 owner screenshot shows two Discovery cards centered under a wide results area.
Cause: The responsive four-column `Wrap` used center alignment; RTL would start at the physical right even after changing to start alignment.
Fix: Start the desktop Wrap at the physical left in both locales. Keep existing card contents, width calculation and phone direction.
Verification: Focused card tests pass for 4, 3, 2 and 1 columns in English and Arabic. Owner visual retest pending.

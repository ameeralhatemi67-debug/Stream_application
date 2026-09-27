# Wave4v2 consolidated owner retest

**Main-checkout update, 2026-09-27:** use the merged **master** checkout at `C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app`, with Flutter under `project/`. The original integration-build hashes below are historical; record the actual rebuilt/installed master candidate in W00 and the results sheet. The merge/push does not update an installed phone app or supply missing test configuration. Keep all unperformed results NOT RUN.

**Start with [README](README.md), then W00 below. The current candidate is diagnostic until the documented Google/YouTube setup is supplied and a newly hashed configured build is produced.** Fill [matching results](WAVE4V2_ACCEPTANCE_RESULTS.md); all rows initially NOT RUN.

## Roles, evidence and stop rules

A and B are two physical Android phones (include the owner's SM-S936B; record the second model), taking turns as sender/receiver. C is Chrome on a separate laptop/profile, with an independent viewer identity; the admin uses a separate dedicated test account. Record installed package/version/hash, source/build/config/backend identity, locale, OS, actual dp/text scale, role and UTC/timezone on each run. Never record ingest keys, tokens, OAuth secrets or complete private account details.

Run W00, W02–W06 first, about 25–40 minutes per phone including switching roles. **If W00 is blocked, stop all Google/YouTube, signed-in chat/admin and cross-feature acceptance; independent diagnostic offline-map checks may continue.** If W02/W03 fails, stop S01–S08 and dependent live C/I cases; capture preview AND independent receive video, rotation times, sanitized logs and identities. If W04 fails, stop M05/M06/I01/I03 until the selected-card regression is repaired; independent streaming and archive checks may continue. If W05/W06 fails, stop long-duration and propagation/navigation acceptance, record room/feed/map simultaneously and session suffixes. Do not spend hours on dependent cases after a visibly failed smoke.

After smoke, reuse its event/account setup within the same run; start a new session only when a terminal action requires one. Budget roughly 10–13 hours sequentially, including the two ≥30-minute physical sender runs, plus provisioning and failure investigation. Split this into smoke, streaming/security, offline/accessibility and long-run sessions. Do not publish a real event without the test operator's authorization. Use only disposable local accounts for destructive admin tests. Historical reports are references, never new acceptance results.

## W00 — Candidate and configuration

- **Prerequisites / time:** README identity, artifact hashes, dedicated test backend and accounts. 5–10 min.
- **Roles/devices:** Owner; phones A/B (two physical models, include SM-S936B) and Chrome C.
- **Steps:** On Android compare package, Hadayah Test label, version, SHA-256 and source/config/backend identities with identity.json. Chrome retains the Hadayah Live page title: identify it by the dedicated loopback origin, hadayah-build meta value from identity.json (current diagnostic: `34d074a-local-diag-1`) and web archive hash, not the page title. A configured rebuild needs its own updated identity record. Confirm test callback and Google sign-in on both phones and Chrome; verify approved streamer, viewer and admin roles. Record OS/browser/model and USB/LAN topology. Do not replace the owner app.
- **Expected:** Exact candidate; no production backend. Missing Google/YouTube setup is BLOCKED, not an authentication PASS. Diagnostic may run independent map checks only.
- **Evidence:** Installation/settings screenshot without secrets; hashes, identities and role/device table.
- **Replaces / links:** All prior build/setup rows.

## W02 — Upright outgoing video smoke

- **Prerequisites / time:** W00 configured; exact permitted test event and ingest; TOP arrow and round object in frame. 6–8 min per phone.
- **Roles/devices:** A sends; B and C independently receive; then swap A/B.
- **Steps:** Show a moving TOP arrow and say a changing timestamp. Check preview AND receiver in portrait, landscape-left and landscape-right, then back. Record one continuous clip showing both devices. Keep the same session.
- **Expected:** Portrait upright and fitted (bars allowed). Both landscape directions upright and fill encoded canvas without stretching. No extra audio, encoder restart or stream interruption.
- **Evidence:** Synchronized preview/receiver clip, event/session ID suffix, gap/rotation times.
- **Replaces / links:** Camera C01–C05; F07; E4 Check15.

## W03 — Landscape controls, chat and settings smoke

- **Prerequisites / time:** W02 running; en/ar. 5 min per phone.
- **Roles/devices:** A sender, B viewer; admin role once.
- **Steps:** Tap video to hide/show controls. Check End physical top-left and settings/chat top-right. Open chat and all edit/reply paths in landscape, then settings at largest text and short landscape height. Create a portrait draft before rotation; return to it. Exercise Back without accidentally ending.
- **Expected:** Only requested normal sender controls; no telemetry header/title/fullscreen/bitrate badge. No landscape keyboard for sender/viewer/admin. Draft survives. Settings and End/Back remain reachable.
- **Evidence:** Short clips plus landscape screenshots in both languages.
- **Replaces / links:** F08–F10; camera follow-up; E4 Check15.

## W04 — Populated narrow Arabic map smoke

- **Prerequisites / time:** At least one permitted selected venue; map available. 5–8 min.
- **Roles/devices:** C at 320 dp and one physical phone; Arabic, large text.
- **Steps:** Open Spatial Map and actually select a venue. At 320 dp and largest text, inspect offline, video-live and audio-live cards. Activate the main action; return, then Close. Repeat one case at 412 dp. Do not substitute an empty-map screenshot.
- **Expected:** No overflow/clipping. Watch/Listen/Profile and Close reachable with at least 48 dp targets; scroll if needed. Exact selected venue preserved.
- **Evidence:** Selected-card screenshots, viewport/text scale and action/Close clip.
- **Replaces / links:** Map A08/A12/A14; confirmed card regression.

## W05 — Real controls and ordinary End smoke

- **Prerequisites / time:** W02 live; exact session. 5–7 min.
- **Roles/devices:** A ordinary streamer; B viewer; C feed/map.
- **Steps:** Use actual player pause/resume and mute/unmute while watching/hearing reception; do not infer from icons. On A press ordinary End and confirm. Observe B room and C feed/map without restarting either app.
- **Expected:** Commands affect media; mute/pause intent matches reception. Sender stops/releases; room becomes ended/unavailable within30s and listing/map lose LIVE within40s on healthy networks, measured from server confirmation. No stale sound or privileged role loss.
- **Evidence:** Continuous sender/receiver video, propagation timing, camera/mic indicators.
- **Replaces / links:** F01/F02/R01/R09; E4 Check3.

## W06 — Map → live → map smoke

- **Prerequisites / time:** W04/W05 passed; new permitted session. 4–6 min.
- **Roles/devices:** B viewer and C; A authorized live sender.
- **Steps:** Pan/zoom map, select the live venue, enter room, exercise visible retained-player/back behavior, then return. Repeat after End. Inspect audio, selection, viewport and current live state.
- **Expected:** Viewport preserved; exactly one permitted playback session; no ghost audio or stale LIVE after End. Return shortcut is not falsely presented as floating/PiP playback.
- **Evidence:** Before/after viewport screenshots and audio/video clip.
- **Replaces / links:** Map A17; F04/R09.

## S01 — Capture geometry, front refusal and Hide video

- **Prerequisites / time:** All streaming smoke passed; two physical models; supported quality presets. 15 min per phone.
- **Roles/devices:** A/B alternate sender; other phone + C receive.
- **Steps:** Repeat three orientations at each supported preset; use circles/edges/TOP arrow. Tap front-camera control repeatedly. Hide/restore video in each orientation while listening. Request unsupported capture configuration through a controlled local fixture if ordinary UI cannot expose one.
- **Expected:** Geometry uses actual capture; upright proportional output. Front shows localized Coming Soon without native switch/interruption. Hidden received video is black; audio single. Unsupported configuration fails safely and releases partial resources.
- **Evidence:** Receiver frame samples with timestamps, native events, preset/capture sizes where safely observable.
- **Replaces / links:** F07; R07/R11; latest camera tests.

## S02 — Read-only landscape and accessible sheets

- **Prerequisites / time:** W03 passed; portrait draft and test messages. 15 min.
- **Roles/devices:** Streamer/viewer/admin on A/B/C; both languages.
- **Steps:** For each role open chat, reply, edit and admin editing in landscape; attempt hardware/software keyboard entry. Rotate during edits/dialogs. Scroll every setting/action/End sheet at short height and large text; Back/Cancel then rotate again.
- **Expected:** No landscape keyboard or editable chat path; draft restored in portrait. No trapped sheet, lost End, overflow or accidental send. Necessary recovery messages remain readable.
- **Evidence:** Role/orientation matrix, keyboard video, screen-reader notes.
- **Replaces / links:** F08/F09/F10; P01.

## S03 — Bounded reconnect and intent

- **Prerequisites / time:** Smoke passed; approved event; log timestamps without ingest keys. 15–20 min per sender.
- **Roles/devices:** A sender; B/C receivers; local backend reachable independently when isolating media loss.
- **Steps:** Mute sender microphone and viewer playback, pause viewer separately. Drop media network briefly, restore; then repeat loss >60 s. Repeat backend loss separately and explicit Wi-Fi↔cellular transition. Restore after exhaustion and exercise Retry/Leave in both languages. Use controlled local failing-ingest endpoint only for unsupported-service failure testing.
- **Expected:** One retry controller; roughly 3 s cadence, at most 10 attempts and 60 s episode. Fresh authority required; same session recovered or terminal failure. No duplicate sound, false LIVE or unbounded loop. Android preserves measured pause/mute intent; Chrome recovery may remain unconfirmed and require native Play/Retry, with autoplay off and muted to prevent surprise audio. After exhaustion, network return alone must not start another episode; explicit Retry revalidates authority.
- **Evidence:** Timeline, reconnect count, receiver gaps, media-vs-backend topology.
- **Replaces / links:** F03/F04/F05.

## S04 — End, transfer and revocation during recovery

- **Prerequisites / time:** S03; dedicated disposable test accounts. 20–25 min.
- **Roles/devices:** A sender, B replacement/receiver, C admin and independent viewer.
- **Steps:** During a reconnect, ordinary End; repeat admin End and viewer-offline End (viewer offline5s, End, restore without refresh), including same-watch replacement. In separate sessions transfer A→B, revoke broadcaster/device, sign out or ban account while A disconnected; restore A network. Repeat transfer while End dialog is open and rapid End/start with delayed old callbacks.
- **Expected:** Terminal authority wins; old encoder stops and cannot publish or terminate a replacement. New primary owns fresh session. Room/feed/map converge; ordinary End preserves account approval/primary status.
- **Evidence:** Session/device suffixes, admin audit rows, A/B/C synchronized clips; redact tokens.
- **Replaces / links:** F06; R01/R03/R04/R12.

## S05 — OBS exact-event and duration

- **Prerequisites / time:** Configured dedicated test channel/event and permitted watch ID; smoke passed. 20–25 min.
- **Roles/devices:** Laptop OBS sender; A/B/C independent receivers.
- **Steps:** Send moving scene and spoken changing markers for ≥15 min. Disconnect OBS network, restore; record app state. End app listing normally then separately in OBS/YouTube Studio as required by test operator.
- **Expected:** Receivers play the exact event, not unrelated VOD. Recovery/status truthful. App End does not claim to control external OBS. No stale LIVE after app session terminal state.
- **Evidence:** OBS version/settings without keys, session/watch suffix, timestamped receive clips/gaps.
- **Replaces / links:** R06; P6S-1.

## S06 — Watch/channel validation and D8

- **Prerequisites / time:** Dedicated test configuration; safe disposable fixtures; never probe hosted backend here. 15–20 min.
- **Roles/devices:** Approved test streamer and unauthorized account; local API engineer.
- **Steps:** Try malformed channel URL, stale handle/channel mismatch, VOD, scheduled/not-yet-live, ended/blocked watch IDs and a permitted fresh event. Use local SQL/API negative probes to distinguish UI rejection from server authority.
- **Expected:** Client checks fail closed and explain correction. Permitted exact live event succeeds. D8 remains HIGH: these checks do not prove server-side ownership; any server bypass is recorded, not relabelled PASS.
- **Evidence:** Redacted inputs/responses, exact backend, negative-case matrix.
- **Replaces / links:** F11/F12; D8; E4 Check7.

## S07 — Physical AV, frame delivery and resources

- **Prerequisites / time:** Streaming smoke and S01 passed; temperature/resource baseline. 35–45 min per phone.
- **Roles/devices:** Each phone sends in a separate ≥30 min run; B/C independently receive.
- **Steps:** Keep changing visible/spoken markers. Include rotation, map/live navigation and a brief recoverable outage. Sample frame timestamps, AV sync, CPU/memory/thermal/battery and dropped frames at start/mid/end. Capture ANR trace/bugreport and redacted logcat if any freeze occurs. End and observe resource release.
- **Expected:** No progressive leak, duplicate audio or prolonged stalls; measure actual fps/gaps rather than nominal 30 fps. Record unacceptable behavior as FAIL. The historical System UI ANR is not cleared without attributable evidence.
- **Evidence:** Time series, representative received clips, frame timing, before/after resource/camera/service snapshots.
- **Replaces / links:** R05; map A18; unresolved emulator ANR.

## S08 — Audio-only and Home/lock truthfulness

- **Prerequisites / time:** Smoke passed; owner knows current camera-release/background limits. 15–20 min per phone.
- **Roles/devices:** A sender, B/C receiver.
- **Steps:** Start audio-only path; inspect received audio/video and OS camera/mic indicators. Hide video separately. Home 30 s, lock 60 s, return; then confirmed route exit and End. Repeat viewer pause/mute around background/foreground.
- **Expected:** Record actual continuity/gaps and resource ownership. Current hidden video keeps camera active: camera-release requirement cannot PASS. Background survival is measured, not inferred from notification. End/exit releases resources.
- **Evidence:** OS indicators, continuous receiver clip, thermal/resource notes and lifetime timeline.
- **Replaces / links:** R07/R08; P6S-2/7.

## S09 — Unavailable modes and approved deferrals

- **Prerequisites / time:** Normal diagnostic UI usable; no broadcast needed. 10–15 min.
- **Roles/devices:** Guest/viewer/streamer/admin on A/C.
- **Steps:** Visit all studio routes and organization, upcoming, external-phone, Local, private, laptop direct, web Phone, front camera, mini/PiP entries. Try repeated taps and indirect application routes.
- **Expected:** Unavailable modes explain limitation and cannot activate. No unlisted-as-private claim. Distinguish owner-approved org/upcoming/return-chip/front deferrals from unresolved mode-scope decisions.
- **Evidence:** Entry-route matrix and localized screenshots.
- **Replaces / links:** R10/R11; D3–D7.

## S10 — Player readiness and reachable-iframe fallback

- **Prerequisites / time:** W00 and W05; engineer-prepared, separately hashed debug fault fixture from the same reviewed source. 10–15 min.
- **Roles/devices:** A/B viewer plus C Chrome; independent receiver/operator.
- **Steps:** First use normal candidate with a successful iframe and actual native Play/pause/mute. Then use the existing `tool/p6s_browser_probe.dart` debug fixture with `WAVE4V2_SUPPRESS_PLAYER_READY=true` to suppress only the bridge handshake, leaving the iframe/network reachable. Engineer records this fixture's source/hash separately; do not install it over the owner app or confuse it with the deliverable. Compare normal and suppressed handshake, wait10s, exercise reachable eye toggle, native Play and Retry. Repeat a genuine player error separately.
- **Expected:** Timed unconfirmed fallback without fabricated play state; accessible controls and current-session Retry. A blocked iframe is not a handshake test. Fixture evidence does not become an ordinary-candidate physical PASS.
- **Evidence:** Normal/fixture hashes, continuous iframe response/fallback video, timestamps and role/platform results. Missing fixture means BLOCKED for that subcase.
- **Replaces / links:** R09; camera C10; previous viewer-toggle defect.

## C01 — Chat states and drafts

- **Prerequisites / time:** Configured disposable accounts; live smoke passed. 15 min.
- **Roles/devices:** Guest, viewer, muted/banned user and streamer across A/B/C.
- **Steps:** Send normally, go offline with draft, retry failed send, enter slow mode, mute/ban; scroll up while messages arrive and use new-message control. Rotate without resending.
- **Expected:** Correct read-only/slow/offline notices; draft survives; one accepted message per action; no ghost messages or duplicate retry. Landscape rule remains.
- **Evidence:** Role/state matrix and synchronized chat clips.
- **Replaces / links:** P01; F08.

## C02 — Server chat security

- **Prerequisites / time:** Disposable backend identity confirmed. 10–15 min engineer.
- **Roles/devices:** Local SQL/API fixtures for viewer, stranger, owner, admin.
- **Steps:** Run committed local SQL suite and record fresh counts/exit codes. Exercise rapid sends, Arabic normalized blocked words, invalid/duplicate reports and unauthorized moderation/settings writes. Confirm legitimate owner actions still succeed.
- **Expected:** Server rejection independent of hidden UI; no bypass of RLS, rate or moderation rules. No hosted DB operation.
- **Evidence:** Redacted SQL report and backend/container identity; do not copy older PASS into owner result.
- **Replaces / links:** P02.

## C03 — Block, report and moderate convergence

- **Prerequisites / time:** C01; dedicated messages. 15–20 min.
- **Roles/devices:** A commenter; B viewer; C admin/owner.
- **Steps:** B blocks A then restarts; A posts. Report a valid reason twice. Observe admin queue; delete/mute/unmute through authorized roles; reconnect a previously offline viewer.
- **Expected:** Block persists/synchronizes, report enum/uniqueness enforced; queue/room converge, audit evidence exists, lower roles denied.
- **Evidence:** Two-client clips, report/audit suffixes and timing.
- **Replaces / links:** P03.

## C04 — Admin directory and account isolation

- **Prerequisites / time:** Configured local accounts only; deletion does not affect owner data. 20 min.
- **Roles/devices:** Admin and lower role; sacrificial local accounts on A/B.
- **Steps:** Search/details; ban/unban, revoke broadcaster/device sessions, delete a disposable account after required ownership transfer. Try equivalent lower-role RPCs. Sign out/in across guest/viewer/streamer/other account.
- **Expected:** Authorized audited changes; no stale channel/role/privilege or deleted-account cache; lower roles denied. No old account authority after refresh/recovery.
- **Evidence:** Audit excerpts, redacted responses, account-switch clips.
- **Replaces / links:** P04/R12.

## C05 — Admin tools, flags and discovery state

- **Prerequisites / time:** Smoke passed; safe dedicated fixtures. 15–20 min.
- **Roles/devices:** C admin; A streamer; B viewer.
- **Steps:** Hide/show one broadcast, End-and-block watch ID, try relisting same then a new permitted event. Check live list, audit filters, keyword manager, chat pause and registrations pause; nonadmin attempts same actions.
- **Expected:** Hide affects discovery but does not promise private media or end existing room; block applies to exact watch ID. Flags/tools server-backed and audited. Unavailable tools remain open requirements.
- **Evidence:** Feed/map/room clips, flag state and audit rows.
- **Replaces / links:** R02/P05.

## C06 — Authority/concurrency regression

- **Prerequisites / time:** Disposable DB only; exact tested migrations. 10–15 min engineer.
- **Roles/devices:** Local fixtures, two simultaneous clients.
- **Steps:** Run the three committed concurrency scenarios: competing different watches, same watch and expired-lease replacement. Repeat stale end after replacement and outsider authority probes from existing SQL suite.
- **Expected:** One authorized current session; stale generations cannot affect replacement; no privilege escalation. D8 remains outside these guarantees.
- **Evidence:** Fresh command/exit/count logs, identity and cleanup confirmation.
- **Replaces / links:** P02/P04; session fencing.

## C07 — Counts and unrelated organization flows

- **Prerequisites / time:** Configured local fixtures; organization broadcast stays gated. 10–15 min.
- **Roles/devices:** Guest/viewer plus owner/nonmember/admin.
- **Steps:** Observe heartbeat counts on multiple tabs/device transitions. Exercise unrelated org venue/profile/invite/permission screens, main/branch application locations; attempt deferred org broadcasting.
- **Expected:** Counts follow intended identity rules; stranger denies; legitimate nonbroadcast org actions and exact venue coordinates preserved. Disabled broadcast remains disabled.
- **Evidence:** Count timeline and role/location matrix.
- **Replaces / links:** P06; org deferral.

## M01 — Android cold offline map and reboot

- **Prerequisites / time:** Installed exact diagnostic or acceptance candidate; no live session; known cache state. 12–15 min per phone.
- **Roles/devices:** A/B separately, en/ar.
- **Steps:** Before first launch turn internet off; complete guest flow and open map. Inspect all three city views and previously unvisited deep locations. Restart and reboot offline; repeat. Measure entry-to-map, not only splash.
- **Expected:** Bundled streets/water/buildings/labels available, no blank tiles. Offline venue freshness truthful. Proposed 2 s phone map-ready target measured, never borrowed from Windows.
- **Evidence:** Cold-start videos, timings, locale/OS, screenshot at each city.
- **Replaces / links:** A01/A02/A04/A09.

## M02 — Chrome complete Save and cold offline start

- **Prerequisites / time:** Correct stamped web build; origin initially reachable. 12–15 min.
- **Roles/devices:** C isolated browser profile.
- **Steps:** Open normal guest app/map, Save; record ready state/build. Switch Arabic, close all Chrome test windows, make origin and internet unavailable, reopen exact origin in same profile. Complete guest path and inspect avatars/logo, joined Arabic map labels, both language styles and credits.
- **Expected:** Ready only after full app/font/image/map save. Cold shell and map actually work; private backend remains unreachable with truthful saved status. Never-saved fresh origin offline is explicitly unavailable.
- **Evidence:** Cache identity/file inventory without user data, network from-service-worker log, cold-start clip and Arabic screenshots.
- **Replaces / links:** A03/A04/A09/A13.

## M03 — Failed update, re-save and eviction

- **Prerequisites / time:** M02 prepared old copy; separate build with unchanged map but new app ID. 20 min engineer.
- **Roles/devices:** C isolated profile; local test server.
- **Steps:** Load new app without saving: readiness must require Save. Inject failure during download, then specifically at final pointer Cache.put after downloads; old copy must remain intact. Restore network and re-save. Delete one required cached file to simulate eviction and reload; separately run existing corrupt/truncated/incompatible map fixtures and record those as automated evidence, with any device fault-fixture check NOT RUN unless an identified fixture artifact is supplied; Save again, cold-start offline.
- **Expected:** No mixed build, false ready or lost old copy on failure. Locks settle and failed generation removed. Eviction noticed; full Arabic/fonts/images retained after successful re-save.
- **Evidence:** Before/after pointer, required-file inventory, failure counters, screenshots and network log.
- **Replaces / links:** A05/A06; app-only identity and atomic promotion concerns.

## M04 — Worker restart, hanging origin and concurrent tabs

- **Prerequisites / time:** M02 ready; old/new build snapshots available. 15–20 min engineer.
- **Roles/devices:** Two C tabs in one isolated profile; local controlled server.
- **Steps:** Keep old tab open; save new build in another. Terminate/restart worker through test browser, exercise both tabs. Hang origin (connection accepted, no headers/body); cold navigation then cached fonts/JS. Try simultaneous Save/reset; close old tab, wait past the five-minute recent-pin grace and reopen site. Also Save on the very first claimed page and request not-yet-rendered images/fonts offline without a reload. Keep one tab repeatedly requesting cleanup while another navigates; separately use the deterministic reserved-client test fixture for the pre-commit window.
- **Expected:** Each page receives its own build; new page never falls back to old JS. Navigation fallback about 4 s plus rendering, cached assets prompt. Save failures bounded; no partial publication or removal of a live tab's copy; obsolete copies reclaimed on later cleanup after closure and the five-minute recent-pin grace. A navigation suspended beyond that grace may require reload; record it rather than inferring unlimited survival.
- **Evidence:** Per-tab build/file identity, lock/cache inventory and timing trace.
- **Replaces / links:** A05 plus integration worker/concurrency concerns.

## M05 — City scope and selected-card matrix

- **Prerequisites / time:** Permitted fixtures for three cities, adjacent town, unknown city, hidden, unverified, same-coordinate cluster. 25–35 min.
- **Roles/devices:** C at 320/360/384/412 dp; A/B; en/ar 1× and largest text.
- **Steps:** Compare city dropdown/search/markers; verify only known three-city records are included. Select every offline/video/audio card variant at each width/locale/scale; activate primary and Close. Zoom overview/detail and overlapping clusters. Refresh hide/unverify while selected.
- **Expected:** No overflow or inaccessible main action; targets ≥48 dp. Padding does not add nearby-town venues. Hidden/unverified/stale selection removed appropriately; exact legitimate coordinates retained; no saved data rewritten.
- **Evidence:** Populated-card matrix/screenshots, marker/search IDs, viewport and text scale.
- **Replaces / links:** A07/A08/A12/A14/A15.

## M06 — Pinned/unpinned details and application

- **Prerequisites / time:** Dedicated local forms; one pinned venue and one absent/0,0 pin. 15–20 min.
- **Roles/devices:** Streamer applicant/admin and viewer on A/C.
- **Steps:** Open card/live venue details/profile navigation. With no known user origin, check no invented distance. Unpinned venue offers no unusable directions. Pick exact main and branch coordinates online/offline; submit/approve and reload profile/map. Exercise every offered application city, including Ahsa/Jubail/Riyadh/Other; those applications remain valid but outside three-city map membership. Check organization reload with an approved public point and with no public point. Private branch records must remain private and unchanged.
- **Expected:** No 0,0 directions or fabricated origin/city/video. Exact coordinates and typed legitimate venue values survive; valid directions launch real coordinates. Unknown city is not guessed into three-city scope.
- **Evidence:** Before/submitted/approved coordinate strings, screenshots; no private address disclosure in shared logs.
- **Replaces / links:** A19; map regression; approval overlap.

## M07 — Coverage, outlines, movement and credit

- **Prerequisites / time:** Map available. 12–15 min.
- **Roles/devices:** A/C; offline en/ar.
- **Steps:** Inspect overview/city framing, min/max zoom, deep points in each city, panning edge and twist gestures. Read credits/licences offline. Check whether accurate official city outlines exist.
- **Expected:** No arbitrary polygon presented as official. Current accurate outlines are unmet; mark that requirement BLOCKED pending suitable licensed geometry or explicit scope decision. Required OSM/Protomaps attribution remains visible/readable.
- **Evidence:** Boundary/coverage notes, screenshots, source/licence decision.
- **Replaces / links:** A10/A11/A13/A16.

## A01 — Arabic, text and assistive access

- **Prerequisites / time:** Selected venue and supported live session; smoke passed. 20–25 min.
- **Roles/devices:** A/B TalkBack; C keyboard/zoom; en/ar.
- **Steps:** Traverse main action, Close, End/Back, settings, chat read-only notices and credits. Use largest OS text, short landscape and 320 dp Chrome; record actual app scaling (current root clamps at 1.3; widget tests force 2×). Check joined Arabic and focus order.
- **Expected:** Reachable named targets and readable content; no clipped failure text or forced keyboard. Any practical accessibility barrier FAILs even if a widget assertion passed. Root scaling limit remains a documented limitation.
- **Evidence:** TalkBack/keyboard clip, focus order, actual scale/viewport and screenshots.
- **Replaces / links:** A08/A09/A12; F08–F10.

## A02 — Permissions, cancellation and platform limits

- **Prerequisites / time:** Diagnostic UI; configured live only for authorized start cases. 12–15 min.
- **Roles/devices:** A/B sender; C browser.
- **Steps:** Deny camera/mic, cancel key/setup, Back during loading, failed preparation and reconnect. Check unsupported browsers/desktop sender modes; confirm release build requires real signing and debug callback matches test package.
- **Expected:** Graceful exit/recovery, no camera/mic/wakelock leak or stuck modal; unsupported mode clearly disabled. Never copy keys into evidence.
- **Evidence:** Permission/exit matrix, indicators and redacted manifest identity.
- **Replaces / links:** R10/R11; supported-platform limits.

## I01 — Repeated map/player navigation and memory

- **Prerequisites / time:** W06 and S07 baseline; real stream. 20–25 min.
- **Roles/devices:** B/C viewers; A live sender.
- **Steps:** Run 20 map→room→map cycles, including deep zoom, language change and playback pause/mute. Capture memory before, peak and after idle; End while map visible.
- **Expected:** Viewport/selection maintained where valid; one player, no accumulated audio/camera/surfaces or steadily growing unreleased memory. End removes live state without app restart.
- **Evidence:** Memory timeline, route/playback clip and ended map/feed screenshot.
- **Replaces / links:** A17/A18; F04/R09.

## I02 — Moderation/revocation across recovery

- **Prerequisites / time:** S03/C05 passed. 15–20 min.
- **Roles/devices:** A sender; B viewer; C admin.
- **Steps:** During independent sender/viewer outages apply Hide then Show, transfer, ban/device revoke and End in separate fresh sessions. Return to map/feed while reconnecting, then restore networks.
- **Expected:** Latest authority controls recovery; discovery hide is distinct from terminal End. No revoked publisher restart, stale room or returned LIVE badge.
- **Evidence:** Ordered action/session timeline and all three surfaces.
- **Replaces / links:** R01/R02/R03/R12; P04/P05.

## I03 — Application/profile map and channel integration

- **Prerequisites / time:** Dedicated local accounts; channel test data; M06. 12–15 min.
- **Roles/devices:** Applicant, approving admin and viewer.
- **Steps:** Apply with valid channel and exact optional pin; use map picker, return, rotate/localize, submit, approve and reload. Repeat without pin and with conflicting channel handle.
- **Expected:** Map upgrade does not bypass streaming channel checks. No invented pin/city/sample video; legitimate existing city/channel/location retained. Unpinned UI honest.
- **Evidence:** Redacted form/result comparison and coordinate equality.
- **Replaces / links:** F11/F12; A19; shared apply/provider files.

## I04 — Final candidate identity and preservation

- **Prerequisites / time:** All executable checks and critic complete. 5–10 min engineer.
- **Roles/devices:** Integrator/owner.
- **Steps:** Confirm final source equals tested source; compare artifact/config hashes and backend identity, source branches, owner file hashes and stash IDs. Record local master merge state. Check every remaining blocker and result is explicit.
- **Expected:** No inherited PASS, unreviewed source repair, secret in logs or overwritten owner work. P5/P6/P6S remain separate until required evidence is accepted.
- **Evidence:** identity.json, PRESERVATION_CHECK.json, critic and source-tree comparison.
- **Replaces / links:** Final handoff.

## Historical mapping and changed behavior

The IDs F01–F12, R01–R12 and P01–P06 refer to the [September 26 streaming script](../../2026-09-26/p6s-wave4v2/WAVE4V2_RETEST_SCRIPT.md). A01–A19 refer to the [map acceptance matrix](../../2026-09-26/p5-tricity-map-upgrade/ACCEPTANCE_RESULTS.md). Camera follow-up refers to the [September 27 camera script](../p6s-camera-landscape/WAVE4V2_RETEST_SCRIPT.md); its C01–C10 map to W02/W03/W05/S01/S02/S04/S10 as detailed below. Main-checkout E4 owner results remain preserved at their original path in the audit inputs.

| Historical set / case | Consolidated cases |
|---|---|
| Camera C01/C02 | W02, S01, S07 |
| Camera C03/C04/C05/C06 | W03, S02, S01 |
| Camera C07/C08 | W05, A01/A02 |
| Camera C09/C10 | S03/S04/S10 |
| Streaming F01/F02 | W05, S04 |
| Streaming F03/F04/F05/F06 | S03/S04, I02 |
| Streaming F07/F08/F09/F10 | W02/W03, S01/S02, A01 |
| Streaming F11/F12 | S06, I03 |
| Streaming R01/R02/R03/R04 | S04, C05, I02 |
| Streaming R05/R06/R07/R08/R09 | S07/S05/S08/S10 |
| Streaming R10/R11/R12 | S09/A02/C04 |
| P6 P01/P02/P03/P04/P05/P06 | C01/C02/C03/C04/C05/C07; concurrency C06 |
| Map A01/A02/A03 | M01/M02 |
| Map A04/A05/A06/A07 | M03/M04 (corruption/eviction fixture evidence recorded separately) |
| Map A08/A09/A10 | M05/M07, W04, A01 |
| Map A11/A12/A13 | M07/A01/M02 |
| Map A14/A15/A16 | M05/C05/I02; backend state and cluster fixtures |
| Map A17/A18/A19 | W06/I01, M06/I03 |

Repeated End, rotation, chat and navigation actions were consolidated into smoke plus explicit deeper state/race cases. Card layout/location/scope require W04/M05/M06/I03 again. Cache identity/publication/cleanup require M02–M04 again even though the map bytes did not change. Integrated streaming and map lifecycle require W05/W06/I01/I02 again. Changed label/callback/build packaging requires W00 again. Old passes never waive these retests.

Use PASS only with evidence for every required device/role in that row. **FAIL** means observed deviation; **BLOCKED** means a prerequisite is missing, named in the result; **NOT RUN** means no new execution; **APPROVED DEFERRAL** requires an exact owner decision and applies only to that capability, not adjacent safety checks. Keep per-device subresults instead of hiding one failure in a combined PASS. A score of 8+ does not establish physical acceptance.


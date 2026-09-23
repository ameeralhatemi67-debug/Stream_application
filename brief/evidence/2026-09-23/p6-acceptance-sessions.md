# P6 safety acceptance attempt, 2026-09-23 (Claude Opus 5.5)

Branch `p6-acceptance` from `master` `f581329`. Local disposable stack `P6_accept_disposable` only; stopped with `backup=false` afterwards. No linked or production project, push or deploy. **P6 is not accepted.** Some required UI checks could not be completed (see "Not done").

## Method

- A release web build (`flutter build web`) pointed at the local stack (`127.0.0.1:54321`). Keys were passed only as build flags and never written to the repo.
- Four real Auth users were created in the local GoTrue: Viewer A, Viewer B, Master Admin P6 (`master_admin` role) and Caster P6 (verified streamer). Each signed in through GoTrue's password grant, which issues real JWTs with real `auth.sessions` rows. The app only offers Google OAuth, and a local stack has no Google credentials, so these sessions were placed in each origin's `localStorage` (`sb-127-auth-token`). The app then restored and refreshed them as usual.
- Separate browser origins stood in for separate devices, each with its own storage: `127.0.0.1:8081` (Viewer A, device 1), `:8082` (Viewer B), `:8083` (Master Admin), `:8084` (Viewer A, device 2: a second password grant, so a different session id). The UI was driven through Chrome.
- The caster went live through its own session's RPCs: `claim_broadcaster_device`, `set_live_state` and a `device_heartbeat` every 20 seconds. No phone or RTMP broadcast was involved.

Evidence types below: **UI** = seen in the running app with real sessions; **API** = a REST/RPC call made with a real user's session, with database read-back; **SQL** / **widget** = automated tests.

## Results

| Check | Evidence | Result |
|---|---|---|
| B's chat reaches A in real time | UI | PASS |
| A blocks B from the message action sheet | UI + DB row `Viewer A blocks Viewer B` | PASS; B's message disappears and the toast appears |
| B's new message while A's room is open | UI | PASS; hidden for A, shown for B |
| A's second device (separate session) loads the room | UI | PASS; B's history hidden on first load |
| A's second device: Settings › Blocked accounts lists "Viewer B" and Unblock works | UI + DB (0 rows) | PASS |
| A's first device re-enters the room after the unblock | UI | PASS; B's messages visible again (sync on refresh, as documented) |
| Master pauses platform chat with a reason | UI (switch Off, toast) + DB + audit `appFlagChanged` by *Master Admin P6* with `previous/enabled` | PASS |
| A viewer entering while paused | UI: "Chat is paused across the platform right now." | PASS |
| Insert while paused, as Viewer B and as the stream owner | API: 403 `42501 Feature temporarily disabled` for both | PASS |
| Master resumes chat | UI + DB + audit | PASS |
| A room left open while paused, after chat is resumed | UI | **FAIL → fixed** (defect 2) |
| Viewer tries to change a switch | API: 403 `Not permitted` | PASS |
| Master pauses sign-ups; new `/auth/v1/signup` | API: 500 "Database error saving new user"; audit row | PASS |
| Existing user signs in while sign-ups are paused | API: 200 | PASS |
| Master reopens sign-ups; new sign-up | API: 200; audit row | PASS |
| Admin Safety › Live now | UI: "1 live · 1 watching", Caster P6 video | PASS |
| Viewer tries force end | API: 403 | PASS |
| Master force-ends | API: 204, profile not live, audit `streamForceEnded` by *Master Admin P6* with stream and target | PASS |
| Master removes from feed (caster re-claimed device and went live) | API: 204, not live, audit `streamRemovedFromFeed` | PASS |
| Caster retries the removed video / a new video | API: 403 "Stream removed by moderation" / 204 | PASS |

Audit trail after the run: 4 × `appFlagChanged`, `streamForceEnded` and `streamRemovedFromFeed`, all attributed to *Master Admin P6* with the typed reasons.

## Defects found and fixed

1. **Room history rendered upside down.** `postgrest` `order()` defaults to descending, so `_loadRecentMessages` received newest-first rows and the reversed list showed the oldest message at the bottom, the reverse of live-appended messages. Fix: explicitly fetch the newest 100 with `ascending: false`, then `LiveChatController.chronological` sorts them oldest first. Test: `room history is shown oldest first, like live inserts`.
2. **An open room stayed paused after chat was resumed.** The paused composer has no send action, and `app_flags` is not on Realtime, so nothing re-read the flag until re-entry or app resume. Fix: while chat is paused, the controller re-reads `app_flags` every 30 seconds and stops once it is on again. Test: `a paused room notices chat coming back without a reload`.
3. **API roles held TRUNCATE, TRIGGER and REFERENCES on 27 of 29 tables** (review finding #7). Fixed by migration `20260923140000` with catalog assertion R3d and truncate tests. See `p6-keyword-audit-migration-review.md`.

Verification after the fixes: full Flutter `+506: All tests passed!` (504 + 2 new); `flutter analyze` 0 issues; fresh `P6_accept_disposable` bootstrap through `20260923140000`, then `supabase test db` `Files=15, Tests=283, Result: PASS`; gates exit 0, G6=552 unchanged, all others PASS or INFO. Both UI fixes are covered by the tests above. Their on-screen confirmation is owner steps 1 and 2, because the Chrome window became hidden and I did not click blind (see "Not done").

## Other findings, not fixed (outside P6 safety)

- **Admin Overview KPIs show sample numbers.** `ViewerAnalyticsModel.createDefault()` in `project/lib/features/admin/models/viewer_analytics_model.dart` hard-codes 1420 guest sessions, 185 users, 365 RSVPs, 342 live viewers and so on. The Overview's "Active Viewers 1605" and "Auditorium Seats 365" are these values, and the fresh disposable DB's `platform_analytics` row contained them too. This is a truthfulness defect of the P2 kind; it needs real KPI sources.
- **Direct `/#/admin` deep link redirects to `/feed`** because the router evaluates it before `is_admin_tier()` resolves. The sidebar entry works. Minor.
- `loadOrgVenues` and `loadOrgSpeakers` also use a bare `.order('created_at')` (descending). The intended order is unknown; left unchanged.
- The message action sheet opens only by long-press. On desktop web, that means holding the mouse button for 0.5 seconds. It is not discoverable for mouse users.

## Not done (needs the owner)

After the chat-switch checks, Chrome's window reported `document.visibilityState = hidden` for every tab and every new window, probably because the display was locked or another window was in front. Flutter stops painting and screenshots time out. I stopped UI driving there rather than click without seeing. The following were therefore not observed in the UI: the Welcome "sign-ups paused" notice and disabled Sign up; ending or removing through the Safety buttons (only through the API); the audit-log and keyword views showing the new rows; and the two fixes on screen. Physical Android devices were not used.

## Owner steps

Use two real Google accounts (A and B) plus a Master Admin account, on two devices or two browsers, against a **local or staging** stack that has `20260923130000` and `20260923140000` applied. Do not use production until you have decided on the migrations.

1. **Blocks across devices.** A and B join the same live room; B sends "one". A long-presses (or holds the mouse on) B's message and chooses Block User. *Expected:* the message disappears and the toast says so; B's next message never appears for A. On A's second device, open Settings › Blocked accounts. *Expected:* B is listed by name. Tap Unblock. *Expected:* the toast appears and the list is empty. On A's first device, leave and re-enter the room, or switch away from the app and back. *Expected:* B's messages are visible, **oldest at the top**.
2. **Chat pause.** Master Admin: Admin Hub › Safety › Platform switches › turn off "Chat across the platform" with a reason. *Expected (corrected 2026-09-23):* a room that was already open with chat on does **not** change by itself; polling runs only while paused. When A next sends, the message fails with "Chat is paused across the platform right now." and only Discard (no retry), and the composer switches to the paused notice. A room entered after the pause shows the notice at once, and so does returning to the app. Turn chat back on. *Expected:* A's paused room gets its composer back within about 30 seconds **without reloading**.
3. **Sign-ups pause.** Turn off "New account sign-ups" with a reason. On a signed-out browser, open Welcome. *Expected:* the paused notice is shown, Sign up is disabled and Log in still works for an existing account. A brand-new Google account's sign-in fails. Turn it back on.
4. **Live actions.** A broadcaster goes live from the phone. Master Admin: Safety › Live now shows them with a viewer count. Choose End broadcast and give a reason. *Expected:* the "ended in the app" toast appears, the row disappears and the broadcaster's app leaves the live state; the YouTube stream itself keeps running (documented limit). Go live again, then choose Remove from feed. *Expected:* the same video ID cannot go live again in the app; a new video ID can.
5. **Audit.** Safety › Audit log. *Expected:* each action above appears with your name, the reason and the time; the filter narrows by action. Safety › Chat keywords: add, change and remove a word, then check that three keyword entries appear in the audit log.

Record pass or fail for each step in `brief/LEDGER.md`. P6 can be marked accepted only once steps 1–5 pass.

## Correction and guided session, 2026-09-23 (later)

**Instruction mismatch corrected.** The earlier step 2 said an open room with chat on would show the pause within about 30 seconds. The code polls `app_flags` only while a room is already paused. An enabled open room learns of a pause from a refused send, re-entry or app resume. I kept the implementation and corrected the step. Evidence:
- Widget test `an open room with chat on does not poll app_flags`: no fetches while enabled; the composer changes only after the refresh that a refused send performs.
- On screen (browser session, Viewer A on `:8081`): chat was paused through the Master Admin's real session at 13:48:11 UTC. After 40 seconds the open room still showed the normal composer. Sending "Sent while paused" produced the failed message with the reason and Discard only, and the composer switched to the paused notice.

**Both earlier fixes confirmed on screen** (browser session): history loaded oldest first ("order check one" above "order check three"); after chat resumed at 13:58:29 UTC, the paused room got its composer back without a reload.

**New defect fixed:** the refused-send toast read "Exception: Chat is paused …". The controller now throws `ChatSendException`, whose text is the reason alone, for every refused send. Test: `a refused send reads as the reason alone`.

Browser sessions here are separate origins in one desktop Chrome, not separate physical devices. Physical Android checks (a phone broadcaster reacting to force end, two phones with real Google accounts) remain separate owner work.

## Guided checklist for the prepared local environment

Disposable stack `P6_accept_disposable` with both migrations; test users Viewer A, Viewer B, Master Admin P6 and Caster P6 (live on `P6acceptVid`, heartbeat running). Open each link in Chrome; each port keeps its own sign-in.

| Session | Link |
|---|---|
| Viewer A, browser session 1 | `http://127.0.0.1:8081/p6-login.html?u=viewerA` |
| Viewer B | `http://127.0.0.1:8082/p6-login.html?u=viewerB` |
| Master Admin | `http://127.0.0.1:8083/p6-login.html?u=master&to=/%23/feed`, then the sidebar **Admin Hub** (a direct `/#/admin` link bounces before the role loads) |
| Viewer A, browser session 2 | `http://127.0.0.1:8084/p6-login.html?u=viewerA2` |
| Signed-out guest | `http://127.0.0.1:8085/#/welcome` |

G1. **Sign-ups notice.** Master: Safety › Platform switches › turn off "New account sign-ups" with a reason. Guest tab: reload Welcome. *Expected:* the paused notice, Sign up disabled, Log in enabled. Turn it back on and reload. *Expected:* the notice is gone.
G2. **End broadcast (UI).** Master: Safety › Live now shows "Caster P6". Choose End broadcast, give a reason and confirm. *Expected:* the "Broadcast ended in the app." toast appears and the list becomes empty. Put the caster back on air: `! node "C:/Users/User/.claude/jobs/679cf4c4/tmp/caster_loop.mjs" relive P6acceptVid`, then pull to refresh or reopen Live now.
G3. **Remove from feed (UI).** Choose Remove from feed with a reason. *Expected:* the "Stream removed from the feed." toast. Then run `! node "C:/Users/User/.claude/jobs/679cf4c4/tmp/caster_loop.mjs" relive P6acceptVid`. *Expected:* the output shows `set_live_state 403 … Stream removed by moderation`. Running it with `relive P6acceptV3` is expected to show 204 and the caster is listed again.
G4. **Audit log (UI).** Safety › Audit log. *Expected:* entries for the switch changes, the end and the removal, each with "By Master Admin P6" and your reasons; the filter narrows to one action.
G5. **Keywords (UI).** Safety › Chat keywords: add a word, change it to "Anywhere in text", remove it. *Expected:* three matching entries in the audit log. Viewer B sending that word while it is listed is refused.
G6. **Optional repeat of blocks:** Viewer A blocks B in session 1, checks session 2's Blocked accounts list, unblocks there, then re-enters the room in session 1.

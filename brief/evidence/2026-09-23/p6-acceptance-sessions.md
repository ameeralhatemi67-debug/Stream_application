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
2. **Chat pause.** Master Admin: Admin Hub › Safety › Platform switches › turn off "Chat across the platform" with a reason. *Expected:* A's open room shows "Chat is paused across the platform right now." within about 30 seconds, or at once on re-entry. Turn it back on. *Expected:* A's open room gets its composer back within about 30 seconds **without reloading**.
3. **Sign-ups pause.** Turn off "New account sign-ups" with a reason. On a signed-out browser, open Welcome. *Expected:* the paused notice is shown, Sign up is disabled and Log in still works for an existing account. A brand-new Google account's sign-in fails. Turn it back on.
4. **Live actions.** A broadcaster goes live from the phone. Master Admin: Safety › Live now shows them with a viewer count. Choose End broadcast and give a reason. *Expected:* the "ended in the app" toast appears, the row disappears and the broadcaster's app leaves the live state; the YouTube stream itself keeps running (documented limit). Go live again, then choose Remove from feed. *Expected:* the same video ID cannot go live again in the app; a new video ID can.
5. **Audit.** Safety › Audit log. *Expected:* each action above appears with your name, the reason and the time; the filter narrows by action. Safety › Chat keywords: add, change and remove a word, then check that three keyword entries appear in the audit log.

Record pass or fail for each step in `brief/LEDGER.md`. P6 can be marked accepted only once steps 1–5 pass.

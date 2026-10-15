# 02 — Testing plan before the Google Play launch

Written 2026-10-10. You have already tested:
- user streaming
- user settings
- chat
- viewer counts
- UI
- the map
- admin features

This plan covers what is **left**:

- **A** Organizations
- **B** Organization admin features
- **C** Reminders
- **D** Notifications
- **E** Release-build checks (the signed Play build behaves differently from a debug build)
- **F** The 12-tester closed test

Owner setup is in [01_OWNER_STEPS.md](01_OWNER_STEPS.md). Claude's work is in [03_CLAUDE_REMAINING_WORK.md](03_CLAUDE_REMAINING_WORK.md).

---

## Before you start

### What must be ready

| Needed for | Ready when |
|---|---|
| A, B (organizations) | YouTube OAuth secrets set and the org-events key added (01 §5). Claude has deployed `dispatch-organization-events` and its job (03 §2). |
| C, D (reminders, push) | Firebase project set up (01 §4). Claude has scheduled the reminder job (03 §2). The app build includes the Firebase values. |
| E (release build) | Signing key exists (01 §6). Claude has built the signed `.aab`, and it's installed from the Play **internal testing** link (01 §8). |

### Accounts (use different Google accounts, not one account on two devices)

| Name in this plan | Who | Used for |
|---|---|---|
| **ADMIN** | your Master Admin account | pilots, switches, approvals |
| **OWNER** | owns the test organization and the YouTube channel `@amiralhatime4831` | connects the channel, invites people |
| **PRES1**, **PRES2**, **PRES3** | three presenters (can be friends' accounts) | run the 3 simultaneous shows |
| **VIEWER** | a normal signed-in viewer who follows the organization | sees shows, gets pushes |
| **OUTSIDER** | an account that is not a member | must be refused |
| **GUEST** | not signed in | read-only checks |

### Devices
- 2 Android phones (for presenters and senders).
- OBS on a laptop (third sender).
- Chrome on desktop (management and viewing).

### How to record results
For each row, write **PASS**, **FAIL** or **BLOCKED**, the build (version + date), the device, and a screenshot for every FAIL. Never screenshot a stream key or RTMP URL. Send the list of FAILs to Claude in one message.

---

## A. Organizations

### A1. Turning organizations on for the pilot

| # | Steps | Expected |
|---|---|---|
| A1.1 | As ADMIN: Admin → Safety. Check **Accept new organization applications** is **off**. As OUTSIDER, try to apply as an organization. | The application is refused, with a clear message. |
| A1.2 | ADMIN turns **Accept new organization applications** on. OWNER applies as an organization (fill every step). | The application is saved and shows in the verification queue. |
| A1.3 | ADMIN approves it in the verification queue, then turns the switch **off** again. | OWNER sees the organization approved. New organization applications are refused again. |
| A1.4 | ADMIN: Safety → **Organization pilots** → enable this organization. | The organization shows as enabled. Other organizations stay disabled. |
| A1.5 | Check that `organizations_v1_enabled` matches decision 0 in 01 (off for the public launch). Re-check A1.4 still works when it's off. | Only the pilot organization can schedule and start shows. |

### A2. Connecting the organization's YouTube channel

| # | Steps | Expected |
|---|---|---|
| A2.1 | OWNER: Settings → **Organizations** → the organization → setup checklist → **YouTube connections → Connect YouTube**. Pick the Google account that owns `@amiralhatime4831`. | Google consent opens, then you return to the app. The channel title and identity shown are correct. |
| A2.2 | Start a consent, then cancel it on the Google page. | You return to the app with a "cancelled" message. Nothing is connected. |
| A2.3 | Start two consents and finish the **older** one. | The older one is refused. Only the newest attempt counts. |
| A2.4 | Pick a Google account that has **no** channel or a different channel. | Clear refusal. No wrong channel is connected. |
| A2.5 | Phone and web: repeat A2.1 on both. | Works on both; the web returns to `/#/channel-connected`. |

### A3. Invitations, roles and membership

| # | Steps | Expected |
|---|---|---|
| A3.1 | OWNER invites PRES1 as **co-owner**, PRES2 as **manager**, PRES3 as **moderator** (by email/handle). | Each gets an invitation (in-app inbox, plus push once D is set up). |
| A3.2 | PRES1 opens the invitation link signed in as **another** account. | Explained as the wrong account. Can't accept. |
| A3.3 | PRES1 accepts with the right account. Then try to open the same link again. | Accepted once. The second use is refused (single-use). |
| A3.4 | An invitation older than 7 days (or ask Claude to set one expired on the test backend). | Shown as expired. Can't accept. |
| A3.5 | OWNER withdraws a pending invitation. | The link stops working. |
| A3.6 | OUTSIDER sends a **join request**. OWNER approves one, declines another. | Both outcomes shown to the requester. |
| A3.7 | Check what each role can do in the org management screen: co-owner, manager, moderator. | The moderator can only moderate chat. The manager can't change the owner or transfer. Nobody gets platform admin powers. |
| A3.8 | OWNER gives PRES1 and PRES2 **video** broadcasting grants and PRES3 an **audio-only** grant. | Grants shown on each member. PRES3 can't start video. |
| A3.9 | OWNER removes (revokes) PRES3 from the organization. | PRES3 loses access immediately (after a refresh at most). |
| A3.10 | Do A3.1–A3.9 in **Arabic** on a narrow phone too. | No cut-off text. Correct RTL. |

### A4. Scheduling shows (the `/shows` screen)

| # | Steps | Expected |
|---|---|---|
| A4.1 | OWNER schedules a show for PRES1: Riyadh time, default 1 hour. | The show appears, and PRES1 gets an assignment. |
| A4.2 | PRES1 **accepts**. PRES2 is assigned another show and **declines**. | Status updates for the owner on both. |
| A4.3 | OWNER edits a show's time, then cancels another. | Presenters see the change or cancellation. |
| A4.4 | A weekly show: check that the next 4 weeks of occurrences exist. | Four weeks are visible, at the correct Riyadh times. |
| A4.5 | Change the phone's time zone to a non-Saudi zone and open shows. | Times are still clearly Riyadh time. |
| A4.6 | OUTSIDER opens a show link. | Refused, with an explanation. |

### A5. Going live as the organization (the main pilot)

| # | Steps | Expected |
|---|---|---|
| A5.1 | PRES1 on **Android**: open the accepted show → studio → confirm the channel → camera preview → Go live. | YouTube Studio shows a live broadcast on `@amiralhatime4831`. In the app it's LIVE only after the server confirms it. |
| A5.2 | PRES2 on the **second Android phone**: same for its show, at the same time. | A second, separate live broadcast. |
| A5.3 | PRES3's show (or the owner) from **OBS** on the laptop, using the ingest the studio shows. | A third simultaneous broadcast. Close the management tab: OBS keeps streaming. |
| A5.4 | Try a **4th** simultaneous show. | Refused (maximum 3). |
| A5.5 | VIEWER opens each of the 3 shows. | Each room plays **its own** video (check the content differs), with its own chat and viewer count. |
| A5.6 | Chat in show 1. Check it does **not** appear in show 2 or 3. | Chats are separate. |
| A5.7 | The moderator (PRES3, if still a member) deletes a message and mutes VIEWER in show 1. | Works in show 1 only. |
| A5.8 | Lock the screen of phone 1 for 2 minutes, then unlock. | The stream continues. The notification is visible while locked. |
| A5.9 | Turn Wi-Fi off on phone 2 for 20 seconds, then on. | Reconnects, or shows a clear recovery state. No ghost LIVE. |
| A5.10 | OWNER revokes PRES2's grant while PRES2 is live. | PRES2's show ends cleanly. The viewer sees it ended. |
| A5.11 | End show 1 normally. End show 3 from OBS (stop streaming) without pressing End in the app. | Both end. The server completes the YouTube broadcast within a few minutes. No show stuck LIVE. |
| A5.12 | After the end: replay state on each show card. | Shows the processing/available replay honestly (YouTube decides). |
| A5.13 | A presenter on **two devices**: start on phone 1, then try to start on phone 2. | Conflict handled: one active broadcast per person. |
| A5.14 | Write down for the pilot record: 3 session IDs, 3 YouTube watch URLs, start/end times. | Kept as release evidence. No stream keys. |

### A6. Ownership transfer and the public profile

| # | Steps | Expected |
|---|---|---|
| A6.1 | OWNER proposes transfer to PRES1 **while a show is live**. | Refused: no active shows allowed. |
| A6.2 | With no live shows: propose → PRES1 sees the banner → **withdraw**. | Proposal cancelled on both sides. |
| A6.3 | Propose again → PRES1 accepts. | PRES1 is the owner. The channel connection is fenced: PRES1 must **reconnect** YouTube before any show can start. |
| A6.4 | Disconnect the channel while a show is preparing or live. | Refused until all shows finish. |
| A6.5 | GUEST and VIEWER open the organization's public profile. | Real info only: name, logo, venue/branches, roster, live/upcoming. Nothing private shown. |

---

## B. Organization admin features (platform admin side)

| # | Steps | Expected |
|---|---|---|
| B1 | ADMIN: verification queue. Approve an individual broadcaster and an organization broadcaster separately. | Personal and organization approval are independent. |
| B2 | ADMIN: Safety → **Organization pilots**. Disable the pilot organization while it has a scheduled (not live) show. | New starts blocked with a clear message. Ending and recovery still work. |
| B3 | ADMIN: Safety → live list. Force-end one organization show; remove one from the feed. | The sender stops. Viewers see it ended. The card is gone from the feed. |
| B4 | ADMIN: Chat Moderation tab. A report from an organization show's chat appears; delete, mute, dismiss. | Works and is audited. |
| B5 | ADMIN: audit log. Filter by actor, action and date for the actions in A and B. | Every organization action is listed: invites, grants, revocations, transfer, pilot changes, force-end. |
| B6 | A plain **Admin** (not Master Admin) tries Organization pilots and the two switches. | Not allowed (Master Admin only). |
| B7 | OWNER and the co-owner open `/org-admin`. VIEWER and OUTSIDER try the same URL. | The owner and co-owner see only their organization. Others are redirected or refused. |
| B8 | ADMIN user directory: open OWNER and PRES1. | Organization memberships and roles shown correctly. |
| B9 | ADMIN tries to delete OWNER's account while they own an organization. | Refused or explained (organization and storage owner protection). |

---

## C. Reminders (planned/upcoming streams)

Needs Firebase + the reminder job. Use an approved **individual** broadcaster (call them STREAMER) plus VIEWER on two devices.

| # | Steps | Expected |
|---|---|---|
| C1 | STREAMER adds 2 weekly series (different days/times) and 1 one-time special, then edits one and deletes one. | Saved. The second device sees the same order, colours and tags. No past one-time events shown. |
| C2 | A rejected or revoked broadcaster tries to manage schedules. | Refused. |
| C3 | Browse Upcoming in English and Arabic, on a narrow phone and a laptop, with large text. | Readable, no overflow. Long-press share gives the real title and Saudi time. |
| C4 | GUEST taps the reminder bell. | Asked to sign in. |
| C5 | VIEWER on phone + Chrome: turn on a **channel** reminder and a **card** reminder separately. Set the lead time to 5, then 30 minutes. | Exactly **one** alert per occurrence, at the chosen lead time, on each device. |
| C6 | A planned stream at an awkward hour (for example 3 a.m. Saudi time). | The alert still arrives on time. |
| C7 | VIEWER denies the notification permission. | The app explains how to enable it. No crash. |
| C8 | STREAMER changes or deletes a schedule **before** the alert time. | No stale alert arrives. |
| C9 | Phone offline at alert time, then online. | No duplicate alerts. |
| C10 | VIEWER signs out (or switches account) on one phone. | That phone stops getting this account's reminders. |
| C11 | A planned card when its time comes. | It **never** shows LIVE by itself. LIVE only comes from a real broadcast. |
| C12 | Saved/bookmarked upcoming item (from Discovery → Bookmarks → Upcoming). | Opens the channel's Upcoming tab. Separate from reminder on/off. |

---

## D. Notifications

| # | Steps | Expected |
|---|---|---|
| D1 | Fresh install on Android 13+. | The notification permission is asked at a sensible moment, not on first launch with no context. |
| D2 | In-app notification centre (bell). | Organization events appear once, unread count is correct, and reading on one device marks them read on the other. |
| D3 | Push for each organization event, sent to the right person: invitation, join request, assignment new/edited/cancelled, presenter reminder, grant changed, show started (to followers and leadership), show ended by the server, transfer proposed/withdrawn/completed. | Each arrives once, in the user's app language, and **tapping opens the right screen**. |
| D4 | Settings → notification preferences: turn off live pushes, then organization pushes. | Matching pushes stop. The in-app inbox still records them. |
| D5 | App in the foreground when a push arrives. | Sensible behaviour (in-app banner or silent update). No duplicate. |
| D6 | App fully closed (swiped away) when a push arrives. | Arrives. The tap opens the app at the right place. |
| D7 | Chrome (web push): allow notifications, close the tab, trigger an event. | The browser notification arrives. The click opens the right page. |
| D8 | Signed-out device. | Gets nothing for the old account. |
| D9 | Arabic device language. | Push text is in Arabic. |

---

## E. Release-build checks (from the Play internal-testing link)

The release build is minified and Play-signed, which can break things that worked in debug. Do this short pass on the **Play-installed** app, not on `flutter run`.

| # | Steps | Expected |
|---|---|---|
| E1 | Uninstall any old app. Install from the internal-testing link. Open it with no network, then with network. | The welcome screen; the offline notice when offline. No red error screen. |
| E2 | Google sign-in, sign-out, sign in again. | Works and returns to the app. |
| E3 | Connect YouTube (individual) → go live 2 minutes → end. | Works the same as in debug. |
| E4 | Feed, map, a live room, chat, VOD/archive, playlists. | All load real data. |
| E5 | Settings → Privacy → **export my data**. | Shows/downloads your data. Claude is expanding what it covers (03 §3); recheck after that. |
| E6 | Create a **throwaway** account → Settings → **Delete account**. | The account is gone: sign-in creates a fresh one, and the profile/avatar no longer appear anywhere. |
| E7 | The public **delete-account web page** (01 §1): submit a request for another throwaway account. | The request reaches you and you can act on it. |
| E8 | Privacy policy and terms links inside the app. | They open the final pages. |
| E9 | Deny camera, mic and location permissions, then use those features. | Clear explanations. No crash. |
| E10 | A tablet, or a phone in landscape. | Layout OK. Note: Android 16 ignores orientation locks on large screens, so check the live room on a tablet. |
| E11 | Leave a broadcast running 30+ minutes with the screen locked. | Doesn't stop. Phone not too hot. Report battery and heat. |
| E12 | Play Console → Android vitals / pre-launch report (after upload). | No crashes or ANRs reported. Send Claude anything listed. |

---

## F. Closed test (12 testers × 14 days, only for a new personal account)

1. Recruit at least **15** people (a buffer in case some drop) who will really use it: a mix of viewers and 2–3 broadcasters.
2. Send them the opt-in link. Each must accept it with the Google account their phone uses, then install from Play.
3. Give them a short task list: sign in, watch a live stream, chat, follow a channel, set a reminder, report a message, try Arabic.
4. Collect feedback in one place (a form or group). Note what you changed because of it; Google asks.
5. Keep at least 12 opted in for **14 days in a row** before applying for production (01 §8).

---

## Done means
- Every row in A–E is PASS, or is a FAIL that Claude fixed and you re-tested.
- Any item you choose to cut (for example organization broadcasting at launch) is switched off in the app and written down as a decision.

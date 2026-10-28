# Pre-test feature check — 2026-10-28

Before the 14-day Google Play closed test. Areas checked: notifications, reminders, saves, the admin's live-streaming tools, followers, and the admin's review of applications, of profile edits, and of application history.

How it was checked:
- **Code:** read the app and the migrations.
- **Hosted database:** read-only queries only.
- **Local test copy:** two behaviours were reproduced on the local copy of the database (`rec_new_20261027` in container `supabase_db_P6_accept_disposable`), each inside a transaction that was rolled back.

Nothing in the app or on hosted was changed. Each item is marked:
- **[tested]**: reproduced on the database copy.
- **[hosted]**: seen in hosted data.
- **[code]**: read in the code, not run.

## What hosted looks like today

- Applications: 8 (2 profile edits). 2 are pending. Review history has 5 events, all approvals.
- `f362af24` is a real applicant's application. It has been waiting since **2026-10-02**.
- `9279020a` belongs to a master admin who is already a verified streamer. On 2026-10-19 the application was put back to "pending" (see bug 1).
- Organizations: 0. `organizations_v1_enabled` and `organization_applications_open` are both off, so nothing about organizations is part of the test.
- Follows: 3 rows. Bookmarks: 0.
- Channel schedule reminders: 5. Reminder pushes sent: 3 (on 10-19, 10-22 and 10-26). Push devices registered: 1.
- `org_v1_events`: 5 "followed channel is live" rows (personal channels). **None was ever read.**
- Edge functions: `broadcast-control`, `reconcile-broadcasts`, `dispatch-upcoming-reminders`, `channel-authorization`. **`dispatch-organization-events` is not deployed.**
- Scheduled jobs: only `dispatch-upcoming-reminders` and `hadayah-reconcile-broadcasts`.
- Broadcast sessions: 17 completed, 30 ended, none stuck.

---

## 1. Notifications — partly works

**Works**
- **"Live now" alerts:** when someone goes live in the app, the server writes an alert for that channel's followers (`20261001160000_organization_v1_notifications.sql:100-110`). The bell loads these alerts and marks them read on the server (`app_provider.dart:1324-1371, 3411-3426`) **[code, hosted]**.
- **Lesson notifications:** these are real server rows. They cover a new lesson from a followed preacher or mosque, a cancellation, and a change of time or place. They appear in a separate Lessons inbox at `/lessons/me/notifications` **[code]**.

**Problems**
- **No push for "followed channel is live".** `dispatch-organization-events` and its scheduled job are not on hosted **[hosted]**. A follower only learns about a live if the app is open.
- **Old alerts drop out of the bell.** The bell throws away anything older than 12 hours, and the older list anything older than 6 hours (`app_provider.dart:3370-3374`). A follower who opens the app the next day never sees yesterday's alert. All 5 hosted alerts are still unread **[code, hosted]**.
- **The applicant is never told the decision.** "Your application was approved" and "rejected" go into the *admin's own* bell, not the applicant's (`app_provider.dart:5626-5642, 5676-5697`). The applicant only finds out by opening Settings **[code]**.
- **The unread badge counts every item twice.** Each item is copied into a second list with the same id, and the badge adds up both lists (`app_provider.dart:3364-3367` and `3477`) **[code]**.
- **A reminder that arrives while the app is open cannot be seen.** It only goes into the second list, which the notification centre does not show (`app_provider.dart:5178`, `notification_center_sheet.dart:61`). The badge goes up, but nothing is shown **[code]**.
- **Arabic users get English push text.** Every sign-in stores the device language as `'en'` (`app_provider.dart:657`) **[code]**.
- **Several Settings switches do nothing:**
  - The switches for watch milestones, new recordings and admin notes control notification types that are never created (`app_provider.dart:7060-7233`). The rate-limit slider and the mute list work only on the phone.
  - Preferences are never loaded back, so after a restart every switch shows "on" (`app_provider.dart:436`) **[code]**.
- **The phone only asks for notification permission when a schedule reminder is turned on** (`app_provider.dart:5307, 5325`). Someone who only follows channels never registers a phone for push **[code]**.
- **Personal lives get the wrong push text.** It reads "Live now — Your organization" because the organization name falls back to that text (`supabase/functions/_shared/org_event_text.ts:26, 64-66`) **[code]**.
- **Two separate inboxes:** the bell, and the Lessons inbox.

## 2. Reminders — channel reminders work; lesson reminders never arrive

**Works**
- **Channel and card reminders work end to end.** The bell on a channel or a card writes the reminder. A server job runs every minute, and Firebase sends "starts in N minutes". Tapping the notification opens the channel's Upcoming tab. If the schedule is edited, the reminder moves to the new time. If it is deleted, the reminder goes with it. On hosted, 3 reminder pushes were sent **[code, hosted]**.

**Problems**
- **Lesson reminders are stored but nothing ever sends them.** No function or scheduled job reads `lesson_reminders.remind_at` **[code, hosted]**. Yet the reminder sheet tells users "Reminders arrive as a notification in your inbox." (`en.json` `lessons.remind.note`). Tester tasks 3 and 12 in `brief/launch/06_CLOSED_TEST_TESTERS.md` depend on these reminders.
- **No "my reminders" list for channel and card reminders.** Lessons has one; channels do not **[code]**.
- **"Starts in N minutes" is still sent if the live already started early** **[code]**.
- **Not yet confirmed on a real phone:**
  - A push arriving while the app is fully closed.
  - The icon in the notification tray: there is no `default_notification_icon`, so it may show as a white square.

## 3. Saves (bookmarks) — works for signed-in users

**Works**
- **What can be saved:** recordings and upcoming announcements. Copies of the same video count as one save.
- **The Saved list:** opened from the bookmark icon on Discover. It has filters for All, Recordings and Upcoming, shows an empty state, offers retry if loading fails, and lets you remove an item.
- **On the server:** saves are stored there, and only the owner can read them. Data export includes them, and deleting the account removes them **[code]**.

**Problems**
- **Saved still shows recordings that are hidden, taken down or deleted.** They look playable but open into a YouTube error. The new hide and delete feature never touches `bookmarks` **[code]**.
- **Guests lose their saves** when they close the app or sign in, and nothing tells them **[code]**.
- **A saved upcoming item opens the wrong tab.** It opens the channel on Archive, not Upcoming (`bookmarks_sheet.dart:33`) **[code]**.
- **A whole channel, a live or a playlist cannot be saved.** This is by design.

## 4. Admin, live-streaming side — the core controls exist, but there is no health view

**Works** (Admin → Safety)
- **Live now:** a list of who is live, with the viewer count.
- **Force end:**
  - A reason is required, and the action is audited.
  - The server then ends the live on YouTube within about a minute, and the streamer's phone stops within about 20 seconds.
- **Ban:** the user directory has a permanent ban. The Banned Accounts tab offers 24 hours, 7 days, 30 days or permanent. Both can lift a ban, and the banned person sees a "banned" screen with the reason.
- **Recordings:** a recording can be taken down and restored, with a reason, from the channel page (long-press).
- **Chat moderation:** a reports queue, mute with a duration, ban, and delete. Inside a live, an admin can also delete and mute.
- **Audit log:** filtered by action, actor and date.

**Problems**
- **Nothing shows broadcast health.** Admins cannot see failed starts, stuck sessions or YouTube connections that have expired.
  - The streamer gets a vague "could not be confirmed" message rather than "reconnect YouTube".
  - With the Google app still in **Testing**, YouTube access expires every 7 days, so this will happen during the test.
  - A session stuck in "preparing" or "ending" blocks new lives, and no admin tool can clear it (`broadcast_control.ts:126`, `20261001111022…sql:241-243`).
  - Nothing is stuck right now **[code, hosted]**.
- **The force-end dialog text is wrong.** It says "This does not stop their stream on YouTube" (`en.json:1663`), but for lives started from the phone the server does end it on YouTube **[code]**.
- **Banned Accounts tab** **[code]**:
  - Any admin can ban a master admin. The database allows it (`20260920140000_policy_quality.sql:91-103`), and no check stops it.
  - Lifting a ban is not audited, and placing a ban is audited under the wrong label.
- **The admin's typed force-end reason never reaches the streamer.** The streamer sees a fixed message. The phone may even show an older session's reason (`my_broadcast_status.last_ended` orders by revision) **[code, likely]**.
- **"Live now" does not refresh by itself, and it has no Watch button, start time or health.**
- **No single "end and make the recording private" action,** and no admin list of recordings.
- **The Organizations tab is hard-coded to `org_dalilk_04`** (`admin_hub_screen.dart:380`). Organizations are off, so this is low priority.
- **Force end and Remove from feed show for accounts that are not live,** and then fail with a generic error (`admin_user_directory_view.dart:306-316`).

## 5. Followers — viewers can follow; streamers see nothing

**Works**
- **Following:** a viewer can follow a channel from the channel page, the live page or the website cards. Lessons can also follow preachers, series and mosques, with a "followed" page.
- **Privacy:** only you can read your own follows, both in the RLS policies and in the data export **[code]**.
- **Saved on the server:** follows are stored on hosted (3 rows) **[hosted]**.

**Problems**
- **Streamers have no follower count and no follower list,** and neither do organizations or admins:
  - `follower_count` exists but nothing ever fills it, so it is always 0 (`initial_schema:62,111`). It is shown nowhere.
  - The edit sheet defaults it to a made-up 1200, in memory only (`streamer_editor_sheet.dart:269`) **[code]**.
- **Viewers have no "channels I follow" list,** and there is no Following filter on Discover. You can only unfollow from each channel's page **[code]**.
- **A follow that fails is silent.** The button shows "Following", nothing is saved, and it is gone after a restart (`app_provider.dart:5132-5136`) **[code]**.
- **Following a channel you already follow on the server fails,** for example when the list did not load at sign-in.
  - The app sends an upsert that updates on conflict (`admin_database_service.dart:2907`), and `follows` has no update policy.
  - Reproduced on the local copy **[tested]**. The bookmark code already avoids this with `ignoreDuplicates: true`.
- **Hosted and the migration files do not match for follows.**
  - Hosted lets signed-in users UPDATE `follows`; the migration files do not grant that.
  - On a database built from the migrations (staging, or a rebuild) **every** follow would fail **[hosted, tested]**.
- **Guest follows are not merged at sign-in.** The Follow button also shows on your own channel.
- **Website only:** the follow button on a live card stores the live session's id instead of the channel's (`discovery_web_view.dart:676, 781`), so it never alerts anyone **[code]**.

## 6. Reading an application fully before approving — partly works

**Works**
- **The Inspect window shows:** name, title, email, phone, YouTube handle and link, category, tags, venue with coordinates, and the bio in both languages.
- **The application list:** filters for pending, approved and rejected, a search box, and select-several to approve or reject together.

**Problems**
- **Approve sits on the card itself,** so an application can be approved without opening it. Approve also has no "are you sure?" step **[code]**.
- **The banner can never be seen.** A solid dark box is drawn on top of it (`admin_hub_screen.dart:1903-1924`, colour `0xFF151D24`) **[code]**.
- **The Inspect window leaves things out:**
  - The name and title in the other language.
  - The institution, the city and the official website.
  - The submitted date and the reviewer.
  - The location is shown only as numbers: no map, and the YouTube link cannot be tapped **[code]**.
- **Some text is English-only:**
  - The approval progress text ("Stage 1 of 5: …", `app_provider.dart:5509-5645`).
  - "ORGANIZATION"/"INDIVIDUAL", "N/A", "Educational Academy", "Delete Application", "Select all pending" **[code]**.

## 7. Seeing old and new values on an edit — partly works

**How it works today** (`20260927030000_profile_edit_review.sql:94-138`):
- **Changes that wait for an admin:** email, phone, city, venue, map location and YouTube channel. Until then the approved version stays public. The admin sees each change as "old → new".
- **Changes that go public at once:** name, title, institution, bio, photo, banner, category, tags and website. **No admin review, and no record of the old value.**

**Problems**
- **A verified streamer can change their name or photo to anything, instantly, and the admin is never told.** This is the main gap for "seeing the old and new" **[code]**.
- **The venue comparison only shows the language the admin is using** (`admin_hub_screen.dart:1883, 1092`). An Arabic-only venue change shows as "no reviewed changes" to an admin working in English **[code]**.

## 8. Every version, current version, who approved — partly works

**Works**
- **Review history** (Applications → Action log) lists every approve, reject and remove, with who, when and why.
- **Each entry keeps a full copy** of the application at that moment, and of the version before it for edits.
- **The latest decision can be reversed,** with a reason (`20260929010000_application_review_history.sql`).

**Problems**
- **The log has no filters:** not by name, action, type, reviewer or date. It is one flat list, newest first.
- **It is not grouped by channel,** and nothing marks which version is the **current approved** one.
- **"Inspect" on a log entry shows only 5 fields** of the stored copy (`admin_hub_screen.dart:1080-1154`).
- **The application card does not show who approved it.**
- **Decisions made before 2026-09-29 are not in the log.**
- **The queue hides older applications from the same person** (`broadcaster_application_model.dart:17-50`).
- **Instant edits (section 7) are not versioned at all.**

---

## Bugs found in the application flow

1. **"Reapply" after a rejection is refused by the database. "Edit application" in Settings is refused for an approved streamer** **[tested]**.
   - **What the app does:** the form saves onto the *same* row (`streamer_apply_screen.dart:385` → `admin_database_service.dart:286` upsert). A normal user may only change a **pending** row (`20260921100000_policy_roles_and_per_command.sql:178-181`).
   - **What the user sees:** the error is caught and the user is shown "your form is preserved", which is the offline message.
   - **On the local copy:** `new row violates row-level security policy (USING expression)`.
   - **Admins are different:** the database allows the write, so the approved application is overwritten and put back to pending. That is what happened to `9279020a` on 2026-10-19 **[hosted]**.
   - **Side effect:** that account's profile editor now refuses to save ("Approved profile required"), and the application sits in the queue as a new one.
2. **Applicants who don't pick a photo or banner get the owner's personal photos.** The form starts with `assets/images/Amir_Alhatemi/amir_person_pic.jpg` and `amir_card_pic.jpg`, and those are saved and published (`streamer_apply_screen.dart:49-50, 336, 349`) **[code]**. The avatar is replaced by the Google picture when there is one; the banner never is.
3. **Editing the application rewrites the Arabic text.** It reloads only the English text and machine-translates the Arabic again, so hand-written Arabic is overwritten (`streamer_apply_screen.dart:98-121, 371`) **[code]**.

---

## Suggestions

### Fix before testers start
1. **Make reapply and Settings "Edit application" work.**
   - A rejected application should create a new pending row, linked to the old one, or go through a server function.
   - For an approved streamer, "Edit" should open the profile editor.
   - Show a real error instead of the offline text.
   - Ask the owner how to put `9279020a` back to approved.
2. **Remove the owner's photos as defaults.** Use a neutral placeholder and require a photo.
3. **Tell the applicant the decision:**
   - Write a server notification to the applicant on approve and reject, with a push.
   - Remove the toast that goes to the admin.
4. **Lesson reminders:**
   - Add a small server job that sends them, like `dispatch-upcoming-reminders`.
   - Or change the sheet's text and tester tasks 3 and 12 until it exists.
5. **Live alerts:**
   - Deploy `dispatch-organization-events` (it also sends personal-channel lives), with its scheduled job.
   - Fix the "Your organization" text.
   - Stop dropping unread alerts after 12 hours.
6. **Follow:**
   - `ignoreDuplicates: true`.
   - Roll back and show a message when a follow fails.
   - Add the missing grant or policy as a migration so hosted and the migration files match.
7. **Publish the Google sign-in app to "In production"** (carried over from the last check). Otherwise every broadcaster has to reconnect YouTube every 7 days, and nothing in the app tells them to.
8. **Review `f362af24`,** which has been waiting since 2026-10-02.

### Polish during the test
- **Badge:** count each item once, and keep reminders received in the inbox.
- **Push language:** send it in the user's language.
- **Saved:** hide or label recordings that are hidden or deleted, and open saved upcoming items on the Upcoming tab.
- **Admin text:** fix the force-end dialog, and translate the English-only admin strings.
- **Admin details view:** remove the box covering the banner, add the missing fields, a map pin and a link that opens the YouTube channel. Allow approving only from inside the details, with a confirmation.
- **Venue comparison:** compare both languages.
- **Banned Accounts:** protect master admins and audit lifting a ban, or route both through `admin_update_account`.
- **Settings:** hide the notification switches that do nothing, and load saved preferences at start.

### Worth adding next
- **One inbox stored on the server:** a single list for alerts, lessons, application decisions and admin notices. Each item has read state and 30 days of history, and push works for all of them.
- **Ask for notification permission at a clear moment:** after the first follow, or right after sign-in, with one sentence on why.
- **Following and My reminders pages** in the account area, with unfollow and cancel.
- **Follower count for streamers:**
  - A count kept up to date by the server, shown on the channel page.
  - "Followers over time" in the streamer's own area.
  - Never the identities, by default.
- **Admin review page, full screen:**
  - Old and new side by side, changes highlighted.
  - Map pin, a YouTube channel check and a short checklist.
  - Approve or reject at the bottom.
- **Channel history for admins:**
  - Every version of a streamer's or an organization's application as a timeline, with a "current" badge, who approved, when and why.
  - Compare any two versions.
  - Filters by status, type, reviewer, date and name.
- **Name, photo and bio changes:**
  - Either put them through review too.
  - Or keep "publish now" but log each change with old and new values, and let an admin revert it in one tap.
- **Admin "Live now" upgrade:**
  - Refreshes by itself, with start time, health and a Watch button.
  - "End and make the recording private" as one action.
  - A list of stuck sessions and of streamers whose YouTube connection has expired, with a "Reconnect YouTube" banner on the streamer's side.

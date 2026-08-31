---
type: checklist
tags:
  - streamer_app
  - testing
  - qa
  - checklist
  - roadmap
created: 2026-08-30
updated: 2026-08-30
status: active
---

# 🧪 Streamer App — Testing & QA Checklist

> [!info] Instructions for Obsidian
> Every item below is a native clickable Obsidian task `- [ ]`. Clicking any box will toggle it to `- [x]`.
> Under each task, you can read the test steps and type your test notes directly into `Comments:`.

---

## 🎬 Cluster 1: Live Stream Player, Audio & Viewport Enhancements

- [ ] **Task 1: Audio Playback Stability & Streamer Silence / Mic Muted Indicator**
	- **Description:** Join an Audio-Only broadcast (e.g. Al Quran 4K). Verify audio starts automatically (`autoPlay: true`) and continues in the background. When the broadcaster mutes mic or stays silent for >3s, verify the animated amber badge *"Streamer Microphone Muted / Silent Mode"* appears. Verify voice ripples pause when silent.
	- **Comments:** have the same issue in [[issue_log]] where I can't inter as a viwer to see my current signed in account live. so I can't verify the "Mic Muted Indicator". but the other Audio Playback Stability is good. 

- [ ] **Task 2: Real Resolution Quality Selector (Auto, 1080p, 720p, 480p, 360p)**
	- **Description:** Open a video stream and tap the quality gear button. Verify it offers actual resolution presets (`Auto`, `1080p`, `720p`, `480p`, `360p`) instead of internal engine strings. Open an Audio-Only stream: verify the quality button is completely hidden.
	- **Comments:** can't inter other account to test this feature du to issues in [[issue_log]]

- [x] **Task 3: Auto-Rotate to Fullscreen Landscape (One-Way Exit)**
	- **Description:** Tap the fullscreen button in portrait mode. Verify it rotates to landscape and enters sticky immersive mode. Tap exit fullscreen: verify orientation unlocks freedom (`portraitUp`, `landscapeLeft`, `landscapeRight`) without forcefully snapping back to portrait.
	- **Comments:** working. 

- [ ] **Task 4a: Branded Default Stream State Placeholders & Diagnostics**
	- **Description:** Check non-live states: Initializing, Starting Soon, Concluded, Offline, Reconnecting. Verify `StreamStatePlaceholderOverlay` displays branded illustrations with localized status text and diagnostic retry actions instead of raw error screens.
	- **Comments:** can't inter other account to test this feature du to issues in [[issue_log]]

- [ ] **Task 4b: Custom Streamer Placeholders & Admin Moderation Pipeline**
	- **Description:** As a streamer: upload custom broadcast cards (Starting Soon, Intermission, Ending) in profile editor. As an admin: open Admin Hub $\rightarrow$ Placeholder Approval Queue, test approving or rejecting with a required feedback reason. As streamer: verify receiving notification feedback.
	- **Comments:** can't inter other account to test this feature du to issues in [[issue_log]]. but add the ability to have this as a fixed action, meaning its approved once, then if the same image is used, no need for the admin to approve. 

- [x] **Task 5: Resilient "Open in YouTube" Fallback Button**
	- **Description:** In live broadcast room or VOD player, tap "Open in YouTube". Verify it launches the native YouTube app (or browser fallback) directly using multi-tier URL schemes (`vnd.youtube` $\rightarrow$ `https://www.youtube.com/watch?v=...`).
	- **Comments:** works.

- [x] **Task 6: In-App Picture-in-Picture (PiP) Floating Mini-Player**
	- **Description:** Tap minimize in `LiveBroadcastScreen`. Verify floating mini-player displays 16:9 thumbnail preview, single-line truncated title (0px overflow), and Play/Pause + Close buttons. Audio continues playing. Tap mini-bar to expand back to full room.
	- **Comments:** working, maybe we can add a feature to make it bigger and samller window. but later

---

## 🗺️ Cluster 2: Spatial Map & GIS Navigation Polish

- [ ] **Task 7: Free Carto / OpenStreetMap Basemap Tiles without API Key**
	- **Description:** Open the Spatial Map tab (`/map`). Pan and zoom around Saudi Arabia and Eastern Province. Verify tiles load smoothly with zero missing grey tiles or API key errors.
	- **Comments:** 

- [ ] **Task 8: White Disc Background for Spatial Map Profile Markers**
	- **Description:** Inspect streamer avatars, offline markers, and pulsing live markers on the map. Verify marker avatar discs have a clean white background (`Colors.white`), giving high contrast against the dark basemap.
	- **Comments:** 

- [ ] **Task 9: One-Click Google Maps Navigation Integration**
	- **Description:** Tap a streamer or institution marker to open `VenueNavigationSheet` or `MarkerSummaryCard`. Tap "Open in Google Maps". Verify it launches Google Maps with exact `latitude, longitude` destination pins.
	- **Comments:** 

---

## 🏷️ Cluster 3: Categories, Tags & Feed Filter Synchronization

- [x] **Task 10: Sync Academic Categories Across Discovery, Filters & Spatial Map**
	- **Description:** Select an academic category chip in Discovery Feed (e.g. "Computer Science"). Switch to Spatial Map: verify the "All Topics" dropdown reflects the same category filter. Open the Advanced Tags Filter sheet: verify category selection is synchronized.
	- **Comments:** no comments, all good. 

- [ ] **Task 11: Admin Power to Create, Edit, and Reorder Academic Categories**
	- **Description:** Log in as Admin $\rightarrow$ Admin Hub $\rightarrow$ Academic Categories tab. Test adding a new category with bilingual (EN/AR) names and icon glyph. Test editing names, reordering sort order, and deleting. Verify Discovery Feed and Map update immediately.
	- **Comments:** its good but its too small as its open in a desktop so have the desktop version bugger. over that I want add a Icon library so the admin does not need to remember all the icons name. over that I get the following massage "PostgrestException (message: Could not find the table 'public.academic_categories' in the schema cache, code: PGRST205, details:, hint" so we need to correctly connect it, as when the admin adds one/edits/delete a Academic Categories, the rest of the users must get the live update. lastly need to have correction for knew the admins add an English name into the Arabic filed for the Academic Categories name, and the same for when the user add an Arabic name for when adding to the English name for Academic Categories, as in add some error handling. 

- [ ] **Task 12: Admin Controls on Tags & Tag Moderation**
	- **Description:** In Admin Hub $\rightarrow$ Tag Moderation Manager: test approving, merging/renaming, and blacklisting submitted tags. Verify approved tags autocomplete in Streamer Application Step 3 and display in the Discovery Tags Filter sheet.
	- **Comments:** good, but where is the current tags ?? so we can edit them. plus we need to make a feature where the admin can see the streamers that user specific tags, so we have full moderation abilities. 

---

## 🛡️ Cluster 4: Moderation, Chat, and User Permission Architecture

- [x] **Task 13: User Message Actions (Edit/Delete Own, Report/Hide Others)**
	- **Description:** In live chat, long-press your own message: test "Edit Message" (edits save with `(edited)` indicator) and "Delete Message". Long-press another user's message: test "Report Message", "Hide Message" (hides locally), and "Block User".
	- **Comments:** only thing to add is an indicator for an admin/moderator massage, so we can see when an admin/moderator types in the chat more visibly. in addition to that we need to add a notification to the viewer if they got blocked. this action also must go to the admin so he can see how many ppl blocked him, and what massages did he send. another notification to the admin/moderator (while the are in the stream) if a another 3+ users hid/report another user then admin/moderator are notified and can block him (we see if we can make it easer by first highlighting that user (only for the admin/moderator, but also within the notification there is a quick action button to block the user)). another admin feature is a list of users that got Muted by either the admin/moderator in a stream and how many streams he got muted in, and the massages prior to being muted. 
	  

- [x] **Task 14: Link Reports and Hides to the Moderation Team**
	- **Description:** Report a chat message as a viewer. Log in as Admin/Org Owner $\rightarrow$ Admin Hub $\rightarrow$ Chat Moderation tab. Verify reported message appears in real-time. Test action buttons: `Dismiss Report`, `Delete Message`, `Mute User` (10m, 1h, Permanent), and `Ban Platform-Wide`.
	- **Comments:** its working. I can report in one phone, and another I can inter as an admin and check the admin hup for that massage. 

- [ ] **Task 15: Stream Moderator Labels (`🛡️ MOD`) & Delegation Hierarchy**
	- **Description:** As streamer or admin, appoint a viewer as stream moderator from their chat profile. Verify they receive the `🛡️ MOD` badge on their chat messages. In Admin Hub $\rightarrow$ Role & Permission Management, verify moderator audit table logs the appointment.
	- **Comments:** I get this massage "PostgrestException(message: Could not find the table 'public.stream_moderators' in the schema cache, code: PGRST205, details: Not Found, hint: Perhaps you meant the table 'public.streamer_public_profiles')" and it does not work

- [ ] **Task 16: Admin Power to Block User from Application (Email/Account Ban)**
	- **Description:** In Admin Hub $\rightarrow$ Banned Accounts tab, ban a test user with a reason. Sign in with that user: verify `AppRouter` immediately redirects them to `/account-banned` and blocks navigation to other screens.
	- **Comments:** need to add a massage to that use when he try's inteing using that same email. 

- [x] **Task 17: Option in Settings to Delete Past Messages (All or by Stream)**
	- **Description:** Go to Settings $\rightarrow$ Chat History & Privacy. Test "Delete All My Messages" (purges all user messages across all broadcasts). Test "Clear Messages by Stream" (purges messages only for a chosen broadcast room).
	- **Comments:** 

- [ ] **Task 18: Temporary Removal of Streamer from Map by Moderation**
	- **Description:** In Admin Hub $\rightarrow$ Streamers Registry, toggle "Hide from Map" on a streamer. Open Spatial Map: verify their marker is hidden from the map. Verify their profile remains accessible via direct link or Discovery Feed.
	- **Comments:** "Failed to update map visibility" this is what I get when I try hiding an account. 

---

## 📊 Cluster 5: Stream & Video Data Telemetry, Views & Logging

- [ ] **Task 19: Accurate Views Counter on Streams and Videos**
	- **Description:** Check viewer counters on Discovery Feed live cards (e.g. `4.2K watching`), VOD grid tiles (e.g. `12.5K views`), and live player overlays. Verify counts match Supabase presence and format cleanly.
	- **Comments:** 

- [ ] **Task 20: Logging Stream Session Data into Supabase Database**
	- **Description:** Start a live broadcast (Phone camera or OBS mode). Verify a row is inserted in `public.streams` with stream ID, streamer ID, title, start time, and ingest mode. End stream: verify record updates with end time, duration, and peak viewers.
	- **Comments:** 

---

## 🎨 Cluster 6: Responsive UI, Assets & Localization

- [ ] **Task 21: Refresh Default Profile Avatars & Banners**
	- **Description:** Open Streamer Application Step 2 & Viewer Setup. Verify avatar picker offers professional academic/vector presets and banner picker offers high-res university/scholarly themes.
	- **Comments:** 

- [ ] **Task 22: Connect Lecture Bookmarks Feature**
	- **Description:** Tap the bookmark icon on any VOD or live card. Open Discovery Feed $\rightarrow$ Bookmarks sheet. Verify saved lectures render in a responsive GridView with instant playback on tap.
	- **Comments:** 

- [ ] **Task 23: Fix Overflowed Pixels Across All Screen Sizes**
	- **Description:** Test the app on narrow phone screens (320px–375px). Verify zero RenderFlex yellow/black stripe overflow errors in Admin Hub metric cards, Discovery live carousel, and Map search bar.
	- **Comments:** 

- [ ] **Task 24: Remove Emojis from Notifications**
	- **Description:** Trigger notification events (broadcast started, admin approval, application status). Verify notification titles and toast alerts use clean vector icons instead of emoji prefixes.
	- **Comments:** 

- [ ] **Task 25: Remove App Language Option from Settings Body**
	- **Description:** Open Settings (`/settings`). Verify Section 3 (Language selector card) has been removed from the scrollable body, while the top App Bar `LanguageSwitcher` pill remains the clean single toggle.
	- **Comments:** 

- [ ] **Task 26: Fully Build Mobile Admin Hub View**
	- **Description:** Open Admin Hub on a phone screen (<600px width). Verify tabs scroll horizontally without overflowing and metrics cards, verification tables, and moderation queues stack vertically and responsively.
	- **Comments:** 

- [ ] **Task 27: Harmonize Phone Broadcast with Live Stream Room Interface**
	- **Description:** Launch Phone Camera Broadcasting mode. Verify Live Chat, floating reactions, viewer counter, and mic mute toggle overlay cleanly on top of the camera viewfinder without clipping.
	- **Comments:** 

- [ ] **Task 28: Streamer Can Only Go Live on Their Own Profile Page**
	- **Description:** Log in as Streamer A and visit Streamer B's profile page: verify the cell tower "Go Live" button in the App Bar is hidden. Visit Streamer A's own profile: verify the "Go Live" studio button is visible and working.
	- **Comments:** 

- [ ] **Task 29: Complete Remaining Arabic Localization & RTL Polish**
	- **Description:** Switch language to Arabic (🇸🇦 العربية). Verify 100% Arabic text coverage across Discovery, Map, Admin Hub, Live Player, Settings, and Application Wizard with zero missing translation keys (`live.xyz`).
	- **Comments:** 

---

## 🏗️ Core System Architecture Pipelines

- [ ] **Pipeline 1: Broadcaster Abilities & Content Management**
	- **Description:** Test phone RTMP stream publishing, OBS ingest key generation, audio-only broadcasting, VOD publishing, live chat moderation, and moderator delegation.
	- **Comments:** 

- [ ] **Pipeline 2: Super Admin Platform Governance**
	- **Description:** Test broadcaster verification queue, category/tag CRUD, chat report triage, platform-wide email bans, and custom placeholder approvals.
	- **Comments:** 

- [ ] **Pipeline 3: Organization & Multi-Campus Management**
	- **Description:** Test organization profile editing, branch campus map pinpointing, speaker roster management, and affiliation request approvals.
	- **Comments:** 

- [ ] **Pipeline 4: 5-Step Streamer & Organization Application Wizard**
	- **Description:** Test complete onboarding flow: Step 1 Identity $\rightarrow$ Step 2 Media Upload $\rightarrow$ Step 3 Channel Info $\rightarrow$ Step 4 Venue Pinpoint $\rightarrow$ Step 5 Terms & Charter submission.
	- **Comments:** 

- [ ] **Pipeline 5: Real-Time Notifications & Heartbeat Architecture**
	- **Description:** Test high-priority push notifications, broadcast alerts to followers, and admin status change toasts.
	- **Comments:** 

- [ ] **Pipeline 6: Phone Camera Broadcast Pipeline**
	- **Description:** Test camera permissions, RTMP publishing to YouTube / RTMP endpoint, auto-reconnect on network jitter, and studio controls.
	- **Comments:** 

- [ ] **Pipeline 7: OBS Studio & External Ingest Pipeline**
	- **Description:** Test stream key generation, RTMP server ingest endpoint, and stream privacy whitelist enforcement.
	- **Comments:** 

- [ ] **Pipeline 8: Local Wi-Fi Network Streaming Pipeline**
	- **Description:** Test local IP configuration, low-latency loopback, and local auditorium distribution on the same Wi-Fi network.
	- **Comments:** 

- [ ] **Pipeline 9: Supabase Database Schema & Realtime Replication**
	- **Description:** Test PostgreSQL RLS policies, Realtime chat message replication, Supabase Storage buckets, and migration schema integrity.
	- **Comments:** 

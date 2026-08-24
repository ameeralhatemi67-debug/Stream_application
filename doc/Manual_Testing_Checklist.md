# 📱 Streamer App — Master Manual Testing Checklist & QA Guide

> **Target Versions Verified:** `v0.5 Backend Foundation`, `v0.6 Realtime Chat`, `v0.7 Mobile Android Streaming`, `v0.8 Tiered Admin RBAC`  
> **Environment Prerequisites:** Supabase Remote Database (14 migrations active), YouTube Data API v3 key in `dart_define.local.json`.

---

## 🚀 Setup & Launching Dual Environments (Phone & Laptop)

To test true **multi-user interaction** (e.g. Broadcaster streaming on Phone ⇄ Viewer watching & chatting on Laptop ⇄ Admin moderating):

### 1. Laptop Setup (Web / Chrome)
```powershell
cd project
flutter run -d chrome --dart-define-from-file=dart_define.local.json
```

### 2. Phone Setup (Physical Android Device or Android Emulator)
* **Option A: Physical Android Phone:** Enable USB Debugging, connect via USB, and check `flutter devices`.
* **Option B: Android Emulator:** Run `flutter emulators --launch rtmp_spike_x86_64`.
```powershell
cd project
flutter run -d <phone-or-emulator-device-id> --dart-define-from-file=dart_define.local.json
```

---

## 📋 Checklist Matrix: 10 Functional Domains (139 Test Cases)

Use the checkboxes below `[ ]` to log your manual testing results.

---

### Section 1: Authentication, Onboarding & Guest Mode (`TC-AUTH`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 1.1 | **Welcome Screen Branding** | Launch app on fresh install / sign-out. | Welcome screen displays app branding, Google Sign-In button, and "Continue as Guest". | [ ] |
| 1.2 | **Guest Mode Access** | Tap "Continue as Guest". | Enters Discovery Feed / Spatial Map as guest viewer without credentials. | [ ] |
| 1.3 | **Google OAuth Sign-In** | Tap "Sign in with Google" and complete web OAuth. | Authenticates via real Supabase Auth, updates session state, and redirects to home feed. | [ ] |
| 1.4 | **Guest Route Protection** | While logged in as Guest, attempt to navigate to `/streamer-apply` or `/settings`. | Intercepted by `GoRouter` guard and redirected to `/welcome` or prompted with sign-in sheet. | [ ] |
| 1.5 | **Broadcaster Application Wizard** | Sign in as regular user, open `/streamer-apply`, fill multi-step wizard. | Progresses through steps (Personal info, Org affiliation, Terms acceptance) with zero overflow. | [ ] |
| 1.6 | **Sign Out Lifecycle** | In Profile/Settings, tap "Sign Out". | Session clears cleanly, auth state resets, and UI returns to WelcomeScreen. | [ ] |

---

### Section 2: Mobile Phone Streaming & Audio-Only (`v0.7` / `TC-RTMP`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 2.1 | **Permission Rationale Dialog** | On Phone, tap "Go Live" ➔ select "From Phone" tab. | Contextual dialog explains Camera & Mic access *before* triggering OS permissions. | [ ] |
| 2.2 | **Live Camera Preview** | Grant permissions. | Phone camera preview renders smoothly with front/back camera flip button. | [ ] |
| 2.3 | **RTMP Key Ingest Entry** | In "From Phone" tab, paste RTMP URL (e.g. `rtmp://a.rtmp.youtube.com/live2`) and Stream Key. | Inputs validate, store securely, and enable "Start Broadcasting". | [ ] |
| 2.4 | **Go-Live Video Stream** | Start broadcast. Test camera swap and mic mute while live. | Streaming starts with live timer; camera flips without freezing; mic mute toggles audio track. | [ ] |
| 2.5 | **Audio-Only Phone Broadcast** | In Go-Live dialog, toggle **"Audio-Only"** mode and start stream. | Camera is disabled; static branded thumbnail feeds YouTube ingest track; mic captures audio. | [ ] |
| 2.6 | **Background / Lock-Screen Streaming** | While broadcasting audio-only, press Home or lock phone screen. | Stream **continues in background**; ongoing Foreground Service notification appears in tray. | [ ] |
| 2.7 | **Connection Drop & Auto-Reconnect** | While broadcasting, toggle WiFi off/on (or drop network). | Shows *"Stream Interrupted — Reconnecting… (Attempt X/6)"* banner; auto-reconnects smoothly. | [ ] |
| 2.8 | **Safe Exit Mid-Broadcast** | Tap back/close while broadcasting live. | Confirmation prompt stops stream cleanly without crashing or leaving phantom background service. | [ ] |

---

### Section 3: Realtime Live Chat & Reactions (`v0.6` / `TC-CHAT`)

*(Best tested with Phone as Broadcaster / Laptop as Viewer)*

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 3.1 | **Live Connection Indicator** | Open any live stream broadcast screen. | Status pill transitions from amber *"Connecting…"* to green *"Live"*. | [ ] |
| 3.2 | **Optimistic Chat Message Send** | Type a message on Phone and tap Send. | Message appears immediately with checkmark delivery confirmation. | [ ] |
| 3.3 | **Cross-Client Live Sync** | Send a chat message on Phone. Observe Laptop screen on same stream. | Message instantly pops up on Laptop in real-time (< 300ms) without refreshing. | [ ] |
| 3.4 | **Sender Role Badges** | Send message from an Admin, Verified, or Speaker account. | Distinct badge displays next to sender name: 🎙️ (Speaker), 🏛️ (Org), 🛡️ (Admin), ✅ (Verified). | [ ] |
| 3.5 | **Floating Emoji Reactions** | Tap reaction FABs (❤️, 🔥, 👏, 💡, 🎓) on Phone. | Ephemeral floating animations float up on both Phone and Laptop simultaneously (zero DB row waste). | [ ] |
| 3.6 | **Guest Chat Restriction** | Open stream as an unauthenticated guest and attempt to send chat. | Blocked with toast *"Sign in to send a chat message"*. | [ ] |

---

### Section 4: Chat Moderation & UGC Safety (`Apple Guideline 1.2`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 4.1 | **Report Message** | Long-press another viewer's message ➔ select "Report Message" ➔ choose reason. | Report writes to `chat_reports` table; confirmation toast confirms report submitted. | [ ] |
| 4.2 | **Block User (Client-Side)** | Long-press user message ➔ select "Block User". | Future messages from that sender are hidden instantly on your device. | [ ] |
| 4.3 | **Active Profanity / Keyword Filter** | Attempt to send a message containing a banned word. | Database `BEFORE INSERT` trigger rejects message with an instant moderation alert. | [ ] |
| 4.4 | **Live Message Deletion** | Log in as Admin/Owner, long-press offending message ➔ "Delete Message". | Message is deleted from DB and **disappears in real-time from all viewers' screens**. | [ ] |
| 4.5 | **Mute Bad Actor** | Admin selects "Mute Sender". | Target user added to `chat_muted_users`; target user is blocked from sending further messages. | [ ] |

---

### Section 5: Tiered Admin Hub & RBAC Management (`v0.8` / `TC-ADMIN`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 5.1 | **Admin Hub Access Control** | Sign in as Master Admin ➔ navigate to `/admin`. | Access granted. Header badge shows **MASTER ADMIN**. | [ ] |
| 5.2 | **Non-Admin Block** | Sign in as regular user ➔ attempt navigating to `/admin`. | Route guard redirects to access-denied page with no administrative data exposed. | [ ] |
| 5.3 | **Broadcaster Verification Queue** | In Admin Hub ➔ Applications tab, review pending broadcaster submissions. | Details, submitted documents, and org affiliation request are clearly displayed. | [ ] |
| 5.4 | **Batch Approval / Rejection** | Tick multiple application checkboxes ➔ tap "Select All" ➔ tap "Batch Approve". | Batch action modal prompts confirmation; approved applicants become real organizations/streamers. | [ ] |
| 5.5 | **Roles & Permissions Matrix** | In Admin Hub ➔ "Roles & Permissions" tab, locate an Admin user. | Master Admin can grant/revoke Admin role and toggle capability checkboxes (`edit_terms`, `moderate_chat`, `manage_admins`). | [ ] |
| 5.6 | **Platform Chat Moderation Queue** | In Admin Hub ➔ "Chat Moderation" tab, inspect reported messages queue. | Displays reporter, sender, text, and timestamp. Actions: **Dismiss Report**, **Delete Message**, **Mute User**. | [ ] |

---

### Section 6: Organization & Permitted Admin Portal (`v0.8 CP3` / `TC-ORG`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 6.1 | **Permitted Admin Org Portal** | Sign in as an Organization Owner ➔ navigate to `/org-admin`. | Opens `OrgAdminScreen` strictly scoped to the owner's `permittedAdminOrgIds`. | [ ] |
| 6.2 | **Manage Campus Venues** | In `/org-admin`, add or edit a campus branch location. | Venue writes through to `org_venues` in Supabase; updates reflect on org profile. | [ ] |
| 6.3 | **Manage Org Speakers** | In `/org-admin`, add an instructor/speaker with bio and photo. | Speaker writes through to `org_speakers` in Supabase. | [ ] |
| 6.4 | **Org Profile Display** | Open public Organization Profile screen from Discovery Feed. | Displays Org banner, featured channels, campus branches modal, and instructor inspection sheets. | [ ] |
| 6.5 | **PII Protection Check** | Inspect network requests or query public view for venue coordinates and phone numbers. | Private contact numbers and exact GPS coordinates are stripped for non-admin viewers. | [ ] |

---

### Section 7: Spatial Map & GIS Navigation (`TC-MAP`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 7.1 | **Spatial Map Marker Rendering** | Switch to the Map tab. | Streamer markers render across Saudi & GCC regions with category-colored indicators. | [ ] |
| 7.2 | **80% Transparency Top Bar Controls** | Inspect top search bar, city dropdown, and topic selector chips. | Controls render with 80% backdrop blur styling; category chips filter markers dynamically. | [ ] |
| 7.3 | **Marker Tap & Inspection Card** | Tap any active streamer pin on the map. | Bottom streamer preview card slides up showing live status, avatar, and "Watch Stream" button. | [ ] |
| 7.4 | **State Isolation Check (`context.select`)** | Pan and zoom the map continuously. | Map runs smoothly at 60fps without triggering rebuilds across other tabs. | [ ] |

---

### Section 8: Video Player, YouTube Integration & VOD Archive (`TC-YT` / `TC-VOD`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 8.1 | **YouTube Live Player Embed** | Tap any active YouTube streamer in Discovery feed. | Embedded player starts playback using `youtube-nocookie.com` with zero Error 150 embed rejections. | [ ] |
| 8.2 | **Mini-Player Docking** | While playing a video, swipe down or navigate to Map tab. | Mini-player docks to bottom right with audio continuing seamlessly. | [ ] |
| 8.3 | **VOD / Playlist Modal Sheet** | On an Org or Streamer profile, tap "Playlists" or "Recent VODs". | Fetches and displays YouTube channel uploads and playlist items cleanly. | [ ] |
| 8.4 | **Premieres & Upcoming Filter** | Browse upcoming scheduled broadcasts. | Displays countdown badge (*"Live in X hours/days"*). | [ ] |

---

### Section 9: Offline Resilience & Demo Mode (`v0.6 CP4`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 9.1 | **Ghost Chat Offline Fallback** | Disconnect internet / turn on Airplane mode while watching a stream. | Chat tab shows persistent amber **"Demo Mode / Offline"** banner. | [ ] |
| 9.2 | **Ghost Comment Stream** | Observe chat in Demo Mode. | Simulated commentary (`ghost_comments.dart`) injects periodically with dimmed colors. | [ ] |
| 9.3 | **Offline Send Prevention** | Attempt typing and sending chat in Demo Mode. | Send button disabled; tapping shows *"You are offline"* toast without crashing. | [ ] |
| 9.4 | **Seamless Reconnection** | Turn WiFi back on. | Demo messages clear automatically; real Supabase Realtime chat reconnects and syncs. | [ ] |

---

### Section 10: Localization & Bilingual RTL/LTR (`ADR-003`)

| # | Test Scenario | Steps to Perform | Expected Result | Pass / Fail |
|---|---|---|---|---|
| 10.1 | **Language Switch (EN ➔ AR)** | Go to Settings ➔ switch language to Arabic (العربية). | Entire app flips to native RTL (Right-to-Left) with Tajawal Arabic typography. | [ ] |
| 10.2 | **Key Symmetry Verification** | Check all screens (Chat, Map, Admin Hub, Go Live, Org Profile) in Arabic. | Zero missing translation keys (no raw `[key.name]` strings displayed). | [ ] |
| 10.3 | **RTL Layout Mirroring** | Inspect back buttons, action bars, drawer navigation, and chat timestamps in Arabic. | Icons and directional elements mirror correctly without visual text clipping. | [ ] |

---

## 📝 QA Test Summary & Notes

* **Tester Name:** `_______________________`
* **Test Date:** `_______________________`
* **Devices Tested:** 
  - Laptop: `_______________________ (e.g. Chrome on Windows 11)`
  - Phone: `_______________________ (e.g. Pixel Emulator / Physical Phone)`
* **Total Tests Executed:** `____ / 45 Scenarios (139 Unit Cases Covered)`
* **Overall QA Status:** `[ ] PASSED` / `[ ] ISSUES FOUND`

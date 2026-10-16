# Data safety working draft

Status: 2026-10-16. The copy-ready Play form answers are in the first section below. They come from the code, the migrations and the hosted backend as of 2026-10-16. No release bundle, SDK traffic capture or Play form was inspected, so counsel and the owner still verify before submitting. Where Google's definitions leave a real choice, the table says so and recommends the more cautious answer (over-declaring is safe; under-declaring is a policy violation).

## Play Console answers (copy-ready)

Play Console > Policy > App content > Data safety.

### Part 1: the screening questions

| Question | Answer | Why |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** | Account, chat, location, device and media data below. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | Cleartext traffic is off (`usesCleartextTraffic="false"`); Supabase, Google and YouTube are HTTPS; RTMPS is used for ingest. |
| Do you provide a way for users to request that their data be deleted? | **Yes** | In-app Settings > Delete My Account, and the web page. |
| Deletion URL | `https://stream-application-ten.vercel.app/delete-account.html` | Also states what is deleted. |
| Independent security review (optional badge) | No | Not done. |
| Committed to the Play Families Policy | Not applicable | Target audience is not children (see below). |

### Part 2: data types

"Shared" below means disclosed to a third party under Google's definition. Disclosure to a service provider that only processes data for us (Supabase, Vercel, Firebase Cloud Messaging) and users seeing each other's public content inside the app are **not** sharing, so they are marked "No". Purposes use Play's names.

| Play data type | Collected | Shared | Optional? | Purpose | Notes for the form |
| --- | --- | --- | --- | --- | --- |
| **Personal info: Name** | Yes | No | Optional (guests need no account) | App functionality, Account management | Google display name and the profile name. |
| **Personal info: Email address** | Yes | No | Optional | App functionality, Account management | From Google sign-in; also on applications. |
| **Personal info: User IDs** | Yes | No | Optional | App functionality, Account management | Supabase account ID. |
| **Personal info: Phone number** | Yes | No | Optional (only broadcaster applicants) | App functionality | Application review. |
| **Personal info: Other info** | Yes | No | Optional | App functionality | Bio, YouTube handle, academic and organization details, roles. |
| **Location: Precise location** | Yes | No | Optional | App functionality | "Use my location" is read on tap, foreground only, to place a venue pin. Only the venue point the user confirms is saved. Declare it because the point can equal the device position. |
| **Messages: Other in-app messages** | Yes | No | Optional | App functionality | Live chat and reports. |
| **Photos and videos: Photos** | Yes | No | Optional | App functionality | Avatar, banner and application images picked by the user (photo picker, no broad media permission). |
| **Photos and videos: Videos** | Yes | **Yes** (Google / YouTube) | Optional (broadcasters only) | App functionality | Phone camera video is sent by the app to the broadcaster's YouTube live ingest. We never receive or store it. Mark **ephemerally processed: yes**. Cautious choice: declare as shared because YouTube is a third party; counsel may accept the "user-initiated" exemption instead. |
| **Audio: Voice or sound recordings** | Yes | **Yes** (Google / YouTube) | Optional (broadcasters only) | App functionality | Same as video, including audio-only mode. Ephemeral: yes. |
| **App activity: App interactions** | Yes | No | Optional | App functionality | Follows, bookmarks, reminders, live viewer presence. |
| **App activity: Other user-generated content** | Yes | No | Optional | App functionality | Profile and organization text, schedules, show details. |
| **Device or other IDs** | Yes | **Yes** (Google) | Required for notifications only | App functionality | Device ID/name/platform; the Firebase push token and installation ID. Declared as shared with Google because Firebase Messaging and the YouTube embedded player receive device or connection identifiers. |
| **Web browsing, Contacts, Calendar, Files, Health, Financial info, Approximate location, Audio files, Emails, SMS** | No | n/a | n/a | n/a | Not collected. |
| **App info and performance (crash logs, diagnostics)** | No | n/a | n/a | n/a | No crash or analytics SDK is installed and no error report is sent to a server. (Google Play's own vitals are not declared by developers.) |

Not asked by the form but be ready to explain: no advertising SDK, no analytics SDK, no data sale, no data used for ads.

### Part 3: other Play forms that depend on this

| Form | Answer |
| --- | --- |
| Ads | No ads. |
| Target audience | 18 and over (recommended). Choosing under-13 triggers the Families policy; do not. Counsel question 6 decides 13+. |
| Content rating (IARC) | User-generated content: yes (chat, profiles). Users can interact: yes. Shares location with other users: venue coordinates only, public. Violence, sexual content, gambling, drugs: none from the app itself. Expect a Teen/PEGI 12-type result because of unmoderated-in-real-time chat; answer honestly. |
| Permissions declared in the manifest | Camera, microphone, foreground service (camera, microphone), notifications, approximate and precise location. No storage or media permission. See `permissions_and_fgs_declaration.md`. |
| Government app / Financial features / Health / News | No / none / none / no. |
| Account deletion | The URL above, plus "the app has in-app deletion". |

### Items to confirm before pressing Submit

1. If you add any analytics, crash reporting or ads SDK later, this form changes.
2. The privacy policy says data is stored in Frankfurt (Supabase `eu-central-1`); the Data safety form does not ask for a region but counsel question 4 does.
3. Re-read Part 2 against the **merged manifest of the final `.aab`** (`bundletool`), not just this file.

Google requires an accurate, package-wide Data safety form covering data collected or shared by the app and its SDKs; the form also asks about encryption in transit and deletion. These are form questions, not answers established by this draft. [Google Play Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

## What the current code handles

| Data and purpose | Current path and evidence | Destination or visibility |
| --- | --- | --- |
| Google account identity, email, display name, avatar and Supabase user ID for sign-in/profile | Google OAuth through Supabase Auth in project/lib/core/services/supabase_auth_service.dart; profile columns in supabase/migrations/20260821203000_initial_schema.sql | Google sign-in and Supabase Auth/database. Profile information may be shown publicly. |
| Applicant name, email, phone, academic and organization details, YouTube handle, optional venue coordinates and uploaded images for broadcaster review | broadcaster_applications schema and project/lib/core/services/admin_database_service.dart upload/write paths | Supabase database and public streamer-assets URLs for approved/public assets. Admin review notes are also stored. |
| Profile and organization text, venue names/addresses and coordinates, affiliations, permissions, roles, follows and bookmarks for discovery and account features | initial_schema.sql; 20260920150000_follows_and_bookmarks.sql | Supabase; some profile, organization and venue details are public. Coordinates are a venue point the user confirms on the map. |
| Device location for "use my location" while picking a venue (2026-10-15 check) | `location_picker_modal.dart` `_useMyLocation()`; manifest declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`, foreground only | Requested only when the user taps the button, never at start-up or in the background. The reading only moves the map pin on the device; nothing is sent until the user confirms a point, and then only that venue point is saved (and shown publicly on the map). Precise location is kept because coarse (~2 km) cannot pin a venue. Play form: likely "precise location, collected, optional, app functionality"; **for counsel review**. |
| Chat body, sender ID, reports and reason, blocks, mutes, bans and moderation audit for chat and safety | chat_messages, chat_reports, chat_muted_users, banned_users, chat_user_blocks and audit migrations; live_chat_controller.dart | Supabase; chat is visible to room users subject to access and blocks; reports and moderation records have restricted reads. |
| Device ID/name/platform, primary-broadcaster state, heartbeat and viewer presence for one-broadcaster control and live count | device_sessions and stream_viewers migrations; AppProvider local_device_id | Supabase. viewer_key needs separate identity/retention review. |
| Consent version and acceptance time for the Welcome gate | profiles.consent_version / consent_accepted_at; AppProvider.recordConsent() | Supabase for signed-in users; SharedPreferences first, and only local for guests. |
| Selected image bytes for profile/application assets | admin_database_service.dart uploadBinary to streamer-assets | Supabase Storage; public URL is returned. The code does not use whole-library photo access. |
| Camera/microphone live media for broadcaster-initiated RTMP | Android RtmpPublisherBridge and RtmpPublishEngine; project/android/app/src/main/AndroidManifest.xml | RTMP endpoint entered/selected by broadcaster, commonly YouTube ingest. Media is not shown as stored in the app database. Endpoint operator's retention is unverified. |
| YouTube channel handle, video IDs and player requests for discovery/playback | youtube_api_service.dart sends handles/IDs to www.googleapis.com/youtube/v3; youtube_player_adapter.dart embeds youtube-nocookie.com; thumbnail URLs use img.youtube.com | Google/YouTube receive those requests and normal connection metadata. No claim about their downstream retention. |
| Map tiles, external directions and remote imagery | spatial_map_screen.dart uses ArcGIS or OpenStreetMap tiles; Google Maps directions use coordinate URLs; some fallback images use Unsplash | These third-party requests can expose IP/device connection metadata and map view or destination coordinates. Confirm shipped paths and vendor terms before form submission. |

Supabase is the app's backend processor in this draft. Google handles OAuth, YouTube API/player/ingest where invoked, and Maps directions when the user opens them. A third-party embedding, transport or disclosure classification for each Play data type is **for counsel review** with the owner. Do not infer that YouTube video is private from an unlisted URL.

## Current export, deletion and retention limits

Updated 2026-10-15 (backend live on hosted; app change ships with the next build): Settings > Privacy saves a complete JSON export from `export_my_data()`, and Settings > Delete account removes the user's uploaded files through the Storage API, then deletes the account with the name/email copies in the audit log and review history redacted. Details and remaining gaps: data_export_and_withdrawal_gaps.md. Metadata in audit entries is not rewritten.

No table-wide retention schedule or automatic deletion period is defined in the inspected migrations. The app limits local notification history to 30 records, and caches some catalog, moderation and device data in SharedPreferences; those bounds do not establish server retention. Backups, Auth logs, YouTube media, Google OAuth data, and external tile/image logs were not inspected. Retention wording and exceptions are **for counsel review**.

Google Play requires an in-app deletion path and a functional web deletion link for apps with account creation; associated data and service providers need review. The repository has an in-app path and a project/web/delete-account.html draft, but the public URL and actual end-to-end erasure were not verified here. [Google Play account deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)

## Answers to obtain before the form

- Owner: confirm the exact release AAB merged manifest, SDK list, destination domains, Supabase project region, public privacy/deletion URLs, encryption evidence, and actual production retention/backups without granting this task production access.
- Owner and counsel: decide each Play data type's collected/shared/optional/ephemeral classification, purposes, deletion disclosures and service-provider treatment. **For counsel review.**
- Engineering: close the export and withdrawal gaps, verify uploaded-object erasure and surviving audit identity, then run account deletion on a disposable local stack. No such code change or test was made in this documentation task.

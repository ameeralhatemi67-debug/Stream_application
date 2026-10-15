# Data safety working draft

Status: 2026-09-24 repository-based draft. For counsel review and owner verification before any Play Console answer. No production configuration, release bundle, SDK traffic capture, or Play form was inspected. P8B is not accepted.

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

Updated 2026-10-15 (local, not yet deployed): Settings > Privacy saves a complete JSON export from `export_my_data()`, and Settings > Delete account removes the user's uploaded files through the Storage API, then deletes the account with the name/email copies in the audit log and review history redacted. Details and remaining gaps: data_export_and_withdrawal_gaps.md. Metadata in audit entries is not rewritten.

No table-wide retention schedule or automatic deletion period is defined in the inspected migrations. The app limits local notification history to 30 records, and caches some catalog, moderation and device data in SharedPreferences; those bounds do not establish server retention. Backups, Auth logs, YouTube media, Google OAuth data, and external tile/image logs were not inspected. Retention wording and exceptions are **for counsel review**.

Google Play requires an in-app deletion path and a functional web deletion link for apps with account creation; associated data and service providers need review. The repository has an in-app path and a project/web/delete-account.html draft, but the public URL and actual end-to-end erasure were not verified here. [Google Play account deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)

## Answers to obtain before the form

- Owner: confirm the exact release AAB merged manifest, SDK list, destination domains, Supabase project region, public privacy/deletion URLs, encryption evidence, and actual production retention/backups without granting this task production access.
- Owner and counsel: decide each Play data type's collected/shared/optional/ephemeral classification, purposes, deletion disclosures and service-provider treatment. **For counsel review.**
- Engineering: close the export and withdrawal gaps, verify uploaded-object erasure and surviving audit identity, then run account deletion on a disposable local stack. No such code change or test was made in this documentation task.

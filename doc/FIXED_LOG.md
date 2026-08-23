# 🛠️ Fixed Issues & Technical Resolution Registry (`FIXED_LOG.md`)

> Permanent engineering log of resolved bugs, root-cause analyses, database migrations, and architectural fixes to ensure knowledge retention across agent sessions.

---

## 1. Ephemeral Emoji & Reaction Synchronization Over Realtime Broadcast
- **Symptom:** Reactions sent on one device did not appear or float on peer viewer screens.
- **Root Cause:** Chat message tables should not store millions of throwaway reaction rows. Reactions needed an ephemeral pub/sub channel.
- **Resolution:**
  - Implemented `RealtimeChannel.sendBroadcastMessage(event: 'reaction', payload: {'reaction_type': type})` in `LiveChatController`.
  - Ephemeral floating reactions now sync between unlimited viewers simultaneously with zero database row cost.
- **Related Commits:** `v0.6 Milestone CP2`

---

## 2. Cross-Device Live Chat Visibility & Guest Mode RLS Policy
- **Symptom:** Text messages sent from an authenticated mobile phone were not visible on the Web (Chrome) viewer screen.
- **Root Cause:** `chat_messages` table had `CREATE POLICY chat_messages_select_authenticated TO authenticated USING (true);`. Unauthenticated guest viewers received 0 rows and 0 realtime insert events.
- **Resolution:**
  - Added migration `20260828090000_chat_messages_public_read.sql` changing SELECT policy to `TO authenticated, anon`.
  - Granted `chat_sender_info(uuid[])` execution to `anon` so guest viewers can also see sender display names, avatars, and role badges.
- **Related Commits:** `4ab4d6f`

---

## 3. Web (Chrome) Google OAuth Redirect & Dynamic Origin Resolution
- **Symptom:** Clicking "Sign in with Google" on Web redirected to `http://localhost:3000/?code=...` with `"Cannot GET /"` error when Flutter was running on dynamic ports.
- **Root Cause:** Passing `redirectTo: null` on Web defaulted to Supabase's static Site URL (`localhost:3000`).
- **Resolution:**
  - Updated `supabase_auth_service.dart` to pass `redirectTo: kIsWeb ? Uri.base.origin : SupabaseConfig.oauthRedirectUrl`.
  - Configured Supabase Dashboard Redirect URLs with `http://localhost:*/**` and `http://localhost:*`.
- **Related Commits:** `4ab4d6f`

---

## 4. Google Account Switching & Sign-Out Role Cache Purge
- **Symptom:** Clicking "Sign in with Google" after logging out silently re-selected the previous Google account without showing the account chooser dialog.
- **Root Cause:** Google OAuth 2.0 defaults to reusing browser session cookies unless `prompt=select_account` is explicitly requested. Additionally, `AppProvider.logout()` did not reset cached `_isAdminFromRoles` flags.
- **Resolution:**
  - Added `queryParams: {'prompt': 'select_account'}` to `SupabaseAuthService.signInWithGoogle()`.
  - Purged `_isAdminFromRoles = false`, `_isMasterAdminFromRoles = false`, and `_permittedAdminOrgIds = []` inside `AppProvider.logout()`.
- **Related Commits:** `3e3870a`

---

## 5. Streamer Application to Admin Queue Pipeline Break (UUID Syntax Mismatch)
- **Symptom:** Submitting a broadcaster application on mobile showed success locally, but the application never appeared in the Web Admin "Verification Queue".
- **Root Cause:**
  - `broadcaster_application_sheet.dart` generated IDs using legacy string format `'app_${DateTime.now().millisecondsSinceEpoch}'`.
  - PostgreSQL's `broadcaster_applications.id` is a strict `UUID` type. PostgreSQL rejected the write with `PostgrestException 22P02 (invalid input syntax for type uuid)`.
  - `AdminDatabaseService.submitApplication` caught the exception and fell back to local storage without writing to Supabase.
- **Resolution:**
  - Created proof test [`test/broadcaster_application_uuid_verification_test.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/test/broadcaster_application_uuid_verification_test.dart).
  - Replaced legacy string ID generation with `newId()` (RFC4122 v4 UUID).
  - Added `_looksLikeUuid()` guards to `loadOrgVenues`, `loadOrgSpeakers`, and `loadOrganizationProfile` in `AdminDatabaseService` to prevent 22P02 errors on seed mock IDs.
- **Related Commits:** `6c6070b`

---

## 6. Streamer Mode Role-Gating & Live Application Status Sync
- **Symptom:** Non-streamer viewers had access to the "Broadcaster / Streamer Mode Active" toggle, and applicants' phones remained stuck on "Application Under Review" after admin approval.
- **Root Cause:**
  - `_applySessionUser` unconditionally set `_isStreamerModeEnabled = true` for all authenticated users upon sign-in.
  - `settings_screen.dart` used a mock fallback (`firstWhere`) instead of retrieving the active user's real Supabase application record.
- **Resolution:**
  - Added `isApprovedStreamer` gate (`_isApprovedStreamer || _isAdminFromRoles || _permittedAdminOrgIds.isNotEmpty`) in `AppProvider`.
  - Added `loadMyApplication(profileId)` and `checkIsProfileStreamer(profileId)` in `AdminDatabaseService`.
  - Disabled the Streamer Mode toggle in Settings for unapproved users and clearly marked them as Viewer accounts.
  - Added `refreshMyApplicationAndStreamerStatus()` to automatically detect admin approvals, promote user to Streamer, unlock the studio, and trigger the in-app celebration notification (`🎉 Broadcaster Application Approved!`).
- **Related Commits:** `5d5d410`

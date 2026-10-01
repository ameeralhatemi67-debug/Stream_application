# Organization broadcasting: owner setup and recovery

Pilot backend: **streamer_app**, project **zkkmfjsjouqzibvnzkau**. Pilot channel: [@amiralhatime4831](https://www.youtube.com/@amiralhatime4831). These are owner-selected test resources; implementation does not enable the pilot or change the hosted project automatically.

## Configure the backend

1. Review the phase migrations and function source, then apply them to the dedicated test backend. Keep `organizations_v1_enabled` disabled and explicitly allow only the pilot organization through `org_v1_set_pilot`. Keep termination and reconciliation running when starts are disabled.
2. In the Google Cloud project enable YouTube Data API v3. Configure a **web application** OAuth client, the consent screen, and the actual channel owner's Google account as a test user. The owner must select the account owning the intended YouTube channel; an app sign-in or Studio delegation is not publishing consent.
3. Register this exact OAuth redirect URI:
   `https://zkkmfjsjouqzibvnzkau.supabase.co/functions/v1/channel-authorization`
4. Set Supabase Edge Function secrets: `YOUTUBE_OAUTH_CLIENT_ID`, `YOUTUBE_OAUTH_CLIENT_SECRET`, `YOUTUBE_OAUTH_CALLBACK_URL` (the URI above), and `PUBLIC_APP_ORIGIN` (the pilot app's HTTPS origin, without a path). Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. Never put client secrets, service keys, refresh tokens, or stream keys into Flutter defines, git, screenshots, or issue reports.
5. Deploy `channel-authorization` with JWT verification disabled **only for its Google callback**. POST requests validate the signed-in account themselves. Configure the app's Supabase Auth site URL/redirect allowlist separately; channel consent is a different flow.
6. Build the app with the pilot Supabase public URL/key and `PUBLIC_APP_URL` set to the HTTPS app URL. Configure the existing Firebase reminder integration using public Firebase defines and its server credentials in secret settings. No new email provider is needed.
7. Enable live streaming on the channel in YouTube Studio and confirm its eligibility before the pilot. On the organization owner account open **YouTube connections → Connect YouTube**, consent, and verify the returned channel title/identity. Organization presenters need platform organization broadcasting approval, active membership, a video/audio grant, and an accepted assignment; they do not connect a personal channel.
8. Deploy `broadcast-control` and `reconcile-broadcasts`. Both use `verify_jwt=false` with explicit authorization: validated account JWTs for control, a dedicated `BROADCAST_RECONCILE_KEY` secret for the job. Schedule an authenticated **POST every minute** to `/functions/v1/reconcile-broadcasts` through Supabase Cron with the key in Vault/secret settings and an Authorization header. The job replenishes four weeks of Riyadh occurrences, observes provider transitions, completes revoked sessions, retires feeds and checks replays. Run the existing `dispatch-upcoming-reminders` job with its configured Firebase server credentials. Neither job may depend on an open management tab.

OAuth requests use PKCE and account/session-bound, ten-minute, single-use state. Only server-validated `channels.mine` results become connections. Refresh tokens are encrypted in Vault; client-visible rows contain channel identity/status only. Changing channels or disconnecting requires all preparing/live/ending shows to finish. Ownership transfer fences the connection until the incoming owner reconnects.

Google production OAuth readiness and the real three-show pilot remain release gates. A testing consent screen is not evidence of production approval. See [Google's server OAuth guide](https://developers.google.com/youtube/v3/live/guides/auth/server-side-web-apps) and [Supabase Vault](https://supabase.com/docs/guides/database/vault).

## Recovery

- Consent cancelled or expired: return to YouTube connections and start a new consent attempt. A newer attempt invalidates older callbacks, including callbacks already exchanging a code.
- Permission/channel revoked: publishing stays blocked. The owner reconnects through the consent flow; an arbitrary watch link cannot restore authority.
- Provider write timed out: reconcile the recorded session operation before attempting creation again. Do not create replacement streams manually while an operation is unresolved.
- Termination pending: stop the sender, then complete the specific broadcast in YouTube Studio if the backend cannot do so. Complete the broadcast before deleting its bound feed. Keep its session visible as pending until reconciliation confirms completion. [YouTube feed deletion rules](https://developers.google.com/youtube/v3/live/docs/liveStreams/delete).
- Replay processing/missing: report the actual provider status. YouTube archival is best effort, without a promised backup recording. [YouTube archive conditions](https://support.google.com/youtube/answer/6247592?hl=en).

## Pilot evidence required

Record three distinct session IDs, YouTube broadcast/feed IDs and public watch URLs on this channel, with Android and OBS senders. Verify separate playback, chat, moderation, ending and membership revocation. Confirm OBS remains healthy after closing management, and test physical Android reconnect/device transfer and lifecycle behavior. Record timestamps and sanitized outcomes, never ingest credentials. A bundle or automated test does not replace this pilot.

# Streaming regression repair — 2026-10-04

The connection regression is repaired in source and on the owner-designated `streamer_app` backend (`zkkmfjsjouqzibvnzkau`). The configured Android APK is built. Real Google consent and camera/microphone → YouTube playback still require an attached phone and owner action; no real broadcast was started for this verification.

## What failed and what changed

The initial hosted backend had the new database migrations but no Edge Functions. After deploying channel authorization, the real Connect POST returned 401 before Google consent or an OAuth intent was allocated. Both channel and broadcast handlers passed a lowercase `authorization` header to Supabase JS. Its uppercase default `Authorization` collided with that header, so Auth rejected the request. `channel_auth_header_check.mjs` reproduces the rejection using the real SDK (2.117.2) with synthetic credentials/fetch responses. Canonical header casing plus explicit `getUser(token)` verifies the forwarded session. The Flutter service now explicitly includes its current access token, too.

The channel screen's single generic catch message mentioned ending active shows regardless of the failed action. It now distinguishes sign-in, approval, platform setup, browser launch and an actual active-show conflict.

Google consent returns to a fixed Android deep link, registered in the APK manifest, rather than the old web return page. A fixed platform suffix selects the return route; the original single-use database state and PKCE verifier still authorize the account operation. No code, token or stream key appears in that return URL. The SDK ignores this non-auth callback because it contains no auth parameters.

The personal streaming journey now selects a sole connected personal channel automatically and defaults to Android phone. It displays the channel name without a repeated confirmation checkbox. Multiple destinations retain explicit choice/confirmation. The streamer enters a title, previews the camera, then taps Go live. Preview does not send the encoder; it may allocate an upcoming YouTube broadcast. Leaving preview cancels the prepared session. Preview has start controls in portrait and landscape and avoids mounting the live room/chat before starting.

## Hosted repair and recovery

The deployed functions are ACTIVE: channel-authorization (version 5), broadcast-control (version 3), reconcile-broadcasts (version 3), as read back on this date. User-facing functions verify the actor inside their handlers; reconciliation requires a dedicated scheduler secret. Credentials remain server-side.

The owner explicitly approved the recovery job after automatic approval review rejected installing a persistent job capable of ending/deleting provider resources without that specific approval. `doc/broadcast-recovery-schedule.sql` records the reviewed job. The key is configured in Edge secrets and Vault without recording its value. The minute job is active.

Its first runs exposed SQLSTATE 42702: `broadcast_reconcile_claim()` declared a record `s` and reused `s` as an UPDATE table alias. A new migration renames the record and qualifies the revision increment. Subsequent job runs succeeded and the Edge response was 200, `{"complete":0,"pending":0}`. A successful cron SQL submission alone is not treated as proof of successful HTTP work.

New hosted migrations match local files:

- `20261004152527_broadcast_recovery_extensions.sql`
- `20261004153156_fix_broadcast_reconcile_claim.sql`

The service-role claim RPC executes; anon/authenticated cannot invoke it or access the cron schema. Supabase's managed `net` schema retains its platform grants; the job secret is not accessible through client cron access. No change to public API exposed schemas was made.

## Verification

| Check | Result |
| --- | --- |
| Real SDK header regression | Rejected before fix; verified after fix |
| Actual Edge handler tests with stubbed network | PASS: signed/unsigned requests, permission/setup/active-show status codes, fixed native routes, cancelled consent and replayed state |
| Real approved account preflight | PASS in a rollback-only transaction: consent begin/consume/commit, Vault storage, personal session creation, phone reservation and provider context |
| Device freshness gate | Stale stored device initially refused reservation; test modeled the normal fresh app heartbeat inside the same transaction, then rolled it back. The 90-second server gate was retained |
| Recovery RPC and client authorization | PASS, rollback-only |
| Scheduled HTTP response | 200; zero pending work |
| Flutter analyzer | Zero issues |
| Full Flutter suite | 982 tests passed |
| English/Arabic catalogs | Organization keys symmetric |
| Native preview tests | PASS: no encoder send before Go live, start after tap, cancellation on Back, landscape, Arabic and narrow enlarged text |
| Visual check | EN/AR studio rendered with the app fonts; settled button/focus state inspected (`studio_en.png`, `studio_ar.png`) |
| Configured Android debug APK | Built successfully |
| Physical phone | Not attached (`adb devices -l` empty) |

The account preflight used the owner's public handle `amiralhatime4831` to locate an approved account, an existing auth session and primary device. The channel ID and refresh token in the test were synthetic. All test channel, session, provider, Vault and heartbeat changes were rolled back. A final read found zero channel connections and provider rows, plus the one intended recovery scheduler key. No real Google credentials were read for these tests.

APK: `project/build/app/outputs/flutter-apk/Hadayah-streaming-repair-debug.apk` (test build, same bytes as `app-debug.apk`). Package: `sa.hadayah.streamer_app`. Native scheme: `sa.hadayah.streamerapp`. Backend host matches the owner-designated project. SHA-256: `F40D21753029788F578CCEE87F35333C4890DB1016473BBABFE94E525F55EC73`.

## Streamer steps and remaining acceptance

1. Install the updated APK. The previously installed phone build has not been replaced by this task.
2. Sign in with the approved Hadayah account. Open Settings → YouTube connections → Connect YouTube. Choose the account/channel that owns `@amiralhatime4831` and grant the Google permission. This is a one-time channel connection; platform Cloud/Supabase settings belong to the operator.
3. Confirm the returned screen shows the real connected channel. Open Broadcast studio, enter a title and select Preview camera. Android phone is already selected.
4. Grant camera/microphone permission if prompted. Tap Go live when ready. Check playback on YouTube and a second Hadayah viewer, then End broadcast.
5. Verify one interrupted show and recovery cleanup on real YouTube before closing acceptance.

If YouTube reports live streaming is disabled, check [YouTube Studio](https://studio.youtube.com/) and [the current YouTube live-streaming requirements](https://support.google.com/youtube/answer/2474026?hl=en), checked 2026-10-04. This task did not verify the channel's private YouTube eligibility or Google consent configuration through a real authorization.

## Public-release cleanup note

Retain the recovery job after public launch: it repairs interrupted/end/revocation work and is part of the live feature. It is not a temporary test schedule. No diagnostic job was installed.

Temporary diagnostic SDK/handler directories, staging patches and the Flutter screenshot harness were removed after verification. Before public release, keep synthetic regression tests and rollback-only SQL scripts as development checks, and never run them as startup/deployment migrations. Do not publish this debug APK as the release candidate; store signing and the existing release acceptance gates remain separate work.

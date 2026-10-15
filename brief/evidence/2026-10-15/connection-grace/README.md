# Connection-loss grace window and guest-permission cleanup — 2026-10-15

## Owner decision (2026-10-15)

- Phone dies or the app is killed → the live must end.
- Connection lost → viewers see "we'll be right back / connection issues". If the broadcaster comes back before the window runs out, the live continues; otherwise it ends.

## What existed before

| Situation | Before | Gap |
|---|---|---|
| Phone loses internet | Engine retried 60 s, then asked the server to end the broadcast. It reported `interrupted` to the server first. | Both the report and the end request need the internet that was just lost. |
| Server-side expiry | `sweep_stale_live_flags()` ended phone sessions reported `interrupted` for 120 s. | Not scheduled on hosted (only `hadayah-reconcile-broadcasts` runs), and it ignored OBS sessions. |
| Phone dies / app killed | Nothing reported. YouTube auto-stop is off by design. | Broadcast stayed LIVE indefinitely. |
| Viewer | Small banner "the broadcaster's connection dropped" when `ingest_state='interrupted'`. | Only shown when the phone itself could report. |

## What was built

- `supabase/migrations/20261015190100_broadcast_connection_grace.sql`:
  - `broadcast_observe_feed(id, token, active)`, service-role only and bound to the reconcile reservation. It records YouTube's feed status. A lost feed marks the session interrupted once per outage (start time kept). A returning feed clears that mark unless the phone has reported since the outage began, because the phone's newer report wins.
  - `sweep_stale_live_flags()`: any sender mode; ends a live session interrupted for more than **120 s** (`end_reason='ingest_lost'`). Backstop: a feed YouTube has not received for **10 minutes** ends it even if the phone still says it is sending.
  - `broadcast_reconcile_claim()` runs the sweep first, so the every-minute reconcile job enforces the window and completes the YouTube broadcast in the same pass. No new cron job.
- `supabase/functions/_shared/broadcast_control.ts`: on each scheduled observation of a live broadcast, reads `liveStreams.status` (`streamStatus='active'` and `healthStatus` not `noData`) and calls `broadcast_observe_feed`. User-triggered operations never probe.
- App: `RtmpPublishEngine.recoveryWindow` is now 120 s (was 60 s), matching the server window. Viewers see a full-screen "We'll be right back" card over the video (English and Arabic) instead of the small banner; the LIVE badge is hidden while interrupted.

Timing on a dead phone: YouTube marks the feed inactive within seconds to about a minute. The next reconcile pass (at most a minute) shows viewers the card, and the broadcast ends about 2 minutes after that, typically 3 to 4 minutes in all.

## Guest permissions (hosted)

Hosted `anon` held SELECT/INSERT/UPDATE/DELETE on 27 public tables and both public views. These were leftovers from Supabase's old auto-expose default; local builds from migrations never had them. Every guest policy was SELECT-only and both views are not updatable, so nothing could use the write grants.

`20261015182953_revoke_legacy_guest_grants.sql` was applied to hosted on 2026-10-15 at the owner's request. Guests now hold SELECT on exactly the 10 intended objects: academic_categories, app_flags, broadcast_sessions, chat_messages, chat_stream_settings, organization_public_profiles, streamer_custom_placeholders, streamer_public_profiles, tags, terms_and_conditions. New tables created by `postgres` (our migrations) no longer grant guests anything. The remaining default for Supabase's internal `supabase_admin` role cannot be changed by the project and is not used by our migrations.

Not changed (report only): hosted `authenticated` also holds some grants beyond the migration contract, for example DELETE on profiles/organizations and write on audit_logs, device_sessions and the public views. No RLS policy allows those commands, so they are unusable today. Cleaning them is a separate, approval-gated step.

## Verification

- `supabase/tests/broadcast_connection_grace.test.sql`: 36/36 on a disposable copy (`grace_20261015`) of the repaired local database.
- Whole SQL suite on that copy: 34 files, **744 ok, 0 not ok**.
- `node --experimental-transform-types brief/tools/broadcast_control_check.mjs`: passes, including the new dropped-feed case (only scheduled observations probe).
- Flutter: `flutter analyze` 0 issues; full suite 1,104 passed, 0 failed (one run showed a third failure that did not repeat in two later runs).

## Not deployed

The grace-window migration and the `reconcile-broadcasts` / `broadcast-control` Edge Functions (shared code changed) are **not** on hosted yet. Deploying needs the owner's approval. The app change ships with the next build. Not verified on a physical phone: kill the app mid-broadcast and watch a second device.

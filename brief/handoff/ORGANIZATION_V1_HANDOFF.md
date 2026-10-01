# Organization broadcasting V1 — next-agent handoff

Date: 2026-10-01 (updated after Phase 4 completion by Claude). **Phase 4 is implemented, locally verified and committed locally (not pushed)** together with the owner work it depends on (see "Git and preserved work"). Rollout stays disabled. This is not a shipping claim: hosted deployment, real OAuth, physical Android and the real three-show pilot are still required.

## Start here

1. Read this file, `doc/organization-v1-owner-setup.md`, `brief/evidence/2026-10-01/organization-v1/README.md` and ADR-009 (including its Phase 4 completion notes) in `Core_files/decisions.md`.
2. Read `git status`. Preserve owner changes and both stashes. Work on master; no feature branch, reset, clean, stash-all or add-all.
3. Remaining work is **pushing (owner), hosted setup and the pilot** (below).

Repository: `C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app`. Flutter commands run in `project/`; Supabase and Node checks run in the repository root.

## Authority and scope (unchanged)

The human approved the full Organization Broadcasting V1 plan. Accepted scope: multiple memberships; one active broadcast per person; one owner-consented, verified YouTube channel per organization; at most three simultaneous organization shows; Android and OBS publishing; web management/viewing; independent personal and organization broadcaster approval; owner/co-owner/manager/moderator roles with separate broadcasting grants and no platform privileges; per-occurrence presenter acceptance (Riyadh time, four weeks, one hour default); session-specific playback/chat/moderation; seven-day single-use account/verified-email invitations; two-party ownership transfer with no active shows and channel reconnection; shared server authorization closing STREAM-D8. No prerecorded uploads, payments, multiple channels, private viewing, desktop capture or iOS publishing in V1. Rollout disabled; explicit pilot organizations; a real three-show pilot and physical Android checks are mandatory.

## What exists

| Phase | Commit | State |
| --- | --- | --- |
| 1: memberships and approval | `31aebbf` | committed, pushed |
| 2: server channel OAuth | `2149722` | committed, pushed |
| 3: canonical scheduled sessions | `cb1c10f` | committed, pushed |
| 4: client, events, recovery | `feat(organization)` commit after `cb1c10f` | committed locally, **not pushed** |

Phase 4:

- **Studio/session client** (previous agent): canonical destination/assignment studio with explicit channel confirmation, volatile RTMPS credentials, retry limited to encoder waits, serialized Start/End, truthful termination-pending recovery, credentials cleared on sign-out/displacement/end; `/shows` scheduling, Riyadh editing, acceptance and scoped End; exact session rooms, chat/presence IDs, concurrent cards, replay states. Migration `20261001114055_organization_v1_client_events.sql`.
- **Durable events and push** (this continuation): `20261001160000_organization_v1_notifications.sql` adds `org_v1_events` written only by triggers/RPCs (invitations, join requests, assignments/edits/cancellations/answers, presenter reminders, grant/role changes, confirmed starts to followers and leadership, server-initiated endings, transfer proposed/withdrawn/completed), per-recipient dedupe, `org_v1_events`/`org_v1_mark_events_read` RPCs, `notification_push_preferences`, and `claim_org_v1_event_pushes` for the new `dispatch-organization-events` Edge Function (shared `_shared/fcm.ts`, `_shared/org_event_text.ts`; dedicated `ORG_EVENTS_DISPATCH_KEY`). The client shows unread events once in the notification center (reading syncs to the server), handles `org_event` pushes (validated-ID routes only) and the web push worker shows them.
- **Journeys**: new `/organizations` hub (Settings → Organizations, every signed-in account) with in-app invitations (verified-email binding on read), memberships with V1 availability, incoming/outgoing transfer banners (withdraw, accept → reconnect channel), owner setup checklist and activity list. Membership panel lists/withdraws pending invitations, confirms revoke/transfer, shows grants, maps server refusals. Invitation screen shows organization/role and explains wrong-account/expired. Shows screen accepts an organization link, explains not-enabled organizations and maps errors.
- **Availability**: `org_v1_memberships` rows carry `v1_enabled` and transfer state; Safety console gets **Organization pilots** (Master Admin, `org_v1_set_pilot`) and two new switches: `organizations_v1_enabled` and `organization_applications_open` (rollout switches count as off when unread). New organization applications are trigger-refused while the switch is off; both application selectors follow it.
- **Fixes**: the deployed web app uses hash routes, so the consent callback now returns to `/#/channel-connected?status=…` (failures return to the app, not a JSON page) and invitation links are `https://<origin>/#/org-invite/<id>?token=…`. The 21 older test failures were tests driving the offline write fallback that Phase 1 removed; they now use `test/support/fixture_application_db.dart`. The studio's literal "Android" label is localized (G6).

## Verification (this continuation)

- `flutter analyze`: 0 issues. Full `flutter test`: **968 passed, 0 failed**. New `test/organization_v1_journeys_test.dart`: 33 tests incl. en/ar, 320 px at 2× text.
- Disposable SQL (`node brief/tools/organization_v1_db_check.mjs <docker.exe>`): **155/155** (22 + 24 + 36 + 25 + 48 new events). Database `org_v1_audit_20261001` only.
- Provider checks and the new `node --experimental-transform-types brief/tools/org_event_text_check.mjs`: pass.
- Edge Runtime v1.74.3 bundles: `dispatch-organization-events`, `channel-authorization`, `broadcast-control`, `reconcile-broadcasts`.
- Release web build (`PUBLIC_APP_URL` set) and Android debug APK build. A hash invitation link opens the invitation screen in the release web build.
- Gates: 23 PASS / 5 INFO / 3 FAIL. Remaining FAILs are not this feature: G2d gradients and G3 raised-hand glyphs in owner's uncommitted work (welcome/entry background; LIVE-03 chat), G11a secret-bearing files in old nested `.claude/worktrees` (not read, changed or deleted).
- Not verified: hosted security advisors, real OAuth, real push delivery, physical Android, real three-show pilot.

## Git and preserved work

origin/master: `cb1c10f`. Local master: the Phase 4 commit on top (not pushed; the owner pushes). Stashes `d646b945…` and `d53c178e…` untouched.

Phase 4 could not be separated from owner work, so on 2026-10-01 the owner chose **"Phase 4 + needed dependencies"**: the commit holds 98 paths — every Phase 4 file at its full working version (including owner edits inside those files) plus the owner work Phase 4 code needs: reminder push (`reminder_push_service.dart`, `upcoming_schedule_service.dart`, `reminder_firebase_config.dart`, Upcoming tab/editor, `firebase-messaging-sw.js`, Firebase `pubspec` entries and generated Windows plugin files), the live chat layout/widget/actions sheet, verification-queue history (`admin_database_service.dart`, `admin_hub_screen.dart`, `broadcaster_application_model.dart`, migration `20260929010000` and its test), the Discovery feed card height change, the charity parent image, and the owner tests those need. Verified before committing in an isolated copy of HEAD + exactly these files: analyzer 0, **952 tests passed, 0 failed**. All other owner work stays uncommitted in the working tree (for example migration `20260928010000`, welcome/entry background, map, admin views, launcher icons, brief documents). Not separately verified: the disposable SQL suite against the committed migration set alone (it ran with all local migrations applied). Never rerun the old stage/restore scripts.

## Remaining work (in order)

1. **Push** (owner) when ready.
2. **Hosted setup** (owner approval required for every hosted change), per `doc/organization-v1-owner-setup.md`: Vercel env vars (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PUBLIC_APP_URL=https://stream-application-ten.vercel.app`, Firebase web values) and redeploy; Supabase Auth redirect allowlist; apply migrations `20261001095030`…`20261001160000` to the pilot project; deploy the four functions; secrets (`YOUTUBE_OAUTH_*`, `PUBLIC_APP_ORIGIN`, `BROADCAST_RECONCILE_KEY`, `ORG_EVENTS_DISPATCH_KEY`, Firebase); minute cron jobs for reconciliation and event dispatch; then run the hosted security advisors.
3. **Pilot**: enable the organization-application switch only to onboard the pilot organization, approve it, enable it in Organization pilots, owner connects `@amiralhatime4831`, invite presenters, schedule three concurrent shows (Android + OBS) and record the evidence listed in the setup guide. Physical Android lifecycle/reconnect/transfer checks.

Owner-selected pilot resources: Supabase **streamer_app** `zkkmfjsjouqzibvnzkau`; channel https://www.youtube.com/@amiralhatime4831; web app https://stream-application-ten.vercel.app (currently the Phase 3 build with no backend configured). Google callback: `https://zkkmfjsjouqzibvnzkau.supabase.co/functions/v1/channel-authorization`.

Tooling: Flutter `C:/Users/User/sru/flutter/bin/flutter.bat`; Node 22; Docker Desktop with container `supabase_db_P6_accept_disposable` (database `org_v1_audit_20261001`); Edge Runtime image `public.ecr.aws/supabase/edge-runtime:v1.74.3`. Never run linked/production commands without owner approval.

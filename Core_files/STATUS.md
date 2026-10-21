---
type: status
project: Streamer_app
updated: 2026-10-21
phase: release_hardening
health: release_blocked
---

# Project status: Streamer App

## Taysir in Hadayah Live: the mosque lessons programme, 2026-10-21

Owner request: build the reviewed prototype (artifact `PPAvDrjpoiZBV5MbGm8tNc`) into the app on our Supabase, reached from the Settings logo (ADR-013, ADR-014). Local commits only; **the migration is not deployed to hosted**.

- **Backend (not deployed):** `supabase/migrations/20261021120000_taysir_lessons_programme.sql`: districts, mosques, an org-scoped preacher roster, series, lessons, reports, user flags, an action log, and viewer reminders, follows, attendance and preferences. Authority is `activities.coordinate` / `activities.submit` through `has_permission()`; every write is a security definer function; phone numbers are private with a logged reveal; single-use hashed invitation links replace Taysir's shared password; `export_my_data()` gains a `taysir` section. `supabase/tests/taysir_lessons_programme.test.sql` 62/62 on a disposable clone; the whole SQL suite there gives 935 ok and only the 3 pre-existing `rls_catalog` failures.
- **App:** `project/lib/features/taysir/`: Umm al-Qura prayer times and Hijri dates, clash and series rules, Excel-safe CSV, Supabase and sample-data repositories, `TaysirController`, and every prototype screen (discover, lessons with filters and week grid, lesson/series/preacher/mosque pages, map on the tri-city pack, me, saved, notifications, invitation claim, my lessons, the submit wizard, lesson reports, permissions, and the coordinator console: overview, review, preachers, mosques, statistics, action log, team) with phone tabs and the gold website layout, in Arabic and English (about 780 strings each).
- **Found and fixed while testing:** the controller notified listeners while widgets were building (a load starts in the shell's `initState`, `TaysirPage.build` and the provider's account update), which throws in debug builds; it now notifies after the frame. Overflows at 2x text on a 360 px phone: segmented controls (now scroll sideways), the wizard's Back/Next row (stacks when it does not fit), the prayer strip's columns (grow with the text) and the console's weekly chart and team rows. Search boxes drew the app theme's outline inside the pill. The coordinator's Me card said "no reports" until the console had been opened (staff data now loads with the catalogue). Switching language from Taysir's header left the tabs, app bar and sample banner in the old language and did not update push-reminder language; both Taysir language controls now go through `LanguageSwitcher`, which rebuilds the tree once after a switch (this also covers any Hadayah screen with the same pattern).

Verification: analyzer 0 issues. New `test/taysir_screens_test.dart` (48 tests) on the real router with sample data: the Settings switch's `/feed` → `/taysir` redirect; discover at phone and 1280 px; the header language switch; lesson filters (sheet, shared link, website panel and week grid); a guest asked to sign in to set a reminder; reminder set and removed; share card copied; a coordinator cancelling a session and the reminded viewer counted; the submit wizard to "Send for review" (and a coordinator publishing directly); review approve, reject with a reason and undo, and select-all; the roster phone reveal written to the log and an invitation link; the claim flow (guest, signed in, used link); the persona switcher; notifications marked read; and a layout sweep of 37 page/role pairs at 360 and 1280 px, Arabic and English, text 1x and 2x, with no overflow or exception. Full suite: see the ledger block. Looked at in a browser (debug web build, sample data) at 375 and 1280 px in both languages; the ledger lists which pages.

Not done: hosted deployment (needs the owner's yes), enabling Taysir for the Hidayah organization and granting the first coordinator, push reminders for Taysir (stored, not sent by `dispatch-upcoming-reminders`), the evening digest (stored only), a QR code on the share card, post-lesson photos, importing the real Taysir roster, and the live Taysir site's security fixes (research report section 6.1). Not checked on a phone.

## Hidayah Gold is the only design; the logo switches to Taysir, 2026-10-21

Commit `efed22a` (ADR-013). The green design and its runtime palette remap (`paletteColor` and about 2,400 call sites) are gone; gold is the source token set. Settings → About's logo now switches the application between Hadayah Live and Taysir (`AppExperience`, a device preference); the retired `hidayah_palette_enabled` key is deleted on start. Gold launcher icon on Android, iOS and web; splash on night slate; both Android launcher aliases kept. Website layouts are always on at 1024 px and wider; the overflows that exposed (live room identity row, studio header, quiet discovery panel, header wordmark, system-bar insets) are fixed, and gold's success colour darkened to `2D7647` for contrast. Verification at that commit: analyzer 0; full suite 1,556 passed, 10 skipped.

## Arabic plurals for admin and moderation counts, 2026-10-21

Follow-up to the quick wins below (audit section 5.3). `admin.tag_broadcaster_count`, `admin.pending_review`, `safety.live_viewers`, `safety.live_summary`, `moderation.stream_count` and `live.sender_delete_all_body` now have all six plural forms in both catalogs and are called with `.plural()` (admin hub, tag moderation, safety live list, chat moderation, chat sender sheet). `safety.live_summary` counts the streams; its `{viewers}` slot takes the `safety.live_viewers` phrase, so both numbers agree with their nouns ("بثّان مباشران · 7 مشاهدين"). English is unchanged apart from singular forms ("1 broadcaster", "1 application", "1 stream", "1 message" instead of "message(s)").

Verification: analyzer 0 issues; full suite 1,603 passed, 11 skipped (was 1,602 + 11); `test/hidayah_quick_wins_test.dart` gains an Arabic/English case for these keys (forms 0/1/2/3–10/11–99/100+, 103 and 250 to show CLDR reads the last two digits). Not checked on a device.

## Hidayah Gold audit: engineering quick wins, 2026-10-21

From `brief/audit/2026-10-21_USER_FLOW_AND_ATTENTION_AUDIT_HIDAYAH_GOLD.md` (sections 3, 4, 5.3, 6, 9). Product decisions in that report (removing the gate, hiding test channels, categories, brand spelling, lecturer terminology, language default) are untouched.

- **Lighter first load.** The app bundles `assets/logo/hidayah_mark.png` (208 px, 33 KB) and a `3.0x/` variant (312 px, 56 KB) instead of the 2.9 MB `clearlogo2.png`, which stays on disk as the master for the launcher-icon script; `brief/tools/make_hidayah_display_logo.py` rebuilds both. `pubspec.yaml` lists each variable font once: the engine downloads every entry and ignores `weight`, so IBM Plex Sans and Reem Kufi were each downloaded twice on the web.
- **Returning guests.** Consent stashed by `recordConsent`, the guest name and avatar, and follows made without an account are read back at start (`AppProvider._restoreLocalViewerState`). The splash opens Discovery for a guest who already agreed and chose a name; the welcome screen's guest button does the same for them. Signing out forgets the guest. A session always wins over the guest record. Guest follows are not merged into the account on sign-in (follow-up).
- **Sign-in comes back.** Live chat's Sign in, the channel reminder sheet, the Upcoming tab's reminder and the gold header's Sign in push the welcome screen (`openSignIn`, `lib/core/routing/sign_in_prompt.dart`) and remember the page; after Google sign-in the router, splash and role picker open that page instead of Discovery. Stored for 30 minutes, in-app paths only, used once.
- **Channel page counts.** The gold channel page shows a dash, not "0 recordings / 0 playlists", until the archive has loaded (`AppProvider.isChannelArchiveKnown`); an empty YouTube answer counts as unknown because a failed request returns the same.
- **Arabic plurals.** `web.live_count`, `web.map_count`, `web.stat_*` (5), `map.cluster_label`, `map.cluster_list_title`, `map.web_offline_preparing`, `profile.lectures_count`, new `profile.playlists_count`, and the two slow-mode strings use easy_localization plural forms (all six forms in both catalogs). `main.dart` sets `ignorePluralRules: false`; the package default never selects Arabic's few/many forms. Admin and moderation counts (`admin.*`, `safety.*`, `moderation.stream_count`, `live.sender_delete_all_body`) still use fixed strings.
- **Snackbar font.** `snackBarTheme.contentTextStyle` names IBM Plex Sans Arabic / IBM Plex Sans with fallbacks, so Arabic snackbars no longer wait for a downloaded fallback font.
- **Web.** `web/index.html`: one Arabic + English description, `og:` title, description, image (absolute, on `AppIdentity.websiteUrl`; a test keeps them in step), locale `ar_SA` with `en_US` alternate; the boot splash spinner is neutral grey instead of green. `GoRouter.optionURLReflectsImperativeAPIs` is on (set in `AppRouter.build`), so pushed channel, live and sign-in pages show their own `#/...` address and can be shared or reloaded. The live page's back and minimize go to `/feed` when nothing is under them (they went to `/`, which has no route). Hash URLs are kept; path URLs and a `/watch/:videoId` route are the audit's next step.
- **Chat direction.** Each chat message takes its direction from its first strong letter (`firstStrongTextDirection`, `lib/core/utils/text_direction.dart`; emoji and digits are skipped), in the chat bubble, the broadcaster's last-messages overlay and the sender sheet. The sender name is isolated when the directions differ.

Verification: analyzer 0 issues; full suite 1,602 passed, 11 skipped (was 1,577 + 11); new `test/hidayah_quick_wins_test.dart` (25 tests: asset sizes and font list, guest restore and splash/welcome routing, sign-in return through the welcome redirect, the native login-callback and the role picker, live chat Sign in pushing over a live page opened from its link, dash-then-count on the gold channel page in both languages, Arabic and English plural output, snackbar font, `index.html` tags, message direction); en/ar catalogs key-symmetric. A release web build compiles; its `FontManifest.json` lists each font once and its assets hold the two mark sizes and no `clearlogo2.png`. Not checked: a real Google sign-in round trip on web or Android (the return path is covered by router and provider tests, not by OAuth itself), link previews as WhatsApp renders them, the site in a browser, and a physical phone.

## Replay checks no longer drain the YouTube quota, 2026-10-19

Cause of the 4 hosted sessions stuck in `processing_replay`: after a live, the reconcile job asked YouTube about the replay every minute (`liveBroadcasts.list` + `videos.list`, 2 units) until `videos.list` said `status.uploadStatus='processed'`. Public watch pages show what YouTube does: a finished live is watchable at once as a post-live recording, but turns `processed` only about 12 h later (the two sessions that settled took 12 h), so every normal live cost about 1,440 units. A recording YouTube did not keep (the two 14 s and 68 s lives from 2026-10-18 show "This live stream recording is not available") never turns `processed` and the video still exists, so those sessions were checked every minute for good. The other two (ended 09:43 and 10:35 on 2026-10-19) settled `available` at 21:45 and 22:37 UTC that night, before the fix was deployed.

Fix: migration `20261020075541_replay_check_backoff.sql` replaces `broadcast_reconcile_claim()`. After the live, checks run every 5 min in the first hour, every 15 min up to a day, then hourly, and failed checks wait the same way. Live, preparing and ending sessions keep 30 s. A replay still open 72 h after the end is settled as `missing` in SQL, and retrying a completed session's feed deletion stops after 7 days. `_shared/broadcast_control.ts`: a replay is `available` on `processed` or `processingDetails.processingStatus='succeeded'`, and `missing` on failed/rejected/deleted, processing `failed`, or 48 h after the end. Sessions past the live no longer read the broadcast (one unit saved, and a broadcast the owner deleted on YouTube no longer blocks the replay check with `broadcast_missing`). A feed deletion answered 404 counts as retired instead of being retried at 50 units each. Expected cost for a stuck replay: 95 checks on day one, about 24 a day after that, then none. That is about 140 units in total, against 2,880 a day before.

Verification: new `supabase/tests/replay_check_backoff.test.sql` 40/40 on disposable `replay_backoff_20261019` (a copy of `fastlive_new_20261019` plus the migration); the same file fails 10 assertions on the copy without it (1,440 checks a day, never settles). The other 37 SQL files give identical results with and without the migration (`rls_catalog`'s 3 failures predate it). Edge logic: a Node harness with a fake YouTube API, 12/12 (scratchpad, not committed; no Deno here). The committed version fails its first check. `tsc --strict` on the shared modules: 0 errors. No Dart change. **Not verified against real YouTube**: the API value YouTube returns for a recording it did not keep is inferred by elimination (still `uploaded`), not read with the owner's token.

**Deployed 2026-10-20 (owner said yes).** Preflight: the hosted claim, provider-step and operation-context bodies hash-matched the tested base, and both functions (v8) matched the pre-change source. The migration was applied through the MCP connector and stamped `20261020075541` (local file renamed). The hosted claim body now hash-matches the tested copy, and execute stays with service_role and postgres only. `reconcile-broadcasts` and `broadcast-control` were redeployed as v9 (`verify_jwt=false`); the deployed files equal the committed ones, and `broadcast-control` answers OPTIONS 200 and an unauthenticated POST with 401. Security advisors show no new finding. The cron's own responses show the effect: every run up to 07:55 UTC returned `{"complete":2}`, and from 07:56 they return `{"complete":0}` with no YouTube calls. The two remaining stuck sessions (`fdd40bd4`, `a2beb50a`) are now checked hourly, about 1 unit each. They should settle `missing` at their first check past 48 h (about 10:58 and 15:02 UTC on 2026-10-20). The SQL 72-hour settlement is the fallback. Not yet watched happening: the first hourly check and the 48 h give-up on hosted.

## Faster go-live, low-latency streaming and "hide the video when the live ends", 2026-10-19

Owner targets: viewers see a new live within 15 s (ideally under 3 s); camera-to-viewer delay 5–10 s (never over 12 s); ending as fast as starting. What changed (ADR-012):

- **Early YouTube handshake.** Opening the Broadcast studio on a phone with the presenter's own connected channel creates the session and prepares the YouTube feed, broadcast and binding in the background. Preview adopts it (title/video-audio choices made meanwhile are applied with `broadcast_update_personal`; the YouTube title follows on start). Closing the studio keeps it 90 s for reuse, then ends it; switching to OBS or another destination ends it at once. A preparation whose window passed is ended by the reconcile job (`stale_expired`).
- **Go live.** No second prepare at Go Live; the phone's first connect reuses the running preview encoder instead of reopening the camera; 1 s keyframes. `broadcast-control` now waits server-side (1 s checks, 15 s budget) for YouTube to receive the encoder, transitions, and waits for `live`, so one call usually confirms the live (was: phone retries every 3 s plus extra reads). Cached Google access token per warm function instance.
- **Lag.** New YouTube broadcasts use `latencyPreference: ultraLow` (falls back to `low` if YouTube refuses it for a channel). Ultra-low supports up to 1080p and no closed captions; our presets are ≤1080p.
- **Viewers see it live.** Every change into or out of `live` sends a content-free public Realtime broadcast (`catalog_changed`); the app re-reads the catalog and open rooms within ~1–2 s (was the 15/30 s feed poll and the room's 20 s poll).
- **End.** The page closes as soon as the camera stops; the server end continues behind it (unconfirmed ends still show the warning toast). `broadcast-control` answers End right after YouTube completes the broadcast; feed retirement and the replay check finish in the background (`EdgeRuntime.waitUntil`). An End tapped during Go Live stops the start's retries.
- **Hide the video when the live ends.** A switch in the studio (before starting) and in the live screen's ⋮ options sheet. When a live ends with it on, its video is added to `hidden_channel_content`; the owner shows it again from the channel page's long-press menu.

**Deployed 2026-10-19 (owner said yes):** migration applied to hosted through the MCP connector as `20261019155816` (local file renamed); `broadcast-control` and `reconcile-broadcasts` redeployed as v8 (`verify_jwt=false`). App changes reach users with the next build. Verification: analyzer 0; new Flutter tests in `broadcaster_studio_entry_test.dart` (7) and `phone_broadcast_end_test.dart` (3); full suite in the ledger block; new `supabase/tests/fast_go_live_and_hidden_replay.test.sql` 44/44 on a disposable copy, the other 36 SQL files identical with and without the migration (rls_catalog's 3 failures predate it: `hidden_channel_content` is missing from its anon allowlist, plus the admin-built copy's grant drift); edge logic checked with a Node harness against a fake YouTube API (not committed; no Deno here); Android debug APK builds. **Not measured on a phone or against real YouTube**: the second counts above are design targets until a physical test. Hosted checks after deploy: the five new/changed function bodies hash-match the tested local copy; guests cannot call the two new RPCs; no new security advisor finding; the first reconcile run on v8 returned 200 (`complete 4, pending 0`, real Google token and YouTube reads). Pre-existing, not changed here: 4 sessions have sat in `processing_replay` since 2026-10-18/19 and are re-checked on YouTube every minute (~11k quota units a day, above the default 10k). Fixed locally in the "Replay checks" entry above.

## Hide and share videos and playlists, 2026-10-19

A channel owner (a streamer on their own channel, or an organization owner) long-presses a video or playlist, in both designs, to **hide** it from viewers or **share** it. Hidden items stay on YouTube; the app only stops listing them. The owner sees them blurred with a "hidden" icon, everyone else does not get them at all (profile grids, playlist contents and the live page's recordings). Share sends the title and the YouTube link, and falls back to copying the link in browsers without a share sheet. Viewers can share too, but only the owner sees the hide option.

The list lives in `public.hidden_channel_content` (migration `20261019084719`, applied to the hosted project): everyone can read it, only the channel owner can insert or delete (`streamer_id = auth.uid()` or `owns_organization`). Checked on the hosted database with the owner, another signed-in user and a signed-out caller. `supabase/tests/hidden_channel_content.test.sql` covers the same cases for the local pgTAP run (not run here; Docker was off). Bookmarks a viewer saved before an item was hidden still open it; that is not filtered.

Debug builds now also list `MainActivity` as a launcher entry so `flutter run` works after the gold palette disabled the `DefaultLauncher` alias on a phone (debug installs show one extra icon).

## Hidayah Gold palette and website layouts, 2026-10-19

The Settings → About logo toggle now switches between the current green design and the **Hidayah Gold** proposal, for team comparison. Gold replaces the first gold draft: role-based tokens from the logo (`hidayah_gold.dart`), night-slate panels, minted gold primary actions lit from the top, and ink selected states. On windows 1024 px and wider, gold also switches five screens to website layouts: Discovery, Map, Streamer account, Live (video and audio-only) and the Broadcast studio, under a top navigation bar with a footer. All other screens, and phones, keep today's layouts with the new colours. Details: `Core_files/Desgin.md` ("Optional Hidayah palette"). Verification: analyzer zero issues; new `test/hidayah_web_layout_test.dart` (website layouts at 1024 and 1440 px in both languages, green and phone layouts unchanged); updated appearance tests; rendered-contrast suite 76/76 for both palettes. Screenshots were rendered with the real fonts through `test/web_design_capture_test.dart` (set `WEB_CAPTURE_DIR`); the live page and chat need a live backend, so its capture uses stand-ins. Not yet checked in a real browser session against live data or on a physical phone.

## Optional palette and Arabic default, 2026-10-18

Settings → About's existing application logo now switches between the normal palette and Hidayah gold/ivory/slate on a double-click or double-tap. The device preference is saved before applying and restored before startup. Hidayah uses the preview's already bundled IBM Plex Sans Arabic font; normal typography and layouts are retained. The follow-up correction restores bright gold gradients with dark ink labels, removes the gray tint over the gold profile header, and uses the supplied `clearlogo2.png` in-app. Android launcher aliases switch between the normal icon and the supplied gold artwork with the saved palette; MainActivity and OAuth callbacks stay enabled. Arabic is the fresh-install default, while the language toggle and a saved English preference remain supported. No backend or deployment change is involved. Verification completed: analyzer zero issues, full Flutter suite 1,547 tests passed, including the 10 appearance tests and 76 rendered-contrast cases across 19 screens/dialogs in both languages and both palettes. Android debug APK compilation and Android 16 emulator checks confirmed both launcher aliases, palette persistence after force-stop/restart in both directions, and the visible gold icon in the app drawer. Details and evidence paths: `Core_files/PALETTE_RESUME.md`. This is host/widget evidence, not a physical-device acceptance claim.

## iOS integration evidence, 2026-10-17

The active iOS contract is `brief/ios/IOS_PLAN_V2.md`; current state and checks are in `brief/ios/IOS_STATUS.md` and `IOS_PROGRESS.md`. The native shell, bundle identity, iOS 15/iPhone configuration, permission/URL/privacy setup and Apple entitlement are **E0: implemented, not run on iOS**. Shared Dart iOS-override tests provide **E1 Windows host evidence** for auth exchange, availability gates and UI reachability.

No native iOS build, simulator launch or iPhone run has been recorded; E2/E2S/E3 are not claimed. In particular, WKWebView live/VOD playback and prevention of YouTube Errors 150/152/153 remain E0 assumptions, despite historical cross-platform wording in older records. The origin/referrer implementation is unchanged.

HTTPS organization invitations currently open the browser. Associated Domains and a non-auth invitation-link consumer are deferred; the custom OAuth URL scheme is not universal-link proof. W11's Apple deletion/public-policy blockers and W13's missing native build log remain open. Paid enrollment is deferred; Debug must stay free of paid entitlements.


## Connection-loss grace window, 2026-10-15

Owner rule: lost connection → viewers see "We'll be right back"; the live continues if the broadcaster returns within 2 minutes, otherwise it ends; a dead phone ends the live. Before today a dead phone stayed LIVE forever and the 120 s sweep never ran on hosted. Now the every-minute reconcile job checks YouTube's feed health, enforces the 2-minute window for every sender mode (plus a 10-minute no-feed backstop), and the phone retries for the same 2 minutes. **Deployed to hosted** (owner approved): migration `20261015191428` and Edge Functions `reconcile-broadcasts` v5 / `broadcast-control` v5; reconcile runs return 200. The phone's 2-minute retry and the viewer card ship with the next app build; a physical kill-the-app test is still owed. Hosted guest (anon) grants were reduced to the 10 intended reads (`20261015182953`). Firebase click-by-click guide: `brief/launch/04_FIREBASE_REMINDERS_SETUP.md`.

## Launch work without owner inputs, 2026-10-15

The active plan is `brief/launch/` (owner steps, testing plan, Claude's
remaining work). Owner physical testing of streaming, settings, chat, viewer
counts, UI, map and admin is recorded there as reported by the owner
(2026-10-10). STREAM-D8 is implemented server-side through the shared channel
authorization path (`2149722`, `cb1c10f`); which account and channel the owner's
streaming tests used is still to be confirmed before it is recorded as accepted.

Done on 2026-10-15. The migration was applied to hosted `zkkmfjsjouqzibvnzkau` on 2026-10-15 as `20261015172851` with the owner's approval (security advisors: no new findings beyond the intended self-service RPC warning); the app changes ship with the next build:
- Migration `20261015172851_data_rights_export_and_deletion.sql`:
  `export_my_data()` returns every user-linked table (secrets and other people's
  identities left out); `prepare_account_deletion()` and a stricter
  `delete_own_account()` refuse while banned, broadcasting, owning an
  organization with other active members, or holding uploaded files, and redact
  the name/email copies that do not cascade (audit log actor, review history,
  speaker link email, invitations by email). Owners may now delete their own
  legacy flat-path uploads. 39 pgTAP assertions in `supabase/tests/data_rights.test.sql`.
- Settings: export saves a JSON file (share sheet / browser download); deletion
  removes uploaded files through the Storage API first and explains each refusal.
- Reminder controls are hidden in builds without the Firebase values, because
  reminders are delivered only by push.
- The studio offers an organization destination only when that organization is
  enabled (rollout flag or pilot).
- Android 16: the map control row clears the system navigation bar on wide
  screens; new `android16_layout_test.dart` checks system-bar insets and tablet
  orientations for feed, map, settings, live room, phone broadcast and studio.

The older local SQL suite was rerun on a disposable copy: results are identical
with and without the new migration, but many pre-existing files fail (see
`brief/evidence/2026-10-15/launch-unblocked/README.md`), including an ambiguous
`schedule_id` reference in the reminders tests. The suite was repaired the same
day (`cb46213`: 33 files, 708 ok) and its four defect-fix migrations were applied
to hosted as `20261015174558`..`20261015174647` with the owner's approval: the
reminder claim function now runs, admins can read application review history,
anon lost leftover grants on reminder/review tables, and a ban records `ban` as
the broadcast end reason.

## Upcoming reminders: backend deployment, 2026-10-08

Hosted `zkkmfjsjouqzibvnzkau`: `dispatch-upcoming-reminders` is deployed
(`verify_jwt=false`, authorizes itself) and migration `20261008110548` adds the
service-role-only `verify_reminder_dispatch_key` RPC, so the cron job can use a
database-generated Vault key instead of the service-role key. **Not finished:**
the Vault secrets `upcoming_reminder_dispatch_key` and
`upcoming_reminder_function_url` and the `dispatch-upcoming-reminders` cron job
are not created yet (run `supabase/functions/dispatch-upcoming-reminders/cron.sql`
on the hosted project), and no Firebase project values exist anywhere: the web
build has no `FIREBASE_*` variables and the function has no confirmed
`FIREBASE_SERVICE_ACCOUNT_JSON`/`FIREBASE_PROJECT_ID`. Until those are set, no
reminder can reach a device (0 registered push devices on 2026-10-08). The
reminder bell is independent of Follow by design; no delivered notification has
been observed.

## Saved lectures and upcoming bookmarks, 2026-10-06

Discovery's Bookmarked Lectures sheet now lists playable recordings and saved
upcoming announcements, with All saved / Recordings / Upcoming filters and
removal controls. Saving marks archive/playlist thumbnails and changes the
player action to a green checked state. Upcoming saves are separate from reminder
subscriptions and open the channel's Upcoming tab. The repeated completed-session
list was removed from profile headers; the VOD sheet avatar no longer has a ring.

The private bookmarks table stores public metadata snapshots and typed references.
Archive/playlist aliases share a YouTube identity; old ID-only saves resolve through
the public web proxy. Failed writes roll back, failed reads retain existing content,
and late loads cannot overwrite a newer change or another account. Guests retain
the existing session-only behavior. Hosted migration `20261006085602` is applied;
ownership and banned-account policies are preserved. A rollback-only SQL probe
passed for old-save preservation, deduplication, private reads/writes, removal and
snapshot constraints. No new bookmark security-advisor findings.

## Discovery Hub loading skeletons, 2026-10-06

The owner-approved mint card skeletons are scoped to Discovery Hub. Full cards
appear only during a real first catalog request with no existing/cached snapshot;
completion, failure, or loss of connectivity stops them. Refreshes and empty
search results keep their existing content/state. Discovery banner/avatar image
placeholders stop at the first decoded frame or error, with shared-widget defaults
unchanged. There are no artificial delays. Queued catalog reads now skip disposed
providers. Verification: 1,066 Flutter tests passed, configured release web build
passed, analyzer zero, EN/AR catalogs symmetric, and phone/desktop EN/AR renders inspected.
Production deployment follows the requested master push.

## YouTube web Archive/playlist repair, 2026-10-05

The failing web build lacked a YouTube API key, and Vercel was missing the
corresponding environment variable. Web public Data API reads
now use a validated, cached same-origin server function; the browser bundle
contains no YouTube key. Native transport is preserved. Analyzer zero, full
Flutter 1,059 passed, seven Node checks passed, release web build and sentinel
key exclusion verified. Real local server reads returned 25 archive items and
10 playlists. The exposed key was removed from the test fixture and two audit
documents, but remains in Git history and should be replaced.

Deployment verified 2026-10-06 after explicit owner approval: the existing phone
key is stored as a sensitive, Production-only Vercel variable. Deployment
`dpl_BFLczX7sA7HiJzeeARzNmNsRn1pF` is READY on the public domain, running
`77bba0a`. Browser verification shows populated Hedayh Archive and playlists,
including four videos in an opened playlist. Public API reads returned 25
archive items and 10 playlists, and neither the bundle nor public responses
contains the key. Setup: `doc/YouTube_web_configuration.md`; screenshots and
evidence: `brief/evidence/2026-10-06/youtube-web-deploy/README.md`. The older
Phase 3 deployment note below is historical.

## Streaming regression repair, 2026-10-04

Connect YouTube's pre-consent 401 was reproduced with the real Supabase JS SDK: lowercase forwarded authorization collided with the SDK's default header. The channel and broadcast handlers now verify the explicit user token. Hosted channel-authorization, broadcast-control and reconcile-broadcasts are ACTIVE on the owner-designated streamer_app backend. The owner-approved recovery job is installed; a newly exposed recovery RPC alias collision was repaired by a new migration, and scheduled responses are 200.

Android returns from Google directly to channel connections. A sole personal channel is selected automatically, phone is the default sender, and the title → camera preview → explicit Go live flow replaces repeated destination confirmation for that case. Multiple-channel/organization selection remains explicit. Fresh checks: analyzer zero, 982 Flutter tests green, real-account rollback-only channel/Vault/phone reservation/provider context check passes with a modeled fresh heartbeat, configured Android debug APK built. No phone was attached; real Google consent, YouTube ingest and interrupted-show cleanup remain unverified. Release acceptance remains open. [Repair evidence](../brief/evidence/2026-10-04/streaming-regression/README.md).

## Organization V1 implementation snapshot, 2026-10-01

Organization V1 phases 1–3 are implemented and pushed through cb1c10f. **Phase 4 (client, notifications, recovery) is implemented and committed locally, not pushed (2026-10-01, together with the owner work it depends on)**: canonical studio/shows, phone session authority, exact viewer rooms/replays and scoped chat; durable organization events with in-app inbox and a push job; an Organizations hub (invitations, memberships, transfer, owner setup checklist, activity); invitation/transfer journeys; rollout availability (pilot list, organization-application switch). Local evidence: analyzer 0, **full Flutter suite green**, **155/155** disposable organization SQL assertions, Edge bundles, release web and Android debug builds. Not done: hosted migration/function deployment, real OAuth, physical Android and the mandatory real three-show pilot; three pre-existing gate findings in unrelated owner work remain. The deployed web app (https://stream-application-ten.vercel.app) is still the Phase 3 build without a configured backend. See [current handoff](../brief/handoff/ORGANIZATION_V1_HANDOFF.md) and [evidence](../brief/evidence/2026-10-01/organization-v1/README.md). Organization broadcasting remains disabled pending the pilot.

## Local master integration, 2026-09-27 10:55 +03:00

Owner requested one master checkout for testing. Local merge `c9e441f` now contains Opus map `74157ba`, Astra streaming `818cc12` and combined integration `8e28801`. Owner documentation was saved first in `571bcdd`; four documentation conflicts were reconciled without application/SQL changes. Project, supabase and build-script content exactly matches reviewed source `34d074a`. Fresh offline worker/page checks pass. Earlier 847 Flutter tests, zero analyzer issues, 462 SQL assertions and three concurrency checks remain inherited exact-source evidence, not rerun results.

Both stashes, source branches and all 109 previously untracked files were preserved. No push, hosted migration, credential-file read or phone installation occurred. Use this main checkout's `project/` for the next full rebuild/relaunch; the already-installed phone app has not changed. Dedicated Google/YouTube configuration and both new database migrations on the intended authorized test backend still need readiness verification. P5/P6/P6S remain unaccepted; STREAM-D8 and physical/scope requirements remain open.

## Earlier coordination snapshot, 2026-09-27

Hadayah is **not release-ready**. P5/map, P6 and P6S are **NOT ACCEPTED**. This historical section is superseded by the local master integration entry above. Current ownership and dependencies are in [the manager task board](../brief/management/TASK_BOARD.md), [event log](../brief/management/EVENT_LOG.md) and [release scope](../brief/management/RELEASE_SCOPE.md).

- **Astra integration is RUNNING:** `codex/hadayah-wave4v2-integration`, worktree `C:/Users/User/.codex/worktrees/hadayah-wave4v2-integration/Streamer_app`. Chat: Integrate Hadayah streaming and map. It owns the combined audit, repairs, independent critic, conditional local merge and consolidated Wave4v2 sheet. No final outcome has been reviewed.
- **Opus map implementation is finished but needs repair/acceptance:** branch `codex/tricity-map-upgrade`, tip `74157ba`, source `a57dda7`; critic **8/7/8/8**. Selected venue-card overflow, device/backend evidence, boundaries and geography scope remain. Recorded 734 tests and analysis 0 apply to that separate branch.
- **Astra camera follow-up is finished but unaccepted:** `codex/p6s-wave4v2-repair`, source `ddcb521`, evidence tip `818cc12`; reported 730 tests, analysis 0 and Android/web builds. Physical camera/YouTube behaviour and poor emulator frames/System UI ANR remain open. The prior 8/7/7/7 critic score does not review this later source.
- **Owner Wave4v2 testing is PAUSED.** Wave 4/E4 was completed with findings; Wave4v2 stopped after camera/layout problems and build-identity confusion. Resume on one identified, configured Hadayah Test candidate after the integration handoff and a short smoke test.
- **Acceptance configuration is unconfirmed.** The owner has no confirmed dedicated Google/YouTube/non-production configuration path. INT-01 may investigate authorized reuse and finish independent local work. Its setup question has been answered; no production fallback is authorized.
- **Last verified master is `7b54cb5`**, with owner edits and untracked evidence. The September 26 audit recorded 695 Flutter tests, 440 SQL assertions and 3 concurrency cases. INT-01 may later advance local master; refresh before reporting a merge.

Approved later work: organization broadcasting/individual-organization broadcast switching/org-scoped broadcast revocation; advance scheduling/Upcoming Live management; return-to-broadcast shortcut polish. Front switching is deferred for now with Coming Soon. Sources and boundaries are in the [scope register](../brief/management/RELEASE_SCOPE.md). These cuts do not waive all P7, full PiP, Local/private modes or other unresolved requirements.

**STREAM-D8 server-side YouTube authorization remains HIGH and release-blocking.** Accurate map boundaries, supported-mode decisions and physical evidence remain open. Publication also needs retained P7 scope, P8B data-rights/store/legal work, owner signing and signed AAB/secret scan, physical release smoke and P9 gates. Main-checkout G11a findings in the September 26 manager review are not cleared by another worktree's clean gates.

These owner-authorized management edits are concurrent with INT-01. Preserve them against its earlier protected-file baseline. No app source, database, build or installed app changed in this update.

## Earlier status snapshots

Hadayah Wave4v2 integration (isolated `codex/hadayah-wave4v2-integration`, 2026-09-27), frozen source `34d074a5c577cd35944813f0a3db5315f4c85e96`: combines preserved streaming `818cc12` and map `74157ba`. Repairs selected Arabic/narrow cards and short sheets, absent/fabricated locations, seven-city application persistence with private/public organization separation, and complete application-versioned offline save/update/worker handling. One **Hadayah Test** diagnostic identity; Google/YouTube configuration absent. Cycle 2 critic: **8/8/8/8**, provisional for physical/backend acceptance. Fresh verification: **847 Flutter tests**, analyzer 0, gates 0 failures, local SQL 462 assertions/3 concurrency cases and Android/web builds passed. Full evidence is recorded in `brief/evidence/2026-09-27/hadayah-wave4v2-integration/README.md`. Local master remains `7b54cb5` because protected owner/manager documents overlap; no push, hosted operation or app install. D8 remains HIGH; physical output/frame/ANR/background/resource evidence and licensed accurate city outlines remain open. **P5/map NOT ACCEPTED; P6 NOT ACCEPTED; P6S INCOMPLETE / NOT ACCEPTED.** The new 36-case owner sheet starts entirely NOT RUN. This integration has its own maximum-three review allowance; earlier branches' exhausted cycles remain historical.

Camera/landscape follow-up (isolated `codex/p6s-wave4v2-repair`, 2026-09-27), source `ddcb52178e126894e1b456aa06516a3d789cdac0`: actual Activity-display rotation and advertised rear capture sizes, portrait fit/landscape crop, three tap-toggle sender controls, no landscape chat/edit/studio keyboard, scrollable sheets and owner-deferred front camera Coming Soon. Unconfirmed viewer-toggle overlap is repaired. Analyzer 0, full suite 730, gates 26 PASS / 5 INFO / 0 FAIL. Local native receive shows both framing changes and black video when hidden; delivery is only 9.91 fps and System UI ANR remains unresolved. Physical uprightness/smoothness/YouTube/IME/TalkBack/long-duration evidence is NOT RUN. The three earlier critic rounds are exhausted; no score applies to this new source. D8 remains HIGH and release-blocking. **P6 and P6S are NOT ACCEPTED.** Current test pack and build identities: `brief/evidence/2026-09-27/p6s-camera-landscape/README.md`. Master, Opus and owner apps remain untouched; no merge/push/deploy/hosted operation.

Wave 4v2 repair (isolated `codex/p6s-wave4v2-repair`, 2026-09-26): G1 End reconciliation, bounded authorized recovery, native fixed-canvas orientation, landscape controls/chat and channel/mode guards implemented. Verification and physical evidence are separate in `brief/evidence/2026-09-26/p6s-wave4v2/README.md`. D8 server-side YouTube authorization is an explicit owner-retained release blocker. Final source5162add: analyzer0,722 Flutter tests,440 local SQL assertions, APK/web builds pass. Critic3/3 is8/7/7/7; target not met. Unconfirmed viewer notice still obstructs the controls toggle (P2); native ANR/sparse frames unresolved and physical evidence missing. P6 and P6S remain NOT ACCEPTED; no merge/push/hosted operation authorized.

Wave 3 owner retest review, 2026-09-24: The owner reports two-phone broadcaster conflict and transfer working, physical Android camera ingest reaching YouTube Studio, in-sheet studio errors, two-phone chat/blocking, and a platform pause notice. On transfer during a live broadcast, the receiving phone kept a false LIVE display until restart although the sender and viewer stopped; the exact refresh failure is not yet isolated. The supplied viewer screenshot plays an unrelated YouTube Developers video, so this broadcast's viewer playback remains unverified. Admin End/Remove, reports and owner moderation, audio-only, full rotation/background/reconnect, R09 post-repair actions and P5 offline map remain open. The owner reports the two new migrations applied to the hosted project; this review did not verify or access it. See `brief/evidence/2026-09-24/p6-wave3-review.md`. **P6/P5 are NOT ACCEPTED; P6S is INCOMPLETE; P8B is NOT ACCEPTED; no Play release is ready.**

Local P6/P5 integration, 2026-09-24: P6 retest repairs are on `master` through `938dc22`; P5.4/P5.5 map work and a focused offline marker-cache correction are merged locally. The combined Flutter suite passed **587** tests, analyzer found **0** issues, and the added cache test passed separately. G5c/G6/G7 are 0; G11a still flags five local credential-shaped hits for private owner review. Opus's 330 SQL assertions passed on a disposable backend. At this local checkpoint the two new P6 migrations had not been applied to a hosted backend; the later owner report above supersedes that target-status statement. **P6 and P5 are not accepted; P6S is incomplete.**

P6 retest repair, 2026-09-24 (branch `codex/p6-retest-repair`, commits `748ed87`, `c5869dd`, `e821adf`; not merged): R02's missing conflict dialog was reproduced (opened on `/splash` during hydration and removed by the next navigation) and fixed, together with a locked claim-or-report RPC, read-after-join device updates, persisted viewer choice and server-confirmed demotion. The studio buttons were not inert: their refusals were hidden under the bottom sheet; errors now show in the sheet, Phone/OBS preflight is explicit and Local is marked unavailable. R09 map visibility and revocation now use authorized, atomic, audited server actions; revocation no longer deletes organizations. Ban/unban, approval refresh, the application exit and the blank avatar were fixed. Verification: full Flutter **577 passed**, analyzer **0**, fresh local SQL **Files=18, Tests=330, PASS**, gates G6=1 (unchanged) and G11a=0 in this worktree (not a clearance of master's five hits). Two new migrations need an owner decision before any hosted retest. The Chrome reload hang and old PGRST205 did not reproduce locally. **P6 remains NOT ACCEPTED; P6S remains INCOMPLETE.** Evidence and the two-phone retest script: `brief/evidence/2026-09-24/p6-retest-repair/README.md`.

P6 owner retest, 2026-09-24: two physical Android phones and Chrome passed the reported account isolation, unverified broadcast denial, admin layout/filter and profile-sync checks. The two-device broadcaster conflict did **not** appear, and the studio actions did not start a live room; chat, admin live end/remove, camera and YouTube ingest were therefore blocked. Directory/ban/revocation UI passed in part, but ban/unban needed restart and map-hide/legacy revocation audit entries were missing. The setup fields do not identify the tested backend/build. See `brief/evidence/2026-09-24/p6-retest-review.md` for the evidence matrix. **P6 remains NOT ACCEPTED; P6S remains incomplete.**

Local integration, 2026-09-24: P5.1–P5.3 offline work and its reachability/room-recovery hardening were fast-forwarded to local master at `96a67f6`. Worktree verification was 549 Flutter tests and analyzer 0; physical offline acceptance and P5.4/P5.5 remain open. G6 and G11a scanner fixes were cherry-picked as `cf992e2` and `9fbc9a1`; combined focused scanner tests passed, and local gates report G6=1 and G11a=5. The five credential-shaped hits need private owner classification. Nothing was pushed or run against production in this integration.

P8B documentation update, 2026-09-24: seven `store/` compliance and bilingual listing drafts were merged locally at `e151559`. They identify unresolved owner/counsel decisions and export, withdrawal and erasure engineering. **P8B is not accepted.** P6 physical-device/Google acceptance and P6S remain open; no Play Store readiness is claimed.

## Current release status (2026-09-23)

Owner-evidence remediation, 2026-09-23: account-scoped role hydration, viewer/transfer cleanup, server-confirmed LIVE, actor/action/date audit paging, phone/RTL layouts, admin localization, profile/VOD truthfulness and asset-listing restrictions are implemented locally. Final Flutter **530 passed**, analyzer **0 issues**, disposable SQL **288 assertions / 16 files passed**. Two local password sessions verified Realtime transfer and server denial of the displaced device; the initial snapshot/join window still uses the existing 20-second heartbeat fallback. G6=565 (+11 localized `.tr()` matches), G11a=9 unchanged, G7=0. **P6 is NOT accepted; P6S is NOT complete; the app is not release-ready.** Partial phone lifecycle repairs compile, but two physical phones, Google OAuth and YouTube ingest were not tested. Windows STL1011 was reproduced; signed-in blank-web and exact avatar-429 behavior remain owner retests. Evidence, issue-by-issue outcomes and exact retest steps: `brief/evidence/2026-09-23/p6-owner-acceptance/REMEDIATION_2026-09-23.md`. No push, deploy or production operation.

Prior checkpoint (historical): Admin Hub checkpoint 2026-09-23, commit `11d0b09`: desktop side navigation, narrow-screen drawer, persistent English/Arabic toggle, honest unavailable analytics, and the admin role-loading fix are locally verified. Full Flutter 514 passed, analyzer 0, fresh local SQL 283 assertions passed. Browser UI evidence covers Welcome pause, Safety end/remove, audit reasons/actor/action filter, keyword lifecycle, history/recovery and refresh-based block synchronization. Gates are NOT green: G6=554 and G11a=9 in pre-existing nested worktrees. P6 remains NOT accepted; no physical Android devices or real Google OAuth were tested. Actor/date audit filter controls remain absent. P6S has not started. Separate P2/player truthfulness work remains open. Evidence and exact owner steps: `brief/evidence/2026-09-23/admin-hub/README.md`.


The app is not publish-ready. P6.4 directory and device access were locally verified in `1832b3e`. Commits `034aaf9` and `4f1dbda` added the weekly budget guard and audited account/session, app live-end/feed-removal, chat-block/report-validation and app-flag backend controls. The subsequent client and admin checkpoint below supersedes that backend checkpoint's test and G6 counts.

Update 2026-09-23 (Claude Opus, commits `bb285c8`, `1eb5d71`, fast-forwarded into `master` at `0d6b7a1`): chat blocks are server-owned with failure handling and refresh-based cross-device sync, and Settings has an unblock list. Report reasons match server validation. App flags drive a platform chat pause and a sign-ups-paused notice. Admins have a Safety tab (live list with presence counts, audit log, keyword manager with server-side audit trigger, Master Admin platform switches). Confirmed account deletions purge local caches. Evidence: full Flutter 504 passed, analyzer 0, SQL 278 assertions across 15 files on a fresh disposable database, gates exit 0 with G6=552 (+24 localized `.tr()` calls counted by the regex).

P6 client and admin scope is implemented and locally verified (see `brief/evidence/2026-09-23/p6-client-admin.md`); P6 safety acceptance (owner review of migration `20260923130000`, two-device/real-session checks) is still open, so P6S stays blocked. Account deletion is locally tested, but real Auth HTTP, storage and issued-JWT behavior remain limits. P6S physical broadcast and access tests, P5, P7, P8B and P9 remain open. There is no signed release AAB or physical-device streaming acceptance. See `brief/README.md`, `brief/03_WORK_PLAN.md` and the latest RESUME block in `brief/LEDGER.md` for the active plan and evidence limits.

Acceptance update 2026-09-23: Branch `p6-acceptance` (from `f581329`): reviewed migration `20260923130000` (packet: `brief/evidence/2026-09-23/p6-keyword-audit-migration-review.md`; recommendation: apply together with the new `20260923140000`, which revokes TRUNCATE/TRIGGER/REFERENCES that anon/authenticated held on 27 of 29 public tables and audits privileged keyword truncates). A local real-session run (four GoTrue users with password-grant sessions, separate browser origins, disposable `P6_accept_disposable`) passed in the UI: blocking, blocked-sender filtering, a second device honouring the block, unblocking from Settings on the second device, and the first device resyncing on re-entry; the Master Admin chat pause and resume with audit rows; the paused composer. It passed through the API with real sessions: server refusal of paused chat including for the stream owner, sign-ups pause and reopen, force end, remove from feed with the video barred and a new video allowed, and permission denials, all audited to the actor. Fixed two defects found in the run: room history displayed newest-first (postgrest `order` defaults to descending), and an open room stayed paused after chat resumed (now re-reads `app_flags` every 30 s while paused). Verification: full Flutter `+506: All tests passed!`, analyzer 0, SQL on a fresh bootstrap `Files=15, Tests=283, Result: PASS`, gates exit 0 with G6=552 unchanged. **P6 is NOT accepted**: Chrome became hidden, so the Welcome sign-ups notice, the Safety end/remove buttons, the audit and keyword views and both fixes were not seen on screen, and no physical devices were used; owner steps are in `brief/evidence/2026-09-23/p6-acceptance-sessions.md`. Also found, not fixed: the admin Overview KPIs are hard-coded samples (`ViewerAnalyticsModel.createDefault`), and a `/admin` deep link redirects before the role loads.

Integration and guided-acceptance update 2026-09-23: `p6-acceptance` was reviewed and fast-forwarded into `master` at `6e63f5d` (`git merge --ff-only`; owner edits to `AGENTS.md` and `Core_files/README.md` and both stashes preserved). Follow-up `1ed891c`: refused chat sends no longer toast an "Exception:" prefix; a misplaced doc comment was fixed; and a test pins that pause polling runs only while a room is paused. The earlier owner step promising that an open, enabled room notices a pause within 30 s was wrong and has been corrected: such a room learns of it from its next refused send (verified on screen: failed message with Discard only, then the paused notice), from re-entry, or from app resume. Browser-session evidence (separate origins in one desktop Chrome, real local GoTrue sessions) confirmed history oldest-first and a paused room recovering without reload. Focused tests `+60` across the three affected files and analyzer 0; the full suite (506) was not repeated because only those files exercise the changed send path. A disposable acceptance environment (`P6_accept_disposable`, both migrations, four test users, caster live) and a guided checklist G1–G6 are in `brief/evidence/2026-09-23/p6-acceptance-sessions.md`. **P6 remains NOT accepted and P6S remains blocked** until the owner completes the on-screen checklist and the physical-device steps (a phone broadcaster reacting to force end, two phones with real Google accounts). **P2 truthful data is reopened:** the admin Overview KPIs come from hard-coded samples in `ViewerAnalyticsModel.createDefault()` (1420 guests, 185 users, 365 RSVPs, 342 live viewers) and were found seeded in a fresh `platform_analytics` row. No launch date is committed.

The Claude Opus P6 client run completed under the §K metering waiver; the Codex cap in §J is unchanged.

---

## Historical feature snapshot (2026-08-17)

The following feature and test inventory is historical. Its "Online" labels and older counts do not establish current release readiness; use the current release status above for that decision.

| Subsystem | Status | Details |
| :--- | :---: | :--- |
| **Flutter Map (GIS Engine)** | 🟢 Online | Crash-free `SpatialStreamerMarker`, 3 streaming states (Offline, Video Live, Audio Live), Organizations |
| **Top Map Controls** | 🟢 Online | Full-width search bar + side-by-side City & Topic dropdowns |
| **Arabic & RTL Localization**| 🟢 Online | 100% key symmetry in `ar.json` & `en.json`, Tajawal typography |
| **YouTube Streaming Engine**  | 🟢 Online | Live YouTube video sync, 16:9 sticky player, VOD playback, Audio-Only Stage |
| **Cinema Split-View Room**    | 🟢 Online | 4 interactive tabs (Live Chat, Slides PDF, Q&A, Venue RSVP), Audio Waveform Visualizer |
| **Floating Mini-Player (PiP)**| 🟢 Online | Global draggable overlay with play/pause and expand controls |
| **Discovery Feed Hub**        | 🟢 Online | Live Hero carousel, VOD grid, bookmarking, notifications, Audio Live badges |
| **Streamer Studio & Settings**| 🟢 Online | Google Broadcaster Auth, Format selector (Video vs Audio), Streamer/Viewer toggle |
| **Auth & Onboarding Wizard**  | 🟢 Online | Branded Welcome screen, Google Sign-In, Guest Setup, 5-Step Application Wizard |
| **Bi-directional Org System** | 🟢 Online | Broadcaster Join Org requests, Org Speaker Invites, Granular RBAC Permissions |
| **Admin Hub Dashboard**       | 🟡 Partial | Desktop moderation workspace (`AdminHubScreen`), live pending badge. Overview KPIs are hard-coded samples (`ViewerAnalyticsModel.createDefault`); truthfulness work reopened 2026-09-23 |
| **Multi-Account Super Admin** | 🟢 Online | Multi-account RBAC (`polkgvd2@gmail.com`, `ameeralhatemi67@gmail.com`, `amir.alhatemi@gmail.com`) |
| **Terms & Governance Viewer** | 🟢 Online | Dynamic live terms editor in Admin Hub + in-app viewer modal in Settings for all users |
| **Desktop / Responsive**      | 🟢 Online | NavigationRail sidebar on $\ge 900\text{px}$, Bottom Nav on mobile |

---

## 🎯 Completed: Auth, Onboarding, 5-Step Streamer Wizard & Dual Account Management

- 🔐 **Branded Welcome Landing (`welcome_screen.dart`):** Google Sign-In with mandatory account picker, Login, and lightweight Guest viewer entry.
- 👤 **Guest Viewer Setup (`viewer_setup_screen.dart`):** Custom name + avatar preset/upload from device.
- 🎭 **Role Selection (`role_select_screen.dart`):** Viewer/Student vs Streamer Application.
- 🧙 **Dynamic Streamer / Organization Wizard (`streamer_apply_screen.dart`):**
  - Step 1: Legal Name (dynamically populated from Google), Handle, Bio
  - Step 2: Any-ratio Avatar & Banner Upload with Interactive **Arrange & Reposition Modal** (`ImageArrangeModal`) and error diagnostics
  - Step 3: Affiliation, YouTube Link (proof checked), Custom Categories (up to 6 fields), Individual vs Org Toggle, Topic Tags
  - Step 3.5 (Org): Organization Multi-Streamer Roster with auto-fill from existing handles (`@handle`)
  - Step 4: Geographic hub dropdown, interactive **Spatial Map Pinpoint Picker** (`LocationPickerModal`), Saudi phone validator, and Multi-Branch locations
  - Step 5: Live Broadcaster Card Preview, dynamic clickable **Terms & Conditions Sheet** for Streamers/Organizations, and mandatory agreement checkbox
- 🏢 **Bi-Directional Organization Management:**
  - Individual Broadcasters can apply to join registered Organizations via `JoinOrgModalSheet`.
  - Organizations can review incoming applications in `OrgManagementView` with one-click Accept/Decline.
- 📊 **Real-time Admin Telemetry:** Live Google user and guest session tracking in Admin Hub.

---

## 🧪 Test Suite Health & Verification Metrics

- **Unit & Integration Suite:** `93/93 PASSING (100% Green)`
- **Static Analysis & Linting:** `0 issues (flutter analyze)`
- **Core Verification Suites:**
  - `auth_onboarding_and_org_affiliation_test.dart` (10/10 PASS)
  - `admin_hub_screen_test.dart` (5/5 PASS)
  - `organization_admin_and_go_live_test.dart` (6/6 PASS)
  - `organization_models_and_rbac_test.dart` (5/5 PASS)
  - `organization_profile_screen_test.dart` (5/5 PASS)
  - `live_multi_speaker_test.dart` (6/6 PASS)
  - `organization_admin_and_go_live_test.dart` (6/6 PASS)
  - `admin_database_service_test.dart` (7/7 PASS)
  - `admin_hub_screen_test.dart` (8/8 PASS)
  - `spatial_map_test.dart` (7/7 PASS)
  - `youtube_api_test.dart` (5/5 PASS)
  - `vod_archive_test.dart` (6/6 PASS)
  - `live_stream_test.dart` (5/5 PASS)

---

## 🧪 Quality & Test Metrics

- **Static Analysis:** `flutter analyze` $\rightarrow$ **0 issues (100% clean)**.
- **Automated Tests:** `flutter test` $\rightarrow$ **83/83 tests passing across all suites**.
- **Localization:** 100% symmetric JSON dictionaries (`ar.json` / `en.json`).

## 2026-09-23 checkpoint: weekly budget preflight repaired

The owner authorized weekly-only budgeting with a 5% absolute ceiling, aiming lower. Codex exposes a 10,080-minute weekly window and no five-hour window. The meter now classifies by duration, preserves 1% as 1%, rejects stale/missing weekly readings, and supports `--plan weekly --cap 5` with a 4% soft stop. Focused Node tests passed. Entry usage 1%, implementation entry 2%; no app/SQL/Flutter evidence added yet. P6.4 item 1 remains verified in `1832b3e`; P6 safety implementation is next and P6S remains blocked. Owner edits and both stashes are preserved. See brief/04_BUDGET_PROTOCOL.md section J. No push/deploy/production operations.

## 2026-09-23 checkpoint: P6 account/live controls and safety backend

Implemented authorized, audited directory account deletion/Auth-session revocation and app live end/feed removal. The server requires active admin sessions, protects self/master/admin targets, rejects deletion of organization/storage owners, and prevents forged success audits. Feed removal blocks the video ID from going live again in the app. Issued JWT expiry and external YouTube media remain explicit limits.

Also implemented backend own-row chat blocks, server report-reason/message validation and master-admin app flags enforced at chat/Auth INSERT. Client block persistence/cache sync and app-flag management/availability UI remain NOT DONE. Dedicated live list, audit viewer, keyword manager and global deleted-account cache acceptance remain open. P6S is not started.

Verification: 8 focused Flutter tests; 25 admin safety + 26 block/flag SQL assertions; GPT-6 Luna Medium analyzer 0 and full Flutter 464 passed. Parent fixed the intentional deny-all catalog allowlist and block-policy helper, then final SQL passed all 263 assertions across 14 files. Final gates retain known G6=528; security/secret gates passed. Only the named disposable local database was used. Existing owner edits and both stashes remain preserved. Evidence and next dependencies: `brief/evidence/2026-09-23/p6-safety.md`. Weekly usage measured 3% against the owner's 5% absolute ceiling; not all P6 work is complete.

## 2026-09-24 build preflight for third device retest

The local Windows debug build now passes with a compiler compatibility definition scoped to `permission_handler_windows_plugin` (MSVC 14.51). The local Android debug APK also builds; the owner's earlier missing `dart_plugin_registrant.dart` error did not recur and its cause is unconfirmed. These are build checks only, not app launch, signed-in flow, physical-device, P6, or P5 acceptance evidence. P6 and P5 remain NOT ACCEPTED; P6S remains INCOMPLETE. No hosted migration, production access, push, or release action occurred. See `issue_encountered.md` and the latest `brief/LEDGER.md` RESUME block.

## 2026-09-24 Android device build recovery

After the owner's repeat `dart_plugin_registrant.dart` failure, the generated file was present during inspection. `flutter run` launched an unconfigured build on SM M307FN, then a placeholder-config build on the exact failing SM S936B. Following `flutter clean` (which removed `.dart_tool`), a fresh placeholder-config `flutter run` again built, installed and launched on SM S936B. An arm64 debug APK using the owner's local define file then built and was installed on SM S936B without launch. The intermittent cause remains unconfirmed; the real-config app and P6 flows have not been accepted. No backend operation, push, deployment or hosted migration was performed. See `issue_encountered.md`.


## Wave 4v2 repair branch — 2026-09-26
NEEDS WORK. Isolated source commits 0eaa645 / 68394e9 repair interrupted-room End/session identity and part of landscape chat/settings. Codex weekly budget reached the 4% soft stop; G2 recovery, native rotation, G4 channel/security/scope remain open. Neither P6 nor P6S accepted. See brief/evidence/2026-09-26/p6s-wave4v2/README.md. This branch note does not overwrite the owner’s newer main-checkout status.

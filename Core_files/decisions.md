---
type: decisions
project: Streamer_app
updated: 2026-10-28
---

# 🏛️ Architecture Decision Records (ADRs): Streamer App

> Key architectural, UX, and technical decisions governing the Educational Streamer App.

## ADR-019: Account notices are server events; one dispatcher sends events and lesson reminders (2026-10-28)

Pre-test check (brief/audit/2026-10-28_PRE_TEST_FEATURE_CHECK.md): the
applicant never heard the admin's decision (the notice was added on the
reviewing admin's device), live alerts for followed channels were written
but never pushed, and lesson reminders were stored but never sent. Owner:
"start fixing the 'before testers start' list; ask me before anything goes
to the live server".

- **One inbox table for account notices.** Decisions on the account's own
  application (`application_approved`/`application_rejected`, with the
  reviewer's note and whether it was an edit) join the Organization V1 kinds
  in `org_v1_events`, written by a trigger on `broadcaster_applications`. The
  client already loads that table into the bell and marks rows read. Lessons
  keep their own inbox (`lesson_notifications`).
- **One dispatcher.** `dispatch-organization-events` sends `org_v1_events`
  pushes and, in the same run, the due lesson reminders
  (`claim_due_lesson_reminders`: inbox row once, then the viewer's devices).
  It authenticates with the Vault-held reminder dispatch key, so deploying it
  needs no new function secret. Decision pushes ignore the notification
  switches: they are account notices.
- **Asking for push.** A first follow and a lesson reminder ask for
  permission, as channel reminders did; live alerts arrive only by push.
- **Lesson reminder times stay the app's.** Only the app knows prayer times,
  so the server sends at the stored `remind_at` and the app moves a reminder
  to a moved lesson's new time on load; a new `remind_at` re-arms it.
- **The bell keeps unread server notices** past the 12-hour window (a stale
  "live now" alert still drops out) and never throttles them.

## ADR-018: Recordings: hidden means private on YouTube; owners delete, admins take down (2026-10-27)

Owner request 2026-10-27, after finding that "hide the video" only took a
recording off the app's lists while it stayed public on YouTube. Owner
answers: hide and show also change YouTube; deletion only for recordings of
lives made in the app; on an organization's channel only its owner deletes;
admins can make a recording private, not delete it.

- **Scope: lives made in the app.** Only a recording with a session
  (`broadcast_sessions.stream_id`, `started_at` set) is touched on YouTube.
  Other videos on a channel keep the app-only hide; the owner manages them
  in YouTube Studio.
- **Hidden = private.** `hide_replay` is the owner's wish for the
  recording. The end-of-live switch sets it before or during the live; after
  the live a trigger on `hidden_channel_content` keeps it in step with the
  channel page's hide and show, so every path (including older app builds)
  drives YouTube. `broadcast_provider.replay_privacy` records what was last
  written. `broadcast-control` writes the difference right after End (in the
  background) and the reconcile job claims unfinished work every 30 seconds.
  The write reads the video's status first and sends it back with only
  `privacyStatus` changed, because a status update erases the fields it is
  not sent.
- **Delete.** `recording_delete()` (the streamer on their own channel, an
  organization's owner; not a co-owner or presenter) hides it at once and
  audits `recordingDeleted`; the server calls `videos.delete` (404 counts as
  done) and marks `replay_status='deleted'`.
- **Takedown.** `admin_recording_takedown()` (admin tier, reason required,
  audited `recordingTakenDown`/`recordingRestored`) sets `replay_taken_down`
  and hides it. The delete policy on `hidden_channel_content` then deletes
  nothing for the owner, so only an admin can restore it; restoring hands it
  back still hidden. The owner can still delete it. Admins see hidden items
  on channel pages so they can find a taken-down one again.
- **Quota.** A privacy change costs 51 units (read + update), a deletion 50.
  A failed attempt is retried after 15 minutes; a privacy change YouTube
  refuses (400/403) only every 6 hours, so one stuck video cannot use up the
  daily 10,000 units.
- **Not covered.** Anything viewers saw live or recorded themselves.
  Replays that are hidden or taken down are not offered for playing in the
  app (`BroadcastSession.replayWatchable`), since a private video only shows
  an error in the player.

## ADR-017: The Android APK from the website, and how installs are updated (2026-10-26)

Owner plan 2026-10-26: while Google's verification is pending, Android users
download the APK from the website; the same app moves to Google Play later.

- **One build, two distributions.** `--dart-define=DISTRIBUTION=apk` (the
  website APK) or `play` (Google Play). The Android release build refuses
  anything else, and refuses an app bundle built as `apk`
  (`android/app/build.gradle.kts`). Debug runs, tests and the web have no
  distribution and never look for updates (`AppDistribution`).
- **Updates: offer, and require only through a floor.** `public.app_releases`
  (`20261026120000`) holds each published release per channel with
  `min_supported_code`. On start and on return (at most every six hours)
  `AppUpdateController` reads the newest published row of its channel:
  newer → a "Later / Download" dialog once per release, on a main tab, never
  during a phone broadcast (`AppUpdatePresenter`), plus a row in Settings →
  About; below the floor → `UpdateRequiredPage` over the app (kept mounted
  underneath, held back while broadcasting). A failed check changes nothing,
  so being offline never blocks. Forcing every release was rejected: each
  update is a large download through the unknown-sources screens and a host
  outage would lock everyone out. The floor exists from the first APK because
  an install without a checker can never be told to update.
- **No self-install.** Download opens the release link in the browser and
  Android's installer does the rest. `REQUEST_INSTALL_PACKAGES` is not
  requested: Play restricts it, so the same app could not ship there. The
  Play build only ever opens its own Play listing (Play forbids updating an
  app any other way); the database and the app both enforce that.
- **Where the file lives.** The public Storage bucket `app-releases`; the
  website's `/download` page and `/download/android` short link read the
  newest row through `api/app-release.mjs`. The APK opens release links only
  on the website or the Supabase project.
- **Signing.** The APK is signed with the key that becomes the Play app
  signing key ("use my own key" in Play Console), so Play can later install
  over APK installs; a different key would force every APK user to uninstall.
  The same key is registered for Android developer verification (enforced
  globally from 2027).
- **Backend changes stay compatible** with installs still in use: add before
  removing, and raise `min_supported_code` before a migration that breaks old
  versions (the `taysir_*` drop of 2026-10-22 would have broken every older
  APK).
- **YouTube on phones goes through the website** (`/api/youtube`, ADR-011
  extended): a public APK can be unpacked, so it carries no YouTube key.

## ADR-016: A second design, the Hedayah skin, beside gold & black (2026-10-22)

Owner request 2026-10-22: the team should see two design versions and switch
between them. Gold & black (ADR-013) stays the default; the **Hedayah skin**
(`hedayah-skin`) follows the association's identity book ("Hedayah Brand
Identity", scanned from hedayh.org.sa): white and mist grounds, flat gold
bands carrying the owner's lattice, slate, 25 px pills, Readex Pro headings
over IBM Plex Sans Arabic, and its own icon set. This amends ADR-013's "only
design"; nothing in gold & black changes.

- **Where it is chosen.** Settings → Design (two picture tiles), per device
  (`app_skin` in shared preferences: `gold-black` or `hedayah-skin`). On the
  web a link can carry it, `/?skin=hedayah-skin#/welcome`, so guests and the
  team can see it without signing in; a linked skin is remembered. It is read
  before the first frame (`readAppSkin` in `main.dart`), so the app never opens
  in one design and flips.
- **How it reaches the screens.** The skin rides on the theme
  (`AppSkinTheme` extension; `context.isHedayahSkin`). The gold tokens stay
  `const`; a runtime remap of every token was removed in ADR-013 and is not
  brought back. Instead the shared pieces change by skin: `CaIcon` (icon set
  and icon gold), `CaButton`, `CaCard`, `CaChip`, `CaInput`, `CaNavBar`, the
  laptop rail, the website header and footer, page grounds
  (`context.pageGround`), the Lessons icons and night bands, and the Material
  theme. Pages with their own Hedayah layout: splash, welcome/sign-in, guest
  name, role choice, Discover's opening band and headings, the Settings
  account card. Two text-style helpers with no context (website and Lessons
  display face) read `ActiveSkin`, set when a theme is built; a change of
  skin rebuilds every element, as a language change does.
- **Identity rules kept.** Gold is a fill; text on gold is ink #151D24
  (6.0:1), never white (2.8:1). Gold-coloured text is bronze #805B1B; icons on
  white are Gold 600 #A87726. The rosette is never shown in its primary
  colours on gold: the reversed (white) lockup is. Dark bands that carry light
  text (Lessons heroes) become the book's night variant, flat ink with the
  lattice, rather than gold.
- **Assets.** The lattice is the owner's motif (`assets/hedayah/source/
  motif.svg`, their `solopattern.svg`), turned into Dart path data by
  `brief/tools/make_hedayah_motif.py` and repeated on the exact 12.149 mm grid
  the book measured, so it has no seams; its 0.12 mm lines get a screen-scaled
  stroke to read at about a pixel. The rosette is drawn in code (four loops at
  45°, proportions from the logo file). The wordmark is cropped from the
  association logo. Icons: `brief/tools/make_hedayah_icons.py` →
  `assets/hedayah/icons/` (one per `CaGlyph`). Font: Readex Pro (SIL OFL), the
  book's stand-in for the website's Hacen Maghreb.
- **Not covered yet.** Screens built from their own fixed colours (admin
  consoles, the broadcast studio, channel pages, Lessons cards) take the
  icons, fonts and shared controls but keep their gold layouts.

## ADR-015: Admins run the lessons; preachers use links, not accounts (2026-10-22)

Owner decisions 2026-10-22 (the seven questions, answered as recommended).
This replaces ADR-014's authority model; its "inside Hadayah Live" layout
stands. "Taysir" is no longer a name in the app: the feature is Lessons
(الدروس) in code, links and screens.

- **One platform-wide programme, run only by admins.** No organization owns
  preachers, mosques or lessons, and nothing is switched on per organization.
  There are no coordinators and no preacher accounts. Who manages lessons is
  `is_lessons_admin()`: admins, master admins and the new **lessons-only
  admin** role (`user_roles.role = 'lessons_admin'`, granted by a master
  admin in Roles & Permissions). Lessons-only admins are not admin tier
  (`is_admin_tier()` is unchanged) and see only the lessons area.
- **Admin emails.** A master admin adds an email address
  (`admin_email_grants`); a verified account with that email becomes an
  admin now or at its first sign-in. Emails grant only `admin`; master admin
  is given only by an existing master admin. The old hard-coded bootstrap
  list moved into the table as master-admin rows.
- **A preacher is a person in the admins' list, never an organization.**
  Admins add, edit, hide and remove preachers and can do everything for them
  (add lessons, choose mosques, file reports) whether or not the preacher is
  ever involved. A card can be linked to a Hadayah Live account only for a
  preacher who also streams.
- **Preacher links instead of accounts.** An admin creates a link for a
  preacher: **one-time** (the first phone that opens it keeps it, until
  revoked or an optional end) or **timed** (any phone, from a start to an
  end). Only hashes of the key and of the bound phone's id are stored; the
  link is shown once, to send on WhatsApp. Through the link (`/preacher/:key`,
  no sign-in) a preacher sees his lessons, proposes card changes and requests
  lessons (date, prayer time, topic, a note). Each request and each card
  change waits for an admin; approving a request needs a mosque, which the
  admin chooses. Errors carry why a link no longer opens (revoked, not yet,
  ended, used on another phone).
- **The admin page has two areas**: the platform and Preachers & lessons
  (`/admin/lessons/:tab`: overview, approvals, preachers, lessons, mosques,
  reports from users, statistics, log; plus a page per preacher with his
  links). A switch at the top of the navigation moves between them; a
  lessons-only admin opening `/admin` lands on the lessons area.
- **Public card:** name, title, bio, languages, photo, upcoming lessons and
  mosques. The phone stays private: admins see a mask, and each reveal is
  logged.
- **Data:** migration `20261022125222_lessons_programme_v2.sql` drops the
  `taysir_*` schema (hosted held only seeded districts) and creates
  `mosque_districts`, `mosques`, `preachers`, `preacher_edits`,
  `lesson_series`, `lessons`, `lesson_*` and private `preacher_contacts` /
  `preacher_keys`; every write is a security definer `lessons_*` function.
  `20261022124908_admin_email_grants.sql` adds the email grants and the
  lessons-only role. Both are tested on a hosted-equivalent database
  (pgTAP: `supabase/tests/lessons_programme.test.sql`,
  `admin_email_grants.test.sql`) and must be applied to hosted together
  with the app that uses them.

## ADR-014: Taysir, the mosque lessons programme, inside Hadayah Live (2026-10-21)

> **Superseded in part by ADR-015 (2026-10-22):** the organization-scoped
> permissions, coordinators and invitation claims below are gone; the
> layout inside Hadayah Live stands.

Owner request: build the reviewed "Taysir in Hadayah Live" prototype into the
app on our Supabase, taking Taysir's features but not its code or security
model (review: `brief/research/taysir/2026-10-21_TAYSIR_DNA_HEALTH_AND_INTEGRATION.md`).

- **Authority is two organization-scoped permission keys**, not new role tiers:
  `activities.coordinate` and `activities.submit` in `user_permissions`, read
  through `has_permission()`. Org owners and co-owners coordinate their own
  organization implicitly and grant `activities.coordinate` to members; a
  master admin switches Taysir on per organization (`taysir_organizations`).
  Owners can make only their members coordinators (ADR-007's `org_co_owner`
  rules are unchanged). **Admins (admin tier) add, change and remove
  coordinators for any organization**, members or not, from the console's
  Team tab (owner decision 2026-10-21: no first coordinator was granted at
  deploy; admins manage them). `taysir_set_coordinator_orgs` sets a person's
  organizations in one step and logs each grant and revocation.
- **Invitation links instead of passwords.** A coordinator adds a preacher to
  the roster and sends a single-use link that expires after 14 days; only its
  hash is stored.
  The preacher signs in with the app's normal Google/Apple sign-in and claims
  the card, which grants `activities.submit`. No shared default password, no
  account created on anyone's behalf.
- **Every write is a security definer function** that checks the caller.
  Clients hold no INSERT/UPDATE/DELETE on programme tables except their own
  reminders, follows, attendance log and preferences. Phone numbers sit in a
  private table: coordinators see a mask, and each reveal is written to the
  action log. The public reads approved and cancelled sessions of enabled
  organizations, verified mosques and listed preachers, nothing else.
- **Client:** `lib/features/taysir/` with its own `TaysirController` (a
  standalone `ChangeNotifier`, provided next to `AppProvider` in `main.dart`,
  not part of it). The repository interface has a Supabase implementation
  and a sample-data `DemoTaysirRepository` used when Supabase is not
  configured and by widget tests; the sample build shows a banner and a
  persona switcher on the programme page (`/taysir/me`).
- **Part of Hadayah Live, not a second app (amended 2026-10-22).** The first
  build put Taysir behind the Settings logo as a separate shell that replaced
  Discover and Map with its own tabs, so switching to it hid every streamer.
  The owner's intent was a merge, so:
  - **Lessons is the third tab** of Hadayah Live's shell (Discover, Map,
    Lessons): `/taysir` (the programme's home) with `/taysir/lessons` inside
    the tab. Phone pill, desktop rail and website header all list it.
    Lesson, series, preacher, mosque, submit, report, claim and console
    pages open above the tabs; on the website they carry Hadayah Live's
    header and footer (`TaysirPage`).
  - **One map.** Mosques with approved lessons in the next seven days are
    gold coins on the Spatial Map beside broadcasters, with an
    All / Broadcasters / Mosque lessons switch shown only when there are
    lessons. A coin opens the mosque's card (next lessons, mosque page,
    directions). `/map?mosque=<id>` opens on a mosque; the old
    `/taysir/map` links redirect there. Taysir's own map screen is gone.
  - **Discover** has a "Mosque lessons this week" row (phone and website),
    hidden when there are none.
  - **A person's programme pages are in Settings** (`TaysirSettingsCard`):
    the programme page (following, learning log, preferences, roles),
    reminders, notifications, "My lessons" for preachers and the console
    for coordinators. The Lessons tab's phone bar keeps only the language
    button and an alert bell while Taysir notifications are unread.
  - No switch remains: `AppExperience` and the `/feed` → `/taysir` redirect
    are deleted, and the saved `app_experience` choice is removed on start
    (`forgetRetiredPreferences`). Shared `/taysir/...` links open for
    everyone; public pages need no sign-in.

Consequences: migration `20261021142359_taysir_lessons_programme.sql` is
deployed to hosted (2026-10-21). Hosted has no organizations yet, so Taysir
stays empty until the Hidayah organization exists and a master admin switches
Taysir on for it. Push reminders for Taysir are stored but not
sent yet (`dispatch-upcoming-reminders` does not read `taysir_reminders`).
Taysir's real data (43 preachers with phone numbers) is not imported;
coordinators import a CSV in the console.

## ADR-013: Hidayah Gold is the only design (2026-10-21)

The green design and its runtime palette remap are removed. Gold is the
source token set (`canopy_tokens.dart`, `app_theme.dart`); `AppPalette` holds
plain gold constants. The retired `hidayah_palette_enabled` key is deleted on
start (`lib/core/services/retired_preferences.dart`). Website layouts are
always on at 1024 px and wider. Both Android launcher aliases are kept so
component state survives updates; the launcher icon is gold on Android, iOS
and web.

Superseded part (2026-10-22): the Settings → About logo briefly switched the
whole app between Hadayah Live and Taysir (`AppExperience`). That hid
Discover's streamers and the map whenever Taysir was on, and a guest in
Taysir could not get back (Settings needs sign-in). The switch is removed;
Taysir is a tab of Hadayah Live (ADR-014) and the logo is only the logo.

## ADR-012: Private saved recordings and upcoming announcements

Owner request, 2026-10-06: extend the existing own-row `bookmarks` table with
`item_kind` and a bounded public metadata snapshot. Recording keys use the YouTube
video ID rather than archive/playlist aliases; upcoming keys are
`upcoming:<schedule ID>`. Snapshots let the library reopen recordings without
visiting the source channel. Old ID-only saves resolve through the existing public
YouTube proxy. Snapshot metadata never authorizes access or proves a live state;
upcoming schedules refresh through the public schedule service and removed/expired
announcements are labeled accordingly. Saving is independent of reminders and
does not download media. Writes use insert-or-ignore, keep the existing own-row
and banned-account rules, and roll back visible state on failure. Account changes
and newer mutations fence late reads. Guest bookmarks remain session-only.

---

## ADR-001: Persistent Dual Navigation via `go_router` StatefulShellRoute
* **Status:** `ACCEPTED`
* **Context:** The application features two primary discovery paradigms: an interactive Spatial GIS Map and a Twitch-style Discovery Feed. Rebuilding the map canvas on every tab switch would destroy pan/zoom state and cause visual stutter.
* **Decision:** Use `StatefulShellRoute` in `go_router` to maintain independent navigation stacks and persistent widget trees for both tabs.
* **Consequences:** Instant tab switching with zero map reload latency and preserved camera coordinates.

---

## ADR-002: Dual Streaming Strategy (YouTube Live Embeds + Cloud RTMP/HLS)
* **Status:** `ACCEPTED`
* **Context:** To ensure low operational cost while scaling educational content across Saudi Arabia, authorized educational channels primarily broadcast on YouTube Live, with cloud fallback (AWS IVS / RTMP) for custom private seminars.
* **Decision:** Implement `youtube_player_iframe` for YouTube Live and VOD playback, with clean encapsulation in a unified `VideoViewport` interface.
* **Consequences:** Zero streaming server hosting costs for public lectures, reliable multi-bitrate HLS playback, and native integration with YouTube's CDN.

---

## ADR-003: Dynamic Bilingual Layout Mirroring (Easy Localization)
* **Status:** `ACCEPTED`
* **Context:** The platform serves Saudi Arabia and international academic audiences, requiring 100% parity between Arabic (RTL) and English (LTR).
* **Decision:** Use `easy_localization` with JSON translation catalogs (`en.json`, `ar.json`) and native `Directionality` layout mirroring.
* **Consequences:** Sub-100ms language swaps without restarting the app or losing current scroll/stream states.

---

## ADR-004: Anti-Slop Design System & Impeccable Contract (`Desgin.md`)
* **Status:** `ACCEPTED`
* **Context:** Prior UI iterations suffered from generic design patterns and ad-hoc color styles.
* **Decision:** Enforce a strict `Core_files/Desgin.md` contract governed by `[[impeccable]]` design rules, curated HSL/OKLCH color palettes, glassmorphism surface layers, and modern typography (Inter + Tajawal).
* **Consequences:** Premium educational aesthetic, crisp visual hierarchy, and automated design linting via `.agents/hooks.json`.

---

## ADR-005: 100% Pitch Safety & Graceful Error Overlays
* **Status:** `ACCEPTED`
* **Context:** During investor pitches and stakeholder live demos, unhandled errors or blank tabs destroy credibility.
* **Decision:** Never expose raw Flutter exception screens. All unbuilt actions route to `FeatureInProgressModal`, and network drops display a branded "Stream Temporarily Offline" overlay with secret Pitch Director overrides.
* **Consequences:** Guaranteed crash-free demo experience.

---

## ADR-006: YouTube IFrame Cross-Origin Referrer Architecture (Error 150/152/153 Prevention)
* **Status:** `ACCEPTED` (shared implementation present; iOS E0, native build/runtime unverified as of 2026-10-17)
* **Context:** YouTube's mid-2025/2026 security updates enforce strict embedder verification on mobile WebViews. Loading raw URLs or using default WebView headers caused Error 150 (embed restriction), Error 152 (Play Integrity/bot check on debug builds), and Error 153 (configuration error due to missing/same-origin `Referer` headers).
* **Decision:** In `YouTubePlayerAdapter`, configure:
  1. `AndroidWebViewController.setMediaPlaybackRequiresUserGesture(false)` and iOS `WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{})`.
  2. Embed wrapper HTML with `<meta name="referrer" content="strict-origin-when-cross-origin">` and `iframe referrerpolicy="strict-origin-when-cross-origin"`.
  3. Base URL set strictly to `https://www.youtube-nocookie.com`.
  4. Embed source URL: `https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&playsinline=1&controls=1&rel=0&modestbranding=1&enablejsapi=1`.
* **Consequences:** The origin/referrer strategy is implemented for Live and VOD. Existing Android/web observations remain platform-specific evidence; they do not guarantee every device. The former universal iOS verification claim is withdrawn. iOS playback and prevention of Errors 150/152/153 are **E0: implemented settings, not built or run on iOS**. Windows Dart tests are E1 host proof only; no native E2/E2S/E3 evidence exists.
* **iOS evidence boundary, 2026-10-17:** W7 audited the existing WKWebView settings against [official 3.25.1 source](https://github.com/flutter/packages/blob/webview_flutter_wkwebview-v3.25.1/packages/webview_flutter/webview_flutter_wkwebview/lib/src/webkit_webview_controller.dart). This is source evidence, not playback proof. The embed base URL and referrer policy are unchanged. See `brief/ios/IOS_STATUS.md` and `IOS_PROGRESS.md` for current evidence.
* **iOS link limitation:** Custom-scheme OAuth registration is E0 configuration. HTTPS organization invitations open the browser; Associated Domains and a non-auth invitation-link consumer are deferred. No native universal-link or completed iOS OAuth return is claimed.

---

## ADR-007: "Permitted Admin" / "User" Tiers Map onto Existing `org_owner`/`org_co_owner`/No-Row Scheme
* **Status:** `ACCEPTED`
* **Context:** `doc/Roadmap/v0.8_Admin_Upgrade.md` describes the `user_roles.role` hierarchy as `master_admin`, `admin`, `permitted_admin`, `user`. The table was already scaffolded in v0.5 (`20260821203000_initial_schema.sql`) with `role in ('master_admin', 'admin', 'org_owner', 'org_co_owner')` and no stored value for a base "user" — specifically so v0.8 "doesn't need another schema migration round" (roadmap's own words). Renaming the enum values to match the roadmap's prose literally would be that extra migration round the roadmap says to avoid, and would also erase the existing owner-vs-co-owner distinction other code paths may need later (e.g. org transfer flows, different scopes of org authority).
* **Decision:** Keep the v0.5 enum values as-is. `org_owner` and `org_co_owner` together ARE the roadmap's "Permitted Admin" tier (two DB values instead of one, both org-scoped via `organization_id`). "User" tier is the implicit case of having no `user_roles` row at all — no code should ever query `role = 'user'`. v0.8 Checkpoint 1 Phase 1 (`20260827090000_rbac_role_hierarchy_hardening.sql`) hardens RLS around this existing shape rather than reshaping it: added `is_master_admin()` and split the old blanket admin-tier write policy into a master_admin-only policy (full control) and a plain-admin policy restricted to `org_owner`/`org_co_owner` rows only, plus a `granted_by = auth.uid()` check to keep the audit trail honest.
* **Consequences:** No new schema migration for Checkpoint 1 Phase 1, consistent with the roadmap's own stated intent. Any future code/UI referencing "Permitted Admin" (Checkpoint 2's role-management screen, Checkpoint 3's org-scoped surface) should treat `role in ('org_owner', 'org_co_owner')` as that tier, not look for a literal `permitted_admin` string.
* **Follow-up (Checkpoint 1 Phase 3, 2026-08-23):** `org_owner` rows now auto-derive from `organizations.owner_profile_id` (`20260827110000_rbac_auto_derive_org_owner_role.sql`). `org_co_owner` does **not** auto-derive — user confirmed scoping Phase 3 to owner-only, since no co-owner concept exists anywhere in the schema/app yet (no flag on `org_speakers` or `affiliation_requests`). Checkpoint 2/3 need to design an actual co-owner designation mechanism before `org_co_owner` rows can populate; until then it's a supported-but-unused role value.


---

## ADR-009: Organization broadcasting V1

Owner decision 2026-10-01: membership rows authorize organization actions; roster cards are display data. Roles are scoped and independent from platform broadcaster approval and video/audio grants. Personal and organization approval are separate. Use owner OAuth and encrypted server credentials for a single verified YouTube channel, with three independent non-reusable feeds. Canonical sessions carry presenter/content owner/destination/occurrence identity; every occurrence requires acceptance. Organization-only presenters need no personal channel. Default rollout off, explicitly enable pilot organizations, and require a real three-show pilot before release. Complete broadcasts before feed retirement; show termination pending on provider failure. Ownership transfer requires both parties and no active sessions, followed by channel reconnection. Public replays are best effort with accurate status. This supersedes the organization deferral and ADR-007's absence of a co-owner model; it grants no platform-wide privileges to organization staff.

**Phase 4 completion (2026-10-01, `20261001160000_organization_v1_notifications.sql`):**
- *Events are server facts.* Triggers on sessions, memberships, invitations and ownership write `org_v1_events` rows, one per recipient and subject revision (series assignment/cancellation events collapse to one per series per Riyadh day so a four-week series is not 28 notifications). Clients read only their own rows and mark them read; they cannot insert. Push is a separate service job (`dispatch-organization-events`, dedicated key) that leases each event/device once and honours `notification_push_preferences` (live alerts vs. organization work). The in-app inbox never depends on push.
- *Confirmed starts* notify followers of the content owner (organization, or presenter for personal shows) unless the session is hidden from discovery, plus organization owner/co-owner/manager. Presenters and moderators are not told about their own start.
- *Invitation binding.* A pending invitation addressed to a verified email binds to that account when it lists its invitations — the same binding the inviter's lookup makes when the account already exists — so it can be answered in-app; share links keep their single-use token. Either transfer party may withdraw a pending transfer.
- *Availability.* Membership rows expose `v1_enabled` (global flag or pilot) and pending transfer state, so the UI never offers an action the server would refuse. New organization applications follow their own server switch, `organization_applications_open` (default off, trigger-enforced), separate from the V1 rollout flag. Rollout switches count as **off** when unread; safety switches keep counting as on.
- *Web links* use Flutter's hash routes (`/#/org-invite/…`, `/#/channel-connected`); path-style deep links are not used.

## ADR-011: Server-side YouTube public reads on web

Owner requested a secure repair of empty web Archives/playlists on 2026-10-05.
The deployed browser bundle had no key and the Vercel environment had no YouTube
setting. Web uses the same-origin `/api/youtube` function with its server-side
`YOUTUBE_API_KEY`; native retains its build-time key. No YouTube key is compiled
into web JavaScript. The function accepts only bounded public GET queries for
the existing channel, archive, playlist, statistics and live reads, caches
successful responses, and returns sanitized errors. It uses no OAuth credentials
or service-role database key. Production builds require the server setting.
Guest reads remain public; browser origin checks are not authentication.
Provider quota controls and distributed Firewall rate limits remain separate
operational controls. Setup and verification: `doc/YouTube_web_configuration.md`.

## ADR-012: Low-latency go-live (2026-10-19)

Owner targets: a new live reaches viewers in under 15 s (ideally 3 s), the
camera-to-viewer delay stays at 5–10 s and never above 12 s, and ending is as
fast as starting.

- **Latency:** new YouTube broadcasts request `latencyPreference: ultraLow`
  (YouTube's 2–5 s mode; no closed captions, max 1080p, which our presets
  respect), falling back to `low` when YouTube refuses it. Encoder keyframes
  every 1 s. Normal latency (the old default) cannot meet the 12 s ceiling.
- **Handshake early:** the studio prepares the presenter's own phone broadcast
  as soon as it opens. Trade-off accepted: a studio visit that never goes live
  still spends YouTube quota (create feed/broadcast/bind, then delete), and
  the broadcast is listed on YouTube as upcoming while the studio is open, as
  it already was during Preview. A 90 s reuse grace and reuse of a leftover
  preparation limit the cost; the reconcile job ends expired preparations.
- **Confirmation in one call:** `broadcast-control` waits for YouTube (1 s
  checks within a 15 s budget) instead of the phone polling every 3 s.
- **Viewer signal:** session changes into or out of `live` send a public
  Realtime broadcast with no ids (`catalog_changed`); clients re-read what they
  may see. Profiles RLS still keeps other accounts' rows off Realtime.
- **End:** the phone screen closes once the camera stops; the server end and
  its feed cleanup continue after the response.

## ADR-008: Bundled Three-City Vector Map Pack, One Viewport Policy
* **Status:** `PROPOSED` (branch `codex/tricity-map-upgrade`, 2026-09-26; awaiting independent audit and owner approval)
* **Context:** The Spatial Map drew Esri/OSM raster tiles only while the backend was reachable, fell back to three unsourced city polygons offline, allowed a Saudi-wide camera (zoom 5, centre-only constraint) and showed missing-data tiles at deep zoom. The venue picker used its own online OSM layer and guessed neighbourhood addresses from latitude thresholds. Research and plan: `brief/research/p5-tricity-map-upgrade/`.
* **Decision:** Keep flutter_map (now 8.3.2) and render a hash-verified regional Protomaps pack (`project/assets/maps/tricity/`, z0-15, 11.9 MB) with flutter_map_vector_tiles 2.9.0. Its published PMTiles reader speaks HTTP ranges only, so a bounded in-memory range client (`local_pmtiles.dart`) feeds it without a server, parser or fork. `MapPackController` owns pack verification and themes, independent of `AppProvider` connectivity. Native builds read the pack from the installed bundle (no device storage writes); the web gets an explicit "Prepare offline map" that stores the shell, pack and label fonts in Cache Storage behind a network-first service worker. Every camera path uses `MapViewportPolicy` (whole-viewport containment, overview-derived minimum zoom, maximum 18, no rotation). Venue eligibility is a finite, non-null point inside the three-city venue rectangle; records elsewhere stay in the rest of the app. No city polygons ship until licensed municipal geometry exists.
* **Consequences:** Streets and labels are designed to work offline on first native launch (the map path has no network code), but this is **unverified on hardware**: no fresh offline install on a phone has been run yet. They work on prepared browsers (verified in Chrome only). The APK grows about 12.3 MB. The web start-up script (`web/flutter_bootstrap.js`) does not register Flutter's deprecated service worker, because that worker shares the site scope with the offline map worker and unregisters whatever owns the scope when it activates. Map updates ship with app releases (no remote update service). Labels use platform default fonts because the renderer ignores style font names; on the web those fonts come from the engine CDN and are cached only by preparation. Accurate city outlines remain an open owner decision. A future renderer/pack change must re-run `tool/maps` validation and the map tests, and keep the manifest hashes in step (`.gitattributes` marks the pack `-text`).

---
type: decisions
project: Streamer_app
updated: 2026-10-21
---

# 🏛️ Architecture Decision Records (ADRs): Streamer App

> Key architectural, UX, and technical decisions governing the Educational Streamer App.

## ADR-014: Taysir, the mosque lessons programme, inside Hadayah Live (2026-10-21)

Owner request: build the reviewed "Taysir in Hadayah Live" prototype into the
app on our Supabase, taking Taysir's features but not its code or security
model (review: `brief/research/taysir/2026-10-21_TAYSIR_DNA_HEALTH_AND_INTEGRATION.md`).

- **Authority is two organization-scoped permission keys**, not new role tiers:
  `activities.coordinate` and `activities.submit` in `user_permissions`, read
  through `has_permission()`. Org owners and co-owners coordinate their own
  organization implicitly and grant `activities.coordinate` to members; a
  master admin switches Taysir on per organization (`taysir_organizations`).
  Coordinators must be organization members (ADR-007's `org_co_owner` rules
  are unchanged).
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
  persona switcher on the Me tab. Taysir has its own `StatefulShellRoute`
  (`/taysir`, lessons, map, me) and root routes for detail, submit, report,
  claim and console pages; public pages need no sign-in.
- **Switching:** Settings → About's logo switches between Hadayah Live and
  Taysir (ADR-013). Shared `/taysir/...` links open for everyone.

Consequences: migration `20261021120000_taysir_lessons_programme.sql` must be
deployed before configured builds can show Taysir (they show the branded
"unavailable" state until then). Push reminders for Taysir are stored but not
sent yet (`dispatch-upcoming-reminders` does not read `taysir_reminders`).
Taysir's real data (43 preachers with phone numbers) is not imported;
coordinators import a CSV in the console.

## ADR-013: Hidayah Gold is the only design; the logo switches applications (2026-10-21)

The green design and its runtime palette remap are removed. Gold is the
source token set (`canopy_tokens.dart`, `app_theme.dart`); `AppPalette` holds
plain gold constants. The Settings → About logo no longer toggles a palette:
it switches the application between Hadayah Live (`/feed`) and Taysir
(`/taysir`) through `AppExperience` (`lib/core/providers/app_experience.dart`),
a per-device preference saved before it applies. When Taysir is chosen the
router sends `/feed` to `/taysir`. The retired `hidayah_palette_enabled` key
is deleted on first start. Website layouts are always on at 1024 px and wider.
Both Android launcher aliases are kept so component state survives updates;
the launcher icon is gold on Android, iOS and web.

Consequences: guests cannot reach Settings, so the switch needs a signed-in
account; anyone can open Taysir from a shared link.

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

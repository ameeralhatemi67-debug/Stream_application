---
type: audit
project: Streamer_app
phase: 4 of 8
created: 2026-08-20
status: complete
---

# 📋 Phase 4 — Missing & Incomplete Features Inventory (Admin / Streamer / Organization / Viewer)

**Method:** Reconciled `doc/new feature list.md`, `doc/fix bug list.md` (including your own "new Edits to work on" notes at the bottom, which are effectively a live incomplete-features list you wrote yourself), `doc/roadmap to publishing.md`'s Phase 5 active-sprint list, and the actual `lib/` source tree, into one matrix per role. Status definitions: **Done** = built and working per your own docs; **Partial** = built but with known gaps; **Stub** = UI exists but routes to `FeatureInProgressModal` or has placeholder behavior; **Missing** = not started.

---

## 1. Cross-cutting (affects every role, not role-specific)

| Feature | Status | Notes |
|---|---|---|
| Backend / database | **Missing** | Everything runs on-device via `SharedPreferences`. This is the single biggest structural gap — it's why RBAC, moderation, and data persistence are all client-side-only (see Phase 1). No amount of role-specific polish fixes this; it's an architecture decision for you to make (Firebase, a small custom API, etc.) and it gates real multi-device/multi-admin use. |
| Push notifications (FCM/APNs) | **Missing** | Explicitly unchecked in `new feature list.md` §1. In-app notification center (`notification_center_sheet.dart`) works while the app is open; nothing reaches a locked screen or terminated app. |
| Geofencing / proximity alerts | **Missing** | Unchecked in `new feature list.md` §1. Also would require adding real device location (currently absent, see Phase 2) — not a small add-on. |
| iOS platform | **Missing entirely** | No `ios/` folder exists in the project at all (see Phase 2). Everything Apple-specific starts from zero. |
| In-app account/data deletion | **Missing** | Flagged in Phase 3 as a hard store-submission blocker for both platforms. |
| Live chat moderation (report/block/mute) | **Missing** | Flagged in Phase 3 as an Apple Guideline 1.2 risk. |
| Consent / privacy-notice step in onboarding | **Missing** | Flagged in Phase 1 & 3. |
| Sign in with Apple | **Missing** | Only Google Sign-In + guest mode exist; needed for iOS per Phase 3. |
| Automated tests | **Done, but scope-limited** | `STATUS.md` reports 93/93 (or 83/83, the doc has both numbers in different places — worth reconciling) passing, `flutter analyze` clean. Good baseline, but by nature these are unit/widget tests for existing features — they wouldn't catch any of the gaps in this document since there's nothing to test yet for features that don't exist. |

---

## 2. Viewer side

| Feature | Status | Notes |
|---|---|---|
| Discovery feed (live hero carousel, VOD grid, category filters, bookmarks) | **Done** | `discovery_feed_screen.dart` is built out; matches `STATUS.md` claims. |
| Spatial GIS map (venue discovery, live/offline/audio pin states) | **Done** | Confirmed via `spatial_map_screen.dart` and widget set; the gray-tile bug from `fix bug list.md` is marked resolved. |
| Live video/audio playback (YouTube embed) | **Done, with known caveats** | Works per ADR-006, but inherits the WebView hardening gaps from Phase 1 (unrestricted JS, open navigation). |
| Live chat, reactions, Q&A | **Partial** | Chat/reactions/Q&A UI exists and functions, but with none of the moderation tooling flagged in Phase 3 — functionally complete for a demo, not complete for a public release with strangers chatting. |
| Follow / reminders | **Done** | `toggleReminder`/`isReminderSet` implemented per `new feature list.md` §2. |
| Venue navigation / RSVP | **Partial** | Venue sheet with seating/gate info works; `User Flow & UX Ergonomics Audit` §Journey Phase 4 notes the "Directions" action copies a URL to clipboard rather than launching a native Google Maps intent — a real, if minor, functional gap. |
| Guest browsing without forced sign-up | **Done** | Guest viewer flow exists (`viewer_setup_screen.dart`), though the UX audit flags friction in how it's presented (display name required upfront with no clear "skip" affordance). |
| Bilingual EN/AR with RTL | **Done** | 100% key symmetry claimed and independently plausible given the `easy_localization` setup reviewed. |
| Report/block a stream, streamer, or chat message | **Missing** | No such affordance found anywhere in the reviewed screens. |
| Data export / "download my data" | **Missing** | Ties to Phase 3's PDPL gap. |

---

## 3. Streamer (Individual Broadcaster) side

This role has the most granular incomplete-item detail because you wrote a lot of it down yourself in `doc/fix bug list.md`'s "new Edits to work on" section — reproduced here as a checklist rather than prose so it's trackable, cross-referenced against what the code actually does today where I could verify it:

| Feature | Status | Notes |
|---|---|---|
| Google Sign-In / Log-In with account picker | **Partial — and one item is now also a security fix, not just UX** | Your note asks that sign-in let the user *pick* which Google email to use rather than auto-assigning one. Phase 1 found the deeper version of this problem: the auth service's catch-block doesn't just skip account-picking, it fabricates a fake successful login as a hardcoded super-admin email on *any* exception. Fixing account-picking properly and removing the fallback should be done together. |
| "Full Name" auto-fill from Google account | **Needs verification** | Your note asks whether this is hardcoded or pulled from the real account. Confirmed in code: `google_auth_service.dart` does use `account.displayName ?? account.email.split('@').first` from the real Google account on the success path — it's only hardcoded to "Amir Al-Hatemi" in the fallback/error path (the same bad fallback from Phase 1). So: correct on the happy path, wrong (and insecure) on the error path. |
| Channel banner / avatar upload — any-ratio with auto-fit + manual re-arrange | **Partial** | `image_arrange_modal.dart` exists and is the right idea, but your own note says the arrange behavior "is not working good" and asks to copy X's (Twitter's) crop-and-reposition approach — logged as a known-broken feature, not a missing one. |
| Broken/gray image detection with user-facing error flag | **Missing** | No such error-flagging found in the image upload flow. |
| Custom "Primary Academic / Content Field" — user-added custom tags, up to 6 | **Partial** | Your note describes wanting a "+ add Custom" option; `fix bug list.md` separately logs an overflow bug (9.9px) specifically in this "+ add Custom" control on phone-sized viewports — so the feature is present but has an active layout bug. |
| YouTube handle/URL format validation | **Missing** | Your note asks for a simple pattern check (`https://www.youtube.com/@...` or `@...`); not confirmed as implemented. |
| YouTube handle *live* verification (does the channel actually exist) | **Missing** | Your note explicitly separates this from the format check above and says the "Valid YouTube Broadcast target verified" message should only show after a real check — currently it's unclear whether any live verification exists, and your note implies it currently shows unconditionally, which is misleading to applicants and reviewers alike. |
| Map-based location picker with auto-fill of venue description | **Done (picker), Partial (auto-fill)** | `LocationPickerModal` exists; whether picking a map point auto-populates the "Campus, Hall or Venue Description" text field as your note requests wasn't independently confirmed in this pass. |
| Saudi phone number validation (10 or 12 digits, `+966`/`0` prefixes, strip spaces) | **Missing** | No phone-format validation logic found in the files reviewed; flagged as open in your own notes too. |
| Masking the displayed phone number so it's not directly callable | **Missing** | Explicit ask in your notes; not found implemented. |
| Terms & Conditions checkbox at final review step, with dynamic "Streamer" vs "Organization" label | **Partial** | Terms & Conditions viewer/editor exists in Admin Hub and Settings per `STATUS.md`; whether it's wired into `apply_step_5_review.dart` with the mandatory checkbox and correct dynamic label wasn't independently confirmed this pass — worth a direct check in Phase 6. |
| Editable review step ("Edit Step" jump buttons) | **Missing** | Called out in the UX audit (§1.3) as a real friction point — currently requires repeated "Back" taps. |
| Phone-viewport overflow bugs (Step 3, two separate 9.9px overflows) | **Open bug, not a missing feature** | Explicitly logged in your own notes; carried forward here so it doesn't get lost. |
| Streamer Studio (Go Live controls, format switch, RTMP/YouTube target) | **Done** | `rtmp_ip_dialog.dart` and related studio screens are built; the earlier note about IP validation is a robustness gap, not an absence (see Phase 1's revised low-severity rating). |
| VOD archive & playlists | **Done** | `vod_models.dart` and playlist viewer/grid widgets exist per the `lib/` listing and `new feature list.md`. |

---

## 4. Organization side

| Feature | Status | Notes |
|---|---|---|
| Org vs. Individual account type distinction | **Done** | Modeled throughout (`org_venue_branch_model.dart`, `org_speaker_model.dart`, `org_broadcaster_permissions.dart`). |
| Dedicated Organization profile screen (spatial pin, roster, schedules, capacities) | **Missing** | Explicitly listed as unchecked in both `roadmap to publishing.md` Phase 5 and `new feature list.md` §7 — this is your own current "active sprint" item, not yet built. |
| Multi-streamer roster management under one org | **Partial** | Data model exists (`org_speaker_model.dart`, roster fields in the application model); full management UI for adding/removing speakers with auto-fill from existing handles is called out as still needed in your own application-wizard notes (Step 3.5). |
| Bi-directional affiliation requests (streamer↔org) | **Done** | `OrgAffiliationRequestModel`, `JoinOrgModalSheet`, and `OrgManagementView`'s accept/decline flow are all present and match `STATUS.md`'s claims. |
| Multi-branch venue management | **Partial** | `org_venue_branch_model.dart` exists; your own notes ask for a "main location + branches" pattern in Step 4 for orgs specifically, distinct from how it's currently handled — worth a direct UI check in Phase 6. |
| Granular broadcast permissions (video/audio/location per speaker) | **Done** | `org_broadcaster_permissions.dart` models this; matches `STATUS.md`'s "Granular RBAC Permissions" claim — though see Phase 1: these permissions are enforced client-side only, so "done" here means "the UI and data model exist," not "this can't be bypassed." |
| Organization audit trail | **Done** | `org_audit_log_entry.dart` + seeded examples in `admin_database_service.dart` are implemented and functional (as client-side storage — same RBAC caveat applies). |
| Step 3.5 — add streamers while applying as an Organization | **Partial** | Present as a concept in the wizard (mentioned in `STATUS.md`); your own notes ask for a specific interaction (a "+" button per streamer, auto-fill if the handle already exists in the system) that wasn't independently confirmed as fully built this pass. |

---

## 5. Admin side

| Feature | Status | Notes |
|---|---|---|
| Broadcaster application verification queue | **Done** | `AdminHubScreen`, backed by `AdminDatabaseService`'s applications repository, with seeded realistic test data. |
| Approve / reject / request-changes workflow | **Done** | `updateApplicationStatus()` supports all three states with reviewer notes. |
| Dynamic Terms & Conditions / governance editor | **Done** | `TermsAndConditionsModel` + live editor per `STATUS.md`. |
| Viewer analytics | **Done (basic)** | `viewer_analytics_model.dart` + repository exist; depth/accuracy of the analytics themselves wasn't assessed in this pass. |
| Organization management (approve org registrations, manage affiliations) | **Done** | `OrgManagementView` is a substantial (54KB) implemented screen. |
| Multi-account Super Admin RBAC | **Built, but see Phase 1** | Functionally present exactly as documented — three hardcoded emails get admin rights — but this is the single biggest security finding in the whole audit (client-side allowlist + auth-bypass fallback both grant this same privilege unintentionally). "Done" and "safe" are different questions here. |
| **Live chat / content moderation tools** (as opposed to broadcaster-application moderation) | **Missing** | This is a distinct feature from everything else in this section — nothing in `AdminHubScreen` touches what's said in a live chat while a stream is running. Flagged in Phase 3 as an Apple review risk. |
| Batch actions / advanced filtering in verification queue | **Missing** | Explicitly listed as a current-sprint target in `roadmap to publishing.md` Phase 5 ("Advanced verification queue filtering, batch actions... streamlined inspection sheets"), not yet built per that same doc's checkbox state. |
| Route protection for `/admin` | **Missing (security-critical)** | Covered in depth in Phase 1 (VULN-RBAC-01) — the admin nav item is hidden from non-admins in the UI, but the route itself has no guard. Listed here too because it's as much a "missing feature" (access control) as it is a vulnerability. |

---

## 6. What this inventory feeds into

Phase 6 (role-by-role deep audit) will take each of these four sections and go one level deeper — actually opening the specific screens flagged as "Partial" or "needs verification" above to confirm the exact current behavior, rather than relying on cross-referencing docs. Phase 8 will merge this with the security, permissions, and legal findings into one final prioritized punch list.

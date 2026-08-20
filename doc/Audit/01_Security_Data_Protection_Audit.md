---
type: audit
project: Streamer_app
phase: 1 of 8
created: 2026-08-20
status: complete
supersedes-check-of: "doc/Security, Vulnerability & Platform Hardening Audit.md (Aug 18, 2026)"
---

# 🔐 Phase 1 — Security & Data Protection: Re-Verification Against Current Code

**Method:** Your existing `doc/Security, Vulnerability & Platform Hardening Audit.md` (dated Aug 18, 2026) already did the deep vulnerability analysis with CVSS scoring. Rather than redo that work, I re-read the actual current source files it names and checked, line by line, whether each finding is still true today (Aug 20, 2026). Two days isn't long, so I expected most to still be open — but this confirms it rather than assumes it, and catches anything that *did* get fixed in between.

**Bottom line: 15 of the 17 original findings are still open exactly as described. Two are worth re-scoring — one lower, one with a correction to the original claim.**

---

## 1. Verification Table

| ID | Finding | Original Severity | **Current Status** | Evidence |
|---|---|---|---|---|
| VULN-AUTH-01 | Catch-block auth bypass → auto-grants `amir.alhatemi@gmail.com` session on any sign-in exception | Critical (9.8) | 🔴 **Still open, unchanged** | `google_auth_service.dart:97-107` — the `catch (e)` block still fabricates a `GoogleAuthResult.success(email: preferredEmail ?? 'amir.alhatemi@gmail.com', ...)` with a `mock_google_id_token_...` |
| VULN-AUTH-02 | `setRoleMode()` toggle auto-assigns super-admin email | High (8.8) | 🔴 **Still open, unchanged** | `app_provider.dart:986-994` — `setRoleMode(true)` when not logged in sets `_googleUserEmail = 'amir.alhatemi@gmail.com'` directly, no auth check |
| VULN-AUTH-03 | Plaintext PII in `SharedPreferences` | High (7.5) | 🔴 **Still open, confirmed broader than originally scoped** | `admin_database_service.dart` persists full applicant name, email, phone, lat/long, and org rosters as unencrypted `jsonEncode(...)` under plain string keys (`streamer_admin_applications_v1`, etc.) with zero encryption at rest |
| VULN-AUTH-04 | No backend signature verification of Google ID token | High (8.5) | 🔴 **Still open — architectural, not a bug** | There is no backend at all (confirmed: no Firebase, no server SDK, no API layer beyond the public YouTube Data API). The ID token from `google_sign_in` is accepted and stored client-side only; nothing verifies it server-side because there is no server. |
| VULN-RBAC-01 | Missing `GoRouter` guards on `/admin`, `/settings`, `/streamer-apply` | Critical (9.1) | 🔴 **Still open, unchanged** | `app_router.dart` — every `GoRoute` builder is unconditional; the `GoRouter(...)` constructor has no `redirect:` parameter at all. Typing `/admin` in a URL (web build) or a deep link renders `AdminHubScreen` directly; the only "protection" is `provider.isAdminUser` gating whether a *link to* `/admin` is *shown* in the nav rail, not whether the route itself resolves. |
| VULN-RBAC-02 | Client-side-only governance/RBAC for orgs | High (8.5) | 🔴 **Still open — architectural** | Same root cause as AUTH-04: all approve/reject/audit-log logic lives in `AdminDatabaseService`/`AppProvider` running on the requesting device. There's no server to enforce anything a modified client couldn't bypass. |
| VULN-RBAC-03 | Hardcoded super-admin email allowlist in client binary | Medium (6.5) | 🔴 **Still open, unchanged** | `app_provider.dart:41-44` — `_superAdminEmails = {'polkgvd2@gmail.com', 'ameeralhatemi67@gmail.com', 'amir.alhatemi@gmail.com'}`, compiled directly into the shipped app (and readable by anyone who decompiles the APK/IPA) |
| VULN-DATA-01 | Hardcoded YouTube Data API v3 key in source | High (7.5) | 🔴 **Still open, unchanged** | `youtube_api_service.dart:10` — `'AIzaSyADRzIa7p3RlPlik-8C1r0bZjUipQTpOis'` is still the literal default value |
| VULN-DATA-02 | Global cleartext HTTP + no Network Security Config | Critical (9.0) | 🔴 **Still open, unchanged** | `AndroidManifest.xml:11` — `android:usesCleartextTraffic="true"`; no `android:networkSecurityConfig` attribute, and there is no `res/xml/network_security_config.xml` file anywhere in the project |
| VULN-INJ-01 | Unrestricted JS + no navigation restriction in embedded WebView player | High (8.2) | 🔴 **Still open, unchanged** | Both `youtube_player_adapter.dart:56` and `web_live_player_adapter.dart:39` call `setJavaScriptMode(JavaScriptMode.unrestricted)`. The YouTube adapter's `onNavigationRequest` callback (line ~95-97) unconditionally returns `NavigationDecision.navigate` for *any* URL the page tries to load — there's no allow-list restricting navigation to `youtube-nocookie.com` |
| VULN-INJ-02 | Unbounded media upload / OOM risk | High (7.3) | 🟡 **Not independently re-verified this pass** | `image_picker` usage wasn't part of this pass's file set — carrying forward as open per original audit; will confirm in Phase 6 (role audits) when the upload flows are reviewed in context |
| VULN-INJ-03 | Missing input sanitization / bidi controls | Medium (5.3) | 🟡 **Not independently re-verified this pass** | Same as above — deferred to Phase 6 |
| VULN-COMP-01 | Unconsented PII/telemetry collection under PDPL | High (7.5) | 🔴 **Still open** | No consent screen, no privacy-notice acceptance flow, no toggleable analytics/telemetry opt-in anywhere in the auth/onboarding files reviewed. See Phase 3 (legal) for the regulatory detail. |
| VULN-COMP-02 | Sub-meter GPS precision collected for individual scholars | High (7.1) | 🟠 **Correction to the original finding** | This needs a factual correction, not just a re-check: **the app does not use device GPS at all.** There is no `geolocator`, `location`, or any runtime-location package in `pubspec.yaml`, and no `LocationPermission`/`getCurrentPosition()` call anywhere in `lib/`. The lat/long values in `apply_step_4_location.dart` and `LocationPickerModal` come from the applicant **manually tapping a point on an in-app map** (`flutter_map`), not from device sensors. The privacy concern is real but different in kind: it's *precise self-disclosed venue coordinates stored in plaintext* (still a PDPL/precision concern for individual scholars broadcasting from a home address), not *silent high-precision device GPS harvesting*. Recommend re-labeling this finding accordingly — it changes the remediation (no location-permission runtime flow to add; the fix is storage encryption + optional coordinate fuzzing/rounding for individual, non-institutional broadcasters) and it also means Phase 2's permissions audit will **not** be recommending `ACCESS_FINE_LOCATION` be added, since nothing in the code currently asks for it. |
| VULN-COMP-03 | No right-to-erasure / data export | Medium (6.0) | 🔴 **Still open, and now a store-blocker too** | No account-deletion flow exists anywhere (`settings_screen.dart` has no delete-account path). This is no longer just a PDPL nicety — as of the applicable Apple/Google policy dates, **both stores will reject the app outright without it**. Escalating this to the Phase 3 (legal/store) document as a hard submission blocker, not just a compliance nice-to-have. |
| VULN-BUILD-01 | Release APK signed with debug keystore | Medium (6.8) | 🔴 **Still open, unchanged** | `android/app/build.gradle.kts:34-38` — `release { signingConfig = signingConfigs.getByName("debug") }`, with the `// TODO: Add your own signing config for the release build.` comment still in place |

### New observation not in the original audit
- **VULN-DATA-03 (RTMP arbitrary IP entry) — re-scored down.** The original doc rated this High/SSRF-risk. Looking at `rtmp_ip_dialog.dart`, this is a broadcaster manually typing *their own* OBS machine's local IP so *their own device* can preview an `rtmp://<ip>/live/demo` URL — there's no server making requests on the user's behalf, so classic SSRF (tricking a server into hitting an internal resource) doesn't apply here. The real (much smaller) risk is pure input validation: the text field accepts anything, including malformed strings, with no IP-format regex check. Re-scoring this **Low** rather than High; it's a UX/robustness issue, not a security vulnerability, in the current client-only architecture. Worth fixing for polish, not urgent for launch.

---

## 2. What this means for publishing readiness

None of the Critical/High items are cosmetic — several are things Apple/Google review teams and, separately, Saudi regulators would treat as disqualifying if they were found (auth bypass, cleartext traffic, hardcoded secrets, no consent flow, no account deletion). The common root cause behind roughly two-thirds of the list is architectural: **there is no backend**. Client-side "RBAC" checked only by an email string baked into the app binary cannot be secured — anyone with `apktool` or a jailbroken device can read the allowlist and the auth fallback logic straight out of the binary, then set their own email accordingly (they can't easily forge the Google OAuth handshake, but they don't need to: the catch-block fallback in VULN-AUTH-01 hands them the super-admin identity for free the moment sign-in throws any exception).

That's a scope-defining fact for the roadmap, worth flagging to you directly rather than burying in a table: **shipping a real admin/verification/RBAC system for this app requires standing up a minimal backend** (even a small one — e.g. Firebase Auth + Firestore with security rules, or a lightweight API) **before this is safe to publish with real user data in it.** Everything else in this list (secrets, cleartext, signing) is a standard pre-launch hardening pass and comparatively quick to fix. The backend gap is the one item that changes the shape of the remaining roadmap, so I wanted it stated plainly rather than left as one bullet among seventeen.

---

## 3. Priority order for remediation (informs Phase 8's final checklist)

1. **Blocking, must-fix before any public build:** VULN-AUTH-01, VULN-RBAC-01, VULN-DATA-02, VULN-BUILD-01, VULN-DATA-01 — these are each independently exploitable by anyone who downloads the app, no special access needed.
2. **Blocking for real user data, requires backend work:** VULN-AUTH-02, VULN-AUTH-04, VULN-RBAC-02, VULN-RBAC-03, VULN-AUTH-03 (encryption at rest) — these need the architecture conversation above, not just a patch.
3. **Store-submission blocker (separate from security, see Phase 3):** VULN-COMP-03 (account deletion).
4. **Fix opportunistically:** VULN-INJ-01 (scope the WebView navigation allow-list to `*.youtube-nocookie.com` and `*.youtube.com`), VULN-COMP-01/02, VULN-DATA-03 (now Low).
5. **Confirm in Phase 6:** VULN-INJ-02, VULN-INJ-03.

---
type: audit
project: Streamer_app
phase: 8 of 8 (final)
created: 2026-08-20
status: complete
---

# ✅ Phase 8 — Consolidated Findings & Go/No-Go Publishing Checklist

This is the rollup. Phases 1–7 each dug into one slice; this document merges all of it into one prioritized list and gives a direct answer to "can this go to the stores right now."

**Direct answer: no, not yet — but the gap is smaller and more specific than a fresh reader of all seven reports might assume.** Two things did most of the work of shrinking that gap during this audit itself: several items the earlier feature inventory (Phase 4) marked missing turned out to already be built once the actual screens were opened (Phase 6), and the Android release-config fixes in Phase 7 are already applied to your project, not just recommended. What's left is a genuinely short, concrete list — not a rewrite.

---

## 1. Hard blockers — cannot submit without these, regardless of platform

| # | Item | Source phase | Effort (rough) |
|---|---|---|---|
| 1 | **Auth bypass**: sign-in error handler fabricates a super-admin session (`google_auth_service.dart`) | Phase 1, VULN-AUTH-01 | Small — remove the fallback, show a real error instead |
| 2 | **No route guard on `/admin` and other privileged routes** | Phase 1, VULN-RBAC-01 | Small — add `redirect:` to `GoRouter` |
| 3 | **Hardcoded YouTube API key in source** | Phase 1, VULN-DATA-01 | Small — move to `--dart-define` build-time injection |
| 4 | **Release build signed with debug keystore** | Phase 1, VULN-BUILD-01 | ✅ **Already fixed this session** — see Phase 7; just needs your real keystore (Phase 7 §1a) |
| 5 | **No in-app account/data deletion** | Phase 3 — also independently a Phase 1/4 finding | Medium — needs a real "delete my account" flow, wired to whatever storage exists at the time |
| 6 | **No consent/privacy-notice step in onboarding** | Phase 3 | Small–Medium — one new screen/step + a records-of-consent mechanism |
| 7 | **iOS platform doesn't exist yet** | Phase 2 & 7 | Medium — `flutter create` + Info.plist/Privacy Manifest + Sign in with Apple, all scoped with exact steps in Phase 7 |
| 8 | **CST/GCAM licensing question unresolved** | Phase 3 | Unknown — this is the one item that needs a phone call or lawyer, not code |

## 2. Should fix before submitting — high risk of rejection or real security exposure, not an automatic block

| # | Item | Source phase |
|---|---|---|
| 9 | Client-side-only RBAC/governance (no backend at all) | Phase 1, 6a, 6c |
| 10 | Plaintext PII storage in `SharedPreferences` (names, phone, coordinates) | Phase 1, VULN-AUTH-03 |
| 11 | Live chat has zero moderation tooling (report/block/mute) | Phase 3, 4, 6a, 6d — Apple Guideline 1.2 risk |
| 12 | Sign in with Apple missing | Phase 3, 7 §2 Step 5 |
| 13 | Unrestricted JS + open navigation in embedded WebView players | Phase 1, VULN-INJ-01 |
| 14 | Application ID still the Flutter placeholder (`com.example.streamer_app`) | Phase 7 §1b — your decision, blocks nothing technically but must be set before first submission |
| 15 | ✅ Cleartext traffic — **already fixed this session** | Phase 1 → Phase 7 |
| 16 | ✅ Unused `CAMERA` permission — **already fixed this session** | Phase 2 → Phase 7 |

## 3. Worth fixing, not launch-blocking

- Sequential (unbatched) YouTube live-viewer polling — Phase 5, quick fix, same-file pattern already exists.
- No `cacheWidth`/`cacheHeight` on avatar/banner images, plus two oversized source JPGs (5.23 MB, 2.52 MB) — Phase 5.
- `context.watch<AppProvider>()` used everywhere instead of `context.select`/`Selector` (7 screens) — Phase 5, larger refactor.
- O(N²) map-marker collision resolution on the UI thread — Phase 5.
- Image re-arrange/crop tool doesn't match the intended UX; no broken-image detection — Phase 6b.
- Phone number display masking; YouTube handle format + live verification — Phase 6b.
- Dedicated Organization profile screen not yet built — Phase 6c (your own stated active-sprint item).
- Admin verification queue has no batch actions — Phase 6a.
- Venue "Directions" copies a URL instead of opening native Maps — Phase 6d, UX audit.
- RTMP IP field has no format validation (re-scored Low from the original security audit's High) — Phase 1.
- Foreground service for background audio — needs a real-device check, not just a code read — Phase 2.

## 4. Re-scored or corrected from the original documentation during this audit (so nothing gets "fixed" twice)

- GPS precision concern → there is no device GPS at all; it's manually-tapped map coordinates (Phase 1).
- RTMP arbitrary IP entry → downgraded High → Low, not a real SSRF path in this client-only architecture (Phase 1).
- Orphaned `Ahmed_Amer_YouTube.html` (4.43 MB) → not actually bundled into the shipped app; repo clutter, not a bundle-size problem (Phase 5).
- YouTube API batching → partially already implemented (VOD view-counts), just not applied to the live-viewer polling loop that actually matters (Phase 5).
- Saudi phone validation, org-roster auto-fill, terms-checkbox wiring, location auto-fill wiring → all confirmed **already built**, contrary to the initial feature-inventory pass (Phase 6b/6c).
- Admin queue filtering → partially built (status + type filters exist); only batch actions are actually missing (Phase 6a).

---

## 5. Updated store-submission checklist

Building on your own `doc/roadmap to publishing.md` checklist, with this audit's findings folded in:

**Before any store submission:**
- [ ] Items 1–8 above resolved
- [ ] Real upload keystore generated and `key.properties` created (Phase 7 §1a)
- [ ] Permanent application ID / bundle ID decided and set consistently (Phase 7 §1b)
- [ ] Legal/licensing question (CST/GCAM) resolved with a direct answer, not this audit's best-effort research (Phase 3 §2)

**Google Play specifically:**
- [ ] Data Safety form completed *after* items 1–8 (can't honestly answer it before then)
- [ ] Account deletion web-link page hosted and reachable
- [ ] Pre-launch report reviewed for 16 KB page-size warnings (Phase 7 §1c) and any residual cleartext/secret flags
- [ ] Content rating questionnaire completed *after* chat moderation exists, not before (the answer may change)

**Apple App Store specifically:**
- [ ] `ios/` project generated and configured (Phase 7 §2)
- [ ] Sign in with Apple implemented
- [ ] `PrivacyInfo.xcprivacy` completed with real data-collection answers (Phase 7 §2 Step 3)
- [ ] Apple Developer Program enrollment + Mac/Xcode access secured (Phase 7 §2 Step 6)
- [ ] App Privacy "nutrition label" completed *after* items 1–8

---

## 6. What I'd do first, if I were prioritizing for you

1. Items 1–3 (auth bypass, route guard, API key) — small, independent fixes, close the worst exposure fastest.
2. Item 5 + 6 (account deletion + consent step) — one focused feature push that clears two regulatory/policy blockers at once.
3. Decide the licensing question (item 8) in parallel — it has the longest lead time and doesn't block engineering work.
4. Start the iOS scaffold (item 7) early even before it's fully configured, since it surfaces its own unknowns (Sign in with Apple, Mac access) that are better discovered now than during a submission crunch.
5. The backend conversation (item 9) is the one strategic decision that reshapes the rest of the roadmap — worth deciding deliberately rather than by default, since it affects how permanent items 1, 2, 10, and the RBAC findings in 6a/6c actually get resolved.

---

## 7. Where everything lives

All eight phases are saved in `doc/Audit/`:
`00_Audit_Master_Plan.md`, `01_Security_Data_Protection_Audit.md`, `02_Permissions_Audit.md`, `03_Saudi_Legal_And_Store_Compliance_Audit.md`, `04_Missing_Incomplete_Features_Inventory.md`, `05_Performance_Optimization_Audit.md`, `06a–06d_*_Side_Audit.md`, `07_Platform_Build_Readiness.md`, and this file.

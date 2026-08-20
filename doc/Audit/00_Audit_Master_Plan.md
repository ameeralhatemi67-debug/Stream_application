---
type: audit-plan
project: Streamer_app
created: 2026-08-20
status: active
---

# 🧭 Publishing Readiness Audit — Master Plan
**Target:** Educational Cloud Streaming Platform ("Streamer App"), Saudi Arabia (Eastern Province)
**Goal:** Get the app safely and legally ready for submission to the Apple App Store and Google Play Store.
**Method:** One phase at a time. Each phase produces its own report in `doc/Audit/`, ends with a short list of findings and open questions, and waits for your go-ahead before the next phase starts.

---

## 0. What I already know before starting (grounding, not a finding yet)

I read the project's existing docs so this audit builds on top of your work instead of repeating it:

- `Core_files/STATUS.md`, `README.md`, `decisions.md`, `PRODUCT.md` — architecture, tech stack, ADRs.
- `doc/roadmap to publishing.md` — your own 8-phase roadmap; Phases 1–4 marked done, Phase 5 (polish) active, Phases 6–7 (Android/iOS platform prep) and 8 (submission) not started.
- `doc/Security, Vulnerability & Platform Hardening Audit.md` (Aug 18, 2026) — already a deep, CVSS-scored security audit with 17 findings, 4 of them Critical.
- `doc/User Flow & UX Ergonomics Comprehensive Audit.md` — UX heuristic audit, overall score 76/100.
- `doc/Performance, Rendering & Resource Optimization Report.md` — rendering/memory/perf audit with specific hotspots.
- `doc/fix bug list.md`, `doc/new feature list.md` — bug/feature backlogs.
- `project/pubspec.yaml`, `project/android/app/src/main/AndroidManifest.xml`, and a full listing of `project/lib/`.

Quick facts that shape the plan:

- **Stack:** Flutter, `provider` for state, `go_router`, YouTube-only streaming (`youtube_player_iframe` + `flutter_vlc_player` for RTMP), `flutter_map` for GIS, `google_sign_in`, `easy_localization` (EN/AR). **No backend/database** (no Firebase, no server) — everything including "admin" moderation and RBAC currently lives in client-side state (`AppProvider`, `SharedPreferences`).
- **Platforms present on disk:** `android/`, `web/`, `windows/`. **There is no `ios/` folder at all** — the iOS platform target hasn't even been generated yet. This alone blocks any iOS submission until it's created and configured.
- **Android manifest today** only requests `INTERNET`, `ACCESS_NETWORK_STATE`, `CAMERA`, `READ_EXTERNAL_STORAGE` (≤32), `READ_MEDIA_IMAGES`, and has `usesCleartextTraffic="true"`. It does **not** yet have the location/notification/foreground-service permissions your own roadmap describes as needed — meaning the roadmap describes a future state, not the current one.
- The existing Security audit already flags critical items (auth bypass, missing route guards, hardcoded API key, cleartext traffic, plaintext PII storage, no PDPL consent flow) — these are Aug 18 findings; Phase 1 below will re-check whether any have since been fixed rather than assuming they're still open.

None of this is the full audit yet — it's just the map I'll use to sequence the work.

---

## 1. How the audit is organized

Your ask maps onto 8 phases. Each phase = one focused pass, one deliverable file, one checkpoint with you.

| # | Phase | Deliverable file | Builds on |
|---|-------|-------------------|-----------|
| 1 | **Security & Data Protection** — re-verify the existing security audit against the current code (what's fixed, what's still open), plus anything store-specific (secrets handling, transport security, backend trust boundary) | `01_Security_Data_Protection_Audit.md` | existing Security audit |
| 2 | **Permissions Audit** — Android manifest permissions vs. actual usage, missing iOS `Info.plist` usage strings (once iOS exists), runtime-permission UX, over-asking | `02_Permissions_Audit.md` | new |
| 3 | **Saudi Legal & Store Policy Compliance** — Saudi PDPL/SDAIA, CITC content & streaming rules, data residency, required account-deletion feature, Sign in with Apple requirement, age rating/content moderation duties for live user chat, Play Data Safety form, Apple Privacy Nutrition Label, export-compliance | `03_Saudi_Legal_And_Store_Compliance_Audit.md` | new — I'll web-search current regulations, since these change and can't come from memory |
| 4 | **Missing & Incomplete Features Inventory** — a single completeness matrix across Admin / Streamer / Organization / Viewer: done, partial, stubbed (`FeatureInProgressModal`), or not started; reconciles your `fix bug list.md` / `new feature list.md` backlogs into one picture | `04_Missing_Incomplete_Features_Inventory.md` | fix bug list, new feature list, roadmap |
| 5 | **Performance & Optimization** — re-verify the existing performance audit against current code, add app-size/cold-start/battery items specific to store review | `05_Performance_Optimization_Audit.md` | existing Performance audit |
| 6 | **Role-by-Role Deep Audit** — one short report per side, each covering functional completeness + security/permission implications + UX blockers specific to that role: <br>6a Admin, 6b Streamer/Broadcaster, 6c Organization, 6d Viewer | `06a/b/c/d_*_Side_Audit.md` | UX audit + Phases 1–4 |
| 7 | **Platform Build Readiness** — Android release signing/R8/target-SDK/16KB-page-size, and iOS from scratch (generate the `ios/` project, Xcode config, entitlements, `PrivacyInfo.xcprivacy`, provisioning) | `07_Platform_Build_Readiness.md` | roadmap Phases 6–7 |
| 8 | **Consolidated Findings & Go/No-Go Checklist** — everything rolled into one prioritized remediation list (Critical/High/Medium/Low) with rough effort, plus an updated store-submission checklist | `08_Consolidated_Findings_And_Publishing_Checklist.md` | all of the above |

---

## 2. Working agreement

- I'll do **one phase at a time**, in the order above unless you tell me to reorder or skip.
- After each phase I'll post a short summary in chat and save the full detail to the file — you don't have to read the whole file to stay in the loop.
- Where a finding is a **judgment call for you** (e.g., "do you want in-app account deletion or web-based deletion", "individual scholars only or do orgs need company registration docs"), I'll flag it rather than assume.
- Legal/regulatory content (Phase 3) will be clearly marked as informational, not legal advice — Saudi PDPL enforcement details and store policies should be confirmed with a local lawyer before submission.
- All files land in `doc/Audit/` in your project folder, same place as your other audits.

---

## 3. Suggested order & why

Security (1) and the iOS-missing / permissions gap (2) come first because they're the kind of thing that either blocks a submission outright or is expensive to retrofit later. Legal (3) comes next since it can run in parallel with your own business-side steps (Play Console / Apple Developer enrollment, business registration) and has long lead times. Feature completeness (4) and performance (5) come before the role-by-role pass (6) so that pass has full context. Platform build readiness (7) is last before the final rollup (8) since it depends on everything else being known.

If you'd rather start somewhere else (e.g., jump straight to "what's missing" before security), just say so.

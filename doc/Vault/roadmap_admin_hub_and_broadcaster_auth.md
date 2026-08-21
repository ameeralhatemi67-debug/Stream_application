---
type: roadmap
tags: [admin-hub, roadmap, verification, database, governance, milestones]
project: Streamer_app
updated: 2026-08-17
version: 1.0.0
---

# 🗺️ Feature Roadmap: Admin Hub, Broadcaster Verification & Platform Governance

> **Feature Target:** Production Admin Moderation Portal, In-App Application Workflow, Persistent DB Layer & Dynamic Governance.  
> **Parent Documents:** [[doc/technical_specs_admin_hub_and_governance.md|Technical Specs]] | [[Core_files/README.md|Core README]] | [[Core_files/STATUS.md|System Status]]

---

## 🎯 Phase Breakdown & Sprint Milestones

```
+---------------------------------------------------------------------------------------------------------------+
|                                    ADMIN HUB & GOVERNANCE EXECUTION ROADMAP                                   |
|                                                                                                               |
|  [PHASE 1] ─────────────► [PHASE 2] ─────────────► [PHASE 3] ─────────────► [PHASE 4] ─────────────► [PHASE 5] |
|  Database Layer &         In-App Broadcaster       Admin Moderation Hub     Terms & Conditions       Testing & |
|  Data Models Schema       Application Sheet        Desktop Dashboard        Governance Manager       Hardening|
+---------------------------------------------------------------------------------------------------------------+
```

---

### 📦 Phase 1: Database Architecture & Data Layer
* **Milestone 1.1:** Create `BroadcasterApplicationModel` supporting dual-track accounts (Individual Scholar vs Organization Venue) with JSON serialization.
* **Milestone 1.2:** Create `TermsAndConditionsModel` with bilingual English & Arabic Markdown storage.
* **Milestone 1.3:** Build `AdminDatabaseService`:
  - Persistent local storage engine with fallback caching.
  - CRUD operations for applications (`submitApplication`, `approveApplication`, `rejectApplication`, `deleteApplication`).
  - Pre-seeded realistic pending applications (*KFUPM AI Research Center* and *Dammam Medical College Lecturer*) for immediate verification testing.
  - CRUD operations for Terms & Conditions and Viewer engagement analytics.
* **Milestone 1.4:** Connect `AdminDatabaseService` into [`AppProvider`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/providers/app_provider.dart).

---

### 📝 Phase 2: In-App "Become a Broadcaster / Register Org" Flow
* **Milestone 2.1:** Design and build `BroadcasterApplicationSheet` bottom-sheet modal:
  - Account Type Segmented Switcher (`🎓 Individual Scholar` vs `🏢 Academic Institution / Venue`).
  - Form validation: Name, Title, University/Org, GPS coordinates, YouTube channel handle, bio.
  - High-contrast dark theme form elements with Tajawal Arabic RTL support.
* **Milestone 2.2:** Add application launch triggers to:
  - Viewer Profile Header ("Apply to Become a Broadcaster").
  - Settings Screen ("Register an Organization / Apply for Verification").
  - Onboarding Screen.
* **Milestone 2.3:** Implement live Application Status Tracking Banner (`Under Review ⏳`, `Approved ✅`, `Changes Requested ✏️`).

---

### 🛡️ Phase 3: Desktop Admin Hub Dashboard (`AdminHubScreen`)
* **Milestone 3.1:** Implement desktop-only route `/admin` in `app_router.dart` gated by `provider.isAdminUser` (`amir.alhatemi@gmail.com`) and screen width $\ge 900\text{px}$.
* **Milestone 3.2:** Build Top KPI & Operational Metrics Grid:
  - Active Live Streamers, Pending Verification Requests, Verified Organizations, Logged-in Viewers, Daily Lectures.
* **Milestone 3.3:** Build **Tab 1: Verification Queue**:
  - Application cards highlighting Scholar vs Organization requirements.
  - `Approve` action: Automatically converts application into a live `StreamerModel` on the GIS Map and Discovery Feed.
  - `Reject` action: Dialog prompt for admin feedback reason.
* **Milestone 3.4:** Build **Tab 2: Streamers & Organizations Registry**:
  - Searchable table/grid of all active streamers.
  - Quick actions: Edit Profile, Toggle Verification Badge, Suspend, Delete.
* **Milestone 3.5:** Build **Tab 3: Viewers & Engagement Analytics**:
  - Breakdown of active viewer sessions, guest viewers, logged-in Google accounts, total lecture bookmarks, and physical auditorium RSVPs.
* **Milestone 3.6:** Build `StreamerDetailsInspectionSheet`: 360° modal view of applicant/streamer metadata.

---

### 📜 Phase 4: Platform Terms of Service & Governance Manager
* **Milestone 4.1:** Build **Tab 4: Terms & Governance Editor** in Admin Hub:
  - Bilingual Markdown editor tabs (English & Arabic).
  - Version increment and "Save & Publish" button.
* **Milestone 4.2:** Build Viewer-facing Terms & Conditions Modal Sheet accessible from Settings and Onboarding.

---

### 🧪 Phase 5: Verification & End-to-End Testing
* **Milestone 5.1:** Unit Tests (`admin_hub_and_governance_test.dart`):
  - `TC-ADM-01`: RBAC Gating (Super Admin vs Viewer access).
  - `TC-ADM-02`: Application submission and JSON round-trip.
  - `TC-ADM-03`: Approval state machine and automated GIS Map marker creation.
  - `TC-ADM-04`: Rejection workflow with feedback notes.
  - `TC-ADM-05`: Terms & Conditions update and version increment.
* **Milestone 5.2:** Static Analysis: Verify `flutter analyze` passes with 0 issues.
* **Milestone 5.3:** Run complete regression test suite (`flutter test`) verifying all 50+ unit tests pass.

---

## 📊 Definition of Done (DoD)

1. [x] Complete Technical Specifications created in `doc/technical_specs_admin_hub_and_governance.md`.
2. [x] Feature Roadmap created in `doc/roadmap_admin_hub_and_broadcaster_auth.md`.
3. [x] Research paper on Industry Standards, Pitfalls & Governance created in `research docs/Admin Hub, Multi-Tier Auth & Platform Governance Architecture.md`.
4. [x] `AdminDatabaseService` implemented with seed data, persistent JSON storage, and state machine integration.
5. [x] `BroadcasterApplicationSheet` implemented with Scholar vs Org validation, GIS presets, and live Settings status banner.
6. [x] `AdminHubScreen` built with 5 desktop modules, live pending badge, and multi-account Super Admin RBAC.
7. [x] 100% clean `flutter analyze` and all 61 automated unit tests passing across all test suites.

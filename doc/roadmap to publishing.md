---
type: roadmap
tags: [streaming, flutter, publishing, app-store, play-store, roadmap, android, ios]
project: Streamer_app
updated: 2026-08-17
status: active
---

# 🗺️ Master Roadmap to Publishing

> **Comprehensive End-to-End Release Strategy for the Educational Cloud Streaming Platform (Streamer App)**  
> Links: [[Core_files/README.md|Core README]] | [[Core_files/STATUS.md|System Status]] | [[Core_files/Desgin.md|Design System]] | [[doc/fix bug list.md|Bug Fix Log]] | [[doc/new feature list.md|Feature Backlog]]

---

## 🎯 Release Vision & Target Milestones

```
+-----------------------------------------------------------------------------------------------------------------------+
|                                           STREAMER APP PUBLISHING ROADMAP                                             |
|                                                                                                                       |
|  [PHASE 1] ──► [PHASE 2] ──► [PHASE 3] ──► [PHASE 4] ──► [PHASE 5] ────────► [PHASE 6 & 7] ───► [PHASE 8]             |
|  Core Bug      Accounts,     Audio &       Admin Hub     Feature Polish    Android & iOS     Store Submission      |
|  Fixes & Map   Workspaces    Notifications & Governance  & Organizations   Platform Prep     & Live Launch         |
|  (✅ DONE)      (✅ DONE)     (✅ DONE)     (✅ DONE)     (⚡ ACTIVE SPRINT) (⏳ NEXT UP)      (⏳ FINAL STEP)        |
+-----------------------------------------------------------------------------------------------------------------------+
```

---

## 📅 Phase-by-Phase Roadmap

### 🪲 Phase 1: Critical Bug Remediation & Core Stabilization (✅ COMPLETED)
* [x] **Map Tile Render Fix:** Resolved the gray map canvas bug when circular profile avatars enter the viewport by introducing `RepaintBoundary`, robust memory image caching (`memCacheWidth`/`memCacheHeight`), and vector pin fallback.
* [x] **YouTube Live Stream Receiver Fix:** Normalized YouTube Live URL parsers, resolved Error 150/152/153 with Strict-Origin Referrer policies, and verified both live streams & archived VOD playback.
* [x] **Navigation & State Verification:** Verified `go_router` shell branch state preservation across all tabs during live streams.

---

### 🔐 Phase 2: Accounts, Workspaces & Broadcaster Verification (✅ COMPLETED)
* [x] **Google Authentication:** Integrated Google Sign-In with persistent session storage and Multi-Account Super Admin RBAC (`polkgvd2@gmail.com`, `ameeralhatemi67@gmail.com`, `amir.alhatemi@gmail.com`).
* [x] **Dual Broadcaster Hierarchy:** Full data model & UI support for **Individual Scholars** vs. **Organization Venues** with seating capacity and GIS coordinates.
* [x] **Broadcaster Application Flow ("Become a Streamer"):** In-app `BroadcasterApplicationSheet`, credential submission, live status banner in Settings, and Desktop Admin Verification Queue.
* [x] **User Onboarding Flow:** High-contrast introductory tour (`OnboardingScreen`) introducing physical venue discovery + live digital streaming.

---

### 🎙️ Phase 3: Audio Streaming & In-App Alerts (✅ COMPLETED)
* [x] **Audio-Only Streaming Engine:** Low-latency, bandwidth-friendly live audio engine (`BroadcastFormat.audioOnly`, `isAudioOnlyLive`) with global floating mini-player.
* [x] **Dynamic Audio Visualizer UI:** Kinetic audio waveforms, frequency bars, and atmospheric ambient pulse animations in `live_broadcast_screen.dart`.
* [x] **In-App Follow & Calendar Reminders:** Live status alert triggers and upcoming lecture reminders (`toggleReminder`).
* [ ] **Native OS Remote Push Notification Backend (FCM / APNs):** Production cloud messaging backend hook for device lockscreen push notifications.

---

### 🎨 Phase 4: UI/UX Modernization & Desktop Admin Hub (✅ COMPLETED)
* [x] **Design Contract Enforcement:** Full alignment with [`Core_files/Desgin.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/Core_files/Desgin.md) and Impeccable design principles (anti-slop, high contrast, clean minimalist palette).
* [x] **Typography & RTL Harmony:** Fluid Tajawal & Inter font pairing across English (LTR) and Arabic (RTL) locales with 100% symmetric key translations.
* [x] **Micro-interactions:** Smooth map pin pulses, bottom sheet drag gestures, and live chat message feeds.
* [x] **Responsive Breakpoints & Desktop Admin Hub:** Desktop `NavigationRail` sidebar (≥ 900px) with live pending badge and dedicated `/admin` 5-module workspace.
* [x] **Dynamic Platform Governance:** Dynamic Markdown editor in Admin Hub + in-app viewer modal in Settings for Terms of Service, Broadcaster Guidelines, and Saudi PDPL Privacy Policy.

---

### ✨ Phase 5: Feature Expansion & Comprehensive Polish (⚡ CURRENT SPRINT TARGET)
* [ ] **Add Organizations Feature:**
  - Dedicated Organization & Venue profile screen with spatial map auditorium pin, affiliated scholar roster, upcoming lecture schedules, and physical hall capacities.
  - Multi-streamer organization management (ability for verified organizations to host and manage multiple sub-streamers / lectures under their verified institutional umbrella).
* [ ] **Polish "Become a Broadcaster / Register Organization":**
  - Enhanced application form UX with preview summary card, dynamic document/badge asset picker, auto-fill capabilities, and instant revision resubmission.
* [ ] **Polish Log-In & Log-Out Flow:**
  - Seamless 1-tap Google account switching, guest-to-broadcaster state transitions, session persistence hardening, and clear feedback toast/dialogs.
* [ ] **Polish Settings Page:**
  - Layout consolidation, improved typography & hierarchy, cleaner card spacing, and optimized profile avatar customization.
* [ ] **Polish Admin Page (`AdminHubScreen`):**
  - Advanced verification queue filtering, batch actions, interactive audit logs, streamlined inspection sheets, and quick status toggles.
* [ ] **Add / Polish Onboarding Feature:**
  - Interactive multi-step introductory tour highlighting the GIS spatial map, live audio/video stages, and physical attendance RSVP.
* [ ] **Make Visual Polish:**
  - Intentional high contrast, refined Tajawal/Inter typography, smooth elevation shadows, fluid page transitions, and responsive polish across all screen sizes.
* [ ] **Make Feature & Media Polish:**
  - YouTube player buffer handling, PiP mini-player gesture refinement, audio visualizer responsiveness, and error boundary fallbacks.

---

### 🤖 Phase 6: Android Platform Readiness & Hardening
* **Android Permissions (`AndroidManifest.xml`):**
  * `android.permission.INTERNET` & `ACCESS_NETWORK_STATE`
  * `android.permission.ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION` (Runtime permission dialog with rationale)
  * `android.permission.POST_NOTIFICATIONS` (Android 13+ runtime notification permission)
  * `android.permission.FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (for background audio)
* **Build Configuration:**
  * `compileSdkVersion`: 34+
  * `minSdkVersion`: 24 (covers 95%+ of active devices)
  * `targetSdkVersion`: 34
* **Release Signing & Obfuscation:**
  * Configure `key.properties` with production upload keystore (`upload-keystore.jks`).
  * Enable R8 code shrinking and ProGuard optimization in `app/build.gradle`.
  * Build optimized Android App Bundle: `flutter build appbundle --release`.

---

### 🍎 Phase 7: iOS (Apple) Platform Readiness & Compliance
* **iOS Permissions & Usage Strings (`Info.plist`):**
  * `NSLocationWhenInUseUsageDescription`: Clear Arabic & English explanation for spatial lecture discovery.
  * `NSLocationAlwaysAndWhenInUseUsageDescription`: (If background proximity alerts enabled).
  * `UIBackgroundModes`: `audio` (for background audio lectures) and `remote-notification`.
* **Apple Privacy Manifest (`PrivacyInfo.xcprivacy`):**
  * Declared API usage types (User Defaults, File Timestamps, Disk Space).
  * Declared data collection categories (User ID, Location, Diagnostics).
* **App Transport Security (ATS):**
  * Verify secure HTTPS / WSS endpoints for YouTube embeds, tile servers, and API backends.
* **Release Build & Archive:**
  * Configure Apple Developer Team, Bundle Identifier, and App Store Provisioning Profiles.
  * Build signed archive: `flutter build ipa --release`.

---

## ⏱️ Publishing Timeline & Store Review Estimates

| Milestone | Key Action Items | Estimated Duration | Buffer / Notes |
| :--- | :--- | :---: | :--- |
| **1. Development & Bug Fixes** | Complete Phases 1 through 4 | 2–3 Weeks | Internal QA & code reviews |
| **2. Platform Preparation** | Android & iOS permissions, icons, splash screens, assets | 3–5 Days | Asset generation & config |
| **3. Store Account Setup** | Google Play Console ($25 one-time) & Apple Developer ($99/year) | 2–4 Days | Identity & D-U-N-S verification (if organization) |
| **4. Google Play Closed Testing** | 20 testers opted-in for 14 continuous days (personal accounts requirement) | **14 Days** | Mandatory Google policy requirement |
| **5. Apple TestFlight Beta** | Internal & External TestFlight beta testing | 3–7 Days | Instant for internal, 24h for external |
| **6. Store Listing Preparation** | Screenshots (6.5", 5.5", 12.9" iPad, Android phone/tablet), Privacy Policy URL, Bilingual descriptions | 2–3 Days | English & Arabic store listings |
| **7. Store Review Turnaround** | Submission to Apple App Review & Google Play Review | **1–3 Days (Apple)**<br>**3–7 Days (Google)** | Rejection buffer: allocate +3 days for metadata/permission adjustments |
| **Total Estimated Time to Launch** | From current state to live on App Store & Google Play | **~5 to 6 Weeks** | Parallel tracks can reduce timeline |

---

## 📋 Store Submission Checklist

### 🟢 Google Play Store Checklist
- [ ] Google Play Console developer account verified.
- [ ] App Content Questionnaire completed (Data Safety, Target Audience, Content Rating).
- [ ] Privacy Policy URL hosted and accessible.
- [ ] 20-tester 14-day closed test track completed with feedback logged.
- [ ] High-resolution app icon (512x512 PNG) and Feature Graphic (1024x500 PNG).
- [ ] App screenshots uploaded for phones (at least 4) and 7"/10" tablets.
- [ ] Release Android App Bundle (`.aab`) signed with upload key.

### 🟢 Apple App Store Checklist
- [ ] Apple Developer Program account enrolled and active.
- [ ] App ID, Capabilities, and Provisioning Profiles configured in Apple Developer Portal.
- [ ] App Store Connect record created with bilingual metadata (English & Arabic).
- [ ] Privacy Policy URL and Support URL provided.
- [ ] Privacy Nutrition Labels (App Privacy data collection answers) completed.
- [ ] Screenshots uploaded for 6.7" iPhone (iPhone 15 Pro Max / 16 Pro Max), 6.5" iPhone, and 12.9" iPad.
- [ ] Test demo account credentials provided in App Review Information for reviewers.
- [ ] `.ipa` archive uploaded via Xcode Organizer / Transporter and approved by App Review.

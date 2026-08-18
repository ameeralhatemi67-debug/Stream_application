---
type: project
tags: [streaming, flutter, roadmap, features, backlog]
project: Streamer_app
updated: 2026-08-17
---

# 🚀 Feature Backlog & Requirements List

> **Master Feature Backlog for the Educational Cloud Streaming Platform (Streamer App)**  
> Links: [[Core_files/README.md|Core README]] | [[Core_files/STATUS.md|System Status]] | [[Core_files/Desgin.md|Design Contract]] | [[doc/roadmap to publishing.md|Publishing Roadmap]]

---

## 1. 🔔 Intelligent Notification System
- [x] **Live Followed Streamers:** In-app followed broadcaster state management and real-time top snackbar live alert triggers.
- [x] **Upcoming & Past Streams Reminders:** Calendar-based notification reminders (`toggleReminder`, `isReminderSet`) for scheduled upcoming events.
- [ ] **Native OS Remote Push Notification Backend (FCM / APNs):** Production cloud messaging backend hook for device lockscreen push notifications when app is terminated.
- [ ] **Nearby Spatial Geo-Fence Trigger Service:** Background OS location geofencing service for automatic proximity alerts.

---

## 2. 🎙️ Audio-Only Streaming & Dynamic Visuals
- [x] **Audio-Only Streaming Engine:** Low-bandwidth, high-fidelity audio live stream pipeline (`BroadcastFormat.audioOnly`, `isAudioOnlyLive`) for lectures and podcasts.
- [x] **Dynamic Audio Visualizer UI:** Animated frequency bars, kinetic audio waveforms, and atmospheric ambient pulse stage.
- [x] **Background Audio Playback & Floating Mini-Player:** Global draggable Picture-in-Picture overlay with playback controls persistent across app navigation.

---

## 3. 🏢 Workspaces, Organizations & Multi-Streamer Locations
- [x] **Dual Broadcaster Hierarchy:** Distinctive Scholar vs Organization Venue schemas, squircle badges, and auditorium seating capacity metadata.
- [x] **Multi-Streamer Association:** Organization entity association with multiple academic auditoriums and verified broadcaster umbrellas.
- [x] **Location Venue Hubs:** Spatial map auditorium inspection, venue RSVP tab, and external Google Maps routing deep links.

---

## 4. 🧭 Streamlined User Flow & Navigation
- [x] **Frictionless Discovery-to-Attendance Flow:** Fast onboarding $\rightarrow$ Spatial Map / Discovery Feed $\rightarrow$ Cinema Room / Audio Stage $\rightarrow$ In-person RSVP / Navigation.
- [x] **Contextual Tab Preservation:** `StatefulNavigationShell` branch state retention across Discovery Feed, Spatial Map, Cinema Room, and Desktop Sidebar.
- [x] **Intuitive Guest vs. Authenticated Experience:** Instant guest viewing for all live lectures/map, with contextual prompts for interactive studio and admin tools.

---

## 5. 🔐 Authentication & Account Onboarding (Google Sign-In)
- [x] **Google Sign-In Integration:** 1-tap OAuth login with Google, session persistence, and Multi-Account Super Admin RBAC (`polkgvd2@gmail.com`, `ameeralhatemi67@gmail.com`, `amir.alhatemi@gmail.com`).
- [x] **Polished Visual Onboarding:** High-contrast introductory welcome screen (`OnboardingScreen`) with Viewer vs Broadcaster role selection.
- [x] **User Profile & Preferences:** Custom profile editing, default streaming quality selection, and dynamic governance viewer.

---

## 6. 🎓 Broadcaster Application & Onboarding ("Become a Streamer")
- [x] **In-App Application Form:** Dual-track `BroadcasterApplicationSheet` with real-time validation and 1-tap AlSharqia GIS coordinate presets.
- [x] **Verification Workflow & Status Banner:** Review state machine (`Under Review ⏳`, `Approved ✅`, `Changes Requested ✏️` with feedback notes) and Desktop `AdminHubScreen` Verification Queue.
- [x] **Streamer Studio Activation:** YouTube Live stream linking, RTMP laptop IP configuration, lecture scheduling, and Go Live controls.

---

## 7. ⚡ Active Sprint: Feature Expansion & Comprehensive Polish
- [ ] **Add Organizations Feature:**
  - Dedicated Organization & Venue profile screen with spatial map auditorium pin, affiliated scholar roster, upcoming lecture schedules, and physical hall capacities.
  - Multi-streamer organization management (ability for verified organizations to host and manage multiple sub-streamers / lectures under their verified institutional umbrella).
- [ ] **Polish "Become a Broadcaster / Register Organization":**
  - Enhanced application form UX with preview summary card, dynamic document/badge asset picker, auto-fill capabilities, and instant revision resubmission.
- [ ] **Polish Log-In & Log-Out Flow:**
  - Seamless 1-tap Google account switching, guest-to-broadcaster state transitions, session persistence hardening, and clear feedback toast/dialogs.
- [ ] **Polish Settings Page:**
  - Layout consolidation, improved typography & hierarchy, cleaner card spacing, and optimized profile avatar customization.
- [ ] **Polish Admin Page (`AdminHubScreen`):**
  - Advanced verification queue filtering, batch actions, interactive audit logs, streamlined inspection sheets, and quick status toggles.
- [ ] **Add / Polish Onboarding Feature:**
  - Interactive multi-step introductory tour highlighting the GIS spatial map, live audio/video stages, and physical attendance RSVP.
- [ ] **Make Visual Polish:**
  - Intentional high contrast, refined Tajawal/Inter typography, smooth elevation shadows, fluid page transitions, and responsive polish across all screen sizes.
- [ ] **Make Feature & Media Polish:**
  - YouTube player buffer handling, PiP mini-player gesture refinement, audio visualizer responsiveness, and error boundary fallbacks.
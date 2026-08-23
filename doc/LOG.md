# 📋 Streamer App — Issues & Refactor Backlog (@Log)

> Centralized engineering backlog for future sprint milestones, architectural enhancements, UI/UX redesigns, and deferred polish items.

---

## 📝 1. Streamer Application Wizard & Data Pipeline Overhaul

### 📌 Problem & Context
The streamer application flow currently has two paths with differing data fidelity and needs a complete UX redesign and end-to-end data completeness overhaul.

### 🔍 Target Field Inventory (Mandatory & Optional Fields)
1. **Account Type:** Individual Scholar vs. Educational Organization Venue.
2. **Full Name:** English & Arabic transliteration/translation.
3. **Phone Number:** Saudi PDPL-compliant format (`+966 5X XXX XXXX`).
4. **Email Address:** Pre-filled from authenticated Google session, separate from primary auth identity if custom business email provided.
5. **Bio / Description:** Bilingual academic overview.
6. **Academic Title / Institution:** University, research center, or academy affiliation.
7. **Categories & Topics:** Multi-select topic tags (e.g., `#AI`, `#Fiqh`, `#MedicalScience`).
8. **Location & Venue Coordinates:** City picker, branch names, latitude/longitude via map picker.
9. **Streaming Targets:** Verified YouTube Channel URL and `@handle`.
10. **Media Assets:** Custom Profile Picture and Banner Uploads (with cropping/arrangement).
11. **Organization-Specific:** Sub-speakers roster, branch auditoriums, seating capacity, official website.

### 🛡️ Validation & UX Requirements
- **Strict Error Handling:** Block submission if mandatory fields (name, phone, valid YouTube link, accepted terms) are missing or invalid.
- **Smart Auto-Fill:** Auto-populate authenticated user's Google display name, email, and handle on wizard mount.
- **Full UI/UX Redesign:** Replace the current multi-step wizard with a streamlined, responsive, high-aesthetic application flow.
- **Backend Schema Completeness:** Ensure every single field captured in the UI is stored in Supabase `broadcaster_applications` and propagated to `organizations` / `profiles` upon admin approval.

### 📂 Related Codebase Files
- [[streamer_apply_screen.dart]] (`lib/features/auth/presentation/streamer_apply_screen.dart`)
- [[apply_step_1_identity.dart]] (`lib/features/auth/presentation/steps/apply_step_1_identity.dart`)
- [[apply_step_2_media.dart]] (`lib/features/auth/presentation/steps/apply_step_2_media.dart`)
- [[apply_step_3_professional.dart]] (`lib/features/auth/presentation/steps/apply_step_3_professional.dart`)
- [[apply_step_3_5_org_speakers.dart]] (`lib/features/auth/presentation/steps/apply_step_3_5_org_speakers.dart`)
- [[apply_step_4_location.dart]] (`lib/features/auth/presentation/steps/apply_step_4_location.dart`)
- [[apply_step_5_review.dart]] (`lib/features/auth/presentation/steps/apply_step_5_review.dart`)
- [[broadcaster_application_sheet.dart]] (`lib/features/profile/presentation/widgets/broadcaster_application_sheet.dart`)
- [[image_arrange_modal.dart]] (`lib/features/auth/presentation/widgets/image_arrange_modal.dart`)
- [[location_picker_modal.dart]] (`lib/features/auth/presentation/widgets/location_picker_modal.dart`)
- [[broadcaster_application_model.dart]] (`lib/features/admin/models/broadcaster_application_model.dart`)

---

## 🚀 2. Viewer Onboarding & Profile Picture Selection

### 📌 Problem & Context
When new viewers join, the avatar selector should not display internal asset images of verified scholars as selectable viewer avatars.

### 🛠️ Required Changes
- **Viewer Avatar Options:** Provide:
  1. Default neutral user icon (monogram / vector avatar).
  2. Custom user image upload from device gallery / camera.
- **Asset Privacy:** Restrict bundled scholar photos (`assets/images/Amir_Alhatemi/...`) strictly to official demo seed profiles, never surfacing them in the viewer signup flow.
- **Onboarding Flow Baseline:** Align the v1.0 onboarding overhaul with the drafted initial onboarding flow as the foundation.

### 📂 Related Codebase Files
- [[viewer_setup_screen.dart]] (`lib/features/auth/presentation/viewer_setup_screen.dart`)
- [[welcome_screen.dart]] (`lib/features/auth/presentation/welcome_screen.dart`)
- [[role_select_screen.dart]] (`lib/features/auth/presentation/role_select_screen.dart`)

---

## 🎙️ 3. Audio-Only Stream Playback Investigation

### 📌 Problem & Context
Audio-only broadcasts (such as the 24/7 Quran live audio stream `@AIQuran4KOfficial` / `quran_4k_05`) currently produce no audio on playback in the player screen.

### 🔍 Investigation Items
- **Ingest / Stream Link:** Verify whether the YouTube live video ID / RTMP stream URL is live, expired, or geographically restricted.
- **Audio Pipeline Routing:** Inspect `LiveBroadcastScreen` and `youtube_player_iframe` configuration to ensure background audio and audio-only streams do not mute or fail to buffer when video frame decoding is static.
- **Native Android Foreground Service Audio:** Verify that mobile audio broadcasting properly binds audio tracks to RTMP output.

### 📂 Related Codebase Files
- [[live_broadcast_screen.dart]] (`lib/features/live_stream/presentation/screens/live_broadcast_screen.dart`)
- [[phone_broadcast_screen.dart]] (`lib/features/live_stream/presentation/screens/phone_broadcast_screen.dart`)
- [[rtmp_publisher_bridge.dart]] (`lib/features/live_stream/services/rtmp_publisher_bridge.dart`)

---

## 🔔 4. Streamer Approval Notification & Realtime Client Sync

### 📌 Problem & Context
When an admin approves a pending broadcaster application in the Web Admin Hub:
1. The applicant on mobile stays stuck on `"Application Under Review"` / `/application-pending` screen.
2. The mobile client does not receive an automated notification or realtime push regarding their approval.
3. Unapproved viewers should **not** have access to the "Broadcaster / Streamer Mode Active" toggle until their application is officially approved by an admin.

### 🛠️ Required Changes
- **Approval Notification:** Push an in-app banner / notification when `broadcaster_applications.status` transitions from `pending` to `approved`.
- **Role Mode Gate:** Restrict `isStreamerModeEnabled` toggle in `SettingsScreen` strictly to verified streamers (`profiles.is_streamer == true`) and organization owners. Non-streamers only see "Apply as Streamer".
- **Realtime Status Sync:** Listen to `broadcaster_applications` update events or check application status on app resume.

### 📂 Related Codebase Files
- [[settings_screen.dart]] (`lib/features/profile/presentation/settings_screen.dart`)
- [[application_pending_screen.dart]] (`lib/features/auth/presentation/application_pending_screen.dart`)
- [[admin_hub_screen.dart]] (`lib/features/admin/presentation/admin_hub_screen.dart`)
- [[app_provider.dart]] (`lib/core/providers/app_provider.dart`)

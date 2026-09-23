# P6-07 Broadcast, Channel Sync & Feed Defect Analysis

**Date:** 2026-09-23  
**Status:** **FAILED / SEVERELY IMPAIRED DUE TO BACKEND SCHEMA DRIFT & CLIENT OVERFLOWS**  
**Tested Devices:** Android Physical Phone (`R5CY42JAW4E`), Desktop Chrome (Broadcaster/Admin & Viewer), YouTube Studio Web Dashboard

---

## 1. Executive Summary & Root Cause Breakdown

During live broadcast and channel profile testing, five major issues were observed:

1. **YouTube Studio Receives No Stream Data (`No data`):**
   * YouTube Studio reports *"Connect your encoder to go live"*. The phone encoder (`RtmpPublishEngine`) did not establish a valid RTMP stream to YouTube.
   * On rotation and in landscape mode, the video preview surface turned completely black.
2. **System Does Not Recognize Broadcaster as Live on Other Devices:**
   * Broadcaster appears live on their own phone, but is shown as **offline** on desktop feed, completely missing on viewer feed, and lacks a live pulsing ring on Spatial Map.
   * **Root Cause:** When `AppProvider.toggleBroadcastLive()` is invoked, it calls Postgres RPC `set_live_state()`. This RPC requires checking `device_sessions` to verify broadcaster ownership. Because `device_sessions` does not exist on the hosted database, the database update fails. The phone toggles its local in-memory flag, but `profiles.is_currently_live` remains `false` on the server.
3. **Empty Feed for Viewers (`desktop-viewer-feed-streamers-empty.png`):**
   * Ordinary viewer accounts query the database view `public.streamer_public_profiles`, which filters `WHERE is_streamer = true`.
   * Newly registered accounts have `is_streamer = false` in `profiles`. Without an approved broadcaster application row or admin streamer grant in the database, the account is excluded from the public directory.
4. **Unsynced Profile & Default Mock VODs (`P6-07-mobile-profile-unlinked-default-vods.jpg`):**
   * The channel profile displayed 4 placeholder videos (Lex Fridman/podcast thumbnails, 40:00 duration) instead of the user's real YouTube channel content.
   * Edits to banner/profile done on the phone were not persisted to `profiles` on the server, leaving desktop profile empty.
5. **Mobile Layout Keyboard Overflow:**
   * When opening the keyboard to chat, the screen surfaces **"BOTTOM OVERFLOWED BY 56 PIXELS"**.

---

## 2. Screenshot Catalog & Categorization

All screenshots have been renamed and filed into their corresponding folders:

### A. Issues & Failures (`screenshots/issue/`)

| Standardized Filename | View / Subject | Observation / Root Cause |
| :--- | :--- | :--- |
| **`P6-07-youtube-studio-no-data-encoder-unconnected.png`** | YouTube Studio Live Dashboard | Shows *"No data / Connect your encoder"*. Phone RTMP stream did not reach YouTube ingest server. |
| **`P6-07-desktop-feed-streamer-shows-offline.png`** | Discovery Feed (Broadcaster Desktop) | Card shows "Your Channel" but displays offline state because DB `is_currently_live` is false. |
| **`P6-07-desktop-viewer-feed-streamers-empty.png`** | Discovery Feed (Viewer Account) | Streamers list is completely blank because caller has no streamers matching `is_streamer = true`. |
| **`P6-07-mobile-broadcast-active-chat-reconnecting.jpg`** | Phone Camera Broadcast | Broadcaster active, but chat shows `• Reconnecting...` due to realtime subscription failures. |
| **`P6-07-mobile-broadcast-landscape-black-screen.jpg`** | Landscape Broadcast | Player surface turns completely black on landscape orientation change. |
| **`P6-07-mobile-broadcast-portrait-black-preview.jpg`** | Portrait Broadcast Preview | Camera preview surface lost / rendered black while live flag remains on. |
| **`P6-07-mobile-broadcast-keyboard-overflow-56px.jpg`** | Chat Input with Keyboard | **"BOTTOM OVERFLOWED BY 56 PIXELS"** hazard stripe when software keyboard pushes up chat tabs. |
| **`P6-07-mobile-chat-keyword-blocked-snack.jpg`** | Live Chat Composer | Sent "hello", blocked with *"Message blocked: that language isn't allowed here."* |
| **`P6-07-mobile-profile-unlinked-default-vods.jpg`** | Broadcaster Channel Profile | Displays 4 default podcast mock VODs (40:00) instead of user's synced YouTube channel. |
| **`P6-07-mobile-map-missing-live-indicator.jpg`** | Spatial Map (Al Khobar) | Broadcaster avatar is plotted, but has no live pulse/ring because backend `is_currently_live = false`. |

### B. Minor Edits & UI Drift (`screenshots/small_edit/`)

| Standardized Filename | View / Subject | Observation / Root Cause |
| :--- | :--- | :--- |
| **`P6-07-desktop-profile-empty-no-sync.png`** | Desktop Channel Profile | Shows profile header without banner or videos because local phone edits were not synced to DB. |

### C. Verified UI Components (`screenshots/good/`)

| Standardized Filename | View / Subject | Observation / Root Cause |
| :--- | :--- | :--- |
| **`P6-07-mobile-broadcast-controls-sheet.jpg`** | Broadcaster Quick Controls | Bottom sheet for Mic, Rear Camera, Video Stream, and End Stream renders correctly. |

---

## 3. Why It "Used to Work" vs. Why It Fails Now

In earlier demo / spike phases (v0.5 / v0.6):
1. **Mock In-Memory State:** Toggling live flipped an in-memory Dart variable `_isBroadcastingLive` in RAM. Streamer cards were loaded from hardcoded lists (`mock_streamers.dart`), and video IDs were hardcoded mock strings.
2. **Transition to Truthful Data (v0.7 / P1–P6):** The codebase was refactored to enforce real-world database truth:
   - Live broadcasting requires server confirmation via `set_live_state()`.
   - Broadcaster channels require real profiles in `public.profiles` and `streamer_public_profiles`.
   - Realtime presence requires `device_sessions`.
3. **The Disconnect:** Because the hosted Supabase database was **never updated with the recent migration scripts**, every server-enforced call fails silently or throws PostgREST errors. The phone falls back to local memory, while other clients receive empty responses from the unmigrated database.

---

---

## 4. Architectural References: Planned Logic Pipelines (OBS, Phone & Local)

The three broadcasting logic paths are formally documented and specified in the repository's architectural blueprints:

### 1. Phone Broadcast Pipeline (Mobile Native RTMP)
* **Master Specification:** [`MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md` (Pipeline 6)](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md#L653-L700)
* **Implementation Plan:** [`Phone_to_YouTube_Live_API_Implementation_Plan.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/Roadmap/Phone_to_YouTube_Live_API_Implementation_Plan.md)
* **Logic Flow:** Broadcaster UI $\rightarrow$ `RtmpPublishEngine` (Dart) $\rightarrow$ `RootEncoder` (Android Camera2/AudioRecord native bridge) $\rightarrow$ RTMP Handshake & TCP Socket $\rightarrow$ YouTube Cloud Ingest $\rightarrow$ Supabase `set_live_state()` session logging. Includes native reconnect state machine, video/audio-only static image swapping, and foreground service lifecycle.

### 2. OBS & External Encoder Pipeline (Desktop Studio)
* **Master Specification:** [`MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md` (Pipeline 7)](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md#L702-L732)
* **Setup Guide Spec:** [`Gamified_Streamer_Setup_Guide_Spec.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/Roadmap/Gamified_Streamer_Setup_Guide_Spec.md)
* **Logic Flow:** OBS Studio / vMix on Laptop $\rightarrow$ Direct RTMP Push (`rtmp://a.rtmp.youtube.com/live2`) $\rightarrow$ YouTube HLS Transcoder $\rightarrow$ Streamer registers YouTube Watch/Video ID in App $\rightarrow$ AppProvider updates `profiles.is_currently_live` $\rightarrow$ Spatial Map displays pulsing red radar marker $\rightarrow$ Viewers play via `YouTubePlayerAdapter`.

### 3. Local Wi-Fi Air-Gapped Streaming Pipeline (Zero-Cloud LAN)
* **Master Specification:** [`MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md` (Pipeline 8)](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/MASTER_TASKS_AND_ARCHITECTURE_ROADMAP.md#L734-L760)
* **Deep-Dive Feature Spec:** [`Local_Phone_Streaming_Feature_Spec.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/Roadmap/Local_Phone_Streaming_Feature_Spec.md)
* **Logic Flow:**
  - **Phone-to-Phone Air-Gapped:** Broadcaster Phone runs embedded RTSP/HTTP server + local WebSocket server on ports 8554 & 8080. Announces via mDNS (`_streamer-lan._tcp`). Audience devices on same Wi-Fi discover feed without cloud. Features Host Knocking ("Accept / Deny" admission gatekeeper) and zero PIN requirement.
  - **Laptop Local Server Mode:** Streamer runs MediaMTX / NGINX RTMP on laptop. Broadcaster Studio configures local LAN IP (`rtmp_ip_dialog.dart`). Audience connects via `WebLivePlayerAdapter` / native VLC loopback with `GhostChatFallbackController`.

### 4. Unified Go-Live Studio UI & Architectural Research (With Diagrams)
* **Studio UI Design Spec:** [`Go_Live_Studio_BottomSheet_Redesign_Plan.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/Roadmap/Go_Live_Studio_BottomSheet_Redesign_Plan.md) — Houses the 3-tab selector: `[ 📱 Phone Camera ]` | `[ 🖥️ OBS Studio ]` | `[ 📶 Local Wi-Fi ]`.
* **Cloud Architecture & Ingestion Research (Diagrams):** [`Cloud Streaming Project Viability Research with diagrams.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/research%20docs/Cloud%20Streaming%20Project%20Viability%20Research%20with%20diagrams.md)
* **Bilingual Technical Architecture & Pipeline Flowcharts:** [`Cloud Streaming Project Viability Research - Arabic with new daiagrams.md`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/doc/research%20docs/Cloud%20Streaming%20Project%20Viability%20Research%20-%20Arabic%20with%20new%20daiagrams.md)

---

## 5. Next Step in Acceptance Run

As agreed, we will complete the remaining client-side and UI tests first, and then execute `npx supabase db push` to reconcile the backend.


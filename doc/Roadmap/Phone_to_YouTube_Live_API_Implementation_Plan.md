# Phone-to-YouTube Live Streaming (Automated API Approach) — Implementation Plan

This document outlines the architecture, pipeline, and step-by-step implementation for the automated **Phone-to-YouTube Live** broadcast system, allowing approved streamers to go live directly from their mobile camera & microphone with one tap.

---

## 1. Feature Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Broadcaster UI (Mobile App)                            │
│                                                                             │
│  [AppBar Actions]                                                           │
│  ├── 📡 Gray/Red Cell Tower  ──► Opens Existing OBS/Studio Settings Dialog │
│  └── 📡 Green Cell Tower     ──► Opens Quick Go-Live Setup Sheet (NEW)      │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 Quick Go-Live Setup Sheet (Modal View)                      │
│                                                                             │
│  • Broadcast Title (e.g. "AI & Machine Learning Lecture")                   │
│  • Category & Tags Selector                                                 │
│  • Campus / Venue Location Picker                                           │
│  • Format Toggle: 📹 Camera Video+Audio  |  🎙️ Audio-Only (Podcast Mode)    │
│  • Quality Preset: 480p Low  |  720p Medium  |  1080p High                  │
│  • Action: [🔴 Start Broadcast & Open Camera]                               │
│                                                                             │
│  * NOTE: Never asks for Google account or YouTube URL (already known).     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 YouTube Live Streaming Service (Automated)                  │
│                                                                             │
│  1. `liveBroadcasts.insert`  ──► Creates YouTube live event & gets Video ID │
│  2. `liveStreams.insert`      ──► Requests private RTMP ingest endpoint      │
│  3. `liveBroadcasts.bind`    ──► Connects broadcast event to ingest pipe    │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 Hardware Engine & App Synchronization                       │
│                                                                             │
│  • Passes RTMP URL & Key to `RtmpPublishEngine` (Camera / Mic Encoder)     │
│  • Navigates directly into `PhoneBroadcastScreen`                           │
│  • Updates Supabase: `is_currently_live = true`, `youtube_video_id`         │
│  • Realtime updates trigger for Viewers (Feed, Map & Q&A Chat)              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Specifications & File Plan

### A. New Files to Create

1. **`lib/features/live_stream/services/youtube_live_service.dart`**
   - Implements automated interaction with YouTube Live Streaming API v3:
     - `createBroadcastSession({required String title, required String description, required bool isAudioOnly, required BroadcastQualityPreset quality})`:
       - Calls YouTube API or returns local test endpoint in offline/sandbox mode.
       - Returns record `({String broadcastId, String videoId, String rtmpUrl, String streamKey})`.
     - `endBroadcastSession({required String broadcastId})`:
       - Transitions YouTube broadcast to `complete` (saving the video as a permanent VOD).

2. **`lib/features/live_stream/presentation/widgets/quick_go_live_sheet.dart`**
   - Modal bottom sheet opened when the green cell tower icon is clicked.
   - Form fields:
     - `_titleController`: Pre-populated from streamer customary title or "Live Academic Lecture".
     - Category Chips / Dropdown (`cs_tech`, `islamic_studies`, `languages_ielts`, `medical_health`, etc.).
     - Venue / Location field (pre-filled from profile/application).
     - Format Switch: **Camera Video + Audio** vs **Audio-Only (Podcast Mode)**.
     - Quality Preset Choice: Low (480p), Medium (720p), High (1080p).
     - Submit Button: Shows progress indicator while initializing YouTube API and navigates to `PhoneBroadcastScreen`.

3. **`test/phone_to_youtube_live_service_test.dart`**
   - Unit tests covering `YouTubeLiveService`, `QuickGoLiveSheet` validation, format switching, and provider state synchronization.

---

### B. Existing Files to Modify

1. **`lib/features/profile/presentation/broadcaster_profile_screen.dart`**
   - In `AppBar.actions`:
     - Keep the original `Icons.cell_tower_rounded` (RTMP / OBS dialog).
     - Add the **second** `Icons.cell_tower_rounded` with **`color: AppTheme.accentGreen`** (or `Colors.greenAccent`).
     - Tapping the green icon invokes `QuickGoLiveSheet.show(context)`.

2. **`lib/features/live_stream/presentation/live_broadcast_screen.dart`**
   - In `AppBar.actions`:
     - Add the green cell tower icon next to the existing gray one so streamers can launch the quick go-live flow from the live broadcast viewer screen.

3. **`lib/core/providers/app_provider.dart`**
   - Add helper method `startQuickPhoneBroadcast({...})`:
     - Configures `customLiveTitle`, `customBroadcastType`, `customLiveVenue`, `customLiveCategory`.
     - Sets `phoneBroadcastRtmpUrl` and `phoneBroadcastStreamKey`.
     - Sets `customYouTubeVideoId` to the newly generated broadcast's `videoId`.
     - Updates `isBroadcastingLive = true` and synchronizes with Supabase.

4. **`lib/features/live_stream/presentation/screens/phone_broadcast_screen.dart`**
   - When launched from `QuickGoLiveSheet`, skip the initial preset picker (since already chosen in the sheet) and immediately open the camera preview.

---

## 3. Strict Development Rules

1. **Do NOT ask the user for Google account email or YouTube URL** — these are already stored in `UserProfileModel` and `StreamerModel`.
2. **Do NOT break or remove the existing OBS / RTMP settings dialog** — the gray cell tower icon stays untouched.
3. **Do NOT edit `doc/LOG.md` or `doc/FIXED_LOG.md`** without explicit user permission.
4. Maintain full offline / mock test capability so widget and unit tests pass without requiring a live Google API key.
5. All code must pass `flutter analyze` with 0 warnings/errors and pass `flutter test`.

# 📋 Implementation Plan — Cluster 1: Live Stream Player, Audio & Viewport Enhancements

**Target:** Claude Code & Engineering Team  
**Scope:** Cluster 1 (Tasks 1, 2, 3, 4a, 4b, 5, 6)  
**Location:** `doc/Roadmap/Cluster_1_Live_Stream_Player_Audio_Viewport_Implementation_Plan.md`  
**Dependencies:** Flutter, `youtube_player_iframe`, `webview_flutter`, `wakelock_plus`, `url_launcher`, Supabase, `easy_localization`.

---

## 🎯 High-Level Objective
Elevate the live broadcast viewer and broadcaster experience by resolving audio stream interruptions, introducing smart streamer silence detection, replacing mock quality selectors with real resolution options, supporting auto-rotate landscape fullscreen, implementing rich default and custom stream state placeholders with admin moderation, adding an external YouTube fallback button, and perfecting in-app Picture-in-Picture (PiP).

---

## 🛠️ Step-by-Step Implementation Instructions

### 📌 STEP 1: Fix Audio Stability & Add Streamer Silence / Mic Muted Indicator (Task 1)

#### 1.1 Audio Focus & Background Continuity
- **Target Files:**
  - `project/lib/features/live_stream/presentation/live_broadcast_screen.dart`
  - `project/lib/features/live_stream/presentation/adapters/youtube_player_adapter.dart`
- **Actions:**
  1. In `LiveBroadcastScreen.initState()`: Call `WakelockPlus.enable()` to prevent the OS from sleeping/pausing webviews and audio streams during active live playback. Ensure `WakelockPlus.disable()` is called in `dispose()`.
  2. In `LiveBroadcastScreen._buildLiveStage()`: When `isAudioLive == true`, ensure the underlying player widget (`AbstractVideoPlayer.fromSource`) stays mounted with `autoPlay: true` and is NOT disposed or replaced, allowing audio to stream continuously behind `LiveAudioStageMultiSpeaker`.
  3. In `youtube_player_adapter.dart`: Update `_loadVideoEmbed()` iframe query parameters to include `playsinline=1&enablejsapi=1&autoplay=1&origin=https://youtube-nocookie.com`.

#### 1.2 Silence / Mic Muted Detection Engine
- **Target Files:**
  - `project/lib/features/live_stream/services/rtmp_publish_engine.dart`
  - `project/lib/features/live_stream/presentation/widgets/live_player_overlay_controls.dart`
  - `project/lib/features/live_stream/presentation/live_broadcast_screen.dart`
- **Actions:**
  1. In `RtmpPublishEngine`: Expose `ValueNotifier<bool> isMicSilent` and `bool isMuted`.
  2. In `LiveBroadcastScreen`: Listen for silence/mute events from Realtime stream metadata or player state.
  3. In `LivePlayerOverlayControls`: When silence / mic mute is active, render an animated status pill:
     - 🇬🇧 *"Streamer Microphone Muted / Silent Mode"*
     - 🇸🇦 *"الميكروفون مغلق / البث في وضع الصمت"*

---

### 📌 STEP 2: Real Resolution Options & Audio-Only Cleanup (Task 2)

#### 2.1 Resolution Enum & Overlay Selector
- **Target File:** `project/lib/features/live_stream/presentation/widgets/live_player_overlay_controls.dart`
- **Actions:**
  1. Add `final bool isAudioOnly;` to `LivePlayerOverlayControls` constructor.
  2. Replace `PopupMenuButton<StreamSourceType>` (which had mock strings `1080p60 Local RTMP Loopback`, `720p60 AWS IVS`, `480p YouTube Embed`) with `PopupMenuButton<String>` with values:
     - `auto`: "Auto (Adaptive) / تلقائي"
     - `1080`: "1080p Full HD / عالي الدقة 1080"
     - `720`: "720p HD / دقة 720"
     - `480`: "480p SD / دقة 480"
     - `360`: "360p Data Saver / توفير البيانات"
  3. Wrap the quality selector button in `if (!widget.isAudioOnly)` so it is completely hidden during Audio-Only broadcasts.
  4. Pass `isAudioOnly: isAudioLive` from `LiveBroadcastScreen`.

---

### 📌 STEP 3: Auto-Rotate to Fullscreen Landscape (Task 3)

#### 3.1 Orientation & System UI Mode Toggle
- **Target File:** `project/lib/features/live_stream/presentation/live_broadcast_screen.dart`
- **Actions:**
  1. In `_LiveBroadcastScreenState`: Implement `_handleToggleFullscreen()`:
     ```dart
     void _handleToggleFullscreen() {
       setState(() => _isFullscreen = !_isFullscreen);
       if (_isFullscreen) {
         SystemChrome.setPreferredOrientations([
           DeviceOrientation.landscapeLeft,
           DeviceOrientation.landscapeRight,
         ]);
         SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
       } else {
         SystemChrome.setPreferredOrientations([
           DeviceOrientation.portraitUp,
         ]);
         SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
       }
     }
     ```
  2. In `dispose()`: Always restore `DeviceOrientation.portraitUp` and `SystemUiMode.edgeToEdge`.
  3. Pass `onToggleFullscreen: _handleToggleFullscreen` to `LivePlayerOverlayControls`.

---

### 📌 STEP 4: Stream State Placeholders (Default & Custom) (Tasks 4a & 4b)

#### 4.1 Create Unified Placeholder Overlay Widget (Task 4a)
- **New File:** `project/lib/features/live_stream/presentation/widgets/stream_state_placeholder_overlay.dart`
- **Actions:**
  1. In `abstract_video_player.dart`: Ensure `enum StreamState` includes:
     `initializing, startingSoon, live, paused, buffering, ended, offline, noAudioToken, fallbackError`.
  2. In `stream_state_placeholder_overlay.dart`: Build a responsive, animated widget handling:
     - `initializing`: Loading spinner + "Connecting to live feed... / جاري الاتصال بالبث المباشر..."
     - `startingSoon`: Clock icon / animation + "Broadcast Starting Soon / سيبدأ البث قريباً"
     - `ended`: Flag/check icon + "Broadcast has Concluded / انتهى البث المباشر"
     - `offline`: Satellite/antenna icon + "Broadcaster is Offline / القناة غير نشطة حالياً"
     - `noAudioToken`: Audio warning + "Audio Token Expired / تعذر مزامنة الصوت"
     - `fallbackError`: Error details + "Retry / إعادة المحاولة" + "Open in YouTube / المشاهدة عبر يوتيوب"
  3. Support rendering custom streamer image when provided and approved (see Step 4.2).

#### 4.2 Streamer Custom Cards & Admin Moderation Pipeline (Task 4b)
- **Target Files:**
  - `project/lib/features/profile/presentation/widgets/streamer_editor_sheet.dart`
  - `project/lib/features/admin/presentation/admin_hub_screen.dart`
  - `project/lib/core/services/admin_database_service.dart`
  - `project/lib/core/providers/app_provider.dart`
  - `supabase/migrations/20260830120000_streamer_custom_placeholders.sql`
- **Actions:**
  1. **Database Migration:** Create table `public.streamer_custom_placeholders`:
     - `id uuid primary key, streamer_id uuid, placeholder_type text (starting_soon, intermission, ending), image_url text, status text (pending, approved, rejected), rejection_reason text, created_at timestamptz`.
  2. **Streamer Upload:** In `StreamerEditorSheet`, add upload slots for "Starting Soon Card", "Break Card", and "Ended Card" with image picker and upload to Supabase Storage `streamer-assets/custom_placeholders/`.
  3. **Admin Review Queue:** In `AdminHubScreen`, add "Custom Cards Review" sub-tab where admins preview the uploaded graphics and choose **Approve** or **Reject**. If Rejected, prompt admin for mandatory rejection reason.
  4. **Notification:** On rejection, call `AppProvider.notifyAdminCardEditRequest()` so the streamer receives an immediate notification explaining what to correct.
  5. **Playback Fallback:** If custom card is not approved or null, `StreamStatePlaceholderOverlay` seamlessly uses the polished **Default System Placeholder**.

---

### 📌 STEP 5: Failed Video YouTube Fallback Button (Task 5)

#### 5.1 Direct External Launch
- **Target Files:**
  - `project/lib/features/live_stream/presentation/adapters/youtube_player_adapter.dart`
  - `project/lib/features/profile/presentation/widgets/vod_player_modal_sheet.dart`
- **Actions:**
  1. In `YouTubePlayerAdapter._buildErrorView()`:
     ```dart
     ElevatedButton.icon(
       onPressed: () async {
         final url = Uri.parse('https://www.youtube.com/watch?v=$_currentVideoId');
         if (await canLaunchUrl(url)) {
           await launchUrl(url, mode: LaunchMode.externalApplication);
         }
       },
       icon: const Icon(Icons.open_in_new_rounded, size: 16),
       label: Text('live.open_in_youtube'.tr()),
       style: ElevatedButton.styleFrom(
         backgroundColor: AppTheme.accentRed,
         foregroundColor: Colors.white,
       ),
     )
     ```
  2. Add key `'live.open_in_youtube': 'Open in YouTube'` (EN) and `'المشاهدة عبر تطبيق يوتيوب'` (AR) in `en.json` and `ar.json`.

---

### 📌 STEP 6: In-App Picture-in-Picture (PiP) Floating Mini-Player Fix (Task 6)

#### 6.1 Coordinate Clamping, Persistence & Restore
- **Target Files:**
  - `project/lib/core/widgets/floating_stream_mini_player.dart`
  - `project/lib/core/providers/app_provider.dart`
  - `project/lib/features/live_stream/presentation/live_broadcast_screen.dart`
- **Actions:**
  1. In `LiveBroadcastScreen`: Add a "Minimize to Mini-Player" button in the app bar actions. When tapped:
     - Calls `appProvider.openMiniPlayer(streamId, streamerName, streamTitle, streamUrl, isAudioOnly)`.
     - Calls `Navigator.of(context).pop()` to return the user to the Feed or Map without interrupting audio.
  2. In `FloatingStreamMiniPlayer`: Ensure pan gesture coordinates are safely clamped within screen boundaries `(dx: 12 to screenWidth - playerWidth - 12, dy: 60 to screenHeight - playerHeight - 90)`.
  3. On tap of the mini-player card: Closes mini-player and navigates back to `/live/$streamId`.

---

## 🧪 Verification & Testing Plan

### Automated Tests
Run from `project/`:
```powershell
flutter analyze
flutter test test/live_stream_test.dart
flutter test
```

### Manual Verification Checklist
1. **Audio:** Start a video live stream and an audio-only stream. Lock/unlock the device and ensure audio does not cut off. Toggle mic mute on the streamer phone and verify the "Streamer Microphone Muted" badge appears on viewers.
2. **Quality Options:** Open live controls; verify `{Auto, 1080p, 720p, 480p, 360p}` popup menu. Switch to Audio-Only stream and verify the quality button is hidden.
3. **Fullscreen Auto-Rotate:** Tap expand button in portrait; verify smooth rotation to landscape and immersive mode. Tap exit; verify return to portrait.
4. **Placeholders & Fallback:** Trigger a stream error; verify `StreamStatePlaceholderOverlay` displays with "Open in YouTube" button that launches the YouTube app.
5. **Custom Placeholders:** Upload a custom starting card as a streamer -> verify it shows "Pending" -> Approve/Reject in Admin Hub -> verify notification received and live stream displays custom card.
6. **PiP:** Tap minimize in live stream -> drag floating player across Feed and Map -> tap to restore full broadcast room.

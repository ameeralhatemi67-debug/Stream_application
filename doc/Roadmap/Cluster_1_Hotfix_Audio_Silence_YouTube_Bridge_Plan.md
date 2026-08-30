# 📋 Implementation Plan — Cluster 1 Hotfix: Real Audio State, Silence Detection & YouTube Fallback Bridge

**Target:** Claude Code & Engineering Team  
**Scope:** Audio Playback Hotfix, Real Audio State Synchronization, Multi-URL YouTube Failover, and Ripple Animation Freeze on Inactive Streams.  
**Location:** `doc/Roadmap/Cluster_1_Hotfix_Audio_Silence_YouTube_Bridge_Plan.md`  

---

## 🎯 Root Cause Analysis

1. **Why the Audio Stage was "Faking" Audio Waves on Dead Streams:**
   - In `LiveAudioStageMultiSpeaker`, `_voiceRippleController.repeat()` and `_equalizerController.repeat()` were started unconditionally in `initState()` and ran forever in an infinite loop, regardless of whether the stream was playing, paused, dead, buffering, or offline.
2. **Why Dead Streams were not Detected:**
   - `YouTubePlayerAdapter` loaded the embed HTML without a `JavascriptChannel` listening to YouTube IFrame API events (`onStateChange` and `onError`). When a stream was terminated or returned Error 100/101/150, Flutter remained unaware, leaving `_streamState` stuck.
3. **Why Audio did not Play on Mobile Devices:**
   - Mobile WebViews enforce autoplay audio restrictions. Because `LiveAudioStageMultiSpeaker` paints an opaque layer over the iframe, the viewer could not tap the webview directly. Tapping the stage must send explicit `unMute()` and `playVideo()` JS commands.
4. **Al Quran 4K Stream URL Expiry:**
   - The previous video ID (`kY31f13b-hU`) concluded. We now have a primary active live stream (`jjBoecWjAnw`) and two fallback streams (`PLkCnLrKN8Q`, `hPeOq1Dz5xI`).

---

## 🛠️ Step-by-Step Implementation Instructions

### 📌 STEP 1: Update Streamer Model with Active & Fallback YouTube IDs
- **Target File:** `project/lib/features/profile/models/streamer_models.dart`
- **Actions:**
  1. Add `final List<String> fallbackYoutubeVideoIds;` to `StreamerModel` (defaulting to `const []`).
  2. Update the `quran_4k_05` entry (Lines 441–478):
     ```dart
     youtubeVideoId: 'jjBoecWjAnw',
     fallbackYoutubeVideoIds: ['PLkCnLrKN8Q', 'hPeOq1Dz5xI'],
     ```

---

### 📌 STEP 2: YouTube IFrame JavaScript Event Bridge & Auto-Failover
- **Target File:** `project/lib/features/live_stream/presentation/adapters/youtube_player_adapter.dart`
- **Actions:**
  1. Add `final List<String> fallbackUrls;` and `final VoidCallback? onAutoUnmute;` to `YouTubePlayerAdapter`.
  2. In `_loadVideoEmbed()`, inject JavaScript event listeners in the HTML template and register a `JavaScriptChannel` named `FlutterYouTubeBridge`:
     ```html
     <script>
       // Listen for postMessage from YouTube iframe
       window.addEventListener('message', function(event) {
         try {
           var data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
           if (data && data.event === 'onStateChange') {
             // -1: unstarted, 0: ended, 1: playing, 2: paused, 3: buffering, 5: cued
             FlutterYouTubeBridge.postMessage(JSON.stringify({ type: 'state', value: data.info }));
           }
           if (data && data.event === 'onError') {
             // 2: invalid param, 5: HTML5 error, 100: not found, 101/150: embed blocked
             FlutterYouTubeBridge.postMessage(JSON.stringify({ type: 'error', code: data.info }));
           }
         } catch(e) {}
       });

       // Auto unmute and play function called by Flutter
       function forceUnmuteAndPlay() {
         var frame = document.querySelector('iframe');
         if (frame && frame.contentWindow) {
           frame.contentWindow.postMessage(JSON.stringify({ event: 'command', func: 'unMute', args: [] }), '*');
           frame.contentWindow.postMessage(JSON.stringify({ event: 'command', func: 'playVideo', args: [] }), '*');
         }
       }
     </script>
     ```
  3. In `onMessageReceived`:
     - If `type == 'error'` or `state == 0 (ended)`:
       - Attempt to switch to the next fallback ID in `fallbackUrls`.
       - If all fallbacks are exhausted, set `_streamState = StreamState.offline` or `StreamState.fallbackError`.
     - If `state == 1 (playing)`:
       - Set `_streamState = StreamState.live` and notify parent.
     - If `state == 2 (paused)`:
       - Set `_streamState = StreamState.paused`.
     - If `state == 3 (buffering)`:
       - Set `_streamState = StreamState.buffering`.
  4. Expose method `unMuteAndPlay()`:
     ```dart
     void unMuteAndPlay() {
       _webViewController.runJavaScript('forceUnmuteAndPlay();');
     }
     ```

---

### 📌 STEP 3: Tie Voice Ripple & Equalizer to Real Audio/Play State
- **Target File:** `project/lib/features/live_stream/presentation/widgets/live_audio_stage_multi_speaker.dart`
- **Actions:**
  1. Add `final bool isPlaying;` and `final StreamState streamState;` properties to `LiveAudioStageMultiSpeaker`.
  2. In `didUpdateWidget()` and `initState()`:
     - Check if `widget.isPlaying && widget.streamState == StreamState.live`.
     - If **TRUE**: Start/resume `_voiceRippleController.repeat()` and `_equalizerController.repeat(reverse: true)`.
     - If **FALSE** (paused, buffering, ended, offline, or fallbackError):
       - Stop `_voiceRippleController.stop()`, stop `_equalizerController.stop()`.
       - Reset animation values to `0.0` so waveforms stay flat and ripples disappear completely!
  3. In `onStageTap`:
     - Trigger unmuting callback to ensure WebViews begin audio playback immediately upon tap.

---

### 📌 STEP 4: Wire Audio Stage & Player in `LiveBroadcastScreen`
- **Target File:** `project/lib/features/live_stream/presentation/live_broadcast_screen.dart`
- **Actions:**
  1. Pass `fallbackUrls: streamer.fallbackYoutubeVideoIds` to `AbstractVideoPlayer.fromSource`.
  2. Pass `isPlaying: _isPlaying` and `streamState: _streamState` to `LiveAudioStageMultiSpeaker`.
  3. In `LiveAudioStageMultiSpeaker.onStageTap`:
     - Set `_isPlaying = true`.
     - Invoke `unMuteAndPlay()` on the player adapter.

---

## 🧪 Verification Plan

### Automated Tests
Run from `project/`:
```powershell
flutter analyze
flutter test test/live_stream_test.dart
flutter test
```

### Manual Verification
1. **Al Quran 4K Playback:** Open Al Quran 4K stream -> verify audio recitations play out loud.
2. **True State Synchronization:**
   - When stream is live and playing: Ripples pulse and equalizer animates.
   - When paused or stream is dead: Ripples freeze/disappear and equalizer goes flat.
3. **Auto-Failover:** If primary stream is offline, verify player automatically loads the fallback URL without user intervention.
4. **Stage Tap Unmute:** Tap audio stage -> confirms immediate audio output without needing to touch hidden iframe controls.

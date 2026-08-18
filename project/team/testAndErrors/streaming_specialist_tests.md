# Streaming & Media Engine Test Matrix & Verification Checklist

**Module:** Streaming, Media & Real-Time Engine  
**Target:** Version 0.1 / Version 0.3 Deliverables  
**File Location:** `team/testAndErrors/streaming_specialist_tests.md`

---

## 1. Unit Test Matrix

### 1.1 `VodModel` Unit Tests (`test/unit/vod_model_test.dart`)
- [ ] **TC-VOD-01: Localized Title Selection**
  - Verify `getLocalizedTitle('en')` returns English title string.
  - Verify `getLocalizedTitle('ar')` returns Arabic title string.
- [ ] **TC-VOD-02: Localized Description Selection**
  - Verify `getLocalizedDescription('en')` returns English description string.
  - Verify `getLocalizedDescription('ar')` returns Arabic description string.
- [ ] **TC-VOD-03: Duration String Formatting**
  - Test `formattedDuration` for seconds under 1 hour (e.g. 3240 seconds -> `"54:00"`).
  - Test `formattedDuration` for seconds over 1 hour (e.g. 4050 seconds -> `"1h 7m"`).
- [ ] **TC-VOD-04: JSON Serialization Round-Trip**
  - Test `VodModel.fromJson()` parses expected json structure cleanly.
  - Test `toJson()` preserves all keys (`vod_id`, `streamer_id`, `youtube_video_id`, `duration_seconds`, etc.).

### 1.2 `GhostComment` & `GhostCommentPool` Unit Tests (`test/unit/ghost_comments_test.dart`)
- [ ] **TC-GHOST-01: Localized Message and Sender Extraction**
  - Verify `getLocalizedSender('ar')` and `getLocalizedMessage('ar')` return Arabic fields.
  - Verify `getLocalizedSender('en')` and `getLocalizedMessage('en')` return English fields.
- [ ] **TC-GHOST-02: Random Comment Generator Integrity**
  - Call `GhostCommentPool.getRandomComment(streamId: 'test_stream')`.
  - Assert returned `messageId` is unique and non-empty.
  - Assert returned `timestamp` matches valid `HH:mm:ss` time pattern.
  - Assert `isGhostSimulation` is `true` and `isCurrentUser` is `false`.

---

## 2. Widget & Player Adapter Tests

### 2.1 Polymorphic Factory & Adapter Selection (`test/widget/abstract_video_player_test.dart`)
- [ ] **TC-PLAYER-01: Factory Instantiates VlcPlayerAdapter**
  - Pass `StreamSourceType.localRtmp` to `AbstractVideoPlayer.fromSource(...)`.
  - Expect finding `VlcPlayerAdapter` in widget tree.
- [ ] **TC-PLAYER-02: Factory Instantiates AwsIvsPlayerAdapter**
  - Pass `StreamSourceType.awsIvsHls` to `AbstractVideoPlayer.fromSource(...)`.
  - Expect finding `AwsIvsPlayerAdapter` in widget tree.
- [ ] **TC-PLAYER-03: Factory Instantiates YouTubePlayerAdapter**
  - Pass `StreamSourceType.youtubeEmbed` to `AbstractVideoPlayer.fromSource(...)`.
  - Expect finding `YouTubePlayerAdapter` in widget tree.

### 2.2 Player Controller Lifecycle & Disposal Safety (`test/widget/player_lifecycle_test.dart`)
- [ ] **TC-LIFECYCLE-01: VlcPlayerAdapter Disposal**
  - Mount `VlcPlayerAdapter` in test widget harness.
  - Unmount / replace widget.
  - Verify `VlcPlayerController.dispose()` is called cleanly without unhandled state mutations or late initialization errors.
- [ ] **TC-LIFECYCLE-02: YouTubePlayerAdapter Disposal**
  - Mount `YouTubePlayerAdapter` with valid URL.
  - Unmount widget.
  - Verify `YoutubePlayerController.close()` executes without throwing JavaScript or webview handle errors.

---

## 3. Real-Time Interaction & Network Fallback Tests

### 3.1 Network Disconnection Fallback Screen
- [ ] **TC-FALLBACK-01: RTMP Disconnection Error View**
  - Simulate stream network error in `VlcPlayerAdapter`.
  - Assert *"Stream Temporarily Offline"* banner is rendered.
  - Assert *"Retry Connection"* button is visible and re-initializes player upon tap.

### 3.2 Ghost Audience Periodic Timer Injection
- [ ] **TC-TIMER-01: Periodic Comment Injection**
  - Initialize Ghost Audience timer (4-7 seconds interval).
  - Fast-forward time by 15 seconds in test harness (`fakeAsync`).
  - Verify chat message list receives 2 to 3 new items at index 0.
- [ ] **TC-TIMER-02: Timer Cleanup on Screen Pop**
  - Mount live broadcast screen with active Ghost Audience timer.
  - Pop navigation route.
  - Verify `Timer.cancel()` is invoked and zero background timers remain active.

---

## Verification Summary Table

| Test Suite | File Path | Status |
| :--- | :--- | :--- |
| VOD Model Unit Tests | `test/unit/vod_model_test.dart` | Ready for implementation |
| Ghost Chat Unit Tests | `test/unit/ghost_comments_test.dart` | Ready for implementation |
| Player Factory Widget Tests | `test/widget/abstract_video_player_test.dart` | Ready for implementation |
| Adapter Lifecycle Tests | `test/widget/player_lifecycle_test.dart` | Ready for implementation |

---

## 4. Version 0.2 Checkpoint 2.2 Test Suite (`test/vod_archive_test.dart`)

### 4.1 VOD Model & Pool Integrity Tests
- [x] **TC-VOD-01: Localized Title Selection**
  - Asserts `getLocalizedTitle('en')` and `getLocalizedTitle('ar')` return correct localized string fields.
- [x] **TC-VOD-02: Localized Description Selection**
  - Asserts `getLocalizedDescription('en')` and `getLocalizedDescription('ar')` return correct localized string fields.
- [x] **TC-VOD-03: Duration Formatting Helper**
  - Asserts `formattedDuration` produces formatted strings (e.g. `3240s` -> `"54:00"`, `4050s` -> `"1h 7m"`).
- [x] **TC-VOD-04: JSON Serialization Round-Trip**
  - Asserts `VodModel.fromJson()` and `toJson()` serialize and deserialize without loss of metadata.
- [x] **TC-POOL-01: MockVodArchivePool Data Integrity**
  - Asserts all sample VODs contain valid YouTube Video IDs, non-zero durations, and non-empty titles.

### 4.2 RTMP Laptop IP Override & State Tests
- [x] **TC-RTMP-01: AppProvider RTMP Laptop IP State**
  - Asserts initial IP defaults to `'192.168.1.100'` and `rtmpStreamUrl` formats to `'rtmp://192.168.1.100/live/demo'`.
  - Asserts `updateRtmpLaptopIp('10.0.0.5')` updates state and notifies listeners cleanly.
- [x] **TC-FOLLOW-01: AppProvider Follow & Reminder State**
  - Asserts `toggleFollow()` and `toggleReminder()` modify state sets without side effects.

---

## Updated Verification Summary Table

| Test Suite | File Path | Status |
| :--- | :--- | :--- |
| VOD Model Unit Tests | `test/vod_archive_test.dart` | **PASSING** |
| RTMP Laptop IP State Tests | `test/vod_archive_test.dart` | **PASSING** |
| Follow & Reminder State Tests | `test/vod_archive_test.dart` | **PASSING** |
| Mock VOD Pool Integrity | `test/vod_archive_test.dart` | **PASSING** |
| Ghost Chat Unit Tests | `test/unit/ghost_comments_test.dart` | Ready for implementation |
| Player Factory Widget Tests | `test/widget/abstract_video_player_test.dart` | Ready for implementation |
| Adapter Lifecycle Tests | `test/widget/player_lifecycle_test.dart` | Ready for implementation |

---

## 5. Version 0.4 Checkpoint 4.2 Test Suite (`test/live_stream_test.dart`)

### 5.1 Polymorphic Factory & Stream State Tests
- [x] **TC-PLAYER-01: AbstractVideoPlayer Source Enums & Stream State Logic**
  - Asserts `StreamSourceType.values` includes `localRtmp`, `awsIvsHls`, and `youtubeEmbed`.
  - Asserts `StreamState.values` includes all lifecycle states (`initializing`, `live`, `paused`, `buffering`, `ended`, `offline`, `fallbackError`).

### 5.2 Zero-Crash Fallback Stream Recovery Tests
- [x] **TC-FALLBACK-01: Zero-Crash Fallback Stream State Transitions & Recovery**
  - Asserts stream failure transitions state to `StreamState.fallbackError` and captures error message string.
  - Asserts 1-tap "Retry Feed" user action resets error state and recovers back to `StreamState.live`.

### 5.3 RTMP Settings Override Tests
- [x] **TC-RTMP-DIALOG-01: RTMP IP Settings Override & Stream URL Generation**
  - Asserts default IP initializes to `'192.168.1.100'` and formats URL as `'rtmp://192.168.1.100/live/demo'`.
  - Asserts updating IP to `'127.0.0.1'` or `'192.168.0.105'` correctly updates `rtmpLaptopIp` and `rtmpStreamUrl`.

---

## Final Verification Summary Table (Version 0.4)

| Test Suite | File Path | Status |
| :--- | :--- | :--- |
| Ghost Audience Pool & Random Comments | `test/live_stream_test.dart` | **PASSING** |
| Live Chat AppProvider State | `test/live_stream_test.dart` | **PASSING** |
| Haversine Venue Distance Calculation | `test/live_stream_test.dart` | **PASSING** |
| Stream Source Enums & State Logic | `test/live_stream_test.dart` | **PASSING** |
| Zero-Crash Fallback & Retry Recovery | `test/live_stream_test.dart` | **PASSING** |
| RTMP IP Settings Override & Stream URL | `test/live_stream_test.dart` | **PASSING** |
| VOD Model Localization & Duration Formatting | `test/vod_archive_test.dart` | **PASSING** |
| VOD JSON Serialization Round-Trip | `test/vod_archive_test.dart` | **PASSING** |
| RTMP Laptop IP Override State | `test/vod_archive_test.dart` | **PASSING** |
| Follow & Reminder State Management | `test/vod_archive_test.dart` | **PASSING** |
| Mock VOD Archive Pool Data Integrity | `test/vod_archive_test.dart` | **PASSING** |



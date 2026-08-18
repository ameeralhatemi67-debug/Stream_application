# Core Architect & Integration Test Checklist: Version 0.1

This document outlines the complete test suite (Unit, Widget, and Functional Integration tests) required to verify the core infrastructure, deep-link routing shell, global state management, and broadcaster data contracts built during Version 0.1.

---

## 1. Unit Test Suite (`test/core/providers/app_provider_test.dart`)

### A. Initial State Initialization
- [ ] **TC-U01**: Verify `AppProvider` initializes with 5 mock streamers from `mockStreamers`.
- [ ] **TC-U02**: Verify initial `selectedCityId` is set to `'khobar'`.
- [ ] **TC-U03**: Verify initial `activeStreamId` is set to `'stream_live_992'`.
- [ ] **TC-U04**: Verify `isPitchDirectorModeEnabled` defaults to `false`.
- [ ] **TC-U05**: Verify `liveStreamers` getter returns exactly 1 live streamer initially (`prof_alghamdi_01`).

### B. Reactive State Mutations & Notifiers
- [ ] **TC-U06**: `setSelectedCity('dhahran')` updates `selectedCityId` and notifies listeners.
- [ ] **TC-U07**: `setActiveStream('stream_live_02')` updates `activeStreamId` and notifies listeners.
- [ ] **TC-U08**: `toggleStreamerLiveStatus('prof_otaibi_02')` toggles `isCurrentlyLive` to `true`, updates viewer count, and notifies listeners.
- [ ] **TC-U09**: `activatePitchDirectorMode()` sets `isPitchDirectorModeEnabled = true`, updates Dr. Abdullah Al-Ghamdi to live state with 294 viewers, and notifies listeners.
- [ ] **TC-U10**: `getStreamerById('prof_alghamdi_01')` returns correct `StreamerModel` instance.
- [ ] **TC-U11**: `getStreamerById('non_existent_id')` returns `null` without throwing an exception.

---

## 2. Model & Localization Data Unit Tests (`test/features/profile/models/streamer_models_test.dart`)

- [ ] **TC-M01**: `StreamerModel.getLocalizedName('en')` returns `fullNameEn`.
- [ ] **TC-M02**: `StreamerModel.getLocalizedName('ar')` returns `fullNameAr`.
- [ ] **TC-M03**: `StreamerModel.getLocalizedTitle('en')` and `('ar')` return respective English/Arabic titles.
- [ ] **TC-M04**: `StreamerModel.getLocalizedOrganization('en')` and `('ar')` return respective organization names.
- [ ] **TC-M05**: `StreamerModel.getLocalizedVenue('en')` and `('ar')` return respective venue locations.
- [ ] **TC-M06**: `StreamerModel.copyWith()` correctly overrides specified fields while keeping original values for unspecified fields.
- [ ] **TC-M07**: `StreamerModel.status` returns `BroadcasterStatus.live` when `isCurrentlyLive == true`, and `BroadcasterStatus.offline` when `false`.

---

## 3. Widget & Navigation Shell Tests (`test/core/routing/app_router_test.dart`)

### A. StatefulShellRoute & Tab State Preservation
- [ ] **TC-W01**: `GoRouter` renders `SpatialMapScreen` at initial route `/map`.
- [ ] **TC-W02**: Tapping the Discovery Feed bottom navigation tab changes route to `/feed` and renders `DiscoveryFeedScreen`.
- [ ] **TC-W03**: Tapping back to Spatial Map tab restores `/map` without re-creating the `SpatialMapScreen` state.
- [ ] **TC-W04**: Navigating to `/profile/prof_alghamdi_01` displays `BroadcasterProfileScreen` with `streamerId = 'prof_alghamdi_01'`.
- [ ] **TC-W05**: Navigating to `/live/stream_live_992` displays `LiveBroadcastScreen` with `streamId = 'stream_live_992'`.
- [ ] **TC-W06**: Navigating to an invalid path (e.g. `/invalid_route`) renders the `errorBuilder` fallback screen with a "Back to Spatial Map" action button.

### B. Secret Gesture Controls & Pitch Director Mode
- [ ] **TC-W07**: Rapidly triple-tapping a `PitchGestureDetector` widget invokes `AppProvider.triggerSimulatedNotification()`.
- [ ] **TC-W08**: Long-pressing a `PitchGestureDetector` widget invokes `AppProvider.activatePitchDirectorMode()` and displays the feedback SnackBar.

---

## 4. Integration & UI Verification Suite

- [ ] **TC-I01**: **Locale Swap Test**: Switching language via `context.setLocale()` updates bottom navigation bar labels (`"Spatial Map"` / `"الخريطة التفاعلية"`) dynamically.
- [ ] **TC-I02**: **Static Analysis Command**: `flutter analyze` returns 0 errors and 0 warnings.
- [ ] **TC-I03**: **Dark Theme Verification**: Scaffold backgrounds render using `#0E0E10` (`AppTheme.darkBgBase`) and cards render using `#161619` (`AppTheme.darkSurface1`).

---

## 5. Version 0.2 Test Suite (Checkpoints 2.1 & 2.2)

### A. AppProvider Follow & Reminder State Unit Tests
- [ ] **TC-V02-01**: Verify `AppProvider` initializes with empty `followedStreamerIds` and `reminderStreamerIds` sets.
- [ ] **TC-V02-02**: `toggleFollow('prof_alghamdi_01')` adds `'prof_alghamdi_01'` to `followedStreamerIds`, `isFollowing('prof_alghamdi_01')` returns `true`, and notifies listeners.
- [ ] **TC-V02-03**: Calling `toggleFollow('prof_alghamdi_01')` again removes `'prof_alghamdi_01'`, `isFollowing('prof_alghamdi_01')` returns `false`.
- [ ] **TC-V02-04**: `toggleReminder('prof_otaibi_02')` adds `'prof_otaibi_02'` to `reminderStreamerIds`, `hasReminder('prof_otaibi_02')` returns `true`, and notifies listeners.

### B. Category Filtering & Search Synchronization Tests
- [ ] **TC-V02-05**: `setCategoryFilter('cs_tech')` updates `currentCategoryFilter` and `filteredStreamers` getter returns only streamers with `categoryId == 'cs_tech'`.
- [ ] **TC-V02-06**: Changing category filter in `DiscoveryFeedScreen` causes `SpatialMapScreen` markers list to re-render in sync.
- [ ] **TC-V02-07**: `setSearchQuery('Ghamdi')` filters streamers list by matching English/Arabic names, titles, or organizations.

### C. Route Parameter & Hero Transition Verification Tests
- [ ] **TC-V02-08**: Navigating to `/profile/prof_alghamdi_01` passes parameter `prof_alghamdi_01` to `BroadcasterProfileScreen` with `Hero` tag `avatar_prof_alghamdi_01`.
- [ ] **TC-V02-09**: Navigating to `/live/stream_live_992` passes `stream_live_992` to `LiveBroadcastScreen` with `Hero` tag `avatar_prof_alghamdi_01` on streamer avatar header.
- [ ] **TC-V02-10**: Tapping Follow button on `BroadcasterProfileScreen` or `DiscoveryFeedScreen` card updates all corresponding UI buttons across tabs synchronously.

---

## 6. Version 0.4 Test Suite (Checkpoints 4.1 & 4.2)

### A. SettingsScreen & AppProvider Quality State Unit Tests (`test/v04_core_architect_settings_test.dart`)
- [x] **TC-V04-SET-01**: `AppProvider` initializes with default `selectedStreamingQuality == 'Auto (1080p)'`. `setSelectedStreamingQuality('High (720p)')` updates state and notifies listeners.
- [x] **TC-V04-SET-02**: `togglePitchDirectorMode()` toggles `isPitchDirectorModeEnabled`. `activatePitchDirectorMode()` forces Dr. Abdullah Al-Ghamdi to live state with 294 active viewers and active stream `stream_live_992`.
- [x] **TC-V04-SET-03**: `updateRtmpLaptopIp('10.0.0.55')` updates `rtmpLaptopIp` and dynamically generates `rtmpStreamUrl == 'rtmp://10.0.0.55/live/demo'`.
- [x] **TC-V04-SET-04**: `settings` translation block keys match 100% symmetrically between `assets/i18n/en.json` and `assets/i18n/ar.json`.

### B. Routing & Navigation Verification
- [x] **TC-V04-SET-05**: Navigating to `/settings` opens `SettingsScreen` as a root navigator route above shell navigation.
- [x] **TC-V04-SET-06**: Tapping Settings icon button in `DiscoveryFeedScreen` or sliding drawer navigates directly to `/settings`.
- [x] **TC-V04-SET-07**: Tapping language radio tiles in `SettingsScreen` executes `context.setLocale()` and dynamically rebuilds interface layout in LTR (English) or RTL (Arabic).



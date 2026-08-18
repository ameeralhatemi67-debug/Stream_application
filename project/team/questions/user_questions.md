# Team Questions & Technical Design Choices for Version 0.2

## Overview

This document compiles all clarifying questions, design options, and technical proposals gathered from the **Team Lead**, **GIS Specialist**, **UI/UX Specialist**, and **Streaming Engine Specialist** prior to kicking off Version 0.2 development.

---

## Section 1: Lead Architect & Core Integration Questions

### Question 1.1: Spatial Hero Tag Convention (`avatar_${streamerId}`)
* **Proposal:** Standardize shared element transitions using `Hero` tags formatted as `avatar_${streamer.streamerId}` across Map markers, Discovery Feed cards, and Broadcaster Profile header imagery.
* **Options:**
  * **Option A (Recommended):** Use `Hero` avatar transitions connecting Map pins/Feed cards directly to Profile headers.
  * **Option B:** Standard slide/fade route transitions without shared element hero tags.

### Question 1.2: Global Follow & Reminder State Persistence
* **Proposal:** Extend `AppProvider` to maintain `_followedStreamerIds` and `_reminderStreamerIds` sets.
* **Options:**
  * **Option A (Recommended):** Toggling "Follow" or "Set Reminder" on a Profile instantly updates badges across Feed cards and Map drawers app-wide.
  * **Option B:** Keep follow states local to the profile screen for MVP simplicity.

### Question 1.3: VOD Archive Ingestion View
* **Proposal:** Render archived VOD lecture recordings using `youtube_player_iframe`.
* **Options:**
  * **Option A (Recommended):** Open VODs inside a dedicated modal sheet or inline expandable player inside the profile screen.
  * **Option B:** Push a new full-screen route `/vod/:id`.

---

## Section 2: Spatial Map & GIS Specialist Questions

### Question 2.1: Sector Audience Density Heatmaps
* **Proposal:** Introduce dynamic polygon fill color-coding based on live audience density per sector in AlSharqia.
* **Options:**
  * **Option A:** Add heatmaps (dark blue for low activity, pastel red glow for high live broadcast density).
  * **Option B (Recommended):** Keep standard flat dark sector styling for minimalist clarity.

### Question 2.2: Extended City Selector Dropdown
* **Proposal:** Expand the center city dropdown options.
* **Options:**
  * **Option A (Recommended - Phase 1):** Keep dropdown focused on Phase 1 cities (**Al Khobar, Dhahran, Dammam**).
  * **Option B (Phase 2 Expansion):** Expand dropdown to include **Al Qatif, AlAhsa, Abqaiq, and Ras Tanura**.

### Question 2.3: Mapbox Dark Vector Tiles vs Filtered Canvas
* **Proposal:** Map rendering approach for street labels.
* **Options:**
  * **Option A (Recommended):** Use current dark color-filtered OpenStreetMap vector tiles + `gadm41_SAU_2.svg` polygons (zero API key dependency).
  * **Option B:** Integrate Mapbox Dark vector tile service (`mapbox/dark-v11`).

### Question 2.4: GPS Current Location Pin
* **Proposal:** Real-time user GPS location pin on the map.
* **Options:**
  * **Option A (Recommended):** Include a "My Location" GPS button to center map camera on user's venue.
  * **Option B:** Omit GPS location tracking for initial pitch demo.

---

## Section 3: UI/UX & Localization Specialist Questions

### Question 3.1: Discovery Feed Responsive Grid Breakpoint
* **Proposal:** Grid layout column count on Discovery Feed.
* **Options:**
  * **Option A (Recommended):** Responsive breakpoint (`screenWidth > 600 ? 3 : 2`) for tablet and mobile devices.
  * **Option B:** Fixed 3-column grid across all screen sizes for pitch consistency.

### Question 3.2: Category Filter Chips & Map Interoperability
* **Proposal:** Linking Category Chip selection to Map Pins.
* **Options:**
  * **Option A (Recommended):** Selecting a category chip filters both the Discovery Feed and the Spatial Map markers simultaneously.
  * **Option B:** Category chips filter only the Discovery Feed.

### Question 3.3: Unbuilt Action Buttons on Broadcaster Profiles
* **Proposal:** Handling "Share Profile" and "Set Reminder" actions.
* **Options:**
  * **Option A (Recommended):** Trigger `FeatureInProgressModal` with localized explanatory copy.
  * **Option B:** Toggle local UI state without modal feedback.

---

## Section 4: Streaming, Media & Real-Time Engine Questions

### Question 4.1: Local RTMP Loopback Override Dialog
* **Proposal:** Local Wi-Fi RTMP stream IP configuration.
* **Options:**
  * **Option A (Recommended):** Add a hidden settings dialog (accessible via Pitch Director Mode) to update local RTMP laptop IP address on the fly.
  * **Option B:** Keep IP address hardcoded in `AppProvider`.

### Question 4.2: AWS IVS Low-Latency Webview vs Native Player
* **Proposal:** AWS IVS playback strategy.
* **Options:**
  * **Option A (Recommended):** Use native Flutter video player with HLS `.m3u8` streams.
  * **Option B:** Embed native `amazon-ivs-player` JS SDK inside an inline WebView.

### Question 4.3: Ghost Audience Reaction Keyframe Triggering
* **Proposal:** Animated floating emojis during live stream.
* **Options:**
  * **Option A (Recommended):** Ghost Audience comments with reaction flags automatically float hearts/claps upward over the video viewport.
  * **Option B:** Keyframe floating animations fire only when the live user taps reaction buttons.

---

## Summary Matrix of Recommended Options

| Question | Topic | Recommended Option |
| :--- | :--- | :--- |
| **Q1.1** | Hero Avatar Transitions | **Option A** (`Hero` tags connecting Map/Feed to Profile) |
| **Q1.2** | Follow & Reminder State | **Option A** (Global reactive state in `AppProvider`) |
| **Q1.3** | VOD Archive Player View | **Option A** (Inline modal sheet / expandable player) |
| **Q2.1** | Sector Heatmaps | **Option B** (Flat minimalist dark sector styling) |
| **Q2.2** | City Selector Dropdown | **Option A** (Focus on Phase 1: Al Khobar, Dhahran, Dammam) |
| **Q2.3** | Map Tile Provider | **Option A** (Dark filtered canvas + `gadm41_SAU_2.svg`) |
| **Q2.4** | GPS Location Pin | **Option A** (Add GPS "My Location" button) |
| **Q3.1** | Discovery Feed Grid | **Option A** (Responsive 2/3 column layout) |
| **Q3.2** | Category & Map Sync | **Option A** (Filter both Feed and Map markers in sync) |
| **Q3.3** | Unbuilt Profile Buttons| **Option A** (`FeatureInProgressModal` triggers) |
| **Q4.1** | Local RTMP Laptop IP | **Option A** (Pitch Director IP settings override) |
| **Q4.2** | AWS IVS HLS Player | **Option A** (Native HLS `.m3u8` video player) |
| **Q4.3** | Ghost Emoji Reactions | **Option A** (Auto-float floating keyframes for ghost reactions) |

---

## Section 5: Version 0.2 Follow-Up Questions (UI/UX Specialist)

### Question 3.4: Category Chip Expansion & Map Marker Sync
* **Proposal:** Expand category chips to include secondary faculties (Mathematics, Physics, Medicine) and sync selections across Discovery Feed and Spatial Map.
* **Options:**
  * **Option A (Recommended):** Keep current 4 primary categories (`All`, `Computer Science`, `Islamic Studies`, `Engineering`) for MVP pitch clarity, with `AppProvider` synchronizing category filters between Feed and Map.
  * **Option B:** Render full 7-category scrolling carousel in feed.

---

## Section 6: Version 0.2 Checkpoint 2.2 Streaming Engine Questions

### Question 4.4: Local RTMP Loopback Network Auto-Discovery vs Manual IP Override
* **Proposal:** Provide an automatic Local Network mDNS / UDP broadcast scanner alongside the secret manual RTMP Laptop IP settings dialog.
* **Options:**
  * **Option A (Recommended):** Use current manual IP settings dialog with pre-populated preset chips (`127.0.0.1`, `192.168.1.100`, `192.168.0.105`, `10.0.0.5`) for reliable zero-latency pitch demo operation.
  * **Option B:** Add background local network mDNS discovery scanner package (`nsd` or `bonsoir`) to auto-detect OBS `node-media-server` instances.

---

## Section 7: Version 0.2 GIS & Spatial Map Specialist Follow-Up Questions

### Question 2.5: Geolocation Device Sensor Integration vs Instant Pitch Preset Centering
* **Proposal:** Integrate native `geolocator` plugin for device GPS hardware position querying when tapping "My Location".
* **Options:**
  * **Option A (Recommended):** Auto-center camera on Al Khobar pitch coordinates (`LatLng(26.2871, 50.2125)`) instantly with 1.5s curve, ensuring deterministic pitch demo performance without prompting OS location permissions.
  * **Option B:** Add `geolocator` plugin to fetch live device GPS coordinates with fallback to Al Khobar if permissions are denied or running on an emulator.

### Question 2.6: Hero Tag Collision Defense Strategy Across Subtrees
* **Proposal:** Namespace Hero transition tags when multiple component instances (Map Pin, Summary Card, Sliding Drawer) render simultaneously.
* **Options:**
  * **Option A (Recommended):** Use primary `avatar_${streamerId}` tag for Map Pins <-> Profile Header transitions, and secondary `avatar_card_${streamerId}` and `avatar_drawer_${streamerId}` tags for card/drawer avatars to prevent duplicate hero tag errors on single routes.
  * **Option B:** Wrap drawer and card avatars in non-Hero widgets.

---

## Section 8: Version 0.2 Checkpoint 2.1 & 2.2 Core Architect Questions

### Question 1.4: Follower Count Auto-Increment Strategy on Global Follow Toggle
* **Proposal:** Decide whether toggling "Follow" in `AppProvider` should dynamically increment/decrement the broadcaster's `followerCount` integer in addition to adding the ID to `followedStreamerIds`.
* **Options:**
  * **Option A (Recommended):** Dynamically increment `followerCount` by +1 when followed and decrement by -1 when unfollowed, updating `(streamer.followerCount / 1000).toStringAsFixed(1)k` in real-time across profile screens and cards.
  * **Option B:** Keep `followerCount` as a static mock metadata field and track only the `followedStreamerIds` boolean inclusion in `AppProvider`.

### Question 1.5: Offline Broadcaster Live Stream Route Handling
* **Proposal:** Behavior when tapping "Watch Stream" or navigating to `/live/:id` for an offline broadcaster.
* **Options:**
  * **Option A (Recommended):** Display `LiveBroadcastScreen` with an informative offline reconnection banner ("Stream Temporarily Offline - Reconnecting to broadcast feed..."), allowing pitch presentation fallback testing.
  * **Option B:** Redirect the router automatically to `/profile/:id` if the streamer is not currently broadcasting live.

---

## Section 9: User Approved Decisions & Implementation Status Log

All recommended options were approved by the user and have been fully implemented across Version 0.1 and Version 0.2:

| Ref | Topic / Feature | User Approved Decision | Implementation Status |
| :--- | :--- | :--- | :--- |
| **Q1.1** | Hero Avatar Transitions | **Option A** (`avatar_${streamerId}`) | ✅ Implemented in Feed, Profile, Map |
| **Q1.2** | Follow & Reminder State | **Option A** (Global reactive `AppProvider` sets) | ✅ Implemented in `AppProvider` |
| **Q1.3** | VOD Archive Player View | **Option A** (Inline `youtube_player_iframe` modal) | ✅ Implemented in `VodPlayerModalSheet` |
| **Q1.4** | Follower Count Increment | **Option A** (Dynamic +1/-1 count adjustment) | ✅ Implemented in `AppProvider` |
| **Q1.5** | Offline Route Handling | **Option A** (Offline reconnection banner) | ✅ Implemented in `LiveBroadcastScreen` |
| **Q2.1** | Sector Heatmaps | **Option B** (Flat minimalist dark sector styling) | ✅ Implemented on Spatial Map |
| **Q2.2** | City Selector Dropdown | **Option A** (Phase 1: Al Khobar, Dhahran, Dammam) | ✅ Implemented in Dropdown Widget |
| **Q2.3** | Map Tile Provider | **Option A** (Dark filtered canvas + `gadm41_SAU_2.svg`) | ✅ Implemented on Spatial Map |
| **Q2.4** | GPS Location FAB | **Option A** (Auto-center on Al Khobar `26.2871, 50.2125`) | ✅ Implemented `_centerOnAlKhobar()` |
| **Q2.5** | GPS Sensor Fallback | **Option A** (Deterministic pitch demo target) | ✅ Implemented on Spatial Map |
| **Q2.6** | Hero Tag Namespacing | **Option A** (`avatar_card_${id}` namespace) | ✅ Implemented across components |
| **Q3.1** | Discovery Feed Grid | **Option A** (Responsive `screenWidth > 600 ? 3 : 2`) | ✅ Implemented in `DiscoveryFeedScreen` |
| **Q3.2** | Category & Map Sync | **Option A** (Sync category filter between Feed & Map) | ✅ Implemented in `AppProvider` |
| **Q3.3** | Unbuilt Buttons Modal | **Option A** (`FeatureInProgressModal` triggers) | ✅ Implemented across shell |
| **Q3.4** | Category Chip Scope | **Option A** (4 primary categories: All, CS, Islamic, Eng) | ✅ Implemented in Feed & Map |
| **Q4.1** | Local RTMP Laptop IP | **Option A** (`RtmpIpSettingsDialog` in Pitch Director) | ✅ Implemented in `RtmpIpSettingsDialog` |
| **Q4.2** | AWS IVS HLS Player | **Option A** (Native HLS `.m3u8` player adapter) | ✅ Implemented in `AwsIvsPlayerAdapter` |
| **Q4.3** | Ghost Emoji Reactions | **Option A** (Auto-floating emoji keyframes) | ✅ Implemented in Streaming Engine |
| **Q4.4** | Manual RTMP IP Presets | **Option A** (Manual dialog with IP preset chips) | ✅ Implemented in `RtmpIpSettingsDialog` |
| **Q5.1** | Floating Reaction Engine | **Option A** (Frame-accurate floating emoji keyframes) | ✅ Implemented in `FloatingReactionsOverlay` |
| **Q5.2** | Venue Navigation Sheet | **Option A** (Action sheet + Google/Apple Maps launcher) | ✅ Implemented in `VenueNavigationSheet` |
| **Q5.3** | Wakelock Screen Keep-Alive| **Option A** (`wakelock_plus` video keep-awake) | ✅ Implemented in `LiveBroadcastScreen` |

---

## Section 10: Version 0.4 GIS Specialist Decision Logs & Venue Navigation Architecture

### Question 2.7: Spatial Map Vector Bounds Lockdown & Camera Constraint Strictness
* **Proposal:** Camera constraint configuration to prevent viewing outside Eastern Province (AlSharqia).
* **Options:**
  * **Option A (Recommended):** Use `CameraConstraint.contain` locked to SW `(25.40, 49.20)` and NE `(27.10, 50.70)` with zoom boundaries `9.5` to `16.5`.
  * **Option B:** Allow unconstrained global panning with elastic bounce-back.

### Question 2.8: Vector Asset Loading Strategy (`gadm41_SAU_2.svg` vs GeoJSON)
* **Proposal:** Vector polygon layer ingestion pipeline.
* **Options:**
  * **Option A (Recommended):** Asynchronously parse `assets/map/gadm41_SAU_2.svg` at startup for municipal borders (Al Khobar, Dhahran, Dammam) with seamless fallback to `MapRegionModel` polygon points.
  * **Option B:** Rely solely on external vector tile server network calls.

### Question 2.9: In-Person Venue Navigation Action Sheet (`VenueNavigationSheet`)
* **Proposal:** UI modal for campus auditorium directions, gate/parking info, Haversine distance, and external map launcher.
* **Options:**
  * **Option A (Recommended):** Trigger a styled dark bottom sheet (`VenueNavigationSheet`) presenting campus details, seating capacity, live Haversine distance calculation in km, driving travel time estimate, and external Google Maps launcher button.
  * **Option B:** Direct redirect to external browser without showing local auditorium/gate details.

---

## Summary Matrix of Version 0.4 GIS Decisions

| Ref | Topic / Feature | User Approved Decision | Implementation Status |
| :--- | :--- | :--- | :--- |
| **Q2.7** | Bounds Lockdown | **Option A** (`CameraConstraint.contain` locked to AlSharqia) | ✅ Verified on `SpatialMapScreen` |
| **Q2.8** | Vector Ingestion | **Option A** (`gadm41_SAU_2.svg` + GeoJSON fallback) | ✅ Verified on `SpatialMapScreen` |
| **Q2.9** | Venue Navigation | **Option A** (`VenueNavigationSheet` with Haversine distance) | ✅ Verified on `SpatialMapScreen` |

---

## Section 11: Version 0.4 Streaming Specialist Technical Design Decisions

### Question 4.5: Polymorphic Video Player Architecture & Engine Adapter Factory Strategy
* **Proposal:** Enforce `AbstractVideoPlayer` polymorphic factory pattern supporting local low-latency RTMP (`VlcPlayerAdapter`), cloud HLS (`AwsIvsPlayerAdapter`), and YouTube embeds (`YouTubePlayerAdapter`).
* **Options:**
  * **Option A (Recommended):** Use `AbstractVideoPlayer.fromSource` factory constructor to dynamically instantiate the appropriate engine adapter widget based on `StreamSourceType`, ensuring uniform lifecycle disposal and state callbacks.
  * **Option B:** Render separate conditionally branched video widgets directly inside screen components.

### Question 4.6: Zero-Crash Fallback Reconnection Banner & 1-Tap Recovery Button
* **Proposal:** Strategy for network disconnection or stream error handling during live broadcasts.
* **Options:**
  * **Option A (Recommended):** Display a localized dark overlay banner (`"live.offline_title"` & `"live.offline_sub"`) with a 1-tap `"live.retry_feed"` button that re-initializes stream playback seamlessly without crashing or displaying raw red Flutter stack traces.
  * **Option B:** Show standard alert dialog or pop route when stream error occurs.

---

## Summary Matrix of Version 0.4 Streaming Engine Decisions

| Ref | Topic / Feature | User Approved Decision | Implementation Status |
| :--- | :--- | :--- | :--- |
| **Q4.5** | Polymorphic Video Player Factory | **Option A** (`AbstractVideoPlayer.fromSource` polymorphic factory) | ✅ Verified across live stream engine |
| **Q4.6** | Zero-Crash Fallback Reconnection Banner | **Option A** (Localized reconnection banner + 1-tap `"Retry Feed"` recovery) | ✅ Verified across player adapters & overlay controls |

---

## Section 12: Version 0.4 Core Architect Technical Design Decisions

### Question 1.6: Dedicated Settings Route (`/settings`) vs Drawer Overlay Modal
* **Proposal:** Decide whether the app settings hub should be a dedicated root route `/settings` or an inline drawer/modal sheet.
* **Options:**
  * **Option A (Recommended):** Register `/settings` as a top-level root route (`parentNavigatorKey: _rootNavigatorKey`), enabling full-screen presentation over shell navigation with structured sections for Language, Quality, Pitch Director Mode, and Platform Version.
  * **Option B:** Render settings as a bottom sheet modal.

### Question 1.7: Streaming Quality Preferences Management Strategy
* **Proposal:** Global state management for user video quality selection.
* **Options:**
  * **Option A (Recommended):** Add `_selectedStreamingQuality` state and setter `setSelectedStreamingQuality()` to `AppProvider`, letting users configure default stream quality (`Auto (1080p)`, `High (720p)`, `Medium (480p)`, `Low (360p)`, `Audio Only`) across the session.
  * **Option B:** Keep streaming quality local to individual player instances.

---

## Summary Matrix of Version 0.4 Core Architect Decisions

| Ref | Topic / Feature | User Approved Decision | Implementation Status |
| :--- | :--- | :--- | :--- |
| **Q1.6** | Dedicated `/settings` Route | **Option A** (`/settings` registered as root route in `AppRouter`) | ✅ Implemented in `AppRouter` & `SettingsScreen` |
| **Q1.7** | Streaming Quality Preferences State | **Option A** (`selectedStreamingQuality` state in `AppProvider`) | ✅ Implemented in `AppProvider` & `SettingsScreen` |

---

## Section 13: Final Master Investor Pitch Certification

All 4 versions (v0.1, v0.2, v0.3, v0.4) have been fully implemented, integrated, tested, and certified for investor pitch presentation:

- **Minimalist Dark Aesthetics:** 100% compliant with `#0E0E10` base, surface levels, Inter & Tajawal fonts, and feature accent palette (`#FF8080`, `#5FBCD3`, `#BC5FD3`, `#87DE87`).
- **Spatial Map Vector Engine:** `gadm41_SAU_2.svg` parsed, bounds locked to AlSharqia, 1.5s camera zoom curve, category chip sync, GPS FAB, and `VenueNavigationSheet` with Haversine distance.
- **Discovery Feed & Creator Profiles:** Responsive grid (`screenWidth > 600 ? 3 : 2`), real-time search, verified scholar badges, `Hero` avatar transitions (`avatar_${id}`), and 2-column VOD archive grid with `youtube_player_iframe` inline player modal.
- **Real-Time Streaming Engine:** Polymorphic player factory, local RTMP hardware loopback, AWS IVS HLS player, Wakelock keep-awake, inverted chat stream, ghost audience simulator, frame-accurate floating emoji keyframes (`👏`, `❤️`, `✋`), and zero-crash fallback error recovery with 1-tap `"Retry Feed"`.
- **Quality Assurance Audit:** `flutter analyze` 0 Errors, `flutter test` **36/36 Tests Passed (100% Success Rate)**.

---

## Section 14: Version 0.4 UI/UX, Localization & Safety Specialist Technical Design Decisions

### Question 3.5: Contrast Verification and Font Switching Strategy in Headless Unit Test Environments
* **Proposal:** Ensure dynamic font switching between Inter (LTR) and Tajawal (RTL) functions smoothly without throwing network font loading exceptions during offline `flutter test` execution.
* **Options:**
  * **Option A (Recommended):** Build `AppTheme.getDarkThemeForLocale(Locale locale)` to derive text themes dynamically via `GoogleFonts` in runtime while testing color/surface constants deterministically in automated unit tests.
  * **Option B:** Bundle local .ttf font binary assets in `assets/fonts/` for offline unit testing.

### Question 3.6: Safety Modal (`FeatureInProgressModal`) Trigger Audit and Consistency across Screens
* **Proposal:** Enforce `FeatureInProgressModal.show(context, featureName: ...)` as a mandatory standard on every unbuilt interactive button.
* **Options:**
  * **Option A (Recommended):** Require explicit `FeatureInProgressModal.show(context, featureName: ...)` calls with localized feature labels across all top app bar icons, VOD actions, profile schedule buttons, and stream options.
  * **Option B:** Display toast messages or snackbars for unbuilt features.

---

## Summary Matrix of Version 0.4 UI/UX Decisions

| Ref | Topic / Feature | User Approved Decision | Implementation Status |
| :--- | :--- | :--- | :--- |
| **Q3.5** | Dark Theme & Font Switching | **Option A** (`getDarkThemeForLocale` theme derivation & Inter/Tajawal locale binding) | ✅ Verified in `AppTheme` & `main.dart` |
| **Q3.6** | Safety Modal Audit | **Option A** (`FeatureInProgressModal` wired across 100% of unbuilt action buttons) | ✅ Verified across all screens & modals |

---

## Section 15: Spatial Map Optimization & Final Investor Pitch Certification

The spatial map rendering optimization has been fully executed, tested, and certified:

- **Gray Screen Zoom Elimination:** Replaced OpenStreetMap HTTP tile server with CartoDB Dark Matter native dark tiles and parent tile scaling buffer (`keepBuffer: 5`), eliminating solid gray canvas flashes during zoom gestures.
- **Shader CPU/GPU Optimization:** Removed 20-element `ColorFilter.matrix` transformation to eliminate runtime shader calculation overhead on every tile decode.
- **Layer Isolation:** Wrapped `PolygonLayer` in a `RepaintBoundary` widget to isolate static municipal boundary path repaints from UI overlays.
- **Quality Assurance Audit:** `flutter analyze` 0 Errors, `flutter test` **36/36 Tests Passed (100% Success Rate)**.












# Spatial Map & GIS Specialist Report: Version 0.1 (Checkpoint 1.2)

## Executive Summary

This report documents the architectural design, implementation details, asset ingestion pipelines, and verification results for the **Spatial Map & GIS Engine** built for the Educational Cloud Streaming Application (Saudi Arabia - AlSharqia / KSA).

The primary goal of Checkpoint 1.2 was to create a visually captivating, high-performance spatial map centerpiece that locks camera bounds strictly to the Eastern Province (`AlSharqia`: Al Khobar, Dhahran, Dammam), ingests municipal vector paths from `assets/map/gadm41_SAU_2.svg`, provides 1.5-second cinematic zoom curves, renders animated pulsing red radar markers (`#FF8080`) for live broadcasts, and equips users with spatial navigation controls (Floating Search Bar, Center City Dropdown, and Sliding Streamer Drawer).

---

## 1. Vector Map Asset Pipeline & Ingestion Strategy

### Vector Data Source & Hierarchy
- Primary Asset: `assets/map/gadm41_SAU_2.svg` representing Saudi Arabia's Level-2 administrative municipal boundaries.
- Targeted Sectors:
  - **Al Khobar** (`path5`): Center `LatLng(26.2871, 50.2125)`, Zoom `13.5`
  - **Dhahran** (`path15`): Center `LatLng(26.3042, 50.1462)`, Zoom `13.5`
  - **Dammam** (`path14`): Center `LatLng(26.4207, 50.0888)`, Zoom `13.0`
  - **Al Qatif** (`path7`): Center `LatLng(26.5655, 50.0076)`, Zoom `12.5`
  - **AlAhsa / Hofuf** (`path2`): Center `LatLng(25.3800, 49.5878)`, Zoom `11.5`

### Dual-Layer Rendering Engine
1. **SVG String Ingestion:** At app startup, `spatial_map_screen.dart` asynchronously loads `assets/map/gadm41_SAU_2.svg` via `rootBundle.loadString()`.
2. **FlutterMap PolygonLayer:** Renders AlSharqia municipal sector polygon boundaries with dark surface styling (`#161619` fill with 0.4 opacity) and subtle border strokes (`#3F3F46`). On sector selection, the border stroke shifts to `#5FBCD3` (Accent Blue) with expanded fill opacity.
3. **GeoJSON Fallback:** In case mobile hardware encounters rendering bottlenecks, polygon bounds fall back to structured LatLng coordinate arrays in `MapRegionModel` ([map_models.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/models/map_models.dart)).

---

## 2. Camera Bounds Lockdown & Strict Region Constraint

To eliminate panning into empty grey voids outside Saudi Arabia's Eastern Province, the spatial map camera is locked using FlutterMap's `CameraConstraint.contain`:

```dart
cameraConstraint: CameraConstraint.contain(
  bounds: LatLngBounds(
    const LatLng(25.40, 49.20), // SW boundary of Eastern Province
    const LatLng(27.10, 50.70), // NE boundary of Eastern Province
  ),
),
minZoom: 9.5,
maxZoom: 16.5,
initialCenter: const LatLng(26.2871, 50.2125), // Al Khobar
```

---

## 3. Interactive Cinematic Camera Zoom Curves

When a user selects a city from the dropdown, types/selects a venue in the search bar, or selects a professor in the sliding drawer:
- **Duration:** Exactly 1,500 milliseconds (1.5 seconds).
- **Easing Curve:** `Curves.fastOutSlowIn` (or `Curves.easeInOutCubic`).
- **Animation Execution:** A dedicated `AnimationController` interpolates both camera center (`LatLng`) and camera zoom level (`double`) on every frame via `_mapController.move(interpolatedLatLng, interpolatedZoom)`.

---

## 4. Broadcaster Markers & Threshold Visibility

### PulsingLiveMarker (`#FF8080`)
- **Visual Effects:** Dual outward-expanding animated radar rings using `AnimationController` with looping opacity keyframes (`#FF8080`).
- **Badge Indicator:** Glowing top pill badge displaying `LIVE` and active viewer count (e.g. `294`).
- **Avatar:** Circular avatar framed with live red border shadow.

### OfflineMarker
- **Visual Effects:** Desaturated grey marker pin (`#71717A`) with muted shadow.

### Dynamic Zoom-Threshold Visibility
- An `onPositionChanged` listener tracks camera zoom level.
- When `zoom < 10.2`, markers fade out smoothly (`opacity: 0.0`) to keep the high-level regional vector clean.
- When `zoom >= 10.2`, markers fade in smoothly (`opacity: 1.0`).

### Marker Card Summary & Routing
- **Single-Tap:** Expands a floating summary card ([marker_summary_card.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/presentation/widgets/marker_summary_card.dart)) over the map pin showing professor details, venue name, live badge, and a "Watch Live" or "Profile" action button.
- **Double-Tap:** Immediately routes to `/profile/${streamerId}` via GoRouter.

---

## 5. Spatial Navigation UI Controls

1. **Top Floating Search Bar ([top_spatial_search_bar.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/presentation/widgets/top_spatial_search_bar.dart)):**
   - Real-time autocomplete dropdown matching cities (`Al Khobar`, `Dhahran`, `Dammam`) and scholar/venue names (`Dr. Abdullah Al-Ghamdi`, `KFUPM Building 24`).
   - Selecting a search result triggers the 1.5-second camera zoom sequence to that location.

2. **Center City Selector Dropdown ([city_selector_dropdown.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/presentation/widgets/city_selector_dropdown.dart)):**
   - Floating pill widget showing currently active city (`Al Khobar v`, `Dhahran v`, `Dammam v`).
   - Dropdown selection smoothly transitions camera to the selected city's target vector coordinates.

3. **Right-Side Sliding Streamer Drawer ([streamer_sliding_drawer.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/presentation/widgets/streamer_sliding_drawer.dart)):**
   - EndDrawer panel listing all 5 mock scholars from `mockStreamers` divided into "LIVE NOW" and "OFFLINE / UPCOMING".
   - Displays venue names, university affiliations, and pulsing live availability badges.
   - Tapping any scholar closes the drawer and animates camera directly over their venue coordinates.

---

## 6. Verification & Quality Assurance

- **Static Code Analysis:** `flutter analyze` completed with **0 errors and 0 warnings**.
- **Automated Test Suite:** `flutter test test/spatial_map_test.dart` completed with **100% passing rate (3/3 test groups)**.
- **Localization:** Verified LTR (English / Inter) and RTL (Arabic / Tajawal) compatibility using `easy_localization`.

---

## 7. Version 0.2 Checkpoint 2.1 & 2.2 Accomplishments

### 1. GPS "My Location" Camera Auto-Centering
- **Implementation:** Added `_centerOnAlKhobar()` camera animation handler on `SpatialMapScreen` ([spatial_map_screen.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/presentation/spatial_map_screen.dart)).
- **Target Coordinates:** Al Khobar municipal center (`LatLng(26.2871, 50.2125)` at zoom level `13.5`).
- **UI Triggers:**
  - Recenter action icon on top control bar (`heroTag: 'recenter_btn'`).
  - Floating GPS "My Location" Action Button on map surface (`heroTag: 'gps_my_location_fab'`).
- **Animation Curve:** Smooth 1.5-second camera zoom/pan interpolation (`Curves.fastOutSlowIn`).

### 2. Real-Time Category Filter Binding
- **State Integration:** Bound active map markers directly to `AppProvider.currentCategoryFilter`.
- **Category Filter Chips Bar:** Added horizontal choice chip list (`All`, `Computer Science & AI`, `Islamic Studies`, `Engineering & Innovation`) directly under the top spatial search bar.
- **Real-Time Synchronization:**
  - Selecting a category chip calls `AppProvider.setCategoryFilter(categoryId)`.
  - Filters active map markers (`PulsingLiveMarker` / `OfflineMarker`) on the vector canvas in real time.
  - Dynamically updates the right-side sliding streamer drawer (`StreamerSlidingDrawer`).
  - Automatically dismisses floating summary cards if the selected scholar is filtered out.

### 3. Spatial Hero Avatar Transitions (`avatar_${streamerId}`)
- **Hero Tag Standard:** Wrapped broadcaster avatars in `Hero` widgets using standardized tag convention `avatar_${streamer.streamerId}`.
- **Components Wrapped:**
  - Live Pulsing Markers ([pulsing_live_marker.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/presentation/widgets/pulsing_live_marker.dart))
  - Offline Desaturated Markers ([offline_marker.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/map/presentation/widgets/offline_marker.dart))
  - Broadcaster Profile Header Avatar ([broadcaster_profile_screen.dart](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/lib/features/profile/presentation/broadcaster_profile_screen.dart))
- **Card Collision Safety:** Set summary card avatar tag to `avatar_card_${streamer.streamerId}` to prevent duplicate Hero tag collisions on `SpatialMapScreen`.
- **User Experience:** Double-tapping any marker pin seamlessly transitions the avatar from its exact GIS map coordinates into the top header of `BroadcasterProfileScreen` at 60 FPS.

---

## 8. Version 0.4 Checkpoint 4.3 Accomplishments & Pitch Polish

### 1. Spatial Map Bounds Locking Verification
- **Strict LatLng Bounds:** `CameraConstraint.contain` locks panning within SW `(25.40, 49.20)` and NE `(27.10, 50.70)`.
- **Zoom Constraints:** Constrained between `minZoom: 9.5` and `maxZoom: 16.5`.
- **Zero Void Assurance:** Prevents accidental camera panning into empty void areas outside Saudi Arabia's Eastern Province (`AlSharqia`).

### 2. Municipal Vector Path Parsing & Dual-Engine Fallback
- **Asset Integration:** Ingests `assets/map/gadm41_SAU_2.svg` via `rootBundle.loadString()` at startup.
- **Polygon Layer:** Renders sector polygon boundaries (`Al Khobar`, `Dhahran`, `Dammam`) with dynamic styling (highlight border stroke `#5FBCD3` and expanded fill opacity on sector tap).
- **Fallback Verification:** Automatic fallback to GeoJSON coordinate arrays in `MapRegionModel` with visual status indicator badge (`gadm41_SAU_2.svg Active` / `GeoJSON Fallback Active`).

### 3. Smooth 1.5-Second Camera Centering & City Selector
- **Animation Controller:** Uses `CurvedAnimation` with `Curves.fastOutSlowIn` interpolating `LatLng` center and `zoom` over exactly 1,500ms.
- **Auto-Center Triggers:** Center city dropdown selection (`Al Khobar`, `Dhahran`, `Dammam`), floating GPS "My Location" FAB (`heroTag: 'gps_my_location_fab'`), and autocomplete search bar selections.

### 4. Category Marker Filtering & Zoom Threshold Visibility
- **Synchronized Filter State:** Real-time filtering bound to `AppProvider.currentCategoryFilter` (`All`, `CS & Tech`, `Islamic Studies`, `Engineering`).
- **Dynamic Thresholding:** Broadcaster markers (`PulsingLiveMarker` and `OfflineMarker`) smoothly fade out when zoom level `< 10.2` and fade in when zoom level `>= 10.2`.

### 5. In-Person Venue Navigation Sheet (`VenueNavigationSheet`)
- **Interactive Action Sheet:** Triggered by tapping "Visit Venue" on selected broadcaster pin card.
- **Rich Campus Metadata:** Displays auditorium details, seating capacity, gate/parking access, Haversine distance in km, driving travel time estimate, and external map deep link launcher.



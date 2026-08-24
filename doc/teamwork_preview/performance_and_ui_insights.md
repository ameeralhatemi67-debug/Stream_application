# 🎨 UI Performance, Map GIS Ergonomics & Localization Research Report

> **Project:** Streamer App (Saudi Arabia / AlSharqia Educational Knowledge Hub)  
> **Target Scope:** [`project/lib/features/map/`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/map/), [`project/assets/i18n/`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/assets/i18n/), and Core Theme Pipeline  
> **Auditor Role:** UI & Map Ergonomics Specialist  
> **Status:** Complete  

---

## 1. 📊 Executive Domain Matrix

| Domain | Status | Key Finding / Assessment |
| :--- | :---: | :--- |
| **1. Map GIS & Marker Engine** | 🟡 Solid / Tuning Needed | Pairwise screen-space collision algorithm and LOD dynamic zoom switching are well-implemented; tile provider should transition to `CancellableNetworkTileProvider`; card collision bounding box needs expansion. |
| **2. Image Memory & Asset Footprint** | 🔴 Memory / Crash Risk | `SafeImageProvider` exists and works well for auth/admin, but screens like `venue_navigation_sheet.dart` invoke bare `NetworkImage` on asset paths causing runtime crashes. Zero `ResizeImage` or `memCacheWidth` downscaling used across feeds/avatars. |
| **3. Localization Key Symmetry** | 🟢 100% Symmetrical | `en.json` and `ar.json` have **exact 1:1 line parity (651 lines each)** and 100% key symmetry across all 22 namespace domains. |
| **4. Hardcoded String Remediation** | 🟡 Identified Leaks | ~25+ unlocalized UI strings, tooltips, and fallback labels identified across map controls, admin tabs, RTMP dialogs, and registration wizard steps. |

---

## 2. 🗺️ Map GIS Ergonomics & Marker Rendering

### 2.1 FlutterMap Configuration & Prebuffering Analysis
- **Tile Prebuffering (`keepBuffer: 6`, `panBuffer: 2`)**:
  - `panBuffer: 2`: Fetches a 2-tile margin outside the visible viewport. This successfully prevents grey fringe flashing during continuous user panning.
  - `keepBuffer: 6`: Retains up to 6 zoom levels of tiles in memory. While this guarantees instant tile reuse when rapidly zooming in/out, keeping 6 zoom levels of CartoDB 256x256 tiles without cache bounds consumes significant GPU/RAM memory on mobile devices.
  - **Tile Provider Recommendation**: In [`spatial_map_screen.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/map/presentation/spatial_map_screen.dart#L159), `tileProvider: NetworkTileProvider()` is used. However, `flutter_map_cancellable_tile_provider: ^3.0.1` is already in `pubspec.yaml`. Migrating to `CancellableNetworkTileProvider()` will immediately cancel obsolete in-flight HTTP requests during fast gestures, saving bandwidth and preventing main-thread frame drops.
- **Boundary Rendering**:
  - City polygon outlines in `PolygonLayer` are correctly wrapped in a `RepaintBoundary`, preventing expensive vector re-rasterization during camera motion.

### 2.2 Dynamic Level of Detail (LOD) & Z-Index Layering
- **Rebuild Isolation**: The marker layer uses `ValueListenableBuilder<double>(valueListenable: _zoomNotifier, ...)` triggered only on camera zoom changes (`onPositionChanged`), avoiding full `FlutterMap` widget tree rebuilds.
- **LOD Visibility Filtering**:
  - **Live Streamers** (Video & Audio): Visible across **all zoom levels** (from max zoom-out to street level).
  - **Offline Broadcasters**: Filtered out until `currentZoom >= 11.2` (`kStreamerMarkersZoomThreshold`).
- **Z-Index Sorting Order**:
  1. Offline Broadcasters (`score = 1`, bottom)
  2. Live Audio Broadcasters (`score = 2`, middle)
  3. Live Video Broadcasters (`score = 3`, top)
  4. Selected Broadcaster (`isSelected`, rendered at absolute top of the stack)
- **Summary Card LOD Transition**:
  - When `currentZoom >= 13.5` (`kAuditoriumCardZoomThreshold`) and a streamer is selected, the avatar marker morphs into an anchored `MarkerSummaryCard` (320x175 px, `Alignment.topCenter`) directly inside the map MarkerLayer.
  - When `currentZoom < 13.5`, the selected card shifts to a floating bottom overlay modal, keeping the map viewport uncluttered.

### 2.3 Marker Collision Algorithm Inspection
- **Algorithm Structure** ([`spatial_map_screen.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/map/presentation/spatial_map_screen.dart#L223-L280)):
  - Streamers are projected to 2D screen coordinates using `MapCamera.of(context).project(origLatLng)`.
  - Runs 10 iterations of pairwise iterative force-directed repulsion with a minimum gap of `7.0px`:
    $$\text{minDistance} = r_1 + r_2 + 7.0 \quad (r_{\text{live}}=28\text{px}, r_{\text{offline}}=23\text{px})$$
  - Coincident markers ($\text{distance} = 0$) fan out radially via $(i+j) \cdot \frac{2\pi}{N}$.
  - Overlapping pairs are pushed apart along their normal vector by $\frac{\text{overlap}}{2}$.
  - Corrected screen pixels are unprojected back to geographic LatLng via `MapCamera.unproject()`.
- **Identified Ergonomics Gaps**:
  1. **Card Collision Bounding Box**: When a streamer is selected at zoom $\ge 13.5$, the layout engine still calculates collision with a 28px circular radius, rather than the 320x175px bounding box of `MarkerSummaryCard`. Consequently, adjacent markers can end up obscured beneath the card.
  2. **Oscillation Damping**: On clusters with 4+ coincident coordinates, 10 iterations without a velocity damping coefficient (e.g. 0.85 per iteration) can cause slight boundary jitter.

---

## 3. 🖼️ Image Memory Footprint & Aspect-Ratio Preservation

### 3.1 `SafeImageProvider` Evaluation
- Located at [`lib/core/widgets/safe_image_provider.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/widgets/safe_image_provider.dart).
- Robustly handles:
  1. `bytes != null` $\to$ `MemoryImage(bytes)`
  2. `path.startsWith('assets/')` $\to$ `AssetImage(path)`
  3. `path.startsWith('http://') || path.startsWith('https://')` $\to$ `NetworkImage(path)`
  4. Local disk path $\to$ `FileImage(File)` with `existsSync()` safety check
  5. Fallback $\to$ `AssetImage('assets/images/Amir_Alhatemi/amir_person_pic.jpg')`

### 3.2 Critical Image Vulnerabilities & Memory Bloat
1. **Crash in [`venue_navigation_sheet.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/map/presentation/widgets/venue_navigation_sheet.dart#L153)**:
   - Uses `backgroundImage: NetworkImage(streamer.avatarUrl)`. If `streamer.avatarUrl` is a local asset path (e.g. `'assets/images/...'`), `NetworkImage` throws an unhandled `UriScheme` exception.
2. **Duplicated Ad-hoc Resolvers**:
   - `spatial_map_screen.dart` (line 544), `streamer_sliding_drawer.dart` (line 183), `discovery_feed_screen.dart` (line 532, 623), `broadcaster_profile_screen.dart` (line 238, 839), `streamer_grid_card.dart` (line 17), and `marker_summary_card.dart` (line 18) all implement fragmented ternary image resolvers instead of sharing `buildSafeImageProvider()`.
3. **Unbounded Full-Resolution Memory Footprint**:
   - Avatars displayed in 40x40 px `CircleAvatar` widgets or banner thumbnails currently load full uncompressed image rasters. A 4000x3000 photo consumes ~48MB of uncompressed RAM in the Flutter image cache.
   - **Recommendation**: Wrap image providers with `ResizeImage.resizeIfNeeded(width, height, provider)` or use `CachedNetworkImageProvider(maxHeight: 120, maxWidth: 120)` to cap memory consumption.

---

## 4. 🌐 Localization Key Symmetry & Unlocalized Strings

### 4.1 Key Symmetry Verification
- [`assets/i18n/en.json`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/assets/i18n/en.json) (651 lines) and [`assets/i18n/ar.json`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/assets/i18n/ar.json) (651 lines):
  - **100.0% Key Symmetry**: Every single key in English exists in Arabic on the exact same line number.
  - All 22 namespaces are fully matched.

### 4.2 Unlocalized Hardcoded Strings Found

| File | Line(s) | Hardcoded String | Recommended Fix |
| :--- | :--- | :--- | :--- |
| `spatial_map_screen.dart` | 438 | `tooltip: 'Recenter to Al Khobar'` | `'map.recenter'.tr()` |
| `spatial_map_screen.dart` | 446 | `tooltip: 'Broadcasters List'` | `'map.streamers_list'.tr()` |
| `spatial_map_screen.dart` | 554, 562 | `streamer.fullNameEn`, `streamer.venueNameEn` | `streamer.getLocalizedName(langCode)` |
| `top_spatial_search_bar.dart` | 66 | `subtitle: 'City in AlSharqia'` | `'map.city_subtitle'.tr()` |
| `admin_hub_screen.dart` | 229 | `Text('Access Denied')` | `'admin.access_denied'.tr()` |
| `admin_hub_screen.dart` | 897 | `tooltip: 'Refresh Applications'` | `'admin.refresh_apps'.tr()` |
| `admin_hub_screen.dart` | 985, 997 | `Text('Reject Selected')`, `Text('Approve Selected')` | `'admin.reject_selected'.tr()`, `'admin.approve_selected'.tr()` |
| `role_permission_management_view.dart` | 298, 300 | `Text('Admin')`, `Text('Master Admin')` | Localized role labels |
| `org_management_view.dart` | 1331, 1345 | `Text('Decline')`, `Text('Accept to Roster')` | `'common.decline'.tr()`, `'common.accept'.tr()` |
| `rtmp_ip_dialog.dart` | 91, 118 | `'Stream Key Required'`, `'Local RTMP Target Updated'` | Localized toast labels |

---

## 5. 🚀 Actionable UI Polish Plan

1. **Unify Image Resolving via `SafeImageProvider`**: Replace bare `NetworkImage` in `venue_navigation_sheet.dart` with `buildSafeImageProvider()`.
2. **Apply Downscaling**: Wrap avatar image providers in `ResizeImage.resizeIfNeeded(120, 120, provider)`.
3. **Upgrade Map Tile Provider**: Replace `NetworkTileProvider()` with `CancellableNetworkTileProvider()` in `spatial_map_screen.dart`.
4. **Localize Hardcoded Strings**: Replace ~25 hardcoded tooltips and button labels with `.tr()` references.

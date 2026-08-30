# 📋 Implementation Plan — Cluster 2: Spatial Map & GIS Navigation Polish

**Target:** Claude Code & Engineering Team  
**Scope:** Cluster 2 (Tasks 7, 8, 9)  
**Location:** `doc/Roadmap/Cluster_2_Spatial_Map_GIS_Navigation_Implementation_Plan.md`  
**Dependencies:** `flutter_map`, `latlong2`, `url_launcher`, `easy_localization`.

---

## 🎯 High-Level Objective
Polish the Spatial Map and GIS navigation experience by resolving the Carto basemap API key issue with reliable free tile providers, giving the map avatar markers a clean white background so they pop distinctly against the map without altering the dark glassmorphism styling of map cards, and enabling one-click Google Maps external navigation strictly within the Spatial Map tab (Marker Summary Card, Navigation Sheet, and Sliding Side Drawer).

---

## 🛠️ Step-by-Step Implementation Instructions

### 📌 STEP 1: Fix Carto Basemap API Key Issue with Resilient Free Tile Provider (Task 7)

#### 1.1 Free Tile Provider & Dark Aesthetic Customization Options
We have 3 resilient, zero-API-key methods to achieve the sleek dark academic map look:

- **Option A (Recommended Primary — Esri World Dark Gray Base):**
  - URL: `https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}`
  - Pros: 100% free, high GIS quality, sleek dark graphite theme without any API key or billing required.
- **Option B (Direct Multi-Subdomain Raster Endpoints):**
  - URL: `https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png`
  - Subdomains: `['a', 'b', 'c', 'd']`
  - Fallback URL: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- **Option C (In-App Dark ColorFilter over OpenStreetMap):**
  - URL: `https://tile.openstreetmap.org/{z}/{x}/{y}.png` with Flutter `ColorFilter.matrix(...)` to invert/tint tiles into a custom dark midnight theme locally with zero server dependence.

#### 1.2 Animated Zoom-In & Camera Fly-To System
The camera animation system in `_animateCameraTo` in `spatial_map_screen.dart` is preserved and active:
- Uses `CurvedAnimation(parent: _cameraAnimationController, curve: Curves.fastOutSlowIn)`.
- **On Streamer Select:** Flies camera smoothly to `LatLng(streamer.latitude, streamer.longitude)` at `14.5` zoom.
- **On City Pick (Al Khobar / Dhahran / Dammam):** Glides camera to `region.centerCoordinates` at `13.5` zoom.
- **On Recenter Button Tap:** Returns camera smoothly to Al Khobar center.

#### 1.3 Max, Min, Default Zoom & Regional Boundary Enforcement
Configured in `MapOptions`:
- `initialZoom: 12.5`: Default city overview on app start.
- `minZoom: 8.5`: Prevents zooming out beyond the region.
- `maxZoom: 17.5`: Detailed street, venue, and campus level.
- `cameraConstraint: CameraConstraint.contain(bounds: LatLngBounds(LatLng(25.60, 49.50), LatLng(27.10, 50.80)))`: Binds user navigation strictly within the Eastern Province (AlSharqia).

#### 1.4 TileLayer Configuration in `spatial_map_screen.dart`
- **Target File:** `project/lib/features/map/presentation/spatial_map_screen.dart`
- **Actions:**
  1. In `SpatialMapScreen.build()` -> `FlutterMap` -> `children` -> `TileLayer`:
     - Replace the broken `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png` template.
     - Implement the resilient multi-tier tile configuration:
       ```dart
       TileLayer(
         urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png',
         fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
         subdomains: const ['a', 'b', 'c', 'd'],
         maxZoom: 19,
         userAgentPackageName: 'com.streamer.app',
         tileProvider: NetworkTileProvider(),
         keepBuffer: 6,
       ),
       ```
  2. Remove any Carto API key query parameter requirements to guarantee zero unexpected tile breakages.

---

### 📌 STEP 2: Spatial Map Profile Markers White Background (Task 8)

> [!IMPORTANT]
> **STRICT SCOPE:** This change is **ONLY** for the round/squircle avatar marker discs on the map canvas. **DO NOT** edit or change the cards on the map (`MarkerSummaryCard`, `MapDiscoveryChannelCardMarker`, `StreamerSlidingDrawer` cards must maintain their dark graphite `#18181B` / `#27272A` theme).

#### 2.1 Update Marker Avatar Containers
- **Target Files:**
  1. `project/lib/features/map/presentation/widgets/spatial_streamer_marker.dart`
  2. `project/lib/features/map/presentation/widgets/offline_marker.dart`
  3. `project/lib/features/map/presentation/widgets/pulsing_live_marker.dart`
- **Actions:**
  1. In `spatial_streamer_marker.dart` (Lines 185–210):
     - Change the main avatar body container background from `AppTheme.darkSurface1` to `Colors.white`:
       ```dart
       // 2. Main Avatar Body Container
       Container(
         width: isLive ? 44.0 : 38.0,
         height: isLive ? 44.0 : 38.0,
         padding: const EdgeInsets.all(2.0),
         decoration: BoxDecoration(
           shape: isOrg ? BoxShape.rectangle : BoxShape.circle,
           borderRadius: isOrg ? BorderRadius.circular(12.0) : null,
           color: Colors.white, // <-- Crisp white background for avatar disc
           border: Border.all(
             color: widget.isSelected
                 ? AppTheme.accentBlue
                 : (isLive ? primaryAccent : Colors.white),
             width: widget.isSelected ? 2.5 : (isLive ? 2.0 : 1.5),
           ),
           boxShadow: [
             BoxShadow(
               color: isLive
                   ? primaryAccent.withValues(alpha: 0.45)
                   : Colors.black.withValues(alpha: 0.4),
               blurRadius: widget.isSelected ? 10 : (isLive ? 8 : 4),
               spreadRadius: isLive ? 1 : 0,
             ),
           ],
         ),
         child: _buildAvatarImage(),
       ),
       ```
  2. In `offline_marker.dart`: Set the circular border and inner background container to `Colors.white`.
  3. In `pulsing_live_marker.dart`: Keep the animated radar pulse ring active while updating the inner avatar container background to `Colors.white`.

---

### 📌 STEP 3: One-Click Google Maps Integration on Spatial Map (Task 9)

> [!IMPORTANT]
> **STRICT SCOPE:** This feature is scoped **EXCLUSIVELY** to the Spatial Map tab (`/map`):
> 1. In `MarkerSummaryCard` (the card that pops up on the map when tapping a streamer).
> 2. In `VenueNavigationSheet` (the venue details sheet opened from the map).
> 3. In `StreamerSlidingDrawer` (the side list drawer on the map).
> **DO NOT** add Google Maps launch buttons to the Discovery Feed tab (`/feed`).

#### 3.1 Direct Launch in `venue_navigation_sheet.dart`
- **Target File:** `project/lib/features/map/presentation/widgets/venue_navigation_sheet.dart`
- **Actions:**
  1. Replace the clipboard-copy logic (Lines 390–440) on the "Open in Maps / فتح الخرائط" button with direct `launchUrl`:
     ```dart
     onPressed: () async {
       final googleMapsUrl = Uri.parse(
         'https://www.google.com/maps/search/?api=1&query=${streamer.latitude},${streamer.longitude}',
       );
       try {
         if (await canLaunchUrl(googleMapsUrl)) {
           await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
         } else {
           // Fallback to clipboard if browser/maps cannot be launched
           await Clipboard.setData(ClipboardData(text: googleMapsUrl.toString()));
         }
       } catch (e) {
         debugPrint('Error launching Google Maps: $e');
       }
     }
     ```

#### 3.2 Direct Launch in `marker_summary_card.dart`
- **Target File:** `project/lib/features/map/presentation/widgets/marker_summary_card.dart`
- **Actions:**
  1. In the venue row or action buttons row, add a dedicated one-click navigation button:
     ```dart
     IconButton(
       icon: const Icon(Icons.directions_rounded, color: AppTheme.accentBlue, size: 20),
       tooltip: 'venue.open_maps'.tr(),
       onPressed: () async {
         final url = Uri.parse(
           'https://www.google.com/maps/search/?api=1&query=${streamer.latitude},${streamer.longitude}',
         );
         if (await canLaunchUrl(url)) {
           await launchUrl(url, mode: LaunchMode.externalApplication);
         }
       },
     )
     ```

#### 3.3 Direct Launch in `streamer_sliding_drawer.dart`
- **Target File:** `project/lib/features/map/presentation/widgets/streamer_sliding_drawer.dart`
- **Actions:**
  1. In `_buildStreamerTile()` (Lines 210–260): Add a direct Google Maps action icon on each scholar/venue tile:
     ```dart
     IconButton(
       icon: const Icon(Icons.directions_outlined, size: 18, color: AppTheme.accentBlue),
       tooltip: 'venue.open_maps'.tr(),
       onPressed: () async {
         final url = Uri.parse(
           'https://www.google.com/maps/search/?api=1&query=${streamer.latitude},${streamer.longitude}',
         );
         if (await canLaunchUrl(url)) {
           await launchUrl(url, mode: LaunchMode.externalApplication);
         }
       },
     )
     ```

---

## 🧪 Verification & Testing Plan

### Automated Tests
Run from `project/`:
```powershell
flutter analyze
flutter test test/spatial_map_test.dart
flutter test
```

### Manual Verification Checklist
1. **Map Tiles:** Open the Spatial Map tab (`/map`); pan, zoom in to Al Khobar / Dhahran / Dammam, zoom out. Verify all tiles load crisp and clear without any API key watermark, rate limit error, or grey blank squares.
2. **White Marker Discs:** Check offline, live video, and live audio markers on the map canvas. Verify the avatar background is crisp white, while cards (`MarkerSummaryCard`, `StreamerSlidingDrawer`) retain their dark graphite theme.
3. **Google Maps Launch (Map Only):**
   - Tap a marker on the map -> in `MarkerSummaryCard`, click directions -> verify Google Maps opens with the exact venue coordinates.
   - Open the side drawer in the map -> click the directions icon next to a scholar -> verify Google Maps opens.
   - Open `VenueNavigationSheet` from the map -> tap "Open in Maps" -> verify Google Maps opens.
   - Navigate to the Discovery Feed tab (`/feed`) -> confirm NO Google Maps button was added to feed cards.

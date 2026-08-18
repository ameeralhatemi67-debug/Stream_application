# Line-by-Line Debugger Analysis Report

**Author:** Line-by-Line Flutter Debugger Agent  
**Target:** `lib/features/map/presentation/spatial_map_screen.dart`  
**Date:** August 2026

---

## 1. Line-by-Line Diagnostic Audit of `spatial_map_screen.dart`

```dart
201: cameraConstraint: CameraConstraint.contain(
202:   bounds: LatLngBounds(
203:     const LatLng(25.40, 49.20),
204:     const LatLng(27.10, 50.70),
205:   ),
206: ),
```
* **Line 201-206 Analysis:** `CameraConstraint.contain` strictly clamps the map center and camera viewport to AlSharqia bounds. When zooming in past 10.2 near Al Khobar edges (`26.2871, 50.2125`), if the camera attempts to move outside `LatLngBounds(25.40, 49.20) -> (27.10, 50.70)`, FlutterMap's internal camera math rejects out-of-bounds viewports.
* **Potential Issue:** Clamping causes tile grid calculation bounds to truncate tile coordinates $Z/X/Y$ at zoom levels 13–16, causing boundary tiles to fail calculations and drop.

```dart
224: TileLayer(
225:   urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
226:   subdomains: const ['a', 'b', 'c', 'd'],
227:   maxZoom: 19,
228:   userAgentPackageName: 'com.streamer.app',
229:   tileProvider: CancellableNetworkTileProvider(),
230:   retinaMode: RetinaMode.isHighDensity(context),
231:   keepBuffer: 4,
232:   panBuffer: 1,
233:   errorTileCallback: (tile, error, stackTrace) { ... },
234: )
```
* **Line 225 Analysis (`{r}` & `retinaMode`):** `retinaMode: RetinaMode.isHighDensity(context)` replaces `{r}` with `@2x`. On Android high-DPI physical devices, CartoDB tile URLs request `.../{z}/{x}/{y}@2x.png`.
* **Potential Issue:** At zoom level 13–16, CartoDB `@2x` tiles require 4x memory per tile image. On mobile devices with limited GPU memory caches, loading high-res `@2x` tiles while markers pop in at zoom $\ge 10.2$ causes Skia/Impeller image decoding buffers to crash or silently fail.

```dart
253: ValueListenableBuilder<bool>(
254:   valueListenable: _areMarkersVisibleNotifier,
255:   builder: (context, areMarkersVisible, child) { ... }
```
* **Line 253-255 Analysis:** When crossing `zoom >= 10.2`, `ValueListenableBuilder` builds 5 `Marker` widgets. Each `Marker` contains a `PulsingLiveMarker` with a repeating `AnimationController`.
* **Potential Issue:** Rebuilding `MarkerLayer` at zoom 10.2 invalidates the layer stack composite above `TileLayer`.

---

## 2. Recommended Line-by-Line Fixes

1. **Remove `{r}` from `urlTemplate` or Force Standard Resolution:**
   Change `urlTemplate` to `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png` (without `{r}`) and set `retinaMode: false` or `RetinaMode.disabled`. Standard 256x256 tiles load 4x faster and use 75% less GPU memory than `@2x` retina tiles on mobile networks.
2. **Relax Camera Constraints:**
   Widen `cameraConstraint` slightly to `LatLngBounds(LatLng(24.50, 48.50), LatLng(28.00, 51.50))` to prevent hard camera clamping math errors at high zoom levels.
3. **Set `fallbackUrl` in `TileLayer`:**
   Add `fallbackUrl: 'https://a.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}.png'` so if CartoDB primary server drops a tile, it instantly loads from the fallback subdomain.

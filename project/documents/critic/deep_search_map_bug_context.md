# Deep Search Technical Context: FlutterMap Gray-Screen Bug at Zoom Threshold

## 1. Problem Statement & User Symptoms
- **Symptom 1:** When the map is fully zoomed out (zoom < 10.2), the dark basemap tiles render smoothly.
- **Symptom 2:** As soon as the user zooms in past `zoom >= 10.2`, circular broadcaster profile pictures (markers) pop into view. At that exact moment, the map background turns solid gray and remains gray indefinitely.
- **Symptom 3:** The gray background does not recover even after waiting. Only markers and top floating UI controls remain visible over the blank gray canvas.

---

## 2. Technical Code Analysis & Diagnostic Evidence

### A. The Zoom Threshold & `setState` Rebuild Storm
In `lib/features/map/presentation/spatial_map_screen.dart`:
```dart
onPositionChanged: (position, hasGesture) {
  _onZoomChanged(position.zoom);
},

void _onZoomChanged(double zoom) {
  setState(() {
    _areMarkersVisible = zoom >= 10.2;
  });
}
```
* **Issue:** Calling `setState()` inside `onPositionChanged` triggers a top-level widget rebuild on **every single micro-frame of pinch gesture** (up to 60 times a second).
* **Impact:** Rebuilding `SpatialMapScreen` and `FlutterMap` repeatedly while touch gestures are active interrupts `FlutterMap`'s internal tile controller, aborting in-flight HTTP tile network requests.

### B. Marker Ticker Animations & Network Images
In `lib/features/map/presentation/widgets/pulsing_live_marker.dart`:
```dart
_animationController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1800),
)..repeat();

CircleAvatar(
  backgroundImage: NetworkImage(widget.marker.avatarUrl), // Uncached network HTTP image
)
```
* **Issue:** When `zoom >= 10.2`, 5 marker widgets suddenly pop in. Each marker runs a 60-FPS continuous `AnimationController..repeat()` ticker loop AND fires an un-cached `NetworkImage` HTTP fetch from external URLs.
* **Impact:** Main UI/raster thread bottlenecking. Combining 5 repeating animation tickers, 5 uncached avatar network fetches, and continuous parent `setState()` rebuilds completely starves tile decoding, causing the background to freeze in a gray state.

### C. Monolithic `context.watch<AppProvider>()`
```dart
@override
Widget build(BuildContext context) {
  final appProvider = context.watch<AppProvider>();
  // Rebuilds entire screen on any provider notification...
```

---

## 3. Targeted Technical Requirements for Deep Search
We are seeking **multiple distinct architectural solutions** to optimize and eliminate this bug completely:

1. **State & Gesture Decoupling:** How to handle zoom threshold changes (`_areMarkersVisible`) and camera position updates without calling `setState()` on every pinch-gesture micro-frame.
2. **Marker Layer Performance:** Best practices for rendering custom animated markers in `flutter_map` (e.g. repainting inside `CustomPainter`, disabling tickers offscreen, caching avatar images with `cached_network_image`, or rasterizing markers into a single layer).
3. **Tile Layer Resilience:** Configuration patterns for `flutter_map` `TileLayer` to prevent tile dropping during active gestures (e.g. tile caching, separate tile controllers, or dedicated isolate image decoders).
4. **Alternative Vector / Map Architectures:** Pros and cons of switching to `maplibre_gl` or `mapbox-maps-flutter` for GPU-accelerated vector rendering.

---

## 4. Relevant Source Files
- `lib/features/map/presentation/spatial_map_screen.dart`
- `lib/features/map/presentation/widgets/pulsing_live_marker.dart`
- `lib/features/map/presentation/widgets/offline_marker.dart`
- `lib/core/providers/app_provider.dart`
- `pubspec.yaml`

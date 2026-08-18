# SVG Geometry & Map Asset Trimmer Analysis Report

**Author:** SVG Geometry & Map Asset Trimmer Agent  
**Target:** `assets/map/gadm41_SAU_2.svg` & `lib/features/map/models/map_models.dart`  
**Date:** August 2026

---

## 1. Vertex Density & Vector Complexity
- **`gadm41_SAU_2.svg`**: The SVG vector paths (e.g., `path5` for Al Khobar, `path14` for Dammam, and `path15` for Dhahran) contain extremely high vertex densities. They are mapped with high-precision decimals (e.g., up to 6 decimal places) and include hundreds to thousands of points per region.
- **`map_models.dart`**: The `PolygonPoints` array in `MapRegionModel` represents a highly abstracted boundary (only 4 to 5 `LatLng` coordinates per region) meant for broad bounds and zoom targeting, whereas the SVG contains the complex, realistic geographical boundaries.

## 2. Canvas Buffer Invalidation & Frame Drops (Zoom >= 10.2)
- Rendering such high-density polygons inside a Flutter `PolygonLayer` or directly to a Canvas using `flutter_svg` forces heavy tessellation on the CPU/GPU.
- When zooming past certain thresholds (e.g., zoom level 10.2), the geometry gets clipped or scaled beyond the viewport bounding box, forcing the Flutter rendering engine to re-tessellate and recreate the canvas buffers on each frame. This buffer invalidation is the primary cause of GPU frame drops, as tessellating paths with thousands of vertices is computationally expensive in real-time.

## 3. Proposed Optimization Strategies
To optimize the map rendering performance, the following strategies should be implemented:
1. **Polygon Decimation (Douglas-Peucker Algorithm)**:
   Pre-process the SVG paths to reduce vertex count. The Douglas-Peucker algorithm can eliminate redundant vertices along nearly straight lines, massively reducing the point count while maintaining the visual integrity of the boundary.
2. **Path Trimming & Simplification**:
   Round floating-point coordinates to 2 or 3 decimal places in the SVG. This reduces the file size and parsing time without noticeable visual degradation on mobile screens.
3. **SVG Clipping & Tiling**:
   Instead of rendering a single massive SVG path for the entire region when zoomed in, use bounding-box culling. Only render the segments of the SVG that intersect the current map viewport. For deeply zoomed views (> 10.2), consider switching from vector SVGs to raster tiles or using a simplified `PolygonLayer` bounded by the viewport's bounding box.

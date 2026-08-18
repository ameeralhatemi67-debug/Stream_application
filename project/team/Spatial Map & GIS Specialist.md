As the GIS & Spatial Specialist, your primary focus is creating the "wow factor" visual centerpiece of the pitch: loading the custom GeoJSON municipal vector outlines of AlSharqia, locking down camera boundaries, building 1.5-second cinematic zoom curves, designing pulsing map pins, and implementing spatial navigation controls (Search Bar, Dropdown Selector, and Streamer Drawer).

# Spatial Map & GIS Specialist Roadmap

## Version 0.1: The AlSharqia Impressive Spatial Map Engine

### Checkpoint 1.2: Spatial Canvas, Boundary Limits, Camera Curves & Spatial UI

#### Phase 1.2.1: Research, Design & GIS Discovery

- **Task 1:** Inspect and structure vector boundary data using the root `gadm41_SAU_2.svg` file for Saudi Arabia’s Eastern Province (AlSharqia), focusing on **Al Khobar, Dhahran, and Dammam**, establishing GeoJSON extraction and web search as fallback strategies.
    
- **Task 2:** Research vector styling in Flutter (`flutter_svg` / `flutter_map` / `vector_map_tiles`) to achieve a flat, desaturated outline look with dark polygon fills (`#0E0E10` theme).
    
- **Task 3:** Map out spatial touch interactions: single tap (select sector), double tap (trigger cinematic zoom curve), and zoom-threshold pin visibility.
    
- **Task 4:** Design dynamic custom marker UI: animated pulsing radar rings (`#FF8080`) for **Live Broadcasters** and static markers for **Offline Broadcasters**.
    

#### Phase 1.2.2: Spatial Map Canvas & Boundary Constraints

- **Task 1:** Integrate `SpatialMapCanvas` ingesting `gadm41_SAU_2.svg` vector paths (or GeoJSON fallback) to render AlSharqia municipal borders.
    
- **Task 2:** Apply dark desaturated polygon styling with subtle grey border strokes to replicate the high-end spatial layout mockup.
    
- **Task 3:** Set `minZoom` and `maxZoom` parameters, locking `LatLngBounds` strictly to the Eastern Province to prevent panning into empty gray voids.
    
- **Task 4:** Implement polygon tap handlers that highlight sector borders (e.g., shifting from dark gray to an accent border stroke) on click.
    

#### Phase 1.2.3: Interactive Cinematic Camera & Dynamic Markers

- **Task 1:** Build `PulsingLiveMarker` (animated red CSS/SLA keyframe rings) and `OfflineMarker` custom widgets.
    
- **Task 2:** Implement an `AnimationController` that calculates interpolated positions over a 1.5-second curve down to target city coordinates (e.g., Al Khobar) using `mapController.moveAndRotate()`.
    
- **Task 3:** Implement a map zoom listener that keeps broadcaster pins hidden when zoomed out, smoothly fading them in once passing the target zoom threshold.
    
- **Task 4:** Wire marker click interactions: single-tap expands a floating summary card over the pin; double-tap delegates routing to Team Lead's profile handler.
    

#### Phase 1.2.4: Spatial Navigation Controls (Search, Dropdown & Drawer)

- **Task 1:** Build the top floating search bar with auto-complete matching city names; selecting a city triggers the cinematic camera zoom sequence.
    
- **Task 2:** Build the center city selector dropdown (`Al Khobar v`, `Dhahran v`, `Dammam v`); choosing an item animates the camera to that city’s vector coordinates.
    
- **Task 3:** Build the right-side `endDrawer` sliding panel listing all 5 mock professors with their location tags and pulsing live availability badges.
    
- **Task 4:** Wire drawer item selection to focus the map camera directly over the selected professor's venue coordinates.
    

## Version 1.0: Pitch Polish & Spatial Touch Refinement

### Checkpoint 4.2: Map Boundary Elasticity, Gesture Friction & Pitch Hardening

#### Phase 4.2.1: Research & Spatial Gesture Audit

- **Task 1:** Audit map panning friction against drawer swipe gestures to prevent accidental drawer opens while dragging the map view.
    
- **Task 2:** Test boundary constraint collision response during aggressive panning gestures.
    

#### Phase 4.2.2: Spatial UX Polish & Boundary Elasticity

- **Task 1:** Implement smooth spring-back / elastic boundary behavior if a user swipes hard toward the edge of the AlSharqia region.
    
- **Task 2:** Fine-tune marker icon scaling so live pulsing rings remain crisp across high-DPI test devices.
    

#### Phase 4.2.3: GIS Performance Optimization & Pitch Rehearsal

- **Task 1:** Optimize GeoJSON coordinate arrays (simplify vertex count if necessary) to maintain a rock-solid 60 FPS during camera zoom animations.
    
- **Task 2:** Participate in final pitch rehearsals with Team Lead, verifying map animation stability under "Pitch Director Mode" overrides.
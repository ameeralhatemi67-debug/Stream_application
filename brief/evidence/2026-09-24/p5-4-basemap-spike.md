# P5.4 basemap decision checkpoint, 2026-09-24

Base: local `master` `2a0f19d` in clean isolated worktree `codex/p5-basemap-spike`. Scope is P5.4 only. No push, production access, public tile download, owner test-folder edit, or stash operation.

## Decision

Do not adopt the PMTiles/vector basemap yet. The documented package route is plausible, but the four acceptance criteria require a real, licensed regional archive and a physical or mid-range emulator run. A tiny synthetic archive would establish that the API renders one tile, but would not answer archive size, Eastern Province coverage, style legibility, or cold offline paint time. Installing a renderer without those results would add release dependencies without deciding P5.4.

| Criterion in P5.4 | Evidence this spike | Result |
| --- | --- | --- |
| Eastern Province z0-14 and Saudi low zoom coverage | No archive was obtained or checked | Unknown |
| Offline first paint under 2 s on a mid emulator | No emulator paint timing | Unknown |
| APK/AAB growth at most 40 MB | No baseline/candidate APK or AAB was built | Unknown |
| Legible on the white theme | Current online attribution now wraps; no vector style rendered | Unknown for PMTiles |
| Required attribution | Current online Esri source names localized without ellipsis and linked to OSM copyright; PMTiles credit documented, not rendered | Partial, device check open |

The only measured size in this spike is the removed unused GADM SVG: 71,134 bytes on disk. It is not an APK/AAB delta. No size or time criterion is marked passed.

## Package and data checks

- The app declares `flutter_map: ^7.0.2`. [`vector_map_tiles_pmtiles` 1.5.0 changelog](https://pub.dev/packages/vector_map_tiles_pmtiles/changelog) says 1.4.0 moved to `vector_map_tiles: ^8.0.0` for `flutter_map` v7, and 1.5.0 added Protomaps v4.1 themes. Its [usage page](https://pub.dev/packages/vector_map_tiles_pmtiles) shows a local PMTiles file provider and a light theme. This is documentation compatibility, not a local dependency-solver or runtime result. The newest [`flutter_map_vector_tiles` 2.9.0](https://pub.dev/packages/flutter_map_vector_tiles) requires `flutter_map` 8.2.0 or newer, so adopting it would first require a separate map upgrade. `flutter_map_pmtiles` is a raster `TileProvider`, not a vector renderer.
- [Protomaps](https://docs.protomaps.com/basemaps/downloads) allows regional PMTiles extraction from its OSM-derived basemap. Its [CLI](https://docs.protomaps.com/pmtiles/cli) supports a region/bbox and zoom ranges. A z0-14 extract must be produced and measured; the planet's size cannot establish this app's delta. OSM attribution and Produced Work terms apply; see `store/map_licensing.md`.
- The fallback's Natural Earth polygon source is [public domain](https://www.naturalearthdata.com/about/terms-of-use/). Raster browse caching may use only a provider whose terms permit it. OSM's [public tile policy](https://operations.osmfoundation.org/policies/tiles/) forbids offline bulk download. `flutter_map_tile_caching` v9.1.4 is GPL-3.0, so its release use needs a license decision.

## Next bounded test

1. Pick a dated Protomaps v4 build and record its source URL, version, checksum, ODbL credit, and style license. Define a reviewed Eastern Province boundary and Saudi overview coverage. Use the official PMTiles CLI to extract two disjoint zoom ranges (Saudi low zoom and Eastern Province through z14), merge if the formats match, and verify header, tile samples, and exact file bytes. Source this from a permitted archive or OSM data extract, never from a public raster tile server.
2. In this branch, add `vector_map_tiles: 8.0.0` and `vector_map_tiles_pmtiles: 1.5.0` only after the local solver passes. Match the Protomaps v4.1 light theme to the chosen archive. Keep attribution visible on the map in both languages and link to the OSM license. Keep the bundled schematic layer until the replacement works offline.
3. Build baseline and candidate Android APK and AAB with the same mode, defines, ABI/split settings, and toolchain. Record artifact byte counts and differences; pass only if each required artifact grows by at most 40,000,000 bytes (40 MB). This task built neither artifact.
4. On a named mid-range emulator, clear app data, install the candidate, turn on airplane mode, cold launch directly to the map, and time from map entry until geographic detail and labels appear. Repeat at least five times at Eastern Province default and Saudi overview; report median and worst time. Inspect white-theme roads, labels, marker contrast, and complete attribution in English and Arabic at 1.0x and 1.3x text scale. Fail if any required view stays blank, credit is clipped, or paint reaches 2 s.
5. If size, time, style, or credit fails, use fallback F: a licensed live raster provider with browse-only caching and a bundled Natural Earth simplified region layer. Add cache size and clear controls in Settings only after choosing cache licensing. Verify an airplane-mode cold start with cached catalog/markers and a never-blank base. Do not prefetch OSM or Esri tiles.

## Exact owner device checks after implementation

Use a recorded app commit/build and one named physical Android phone plus the mid emulator. Online, inspect the default Eastern Province view, pan to Dammam, Al Khobar, Jubail and Hofuf, then zoom out to Riyadh and Jeddah. Confirm roads and place labels remain readable under the white controls and map markers. In English and Arabic, check that every provider name and the copyright mark is visible with normal and enlarged text, without overlap from controls or the offline banner. Open the map, force-stop the app, enable airplane mode, cold-start, and confirm the base, cached markers, offline banner and attribution behavior. Return online, retry, and confirm the map recovers. In Settings, record cache bytes before and after Clear, then repeat the offline cold start and confirm the bundled base remains. Record screenshots, device/OS, build SHA, exact timings and APK/AAB file lengths. Do not treat this spike as P5 acceptance.

## Verification performed

`node brief/tools/gates.mjs --json` after the localization edit reported G3=0, G5c=0, G6=0 and G7=0. The first run reported G3=2 because raw copyright symbols in the JSON matched the pictograph scanner; JSON `\u00A9` escapes decode to the same visible mark and cleared it. A JSON parse check confirmed both languages retain Esri, HERE, Garmin, OpenStreetMap, GIS and the visible copyright mark. `git diff --check` passed.

`flutter pub get --offline` resolved the existing lockfile. Focused `flutter analyze lib/features/map/presentation/spatial_map_screen.dart` found 0 issues, and `flutter test --no-pub test/spatial_map_test.dart` passed 28 tests. The broader `layout_sweep_test.dart` exited with a Dart VM error; a narrowed empty-map retry exited with `zone.cc: 96: error: Out of memory` while compiling JIT. The changed attribution was therefore not visually verified at narrow widths. Flutter-generated Windows plugin registration edits from dependency resolution were restored, leaving no unrelated tracked changes. No full Flutter suite, package addition/solver check for the candidate stack, emulator run or artifact build is claimed.

Usage: Codex weekly entry 31% used, research/edit checkpoint 31%, pre-commit checkpoint 31% (integer meter reading). No reset used.

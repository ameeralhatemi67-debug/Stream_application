# P5.5 map presentation checkpoint — 2026-09-24

Worktree: `C:\Users\User\.codex\worktrees\p5-basemap-spike\Streamer_app`, branch `codex/p5-basemap-spike`, based on P5.4 tip `d33fc41`; implementation commit `40e444f`. P5 remains unaccepted. No production access, push, merge, tile bulk download, owner P6 test-folder edit, or stash operation.

## What changed

- Replaced ten pairwise marker-displacement passes with a 72-pixel screen-space grid. Clusters have IDs from sorted member IDs, so catalog reorder leaves identity stable. A cluster tap zooms by two levels, capped at 17.5; at the top zoom it lists members for an exact selection. Both online and cached-marker layers use the same bounded grouping. Individual pins keep their exact venue coordinates.
- Expanded the camera center constraint to a Saudi-wide box (15.5–33.0° N, 34.0–56.0° E) and minimum zoom 5.0. The initial view and reset remain Al Khobar. Presets include Saudi Arabia, Eastern Province, Al Khobar, Dhahran, Dammam, Jubail, Hofuf, Riyadh, and Jeddah. The existing three Eastern Province polygons remain the only bundled offline geographic shapes.
- Search recalculates from the current provider-backed visible map list on every build. The presentation filter requires verified, map-visible records with coordinates inside the map bounds. Cached pins are intersected with current eligible IDs; a removed or hidden record is dropped after provider refresh. Selection is resolved by ID against the current visible list rather than retaining an old model object. The map performs no privileged visibility write.
- Added stronger marker contrast, an accent/star badge for the current account's channel, marker and cluster accessibility labels, bilingual empty and tile-error messages, and native directions links (Google Maps route URL on Android, Apple Maps URL on iOS, external HTTPS fallback). Provider names and the required copyright credit remain unchanged in the localized attribution.

## Measured verification

| Check | Result |
| --- | --- |
| Dense layout | Focused test projected 1,000 points exactly 1,000 times and formed one stable cluster; reversed input produced the same member order and ID. This counts layout projections, not frame time. |
| Sparse/refresh layout | Focused test retained singleton IDs and exact coordinates, then removed one ID after a refreshed input. |
| Search/filter | Focused tests removed hidden and unverified records and confirmed refreshed search and eligible cached-ID sets do not retain them. |
| Presets/navigation | Focused tests checked required cities, bounds, zoom range, Arabic names, cluster tap progression, native coordinate URIs, and own-marker tap/highlight. |
| Flutter analysis | `flutter analyze --no-pub`: 0 issues. |
| Focused tests | Final P5.5 test file: 8 passed, including a provider-list refresh widget check. The final full suite also covers the existing spatial map and top-bar tests. Initial focused harness failures were fixed before these results. |
| Full suite | Final `flutter test --no-pub --reporter expanded`: 557 passed in 2:59; layout sweep completed. A prior full run passed 556 before the last search/directions review added one test. The final temp log is `p5_final_flutter_test_2026-09-24.log` under the machine's temp directory. |
| Repository gates | One `node brief/tools/gates.mjs --json` at the map checkpoint: all target gates passed, including G5c=0, G6=0, G7=0, G11a=0. Later edits changed only map behavior and symmetric en/ar wording; the gate script was not repeated. Informational G10b=2 and G10e=3 remain informational; no SQL was changed. |

No APK/AAB was built, so size change is **unknown**. No emulator or physical phone measured offline first paint, map frame time, white-theme legibility, actual native app launch, or attribution at enlarged text. Those criteria are **unknown**, not passed. The P5.4 PMTiles/vector approach remains a decision hold: no archive, renderer, tile dependency, or offline national basemap was added.

## Data and licensing boundary

The current online light raster and OSM fallback retain the existing attribution. This pass uses only city view centers and the previously bundled Eastern Province polygons; it obtains no new basemap data. The [P5.4 decision note](p5-4-basemap-spike.md) records the package and data assessment. Relevant current sources: [flutter_map camera and constraints](https://github.com/fleaflet/flutter_map/blob/master/_autodocs/api-reference/camera-constraint.md), [url_launcher external application behavior](https://pub.dev/packages/url_launcher), [Google Maps directions URLs](https://developers.google.com/maps/documentation/urls/get-started), [Protomaps regional archive guidance](https://docs.protomaps.com/basemaps/downloads), [OSM public tile policy](https://operations.osmfoundation.org/policies/tiles/), [Natural Earth public-domain terms](https://www.naturalearthdata.com/about/terms-of-use/), and [map attribution record](../../../store/map_licensing.md). No public tile server was bulk downloaded.

## Remaining limits and owner checks

The Saudi-wide online view still depends on live raster tiles. Airplane mode has a schematic basemap only around the three existing Eastern Province polygons; Riyadh, Jeddah, Jubail, and Hofuf have no bundled geographic detail. The P5.4 archive size, offline paint, white style, and attribution gate remains open. A disconnected device cannot learn that a venue was revoked after its last successful catalog sync; the offline banner must be treated as a timestamped snapshot. The tile-error message is based on repeated tile load errors and needs a device check with the fallback source. The grid bounds layout work, but adjacent cells can still render nearby badges close together; device readability remains open.

Use a build from this branch and record commit, phone/Android version, locale, text scale, network mode, screenshots and observed times:

1. Online in English at 1.0x: open Map; confirm Al Khobar initial view. Choose Dammam, Al Khobar, Jubail, Hofuf, Riyadh, Jeddah, Eastern Province and Saudi Arabia; inspect roads, labels, map bounds and preset zoom. Pan, zoom, reset to Al Khobar, switch tabs and return. Repeat in Arabic at 1.3x; check RTL control order, no clipped search/preset/credit text, and full Esri, HERE, Garmin, OpenStreetMap and GIS attribution.
2. With a dense known venue area, tap a count badge until member choice appears, select one broadcaster, close its card, tap an individual pin and double-tap to zoom. Verify that a sparse pin stays on its venue. Confirm the current account's verified channel carries the accent/star badge and spoken marker labels identify name and venue.
3. Search a currently verified venue. On an authorized disposable backend, have the P6 owner hide or remove that record, refresh the provider, then confirm its search result, pin, selection card and cached pin no longer appear. Restore only through the authorized P6 flow. Search an unverified record and confirm no result. This pass does not mutate visibility.
4. Tap Directions from a venue card, drawer and offline pin; confirm the native Android map app opens at the exact public venue coordinates. If no native handler exists, confirm the HTTPS fallback. Check empty search, empty catalog and tile-load failure messaging without raw errors.
5. After a successful sync, force-stop, enable airplane mode, cold-start the map and time entry to first visible geographic detail and pins five times. Check the offline timestamp/banner, cached-pin status, topic filter, retry, and the deliberately limited Eastern Province schematic. Restore network and confirm refresh. Record artifact byte lengths only if APK and AAB are actually built under controlled baseline/candidate settings.

Codex weekly usage: entry 31% used; implementation checkpoint 32%; final verification checkpoint 33% used. No reset used.

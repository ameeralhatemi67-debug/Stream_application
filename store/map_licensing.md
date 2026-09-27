# Map sources and licensing

## Current state (2026-09-26, branch `codex/tricity-map-upgrade`, not merged)

The Esri and `tile.openstreetmap.org` raster layers are removed from the app. The Spatial Map and the venue location picker now draw a **bundled** regional vector pack; the app requests no map tiles, styles, sprites or glyphs from any server. Details and hashes: `project/assets/maps/tricity/manifest.json`, build steps: `project/tool/maps/README.md`, evidence: `brief/evidence/2026-09-26/p5-tricity-map-upgrade/`.

| Layer | Source and version | Licence / obligation | How it is met |
|---|---|---|---|
| Map data | OpenStreetMap via the Protomaps Basemap build `20260926.pmtiles` (schema 4.15.2, OSM replication 2026-09-26 04:00 UTC), regional `pmtiles extract` of bbox 49.70,25.95,50.45,26.80, z0-15, 11,919,559 bytes, SHA-256 `1deb87ea…6a87` | ODbL 1.0; Protomaps tiles are a Produced Work ([Protomaps legal](https://protomaps.com/legal), [OSM copyright](https://www.openstreetmap.org/copyright)). Attribution required; the tiles are not a derivative database we publish separately. | Always-visible `© OpenStreetMap` link on the map and picker, in every connectivity state; details sheet names ODbL and Protomaps and shows `NOTICE.txt` offline. |
| Low-zoom context | Natural Earth (inside the Protomaps build) | Public domain | Named in `NOTICE.txt`. |
| Map style | `style-en.json`/`style-ar.json`, written for this app (`tool/maps/build_styles.py`) | Project code | No third-party style, sprite or glyph files. |
| Renderer | `flutter_map` 8.3.2 (BSD-3-Clause), `flutter_map_vector_tiles` 2.9.0 (BSD-3-Clause, © 2026 Jonas Grunau) | Keep notices | Named with links in `NOTICE.txt` (readable offline in the map details). Flutter registers package licence texts automatically, but the app has **no licences screen** yet: open item for the release checklist. |
| Label fonts | Platform default fonts (the renderer does not apply style font names): Android system fonts, Windows system fonts, and on the web the engine's Roboto (Apache 2.0) and Noto Sans Arabic (OFL) from `fonts.gstatic.com`, stored in browser Cache Storage when the user prepares the offline map | Standard engine behaviour; fonts are not redistributed in the app bundle | Recorded as a design deviation (labels do not use IBM Plex). |
| Tooling only | PMTiles Python reader (BSD-3-Clause) copied under `project/tool/maps/third_party/pmtiles/`; go-pmtiles 1.31.2 (BSD-3-Clause) used at build time, not shipped | Keep licence with the copy | `third_party/pmtiles/LICENSE`. |

**City outlines:** none. No licensed, dated municipal geometry for Al Khobar, Dhahran and Dammam was found; the app removed the unsourced polygons and the "municipal bounding coordinates" claim. City names choose a map view only. Accurate outlines remain an **open requirement** needing an owner-authorized data request (Balady/Eastern Province Municipality/GEOSA) with reuse permission.

**Still to confirm before release (counsel/owner):** final wording of the credit line against the OSMF attribution guidelines, and whether the ODbL notice in-app plus `NOTICE.txt` is sufficient for the store listing. No paid service, hosting or GPL tile-cache package is used.

---

# Map sources and licensing decision (2026-09-24, superseded above)

Status: P5.4 decision gate open. No offline tile archive or new tile package has been adopted. This record is for owner and counsel review before release.

## Current map

`SpatialMapScreen` requests Esri World Light Gray Base raster tiles while online and uses `tile.openstreetmap.org` as a network fallback. Its offline layer is a schematic polygon drawn from app model coordinates. The map now renders bilingual, wrapping source credit while the online layer is visible; tapping it opens the OSM copyright page. The credit names Esri, HERE, Garmin, OpenStreetMap contributors, and the GIS User Community as listed by [Esri's World Light Gray Base documentation](https://doc.arcgis.com/en/data-appliance/2022/maps/world-light-gray-base.htm). The English and Arabic strings keep all provider names. This static credit still needs a device check and a review against the live service's current credit metadata. It does not license tile caching or bulk retrieval.

The [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) prohibits offline prefetch and bulk download from `tile.openstreetmap.org`. It allows ordinary interactive viewing with cache headers respected and requires clear map attribution. No tile requests were made in this spike. Esri's [basemap attribution guidance](https://developers.arcgis.com/documentation/glossary/data-attribution/) also requires data source names in applications using its basemap services. Before retaining Esri for a release build, confirm the service's use terms, access method, and credits for this third-party client. The existing code's "zero-key" comment is not a terms determination.

The unused `project/gadm41_SAU_2.svg` was removed (71,134 bytes in the checkout before deletion). [GADM's license](https://gadm.org/license.html) does not permit redistribution or commercial use without prior permission. The file was not declared in `pubspec.yaml` or used by runtime Dart code. G5c was already 0 on this base commit; deletion removes the leftover source file.

## Candidate data

[Protomaps' basemap downloads](https://docs.protomaps.com/basemaps/downloads) offer PMTiles archives derived from OpenStreetMap, distributed as ODbL Produced Works with OSM attribution required. [Protomaps' legal page](https://protomaps.com/legal) gives interactive map attribution guidance. [OSM's copyright page](https://www.openstreetmap.org/copyright) states the database license and attribution duty. A country/province extract from that archive is a candidate source; a separate style must match the archive's schema. No archive, cutout, or hosted service was fetched here.

[Natural Earth terms](https://www.naturalearthdata.com/about/terms-of-use/) place its map data in the public domain and permit electronic redistribution and commercial use. It is a suitable source for a simplified, bundled, never-blank polygon layer, with source and version recorded when obtained. No Natural Earth geometry was imported in this spike.

`flutter_map_tile_caching` 9.1.4 supports `flutter_map` v7 according to its [changelog](https://pub.dev/packages/flutter_map_tile_caching/versions/9.1.4/changelog), but [pub.dev lists GPL-3.0](https://pub.dev/packages/flutter_map_tile_caching/versions/9.1.4). Do not add it to a proprietary release without owner/counsel approval of GPL obligations or a separate commercial license. If neither is acceptable, use a small app-owned browse-only cache or a differently licensed cache provider. Whichever cache is chosen must honor each tile provider's terms and HTTP cache headers; it must expose size and clear controls.

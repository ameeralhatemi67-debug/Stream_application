# Map sources and licensing decision (2026-09-24)

Status: P5.4 decision gate open. No offline tile archive or new tile package has been adopted. This record is for owner and counsel review before release.

## Current map

`SpatialMapScreen` requests Esri World Light Gray Base raster tiles while online and uses `tile.openstreetmap.org` as a network fallback. Its offline layer is a schematic polygon drawn from app model coordinates. The map now renders bilingual, wrapping source credit while the online layer is visible; tapping it opens the OSM copyright page. The credit names Esri, HERE, Garmin, OpenStreetMap contributors, and the GIS User Community as listed by [Esri's World Light Gray Base documentation](https://doc.arcgis.com/en/data-appliance/2022/maps/world-light-gray-base.htm). The English and Arabic strings keep all provider names. This static credit still needs a device check and a review against the live service's current credit metadata. It does not license tile caching or bulk retrieval.

The [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) prohibits offline prefetch and bulk download from `tile.openstreetmap.org`. It allows ordinary interactive viewing with cache headers respected and requires clear map attribution. No tile requests were made in this spike. Esri's [basemap attribution guidance](https://developers.arcgis.com/documentation/glossary/data-attribution/) also requires data source names in applications using its basemap services. Before retaining Esri for a release build, confirm the service's use terms, access method, and credits for this third-party client. The existing code's "zero-key" comment is not a terms determination.

The unused `project/gadm41_SAU_2.svg` was removed (71,134 bytes in the checkout before deletion). [GADM's license](https://gadm.org/license.html) does not permit redistribution or commercial use without prior permission. The file was not declared in `pubspec.yaml` or used by runtime Dart code. G5c was already 0 on this base commit; deletion removes the leftover source file.

## Candidate data

[Protomaps' basemap downloads](https://docs.protomaps.com/basemaps/downloads) offer PMTiles archives derived from OpenStreetMap, distributed as ODbL Produced Works with OSM attribution required. [Protomaps' legal page](https://protomaps.com/legal) gives interactive map attribution guidance. [OSM's copyright page](https://www.openstreetmap.org/copyright) states the database license and attribution duty. A country/province extract from that archive is a candidate source; a separate style must match the archive's schema. No archive, cutout, or hosted service was fetched here.

[Natural Earth terms](https://www.naturalearthdata.com/about/terms-of-use/) place its map data in the public domain and permit electronic redistribution and commercial use. It is a suitable source for a simplified, bundled, never-blank polygon layer, with source and version recorded when obtained. No Natural Earth geometry was imported in this spike.

`flutter_map_tile_caching` 9.1.4 supports `flutter_map` v7 according to its [changelog](https://pub.dev/packages/flutter_map_tile_caching/versions/9.1.4/changelog), but [pub.dev lists GPL-3.0](https://pub.dev/packages/flutter_map_tile_caching/versions/9.1.4). Do not add it to a proprietary release without owner/counsel approval of GPL obligations or a separate commercial license. If neither is acceptable, use a small app-owned browse-only cache or a differently licensed cache provider. Whichever cache is chosen must honor each tile provider's terms and HTTP cache headers; it must expose size and clear controls.

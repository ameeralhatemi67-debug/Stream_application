"""Write assets/maps/tricity/manifest.json from the files actually bundled.

The app verifies the pack and styles against this manifest before showing
the map (lib/features/map/services/map_pack_controller.dart), so the
manifest must be regenerated whenever any pack file changes.

Usage (from project/):  python tool/maps/build_manifest.py
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "third_party"))
from pmtiles.reader import MmapSource, Reader  # noqa: E402

PACK_DIR = Path(__file__).resolve().parents[2] / "assets" / "maps" / "tricity"

# Inputs pinned for this pack; see tool/maps/README.md.
SOURCE = {
    "provider": "Protomaps Basemap daily build",
    "build": "20260926.pmtiles",
    "build_url": "https://build.protomaps.com/20260926.pmtiles",
    "build_metadata_url": "https://build-metadata.protomaps.dev/builds.json",
    "build_version": "4.15.2",
    "build_planet_bytes": 138339871890,
    "build_planet_b3sum": "01bd88082fc61440dadded8c122e1c06be6d6afb0f542aebc099ca4cfb954c45",
    "extract_tool": "go-pmtiles 1.31.2 (commit a3e4951ea6a0477b784c27c1dcbfd9c130878c5a)",
    "extract_tool_zip_sha256": "a658baa4d7e55020aef6ca17bd9ff9faa1582671266b36f58c52db0ac8e785a1",
    "extract_command": "pmtiles extract https://build.protomaps.com/20260926.pmtiles "
                       "basemap.pmtiles --bbox=49.70,25.95,50.45,26.80 --maxzoom=15 "
                       "--download-threads=2",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    pack = PACK_DIR / "basemap.pmtiles"
    with open(pack, "rb") as f:
        reader = Reader(MmapSource(f))
        header = reader.header()
        meta = reader.metadata()
    files = {}
    for name in ("basemap.pmtiles", "style-en.json", "style-ar.json", "NOTICE.txt"):
        p = PACK_DIR / name
        files[name] = {"bytes": p.stat().st_size, "sha256": sha256(p)}
    pack_sha = files["basemap.pmtiles"]["sha256"]
    manifest = {
        "schema": 1,
        "pack_id": f"tricity-20260926-s1-{pack_sha[:12]}",
        "data_date": "2026-09-26",
        "osm_replication_time": meta.get("planetiler:osm:osmosisreplicationtime"),
        "tile_schema": f"protomaps-basemap-{meta.get('version')}",
        "native_zoom": [header["min_zoom"], header["max_zoom"]],
        "display_max_zoom": 18,
        "coverage_wsen": [49.70, 25.95, 50.45, 26.80],
        "navigation_wsen": [49.72, 25.97, 50.43, 26.78],
        "venue_domain_wsen": [49.72, 25.97, 50.33, 26.68],
        "overview_wsen": [49.97, 26.15, 50.24, 26.51],
        "coverage_note": "Product coverage settings for Al Khobar, Dhahran and "
                         "Dammam; not municipal boundaries. The navigation "
                         "extent reaches further east and north over the Gulf than the "
                         "venue domain so wide screens can frame the overview.",
        "files": files,
        "source": SOURCE,
        "attribution": {
            "short": "© OpenStreetMap",
            "url": "https://www.openstreetmap.org/copyright",
            "data_license": "ODbL 1.0",
            "archive_attribution": meta.get("attribution"),
        },
        "boundaries": None,
        "boundaries_note": "No licensed municipal geometry is bundled; city "
                           "outlines are deferred (acceptance A11).",
    }
    out = PACK_DIR / "manifest.json"
    out.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n",
                   encoding="utf-8", newline="\n")
    print("wrote", out, "pack", pack_sha)


if __name__ == "__main__":
    main()

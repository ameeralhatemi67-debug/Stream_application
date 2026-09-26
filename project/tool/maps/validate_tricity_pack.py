"""Validate the bundled three-city basemap pack locally.

Reads only the local archive (no network). Checks:
  1. header/metadata: PMTiles v3, gzip MVT, z0-15, bounds cover the pack envelope;
  2. completeness: every z0-15 tile slot intersecting the pack envelope is
     addressed and decodes as MVT (empty sea/desert tiles are classified, not
     treated as failures);
  3. control locations: each required district control point has a z15 tile
     with road features, and the tile's place/road names are reported;
  4. places inventory: named places (neighbourhoods/suburbs/towns) found in
     the archive, with coordinates, for the coverage review.

Usage (from project/):
  python tool/maps/validate_tricity_pack.py assets/maps/tricity/basemap.pmtiles \
      --out ../brief/evidence/<date>/p5-tricity-map-upgrade/pack-validation.json

Exit status 1 when any required check fails.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "third_party"))
from pmtiles.reader import MmapSource, Reader  # noqa: E402
from pmtiles.tile import Compression, TileType  # noqa: E402

# [west, south, east, north] -- product coverage settings, NOT city limits.
PACK_ENVELOPE = (49.70, 25.95, 50.45, 26.80)
MAX_ZOOM = 15

# Well-known, publicly identifiable control locations per required area.
# Coordinates are approximate landmark positions used only to pick the z15
# tile to decode; they are not boundary claims.
CONTROL_LOCATIONS = [
    ("al_khobar", "Al Khobar corniche", 26.2890, 50.2170),
    ("al_khobar", "Al Khobar Al Aqrabiyah", 26.2930, 50.1960),
    ("al_khobar", "Al Khobar Al Rakah", 26.3570, 50.1970),
    ("al_khobar", "Al Khobar Al Aziziyah (south)", 26.1850, 50.1950),
    ("al_khobar", "King Fahd Causeway approach", 26.1780, 50.2250),
    ("dhahran", "KFUPM campus", 26.3070, 50.1440),
    ("dhahran", "Dhahran (Aramco residential)", 26.2870, 50.1150),
    ("dhahran", "Ithra / King Abdulaziz Center", 26.3350, 50.1210),
    ("dhahran", "Dhahran Mall area", 26.3040, 50.1660),
    ("dammam", "Dammam corniche", 26.4450, 50.1130),
    ("dammam", "Dammam Al Faisaliyah", 26.4150, 50.0450),
    ("dammam", "Dammam city centre (Al Adamah)", 26.4280, 50.0950),
    ("dammam", "Dammam north (Al Shatea)", 26.4780, 50.1250),
    ("dammam", "Dammam south-west (2nd Industrial City)", 26.2600, 49.9700),
    ("dammam", "King Fahd International Airport", 26.4710, 49.7980),
]


def varint(data: bytes, pos: int) -> tuple[int, int]:
    value, shift = 0, 0
    while True:
        byte = data[pos]
        pos += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, pos
        shift += 7
        if shift >= 70:
            raise ValueError("varint too long")


def fields(data: bytes):
    pos = 0
    while pos < len(data):
        tag, pos = varint(data, pos)
        wire = tag & 7
        if wire == 0:
            value, pos = varint(data, pos)
        elif wire in (1, 5):
            n = 8 if wire == 1 else 4
            value, pos = data[pos:pos + n], pos + n
        elif wire == 2:
            n, pos = varint(data, pos)
            value, pos = data[pos:pos + n], pos + n
        else:
            raise ValueError(f"unsupported wire type {wire}")
        yield tag >> 3, value


def packed(data: bytes) -> list[int]:
    out, pos = [], 0
    while pos < len(data):
        v, pos = varint(data, pos)
        out.append(v)
    return out


def zigzag(n: int) -> int:
    return (n >> 1) ^ -(n & 1)


def decode_mvt(data: bytes) -> dict[str, list[dict]]:
    """Returns {layer: [ {props, first_point(extent coords), geom_type} ]}."""
    layers: dict[str, list[dict]] = {}
    for tag, layer in fields(data):
        if tag != 3:
            continue
        name, keys, values, extent, raw_features = None, [], [], 4096, []
        for k, v in fields(layer):
            if k == 1:
                name = v.decode()
            elif k == 3:
                keys.append(v.decode())
            elif k == 4:
                val = None
                for t, s in fields(v):
                    if t == 1:
                        val = s.decode()
                    elif t in (4, 5, 6):
                        val = s
                    elif t == 7:
                        val = bool(s)
                values.append(val)
            elif k == 5:
                extent = v
            elif k == 2:
                raw_features.append(v)
        feats = []
        for raw in raw_features:
            props, geom_type, first = {}, 0, None
            for t, v in fields(raw):
                if t == 2:
                    idx = packed(v)
                    for i in range(0, len(idx) - 1, 2):
                        props[keys[idx[i]]] = values[idx[i + 1]]
                elif t == 3:
                    geom_type = v
                elif t == 4:
                    g = packed(v)
                    if len(g) >= 3 and (g[0] & 7) == 1:
                        first = (zigzag(g[1]), zigzag(g[2]))
            feats.append({"props": props, "type": geom_type, "first": first, "extent": extent})
        layers[name] = feats
    return layers


def lonlat_to_tile(lon: float, lat: float, z: int) -> tuple[int, int]:
    n = 2 ** z
    x = int((lon + 180.0) / 360.0 * n)
    lat_r = math.radians(lat)
    y = int((1.0 - math.asinh(math.tan(lat_r)) / math.pi) / 2.0 * n)
    return min(max(x, 0), n - 1), min(max(y, 0), n - 1)


def tile_point_to_lonlat(z: int, x: int, y: int, px: float, py: float, extent: int):
    n = 2 ** z
    fx = (x + px / extent) / n
    fy = (y + py / extent) / n
    lon = fx * 360.0 - 180.0
    lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * fy))))
    return lon, lat


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("archive")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    path = Path(args.archive)
    raw = path.read_bytes()
    failures: list[str] = []
    report: dict = {
        "archive": str(path).replace("\\", "/"),
        "bytes": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "pack_envelope_wsen": PACK_ENVELOPE,
    }

    with open(path, "rb") as f:
        reader = Reader(MmapSource(f))
        header = reader.header()
        meta = reader.metadata()
        report["header"] = {
            "tile_type": str(header["tile_type"]),
            "tile_compression": str(header["tile_compression"]),
            "min_zoom": header["min_zoom"],
            "max_zoom": header["max_zoom"],
            "bounds_wsen": [header["min_lon_e7"] / 1e7, header["min_lat_e7"] / 1e7,
                            header["max_lon_e7"] / 1e7, header["max_lat_e7"] / 1e7],
            "addressed_tiles_count": header["addressed_tiles_count"],
            "tile_entries_count": header["tile_entries_count"],
            "tile_contents_count": header["tile_contents_count"],
        }
        report["metadata"] = {k: v for k, v in meta.items() if k != "vector_layers"}
        report["vector_layers"] = [l["id"] for l in meta.get("vector_layers", [])]
        if header["tile_type"] != TileType.MVT:
            failures.append("tile type is not MVT")
        if header["tile_compression"] != Compression.GZIP:
            failures.append("tile compression is not gzip")
        if header["min_zoom"] != 0 or header["max_zoom"] != MAX_ZOOM:
            failures.append("zoom range is not 0-15")
        b = report["header"]["bounds_wsen"]
        if not (b[0] <= PACK_ENVELOPE[0] + 1e-6 and b[1] <= PACK_ENVELOPE[1] + 1e-6
                and b[2] >= PACK_ENVELOPE[2] - 1e-6 and b[3] >= PACK_ENVELOPE[3] - 1e-6):
            failures.append(f"archive bounds {b} do not cover the pack envelope")

        # 2. completeness sweep
        per_zoom = {}
        places: dict[tuple, dict] = {}
        decode_errors, missing = [], []
        w, s, e, n = PACK_ENVELOPE
        for z in range(0, MAX_ZOOM + 1):
            x0, y0 = lonlat_to_tile(w, n, z)
            x1, y1 = lonlat_to_tile(e, s, z)
            stats = {"slots": 0, "addressed": 0, "with_roads": 0, "with_buildings": 0,
                     "empty_or_sea_only": 0, "bytes": 0}
            for x in range(x0, x1 + 1):
                for y in range(y0, y1 + 1):
                    stats["slots"] += 1
                    blob = reader.get(z, x, y)
                    if blob is None:
                        missing.append([z, x, y])
                        continue
                    stats["addressed"] += 1
                    stats["bytes"] += len(blob)
                    try:
                        layers = decode_mvt(gzip.decompress(blob))
                    except Exception as exc:  # noqa: BLE001
                        decode_errors.append([z, x, y, str(exc)])
                        continue
                    if layers.get("roads"):
                        stats["with_roads"] += 1
                    if layers.get("buildings"):
                        stats["with_buildings"] += 1
                    if not layers.get("roads") and not layers.get("buildings") \
                            and not layers.get("places"):
                        stats["empty_or_sea_only"] += 1
                    if z == 13:
                        for feat in layers.get("places", []):
                            p = feat["props"]
                            if not p.get("name") or feat["first"] is None:
                                continue
                            lon, lat = tile_point_to_lonlat(z, x, y, *feat["first"], feat["extent"])
                            key = (p.get("name"), round(lon, 3), round(lat, 3))
                            places[key] = {"name": p.get("name"), "name:en": p.get("name:en"),
                                           "name:ar": p.get("name:ar"), "kind": p.get("kind"),
                                           "kind_detail": p.get("kind_detail"),
                                           "lon": round(lon, 4), "lat": round(lat, 4)}
            per_zoom[z] = stats
        report["per_zoom"] = per_zoom
        report["missing_slots"] = missing
        report["decode_errors"] = decode_errors
        if missing:
            failures.append(f"{len(missing)} tile slots missing from the envelope")
        if decode_errors:
            failures.append(f"{len(decode_errors)} tiles failed to decode")

        # 3. control locations
        controls = []
        for area, label, lat, lon in CONTROL_LOCATIONS:
            x, y = lonlat_to_tile(lon, lat, MAX_ZOOM)
            blob = reader.get(MAX_ZOOM, x, y)
            entry = {"area": area, "label": label, "lat": lat, "lon": lon,
                     "tile": [MAX_ZOOM, x, y]}
            if blob is None:
                entry["result"] = "missing"
                failures.append(f"control {label}: tile missing")
            else:
                layers = decode_mvt(gzip.decompress(blob))
                roads = layers.get("roads", [])
                named = sorted({r["props"].get("name") for r in roads if r["props"].get("name")})
                entry.update({
                    "road_features": len(roads),
                    "named_roads": len(named),
                    "road_names_sample": named[:6],
                    "roads_with_name_ar": sum(1 for r in roads if r["props"].get("name:ar")),
                    "roads_with_name_en": sum(1 for r in roads if r["props"].get("name:en")),
                    "buildings": len(layers.get("buildings", [])),
                    "pois": len(layers.get("pois", [])),
                    "result": "pass" if roads else "fail",
                })
                if not roads:
                    failures.append(f"control {label}: no road features")
            controls.append(entry)
        report["control_locations"] = controls
        report["places_z13"] = sorted(places.values(), key=lambda p: (-p["lat"], p["lon"]))

    report["failures"] = failures
    report["result"] = "PASS" if not failures else "FAIL"
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    total_slots = sum(v["slots"] for v in per_zoom.values())
    print(f"{report['result']}: {total_slots} slots, {len(missing)} missing, "
          f"{len(decode_errors)} decode errors, {len(controls)} controls, "
          f"{len(report['places_z13'])} named places; sha256 {report['sha256']}")
    for msg in failures:
        print("  FAIL", msg)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())

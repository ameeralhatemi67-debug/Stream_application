"""Generate the bundled tri-city map styles (English and Arabic).

The styles target the Protomaps basemap v4 schema actually present in
assets/maps/tricity/basemap.pmtiles (layers: earth, water, landuse,
landcover, roads, buildings, places, pois). They are deliberately small and
local-only:

  * the single vector source is served in-app from the bundled archive; the
    style names no tile, glyph or sprite URL, so nothing can be fetched;
  * labels use plain `coalesce` name fallbacks (`name:<lang>` then `name`),
    never machine translation and never the MapLibre `format` expression;
  * no icon images (no sprite sheet is bundled or required);
  * the `boundaries` layer is not drawn: its OSM administrative lines are
    not verified municipal limits (see brief/research/p5-tricity-map-upgrade).

Colours are a cartographic palette derived from the app's Scheme A tokens
(lib/core/theme/app_theme.dart): textPrimary/textSecondary label ink, white
halos, green parks echoing `primary`. Zoom values follow the MapLibre 512 px
convention (display zoom - 1), which flutter_map_vector_tiles'
`TileOffset.maplibre` applies.

Text sizes are always a number or an `interpolate` over `zoom` with literal
outputs, so the app can scale them for the user's text size
(see lib/features/map/services/map_style_loader.dart).

Usage (from project/):  python tool/maps/build_styles.py
"""
from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets" / "maps" / "tricity"

INK = "#202B2B"          # AppTheme.textPrimary
INK_2 = "#485554"        # AppTheme.textSecondary
INK_3 = "#586563"        # AppTheme.textMuted
HALO = "#FFFFFF"
LAND = "#F2F4F1"
WATER = "#C6DEE7"
WATER_INK = "#3F6F80"
PARK = "#D9EDDC"
BUILDING = "#E4E1DB"
BUILDING_LINE = "#D2CDC5"
MINOR = "#FFFFFF"
MINOR_CASE = "#D3D7D3"
MAJOR = "#FFFFFF"
MAJOR_CASE = "#AEB6B3"
HIGHWAY = "#F4D58A"
HIGHWAY_CASE = "#C9A04A"
PATH = "#CFC8B8"
RAIL = "#AAB1AF"
SOURCE = "protomaps"


def interp(*stops, base=None):
    kind = ["linear"] if base is None else ["exponential", base]
    expr = ["interpolate", kind, ["zoom"]]
    for z, v in stops:
        expr += [z, v]
    return expr


def fill(layer_id, source_layer, color, flt=None, minzoom=None, opacity=None):
    layer = {"id": layer_id, "type": "fill", "source": SOURCE,
             "source-layer": source_layer, "paint": {"fill-color": color}}
    if flt is not None:
        layer["filter"] = flt
    if minzoom is not None:
        layer["minzoom"] = minzoom
    if opacity is not None:
        layer["paint"]["fill-opacity"] = opacity
    return layer


def line(layer_id, flt, color, width, minzoom=None, dash=None, cap="round"):
    layer = {"id": layer_id, "type": "line", "source": SOURCE,
             "source-layer": "roads", "filter": flt,
             "layout": {"line-cap": cap, "line-join": "round"},
             "paint": {"line-color": color, "line-width": width}}
    if minzoom is not None:
        layer["minzoom"] = minzoom
    if dash is not None:
        layer["paint"]["line-dasharray"] = dash
    return layer


def kind_in(*kinds):
    return ["match", ["get", "kind"], list(kinds), True, False]


def detail_in(*details):
    return ["match", ["get", "kind_detail"], list(details), True, False]


def name_expr(lang: str):
    return ["coalesce", ["get", f"name:{lang}"], ["get", "name"]]


def label(layer_id, source_layer, lang, size, color, flt=None, minzoom=None,
          maxzoom=None, bold=False, placement="point", halo=1.6,
          max_width=8, sort_key=None):
    layout = {
        "text-field": name_expr(lang),
        "text-font": ["Noto Sans Bold" if bold else "Noto Sans Regular"],
        "text-size": size,
        "text-max-width": max_width,
    }
    if placement == "line":
        layout.update({"symbol-placement": "line", "symbol-spacing": 260,
                       "text-max-angle": 30})
    if sort_key is not None:
        layout["symbol-sort-key"] = sort_key
    layer = {"id": layer_id, "type": "symbol", "source": SOURCE,
             "source-layer": source_layer, "layout": layout,
             "paint": {"text-color": color, "text-halo-color": HALO,
                       "text-halo-width": halo}}
    if flt is not None:
        layer["filter"] = flt
    if minzoom is not None:
        layer["minzoom"] = minzoom
    if maxzoom is not None:
        layer["maxzoom"] = maxzoom
    return layer


def build(lang: str) -> dict:
    major = ["all", ["==", ["get", "kind"], "major_road"]]
    highway = ["==", ["get", "kind"], "highway"]
    minor = ["==", ["get", "kind"], "minor_road"]
    path = ["==", ["get", "kind"], "path"]
    rail = ["==", ["get", "kind"], "rail"]
    runway = ["all", ["==", ["get", "kind"], "aeroway"],
              detail_in("runway", "taxiway")]

    w_highway = interp((6, 0.8), (10, 2.2), (14, 7), (18, 26), base=1.6)
    w_major = interp((7, 0.5), (10, 1.2), (14, 5), (18, 20), base=1.6)
    w_minor = interp((12, 0.5), (14, 2.2), (18, 12), base=1.6)

    def case(w):
        # Casing: the same zoom curve, a fixed 1.6 px wider (top-level
        # interpolate keeps the expression MapLibre-valid).
        out = list(w[:3])
        for i in range(3, len(w), 2):
            out += [w[i], round(w[i + 1] + 1.6, 3)]
        return out

    layers = [
        {"id": "background", "type": "background",
         "paint": {"background-color": WATER}},
        fill("earth", "earth", LAND),
        fill("landcover", "landcover", PARK, opacity=0.5),
        fill("landuse-park", "landuse", PARK,
             kind_in("park", "grass", "garden", "recreation_ground",
                     "nature_reserve", "forest", "golf_course", "pitch",
                     "cemetery")),
        fill("landuse-education", "landuse", "#F1EDDC",
             kind_in("school", "university", "college", "kindergarten")),
        fill("landuse-hospital", "landuse", "#F5E4E6", kind_in("hospital")),
        fill("landuse-industrial", "landuse", "#E9EAEC",
             kind_in("industrial", "commercial", "railway", "military",
                     "naval_base")),
        fill("landuse-airport", "landuse", "#E6EAEA",
             kind_in("aerodrome", "airfield")),
        fill("landuse-sand", "landuse", "#F2ECD8", kind_in("sand", "beach")),
        fill("water", "water", WATER),
        line("roads-runway", runway, "#D6DAD9",
             interp((10, 1), (14, 8), (18, 40), base=1.6), minzoom=10,
             cap="butt"),
        fill("buildings", "buildings", BUILDING, minzoom=13),
        {"id": "buildings-outline", "type": "line", "source": SOURCE,
         "source-layer": "buildings", "minzoom": 14,
         "paint": {"line-color": BUILDING_LINE, "line-width": 0.6}},
        line("roads-path", path, PATH,
             interp((14, 0.8), (18, 2.5)), minzoom=14, dash=[2, 1]),
        line("roads-rail", rail, RAIL,
             interp((10, 0.6), (16, 2)), minzoom=10, dash=[3, 2]),
        line("roads-minor-casing", minor, MINOR_CASE, case(w_minor),
             minzoom=12),
        line("roads-major-casing", major, MAJOR_CASE, case(w_major),
             minzoom=7),
        line("roads-highway-casing", highway, HIGHWAY_CASE, case(w_highway),
             minzoom=5),
        line("roads-minor", minor, MINOR, w_minor, minzoom=12),
        line("roads-major", major, MAJOR, w_major, minzoom=7),
        line("roads-highway", highway, HIGHWAY, w_highway, minzoom=5),
        # Labels, drawn in this order; the renderer's collision pass keeps
        # the earlier (more important) label where two overlap.
        label("places-city", "places", lang,
              interp((8, 14), (12, 18), (15, 20)), INK,
              ["all", ["==", ["get", "kind"], "locality"],
               detail_in("city")],
              minzoom=7, bold=True, halo=2.2),
        label("places-town", "places", lang,
              interp((9, 12.5), (14, 15)), INK,
              ["all", ["==", ["get", "kind"], "locality"],
               detail_in("town", "village")],
              minzoom=9, bold=True, halo=2.0),
        label("water-label", "water", lang,
              interp((8, 12), (14, 14)), WATER_INK,
              kind_in("ocean", "sea", "bay"), minzoom=8, halo=1.4),
        label("roads-label-major", "roads", lang,
              interp((12, 12), (16, 14.5)), INK,
              ["any", highway, major], minzoom=12, placement="line",
              halo=2.0),
        label("places-neighbourhood", "places", lang,
              interp((12, 12), (16, 14)), INK_2,
              kind_in("neighbourhood", "macrohood"), minzoom=12,
              halo=2.0, max_width=7),
        label("roads-label-minor", "roads", lang,
              interp((14, 12), (18, 13.5)), INK_2, minor, minzoom=14,
              placement="line", halo=2.0),
        label("pois-label", "pois", lang, interp((14, 12), (18, 13)), INK_3,
              kind_in("university", "college", "hospital", "mall", "stadium",
                      "park", "library", "museum", "school", "hotel",
                      "sports_centre", "place_of_worship"),
              minzoom=14, halo=2.0, max_width=7),
    ]
    return {
        "version": 8,
        "name": f"Streamer tri-city ({lang})",
        "metadata": {
            "streamer:schema": "protomaps-basemap-v4",
            "streamer:generator": "project/tool/maps/build_styles.py",
            "streamer:license": "Style: this project. Map data: OpenStreetMap "
                                "contributors (ODbL) via Protomaps basemap.",
        },
        "sources": {
            SOURCE: {
                "type": "vector",
                "attribution": "<a href=\"https://www.openstreetmap.org/copyright\">"
                               "&copy; OpenStreetMap</a>",
                "minzoom": 0,
                "maxzoom": 15,
            }
        },
        "layers": layers,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for lang in ("en", "ar"):
        path = OUT / f"style-{lang}.json"
        path.write_text(json.dumps(build(lang), ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8", newline="\n")
        print("wrote", path)


if __name__ == "__main__":
    main()

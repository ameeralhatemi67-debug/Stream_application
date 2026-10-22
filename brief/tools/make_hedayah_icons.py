"""Draws the Hedayah skin's icon set (ADR-016).

One SVG per CaGlyph name in project/assets/hedayah/icons/, so CaIcon can swap
sets by skin. The website draws thin line icons on a 50-unit grid; these keep
that weight on the app's 24-unit grid (1.5 line, round ends) and borrow the
details of the owner's pattern motif: rings at stroke ends, the diamond eye,
the pointed arch and the eight-point star. CaIcon tints every pixel with one
colour, so two-tone marks (verified) cut their detail out of the fill.

Run from the repo root:
    python brief/tools/make_hedayah_icons.py [--sheet out.html]
"""

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "project/assets/hedayah/icons"


def ring(cx, cy, r=1.15):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}"/>'


def diamond(cx, cy, s):
    return f'<path d="M{cx} {cy - s} {cx + s} {cy} {cx} {cy + s} {cx - s} {cy}z"/>'


def solid_diamond(cx, cy, s):
    return (f'<path fill="currentColor" stroke="none" '
            f'd="M{cx} {cy - s} {cx + s} {cy} {cx} {cy + s} {cx - s} {cy}z"/>')


def octagram_points(cx, cy, r):
    """The eight-point star of two squares, as its 16-point outline."""
    a = r / math.sqrt(2)
    k = a * (math.sqrt(2) - 1)
    pts = [(0, -r), (k, -a), (a, -a), (a, -k), (r, 0), (a, k), (a, a), (k, a),
           (0, r), (-k, a), (-a, a), (-a, k), (-r, 0), (-a, -k), (-a, -a), (-k, -a)]
    return [(round(cx + x, 3), round(cy + y, 3)) for x, y in pts]


def octagram(cx, cy, r):
    pts = octagram_points(cx, cy, r)
    return "M" + " ".join(f"{x} {y}" for x, y in pts) + "z"


def slash():
    return '<path d="M4 4l16 16"/>'


ICONS = {
    # Interface
    "translate": (
        '<rect x="2.75" y="3.75" width="11" height="11" rx="2.5"/>'
        '<path d="M5.75 11.75 8.25 6.5l2.5 5.25M6.6 10h3.3"/>'
        '<path d="M16.75 9.25h2a2.5 2.5 0 0 1 2.5 2.5v6.5a2.5 2.5 0 0 1-2.5 2.5h-6.5'
        'a2.5 2.5 0 0 1-2.5-2.5v-1.5"/>'
        '<path d="M13.25 17.75c2 0 3.75-1 4.25-3"/>' + ring(16.4, 12.9, .55)
    ),
    "bell": (
        '<path d="M6.5 16.75V11a5.5 5.5 0 0 1 11 0v5.75l1.75 1.75H4.75z"/>'
        + ring(12, 3.9) + '<path d="M10 21a2 2 0 0 0 4 0"/>'
    ),
    "search": '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.25 15.25 19 19"/>' + ring(19.9, 19.9),
    "sliders": (
        '<path d="M3.5 7.5h8.75M17.75 7.5h2.75M3.5 16.5h2.75M11.75 16.5h8.75"/>'
        + diamond(15, 7.5, 2.75) + diamond(9, 16.5, 2.75)
    ),
    "bookmark": (
        '<path d="M6.25 20.75V9c0-2.6 2.6-4.75 5.75-5.75 3.15 1 5.75 3.15 5.75 5.75v11.75'
        'L12 16.75z"/>' + solid_diamond(12, 9.75, 1.6)
    ),
    "user": '<circle cx="12" cy="7.75" r="3.75"/><path d="M4.5 20.25c.4-4 3.6-6.75 7.5-6.75s7.1 2.75 7.5 6.75"/>',
    "gear": f'<path d="{octagram(12, 12, 9.25)}"/><circle cx="12" cy="12" r="3"/>',
    "menu": '<path d="M4 6.5h16M4 12h16M4 17.5h10.5"/>' + solid_diamond(18.5, 17.5, 1.6),
    "back": '<path d="M14.5 5.5 8 12l6.5 6.5"/>',
    "close": '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    "check": '<path d="M4.75 12.5 9.25 17 19.25 6.75"/>',
    # Filled eight-point star with the check cut out of it (one colour).
    "verified": None,
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "edit": (
        '<path d="M4.5 19.5v-3.25L15.6 5.15a2 2 0 0 1 2.85 0l.4.4a2 2 0 0 1 0 2.85'
        'L7.75 19.5z"/><path d="M13.75 7 17 10.25M13 19.5h6.5"/>'
    ),
    "trash": (
        '<path d="M4.5 6.5h15M9.5 6.5V4.75h5V6.5M6.5 6.5l.9 12.6a2 2 0 0 0 2 1.9h5.2'
        'a2 2 0 0 0 2-1.9l.9-12.6M10 10.5v6M14 10.5v6"/>'
    ),
    "refresh": (
        '<path d="M19.5 12a7.5 7.5 0 0 1-13.25 4.8M4.5 12a7.5 7.5 0 0 1 13.25-4.8"/>'
        '<path d="M18 3.75v3.5h-3.5M6 20.25v-3.5h3.5"/>'
    ),
    "download": '<path d="M12 3.5V15M7.5 10.5 12 15l4.5-4.5M4.5 16v2a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2v-2"/>',
    "share": (
        '<circle cx="17.75" cy="5.5" r="2.5"/><circle cx="6.25" cy="12" r="2.5"/>'
        '<circle cx="17.75" cy="18.5" r="2.5"/><path d="M8.45 10.75 15.55 6.75M8.45 13.25l7.1 4"/>'
    ),
    "copy": (
        '<rect x="8.5" y="8.5" width="11.25" height="11.25" rx="2.5"/>'
        '<path d="M15.5 8.5v-2a2.25 2.25 0 0 0-2.25-2.25h-6.75A2.25 2.25 0 0 0 4.25 6.5v6.75'
        'a2.25 2.25 0 0 0 2.25 2.25h2"/>'
    ),
    "external": (
        '<path d="M13.5 4.5h6v6M19.5 4.5l-8.25 8.25"/>'
        '<path d="M17.5 14v3.5a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2H10"/>'
    ),
    # Two links drawn as the rosette's rounded loops.
    "link": (
        '<path d="M10 14l4-4"/>'
        '<path d="M9.25 7.25l1.4-1.4a4 4 0 0 1 5.65 0l1.85 1.85a4 4 0 0 1 0 5.65l-1.4 1.4"/>'
        '<path d="M14.75 16.75l-1.4 1.4a4 4 0 0 1-5.65 0L5.85 16.3a4 4 0 0 1 0-5.65l1.4-1.4"/>'
    ),
    "key": '<circle cx="8" cy="15.75" r="4.25"/><path d="M11.1 12.65 19.5 4.25M16.25 7.5l2.5 2.5M13.75 10l1.75 1.75"/>' + solid_diamond(8, 15.75, 1.2),
    "lock": (
        '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/>'
        '<path d="M8 10.5V8.25c0-2.6 1.8-4.4 4-5 2.2.6 4 2.4 4 5v2.25"/>' + solid_diamond(12, 15.5, 1.6)
    ),
    "shield": (
        '<path d="M12 3 4.75 6v5.25c0 4.6 3.1 8.4 7.25 9.75 4.15-1.35 7.25-5.15 7.25-9.75V6z"/>'
        + diamond(12, 11.75, 2.5)
    ),
    # The motif's diamond eye.
    "eye": (
        '<path d="M2.75 12S6.25 5.5 12 5.5 21.25 12 21.25 12 17.75 18.5 12 18.5 2.75 12 2.75 12z"/>'
        + diamond(12, 12, 2.75)
    ),
    "eyeoff": (
        '<path d="M2.75 12S6.25 5.5 12 5.5 21.25 12 21.25 12 17.75 18.5 12 18.5 2.75 12 2.75 12z"/>'
        + diamond(12, 12, 2.75) + slash()
    ),
    # Media
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M9 21h6"/>',
    "micoff": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M9 21h6"/>' + slash(),
    "video": '<rect x="2.75" y="6" width="12.5" height="12" rx="2.5"/><path d="M15.25 10.25 21.25 7v10l-6-3.25"/>' + ring(6.5, 9.75, .9),
    "videooff": '<rect x="2.75" y="6" width="12.5" height="12" rx="2.5"/><path d="M15.25 10.25 21.25 7v10l-6-3.25"/>' + slash(),
    "flip": (
        '<path d="M4.75 8h2.5l1.75-2.5h6l1.75 2.5h2.5a1.75 1.75 0 0 1 1.75 1.75v8.5'
        'a1.75 1.75 0 0 1-1.75 1.75H4.75A1.75 1.75 0 0 1 3 18.25v-8.5A1.75 1.75 0 0 1 4.75 8z"/>'
        '<path d="M9 13.25a3 3 0 0 1 5.4-1.8M15 13.75a3 3 0 0 1-5.4 1.8"/>'
        '<path d="M14.75 9.75v1.9h-1.9M9.25 17.25v-1.9h1.9"/>'
    ),
    "volume": '<path d="M4 9.5h3l4.5-4v13L7 14.5H4z"/><path d="M15 9a4.2 4.2 0 0 1 0 6M17.75 6.25a8 8 0 0 1 0 11.5"/>',
    "play": '<path d="M7.5 5.15v13.7a1.1 1.1 0 0 0 1.68.93l10.8-6.85a1.1 1.1 0 0 0 0-1.86L9.18 4.22A1.1 1.1 0 0 0 7.5 5.15z"/>',
    "pause": '<rect x="6" y="4.75" width="4" height="14.5" rx="1.5"/><rect x="14" y="4.75" width="4" height="14.5" rx="1.5"/>',
    "fullscreen": (
        '<path d="M4 9V5.5A1.5 1.5 0 0 1 5.5 4H9M15 4h3.5A1.5 1.5 0 0 1 20 5.5V9'
        'M20 15v3.5a1.5 1.5 0 0 1-1.5 1.5H15M9 20H5.5A1.5 1.5 0 0 1 4 18.5V15"/>'
    ),
    # People and conversation
    "heart": '<path d="M12 20s-7.75-4.6-7.75-10.1A4.4 4.4 0 0 1 12 7.1a4.4 4.4 0 0 1 7.75 2.8C19.75 15.4 12 20 12 20z"/>',
    "send": '<path d="M3.25 11 20.75 3.25 13 20.75l-2.75-7.5z"/><path d="M10.25 13.25 20.75 3.25"/>',
    "chat": (
        '<path d="M4 6a2.75 2.75 0 0 1 2.75-2.75h10.5A2.75 2.75 0 0 1 20 6v8.25'
        'A2.75 2.75 0 0 1 17.25 17h-7l-4.5 3.75V17h-.5A1.25 1.25 0 0 1 4 15.75z"/>'
        + solid_diamond(8.5, 10.1, 1) + solid_diamond(12, 10.1, 1) + solid_diamond(15.5, 10.1, 1)
    ),
    "users": (
        '<circle cx="9" cy="8" r="3.25"/><path d="M3.25 19.75c.4-3.4 2.85-5.75 5.75-5.75s5.35 2.35 5.75 5.75"/>'
        '<path d="M15.25 4.85a3.25 3.25 0 0 1 0 6.3M17.25 14.25c1.9.8 3.1 2.75 3.4 5.5"/>'
    ),
    # Time and place
    "cal": (
        '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>'
        + diamond(12, 15.25, 2.25)
    ),
    "clock": '<circle cx="12" cy="12" r="8.75"/><path d="M12 7.25V12l3.25 2"/>',
    "pin": (
        '<path d="M12 21.25s-6.75-5.75-6.75-11.25a6.75 6.75 0 0 1 13.5 0c0 5.5-6.75 11.25-6.75 11.25z"/>'
        + diamond(12, 10, 2.4)
    ),
    "map": '<path d="M9 4.5 3.5 6.5v13l5.5-2 6 2 5.5-2v-13l-5.5 2z"/><path d="M9 4.5v13M15 6.5v13"/>',
    # The needle is the motif's diamond, its north half filled.
    "compass": (
        '<circle cx="12" cy="12" r="8.75"/><path d="M12 6.25 14.4 12 12 17.75 9.6 12z"/>'
        '<path fill="currentColor" stroke="none" d="M12 6.25 14.4 12H9.6z"/>'
    ),
    # Discover: a list with diamond bullets.
    "list": (
        '<path d="M10 6.5h10.5M10 12h10.5M10 17.5h10.5"/>'
        + solid_diamond(5.25, 6.5, 1.75) + solid_diamond(5.25, 12, 1.75) + solid_diamond(5.25, 17.5, 1.75)
    ),
    "info": '<circle cx="12" cy="12" r="8.75"/><path d="M12 11v5.5M12 7.75h.01"/>',
    "alert": (
        '<path d="M10.3 4.4 3.05 17.1a1.95 1.95 0 0 0 1.7 2.9h14.5a1.95 1.95 0 0 0 1.7-2.9L13.7 4.4'
        'a1.95 1.95 0 0 0-3.4 0z"/><path d="M12 9.5v4M12 16.75h.01"/>'
    ),
    "bars": '<path d="M5 19.5v-5M10 19.5v-9M15 19.5V7M20 19.5V4.5"/>',
    "wifi": (
        '<path d="M2.75 9a13 13 0 0 1 18.5 0M5.75 12.25a8.75 8.75 0 0 1 12.5 0M8.75 15.5a4.5 4.5 0 0 1 6.5 0"/>'
        + ring(12, 19)
    ),
    "dots": solid_diamond(12, 5, 1.6) + solid_diamond(12, 12, 1.6) + solid_diamond(12, 19, 1.6),
    "arrow": '<path d="M7 17 17 7M8.5 7H17v8.5"/>',
    "logout": '<path d="M9.5 4H6.25A2.25 2.25 0 0 0 4 6.25v11.5A2.25 2.25 0 0 0 6.25 20H9.5M15.5 8l4 4-4 4M19.5 12H9.5"/>',
    "globe": (
        '<circle cx="12" cy="12" r="8.75"/><path d="M3.25 12h17.5"/>'
        '<path d="M12 3.25c2.4 2.4 3.6 5.3 3.6 8.75s-1.2 6.35-3.6 8.75'
        'C9.6 18.35 8.4 15.45 8.4 12S9.6 5.65 12 3.25z"/>'
    ),
    "scale": (
        '<path d="M12 5.25V20M7.5 20h9M4.75 7.5h14.5"/>' + ring(12, 4)
        + '<path d="M4.75 7.5 2.5 13a2.6 2.6 0 0 0 4.5 0zM19.25 7.5 17 13a2.6 2.6 0 0 0 4.5 0z"/>'
    ),
    # A house with the pointed-arch door.
    "home": (
        '<path d="M3.5 10.5 12 3.5l8.5 7V19a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19z"/>'
        '<path d="M9.5 20.5V16c0-1.5 1.1-2.6 2.5-3.5 1.4.9 2.5 2 2.5 3.5v4.5"/>'
    ),
}


def verified():
    star = octagram(12, 12, 10.25)
    # The check as a 1.9-wide polygon (mitred at the turn), cut out of the star.
    check = "M7.63 12.97 10.92 16.26 16.59 10.25 15.21 8.95 10.88 13.54 8.97 11.63z"
    return f'<path fill="currentColor" stroke="none" fill-rule="evenodd" d="{star}{check}"/>'


ICONS["verified"] = verified()

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, body in ICONS.items():
        (OUT / f"{name}.svg").write_text(HEAD + body + "</svg>\n", encoding="utf-8")
    print(f"{len(ICONS)} icons -> {OUT.relative_to(ROOT)}")
    if "--sheet" in sys.argv:
        sheet = Path(sys.argv[sys.argv.index("--sheet") + 1])
        canopy = ROOT / "project/assets/canopy/icons"
        cells = []
        for name, body in ICONS.items():
            old = (canopy / f"{name}.svg").read_text(encoding="utf-8")
            old = old.replace("<svg ", '<svg width="32" height="32" style="color:#805B1B" ', 1)
            new = (HEAD.replace("<svg ", '<svg width="32" height="32" style="color:#A87726" ', 1)
                   + body + "</svg>")
            big = (HEAD.replace("<svg ", '<svg width="64" height="64" style="color:#151D24" ', 1)
                   + body + "</svg>")
            cells.append(f'<div class="c"><div>{old}{new}{big}</div><b>{name}</b></div>')
        sheet.write_text(
            "<!doctype html><meta charset=utf-8><style>body{font:12px sans-serif;margin:12px;"
            "display:grid;grid-template-columns:repeat(6,1fr);gap:8px;background:#F8F8F8}"
            ".c{background:#fff;border-radius:10px;padding:8px;text-align:center}"
            ".c div{display:flex;gap:8px;align-items:center;justify-content:center}</style>"
            + "".join(cells),
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()

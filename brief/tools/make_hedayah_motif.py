"""Builds the Hedayah pattern motif for the app from the owner's Inkscape file.

Source: project/assets/hedayah/source/motif.svg (the owner's solopattern.svg,
one motif 19.659 mm square). Output: Dart path data that the Hedayah pattern
painter repeats on the brand grid (one copy every 12.149 mm across and down,
alternate rows shifted half a step; see Hedayah Brand Identity, Pattern).

Every path is written as absolute move/line/cubic/close commands in the
motif's own millimetre space (origin at its top-left corner). Arcs become
cubics. Paths keep their own fill rule; four paths in the source have no fill
set and take the pattern colour like the rest.

Run from the repo root:
    python brief/tools/make_hedayah_motif.py [--preview out.svg]

--preview also writes the rebuilt motif on the brand grid, over gold, to
compare with the source.
"""

import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "project/assets/hedayah/source/motif.svg"
OUTPUT = ROOT / "project/lib/core/widgets/hedayah/hedayah_motif_data.dart"

SVG = "{http://www.w3.org/2000/svg}"
TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def translate_of(element):
    match = re.match(r"translate\(([^,\s]+)[,\s]+([^)]+)\)", element.get("transform", ""))
    return (float(match.group(1)), float(match.group(2))) if match else (0.0, 0.0)


def arc_to_cubics(x1, y1, rx, ry, phi, large, sweep, x2, y2):
    """SVG arc (endpoint form) to cubic segments, per SVG 1.1 F.6.5."""
    if rx == 0 or ry == 0:
        return [(x1, y1, x2, y2, x2, y2)]
    rx, ry = abs(rx), abs(ry)
    cos_p, sin_p = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    xp, yp = cos_p * dx + sin_p * dy, -sin_p * dx + cos_p * dy
    scale = xp * xp / (rx * rx) + yp * yp / (ry * ry)
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    num = rx * rx * ry * ry - rx * rx * yp * yp - ry * ry * xp * xp
    den = rx * rx * yp * yp + ry * ry * xp * xp
    coef = math.sqrt(max(0.0, num / den)) * (-1 if large == sweep else 1)
    cxp, cyp = coef * rx * yp / ry, -coef * ry * xp / rx
    cx = cos_p * cxp - sin_p * cyp + (x1 + x2) / 2
    cy = sin_p * cxp + cos_p * cyp + (y1 + y2) / 2

    def angle(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    start = angle(1, 0, (xp - cxp) / rx, (yp - cyp) / ry)
    delta = angle((xp - cxp) / rx, (yp - cyp) / ry, (-xp - cxp) / rx, (-yp - cyp) / ry)
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    elif sweep and delta < 0:
        delta += 2 * math.pi
    pieces = max(1, math.ceil(abs(delta) / (math.pi / 2) - 1e-9))
    step = delta / pieces
    k = 4 / 3 * math.tan(step / 4)
    out = []
    t = start
    for _ in range(pieces):
        c1, s1 = math.cos(t), math.sin(t)
        c2, s2 = math.cos(t + step), math.sin(t + step)
        p1 = (c1 - k * s1, s1 + k * c1)
        p2 = (c2 + k * s2, s2 - k * c2)
        p3 = (c2, s2)

        def map_point(p):
            x, y = p[0] * rx, p[1] * ry
            return cos_p * x - sin_p * y + cx, sin_p * x + cos_p * y + cy

        out.append((*map_point(p1), *map_point(p2), *map_point(p3)))
        t += step
    return out


def parse_path(d, ox, oy):
    """Absolute ops: ('M', x, y), ('L', x, y), ('C', 6 values), ('Z',)."""
    tokens = TOKEN.findall(d)
    ops, i = [], 0
    x = y = sx = sy = 0.0
    last_ctrl = None
    cmd = None

    def number():
        nonlocal i
        value = float(tokens[i])
        i += 1
        return value

    while i < len(tokens):
        if re.match(r"[A-Za-z]", tokens[i]):
            cmd = tokens[i]
            i += 1
            if cmd in "Zz":
                ops.append(("Z",))
                x, y = sx, sy
                last_ctrl = None
                continue
        rel = cmd.islower()
        c = cmd.upper()
        if c == "M":
            nx, ny = number(), number()
            x, y = (x + nx, y + ny) if rel else (nx, ny)
            sx, sy = x, y
            ops.append(("M", x, y))
            cmd = "l" if rel else "L"
            last_ctrl = None
        elif c == "L":
            nx, ny = number(), number()
            x, y = (x + nx, y + ny) if rel else (nx, ny)
            ops.append(("L", x, y))
            last_ctrl = None
        elif c == "H":
            nx = number()
            x = x + nx if rel else nx
            ops.append(("L", x, y))
            last_ctrl = None
        elif c == "V":
            ny = number()
            y = y + ny if rel else ny
            ops.append(("L", x, y))
            last_ctrl = None
        elif c == "C":
            v = [number() for _ in range(6)]
            if rel:
                v = [v[0] + x, v[1] + y, v[2] + x, v[3] + y, v[4] + x, v[5] + y]
            ops.append(("C", *v))
            last_ctrl = (v[2], v[3])
            x, y = v[4], v[5]
        elif c == "S":
            v = [number() for _ in range(4)]
            if rel:
                v = [v[0] + x, v[1] + y, v[2] + x, v[3] + y]
            c1 = (2 * x - last_ctrl[0], 2 * y - last_ctrl[1]) if last_ctrl else (x, y)
            ops.append(("C", *c1, *v))
            last_ctrl = (v[0], v[1])
            x, y = v[2], v[3]
        elif c == "A":
            rx, ry, phi, large, sweep, nx, ny = [number() for _ in range(7)]
            if rel:
                nx, ny = x + nx, y + ny
            for seg in arc_to_cubics(x, y, rx, ry, phi, int(large), int(sweep), nx, ny):
                ops.append(("C", *seg))
            x, y = nx, ny
            last_ctrl = None
        else:
            raise ValueError(f"Unsupported path command {cmd}")
    return [(op[0], *[v + (ox if j % 2 == 0 else oy) for j, v in enumerate(op[1:])]) for op in ops]


def main():
    tree = ET.parse(SOURCE)
    root = tree.getroot()
    size = float(root.get("viewBox").split()[2])
    paths = []

    def walk(element, ox, oy):
        tx, ty = translate_of(element)
        ox, oy = ox + tx, oy + ty
        if element.tag == SVG + "path":
            style = element.get("style", "")
            even_odd = "evenodd" in style or element.get("fill-rule") == "evenodd"
            paths.append((even_odd, parse_path(element.get("d"), ox, oy)))
        for child in element:
            walk(child, ox, oy)

    walk(root, 0.0, 0.0)

    def fmt(v):
        text = f"{v:.4f}".rstrip("0").rstrip(".")
        return "0" if text in ("-0", "") else text

    codes = {"M": 0, "L": 1, "C": 2, "Z": 3}
    lines = []
    for even_odd, ops in paths:
        flat = []
        for op in ops:
            flat.append(str(codes[op[0]]))
            flat.extend(fmt(v) for v in op[1:])
        lines.append(f"  (evenOdd: {'true' if even_odd else 'false'}, d: [{', '.join(flat)}]),")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        "// Generated by brief/tools/make_hedayah_motif.py from\n"
        "// assets/hedayah/source/motif.svg (the owner's pattern motif). Do not edit.\n"
        "//\n"
        "// Each entry is one filled path in the motif's millimetre space, origin at\n"
        "// its top-left corner. Commands: 0 move x y, 1 line x y,\n"
        "// 2 cubic x1 y1 x2 y2 x y, 3 close.\n\n"
        f"const double hedayahMotifSize = {fmt(size)};\n\n"
        "const List<({bool evenOdd, List<double> d})> hedayahMotifPaths = [\n"
        + "\n".join(lines)
        + "\n];\n",
        encoding="utf-8",
    )

    print(f"{len(paths)} paths, motif {size} mm -> {OUTPUT.relative_to(ROOT)}")
    if "--preview" not in sys.argv:
        return
    preview = Path(sys.argv[sys.argv.index("--preview") + 1])

    def svg_d(ops):
        out = []
        for op in ops:
            out.append(op[0] + " ".join(fmt(v) for v in op[1:]))
        return "".join(out)

    motif = "".join(
        f'<path fill-rule="{"evenodd" if eo else "nonzero"}" d="{svg_d(ops)}"/>' for eo, ops in paths
    )
    step = 12.1494
    uses = []
    for row in range(-1, 8):
        for col in range(-1, 6):
            uses.append(
                f'<use href="#m" x="{fmt(col * 2 * step + (row % 2) * step - size / 2)}" '
                f'y="{fmt(row * step - size / 2)}"/>'
            )
    preview.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 90" width="960" height="720">'
        '<rect width="120" height="90" fill="#BD933F"/>'
        f'<defs><g id="m" fill="#fff">{motif}</g></defs>'
        f'<g opacity=".35">{"".join(uses)}</g>'
        f'<g transform="translate(96 4)"><rect width="{fmt(size)}" height="{fmt(size)}" fill="#151D24"/>'
        '<use href="#m"/></g></svg>',
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

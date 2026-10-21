#!/usr/bin/env python3
"""Builds the launcher-icon layers, splash mark and favicon in Hidayah Gold.

Run from the repository root:  python brief/tools/make_launcher_assets.py
then, from project/:            dart run flutter_launcher_icons

The icon is the owner's gold mark (`clearlogo2.png`) on the Hidayah Gold
"night" tile: slate s800 -> s900 -> s950 with a warm gold glow in the top
corner (design review 2026-10-19). Hidayah Gold is the only design since
2026-10-21; the green tile this script used to build is gone.

Reads only `project/assets/logo/` and never writes to it, except the 192 px
browser tile the app bundles. Every other file in there is owner-supplied and
is preserved as delivered. The layers go to `project/assets/launcher/`, which
`flutter_launcher_icons` consumes.

Why layers rather than a finished tile: an adaptive icon is 108x108dp and the
launcher may mask it to a circle or squircle; only the inner 72dp is sure to
show. flutter_launcher_icons insets the foreground by 16% (to 68% of the
canvas), so the mark is placed at MARK_FRACTION of that inset canvas.
Android 13+ themed icons need a one-colour silhouette; `black.png` is one.

The Play listing icon (store/assets/icon_512.png) is not written here; it is
maintained by hand.
"""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOGO = ROOT / "project" / "assets" / "logo"
OUT = ROOT / "project" / "assets" / "launcher"
RES = ROOT / "project" / "android" / "app" / "src" / "main" / "res"

CANVAS = 1024
S800, S900, S950 = (0x24, 0x2E, 0x37), (0x15, 0x1D, 0x24), (0x0B, 0x11, 0x17)
GOLD = (0xC1, 0x92, 0x3B)
# 0.45 of the full 108dp canvas, as the owner approved on a Samsung squircle
# (2026-10-19), expressed against the 68% inset canvas.
MARK_FRACTION = 0.45 / 0.68
# Mark width on finished (legacy, iOS, web) tiles.
MARK_TILE = 0.54
SPLASH_MARK_DP = 160


def night(side: int) -> Image.Image:
    """The night gradient (top-left to bottom-right) with the gold glow."""
    tile = Image.new("RGB", (side, side))
    px = tile.load()
    for y in range(side):
        for x in range(side):
            t = (x + y) / (2 * (side - 1))
            a, b, u = (S800, S900, t / .55) if t < .55 else (S900, S950, (t - .55) / .45)
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * u) for i in range(3))
    glow = Image.new("L", (side, side))
    ImageDraw.Draw(glow).ellipse(
        (side * .45, -side * .55, side * 1.45, side * .45), fill=round(255 * .24))
    glow = glow.filter(ImageFilter.GaussianBlur(side * .18))
    tile.paste(Image.new("RGB", (side, side), GOLD), (0, 0), glow)
    return tile.convert("RGBA")


def place(canvas: Image.Image, mark: Image.Image, width_ratio: float) -> Image.Image:
    side = canvas.width
    width = round(side * width_ratio)
    art = mark.resize((width, round(width * mark.height / mark.width)),
                      Image.Resampling.LANCZOS)
    canvas.alpha_composite(art, ((side - art.width) // 2, (side - art.height) // 2))
    return canvas


def rounded_tile(mark: Image.Image, side: int) -> Image.Image:
    big = side * 4
    tile = place(night(big), mark, MARK_TILE)
    mask = Image.new("L", (big, big))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1),
                                           radius=round(big * .24), fill=255)
    tile.putalpha(mask)
    return tile.resize((side, side), Image.Resampling.LANCZOS)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    mark = Image.open(LOGO / "clearlogo2.png").convert("RGBA")
    mark = mark.crop(mark.getbbox())

    night(CANVAS).save(OUT / "adaptive_background.png")
    place(Image.new("RGBA", (CANVAS, CANVAS)), mark, MARK_FRACTION).save(
        OUT / "adaptive_foreground.png")
    black = Image.open(LOGO / "black.png").convert("RGBA")
    black = black.crop(black.getbbox())
    solid = Image.new("RGBA", black.size, (0, 0, 0, 255))
    solid.putalpha(black.getchannel("A"))
    place(Image.new("RGBA", (CANVAS, CANVAS)), solid, MARK_FRACTION).save(
        OUT / "adaptive_monochrome.png")
    # The square tile for legacy mipmaps, iOS (no alpha, the OS rounds it) and
    # the web manifest icons.
    place(night(CANVAS), mark, MARK_TILE).convert("RGB").save(OUT / "icon_1024.png")

    # Splash mark: the gold mark at a nominal 160dp, per density, on the
    # night launch window (see drawable/launch_background.xml).
    for bucket, dp_scale in (("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0),
                             ("xxhdpi", 3.0), ("xxxhdpi", 4.0)):
        width = int(SPLASH_MARK_DP * dp_scale)
        height = max(1, round(mark.height * width / mark.width))
        target = RES / f"drawable-{bucket}"
        target.mkdir(parents=True, exist_ok=True)
        mark.resize((width, height), Image.Resampling.LANCZOS).save(target / "splash_logo.png")

    # Browser tab icon and the bundled 192 px tile.
    rounded_tile(mark, 64).save(ROOT / "project" / "web" / "favicon.png")
    rounded_tile(mark, 192).save(LOGO / "hidayah_icon_192.png")

    for p in sorted(OUT.iterdir()):
        with Image.open(p) as im:
            print(f"{p.relative_to(ROOT)}: {im.size[0]}x{im.size[1]} {im.mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

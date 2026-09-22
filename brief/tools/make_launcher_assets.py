#!/usr/bin/env python3
"""Builds the launcher-icon source layers from the owner's supplied logo files.

Run from the repository root:  python brief/tools/make_launcher_assets.py

Reads only `project/assets/logo/` and never writes to it: every file in there is
owner-supplied and is preserved as delivered. The generated layers go to
`project/assets/launcher/`, which `flutter_launcher_icons` consumes.

Why the layers are built rather than taken straight from the supplied files:

* An adaptive icon is 108x108dp and the launcher may mask it to a circle, a
  squircle or a rounded square. Only the inner 72x72dp is guaranteed visible,
  so a full-bleed mark gets its edges cut. `square.png` and `cercal.png` are
  finished tiles with the mark already near the edge, so they are correct as a
  legacy icon but wrong as an adaptive foreground.
* The foreground therefore places the bare mark (`colored.png`) at
  MARK_FRACTION of the canvas, inside the safe zone, on transparency, with the
  tile's own background colour supplied separately as a flat layer.
* Android 13+ themed icons need a single-colour silhouette with an alpha
  channel; `black.png` is exactly that, so the monochrome layer is the same
  geometry in black.
"""

from __future__ import annotations

import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOGO = ROOT / "project" / "assets" / "logo"
OUT = ROOT / "project" / "assets" / "launcher"
STORE = ROOT / "store" / "assets"

CANVAS = 1024
# Fraction of the canvas width the mark occupies.
#
# The safe zone is NOT applied here: flutter_launcher_icons wraps the
# foreground in `<inset android:inset="16%">`, which scales the drawable to 68%
# of the 108dp canvas, or 73dp -- effectively the 72dp guaranteed-visible area
# already. Insetting again here would shrink the mark to roughly 39% of the
# icon and leave it swimming in empty space. 0.92 therefore fills the layer,
# keeping only a little breathing room for the mark's own asymmetry.
MARK_FRACTION = 0.92
# Sampled from the owner's square.png tile, so the generated background matches
# the supplied artwork rather than approximating it.
TILE_BACKGROUND = (238, 255, 243, 255)
# Nominal width of the launch-screen mark, in density-independent pixels.
SPLASH_MARK_DP = 160


def centred(mark_path: pathlib.Path, *, black: bool) -> Image.Image:
    """The mark, scaled into the safe zone and centred on a transparent canvas."""
    mark = Image.open(mark_path).convert("RGBA")
    target_w = int(CANVAS * MARK_FRACTION)
    scale = target_w / mark.width
    size = (target_w, max(1, int(round(mark.height * scale))))
    mark = mark.resize(size, Image.LANCZOS)
    if black:
        # Keep the alpha, force the colour: a themed icon is tinted by the OS.
        solid = Image.new("RGBA", mark.size, (0, 0, 0, 255))
        solid.putalpha(mark.getchannel("A"))
        mark = solid
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(
        mark, ((CANVAS - mark.width) // 2, (CANVAS - mark.height) // 2)
    )
    return canvas


def main() -> int:
    if not LOGO.is_dir():
        print(f"missing {LOGO}", file=sys.stderr)
        return 2
    OUT.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)

    centred(LOGO / "colored.png", black=False).save(OUT / "adaptive_foreground.png")
    centred(LOGO / "black.png", black=True).save(OUT / "adaptive_monochrome.png")
    Image.new("RGBA", (CANVAS, CANVAS), TILE_BACKGROUND).save(
        OUT / "adaptive_background.png"
    )

    # The finished square tile, for the legacy mipmaps, the web icons and the
    # store listing. Downscaled from the supplied 1232px original.
    tile = Image.open(LOGO / "square.png").convert("RGBA")
    tile.resize((CANVAS, CANVAS), Image.LANCZOS).save(OUT / "icon_1024.png")
    # Play's listing icon is 512x512 and must not carry an alpha channel.
    tile.resize((512, 512), Image.LANCZOS).convert("RGB").save(
        STORE / "icon_512.png"
    )

    # Splash mark: the bare coloured mark on transparency, at a nominal 160dp
    # across, rendered per density so the launch window can centre a bitmap
    # without scaling it. The splash background is white in both light and dark
    # mode, because the app itself is light-only (ThemeMode.light, scheme A).
    mark = Image.open(LOGO / "colored.png").convert("RGBA")
    res = ROOT / "project" / "android" / "app" / "src" / "main" / "res"
    for bucket, dp_scale in (
        ("mdpi", 1.0),
        ("hdpi", 1.5),
        ("xhdpi", 2.0),
        ("xxhdpi", 3.0),
        ("xxxhdpi", 4.0),
    ):
        width = int(SPLASH_MARK_DP * dp_scale)
        height = max(1, int(round(mark.height * width / mark.width)))
        target = res / f"drawable-{bucket}"
        target.mkdir(parents=True, exist_ok=True)
        mark.resize((width, height), Image.LANCZOS).save(target / "splash_logo.png")
        print(f"{(target / 'splash_logo.png').relative_to(ROOT)}: {width}x{height}")

    # Web favicon. flutter_launcher_icons writes web/icons/ but leaves
    # web/favicon.png as Flutter's default, which is the one a browser tab
    # actually shows.
    favicon = ROOT / "project" / "web" / "favicon.png"
    tile.resize((64, 64), Image.LANCZOS).save(favicon)
    print(f"{favicon.relative_to(ROOT)}: 64x64")

    for p in sorted(OUT.iterdir()) + [STORE / "icon_512.png"]:
        with Image.open(p) as im:
            print(f"{p.relative_to(ROOT)}: {im.size[0]}x{im.size[1]} {im.mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Build the Hidayah Gold launcher and browser icons; preserve all source logos.

The icon is the supplied gold mark (clearlogo2.png) on the Hidayah Gold
"night" tile: slate s800 -> s900 -> s950 with a warm gold glow in the top
corner, as proposed in the 2026-10-19 design review.

Run from the repository root: python brief/tools/make_hidayah_launcher_assets.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "project/assets/logo"
RES = ROOT / "project/android/app/src/main/res"

S800, S900, S950 = (0x24, 0x2E, 0x37), (0x15, 0x1D, 0x24), (0x0B, 0x11, 0x17)
GOLD = (0xC1, 0x92, 0x3B)

# Mark width as a share of the tile; 20% smaller than the first version
# (.56 / .67) after the owner saw it crowd the Samsung squircle (2026-10-19).
MARK_ADAPTIVE = .45
MARK_LEGACY = .54


def night(side):
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


def place(canvas, mark, width_ratio):
    side = canvas.width
    width = round(side * width_ratio)
    art = mark.resize((width, round(width * mark.height / mark.width)),
                      Image.Resampling.LANCZOS)
    canvas.alpha_composite(art, ((side - art.width) // 2, (side - art.height) // 2))
    return canvas


def rounded_tile(mark, side):
    """Legacy / browser icon: the night tile with rounded corners."""
    big = side * 4
    tile = place(night(big), mark, MARK_LEGACY)
    mask = Image.new("L", (big, big))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1),
                                           radius=round(big * .24), fill=255)
    tile.putalpha(mask)
    return tile.resize((side, side), Image.Resampling.LANCZOS)


def main():
    mark = Image.open(LOGO / "clearlogo2.png").convert("RGBA")
    mark = mark.crop(mark.getbbox())
    for density, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
                           ("xxhdpi", 3), ("xxxhdpi", 4)]:
        mipmap = RES / f"mipmap-{density}"
        mipmap.mkdir(exist_ok=True)
        rounded_tile(mark, round(48 * scale)).save(mipmap / "ic_launcher_hidayah.png")
        side = round(108 * scale)
        drawable = RES / f"drawable-{density}"
        drawable.mkdir(exist_ok=True)
        night(side).save(drawable / "ic_hidayah_background.png")
        # The visible mark fits inside the adaptive icon's central 72dp safe zone.
        place(Image.new("RGBA", (side, side)), mark, MARK_ADAPTIVE).save(
            drawable / "ic_hidayah_foreground.png")
    adaptive = RES / "mipmap-anydpi-v26"
    adaptive.mkdir(exist_ok=True)
    adaptive.joinpath("ic_launcher_hidayah.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_hidayah_background"/>
    <foreground android:drawable="@drawable/ic_hidayah_foreground"/>
    <monochrome>
        <inset android:drawable="@drawable/ic_launcher_monochrome" android:inset="16%"/>
    </monochrome>
</adaptive-icon>
''', encoding="utf-8")
    RES.joinpath("values/hidayah_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <!-- Night slate s900: the Hidayah Gold launcher tile. -->\n'
        '    <color name="hidayah_launcher_background">#151D24</color>\n'
        '</resources>\n', encoding="utf-8")
    # Browser tab icon used while the gold palette is on (web).
    rounded_tile(mark, 192).save(LOGO / "hidayah_icon_192.png")
    rounded_tile(mark, 1024).save(ROOT / "brief/evidence/2026-10-19/hidayah-gold-web/hidayah-launcher-icon.png")
    print("Generated Hidayah Gold launcher and browser icons.")


if __name__ == "__main__":
    main()

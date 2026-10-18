"""Package the supplied gold artwork for Android; preserve all source logos.

Run from the repository root: python brief/tools/make_hidayah_launcher_assets.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "project/assets/logo"
RES = ROOT / "project/android/app/src/main/res"


def main():
    mark = Image.open(LOGO / "clearlogo2.png").convert("RGBA")
    tile = Image.open(LOGO / "logo2.png").convert("RGBA")
    background = tile.getpixel((tile.width // 2, 10))
    assert background[3] == 255
    for density, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
                           ("xxhdpi", 3), ("xxxhdpi", 4)]:
        legacy = Image.new("RGBA", tile.size, background)
        legacy.alpha_composite(tile)
        mipmap = RES / f"mipmap-{density}"
        mipmap.mkdir(exist_ok=True)
        legacy.resize((round(48 * scale),) * 2, Image.Resampling.LANCZOS).save(
            mipmap / "ic_launcher_hidayah.png")
        side = round(108 * scale)
        # The visible mark fits inside the adaptive icon's central 72dp safe zone.
        width = round(side * .62)
        art = mark.resize((width, round(width * mark.height / mark.width)),
                          Image.Resampling.LANCZOS)
        foreground = Image.new("RGBA", (side, side))
        foreground.alpha_composite(art, ((side - art.width) // 2,
                                         (side - art.height) // 2))
        drawable = RES / f"drawable-{density}"
        drawable.mkdir(exist_ok=True)
        foreground.save(drawable / "ic_hidayah_foreground.png")
    adaptive = RES / "mipmap-anydpi-v26"
    adaptive.mkdir(exist_ok=True)
    adaptive.joinpath("ic_launcher_hidayah.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/hidayah_launcher_background"/>
    <foreground android:drawable="@drawable/ic_hidayah_foreground"/>
    <monochrome>
        <inset android:drawable="@drawable/ic_launcher_monochrome" android:inset="16%"/>
    </monochrome>
</adaptive-icon>
''', encoding="utf-8")
    color = "#" + "".join(f"{value:02X}" for value in background[:3])
    RES.joinpath("values/hidayah_launcher.xml").write_text(
        f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="hidayah_launcher_background">{color}</color>\n'
        f'</resources>\n', encoding="utf-8")
    print(f"Generated gold launcher resources. Background: {color}")


if __name__ == "__main__":
    main()

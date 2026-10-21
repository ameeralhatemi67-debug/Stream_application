"""Build the small runtime copies of the Hidayah Gold mark.

The supplied master, project/assets/logo/clearlogo2.png (902 x 800, 2.9 MB),
stays on disk for make_hidayah_launcher_assets.py. The app bundles only these
copies (audit 2026-10-21, P0-5: the master alone was 2.9 MB of the first web
load). The largest place the mark is drawn is the 104 px splash logo, so:

  assets/logo/hidayah_mark.png       208 px wide, 2x of 104 (web, DPR <= 2)
  assets/logo/3.0x/hidayah_mark.png  312 px wide, 3x of 104 (phones)

Run from the repository root after the master changes:
    python brief/tools/make_hidayah_display_logo.py
"""
from pathlib import Path

from PIL import Image

LOGO = Path(__file__).resolve().parents[2] / "project" / "assets" / "logo"


def main():
    master = Image.open(LOGO / "clearlogo2.png").convert("RGBA")
    for width, out in [(208, LOGO / "hidayah_mark.png"),
                       (312, LOGO / "3.0x" / "hidayah_mark.png")]:
        height = round(master.height * width / master.width)
        out.parent.mkdir(exist_ok=True)
        # Full RGBA, no palette: quantising bands the gold gradient.
        master.resize((width, height), Image.LANCZOS).save(out, optimize=True)
        print(f"{out.relative_to(LOGO.parent.parent)}: {out.stat().st_size} bytes")


if __name__ == "__main__":
    main()

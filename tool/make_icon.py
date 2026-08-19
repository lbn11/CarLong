"""Make launcher icon assets from the ImageGen output.

Produces two PNGs in assets/icon/:
  - icon.png            : full opaque 1024x1024 with watermark region cleared
                          (used as image_path for flutter_launcher_icons →
                           iOS AppIcon + Android legacy mipmap-*).
  - icon_foreground.png : transparent background + watermark cleared
                          (used as adaptive_icon_foreground).

The ImageGen output has:
  • a near-solid coral background (bg) — detected from the top edge
  • a dark "AI生成 WORKBUDDY_" watermark in the bottom-right ~220x100 region

Watermark fill uses a sample taken just to the LEFT of the watermark, so
the fill colour matches the immediately adjacent pixels (no visible seam
even if the bg has a subtle gradient).

Usage:  python3 tool/make_icon.py
"""
from __future__ import annotations
from PIL import Image
from collections import Counter

SRC = "/Users/apple/Downloads/CarLong/assets/icon/Mobile_game_app_icon__1024x102_2026-08-18T15-41-58.png"
OUT_FULL = "/Users/apple/Downloads/CarLong/assets/icon/icon.png"
OUT_FG = "/Users/apple/Downloads/CarLong/assets/icon/icon_foreground.png"
WMARK_W, WMARK_H = 220, 100  # bottom-right watermark rect (matches remove_bg.py)


def detect_bg(img: Image.Image) -> tuple[int, int, int]:
    """Dominant colour along the top edge — treated as the background."""
    samples = [img.getpixel((x, 5))[:3] for x in range(0, img.width, 16)]
    return Counter(samples).most_common(1)[0][0]


def dist(a, b) -> float:
    return sum((a[i] - b[i]) ** 2 for i in range(3)) ** 0.5


def hex_(rgb) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    w, h = img.width, img.height
    bg = detect_bg(img)
    print(f"detected background  rgb={bg}  hex={hex_(bg)}")

    # 1) Full opaque icon — fill the watermark rect with the colour sampled
    #    just to the LEFT of the watermark so the fill blends seamlessly.
    full = img.copy()
    fpx = full.load()
    seam_color = fpx[w - WMARK_W - 8, h - 50][:3]  # adjacent pixel, just left
    for y in range(h - WMARK_H, h):
        for x in range(w - WMARK_W, w):
            fpx[x, y] = (seam_color[0], seam_color[1], seam_color[2], 255)
    full.save(OUT_FULL, "PNG", optimize=True)
    print(f"saved  {OUT_FULL}  ({w}x{h})")

    # 2) Transparent foreground — chroma-key the background colour and also
    #    clear the watermark rect entirely (the dark text is NOT bg-coloured,
    #    so chroma-key alone would leave it visible).
    fg = img.copy()
    fpx = fg.load()
    THRESHOLD = 55  # tuned to separate coral bg from pastel vehicle colours
    for y in range(h):
        for x in range(w):
            r, g, b, a = fpx[x, y]
            in_wmark = x >= w - WMARK_W and y >= h - WMARK_H
            if in_wmark or dist((r, g, b), bg) < THRESHOLD:
                fpx[x, y] = (r, g, b, 0)
    fg.save(OUT_FG, "PNG", optimize=True)

    # quick sanity report
    alphas = fg.getchannel("A").getdata()
    visible = sum(1 for a in alphas if a > 30)
    print(f"saved  {OUT_FG}  ({w}x{h}, ~{100*visible/(w*h):.1f}% visible pixels)")


if __name__ == "__main__":
    main()

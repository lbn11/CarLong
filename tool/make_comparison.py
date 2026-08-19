"""
17 款车模的"旧 vs 新"对比图(垂直左右两列)。
两侧都做"bbox + 缩放到最长边 700 + 居中 900×900 透明画布"的归一化,
这样大小变量被控制住,新旧对比纯粹显示"侧光方向"差异。

旧: /tmp/old_toplit/<name>.png  (从 git ba9b2b0 提取的顶光版)
新: assets/vehicles/<name>.png   (侧光 + 翻转 + 归一化后的最新版本)
"""
import os
from PIL import Image, ImageDraw

OLD_DIR = "/tmp/old_toplit"
NEW_DIR = "/Users/apple/Downloads/CarLong/assets/vehicles"
OUT = "/Users/apple/Downloads/CarLong/side_lit_comparison.png"

try:
    from PIL import ImageFont
    FONT = ImageFont.load_default()
except Exception:
    FONT = None

VEH = [
    ("bike",    0xFF4CAF50), ("scooter", 0xFF009688), ("car",    0xFFF44336),
    ("taxi",    0xFFFF9800), ("bus",     0xFF2196F3), ("truck",  0xFF795548),
    ("train",   0xFF9C27B0), ("rocket",  0xFFE91E63), ("tanker", 0xFFFFC107),
    ("metro",   0xFF00BCD4), ("plane",   0xFF607D8B), ("jet",    0xFF8BC34A),
    ("shuttle", 0xFF673AB7), ("ufo",     0xFF3F51B5), ("maglev", 0xFF00BFA5),
    ("station", 0xFF7E57C2), ("comet",   0xFFC2185B),
]

CANVAS = 900       # 每辆车归一化到 900×900 透明画布
LONG_TGT = 700     # 长边目标像素(占画布 78%)


def rgb(h):
    return ((h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF)


def normalize(img):
    """bbox + 缩放最长边到 LONG_TGT + 居中 paste 到 CANVAS×CANVAS 透明画布。"""
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if not bbox:
        return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    crop = img.crop(bbox)
    cw, ch = crop.size
    s = LONG_TGT / max(cw, ch)
    nw, nh = max(1, int(cw * s)), max(1, int(ch * s))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(crop, ((CANVAS - nw) // 2, (CANVAS - nh) // 2), crop)
    return canvas


def gradient_card(draw, x, y, w, h, color):
    """深色渐变卡片 + 车型色边框。"""
    for i in range(h):
        t = i / max(1, h - 1)
        r = int(21 * (1 - t) + 10 * t)
        g = int(28 * (1 - t) + 14 * t)
        b = int(42 * (1 - t) + 22 * t)
        draw.line([(x, y + i), (x + w - 1, y + i)], fill=(r, g, b))
    r, g, b = color
    draw.rectangle([x, y, x + w - 1, y + h - 1], outline=(r, g, b), width=3)


def main():
    margin_x = 40
    margin_top = 80
    gap = 26
    cell_w = 360
    cell_h = 220
    W = margin_x * 2 + 2 * cell_w + gap
    H = margin_top + len(VEH) * cell_h + 50
    bg = Image.new("RGBA", (W, H), (11, 15, 23, 255))
    draw = ImageDraw.Draw(bg)
    draw.text((margin_x, 20), "车模光照：旧(顶光) -> 新(纯侧光·统一方向·统一大小)",
              fill=(235, 238, 245), font=FONT)
    draw.text((margin_x, 46), "两侧均归一化到 900×900 画布,长边 700px,居中(去掉大小变量)",
              fill=(140, 150, 165), font=FONT)

    for row, (name, hexv) in enumerate(VEH):
        y = margin_top + row * cell_h
        color = rgb(hexv)
        x_old = margin_x
        x_new = margin_x + cell_w + gap
        gradient_card(draw, x_old, y, cell_w, cell_h, color)
        gradient_card(draw, x_new, y, cell_w, cell_h, color)

        # 加载并归一化两侧
        old_im = normalize(Image.open(os.path.join(OLD_DIR, name + ".png")))
        new_im = normalize(Image.open(os.path.join(NEW_DIR, name + ".png")))

        # 缩放到卡片内:卡片内可用高度 cell_h-50,宽度 cell_w-30
        # 选 cell_h-50 作为高度限制(因为上下要有标签)
        inner_h = cell_h - 50
        inner_w = cell_w - 30
        # 旧的按"非透明区域高度"算
        def paste_centered(canvas_img, cx, cy, max_w, max_h):
            bbox = canvas_img.getbbox()
            if not bbox: return
            crop = canvas_img.crop(bbox)
            cw, ch = crop.size
            s = min(max_w / cw, max_h / ch)
            nw, nh = max(1, int(cw * s)), max(1, int(ch * s))
            crop = crop.resize((nw, nh), Image.LANCZOS)
            ox = cx - nw // 2
            oy = cy - nh // 2
            bg.paste(crop, (ox, oy), crop)

        cy_old = y + cell_h // 2 - 4
        paste_centered(old_im, x_old + cell_w // 2, cy_old, inner_w, inner_h)
        paste_centered(new_im, x_new + cell_w // 2, cy_old, inner_w, inner_h)

        draw.text((x_old + 8, y + cell_h - 22), "旧 顶光", fill=color, font=FONT)
        draw.text((x_new + 8, y + cell_h - 22), "新 侧光", fill=color, font=FONT)

    bg.convert("RGB").save(OUT, optimize=True)
    print("SAVED", OUT, bg.size)


main()

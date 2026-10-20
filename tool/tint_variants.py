#!/usr/bin/env python3
"""从已有的 17 张车模派生出缺失档位的配色变体。

50 档车型里只有 17 档出过图（`generated-images/` 里 45 张 PNG 全是这 17 款的
SIDE / SIDE2 / SIDE3 三个视角，没有第 18 款）。与其为剩下 33 档重新出图，这里
把「同族车型」复用同一张底图，并用 **色相旋转到该档的车型色** 区分身份：

    颜色 = 车型身份（CarTier.color）——底图跟着车型色走，和图鉴/卡面一致。

用法：
    python3 tool/tint_variants.py            # 生成到 assets/vehicles 与 mini/assets/vehicles
    python3 tool/tint_variants.py --sheet    # 额外输出对照表 docs/preview/vehicle_variants.png

底图永远是那 17 张原始 PNG（bike/car/bus/...），派生文件按档位名命名，
互不覆盖，可反复执行。
"""
from __future__ import annotations

import argparse
import colorsys
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, 'assets/vehicles')
MINI_DIR = os.path.join(ROOT, 'mini/assets/vehicles')
SHEET_OUT = os.path.join(ROOT, 'docs/preview/vehicle_variants.png')

# tier 名, 底图, 车型色, 额外色相偏移(角度)
# 同一底图 + 同一车型色的档位必须靠 hue_offset 拉开（否则两张图完全一样）。
PLAN: list[tuple[str, str, int, float]] = [
    # ── 陆地 ──
    ('motorcycle', 'bike', 0x795548, 0),      # 两轮
    ('suv', 'car', 0x607D8B, 0),              # 高底盘轿车
    ('van', 'bus', 0x8BC34A, 0),              # 短厢车
    ('ambulance', 'bus', 0xE91E63, -18),      # 厢式急救车
    ('police', 'car', 0x1565C0, 0),
    ('firetruck', 'truck', 0xD32F2F, 0),
    ('limousine', 'car', 0x212121, 0),        # 深色公务车
    # ── 重工 ──
    ('bulldozer', 'truck', 0xFFC107, 0),
    ('crane', 'truck', 0x607D8B, 0),
    ('excavator', 'truck', 0xFFC107, 22),     # 与 bulldozer 同色同底图，偏橙拉开
    ('dumptruck', 'truck', 0x795548, 0),
    ('forklift', 'truck', 0xFF9800, -14),
    ('cementmixer', 'tanker', 0x9E9E9E, 0),   # 罐体
    # ── 轨道 ──
    ('tram', 'train', 0xFFC107, 0),
    ('lightrail', 'train', 0x4CAF50, 0),
    ('monorail', 'maglev', 0x2196F3, 0),
    ('steam', 'train', 0x5D4037, 0),
    ('hyperloop', 'maglev', 0x00BCD4, 14),
    # ── 航空 / 太空 ──
    ('glider', 'plane', 0x90A4AE, 0),
    ('cargo', 'plane', 0xFFC107, 0),
    ('seaplane', 'plane', 0x2196F3, 8),
    ('stealth', 'jet', 0x455A64, 0),
    ('warpShip', 'ufo', 0x7C4DFF, 0),
]


def _rgb_to_hsv(a: np.ndarray):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    i = m & (mx == r)
    h[i] = ((g - b)[i] / d[i]) % 6
    i = m & (mx == g) & (mx != r)
    h[i] = ((b - r)[i] / d[i]) + 2
    i = m & (mx == b) & (mx != r) & (mx != g)
    h[i] = ((r - g)[i] / d[i]) + 4
    return h / 6.0, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0), mx


def _hsv_to_rgb(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    i = np.floor(h * 6).astype(np.int32) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,), dtype=np.float32)
    for k, ch in enumerate(((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))):
        m = i == k
        for c in range(3):
            out[..., c][m] = ch[c][m]
    return out


def dominant_hue(img: Image.Image) -> float | None:
    """按饱和度加权取车身主色相（色相是环形，用圆均值）。"""
    a = np.asarray(img.convert('RGBA'), dtype=np.float32) / 255.0
    h, s, v = _rgb_to_hsv(a[..., :3])
    mask = (a[..., 3] > 0.7) & (s > 0.30) & (v > 0.15) & (v < 0.98)
    if mask.sum() < 200:
        return None
    ang = h[mask] * 2 * math.pi
    w = s[mask] * v[mask]
    return (math.atan2(float(np.sum(np.sin(ang) * w)), float(np.sum(np.cos(ang) * w)))
            / (2 * math.pi)) % 1.0


def retint(img: Image.Image, target_hex: int, hue_offset: float = 0.0) -> Image.Image:
    t = (((target_hex >> 16) & 255) / 255, ((target_hex >> 8) & 255) / 255, (target_hex & 255) / 255)
    th, ts, tv = colorsys.rgb_to_hsv(*t)
    th = (th + hue_offset / 360.0) % 1.0

    a = np.asarray(img.convert('RGBA'), dtype=np.float32) / 255.0
    h, s, v = _rgb_to_hsv(a[..., :3])
    base = dominant_hue(img)
    if base is not None:
        h = (h + ((th - base) % 1.0)) % 1.0

    if tv < 0.30:
        # 近黑（豪华轿车）：压暗为主，保留原有高光形状，别变成灰褐色
        v = v * (0.16 + tv * 0.7)
        s = s * 0.28
    else:
        s = np.clip(s + (ts - 0.5) * 0.25, 0, 1)

    out = _hsv_to_rgb(h, s, v)
    res = np.concatenate([out, a[..., 3:4]], axis=-1)
    return Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), 'RGBA')


def build_sheet(rows: list[tuple[str, str, int]]) -> None:
    cell, pad, cols = 150, 10, 6
    lines = (len(rows) + cols - 1) // cols
    w, h = cols * (cell + pad) + pad, lines * (cell + 36) + pad
    sheet = Image.new('RGB', (w, h), (26, 32, 40))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 13)
    except OSError:
        font = ImageFont.load_default()
    for i, (tier, base, hexv) in enumerate(rows):
        x = pad + (i % cols) * (cell + pad)
        y = pad + (i // cols) * (cell + 36)
        d.rounded_rectangle([x, y, x + cell, y + cell], 16, fill=(38, 46, 58),
                            outline=(hexv >> 16 & 255, hexv >> 8 & 255, hexv & 255), width=2)
        im = Image.open(os.path.join(SRC_DIR, tier + '.png')).convert('RGBA')
        im.thumbnail((cell - 14, cell - 14))
        sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2), im)
        d.text((x + 4, y + cell + 4), tier, fill=(230, 235, 245), font=font)
        d.text((x + 4, y + cell + 19), f'<- {base}', fill=(140, 152, 170), font=font)
    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    print(f'sheet -> {SHEET_OUT} ({sheet.size[0]}x{sheet.size[1]})')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--sheet', action='store_true', help='输出对照表')
    args = ap.parse_args()

    if not os.path.isdir(SRC_DIR):
        print(f'缺少 {SRC_DIR}', file=sys.stderr)
        return 1

    made = []
    for tier, base, hexv, off in PLAN:
        src = os.path.join(SRC_DIR, base + '.png')
        if not os.path.exists(src):
            print(f'跳过 {tier}: 底图 {base}.png 不存在', file=sys.stderr)
            continue
        img = Image.open(src)
        out = retint(img, hexv, off)

        dst = os.path.join(SRC_DIR, tier + '.png')
        out.save(dst)
        if os.path.isdir(MINI_DIR):
            small = out.copy()
            small.thumbnail((256, 256), Image.LANCZOS)
            small.save(os.path.join(MINI_DIR, tier + '.png'))
        made.append((tier, base, hexv))

    for tier, base, hexv in made:
        print(f'  {tier:<12} <- {base:<8} #{hexv:06X}')
    print(f'完成 {len(made)} 张；缺底图的档位：{len(PLAN) - len(made)}')

    if args.sheet:
        build_sheet(made)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

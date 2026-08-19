#!/usr/bin/env python3
"""
统一 17 款车模:
  1) 方向 — 把"右侧亮"(R > L)的车水平翻转,统一为"车头朝右 + 左侧来光"
  2) 大小 — bbox 对角线缩放到 TARGET_DIAG px(画布内),居中 paste 到 1024x1024 透明画布
           用「对角线」而非「最长边」:让细长/矮宽车型的视觉体量(外接圆)基本一致,
           避免细长车显得格外大、矮宽车显得格外小。

判断左右亮度时,只用 alpha>200 的实心主体像素。
rocket 等窄物体:若左右样本不够 -> 跳过翻转,只做大小归一化。
"""
import os
from PIL import Image

VEHICLE_DIR = '/Users/apple/Downloads/CarLong/assets/vehicles'
NAMES = ['bike','scooter','car','taxi','bus','truck','train','rocket',
         'tanker','metro','plane','jet','shuttle','ufo','maglev','station','comet']
CANVAS = 1024          # 输出画布尺寸
TARGET_DIAG = 920      # bbox 对角线目标像素(画布内,留边距)
FLIP_THRESHOLD = 5     # |R - L| 超过此值才翻转
MIN_SAMPLES = 100      # 左右样本数下限(防窄物体误判)


def decide_flip(img):
    """根据 bbox 内实心像素左右半平均亮度,判断是否需要水平翻转。
       返回 True 表示 R > L + threshold(右侧亮,车头朝左,需要翻成朝右)。"""
    px = img.load()
    w, h = img.size
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 200:
                xs.append(x)
                ys.append(y)
    if not xs:
        return False
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    cx = (x0 + x1) // 2
    L, R = [], []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            r, g, b, a = px[x, y]
            if a > 200:
                lum = (r + g + b) / 3
                if x < cx:
                    L.append(lum)
                else:
                    R.append(lum)
    if len(L) < MIN_SAMPLES or len(R) < MIN_SAMPLES:
        return False  # 窄物体(rocket)不翻转
    la, ra = sum(L) / len(L), sum(R) / len(R)
    return (ra - la) > FLIP_THRESHOLD


def normalize(name):
    path = os.path.join(VEHICLE_DIR, f'{name}.png')
    im = Image.open(path).convert('RGBA')

    # 1) 翻转
    flip = decide_flip(im)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)

    # 2) bbox
    px = im.load()
    w, h = im.size
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 10:
                xs.append(x)
                ys.append(y)
    if not xs:
        print(f'  SKIP   {name} (empty)')
        return
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    bbox = im.crop((x0, y0, x1 + 1, y1 + 1))
    bw, bh = bbox.size

    # 3) 缩放:对角线长度 -> TARGET_DIAG(保留车型原生比例)
    import math
    diag = math.sqrt(bw * bw + bh * bh)
    scale = TARGET_DIAG / diag
    new_w = max(1, int(round(bw * scale)))
    new_h = max(1, int(round(bh * scale)))
    bbox = bbox.resize((new_w, new_h), Image.LANCZOS)

    # 4) 居中 paste 到 1024x1024 透明画布
    canvas = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    ox = (CANVAS - new_w) // 2
    oy = (CANVAS - new_h) // 2
    canvas.paste(bbox, (ox, oy), bbox)

    canvas.save(path, optimize=True)
    print(f'  {"FLIP" if flip else "keep"}  {name:8}  bbox {bw}x{bh} -> {new_w}x{new_h}  center=({ox},{oy})')


if __name__ == '__main__':
    print('=== normalizing 17 vehicles (diagonal) ===')
    for n in NAMES:
        normalize(n)
    print('=== done ===')

#!/usr/bin/env python3
"""
清理 17 款车模的"棚拍地平面"灰底残留 — 长条状检测版。

策略: 在画布下半部分(y > 0.5*h),找"水平长条状连续低饱和区"作为地平面清掉。
      孤立的圆形/块状像素(车体反光)因不连续会保留。

判定规则(per row):
  - y > 0.5*h
  - 连续一段 >= 80 px 的不透明像素,平均 sat<15 且 100<avg_lum<250
  - 整段清掉(alpha=0)
  - 必须横向连续,不允许空隙(避免破坏车体中间高光)

保护:
  - y < 0.5*h (车体上半)
  - 接触阴影 (lum<100) 即使满足 sat<15 也不清
  - 横向断开的孤立高光块(车体反光、铆钉、车窗)
"""
import os
from PIL import Image

VEHICLE_DIR = '/Users/apple/Downloads/CarLong/assets/vehicles'
NAMES = ['bike','scooter','car','taxi','bus','truck','train','rocket',
         'tanker','metro','plane','jet','shuttle','ufo','maglev','station','comet']
Y_START_RATIO = 0.70
MIN_SEGMENT = 100   # 横向连续最少 100 像素(更严格,避免误删球面切线)
SAT_MAX = 12
LUM_MIN = 100
LUM_MAX = 250
GAP_TOL = 2         # 中间允许的透明像素 gap(更严格)


def clear_residue(name):
    path = os.path.join(VEHICLE_DIR, f'{name}.png')
    im = Image.open(path).convert('RGBA')
    px = im.load()
    w, h = im.size
    y_start = int(h * Y_START_RATIO)
    cleared = 0
    for y in range(y_start, h):
        # 从左到右扫描,找连续 segment
        x = 0
        while x < w:
            # 跳过透明
            while x < w and px[x, y][3] == 0:
                x += 1
            seg_start = x
            # 累计不透明像素和颜色,允许 GAP_TOL 个透明像素中断
            gaps = 0
            rsum = gsum = bsum = n = 0
            while x < w:
                r, g, b, a = px[x, y]
                if a == 0:
                    gaps += 1
                    if gaps > GAP_TOL:
                        break
                    x += 1
                    continue
                rsum += r; gsum += g; bsum += b; n += 1
                gaps = 0
                x += 1
            seg_end = x - gaps  # 实际不透明 segment 结束位置
            if n >= MIN_SEGMENT:
                avg_sat = max(rsum, gsum, bsum) - min(rsum, gsum, bsum)
                avg_lum = (rsum + gsum + bsum) // (3 * n)
                if avg_sat // n < SAT_MAX and LUM_MIN < avg_lum < LUM_MAX:
                    # 这是一个长条状低饱和中灰段,清掉
                    for xx in range(seg_start, seg_end):
                        r, g, b, a = px[xx, y]
                        if a > 0:
                            px[xx, y] = (r, g, b, 0)
                            cleared += 1
    im.save(path, optimize=True)
    print(f'  {name:8} cleared={cleared} pixels (rows y >= {y_start})')


if __name__ == '__main__':
    print('=== clearing gray residue (row-segment v3) ===')
    for n in NAMES:
        clear_residue(n)
    print('=== done ===')

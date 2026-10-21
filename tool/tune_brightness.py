#!/usr/bin/env python3
"""
对单张车模做整体提亮（不动 alpha、不改形状）。

用途：深色船体（军舰 / 航母）在深色卡槽里与背景对比不足，轮廓发糊。
`remove_bg.py` 里已经统一做过一次 `brighten(gamma=0.58)`，这里只给个别
偏暗的资产再叠一次更弱的曲线（默认 gamma 0.78），避免整体过曝。

    python3 tool/tune_brightness.py warship carrier --gamma 0.78
"""
import argparse

from PIL import Image, ImageEnhance

VEHICLE_DIR = 'assets/vehicles'


def tune(name, gamma, sat_boost):
    path = f'{VEHICLE_DIR}/{name}.png'
    img = Image.open(path).convert('RGBA')
    r, g, b, a = img.split()
    lut = [min(255, int((i / 255.0) ** gamma * 255)) for i in range(256)]
    img = Image.merge('RGBA', (r.point(lut), g.point(lut), b.point(lut), a))
    if sat_boost != 1.0:
        img = ImageEnhance.Color(img).enhance(sat_boost)
    img.save(path, optimize=True)
    print(f'  {name:10} gamma={gamma} sat={sat_boost}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('names', nargs='+')
    ap.add_argument('--gamma', type=float, default=0.78)
    ap.add_argument('--sat', type=float, default=1.05)
    a = ap.parse_args()
    for n in a.names:
        tune(n, a.gamma, a.sat)

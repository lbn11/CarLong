#!/usr/bin/env python3
"""
车模后处理：补上去背算法切成筛子的浅色主体。

## 为什么需要

`remove_bg.py` 用「与背景色的色距」判定透明度。这对**浅色/白色主体**是结构性
失效的：白色帆布、白色上层建筑、银色镀铬件与白底的 RGB 几乎相同，色距 < T1，
被整片判为背景 → alpha=0，只在有纹理/缝线的地方留下不透明的碎块。

第一版帆船（白帆）实测就是这个结果：帆成了「网格骨架」，在深色卡上是破帆。
换米色帆只是把问题往后推一点（米色离白 still 很近），所以真正要修的是算法。

## 做法

关键事实：`remove_bg.py` 把判为背景的像素设置成 `(r, g, b, 0)`——**RGB 保留**。
所以被吃掉的帆还能救回来。

1. **内部空洞回填**：从画布四边对 `alpha == 0` 的像素做 flood fill，标记出真正
   的「外部背景」。剩下那些 `alpha == 0` 却不是外部背景的像素 = 被主体包围的
   空洞（帆布中心、座舱内侧），把这些像素的 alpha 恢复成 255。
   - 只填**封闭**的洞：帆与桅杆之间真正通到外面的缝隙仍保持透明。
   - 排除 `(0,0,0,0)`：那是 `remove_bg.py` 主动涂掉的水印区，不能填成黑块。
2. **丢弃游离碎块**：保留最大连通域 + 面积 ≥ 最大 3% 的次级连通域，
   删掉其余的孤立噪点（直升机的杂点就是这样来的）。

用法：
    python3 tool/polish_sprites.py sailboat helicopter [more...]
"""
import sys
from collections import deque

from PIL import Image

VEHICLE_DIR = 'assets/vehicles'
MIN_KEEP_RATIO = 0.03   # 次级连通域至少要有最大块的 3% 才保留


def _components(img, thresh=8):
    """8 邻接连通域（只看 alpha > thresh 的像素），返回像素列表的列表。"""
    w, h = img.size
    px = img.load()
    seen = [[False] * h for _ in range(w)]
    comps = []
    for x0 in range(w):
        for y0 in range(h):
            if seen[x0][y0] or px[x0, y0][3] <= thresh:
                continue
            q = deque([(x0, y0)])
            seen[x0][y0] = True
            blob = []
            while q:
                x, y = q.popleft()
                blob.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if (0 <= nx < w and 0 <= ny < h
                                and not seen[nx][ny] and px[nx, ny][3] > thresh):
                            seen[nx][ny] = True
                            q.append((nx, ny))
            comps.append(blob)
    return comps


def fill_interior_holes(img):
    """把被主体包住的透明像素恢复成不透明（救回被吃掉的浅色区域）。"""
    w, h = img.size
    px = img.load()
    outside = [[False] * h for _ in range(w)]
    q = deque()

    def seed(x, y):
        if px[x, y][3] == 0 and not outside[x][y]:
            outside[x][y] = True
            q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not outside[nx][ny] \
                    and px[nx, ny][3] == 0:
                outside[nx][ny] = True
                q.append((nx, ny))

    filled = 0
    for x in range(w):
        for y in range(h):
            if px[x, y][3] == 0 and not outside[x][y]:
                r, g, b, _ = px[x, y]
                if r + g + b > 8:          # (0,0,0,0) 是水印区，跳过
                    px[x, y] = (r, g, b, 255)
                    filled += 1
    return filled


def drop_stray_blobs(img):
    """删掉与主体不相连的游离碎块（去背残留的噪点、被切断的零件反光）。"""
    comps = _components(img)
    if not comps:
        return 0
    comps.sort(key=len, reverse=True)
    biggest = len(comps[0])
    keep = {i for i, c in enumerate(comps) if len(c) >= biggest * MIN_KEEP_RATIO}
    px = img.load()
    dropped = 0
    for i, c in enumerate(comps):
        if i in keep:
            continue
        for x, y in c:
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)
        dropped += len(c)
    return dropped


def polish(name):
    path = f'{VEHICLE_DIR}/{name}.png'
    img = Image.open(path).convert('RGBA')
    filled = fill_interior_holes(img)
    dropped = drop_stray_blobs(img)
    img.save(path, optimize=True)
    print(f'  {name:11} holes_filled={filled:6}  stray_px={dropped:5}')


if __name__ == '__main__':
    names = sys.argv[1:]
    if not names:
        print('usage: polish_sprites.py <name> [name...]')
        sys.exit(1)
    print(f'=== polishing {len(names)} sprite(s) ===')
    for n in names:
        polish(n)
    print('=== done ===')

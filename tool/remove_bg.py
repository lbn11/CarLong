import os, glob, math
from collections import deque
from PIL import Image, ImageFilter, ImageChops

SRC = "generated-images"
DST = "assets/vehicles"
PAD = 0.05  # 裁剪留白比例，给精致车模留足呼吸空间
WMARK_W, WMARK_H = 220, 100  # ImageGen 右下角水印大致区域(放大覆盖 AI生成/WorkBuddy 水印)

# (源文件名前缀, 目标车型名)。prompt 必须以该前缀开头，确保 ImageGen 文件名唯一。
# V2：换为侧光（左水平射来，顶面在阴影里，不要 rim light）。
MAP = [
    ("BIKE_SIDE2_", "bike"),
    ("SCOOTER_SIDE2_", "scooter"),
    ("CAR_SIDE2_", "car"),
    ("TAXI_SIDE2_", "taxi"),
    ("BUS_SIDE2_", "bus"),
    ("TRUCK_SIDE2_", "truck"),
    ("TRAIN_SIDE2_", "train"),
    ("ROCKET_SIDE2_", "rocket"),
    ("TANKER_SIDE2_", "tanker"),
    ("METRO_SIDE2_", "metro"),
    ("PLANE_SIDE2_", "plane"),
    ("JET_SIDE2_", "jet"),
    ("SHUTTLE_SIDE2_", "shuttle"),
    ("UFO_SIDE2_", "ufo"),
    ("MAGLEV_SIDE2_", "maglev"),
    ("STATION_SIDE2_", "station"),
    ("COMET_SIDE2_", "comet"),
]

# 较宽的羽化带：让边缘过渡更平滑，减少锯齿感。
T1 = 16   # 低于此距离：完全透明
T2 = 130  # 高于此距离：不透明（中间为半透明羽化，保留接触阴影）
ALPHA_THRESHOLD = 30  # 参与连通区域计算的最低 alpha


def sample_bg(img):
    """背景色采样。取边缘最亮 1/3 像素的中位数——对渐变背景(灰底带高光)鲁棒,
    抗单点高光反射。经 V3 实测 17 款车效果稳定,作为主方案。
    """
    w, h = img.size
    pts = []
    for x in range(0, w, max(1, w // 10)):
        pts.append((x, 4)); pts.append((x, h - 5))
    for y in range(0, h, max(1, h // 10)):
        pts.append((4, y)); pts.append((w - 5, y))
    cols = [img.getpixel((x, y))[:3] for (x, y) in pts]
    cols.sort(key=lambda c: -(c[0] + c[1] + c[2]))   # 降序: 最亮在前
    top = cols[:max(1, len(cols) // 3)]               # 最亮 1/3
    top.sort()
    return top[len(top) // 2]


def dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def trim_corner_residues(img, threshold=200):
    """去除裁剪后四个角上残留的渐变背景小方块:
    对每条边(顶/底/左/右)向内最多 `threshold` 像素,若该行/列的所有像素 alpha 都 < 128,
    则把这条边以内的相应区域 alpha 强制设为 0(角落小块残留),但若该行/列的
    主要内容(alpha>128)超过一半,说明主体延伸到这里,跳过不处理。
    """
    w, h = img.size
    px = img.load()
    # 顶/底: 扫描从上往下 / 从下往上,直到遇到一行 alpha>128 像素超过一半
    def scan_row(y):
        cnt = sum(1 for x in range(w) if px[x, y][3] > 128)
        return cnt > w // 2
    # 底/顶
    for y in range(h - 1, -1, -1):
        if scan_row(y):
            # 把 y 以上的所有像素(若 alpha<128)设为 0
            for yy in range(0, y):
                for x in range(w):
                    if px[x, yy][3] < 128:
                        r, g, b, _ = px[x, yy]
                        px[x, yy] = (r, g, b, 0)
            break
    for y in range(h):
        if scan_row(y):
            for yy in range(y + 1, h):
                for x in range(w):
                    if px[x, yy][3] < 128:
                        r, g, b, _ = px[x, yy]
                        px[x, yy] = (r, g, b, 0)
            break
    # 左/右
    for x in range(w):
        cnt = sum(1 for y in range(h) if px[x, y][3] > 128)
        if cnt > h // 2:
            for xx in range(0, x):
                for y in range(h):
                    if px[xx, y][3] < 128:
                        r, g, b, _ = px[xx, y]
                        px[xx, y] = (r, g, b, 0)
            break
    for x in range(w - 1, -1, -1):
        cnt = sum(1 for y in range(h) if px[x, y][3] > 128)
        if cnt > h // 2:
            for xx in range(x + 1, w):
                for y in range(h):
                    if px[xx, y][3] < 128:
                        r, g, b, _ = px[xx, y]
                        px[xx, y] = (r, g, b, 0)
            break
    return img


def dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def remove_gray_floor(img):
    """去除 SIDE 渲染带的摄影棚灰底:底部 50% 区域内,凡是低饱和(sat<18)
    且中等亮度(100<lum<220)的像素一律视为灰底,alpha 置 0。车身为饱和色不命中,
    暗色接触阴影(lum<100)与高光(lum>=220)保留。"""
    w, h = img.size
    px = img.load()
    y_start = int(h * 0.50)
    for y in range(y_start, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            sat = mx - mn
            lum = (r + g + b) // 3
            if sat < 18 and 100 < lum < 220:
                px[x, y] = (r, g, b, 0)
    return img


def keep_significant_blobs(img, min_area=40):
    """删除面积极小的孤岛噪点（< 40 像素），保留所有较大连通域，避免细结构被误删。"""
    w, h = img.size
    px = img.load()
    mask = [[False] * h for _ in range(w)]
    for x in range(w):
        for y in range(h):
            mask[x][y] = px[x, y][3] > ALPHA_THRESHOLD

    seen = [[False] * h for _ in range(w)]
    keep = set()
    for x in range(w):
        for y in range(h):
            if not mask[x][y] or seen[x][y]:
                continue
            blob = []
            q = deque([(x, y)])
            seen[x][y] = True
            while q:
                cx, cy = q.popleft()
                blob.append((cx, cy))
                nx = cx + 1
                if nx < w and mask[nx][cy] and not seen[nx][cy]:
                    seen[nx][cy] = True; q.append((nx, cy))
                nx = cx - 1
                if nx >= 0 and mask[nx][cy] and not seen[nx][cy]:
                    seen[nx][cy] = True; q.append((nx, cy))
                ny = cy + 1
                if ny < h and mask[cx][ny] and not seen[cx][ny]:
                    seen[cx][ny] = True; q.append((cx, ny))
                ny = cy - 1
                if ny >= 0 and mask[cx][ny] and not seen[cx][ny]:
                    seen[cx][ny] = True; q.append((cx, ny))
            if len(blob) >= min_area:
                keep.update(blob)

    for x in range(w):
        for y in range(h):
            if (x, y) not in keep:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return img


def brighten(img, gamma=0.58, sat_boost=1.15):
    """对 RGB 通道做 gamma 校正(<1 = 提亮),让 SIDE 渲染的偏暗车模在深色卡上
    更清晰可读;并轻度提饱和,防止 gamma 拉平后颜色发灰。暗部提得多、亮部几乎
    不变,保留侧光结构(左侧亮、右侧暗、顶面在阴影)。不动 alpha。"""
    from PIL import ImageEnhance
    r, g, b, a = img.split()
    lut = [min(255, int((i / 255.0) ** gamma * 255)) for i in range(256)]
    r = r.point(lut)
    g = g.point(lut)
    b = b.point(lut)
    img = Image.merge("RGBA", (r, g, b, a))
    if sat_boost != 1.0:
        img = ImageEnhance.Color(img).enhance(sat_boost)
    return img


def clean_edges(img):
    """
    去除边缘亮圈：同时消除 (a) 去背残留的浅色 halo 与 (b) 车模渲染自带的菲涅耳/轮廓光(rim light)。
    这两者都是「比车身本色更亮」的一圈额外亮光，在深色卡片上显白、令车模像浮起。

    做法：把实心主体(alpha>230)的颜色做形态学膨胀覆盖到整个边缘，再对每个像素取
    min(原色, 膨胀主体色)——即把「超出车身本色的那部分亮度」压掉，保留暗部与车身本色：
      · 菲涅耳/rim 纯白(255) → 压到车身本色(如 200)，超额白光消失；
      · 亮色车身的真实边缘(本身≈车身本色) → 不受影响，仍为车身色而非被染得更亮；
      · 内部实心区膨胀色=自身 → min=自身，细节零损失（已用 innerLum 验证）。
    背景 halo 残留会被压向黑，叠加在低 alpha 上在深色卡片上≈透明，远优于白边。
    """
    r, g, b, a = img.split()
    solid = a.point(lambda v: 255 if v > 230 else 0)
    rs = ImageChops.multiply(r, solid)
    gs = ImageChops.multiply(g, solid)
    bs = ImageChops.multiply(b, solid)
    for _ in range(7):
        rs = rs.filter(ImageFilter.MaxFilter(3))
        gs = gs.filter(ImageFilter.MaxFilter(3))
        bs = bs.filter(ImageFilter.MaxFilter(3))

    def mn(c, cs):
        d = ImageChops.subtract(c, cs)        # c - cs，负值截断为 0
        return ImageChops.subtract(c, d)      # c - max(0, c-cs) = min(c, cs)

    new_r, new_g, new_b = mn(r, rs), mn(g, gs), mn(b, bs)
    return Image.merge("RGBA", (new_r, new_g, new_b, a))


def smooth_alpha(img, radius=0.6):
    """对 alpha 通道做轻微高斯模糊，让边缘更柔和、减少锯齿感。"""
    r, g, b, a = img.split()
    a = a.filter(ImageFilter.GaussianBlur(radius=radius))
    a = a.point(lambda v: 0 if v < 4 else v)
    return Image.merge("RGBA", (r, g, b, a))


# ---------- 主抠图：仅对存在源图的车型重抠 ----------
for frag, name in MAP:
    matches = glob.glob(os.path.join(SRC, frag + "*.png"))
    if not matches:
        continue  # 无源图：保留现存的已去背 PNG，稍后统一做边缘修边
    src = matches[0]
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    bg = sample_bg(im)
    px = im.load()
    trans = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = dist((r, g, b), bg)
            if d < T1:
                px[x, y] = (r, g, b, 0)
                trans += 1
            elif d < T2:
                px[x, y] = (r, g, b, int(255 * (d - T1) / (T2 - T1)))
                trans += 1
    # 1) 色距之后清掉 ImageGen 右下角水印:深色水印文字离白底很远,会被色距当成车身
    #    强行保留,所以必须后置清;RGB 直接涂成 0,这样后续 clean_edges 即使把
    #    临近车身色"涂"进来,min(0, 车身色) 也仍是 0,水印区彻底变透明黑。
    for y in range(max(0, h - WMARK_H), h):
        for x in range(max(0, w - WMARK_W), w):
            px[x, y] = (0, 0, 0, 0)

    im = keep_significant_blobs(im)
    im = smooth_alpha(im, radius=0.6)
    im = trim_corner_residues(im)
    im = remove_gray_floor(im)

    # 裁剪到非透明包围盒
    bbox = im.getbbox()
    if bbox:
        pw, ph = w * PAD, h * PAD
        x0 = max(0, bbox[0] - int(pw))
        y0 = max(0, bbox[1] - int(ph))
        x1 = min(w, bbox[2] + int(pw))
        y1 = min(h, bbox[3] + int(ph))
        im = im.crop((x0, y0, x1, y1))

    out = os.path.join(DST, name + ".png")
    im.save(out)
    print(f"REGEN {name:8} <- {os.path.basename(src)[:36]}  transparent={trans * 100 // (w * h)}% size={im.size}")

# ---------- 统一边缘修边：覆盖全部 17 款（含缺源图的前 10 款二次修边） ----------
for frag, name in MAP:
    path = os.path.join(DST, name + ".png")
    if not os.path.exists(path):
        continue
    im = Image.open(path).convert("RGBA")
    im = clean_edges(im)
    im = brighten(im)
    im.save(path)
    print(f"EDGE  {name:8}")

import os, glob, math
from collections import deque
from PIL import Image, ImageFilter

SRC = "generated-images"
DST = "assets/vehicles"
PAD = 0.05  # 裁剪留白比例，给精致车模留足呼吸空间

# (源文件名前缀, 目标车型名)。prompt 必须以该前缀开头，确保 ImageGen 文件名唯一。
MAP = [
    ("BIKE_refined_", "bike"),
    ("SCOOTER_refined_", "scooter"),
    ("CAR_refined_", "car"),
    ("TAXI_refined_", "taxi"),
    ("BUS_refined_", "bus"),
    ("TRUCK_refined_", "truck"),
    ("TRAIN_refined_", "train"),
    ("ROCKET_refined_", "rocket"),
    ("TANKER_refined_", "tanker"),
    ("METRO_refined_", "metro"),
    ("PLANE_v2_", "plane"),
    ("JET_v4_", "jet"),
    ("SHUTTLE_v2_", "shuttle"),
    ("UFO_v2_", "ufo"),
    ("MAGLEV_v2_", "maglev"),
    ("STATION_v2_", "station"),
    ("COMET_v2_", "comet"),
]

T1 = 22   # 低于此距离：完全透明
T2 = 90   # 高于此距离：不透明（中间为半透明羽化，保留接触阴影）
ALPHA_THRESHOLD = 25  # 参与连通区域计算的最低 alpha


def sample_bg(img):
    """从图像边缘采样背景色，避开中心主体区域。"""
    w, h = img.size
    pts = [(4, 4), (w - 5, 4), (4, h - 5), (w - 5, h - 5),
           (w // 2, 4), (w // 2, h - 5), (4, h // 2), (w - 5, h // 2),
           (w // 4, 4), (w * 3 // 4, 4), (4, h // 4), (w - 5, h // 4),
           (w // 4, h - 5), (w * 3 // 4, h - 5), (w - 5, h * 3 // 4), (4, h * 3 // 4)]
    cols = []
    for (x, y) in pts:
        cols.append(img.getpixel((x, y))[:3])
    cols.sort()
    return cols[len(cols) // 2]  # 中位数，抗单点异常


def dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def keep_largest_blob(img):
    """只保留最大的非透明连通区域，去除水印/噪点等小块。"""
    w, h = img.size
    px = img.load()
    mask = [[False] * h for _ in range(w)]
    for x in range(w):
        for y in range(h):
            mask[x][y] = px[x, y][3] > ALPHA_THRESHOLD

    seen = [[False] * h for _ in range(w)]
    largest = []
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
            if len(blob) > len(largest):
                largest = blob

    if not largest:
        return img

    keep = set(largest)
    for x in range(w):
        for y in range(h):
            if (x, y) not in keep:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return img


def clean_weak_bg_pixels(img, bg, max_alpha=100, max_dist=T2):
    """清理颜色接近背景但 alpha 较低的像素，打断背景与主体之间的半透明桥接。"""
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if 0 < a <= max_alpha and dist((r, g, b), bg) < max_dist:
                px[x, y] = (r, g, b, 0)
    return img


def smooth_alpha(img, radius=0.6):
    """对 alpha 通道做轻微高斯模糊，让边缘更柔和、减少锯齿感。"""
    r, g, b, a = img.split()
    a = a.filter(ImageFilter.GaussianBlur(radius=radius))
    # 去除极弱alpha，避免边缘灰雾
    a = a.point(lambda v: 0 if v < 10 else v)
    return Image.merge("RGBA", (r, g, b, a))


for frag, name in MAP:
    matches = glob.glob(os.path.join(SRC, frag + "*.png"))
    if not matches:
        print("MISS", name)
        continue
    src = matches[0]
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    bg = sample_bg(im)
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

    im = clean_weak_bg_pixels(im, bg)
    im = keep_largest_blob(im)
    im = smooth_alpha(im, radius=0.5)

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
    print(f"OK {name:8} <- {os.path.basename(src)[:40]}  bg={bg} transparent={trans * 100 // (w * h)}% size={im.size}")

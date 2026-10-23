#!/usr/bin/env python3
"""身份证正反面合成一个文件 —— 给「只允许上传一张」的验证界用。

背景：Google Payments / AdMob 的身份验证上传框有时只给一个槽位，
而中国身份证需要正反两面。合成单页 PDF 比 JPG 更像一次扫描，优先用 PDF。

用法：
    python3 tool/merge_id_card.py front.jpg back.jpg
    python3 tool/merge_id_card.py front.jpg back.jpg -o id_card.pdf
    python3 tool/merge_id_card.py front.jpg back.jpg --layout side   # 左右拼
    python3 tool/merge_id_card.py front.jpg back.jpg --max-mb 3.5

规则（重要）：只做「排列」，不做裁剪、提亮、去背景、加水印、加文字标注。
Google 明确把「被编辑过的证件」列为不可接受文件，任何标注都会拉长审核。
"""

from __future__ import annotations

import argparse
import io
import os
import sys

from PIL import Image, ImageOps

# A4 @ 300dpi。PDF 模式把内容居中放进去，看起来就像一次整页扫描。
A4 = (2480, 3508)
DEFAULT_TARGET_W = 2200  # 单张统一到的宽度；再宽对 OCR 没增益，只是变重
GAP = 80  # 上下两图之间的白缝
MARGIN = 60  # 画布内边距


def load_rgb(path: str) -> Image.Image:
    """读图 → 按 EXIF 摆正 → 去 alpha（铺白底）。不做任何增强。"""
    try:
        im = Image.open(path)
    except FileNotFoundError:
        sys.exit(f"[x] 找不到文件：{path}")
    except Exception as e:  # HEIC 常见
        if str(path).lower().endswith((".heic", ".heif")):
            sys.exit(
                f"[x] 读不了 HEIC：{path}\n"
                f"    先在终端转成 JPG：sips -s format jpeg '{path}' --out '{path}.jpg'"
            )
        sys.exit(f"[x] 打开失败：{path}（{e}）")

    im = ImageOps.exif_transpose(im)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.split()[-1])
        return bg
    return im.convert("RGB")


def fit_width(im: Image.Image, width: int) -> Image.Image:
    if im.width == width:
        return im
    h = round(im.height * width / im.width)
    return im.resize((width, h), Image.LANCZOS)


def merge_vertical(front: Image.Image, back: Image.Image) -> Image.Image:
    w = min(front.width, back.width)
    front, back = fit_width(front, w), fit_width(back, w)
    canvas = Image.new(
        "RGB", (w + MARGIN * 2, front.height + back.height + GAP + MARGIN * 2), (255, 255, 255)
    )
    canvas.paste(front, (MARGIN, MARGIN))
    canvas.paste(back, (MARGIN, MARGIN + front.height + GAP))
    return canvas


def merge_side(front: Image.Image, back: Image.Image) -> Image.Image:
    h = min(front.height, back.height)
    front = fit_width(front, round(front.width * h / front.height))
    back = fit_width(back, round(back.width * h / back.height))
    canvas = Image.new(
        "RGB", (front.width + back.width + GAP + MARGIN * 2, h + MARGIN * 2), (255, 255, 255)
    )
    canvas.paste(front, (MARGIN, MARGIN))
    canvas.paste(back, (MARGIN + front.width + GAP, MARGIN))
    return canvas


def to_a4(content: Image.Image) -> Image.Image:
    """等比塞进 A4 居中，四周留白。"""
    scale = min(
        (A4[0] - MARGIN * 2) / content.width, (A4[1] - MARGIN * 2) / content.height
    )
    if scale < 1:
        content = content.resize(
            (round(content.width * scale), round(content.height * scale)), Image.LANCZOS
        )
    page = Image.new("RGB", A4, (255, 255, 255))
    page.paste(
        content, ((A4[0] - content.width) // 2, (A4[1] - content.height) // 2)
    )
    return page


def write_limited(img: Image.Image, out: str, max_bytes: int, as_pdf: bool) -> tuple[int, int]:
    """在体积上限内落盘：先降 quality，再缩尺寸。返回 (quality, 实际字节)。"""
    work = img
    for round_ in range(4):
        for q in (92, 86, 80, 72, 64, 56):
            buf = io.BytesIO()
            if as_pdf:
                work.save(buf, "PDF", resolution=300.0, quality=q)
            else:
                work.save(buf, "JPEG", quality=q, optimize=True, progressive=True)
            if buf.tell() <= max_bytes:
                with open(out, "wb") as f:
                    f.write(buf.getvalue())
                return q, buf.tell()
        if round_ == 0:
            print(f"[!] {max_bytes/1e6:.1f}MB 内压不下去，等比缩小 15% 重试")
        work = work.resize((round(work.width * 0.85), round(work.height * 0.85)), Image.LANCZOS)
    sys.exit("[x] 无法压到目标体积，用 --max-mb 放宽上限")


def main() -> None:
    ap = argparse.ArgumentParser(description="身份证正反面合成单个文件")
    ap.add_argument("front", help="人像面（有照片、姓名、身份证号的那面）")
    ap.add_argument("back", help="国徽面（有签发机关、有效期限的那面）")
    ap.add_argument("-o", "--out", default=None, help="输出路径，默认 id_card_merged.pdf")
    ap.add_argument(
        "--layout", choices=("vertical", "side"), default="vertical", help="排列方式"
    )
    ap.add_argument("--width", type=int, default=DEFAULT_TARGET_W, help="单张统一宽度（px）")
    ap.add_argument("--max-mb", type=float, default=3.5, help="体积上限（MB），留 0.5MB 余量")
    ap.add_argument("--jpg", action="store_true", help="输出 JPG 而不是 PDF")
    args = ap.parse_args()

    as_pdf = not args.jpg
    out = args.out or ("id_card_merged.jpg" if args.jpg else "id_card_merged.pdf")

    front, back = load_rgb(args.front), load_rgb(args.back)
    print(f"    人像面 {front.width}x{front.height}  国徽面 {back.width}x{back.height}")

    front, back = fit_width(front, args.width), fit_width(back, args.width)
    merged = (
        merge_vertical(front, back) if args.layout == "vertical" else merge_side(front, back)
    )
    if as_pdf:
        merged = to_a4(merged)

    q, size = write_limited(merged, out, int(args.max_mb * 1e6), as_pdf)
    full = os.path.abspath(out)
    print(
        f"[ok] {full}\n"
        f"     {merged.width}x{merged.height}  {size/1e6:.2f}MB  quality={q}  "
        f"{'PDF/A4' if as_pdf else 'JPG'}"
    )
    print(f"     在 Finder 里定位：open -R '{full}'")
    print(f"     来源：{os.path.basename(args.front)} + {os.path.basename(args.back)}")


if __name__ == "__main__":
    main()

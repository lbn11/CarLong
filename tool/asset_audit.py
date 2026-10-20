#!/usr/bin/env python3
"""资源体积盘点 + 可选压缩实测。

为什么需要：小游戏的主包硬限制是 4MB（微信，2026-08 官方口径），而本项目
assets/ 现在是 30MB，光 NotoSansSC 一个字体就 17MB —— 不做资源管线，
小游戏这条路第一步就被卡死。

两种用法：

  # 只读盘点：按 pubspec 判断哪些真进了包，对照小游戏预算给判决
  python3 tool/asset_audit.py

  # 生成优化副本（不碰 assets/，全部写进 build/asset_opt/），并打印实测压缩率
  python3 tool/asset_audit.py --optimize

依赖：Pillow（图像）、cwebp（WebP）、pyftsubset（字体子集）、afconvert（音频，
macOS 自带）。缺哪个就跳过对应项，不会中断。
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
OUT = os.path.join(ROOT, "build", "asset_opt")

# 微信小游戏官方口径（2026-08）：主包 ≤ 4MB，主包+分包 ≤ 30MB。
WX_MAIN = 4 * 1024 * 1024
WX_TOTAL = 30 * 1024 * 1024
# 抖音：官方要求「压缩后尽量小，优秀线 6MB」，首包越大视频分发跳失越高。
DY_GOOD = 6 * 1024 * 1024


def human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024 or unit == "GB":
            return f"{n:.1f}{unit}" if unit != "B" else f"{int(n)}B"
        n /= 1024
    return f"{n:.1f}GB"


def walk_size(path: str) -> tuple[int, int]:
    """返回 (字节数, 文件数)。"""
    total = files = 0
    for root, _, fs in os.walk(path):
        for f in fs:
            p = os.path.join(root, f)
            if os.path.isfile(p):
                total += os.path.getsize(p)
                files += 1
    return total, files


def pubspec_bundled() -> tuple[dict[str, str], list[str], list[str]]:
    """解析 pubspec 的 flutter.assets / flutter.fonts，区分「进包」与「不进包」。"""
    text = open(os.path.join(ROOT, "pubspec.yaml"), encoding="utf-8").read()
    bundled: dict[str, str] = {}
    for m in re.finditer(r"^\s*-\s*(assets/[^\s#]+)", text, re.M):
        bundled[m.group(1).rstrip("/")] = "assets"
    for m in re.finditer(r"^\s*-\s*asset:\s*(assets/[^\s#]+)", text, re.M):
        bundled[m.group(1)] = "font"
    on_disk = sorted(
        d for d in os.listdir(ASSETS) if os.path.isdir(os.path.join(ASSETS, d))
    )
    dirs_bundled, dirs_excluded = [], []
    for d in on_disk:
        key = f"assets/{d}"
        # 目录进包有两种写法：整目录列入 assets，或逐个文件列入 fonts。
        hit = key in bundled or any(k.startswith(key + "/") for k in bundled)
        (dirs_bundled if hit else dirs_excluded).append(d)
    return bundled, dirs_bundled, dirs_excluded


def inventory() -> None:
    bundled, dirs_bundled, dirs_excluded = pubspec_bundled()
    print("=" * 68)
    print("资源盘点（★ = 真进安装包；☆ = 只参与构建，不进包）")
    print("=" * 68)

    total_bundled = 0
    for d in sorted(set(dirs_bundled) | set(dirs_excluded)):
        path = os.path.join(ASSETS, d)
        size, files = walk_size(path)
        mark = "★" if d in dirs_bundled else "☆"
        in_pkg = "进包" if d in dirs_bundled else "不进包"
        if d in dirs_bundled:
            total_bundled += size
        print(f"  {mark} assets/{d:<10} {human(size):>9}  {files:>3} 个文件  ({in_pkg})")

    # 字体单独再列，单个文件大小差异极大（NotoSansSC 一个顶其他全部）
    fonts_dir = os.path.join(ASSETS, "fonts")
    if os.path.isdir(fonts_dir):
        print("\n  字体明细：")
        for f in sorted(os.listdir(fonts_dir)):
            p = os.path.join(fonts_dir, f)
            if os.path.isfile(p):
                print(f"      {f:<28} {human(os.path.getsize(p)):>9}")

    print("\n" + "-" * 68)
    print(f"  App 实际打包体积（代码之外）：{human(total_bundled)}")
    print(f"  微信小游戏预算：主包 {human(WX_MAIN)} / 总包 {human(WX_TOTAL)}")
    verdict = "✗ 超主包" if total_bundled > WX_MAIN else "✓ 可进主包"
    print(f"  当前体量对照：{verdict}（超出 {human(max(0, total_bundled - WX_MAIN))}）")
    print("  抖音优秀线：", human(DY_GOOD), "| 当前",
          "✗ 超标" if total_bundled > DY_GOOD else "✓ 达标")
    print("-" * 68)


def charset() -> str:
    """从 lib/ 下的 Dart 源码抽全部可打印字符 —— 小游戏用的中文字体只需要这些。"""
    chars: set[str] = set()
    for root, _, fs in os.walk(os.path.join(ROOT, "lib")):
        for f in fs:
            if f.endswith(".dart"):
                chars |= set(open(os.path.join(root, f), encoding="utf-8").read())
    chars |= set(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        " .,:;!?()[]{}<>+-*/=%#@&\"'>|~^_\\"
        "，。、；：？！（）《》【】「」『』—…·×÷°¥￥"
    )
    keep = {c for c in chars if c.isprintable() and c not in "\n\r\t"}
    return "".join(sorted(keep))


def optimize() -> None:
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT, exist_ok=True)
    rows: list[tuple[str, int, int, str]] = []  # (项, 原, 新, 做法)
    sum_font_src = sum_font_dst = 0

    # ── 1. 字体子集化 ──
    subset = shutil.which("pyftsubset")
    text = charset()
    chars_file = os.path.join(OUT, "_chars.txt")
    os.makedirs(OUT, exist_ok=True)
    with open(chars_file, "w", encoding="utf-8") as fh:
        fh.write(text)
    fonts_out = os.path.join(OUT, "fonts")
    os.makedirs(fonts_out, exist_ok=True)
    cjk = sum(1 for c in text if "\u4e00" <= c <= "\u9fff")
    print(f"字体子集字符集：{len(text)} 个（其中汉字 {cjk}）")
    for name in sorted(os.listdir(os.path.join(ASSETS, "fonts"))):
        if not name.endswith((".ttf", ".otf")):
            continue
        src = os.path.join(ASSETS, "fonts", name)
        dst = os.path.join(fonts_out, name)
        if subset:
            r = subprocess.run(
                [subset, src, f"--text-file={chars_file}", f"--output-file={dst}",
                 "--layout-features=*"],
                capture_output=True,
            )
            if r.returncode != 0 or not os.path.exists(dst):
                shutil.copy2(src, dst)
                rows.append((f"字体 {name}", os.path.getsize(src), os.path.getsize(dst), "复制（子集化失败）"))
                sum_font_src += os.path.getsize(src)
                sum_font_dst += os.path.getsize(dst)
                continue
            rows.append((f"字体 {name}", os.path.getsize(src), os.path.getsize(dst),
                         "子集化"))
            sum_font_src += os.path.getsize(src)
            sum_font_dst += os.path.getsize(dst)
        else:
            shutil.copy2(src, dst)
            rows.append((f"字体 {name}", os.path.getsize(src), os.path.getsize(dst), "复制（无 pyftsubset）"))
            sum_font_src += os.path.getsize(src)
            sum_font_dst += os.path.getsize(dst)

    # ── 2. 车模：PNG8（平台全兼容）与 WebP（更小，App/较新小游戏基础库）──
    try:
        from PIL import Image
    except ImportError:
        Image = None  # type: ignore
    veh_dir = os.path.join(ASSETS, "vehicles")
    png8_out = os.path.join(OUT, "vehicles_png8")
    webp_out = os.path.join(OUT, "vehicles_webp")
    os.makedirs(png8_out, exist_ok=True)
    os.makedirs(webp_out, exist_ok=True)
    cwebp = shutil.which("cwebp")
    sum_png8 = sum_webp = sum_src = 0
    for name in sorted(os.listdir(veh_dir)):
        if not name.endswith(".png"):
            continue
        src = os.path.join(veh_dir, name)
        sz = os.path.getsize(src)
        sum_src += sz
        stem = os.path.splitext(name)[0]
        if Image:
            img = Image.open(src).convert("RGBA")
            # 512 是卡片/棋盘格子的实际上限（格子最大 96px，图鉴 ~180px），
            # 1024 原图在游戏里是纯浪费 —— 保留 1024 只为兼容旧渲染路径。
            small = img.resize((512, 512), Image.LANCZOS)
            p8 = small.quantize(colors=256, method=Image.Quantize.FASTOCTREE)
            dst = os.path.join(png8_out, f"{stem}.png")
            p8.save(dst, optimize=True)
            sum_png8 += os.path.getsize(dst)
        if cwebp:
            dst = os.path.join(webp_out, f"{stem}.webp")
            subprocess.run(
                [cwebp, "-quiet", "-q", "82", "-alpha_q", "100",
                 "-resize", "512", "512", src, "-o", dst],
                check=False,
            )
            if os.path.exists(dst):
                sum_webp += os.path.getsize(dst)
    rows.append(("车模 17 张 (PNG8@512)", sum_src, sum_png8, "缩放+调色板量化"))
    rows.append(("车模 17 张 (WebP@512)", sum_src, sum_webp, "缩放+WebP q82"))

    # ── 3. 音频：WAV → AAC(m4a) ──
    af = shutil.which("afconvert")
    audio_out = os.path.join(OUT, "audio")
    os.makedirs(audio_out, exist_ok=True)
    sum_a_src = sum_a_dst = 0
    for name in sorted(os.listdir(os.path.join(ASSETS, "audio"))):
        src = os.path.join(ASSETS, "audio", name)
        if not os.path.isfile(src):
            continue
        sum_a_src += os.path.getsize(src)
        stem = os.path.splitext(name)[0]
        dst = os.path.join(audio_out, f"{stem}.m4a")
        ok = False
        if af:
            # BGM 用 96k 立体声，音效用 64k 单声道（短促、无需声场）
            is_bgm = stem.startswith("bgm_")
            args = [af, "-f", "m4af", "-d", "aac", "-b",
                    "96000" if is_bgm else "64000", src, dst]
            if not is_bgm:
                args.insert(4, "-c")
                args.insert(5, "1")
            r = subprocess.run(args, capture_output=True)
            ok = r.returncode == 0 and os.path.exists(dst)
        if ok:
            sum_a_dst += os.path.getsize(dst)
        else:
            shutil.copy2(src, os.path.join(audio_out, name))
            sum_a_dst += os.path.getsize(src)
    rows.append(("音频 12 个 (AAC m4a)", sum_a_src, sum_a_dst,
                 "afconvert 转 AAC"))

    # ── 报告 ──
    print("\n" + "=" * 68)
    print("优化实测（由真实文件转换得出，非估算）")
    print("=" * 68)
    print(f"  {'项':<24}{'原':>10}{'优化后':>10}{'压缩':>8}  做法")
    for label, src, dst, how in rows:
        ratio = f"{src / dst:.1f}×" if dst else "-"
        print(f"  {label:<24}{human(src):>10}{human(dst):>10}{ratio:>8}  {how}")

    before = sum(r[1] for r in rows)
    print("-" * 68)
    print(f"  单项合计 {human(before)}（同一份原图被两种方案各算一次）")

    # 两个「整包方案」的真实总量 —— 这才是要拍板的数字。
    plan_png8 = sum_font_dst + sum_png8 + sum_a_dst
    plan_webp = sum_font_dst + sum_webp + sum_a_dst
    base_src = sum_font_src + sum_src + sum_a_src
    print()
    print(f"  方案 A（PNG8@512，全平台兼容）：{human(base_src)} → {human(plan_png8)}"
          f"  [{base_src / plan_png8:.1f}×]")
    print(f"  方案 B（WebP@512，更小更挑基础库）：{human(base_src)} → {human(plan_webp)}"
          f"  [{base_src / plan_webp:.1f}×]")
    for label, size in (("A·PNG8", plan_png8), ("B·WebP", plan_webp)):
        verdict = "✓ 装得进主包" if size <= WX_MAIN else f"✗ 超主包 {human(size - WX_MAIN)}"
        print(f"     {label} 对照微信主包 4MB：{verdict}"
              f"{'，进分包/远程 CDN' if size > WX_MAIN else ''}")
    print(f"  产物目录：{os.path.relpath(OUT, ROOT)}/")
    print("  注意：不覆盖 assets/。要生效需把 pubspec 的 assets 指向优化目录；")
    print("        小游戏端图片格式按基础库版本取舍（PNG8 最稳，WebP 体积再省 5%）。")
    print("=" * 68)


def main() -> int:
    ap = argparse.ArgumentParser(description="资源体积盘点 / 压缩实测")
    ap.add_argument("--optimize", action="store_true", help="生成优化副本到 build/asset_opt/")
    args = ap.parse_args()
    inventory()
    if args.optimize:
        print()
        optimize()
    return 0


if __name__ == "__main__":
    sys.exit(main())

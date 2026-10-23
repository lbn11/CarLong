#!/usr/bin/env python3
"""上架前静态站体检：app-ads.txt / 占位符 / 本地链接 / 隐私政策必备条款。

这些是提审的硬门槛，出错不会让 App 崩，只会让「广告收入被劫持」或「商店审核打回」，
所以必须能在一条命令里查完。

用法：
    python3 tool/check_site.py             # 人类可读
    python3 tool/check_site.py --strict     # WARN 也算失败（部署前跑这个）
    python3 tool/check_site.py --site-dir other

退出码：0 全部通过；1 有 FAIL（或 --strict 下有 WARN）。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"

# AdMob 官方 cert authority，固定值，写错等于没写
GOOGLE_CERT = "f08c47fec0942fa0"

REQUIRED_FILES = [
    "index.html",
    "privacy.html",
    "support.html",
    "app-ads.txt",
    "robots.txt",
    "assets/style.css",
    "assets/site.js",
]

# 隐私政策必须出现的条款标记（少一条就可能被商店打回）
PRIVACY_MARKERS = [
    ("policies.google.com", "未链接 Google 隐私权政策"),
    ("advertising identifier", "未说明广告标识符（英文）"),
    ("广告标识符", "未说明广告标识符（中文）"),
    ("Last updated", "缺少最后更新日期（英文）"),
    ("最后更新", "缺少最后更新日期（中文）"),
    ("opt out", "未告知如何退出个性化广告（英文）"),
    ("mailto:", "没有可联系的邮箱"),
    ("CCPA", "未覆盖加州用户权利"),
    ("children", "未覆盖儿童条款（英文）"),
]

PLACEHOLDERS = ["YOUR_EMAIL", "example.com", "YOUR-DOMAIN", "TODO", "lorem"]

HREF_RE = re.compile(r'(?:href|src)="([^"]+)"')
EXTERNAL_ASSET_RE = re.compile(
    r'<(?:script[^>]*src|link[^>]*href)="https?://', re.IGNORECASE
)

results: list[tuple[str, str, str]] = []  # (level, name, detail)


def add(level: str, name: str, detail: str = "") -> None:
    results.append((level, name, detail))


def publisher_from_manifest() -> str | None:
    """从 AndroidManifest 里读 AdMob App ID 的 publisher 段。

    必须只认 `com.google.android.gms.ads.APPLICATION_ID` 的 value —— 注释里常留着
    「历史上这里是测试值 ca-app-pub-3940…」，直接全文正则会被注释命中，
    得出「publisher 不一致」的假警报（本脚本第一版就踩了）。
    """
    if not MANIFEST.exists():
        return None
    text = MANIFEST.read_text(encoding="utf-8")
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)  # 剥掉 XML 注释
    m = re.search(
        r'APPLICATION_ID"\s+android:value="ca-app-pub-(\d+)~\d+"', text
    )
    if m:
        return m.group(1)
    # 兜底：剥注释后全文第一个 App ID
    m = re.search(r"ca-app-pub-(\d+)~\d+", text)
    return m.group(1) if m else None


def check_files(site: Path) -> None:
    missing = [f for f in REQUIRED_FILES if not (site / f).exists()]
    if missing:
        add("FAIL", "必需文件", "缺失: " + ", ".join(missing))
    else:
        add("OK", "必需文件", f"{len(REQUIRED_FILES)} 个齐全")


def check_app_ads(site: Path) -> None:
    path = site / "app-ads.txt"
    if not path.exists():
        return
    raw = path.read_bytes()

    if raw.startswith(b"\xef\xbb\xbf"):
        add("FAIL", "app-ads.txt · BOM", "带 UTF-8 BOM，部分解析器会整行识别失败")
    elif b"\r" in raw:
        add("WARN", "app-ads.txt · 换行", "CRLF 换行，建议 LF")
    else:
        add("OK", "app-ads.txt · 编码", "无 BOM / LF")

    text = raw.decode("utf-8", errors="replace")
    data_lines = [
        ln.strip() for ln in text.splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    ]
    if not data_lines:
        add("FAIL", "app-ads.txt · 内容", "没有任何数据行")
        return

    expected_pub = publisher_from_manifest()
    if expected_pub is None:
        add("WARN", "app-ads.txt · 账号", "读不到 AndroidManifest 的 App ID，跳过一致性校验")
        expected_pub = None

    for idx, line in enumerate(data_lines, 1):
        fields = [f.strip() for f in line.split(",")]
        if len(fields) != 4:
            add("FAIL", f"app-ads.txt · 第 {idx} 行", f"字段数 {len(fields)}，应为 4")
            continue
        domain, pub, rel, cert = fields
        problems = []
        if domain != "google.com":
            problems.append(f"domain={domain}")
        if not pub.startswith("pub-"):
            problems.append(f"publisher={pub}")
        if expected_pub and pub != f"pub-{expected_pub}":
            problems.append(f"publisher 与 App ID 不一致（应为 pub-{expected_pub}）")
        if rel != "DIRECT":
            problems.append(f"relationship={rel}")
        if cert != GOOGLE_CERT:
            problems.append(f"cert={cert}")
        if problems:
            add("FAIL", f"app-ads.txt · 第 {idx} 行", "；".join(problems))
        else:
            add("OK", "app-ads.txt · 第 {0} 行".format(idx), f"{pub} / DIRECT / cert 正确")


def check_placeholders(site: Path) -> None:
    # 只扫真正会被访问的页面资源；README.md 里必然要写「占位符」这个词本身
    hits: list[str] = []
    for path in sorted(site.rglob("*")):
        if not path.is_file() or path.suffix not in {".html", ".css", ".js"}:
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for no, line in enumerate(lines, 1):
            for token in PLACEHOLDERS:
                if token in line:
                    hits.append(f"{path.relative_to(site)}:{no} 含 {token}")
                    break

    if hits:
        add("WARN", "待替换占位符", f"{len(hits)} 处：" + "；".join(hits[:4])
            + ("…" if len(hits) > 4 else ""))
    else:
        add("OK", "待替换占位符", "无")


def check_links(site: Path) -> None:
    broken: list[str] = []
    total = 0
    for path in sorted(site.glob("*.html")):
        text = path.read_text(encoding="utf-8")
        for raw in HREF_RE.findall(text):
            if raw.startswith(("http://", "https://", "mailto:", "tel:", "#", "data:")):
                continue
            target = raw.split("#")[0].split("?")[0]
            if not target:
                continue
            total += 1
            if not (path.parent / target).resolve().exists():
                broken.append(f"{path.name} → {raw}")
    if broken:
        add("FAIL", "本地链接", "；".join(broken))
    else:
        add("OK", "本地链接", f"{total} 条全部命中")


def check_privacy(site: Path) -> None:
    path = site / "privacy.html"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    missing = [desc for token, desc in PRIVACY_MARKERS if token not in text]
    if missing:
        add("FAIL", "隐私政策条款", "；".join(missing))
    else:
        add("OK", "隐私政策条款", f"{len(PRIVACY_MARKERS)} 项必备内容齐全")


def check_offline_assets(site: Path) -> None:
    """页面不能依赖外部 CDN：域名挂上去之前、或墙内打开时都要能正常显示。"""
    bad: list[str] = []
    for path in sorted(site.glob("*.html")):
        if EXTERNAL_ASSET_RE.search(path.read_text(encoding="utf-8")):
            bad.append(path.name)
    if bad:
        add("WARN", "外部静态资源", "引用了 CDN：" + ", ".join(bad) + "（离线/受限网络下会白页）")
    else:
        add("OK", "外部静态资源", "全部本地")


def main() -> int:
    ap = argparse.ArgumentParser(description="上架前静态站体检")
    ap.add_argument("--site-dir", default=str(ROOT / "site"), help="站点目录")
    ap.add_argument("--strict", action="store_true", help="WARN 也算失败")
    args = ap.parse_args()

    site = Path(args.site_dir).resolve()
    if not site.is_dir():
        print(f"[FAIL] 找不到站点目录：{site}")
        return 1

    check_files(site)
    check_app_ads(site)
    check_offline_assets(site)
    check_links(site)
    check_privacy(site)
    check_placeholders(site)

    width = max(len(n) for _, n, _ in results)
    for level, name, detail in results:
        tag = {"OK": " OK ", "WARN": "WARN", "FAIL": "FAIL"}[level]
        print(f"[{tag}] {name.ljust(width)}  {detail}")

    n_ok = sum(1 for r in results if r[0] == "OK")
    n_warn = sum(1 for r in results if r[0] == "WARN")
    n_fail = sum(1 for r in results if r[0] == "FAIL")
    print("-" * 68)
    print(f"{n_ok} 通过 / {n_warn} 警告 / {n_fail} 失败")

    if n_fail or (args.strict and n_warn):
        if n_warn and not n_fail:
            print("--strict：警告也视为失败，部署前请先清掉。")
        return 1
    print("可以部署。")
    return 0


if __name__ == "__main__":
    sys.exit(main())

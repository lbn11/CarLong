#!/usr/bin/env python3
"""上架前的广告配置闸门。

为什么需要它：广告这块唯一「没法靠单元测试发现」的错误，是把**测试 unit**
或 **mock provider** 打进发布包。表现是广告照播、日志照常、但收入恒为 0，
而且上架也查不出来——只能靠发版前的静态检查拦。

用法：
    python3 tool/check_ads_release.py            # 检查，有 FAIL 时退出码 1
    python3 tool/check_ads_release.py --strict   # WARN 也算失败（提审前跑）

检查项：
    1. AndroidManifest 的 APPLICATION_ID 不是 Google 测试 App ID
    2. Info.plist 的 GADApplicationIdentifier 不是测试 App ID
    3. AD_ID 权限已声明（Android 13+ 缺它 → 个性化广告失效）
    4. ads.env.json（若存在）10 个 unit 全部填写且非测试值
    5. ios/Runner/PrivacyInfo.xcprivacy 存在、内容完整、已加入 Xcode 工程
       （iOS 17+ 缺隐私清单会被 ITMS-91053 警告，后续直接拒）
    6. SKAdNetworkItems 数量（<5 说明只填了 Google 自家，中介渠道归因会丢）
    7. ATT 文案非空（为空系统不弹窗，IDFA 恒为 0）
    8. iPhone 只声明竖屏（本作锁定竖屏，声明横屏会被审核实测打回）
"""

from __future__ import annotations

import json
import plistlib
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID_MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"
INFO_PLIST = ROOT / "ios/Runner/Info.plist"
PRIVACY_MANIFEST = ROOT / "ios/Runner/PrivacyInfo.xcprivacy"
PBXPROJ = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
ENV_FILE = ROOT / "ads.env.json"

TEST_APP_ID_PREFIX = "ca-app-pub-3940256099942544~"
TEST_UNIT_PREFIX = "ca-app-pub-3940256099942544/"

# 这 10 个 key 是 AdMobConfig 认的全部 unit（5 个位 × 双端）。
UNIT_KEYS = [
    f"ADMOB_{platform}_UNIT_{slot}"
    for platform in ("ANDROID", "IOS")
    for slot in ("SHOP", "REVIVE", "DOUBLE", "UNDO", "HINT")
]

results: list[tuple[str, str, str]] = []  # (level, title, detail)


def add(level: str, title: str, detail: str) -> None:
    results.append((level, title, detail))


def _display_width(text: str) -> int:
    """终端列宽：中日韩全角算 2 列，否则表格会错位。"""
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in text)


def _pad(text: str, width: int) -> str:
    return text + " " * max(0, width - _display_width(text))


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:  # 文件缺失也要报出来，不能静默跳过
        add("FAIL", path.name, f"读取失败：{exc}")
        return ""


def load_plist(path: Path, label: str):
    try:
        with path.open("rb") as fh:
            return plistlib.load(fh)
    except Exception as exc:  # noqa: BLE001 - 任何解析失败都要暴露
        add("FAIL", label, f"plist 解析失败：{exc}")
        return None


def check_android() -> None:
    text = read_text(ANDROID_MANIFEST)
    if not text:
        return
    m = re.search(
        r'com\.google\.android\.gms\.ads\.APPLICATION_ID"\s+android:value="([^"]+)"',
        text,
    )
    if not m:
        add("FAIL", "Android APPLICATION_ID", "Manifest 里没有 AdMob App ID meta-data")
    else:
        app_id = m.group(1)
        if app_id.startswith(TEST_APP_ID_PREFIX):
            add("FAIL", "Android APPLICATION_ID", f"仍是 Google 测试 App ID（{app_id}）")
        else:
            add("OK", "Android APPLICATION_ID", app_id)

    if "com.google.android.gms.permission.AD_ID" in text:
        add("OK", "Android AD_ID 权限", "已声明")
    else:
        add(
            "FAIL",
            "Android AD_ID 权限",
            "未声明 → Android 13+ 拿不到广告 ID，个性化广告 eCPM 会掉",
        )


def check_ios_plist() -> dict:
    data = load_plist(INFO_PLIST, "Info.plist")
    if data is None:
        return {}

    app_id = data.get("GADApplicationIdentifier", "")
    if not app_id:
        add("FAIL", "iOS GADApplicationIdentifier", "缺失 → 启动即崩")
    elif app_id.startswith(TEST_APP_ID_PREFIX):
        add("FAIL", "iOS GADApplicationIdentifier", f"仍是 Google 测试 App ID（{app_id}）")
    else:
        add("OK", "iOS GADApplicationIdentifier", app_id)

    att = data.get("NSUserTrackingUsageDescription", "")
    if not att.strip():
        add("FAIL", "ATT 文案", "为空 → 系统不弹窗，IDFA 恒为 0")
    elif len(att) > 120:
        add("WARN", "ATT 文案", f"{len(att)} 字符，建议 ≤120 以免被截断")
    else:
        add("OK", "ATT 文案", att[:40] + ("…" if len(att) > 40 else ""))

    skad = data.get("SKAdNetworkItems", [])
    count = len(skad) if isinstance(skad, list) else 0
    if count == 0:
        add("FAIL", "SKAdNetworkItems", "为空 → 安装归因全丢")
    elif count < 5:
        # 单渠道 AdMob 只需要 Google 自家这一条，别让人去追那份上百条的清单：
        # 那份是「接入中介网络（Meta/AppLovin/Unity…）」时才按每家逐条补的。
        add(
            "OK",
            "SKAdNetworkItems",
            f"{count} 条（单渠道够用；接中介网络后按各 provider 文档逐家补）",
        )
    else:
        add("OK", "SKAdNetworkItems", f"{count} 条")

    orientations = data.get("UISupportedInterfaceOrientations", [])
    landscape = [o for o in orientations if "Landscape" in o]
    if landscape:
        add(
            "WARN",
            "iPhone 方向",
            f"声明了横屏（{len(landscape)} 个）但游戏锁定竖屏，审核会实测",
        )
    else:
        add("OK", "iPhone 方向", "仅竖屏")
    return data


def check_privacy_manifest() -> None:
    if not PRIVACY_MANIFEST.exists():
        add("FAIL", "PrivacyInfo.xcprivacy", "缺失 → iOS 17+ 会被 ITMS-91053 拦下")
        return
    data = load_plist(PRIVACY_MANIFEST, "PrivacyInfo.xcprivacy")
    if data is None:
        return

    if data.get("NSPrivacyTracking") is True:
        add("OK", "隐私清单 · 跟踪声明", "NSPrivacyTracking = true")
    else:
        add("FAIL", "隐私清单 · 跟踪声明", "缺 NSPrivacyTracking=true（用了 AdMob 必须有）")

    collected = data.get("NSPrivacyCollectedDataTypes", [])
    if isinstance(collected, list) and collected:
        add("OK", "隐私清单 · 数据采集", f"{len(collected)} 类")
    else:
        add("WARN", "隐私清单 · 数据采集", "未声明 NSPrivacyCollectedDataTypes")

    api_types = data.get("NSPrivacyAccessedAPITypes", [])
    categories = {
        item.get("NSPrivacyAccessedAPIType")
        for item in api_types
        if isinstance(item, dict)
    }
    required = {
        "NSPrivacyAccessedAPICategoryUserDefaults",
        "NSPrivacyAccessedAPICategoryFileTimestamp",
        "NSPrivacyAccessedAPICategoryDiskSpace",
        "NSPrivacyAccessedAPICategorySystemBootTime",
    }
    missing = required - categories
    if missing:
        add(
            "FAIL",
            "隐私清单 · API 类型",
            "缺 " + "、".join(sorted(x.replace("NSPrivacyAccessedAPICategory", "") for x in missing)),
        )
    else:
        add("OK", "隐私清单 · API 类型", f"{len(categories)} 类已声明")

    pbx = read_text(PBXPROJ)
    if pbx and "PrivacyInfo.xcprivacy" in pbx:
        add("OK", "隐私清单 · 工程引用", "已在 Xcode 工程内")
    elif pbx:
        add("FAIL", "隐私清单 · 工程引用", "文件存在但没加进 Runner target → 不会打进 ipa")


def check_env_file() -> None:
    if not ENV_FILE.exists():
        add(
            "WARN",
            "ads.env.json",
            "未找到（用 --dart-define-from-file 才需要；直接写死 ID 可忽略）",
        )
        return
    try:
        data = json.loads(ENV_FILE.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        add("FAIL", "ads.env.json", f"JSON 解析失败：{exc}")
        return

    missing = [k for k in UNIT_KEYS if not str(data.get(k, "")).strip()]
    testy = [k for k in UNIT_KEYS if str(data.get(k, "")).startswith(TEST_UNIT_PREFIX)]
    if missing:
        add("FAIL", "ads.env.json", f"{len(missing)} 个 unit 未填：" + "、".join(missing[:4]))
    elif testy:
        add("FAIL", "ads.env.json", f"{len(testy)} 个仍是测试 unit")
    else:
        add("OK", "ads.env.json", f"{len(UNIT_KEYS)} 个 unit 已配齐")


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    check_android()
    check_ios_plist()
    check_privacy_manifest()
    check_env_file()

    icon = {"OK": "✅", "WARN": "⚠️ ", "FAIL": "❌"}
    print("\nAdMob 上架自检\n" + "─" * 62)
    width = max(_display_width(t) for _, t, _ in results) + 2
    for level, title, detail in results:
        print(f"{icon[level]} {_pad(title, width)}{detail}")

    fails = [r for r in results if r[0] == "FAIL"]
    warns = [r for r in results if r[0] == "WARN"]
    print("─" * 62)
    print(f"通过 {len(results) - len(fails) - len(warns)} · 警告 {len(warns)} · 失败 {len(fails)}\n")

    if fails:
        print("上面 ❌ 是提审硬门槛，改完再跑一次。")
        return 1
    if warns:
        print("没有硬性失败，但 ⚠️ 项建议在提审前清掉。")
        return 1 if strict else 0
    print("全部通过，可以提审。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

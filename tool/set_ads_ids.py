#!/usr/bin/env python3
"""把 AdMob 的 App ID / unit ID 一次性写进工程，并做跨账号校验。

为什么要脚本：这批 ID 要写到 3 个地方（AndroidManifest、Info.plist、
ads.env.json），共 12 处字符串。手改有两个高频事故：

1. App ID 是 `~`、unit 是 `/`，抄错符号 → SDK 启动即崩或永远无填充；
2. **App ID 和 unit 分属两个账号**（建应用时切了 Google 账号）→ SDK 不报任何错，
   广告请求永远无填充，只能靠对数字才能发现。

所以：格式错 / 账号不一致时，脚本**一个文件都不改**。

用法（逐位 unit，推荐）：

    python3 tool/set_ads_ids.py \
      --android-app-id 'ca-app-pub-1111111111111111~1111111111' \
      --ios-app-id     'ca-app-pub-1111111111111111~2222222222' \
      --android-units shop=ca-app-pub-1111111111111111/1,... \
      --ios-units     shop=ca-app-pub-1111111111111111/6,...

用法（5 个广告位共用一个 unit，先跑通）：

    python3 tool/set_ads_ids.py --android-app-id ... --ios-app-id ... \
      --android-unit 'ca-app-pub-.../1' --ios-unit 'ca-app-pub-.../2'

先看要改什么不落盘：加 --dry-run。写完自动跑上架闸门。
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT_DEFAULT = Path(__file__).resolve().parent.parent
SLOTS = ("shop", "revive", "double", "undo", "hint")

PUBLISHER_RE = re.compile(r"^ca-app-pub-(\d{16})")
APP_ID_RE = re.compile(r"^ca-app-pub-(\d{16})~(\d{10})$")
UNIT_ID_RE = re.compile(r"^ca-app-pub-(\d{16})/(\d{10})$")


class Abort(Exception):
    """校验失败：直接退出，不写任何文件。"""


def err(msg: str) -> None:
    print(f"  ❌ {msg}")


def ok(msg: str) -> None:
    print(f"  ✅ {msg}")


def parse_units(raw: str, flag: str) -> dict[str, str]:
    """解析 `shop=id,revive=id,...`，允许只给部分位（剩下的会明确报出来）。"""
    units: dict[str, str] = {}
    for chunk in raw.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        if "=" not in chunk:
            raise Abort(f"{flag} 里的「{chunk}」缺少 `slot=unit` 形式")
        slot, value = (x.strip() for x in chunk.split("=", 1))
        if slot not in SLOTS:
            raise Abort(f"{flag} 出现未知广告位「{slot}」，只认 {', '.join(SLOTS)}")
        units[slot] = value
    return units


def check_app_id(value: str, label: str) -> str:
    value = value.strip()
    if not APP_ID_RE.match(value):
        raise Abort(
            f"{label} 格式不对：{value}\n"
            "     应为 ca-app-pub-<16位账号>~<10位编号>（**是波浪号 ~**，不是 / ）"
        )
    return value


def check_unit_id(value: str, label: str) -> str:
    value = value.strip()
    if not UNIT_ID_RE.match(value):
        raise Abort(
            f"{label} 格式不对：{value}\n"
            "     应为 ca-app-pub-<16位账号>/<10位编号>（**是斜杠 /**，不是 ~ ）"
        )
    return value


def publisher_of(value: str) -> str:
    m = PUBLISHER_RE.match(value)
    assert m, value
    return m.group(1)


def patch_android(path: Path, app_id: str) -> str:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r'(com\.google\.android\.gms\.ads\.APPLICATION_ID"\s*\n?\s*android:value=")([^"]*)(")'
    )
    if not pattern.search(text):
        raise Abort(f"{path} 里找不到 APPLICATION_ID meta-data（工程结构变了吗？）")
    new_text, n = pattern.subn(rf"\g<1>{app_id}\g<3>", text)
    if n != 1:
        raise Abort(f"{path} 里 APPLICATION_ID 出现 {n} 处，拒绝自动改")
    path.write_text(new_text, encoding="utf-8")
    return f"{path.name} → {app_id}"


def patch_ios(path: Path, app_id: str) -> str:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(<key>GADApplicationIdentifier</key>\s*<string>)([^<]*)(</string>)"
    )
    if not pattern.search(text):
        raise Abort(f"{path} 里找不到 GADApplicationIdentifier")
    new_text, n = pattern.subn(rf"\g<1>{app_id}\g<3>", text)
    if n != 1:
        raise Abort(f"{path} 里 GADApplicationIdentifier 出现 {n} 处，拒绝自动改")
    path.write_text(new_text, encoding="utf-8")
    return f"{path.name} → {app_id}"


def build_env(android_units: dict[str, str], ios_units: dict[str, str]) -> dict[str, str]:
    env = {
        "_comment": "由 tool/set_ads_ids.py 生成。构建时用 --dart-define-from-file=ads.env.json。真实 ID 不要入库。",
    }
    for platform, units in (("ANDROID", android_units), ("IOS", ios_units)):
        for slot in SLOTS:
            env[f"ADMOB_{platform}_UNIT_{slot.upper()}"] = units[slot]
    return env


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(add_help=True, description="写入 AdMob ID 并校验")
    ap.add_argument("--android-app-id")
    ap.add_argument("--ios-app-id")
    ap.add_argument("--android-unit", help="5 个广告位共用这一个 unit")
    ap.add_argument("--ios-unit", help="5 个广告位共用这一个 unit")
    ap.add_argument("--android-units", help="逐位：shop=...,revive=...,double=...,undo=...,hint=...")
    ap.add_argument("--ios-units", help="同上")
    ap.add_argument("--root", default=str(ROOT_DEFAULT), help=argparse.SUPPRESS)
    ap.add_argument("--dry-run", action="store_true", help="只校验并打印，不写文件")
    ap.add_argument("--no-gate", action="store_true", help="跳过结尾的上架闸门")
    args = ap.parse_args(argv)

    root = Path(args.root)
    android_manifest = root / "android/app/src/main/AndroidManifest.xml"
    info_plist = root / "ios/Runner/Info.plist"
    env_file = root / "ads.env.json"

    print("\nAdMob ID 写入\n" + "─" * 62)

    try:
        if not args.android_app_id or not args.ios_app_id:
            raise Abort("必须同时给 --android-app-id 和 --ios-app-id（只填一个平台会崩）")
        android_app_id = check_app_id(args.android_app_id, "Android App ID")
        ios_app_id = check_app_id(args.ios_app_id, "iOS App ID")

        def collect(
            shared: str | None, per_slot: str | None, per_flag: str, shared_flag: str
        ) -> dict[str, str]:
            if per_slot:
                units = parse_units(per_slot, per_flag)
                missing = [s for s in SLOTS if s not in units]
                if missing:
                    raise Abort(
                        f"{per_flag} 缺少广告位：{', '.join(missing)}（要么全给，要么改用 {shared_flag}）"
                    )
            elif shared:
                units = {slot: shared.strip() for slot in SLOTS}
            else:
                raise Abort(f"必须给 {per_flag} 或 {shared_flag}")
            for slot, value in units.items():
                units[slot] = check_unit_id(value, f"{per_flag} {slot}")
            return units

        android_units = collect(args.android_unit, args.android_units, "--android-units", "--android-unit")
        ios_units = collect(args.ios_unit, args.ios_units, "--ios-units", "--ios-unit")

        # 跨账号校验：同一 AdMob 账号下的 App ID 与 unit 才可能出广告。
        android_pub = publisher_of(android_app_id)
        ios_pub = publisher_of(ios_app_id)
        if android_pub != ios_pub:
            raise Abort(
                f"两个 App ID 属于不同 AdMob 账号（{android_pub} vs {ios_pub}）\n"
                "     双端必须建在同一个账号下，否则付款资料与报表都会分裂"
            )
        for label, units in (("Android", android_units), ("iOS", ios_units)):
            bad = [f"{s}({publisher_of(v)})" for s, v in units.items() if publisher_of(v) != android_pub]
            if bad:
                raise Abort(
                    f"{label} 的 unit 账号与 App ID 不一致：{', '.join(bad)}\n"
                     f"     App ID 账号 {android_pub} —— 这种包 SDK 不报错但永远无填充"
                )

        ok(f"格式与账号一致性通过（publisher {android_pub}）")
        print(f"  Android App ID  {android_app_id}")
        print(f"  iOS     App ID  {ios_app_id}")
        for slot in SLOTS:
            print(f"  {slot:<7} A {android_units[slot]}  |  I {ios_units[slot]}")

        if args.dry_run:
            print("\n--dry-run：未写入任何文件。")
            return 0

        print()
        print("  " + patch_android(android_manifest, android_app_id))
        print("  " + patch_ios(info_plist, ios_app_id))
        env_file.write_text(
            json.dumps(build_env(android_units, ios_units), indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print(f"  {env_file.name} → 10 个 unit")
        ok("已写入。")
        print("\n构建命令：")
        print("  flutter build appbundle --release --dart-define-from-file=ads.env.json")
        print("  flutter build ipa       --release --dart-define-from-file=ads.env.json")
    except Abort as exc:
        print()
        err(str(exc))
        print("\n未修改任何文件。")
        return 1

    if not args.no_gate:
        gate = root / "tool/check_ads_release.py"
        if gate.exists():
            print()
            rc = subprocess.run([sys.executable, str(gate), "--strict"], check=False).returncode
            if rc != 0:
                print("闸门未通过：上面的 ❌/⚠️ 清掉再打包。")
                return rc
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

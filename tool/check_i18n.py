#!/usr/bin/env python3
"""i18n 体检：arb 一致性 + dart 残留中文统计 + 生成术语表。

用法：
    python3 tool/check_i18n.py                # 体检（默认）
    python3 tool/check_i18n.py --glossary     # 顺便生成 docs/i18n_glossary.md
    python3 tool/check_i18n.py --strict       # 有 WARN 也返回失败

为什么需要它：
  1. nullable-getter: false 要求每个 arb 都含模板的全部 key。手工补词时
     漏一个，dart 侧不报错，但中文包会直接抛 assertion。
  2. 铺开阶段最需要的是「还剩多少条中文没搬走」——这个数字必须可观测，
     否则 868 条靠感觉推进，永远不知道什么时候算完。
  3. 术语表从 arb 生成，避免文档和代码两份对不上。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARB_DIR = ROOT / "lib" / "l10n"
TEMPLATE = ARB_DIR / "app_en.arb"
GLOSSARY = ROOT / "docs" / "i18n_glossary.md"

# 只统计「玩家能看见」的中文：注释里的中文是给开发者看的，不需要搬。
CJK = re.compile(r"[\u4e00-\u9fff]")
STR_LIT = re.compile(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"")

# 「数据原文」而不是界面文案：这些中文**必须留着**——
#   zhName / zhTitle / zhSubtitle / label  是导出 shared/levels 与存档用的
#   稳定值（见 docs 里的「落盘 ≠ 显示」），本地化版本另有 getter。
DATA_FIELD = re.compile(r"^\s*(zhName|zhTitle|zhSubtitle|label):\s*['\"]")
DATA_MARK = "// i18n-data"  # 位置式数据（LevelChapter(...) / Boss 绰号元组）的显式标记
BLOCK_BEGIN = "// i18n-data-block"  # 整段数据表（枚举体、名字池）的区间标记
BLOCK_END = "// i18n-data-end"
# `?? '中文'` 是拿不到文案表时的兜底，线上永不触发（builder 一定先同步），
# 和「界面漏翻」不是一回事，单独归到数据栏。
DATA_FALLBACK = re.compile(r"\?\?\s*['\"]")

# 这些目录/文件里的中文是数据或调试用，不算 UI 文案。
IGNORE_FILES = {
    "lib/l10n/app_localizations.dart",
    "lib/l10n/app_localizations_en.dart",
    "lib/l10n/app_localizations_zh.dart",
}


def load_arb(path: Path) -> tuple[dict[str, str], dict[str, dict]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    msgs = {k: v for k, v in raw.items() if not k.startswith("@")}
    meta = {k: v for k, v in raw.items() if k.startswith("@") and k != "@@locale"}
    return msgs, meta


def strip_comments(line: str) -> str:
    """去掉整行注释与行尾注释，只留代码部分。"""
    s = line.strip()
    if s.startswith("//") or s.startswith("///"):
        return ""
    return line.split("//")[0] if "//" in line else line


def scan_dart_cjk() -> tuple[int, dict[str, int], int]:
    """统计 lib/ 下仍硬编码在字符串字面量里的中文。

    返回 (界面文案条数, 按文件分布, 数据原文条数)。两栏必须分开：
    数据原文（zhName 等）本来就是中文，混在一起算会让指标永远回不到 0，
    也就失去了「还剩多少没搬」的意义。
    """
    per_file: dict[str, int] = {}
    total = 0
    data_total = 0
    for f in sorted((ROOT / "lib").rglob("*.dart")):
        rel = f.relative_to(ROOT).as_posix()
        if rel in IGNORE_FILES:
            continue
        in_block = False
        in_data_block = False
        count = 0
        for line in f.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if in_block:
                if "*/" in s:
                    in_block = False
                continue
            if s.startswith("/*"):
                in_block = "*/" not in s
                continue
            if BLOCK_BEGIN in line:
                in_data_block = True
                continue
            if BLOCK_END in line:
                in_data_block = False
                continue
            code = strip_comments(line)
            if not CJK.search(code):
                continue
            n = sum(1 for m in STR_LIT.finditer(code) if CJK.search(m.group(0)))
            if not n:
                continue
            if (in_data_block or DATA_FIELD.match(code) or DATA_MARK in line
                    or DATA_FALLBACK.search(code)):
                data_total += n
                continue
            count += n
        if count:
            per_file[rel] = count
            total += count
    return total, per_file, data_total


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--glossary", action="store_true", help="生成 docs/i18n_glossary.md")
    ap.add_argument("--strict", action="store_true", help="有 WARN 也返回失败")
    args = ap.parse_args()

    fails: list[str] = []
    warns: list[str] = []

    if not TEMPLATE.exists():
        print(f"FAIL 找不到模板 {TEMPLATE}")
        return 1

    en, en_meta = load_arb(TEMPLATE)
    arbs = sorted(ARB_DIR.glob("app_*.arb"))
    arbs = [p for p in arbs if p.name != TEMPLATE.name]

    print("=== arb ===")
    print(f"  模板 {TEMPLATE.name}: {len(en)} 条")
    for p in arbs:
        msgs, _ = load_arb(p)
        locale = json.loads(p.read_text(encoding="utf-8")).get("@@locale", "?")
        missing = sorted(set(en) - set(msgs))
        extra = sorted(set(msgs) - set(en))
        print(f"  {p.name} ({locale}): {len(msgs)} 条")
        if missing:
            fails.append(f"{p.name} 缺 {len(missing)} 条: {', '.join(missing[:8])}")
        if extra:
            warns.append(f"{p.name} 多出 {len(extra)} 条（模板里没有）: {', '.join(extra[:8])}")

    # Dart 里的 Dart 关键字检查：arb key 会生成同名 getter，撞关键字会编译失败
    keywords = {
        "continue", "class", "switch", "default", "new", "return", "if", "else",
        "for", "while", "do", "try", "catch", "final", "const", "var", "void",
        "static", "this", "super", "null", "true", "false", "import", "enum",
    }
    bad = [k for k in en if k in keywords]
    if bad:
        fails.append(f"arb key 撞 Dart 关键字: {', '.join(bad)}")

    print("\n=== dart 残留中文 ===")
    total, per_file, data_total = scan_dart_cjk()
    print(f"  界面文案  {total} 条")
    for rel, n in sorted(per_file.items(), key=lambda x: -x[1])[:10]:
        print(f"  {n:5d}  {rel}")
    print(f"  数据原文  {data_total} 条（zhName / zhTitle / label，故意保留中文，不用搬）")

    if args.glossary:
        write_glossary(en, en_meta)
        print(f"\n[ok] 术语表已生成 {GLOSSARY.relative_to(ROOT)}")

    print("\n=== 结果 ===")
    for f in fails:
        print(f"FAIL {f}")
    for w in warns:
        print(f"WARN {w}")
    if not fails and not warns:
        print("全部通过")

    if fails or (args.strict and warns):
        return 1
    return 0


def write_glossary(en: dict[str, str], meta: dict[str, dict]) -> None:
    """从 arb 生成术语表，避免文档与代码两份不同步。"""
    zh_raw = ARB_DIR / "app_zh.arb"
    zh: dict[str, str] = {}
    if zh_raw.exists():
        zh, _ = load_arb(zh_raw)

    groups: dict[str, list[str]] = {}
    for k in en:
        if k.startswith("vehicle"):
            groups.setdefault("车型名", []).append(k)
        elif k.startswith("rarity"):
            groups.setdefault("稀有度", []).append(k)
        elif k.startswith("cat"):
            groups.setdefault("车型分类", []).append(k)
        else:
            groups.setdefault("通用 / 游戏术语", []).append(k)

    lines = [
        "# i18n 术语表",
        "",
        "> **本文件由 `tool/check_i18n.py --glossary` 从 `lib/l10n/*.arb` 生成，不要手改。**",
        "> 改词条去改 arb，再跑一次脚本。",
        "",
        "术语表存在的唯一理由：868 条文案分散在 50 个文件里，",
        "「合成」「撤销」「提示」这类词在不同文件被翻成不同英文，玩家立刻会觉得是两个人写的。",
        "先定死这张表，再铺开翻译。",
        "",
    ]
    for g in ["通用 / 游戏术语", "车型名", "稀有度", "车型分类"]:
        keys = groups.get(g, [])
        if not keys:
            continue
        lines += [f"## {g}", "", "| key | 英文 | 中文 | 说明 |", "|---|---|---|---|"]
        for k in keys:
            desc = (meta.get(f"@{k}") or {}).get("description", "")
            lines.append(f"| `{k}` | {en[k]} | {zh.get(k, '')} | {desc} |")
        lines.append("")

    GLOSSARY.parent.mkdir(parents=True, exist_ok=True)
    GLOSSARY.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())

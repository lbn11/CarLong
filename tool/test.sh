#!/usr/bin/env bash
# 本机快速测试：跳过 ci-heavy 标签的整体页面 widget 测试。
# Why: musl aarch64 上 flutter_tester 线程栈浅，整屏 pump 会 StackOverflow；
#      这批测试在 CI（ubuntu-latest, glibc）跑全量，本机跑逻辑测试即可。
# 用法: ./tool/test.sh            # 跳过 ci-heavy
#       ./tool/test.sh extra args # 透传给 flutter test
set -euo pipefail
cd "$(dirname "$0")/.."

# flutter 不在 PATH 时回退到常见本机 SDK 位置。
if ! command -v flutter >/dev/null 2>&1; then
  for cand in "$HOME/flutter-sdk/bin" "$HOME/flutter/bin" "/opt/flutter/bin"; do
    if [ -x "$cand/flutter" ]; then
      PATH="$cand:$PATH"
      break
    fi
  done
fi

exec flutter test --exclude-tags ci-heavy "$@"

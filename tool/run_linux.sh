#!/usr/bin/env bash
# 本机 Linux 桌面玩完整游戏（release 模式，含真音效）。
# audioplayers_linux 需要 gstreamer-app-1.0 / gstreamer-audio-1.0。
# mobian(apt) 时代 mesa 被 hold 装不了 dev 包，靠 ~/gstapp-dev 手动解包；
# postmarketOS(apk) 直接 apk add gst-plugins-base-dev 即可，下方目录
# 不存在时自动跳过。
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -d "$HOME/gstapp-dev/root/usr/lib/aarch64-linux-gnu/pkgconfig" ]; then
  export PKG_CONFIG_PATH="$HOME/gstapp-dev/root/usr/lib/aarch64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
  export CPLUS_INCLUDE_PATH="$HOME/gstapp-dev/root/usr/include/gstreamer-1.0:${CPLUS_INCLUDE_PATH:-}"
  export LIBRARY_PATH="$HOME/gstapp-dev/root/usr/lib/aarch64-linux-gnu:${LIBRARY_PATH:-}"
fi

# musl 系统：gcompat 提供 libc.so.6 shim（/lib 下），引擎 so 的 glibc 依赖
# 由 musl loader + gcompat 解析，切勿把真 glibc 目录加进 LD_LIBRARY_PATH
# （会让加载器绕过 shim 直接加载 glibc libc，versioned symbols 全挂）。

# flutter 不在 PATH 时回退到常见本机 SDK 位置。
if ! command -v flutter >/dev/null 2>&1; then
  for cand in "$HOME/flutter-sdk/bin" "$HOME/flutter/bin" "/opt/flutter/bin"; do
    if [ -x "$cand/flutter" ]; then
      PATH="$cand:$PATH"
      break
    fi
  done
fi

flutter pub get >/dev/null

flutter build linux --release

BUNDLE="$(ls -d build/linux/*/release/bundle 2>/dev/null | head -1)"
if [ -z "$BUNDLE" ]; then
  echo "未找到 release bundle，构建可能失败"
  exit 1
fi

# musl 系统（postmarketOS 等）：把 exe 的 interpreter 换成 gcompat 的
# glibc 风格 loader（内部是打过补丁的 musl loader），否则 musl loader 直接
# 加载 glibc 构建的引擎 so 会因 versioned symbols（strtoll_l 等）relocation
# 失败。glibc 发行版无此文件，自动跳过。
if [ -e /lib/ld-musl-aarch64.so.1 ] && [ -e /lib/ld-linux-aarch64.so.1 ] && command -v patchelf >/dev/null 2>&1; then
  patchelf --set-interpreter /lib/ld-linux-aarch64.so.1 "$BUNDLE/merge_fleet"
fi

echo "启动游戏（Ctrl+C 或关闭窗口退出）..."
"$BUNDLE/merge_fleet"
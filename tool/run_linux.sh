#!/usr/bin/env bash
# 本机 Linux 桌面玩完整游戏（release 模式，含真音效）。
# audioplayers_linux 需要 gstreamer-app-1.0 / gstreamer-audio-1.0。
# 本机 mesa 被 apt-mark hold 锁版本（libgbm1 26.0.8-1），装不了
# libgstreamer-plugins-base1.0-dev 整包，所以手动把该 deb 解压到
# ~/gstapp-dev，构建时用 PKG_CONFIG_PATH / CPLUS_INCLUDE_PATH / LIBRARY_PATH 指向。
set -euo pipefail
cd "$(dirname "$0")/.."

export PKG_CONFIG_PATH="$HOME/gstapp-dev/root/usr/lib/aarch64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
export CPLUS_INCLUDE_PATH="$HOME/gstapp-dev/root/usr/include/gstreamer-1.0:${CPLUS_INCLUDE_PATH:-}"
export LIBRARY_PATH="$HOME/gstapp-dev/root/usr/lib/aarch64-linux-gnu:${LIBRARY_PATH:-}"

flutter pub get >/dev/null

flutter build linux --release

BUNDLE="$(ls -d build/linux/*/release/bundle 2>/dev/null | head -1)"
if [ -z "$BUNDLE" ]; then
  echo "未找到 release bundle，构建可能失败"
  exit 1
fi
echo "启动游戏（Ctrl+C 或关闭窗口退出）..."
"$BUNDLE/merge_fleet"
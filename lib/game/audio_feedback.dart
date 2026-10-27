import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

enum Sfx { place, move, merge, bonus, error, undo, tick, win, lose }

/// 音效：用 [AudioPool] 预加载每个音效，支持快速连续播放（合成连发不吞音）。
/// 桌面 Linux 等装不了 gstreamer 的环境，用 tool/run_linux.sh 在构建前
/// 临时替换本文件为静音 stub，本机仅影响开发预览。
class AudioFeedback {
  bool soundOn = true;
  bool vibrateOn = true;

  /// 全局振动开关镜像：供没有 [AudioFeedback] 实例的 UI 层（按钮/弹窗/
  /// 按压组件）使用，保证设置里的振动开关能管住所有触感入口。
  /// 游戏屏在 initState 时从存档同步此值。
  static bool globalVibrateOn = true;

  static const Map<Sfx, String> _files = {
    // 体积优化（2026-10-27）：够长的音效转 AAC m4a（64k 单声道），
    // move/tick/place 这种 <5KB 的短音效转码反而更大，保留 wav。
    Sfx.place: 'place.wav',
    Sfx.move: 'move.wav',
    Sfx.merge: 'merge.m4a',
    Sfx.bonus: 'bonus.m4a',
    Sfx.error: 'error.m4a',
    Sfx.undo: 'undo.m4a',
    Sfx.tick: 'tick.wav',
    Sfx.win: 'win.m4a',
    Sfx.lose: 'lose.m4a',
  };

  final Map<Sfx, AudioPool> _pools = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    for (final entry in _files.entries) {
      try {
        _pools[entry.key] =
            await FlameAudio.createPool(entry.value, maxPlayers: 4);
      } catch (_) {
        // 单个音效加载失败时跳过，不影响游戏运行。
      }
    }
  }

  void play(Sfx sfx) {
    if (!soundOn) return;
    final pool = _pools[sfx];
    if (pool == null) return;
    unawaited(pool.start());
  }

  Future<void> tap() async {
    if (!vibrateOn) return;
    await HapticFeedback.lightImpact();
  }

  /// 轻点选（selectionClick）：点选卡片/拿起/切换选择等"无后果"操作，
  /// 比轻击更短促清脆，与实际生效的动作区分开。
  Future<void> select() async {
    if (!vibrateOn) return;
    await HapticFeedback.selectionClick();
  }

  /// 合成冲击：mediumImpact，比点选重一档，给合成足够的打击感。
  Future<void> merge() async {
    if (!vibrateOn) return;
    await HapticFeedback.mediumImpact();
  }

  /// 连消升档：连消 x1 用合成触感，x2 起升到 heavyImpact，越连越带劲。
  Future<void> combo(int n) async {
    if (!vibrateOn) return;
    if (n >= 2) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// 无效操作拒绝（拖拽弹回/滑不动/点不出）：短促的重击提示，
  /// 配合 error 音效让"为什么没反应"有明确答案。
  Future<void> reject() async {
    if (!vibrateOn) return;
    await HapticFeedback.heavyImpact();
  }

  /// UI 层轻点感（按钮/按压组件等无实例场景），走全局振动开关。
  static Future<void> uiTap() async {
    if (!globalVibrateOn) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> success() async {
    if (!vibrateOn) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> fail() async {
    if (!vibrateOn) return;
    await HapticFeedback.vibrate();
  }
}
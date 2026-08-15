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

  static const Map<Sfx, String> _files = {
    Sfx.place: 'place.wav',
    Sfx.move: 'move.wav',
    Sfx.merge: 'merge.wav',
    Sfx.bonus: 'bonus.wav',
    Sfx.error: 'error.wav',
    Sfx.undo: 'undo.wav',
    Sfx.tick: 'tick.wav',
    Sfx.win: 'win.wav',
    Sfx.lose: 'lose.wav',
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

  Future<void> success() async {
    if (!vibrateOn) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> fail() async {
    if (!vibrateOn) return;
    await HapticFeedback.vibrate();
  }
}
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

/// 全局 BGM 播放器：同一时刻只有一首循环背景音乐。
/// 场景切换（首页/合成/停车）时自动换曲；跟随全局音效开关。
class MusicPlayer {
  MusicPlayer._();

  static final MusicPlayer instance = MusicPlayer._();

  String? _current;
  bool enabled = true;

  static const home = 'bgm_home.wav';
  static const merge = 'bgm_merge.wav';
  static const parking = 'bgm_parking.wav';

  /// 切换/播放场景 BGM（自动停掉上一首）。
  Future<void> play(String asset) async {
    if (!enabled || asset == _current) return;
    _current = asset;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play(asset, volume: 0.55);
    } catch (_) {
      _current = null;
    }
  }

  Future<void> stop() async {
    _current = null;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  /// 全局音效开关变化时同步（关则停 BGM，开则恢复当前场景曲目）。
  void syncEnabled(bool on, String? currentSceneAsset) {
    enabled = on;
    if (!on) {
      _current = null;
      FlameAudio.bgm.stop();
    } else if (currentSceneAsset != null) {
      play(currentSceneAsset);
    }
  }
}

/// 路由观察者：注册到 MaterialApp.navigatorObservers，
/// 供各页面在"回到前台/离开前台"时切换 BGM。
final RouteObserver<ModalRoute<void>> musicRouteObserver =
    RouteObserver<ModalRoute<void>>();

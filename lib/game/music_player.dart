import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

/// 全局 BGM 播放器：同一时刻只有一首循环背景音乐。
///
/// 曲目分层：
///   * 首页一首；
///   * 合并模式按「章」轮换 3 首（同一章内不切歌，换章才换，符合
///     「每个 Boss 段一种情绪」的设计——Boss 正好是章内第 11 关）；
///   * 停车模式按「章」轮换 2 首；
///   * Boss 关无条件覆盖成本身专属的紧张曲。
///
/// 路径相对 [FlameAudio] 的默认前缀 `assets/audio/`，所以写 `bgm/xxx.m4a`
/// 实际读的是 `assets/audio/bgm/xxx.m4a`（pubspec 里已单独声明该子目录）。
///
/// 为什么用 m4a 而不是 ogg：iOS 的 AVAudioPlayer 不支持 ogg，而本项目
/// 主发 iOS。sfx 早前也已统一转 m4a，保持一致。
class MusicPlayer {
  MusicPlayer._();

  static final MusicPlayer instance = MusicPlayer._();

  /// 全局音效开关（与设置里的 soundOn 同步）。关掉时 play/stop 都变成空操作。
  bool enabled = true;

  /// 当前正在播的曲目；用于避免重复 play 同一首（否则每次进关都会重头播）。
  String? _current;

  static const String home = 'bgm/home.m4a';
  static const String boss = 'bgm/boss.m4a';

  static const List<String> _mergeTracks = [
    'bgm/merge_1.m4a',
    'bgm/merge_2.m4a',
    'bgm/merge_3.m4a',
  ];
  static const List<String> _parkingTracks = [
    'bgm/parking_1.m4a',
    'bgm/parking_2.m4a',
  ];

  /// 合并模式按章选曲。传 -1/越界都安全回落到第一首。
  static String mergeTrackFor(int chapterIndex) =>
      _mergeTracks[chapterIndex < 0 ? 0 : chapterIndex % _mergeTracks.length];

  /// 停车模式按章选曲。
  static String parkingTrackFor(int chapterIndex) =>
      _parkingTracks[chapterIndex < 0 ? 0 : chapterIndex % _parkingTracks.length];

  /// 全部曲目（供「防静音」回归测试逐首确认资源存在）。
  static List<String> get allTracks =>
      <String>[home, boss, ..._mergeTracks, ..._parkingTracks];

  /// 切换/播放场景 BGM（自动停掉上一首）。同一首正在播时直接返回。
  Future<void> play(String asset) async {
    if (!enabled || asset == _current) return;
    _current = asset;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play(asset, volume: 0.5);
    } catch (_) {
      // 资源缺失/解码失败时静默降级（无 BGM 也不能影响可玩性）。
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
      // 测试环境没有音频插件，stop 会抛 MissingPluginException，忽略即可。
      try {
        FlameAudio.bgm.stop();
      } catch (_) {}
    } else if (currentSceneAsset != null) {
      play(currentSceneAsset);
    }
  }
}

/// 路由观察者：注册到 MaterialApp.navigatorObservers，
/// 供各页面在"回到前台/离开前台"时切换 BGM。
final RouteObserver<ModalRoute<void>> musicRouteObserver =
    RouteObserver<ModalRoute<void>>();

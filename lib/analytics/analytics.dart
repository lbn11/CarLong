import '../models/level.dart';
import '../save/save_repository.dart';

/// 轻量本地埋点：把关键行为事件追加进存档并落盘。
///
/// 目前没有后端，事件先存本地（封顶条数），供后续数值调优 / 留存分析使用；
/// 将来接真正的上报 SDK 时只改这里，调用方（game_screen 等）保持不变。
class AnalyticsService {
  /// 事件日志封顶条数，超出后丢弃最旧。
  static const int maxEvents = 300;

  final PlayerData data;
  final SaveRepository repo;

  AnalyticsService(this.data, this.repo);

  void _log(String event, [Map<String, Object> params = const {}]) {
    data.analyticsEvents.add({
      't': DateTime.now().toIso8601String(),
      'e': event,
      ...params,
    });
    final over = data.analyticsEvents.length - maxEvents;
    if (over > 0) data.analyticsEvents.removeRange(0, over);
    repo.save(data);
  }

  /// 关卡开始（含无尽模式）。
  void levelStart(LevelDefinition level) {
    _log('level_start', {
      'level': level.id,
      'endless': level.endless,
      'goal': level.goalType.name,
      'time_limit': level.timeLimitSeconds ?? 0,
    });
  }

  /// 关卡结束（胜负 + 关键结算指标）。
  void levelEnd({
    required LevelDefinition level,
    required bool won,
    required int score,
    required int stars,
    required int maxCombo,
    required double elapsedSeconds,
    required int coins,
  }) {
    _log('level_end', {
      'level': level.id,
      'endless': level.endless,
      'won': won,
      'score': score,
      'stars': stars,
      'max_combo': maxCombo,
      'elapsed_s': elapsedSeconds.round(),
      'coins': coins,
    });
  }

  /// 道具成功使用（扣费后调用）。
  void toolUse(String tool, int cost, int coinsLeft) {
    _log('tool_use', {'tool': tool, 'cost': cost, 'coins_left': coinsLeft});
  }
}

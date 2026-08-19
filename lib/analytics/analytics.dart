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

  // ===== 留存 / 变现漏斗事件（任务79）=====

  /// 应用启动（首页渲染）。[isFirst] 标记新玩家首启。
  void appLaunch({bool isFirst = false}) {
    _log('app_launch', {'first': isFirst});
  }

  /// 新手引导完成或跳过（scope: home/merge/parking）。
  void tutorialComplete(String scope, {bool skipped = false}) {
    _log('tutorial_done', {'scope': scope, 'skipped': skipped});
  }

  /// 离线收益发放。
  void offlineReward(int reward, int hours) {
    _log('offline_reward', {'reward': reward, 'hours': hours});
  }

  /// 激励广告完成发奖。
  void adWatch(int reward) {
    _log('ad_watch', {'reward': reward});
  }

  /// 金币宝箱开启。
  void chestOpen(int cost, String result) {
    _log('chest_open', {'cost': cost, 'result': result});
  }

  /// 金币礼包购买（模拟 IAP）。
  void iapPurchase(String product, int amount) {
    _log('iap_purchase', {'product': product, 'amount': amount});
  }

  /// 签到。
  void signIn(int day, int reward) {
    _log('sign_in', {'day': day, 'reward': reward});
  }

  /// 每日挑战通关。
  void dailyClear(int reward) {
    _log('daily_clear', {'reward': reward});
  }

  /// 停车关卡结算。
  void parkingEnd({
    required int level,
    required bool won,
    required int stars,
    required int reward,
  }) {
    _log('parking_end', {
      'level': level,
      'won': won,
      'stars': stars,
      'reward': reward,
    });
  }

  /// 图鉴新点亮。
  void collectionNew(int tierIndex) {
    _log('collection_new', {'tier': tierIndex});
  }
}

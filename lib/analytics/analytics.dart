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
  ///
  /// [beatPar] = 用时 ≤ 参考时间（LevelDataGenerator.parSeconds）：
  /// 与 elapsed_s 一起构成 par 常数的校准数据源——攒够对局后
  /// 按同章 beat_par 比例回调 parSecPerDraw。
  void levelEnd({
    required LevelDefinition level,
    required bool won,
    required int score,
    required int stars,
    required int maxCombo,
    required double elapsedSeconds,
    required int coins,
    bool beatPar = false,
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
      'beat_par': beatPar,
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

  /// 离线收益发放。
  void offlineReward(int reward, int hours) {
    _log('offline_reward', {'reward': reward, 'hours': hours});
  }

  /// 激励广告完成发奖。
  void adWatch(int reward) {
    _log('ad_watch', {'reward': reward});
  }

  /// 广告展示结果（**每次请求都记**，含 skipped / failed / capped）。
  ///
  /// 与 [adWatch] 的分工：adWatch 只在发奖时记（算钱），ad_impression 记
  /// 每一次请求（算漏斗）。两个一起看才能算出「填充率 / 完播率 / 人均请求」，
  /// 只看 adWatch 会把「广告没加载出来」误判成「玩家不想看」。
  void adImpression({
    required String placement,
    required String label,
    required String outcome,
    required bool rewarded,
    String? detail,
  }) {
    _log('ad_impression', {
      'placement': placement,
      'label': label,
      'outcome': outcome,
      'rewarded': rewarded,
      'detail': ?detail,
    });
  }

  /// 金币宝箱开启。
  void chestOpen(int cost, String result) {
    _log('chest_open', {'cost': cost, 'result': result});
  }

  /// 内购成交埋点（**当前无调用点**）。
  ///
  /// 商店里那个「¥6 购买 600 金币」的模拟内购已删除（标价不扣款 = 审核红线），
  /// 本作现在是纯广告变现。这里保留事件名，是为了以后接 IAP 时口径不用重新定义；
  /// 一旦真的接入，**必须在发货成功后调用**，不要在点击时调用——
  /// 点击即记会把「取消支付」算成收入，报表会虚高。
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

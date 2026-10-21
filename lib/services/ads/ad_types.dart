import '../../game/game_config.dart';

/// 广告位（placement）。
///
/// 一个广告位 = 一条 SDK 展示位 ID + 一套业务上限。**新增广告位只加枚举值 +
/// 在 [AdPlacementMeta] 补一条元数据**，调用方不需要知道任何 SDK 细节。
///
/// [key] 是存档里的计数键，**一旦发布就不能改**（改了等于清零历史计数，
/// 玩家当天可以多看一轮）。
enum AdPlacement {
  /// 商店「每日福利 · 看广告赚金币」。
  shopDaily,

  /// 合成失败续命（每局一次，次数由 MergeGame.revivesLeft 管）。
  mergeRevive,

  /// 合成胜利金币 ×2（每局一次）。
  mergeDouble,

  /// 停车撤销卡不足时看广告回退 3 步。
  parkingUndo,

  /// 停车「下一步最优走法」提示。
  parkingHint,
}

/// 广告位的业务元数据。
class AdPlacementMeta {
  /// 存档计数键（发布后不可改）。
  final String key;

  /// 埋点与会话日志里的可读名。
  final String label;

  /// 每日观看上限；null = 不设上限（由玩法本身限制，如「每局一次」）。
  final int? dailyCap;

  const AdPlacementMeta({
    required this.key,
    required this.label,
    this.dailyCap,
  });
}

extension AdPlacementX on AdPlacement {
  AdPlacementMeta get meta => switch (this) {
        AdPlacement.shopDaily => AdPlacementMeta(
            key: 'shop',
            label: '商店每日福利',
            // 与改造前一致：每日 3 次（GameConfig 可远程覆盖）。
            dailyCap: GameConfig.dailyAdLimit,
          ),
        AdPlacement.mergeRevive => const AdPlacementMeta(
            key: 'merge_revive',
            label: '合成续命',
          ),
        AdPlacement.mergeDouble => const AdPlacementMeta(
            key: 'merge_double',
            label: '合成金币翻倍',
          ),
        AdPlacement.parkingUndo => const AdPlacementMeta(
            key: 'parking_undo',
            label: '停车广告撤销',
          ),
        AdPlacement.parkingHint => const AdPlacementMeta(
            key: 'parking_hint',
            label: '停车广告提示',
          ),
      };

  String get key => meta.key;
  String get label => meta.label;
  int? get dailyCap => meta.dailyCap;
}

/// 一次广告请求的结果。
///
/// **发奖判据只有 [AdOutcome.rewarded]**：`skipped / failed / unavailable /
/// capped` 一律不发奖。历史模拟实现是「点击即发奖」，接真实 SDK 后必须改成
/// 回调驱动，否则关掉广告也能刷奖励。
enum AdOutcome {
  /// 完整看完，可以发奖。
  rewarded,

  /// 玩家中途关闭（SDK 的 onUserEarnedReward 没触发）。
  skipped,

  /// 拉取失败 / 超时 / 无填充。
  failed,

  /// 环境不支持（未初始化、家长控制、青少年模式等）。
  unavailable,

  /// 今日次数已用完（本地拦截，不消耗 SDK 请求）。
  capped,
}

class AdResult {
  final AdOutcome outcome;

  /// 诊断信息（只进日志，不给玩家看）。
  final String? detail;

  const AdResult(this.outcome, {this.detail});

  static const AdResult granted = AdResult(AdOutcome.rewarded);
  static const AdResult skipped = AdResult(AdOutcome.skipped);
  static const AdResult failed = AdResult(AdOutcome.failed);
  static const AdResult unavailable = AdResult(AdOutcome.unavailable);
  static const AdResult capped = AdResult(AdOutcome.capped);

  bool get isRewarded => outcome == AdOutcome.rewarded;

  /// 给玩家看的失败原因（区分「你自己的问题」和「广告没加载出来」）。
  String get userMessage => switch (outcome) {
        AdOutcome.rewarded => '',
        AdOutcome.skipped => '广告还没看完，奖励先不发放',
        AdOutcome.failed => '广告暂时没加载出来，稍后再试',
        AdOutcome.unavailable => '当前环境暂时无法播放广告',
        AdOutcome.capped => '今天的次数已经用完啦',
      };
}

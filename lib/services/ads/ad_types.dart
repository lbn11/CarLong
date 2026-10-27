import '../../game/game_config.dart';
import '../../l10n/l10n.dart';

/// 广告位（placement）。
///
/// 一个广告位 = 一条 SDK 展示位 ID + 一套业务上限。**新增广告位只加枚举值 +
/// 在 [AdPlacementMeta] 补一条元数据**，调用方不需要知道任何 SDK 细节。
///
/// [AdPlacementMeta.key] 是存档里的计数键，**一旦发布就不能改**（改了等于
/// 清零历史计数，玩家当天可以多看一轮）。
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
///
/// 三个数字共同决定「玩家一天能看多少」：
/// 1. [dailyCap] 单个广告位的每日次数（防刷）；
/// 2. [cooldown] 同一广告位两次展示的最短间隔（防连点、防被渠道判「诱导观看」）；
/// 3. [envKey] 换 unit 时的 `--dart-define` 后缀（每个位单独算收益）。
class AdPlacementMeta {
  /// 存档计数键（发布后不可改）。
  final String key;

  /// 埋点与会话日志里的可读名。
  final String label;

  /// 每日观看上限；null = 不设单点上限（由玩法本身 + 全局上限兜底，
  /// 如「每局一次」的续命/翻倍）。
  final int? dailyCap;

  /// 同一广告位两次展示的最短间隔。
  final Duration cooldown;

  /// `--dart-define=ADMOB_{ANDROID|IOS}_UNIT_<envKey>` 的后缀。
  final String envKey;

  const AdPlacementMeta({
    required this.key,
    required this.label,
    this.dailyCap,
    this.cooldown = const Duration(seconds: 6),
    required this.envKey,
  });
}

extension AdPlacementX on AdPlacement {
  /// 广告位**展示名**（本地化）。[AdPlacementMeta.label] 是稳定原文，只给
  /// 日志/诊断用，界面一律走这里，否则英文包里会露出中文。
  String get displayLabel => switch (this) {
        AdPlacement.shopDaily => L10n.value.adPlacementShop,
        AdPlacement.mergeRevive => L10n.value.adPlacementRevive,
        AdPlacement.mergeDouble => L10n.value.adPlacementDouble,
        AdPlacement.parkingUndo => L10n.value.adPlacementUndo,
        AdPlacement.parkingHint => L10n.value.adPlacementHint,
      };

  AdPlacementMeta get meta => switch (this) {
        AdPlacement.shopDaily => AdPlacementMeta(
            key: 'shop',
            label: '商店每日福利', // i18n-data
            // 与改造前一致：每日 3 次（GameConfig 可远程覆盖）。
            dailyCap: GameConfig.dailyAdLimit,
            // 商店是玩家最容易连点的地方：留一点间隔，也避免连续两条广告
            // 被渠道判定为「异常高频观看」。
            cooldown: const Duration(seconds: 8),
            envKey: 'SHOP',
          ),
        AdPlacement.mergeRevive => const AdPlacementMeta(
            key: 'merge_revive',
            label: '合成续命', // i18n-data
            cooldown: Duration(seconds: 3),
            envKey: 'REVIVE',
          ),
        AdPlacement.mergeDouble => const AdPlacementMeta(
            key: 'merge_double',
            label: '合成金币翻倍', // i18n-data
            cooldown: Duration(seconds: 3),
            envKey: 'DOUBLE',
          ),
        // 停车两个位都是「随时可点」的即时帮助，最容易变成刷次数：
        // 单点每日 10 次 + 12 秒冷却，既够用又不至于一天几十条。
        AdPlacement.parkingUndo => const AdPlacementMeta(
            key: 'parking_undo',
            label: '停车广告撤销', // i18n-data
            dailyCap: 10,
            cooldown: Duration(seconds: 12),
            envKey: 'UNDO',
          ),
        AdPlacement.parkingHint => const AdPlacementMeta(
            key: 'parking_hint',
            label: '停车广告提示', // i18n-data
            dailyCap: 10,
            cooldown: Duration(seconds: 12),
            envKey: 'HINT',
          ),
      };

  String get key => meta.key;
  String get label => meta.label;
  int? get dailyCap => meta.dailyCap;
  Duration get cooldown => meta.cooldown;
  String get envKey => meta.envKey;
}

/// 一次广告请求的结果。
///
/// **发奖判据只有 [AdOutcome.rewarded]**：`skipped / failed / unavailable /
/// capped / cooldown` 一律不发奖。历史模拟实现是「点击即发奖」，接真实 SDK
/// 后必须改成回调驱动，否则关掉广告也能刷奖励。
enum AdOutcome {
  /// 完整看完，可以发奖。
  rewarded,

  /// 玩家中途关闭（SDK 的 onUserEarnedReward 没触发）。
  skipped,

  /// 拉取失败 / 超时 / 无填充。
  failed,

  /// 环境不支持（未初始化、家长控制、青少年模式、用户拒绝广告同意）。
  unavailable,

  /// 今日次数已用完（本地拦截，不消耗 SDK 请求）。
  capped,

  /// 距上次观看太近（同样本地拦截，不烧 SDK 请求）。
  cooldown,
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
        AdOutcome.skipped => L10n.value.adOutcomeSkipped,
        AdOutcome.failed => L10n.value.adOutcomeFailed,
        AdOutcome.unavailable => L10n.value.adOutcomeUnavailable,
        AdOutcome.capped => L10n.value.adOutcomeCapped,
        AdOutcome.cooldown => L10n.value.adOutcomeCooldown,
      };
}

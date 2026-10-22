/// 广告的**全局策略**：一屏改完所有「一天最多看多少」的数字。
///
/// 分层原则（改数值前先看这条）：
/// - 单个广告位能看几次 → `AdPlacementMeta.dailyCap`（跟着广告位走）；
/// - 同一广告位的最短间隔 → `AdPlacementMeta.cooldown`；
/// - **跨广告位**的日总量 / 总开关 / 环境覆盖 → 本文件。
///
/// 为什么需要全局上限：五个广告位各自封顶后，一个玩家一天仍可能看到
/// 3 + 5 + 5 + 10 + 10 ≈ 33 条。真实广告 15-30 秒一条，这个量级已经接近
/// 渠道「诱导观看」的风控阈值，所以再加一道 30 条/天的总量闸门。
class AdPolicy {
  /// 全部广告位合计的每日上限（达到后所有位都返回 `capped`）。
  final int globalDailyCap;

  /// 总开关。远程想临时关掉全部广告（比如审核期、活动期）只改这一处。
  final bool adsEnabled;

  const AdPolicy({
    this.globalDailyCap = 30,
    this.adsEnabled = true,
  });

  /// 默认策略（线上使用）。
  static const AdPolicy standard = AdPolicy();

  /// 从编译期 `--dart-define` 覆盖：
  /// - `AD_GLOBAL_DAILY_CAP=0` → 关闭全部广告位；
  /// - `AD_GLOBAL_DAILY_CAP=20` → 收紧总量；
  /// - `ADS_DISABLED=true` → 全局停广告（审核/演示用）。
  factory AdPolicy.fromEnvironment() {
    const rawCap = int.fromEnvironment('AD_GLOBAL_DAILY_CAP', defaultValue: 30);
    const disabled = bool.fromEnvironment('ADS_DISABLED');
    return AdPolicy(
      globalDailyCap: rawCap < 0 ? 0 : rawCap,
      adsEnabled: !disabled && rawCap != 0,
    );
  }

  AdPolicy copyWith({int? globalDailyCap, bool? adsEnabled}) => AdPolicy(
        globalDailyCap: globalDailyCap ?? this.globalDailyCap,
        adsEnabled: adsEnabled ?? this.adsEnabled,
      );
}

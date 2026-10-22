import '../../analytics/analytics.dart';
import '../../save/save_repository.dart';
import 'ad_policy.dart';
import 'ad_provider.dart';
import 'ad_types.dart';
import 'mock_ad_provider.dart';

/// 广告总入口：业务代码**只认这个类**，不碰任何 SDK。
///
/// 职责边界（故意收得很窄）：
/// 1. **发奖闸门** —— 只有 provider 返回 [AdOutcome.rewarded] 才算成功，
///    调用方据此决定发不发奖。这是接真实 SDK 后最重要的一条：历史模拟实现
///    是「点击即发奖」，照搬上线等于广告随便关也能刷奖励。
/// 2. **频次治理**（三道闸，全部本地拦截、不烧 SDK 请求）：
///    - 单点每日上限 `AdPlacementMeta.dailyCap`
///    - 单点冷却 `AdPlacementMeta.cooldown`（防连点/防被判诱导观看）
///    - 全局每日总量 [AdPolicy.globalDailyCap]（跨广告位兜底）
/// 3. **合规入口** —— 转发 UMP 的「隐私设置」能力，UI 不需要认识 SDK。
/// 4. **降级** —— SDK 未初始化/无填充/异常一律返回结果对象，不抛异常，
///    UI 只负责提示，不负责 try-catch。
///
/// 不管的事：奖励发多少（`GameConfig`）、每局几次（玩法自己管）、
/// 未成年人模式（接入时在 provider 层按年龄段直接返回 `unavailable`）。
class AdService {
  AdService._();

  /// 当前 provider。默认是模拟实现（开发/预览可用）。
  /// **release 由 `main()` 用 `createAdProvider()` 按平台替换**。
  static AdProvider provider = MockAdProvider();

  /// 全局策略（总量闸门/总开关）。远程配置接入后由这里下发。
  static AdPolicy policy = AdPolicy.standard;

  /// 时钟注入口（测试跨日、跨冷却用）。
  static DateTime Function() now = DateTime.now;

  static bool _initialized = false;
  static bool _supported = true;

  /// 初始化只跑一次的凭据。
  ///
  /// 必须缓存 **Future** 而不是 bool：真实 SDK 初始化要 1-3 秒，
  /// 这期间玩家点了广告位会再触发一次 initialize（重复初始化 AdMob
  /// 会重复注册回调）。缓存 future 让后来者直接等同一次的结果。
  static Future<bool>? _initFuture;

  /// 每个广告位上次「真正播出」的时间（只在会话内有效，重启即清）。
  static final Map<AdPlacement, DateTime> _lastShownAt = {};

  /// 隐私设置入口是否必须展示（null = 还没问过）。
  static bool? _privacyRequired;

  /// 是否处于模拟模式（UI 可据此显示「演示」字样）。
  static bool get usingMock => provider.isMock;

  static String get providerName => provider.name;

  /// 冷启动初始化：幂等，失败只降级不拦启动。
  static Future<bool> initialize() {
    if (_initialized) return Future<bool>.value(_supported);
    return _initFuture ??= _doInitialize();
  }

  static Future<bool> _doInitialize() async {
    try {
      _supported = await provider.initialize();
    } catch (_) {
      _supported = false;
    }
    _initialized = true;
    return _supported;
  }

  /// 今天（本地时区）的日期键。
  static String todayKey() {
    final d = now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// 今日某广告位已看次数（跨日视为 0）。
  static int usedToday(AdPlacement placement, PlayerData data) {
    if (data.adDailyDate != todayKey()) return 0;
    return data.adDailyCounts[placement.key] ?? 0;
  }

  /// 今日**所有广告位合计**已看次数。
  static int usedTodayTotal(PlayerData data) {
    if (data.adDailyDate != todayKey()) return 0;
    return data.adDailyCounts.values.fold<int>(0, (a, b) => a + b);
  }

  /// 今日剩余次数；`null` = 该广告位不设单点上限。
  static int? remainingToday(AdPlacement placement, PlayerData data) {
    final cap = placement.dailyCap;
    if (cap == null) return null;
    final left = cap - usedToday(placement, data);
    return left < 0 ? 0 : left;
  }

  /// 全局还能看几条（跨广告位）。
  static int remainingGlobalToday(PlayerData data) {
    final left = policy.globalDailyCap - usedTodayTotal(data);
    return left < 0 ? 0 : left;
  }

  /// 该广告位还要等多久才能再播（无冷却返回 [Duration.zero]）。
  static Duration cooldownRemaining(AdPlacement placement) {
    final last = _lastShownAt[placement];
    if (last == null) return Duration.zero;
    final ready = last.add(placement.cooldown);
    final diff = ready.difference(now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// 展示激励视频并返回结果。
  ///
  /// 只有 `result.isRewarded == true` 时调用方才发奖并落存档；本方法已经
  /// 负责把「成功」计入今日次数。
  static Future<AdResult> show(
    AdPlacement placement, {
    required PlayerData data,
    required SaveRepository repo,
    AnalyticsService? analytics,
  }) async {
    AdResult? blocked = _guardBeforeShow(placement, data);
    if (blocked == null && !await initialize()) {
      blocked = AdResult.unavailable;
    }

    if (blocked != null) {
      return _record(
        blocked,
        placement: placement,
        data: data,
        repo: repo,
        analytics: analytics,
      );
    }

    AdResult result;
    try {
      result = await provider.showRewarded(placement);
    } catch (e) {
      result = AdResult(AdOutcome.failed, detail: e.toString());
    }

    // 只要真的播出去了（看完或中途关闭），就记冷却：防「秒关再点」刷次数。
    if (result.outcome == AdOutcome.rewarded ||
        result.outcome == AdOutcome.skipped) {
      _lastShownAt[placement] = now();
    }

    if (result.isRewarded) {
      final today = todayKey();
      if (data.adDailyDate != today) {
        data.adDailyDate = today;
        data.adDailyCounts.clear();
      }
      final next = (data.adDailyCounts[placement.key] ?? 0) + 1;
      data.adDailyCounts[placement.key] = next;
      // 旧字段同步：老版本（只认识商店福利）降级后不会白送一轮次数。
      if (placement == AdPlacement.shopDaily) {
        data.adWatchDate = today;
        data.adWatchCount = next;
      }
      await repo.save(data);
    }

    return _record(
      result,
      placement: placement,
      data: data,
      repo: repo,
      analytics: analytics,
    );
  }

  /// 展示前的三道本地闸门，返回 null 表示放行。
  ///
  /// 顺序有意义：先全局总开关 → 再总量 → 再单点 → 最后冷却。这样玩家看到的
  /// 提示永远是最「顶层」的原因（关广告时不该提示「休息几秒」）。
  static AdResult? _guardBeforeShow(AdPlacement placement, PlayerData data) {
    if (!policy.adsEnabled) {
      return const AdResult(AdOutcome.unavailable, detail: 'ads disabled by policy');
    }
    if (remainingGlobalToday(data) <= 0) {
      return const AdResult(AdOutcome.capped, detail: 'global daily cap');
    }
    final cap = placement.dailyCap;
    if (cap != null && usedToday(placement, data) >= cap) {
      return AdResult(AdOutcome.capped, detail: 'placement daily cap ($cap)');
    }
    final wait = cooldownRemaining(placement);
    if (wait > Duration.zero) {
      return AdResult(
        AdOutcome.cooldown,
        detail: 'cooldown ${wait.inSeconds + 1}s',
      );
    }
    return null;
  }

  static AdResult _record(
    AdResult result, {
    required AdPlacement placement,
    required PlayerData data,
    required SaveRepository repo,
    AnalyticsService? analytics,
  }) {
    (analytics ?? AnalyticsService(data, repo)).adImpression(
      placement: placement.key,
      label: placement.label,
      outcome: result.outcome.name,
      rewarded: result.isRewarded,
      detail: result.detail,
    );
    return result;
  }

  /// 预加载（SDK 支持时减少首次点击等待）。
  ///
  /// 入口页一进来就调它，能把「点广告 → 看视频」的等待从 2-5 秒压到 0。
  /// 预加载失败不提示：真点了会再拉一次。
  static Future<void> preload(AdPlacement placement) async {
    if (!policy.adsEnabled) return;
    try {
      await provider.preload(placement);
    } catch (_) {
      // 预加载失败不影响后续 show（show 会再拉一次）。
    }
  }

  /// 批量预加载（进关卡时把可能用到的位一起拉）。
  static Future<void> preloadAll(Iterable<AdPlacement> placements) async {
    await Future.wait(placements.map(preload));
  }

  // ===== 隐私设置（UMP）=====

  /// 应用内是否必须提供「隐私设置」入口。
  ///
  /// 结果缓存：这是低频状态，不必每次进设置页都打一次原生调用。
  static Future<bool> privacyOptionsRequired({bool refresh = false}) async {
    if (_privacyRequired != null && !refresh) return _privacyRequired!;
    try {
      _privacyRequired = await provider.privacyOptionsRequired();
    } catch (_) {
      _privacyRequired = false;
    }
    return _privacyRequired!;
  }

  /// 打开隐私设置表单。返回 true 表示确实弹出过（玩家可撤回/修改同意）。
  static Future<bool> showPrivacyOptions() async {
    try {
      final shown = await provider.showPrivacyOptions();
      // 玩家可能撤回同意：不用刷新状态，下次 show() 时 provider 自己会
      // 重新读 canRequestAds，撤回后自然返回 unavailable。
      return shown;
    } catch (_) {
      return false;
    }
  }

  /// 测试/热重载用：重置初始化状态与会话内的冷却记录。
  static void resetForTest() {
    _initialized = false;
    _supported = true;
    _initFuture = null;
    _privacyRequired = null;
    _lastShownAt.clear();
  }
}

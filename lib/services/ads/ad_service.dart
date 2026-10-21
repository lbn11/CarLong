import '../../analytics/analytics.dart';
import '../../save/save_repository.dart';
import 'ad_provider.dart';
import 'ad_types.dart';
import 'mock_ad_provider.dart';

/// 广告总入口：业务代码**只认这个类**，不碰任何 SDK。
///
/// 职责边界（故意收得很窄）：
/// 1. **发奖闸门** —— 只有 provider 返回 [AdOutcome.rewarded] 才算成功，
///    调用方据此决定发不发奖。这是接真实 SDK 后最重要的一条：历史模拟实现
///    是「点击即发奖」，照搬上线等于广告随便关也能刷奖励。
/// 2. **每日上限** —— 按 `AdPlacement.dailyCap` 本地拦截，跨日自动清零；
///    计数落存档（`PlayerData.adDailyCounts`），不依赖网络。
/// 3. **降级** —— SDK 未初始化/无填充/异常一律返回结果对象，不抛异常，
///    UI 只负责提示，不负责 try-catch。
///
/// 不管的事：奖励发多少（`GameConfig`）、每局几次（玩法自己管）、
/// 未成年人模式（接入时在 provider 层按年龄段直接返回 `unavailable`）。
///
/// 换真实 SDK 只改一行（或直接用 `createAdProvider()` 让工厂按平台选）：
/// ```dart
/// AdService.provider = createAdMobProvider();
/// ```
class AdService {
  AdService._();

  /// 当前 provider。默认全是模拟实现（开发/预览可用）。
  /// **release 必须在 main() 里换成真实 provider**，否则等于没有广告。
  static AdProvider provider = MockAdProvider();

  /// 时钟注入口（测试跨日逻辑用）。
  static DateTime Function() now = DateTime.now;

  static bool _initialized = false;
  static bool _supported = true;

  /// 初始化只跑一次的凭据。
  ///
  /// 必须缓存 **Future** 而不是 bool：真实 SDK 初始化要 1-3 秒，
  /// 这期间玩家点了广告位会再触发一次 initialize（重复初始化 AdMob
  /// 会重复注册回调）。缓存 future 让后来者直接等同一次的结果。
  static Future<bool>? _initFuture;

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

  /// 今日剩余次数；`null` = 该广告位不设每日上限。
  static int? remainingToday(AdPlacement placement, PlayerData data) {
    final cap = placement.dailyCap;
    if (cap == null) return null;
    final left = cap - usedToday(placement, data);
    return left < 0 ? 0 : left;
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
    final cap = placement.dailyCap;
    if (cap != null && usedToday(placement, data) >= cap) {
      return AdResult.capped;
    }

    if (!await initialize()) {
      return _record(
        AdResult.unavailable,
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
  static Future<void> preload(AdPlacement placement) async {
    try {
      await provider.preload(placement);
    } catch (_) {
      // 预加载失败不影响后续 show（show 会再拉一次）。
    }
  }

  /// 测试/热重载用：重置初始化状态。
  static void resetForTest() {
    _initialized = false;
    _supported = true;
    _initFuture = null;
  }
}

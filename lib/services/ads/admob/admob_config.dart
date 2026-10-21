import '../ad_types.dart';

/// AdMob 的 Google 官方**测试**激励视频单元（可安全用于开发/审核演示，
/// 不要换成真实 unit 之前就发布）。
///
/// 测试单元永远有填充、不计费、不产生无效流量。上线前务必在
/// `AdMobConfig.production()` / `--dart-define` 里换成自己后台建的 unit。
const String kAdMobTestAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
const String kAdMobTestIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

/// 测试用 App ID（写在 AndroidManifest / Info.plist 里）。
/// 换成正式 App ID 时**两个平台都要换**，只换一个会在启动时崩。
const String kAdMobTestAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';
const String kAdMobTestIosAppId = 'ca-app-pub-3940256099942544~1458002511';

/// AdMob 配置：一个平台一套 unit ID + 合规开关。
///
/// 为什么按广告位分开配：AdMob 后台每个广告位单建 unit，才能在报表里看出
/// 「商店福利 3 次」和「停车提示 10 次」分别值多少钱（eCPM 差 3-5 倍很常见）。
/// 早期共用一个 unit 也能跑，但后面想调优先级就只能重发版。
///
/// 注入方式（优先级从高到低）：
/// 1. 代码里 `AdMobConfig.production(...)` 显式传；
/// 2. 编译期 `--dart-define=ADMOB_ANDROID_UNIT=... --dart-define=ADMOB_IOS_UNIT=...`
///    （所有广告位共用一个 unit，适合先跑通）；
/// 3. 都没配 → Google 官方测试 unit + 测试 App ID，真机可验证但无收入。
class AdMobConfig {
  /// 每个广告位在 Android 上的激励视频 unit ID。
  final Map<AdPlacement, String> androidUnitIds;

  /// 每个广告位在 iOS 上的激励视频 unit ID。
  final Map<AdPlacement, String> iosUnitIds;

  /// 测试设备 ID（真机调试时避免自己点掉真实广告、触发无效流量）。
  /// 运行后从日志里搜 `Use RequestConfiguration.Builder.setTestDeviceIds`
  /// 拿到自己的哈希串。
  final List<String> testDeviceIds;

  /// 是否走 UMP 同意流程（GDPR / CCPA / DMA）。海外发行**必须为 true**：
  /// 欧盟用户不弹同意表单就请求个性化广告，属于违规收集。
  final bool requestConsent;

  /// 是否在 iOS 上请求 ATT 授权（IDFA）。为 false 时 IDFA 恒为零，
  /// 个性化广告失效、eCPM 明显下降。
  final bool requestAtt;

  /// 单次拉取超时（无填充时 SDK 可能长时间不回调）。
  final Duration loadTimeout;

  /// 单次展示超时（兜底：SDK 卡住不回调关闭事件时不要让 UI 永远转圈）。
  final Duration showTimeout;

  const AdMobConfig({
    this.androidUnitIds = const {},
    this.iosUnitIds = const {},
    this.testDeviceIds = const [],
    this.requestConsent = true,
    this.requestAtt = true,
    this.loadTimeout = const Duration(seconds: 12),
    this.showTimeout = const Duration(minutes: 3),
  });

  /// 全测试配置：Google 官方测试 unit，真机可直接看到广告。
  static const AdMobConfig test = AdMobConfig();

  /// 所有广告位共用一个 unit 的简化生产配置。
  factory AdMobConfig.production({
    required String androidUnitId,
    required String iosUnitId,
    List<String> testDeviceIds = const [],
  }) {
    return AdMobConfig(
      androidUnitIds: {
        for (final placement in AdPlacement.values) placement: androidUnitId,
      },
      iosUnitIds: {
        for (final placement in AdPlacement.values) placement: iosUnitId,
      },
      testDeviceIds: testDeviceIds,
    );
  }

  /// 从编译期 `--dart-define` 读配置；没配就回落测试 unit。
  factory AdMobConfig.fromEnvironment() {
    const android = String.fromEnvironment('ADMOB_ANDROID_UNIT');
    const ios = String.fromEnvironment('ADMOB_IOS_UNIT');
    if (android.isEmpty && ios.isEmpty) return test;
    return AdMobConfig.production(
      androidUnitId: android.isEmpty ? kAdMobTestAndroidRewarded : android,
      iosUnitId: ios.isEmpty ? kAdMobTestIosRewarded : ios,
    );
  }

  /// 取某广告位在指定平台的 unit ID，未配置时回落官方测试 unit。
  String unitIdFor(AdPlacement placement, {required bool isIOS}) {
    final map = isIOS ? iosUnitIds : androidUnitIds;
    final configured = map[placement];
    if (configured != null && configured.isNotEmpty) return configured;
    return isIOS ? kAdMobTestIosRewarded : kAdMobTestAndroidRewarded;
  }

  /// 是否仍在用测试 unit（用来在 UI / 日志里提示「演示广告」）。
  bool get usesTestUnits {
    final ids = [...androidUnitIds.values, ...iosUnitIds.values];
    if (ids.isEmpty) return true;
    return ids.every((id) => id.startsWith('ca-app-pub-3940256099942544/'));
  }

  /// App ID 是否仍是测试值（写进平台配置后由 CI/脚本核对）。
  static bool isTestAppId(String appId) =>
      appId.startsWith('ca-app-pub-3940256099942544~');
}

import 'ad_types.dart';

/// 广告 SDK 适配层。
///
/// **本项目采用 AdMob**（发行目标是海外 iOS / Google Play），实现见
/// `admob/admob_ad_provider_io.dart`。其余渠道仅作对比记录：
///
/// | 平台 | 激励视频 | appId 配置 |
/// |---|---|---|
/// | **AdMob（海外，已采用）** | `RewardedAd.load` + `show()` | `MobileAds.initialize` + AndroidManifest / Info.plist 的 App ID |
/// | 穿山甲 CSJ（国内） | `TTAdNative.loadRewardVideoAd` | `AndroidManifest` 的 `com.bytedance.sdk.openadsdk.APPID` |
/// | 优量汇 GDT（国内） | `GDTRewardVideoAd` | `GDTSDKConfig.registerAppId` |
/// | GroMore / MAX（聚合） | 聚合 SDK 的 reward 广告对象 | 后台配置各渠道 + 瀑布流 |
///
/// 实现时必须遵守的三条（否则线上会丢钱或违规）：
/// 1. **只在 SDK 的「奖励回调」里返回 [AdResult.granted]**，`onAdClosed` 但
///    没触发奖励回调 = `skipped`；加载失败/超时 = `failed`。
/// 2. [showRewarded] 必须在 UI 线程被 await 到「广告关闭」才 resolve，
///    不要 fire-and-forget（调用方要靠返回值决定发不发奖）。
/// 3. [initialize] 要幂等，冷启动调一次即可；`preload` 在每次展示后补拉下一条。
abstract class AdProvider {
  /// provider 名（进日志，便于区分 mock / 各渠道）。
  String get name;

  /// 是否为模拟实现（决定 UI 是否显示「演示」提示、是否允许跳过初始化）。
  bool get isMock;

  /// 当前是否在用**官方测试库存**：SDK 是真的、广告画面是真的，但计费为 0。
  ///
  /// 这一位是「能不能上架」之外的独立维度，不要和 [isMock] 混为一谈：
  /// - `isMock == true` → 根本没有广告 SDK，点了立刻发奖（Web / 演示包）
  /// - `isMock == false && usesTestInventory == true` → 真 SDK + 测试 unit
  ///   （真机可验证全链路，但一条收入都没有，**不能上架**）
  /// - 两者都 false → 真实广告，可上架
  ///
  /// 只用于诊断与发布前自检，不参与任何展示逻辑。
  bool get usesTestInventory => true;

  /// 冷启动初始化（幂等）。返回 false 表示环境不支持，后续展示全部走
  /// [AdResult.unavailable]，调用方应静默降级而不是报错弹窗。
  Future<bool> initialize();

  /// 预加载某个广告位（可选：SDK 支持预加载时实现，避免首次点击等待）。
  Future<void> preload(AdPlacement placement) async {}

  /// 展示激励视频，**等到广告关闭/失败后才返回**。
  Future<AdResult> showRewarded(AdPlacement placement);

  /// 应用内是否**必须**提供「隐私设置」入口。
  ///
  /// UMP 的 `PrivacyOptionsRequirementStatus.required` 表示用户必须能随时
  /// 撤回/修改广告同意，否则欧盟区不合规（可被下架）。为 true 时 UI 的
  /// 设置里要展示入口；为 false 时入口可以隐藏或显示「当前无需设置」。
  Future<bool> privacyOptionsRequired() async => false;

  /// 打开隐私设置表单（撤回同意 / 改个性化广告）。返回是否真的弹出过。
  ///
  /// 只在 [privacyOptionsRequired] 为 true 时保证有效；UMP 未发消息时
  /// 会返回 false，调用方据此提示「当前地区无需设置」。
  Future<bool> showPrivacyOptions() async => false;

  Future<void> dispose() async {}
}

import 'ad_types.dart';

/// 广告 SDK 适配层。
///
/// 真实实现（穿山甲 / 优量汇 / GroMore / AdMob）只需实现本接口，**业务代码
/// 一行都不用改**。参考实现要点：
///
/// | 平台 | 激励视频 | appId 配置 |
/// |---|---|---|
/// | 穿山甲 CSJ（国内） | `TTAdNative.loadRewardVideoAd` + `TTRewardVideoAd` | `AndroidManifest` 的 `com.bytedance.sdk.openadsdk.APPID` / Info.plist `BUAdSDKAppID` |
/// | 优量汇 GDT（国内） | `GDTRewardVideoAd` | `GDTSDKConfig.registerAppId` |
/// | AdMob（海外） | `RewardedAd.load` + `show()` | `MobileAds.initialize` + AndroidManifest `APPLICATION_ID` |
/// | GroMore / TopOn（聚合） | 聚合 SDK 的 reward 广告对象 | 后台配置各渠道 + 瀑布流 |
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

  /// 冷启动初始化（幂等）。返回 false 表示环境不支持，后续展示全部走
  /// [AdResult.unavailable]，调用方应静默降级而不是报错弹窗。
  Future<bool> initialize();

  /// 预加载某个广告位（可选：SDK 支持预加载时实现，避免首次点击等待）。
  Future<void> preload(AdPlacement placement) async {}

  /// 展示激励视频，**等到广告关闭/失败后才返回**。
  Future<AdResult> showRewarded(AdPlacement placement);

  Future<void> dispose() async {}
}

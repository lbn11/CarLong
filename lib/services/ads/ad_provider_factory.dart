import 'package:flutter/foundation.dart';

import 'ad_provider.dart';
import 'admob/admob_ad_provider.dart';
import 'mock_ad_provider.dart';

/// 是否强制使用模拟广告（`--dart-define=MOCK_ADS=true`）。
///
/// 用途：给渠道/审核演示「不接 SDK 也能跑完整流程」，以及本地复现
/// 无填充、跳过等失败路径。**不要用它发布**。
const bool kForceMockAds = bool.fromEnvironment('MOCK_ADS');

/// 当前环境的广告 provider 选择（业务代码只认 `AdService`，这里是唯一
/// 需要区分平台的地方）：
///
/// | 环境 | provider | 原因 |
/// |---|---|---|
/// | Web / 桌面 | [MockAdProvider] | AdMob 插件只支持 Android/iOS |
/// | `MOCK_ADS=true` | [MockAdProvider] | 演示 / 失败路径回归 |
/// | Android / iOS | AdMob | 海外发行主渠道 |
///
/// 接其他渠道（AppLovin MAX / ironSource 聚合）时在这里加一个分支即可，
/// 5 个广告位的业务代码一行都不用改。
AdProvider createAdProvider({AdMobConfig? config}) {
  if (kForceMockAds) {
    // 发布包里出现 mock = 这个包一条广告收入都没有。
    // 不直接抛异常（会把演示包砸掉），但要在日志里喊出来，别静默发出去。
    if (kReleaseMode) {
      debugPrint('================ ADS: MOCK PROVIDER IN RELEASE BUILD ================');
      debugPrint('构建时带了 --dart-define=MOCK_ADS=true，全部广告位都在模拟播放。');
      debugPrint('这是给渠道/审核演示用的包，**不能用于上架**。');
      debugPrint('==================================================================');
    }
    return MockAdProvider(
      playback: kIsWeb ? Duration.zero : const Duration(milliseconds: 700),
    );
  }
  if (kIsWeb) {
    // Web 预览不真播，直接返回发奖，截图/自动化测试不用等 0.7 秒。
    return MockAdProvider(playback: Duration.zero);
  }
  return createAdMobProvider(config: config);
}

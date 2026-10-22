import 'dart:math';

import 'ad_provider.dart';
import 'ad_types.dart';

/// 模拟广告 provider：开发/预览/测试用。
///
/// 默认 100% 成功、约 0.7s「播放」延时——**不要在 release 包里留着它当兜底**
/// （等于绕过所有广告），release 必须换成真实 provider；[isMock] 存在的意义
/// 就是让 UI 与日志能识别出「这是演示实现」。
///
/// 注意用 `extends` 而不是 `implements`：[AdProvider] 的 `preload / dispose`
/// 有默认空实现，`implements` 不会继承它们（编译期就会报缺实现）。
class MockAdProvider extends AdProvider {
  /// 模拟播放时长（真实 SDK 是 15-30s 视频）。
  final Duration playback;

  /// 失败概率（0-1），用于本地验证「无填充」降级路径。
  final double failRate;

  /// 中途跳过概率（0-1）。
  final double skipRate;

  /// 测试注入口：设了就按它返回，忽略概率。
  AdOutcome? nextOutcome;

  /// 累计展示次数（测试断言用）。
  int showCount = 0;

  /// 模拟「隐私设置入口是否必须展示」。默认 true，方便在预览里看到入口。
  bool privacyRequired = true;

  /// 模拟隐私表单被打开的次数。
  int privacyShowCount = 0;

  final Random _rng;

  MockAdProvider({
    this.playback = const Duration(milliseconds: 700),
    this.failRate = 0,
    this.skipRate = 0,
    Random? rng,
  }) : _rng = rng ?? Random();

  @override
  String get name => 'mock';

  @override
  bool get isMock => true;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async {
    showCount++;
    if (playback > Duration.zero) await Future<void>.delayed(playback);

    final forced = nextOutcome;
    if (forced != null) {
      nextOutcome = null;
      return AdResult(forced, detail: 'scripted');
    }
    final roll = _rng.nextDouble();
    if (roll < failRate) {
      return const AdResult(AdOutcome.failed, detail: 'mock no-fill');
    }
    if (roll < failRate + skipRate) {
      return const AdResult(AdOutcome.skipped, detail: 'mock skipped');
    }
    return AdResult.granted;
  }

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  /// 演示实现：不弹真实表单，只计数（UI 据此提示「演示环境」）。
  @override
  Future<bool> showPrivacyOptions() async {
    privacyShowCount++;
    if (playback > Duration.zero) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return privacyRequired;
  }
}

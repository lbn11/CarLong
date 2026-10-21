import '../ad_provider.dart';
import '../ad_types.dart';
import 'admob_config.dart';

/// 非移动端（Web / macOS / Windows / Linux）的 AdMob 占位实现。
///
/// `google_mobile_ads` 只声明了 android/ios 两个平台，Web 上一旦实例化就会
/// 抛 `MissingPluginException`。这个文件由 [createAdMobProvider] 通过条件
/// 导入选中，保证 `flutter build web`（本项目用来做可视化预览）不受影响。
class AdMobUnsupportedProvider extends AdProvider {
  final AdMobConfig config;

  AdMobUnsupportedProvider({this.config = AdMobConfig.test});

  @override
  String get name => 'admob-unsupported';

  @override
  bool get isMock => true;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async =>
      const AdResult(AdOutcome.unavailable, detail: 'platform unsupported');
}

/// 创建 AdMob provider（非移动端版本）。
AdProvider createAdMobProvider({AdMobConfig? config}) =>
    AdMobUnsupportedProvider(config: config ?? AdMobConfig.test);

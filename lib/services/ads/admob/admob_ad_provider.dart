import '../ad_provider.dart';
import 'admob_config.dart';
import 'admob_ad_provider_stub.dart'
    if (dart.library.io) 'admob_ad_provider_io.dart' as impl;

export 'admob_config.dart';

/// AdMob provider 的**唯一入口**。
///
/// 条件导入把移动端实现和 Web 占位分开：
/// - Android / iOS → `admob_ad_provider_io.dart`（真实 SDK）
/// - Web / 桌面   → `admob_ad_provider_stub.dart`（永远返回 unavailable）
///
/// 这样 `flutter build web` 不会把 `google_mobile_ads` 拖进产物，
/// 预览环境仍然走 `MockAdProvider`（见 `ad_provider_factory.dart`）。
AdProvider createAdMobProvider({AdMobConfig? config}) =>
    impl.createAdMobProvider(config: config);

import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/services/ads/ad_provider.dart';
import 'package:merge_fleet/services/ads/ad_service.dart';
import 'package:merge_fleet/services/ads/ad_types.dart';
import 'package:merge_fleet/services/ads/admob/admob_ad_provider_stub.dart';
import 'package:merge_fleet/services/ads/admob/admob_config.dart';

/// 记录初始化次数的慢 provider（验证 AdService 的 future 缓存）。
class _SlowInitProvider extends AdProvider {
  int initCount = 0;

  @override
  String get name => 'slow';

  @override
  bool get isMock => false;

  @override
  Future<bool> initialize() async {
    initCount++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return true;
  }

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async => AdResult.granted;
}

bool _looksLikeUnitId(String id) =>
    id.startsWith('ca-app-pub-') && id.contains('/');

void main() {
  group('AdMobConfig', () {
    test('测试配置给全部 5 个广告位都下发可用 unit ID', () {
      for (final placement in AdPlacement.values) {
        final android = AdMobConfig.test.unitIdFor(placement, isIOS: false);
        final ios = AdMobConfig.test.unitIdFor(placement, isIOS: true);
        expect(_looksLikeUnitId(android), isTrue, reason: '$placement android=$android');
        expect(_looksLikeUnitId(ios), isTrue, reason: '$placement ios=$ios');
      }
    });

    test('Android 与 iOS 的测试 unit 不同（AdMob 按平台分 unit）', () {
      for (final placement in AdPlacement.values) {
        expect(
          AdMobConfig.test.unitIdFor(placement, isIOS: false),
          isNot(AdMobConfig.test.unitIdFor(placement, isIOS: true)),
        );
      }
    });

    test('production 配置覆盖全部广告位，且不再判定为测试 unit', () {
      final config = AdMobConfig.production(
        androidUnitId: 'ca-app-pub-1234567890123456/1111111111',
        iosUnitId: 'ca-app-pub-1234567890123456/2222222222',
      );
      expect(config.usesTestUnits, isFalse);
      for (final placement in AdPlacement.values) {
        expect(
          config.unitIdFor(placement, isIOS: false),
          'ca-app-pub-1234567890123456/1111111111',
        );
        expect(
          config.unitIdFor(placement, isIOS: true),
          'ca-app-pub-1234567890123456/2222222222',
        );
      }
    });

    test('只配一侧时另一侧回落测试 unit（不会出现空串请求）', () {
      final config = AdMobConfig.production(
        androidUnitId: 'ca-app-pub-1234567890123456/1111111111',
        iosUnitId: '',
      );
      final ios = config.unitIdFor(AdPlacement.shopDaily, isIOS: true);
      expect(ios, isNotEmpty);
      expect(_looksLikeUnitId(ios), isTrue);
    });

    test('未注入 --dart-define 时 fromEnvironment 回落测试配置', () {
      // 测试进程没有传 ADMOB_*_UNIT，走的就是回落分支。
      final config = AdMobConfig.fromEnvironment();
      expect(config.usesTestUnits, isTrue);
      expect(
        config.unitIdFor(AdPlacement.mergeRevive, isIOS: false),
        kAdMobTestAndroidRewarded,
      );
    });

    test('合规开关默认全开（海外发行必需的 UMP + ATT）', () {
      const config = AdMobConfig.test;
      expect(config.requestConsent, isTrue);
      expect(config.requestAtt, isTrue);
      expect(config.loadTimeout.inSeconds, greaterThanOrEqualTo(8));
    });

    test('测试 App ID 能被识别（防止把测试 ID 发上线）', () {
      expect(AdMobConfig.isTestAppId(kAdMobTestAndroidAppId), isTrue);
      expect(AdMobConfig.isTestAppId(kAdMobTestIosAppId), isTrue);
      expect(AdMobConfig.isTestAppId('ca-app-pub-9876543210987654~1234567890'),
          isFalse);
    });
  });

  group('AdMobUnsupportedProvider（Web/桌面占位）', () {
    test('初始化返回 false，展示一律 unavailable，并标记 isMock', () async {
      final provider = createAdMobProvider();
      expect(provider, isA<AdMobUnsupportedProvider>());
      expect(provider.isMock, isTrue);
      expect(provider.name, 'admob-unsupported');
      expect(await provider.initialize(), isFalse);
      final result = await provider.showRewarded(AdPlacement.shopDaily);
      expect(result.outcome, AdOutcome.unavailable);
    });
  });

  group('AdService 初始化', () {
    test('并发调用只初始化 provider 一次（缓存的是 future 不是 bool）', () async {
      AdService.resetForTest();
      final provider = _SlowInitProvider();
      AdService.provider = provider;
      final results = await Future.wait([
        AdService.initialize(),
        AdService.initialize(),
        AdService.initialize(),
      ]);
      expect(results, everyElement(isTrue));
      expect(provider.initCount, 1);
    });

    test('resetForTest 之后允许重新初始化（热重载/测试相互隔离）', () async {
      AdService.resetForTest();
      final first = _SlowInitProvider();
      AdService.provider = first;
      await AdService.initialize();
      AdService.resetForTest();
      final second = _SlowInitProvider();
      AdService.provider = second;
      await AdService.initialize();
      expect(first.initCount, 1);
      expect(second.initCount, 1);
    });
  });

  group('测试库存判定（决定「这个包能不能上架」）', () {
    test('全测试配置 → usesTestUnits 为 true', () {
      expect(AdMobConfig.test.usesTestUnits, isTrue);
    });

    test('生产配置（5 位双端全真 ID）→ false', () {
      final config = AdMobConfig.production(
        androidUnitId: 'ca-app-pub-9999999999999999/1111111111',
        iosUnitId: 'ca-app-pub-9999999999999999/2222222222',
      );
      expect(config.usesTestUnits, isFalse);
    });

    test('半配置（只填 Android，iOS 回落测试 unit）也必须判成测试库存', () {
      // 这是最容易被漏掉的一种：报表里 Android 有收入、iOS 恒为 0，
      // 但界面上看起来「已经配好了」。
      final config = AdMobConfig(
        androidUnitIds: {
          for (final p in AdPlacement.values)
            p: 'ca-app-pub-9999999999999999/1111111111',
        },
      );
      expect(config.usesTestUnits, isTrue);
    });

    test('5 个位里只有 1 个是测试 unit → 也要判成测试库存', () {
      final config = AdMobConfig(
        androidUnitIds: {
          for (final p in AdPlacement.values)
            p: p == AdPlacement.parkingHint
                ? 'ca-app-pub-3940256099942544/5224354917'
                : 'ca-app-pub-9999999999999999/1111111111',
        },
        iosUnitIds: {
          for (final p in AdPlacement.values)
            p: 'ca-app-pub-9999999999999999/2222222222',
        },
      );
      expect(config.usesTestUnits, isTrue);
    });

    test('测试 App ID 判定（平台配置文件用）', () {
      expect(AdMobConfig.isTestAppId(kAdMobTestAndroidAppId), isTrue);
      expect(AdMobConfig.isTestAppId('ca-app-pub-9999999999999999~1234567890'), isFalse);
    });

    test('provider 把测试库存暴露给诊断层', () {
      // 非移动端占位实现：没有 SDK，当然也不算真实库存。
      final provider = AdMobUnsupportedProvider(config: AdMobConfig.test);
      expect(provider.isMock, isTrue);
      expect(provider.usesTestInventory, isTrue);
    });
  });
}

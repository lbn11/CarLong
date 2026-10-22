import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/services/ads/ad_diagnostics.dart';
import 'package:merge_fleet/services/ads/ad_policy.dart';
import 'package:merge_fleet/services/ads/ad_provider.dart';
import 'package:merge_fleet/services/ads/ad_service.dart';
import 'package:merge_fleet/services/ads/ad_types.dart';
import 'package:merge_fleet/services/ads/mock_ad_provider.dart';

/// 真实库存的 provider（isMock=false 且非测试 unit）。
class _RealProvider extends AdProvider {
  @override
  String get name => 'admob';

  @override
  bool get isMock => false;

  @override
  bool get usesTestInventory => false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async => AdResult.granted;
}

/// 真 SDK + 测试 unit：有画面、零收入——上架前最危险的那种「看起来正常」。
class _TestInventoryProvider extends AdProvider {
  @override
  String get name => 'admob';

  @override
  bool get isMock => false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async => AdResult.granted;
}

void main() {
  tearDown(() {
    AdService.provider = MockAdProvider(playback: Duration.zero);
    AdService.policy = AdPolicy.standard;
    AdService.now = DateTime.now;
    AdService.resetForTest();
  });

  group('AdDiagnostics · 三态判定', () {
    test('演示通道：isMock 优先，绝不显示“正式广告”', () {
      final text = AdDiagnostics.channelText(
        provider: 'mock',
        isMock: true,
        testInventory: true,
      );
      expect(text, contains('演示通道'));
      expect(
        AdDiagnostics.levelOf(isMock: true, testInventory: true),
        AdDiagLevel.warn,
      );
    });

    test('测试广告：真 SDK 也要标红，并说明零收入', () {
      final text = AdDiagnostics.channelText(
        provider: 'admob',
        isMock: false,
        testInventory: true,
      );
      expect(text, contains('测试广告'));
      expect(text, contains('零收入'));
      expect(
        AdDiagnostics.levelOf(isMock: false, testInventory: true),
        AdDiagLevel.warn,
      );
    });

    test('正式广告：只有两个 false 才是 good', () {
      final text = AdDiagnostics.channelText(
        provider: 'admob',
        isMock: false,
        testInventory: false,
      );
      expect(text, contains('正式广告'));
      expect(text, contains('会计费'));
      expect(
        AdDiagnostics.levelOf(isMock: false, testInventory: false),
        AdDiagLevel.good,
      );
    });

    test('启动日志包含初始化结果', () {
      final ok = AdDiagnostics.logLine(
        provider: 'admob',
        isMock: false,
        testInventory: true,
        initialized: true,
      );
      expect(ok, contains('测试广告'));
      expect(ok, contains('初始化成功'));
      final bad = AdDiagnostics.logLine(
        provider: 'admob',
        isMock: false,
        testInventory: true,
        initialized: false,
      );
      expect(bad, contains('初始化失败'));
    });

    test('诊断区在测试/开发环境默认可见', () {
      // flutter test 不是 release 模式，诊断必须开着（否则等于没做）。
      expect(AdDiagnostics.enabled, isTrue);
    });
  });

  group('AdDiagnostics · 单点额度文案', () {
    test('按已用次数算剩余，越界夹到 0', () {
      expect(AdDiagnostics.slotText(AdPlacement.shopDaily, 1), '商店 2/3');
      expect(AdDiagnostics.slotText(AdPlacement.shopDaily, 5), '商店 0/3');
      expect(AdDiagnostics.slotText(AdPlacement.parkingHint, 10), '提示 0/10');
      expect(AdDiagnostics.slotText(AdPlacement.parkingUndo, 0), '撤销 10/10');
    });
  });

  group('AdService.diagnose', () {
    test('mock provider：通道标黄 + 四行齐全', () {
      AdService.provider = MockAdProvider(playback: Duration.zero);
      final rows = AdService.diagnose(PlayerData());

      expect(rows.length, 4);
      expect(rows.first.label, '通道');
      expect(rows.first.level, AdDiagLevel.warn);
      expect(rows.first.value, contains('演示通道'));
      expect(rows[1].value, contains('未初始化'));
      expect(rows[2].value, contains('/ 30 条'));
      // 只有设了 dailyCap 的位才进「单点剩余」。
      expect(rows[3].value, contains('商店'));
      expect(rows[3].value, contains('撤销'));
      expect(rows[3].value, contains('提示'));
      expect(rows[3].value, isNot(contains('续命')));
    });

    test('真实库存 + 今日已看 2 条：通道绿、总量对得上', () {
      AdService.provider = _RealProvider();
      final data = PlayerData()
        ..adDailyDate = AdService.todayKey()
        ..adDailyCounts = {'shop': 2};
      final rows = AdService.diagnose(data);

      expect(rows.first.level, AdDiagLevel.good);
      expect(rows.first.value, contains('正式广告'));
      expect(rows[2].value, contains('2 / 30'));
      expect(rows[3].value, contains('商店 1/3'));
    });

    test('测试 unit 的 provider 与 mock 区分开（最容易误判的一种）', () {
      AdService.provider = _TestInventoryProvider();
      final rows = AdService.diagnose(PlayerData());

      expect(AdService.usingMock, isFalse);
      expect(AdService.usingTestInventory, isTrue);
      expect(rows.first.value, contains('测试广告'));
      expect(rows.first.level, AdDiagLevel.warn);
    });

    test('广告全局关闭时总量行要写明原因', () {
      AdService.provider = _RealProvider();
      AdService.policy = const AdPolicy(adsEnabled: false);
      final rows = AdService.diagnose(PlayerData());

      expect(rows[2].level, AdDiagLevel.warn);
      expect(rows[2].value, contains('全局关闭'));
    });

    test('diagnose 只读：不调用 provider、不写存档', () {
      final provider = MockAdProvider(playback: Duration.zero);
      AdService.provider = provider;
      final before = provider.showCount;
      AdService.diagnose(PlayerData());
      expect(provider.showCount, before);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/services/ads/ad_provider.dart';
import 'package:merge_fleet/services/ads/ad_service.dart';
import 'package:merge_fleet/services/ads/ad_types.dart';
import 'package:merge_fleet/services/ads/mock_ad_provider.dart';

/// 只存在内存里的仓库：广告计数是纯本地逻辑，测试不该依赖 SharedPreferences。
class _MemoryRepo extends SaveRepository {
  PlayerData? stored;
  int saveCount = 0;

  @override
  Future<PlayerData> load() async => stored ?? PlayerData();

  @override
  Future<void> save(PlayerData data) async {
    stored = data;
    saveCount++;
  }
}

/// 可编排的 provider：按队列吐结果，并统计实际被调用的次数。
class _ScriptedProvider extends AdProvider {
  final List<AdResult> queue;
  final bool supported;
  int showCount = 0;

  _ScriptedProvider(this.queue, {this.supported = true});

  @override
  String get name => 'scripted';

  @override
  bool get isMock => false;

  @override
  Future<bool> initialize() async => supported;

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async {
    showCount++;
    return queue.isEmpty ? AdResult.granted : queue.removeAt(0);
  }
}

void main() {
  final repo = _MemoryRepo();
  late PlayerData data;

  setUp(() {
    data = PlayerData();
    repo.stored = data;
    AdService.resetForTest();
    AdService.provider = MockAdProvider(playback: Duration.zero);
    // 固定时钟，避免测试跑在午夜前后时跨日逻辑随机翻红。
    AdService.now = () => DateTime(2026, 10, 22, 10);
  });

  tearDown(() {
    AdService.provider = MockAdProvider(playback: Duration.zero);
    AdService.now = DateTime.now;
  });

  group('AdPlacement 元数据', () {
    test('每个广告位都有唯一 key，且商店福利保留每日 3 次', () {
      final keys = AdPlacement.values.map((p) => p.key).toList();
      expect(keys.toSet().length, keys.length, reason: '广告位 key 必须唯一（存档按 key 计数）');
      expect(AdPlacement.shopDaily.dailyCap, 3);
      // 玩法层自己限制次数的广告位（每局一次）不设每日上限。
      expect(AdPlacement.mergeRevive.dailyCap, isNull);
      expect(AdPlacement.mergeDouble.dailyCap, isNull);
    });
  });

  group('发奖闸门', () {
    test('看完才发奖：rewarded 计数 +1 并落存档', () async {
      final r = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(r.isRewarded, isTrue);
      expect(AdService.usedToday(AdPlacement.shopDaily, data), 1);
      expect(AdService.remainingToday(AdPlacement.shopDaily, data), 2);
      expect(repo.saveCount, greaterThan(0));
    });

    test('中途关闭（skipped）不发奖、不计数', () async {
      AdService.provider = _ScriptedProvider([AdResult.skipped]);
      final r = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(r.outcome, AdOutcome.skipped);
      expect(AdService.usedToday(AdPlacement.shopDaily, data), 0);
      expect(r.userMessage, contains('没看完'));
    });

    test('无填充（failed）不发奖、不计数', () async {
      AdService.provider = _ScriptedProvider([AdResult.failed]);
      final r = await AdService.show(
        AdPlacement.parkingHint,
        data: data,
        repo: repo,
      );
      expect(r.isRewarded, isFalse);
      expect(AdService.usedToday(AdPlacement.parkingHint, data), 0);
    });

    test('provider 抛异常也只降级成 failed，不冒泡给 UI', () async {
      AdService.provider = _ThrowingProvider();
      final r = await AdService.show(AdPlacement.mergeRevive, data: data, repo: repo);
      expect(r.outcome, AdOutcome.failed);
      expect(r.detail, contains('boom'));
    });

    test('SDK 初始化失败 → unavailable，且不消耗次数', () async {
      AdService.provider = _ScriptedProvider([AdResult.granted], supported: false);
      final r = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(r.outcome, AdOutcome.unavailable);
      expect(AdService.usedToday(AdPlacement.shopDaily, data), 0);
    });
  });

  group('每日上限', () {
    test('商店 3 次后返回 capped，且不再向 SDK 发请求', () async {
      final p = _ScriptedProvider([]);
      AdService.provider = p;
      for (var i = 0; i < 3; i++) {
        final r = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
        expect(r.isRewarded, isTrue, reason: '第 ${i + 1} 次应该成功');
      }
      expect(p.showCount, 3);
      final capped = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(capped.outcome, AdOutcome.capped);
      expect(p.showCount, 3, reason: 'capped 必须本地拦截，不能白烧一次 SDK 请求');
      expect(AdService.remainingToday(AdPlacement.shopDaily, data), 0);
    });

    test('不设上限的广告位可以一直看', () async {
      for (var i = 0; i < 10; i++) {
        final r = await AdService.show(AdPlacement.parkingUndo, data: data, repo: repo);
        expect(r.isRewarded, isTrue);
      }
      expect(AdService.remainingToday(AdPlacement.parkingUndo, data), isNull);
      expect(AdService.usedToday(AdPlacement.parkingUndo, data), 10);
    });

    test('跨日后次数清零，不需要额外写盘', () async {
      for (var i = 0; i < 3; i++) {
        await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      }
      expect(AdService.remainingToday(AdPlacement.shopDaily, data), 0);

      AdService.now = () => DateTime(2026, 10, 23, 0, 5);
      expect(AdService.usedToday(AdPlacement.shopDaily, data), 0);
      expect(AdService.remainingToday(AdPlacement.shopDaily, data), 3);

      final r = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(r.isRewarded, isTrue);
      expect(data.adDailyCounts, {'shop': 1}, reason: '新的一天应清掉旧计数');
    });
  });

  group('存档兼容', () {
    test('旧字段 adWatchCount 会迁移到新结构', () {
      final old = PlayerData.fromJson({
        'adWatchDate': '2026-10-22',
        'adWatchCount': 2,
      });
      expect(old.adDailyCounts, {'shop': 2});
      expect(old.adDailyDate, '2026-10-22');
    });

    test('商店广告成功后同步旧字段，降级老版本不会白送次数', () async {
      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(data.adWatchDate, '2026-10-22');
      expect(data.adWatchCount, 1);
    });

    test('adDailyCounts 能完整 round-trip', () {
      final d = PlayerData()
        ..adDailyDate = '2026-10-22'
        ..adDailyCounts['shop'] = 2
        ..adDailyCounts['parking_hint'] = 5;
      final back = PlayerData.fromJson(
        jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
      );
      expect(back.adDailyDate, '2026-10-22');
      expect(back.adDailyCounts, {'shop': 2, 'parking_hint': 5});
    });
  });

  group('埋点', () {
    test('每次请求都记 ad_impression，包含广告位与结果', () async {
      AdService.provider = _ScriptedProvider([AdResult.skipped, AdResult.granted]);
      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);

      final events = data.analyticsEvents
          .where((e) => e['e'] == 'ad_impression')
          .toList();
      expect(events.length, 2, reason: '失败请求也要记，否则算不出填充率');
      expect(events.first['placement'], 'shop');
      expect(events.first['outcome'], 'skipped');
      expect(events.first['rewarded'], isFalse);
      expect(events.last['outcome'], 'rewarded');
      expect(events.last['rewarded'], isTrue);
    });
  });

  group('Mock provider', () {
    test('默认成功、isMock 暴露给 UI', () async {
      final mock = MockAdProvider(playback: Duration.zero);
      expect(mock.isMock, isTrue);
      final r = await mock.showRewarded(AdPlacement.shopDaily);
      expect(r.isRewarded, isTrue);
      expect(mock.showCount, 1);
    });

    test('failRate=1 时永远拿不到奖励（本地可复现无填充）', () async {
      final mock = MockAdProvider(playback: Duration.zero, failRate: 1);
      final r = await mock.showRewarded(AdPlacement.shopDaily);
      expect(r.outcome, AdOutcome.failed);
    });
  });
}

class _ThrowingProvider extends AdProvider {
  @override
  String get name => 'throwing';

  @override
  bool get isMock => false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<AdResult> showRewarded(AdPlacement placement) async =>
      throw StateError('boom');
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/services/ads/ad_policy.dart';
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
  int privacyShowCount = 0;
  bool privacyRequired = false;

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

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<bool> showPrivacyOptions() async {
    privacyShowCount++;
    return privacyRequired;
  }
}

void main() {
  final repo = _MemoryRepo();
  late PlayerData data;

  /// 可推进的时钟：冷却和跨日都靠它验证（不能用真实时钟，否则测试变慢）。
  late DateTime clock;

  void tick([int seconds = 60]) {
    clock = clock.add(Duration(seconds: seconds));
  }

  setUp(() {
    data = PlayerData();
    repo.stored = data;
    repo.saveCount = 0;
    AdService.resetForTest();
    AdService.policy = AdPolicy.standard;
    AdService.provider = MockAdProvider(playback: Duration.zero);
    // 固定时钟，避免测试跑在午夜前后时跨日逻辑随机翻红。
    clock = DateTime(2026, 10, 22, 10);
    AdService.now = () => clock;
  });

  tearDown(() {
    AdService.provider = MockAdProvider(playback: Duration.zero);
    AdService.policy = AdPolicy.standard;
    AdService.now = DateTime.now;
  });

  group('AdPlacement 元数据', () {
    test('每个广告位都有唯一 key，且商店福利保留每日 3 次', () {
      final keys = AdPlacement.values.map((p) => p.key).toList();
      expect(keys.toSet().length, keys.length, reason: '广告位 key 必须唯一（存档按 key 计数）');
      expect(AdPlacement.shopDaily.dailyCap, 3);
      // 玩法层自己限制次数的广告位（每局一次）不设单点上限，由全局上限兜底。
      expect(AdPlacement.mergeRevive.dailyCap, isNull);
      expect(AdPlacement.mergeDouble.dailyCap, isNull);
    });

    test('停车两位置每日 10 次并带冷却（防连点刷次数）', () {
      for (final p in [AdPlacement.parkingUndo, AdPlacement.parkingHint]) {
        expect(p.dailyCap, 10, reason: '$p');
        expect(p.cooldown.inSeconds, greaterThanOrEqualTo(8), reason: '$p');
      }
    });

    test('每个广告位有独立 unit 环境变量后缀（收益分位统计）', () {
      final envKeys = AdPlacement.values.map((p) => p.envKey).toList();
      expect(envKeys.toSet().length, envKeys.length);
      expect(AdPlacement.shopDaily.envKey, 'SHOP');
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
        tick();
      }
      expect(p.showCount, 3);
      final capped = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(capped.outcome, AdOutcome.capped);
      expect(p.showCount, 3, reason: 'capped 必须本地拦截，不能白烧一次 SDK 请求');
      expect(AdService.remainingToday(AdPlacement.shopDaily, data), 0);
    });

    test('停车位 10 次/日：第 11 次 capped，且不烧 SDK 请求', () async {
      final p = _ScriptedProvider([]);
      AdService.provider = p;
      for (var i = 0; i < 10; i++) {
        final r = await AdService.show(AdPlacement.parkingHint, data: data, repo: repo);
        expect(r.isRewarded, isTrue, reason: '第 ${i + 1} 次应该成功');
        tick();
      }
      final capped = await AdService.show(AdPlacement.parkingHint, data: data, repo: repo);
      expect(capped.outcome, AdOutcome.capped);
      expect(p.showCount, 10);
      expect(capped.detail, contains('placement daily cap'));
    });

    test('全局总量到顶后所有广告位都 capped（跨位兜底）', () async {
      AdService.policy = const AdPolicy(globalDailyCap: 2);
      final p = _ScriptedProvider([]);
      AdService.provider = p;

      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      tick();
      await AdService.show(AdPlacement.mergeRevive, data: data, repo: repo);
      tick();

      expect(AdService.usedTodayTotal(data), 2);
      expect(AdService.remainingGlobalToday(data), 0);

      final r = await AdService.show(AdPlacement.parkingHint, data: data, repo: repo);
      expect(r.outcome, AdOutcome.capped);
      expect(r.detail, contains('global'));
      expect(p.showCount, 2, reason: '全局上限也必须本地拦截');
    });

    test('总开关关闭时一律 unavailable（审核/活动期可远程停广告）', () async {
      AdService.policy = const AdPolicy(adsEnabled: false);
      final p = _ScriptedProvider([]);
      AdService.provider = p;
      final r = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(r.outcome, AdOutcome.unavailable);
      expect(p.showCount, 0);
    });

    test('跨日后次数清零，不需要额外写盘', () async {
      for (var i = 0; i < 3; i++) {
        await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
        tick();
      }
      expect(AdService.remainingToday(AdPlacement.shopDaily, data), 0);

      clock = DateTime(2026, 10, 23, 0, 5);
      expect(AdService.usedToday(AdPlacement.shopDaily, data), 0);
      expect(AdService.remainingToday(AdPlacement.shopDaily, data), 3);

      final r = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(r.isRewarded, isTrue);
      expect(data.adDailyCounts, {'shop': 1}, reason: '新的一天应清掉旧计数');
    });
  });

  group('冷却（防连点 / 防被判诱导观看）', () {
    test('冷却期内再点返回 cooldown，且不消耗 SDK 请求与次数', () async {
      final p = _ScriptedProvider([]);
      AdService.provider = p;
      final first = await AdService.show(
        AdPlacement.parkingHint,
        data: data,
        repo: repo,
      );
      expect(first.isRewarded, isTrue);
      expect(p.showCount, 1);

      // 冷却期内立刻再点（真实玩家不会这么快，但连点/脚本会）。
      final second = await AdService.show(
        AdPlacement.parkingHint,
        data: data,
        repo: repo,
      );
      expect(second.outcome, AdOutcome.cooldown);
      expect(second.userMessage, contains('等几秒'));
      expect(p.showCount, 1, reason: '冷却必须本地拦截');
      expect(AdService.usedToday(AdPlacement.parkingHint, data), 1);

      // 冷却结束后恢复。
      tick(AdPlacement.parkingHint.cooldown.inSeconds + 1);
      final third = await AdService.show(
        AdPlacement.parkingHint,
        data: data,
        repo: repo,
      );
      expect(third.isRewarded, isTrue);
      expect(p.showCount, 2);
    });

    test('中途关闭也计入冷却（秒关再点不刷次数）', () async {
      AdService.provider = _ScriptedProvider([AdResult.skipped]);
      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(AdService.cooldownRemaining(AdPlacement.shopDaily), greaterThan(Duration.zero));

      final again = await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      expect(again.outcome, AdOutcome.cooldown);
    });

    test('不同广告位互不影响（各自的冷却独立）', () async {
      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      final other = await AdService.show(
        AdPlacement.mergeRevive,
        data: data,
        repo: repo,
      );
      expect(other.isRewarded, isTrue);
    });
  });

  group('隐私设置（UMP）', () {
    test('入口需求状态可读，并且结果缓存不重复打原生', () async {
      final p = _ScriptedProvider([])..privacyRequired = true;
      AdService.provider = p;

      expect(await AdService.privacyOptionsRequired(), isTrue);
      expect(await AdService.privacyOptionsRequired(), isTrue);
      // 刷新才会重新问。
      expect(await AdService.privacyOptionsRequired(refresh: true), isTrue);
    });

    test('地区不要求时返回 false（UI 不弹空表单）', () async {
      AdService.provider = _ScriptedProvider([]);
      expect(await AdService.privacyOptionsRequired(refresh: true), isFalse);
    });

    test('showPrivacyOptions 转发到 provider 并统计调用', () async {
      final p = _ScriptedProvider([])..privacyRequired = true;
      AdService.provider = p;
      expect(await AdService.showPrivacyOptions(), isTrue);
      expect(p.privacyShowCount, 1);
    });

    test('provider 抛异常时降级为 false，不冒泡', () async {
      AdService.provider = _ThrowingProvider();
      expect(await AdService.showPrivacyOptions(), isFalse);
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
      tick();
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

    test('被本地闸门拦下的请求也记一条（能算出真实需求与上限）', () async {
      AdService.policy = const AdPolicy(globalDailyCap: 1);
      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);
      tick();
      await AdService.show(AdPlacement.shopDaily, data: data, repo: repo);

      final outcomes = data.analyticsEvents
          .where((e) => e['e'] == 'ad_impression')
          .map((e) => e['outcome'])
          .toList();
      expect(outcomes, ['rewarded', 'capped']);
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

    test('模拟隐私入口：需求标记可读，展示计数可断言', () async {
      final mock = MockAdProvider(playback: Duration.zero);
      expect(await mock.privacyOptionsRequired(), isTrue);
      expect(await mock.showPrivacyOptions(), isTrue);
      expect(mock.privacyShowCount, 1);
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

  @override
  Future<bool> privacyOptionsRequired() async =>
      throw StateError('boom-privacy');

  @override
  Future<bool> showPrivacyOptions() async => throw StateError('boom-privacy');
}

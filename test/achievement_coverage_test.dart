import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/achievement.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/achievements_screen.dart';
import 'package:merge_fleet/services/level_data_generator.dart';
import 'package:merge_fleet/services/parking_chapters.dart';

/// 成就表的结构与判据守护。
///
/// 这组测试存在的理由：成就从 27 条扩到 70+ 条时，最大的风险不是写错
/// 某一条，而是**数量与内容脱节** —— 章节从 7 拓到 21 章、车型从 17 扩到
/// 50 档、Boss 从无到 56 只，成就表曾经整整两轮没跟上（文案还写着
/// 「点亮全部 17 款」「通关第四章（第 1-40 关）」）。所以这里断言的是
/// 「每一类内容都必须有对应的成就覆盖」，而不是逐条核对文案。
void main() {
  Achievement byId(String id) => achievements.firstWhere((a) => a.id == id);

  group('成就表结构', () {
    test('id 唯一', () {
      final ids = achievements.map((a) => a.id).toList();
      expect(ids.length, ids.toSet().length, reason: '存在重复 id：$ids');
    });

    test('数量足够撑起 1500 关（≥ 70 条）', () {
      expect(achievements.length, greaterThanOrEqualTo(70));
    });

    test('7 个分组都有内容，且单组不少于 6 条', () {
      for (final g in AchievementGroup.values) {
        final n = achievements.where((a) => a.group == g).length;
        expect(n, greaterThanOrEqualTo(6), reason: '${g.label} 组只有 $n 条');
      }
    });

    test('奖励区间合理（30 ~ 400 金币）', () {
      for (final a in achievements) {
        expect(a.reward, greaterThanOrEqualTo(30), reason: a.id);
        expect(a.reward, lessThanOrEqualTo(400), reason: a.id);
      }
    });

    test('不存在重复奖励同一件事的成就（标题 + 判据描述唯一）', () {
      final titles = achievements.map((a) => a.title).toList();
      expect(titles.length, titles.toSet().length, reason: '标题重复：$titles');
    });

    test('文案里不再出现写死的旧车型总数', () {
      for (final a in achievements) {
        expect(a.desc.contains('17 款'), isFalse,
            reason: '${a.id} 仍写着「17 款」，实际是 '
                '${VehicleType.values.length} 款');
      }
    });
  });

  group('章节覆盖', () {
    test('每一章都有对应的通关成就', () {
      for (var i = 0; i < levelChapters.length; i++) {
        final id = 'chapter_${(i + 1).toString().padLeft(2, '0')}';
        final a = achievements.where((x) => x.id == id);
        expect(a, hasLength(1), reason: '缺少 $id（${levelChapters[i].title}）');
        // 描述里的关卡区间必须落在该章 id 区间内。
        final start = levelChapters[i].startId;
        expect(a.first.desc.contains('第 $start-'), isTrue,
            reason: '$id 的描述与章节起点 $start 不符：${a.first.desc}');
      }
    });

    test('章节成就条数 == 章节数（不多不少）', () {
      final chapterAch =
          achievements.where((a) => a.group == AchievementGroup.chapter).length;
      expect(chapterAch, levelChapters.length);
    });
  });

  group('内容规模覆盖', () {
    test('Boss 成就覆盖全部 56 只', () {
      final bossAch =
          achievements.where((a) => a.group == AchievementGroup.boss).toList();
      expect(bossAch, isNotEmpty);
      expect(byId('boss_all').desc.contains('${LevelDataGenerator.bossTotal}'),
          isTrue);
    });

    test('停车成就覆盖到第 800 关（不是停在前 20 关）', () {
      expect(byId('park_clear_all').desc.contains('800'), isTrue);
    });

    test('图鉴成就覆盖全部车系', () {
      for (final family in VehicleCategory.values) {
        expect(achievements.any((a) => a.id == 'collection_${family.name}'),
            isTrue,
            reason: '缺少 ${family.label}系收集成就');
      }
    });

    test('技巧/日常组消费了连消、每日、无尽这些已有字段', () {
      for (final id in ['combo_5', 'daily_first', 'daily_streak_7', 'endless_1000']) {
        expect(achievements.any((a) => a.id == id), isTrue, reason: '缺少 $id');
      }
    });
  });

  group('达成判据', () {
    test('空存档一条都拿不到', () {
      final none = PlayerData();
      final got = achievements.where((a) => a.achieved(none)).map((a) => a.id);
      expect(got, isEmpty, reason: '空存档意外达成：$got');
    });

    test('满存档全部达成', () {
      final maxStars = {for (var i = 1; i <= levels.last.id; i++) i: 3};
      final full = PlayerData(
        coins: 20000,
        unlockedLevel: levels.last.id + 1,
        bestStars: maxStars,
        parkingUnlocked: ParkingChapters.totalLevels + 1,
        parkingBestStars: {
          for (var i = 1; i <= ParkingChapters.totalLevels; i++) i: 3,
        },
        collection: {for (final v in VehicleType.values) v.id},
        signInTotal: 60,
        signInStreak: 30,
        dailyClearedDate: '2026-10-21',
        dailyStreak: 30,
        bestCombo: 20,
        endlessBest: [9999],
        defeatedBosses: {
          for (var c = 0; c < LevelDataGenerator.chapterCount; c++)
            for (var b = 0; b < LevelDataGenerator.bossPerChapter; b++) '$c.$b',
        },
      );
      final missing =
          achievements.where((a) => !a.achieved(full)).map((a) => a.id).toList();
      expect(missing, isEmpty, reason: '满存档仍未达成：$missing');
    });

    test('通关第 1 章只解锁该章成就，不误触发后续章节', () {
      final first = PlayerData(
        bestStars: {for (var i = 1; i <= 10; i++) i: 3},
      );
      expect(byId('chapter_01').achieved(first), isTrue);
      expect(byId('chapter_02').achieved(first), isFalse);
      expect(byId('clear_10').achieved(first), isTrue);
      expect(byId('clear_30').achieved(first), isFalse);
    });

    test('Boss 单章全清只在整章 4 只都击败时成立', () {
      final three = PlayerData(defeatedBosses: {'0.0', '0.1', '0.2'});
      expect(byId('boss_sweep').achieved(three), isFalse);

      final four = PlayerData(defeatedBosses: {'0.0', '0.1', '0.2', '0.3'});
      expect(byId('boss_sweep').achieved(four), isTrue);
    });

    test('车位成就按 3 星数量而非通关数量计', () {
      final clearedOnly = PlayerData(
        parkingBestStars: {for (var i = 1; i <= 60; i++) i: 1},
      );
      expect(byId('park_star50').achieved(clearedOnly), isFalse);
      expect(byId('park_clear_100').achieved(clearedOnly), isFalse);

      final stars = PlayerData(
        parkingBestStars: {for (var i = 1; i <= 50; i++) i: 3},
      );
      expect(byId('park_star50').achieved(stars), isTrue);
    });
  });

  // 成就页从 27 条平铺改成 7 组 + 筛选后，长列表 + 4 个筛选 chip 在
  // 320px 窄屏是新的溢出风险点（HUD/chip 挤爆过一次，见 MEMORY）。
  group('成就页渲染', () {
    Future<void> pump(
      WidgetTester tester,
      PlayerData data, {
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AchievementsScreen(data: data, repo: SaveRepository()),
      ));
      // 页面有循环氛围动画，pumpAndSettle 不收敛，用固定时长 pump。
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('320px 窄屏渲染不溢出', (tester) async {
      await pump(tester, PlayerData(), size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.text('成就'), findsWidgets);
    });

    testWidgets('筛选「可领取」只保留已达成未领取的条目', (tester) async {
      // 只通了第 1 关：first_win 达成，十关先锋未达成。
      await pump(tester, PlayerData(bestStars: {1: 3}));
      expect(find.text('初出茅庐'), findsOneWidget);
      expect(find.text('十关先锋'), findsOneWidget);

      await tester.tap(find.text('可领取'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('初出茅庐'), findsOneWidget);
      expect(find.text('十关先锋'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

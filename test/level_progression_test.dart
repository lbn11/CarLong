import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/logic/parking_solver.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/services/level_data_generator.dart';
import 'package:merge_fleet/services/level_progression.dart';
import 'package:merge_fleet/services/parking_chapters.dart';
import 'package:merge_fleet/services/parking_generator.dart';

/// 总关卡进度结构（大阶段 / 魔王章 / 广告挑战关）的回归测试。
///
/// 这套结构是「心流小循环」之上的宏观层，测试重点：
/// 1. 广告关占比落在用户拍板的 1/4~1/5，且**相位分布均匀**
///    （判定式必须与心跳周期互质，否则会扎堆单一相位）；
/// 2. 魔王章 = 每 3 章末 + 全表最后一章；
/// 3. 广告关加成真实生效但**不叠加**（魔王章 × 广告关只 +1 档）；
/// 4. 广告关不是墙：依然可解、且预算占用率有上限。
void main() {
  group('广告挑战关：占比与分布', () {
    test('停车：章内每 5 关 1 个，占比 ≈20%', () {
      var count = 0;
      for (var id = 1; id <= ParkingChapters.totalLevels; id++) {
        if (LevelProgression.isParkingAdGate(id)) count++;
      }
      // 22 章 × 每章 8 个（36/37 关内 offset%5==0）= 176，
      // 扣新手期豁免 3 个（章 1 的 offset 0/5/10）= 173。
      expect(count, 173);
      expect(count / ParkingChapters.totalLevels, closeTo(0.216, 0.02));
    });

    test('合成：章内每 4 关 1 个，占比 ≈25%', () {
      var count = 0;
      for (var id = 1; id <= levels.length; id++) {
        if (LevelProgression.isMergeAdGate(id)) count++;
      }
      // 生成段章内偏移 %4==0：每章 12 个，扣除与 Boss 关重叠的 offset 32
      // 后每章 11 个；章 1 再扣新手期豁免的 offset 0（id 71 ≤ 74）。
      // 10 + 13×11 = 153（Boss 关不叠加规则生效的直接证据）。
      expect(count, 153);
      expect(count / levels.length, closeTo(0.22, 0.04));
    });

    test('新手保护期：停车前 15 关、合成前 74 关无广告关', () {
      for (var id = 1; id <= 15; id++) {
        expect(LevelProgression.isParkingAdGate(id), isFalse, reason: 'id=$id');
      }
      for (var id = 1; id <= 74; id++) {
        expect(LevelProgression.isMergeAdGate(id), isFalse, reason: 'id=$id');
      }
    });

    test('停车广告关在全部 6 个相位上出现（与周期 6 互质）', () {
      final phases = <int>{};
      for (var id = 1; id <= ParkingChapters.totalLevels; id++) {
        if (LevelProgression.isParkingAdGate(id)) {
          phases.add(ParkingLevelGenerator.rhythmPhase(id));
        }
      }
      expect(phases, {0, 1, 2, 3, 4, 5});
    });

    test('合成广告关在全部 5 个相位上出现（与周期 5 互质）', () {
      final phases = <int>{};
      for (var id = 71; id <= levels.length; id++) {
        if (LevelProgression.isMergeAdGate(id)) {
          phases.add(LevelDataGenerator.rhythmPhase(id));
        }
      }
      expect(phases, {0, 1, 2, 3, 4});
    });

    test('同章内无连续广告关', () {
      // 跨章边界允许相邻（如章末尖峰难关 + 下章首新车型轻松关），
      // 语义上是「难后接亮相」而非双重压力；同章内必须隔开。
      for (var id = 2; id <= ParkingChapters.totalLevels; id++) {
        if (!LevelProgression.isParkingAdGate(id)) continue;
        if (LevelProgression.parkingChapterIndex(id) !=
            LevelProgression.parkingChapterIndex(id - 1)) {
          continue;
        }
        expect(LevelProgression.isParkingAdGate(id - 1), isFalse,
            reason: 'id=$id 与 id=${id - 1} 同章连续');
      }
      for (var id = 2; id <= levels.length; id++) {
        if (!LevelProgression.isMergeAdGate(id)) continue;
        if (LevelProgression.mergeChapterIndex(id) !=
            LevelProgression.mergeChapterIndex(id - 1)) {
          continue;
        }
        expect(LevelProgression.isMergeAdGate(id - 1), isFalse,
            reason: 'id=$id 与 id=${id - 1} 同章连续');
      }
    });
  });

  group('大阶段与魔王章', () {
    test('停车魔王章 = 每 3 章末 + 最后一章', () {
      final demons = <int>[];
      for (var i = 0; i < ParkingChapters.all.length; i++) {
        if (LevelProgression.isParkingDemon(ParkingChapters.all[i].startId)) {
          demons.add(i);
        }
      }
      // 22 章：index 2,5,8,11,14,17,20（最后一章 index 21 是阶段首章，
      // 按「不连续魔王章」规则把收官让给 index 20）。
      expect(demons, [2, 5, 8, 11, 14, 17, 20]);
    });

    test('合成魔王章 = 每 3 章末 + 最后一章', () {
      final demons = <int>{};
      for (final c in levelChapters) {
        if (LevelProgression.isMergeDemon(c.startId)) {
          demons.add(levelChapters.indexOf(c));
        }
      }
      // 21 章：index 2,5,8,11,14,17,20
      expect(demons, {2, 5, 8, 11, 14, 17, 20});
    });

    test('阶段序号单调不回退，且首章恒为阶段起点', () {
      var last = -1;
      for (var i = 0; i < ParkingChapters.all.length; i++) {
        final s = LevelProgression.stageOf(i);
        expect(s, greaterThanOrEqualTo(last));
        if (s > last) {
          expect(i % LevelProgression.stageChapters, 0);
        }
        last = s;
      }
    });

    test('阶段名非空且越界回退', () {
      expect(LevelProgression.stageName(0), '启航');
      expect(LevelProgression.stageName(999), '巅峰');
    });
  });

  group('停车广告关难度加成', () {
    test('同相位下广告关 target = 普通关 +1', () {
      // 章 4（id 109-144，5x5，非魔王章）：offset 5 → id 114 是广告关
      // 且 phase 5；offset 11 → id 120 是非广告同相位关。
      expect(LevelProgression.isParkingDemon(109), isFalse);
      expect(LevelProgression.isParkingAdGate(114), isTrue);
      expect(LevelProgression.isParkingAdGate(120), isFalse);
      expect(ParkingLevelGenerator.rhythmPhase(114), 5);
      expect(ParkingLevelGenerator.rhythmPhase(120), 5);
      expect(ParkingLevelGenerator.targetMinMoves(114, 5), 4);
      expect(ParkingLevelGenerator.targetMinMoves(120, 5), 3);
    });

    test('魔王章 × 广告关不叠加：只 +1 档', () {
      // 章 3 是魔王章；offset 15 → id 88 既是广告关又是魔王章内，phase 3。
      expect(LevelProgression.isParkingDemon(73), isTrue);
      expect(LevelProgression.isParkingAdGate(88), isTrue);
      // 基线 2.44 × 0.70 ≈ 1.7 → round 2；+1 = 3（叠加会是 4）。
      expect(ParkingLevelGenerator.targetMinMoves(88, 3), 3);
    });

    test('广告关仍 100% 可解且无 1 步弱关', () {
      var checked = 0;
      for (var id = 20; id <= 400; id++) {
        if (!LevelProgression.isParkingAdGate(id)) continue;
        final lvl = ParkingLevelGenerator.generateOne(id);
        final real = ParkingSolver.minMoves(lvl, maxStates: 200000);
        expect(real, isNotNull, reason: 'id=$id 不可解');
        expect(real!, greaterThanOrEqualTo(2), reason: 'id=$id 一步弱关');
        checked++;
      }
      expect(checked, greaterThan(50));
    });
  });

  group('合成广告关牌堆收紧', () {
    test('广告关预算占用率有上限（难一档但不是墙）', () {
      var n = 0;
      for (var id = 75; id <= levels.length; id++) {
        if (!LevelProgression.isMergeAdGate(id)) continue;
        final lvl = levels[id - 1];
        if (lvl.goalType != GoalType.produce) continue;
        final expected = LevelDataGenerator.expectedDraws(lvl);
        if (expected <= 0) continue;
        final slack = expected / lvl.stockSize;
        // 心流通道上限 0.55，广告关放宽到 0.60 仍远低于「必须全中」的 1.0
        expect(slack, lessThanOrEqualTo(0.60), reason: 'id=$id slack=$slack');
        n++;
      }
      expect(n, greaterThan(60));
    });

    test('非广告关预算占用率维持原通道（魔王章 / Boss 关单独放行）', () {
      for (var id = 75; id <= levels.length; id++) {
        if (LevelProgression.isMergeAdGate(id)) continue;
        final lvl = levels[id - 1];
        if (lvl.goalType != GoalType.produce) continue;
        final expected = LevelDataGenerator.expectedDraws(lvl);
        if (expected <= 0) continue;
        final slack = expected / lvl.stockSize;
        if (LevelProgression.isMergeBossLevel(id)) {
          // Boss 关：全表最紧节点，上限放到 0.62（仍远低于无解线 1.0）
          expect(slack, lessThanOrEqualTo(0.62), reason: 'id=$id Boss 关');
        } else if (LevelProgression.isMergeDemon(id)) {
          // 魔王章 ×0.95：上限放到 0.58
          expect(slack, lessThanOrEqualTo(0.58), reason: 'id=$id 魔王章');
        } else {
          expect(slack, lessThanOrEqualTo(0.56), reason: 'id=$id');
        }
      }
    });

    test('广告关整体比普通关更紧（均值比较）', () {
      double meanOf(bool adGate) {
        var sum = 0.0;
        var n = 0;
        for (var id = 75; id <= levels.length; id++) {
          if (LevelProgression.isMergeAdGate(id) != adGate) continue;
          final lvl = levels[id - 1];
          if (lvl.goalType != GoalType.produce) continue;
          final expected = LevelDataGenerator.expectedDraws(lvl);
          if (expected <= 0) continue;
          sum += expected / lvl.stockSize;
          n++;
        }
        return sum / n;
      }

      expect(meanOf(true), greaterThan(meanOf(false)));
    });
  });

  group('合成 Boss 关：两个完整心跳后一个', () {
    test('每章 4 个（offset 10/21/32/43），全表 56 个', () {
      final ids = <int>[];
      for (var id = 71; id <= levels.length; id++) {
        if (LevelProgression.isMergeBossLevel(id)) ids.add(id);
      }
      expect(ids.length, 56);
      expect(ids.first, 81); // 第一个 Boss：两个心跳（10 关）之后
      expect(ids.last, 699); // 末章收官位
      for (var c = 0; c < LevelDataGenerator.chapterCount; c++) {
        final start =
            LevelDataGenerator.firstId + c * LevelDataGenerator.chapterSize;
        expect(
          ids.where((i) => i >= start && i < start + 45).map((i) => i - start),
          [10, 21, 32, 43],
          reason: '第 $c 章',
        );
      }
    });

    test('两个 Boss 之间隔 10-11 个普通关（章边界多 1）', () {
      // 章内：offset 10→21→32→43，间隔 11；
      // 跨章：offset 43 → 下章 offset 10 = 45-43+10 = 12（间隔 11 个普通关）。
      var last = 0;
      for (var id = 71; id <= levels.length; id++) {
        if (!LevelProgression.isMergeBossLevel(id)) continue;
        if (last > 0) {
          final gap = id - last;
          expect(gap, anyOf(11, 12), reason: 'id=$id gap=$gap');
        }
        last = id;
      }
    });

    test('Boss 在相位 0-3 轮转，永不叠加硬仗峰值', () {
      // 11 mod 5 = 1 → 每章 4 个 Boss 依次落在 phase 0/1/2/3。
      // 关键不变量：永不在 phase 4（硬仗）——不会双重高压。
      final phases = <int>{};
      for (var id = 71; id <= levels.length; id++) {
        if (!LevelProgression.isMergeBossLevel(id)) continue;
        phases.add(LevelDataGenerator.rhythmPhase(id));
      }
      expect(phases, {0, 1, 2, 3});
      expect(phases.contains(4), isFalse);
    });

    test('每章第一个 Boss 落在轻松槽（打断预期）', () {
      // 章 1：offset 10 → id 81，phase 0（本该是新车型亮相关）
      expect(LevelProgression.isMergeBossLevel(81), isTrue);
      expect(LevelDataGenerator.rhythmPhase(81), 0);
    });

    test('手写段（L1-70）无 Boss 关；停车模式无 Boss 概念', () {
      for (var id = 1; id <= 70; id++) {
        expect(LevelProgression.isMergeBossLevel(id), isFalse, reason: 'id=$id');
      }
      // 停车模式没有 Boss 关：滑块解谜无「敌人」概念，难度即谜题结构，
      // 高峰位由尖峰相位（每 6 关一个）承担。这一层是「没有代码路径」
      // 而非「关掉开关」——停车生成器没有任何 Boss 分支，
      // 因此这里只锁死停车心流相位集合不被 Boss 语义污染。
      for (var id = 1; id <= ParkingChapters.totalLevels; id += 7) {
        final phase = ParkingLevelGenerator.rhythmPhase(id);
        expect(phase, greaterThanOrEqualTo(0));
        expect(phase, lessThanOrEqualTo(5));
      }
    });

    test('与广告关不叠加（Boss 更强，取 Boss）', () {
      for (var id = 71; id <= levels.length; id++) {
        if (LevelProgression.isMergeBossLevel(id)) {
          expect(LevelProgression.isMergeAdGate(id), isFalse, reason: 'id=$id');
        }
      }
    });

    test('Boss 配方：+2 档 / 障碍更多 / 无补给 / 专属命名', () {
      // L81：章 0 组 2，普通档位 21 → Boss 23；普通轻松关 L71 档位 20。
      final boss = levels[80];
      expect(LevelProgression.isMergeBossLevel(81), isTrue);
      expect(boss.targetTier!.index, 23);
      expect(boss.targetCount, 1);
      expect(boss.wildcards, 0); // 无万能卡补给
      expect(boss.bombs, 0); // 无炸弹补给
      expect(boss.name.startsWith('👑'), isTrue);

      final normal = levels[70]; // L71：同章普通轻松关
      expect(LevelProgression.isMergeBossLevel(71), isFalse);
      expect(normal.targetTier!.index, 20);
      // 障碍：轻松关 -1，Boss 再 +2（净 +1，且不低于普通关）
      expect(boss.obstacles.length, greaterThan(normal.obstacles.length));
      expect(boss.obstacles.length, greaterThanOrEqualTo(2));

      // 深水区 Boss 顶到障碍上限 6（L666：末章 offset 10）
      final lateBoss = levels[665];
      expect(LevelProgression.isMergeBossLevel(666), isTrue);
      expect(lateBoss.obstacles.length, 6);
    });

    test('Boss 关是全表最紧节点但远不是墙', () {
      var n = 0;
      var maxSlack = 0.0;
      for (var id = 71; id <= levels.length; id++) {
        if (!LevelProgression.isMergeBossLevel(id)) continue;
        final lvl = levels[id - 1];
        if (lvl.goalType != GoalType.produce) continue;
        final expected = LevelDataGenerator.expectedDraws(lvl);
        expect(expected, greaterThan(0), reason: 'id=$id');
        // 构造上可达成：牌堆 ≥ 期望出牌数
        expect(lvl.stockSize, greaterThanOrEqualTo(expected),
            reason: 'id=$id 牌堆低于期望');
        maxSlack = math.max(maxSlack, expected / lvl.stockSize);
        n++;
      }
      expect(n, 56);
      // 刻意超出心流通道上限 0.55（Boss 就是用来超出日常节奏的），
      // 但必须低于焦虑线：远不是「必须全中」的墙，失败有广告支援。
      expect(maxSlack, greaterThan(0.55));
      expect(maxSlack, lessThanOrEqualTo(0.62));
    });

    test('Boss 关整体比普通关更紧（均值比较）', () {
      double meanOf(bool boss) {
        var sum = 0.0;
        var n = 0;
        for (var id = 75; id <= levels.length; id++) {
          if (LevelProgression.isMergeBossLevel(id) != boss) continue;
          final lvl = levels[id - 1];
          if (lvl.goalType != GoalType.produce) continue;
          final expected = LevelDataGenerator.expectedDraws(lvl);
          if (expected <= 0) continue;
          sum += expected / lvl.stockSize;
          n++;
        }
        return sum / n;
      }

      expect(meanOf(true), greaterThan(meanOf(false)));
    });
  });
}

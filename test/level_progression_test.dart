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
      // 生成段 75..700，章内偏移 %4==0：每章 45/4 ≈ 11 个 × 14 章 ≈ 157
      expect(count, greaterThan(140));
      expect(count, lessThan(175));
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

    test('非广告关预算占用率维持原通道（魔王章单独放行）', () {
      for (var id = 75; id <= levels.length; id++) {
        if (LevelProgression.isMergeAdGate(id)) continue;
        final lvl = levels[id - 1];
        if (lvl.goalType != GoalType.produce) continue;
        final expected = LevelDataGenerator.expectedDraws(lvl);
        if (expected <= 0) continue;
        final slack = expected / lvl.stockSize;
        if (LevelProgression.isMergeDemon(id)) {
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
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/car.dart';
import 'package:merge_fleet/models/level.dart';

/// 正式回归测试（任务70）：合成链产出耐刷性。
/// 模型：无限棋盘贪心三消（忽略棋盘容量/死局，给出理论下界）。
/// 断言：所有 produce 关的 p50 出牌数 <= stockSize × 0.9（留余量）。
/// 防止未来关卡表/权重改动让高目标关再次"设计上不可达成"。
void main() {
  test('all produce levels are reachable within stock (p50 <= 0.9*stock)', () {
    final rng = Random(42);
    final failures = <String>[];

    for (final lvl in levels) {
      if (lvl.goalType != GoalType.produce) continue;
      final weights = lvl.spawnWeights();
      final totalW = weights.fold(0, (a, b) => a + b);
      int tierFor() {
        var roll = rng.nextInt(totalW);
        for (var i = 0; i < weights.length; i++) {
          roll -= weights[i];
          if (roll < 0) return i;
        }
        return 0;
      }

      final draws = <int>[];
      final nTiers = CarTier.values.length;
      final cap = lvl.targetTier!.index;
      for (var sim = 0; sim < 240; sim++) {
        final count = List<int>.filled(nTiers, 0);
        var d = 0;
        while (true) {
          d++;
          count[tierFor()]++;
          for (var i = 0; i < cap; i++) {
            if (count[i] >= 3) {
              count[i] -= 3;
              count[i + 1]++;
            }
          }
          if (count[cap] >= lvl.targetCount) break;
          if (d > 3000) break;
        }
        draws.add(d);
      }
      draws.sort();
      final p50 = draws[draws.length ~/ 2];
      final budget = (lvl.stockSize * 0.9).round();
      if (p50 > budget) {
        failures.add('L${lvl.id} ${lvl.name} target=${lvl.targetTier!.name} '
            'x${lvl.targetCount} stock=${lvl.stockSize} p50=$p50 > budget=$budget');
      }
    }

    expect(failures, isEmpty,
        reason: '以下关卡 p50 超过 stock 的 90%，设计上难以达成：\n'
            '${failures.join('\n')}');
  });
}

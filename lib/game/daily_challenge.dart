import 'dart:math';

import '../models/car.dart';
import '../models/level.dart';

/// 每日挑战：按日期确定性生成一关，每天一个，首次通关领大奖。
class DailyChallenge {
  /// 当日首次通关的固定奖励。
  static const int reward = 150;

  /// 每日关卡 id（避开正常关卡 1-50）。
  static const int levelId = 900;

  /// 根据日期生成当天的关卡（同一天内完全一致）。
  static LevelDefinition levelFor(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final rng = Random(seed);

    // 目标等级取 bus(4)..train(6)，保证当天可完成、又有变化。
    final targetTier = CarTier.values[4 + rng.nextInt(3)];
    final targetCount = 1 + rng.nextInt(2);
    // 约三分之一的日子限时。
    final timed = rng.nextInt(3) == 0;

    // 随机 0-2 个障碍（冰/锁/石），避免堵死角落。
    final obstacles = <ObstacleSpec>[];
    final used = <int>{};
    final n = rng.nextInt(3);
    for (var i = 0; i < n; i++) {
      final pos = rng.nextInt(25);
      if (!used.add(pos)) continue;
      final col = pos ~/ 5;
      final row = pos % 5;
      // 石块不上角落，避免卡死。
      if (col == 0 && row == 0) continue;
      if (col == 4 && row == 4) continue;
      final type = ObstacleType.values[rng.nextInt(3)];
      obstacles.add(ObstacleSpec(type, col, row, layers: 2));
    }

    return LevelDefinition(
      id: levelId,
      name: '每日挑战',
      cols: 5,
      rows: 5,
      stockSize: 40,
      targetTier: targetTier,
      targetCount: targetCount,
      daily: true,
      timeLimitSeconds: timed ? 90 : null,
      obstacles: obstacles,
    );
  }
}
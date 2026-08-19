import '../models/car.dart';
import '../models/level.dart';

/// 主线关卡数据生成器（71-200 关）：在 70 关手写表之后程序化扩展。
///
/// 与手写关一致的要求：
/// - 确定性：同一 id 永远生成同一关（纯函数，无随机种子）。
/// - 耐刷性：高目标关必须配 highTierBias（3合1 指数成本 vs 线性权重，
///   无 bias 会导致"设计上不可达成"，见 test/merge_output_sim_test.dart）。
class LevelDataGenerator {
  /// 生成 71-200 关（130 关）。
  static List<LevelDefinition> levels71To200() {
    return [for (var i = 71; i <= 200; i++) _generateLevel(i)];
  }

  static LevelDefinition _generateLevel(int id) {
    final tier = _tierForLevel(id);
    final size = id < 100 ? 5 : (id < 150 ? 5 : 6);
    final obstacles = ((id - 70) ~/ 10).clamp(0, 8);
    final timeLimit = id % 3 == 0 ? 90 + ((id - 70) ~/ 5) * 5 : null;
    final targetCount = (id < 120) ? 1 : ((id < 180) ? 2 : 3);

    return LevelDefinition(
      id: id,
      name: _chapterName(id),
      cols: size,
      rows: size,
      stockSize: 30 + (id - 70),
      targetTier: tier,
      targetCount: targetCount,
      goalType: id % 7 == 0 ? GoalType.clearBoard : GoalType.produce,
      timeLimitSeconds: timeLimit,
      highTierBias: _autoBias(tier, targetCount),
      obstacles: _generateObstacles(obstacles, size),
    );
  }

  /// 自动 bias：目标档越高、目标数越多，偏置越大。
  /// 经验校准（#70 搜索结论）：x1 低中档 0-2，x1 高档 4-6，x2/x3 再 +2~3。
  static int _autoBias(CarTier tier, int count) {
    final depth = tier.index - 4; // bus(4) 起算
    final base = depth <= 0
        ? 0
        : (depth <= 2
            ? 1
            : (depth <= 4
                ? 2
                : (depth <= 6 ? 4 : (depth <= 8 ? 5 : 6))));
    final countBonus = count >= 3 ? 3 : (count >= 2 ? 2 : 0);
    return base + countBonus;
  }

  static CarTier _tierForLevel(int id) {
    if (id < 90) return CarTier.bus;
    if (id < 110) return CarTier.truck;
    if (id < 130) return CarTier.train;
    if (id < 150) return CarTier.metro;
    if (id < 170) return CarTier.jet;
    if (id < 190) return CarTier.shuttle;
    return CarTier.ufo;
  }

  static String _chapterName(int id) {
    if (id < 90) return '地铁线';
    if (id < 110) return '航空港';
    if (id < 130) return '星际前哨';
    if (id < 150) return '深空巡航';
    if (id < 170) return '时空裂隙';
    if (id < 190) return '宇宙尽头';
    return '彗星计划';
  }

  static List<ObstacleSpec> _generateObstacles(int count, int size) {
    final obstacles = <ObstacleSpec>[];
    const types = [
      ObstacleType.block,
      ObstacleType.ice,
      ObstacleType.lock,
      ObstacleType.teleport,
    ];

    for (var i = 0; i < count; i++) {
      final type = types[i % types.length];
      final c = ((i * 7 + 3) % (size - 2)) + 1;
      final r = ((i * 11 + 5) % (size - 2)) + 1;
      obstacles.add(ObstacleSpec(type, c, r,
          layers: type == ObstacleType.ice ? 2 + (i % 2) : 2));
    }
    return obstacles;
  }
}

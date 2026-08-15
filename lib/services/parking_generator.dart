import '../models/parking_level.dart';
import '../models/car.dart';

/// 停车关卡生成器
class ParkingLevelGenerator {
  static List<ParkingLevel> generate({int count = 1000}) {
    final levels = <ParkingLevel>[];

    for (var i = 1; i <= count; i++) {
      levels.add(_generateLevel(i));
    }
    return levels;
  }

  static ParkingLevel _generateLevel(int id) {
    // 难度递增
    final tier = _tierForLevel(id);
    final size = id < 50 ? 4 : (id < 200 ? 5 : 6);
    final obstacles = (id ~/ 50).clamp(0, 6);

    return ParkingLevel(
      id: id,
      name: '停车 #$id',
      rows: size,
      cols: size,
      grid: _generateGrid(size, obstacles),
      vehicles: _generateVehicles(id, size, tier),
      targetTier: tier,
      timeLimit: id >= 100 ? 120 + (id ~/ 10) * 10 : null,
      movesLimit: id >= 50 ? size * 8 : null,
    );
  }

  static CarTier _tierForLevel(int id) {
    if (id < 50) return CarTier.bike;
    if (id < 150) return CarTier.scooter;
    if (id < 300) return CarTier.car;
    if (id < 500) return CarTier.taxi;
    if (id < 700) return CarTier.bus;
    if (id < 900) return CarTier.truck;
    return CarTier.train;
  }

  static List<List<ParkingCellType>> _generateGrid(int size, int obstacleCount) {
    final grid = List.generate(
      size,
      (_) => List.filled(size, ParkingCellType.road),
    );

    // 入口和出口
    grid[0][0] = ParkingCellType.entrance;
    grid[size - 1][size - 1] = ParkingCellType.exit;

    // 随机障碍
    var placed = 0;
    while (placed < obstacleCount) {
      final c = (size * 0.3 + (placed * 7) % (size * 0.4)).toInt();
      final r = (size * 0.3 + (placed * 11) % (size * 0.4)).toInt();
      if (grid[r][c] == ParkingCellType.road) {
        grid[r][c] = ParkingCellType.obstacle;
        placed++;
      }
    }

    return grid;
  }

  static List<VehicleSpawn> _generateVehicles(int id, int size, CarTier tier) {
    final count = id < 100 ? 2 : (id < 500 ? 3 : 4);
    return List.generate(
      count,
      (i) => VehicleSpawn(
        col: (i * 3 + 1) % size,
        row: (i * 5 + 2) % size,
        tier: CarTier.fromIndex((tier.index - 1).clamp(0, CarTier.values.length - 1)),
        count: 1,
      ),
    );
  }
}

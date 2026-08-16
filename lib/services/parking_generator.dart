import '../models/parking_level.dart';
import '../models/car.dart';

/// 停车关卡生成器 (Car Master 3D 风格)
class ParkingLevelGenerator {
  static List<ParkingLevel> generate({int count = 1000}) {
    final levels = <ParkingLevel>[];

    for (var i = 1; i <= count; i++) {
      levels.add(_generateLevel(i));
    }
    return levels;
  }

  /// 按 id 取单个关卡（下一关、重试时复用，保持确定性）。
  static ParkingLevel generateOne(int id) => _generateLevel(id);

  static ParkingLevel _generateLevel(int id) {
    // 难度递增
    final tier = _tierForLevel(id);
    final size = id < 50 ? 4 : (id < 200 ? 5 : 6);
    final obstacleCount = (id ~/ 50).clamp(0, 6);

    // 基础网格
    final grid = List.generate(size, (_) => List.filled(size, ParkingCellType.road));
    grid[0][0] = ParkingCellType.entrance;
    grid[size - 1][size - 1] = ParkingCellType.exit;

    // 停车位在底部
    final parkRow = size - 1;
    final parkCol = (size - 2).clamp(0, size - 1);
    grid[parkRow][parkCol] = ParkingCellType.parking;

    // 障碍（避开停车列）
    var placed = 0;
    var seed = id * 7;
    while (placed < obstacleCount && placed < size) {
      final c = (seed % (size - 1)).clamp(0, size - 1);
      final r = ((seed * 3) % (size - 1)).clamp(0, size - 1);
      seed = seed * 11 + 7;
      if (grid[r][c] == ParkingCellType.road && c != parkCol) {
        grid[r][c] = ParkingCellType.obstacle;
        placed++;
      }
    }

    // 车辆：1 辆目标车（停在第一列，与停车位同行）
    final vehicles = <VehicleSpawn>[
      VehicleSpawn(col: 0, row: parkRow, tier: tier, count: 1),
    ];

    // 填充车（挡路的，低一等级）
    final fillTier = CarTier.fromIndex((tier.index - 1).clamp(0, CarTier.values.length - 1));
    final fillCount = id < 100 ? 1 : (id < 500 ? 2 : 3);
    for (var i = 0; i < fillCount; i++) {
      var row = (i * 2 + 1) % (size - 1);
      var col = (parkCol ~/ 2 + i) % size;
      if (row == parkRow) row = (row + 1) % (size - 1);
      vehicles.add(VehicleSpawn(col: col, row: row, tier: fillTier));
    }

    return ParkingLevel(
      id: id,
      name: '停车 #$id',
      rows: size,
      cols: size,
      grid: grid,
      vehicles: vehicles,
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
}

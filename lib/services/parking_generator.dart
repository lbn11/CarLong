import 'dart:math';

import '../logic/parking_solver.dart';
import '../models/car.dart';
import '../models/parking_level.dart';

/// 停车关卡生成器 (Car Master 3D 风格)
///
/// 设计要点：
/// - 每关都经 [ParkingSolver] 校验可解；不可解则换种子重试（有上限），保证永不产出死局。
/// - 求解出的真实最短步数写入 [ParkingLevel.minMoves]，并据此标定 movesLimit / timeLimit，
///   使"按最优解通关"可拿三星，难度随 id 平滑递增。
/// - 全程基于 id 的确定性随机，generateOne(id) 与 generate() 结果一致、可复现。
class ParkingLevelGenerator {
  /// 单关求解器状态上限：有解关卡通常 <1ms，无解关会在该上限内放弃并重试。
  static const int _maxSolverStates = 40000;

  /// 每关最多重生成次数（防极端情况下耗时过长）。
  static const int _maxRetries = 40;

  static List<ParkingLevel> generate({int count = 1000}) {
    return [
      for (var i = 1; i <= count; i++) generateOne(i),
    ];
  }

  /// 按 id 取单个关卡（下一关、重试时复用，保持确定性）。
  static ParkingLevel generateOne(int id) => _generateLevel(id);

  static ParkingLevel _generateLevel(int id) {
    final rng = Random(id * 2654435761 % 2147483647);
    final size = id < 50 ? 4 : (id < 200 ? 5 : 6);
    final tier = _tierForLevel(id);
    final fillTier =
        CarTier.fromIndex((tier.index - 1).clamp(0, CarTier.values.length - 1));

    // 障碍 / 挡路车数量随难度缓慢增长（上限受棋盘大小约束，降低堵死概率）。
    final obstacleCount = ((id ~/ 15).clamp(0, size - 2));
    final fillCount = (id < 30 ? 1 : (id < 200 ? 2 : 3)).clamp(1, size - 2);

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final candidate = _tryBuild(
        rng,
        id: id,
        size: size,
        tier: tier,
        fillTier: fillTier,
        obstacleCount: obstacleCount,
        fillCount: fillCount,
      );
      final minMoves = ParkingSolver.minMoves(
        candidate,
        maxStates: _maxSolverStates,
      );
      if (minMoves == null) continue; // 不可解，换种子重试。

      // 难度下限：较大棋盘要求更长的合理最优解，避免"一步通关"的弱关。
      final floor = size <= 4 ? 2 : 3;
      if (minMoves < floor) continue; // 太易，换种子重试。

      // 标定难度：最优解可拿三星，给足余量。
      final movesLimit = max(minMoves * 2, minMoves + 4).toInt();
      final timeLimit = id >= 100
          ? (minMoves * 8 + 25).clamp(60, 600).toInt()
          : null;

      return candidate.copyWith(
        minMoves: minMoves,
        movesLimit: movesLimit,
        timeLimit: timeLimit,
      );
    }

    // 兜底：极端情况下退化为"目标车在停车位同行、一步可解"的简单关，永不死局。
    return _fallbackLevel(id, size, tier, fillTier);
  }

  static ParkingLevel _tryBuild(
    Random rng, {
    required int id,
    required int size,
    required CarTier tier,
    required CarTier fillTier,
    required int obstacleCount,
    required int fillCount,
  }) {
    final pr = size - 1; // 停车位所在行（底部）
    final pc = (size - 2).clamp(0, size - 1); // 停车位所在列

    final grid = List.generate(
      size,
      (_) => List.filled(size, ParkingCellType.road),
    );
    grid[0][0] = ParkingCellType.entrance; // 装饰性入口
    grid[pr][pc] = ParkingCellType.parking;

    // 目标车起点：强制放在非停车行（棋盘较小时放开），制造需要纵向移动的解谜空间。
    int tr;
    if (size <= 4) {
      tr = rng.nextInt(size);
    } else {
      tr = rng.nextInt(size - 1); // 0 .. size-2，必不在底部停车行
    }
    int tc = rng.nextInt(size);
    var guard = 0;
    while ((tr == pr && tc == pc) || (tr == 0 && tc == 0) && guard++ < 50) {
      if (size <= 4) {
        tr = rng.nextInt(size);
      } else {
        tr = rng.nextInt(size - 1);
      }
      tc = rng.nextInt(size);
    }

    final vehicles = <VehicleSpawn>[
      VehicleSpawn(col: tc, row: tr, tier: tier), // 目标车
    ];

    // 障碍：只放在 road 上，且不在停车位、入口、目标车占位。
    var placed = 0;
    guard = 0;
    while (placed < obstacleCount && guard++ < 200) {
      final r = rng.nextInt(size);
      final c = rng.nextInt(size);
      if (grid[r][c] == ParkingCellType.road &&
          !(r == pr && c == pc) &&
          !(r == tr && c == tc)) {
        grid[r][c] = ParkingCellType.obstacle;
        placed++;
      }
    }

    // 挡路车：放在空闲 road 格，不与已有车辆 / 停车位 / 入口重叠。
    var fillers = 0;
    guard = 0;
    while (fillers < fillCount && guard++ < 300) {
      final r = rng.nextInt(size);
      final c = rng.nextInt(size);
      final occupied = vehicles.any((v) => v.row == r && v.col == c);
      if (grid[r][c] == ParkingCellType.road &&
          !(r == pr && c == pc) &&
          !(r == 0 && c == 0) &&
          !occupied) {
        vehicles.add(VehicleSpawn(col: c, row: r, tier: fillTier));
        fillers++;
      }
    }

    return ParkingLevel(
      id: id,
      name: '停车 #$id',
      rows: size,
      cols: size,
      grid: grid,
      vehicles: vehicles,
      targetTier: tier,
    );
  }

  /// 兜底关：目标车在停车位同行、路径清空，一步可解。
  static ParkingLevel _fallbackLevel(
    int id,
    int size,
    CarTier tier,
    CarTier fillTier,
  ) {
    final grid = List.generate(
      size,
      (_) => List.filled(size, ParkingCellType.road),
    );
    grid[0][0] = ParkingCellType.entrance;
    grid[size - 1][(size - 2).clamp(0, size - 1)] = ParkingCellType.parking;
    final pr = size - 1;
    final pc = (size - 2).clamp(0, size - 1);
    final vehicles = <VehicleSpawn>[
      VehicleSpawn(col: (pc - 1).clamp(0, size - 1), row: pr, tier: tier),
    ];
    if (size > 3) {
      vehicles.add(VehicleSpawn(col: 0, row: 0, tier: fillTier));
    }
    return ParkingLevel(
      id: id,
      name: '停车 #$id',
      rows: size,
      cols: size,
      grid: grid,
      vehicles: vehicles,
      targetTier: tier,
      minMoves: 1,
      movesLimit: 6,
      timeLimit: id >= 100 ? 90 : null,
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

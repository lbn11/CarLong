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
  static const int _maxRetries = 60;

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

    // 难度目标随 id 缓慢增长：小棋盘易，大棋盘需多思考。达到目标即提前结束，控制耗时。
    final target = _targetMinMoves(id);

    ParkingLevel? bestCandidate;
    int bestMin = 0;

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

      // 难度下限：避免"一步通关"的弱关（长条车让 2 步谜题已具解谜感）。
      const floor = 2;
      if (minMoves < floor) continue; // 太易，换种子重试。

      // 在重试预算内保留"步数最多"的候选，让难度尽量贴近目标。
      if (minMoves > bestMin) {
        bestMin = minMoves;
        bestCandidate = candidate;
      }
      if (bestMin >= target) break; // 已达目标难度，提前结束
    }

    // 兜底：极端情况下退化为"目标车在停车位同行、一步可解"的简单关，永不死局。
    if (bestCandidate == null) {
      return _fallbackLevel(id, size, tier, fillTier);
    }

    // 标定难度：最优解可拿三星，给足余量。
    final movesLimit = max(bestMin * 2, bestMin + 4).toInt();
    final timeLimit = id >= 100
        ? (bestMin * 8 + 25).clamp(60, 600).toInt()
        : null;

    return bestCandidate.copyWith(
      minMoves: bestMin,
      movesLimit: movesLimit,
      timeLimit: timeLimit,
    );
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

    final taken = <(int, int)>{};
    taken.add((pr, pc));
    taken.add((0, 0));

    final vehicles = <VehicleSpawn>[];

    // 目标车：size>=5 时放 2 格横车在停车行（经典 Rush Hour 红车），起点不压停车位；
    // 小棋盘(size<=4)用单格车，且强制不在底部停车行，保证至少"下移+横移"两步。
    if (size >= 5) {
      var placed = false;
      for (var attempt = 0; attempt < 30 && !placed; attempt++) {
        final c = rng.nextInt(size - 2); // 0..size-3，保证 2 格不越界且不压停车位
        final cells = [(pr, c), (pr, c + 1)];
        if (cells.any((p) => p == (pr, pc))) continue; // 避开停车位
        if (cells.any(taken.contains)) continue;
        for (final p in cells) {
          taken.add(p);
        }
        vehicles.add(VehicleSpawn(
          col: c,
          row: pr,
          tier: tier,
          length: 2,
          orientation: ParkingOrientation.horizontal,
        ));
        placed = true;
      }
      if (!placed) {
        final tc = (pc - 1).clamp(0, size - 1);
        vehicles.add(VehicleSpawn(col: tc, row: pr, tier: tier));
        taken.add((pr, tc));
      }
    } else {
      int tr = rng.nextInt(size - 1); // 0..size-2，永不在底部停车行
      int tc = rng.nextInt(size);
      var guard = 0;
      // 同时避开停车列，强制至少"下移 + 横移"两步，避免一步通关。
      while (((tr == pr && tc == pc) ||
                  (tr == 0 && tc == 0) ||
                  tc == pc) &&
              guard++ < 50) {
        tr = rng.nextInt(size - 1);
        tc = rng.nextInt(size);
      }
      vehicles.add(VehicleSpawn(col: tc, row: tr, tier: tier));
      taken.add((tr, tc));
    }

    // 底部行挡块：竖向 2 格车压在停车行上，是经典 Rush Hour 的"必须让位"机制
    // （竖车可上下滑离底部行，横车则永远清不掉该行，故只用竖车）。
    if (size >= 5) {
      final rowBlockers = 2;
      var rb = 0;
      var guard = 0;
      while (rb < rowBlockers && guard++ < 60) {
        final c = rng.nextInt(size);
        if (taken.contains((pr, c)) || taken.contains((pr - 1, c))) continue;
        if (grid[pr][c] != ParkingCellType.road ||
            grid[pr - 1][c] != ParkingCellType.road) {
          continue;
        }
        taken.add((pr, c));
        taken.add((pr - 1, c));
        vehicles.add(VehicleSpawn(
          col: c,
          row: pr - 1,
          tier: fillTier,
          length: 2,
          orientation: ParkingOrientation.vertical,
        ));
        rb++;
      }
    }

    // 其余挡路车：随棋盘大小大量混入长度 2 的横/竖车（不在底部行放横车，避免永久堵死）。
    final longChance = size >= 6 ? 0.7 : 0.5;
    var fillers = 0;
    var guard = 0;
    while (fillers < fillCount && guard++ < 400) {
      final makeLong = rng.nextDouble() < longChance;
      final len = makeLong ? 2 : 1;
      final horiz = rng.nextBool();
      final spot = _findFreeSegment(rng, size, len, horiz, grid, taken);
      if (spot == null) continue;
      // 横车若落在底部停车行会永久堵死该行 => 跳过（横车只允许非底部行）。
      if (horiz && spot.$1 == pr) continue;
      for (final p in _segmentCells(spot.$1, spot.$2, len, horiz)) {
        taken.add(p);
      }
      vehicles.add(VehicleSpawn(
        col: spot.$2,
        row: spot.$1,
        tier: fillTier,
        length: len,
        orientation: horiz
            ? ParkingOrientation.horizontal
            : ParkingOrientation.vertical,
      ));
      fillers++;
    }

    // 障碍：只放在空闲 road 格。
    var placed = 0;
    guard = 0;
    while (placed < obstacleCount && guard++ < 200) {
      final r = rng.nextInt(size);
      final c = rng.nextInt(size);
      if (!taken.contains((r, c)) && grid[r][c] == ParkingCellType.road) {
        grid[r][c] = ParkingCellType.obstacle;
        placed++;
        taken.add((r, c));
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

  /// 在棋盘上找一段连续 [len] 格、全为 road 且未被占用的空闲段。
  static (int, int)? _findFreeSegment(
    Random rng,
    int size,
    int len,
    bool horiz,
    List<List<ParkingCellType>> grid,
    Set<(int, int)> taken,
  ) {
    for (var attempt = 0; attempt < 60; attempt++) {
      int r;
      int c;
      if (horiz) {
        r = rng.nextInt(size);
        c = rng.nextInt(size - len + 1);
      } else {
        r = rng.nextInt(size - len + 1);
        c = rng.nextInt(size);
      }
      var free = true;
      for (final p in _segmentCells(r, c, len, horiz)) {
        if (taken.contains(p) ||
            grid[p.$1][p.$2] != ParkingCellType.road) {
          free = false;
          break;
        }
      }
      if (free) return (r, c);
    }
    return null;
  }

  /// 给定 anchor 与朝向，返回占用格序列。
  static List<(int, int)> _segmentCells(
      int r, int c, int len, bool horiz) {
    final out = <(int, int)>[];
    for (var i = 0; i < len; i++) {
      out.add(horiz ? (r, c + i) : (r + i, c));
    }
    return out;
  }

  /// 兜底关：长条目标车 + 底部行竖挡块的 Rush Hour 式可解关（绝不退化成 1 步弱关）。
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
    final pr = size - 1;
    final pc = (size - 2).clamp(0, size - 1);
    grid[pr][pc] = ParkingCellType.parking;

    final vehicles = <VehicleSpawn>[
      // 目标车：底部行 2 格横车，起点不压停车位。
      VehicleSpawn(
        col: 0,
        row: pr,
        tier: tier,
        length: 2,
        orientation: ParkingOrientation.horizontal,
      ),
      // 竖挡块压在底部行、停车位正上方列，必须上移才能让目标滑入。
      VehicleSpawn(
        col: pc,
        row: pr - 1,
        tier: fillTier,
        length: 2,
        orientation: ParkingOrientation.vertical,
      ),
    ];
    return ParkingLevel(
      id: id,
      name: '停车 #$id',
      rows: size,
      cols: size,
      grid: grid,
      vehicles: vehicles,
      targetTier: tier,
      minMoves: 2,
      movesLimit: 8,
      timeLimit: id >= 100 ? 120 : null,
    );
  }

  /// 难度目标步数随 id 缓增：小棋盘以 2~3 步为主，大棋盘逐步上探到 6~8 步。
  /// 达到该目标即提前结束重试，控制生成耗时。
  static int _targetMinMoves(int id) {
    if (id < 50) return 2;
    if (id < 200) return 3 + ((id - 50) ~/ 50); // 50-99:3, 100-149:4, 150-199:5
    if (id < 500) return 5 + ((id - 200) ~/ 100); // 200-299:5, 300-399:6, 400-499:7
    return 8;
  }

  static CarTier _tierForLevel(int id) {    if (id < 50) return CarTier.bike;
    if (id < 150) return CarTier.scooter;
    if (id < 300) return CarTier.car;
    if (id < 500) return CarTier.taxi;
    if (id < 700) return CarTier.bus;
    if (id < 900) return CarTier.truck;
    return CarTier.train;
  }
}

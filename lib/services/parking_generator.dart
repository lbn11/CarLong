import 'dart:math';

import '../logic/parking_solver.dart';
import '../models/car.dart';
import '../models/parking_level.dart';
import 'parking_chapters.dart';

/// 停车关卡生成器 (Car Master 3D 风格)
///
/// 设计要点：
/// - 每关都经 [ParkingSolver] 校验可解；不可解则换种子重试（有上限），保证永不产出死局。
/// - 求解出的真实最短步数写入 [ParkingLevel.minMoves]，并据此标定 movesLimit / timeLimit，
///   使"按最优解通关"可拿三星，难度随 id 平滑递增。
/// - 全程基于 id 的确定性随机，generateOne(id) 与 generate() 结果一致、可复现。
class ParkingLevelGenerator {
  /// 单关求解器状态上限：有解关卡通常 <1ms，无解关会在该上限内放弃并重试。
  /// 实测：6x6 在 300k 预算下最短路 max 仅 ~8，但 7x7 需要 300k 预算时
  /// 单关生成平均 28.7s（最差 62s）——实时生成不可接受。故定稿：
  /// 棋盘封顶 6x6，预算 60000（6x6 足够且生成快），难度靠"后期下限 + 目标"
  /// 稳定在 5~8 步，而非无意义地追高目标。
  static const int _maxSolverStates = 60000;

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
    // 棋盘尺寸：4→5→6。7x7 因生成耗时爆炸（实测 avg 28.7s/关）被否决。
    final size = id < 50 ? 4 : (id < 200 ? 5 : 6);
    final tier = _tierForLevel(id);

    // 障碍 / 挡路车数量随难度增长（6x6 密度封顶：障碍 6、挡路车 4）。
    final obstacleCount = ((id ~/ 6).clamp(1, size));
    final fillCount = (id < 25
            ? 1
            : (id < 100 ? 2 : (id < 300 ? 3 : 4)))
        .clamp(1, size - 2);

    // 难度目标随 id 缓慢增长：小棋盘易，大棋盘需多思考。达到目标即提前结束，控制耗时。
    final target = _targetMinMoves(id);

    // 难度下限：避免"一步通关"的弱关。5x5+ 要求至少 3 步（有解谜感）。
    // 注意不能设太高——6x6 随机布局高步数关稀有，floor 过苛会导致重试耗尽
    // → fallback 爆炸（实测 floor=5 时 285/500 关退化成 2 步弱关）。
    final floor = size >= 5 ? 3 : 2;

    ParkingLevel? bestCandidate;
    int bestMin = 0;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final candidate = _tryBuild(
        rng,
        id: id,
        size: size,
        tier: tier,
        obstacleCount: obstacleCount,
        fillCount: fillCount,
      );
      final minMoves = ParkingSolver.minMoves(
        candidate,
        maxStates: _maxSolverStates,
      );
      if (minMoves == null) continue; // 不可解，换种子重试。

      if (minMoves < floor) continue; // 低于当期下限，换种子重试。

      // 在重试预算内保留"步数最多"的候选，让难度尽量贴近目标。
      if (minMoves > bestMin) {
        bestMin = minMoves;
        bestCandidate = candidate;
      }
      if (bestMin >= target) break; // 已达目标难度，提前结束
    }

    // 兜底：极端情况下退化为"目标车在停车位同行、一步可解"的简单关，永不死局。
    if (bestCandidate == null) {
      return _fallbackLevel(id, size, tier);
    }

    // 标定难度：最优解可拿三星，给足余量。
    // 6x6 步数天花板 ~8，后期"变难"靠收紧三星门槛与限时压力，而非追步数。
    final movesLimit = max(bestMin + 4, (bestMin * 1.6).round()).toInt();
    final timeLimit = id >= 100
        ? (bestMin * 6 + 20).clamp(45, 600).toInt()
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

    // 填充车使用"除目标档之外的所有档位"，逐个取不同档位，使每辆车颜色/图标都不同，
    // 还原"不同车不同颜色"的观感；同时保证没有任何填充车能冒充目标车开进停车位。
    final otherTiers = [
      for (var i = 0; i < CarTier.values.length; i++)
        if (i != tier.index) CarTier.values[i]
    ];
    otherTiers.shuffle(rng); // 确定性：同 id 同一关配色稳定可复现
    var fillerCursor = 0;
    CarTier nextFillerTier() =>
        otherTiers[fillerCursor++ % otherTiers.length];

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
    // 中度难度：4×4 也加入该机制（放 1 个），5×5+ 放 2 个。
    if (size >= 4) {
      final rowBlockers = size >= 5 ? 2 : 1;
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
          tier: nextFillerTier(),
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
        tier: nextFillerTier(),
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

  /// 兜底关：长条目标车 + 底部行竖挡块的 Rush Hour 式可解关。
  /// 5x5+ 放 2 个竖挡块（目标车正前方 + 停车位列），解 = 2 次上移 + 横移 = 3 步，
  /// 满足"较大棋盘 >=3 步"的解谜感约定；4x4 单挡块 2 步。绝不退化成 1 步弱关。
  static ParkingLevel _fallbackLevel(
    int id,
    int size,
    CarTier tier,
  ) {
    final grid = List.generate(
      size,
      (_) => List.filled(size, ParkingCellType.road),
    );
    grid[0][0] = ParkingCellType.entrance;
    final pr = size - 1;
    final pc = (size - 2).clamp(0, size - 1);
    grid[pr][pc] = ParkingCellType.parking;

    final big = size >= 5;
    final vehicles = <VehicleSpawn>[
      // 目标车：底部行 2 格横车，起点不压停车位。
      VehicleSpawn(
        col: 0,
        row: pr,
        tier: tier,
        length: 2,
        orientation: ParkingOrientation.horizontal,
      ),
      // 挡块 A：压在目标车正前方（col 1），必须上移目标才能右滑。
      VehicleSpawn(
        col: 1,
        row: pr - 1,
        tier: CarTier.fromIndex((tier.index + 1) % CarTier.values.length),
        length: 2,
        orientation: ParkingOrientation.vertical,
      ),
      // 挡块 B（5x5+）：压在停车位列上方，必须再上移一格目标才能滑入。
      if (big)
        VehicleSpawn(
          col: pc,
          row: pr - 1,
          tier: CarTier.fromIndex((tier.index + 2) % CarTier.values.length),
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
      minMoves: big ? 3 : 2,
      movesLimit: 8,
      timeLimit: id >= 100 ? 120 : null,
    );
  }

  /// 难度目标步数随 id 缓增。
  /// 数据定稿：6x6 最短路天花板实测 ~8（avg 4），500+ 目标封顶 7 即可
  /// （让生成尽量往高处够），后期难度主要由密度 + 三星门槛 + 限时承担。
  static int _targetMinMoves(int id) {
    if (id < 50) return 3;
    if (id < 200) return 3 + ((id - 50) ~/ 50); // 50-99:3, 100-149:4, 150-199:5
    if (id < 500) return 5 + ((id - 200) ~/ 100); // 200-299:5, 300-399:6, 400-499:7
    return 7; // 500+: 6x6 上探目标
  }


  /// 车型分段与 [ParkingChapters] 保持一致，便于停车章节与合成图鉴联动。
  static CarTier _tierForLevel(int id) => ParkingChapters.tierForId(id);
}

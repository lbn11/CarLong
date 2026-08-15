import 'dart:math';

import '../models/car.dart';
import '../models/level.dart';

/// 一次移动的结果。
class MoveResult {
  /// 是否发生了有效移动（移动/交换/合并）。
  final bool valid;
  /// 是否发生了升级。
  final bool upgraded;
  /// 升级发生在哪个格子。
  final ({int col, int row})? upgradeAt;
  /// 目标格子是否产生了目标车辆。
  final bool producedTarget;
  /// 本次合并融化的冰块格子（层数清零后）。
  final List<({int col, int row})> meltedIce;
  /// 是否经过传送门改道。
  final bool teleported;
  /// 是否引爆炸弹。
  final bool detonated;
  /// 炸弹引爆位置。
  final ({int col, int row})? detonatedAt;
  /// 炸弹引爆清除的格子（含炸弹自身）。
  final List<({int col, int row})> detonatedCells;

  const MoveResult({
    this.valid = false,
    this.upgraded = false,
    this.upgradeAt,
    this.producedTarget = false,
    this.meltedIce = const [],
    this.teleported = false,
    this.detonated = false,
    this.detonatedAt,
    this.detonatedCells = const [],
  });
}

/// 棋盘快照（撤销用）。
typedef BoardSnapshot = ({
  List<StackData?> grid,
  int producedCount,
  int totalMerges,
  List<Obstacle> obstacles,
  List<bool> fogged,
});

/// 纯逻辑棋盘。不依赖任何渲染，方便单测。
class BoardLogic {
  final LevelDefinition level;
  final int cols;
  final int rows;
  final Random _random;

  final List<StackData?> _grid;
  final List<int> _spawnWeights;
  final List<Obstacle> _obstacles;

  /// 传送门配对：入口格索引 -> 出口格索引（按障碍列表顺序两两配对）。
  final Map<int, int> _teleportPair;

  /// 迷雾覆盖的格子索引（true = 未揭开，卡牌被隐藏）。
  late final List<bool> _fogged;

  /// 已产出的目标车辆数量。
  int producedCount = 0;
  int totalMerges = 0;

  BoardLogic(this.level, {Random? random})
      : cols = level.cols,
        rows = level.rows,
        _random = random ?? Random(),
        _grid = List<StackData?>.filled(level.cols * level.rows, null),
        _spawnWeights = level.spawnWeights(),
        _obstacles = [
          for (final spec in level.obstacles) Obstacle.fromSpec(spec),
        ],
        _teleportPair = {} {
    final ports = <int>[];
    for (final o in _obstacles) {
      if (o.type == ObstacleType.teleport && !o.removed) {
        ports.add(_idx(o.col, o.row));
      }
    }
    for (var i = 0; i + 1 < ports.length; i += 2) {
      _teleportPair[ports[i]] = ports[i + 1];
      _teleportPair[ports[i + 1]] = ports[i];
    }
    _fogged = List<bool>.filled(cols * rows, false);
    final candidates = <({int col, int row})>[];
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        if (_usable(c, r)) candidates.add((col: c, row: r));
      }
    }
    candidates.shuffle(_random);
    for (var i = 0;
        i < level.fogCells.clamp(0, candidates.length) && i < candidates.length;
        i++) {
      _fogged[_idx(candidates[i].col, candidates[i].row)] = true;
    }
  }

  StackData? at(int col, int row) => _grid[_idx(col, row)];

  /// 指定格当前生效的障碍物；无则返回 null。
  Obstacle? obstacleAt(int col, int row) {
    for (final o in _obstacles) {
      if (o.col == col && o.row == row && o.active) return o;
    }
    return null;
  }

  /// 指定格是否可被占用（无生效障碍物）。
  bool _usable(int col, int row) => obstacleAt(col, row) == null;

  /// 直接在某格放置一张卡片（测试/初始化用）。
  void placeAt(int col, int row, StackData data) {
    _grid[_idx(col, row)] = data;
  }

  /// 是否已无可用空格（空格、或已清除的空卡位都不算；障碍格视为占满）。
  bool get isFull {
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if ((s == null || s.isEmpty) && _usable(i % cols, i ~/ cols)) {
        return false;
      }
    }
    return true;
  }

  /// 棋盘上非空卡片的格数（clearBoard 目标的进度）。
  int get tileCount => _grid.where((s) => s != null && !s.isEmpty).length;

  /// 棋盘是否已清空。
  bool get isEmpty => tileCount == 0;

  /// 目标是否达成。
  bool get isTargetReached => producedCount >= level.targetCount;

  /// 棋盘是否死局：无空格 且 没有任何可合并的组合。
  bool get isDeadlocked {
    if (!isFull) return false;
    return !hasPossibleMove;
  }

  /// 在随机空格生成一张随机卡片。
  /// 返回生成的格子；满盘返回 null。
  ({int col, int row})? spawn() {
    return placeTier(_weightedTier());
  }

  /// 在随机空格放入指定等级的卡片。跳过障碍格。满盘返回 null。
  ({int col, int row})? placeTier(CarTier tier) {
    if (isFull) return null;
    final empties = <({int col, int row})>[];
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        final s = _grid[_idx(c, r)];
        if ((s == null || s.isEmpty) && _usable(c, r)) {
          empties.add((col: c, row: r));
        }
      }
    }
    if (empties.isEmpty) return null;
    final cell = empties[_random.nextInt(empties.length)];
    _grid[_idx(cell.col, cell.row)] = StackData(tier);
    return cell;
  }

  /// 在随机空格放入一张万能卡。满盘返回 null。
  ({int col, int row})? placeWildcard() {
    final cell = _randomEmptyCell();
    if (cell == null) return null;
    _grid[_idx(cell.col, cell.row)] =
        StackData(CarTier.bike, isWildcard: true);
    return cell;
  }

  /// 在随机空格放入一张炸弹卡。满盘返回 null。
  ({int col, int row})? placeBomb() {
    final cell = _randomEmptyCell();
    if (cell == null) return null;
    _grid[_idx(cell.col, cell.row)] = StackData(CarTier.bike, isBomb: true);
    return cell;
  }

  ({int col, int row})? _randomEmptyCell() {
    if (isFull) return null;
    final empties = <({int col, int row})>[];
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        final s = _grid[_idx(c, r)];
        if ((s == null || s.isEmpty) && _usable(c, r)) {
          empties.add((col: c, row: r));
        }
      }
    }
    if (empties.isEmpty) return null;
    return empties[_random.nextInt(empties.length)];
  }

  /// 指定格是否被迷雾盖住。
  bool isFogged(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rows &&
      _fogged[_idx(col, row)];

  /// 揭开 (c,r) 及其四邻的迷雾（落子/移动后触发）。
  void revealNear(int c, int r) {
    if (c < 0 || c >= cols || r < 0 || r >= rows) return;
    _fogged[_idx(c, r)] = false;
    for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = c + dc, nr = r + dr;
      if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
      _fogged[_idx(nc, nr)] = false;
    }
  }

  /// 按出生权重生成一个随机等级。
  CarTier randomTier() => _weightedTier();

  /// 在 0..maxTierIndex 之间按降序权重随机（无尽模式动态权重）。
  CarTier weightedTierUpTo(int maxTierIndex) {
    final maxIdx = maxTierIndex.clamp(0, CarTier.values.length - 1);
    final weights = List.generate(maxIdx + 1, (i) => maxIdx - i + 1);
    var total = 0;
    for (final w in weights) {
      total += w;
    }
    var roll = _random.nextInt(total);
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return CarTier.fromIndex(i);
    }
    return CarTier.bike;
  }

  /// 棋盘上等级最高的卡片（撤销后高亮用）。空盘返回 null。
  ({int col, int row, CarTier tier})? highest() {
    var bestIdx = -1;
    var bestTier = -1;
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s != null && s.tier.index > bestTier) {
        bestTier = s.tier.index;
        bestIdx = i;
      }
    }
    if (bestIdx == -1) return null;
    final data = _grid[bestIdx]!;
    return (col: bestIdx % cols, row: bestIdx ~/ cols, tier: data.tier);
  }

  /// 移除棋盘上等级最低的一张卡片（腾位置用）。
  /// 返回被移除的格子与等级；空盘返回 null。
  ({int col, int row, CarTier tier})? removeLowest() {
    var bestIdx = -1;
    var bestTier = CarTier.values.length;
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s != null && s.tier.index < bestTier) {
        bestTier = s.tier.index;
        bestIdx = i;
      }
    }
    if (bestIdx == -1) return null;
    final data = _grid[bestIdx]!;
    _grid[bestIdx] = null;
    return (col: bestIdx % cols, row: bestIdx ~/ cols, tier: data.tier);
  }

  /// 移除指定格的卡片（锤子道具）。返回被移除的卡片；空格返回 null。
  StackData? removeAt(int col, int row) {
    final i = _idx(col, row);
    final data = _grid[i];
    _grid[i] = null;
    return data;
  }

  /// 当前棋盘快照（撤销用）。
  BoardSnapshot snapshot() => (
        grid: List.generate(_grid.length, (i) => _grid[i]?.copy()),
        producedCount: producedCount,
        totalMerges: totalMerges,
        obstacles: [
          for (final o in _obstacles)
            Obstacle.fromSpec(
              ObstacleSpec(o.type, o.col, o.row, layers: o.layers),
              layers: o.layers,
            )
              ..removed = o.removed,
        ],
        fogged: List.of(_fogged),
      );

  /// 恢复到某个快照（撤销用）。
  void restore(BoardSnapshot snap) {
    _grid.setAll(0, snap.grid);
    producedCount = snap.producedCount;
    totalMerges = snap.totalMerges;
    _obstacles
      ..clear()
      ..addAll(snap.obstacles);
    _fogged.setAll(0, snap.fogged);
  }

  /// 把 (from) 处的卡片移动到 (to)。
  /// 规则：
  ///  - 目标为空：移动。
  ///  - 目标同等级：合并（够 3 升级）。
  ///  - 目标不同等级：交换。
  ///  - 目标格有生效障碍：不可进入（冰块需先在相邻格上合成融化）。
  ///  - 目标格是传送门：卡片从配对的另一个传送门出现（允许停靠在出口的传送门上）。
  ///  - 万能卡可与任意卡片合并（等效为该等级 1 张）。
  ///  - 炸弹卡只与炸弹卡合并，集满 3 张引爆，清空 3×3 内的卡片与冰/锁。
  MoveResult move(int fc, int fr, int tc, int tr) {
    final from = _grid[_idx(fc, fr)];
    if (from == null || (fc == tc && fr == tr)) {
      return const MoveResult();
    }

    // 传送门改道：目标若是传送门，改为从配对出口出现。
    var teleported = false;
    final exit = _teleportPair[_idx(tc, tr)];
    if (exit != null) {
      tc = exit % cols;
      tr = exit ~/ cols;
      teleported = true;
    }
    if (fc == tc && fr == tr) return const MoveResult();
    if (!_usable(tc, tr)) {
      // 传送出口本身是传送门时允许停靠（卡片从传送门内钻出来）。
      if (!teleported || obstacleAt(tc, tr)?.type != ObstacleType.teleport) {
        return const MoveResult();
      }
    }

    final target = _grid[_idx(tc, tr)];
    if (target == null) {
      _grid[_idx(tc, tr)] = from;
      _grid[_idx(fc, fr)] = null;
      return MoveResult(valid: true, teleported: teleported);
    }

    // 炸弹：只与炸弹合并；集满 3 引爆。
    if (from.isBomb || target.isBomb) {
      if (from.isBomb && target.isBomb) {
        target.count += from.count;
        _grid[_idx(fc, fr)] = null;
        totalMerges++;
        if (target.count >= 3) {
          final cleared = _detonateBomb(tc, tr);
          return MoveResult(
            valid: true,
            detonated: true,
            detonatedAt: (col: tc, row: tr),
            detonatedCells: cleared,
            teleported: teleported,
          );
        }
        return MoveResult(valid: true, teleported: teleported);
      }
      // 炸弹与普通卡：交换。
      _grid[_idx(tc, tr)] = from;
      _grid[_idx(fc, fr)] = target;
      return MoveResult(valid: true, teleported: teleported);
    }

    // 万能卡：与任意卡片合并（等效为该等级 1 张）。
    if (from.isWildcard || target.isWildcard) {
      if (from.isWildcard && target.isWildcard) {
        target.count += from.count;
        _grid[_idx(fc, fr)] = null;
      } else if (from.isWildcard) {
        target.count += 1;
        _grid[_idx(fc, fr)] = null;
      } else {
        // 普通卡移到万能卡上：万能卡先变成该等级再合并。
        target
          ..tier = from.tier
          ..isWildcard = false;
        target.count += from.count;
        _grid[_idx(fc, fr)] = null;
      }
      return _completeMerge(target, tc, tr, teleported);
    }

    if (target.tier == from.tier) {
      target.count += from.count;
      _grid[_idx(fc, fr)] = null;
      return _completeMerge(target, tc, tr, teleported);
    }

    // 交换
    _grid[_idx(tc, tr)] = from;
    _grid[_idx(fc, fr)] = target;
    return MoveResult(valid: true, teleported: teleported);
  }

  /// 合并后的公共结算：升级判断、目标计数、融化四邻冰块。
  MoveResult _completeMerge(
      StackData target, int tc, int tr, bool teleported) {
    var upgraded = false;
    if (target.count >= 3) {
      upgraded = true;
      final next = target.tier.next;
      if (next == null) {
        // 最高级（彗星）：保留在棋盘上，不清掉。
        // 玩家可以看到自己的彗星成就。
        target.count = 1;
      } else {
        target.tier = next;
        target.count = 1;
      }
    }
    totalMerges++;
    var produced = false;
    if (level.goalType == GoalType.produce &&
        upgraded &&
        target.tier == level.targetTier) {
      producedCount++;
      produced = true;
    }
    final meltedIce = _meltAdjacentIce(tc, tr);
    return MoveResult(
      valid: true,
      upgraded: upgraded,
      upgradeAt: (col: tc, row: tr),
      producedTarget: produced,
      meltedIce: meltedIce,
      teleported: teleported,
    );
  }

  /// 炸弹引爆：清空 3×3 内的卡片与冰/锁（石块与传送门保留）。
  /// 返回被清除卡片的格子。
  List<({int col, int row})> _detonateBomb(int c, int r) {
    final cleared = <({int col, int row})>[];
    for (var dc = -1; dc <= 1; dc++) {
      for (var dr = -1; dr <= 1; dr++) {
        final nc = c + dc, nr = r + dr;
        if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
        if (_grid[_idx(nc, nr)] != null) {
          _grid[_idx(nc, nr)] = null;
          cleared.add((col: nc, row: nr));
        }
        for (final o in _obstacles) {
          if (o.col == nc && o.row == nr && o.active &&
              (o.type == ObstacleType.ice || o.type == ObstacleType.lock)) {
            o.removed = true;
            o.layers = 0;
            break;
          }
        }
      }
    }
    return cleared;
  }

  /// 合并后消融 (c,r) 四邻的冰块，返回完全融化（层数归零）的格子。
  List<({int col, int row})> _meltAdjacentIce(int c, int r) {
    final melted = <({int col, int row})>[];
    for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = c + dc, nr = r + dr;
      if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
      for (final o in _obstacles) {
        if (o.col == nc &&
            o.row == nr &&
            o.type == ObstacleType.ice &&
            o.layers > 0) {
          o.layers--;
          if (o.layers <= 0) melted.add((col: nc, row: nr));
          break;
        }
      }
    }
    return melted;
  }

  /// 用锤子清除指定格的锁链障碍。返回被移除的障碍；没有锁链返回 null。
  Obstacle? removeObstacleAt(int col, int row) {
    for (final o in _obstacles) {
      if (o.col == col &&
          o.row == row &&
          o.type == ObstacleType.lock &&
          !o.removed) {
        o.removed = true;
        return o;
      }
    }
    return null;
  }

  /// 是否存在任意可合并操作（用于提示，含万能卡与炸弹）。
  /// 修复：BFS 搜索判断同等级卡是否可达（不只是数数量）。
  bool get hasPossibleMove {
    var wildcards = 0;
    var bombs = 0;
    final normalByTier = <CarTier, int>{};
    for (final s in _grid) {
      if (s == null || s.isEmpty) continue;
      if (s.isWildcard) {
        wildcards += s.count;
      } else if (s.isBomb) {
        bombs += s.count;
      } else {
        normalByTier[s.tier] = (normalByTier[s.tier] ?? 0) + s.count;
      }
    }
    if (wildcards >= 2) return true;
    if (bombs >= 2) return true;
    final normalCount = normalByTier.values.fold(0, (a, b) => a + b);
    if (wildcards >= 1 && normalCount >= 1) return true;

    // 普通卡：检查是否有任意两张同等级卡可达，或交换可制造合并
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        final s = at(c, r);
        if (s == null || s.isEmpty || s.isWildcard || s.isBomb) continue;
        if (_canReachSameTier(c, r, s.tier)) return true;
        if (_swapCreatesMerge(c, r)) return true;
      }
    }
    return false;
  }

  /// BFS 搜索：从 (col,row) 出发，能否到达任意同等级卡。
  /// 空格可通过，障碍 / 其他卡片阻挡。
  bool _canReachSameTier(int col, int row, CarTier tier) {
    final visited = <int>{};
    final queue = <int>[_idx(col, row)];
    visited.add(_idx(col, row));

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final cc = curr % cols;
      final cr = curr ~/ cols;

      for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nc = cc + dc, nr = cr + dr;
        if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
        final ni = _idx(nc, nr);
        if (visited.contains(ni)) continue;
        visited.add(ni);

        final ns = _grid[ni];
        if (ns == null || ns.isEmpty) {
          queue.add(ni);
        } else if (!ns.isWildcard &&
            !ns.isBomb &&
            ns.tier == tier) {
          return true;
        }
      }
    }
    return false;
  }

  /// 检查 (col,row) 的卡片与任意邻居交换后是否制造同等级相邻。
  bool _swapCreatesMerge(int col, int row) {
    final s = at(col, row);
    if (s == null) return false;

    for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = col + dc, nr = row + dr;
      if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
      final ns = at(nc, nr);
      if (ns == null ||
          ns.isEmpty ||
          ns.isWildcard ||
          ns.isBomb ||
          ns.tier == s.tier) continue;

      // 模拟交换后检查 (nc,nr) 周围是否有 s 的同等级卡
      for (final (dc2, dr2) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final ac = nc + dc2, ar = nr + dr2;
        if (ac >= 0 &&
            ac < cols &&
            ar >= 0 &&
            ar < rows &&
            !(ac == col && ar == row)) {
          final adj = at(ac, ar);
          if (adj != null &&
              !adj.isEmpty &&
              !adj.isWildcard &&
              !adj.isBomb &&
              adj.tier == s.tier) {
            return true;
          }
        }
      }
    }
    return false;
  }

  CarTier _weightedTier() {
    var total = 0;
    for (final w in _spawnWeights) {
      total += w;
    }
    var roll = _random.nextInt(total);
    for (var i = 0; i < _spawnWeights.length; i++) {
      roll -= _spawnWeights[i];
      if (roll < 0) return CarTier.fromIndex(i);
    }
    return CarTier.bike;
  }

  int _idx(int c, int r) => r * cols + c;
}

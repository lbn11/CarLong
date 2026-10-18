import 'dart:math';

import '../models/vehicle.dart';
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
  /// 移动的卡被黑洞吞掉（格子变空，不结算合并——落点陷阱）。
  final bool swallowed;

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
    this.swallowed = false,
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

/// Boss 黑洞格子（可变的剩余秒数，故用类不用 record）。
class _Hole {
  final int col;
  final int row;
  double left;
  _Hole(this.col, this.row, this.left);
}

/// 纯逻辑棋盘。不依赖任何渲染，方便单测。
class BoardLogic {  final LevelDefinition level;
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

  /// Boss 黑洞：临时占格的旋涡格子（col,row + 剩余秒数）。
  /// 占格期间落不下牌，但**可以主动把卡拖进去喂给它**（吞掉不结算）。
  final List<_Hole> _holes = [];

  /// 已产出的目标车辆数量。
  int producedCount = 0;
  int totalMerges = 0;

  /// [hasPossibleMove] 的结果缓存。棋盘每次变化后失效，
  /// 避免在每帧的死局检测里重复跑整套 BFS（满盘时开销极大）。
  bool? _possibleMoveCache;

  void _invalidate() => _possibleMoveCache = null;

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

  /// 指定格是否可被占用（无生效障碍物、无黑洞）。
  bool _usable(int col, int row) =>
      obstacleAt(col, row) == null && !holeAt(col, row);

  /// 直接在某格放置一张卡片（测试/初始化用）。
  void placeAt(int col, int row, StackData data) {
    _grid[_idx(col, row)] = data;
    _invalidate();
  }

  /// Boss 冰封：给 (col,row) 上的普通车加冰层（不碰空格/万能卡/炸弹）。
  ///
  /// 与 [addObstacle] 不同——冰封是**车的状态**不是格子障碍：
  /// 车还在原地、看得见，但动不了也合不了，邻格每次合并融化 1 层。
  /// 快照走 [StackData.copy]（含 frozen），撤销自动兼容。
  void freezeAt(int col, int row, {int layers = 2}) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) return;
    final s = _grid[_idx(col, row)];
    if (s == null || s.isEmpty || s.isWildcard || s.isBomb) return;
    s.frozen = layers;
    _invalidate();
  }

  /// Boss 胶水：把 (col,row) 上的车粘住 [seconds] 秒（只随时间流逝干掉，
  /// 不像冰封要靠邻格合并救）。与冰封共用 [StackData.locked] 阻断面，
  /// 死局检测/hint 自动同步感知。
  void glueAt(int col, int row, double seconds) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) return;
    if (seconds <= 0) return;
    final s = _grid[_idx(col, row)];
    if (s == null || s.isEmpty || s.isWildcard || s.isBomb) return;
    s.glueT = seconds;
    _invalidate();
  }

  /// 全场胶水倒计时（MergeGame.update 驱动）。返回本次干掉的张数。
  int tickGlue(double dt) {
    if (dt <= 0) return 0;
    var dried = 0;
    for (final s in _grid) {
      if (s == null || s.isEmpty || s.glueT <= 0) continue;
      s.glueT -= dt;
      if (s.glueT <= 0) {
        s.glueT = 0;
        dried++;
      }
    }
    if (dried > 0) _invalidate();
    return dried;
  }

  /// 场上是否有被胶水粘住的车（死局等待判定的条件之一）。
  bool get hasGlue {
    for (final s in _grid) {
      if (s != null && !s.isEmpty && s.glueT > 0) return true;
    }
    return false;
  }

  /// 剩余胶水秒数（最大值；0 = 没有）。供 hint 显示「再等 N 秒」。
  double get glueLeft {
    var left = 0.0;
    for (final s in _grid) {
      if (s != null && !s.isEmpty && s.glueT > left) left = s.glueT;
    }
    return left;
  }

  /// Boss 黑洞：在空格上开一个持续 [seconds] 秒的旋涡。
  /// 占格期间落不下牌（[placeTierSmart] 自动避开），但玩家可以把卡
  /// **拖进去喂给它**——[move] 命中黑洞 = 吞卡（[MoveResult.swallowed]）。
  void addHole(int col, int row, double seconds) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) return;
    if (seconds <= 0) return;
    if (_grid[_idx(col, row)] != null) return; // 只开在空格
    if (obstacleAt(col, row) != null) return;
    if (holeAt(col, row)) return;
    _holes.add(_Hole(col, row, seconds));
    _invalidate();
  }

  bool holeAt(int col, int row) {
    for (final h in _holes) {
      if (h.col == col && h.row == row) return true;
    }
    return false;
  }

  /// 黑洞剩余秒数（0 = 没有）。
  double holeLeftAt(int col, int row) {
    for (final h in _holes) {
      if (h.col == col && h.row == row) return h.left;
    }
    return 0;
  }

  /// 黑洞倒计时。返回本次消失的个数。
  int tickHoles(double dt) {
    if (dt <= 0 || _holes.isEmpty) return 0;
    var gone = 0;
    for (final h in _holes.toList()) {
      h.left -= dt;
      if (h.left <= 0) {
        _holes.remove(h);
        gone++;
      }
    }
    if (gone > 0) _invalidate();
    return gone;
  }

  bool get hasHoles => _holes.isNotEmpty;

  /// 把指定格盖上的迷雾重新打开（Boss 迷雾技能用；与关卡初始迷雾
  /// 同一张 [ _fogged ] 表，落子揭开/反制逻辑全部复用）。
  void fogCellsAt(List<({int col, int row})> cells) {
    for (final c in cells) {
      if (c.col < 0 || c.col >= cols || c.row < 0 || c.row >= rows) continue;
      _fogged[_idx(c.col, c.row)] = true;
    }
    _invalidate();
  }

  /// 场上是否还有被 Boss 冰封的车（融雪安全阀的触发条件之一）。
  bool get hasFrozen {
    for (final s in _grid) {
      if (s != null && !s.isEmpty && s.frozen > 0) return true;
    }
    return false;
  }

  /// 全场冻车剩余冰层总数（融雪提示文案用）。
  int get frozenLayers {
    var total = 0;
    for (final s in _grid) {
      if (s != null && !s.isEmpty && s.frozen > 0) total += s.frozen;
    }
    return total;
  }

  /// 融雪安全阀：全场冻车统一融 1 层，返回本次融掉层的车数。
  ///
  /// 用途：玩家真卡死（牌堆空/棋盘满 且 无可合步）时由 MergeGame 定时调用，
  /// 保证「被 Boss 冻住＝永远解冻不了」在设计上不可能发生——冰层总会
  /// 持续减弱，玩家要么等到翻盘时刻，要么全场融化后走死局收尾。
  int meltAllFrozenOneLayer() {
    var melted = 0;
    for (final s in _grid) {
      if (s == null || s.isEmpty || s.frozen <= 0) continue;
      s.frozen -= 1;
      melted++;
    }
    if (melted > 0) _invalidate();
    return melted;
  }

  /// 场上是否还有 Boss 扔的冰块障碍（融雪安全阀的触发条件之一）。
  bool get hasIce {
    for (final o in _obstacles) {
      if (o.type == ObstacleType.ice && !o.removed && o.layers > 0) return true;
    }
    return false;
  }

  /// 全场活跃冰块剩余层数总数（融雪提示文案用）。
  int get iceLayers {
    var total = 0;
    for (final o in _obstacles) {
      if (o.type == ObstacleType.ice && !o.removed && o.layers > 0) {
        total += o.layers;
      }
    }
    return total;
  }

  /// 融雪安全阀（冰块版）：全场活跃冰块统一融 1 层，返回本次融掉层的冰块数。
  ///
  /// 与冻车版的关键区别：冰块**只能被相邻合并融化**，玩家被 Boss 用冰块
  /// 填满棋盘时没有任何自助手段。没有这条阀，「冰封棋盘」会永久卡死对局——
  /// 死局收尾（_clearLowestAuto）只删车删不到冰，牌堆又永远抽不完，
  /// 游戏挂着永不结束。层数归零即标记 removed，格子重新可落子。
  int meltAllIceOneLayer() {
    var melted = 0;
    for (final o in _obstacles) {
      if (o.type != ObstacleType.ice || o.removed || o.layers <= 0) continue;
      o.layers -= 1;
      melted++;
      if (o.layers <= 0) o.removed = true;
    }
    if (melted > 0) _invalidate();
    return melted;
  }

  /// 运行时添加障碍物（Boss 攻击往空格扔冰用）。
  ///
  /// 快照会序列化当前全部障碍（含运行时添加的），因此**撤销自动兼容**：
  /// 撤销回到攻击前的快照时，Boss 扔的冰会随之消失——公平且无需特判。
  void addObstacle(ObstacleType type, int col, int row, {int layers = 1}) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) return;
    if (obstacleAt(col, row) != null) return;
    if (at(col, row) != null) return; // 只扔空格
    _obstacles.add(Obstacle.fromSpec(
      ObstacleSpec(type, col, row, layers: layers),
    ));
    _invalidate();
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
  ({int col, int row})? placeTier(VehicleType tier) {
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
    _invalidate();
    return cell;
  }

  /// 智能落点：优先放在同等级普通卡的四邻空格（为下一步合成铺路），
  /// 其次万能卡邻格（万能卡可与任意等级合并）；都没有则退回随机空格。
  /// 返回落点；满盘返回 null。
  ({int col, int row})? placeTierSmart(VehicleType tier) {
    if (isFull) return null;
    final empties = <({int col, int row})>[];
    final nextToSame = <({int col, int row})>[];
    final nextToWild = <({int col, int row})>[];
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        final s = _grid[_idx(c, r)];
        if ((s == null || s.isEmpty) && _usable(c, r)) {
          empties.add((col: c, row: r));
          // 四邻有同等级普通卡 → 一步就能合成；有万能卡 → 也能立即合并。
          for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final nc = c + dc, nr = r + dr;
            if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
            final adj = _grid[_idx(nc, nr)];
            if (adj == null || adj.isEmpty) continue;
            if (!adj.isBomb && adj.tier == tier) {
              nextToSame.add((col: c, row: r));
              break;
            }
            if (adj.isWildcard) {
              nextToWild.add((col: c, row: r));
              break;
            }
          }
        }
      }
    }
    final pool = nextToSame.isNotEmpty
        ? nextToSame
        : (nextToWild.isNotEmpty ? nextToWild : empties);
    if (pool.isEmpty) return null;
    final cell = pool[_random.nextInt(pool.length)];
    _grid[_idx(cell.col, cell.row)] = StackData(tier);
    _invalidate();
    return cell;
  }

  /// 在随机空格放入一张万能卡。满盘返回 null。
  ({int col, int row})? placeWildcard() {
    final cell = _randomEmptyCell();
    if (cell == null) return null;
    _grid[_idx(cell.col, cell.row)] =
        StackData(VehicleType.bicycle, isWildcard: true);
    _invalidate();
    return cell;
  }

  /// 在随机空格放入一张炸弹卡。满盘返回 null。
  ({int col, int row})? placeBomb() {
    final cell = _randomEmptyCell();
    if (cell == null) return null;
    _grid[_idx(cell.col, cell.row)] = StackData(VehicleType.bicycle, isBomb: true);
    _invalidate();
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

  /// 揭开 (c,r) 及其 range 范围内的迷雾（落子/移动后触发）。
  void revealNear(int c, int r, {int range = 1}) {
    if (c < 0 || c >= cols || r < 0 || r >= rows) return;
    _fogged[_idx(c, r)] = false;
    for (var dc = -range; dc <= range; dc++) {
      for (var dr = -range; dr <= range; dr++) {
        if (dc == 0 && dr == 0) continue;
        final nc = c + dc, nr = r + dr;
        if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
        _fogged[_idx(nc, nr)] = false;
      }
    }
  }

  /// 按出生权重生成一个随机等级。
  VehicleType randomTier() => _weightedTier();

  /// 在 0..maxTierIndex 之间按降序权重随机（无尽模式动态权重）。
  VehicleType weightedTierUpTo(int maxTierIndex) {
    final maxIdx = maxTierIndex.clamp(0, VehicleType.values.length - 1);
    final weights = List.generate(maxIdx + 1, (i) => maxIdx - i + 1);
    var total = 0;
    for (final w in weights) {
      total += w;
    }
    var roll = _random.nextInt(total);
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return VehicleType.fromId(i);
    }
    return VehicleType.bicycle;
  }

  /// 棋盘上等级最高的卡片（撤销后高亮用）。空盘返回 null。
  ({int col, int row, VehicleType tier})? highest() {
    var bestIdx = -1;
    var bestTier = -1;
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s != null && s.tier.id > bestTier) {
        bestTier = s.tier.id;
        bestIdx = i;
      }
    }
    if (bestIdx == -1) return null;
    final data = _grid[bestIdx]!;
    return (col: bestIdx % cols, row: bestIdx ~/ cols, tier: data.tier);
  }

  /// 移除棋盘上等级最低的一张卡片（腾位置用）。
  /// 返回被移除的格子与等级；空盘返回 null。
  ({int col, int row, VehicleType tier})? removeLowest() {
    var bestIdx = -1;
    var bestTier = VehicleType.values.length;
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s != null && s.tier.id < bestTier) {
        bestTier = s.tier.id;
        bestIdx = i;
      }
    }
    if (bestIdx == -1) return null;
    final data = _grid[bestIdx]!;
    _grid[bestIdx] = null;
    _invalidate();
    return (col: bestIdx % cols, row: bestIdx ~/ cols, tier: data.tier);
  }

  /// 移除指定格的卡片（锤子道具）。返回被移除的卡片；空格返回 null。
  StackData? removeAt(int col, int row) {
    final i = _idx(col, row);
    final data = _grid[i];
    _grid[i] = null;
    _invalidate();
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
    _invalidate();
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
    _invalidate();
    final from = _grid[_idx(fc, fr)];
    if (from == null || (fc == tc && fr == tr)) {
      return const MoveResult();
    }
    // Boss 冰封/胶水：动不了的车一步也动不了——冰封要在旁边合
    // 「救它」，胶水只能等时间。两种状态共用 locked 阻断面。
    if (from.locked) return const MoveResult();

    // 传送门改道：目标若是传送门，改为从配对出口出现。
    var teleported = false;
    final exit = _teleportPair[_idx(tc, tr)];
    if (exit != null) {
      tc = exit % cols;
      tr = exit ~/ cols;
      teleported = true;
    }
    if (fc == tc && fr == tr) return const MoveResult();

    // Boss 黑洞：落点是旋涡 → 卡被吞掉（不结算合并）。这是**陷阱**
    // 不是墙——玩家可以主动喂卡清位，也可以绕着走。
    if (holeAt(tc, tr)) {
      _grid[_idx(fc, fr)] = null;
      return MoveResult(valid: true, swallowed: true, teleported: teleported);
    }

    if (!_usable(tc, tr)) {
      // flyOver 能力：忽略障碍物，允许降落
      final moverAbility = from.tier.stats.ability;
      if (moverAbility == SpecialAbility.flyOver) {
        // 允许移动到障碍格
      } else if (!teleported || obstacleAt(tc, tr)?.type != ObstacleType.teleport) {
        return const MoveResult();
      }
    }

    final target = _grid[_idx(tc, tr)];
    // Boss 冰封/胶水的目标格也不能进：动不了的车不参与合成/交换。
    if (target != null && target.locked) return const MoveResult();
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
        // 最高级：产出后清除（count=0）。
        // 必须清掉——clearBoard 关的胜利条件是"牌堆空 && 残留 ≤ clearLimit"，
        // 而合并只会 3 堆变 1 堆；若最高级永久占格，残堆永远无法减少，
        // 17 个清道夫关卡将数学上不可通关（d491acc 曾改为保留，已回归修复）。
        // 彗星成就由图鉴/producedCount 记录，不依赖棋盘实体。
        target.count = 0;
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
    final meltedIce = _meltAdjacentIce(tc, tr, mover: target.tier);
    _meltAdjacentFrozen(tc, tr);
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

  /// 合并发生在 (c,r)：四邻被 Boss 冰封的车融化 1 层（救它要合两次）。
  void _meltAdjacentFrozen(int c, int r) {
    for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = c + dc, nr = r + dr;
      if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
      final s = _grid[_idx(nc, nr)];
      if (s != null && s.frozen > 0) s.frozen -= 1;
    }
  }

  /// 合并后消融 (c,r) 四邻的障碍，返回完全融化/移除的格子。
  /// 若 mover 具有 breakIce / breakChain / clearRock 能力，
  /// 则直接清除相邻格对应类型的障碍（不逐层递减）。
  List<({int col, int row})> _meltAdjacentIce(int c, int r,
      {VehicleType? mover}) {    final melted = <({int col, int row})>[];
    final ability = mover?.stats.ability;
    for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = c + dc, nr = r + dr;
      if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
      for (final o in _obstacles) {
        if (o.col != nc || o.row != nr) continue;
        if (ability == SpecialAbility.breakIce &&
            o.type == ObstacleType.ice &&
            o.layers > 0) {
          o.layers = 0;
          o.removed = true;
          melted.add((col: nc, row: nr));
          break;
        }
        if (ability == SpecialAbility.breakChain &&
            o.type == ObstacleType.lock &&
            !o.removed) {
          o.removed = true;
          melted.add((col: nc, row: nr));
          break;
        }
        if (ability == SpecialAbility.clearRock &&
            o.type == ObstacleType.block &&
            !o.removed) {
          o.removed = true;
          melted.add((col: nc, row: nr));
          break;
        }
        if (o.type == ObstacleType.ice && o.layers > 0) {
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

  /// 是否存在任意可合并操作（用于死局检测与提示，含万能卡与炸弹）。
  /// 结果缓存到 [_possibleMoveCache]，棋盘被改写时由 [_invalidate] 失效。
  ///
  /// 规则必须与 [move] / [hintMove] / UI 高亮（MergeGame._canMergeWith）
  /// 严格一致：**格对格合并——任意两张同档车点哪都能合，不看距离、
  /// 不看空格通路**。
  /// 2026-10-19 修复：旧实现要求 BFS 空格通路或相邻交换（W1 滑块合并
  /// 时代的遗留，d491acc），比 [move] 严苛——被别的车墙隔开的同档对
  /// 会被误判「无路可走」，牌堆空时直接误判负（而 hint 按钮照样能
  /// 指出那一步，自相矛盾）。
  bool get hasPossibleMove {
    final cached = _possibleMoveCache;
    if (cached != null) return cached;
    final result = _computePossibleMove();
    _possibleMoveCache = result;
    return result;
  }

  bool _computePossibleMove() {
    var wildcards = 0;
    var bombs = 0;
    final stacksByTier = <VehicleType, int>{};
    var normalStacks = 0;
    for (final s in _grid) {
      if (s == null || s.isEmpty) continue;
      // Boss 冰封：冻住的车不可动、不可被合——不算可合资源。
      // 不排除它会把「唯一同等级对是冻车」误判成有步可走，玩家零操作
      // 而死局检测不触发，游戏永久卡死。胶水（glueT）同理——它虽然
      // 几秒后自动干掉，但等待期间不该被算成可合资源。
      if (s.locked) continue;
      if (s.isWildcard) {
        wildcards += s.count;
      } else if (s.isBomb) {
        bombs += s.count;
      } else {
        // 数**堆数**不是 count：单堆 count=2 无法自己合自己。
        stacksByTier[s.tier] = (stacksByTier[s.tier] ?? 0) + 1;
        normalStacks += 1;
      }
    }
    if (wildcards >= 2) return true;
    if (bombs >= 2) return true;
    if (wildcards >= 1 && normalStacks >= 1) return true;
    // 普通卡：任意两堆同档即可合（move() 格对格，无通路/距离要求）。
    for (final n in stacksByTier.values) {
      if (n >= 2) return true;
    }
    return false;
  }

  /// Boss 洗牌：只重排**没被冻/粘**的车（冻车胶车原地不动，
  /// 否则「洗完冻车换位置」会和冰封的「原地救车」叙事打架）。
  /// 车的多重集合不变，纯搅局——破坏玩家布局，也顺带破解死局。
  /// 返回参与重排的张数。
  int shuffleUnlocked() {
    final movable = <int>[]; // 格子索引
    final cards = <StackData>[];
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s == null || s.isEmpty || s.locked) continue;
      if (!_usable(i % cols, i ~/ cols)) continue;
      movable.add(i);
      cards.add(s);
    }
    if (movable.length < 2) return 0;
    cards.shuffle(_random);
    for (var k = 0; k < movable.length; k++) {
      _grid[movable[k]] = cards[k];
    }
    _invalidate();
    return movable.length;
  }

  /// 洗牌重排（金币道具）：收集所有非空卡片，打乱后重新分配到全部可占用格
  /// （含原卡位）。障碍 / 传送门 / 迷雾保持不动，卡片数量不变。
  /// 死局时用可解除死局（重排后可能出现可合并组合）。
  void shuffleTiles() {
    final cards = <StackData>[];
    final slots = <int>[];
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s != null && !s.isEmpty) cards.add(s);
      if (_usable(i % cols, i ~/ cols)) slots.add(i);
    }
    if (cards.isEmpty) return;
    cards.shuffle(_random);
    for (var i = 0; i < _grid.length; i++) {
      _grid[i] = null;
    }
    for (var k = 0; k < cards.length; k++) {
      _grid[slots[k % slots.length]] = cards[k];
    }
    _invalidate();
  }

  /// 提示一步：返回一个"立即能合并/引爆"的操作 (from -> to)，供高亮与文案提示。
  /// 优先级：炸弹对炸弹 → 普通卡 + 万能卡 → 任意两张同等级卡。无操作返回 null。
  /// 注：move() 是格对格操作（同等级合并、异等级交换），无需路径可达性。
  ({int fc, int fr, int tc, int tr})? hintMove() {
    // 1) 炸弹：任意两颗炸弹相互合并即引爆。
    var firstBomb = -1;
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s != null && s.isBomb && !s.locked) {
        if (firstBomb == -1) {
          firstBomb = i;
        } else {
          return (
            fc: firstBomb % cols,
            fr: firstBomb ~/ cols,
            tc: i % cols,
            tr: i ~/ cols,
          );
        }
      }
    }
    // 2) 万能卡 + 任意普通卡。
    var firstWild = -1;
    var firstNormal = -1;
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s == null || s.isEmpty || s.locked) continue;
      if (s.isWildcard) {
        if (firstWild == -1) firstWild = i;
      } else if (!s.isBomb) {
        if (firstNormal == -1) firstNormal = i;
      }
    }
    if (firstWild != -1 && firstNormal != -1) {
      return (
        fc: firstNormal % cols,
        fr: firstNormal ~/ cols,
        tc: firstWild % cols,
        tr: firstWild ~/ cols,
      );
    }
    // 3) 任意两张同等级普通卡。
    for (var i = 0; i < _grid.length; i++) {
      final s = _grid[i];
      if (s == null || s.isEmpty || s.isWildcard || s.isBomb) continue;
      if (s.locked) continue;
      for (var j = i + 1; j < _grid.length; j++) {
        final t = _grid[j];
        if (t == null || t.isEmpty || t.isWildcard || t.isBomb) continue;
        if (t.locked) continue;
        if (t.tier == s.tier) {
          return (
            fc: i % cols,
            fr: i ~/ cols,
            tc: j % cols,
            tr: j ~/ cols,
          );
        }
      }
    }
    return null;
  }

  VehicleType _weightedTier() {
    var total = 0;
    for (final w in _spawnWeights) {
      total += w;
    }
    var roll = _random.nextInt(total);
    for (var i = 0; i < _spawnWeights.length; i++) {
      roll -= _spawnWeights[i];
      if (roll < 0) return VehicleType.fromId(i);
    }
    return VehicleType.bicycle;
  }

  int _idx(int c, int r) => r * cols + c;
}

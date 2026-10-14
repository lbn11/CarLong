import 'dart:math';

import '../logic/parking_solver.dart';
import '../models/vehicle.dart';
import '../models/parking_level.dart';
import 'parking_chapters.dart';
import 'parking_reverse_builder.dart';

/// 停车关卡生成器（反向生成 + 6 关难度心跳）
///
/// # 生成方法：反向生成（不再是「随机撒车 + 事后筛选」）
///
/// 旧方法是随机布局后用求解器筛，实测 6x6 上填充车 4→12 时平均最短路
/// **反而从 1.90 掉到 1.00**、不可解率 13%→65% —— 密集布局大概率是死局，
/// 能存活的反而是简单布局（幸存者偏差）。天花板是方法本身，加参数没用。
///
/// 现在改为 [ParkingReverseBuilder]：从「已停好」的解状态出发，在滑动图上
/// 沿 BFS 距离严格 +1 的边倒走 K 步 —— 因为滑动可逆（图无向），
/// 得到的局面最短解**精确等于 K**，难度可点名指定，且 100% 可解。
///
/// # 难度心跳：每 6 关一个轮回（双波峰）
///
/// 轻松 → 顺手 → 动脑 → 缓冲 → 硬仗 → 尖峰，不停轮回。
/// 心流的本质不是「越来越难」，而是**张弛交替**：连续爬坡会疲劳，
/// 一直平又会无聊。两个波峰之间夹一个「缓冲」波谷，玩家不会连吃两关高压。
///
/// 相位以「章内偏移」取模（不是全局 id），因此每章第 1 关恒为相位 0 ——
/// 新车型永远在轻松关登场（先亮相、再加压），且章节边界不打断心跳。
///
/// **周期与合成模式故意不同**（合成 5 关一轮）：两个模式的局部难度曲线
/// 关卡数不能相同，否则交替游玩时紧张点/松弛点互相叠加，节奏感抵消。
class ParkingLevelGenerator {
  /// 真实求解器校验的状态预算（反向生成已保证有解，这里只是复核最短步数）。
  static const int _maxSolverStates = 200000;

  /// 换布局重试次数（地形太挤 / 图太浅时）。
  static const int _layoutTries = 6;

  /// 高压相位（硬仗/尖峰）的换布局重试次数。
  static const int _climaxLayoutTries = 12;

  /// 单次倒走 DFS 的节点预算。
  static const int _maxNodes = 4000;

  /// 高压相位的 DFS 节点预算（更深的目标需要更大的搜索空间）。
  static const int _climaxMaxNodes = 20000;

  /// 步数上限（硬仗关封顶）。
  ///
  /// 实测 6x6 上 9 辆挡路车的倒走天花板约 7 步 —— 再往上要 12+ 辆车，
  /// 单次生成会从几十毫秒飙到秒级（选关是进一关生成一关，卡顿必须封顶）。
  /// 而且这也够用了：原来全程只有 3-5 步，现在轻松 2 → 硬仗 7，跨度足够。
  static const int _maxMinMoves = 7;

  static List<ParkingLevel> generate({int? count}) {
    final n = count ?? ParkingChapters.totalLevels;
    return [
      for (var i = 1; i <= n; i++) generateOne(i),
    ];
  }

  /// 按 id 取单个关卡（下一关、重试时复用，保持确定性）。
  static ParkingLevel generateOne(int id) => _generateLevel(id);

  // ─────────────────────────────────────────────────────────────
  //  难度心跳（6 关一轮，双波峰）
  // ─────────────────────────────────────────────────────────────

  /// 心跳周期（关）。与合成模式（5）**故意不同**，见类注释。
  static const int rhythmPeriod = 6;

  /// 相位名（0..5），供 UI 显示难度标记。
  static const List<String> phaseNames = [
    '轻松',
    '顺手',
    '动脑',
    '缓冲',
    '硬仗',
    '尖峰',
  ];

  /// 各相位相对基线的步数倍率。
  ///
  /// 形状是「双波峰」：谷(0.50) → 升(0.80) → 第一峰(1.00) → 波谷(0.70)
  /// → 第二峰(1.15) → 尖峰(1.28)。与合成模式的单波峰（5 关一轮）错开，
  /// 两个模式的紧张点不会同时到达。
  static const List<double> _phaseMultiplier = [
    0.50, // 轻松：新车型登场
    0.80, // 顺手
    1.00, // 动脑：第一波峰
    0.70, // 缓冲：波谷，喘口气
    1.15, // 硬仗：第二波峰
    1.28, // 尖峰：全压力
  ];

  /// 各相位对挡路车数量的增减（轻松/缓冲更空，硬仗/尖峰更拥挤）。
  static const List<int> _phaseCrowd = [-1, 0, 0, -1, 1, 1];

  /// 高压力相位（硬仗/尖峰）的额外能力车偏置。
  ///
  /// 6x6 上整数步数是粗粒度（动脑与硬仗常落在同一档），
  /// 波峰之间的差异主要靠**机制密度**：能力车（传送/飞越/变向）越多，
  /// 局面越「活」，读盘成本越高 —— 这比硬拔步数更符合放松定位。
  static const double _climaxAbilityBonus = 0.12;

  /// 难度心跳相位（0..5）。
  ///
  /// 以**章内偏移**取模：每章第 1 关恒为相位 0（轻松），新车型在此登场。
  static int rhythmPhase(int id) {
    final c = ParkingChapters.chapterForId(id);
    return (id - c.startId) % rhythmPeriod;
  }

  /// 难度基线：随 id 线性爬升 2 → 6 步（这是"技能曲线"）。
  ///
  /// 末端取 6 而非更高，是为了让「硬仗」相位（×1.15 → 6.9）与
  /// 「尖峰」相位（×1.28 → 7.7）分别落在天花板 7 的两侧附近。
  /// 基线定太高会让波峰关频繁够不着目标、退化成中等关 —— 实测目标 8 时
  /// 波峰关均值反而被拖到 4.6，比「动脑」关还低，心跳的峰就平了。
  static double _baseCurve(int id) {
    final n = ParkingChapters.totalLevels;
    return 2.0 + (id - 1).clamp(0, n - 1) / (n - 1) * 4.0;
  }

  /// 目标最短步数 = 基线 × 相位倍率（这是"挑战曲线"= 技能曲线 × 心跳）。
  static int targetMinMoves(int id, int phase) {
    if (id <= 10) return 2; // 新手期恒定：点两下就停好
    return (_baseCurve(id) * _phaseMultiplier[phase])
        .round()
        .clamp(2, _maxMinMoves);
  }

  // ─────────────────────────────────────────────────────────────
  //  生成
  // ─────────────────────────────────────────────────────────────

  static ParkingLevel _generateLevel(int id) {
    final rng = Random(id * 2654435761 % 2147483647);
    // 棋盘尺寸：4→5→6。7x7 因生成耗时爆炸（实测 avg 28.7s/关）被否决。
    final size = id < 40 ? 4 : (id < 160 ? 5 : 6);
    final tier = ParkingChapters.tierForId(id);
    final phase = rhythmPhase(id);
    final target = targetMinMoves(id, phase);

    // 高压相位（硬仗/尖峰）给更多搜索预算：实测这两个相位目标最高、
    // 单次 DFS 命中率也最低（约 65-75%），不加重试会让波峰被压平 ——
    // 尖峰关实际步数反而低于硬仗关，心跳的"尖"就没了。
    // 代价是尖峰关生成最坏约 0.5-1s（选关页进一关生成一关，可接受）。
    final climax = phase >= 4;
    final tries = climax ? _climaxLayoutTries : _layoutTries;
    final nodeBudget = climax ? _climaxMaxNodes : _maxNodes;

    ParkingLevel? best;
    var bestMin = 0;

    for (var attempt = 0; attempt < tries; attempt++) {
      final r = _tryReverse(
        rng,
        id: id,
        size: size,
        tier: tier,
        target: target,
        phase: phase,
        maxNodes: nodeBudget,
      );
      if (r == null) continue;
      if (r.minMoves > bestMin) {
        bestMin = r.minMoves;
        best = r.level;
      }
      if (bestMin >= target) break; // 点名到位，提前结束
    }

    // 兜底：极端情况下退回 Rush Hour 式固定关，永不死局。
    if (best == null) {
      return _finalize(_fallbackLevel(id, size, tier), id, phase);
    }
    return _finalize(best, id, phase, minMoves: bestMin);
  }

  static ({ParkingLevel level, int minMoves})? _tryReverse(
    Random rng, {
    required int id,
    required int size,
    required VehicleType tier,
    required int target,
    required int phase,
    int maxNodes = _maxNodes,
  }) {
    final chapterIdx =
        ParkingChapters.all.indexOf(ParkingChapters.chapterForId(id));
    // 能力车偏置：越往后越依赖特殊能力（turn/teleport/flyOver）作为真实解法。
    // 波峰相位额外加成 —— 见 [_climaxAbilityBonus]。
    var abilityBias = chapterIdx <= 0
        ? 0.0
        : (0.10 + (chapterIdx - 1) * 0.05).clamp(0.0, 0.45);
    if (phase >= 4) {
      abilityBias = (abilityBias + _climaxAbilityBonus).clamp(0.0, 0.45);
    }

    // 挡路车数量：基线按棋盘尺寸，再叠相位增减。
    //
    // 这里比旧生成器**显著更密**是有意为之：旧方法是「随机撒车 + 事后筛选」，
    // 加密度会让不可解率飙到 65%（密集布局多死局，存活的反而更简单）。
    // 反向生成不受此约束 —— 从解状态倒走出来的局面 100% 可解，
    // 所以密度不再是敌人，而是**连锁的燃料**：车越多，越容易形成
    // 「挪开 A 才动得了 B、挪开 B 才动得了目标车」的多层阻挡。
    final baseFill = size == 4 ? 4 : (size == 5 ? 6 : 9);
    // 封顶 10：6x6 尖峰关靠第 10 辆车把连锁撑到 6-7 步
    // （实测 9 辆车时尖峰命中率仅 ~70%，波峰会被压平）。
    final fillCount = (baseFill + _phaseCrowd[phase]).clamp(2, 10);

    // 障碍：反向生成靠滑动图连通性，障碍过多会压低步数上限，故封顶 4。
    final obstacleCount = ((id ~/ 14) + 1 + _phaseCrowd[phase]).clamp(0, 4);

    // 目标车：5x5+ 用 2 格横车（经典 Rush Hour 红车），4x4 用单格车。
    final pieces = <ParkingPiece>[ParkingPiece(size >= 5 ? 2 : 1, true)];
    // 填充车**偏向竖车**（约 65%）：只有竖车能上下滑进停车位行去挡路，
    // 横车只能左右滑，对「目标车 → 停车位」这条通道毫无阻挡能力。
    final longChance = size >= 6 ? 0.65 : 0.45;
    for (var i = 0; i < fillCount; i++) {
      final len = rng.nextDouble() < longChance ? 2 : 1;
      pieces.add(ParkingPiece(len, rng.nextDouble() < 0.35));
    }

    final built = ParkingReverseBuilder.buildSolved(
      rng: rng,
      size: size,
      pieces: pieces,
      obstacleCount: obstacleCount,
    );
    if (built == null) return null;

    // 目标导向倒走：每一步都要求真实最短解严格 +1，
    // 因此终点的真实解精确等于走到的深度（详见 reverseWalk 注释）。
    final (coords, depth) =
        built.board.reverseWalk(built.solved, target, rng, maxNodes: maxNodes);
    if (depth < 1) return null;

    // 注意用**实际放下**的车（放不下的会被 buildSolved 省略），
    // 不能用请求的 pieces —— 两者长度不一致会越界。
    final actual = built.board.pieces;
    // 车型分配：index 0 = 目标车；填充车排除目标档（防止冒充目标车停进车位）。
    final tiers = _tierList(rng, tier, actual.length, abilityBias);
    final anchors = built.board.anchorsOf(coords);
    final vehicles = <VehicleSpawn>[
      for (var j = 0; j < actual.length; j++)
        VehicleSpawn(
          col: anchors[j].$2,
          row: anchors[j].$1,
          tier: tiers[j],
          length: actual[j].length,
          orientation: actual[j].horizontal
              ? ParkingOrientation.horizontal
              : ParkingOrientation.vertical,
        ),
    ];

    final lvl = ParkingLevel(
      id: id,
      name: '停车 #$id',
      rows: size,
      cols: size,
      grid: built.board.grid,
      vehicles: vehicles,
      targetTier: tier,
      rowHints: id >= 150 ? _generateRowHints(size, vehicles) : null,
      colHints: id >= 150 ? _generateColHints(size, vehicles) : null,
    );

    // 与游戏规则对齐的最终复核（builder 的内部 BFS 与 ParkingSolver 应是同一套
    // 滑动规则，这里兜底任何细微差异，成本只有一次）。
    final real = ParkingSolver.minMoves(lvl, maxStates: _maxSolverStates);
    // 1 步通关 = 弱关（点一下就赢），一律弃用换布局 —— 实测全量 800 关时
    // 出现过 L380 六次重试全部只倒走出 1 步深度的情况，没有这道闸门就会漏出去。
    if (real == null || real < 2) return null;
    return (level: lvl, minMoves: real);
  }

  /// 填充车档位序列：排除目标档，并按概率偏向带特殊能力的档位。
  static List<VehicleType> _tierList(
    Random rng,
    VehicleType tier,
    int n,
    double abilityBias,
  ) {
    final others = [
      for (var i = 0; i < VehicleType.values.length; i++)
        if (i != tier.id) VehicleType.values[i]
    ];
    others.shuffle(rng); // 确定性：同 id 同一关配色稳定可复现
    final abilityTiers = [
      for (final t in others) if (t.stats.ability != SpecialAbility.none) t,
    ];

    final out = <VehicleType>[tier];
    var cursor = 0;
    for (var i = 1; i < n; i++) {
      if (abilityBias > 0 &&
          abilityTiers.isNotEmpty &&
          rng.nextDouble() < abilityBias) {
        out.add(abilityTiers[rng.nextInt(abilityTiers.length)]);
      } else {
        out.add(others[cursor++ % others.length]);
      }
    }
    return out;
  }

  /// 标定判负线与限时。
  static ParkingLevel _finalize(
    ParkingLevel lvl,
    int id,
    int phase, {
    int? minMoves,
  }) {
    final m = minMoves ?? lvl.minMoves ?? 2;

    // movesLimit 是**硬判负线**（ParkingGame._checkLose：步数耗尽且未停车直接判负），
    // 不是星级门槛。放松向定位下必须给足余量：最优解的 2 倍 + 5 步，新手期 +8。
    // 想让"找最优解"有意义应该靠三星门槛，而不是收紧这条线把人卡死。
    final movesLimit =
        max(m + (id <= 10 ? 8 : 5), (m * 2.0).round()).toInt();

    // 限时只出现在「尖峰」相位（id>=120 起，每 6 关一次），
    // 让全轮最重的一拍有个可辨识的身份，而不是机械地周期性插。
    // 每步 8 秒，远宽于实际操作速度 —— 是仪式感，不是闸门。
    final timeLimit = (id >= 120 && phase == 5)
        ? (m * 8 + 25).clamp(50, 600).toInt()
        : null;

    return lvl.copyWith(
      minMoves: m,
      movesLimit: movesLimit,
      timeLimit: timeLimit,
    );
  }

  /// 扫雷风格行约束：计算每行实际被车辆占用的格数。
  static List<int?> _generateRowHints(int size, List<VehicleSpawn> vehicles) {
    return List.generate(size, (r) {
      var count = 0;
      for (final v in vehicles) {
        for (final (vr, _) in v.cells()) {
          if (vr == r) count++;
        }
      }
      return count > 0 ? count : null;
    });
  }

  /// 扫雷风格列约束：计算每列实际被车辆占用的格数。
  static List<int?> _generateColHints(int size, List<VehicleSpawn> vehicles) {
    return List.generate(size, (c) {
      var count = 0;
      for (final v in vehicles) {
        for (final (_, vc) in v.cells()) {
          if (vc == c) count++;
        }
      }
      return count > 0 ? count : null;
    });
  }

  /// 兜底关：长条目标车 + 底部行竖挡块的 Rush Hour 式可解关。
  /// 5x5+ 放 2 个竖挡块（目标车正前方 + 停车位列），解 = 2 次上移 + 横移 = 3 步，
  /// 满足"较大棋盘 >=3 步"的解谜感约定；4x4 单挡块 2 步。绝不退化成 1 步弱关。
  static ParkingLevel _fallbackLevel(
    int id,
    int size,
    VehicleType tier,
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
        tier: VehicleType.fromId((tier.id + 1) % VehicleType.values.length),
        length: 2,
        orientation: ParkingOrientation.vertical,
      ),
      // 挡块 B（5x5+）：压在停车位列上方，必须再上移一格目标才能滑入。
      if (big)
        VehicleSpawn(
          col: pc,
          row: pr - 1,
          tier: VehicleType.fromId((tier.id + 2) % VehicleType.values.length),
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
    );
  }
}

import 'dart:math';

import '../models/parking_level.dart';

/// 一辆车的几何（车型由生成器按 index 分配，此处只关心占格与滑动轴）。
class ParkingPiece {
  /// 占格数（1 = 单格车；>=2 = 长条车）。
  final int length;

  /// 是否横向（占同一行的若干列）。
  final bool horizontal;

  const ParkingPiece(this.length, this.horizontal);

  /// 能否纵向滑动：单格车四向可滑，长条车只能沿自身朝向轴。
  bool get vertical => length == 1 || !horizontal;
}

/// 一次单步滑动：第 [vi] 辆车滑到 (row, col)。
typedef ParkingSlide = ({int vi, int row, int col});

/// 一次 BFS 的结果：距离表 + 按深度分组的状态池（供 [ParkingReverseBuilder.walk] 抽取）。
class ParkingBfsResult {
  final Map<Object, int> dist;
  final Map<int, List<List<int>>> byDepth;

  const ParkingBfsResult(this.dist, this.byDepth);

  /// 该布局能达到的最大倒走深度（即这一局的步数天花板）。
  int get maxDepth {
    var m = 0;
    for (final d in byDepth.keys) {
      if (d > m) m = d;
    }
    return m;
  }
}

/// 反向停车关卡构建器（Rush Hour 关卡生成的标准做法）。
///
/// # 为什么必须反向生成
///
/// 旧生成器是「随机撒车 + 求解器事后筛选」，实测在 6x6 上填充车 4→12 时
/// 平均最短路**反而从 1.90 掉到 1.00**、不可解率 13%→65% —— 密集布局大概率
/// 是死局，能存活下来的反而是简单布局（幸存者偏差）。所以步数天花板是
/// **生成方法的瓶颈**，不是参数没给够，加密度只会换来更多死局。
///
/// # 本方法的两个关键性质
///
/// 1. **滑动可逆**：若局面 A 经「车 i 滑到位置 q」变成 B，则 B 也能经
///    「车 i 滑回原位置」变成 A（A 中车身占格合法 ⟹ B 中也合法）。
///    因此滑动图是**无向图**，从「解状态」做一次 BFS 得到的距离 d(s)，
///    恰好等于「局面 s 到解状态的最短步数」。
/// 2. **沿 d 严格 +1 倒走 K 步 ⟹ 最短解精确等于 K**，无需事后筛选。
///
/// # 唯一需要小心的地方
///
/// 胜利判定是「目标车压住停车位」，而停车位在 6x6 上可能被目标车以多种
/// 位置压住。若倒走途中目标车又滑回停车位，玩家实际可以提前获胜，
/// 真实最短解会小于 d。故 walk 中：
/// - 第一步强制移动目标车（正向最后一步 = 目标车滑入，符合直觉）；
/// - 之后禁止任何使目标车重新压住停车位的移动。
class ParkingReverseBuilder {
  /// BFS 状态预算。6x6 上 4-6 辆车的连通状态数通常几千到几万，
  /// 60k 足以展开到深度 8-10；超出即停止（已探索到的距离依然正确）。
  static const int defaultMaxStates = 60000;

  /// 上一次 [reverseWalk] 消耗的工作量（累计展开的 BFS 状态数）。
  ///
  /// 仅用于标定 [reverseWalk] 的预算常数，以及测试里做确定性回归。
  static int lastWork = 0;

  /// 本次倒走已消耗的工作量。
  ///
  /// **为什么不用墙钟**：旧版预算写的是 `Stopwatch > 40ms`，于是同一关在
  /// 不同机器/不同 CPU 负载下会生成出**不同布局** —— 玩家清缓存重进同一关
  /// 会看到另一张图，导出 JSON 也无法复现（实测两次全量导出，指纹不同）。
  /// 工作量只取决于搜索树本身，与机器速度无关，「超预算即放弃」于是变成
  /// 确定性行为；同时它仍然线性对应真实耗时，卡顿该封的顶照样封得住。
  int _work = 0;

  final int rows;
  final int cols;

  /// 地形（road / parking / obstacle / entrance）。
  final List<List<ParkingCellType>> grid;

  /// 车辆几何（index 0 恒为目标车）。
  final List<ParkingPiece> pieces;

  /// 停车位坐标。
  final int pr;
  final int pc;

  /// 目标车在 [pieces] 中的下标（恒为 0）。
  static const int targetIdx = 0;

  late final List<bool> _passable;
  late final List<List<int>> _offR;
  late final List<List<int>> _offC;
  late final List<List<(int, int)>> _dirs;
  late final List<int> _occ;

  ParkingReverseBuilder({
    required this.rows,
    required this.cols,
    required this.grid,
    required this.pieces,
    required this.pr,
    required this.pc,
  }) {
    _passable = List<bool>.generate(rows * cols, (i) {
      final t = grid[i ~/ cols][i % cols];
      return t == ParkingCellType.road || t == ParkingCellType.parking;
    });
    _offR = [];
    _offC = [];
    _dirs = [];
    for (final p in pieces) {
      final rs = <int>[];
      final cs = <int>[];
      for (var k = 0; k < p.length; k++) {
        if (p.horizontal) {
          rs.add(0);
          cs.add(k);
        } else {
          rs.add(k);
          cs.add(0);
        }
      }
      _offR.add(rs);
      _offC.add(cs);
      _dirs.add([
        if (p.horizontal) ...const [(0, 1), (0, -1)],
        if (p.vertical) ...const [(1, 0), (-1, 0)],
      ]);
    }
    _occ = List<int>.filled(rows * cols, 0);
  }

  // ─────────────────────────────────────────────────────────────
  //  构造「解状态」布局
  // ─────────────────────────────────────────────────────────────

  /// 构造一个**已通关**的布局：目标车压住停车位，其余车随机散布且不重叠。
  ///
  /// 返回构建器与其解状态坐标；约束无解（地形太挤）时返回 null。
  static ({ParkingReverseBuilder board, List<int> solved})? buildSolved({
    required Random rng,
    required int size,
    required List<ParkingPiece> pieces,
    required int obstacleCount,
  }) {
    if (pieces.isEmpty) return null;
    final pr = size - 1;
    final pc = (size - 2).clamp(0, size - 1);

    final grid = List.generate(
      size,
      (_) => List.filled(size, ParkingCellType.road),
    );
    grid[0][0] = ParkingCellType.entrance; // 装饰性入口
    grid[pr][pc] = ParkingCellType.parking;

    final taken = <(int, int)>{(0, 0), (pr, pc)};
    bool blocked((int, int) p) => taken.contains(p);

    // 障碍：撒在空闲 road 格上，避开入口与停车位。
    // 另需避开**整条停车位行**：那里是目标车的必经通道，
    // 一颗石墩就能把通道掐死，倒走出来的关卡会塌回 1-2 步。
    var placed = 0;
    var guard = 0;
    while (placed < obstacleCount && guard++ < 200) {
      final r = rng.nextInt(size);
      final c = rng.nextInt(size);
      if (r == pr) continue;
      if (blocked((r, c))) continue;
      grid[r][c] = ParkingCellType.obstacle;
      taken.add((r, c));
      placed++;
    }

    bool fits(int r, int c, ParkingPiece p) {
      for (var k = 0; k < p.length; k++) {
        final br = p.horizontal ? r : r + k;
        final bc = p.horizontal ? c + k : c;
        if (br < 0 || br >= size || bc < 0 || bc >= size) return false;
        if (grid[br][bc] == ParkingCellType.obstacle) return false;
        if (blocked((br, bc))) return false;
      }
      return true;
    }

    void occupy(int r, int c, ParkingPiece p) {
      for (var k = 0; k < p.length; k++) {
        taken.add(p.horizontal ? (r, c + k) : (r + k, c));
      }
    }

    // 目标车：必须压住停车位。枚举所有合法 anchor 后随机取一个。
    final target = pieces[targetIdx];
    final anchors = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        var covers = false;
        var ok = true;
        for (var k = 0; k < target.length; k++) {
          final br = target.horizontal ? r : r + k;
          final bc = target.horizontal ? c + k : c;
          if (br < 0 || br >= size || bc < 0 || bc >= size) {
            ok = false;
            break;
          }
          if (br == pr && bc == pc) covers = true;
          if (grid[br][bc] == ParkingCellType.obstacle) {
            ok = false;
            break;
          }
        }
        if (ok && covers) anchors.add((r, c));
      }
    }
    if (anchors.isEmpty) return null;
    final tAnchor = anchors[rng.nextInt(anchors.length)];
    occupy(tAnchor.$1, tAnchor.$2, target);

    /// 车 [p] 放在 (r,c) 时是否压到 [row] 行。
    bool touchesRow(int r, int c, ParkingPiece p, int row) {
      for (var k = 0; k < p.length; k++) {
        if ((p.horizontal ? r : r + k) == row) return true;
      }
      return false;
    }

    // 实际放下的车（放不下的直接省略，而不是整局作废 ——
    // 少一两辆车无关紧要，整局重来才浪费）。
    final placedPieces = <ParkingPiece>[target];
    final coords = <int>[tAnchor.$1, tAnchor.$2];

    // 其余车的**布局骨架**：这是能否倒走出高步数的关键，也是踩过坑的地方。
    //
    // 曾试过「直接在停车位行放车」，结果倒走连两步都走不到 —— 因为
    // 「要挡路就得有车在通道上」与「目标车要先滑开」互相矛盾：
    // 车占了通道，目标车根本滑不出去，通道宽度就是 0。
    //
    // 正确做法是反过来：解状态里**停车位行只留目标车**（让他能一路滑到尽头，
    // 通道才拉得开），把竖车预先停在停车位左侧的列上方 —— 倒走时它们
    // 「下落」到必经通道上，才形成「挪开 A 才动得了目标车」，
    // 而 A 自己上移时若被横车挡住，就进一步长出连锁。
    // 注意这不违反胜利条件：胜利只判定目标车压住停车位，其余车在哪都算赢。
    final fillCount = pieces.length - 1;
    // 关键列**从停车位往外排**：目标车滑到尽头后，通道就是它右端到停车位之间
    // 的那几列，紧邻停车位的列才是真正卡脖子的位置。若按 0..pc-1 随机撒，
    // 车会停在根本不在通道上的列，白占一辆车（实测深度只能到 2-3）。
    // onKey 辆车按列轮转 → 同一列叠 2 辆，天然形成「上移前得先挪开上面那辆」的连锁。
    final keyCols = <int>[for (var c = pc - 1; c >= 0; c--) c];
    final onKey = (fillCount * 0.8).round().clamp(1, fillCount);
    int prefColFor(int i) => i < onKey ? keyCols[i % keyCols.length] : -1;

    for (var i = 1; i < pieces.length; i++) {
      final p = pieces[i];
      final prefCol = prefColFor(i - 1);
      var put = false;
      for (var attempt = 0; attempt < 200 && !put; attempt++) {
        int r;
        int c;
        // 关键列只放**竖车**：横车只能左右滑，永远落不进停车位行，
        // 占了关键列等于白占（实测这一步之前深度只有 1）。
        if (prefCol >= 0 && !p.horizontal && attempt < 120) {
          // 停在停车位行的上方，把 pr 行留给目标车。
          final maxR = pr - p.length + 1;
          if (maxR <= 0) break;
          r = rng.nextInt(maxR);
          c = prefCol;
        } else {
          r = p.horizontal
              ? rng.nextInt(size)
              : rng.nextInt(size - p.length + 1);
          c = p.horizontal
              ? rng.nextInt(size - p.length + 1)
              : rng.nextInt(size);
        }
        if (!fits(r, c, p)) continue;
        // 解状态里停车位行只属于目标车。
        if (touchesRow(r, c, p, pr)) continue;
        occupy(r, c, p);
        placedPieces.add(p);
        coords.add(r);
        coords.add(c);
        put = true;
      }
      // 放不下就跳过这辆（placedPieces / coords 始终等长）。
    }
    if (placedPieces.length < 2) return null; // 至少得有一辆挡路车

    final board = ParkingReverseBuilder(
      rows: size,
      cols: size,
      grid: grid,
      pieces: placedPieces,
      pr: pr,
      pc: pc,
    );
    // 兜底：目标车至少要有一步可走，否则倒走无从开始。
    if (!board.moves(coords).any((m) => m.vi == targetIdx)) return null;
    return (board: board, solved: coords);
  }

  // ─────────────────────────────────────────────────────────────
  //  滑动图
  // ─────────────────────────────────────────────────────────────

  void _fillOcc(List<int> c, {int skip = -1}) {
    _occ.fillRange(0, _occ.length, 0);
    for (var i = 0; i < pieces.length; i++) {
      if (i == skip) continue;
      final r = c[i * 2];
      final col = c[i * 2 + 1];
      for (var k = 0; k < _offR[i].length; k++) {
        _occ[(r + _offR[i][k]) * cols + (col + _offC[i][k])] = 1;
      }
    }
  }

  /// 状态键：每车 6bit（row<<3|col），前 5 辆打进 lo、其余打进 hi，
  /// 两条 30bit 在 web（JS 安全整数 53bit）上也不会失真。
  Object keyOf(List<int> c) {
    var lo = 0;
    var hi = 0;
    for (var i = 0; i < pieces.length; i++) {
      final v = ((c[i * 2] << 3) | c[i * 2 + 1]) & 0x3F;
      if (i < 5) {
        lo |= v << (i * 6);
      } else {
        hi |= v << ((i - 5) * 6);
      }
    }
    return (hi, lo);
  }

  bool coversParking(List<int> c, int vi) {
    final r = c[vi * 2];
    final col = c[vi * 2 + 1];
    for (var k = 0; k < _offR[vi].length; k++) {
      if (r + _offR[vi][k] == pr && col + _offC[vi][k] == pc) return true;
    }
    return false;
  }

  /// 枚举当前局面下所有合法的单步滑动（一步 = 一辆车沿直线滑到任意可达终点）。
  List<ParkingSlide> moves(List<int> c) {
    final out = <ParkingSlide>[];
    _fillOcc(c);
    for (var vi = 0; vi < pieces.length; vi++) {
      final r = c[vi * 2];
      final col = c[vi * 2 + 1];
      final bodyLen = _offR[vi].length;
      // 腾出本车占格后再判滑行（自己不挡自己）。
      for (var k = 0; k < bodyLen; k++) {
        _occ[(r + _offR[vi][k]) * cols + (col + _offC[vi][k])] = 0;
      }
      for (final (dr, dc) in _dirs[vi]) {
        var nr = r + dr;
        var nc = col + dc;
        while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          var ok = true;
          for (var k = 0; k < bodyLen; k++) {
            final br = nr + _offR[vi][k];
            final bc = nc + _offC[vi][k];
            if (br < 0 || br >= rows || bc < 0 || bc >= cols) {
              ok = false;
              break;
            }
            final idx = br * cols + bc;
            if (!_passable[idx] || _occ[idx] == 1) {
              ok = false;
              break;
            }
            // 停车位仅目标车可进入。
            if (vi != targetIdx && br == pr && bc == pc) {
              ok = false;
              break;
            }
          }
          if (!ok) break;
          out.add((vi: vi, row: nr, col: nc));
          nr += dr;
          nc += dc;
        }
      }
      for (var k = 0; k < bodyLen; k++) {
        _occ[(r + _offR[vi][k]) * cols + (col + _offC[vi][k])] = 1;
      }
    }
    return out;
  }

  List<int> apply(List<int> c, ParkingSlide m) {
    final out = List<int>.from(c);
    out[m.vi * 2] = m.row;
    out[m.vi * 2 + 1] = m.col;
    return out;
  }

  /// 从解状态出发做一次 BFS，返回按深度索引的状态表。
  ///
  /// 滑动图无向，故 BFS 深度 d 恰好等于「该局面通关所需的最少步数」。
  ///
  /// **剪枝**：任何「目标车压住停车位」的非解状态一律不入队。
  /// 这类状态玩家一步就赢了，若让它们成为通路上的中间节点，
  /// 倒走出来的路径会中途"提前胜利"，真实最短解短于深度。
  /// 剪掉它们后，BFS 图中 [solved] 是唯一胜利态，深度即真实步数。
  ParkingBfsResult bfs(List<int> solved, {int maxStates = defaultMaxStates}) {
    final dist = <Object, int>{keyOf(solved): 0};
    final byDepth = <int, List<List<int>>>{
      0: [List<int>.from(solved)],
    };
    final queue = <(List<int>, int)>[(solved, 0)];
    var head = 0;
    while (head < queue.length) {
      if (dist.length >= maxStates) break;
      final (cur, d) = queue[head++];
      for (final m in moves(cur)) {
        final next = apply(cur, m);
        final k = keyOf(next);
        if (dist.containsKey(k)) continue;
        // 提前胜利的状态不参与建图（见上方剪枝说明）。
        if (coversParking(next, targetIdx)) continue;
        dist[k] = d + 1;
        (byDepth[d + 1] ??= <List<int>>[]).add(next);
        queue.add((next, d + 1));
      }
    }
    return ParkingBfsResult(dist, byDepth);
  }

  /// 目标导向的倒走：用 DFS 找一条「真实最短解严格逐层 +1」的长度 [steps] 路径。
  ///
  /// 为什么必须逐步验证：胜利只要求「目标车压住停车位」，其余车停在何处无关，
  /// 因此「离某个特定解状态 K 步」≠「离胜利 K 步」。实测直接抽深度 K 的样本，
  /// 真实解普遍只有 2-3 步 —— 目标车一步就能滑进去，前面的深度全是假的。
  ///
  /// 这里每一步都要求 [minMovesToWin] 恰好等于 d+1，于是终点的真实最短解
  /// **精确等于**走到的深度，且能造出真正需要层层挪车的连锁（挪开 A 才能挪 B）。
  ///
  /// 返回 (终点坐标, 实际深度)；走不满 [steps] 时返回过程中达到的最深局面。
  (List<int>, int) reverseWalk(
    List<int> solved,
    int steps,
    Random rng, {
    int maxNodes = 4000,

    /// 工作量预算（累计展开的 BFS 状态数，替代原先的墙钟毫秒预算）。
    ///
    /// 深层目标（7-8 步）的组合爆炸会让单次倒走飙到秒级，而选关是
    /// 进一关生成一关，卡顿必须封顶。超预算即放弃、返回已走到的最深局面。
    ///
    /// 取值来自 800 关全量标定：见 tool/bench_parking.dart。
    int workBudget = 220000,
  }) {
    final visited = <Object>{keyOf(solved)};
    var best = List<int>.from(solved);
    var bestD = 0;
    var nodes = 0;
    _work = 0;

    bool dfs(List<int> cur, int d) {
      if (d >= steps) return true;
      if (nodes++ > maxNodes) return false;
      if (_work > workBudget) return false;
      final ms = moves(cur)..shuffle(rng);
      // 启发式排序：优先「把车挪到目标车必经通道上」。
      //
      // 纯随机会白试大量无关移动 —— 目标车锁在停车位那一行，
      // 只有压住它通道的车才真正构成阻挡。竖车挡路价值更高：
      // 它要上下挪开才能让路，而挪开它又可能需要先动别的车 —— 连锁由此产生。
      ms.sort((a, b) => _score(cur, apply(cur, b), b, d) -
          _score(cur, apply(cur, a), a, d));
      for (final m in ms) {
        final nx = apply(cur, m);
        final k = keyOf(nx);
        if (!visited.add(k)) continue;
        // 提前胜利的局面既不能做中间态也不能做终点。
        if (coversParking(nx, targetIdx)) {
          visited.remove(k);
          continue;
        }
        // 真实解必须严格 +1 —— 这一步是整个算法的灵魂。
        if (minMovesToWin(nx, limit: d + 1) != d + 1) {
          visited.remove(k);
          continue;
        }
        if (d + 1 > bestD) {
          bestD = d + 1;
          best = nx;
        }
        if (dfs(nx, d + 1)) return true;
        visited.remove(k);
      }
      return false;
    }

    dfs(solved, 0);
    lastWork = _work;
    return (best, bestD);
  }

  /// 倒走候选的启发式打分（越大越优先尝试）。
  int _score(List<int> cur, List<int> nx, ParkingSlide m, int d) {
    if (d == 0) {
      // 第一步：目标车滑得越远越好 —— 通道越长，后面能插进来的阻挡越多，
      // 紧贴停车位滑开一格的话通道为零，根本无从阻挡。
      return (nx[targetIdx * 2 + 1] - pc).abs();
    }
    if (m.vi == targetIdx) return 0; // 目标车留到最后：它的位置决定终点，不该乱窜
    if (blocksPath(nx, m.vi)) return pieces[m.vi].vertical ? 6 : 3;
    return 0;
  }

  /// 从深度 [steps] 的状态里随机取一个作为关卡初始局面。
  ///
  /// 存在性由 BFS 树保证：深度 K 的状态必然有一条长度恰好 K 的到解路径
  /// （沿 BFS 父指针回溯即可），所以最短解精确等于 K —— 这就是反向生成
  /// 相对「随机撒车 + 事后筛选」的决定性优势：难度可以**点名指定**。
  ///
  /// 该深度不存在时（布局太松散，图不够深）退到最深的可用层并回传实际深度。
  (List<int>, int) walk(
    List<int> solved,
    int steps,
    Random rng,
    ParkingBfsResult r,
  ) {
    var d = steps;
    while (d > 0 && (r.byDepth[d]?.isEmpty ?? true)) {
      d--;
    }
    if (d <= 0) return (List<int>.from(solved), 0);
    final bucket = r.byDepth[d]!;
    return (bucket[rng.nextInt(bucket.length)], d);
  }

  /// 从局面 [start] 出发真实通关所需的最少步数（胜利 = 目标车压住停车位）。
  ///
  /// 与 [ParkingSolver] 等价，但直接在本构建器的内部表示上跑 BFS，
  /// 省掉每次试探都要组装一个 ParkingLevel 的开销 —— 倒走 DFS 需要成百上千次试探。
  ///
  /// [limit] 为搜索深度上限：超过即放弃并返回 null。
  /// 倒走 DFS 只关心「真实解是否**恰好**等于 d+1」，给足这个上限就能把
  /// 试探成本砍掉一个量级 —— 车一多时完整 BFS 会让单关耗时飙到秒级。
  int? minMovesToWin(List<int> start, {int maxStates = 20000, int? limit}) {
    if (coversParking(start, targetIdx)) return 0;
    final seen = <Object>{keyOf(start)};
    var frontier = <List<int>>[start];
    var depth = 0;
    while (frontier.isNotEmpty && seen.length < maxStates) {
      if (limit != null && depth >= limit) return null;
      // 工作量记账：只数「实际展开的状态」，与机器速度无关，
      // 是 [reverseWalk] 预算的确定性等价物。
      _work += frontier.length;
      depth++;
      final next = <List<int>>[];
      for (final cur in frontier) {
        for (final m in moves(cur)) {
          final nx = apply(cur, m);
          if (!seen.add(keyOf(nx))) continue;
          if (coversParking(nx, targetIdx)) return depth;
          next.add(nx);
        }
      }
      frontier = next;
    }
    return null;
  }

  /// 停车位所在行上，目标车车身与停车位之间的「必经通道」列集合。
  ///
  /// 目标车是横车、只能左右滑，所以它与停车位之间只可能隔着同一行的格子 ——
  /// 挡住这些格子才是真正的阻挡，别处的车再多也与他无关。
  /// 这是倒走启发式的依据：优先把车挪到这些列上，才能形成「挪开 A 才动得了目标车」。
  Set<int> pathCols(List<int> coords) {
    final tr = coords[targetIdx * 2];
    if (tr != pr) return const <int>{};
    final tc = coords[targetIdx * 2 + 1];
    var tMin = 99;
    var tMax = -1;
    for (var k = 0; k < _offC[targetIdx].length; k++) {
      final c = tc + _offC[targetIdx][k];
      if (c < tMin) tMin = c;
      if (c > tMax) tMax = c;
    }
    final out = <int>{};
    if (pc > tMax) {
      for (var c = tMax + 1; c <= pc; c++) {
        out.add(c);
      }
    } else if (pc < tMin) {
      for (var c = pc; c < tMin; c++) {
        out.add(c);
      }
    }
    return out;
  }

  /// 车 [vi] 是否正压在目标车的必经通道上。
  bool blocksPath(List<int> coords, int vi) {
    if (vi == targetIdx) return false;
    final cols = pathCols(coords);
    if (cols.isEmpty) return false;
    final r = coords[vi * 2];
    final c = coords[vi * 2 + 1];
    for (var k = 0; k < _offC[vi].length; k++) {
      if (r + _offR[vi][k] == pr && cols.contains(c + _offC[vi][k])) return true;
    }
    return false;
  }

  /// 目标车能否**一步**滑入停车位。
  ///
  /// 若能，该局面的真实最短解就是 1 —— 无论它在 BFS 距离图里有多深。
  /// 因为胜利只要求「目标车压住停车位」，并不要求其余车回到解状态的位置；
  /// 所以「离某个特定解状态 K 步」不等于「离胜利 K 步」，这曾让早期版本
  /// 采出的关卡真实步数塌回 1-2 步。抽样时必须先用本方法滤掉这类捷径。
  bool targetCanEnterInOne(List<int> coords) {
    for (final m in moves(coords)) {
      if (m.vi != targetIdx) continue;
      if (coversParking(apply(coords, m), targetIdx)) return true;
    }
    return false;
  }

  /// 目标车与停车位是否既不同行也不同列（单格车需转弯，天然 ≥2 步）。
  bool targetOffAxis(List<int> coords) {
    return coords[targetIdx * 2] != pr && coords[targetIdx * 2 + 1] != pc;
  }

  /// 坐标序列 → 车辆锚点列表（供生成器组装 VehicleSpawn）。
  List<(int row, int col)> anchorsOf(List<int> coords) => [
        for (var i = 0; i < pieces.length; i++) (coords[i * 2], coords[i * 2 + 1]),
      ];
}

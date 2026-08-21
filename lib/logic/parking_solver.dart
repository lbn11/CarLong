import '../models/parking_level.dart';

/// 一次滑动操作（停车模式里"一步"= 选一辆车，沿直线滑到任意可达终点）。
class ParkingMove {
  final int vehicleIndex;
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;

  const ParkingMove({
    required this.vehicleIndex,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
  });
}

/// 停车关卡求解器：用 BFS 求最短操作序列（一步 = 一辆车沿直线滑到任意可达终点）。
///
/// 支持长条车（[VehicleSpawn.length] >= 2）：车身占多格、仅沿朝向轴滑动，
/// 与 [ParkingGame] 的滑动规则严格一致。胜利判定：目标等级的车车身压住停车位即获胜，
/// 且只有目标车能进入停车位。entrance/exit/obstacle 视为不可通行的静态障碍。
class ParkingSolver {
  /// 返回最短解步骤；关卡无解（或状态空间过大超出 [maxStates]）时返回 null。
  static List<ParkingMove>? solve(ParkingLevel level, {int maxStates = 300000}) {
    final rows = level.rows;
    final cols = level.cols;

    // 停车位坐标（全局应唯一）。
    int? pr;
    int? pc;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (level.grid[r][c] == ParkingCellType.parking) {
          pr = r;
          pc = c;
        }
      }
    }
    if (pr == null) return null;

    // 目标车索引（唯一）。
    int? targetIdx;
    for (var i = 0; i < level.vehicles.length; i++) {
      if (level.vehicles[i].tier == level.targetTier) {
        targetIdx = i;
        break;
      }
    }
    if (targetIdx == null) return null;

    // 每辆车：长度 / 是否可横 / 是否可纵。
    final lens = <int>[];
    final canHoriz = <bool>[];
    final canVert = <bool>[];
    for (final v in level.vehicles) {
      lens.add(v.length);
      final horiz = v.length == 1 ||
          v.orientation == ParkingOrientation.horizontal;
      final vert =
          v.length == 1 || v.orientation == ParkingOrientation.vertical;
      canHoriz.add(horiz);
      canVert.add(vert);
    }

    // 车身相对锚点的偏移（扁平数组，避免热路径分配）。
    final offR = <List<int>>[];
    final offC = <List<int>>[];
    for (var i = 0; i < level.vehicles.length; i++) {
      final rs = <int>[];
      final cs = <int>[];
      for (var k = 0; k < lens[i]; k++) {
        if (canHoriz[i]) {
          rs.add(0);
          cs.add(k);
        } else {
          rs.add(k);
          cs.add(0);
        }
      }
      offR.add(rs);
      offC.add(cs);
    }

    // 初始坐标序列 [r0,c0,r1,c1,...]。
    final startCoords = <int>[];
    for (final v in level.vehicles) {
      startCoords.add(v.row);
      startCoords.add(v.col);
    }
    // 开局即胜利：目标车车身已压住停车位。
    bool targetWins(List<int> coords) {
      final r = coords[targetIdx! * 2];
      final c = coords[targetIdx * 2 + 1];
      for (var k = 0; k < offR[targetIdx].length; k++) {
        if (r + offR[targetIdx][k] == pr && c + offC[targetIdx][k] == pc) {
          return true;
        }
      }
      return false;
    }

    if (targetWins(startCoords)) return [];

    // 静态可通行：road 或 parking；obstacle/entrance/exit 不可通行（与 canMoveTo 一致）。
    final passable = List<bool>.filled(
      rows * cols,
      false,
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final t = level.grid[r][c];
        passable[r * cols + c] =
            t == ParkingCellType.road || t == ParkingCellType.parking;
      }
    }

    // 占用网格：1 = 被某辆车压住。每个状态出队时重建（棋盘 ≤ 8x8，代价可忽略）。
    final occ = List<int>.filled(rows * cols, 0);
    void fillOccupancy(List<int> coords, {int? skip}) {
      occ.fillRange(0, occ.length, 0);
      for (var i = 0; i < level.vehicles.length; i++) {
        if (i == skip) continue;
        final r = coords[i * 2];
        final c = coords[i * 2 + 1];
        for (var k = 0; k < offR[i].length; k++) {
          occ[(r + offR[i][k]) * cols + (c + offC[i][k])] = 1;
        }
      }
    }

    String encode(List<int> coords) => coords.join(',');

    // 状态键：小棋盘（≤7x7）且车辆 ≤10 时打包成 (hi, lo) 整型记录——
    // 每车 2 坐标 × 3bit = 6bit，5 车打进一个 32bit，结构相等可直接去重，
    // 免去热路径上的字符串拼接；否则退回字符串键。
    final nV = level.vehicles.length;
    final packable = rows <= 7 && cols <= 7 && nV <= 10;
    Object packKey(List<int> coords) {
      if (!packable) return encode(coords);
      var lo = 0;
      var hi = 0;
      for (var i = 0; i < nV; i++) {
        final v = ((coords[i * 2] << 3) | coords[i * 2 + 1]) & 0x3F;
        if (i < 5) {
          lo |= v << (i * 6);
        } else {
          hi |= v << ((i - 5) * 6);
        }
      }
      return (hi, lo);
    }

    // 打包模式下 O(1) 派生候选键：只替换第 vi 辆车的 6bit 字段。
    (int, int) packMoved(int hi, int lo, int vi, int nr, int nc) {
      final v = ((nr << 3) | nc) & 0x3F;
      if (vi < 5) {
        final shift = vi * 6;
        lo = (lo & ~(0x3F << shift)) | (v << shift);
      } else {
        final shift = (vi - 5) * 6;
        hi = (hi & ~(0x3F << shift)) | (v << shift);
      }
      return (hi, lo);
    }

    final startKey = packKey(startCoords);
    final queue = <List<int>>[startCoords];
    var head = 0;
    final visited = <Object>{};
    visited.add(startKey);
    final parent = <Object, Object>{};
    final moveOf = <Object, ParkingMove>{};

    // 每辆车的滑动方向（只依赖朝向，预计算一次）。
    final dirsPerVehicle = <List<(int, int)>>[
      for (var vi = 0; vi < level.vehicles.length; vi++)
        [
          if (canHoriz[vi]) ...[(0, 1), (0, -1)],
          if (canVert[vi]) ...[(1, 0), (-1, 0)],
        ],
    ];

    var states = 0;
    while (head < queue.length) {
      final coords = queue[head++];
      states++;
      if (states > maxStates) return null;

      fillOccupancy(coords);
      final curKey = packKey(coords);

      for (var vi = 0; vi < level.vehicles.length; vi++) {
        final r = coords[vi * 2];
        final c = coords[vi * 2 + 1];
        // 腾出本车占用的格子后即可滑行检查。
        for (var k = 0; k < offR[vi].length; k++) {
          occ[(r + offR[vi][k]) * cols + (c + offC[vi][k])] = 0;
        }
        final bodyLen = offR[vi].length;
        final offRVi = offR[vi];
        final offCVi = offC[vi];

        for (final (dr, dc) in dirsPerVehicle[vi]) {
          var nr = r + dr;
          var nc = c + dc;
          while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
            // 整车身在该 anchor 下必须合法。
            var ok = true;
            var hitsParking = false;
            for (var k = 0; k < bodyLen; k++) {
              final br = nr + offRVi[k];
              final bc = nc + offCVi[k];
              if (br < 0 || br >= rows || bc < 0 || bc >= cols) {
                ok = false;
                break;
              }
              final idx = br * cols + bc;
              if (!passable[idx] || occ[idx] == 1) {
                ok = false;
                break;
              }
              // 停车位仅目标车可进入（全局唯一，坐标比较即可）。
              if (vi != targetIdx && br == pr && bc == pc) {
                ok = false;
                break;
              }
              if (vi == targetIdx && br == pr && bc == pc) {
                hitsParking = true;
              }
            }
            if (!ok) break;

            // 候选状态键：打包模式 O(1) 派生；否则整串编码。
            final Object key;
            final List<int> nextCoords;
            if (packable) {
              key = packMoved(
                (curKey as (int, int)).$1,
                curKey.$2,
                vi,
                nr,
                nc,
              );
              nextCoords = List<int>.from(coords);
              nextCoords[vi * 2] = nr;
              nextCoords[vi * 2 + 1] = nc;
            } else {
              nextCoords = List<int>.from(coords);
              nextCoords[vi * 2] = nr;
              nextCoords[vi * 2 + 1] = nc;
              key = encode(nextCoords);
            }
            if (visited.add(key)) {
              parent[key] = curKey;
              moveOf[key] = ParkingMove(
                vehicleIndex: vi,
                fromRow: r,
                fromCol: c,
                toRow: nr,
                toCol: nc,
              );
              // 目标车车身压住停车位即胜利。
              if (hitsParking) {
                return _reconstruct(parent, moveOf, key);
              }
              queue.add(nextCoords);
            }
            nr += dr;
            nc += dc;
          }
        }
        // 恢复本车占用标记。
        for (var k = 0; k < bodyLen; k++) {
          occ[(r + offRVi[k]) * cols + (c + offCVi[k])] = 1;
        }
      }
    }
    return null;
  }

  /// 最短步数；无解返回 null。
  static int? minMoves(ParkingLevel level, {int maxStates = 300000}) =>
      solve(level, maxStates: maxStates)?.length;

  static List<ParkingMove> _reconstruct(
    Map<Object, Object> parent,
    Map<Object, ParkingMove> moveOf,
    Object end,
  ) {
    final path = <ParkingMove>[];
    var cur = end;
    while (parent.containsKey(cur)) {
      path.add(moveOf[cur]!);
      cur = parent[cur]!;
    }
    return path.reversed.toList();
  }
}

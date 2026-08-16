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

    // 车身占用的格子（给定 anchor）。
    List<(int, int)> cellsOf(int idx, int r, int c) {
      final out = <(int, int)>[];
      final horiz = canHoriz[idx];
      for (var i = 0; i < lens[idx]; i++) {
        out.add(horiz ? (r, c + i) : (r + i, c));
      }
      return out;
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
      for (final cell in cellsOf(targetIdx, r, c)) {
        if (cell == (pr, pc)) return true;
      }
      return false;
    }

    if (targetWins(startCoords)) return [];

    // 静态可通行：road 或 parking；obstacle/entrance/exit 不可通行（与 canMoveTo 一致）。
    bool staticPassable(int r, int c) =>
        level.grid[r][c] == ParkingCellType.road ||
        level.grid[r][c] == ParkingCellType.parking;

    // 占用集合（排除 moving 车）。
    Set<(int, int)> occupiedExcept(List<int> coords, int moving) {
      final occ = <(int, int)>{};
      for (var i = 0; i < level.vehicles.length; i++) {
        if (i == moving) continue;
        final r = coords[i * 2];
        final c = coords[i * 2 + 1];
        for (final cell in cellsOf(i, r, c)) {
          occ.add(cell);
        }
      }
      return occ;
    }

    String encode(List<int> coords) => coords.join(',');

    final start = encode(startCoords);
    final queue = <String>[start];
    var head = 0;
    final visited = <String>{};
    visited.add(start);
    final parent = <String, String>{};
    final moveOf = <String, ParkingMove>{};

    var states = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      states++;
      if (states > maxStates) return null;

      final coords = cur.split(',').map(int.parse).toList();

      for (var vi = 0; vi < level.vehicles.length; vi++) {
        final r = coords[vi * 2];
        final c = coords[vi * 2 + 1];
        // 该车的可用滑动方向（受长度/朝向约束）。
        final dirs = <(int, int)>[];
        if (canHoriz[vi]) {
          dirs.add((0, 1));
          dirs.add((0, -1));
        }
        if (canVert[vi]) {
          dirs.add((1, 0));
          dirs.add((-1, 0));
        }
        final movingOcc = occupiedExcept(coords, vi);

        for (final (dr, dc) in dirs) {
          var nr = r + dr;
          var nc = c + dc;
          while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
            // 整车身在该 anchor 下必须合法。
            var ok = true;
            for (final (br, bc) in cellsOf(vi, nr, nc)) {
              if (br < 0 || br >= rows || bc < 0 || bc >= cols) {
                ok = false;
                break;
              }
              if (!staticPassable(br, bc)) {
                ok = false;
                break;
              }
              if (movingOcc.contains((br, bc))) {
                ok = false;
                break;
              }
              // 停车位仅目标车可进入。
              if (level.grid[br][bc] == ParkingCellType.parking &&
                  vi != targetIdx) {
                ok = false;
                break;
              }
            }
            if (!ok) break;

            final nextCoords = List<int>.from(coords);
            nextCoords[vi * 2] = nr;
            nextCoords[vi * 2 + 1] = nc;
            final key = encode(nextCoords);
            if (!visited.contains(key)) {
              visited.add(key);
              parent[key] = cur;
              moveOf[key] = ParkingMove(
                vehicleIndex: vi,
                fromRow: r,
                fromCol: c,
                toRow: nr,
                toCol: nc,
              );
              // 目标车车身压住停车位即胜利。
              if (vi == targetIdx && cellsOf(vi, nr, nc).contains((pr, pc))) {
                return _reconstruct(parent, moveOf, key);
              }
              queue.add(key);
            }
            nr += dr;
            nc += dc;
          }
        }
      }
    }
    return null;
  }

  /// 最短步数；无解返回 null。
  static int? minMoves(ParkingLevel level, {int maxStates = 300000}) =>
      solve(level, maxStates: maxStates)?.length;

  static List<ParkingMove> _reconstruct(
    Map<String, String> parent,
    Map<String, ParkingMove> moveOf,
    String end,
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

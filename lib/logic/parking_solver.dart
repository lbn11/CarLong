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
/// 胜利判定与 [ParkingGame] 一致：目标等级的车停在停车位（parking 格）即获胜，
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

    // 初始坐标序列 [r0,c0,r1,c1,...]。
    final startCoords = <int>[];
    for (final v in level.vehicles) {
      startCoords.add(v.row);
      startCoords.add(v.col);
    }
    if (startCoords[targetIdx * 2] == pr &&
        startCoords[targetIdx * 2 + 1] == pc) {
      return []; // 开局即胜利。
    }

    // 静态可通行：road 或 parking；obstacle/entrance/exit 不可通行（与 canMoveTo 一致）。
    bool staticPassable(int r, int c) =>
        level.grid[r][c] == ParkingCellType.road ||
        level.grid[r][c] == ParkingCellType.parking;

    String encode(List<int> coords) => coords.join(',');

    final start = encode(startCoords);
    final queue = <String>[start];
    var head = 0;
    final visited = <String>{};
    visited.add(start);
    final parent = <String, String>{};
    final moveOf = <String, ParkingMove>{};

    // ignore: prefer_const_declarations
    final dirs = const <(int, int)>[
      (0, 1),
      (0, -1),
      (1, 0),
      (-1, 0),
    ];

    var states = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      states++;
      if (states > maxStates) return null;

      final coords = cur.split(',').map(int.parse).toList();
      for (var vi = 0; vi < level.vehicles.length; vi++) {
        final r = coords[vi * 2];
        final c = coords[vi * 2 + 1];
        // 目标车若已在停车位，视为已胜利状态，不会进入队列（初始已检查，命中即返回）。
        for (final (dr, dc) in dirs) {
          var nr = r + dr;
          var nc = c + dc;
          while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
            if (!staticPassable(nr, nc)) break;
            // 被其他车辆占据。
            var occupied = false;
            for (var oi = 0; oi < level.vehicles.length; oi++) {
              if (oi == vi) continue;
              if (coords[oi * 2] == nr && coords[oi * 2 + 1] == nc) {
                occupied = true;
                break;
              }
            }
            if (occupied) break;
            // 停车位仅目标车可进入。
            if (level.grid[nr][nc] == ParkingCellType.parking &&
                vi != targetIdx) {
              break;
            }

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
              // 目标车抵达停车位即胜利。
              if (vi == targetIdx && nr == pr && nc == pc) {
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

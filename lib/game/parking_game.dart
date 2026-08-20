import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/parking_solver.dart';
import '../models/parking_level.dart';
import '../models/vehicle.dart';

/// 棋盘格子状态
class ParkingCell {
  final ParkingCellType type;
  final int? vehicleIndex; // 占用该格的车辆索引(-1 表示无)

  const ParkingCell({required this.type, this.vehicleIndex});

  ParkingCell copyWith({
    ParkingCellType? type,
    int? vehicleIndex,
    bool clearVehicle = false,
  }) {
    return ParkingCell(
      type: type ?? this.type,
      vehicleIndex: clearVehicle ? null : (vehicleIndex ?? this.vehicleIndex),
    );
  }

  bool get isRoad => type == ParkingCellType.road;
  bool get isParking => type == ParkingCellType.parking;
  bool get isObstacle => type == ParkingCellType.obstacle;
  bool get isEntrance => type == ParkingCellType.entrance;
  bool get isExit => type == ParkingCellType.exit;
  bool get isPassable =>
      (type == ParkingCellType.road || type == ParkingCellType.parking) &&
      vehicleIndex == null;
}

/// 车辆状态
class VehicleState {
  final int index;
  final VehicleType tier;
  final String label;
  int row;
  int col;
  final int length; // 占用格数（>=2 为长条车）
  final ParkingOrientation orientation; // 长条车朝向
  bool parked; // 是否已停在停车位

  VehicleState({
    required this.index,
    required this.tier,
    required this.label,
    required this.row,
    required this.col,
    this.length = 1,
    this.orientation = ParkingOrientation.horizontal,
    this.parked = false,
  });

  /// 该车辆当前占用的所有格子（以 anchor(row,col) 为左上角）。
  List<(int, int)> get cells {
    final out = <(int, int)>[];
    for (var i = 0; i < length; i++) {
      out.add(orientation == ParkingOrientation.horizontal
          ? (row, col + i)
          : (row + i, col));
    }
    return out;
  }

  /// 长条车只能沿车身方向滑动；单格车四向均可。
  bool get _canHoriz =>
      length == 1 || orientation == ParkingOrientation.horizontal;
  bool get _canVert =>
      length == 1 || orientation == ParkingOrientation.vertical;

  VehicleState copyWith({int? row, int? col, bool? parked}) {
    return VehicleState(
      index: index,
      tier: tier,
      label: label,
      row: row ?? this.row,
      col: col ?? this.col,
      length: length,
      orientation: orientation,
      parked: parked ?? this.parked,
    );
  }
}

/// 操作撤销记录
class ParkingAction {
  final int vehicleIndex;
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;

  const ParkingAction({
    required this.vehicleIndex,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
  });
}

/// 停车模式游戏逻辑
class ParkingGame extends ChangeNotifier {
  final ParkingLevel level;
  late final List<List<ParkingCell>> _grid;
  late final List<VehicleState> _vehicles;
  final List<ParkingAction> _undoStack = [];

  int _moves = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _won = false;
  bool _lost = false;

  ParkingGame(this.level) {
    _initGrid();
    _initVehicles();
    _startTimer();
  }

  /// 棋盘宽度(列数)
  int get cols => level.cols;

  /// 棋盘高度(行数)
  int get rows => level.rows;

  /// 所有车辆(只读)
  List<VehicleState> get vehicles => List.unmodifiable(_vehicles);

  /// 步数
  int get moves => _moves;

  /// 耗时(秒)
  int get elapsedSeconds => _elapsedSeconds;

  /// 是否胜利
  bool get hasWon => _won;

  /// 是否失败
  bool get hasLost => _lost;

  /// 能否撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 剩余时间(限时有意义时)
  int? get timeLeft =>
      level.timeLimit != null ? level.timeLimit! - _elapsedSeconds : null;

  /// 剩余步数(限步时有意义时)
  int? get movesLeft =>
      level.movesLimit != null ? level.movesLimit! - _moves : null;

  /// 获取格子(只读)
  ParkingCell cellAt(int row, int col) => _grid[row][col];

  /// 获取某位置的车辆(无则返回 null)
  VehicleState? vehicleAt(int row, int col) {
    final idx = _grid[row][col].vehicleIndex;
    return idx != null ? _vehicles[idx] : null;
  }

  void _initGrid() {
    _grid = List.generate(
      level.rows,
      (r) => List.generate(level.cols, (c) => ParkingCell(type: level.grid[r][c])),
    );
  }

  void _initVehicles() {
    _vehicles = <VehicleState>[];
    for (var i = 0; i < level.vehicles.length; i++) {
      final v = level.vehicles[i];
      _vehicles.add(VehicleState(
        index: i,
        tier: v.tier,
        label: v.tier.icon,
        row: v.row,
        col: v.col,
        length: v.length,
        orientation: v.orientation,
      ));
      for (final (r, c) in _vehicles[i].cells) {
        _grid[r][c] = _grid[r][c].copyWith(vehicleIndex: i);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_won || _lost) return;
      _elapsedSeconds++;

      // 限步超时
      if (level.timeLimit != null && _elapsedSeconds >= level.timeLimit!) {
        _lost = true;
        _timer?.cancel();
      }
      notifyListeners();
    });
  }

  /// 计算车辆以 (row,col) 为 anchor 时占用的所有格子。
  static List<(int, int)> _cellsAt(
      VehicleState v, int row, int col) {
    final out = <(int, int)>[];
    for (var i = 0; i < v.length; i++) {
      out.add(v.orientation == ParkingOrientation.horizontal
          ? (row, col + i)
          : (row + i, col));
    }
    return out;
  }

  /// 在 (row,col) 处落子该车占用的所有格子。
  void _occupy(VehicleState v, int row, int col) {
    for (final (r, c) in _cellsAt(v, row, col)) {
      _grid[r][c] = _grid[r][c].copyWith(vehicleIndex: v.index);
    }
  }

  /// 清空 (row,col) 处该车占用的所有格子。
  void _vacate(VehicleState v, int row, int col) {
    for (final (r, c) in _cellsAt(v, row, col)) {
      _grid[r][c] = _grid[r][c].copyWith(clearVehicle: true);
    }
  }

  /// 能否将车辆移动到目标 anchor 格
  bool canMoveTo(int vehicleIndex, int toRow, int toCol) {
    if (_won || _lost) return false;
    final v = _vehicles[vehicleIndex];
    if (v.parked) return false;

    // 目标在棋盘内
    if (toRow < 0 ||
        toRow >= level.rows ||
        toCol < 0 ||
        toCol >= level.cols) {
      return false;
    }

    // teleport ability: can jump to any empty cell (ignoring slide direction rules)
    if (v.tier.stats.ability == SpecialAbility.teleport) {
      for (final (r, c) in _cellsAt(v, toRow, toCol)) {
        if (r < 0 || r >= level.rows || c < 0 || c >= level.cols) return false;
        final cell = _grid[r][c];
        if (!cell.isRoad && !cell.isParking) return false;
        if (cell.vehicleIndex != null && cell.vehicleIndex != vehicleIndex) return false;
        if (cell.isParking && v.tier != level.targetTier) return false;
      }
      return true;
    }

    // 必须沿直线滑动（单格车四向，长条车仅沿车身轴）。
    if (toRow != v.row && toCol != v.col) return false;
    if (v.length > 1) {
      if (v.orientation == ParkingOrientation.horizontal &&
          toRow != v.row) {
        return false;
      }
      if (v.orientation == ParkingOrientation.vertical &&
          toCol != v.col) {
        return false;
      }
    }

    // 目标车身占用的所有格子都必须合法（路面/停车位，且无其他车辆）。
    for (final (r, c) in _cellsAt(v, toRow, toCol)) {
      if (r < 0 || r >= level.rows || c < 0 || c >= level.cols) {
        return false;
      }
      final cell = _grid[r][c];
      if (!cell.isRoad && !cell.isParking) {
        // flyOver: can pass through obstacle cells
        if (v.tier.stats.ability == SpecialAbility.flyOver && cell.isObstacle) {
          continue;
        }
        // waterWalk/amphibious: can pass through water obstacles
        if ((v.tier.stats.ability == SpecialAbility.waterWalk ||
             v.tier.stats.ability == SpecialAbility.amphibious) && cell.isObstacle) {
          continue;
        }
        return false;
      }
      if (cell.vehicleIndex != null && cell.vehicleIndex != vehicleIndex) {
        return false;
      }
      // 只有目标等级的车才能进入停车位。
      if (cell.isParking && v.tier != level.targetTier) return false;
    }

    return true;
  }

  /// 移动车辆到目标 anchor 格
  bool moveVehicle(int vehicleIndex, int toRow, int toCol) {
    if (!canMoveTo(vehicleIndex, toRow, toCol)) return false;

    final v = _vehicles[vehicleIndex];
    _undoStack.add(ParkingAction(
      vehicleIndex: vehicleIndex,
      fromRow: v.row,
      fromCol: v.col,
      toRow: toRow,
      toCol: toCol,
    ));

    // 清空原占用（长条车可能占多格）
    _vacate(v, v.row, v.col);

    // 检查移动后是否停在停车位（车身任一格压住停车位即算停好）
    final parked = _cellsAt(v, toRow, toCol)
        .any((cell) => _grid[cell.$1][cell.$2].isParking);
    _vehicles[vehicleIndex] = v.copyWith(
      row: toRow,
      col: toCol,
      parked: parked,
    );

    // 设置新占用
    _occupy(_vehicles[vehicleIndex], toRow, toCol);

    _moves++;
    _checkWin();
    if (!_won) _checkLose();
    notifyListeners();
    return true;
  }

  /// 点击交互：把选中的车朝点击格方向滑动，停在能到达的最远位置（不越过点击格）。
  /// 长条车只能沿车身轴滑动；单格车四向。返回是否发生了移动。
  bool slideTo(int vehicleIndex, int tapRow, int tapCol) {
    if (_won || _lost) return false;
    final v = _vehicles[vehicleIndex];
    if (v.parked) return false;

    // turn ability: long-bar vehicles can slide in any direction
    final canTurn = v.tier.stats.ability == SpecialAbility.turn;

    if ((v._canHoriz || canTurn) && tapRow == v.row && tapCol != v.col) {
      final dir = tapCol > v.col ? 1 : -1;
      // 目标 anchor：让车头（dir>0 时为右端）对齐到点击列；dir<0 时左端对齐。
      final desired = (v.length > 1 && dir > 0)
          ? tapCol - (v.length - 1)
          : tapCol;
      var best = v.col;
      var c = v.col + dir;
      while (desired > v.col ? c <= desired : c >= desired) {
        if (!canMoveTo(vehicleIndex, v.row, c)) break;
        best = c;
        c += dir;
      }
      if (best == v.col) return false;
      return moveVehicle(vehicleIndex, v.row, best);
    } else if ((v._canVert || canTurn) && tapCol == v.col && tapRow != v.row) {
      final dir = tapRow > v.row ? 1 : -1;
      final desired = (v.length > 1 && dir > 0)
          ? tapRow - (v.length - 1)
          : tapRow;
      var best = v.row;
      var r = v.row + dir;
      while (desired > v.row ? r <= desired : r >= desired) {
        if (!canMoveTo(vehicleIndex, r, v.col)) break;
        best = r;
        r += dir;
      }
      if (best == v.row) return false;
      return moveVehicle(vehicleIndex, best, v.col);
    }
    return false;
  }

  void _checkWin() {
    // 胜利条件:目标等级的任意一辆车停在停车位
    final targetVehicle =
        _vehicles.where((v) => v.tier == level.targetTier).firstOrNull;
    if (targetVehicle != null && targetVehicle.parked) {
      _won = true;
      _timer?.cancel();
    }
  }

  /// 判负：限步关步数耗尽且未达成；或已无任何可移动的车辆（死局）。
  void _checkLose() {
    if (level.movesLimit != null &&
        _moves >= level.movesLimit! &&
        _targetVehicle != null &&
        !_targetVehicle!.parked) {
      _lost = true;
      _timer?.cancel();
      return;
    }
    if (!_hasAnyMove()) {
      _lost = true;
      _timer?.cancel();
    }
  }

  /// 是否还存在任意一次合法移动。
  bool _hasAnyMove() {
    for (final v in _vehicles) {
      if (v.parked) continue;
      // teleport: can jump to any cell, so always has a move if board has space
      if (v.tier.stats.ability == SpecialAbility.teleport) {
        for (var r = 0; r < level.rows; r++) {
          for (var c = 0; c < level.cols; c++) {
            if (canMoveTo(v.index, r, c)) return true;
          }
        }
        continue;
      }
      // turn ability: long-bar vehicles can slide in any direction
      final canTurn = v.tier.stats.ability == SpecialAbility.turn;
      final dirs = (v._canHoriz && v._canVert) || canTurn
          ? const [
              (0, 1),
              (0, -1),
              (1, 0),
              (-1, 0),
            ]
          : (v._canHoriz
              ? const [(0, 1), (0, -1)]
              : const [(1, 0), (-1, 0)]);
      for (final (dr, dc) in dirs) {
        if (_canMoveOneStep(v.index, dr, dc)) return true;
      }
    }
    return false;
  }

  /// 沿 (dr,dc) 方向找到的目标格是否存在合法移动。
  bool _canMoveOneStep(int vehicleIndex, int dr, int dc) {
    final v = _vehicles[vehicleIndex];
    final toR = v.row + dr;
    final toC = v.col + dc;
    if (toR < 0 || toR >= level.rows || toC < 0 || toC >= level.cols) {
      return false;
    }
    return canMoveTo(vehicleIndex, toR, toC);
  }

  VehicleState? get _targetVehicle =>
      _vehicles.where((v) => v.tier == level.targetTier).firstOrNull;

  /// 提示：基于当前棋盘实时状态求下一步建议（不消耗步数、不改状态）。
  /// 返回 [ParkingMove]，无解或已胜利/失败时返回 null。
  ParkingMove? hint() {
    if (_won || _lost) return null;

    // 用当前格子类型重建网格（type 在移动中不变，仅 vehicleIndex 变化）。
    final grid = List.generate(
      level.rows,
      (r) => List.generate(
        level.cols,
        (c) => _grid[r][c].type,
      ),
    );

    // 用当前车辆坐标重建生成信息（含长度/朝向，供求解器精确建模）。
    final vehicles = _vehicles
        .map((v) => VehicleSpawn(
              col: v.col,
              row: v.row,
              tier: v.tier,
              length: v.length,
              orientation: v.orientation,
            ))
        .toList();

    final snapshot = ParkingLevel(
      id: level.id,
      name: level.name,
      rows: level.rows,
      cols: level.cols,
      grid: grid,
      vehicles: vehicles,
      targetTier: level.targetTier,
    );

    final solution = ParkingSolver.solve(snapshot, maxStates: 40000);
    return solution?.firstOrNull;
  }

  /// 通关星级：步数越省、用时越短星级越高（胜利时调用）。
  int calcStars() {
    if (!_won) return 0;
    var stars = 1;
    if (level.movesLimit != null) {
      final ratio = _moves / level.movesLimit!;
      if (ratio <= 0.5) {
        stars = 3;
      } else if (ratio <= 0.75) {
        stars = 2;
      }
    } else if (level.timeLimit != null) {
      final ratio = _elapsedSeconds / level.timeLimit!;
      if (ratio <= 0.5) {
        stars = 3;
      } else if (ratio <= 0.75) {
        stars = 2;
      }
    } else {
      // 无限关：6 步内三星、10 步内两星
      if (_moves <= 6) {
        stars = 3;
      } else if (_moves <= 10) {
        stars = 2;
      }
    }
    return stars;
  }

  /// 撤销上一步
  void undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();

    final v = _vehicles[action.vehicleIndex];

    // 清空移动后的占用，恢复原位占用（长条车占多格）。
    _vacate(v, v.row, v.col);
    _vehicles[action.vehicleIndex] = v.copyWith(
      row: action.fromRow,
      col: action.fromCol,
      parked: false,
    );
    _occupy(_vehicles[action.vehicleIndex], action.fromRow, action.fromCol);

    _moves--;
    _won = false; // 撤销后重新检查胜利
    _lost = false; // 撤销后解除死局/限步判负
    notifyListeners();
  }

  /// 重置关卡
  void reset() {
    _timer?.cancel();
    _undoStack.clear();
    _moves = 0;
    _elapsedSeconds = 0;
    _won = false;
    _lost = false;
    _initGrid();
    _initVehicles();
    _startTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

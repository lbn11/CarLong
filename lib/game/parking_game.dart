import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/parking_solver.dart';
import '../models/car.dart';
import '../models/parking_level.dart';

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
  final CarTier tier;
  final String label;
  int row;
  int col;
  bool parked; // 是否已停在停车位

  VehicleState({
    required this.index,
    required this.tier,
    required this.label,
    required this.row,
    required this.col,
    this.parked = false,
  });

  VehicleState copyWith({int? row, int? col, bool? parked}) {
    return VehicleState(
      index: index,
      tier: tier,
      label: label,
      row: row ?? this.row,
      col: col ?? this.col,
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
      ));
      _grid[v.row][v.col] =
          _grid[v.row][v.col].copyWith(vehicleIndex: i);
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

  /// 能否将车辆移动到目标格
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

    // 目标格必须可通行(路面或停车位)且无其他车辆
    final dest = _grid[toRow][toCol];
    if (!dest.isPassable) return false;

    // 只有目标等级的车才能停进停车位；其余车只能停在路面。
    if (dest.isParking && v.tier != level.targetTier) return false;

    // 只能沿直线移动(滑块风格)
    if (toRow != v.row && toCol != v.col) return false;

    // 检查路径上是否有障碍
    if (toRow == v.row) {
      // 横向
      final step = toCol > v.col ? 1 : -1;
      for (var c = v.col + step; c != toCol + step; c += step) {
        if (_grid[toRow][c].vehicleIndex != null || _grid[toRow][c].isObstacle) {
          return false;
        }
      }
    } else {
      // 纵向
      final step = toRow > v.row ? 1 : -1;
      for (var r = v.row + step; r != toRow + step; r += step) {
        if (_grid[r][toCol].vehicleIndex != null || _grid[r][toCol].isObstacle) {
          return false;
        }
      }
    }

    return true;
  }

  /// 移动车辆到目标格
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

    // 清空原格
    _grid[v.row][v.col] = _grid[v.row][v.col].copyWith(clearVehicle: true);

    // 检查是否停在停车位
    final isParking = _grid[toRow][toCol].isParking;
    _vehicles[vehicleIndex] = v.copyWith(
      row: toRow,
      col: toCol,
      parked: isParking,
    );

    // 设置新格
    _grid[toRow][toCol] = _grid[toRow][toCol].copyWith(vehicleIndex: vehicleIndex);

    _moves++;
    _checkWin();
    if (!_won) _checkLose();
    notifyListeners();
    return true;
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
      // 四个方向各走一步即可，路径合法性交给 canMoveTo。
      for (final (dr, dc) in const [
        (0, 1),
        (0, -1),
        (1, 0),
        (-1, 0),
      ]) {
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

    // 用当前车辆坐标重建生成信息。
    final vehicles = _vehicles
        .map((v) => VehicleSpawn(col: v.col, row: v.row, tier: v.tier))
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

    // 移回原位
    _grid[v.row][v.col] = _grid[v.row][v.col].copyWith(clearVehicle: true);
    _vehicles[action.vehicleIndex] = v.copyWith(
      row: action.fromRow,
      col: action.fromCol,
      parked: false,
    );
    _grid[action.fromRow][action.fromCol] =
        _grid[action.fromRow][action.fromCol].copyWith(vehicleIndex: action.vehicleIndex);

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

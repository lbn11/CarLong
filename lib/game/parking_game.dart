import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/car.dart';
import '../models/parking_level.dart';

/// 棋盘格子状态
class ParkingCell {
  final ParkingCellType type;
  final int? vehicleIndex; // 占用该格的车辆索引(-1 表示无)

  const ParkingCell({required this.type, this.vehicleIndex});

  ParkingCell copyWith({ParkingCellType? type, int? vehicleIndex}) {
    return ParkingCell(
      type: type ?? this.type,
      vehicleIndex: vehicleIndex ?? this.vehicleIndex,
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
    _grid[v.row][v.col] = _grid[v.row][v.col].copyWith(vehicleIndex: null);

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

  /// 撤销上一步
  void undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();

    final v = _vehicles[action.vehicleIndex];

    // 移回原位
    _grid[v.row][v.col] = _grid[v.row][v.col].copyWith(vehicleIndex: null);
    _vehicles[action.vehicleIndex] = v.copyWith(
      row: action.fromRow,
      col: action.fromCol,
      parked: false,
    );
    _grid[action.fromRow][action.fromCol] =
        _grid[action.fromRow][action.fromCol].copyWith(vehicleIndex: action.vehicleIndex);

    _moves--;
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

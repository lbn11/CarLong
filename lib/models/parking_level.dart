import '../models/car.dart';

/// 停车模式格子类型
enum ParkingCellType {
  road, // 可行车
  parking, // 可停车(终点)
  obstacle, // 障碍(石墩 / 水坑)
  entrance, // 入口(车从这里出现)
  exit, // 出口(车从这里离开)
}

/// 停车模式障碍类型
enum ParkingObstacleType {
  none,
  block, // 石墩(永久障碍)
  puddle, // 水坑(可融化)
}

/// 车辆朝向：决定长条车能滑动的轴（Rush Hour 风格）。
enum ParkingOrientation {
  horizontal, // 横向（占同一行的若干列）
  vertical, // 纵向（占同一列的若干行）
}

/// 初始车辆放置
class VehicleSpawn {
  final int col;
  final int row;
  final CarTier tier;
  final int count;

  /// 占用格数（1 = 单格车；>=2 = 长条车，沿 [orientation] 延伸）。
  final int length;

  /// 朝向：仅当 [length] > 1 时约束滑动轴；length == 1 时四向均可滑动。
  final ParkingOrientation orientation;

  const VehicleSpawn({
    required this.col,
    required this.row,
    required this.tier,
    this.count = 1,
    this.length = 1,
    this.orientation = ParkingOrientation.horizontal,
  });

  /// 该车辆占用的所有格子（以 anchor 为左上角）。
  List<(int, int)> cells() {
    final out = <(int, int)>[];
    for (var i = 0; i < length; i++) {
      out.add(orientation == ParkingOrientation.horizontal
          ? (row, col + i)
          : (row + i, col));
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'col': col,
        'row': row,
        'tier': tier.index,
        'count': count,
        'length': length,
        'orientation': orientation.index,
      };

  factory VehicleSpawn.fromJson(Map<String, dynamic> json) => VehicleSpawn(
        col: json['col'] as int,
        row: json['row'] as int,
        tier: CarTier.fromIndex(json['tier'] as int),
        count: json['count'] as int? ?? 1,
        length: json['length'] as int? ?? 1,
        orientation: ParkingOrientation
            .values[(json['orientation'] as int?) ?? 0],
      );
}

/// 停车关卡定义
class ParkingLevel {
  final int id;
  final String name;
  final int rows;
  final int cols;
  final List<List<ParkingCellType>> grid;
  final List<VehicleSpawn> vehicles;
  final CarTier targetTier;
  final int? timeLimit;
  final int? movesLimit;
  final int? minMoves; // 求解器算出的最短步数（标定难度用，无解为 null）

  const ParkingLevel({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.vehicles,
    required this.targetTier,
    this.timeLimit,
    this.movesLimit,
    this.minMoves,
  });

  ParkingLevel copyWith({
    int? id,
    String? name,
    int? rows,
    int? cols,
    List<List<ParkingCellType>>? grid,
    List<VehicleSpawn>? vehicles,
    CarTier? targetTier,
    int? timeLimit,
    int? movesLimit,
    int? minMoves,
  }) {
    return ParkingLevel(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      grid: grid ?? this.grid,
      vehicles: vehicles ?? this.vehicles,
      targetTier: targetTier ?? this.targetTier,
      timeLimit: timeLimit ?? this.timeLimit,
      movesLimit: movesLimit ?? this.movesLimit,
      minMoves: minMoves ?? this.minMoves,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rows': rows,
        'cols': cols,
        'grid': grid
            .map((row) => row.map((c) => c.index).toList())
            .toList(),
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
        'targetTier': targetTier.index,
        'timeLimit': timeLimit,
        'movesLimit': movesLimit,
        'minMoves': minMoves,
      };

  factory ParkingLevel.fromJson(Map<String, dynamic> json) => ParkingLevel(
        id: json['id'] as int,
        name: json['name'] as String,
        rows: json['rows'] as int,
        cols: json['cols'] as int,
        grid: (json['grid'] as List)
            .map((row) => (row as List)
                .map((c) => ParkingCellType.values[c as int])
                .toList())
            .toList(),
        vehicles: (json['vehicles'] as List)
            .map((v) => VehicleSpawn.fromJson(v as Map<String, dynamic>))
            .toList(),
        targetTier: CarTier.fromIndex(json['targetTier'] as int),
        timeLimit: json['timeLimit'] as int?,
        movesLimit: json['movesLimit'] as int?,
        minMoves: json['minMoves'] as int?,
      );
}

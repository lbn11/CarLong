import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/logic/parking_solver.dart';
import 'package:merge_fleet/models/parking_level.dart';
import 'package:merge_fleet/services/parking_generator.dart';

/// 辅助：构造棋盘
List<List<ParkingCellType>> _grid(int size, Map<(int, int), ParkingCellType> special) {
  final g = List.generate(size, (_) => List.filled(size, ParkingCellType.road));
  special.forEach((k, v) => g[k.$1][k.$2] = v);
  return g;
}

void main() {
  group('ParkingSolver', () {
    test('一步到位：目标车与停车位同行、路径空', () {
      final lvl = ParkingLevel(
        id: 1,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4, {(3, 3): ParkingCellType.parking}),
        vehicles: [
          VehicleSpawn(col: 0, row: 3, tier: VehicleType.sedan),
        ],
        targetTier: VehicleType.sedan,
      );
      expect(ParkingSolver.minMoves(lvl), 1);
    });

    test('需要纵移再横移：目标车与停车位不同行不同列（畅通）', () {
      final lvl = ParkingLevel(
        id: 2,
        name: 't',
        rows: 5,
        cols: 5,
        grid: _grid(5, {(4, 3): ParkingCellType.parking}),
        vehicles: [
          // 目标车在 (row1,col1)；停车位在 (row4,col3)。
          // 一步 = 沿直线滑到任意可达终点：先纵移到 (4,1)，再横移到 (4,3) => 2 步。
          VehicleSpawn(col: 1, row: 1, tier: VehicleType.sedan),
        ],
        targetTier: VehicleType.sedan,
      );
      expect(ParkingSolver.minMoves(lvl), 2);
    });

    test('挡路车需要让位：最优解步数 > 1', () {
      final lvl = ParkingLevel(
        id: 3,
        rows: 5,
        cols: 5,
        name: 't',
        grid: _grid(5, {(4, 3): ParkingCellType.parking}),
        vehicles: [
          VehicleSpawn(col: 0, row: 4, tier: VehicleType.sedan), // 目标车在停车行左端
          VehicleSpawn(col: 2, row: 4, tier: VehicleType.bicycle), // 挡在去停车位的路上
        ],
        targetTier: VehicleType.sedan,
      );
      final moves = ParkingSolver.minMoves(lvl);
      expect(moves, greaterThan(1));
    });

    test('停车位被障碍封死（邻接格皆障）则无解', () {
      // 停车位 (3,3) 只能从 (2,3) 上或 (3,2) 左进入；两格皆障碍 => 目标车永远进不去。
      final lvl = ParkingLevel(
        id: 4,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4, {
          (3, 3): ParkingCellType.parking,
          (2, 3): ParkingCellType.obstacle,
          (3, 2): ParkingCellType.obstacle,
        }),
        vehicles: [
          VehicleSpawn(col: 0, row: 0, tier: VehicleType.sedan),
        ],
        targetTier: VehicleType.sedan,
      );
      expect(ParkingSolver.solve(lvl), isNull);
    });

    test('起步即胜利返回 0 步', () {
      final lvl = ParkingLevel(
        id: 5,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4, {(3, 3): ParkingCellType.parking}),
        vehicles: [
          VehicleSpawn(col: 3, row: 3, tier: VehicleType.sedan),
        ],
        targetTier: VehicleType.sedan,
      );
      expect(ParkingSolver.minMoves(lvl), 0);
    });

    test('无障碍、目标车同列直滑到停车位', () {
      final lvl = ParkingLevel(
        id: 6,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4, {(3, 3): ParkingCellType.parking}),
        vehicles: [
          // 目标车在 (row0,col3)，停车位同列 => 一次竖直滑动直达。
          VehicleSpawn(col: 3, row: 0, tier: VehicleType.sedan),
        ],
        targetTier: VehicleType.sedan,
      );
      expect(ParkingSolver.minMoves(lvl), 1);
    });
  });

  group('ParkingLevelGenerator', () {
    test('前 100 关全部可解且 minMoves 非空', () {
      for (var id = 1; id <= 100; id++) {
        final lvl = ParkingLevelGenerator.generateOne(id);
        expect(lvl.minMoves, isNotNull, reason: 'id=$id 应可解');
      }
    });

    test('较大棋盘(>=5)关卡最优解至少 3 步（有解谜感）', () {
      for (var id = 60; id <= 99; id++) {
        final lvl = ParkingLevelGenerator.generateOne(id);
        expect(lvl.minMoves!, greaterThanOrEqualTo(3), reason: 'id=$id');
      }
    });

    test('movesLimit 给足余量（最优解可拿三星）', () {
      for (var id = 1; id <= 120; id += 7) {
        final lvl = ParkingLevelGenerator.generateOne(id);
        expect(lvl.movesLimit, greaterThanOrEqualTo(lvl.minMoves!));
      }
    });

    test('生成确定性：同一 id 多次结果一致', () {
      final a = ParkingLevelGenerator.generateOne(73);
      final b = ParkingLevelGenerator.generateOne(73);
      expect(a.minMoves, b.minMoves);
      expect(a.vehicles.length, b.vehicles.length);
    });

    test('生成性能：200 关在合理时间内', () {
      final sw = Stopwatch()..start();
      ParkingLevelGenerator.generate(count: 200);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}

import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/parking_game.dart';
import 'package:merge_fleet/logic/parking_solver.dart';
import 'package:merge_fleet/models/parking_level.dart';
import 'package:merge_fleet/services/parking_generator.dart';

/// 构建一个 size×size 的全 road 网格，停车位放在 (size-1, size-2)。
List<List<ParkingCellType>> _grid(int size, {int? parkRow, int? parkCol}) {
  final g = List.generate(
    size,
    (_) => List.filled(size, ParkingCellType.road),
  );
  g[parkRow ?? size - 1][parkCol ?? size - 2] = ParkingCellType.parking;
  return g;
}

void main() {
  group('长条车移动规则', () {
    test('横向长车只能横向滑动，不能纵向', () {
      final level = ParkingLevel(
        id: 1,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 0,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      // 向右滑到 anchor col2（占 (0,2),(0,3)）。
      expect(g.canMoveTo(0, 0, 2), isTrue);
      // 不能纵向移动（长车锁轴）。
      expect(g.canMoveTo(0, 1, 0), isFalse);
      expect(g.canMoveTo(0, 2, 0), isFalse);
      // 越界：anchor col3 会让第二格出界。
      expect(g.canMoveTo(0, 0, 3), isFalse);
    });

    test('纵向长车只能纵向滑动', () {
      final level = ParkingLevel(
        id: 2,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 0,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.vertical,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      expect(g.canMoveTo(0, 2, 0), isTrue); // 向下
      expect(g.canMoveTo(0, 0, 1), isFalse); // 横向不允许
    });

    test('长车移动占满多格，undo 完整还原', () {
      final level = ParkingLevel(
        id: 3,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 0,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      expect(g.cellAt(0, 0).vehicleIndex, 0);
      expect(g.cellAt(0, 1).vehicleIndex, 0);
      expect(g.cellAt(0, 2).vehicleIndex, isNull);

      expect(g.moveVehicle(0, 0, 2), isTrue); // 滑到 (0,2),(0,3)
      expect(g.cellAt(0, 0).vehicleIndex, isNull);
      expect(g.cellAt(0, 1).vehicleIndex, isNull);
      expect(g.cellAt(0, 2).vehicleIndex, 0);
      expect(g.cellAt(0, 3).vehicleIndex, 0);

      g.undo();
      expect(g.cellAt(0, 0).vehicleIndex, 0);
      expect(g.cellAt(0, 1).vehicleIndex, 0);
      expect(g.cellAt(0, 2).vehicleIndex, isNull);
      expect(g.moves, 0);
    });

    test('长车被其他车挡住路径则不可移动越界', () {
      final level = ParkingLevel(
        id: 4,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 0,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
          VehicleSpawn(col: 3, row: 0, tier: VehicleType.bicycle), // 挡在 (0,3)
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      // 滑到 anchor col2（(0,2),(0,3)）会被 bike 挡住。
      expect(g.canMoveTo(0, 0, 2), isFalse);
      // 滑到 anchor col1（(0,1),(0,2)）空闲，可移动。
      expect(g.canMoveTo(0, 0, 1), isTrue);
    });

    test('非目标长车不能进入停车位', () {
      final level = ParkingLevel(
        id: 5,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          // bike 在 (3,0),(3,1)，不压停车位 (3,2)。
          VehicleSpawn(
            col: 0,
            row: 3,
            tier: VehicleType.bicycle,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
          VehicleSpawn(col: 0, row: 0, tier: VehicleType.sedan),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      // bike 滑到 anchor2 (3,2),(3,3) 会压住停车位且非目标 => 不可。
      expect(g.canMoveTo(0, 3, 2), isFalse);
    });

    test('长目标车滑入停车位判胜（边界对齐）', () {
      final level = ParkingLevel(
        id: 6,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          // 目标车在 (3,0),(3,1)，停车位 (3,2)。
          VehicleSpawn(
            col: 0,
            row: 3,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      expect(g.hasWon, isFalse);
      expect(g.moveVehicle(0, 3, 1), isTrue); // anchor1 -> (3,1),(3,2) 压住车位
      expect(g.hasWon, isTrue);
    });

    test('长目标车滑入停车位判胜', () {
      final level = ParkingLevel(
        id: 7,
        name: 't',
        rows: 5,
        cols: 5,
        grid: _grid(5),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 4,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level); // 占 (4,0),(4,1)，停车位 (4,3)
      expect(g.moveVehicle(0, 4, 2), isTrue); // 滑到 (4,2),(4,3) 压住车位
      expect(g.hasWon, isTrue);
    });
  });

  group('slideTo 点击交互', () {
    test('点击右侧：长车沿方向滑到最远可达处（含滑入车位获胜）', () {
      final level = ParkingLevel(
        id: 8,
        name: 't',
        rows: 5,
        cols: 5,
        grid: _grid(5),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 4,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      // 点击 (4,3)（右侧空格），车应滑到 anchor2 覆盖车位并获胜。
      expect(g.slideTo(0, 4, 3), isTrue);
      expect(g.hasWon, isTrue);
    });

    test('单格车 slideTo 等效移动到点击格', () {
      final level = ParkingLevel(
        id: 9,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          VehicleSpawn(col: 0, row: 0, tier: VehicleType.sedan),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      expect(g.slideTo(0, 0, 3), isTrue); // 横移到 col3
      expect(g.vehicles[0].col, 3);
      expect(g.slideTo(0, 3, 3), isTrue); // 纵移到 row3（停车位所在行）
      expect(g.vehicles[0].row, 3);
      expect(g.slideTo(0, 3, 2), isTrue); // 再横移到 col2（停车位），判胜
      expect(g.hasWon, isTrue);
    });

    test('长车点击纵向方向无效（锁轴）', () {
      final level = ParkingLevel(
        id: 10,
        name: 't',
        rows: 4,
        cols: 4,
        grid: _grid(4),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 0,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      expect(g.slideTo(0, 3, 0), isFalse); // 横向车不能纵向滑
    });
  });

  group('求解器支持长条车', () {
    test('长目标车 + 竖挡块：最少 2 步（先挪挡块再滑入）', () {
      final level = ParkingLevel(
        id: 11,
        name: 't',
        rows: 5,
        cols: 5,
        grid: _grid(5),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 4,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
          VehicleSpawn(
            col: 2,
            row: 3,
            tier: VehicleType.bicycle,
            length: 2,
            orientation: ParkingOrientation.vertical,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      // 挡块占 (3,2),(4,2) 堵住底部行车道；必须先上移挡块，目标才能滑入 (4,3)。
      final moves = ParkingSolver.minMoves(level);
      expect(moves, 2);
    });

    test('无障碍长目标车：一步滑入', () {
      final level = ParkingLevel(
        id: 12,
        name: 't',
        rows: 5,
        cols: 5,
        grid: _grid(5),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 4,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      expect(ParkingSolver.minMoves(level), 1);
    });

    test('hint 返回真实第一步且不改变棋盘', () {
      final level = ParkingLevel(
        id: 13,
        name: 't',
        rows: 5,
        cols: 5,
        grid: _grid(5),
        vehicles: [
          VehicleSpawn(
            col: 0,
            row: 4,
            tier: VehicleType.sedan,
            length: 2,
            orientation: ParkingOrientation.horizontal,
          ),
          VehicleSpawn(
            col: 2,
            row: 3,
            tier: VehicleType.bicycle,
            length: 2,
            orientation: ParkingOrientation.vertical,
          ),
        ],
        targetTier: VehicleType.sedan,
      );
      final g = ParkingGame(level);
      final before = g.vehicles.map((v) => (v.row, v.col)).toList();
      final h = g.hint();
      expect(h, isNotNull);
      // hint 不应改变棋盘状态 / 步数。
      final after = g.vehicles.map((v) => (v.row, v.col)).toList();
      expect(after, before);
      expect(g.moves, 0);
      expect(g.hasWon, isFalse);
    });
  });

  group('生成器产出长条车且可解', () {
    test('size>=5 关卡含长条车且可解', () {
      // id>=50 进入 5x5 及以上，应含长条车。
      for (final id in [60, 100, 200, 500]) {
        final lvl = ParkingLevelGenerator.generateOne(id);
        final longCount = lvl.vehicles.where((v) => v.length > 1).length;
        expect(longCount, greaterThan(0),
            reason: 'id=$id 应含长条车');
        expect(ParkingSolver.minMoves(lvl, maxStates: 40000), isNotNull,
            reason: 'id=$id 应可解');
        expect(lvl.minMoves, isNotNull);
        expect(lvl.minMoves!, greaterThanOrEqualTo(2));
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/game/parking_game.dart';
import 'package:merge_fleet/models/car.dart';
import 'package:merge_fleet/models/parking_level.dart';

/// 最小停车关卡（4x4）：
///  入口 (0,0)，停车位 🟢 (3,3)。
///  目标车 car 在 (0,3)（左下角，与停车位同行，可直线滑入）。
///  挡路车 bike 在 (1,3)（与目标同处第 3 行，正好挡住去路，需要先挪开）。
ParkingLevel _miniLevel({int? movesLimit, int? timeLimit}) {
  final grid = List.generate(
    4,
    (_) => List.filled(4, ParkingCellType.road),
  );
  grid[0][0] = ParkingCellType.entrance;
  grid[3][3] = ParkingCellType.parking;
  return ParkingLevel(
    id: 1,
    name: 't',
    rows: 4,
    cols: 4,
    grid: grid,
    vehicles: [
      VehicleSpawn(col: 0, row: 3, tier: CarTier.car, count: 1),
      VehicleSpawn(col: 1, row: 3, tier: CarTier.bike, count: 1),
    ],
    targetTier: CarTier.car,
    movesLimit: movesLimit,
    timeLimit: timeLimit,
  );
}

/// 把 bike 从 (1,3) 让路到 (1,2)（纵向一格），不再挡住 car 第 3 行去路。
void _moveBikeAside(ParkingGame game) {
  final filler = game.vehicles.firstWhere((v) => v.tier == CarTier.bike);
  expect(game.canMoveTo(filler.index, 2, 1), isTrue,
      reason: 'bike 应能纵向让路到 (1,2)');
  game.moveVehicle(filler.index, 2, 1);
}

void main() {
  group('ParkingGame 单元', () {
    test('目标车可以停进停车位并判胜', () {
      final game = ParkingGame(_miniLevel());
      final target =
          game.vehicles.firstWhere((v) => v.tier == CarTier.car);
      _moveBikeAside(game);
      // car 从 (0,3) 直线滑到停车位 (3,3)。
      expect(game.canMoveTo(target.index, 3, 3), isTrue);
      game.moveVehicle(target.index, 3, 3);
      expect(game.hasWon, isTrue);
      expect(game.calcStars(), inInclusiveRange(1, 3));
    });

    test('非目标车不能占用停车位', () {
      final game = ParkingGame(_miniLevel());
      final filler =
          game.vehicles.firstWhere((v) => v.tier == CarTier.bike);
      // bike 与目标同处第 3 行，可路径直达停车位，但等级不符应被拒绝。
      expect(game.canMoveTo(filler.index, 3, 3), isFalse);
    });

    test('限步关卡：步数耗尽且未胜利则判负', () {
      final game = ParkingGame(_miniLevel(movesLimit: 1));
      _moveBikeAside(game);
      // 消耗掉唯一一步且目标未停好 => 判负。
      expect(game.hasLost, isTrue);
    });

    test('撤销可解除判负状态', () {
      final game = ParkingGame(_miniLevel(movesLimit: 1));
      _moveBikeAside(game);
      expect(game.hasLost, isTrue);
      game.undo();
      expect(game.hasLost, isFalse);
      expect(game.moves, 0);
    });

    test('直线移动：不能直接斜向移动', () {
      final game = ParkingGame(_miniLevel());
      final target =
          game.vehicles.firstWhere((v) => v.tier == CarTier.car);
      // 从 (0,3) 斜向到 (1,2) 不合法（非直线）。
      expect(game.canMoveTo(target.index, 1, 2), isFalse);
    });

    test('星级：无限关卡 2 步通关拿三星', () {
      final game = ParkingGame(_miniLevel());
      _moveBikeAside(game);
      final target =
          game.vehicles.firstWhere((v) => v.tier == CarTier.car);
      game.moveVehicle(target.index, 3, 3);
      expect(game.hasWon, isTrue);
      expect(game.moves, 2);
      expect(game.calcStars(), 3);
    });
  });
}

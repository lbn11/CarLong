import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/game/parking_game.dart';
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
      VehicleSpawn(col: 0, row: 3, tier: VehicleType.sedan, count: 1),
      VehicleSpawn(col: 1, row: 3, tier: VehicleType.bicycle, count: 1),
    ],
    targetTier: VehicleType.sedan,
    movesLimit: movesLimit,
    timeLimit: timeLimit,
  );
}

/// 把 bike 从 (1,3) 让路到 (1,2)（纵向一格），不再挡住 car 第 3 行去路。
void _moveBikeAside(ParkingGame game) {
  final filler = game.vehicles.firstWhere((v) => v.tier == VehicleType.bicycle);
  expect(game.canMoveTo(filler.index, 2, 1), isTrue,
      reason: 'bike 应能纵向让路到 (1,2)');
  game.moveVehicle(filler.index, 2, 1);
}

void main() {
  group('ParkingGame 单元', () {
    test('目标车可以停进停车位并判胜', () {
      final game = ParkingGame(_miniLevel());
      final target =
          game.vehicles.firstWhere((v) => v.tier == VehicleType.sedan);
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
          game.vehicles.firstWhere((v) => v.tier == VehicleType.bicycle);
      // bike 与目标同处第 3 行，可路径直达停车位，但等级不符应被拒绝。
      expect(game.canMoveTo(filler.index, 3, 3), isFalse);
    });

    test('限步关卡：步数耗尽扣命，生命耗尽才判负', () {
      final game = ParkingGame(_miniLevel(movesLimit: 1));
      // 每次耗尽步数扣一条命；三条命全部耗光才判负。
      for (var i = 1; i <= ParkingGame.maxLives; i++) {
        _moveBikeAside(game);
        expect(game.lives, ParkingGame.maxLives - i);
        expect(game.hasLost, i == ParkingGame.maxLives);
        if (!game.hasLost) game.undo();
      }
      expect(game.isLivesDepleted, isTrue);
    });

    test('撤销可解除判负状态', () {
      final game = ParkingGame(_miniLevel(movesLimit: 1));
      // 耗光三条命进入判负。
      for (var i = 1; i < ParkingGame.maxLives; i++) {
        _moveBikeAside(game);
        game.undo();
      }
      _moveBikeAside(game);
      expect(game.hasLost, isTrue);
      game.undo();
      expect(game.hasLost, isFalse);
      expect(game.moves, 0);
    });

    test('直线移动：不能直接斜向移动', () {
      final game = ParkingGame(_miniLevel());
      final target =
          game.vehicles.firstWhere((v) => v.tier == VehicleType.sedan);
      // 从 (0,3) 斜向到 (1,2) 不合法（非直线）。
      expect(game.canMoveTo(target.index, 1, 2), isFalse);
    });

    test('星级：无限关卡 2 步通关拿三星', () {
      final game = ParkingGame(_miniLevel());
      _moveBikeAside(game);
      final target =
          game.vehicles.firstWhere((v) => v.tier == VehicleType.sedan);
      game.moveVehicle(target.index, 3, 3);
      expect(game.hasWon, isTrue);
      expect(game.moves, 2);
      expect(game.calcStars(), 3);
    });

    test('hint：返回最优解首步且不改变棋盘状态', () {
      final game = ParkingGame(_miniLevel());
      final hint = game.hint();
      // 初始 bike 挡住 car，首步应建议移动 bike 让路。
      expect(hint, isNotNull);
      final filler =
          game.vehicles.firstWhere((v) => v.tier == VehicleType.bicycle);
      expect(hint!.vehicleIndex, filler.index);
      // hint 不应消耗步数、不应改变 hasWon。
      expect(game.moves, 0);
      expect(game.hasWon, isFalse);
      // 按 hint 执行后，car 应能继续推进（仍可求下一步）。
      game.moveVehicle(hint.vehicleIndex, hint.toRow, hint.toCol);
      final next = game.hint();
      expect(next, isNotNull);
    });

    test('hint：已胜利时返回 null', () {
      final game = ParkingGame(_miniLevel());
      _moveBikeAside(game);
      final target =
          game.vehicles.firstWhere((v) => v.tier == VehicleType.sedan);
      game.moveVehicle(target.index, 3, 3);
      expect(game.hasWon, isTrue);
      expect(game.hint(), isNull);
    });
  });
}

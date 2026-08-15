import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/car.dart';
import 'package:merge_fleet/models/level.dart';

void main() {
  test('万能卡与任意卡片合并', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 4,
      rows: 4,
      stockSize: 10,
      goalType: GoalType.produce,
      targetTier: CarTier.car,
      targetCount: 1,
    );
    final b = BoardLogic(level, random: Random(1));
    b.placeAt(0, 0, StackData(CarTier.bike, isWildcard: true));
    b.placeAt(1, 0, StackData(CarTier.car));
    final r = b.move(0, 0, 1, 0);
    expect(r.valid, true);
    final dst = b.at(1, 0);
    expect(dst, isNotNull);
    expect(dst!.count, 2);
    expect(dst.tier, CarTier.car);
    expect(dst.isWildcard, false);
    // 源格清空
    expect(b.at(0, 0), isNull);
  });

  test('普通卡移到万能卡上会先变级再合并', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 4,
      rows: 4,
      stockSize: 10,
      goalType: GoalType.produce,
      targetTier: CarTier.taxi,
      targetCount: 1,
    );
    final b = BoardLogic(level, random: Random(2));
    b.placeAt(0, 0, StackData(CarTier.bike));
    b.placeAt(1, 0, StackData(CarTier.car, isWildcard: true));
    final r = b.move(0, 0, 1, 0);
    expect(r.valid, true);
    final dst = b.at(1, 0);
    expect(dst, isNotNull);
    expect(dst!.tier, CarTier.bike);
    expect(dst.count, 2);
    expect(dst.isWildcard, false);
  });

  test('炸弹集满 3 引爆清空 3x3', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 4,
      rows: 4,
      stockSize: 10,
      goalType: GoalType.clearBoard,
      targetTier: null,
      targetCount: 1,
    );
    final b = BoardLogic(level, random: Random(3));
    b.placeAt(1, 1, StackData(CarTier.bike, isBomb: true));
    b.placeAt(2, 1, StackData(CarTier.bike, isBomb: true, count: 2));
    b.placeAt(0, 0, StackData(CarTier.car));
    b.placeAt(3, 3, StackData(CarTier.taxi));
    final r = b.move(1, 1, 2, 1);
    expect(r.detonated, true);
    expect(r.detonatedAt, (col: 2, row: 1));
    // 3x3 内卡片全清
    for (var c = 1; c <= 3; c++) {
      for (var rr = 0; rr <= 2; rr++) {
        expect(b.at(c, rr), isNull, reason: '($c,$rr) 应被炸掉');
      }
    }
    // 远处的不受影响
    expect(b.at(3, 3), isNotNull);
  });

  test('炸弹与普通卡交换', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 4,
      rows: 4,
      stockSize: 10,
      goalType: GoalType.clearBoard,
      targetTier: null,
      targetCount: 1,
    );
    final b = BoardLogic(level, random: Random(4));
    b.placeAt(0, 0, StackData(CarTier.bike, isBomb: true));
    b.placeAt(1, 1, StackData(CarTier.taxi));
    final r = b.move(0, 0, 1, 1);
    expect(r.valid, true);
    expect(r.detonated, false);
    expect(b.at(1, 1)!.isBomb, true);
    expect(b.at(0, 0)!.tier, CarTier.taxi);
  });

  test('传送门改道到配对格', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 5,
      rows: 5,
      stockSize: 10,
      goalType: GoalType.produce,
      targetTier: CarTier.car,
      targetCount: 1,
      obstacles: [
        ObstacleSpec(ObstacleType.teleport, 1, 1),
        ObstacleSpec(ObstacleType.teleport, 3, 3),
      ],
    );
    final b = BoardLogic(level, random: Random(5));
    b.placeAt(1, 2, StackData(CarTier.bike));
    final r = b.move(1, 2, 1, 1);
    expect(r.valid, true);
    expect(r.teleported, true);
    // 卡片出现在出口 (3,3)
    expect(b.at(3, 3), isNotNull);
    expect(b.at(3, 3)!.tier, CarTier.bike);
    // 传送门格不可停靠
    expect(b.at(1, 1), isNull);
  });

  test('迷雾揭开：落子 revealNear 揭开周围', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 5,
      rows: 5,
      stockSize: 10,
      goalType: GoalType.produce,
      targetTier: CarTier.car,
      targetCount: 1,
      fogCells: 5,
    );
    final b = BoardLogic(level, random: Random(6));
    var fogged = 0;
    for (var c = 0; c < 5; c++) {
      for (var r = 0; r < 5; r++) {
        if (b.isFogged(c, r)) fogged++;
      }
    }
    expect(fogged, 5);
    // 找一个雾格，在其相邻放置并揭开
    int? fc, fr;
    outer:
    for (var c = 0; c < 5; c++) {
      for (var r = 0; r < 5; r++) {
        if (b.isFogged(c, r)) {
          fc = c;
          fr = r;
          break outer;
        }
      }
    }
    b.revealNear(fc!, fr!);
    expect(b.isFogged(fc, fr), false);
    // 四邻也揭开
    for (final (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = fc + dc, nr = fr + dr;
      if (nc >= 0 && nc < 5 && nr >= 0 && nr < 5) {
        expect(b.isFogged(nc, nr), false);
      }
    }
  });

  test('快照恢复包含迷雾', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 5,
      rows: 5,
      stockSize: 10,
      goalType: GoalType.produce,
      targetTier: CarTier.car,
      targetCount: 1,
      fogCells: 4,
    );
    final b = BoardLogic(level, random: Random(7));
    final snap = b.snapshot();
    b.revealNear(0, 0);
    b.restore(snap);
    var fogged = 0;
    for (var c = 0; c < 5; c++) {
      for (var r = 0; r < 5; r++) {
        if (b.isFogged(c, r)) fogged++;
      }
    }
    expect(fogged, 4);
  });

  test('hasPossibleMove 识别万能卡与炸弹', () {
    final level = LevelDefinition(
      id: 1,
      name: 't',
      cols: 4,
      rows: 4,
      stockSize: 10,
      goalType: GoalType.clearBoard,
      targetTier: null,
      targetCount: 1,
    );
    // 无任何可合并 → false
    final b1 = BoardLogic(level, random: Random(8));
    b1.placeAt(0, 0, StackData(CarTier.bike));
    b1.placeAt(1, 1, StackData(CarTier.car));
    expect(b1.hasPossibleMove, false);
    // 一张万能卡 + 一张普通卡 → true
    final b2 = BoardLogic(level, random: Random(9));
    b2.placeAt(0, 0, StackData(CarTier.bike, isWildcard: true));
    b2.placeAt(1, 1, StackData(CarTier.car));
    expect(b2.hasPossibleMove, true);
    // 两张炸弹 → true
    final b3 = BoardLogic(level, random: Random(10));
    b3.placeAt(0, 0, StackData(CarTier.bike, isBomb: true));
    b3.placeAt(1, 1, StackData(CarTier.bike, isBomb: true));
    expect(b3.hasPossibleMove, true);
    // 一张炸弹 + 一张普通 → false（只交换不合并）
    final b4 = BoardLogic(level, random: Random(11));
    b4.placeAt(0, 0, StackData(CarTier.bike, isBomb: true));
    b4.placeAt(1, 1, StackData(CarTier.car));
    expect(b4.hasPossibleMove, false);
  });
}
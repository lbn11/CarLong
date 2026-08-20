import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';

const testLevel = LevelDefinition(
  id: 1,
  name: 'test',
  cols: 3,
  rows: 3,
  stockSize: 12,
  targetTier: VehicleType.sedan,
  targetCount: 1,
);

/// 8 格棋盘，用于死局测试（死局需要每级卡片 < 2 张，最多 8 格）。
const deadLevel = LevelDefinition(
  id: 2,
  name: 'dead',
  cols: 4,
  rows: 2,
  stockSize: 12,
  targetTier: VehicleType.sedan,
  targetCount: 1,
);

void main() {
  group('BoardLogic', () {
    test('初始棋盘为空', () {
      final b = BoardLogic(testLevel);
      expect(b.at(0, 0), isNull);
      expect(b.isFull, isFalse);
    });

    test('spawn 在空格生成卡片', () {
      final b = BoardLogic(testLevel);
      final cell = b.spawn();
      expect(cell, isNotNull);
      expect(b.at(cell!.col, cell.row), isNotNull);
    });

    test('移动到空格 = 移动', () {
      final b = BoardLogic(testLevel);
      b.placeAt(0, 0, StackData(VehicleType.bicycle));
      final target = _firstEmpty(b, 0, 0)!;
      final r = b.move(0, 0, target.col, target.row);
      expect(r.valid, isTrue);
      expect(b.at(0, 0), isNull);
      expect(b.at(target.col, target.row), isNotNull);
    });

    test('同类合成到 2 不升级', () {
      final b = BoardLogic(testLevel);
      b.placeAt(0, 0, StackData(VehicleType.bicycle));
      b.placeAt(1, 0, StackData(VehicleType.bicycle));
      final r = b.move(1, 0, 0, 0);
      expect(r.valid, isTrue);
      expect(r.upgraded, isFalse);
      expect(b.at(0, 0)!.count, 2);
      expect(b.at(0, 0)!.tier, VehicleType.bicycle);
    });

    test('三张同类合成升级', () {
      final b = BoardLogic(testLevel);
      b.placeAt(0, 0, StackData(VehicleType.bicycle));
      b.placeAt(1, 0, StackData(VehicleType.bicycle));
      b.placeAt(2, 0, StackData(VehicleType.bicycle));
      b.move(1, 0, 0, 0); // count=2
      final r = b.move(2, 0, 0, 0); // count=3 -> upgrade
      expect(r.upgraded, isTrue);
      expect(b.at(0, 0)!.tier, VehicleType.scooter);
      expect(b.at(0, 0)!.count, 1);
    });

    test('目标合成计数', () {
      final b = BoardLogic(testLevel); // target = car
      // bike x3 -> scooter
      b.placeAt(0, 0, StackData(VehicleType.bicycle));
      b.placeAt(1, 0, StackData(VehicleType.bicycle));
      b.placeAt(2, 0, StackData(VehicleType.bicycle));
      b.move(1, 0, 0, 0);
      b.move(2, 0, 0, 0);
      // scooter x3 -> car（目标）
      b.placeAt(1, 1, StackData(VehicleType.scooter));
      b.placeAt(2, 1, StackData(VehicleType.scooter));
      final first = b.move(2, 1, 0, 0); // scooter(2)
      expect(first.upgraded, isFalse);
      final r = b.move(1, 1, 0, 0); // scooter(3) -> car
      expect(r.upgraded, isTrue);
      expect(r.producedTarget, isTrue);
      expect(b.at(0, 0)!.tier, VehicleType.sedan);
      expect(b.producedCount, 1);
      expect(b.isTargetReached, isTrue);
    });

    test('不同等级卡片 = 交换', () {
      final b = BoardLogic(testLevel);
      b.placeAt(0, 0, StackData(VehicleType.bicycle));
      b.placeAt(1, 0, StackData(VehicleType.scooter));
      final r = b.move(0, 0, 1, 0);
      expect(r.valid, isTrue);
      expect(b.at(0, 0)!.tier, VehicleType.scooter);
      expect(b.at(1, 0)!.tier, VehicleType.bicycle);
    });

    test('全满且每级不足 2 张 = 死局', () {
      final b = BoardLogic(deadLevel); // 4x2 = 8 格
      final tiers = VehicleType.values; // 恰好 8 级
      for (var c = 0; c < b.cols; c++) {
        for (var r = 0; r < b.rows; r++) {
          b.placeAt(c, r, StackData(tiers[r * b.cols + c]));
        }
      }
      expect(b.isFull, isTrue);
      expect(b.isDeadlocked, isTrue);
    });

    test('全满但存在可合并卡片 = 非死局', () {
      final b = BoardLogic(deadLevel);
      for (var c = 0; c < b.cols; c++) {
        for (var r = 0; r < b.rows; r++) {
          b.placeAt(c, r, StackData(VehicleType.rocket));
        }
      }
      expect(b.isFull, isTrue);
      expect(b.isDeadlocked, isFalse);
    });

    test('placeTier 放入指定等级', () {
      final b = BoardLogic(testLevel);
      final cell = b.placeTier(VehicleType.bus);
      expect(cell, isNotNull);
      expect(b.at(cell!.col, cell.row)!.tier, VehicleType.bus);
    });

    test('满盘 placeTier 返回 null', () {
      final b = BoardLogic(testLevel);
      for (var c = 0; c < b.cols; c++) {
        for (var r = 0; r < b.rows; r++) {
          b.placeAt(c, r, StackData(VehicleType.bicycle));
        }
      }
      expect(b.placeTier(VehicleType.bicycle), isNull);
    });

    test('removeLowest 移除最低等级', () {
      final b = BoardLogic(testLevel);
      b.placeAt(0, 0, StackData(VehicleType.sedan));
      b.placeAt(1, 0, StackData(VehicleType.bicycle));
      b.placeAt(2, 0, StackData(VehicleType.scooter));
      final removed = b.removeLowest();
      expect(removed, isNotNull);
      expect(removed!.tier, VehicleType.bicycle);
      expect(b.at(removed.col, removed.row), isNull);
      // 剩下的还在
      expect(b.at(0, 0), isNotNull);
    });

    test('空盘 removeLowest 返回 null', () {
      final b = BoardLogic(testLevel);
      expect(b.removeLowest(), isNull);
    });

    test('removeAt 移除指定格', () {
      final b = BoardLogic(testLevel);
      b.placeAt(0, 0, StackData(VehicleType.bus));
      final data = b.removeAt(0, 0);
      expect(data, isNotNull);
      expect(data!.tier, VehicleType.bus);
      expect(b.at(0, 0), isNull);
      expect(b.removeAt(2, 2), isNull);
    });

    test('snapshot/restore 恢复棋盘', () {
      final b = BoardLogic(testLevel);
      b.placeAt(0, 0, StackData(VehicleType.bicycle, count: 2));
      b.placeAt(1, 0, StackData(VehicleType.sedan));
      final snap = b.snapshot();
      b.move(1, 0, 0, 0); // 交换
      b.restore(snap);
      expect(b.at(0, 0)!.tier, VehicleType.bicycle);
      expect(b.at(0, 0)!.count, 2);
      expect(b.at(1, 0)!.tier, VehicleType.sedan);
      expect(b.producedCount, 0);
    });

    test('restore 恢复升级后的计数', () {
      final b = BoardLogic(testLevel); // target = car
      b.placeAt(0, 0, StackData(VehicleType.bicycle));
      b.placeAt(1, 0, StackData(VehicleType.bicycle));
      b.placeAt(2, 0, StackData(VehicleType.bicycle));
      b.move(1, 0, 0, 0);
      final snap = b.snapshot(); // bike(2) + bike
      b.move(2, 0, 0, 0); // -> scooter
      expect(b.producedCount, 0);
      b.restore(snap);
      expect(b.at(0, 0)!.tier, VehicleType.bicycle);
      expect(b.at(0, 0)!.count, 2);
      expect(b.at(2, 0), isNotNull);
    });

    test('spawnWeights 永不生成超过 VehicleType 上限的等级', () {
      for (final level in levels) {
        final weights = level.spawnWeights();
        expect(
          weights.length,
          lessThanOrEqualTo(VehicleType.values.length),
          reason: '关卡 ${level.name} 的权重表超过车辆等级上限',
        );
      }
    });

    test('随机生成大量卡片不越界（回归：RangeError 0..7:8）', () {
      for (final level in levels) {
        final b = BoardLogic(level);
        for (var i = 0; i < 5000; i++) {
          final tier = b.randomTier();
          expect(tier.index, inInclusiveRange(0, VehicleType.values.length - 1));
        }
      }
    });
  });
}

({int col, int row})? _firstEmpty(BoardLogic b, int fc, int fr) {
  for (var c = 0; c < b.cols; c++) {
    for (var r = 0; r < b.rows; r++) {
      if (c == fc && r == fr) continue;
      if (b.at(c, r) == null) return (col: c, row: r);
    }
  }
  return null;
}

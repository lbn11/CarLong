import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';

/// clearBoard（清道夫）关卡闭环回归：
/// d491acc 把最高级合成改为保留后，"牌堆空 && 棋盘空"在合并-3 下
/// 数学上不可达（三进制守恒），主线在第 6 关即卡死。
/// 修复 = 顶部窗口出牌 + 残留上限 clearLimit，本文件锁定这两个机制。
void main() {
  LevelDefinition clearLevel({int? limit}) => LevelDefinition(
        id: 6,
        name: 't',
        cols: 5,
        rows: 5,
        stockSize: 30,
        goalType: GoalType.clearBoard,
        targetTier: null,
        targetCount: 1,
        clearLimit: limit,
      );

  group('spawnWeights：clearBoard 只出最高 3 档', () {
    test('非零权重仅 47/48/49，值为 5/8/12', () {
      final w = clearLevel().spawnWeights();
      expect(w.length, VehicleType.values.length);
      for (var i = 0; i < w.length; i++) {
        if (i == VehicleType.values.length - 1) {
          expect(w[i], 12, reason: '最高档权重 12');
        } else if (i == VehicleType.values.length - 2) {
          expect(w[i], 8, reason: '次高档权重 8');
        } else if (i == VehicleType.values.length - 3) {
          expect(w[i], 5, reason: '第三档权重 5');
        } else {
          expect(w[i], 0, reason: '档位 $i 不应出牌');
        }
      }
    });

    test('produce 关不受影响：目标下方窗口分布', () {
      final w = LevelDefinition(
        id: 1,
        name: 't',
        cols: 4,
        rows: 4,
        stockSize: 20,
        targetTier: VehicleType.truck,
        targetCount: 1,
      ).spawnWeights();
      // 列表只覆盖到目标档-1：目标及以上档位根本不会出牌。
      expect(w.length, VehicleType.truck.index,
          reason: '最高出牌档 = 目标档-1');
      expect(w.last, greaterThan(0));
    });
  });

  group('boardCleared：残留上限判定', () {
    test('残堆 ≤ clearLimit 即胜利', () {
      final l6 = clearLevel(limit: 6);
      expect(l6.boardCleared(6), isTrue);
      expect(l6.boardCleared(7), isFalse);
      expect(l6.boardCleared(0), isTrue);
    });

    test('未配置 clearLimit 时按 0 处理（绝对清空）', () {
      expect(clearLevel().boardCleared(0), isTrue);
      expect(clearLevel().boardCleared(1), isFalse);
    });

    test('手写关难度递减：前期宽后期严', () {
      int? limitOf(int id) => levels
          .firstWhere((l) => l.id == id, orElse: () => throw StateError('$id'))
          .clearLimit;
      expect(limitOf(6), 6);
      expect(limitOf(27), 6);
      expect(limitOf(33), 5);
      expect(limitOf(57), 5);
      expect(limitOf(58), 4);
      expect(limitOf(70), 4);
    });
  });
}

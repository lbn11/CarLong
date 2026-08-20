import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/save/save_repository.dart';

void main() {
  group('BoardLogic weightedTierUpTo', () {
    test('不产生超过上限的等级', () {
      final board = BoardLogic(endlessLevel);
      for (var i = 0; i < 200; i++) {
        final t = board.weightedTierUpTo(3);
        expect(t.index, lessThanOrEqualTo(3));
      }
    });

    test('上限为 0 时恒为最低级', () {
      final board = BoardLogic(endlessLevel);
      for (var i = 0; i < 50; i++) {
        expect(board.weightedTierUpTo(0), VehicleType.bicycle);
      }
    });
  });

  group('BoardLogic highest', () {
    test('返回棋盘最高等级卡片', () {
      final board = BoardLogic(endlessLevel);
      board.placeAt(0, 0, StackData(VehicleType.sedan));
      board.placeAt(1, 1, StackData(VehicleType.highspeed));
      board.placeAt(2, 2, StackData(VehicleType.bus));
      final top = board.highest()!;
      expect(top.tier, VehicleType.highspeed);
      expect(top.col, 1);
      expect(top.row, 1);
    });

    test('空盘返回 null', () {
      final board = BoardLogic(endlessLevel);
      expect(board.highest(), isNull);
    });
  });

  group('PlayerData 序列化', () {
    test('新字段往返保留', () {
      final data = PlayerData(
        coins: 120,
        unlockedLevel: 4,
        bestScores: {1: 500, 2: 800},
        bestStars: {1: 3, 2: 2},
        lastSignInDate: '2026-08-11',
        signInStreak: 3,
        signInTotal: 7,
        endlessBest: [1200, 900, 300],
      );
      final restored = PlayerData.fromJson(data.toJson());
      expect(restored.bestStars, {1: 3, 2: 2});
      expect(restored.lastSignInDate, '2026-08-11');
      expect(restored.signInStreak, 3);
      expect(restored.signInTotal, 7);
      expect(restored.endlessBest, [1200, 900, 300]);
    });

    test('老存档缺省值兼容', () {
      final restored = PlayerData.fromJson({'coins': 5});
      expect(restored.bestStars, isEmpty);
      expect(restored.lastSignInDate, isNull);
      expect(restored.endlessBest, isEmpty);
      expect(restored.soundOn, isTrue);
      expect(restored.vibrateOn, isTrue);
    });

    test('音效/振动开关往返保留', () {
      final data = PlayerData(soundOn: false, vibrateOn: false);
      final restored = PlayerData.fromJson(data.toJson());
      expect(restored.soundOn, isFalse);
      expect(restored.vibrateOn, isFalse);
    });
  });
}

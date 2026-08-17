import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/achievement.dart';
import 'package:merge_fleet/save/save_repository.dart';

void main() {
  Achievement byId(String id) =>
      achievements.firstWhere((a) => a.id == id);

  group('停车专属成就达成条件', () {
    test('park_first: 通关第 1 关', () {
      final none = PlayerData();
      expect(byId('park_first').achieved(none), isFalse);

      final cleared = PlayerData(parkingBestStars: {1: 3});
      expect(byId('park_first').achieved(cleared), isTrue);
    });

    test('park_clear_5 / park_clear_10: 累计关卡数', () {
      // 5 关：刚好达标 park_clear_5，未达 park_clear_10。
      final five = PlayerData(parkingBestStars: {
        1: 1,
        2: 2,
        3: 1,
        4: 3,
        5: 2,
      });
      expect(byId('park_clear_5').achieved(five), isTrue);
      expect(byId('park_clear_10').achieved(five), isFalse);

      // 10 关：达标 park_clear_10。
      final ten = PlayerData(
        parkingBestStars: {for (var i = 1; i <= 10; i++) i: 1},
      );
      expect(byId('park_clear_10').achieved(ten), isTrue);
    });

    test('park_star_3: 任一关 3 星', () {
      final no = PlayerData(parkingBestStars: {1: 2, 2: 1});
      expect(byId('park_star_3').achieved(no), isFalse);

      final yes = PlayerData(parkingBestStars: {1: 2, 2: 3});
      expect(byId('park_star_3').achieved(yes), isTrue);
    });

    test('park_master: 解锁第 20 关 (parkingUnlocked > 20)', () {
      final before = PlayerData(parkingUnlocked: 20);
      expect(byId('park_master').achieved(before), isFalse);

      final after = PlayerData(parkingUnlocked: 21);
      expect(byId('park_master').achieved(after), isTrue);
    });
  });
}

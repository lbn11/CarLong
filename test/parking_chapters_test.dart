import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/services/parking_chapters.dart';

void main() {
  group('ParkingChapters 双向联动', () {
    // 章节边界从表里动态取，避免调边界时测试跟着硬编码一起腐坏。
    final bike = ParkingChapters.all.first;
    final scooter = ParkingChapters.all[1];
    final sedan = ParkingChapters.all[2];
    final last = ParkingChapters.all.last;

    test('tierForId 分段与章节表一致', () {
      expect(ParkingChapters.tierForId(bike.startId), bike.tier);
      expect(ParkingChapters.tierForId(bike.endId), bike.tier);
      expect(ParkingChapters.tierForId(scooter.startId), scooter.tier);
      expect(ParkingChapters.tierForId(scooter.endId), scooter.tier);
      expect(ParkingChapters.tierForId(sedan.startId), sedan.tier);
      expect(ParkingChapters.tierForId(ParkingChapters.totalLevels), last.tier);
    });

    test('章节连续无缝、总关数覆盖完整', () {
      var expected = 1;
      for (final c in ParkingChapters.all) {
        expect(c.startId, expected,
            reason: '${c.title} 起点应与上一章末尾相接');
        expect(c.endId >= c.startId, isTrue);
        expected = c.endId + 1;
      }
      expect(ParkingChapters.all.last.endId, ParkingChapters.totalLevels);
    });

    test('单车章节始终可进入（新玩家起步）', () {
      expect(ParkingChapters.isAccessible(bike, {}, {}), isTrue);
    });

    test('踏板章节默认锁定', () {
      expect(ParkingChapters.isAccessible(scooter, {}, {}), isFalse);
    });

    test('合成收集该档 → 解锁对应停车章节（可跳章）', () {
      expect(
          ParkingChapters.isAccessible(
              scooter, {VehicleType.scooter.index}, {}),
          isTrue);
    });

    test('通关上一章最后一关 → 停车自身顺序解锁', () {
      // 单车章最后一关已通关 → 解锁
      expect(
          ParkingChapters.isAccessible(scooter, {}, {bike.endId: 3}), isTrue);
      // 仅通关倒数第二关 → 仍锁定
      expect(
          ParkingChapters.isAccessible(scooter, {}, {bike.endId - 1: 3}),
          isFalse);
    });

    test('lockReason 提示在合成中收集该车型', () {
      expect(ParkingChapters.lockReason(scooter), contains('踏板'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/car.dart';
import 'package:merge_fleet/services/parking_chapters.dart';

void main() {
  group('ParkingChapters 双向联动', () {
    test('tierForId 分段与生成器一致', () {
      expect(ParkingChapters.tierForId(1), CarTier.bike);
      expect(ParkingChapters.tierForId(45), CarTier.bike);
      expect(ParkingChapters.tierForId(46), CarTier.scooter);
      expect(ParkingChapters.tierForId(90), CarTier.scooter);
      expect(ParkingChapters.tierForId(91), CarTier.car);
      expect(ParkingChapters.tierForId(773), CarTier.warp);
      expect(ParkingChapters.tierForId(819), CarTier.hover);
      expect(ParkingChapters.tierForId(955), CarTier.antigrav);
      expect(ParkingChapters.tierForId(1000), CarTier.antigrav);
    });

    test('单车章节始终可进入（新玩家起步）', () {
      final bike = ParkingChapters.chapterForId(1);
      expect(ParkingChapters.isAccessible(bike, {}, {}), isTrue);
    });

    test('踏板章节默认锁定', () {
      final scooter = ParkingChapters.chapterForId(46);
      expect(ParkingChapters.isAccessible(scooter, {}, {}), isFalse);
    });

    test('合成收集该档 → 解锁对应停车章节（可跳章）', () {
      final scooter = ParkingChapters.chapterForId(46);
      expect(
          ParkingChapters.isAccessible(scooter, {CarTier.scooter.index}, {}),
          isTrue);
    });

    test('通关上一章最后一关 → 停车自身顺序解锁', () {
      final scooter = ParkingChapters.chapterForId(46);
      // 单车章最后一关 id=45 已通关 → 解锁
      expect(ParkingChapters.isAccessible(scooter, {}, {45: 3}), isTrue);
      // 仅通关 44（非最后一关）→ 仍锁定
      expect(ParkingChapters.isAccessible(scooter, {}, {44: 3}), isFalse);
    });

    test('lockReason 提示在合成中收集该车型', () {
      final scooter = ParkingChapters.chapterForId(46);
      expect(ParkingChapters.lockReason(scooter), contains('踏板'));
    });
  });
}

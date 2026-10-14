import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/services/level_data_generator.dart';
import 'package:merge_fleet/services/level_rhythm.dart';
import 'package:merge_fleet/services/parking_chapters.dart';
import 'package:merge_fleet/services/parking_generator.dart';

/// 难度心跳的回归测试。
///
/// 最重要的一条是 [周期必须错开]：产品明确要求两个模式的局部难度曲线
/// 关卡数不能相同（否则交替游玩时紧张点叠加、节奏感互相抵消）。
/// 谁把两个周期改成一样，这条测试就该红。
void main() {
  group('周期错开（产品硬性要求）', () {
    test('合成 5 关一轮、停车 6 关一轮，且互不相等', () {
      expect(LevelDataGenerator.rhythmPeriod, 5);
      expect(ParkingLevelGenerator.rhythmPeriod, 6);
      expect(LevelDataGenerator.rhythmPeriod,
          isNot(equals(ParkingLevelGenerator.rhythmPeriod)));
      expect(LevelRhythm.mergePeriod, LevelDataGenerator.rhythmPeriod);
      expect(LevelRhythm.parkingPeriod, ParkingLevelGenerator.rhythmPeriod);
    });

    test('两个周期都应在 5-7 关之间（可预知的张弛，又不至于太碎）', () {
      for (final p in [
        LevelDataGenerator.rhythmPeriod,
        ParkingLevelGenerator.rhythmPeriod,
      ]) {
        expect(p, greaterThanOrEqualTo(5));
        expect(p, lessThanOrEqualTo(7));
      }
    });
  });

  group('LevelRhythm 表完整性', () {
    for (final mode in RhythmMode.values) {
      test('$mode 四张表长度与周期一致', () {
        final period = LevelRhythm.periodOf(mode);
        expect(LevelRhythm.namesOf(mode).length, period);
        // colorOf / iconOf 对任意相位都不能越界
        for (var phase = 0; phase < period * 2; phase++) {
          expect(() => LevelRhythm.nameOf(mode, phase), returnsNormally);
          expect(() => LevelRhythm.colorOf(mode, phase), returnsNormally);
          expect(() => LevelRhythm.iconOf(mode, phase), returnsNormally);
        }
      });
    }

    test('轻松永远是相位 0（新车型登场位）', () {
      for (final mode in RhythmMode.values) {
        expect(LevelRhythm.nameOf(mode, 0), '轻松');
      }
    });

    test('两个模式的相位名不完全相同（曲线形状可区分）', () {
      expect(LevelRhythm.namesOf(RhythmMode.merge),
          isNot(equals(LevelRhythm.namesOf(RhythmMode.parking))));
    });
  });

  group('生成器相位', () {
    test('合成：相位落在 0..4，章首恒为轻松', () {
      for (var id = LevelDataGenerator.firstId;
          id <= LevelDataGenerator.lastId;
          id++) {
        final phase = LevelDataGenerator.rhythmPhase(id);
        expect(phase, inInclusiveRange(0, 4), reason: 'L$id');
      }
      for (final ch in LevelDataGenerator.generatedChapters) {
        expect(LevelDataGenerator.rhythmPhase(ch.startId), 0,
            reason: ch.title);
      }
    });

    test('停车：相位落在 0..5，章首恒为轻松（新车型登场）', () {
      for (final ch in ParkingChapters.all) {
        expect(ParkingLevelGenerator.rhythmPhase(ch.startId), 0,
            reason: ch.title);
        // 章内每个相位都出现一次
        final phases = {
          for (var id = ch.startId; id <= ch.endId; id++)
            ParkingLevelGenerator.rhythmPhase(id)
        };
        expect(phases.length, ParkingLevelGenerator.rhythmPeriod,
            reason: ch.title);
      }
      for (var id = 1; id <= ParkingChapters.totalLevels; id++) {
        final phase = ParkingLevelGenerator.rhythmPhase(id);
        expect(phase, inInclusiveRange(0, 5), reason: 'L$id');
      }
    });
  });
}

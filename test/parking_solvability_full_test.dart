import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/parking_game.dart';
import 'package:merge_fleet/game/parking_daily_challenge.dart';
import 'package:merge_fleet/logic/parking_solver.dart';
import 'package:merge_fleet/models/parking_level.dart';
import 'package:merge_fleet/services/parking_chapters.dart';
import 'package:merge_fleet/services/parking_generator.dart';

/// 全量可解性验证：停车 1..800 关逐关求解，并抽样用 ParkingGame
/// 真实回放求解序列，证明"每一关都真的能解、能通关"。
///
/// 背景约定：
/// - 生成器已保证产出关可解（不可解会换种子重试），本测试是该约定的回归防线；
/// - ParkingSolver 与 ParkingGame.canMoveTo 的滑动规则（直线滑行、只有目标车
///   可入位、障碍不可穿）一致，解序列在真实对局里逐步 moveVehicle 必须全部合法。
void main() {
  test('停车 1..800 关全部可解（solver 逐关验证）', () {
    final unsolvable = <int>[];
    final noTarget = <int>[];
    final multiTarget = <int>[];
    final multiParking = <int>[];
    final tooEasy = <int>[];
    final minMovesHist = <int, int>{};

    for (var id = 1; id <= ParkingChapters.totalLevels; id++) {
      final lvl = ParkingLevelGenerator.generateOne(id);

      // 结构不变量：目标车存在且唯一、停车位唯一。
      // 唯一性不是洁癖：`ParkingGame._checkWin` 曾用 firstOrNull 取第一辆
      // 目标车判断是否停好，一旦盘上有第二辆目标车，玩家把其中一辆开进
      // 车位也永远判不出胜利（看着车停好了却还在关卡里）。判定已改成
      // any()，这里继续锁住生成器侧的唯一性，两头都不留洞。
      final targets =
          lvl.vehicles.where((v) => v.tier == lvl.targetTier).toList();
      if (targets.isEmpty) noTarget.add(id);
      if (targets.length > 1) multiTarget.add(id);
      var parkingCells = 0;
      for (final row in lvl.grid) {
        for (final c in row) {
          if (c == ParkingCellType.parking) parkingCells++;
        }
      }
      if (parkingCells != 1) multiParking.add(id);

      final min = ParkingSolver.minMoves(lvl, maxStates: 200000);
      if (min == null) {
        unsolvable.add(id);
        continue;
      }
      minMovesHist[min] = (minMovesHist[min] ?? 0) + 1;
      if (min < 2) tooEasy.add(id); // 一步通关 = 弱关
    }

    // ignore: avoid_print
    print('minMoves 分布: $minMovesHist');
    expect(noTarget, isEmpty, reason: '每关必须有目标车');
    expect(multiTarget, isEmpty, reason: '目标车必须唯一: $multiTarget');
    expect(multiParking, isEmpty, reason: '停车位必须唯一');
    expect(unsolvable, isEmpty, reason: '不可解关卡: $unsolvable');
    expect(tooEasy, isEmpty, reason: '一步弱关: $tooEasy');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('抽样关卡：ParkingGame 真实回放求解序列 → 必须通关', () {
    final failures = <String>[];
    // 每 25 关抽 1 关 + 首尾边界，覆盖全部章节与棋盘尺寸。
    final ids = [
      for (var id = 1; id <= ParkingChapters.totalLevels; id += 25) id,
      ParkingChapters.totalLevels - 1,
      ParkingChapters.totalLevels,
    ];

    for (final id in ids) {
      final lvl = ParkingLevelGenerator.generateOne(id);
      final solution = ParkingSolver.solve(lvl, maxStates: 200000);
      if (solution == null) {
        failures.add('id=$id: solver 无解');
        continue;
      }

      final game = ParkingGame(lvl);
      var ok = true;
      for (var i = 0; i < solution.length && ok; i++) {
        final m = solution[i];
        final v = game.vehicles[m.vehicleIndex];
        // 解序列坐标必须与对局状态连续一致（防 solver 与 game 规则漂移）。
        if (v.row != m.fromRow || v.col != m.fromCol) {
          failures.add(
              'id=$id step#$i: solver 起点(${m.fromRow},${m.fromCol}) '
              '与对局(${v.row},${v.col})不一致');
          ok = false;
          break;
        }
        if (!game.moveVehicle(m.vehicleIndex, m.toRow, m.toCol)) {
          failures.add('id=$id step#$i: moveVehicle 拒绝合法解步');
          ok = false;
          break;
        }
      }
      if (ok && !game.hasWon) failures.add('id=$id: 走完解序列仍未通关');
      game.dispose();
    }

    expect(failures, isEmpty, reason: '回放失败: $failures');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('每日挑战关也可解', () {
    final lvl = ParkingDailyChallenge.today();
    expect(ParkingSolver.minMoves(lvl, maxStates: 200000), isNotNull);
  });
}

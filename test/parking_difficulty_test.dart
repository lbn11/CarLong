import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/logic/parking_solver.dart';
import 'package:merge_fleet/services/parking_generator.dart';
import 'package:merge_fleet/models/parking_level.dart';

void main() {
  test('早期关卡：可解、无弱关、难度 heartbeat 节奏、装饰随 id 增长', () {
    var fallbacks = 0;
    var zeroObstacle = 0;
    final obstacleById = <int>[];
    for (final id in [1, 5, 10, 15, 20, 25, 30, 40, 49, 50, 75, 100, 200, 300]) {
      final lvl = ParkingLevelGenerator.generateOne(id);
      final min = ParkingSolver.minMoves(lvl);
      expect(min, isNotNull, reason: 'level $id 必须可解');

      // 1 步通关 = 弱关。心跳节奏的波谷（轻松/缓冲相位）也是 2 步，
      // 不是 1 步 —— 生成器对 real < 2 的候选直接弃用（见 _tryReverse）。
      expect(min!, greaterThanOrEqualTo(2), reason: 'level $id');

      // 障碍数
      var obstacles = 0;
      for (final row in lvl.grid) {
        for (final c in row) {
          if (c == ParkingCellType.obstacle) obstacles++;
        }
      }
      obstacleById.add(obstacles);
      if (obstacles == 0) zeroObstacle++;

      // 兜底关签名：仅 2 辆车且 2 步
      if (lvl.vehicles.length == 2 && min == 2) fallbacks++;

      // ignore: avoid_print
      print('id=$id size=${lvl.rows} obstacles=$obstacles '
          'vehicles=${lvl.vehicles.length} minMoves=$min');
    }
    // 新手章（1-36）的轻松/缓冲相位允许 0 障碍：新车亮相 + 波谷，
    // 装饰密度靠 (id~/14)+1 随 id 增长，不是每关都堆。
    expect(zeroObstacle, lessThanOrEqualTo(2), reason: '只有轻松/缓冲相位允许空场');
    expect(obstacleById.last, greaterThan(obstacleById.first),
        reason: '障碍装饰应随 id 增长');
    expect(fallbacks, 0, reason: '不应退化为兜底弱关');
  });
}

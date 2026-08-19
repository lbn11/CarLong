import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/logic/parking_solver.dart';
import 'package:merge_fleet/services/parking_generator.dart';
import 'package:merge_fleet/models/parking_level.dart';

void main() {
  test('中度难度：早期关卡障碍>0、4x4有底部竖挡车、全部可解', () {
    var fallbacks = 0;
    var size4BlockerMissing = 0;
    var zeroObstacle = 0;
    for (final id in [1, 5, 10, 15, 20, 25, 30, 40, 49, 50, 75, 100, 200, 300]) {
      final lvl = ParkingLevelGenerator.generateOne(id);
      final min = ParkingSolver.minMoves(lvl);
      expect(min, isNotNull, reason: 'level $id 必须可解');

      // 障碍数
      var obstacles = 0;
      for (final row in lvl.grid) {
        for (final c in row) {
          if (c == ParkingCellType.obstacle) obstacles++;
        }
      }
      if (obstacles == 0) zeroObstacle++;

      // 4x4 关卡必须有底部行竖挡车（长度2、vertical、跨越底部行）
      if (lvl.rows == 4) {
        final pr = lvl.rows - 1;
        final hasBottomBlocker = lvl.vehicles.any((v) =>
            v.length == 2 &&
            v.orientation == ParkingOrientation.vertical &&
            v.row == pr - 1);
        if (!hasBottomBlocker) size4BlockerMissing++;
      }

      // 兜底关签名：仅 2 辆车且 2 步
      if (lvl.vehicles.length == 2 && min == 2) fallbacks++;

      // ignore: avoid_print
      print('id=$id size=${lvl.rows} obstacles=$obstacles '
          'vehicles=${lvl.vehicles.length} minMoves=$min');
    }
    expect(zeroObstacle, 0, reason: '不应有 0 障碍的早期关');
    expect(size4BlockerMissing, 0, reason: '4x4 关都应含底部竖挡车');
    expect(fallbacks, 0, reason: '不应退化为兜底弱关');
  });
}

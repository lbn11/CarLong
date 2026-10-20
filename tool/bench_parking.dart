// 停车关生成器的性能/预算标定工具。
//
// `ParkingReverseBuilder.reverseWalk` 的工作量预算（workBudget）必须满足两个
// 互斥目标：① 够大，让尖峰关能走满 7 步；② 够小，选关页进关不卡。
// 这个工具就是标定它用的 —— 跑全量 800 关，输出耗时分布与工作量分布。
//
//   flutter test tool/bench_parking.dart
//
// 注意：耗时受机器影响，**工作量（work）不受影响**，所以调预算看 work 列，
// 判卡顿看 ms 列。
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/services/parking_chapters.dart';
import 'package:merge_fleet/services/parking_generator.dart';
import 'package:merge_fleet/services/parking_reverse_builder.dart';

void main() {
  test('停车 800 关生成标定', () {
    final sw = Stopwatch()..start();
    final ms = <int>[];
    final works = <int>[];
    final moves = <int>[];
    var worstMs = 0;
    var worstId = 0;

    for (var id = 1; id <= ParkingChapters.totalLevels; id++) {
      final t = Stopwatch()..start();
      final lvl = ParkingLevelGenerator.generateOne(id);
      t.stop();
      ms.add(t.elapsedMilliseconds);
      works.add(ParkingReverseBuilder.lastWork);
      moves.add(lvl.minMoves ?? 0);
      if (t.elapsedMilliseconds > worstMs) {
        worstMs = t.elapsedMilliseconds;
        worstId = id;
      }
    }
    sw.stop();

    int pct(List<int> xs, double p) {
      final s = [...xs]..sort();
      return s[(s.length * p).clamp(0, s.length - 1).floor()];
    }

    double avg(List<int> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    // ignore: avoid_print
    print('''
── 800 关全量 ──
总耗时      ${sw.elapsedMilliseconds} ms
单关耗时    avg ${avg(ms).toStringAsFixed(1)} / p50 ${pct(ms, .5)} /
            p99 ${pct(ms, .99)} / max $worstMs (L$worstId)
工作量 work avg ${avg(works).toStringAsFixed(0)} / p50 ${pct(works, .5)} /
            p99 ${pct(works, .99)} / max ${works.reduce((a, b) => a > b ? a : b)}
步数 minMoves avg ${avg(moves).toStringAsFixed(2)} / max ${moves.reduce((a, b) => a > b ? a : b)}
            5 步以上 ${moves.where((m) => m >= 5).length} 关 /
            7 步 ${moves.where((m) => m >= 7).length} 关
''');

    expect(moves.every((m) => m >= 1), isTrue, reason: '不允许 0 步关');
  }, timeout: const Timeout(Duration(minutes: 20)));
}

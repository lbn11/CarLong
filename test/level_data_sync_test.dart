// 数据与代码的同步守卫。
//
// shared/levels/*.json 是跨端唯一真源，但它是**生成物**：
// 谁改了关卡数值/车型颜色/章节表却忘了重新导出，下游（小游戏端、服务端、
// 未来的 TS 实现）就会静默读到过期数据。这个测试每秒检查一次，把这个
// 隐患变成一条会红的断言。
//
// 修法永远只有一条：
//   flutter test tool/export_levels_runner.dart
//
// 注意只比对**合并关卡 + 车型表**（纯函数，秒级）。停车 800 关要跑
// solver 复核（约 40s），不塞进常规测试；它由导出工具内部的
// 「不可解就抛错」闸门守着。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/export_levels.dart';

void main() {
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('shared/levels/$name').readAsStringSync())
          as Map<String, dynamic>;

  test('merge_levels.json 与代码一致（改了数值要重新导出）', () {
    final disk = read('merge_levels.json');
    final now = jsonDecode(jsonEncode(mergePayload())) as Map<String, dynamic>;

    expect(disk['schema'], now['schema'], reason: 'schema 版本不一致');
    expect(disk['count'], now['count'], reason: '关数不一致');

    final diskLevels = disk['levels'] as List;
    final nowLevels = now['levels'] as List;
    expect(diskLevels.length, nowLevels.length);

    // 逐关报错比整体字符串比对更好定位：能直接指出是哪一关。
    for (var i = 0; i < nowLevels.length; i++) {
      final expectLevel = nowLevels[i] as Map<String, dynamic>;
      final diskLevel = diskLevels[i] as Map<String, dynamic>;
      expect(
        diskLevel,
        expectLevel,
        reason: 'L${expectLevel['id']} 的 JSON 与代码生成结果不一致',
      );
    }

    expect(disk['chapters'], now['chapters'], reason: '章节表不一致');
    expect(disk['phases'], now['phases'], reason: '相位名不一致');
  });

  test('vehicles.json 与代码一致', () {
    final disk = read('vehicles.json');
    final now = jsonDecode(jsonEncode(vehiclesPayload())) as Map<String, dynamic>;
    expect(disk['count'], now['count']);
    expect(disk['vehicles'], now['vehicles'], reason: '车型表不一致');
    expect(disk['rarities'], now['rarities']);
  });

  test('index.json 记录的数量与实际文件匹配', () {
    final idx = read('index.json');
    final merge = read('merge_levels.json');
    final parking = read('parking_levels.json');
    final vehicles = read('vehicles.json');

    expect((idx['merge'] as Map)['count'], merge['count']);
    expect((idx['parking'] as Map)['count'], parking['count']);
    expect((idx['vehicles'] as Map)['count'], vehicles['count']);
    expect(merge['count'], 700);
    expect(parking['count'], 800);
    expect(vehicles['count'], 50);
  });

  test('停车关全部经 solver 验证过（导出闸门兜底）', () {
    final idx = read('index.json');
    expect((idx['parking'] as Map)['minMovesVerified'], isTrue);
    // 修正记录不该无限增长：目前全量只有 1 关（L380）需要校准。
    // 数量变大意味着反向倒走的深度记账在退化，值得回头查。
    final corrected =
        ((idx['parking'] as Map)['minMovesCorrected'] as List?) ?? const [];
    expect(corrected.length, lessThanOrEqualTo(2),
        reason: 'minMoves 修正量异常膨胀：$corrected');
  });
}

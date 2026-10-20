// 导出关卡 JSON 的 runner。
//
// 为什么是 test 而不是 `dart run`：车型/关卡模型 import 了 `dart:ui`
// （VehicleType 的 Color 就写在 enum 构造里），纯 dart VM 拿不到 dart:ui，
// 只有 Flutter 的 test 宿主有。所以约定成「用 flutter test 跑一个一次性任务」，
// 与项目里已有的 `test/vehicle_assets_sheet_test.dart --update-goldens` 同套路。
//
//   flutter test tool/export_levels_runner.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'export_levels.dart';

void main() {
  test('导出 shared/levels/*.json', () async {
    // 从包根跑（flutter test 的 cwd 就是包根）。
    final out = Directory('shared/levels');
    final r = await exportLevels(out: out);

    // 硬断言，避免「悄悄导出了 0 关」这种静默失败。
    expect(r.mergeLevels, 700, reason: '主线应为 700 关');
    expect(r.parkingLevels, 800, reason: '停车应为 800 关');
    expect(File('${out.path}/index.json').existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/l10n/l10n.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';

import '../tool/export_levels.dart';
import 'helpers/localized_app.dart';

/// 模型层本地化（车辆名/大类/稀有度/能力）的守门测试。
///
/// 这层的特殊性：getter 签名里没有 `BuildContext`，值来自 `L10n.current`
/// 这份广播（`MaterialApp.builder` 同步）。所以两个方向都要锁死：
///   ① 界面侧：locale 变了，`tier.name` 必须跟着变，且中文下与 `zhName` 逐字相同；
///   ② 数据侧：`shared/levels/*.json` 的导出必须**与 locale 无关**，
///      否则同一台机器换个系统语言就会产出不同的关卡数据。
void main() {
  setUp(L10n.resetForTest);
  tearDown(L10n.resetForTest);

  test('未同步 locale 时回落中文字面量（不能是空串）', () {
    expect(L10n.current, isNull);
    expect(VehicleType.sedan.name, '轿车');
    expect(VehicleCategory.rail.displayLabel, '轨道');
    expect(Rarity.epic.displayLabel, '史诗');
    expect(SpecialAbility.warp.displayLabel, '曲速');
    expect(VehicleType.sedan.abilityDescription, '无特殊能力');
  });

  testWidgets('英文 locale：车型名走 arb', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('en')),
    );
    expect(VehicleType.sedan.name, 'Sedan');
    expect(VehicleType.warpShip.name, 'Warp Ship');
    expect(VehicleCategory.rail.displayLabel, 'Rail');
    expect(Rarity.legendary.displayLabel, 'Legendary');
    expect(SpecialAbility.breakIce.displayLabel, 'Ice breaker');
    expect(VehicleType.sedan.abilityDescription, 'No special ability');
    // 落盘名不受影响。
    expect(VehicleType.sedan.zhName, '轿车');
  });

  testWidgets('中文 locale：显示名必须与落盘名逐字一致', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('zh')),
    );
    for (final t in VehicleType.values) {
      expect(t.name, t.zhName, reason: '${t.id} 档中文显示名与 zhName 不一致');
    }
    for (final c in VehicleCategory.values) {
      expect(c.displayLabel, c.label, reason: '${c.name} 中文分类名不一致');
    }
    for (final r in Rarity.values) {
      expect(r.displayLabel, r.label, reason: '${r.name} 中文稀有度不一致');
    }
    for (final a in SpecialAbility.values) {
      expect(a.displayLabel, a.label, reason: '${a.name} 中文能力名不一致');
    }
  });

  testWidgets('导出数据与 locale 无关（英文环境仍导中文）', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('en')),
    );
    // 先确认界面确实已经切到英文，避免"没同步所以看起来对"的假通过。
    expect(VehicleType.sedan.name, 'Sedan');

    final payload = vehiclesPayload();
    final first = (payload['vehicles'] as List).first as Map;
    expect(first['name'], '自行车');
    expect((payload['categories'] as List).first['label'], '陆地');
    expect((payload['abilities'] as List).first['label'], '无');

    // 关卡里的 targetName 也是落盘字段：必须等于该档的 zhName。
    final json = mergeLevelToJson(levels.first);
    final tier = VehicleType.fromId(json['target'] as int);
    expect(json['targetName'], tier.zhName);
  });
}

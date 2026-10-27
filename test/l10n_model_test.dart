import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/l10n/l10n.dart';
import 'package:merge_fleet/models/achievement.dart';
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

  /// 关名/章节名/绰号是"数据里带中文"的三块。它们能本地化的前提是
  /// **落盘值单独存一份**（zhName / zhTitle / epithet），所以这里既查
  /// 界面侧不出中文，也查数据侧不出英文。
  testWidgets('英文 locale：关名/章节名/Boss 绰号全部英文化', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('en')),
    );
    final cjk = RegExp(r'[\u4e00-\u9fff]');

    // 主线 700 关逐关过一遍：手写段查表、生成段拼章节名，两条路径都要
    // 干净。漏一条就会在 HUD「第 X 关 · 名字」里露出中文。
    for (final lv in levels) {
      expect(cjk.hasMatch(lv.name), isFalse,
          reason: '第 ${lv.id} 关英文名下仍含中文：${lv.name}');
      expect(lv.zhName, isNotEmpty);
    }
    expect(levels.first.name, 'Morning Run');
    expect(endlessLevel.name, 'Endless');

    // Boss 关：`👑 Boss · <章节短名>`，两部分都不能有中文。
    final bossLevels = levels.where((l) => l.boss != null).toList();
    expect(bossLevels, isNotEmpty);
    for (final lv in bossLevels.take(20)) {
      expect(cjk.hasMatch(lv.name), isFalse, reason: 'Boss 关名漏翻：${lv.name}');
      expect(lv.name, contains('Boss'));
    }

    // 章节标题/短名/副标题。
    for (final ch in levelChapters) {
      expect(cjk.hasMatch(ch.title), isFalse, reason: '章节标题漏翻：${ch.title}');
      expect(cjk.hasMatch(ch.shortTitle), isFalse,
          reason: '章节短名漏翻：${ch.shortTitle}');
      expect(cjk.hasMatch(ch.subtitle), isFalse,
          reason: '章节副标题漏翻：${ch.subtitle}');
    }
    expect(levelChapters.first.title, 'Chapter 1 · Street Start');
    expect(levelChapters.first.shortTitle, 'Street Start');

    // 招牌 Boss 绰号（14 章 × 尖峰位）。
    for (var c = 0; c < 14; c++) {
      final spec = BossSpec.forLevel(c, 3, 6);
      final label = spec.epithetLabel;
      expect(label, isNotNull);
      expect(cjk.hasMatch(label!), isFalse, reason: '第 ${c + 1} 章绰号漏翻：$label');
    }
  });

  testWidgets('中文 locale：关名与章节名回到原文', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('zh')),
    );
    for (final lv in levels) {
      expect(lv.name, lv.zhName, reason: '第 ${lv.id} 关中文显示名与 zhName 不一致');
    }
    for (final ch in levelChapters) {
      expect(ch.title, ch.zhTitle);
      expect(ch.shortTitle, ch.zhShortTitle);
      expect(ch.subtitle, ch.zhSubtitle);
    }
  });

  testWidgets('关卡数据导出不受 locale 影响（关名仍是中文）', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('en')),
    );
    expect(levels.first.name, 'Morning Run');
    // 导出的是 zhName，不能跟着界面走。
    expect(mergeLevelToJson(levels.first)['name'], '清晨路段');
    expect(mergeLevelToJson(levels[699])['name'], levels[699].zhName);
  });

  /// 成就表是静态 final 列表，文案按 id 查表——漏一条 id 就会静默回落中文，
  /// 界面上一半英文一半中文，所以这里 73 条逐条过。
  testWidgets('英文 locale：成就标题与描述全部英文化', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('en')),
    );
    final cjk = RegExp(r'[\u4e00-\u9fff]');
    expect(achievements.length, greaterThanOrEqualTo(70));
    for (final a in achievements) {
      expect(cjk.hasMatch(a.title), isFalse,
          reason: '成就 ${a.id} 标题漏翻：${a.title}');
      expect(cjk.hasMatch(a.desc), isFalse,
          reason: '成就 ${a.id} 描述漏翻：${a.desc}');
    }
    // 分组名。
    for (final g in AchievementGroup.values) {
      expect(cjk.hasMatch(g.displayLabel), isFalse,
          reason: '成就分组 ${g.name} 漏翻：${g.displayLabel}');
    }
    expect(achievements.first.title, 'First Steps');
    expect(AchievementGroup.progress.displayLabel, 'Progress');
  });

  testWidgets('中文 locale：成就文案回到原文', (tester) async {
    await tester.pumpWidget(
      l10nHost(const SizedBox(), locale: const Locale('zh')),
    );
    for (final a in achievements) {
      expect(a.title, a.zhTitle, reason: '成就 ${a.id} 中文标题与 zhTitle 不一致');
      expect(a.desc, a.zhDesc, reason: '成就 ${a.id} 中文描述与 zhDesc 不一致');
    }
    for (final g in AchievementGroup.values) {
      expect(g.displayLabel, g.label);
    }
  });
}

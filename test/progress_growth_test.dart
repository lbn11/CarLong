import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';
import 'package:merge_fleet/services/level_data_generator.dart';
import 'package:merge_fleet/services/level_progression.dart';

/// 成长感三件套回归（2026-10-19）：
/// - Boss 徽章墙：defeatedBosses 持久化 + 生成侧 bossKey 不变量
/// - 历史最高连消：bestCombo 持久化 + 旧存档兼容
/// - 新车特写：首次合成新车弹非阻塞浮层
void main() {
  // ─────────────────────────────────────────────────────────────
  //  存档层（纯函数，快）
  // ─────────────────────────────────────────────────────────────

  test('PlayerData 序列化往返：defeatedBosses / bestCombo', () {
    final data = PlayerData(
      defeatedBosses: {'0.0', '3.2', '13.3'},
      bestCombo: 12,
    );
    final restored = PlayerData.fromJson(data.toJson());
    expect(restored.defeatedBosses, {'0.0', '3.2', '13.3'});
    expect(restored.bestCombo, 12);
  });

  test('旧存档兼容：没有新键时默认空集合 / 0，不崩', () {
    // 模拟三件套上线前的存档 JSON（只含老键）。
    final legacy = <String, dynamic>{
      'coins': 300,
      'unlockedLevel': 42,
      'bestScores': {'1': 100},
      'bestStars': {'1': 2},
      'collection': [3, 4],
      'soundOn': true,
      'vibrateOn': true,
    };
    final data = PlayerData.fromJson(legacy);
    expect(data.defeatedBosses, isEmpty);
    expect(data.bestCombo, 0);
    expect(data.coins, 300);
  });

  test('defeatedBosses 是引用语义：add 后 toJson 立即可见', () {
    final data = PlayerData();
    data.defeatedBosses.add('1.1');
    expect(PlayerData.fromJson(data.toJson()).defeatedBosses, contains('1.1'));
  });

  // ─────────────────────────────────────────────────────────────
  //  生成侧：bossKey 不变量（徽章墙的 key 必须稳定且唯一）
  // ─────────────────────────────────────────────────────────────

  test('bossKey：Boss 关全有、非 Boss 关全无、56 个唯一', () {
    final keys = <String>{};
    var bossCount = 0;
    for (final lvl in levels) {
      final isBoss = LevelProgression.isMergeBossLevel(lvl.id);
      if (!isBoss) {
        expect(lvl.bossKey, isNull, reason: 'id=${lvl.id} 非 Boss 关');
        expect(lvl.boss, isNull);
        continue;
      }
      bossCount++;
      expect(lvl.bossKey, isNotNull, reason: 'id=${lvl.id}');
      final key = lvl.bossKey!;
      expect(key, matches(RegExp(r'^\d{1,2}\.[0-3]$')),
          reason: 'id=${lvl.id} key=$key');
      expect(key, lvl.bossKey); // 自洽（防呆）
      keys.add(key);
    }
    expect(bossCount, 56);
    expect(keys.length, 56, reason: '56 枚徽章 key 必须唯一');
    expect(LevelDataGenerator.bossTotal, 56);
    expect(keys, contains('0.0')); // L81 = 章 0 第一个 Boss
  });

  test('bossKey 与 BossSpec.forLevel 参数同源：同 key 同卡组', () {
    for (final lvl in levels) {
      final key = lvl.bossKey;
      if (key == null) continue;
      final parts = key.split('.');
      final c = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      // 卡组确定性：同参数重建 spec，主/辅/绰号必须一致。
      final rebuilt = BossSpec.forLevel(c, b, lvl.boss!.hp);
      expect(rebuilt.primary, lvl.boss!.primary, reason: 'key=$key');
      expect(rebuilt.secondary, lvl.boss!.secondary, reason: 'key=$key');
      expect(rebuilt.epithet, lvl.boss!.epithet, reason: 'key=$key');
    }
  });

  // ─────────────────────────────────────────────────────────────
  //  新车特写（widget 级：真实对局里首次合成触发）
  // ─────────────────────────────────────────────────────────────

  testWidgets('首次合成新车弹特写浮层，不挡后续操作', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    // scooter 目标关：出牌全是 bicycle，两辆自行车必合出踏板车（新车）。
    final level = LevelDefinition(
      id: 9100,
      name: '新车特写测试关',
      cols: 4,
      rows: 4,
      stockSize: 20,
      targetTier: VehicleType.scooter,
      targetCount: 1,
    );
    final data = PlayerData();
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: ValueKey(level.id),
        level: level,
        data: data,
        repo: SaveRepository(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final gw = tester.widget<GameWidget>(
        find.byWidgetPredicate((w) => w is GameWidget));
    final game = gw.game as MergeGame;
    const gap = 6.0;

    Offset cellCenter(int col, int row) {
      final rect = tester.getRect(
          find.byWidgetPredicate((w) => w is GameWidget));
      final origin = game.boardOriginForTest;
      final cell = game.cellPx.value;
      return Offset(
        rect.left + origin.x + col * (cell + gap) + cell / 2,
        rect.top + origin.y + row * (cell + gap) + cell / 2,
      );
    }

    // 抽 4 张保证至少两辆自行车落盘。
    for (var i = 0; i < 4; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }

    // 反复抽牌 + tap-tap 合并，直到图鉴点亮（最多 30 轮）。
    // 不用单次两次 tap 赌稳定：真实对局就是反复尝试，
    // 且能容忍 Flame 手势循环的帧时序波动。
    var guard = 0;
    while (!data.collection.contains(VehicleType.scooter.id) && guard < 30) {
      guard++;
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 100));

      // 找一对同档自行车。
      (int, int)? from;
      (int, int)? to;
      for (var c = 0; c < 4 && from == null; c++) {
        for (var r = 0; r < 4 && from == null; r++) {
          final a = game.board.at(c, r);
          if (a == null || a.isEmpty) continue;
          for (var c2 = 0; c2 < 4 && to == null; c2++) {
            for (var r2 = 0; r2 < 4 && to == null; r2++) {
              if (c == c2 && r == r2) continue;
              final b = game.board.at(c2, r2);
              if (b != null && !b.isEmpty && b.tier == a.tier) {
                from = (c, r);
                to = (c2, r2);
              }
            }
          }
        }
      }
      if (from == null || to == null) continue;

      await tester.tapAt(cellCenter(from.$1, from.$2));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tapAt(cellCenter(to.$1, to.$2));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 图鉴已点亮 + 特写浮层出现。
    expect(data.collection, contains(VehicleType.scooter.id));
    expect(find.text('✨ 新车加入图鉴'), findsOneWidget);
    expect(find.text(VehicleType.scooter.name), findsOneWidget);

    // 浮层自动消失（不挡操作、不永久挂屏）。
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('✨ 新车加入图鉴'), findsNothing);
  });
}

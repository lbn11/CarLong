import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';
import 'package:merge_fleet/services/level_progression.dart';

/// Boss 战回归测试（2026-10-16）：
/// - 配置不变量：Boss 关才挂 BossSpec、HP = 目标数 +2、强制 produce、
///   无限时/限步（Boss 战不叠机制）；全表 56 个，位置与判定一致
/// - 战斗规则：合成目标车 = 扣 Boss 血；打空血条 → 胜利结算弹窗
/// - Boss 会动：预警后真的往棋盘扔冰块（obstacle 数量增加）
///
/// 测试关用 targetTier=scooter：spawnWeights 全部落在 bicycle，
/// 3 辆自行车必合出一辆踏板车（目标车），伤害链确定可复现。
LevelDefinition _bossLevel({
  int id = 9001,
  int hp = 3,
  double firstDelay = 9999,
  double interval = 9,
  int stock = 90,
}) {
  return LevelDefinition(
    id: id,
    name: '👑 Boss · 测试关',
    cols: 4,
    rows: 4,
    stockSize: stock,
    targetTier: VehicleType.scooter,
    targetCount: 1,
    boss: BossSpec(
      hp: hp,
      attackInterval: interval,
      firstDelay: firstDelay,
    ),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────
  //  配置不变量（纯函数，快）
  // ─────────────────────────────────────────────────────────────

  test('Boss 关配置：56 个、HP=目标数+2、produce、无时限/限步', () {
    var bossCount = 0;
    for (final lvl in levels) {
      final isBoss = LevelProgression.isMergeBossLevel(lvl.id);
      if (!isBoss) {
        expect(lvl.boss, isNull, reason: 'id=${lvl.id} 非 Boss 关不应挂 BossSpec');
        continue;
      }
      bossCount++;
      expect(lvl.boss, isNotNull, reason: 'id=${lvl.id}');
      expect(lvl.boss!.hp, lvl.targetCount + 2, reason: 'id=${lvl.id}');
      expect(lvl.boss!.hp, greaterThanOrEqualTo(3), reason: 'id=${lvl.id}');
      expect(lvl.goalType, GoalType.produce, reason: 'id=${lvl.id}');
      expect(lvl.timeLimitSeconds, isNull, reason: 'id=${lvl.id}');
      expect(lvl.movesLimit, isNull, reason: 'id=${lvl.id}');
      expect(lvl.targetTier, isNotNull, reason: 'id=${lvl.id}');
    }
    // 14 章 × 4 个 = 56（两心跳一 Boss，占轻松槽起）
    expect(bossCount, 56);
  });

  test('手写段（L1-70）与无尽/每日均无 Boss', () {
    for (var id = 1; id <= 70; id++) {
      expect(LevelProgression.isMergeBossLevel(id), isFalse, reason: 'id=$id');
      expect(levels[id - 1].boss, isNull, reason: 'id=$id');
    }
    expect(endlessLevel.boss, isNull);
  });

  test('Boss 关目标档位 = 普通关 +2（事件感：提前开出高阶车）', () {
    // L81 是章 0 的第 2 组 Boss 位：普通档 21 → Boss 23。
    final boss = levels[80];
    expect(LevelProgression.isMergeBossLevel(81), isTrue);
    expect(boss.targetTier!.index, 23);
  });

  // ─────────────────────────────────────────────────────────────
  //  战斗模拟（widget 级，驱动真实对局）
  // ─────────────────────────────────────────────────────────────

  /// 固定时长 pump（Flame 持续渲染，pumpAndSettle 不收敛）。
  Future<MergeGame> pumpBossGame(
    WidgetTester tester,
    LevelDefinition level,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: ValueKey(level.id),
        level: level,
        data: PlayerData(),
        repo: SaveRepository(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    final gw = tester.widget<GameWidget>(
        find.byWidgetPredicate((w) => w is GameWidget));
    return gw.game as MergeGame;
  }

  /// 格子中心的全局坐标（棋盘在 GameWidget 内居中，gap=6）。
  Offset cellCenter(WidgetTester tester, MergeGame game, int col, int row) {
    final rect = tester.getRect(
        find.byWidgetPredicate((w) => w is GameWidget));
    const gap = 6.0;
    final cell = game.cellPx.value;
    final boardW = game.level.cols * cell + gap * (game.level.cols - 1);
    final boardH = game.level.rows * cell + gap * (game.level.rows - 1);
    final ox = rect.left + (rect.width - boardW) / 2;
    final oy = rect.top + (rect.height - boardH) / 2;
    return Offset(
      ox + col * (cell + gap) + cell / 2,
      oy + row * (cell + gap) + cell / 2,
    );
  }

  Future<void> tapCell(
      WidgetTester tester, MergeGame game, int col, int row) async {
    await tester.tapAt(cellCenter(tester, game, col, row));
    await tester.pump(const Duration(milliseconds: 120));
  }

  /// 找一对可合并的同档车（优先落在 count==2 的堆上——一步升级）。
  /// 返回 (from, to)；找不到返回 null。
  ({(int, int) from, (int, int) to})? findMergePair(MergeGame game) {
    final cells = <({int col, int row, int count, VehicleType tier})>[];
    for (var c = 0; c < game.level.cols; c++) {
      for (var r = 0; r < game.level.rows; r++) {
        final d = game.board.at(c, r);
        if (d == null || d.isEmpty || d.isWildcard || d.isBomb) continue;
        cells.add((col: c, row: r, count: d.count, tier: d.tier));
      }
    }
    // 第一轮：找 count==2 的同档堆 + 任意同档车 → 直接升级。
    for (final a in cells) {
      if (a.count != 2) continue;
      for (final b in cells) {
        if ((b.col, b.row) == (a.col, a.row)) continue;
        if (b.tier == a.tier) {
          return (from: (b.col, b.row), to: (a.col, a.row));
        }
      }
    }
    // 第二轮：任意同档对。
    for (var i = 0; i < cells.length; i++) {
      for (var j = i + 1; j < cells.length; j++) {
        if (cells[i].tier == cells[j].tier) {
          return (
            from: (cells[i].col, cells[i].row),
            to: (cells[j].col, cells[j].row)
          );
        }
      }
    }
    return null;
  }

  testWidgets('Boss 战：目标车产出扣血，打空血条出胜利结算', (tester) async {
    final level = _bossLevel(hp: 3, firstDelay: 9999);
    final game = await pumpBossGame(tester, level);

    expect(game.bossMaxHp.value, 3);
    expect(game.bossHp.value, 3);

    // 出牌 + 贪心合并，直到 Boss 血条打空（最多 60 轮，足够 27 辆自行车）。
    var guard = 0;
    while (game.bossHp.value > 0 && guard < 60) {
      guard++;
      game.drawStock();
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 100));
      final pair = findMergePair(game);
      if (pair == null) continue;
      await tapCell(tester, game, pair.from.$1, pair.from.$2);
      await tapCell(tester, game, pair.to.$1, pair.to.$2);
    }

    expect(game.bossHp.value, 0,
        reason: '合成 3 辆目标车应打空 Boss 血条（guard=$guard）');
    expect(game.bossHp.value, lessThan(game.bossMaxHp.value));

    // 死亡演出 1.15s 后结算：弹窗标题说破「Boss 被击败」。
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('👑 Boss 击败！'), findsOneWidget);
  });

  testWidgets('Boss 会动手：预警后往棋盘扔冰块', (tester) async {
    // firstDelay/interval 都压到 0.6s：测试时间内必然发动攻击。
    final level = _bossLevel(id: 9002, hp: 99, firstDelay: 0.6, interval: 0.6);
    final game = await pumpBossGame(tester, level);

    // 先摆几辆车（也给"拖车"攻击准备目标）。
    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final obsBefore = _obstacleCount(game);
    expect(obsBefore, 0, reason: '测试关开局无障碍');

    // 攻击周期：idle 0.6 + stalk 0.65 + windup 0.95 + strike 0.34 ≈ 2.5s
    // 出手一次；再留余量给第二轮（拖车）。
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(_obstacleCount(game), greaterThan(0),
        reason: 'Boss 应往棋盘扔出至少一块冰');
    expect(game.hint.value, isNotNull);
    expect(game.hint.value!.contains('Boss'), isTrue,
        reason: '攻击要有提示说破：${game.hint.value}');
  });
}

/// 棋盘上当前生效的障碍物数量（Boss 落冰的直接证据）。
int _obstacleCount(MergeGame game) {
  var n = 0;
  for (var c = 0; c < game.level.cols; c++) {
    for (var r = 0; r < game.level.rows; r++) {
      if (game.board.obstacleAt(c, r) != null) n++;
    }
  }
  return n;
}

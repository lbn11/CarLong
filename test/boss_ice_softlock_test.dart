import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

/// 冰块软锁回归（2026-10-19，实玩复盘发现）：
///
/// Boss 的冰技能往空格扔 [ObstacleType.ice] 障碍，而冰块**只能被相邻合并
/// 融化**（没有自然消退）。玩家消极对局时棋盘被冰块逐个填满后：
///   isFull=true（障碍格视为占满）、hasPossibleMove=false（没车可合）、
///   hasFrozen/hasGlue=false（冻车安全阀不覆盖冰块）……
/// 于是死局收尾 _clearLowestAuto 只删车删不到冰，牌堆又永远抽不完
/// （drawStock 被 isFull 拒绝）——**对局永久挂死，游戏永不结束**。
///
/// 修复：融雪安全阀扩展到冰块（board.meltAllIceOneLayer），卡死时全场
/// 冰块每 2.5s 融 1 层，直到翻盘或走标准死局收尾。
LevelDefinition _lv({
  int cols = 2,
  int rows = 2,
  int stock = 40,
  VehicleType? target,
  BossSpec? boss,
}) =>
    LevelDefinition(
      id: 9401,
      zhName: '冰块软锁测试',
      cols: cols,
      rows: rows,
      stockSize: stock,
      goalType: GoalType.produce,
      targetTier: target ?? VehicleType.scooter,
      targetCount: 1,
      boss: boss,
    );

BossSpec _dormantBoss() => const BossSpec(
      hp: 5,
      attackInterval: 9,
      firstDelay: 9999, // 测试窗口内不攻击，只验证冰块/融雪本身
      primary: BossAttackKind.freeze,
    );

void main() {
  // ─────────────────────────────────────────────────────────────
  //  BoardLogic 纯逻辑：冰块 API 与占满判定
  // ─────────────────────────────────────────────────────────────

  test('冰块 API：hasIce / iceLayers / meltAllIceOneLayer', () {
    final b = BoardLogic(_lv());
    expect(b.hasIce, isFalse);
    expect(b.iceLayers, 0);
    expect(b.meltAllIceOneLayer(), 0, reason: '没有冰块时白跑一趟');

    b.addObstacle(ObstacleType.ice, 0, 0, layers: 2);
    b.addObstacle(ObstacleType.ice, 1, 1, layers: 1);
    expect(b.hasIce, isTrue);
    expect(b.iceLayers, 3);

    // 融一轮：两块各掉 1 层，1 层的那块归零（obstacleAt 只返回 active 的）。
    expect(b.meltAllIceOneLayer(), 2);
    expect(b.iceLayers, 1);
    expect(b.hasIce, isTrue);
    expect(b.obstacleAt(0, 0), isNotNull, reason: '还剩 1 层，仍然 active');
    expect(b.obstacleAt(1, 1), isNull, reason: '1 层的那块已归零移除');
    expect(b.meltAllIceOneLayer(), 1);
    expect(b.iceLayers, 0);
    expect(b.hasIce, isFalse);
    expect(b.obstacleAt(0, 0), isNull,
        reason: '层数归零必须标记 removed，格子重新可落子');
  });

  test('冰块填盘：isFull=true 且 isDeadlocked=true（无车可合）', () {
    final b = BoardLogic(_lv());
    // 空格上扔冰 → 占满但不提供任何可合资源。
    b.addObstacle(ObstacleType.ice, 0, 0, layers: 2);
    b.addObstacle(ObstacleType.ice, 1, 0, layers: 2);
    b.addObstacle(ObstacleType.ice, 0, 1, layers: 2);
    b.addObstacle(ObstacleType.ice, 1, 1, layers: 2);
    expect(b.hasIce, isTrue);
    expect(b.isFull, isTrue, reason: '障碍格视为占满');
    expect(b.hasPossibleMove, isFalse, reason: '没有车，无从可合');
    expect(b.isDeadlocked, isTrue, reason: '满盘 + 无步 = 死局');

    // 融掉两层后棋盘全空：脱离死局（玩家可以继续抽牌）。
    b.meltAllIceOneLayer();
    b.meltAllIceOneLayer();
    expect(b.hasIce, isFalse);
    expect(b.isFull, isFalse, reason: '冰块清空后格子重新可用');
    expect(b.isDeadlocked, isFalse);
  });

  test('removeLowest 删不到冰块：软锁必须靠融雪阀而不是死局收尾', () {
    final b = BoardLogic(_lv());
    for (var c = 0; c < 2; c++) {
      for (var r = 0; r < 2; r++) {
        b.addObstacle(ObstacleType.ice, c, r, layers: 2);
      }
    }
    expect(b.removeLowest(), isNull,
        reason: '死局收尾只删车；纯冰棋盘无车可删 → 修复前永久挂死');
    expect(b.hasIce, isTrue);
  });

  // ─────────────────────────────────────────────────────────────
  //  MergeGame 集成：融雪安全阀（冰块版）
  // ─────────────────────────────────────────────────────────────

  testWidgets('冰块填盘翻盘：融雪阀融冰 → 棋盘释放，游戏不结束', (tester) async {
    // 复现实玩场景：消极对局被 Boss 冰块填满 2x2 棋盘，牌堆还有牌。
    // 修复前：融雪阀只管冻车不管冰 → 死局收尾 no-op → 永久挂起。
    final level = _lv(stock: 40, boss: _dormantBoss());
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: const ValueKey(9401),
        level: level,
        data: PlayerData(),
        repo: SaveRepository(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final game = tester
        .widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget))
        .game as MergeGame;

    var gameOver = false;
    game.onGameOver = (_) => gameOver = true;

    // 用冰块填满整个棋盘（模拟 Boss 冰技能逐一扔冰的终点）。
    // 先清掉开局初始车——addObstacle 只扔空格，有车的格会被跳过。
    for (var c = 0; c < 2; c++) {
      for (var r = 0; r < 2; r++) {
        game.board.removeAt(c, r);
        game.board.addObstacle(ObstacleType.ice, c, r, layers: 2);
      }
    }
    expect(game.board.iceLayers, 8, reason: '4 格 × 2 层');
    expect(game.board.isFull, isTrue);
    expect(game.board.hasPossibleMove, isFalse);
    expect(game.board.isDeadlocked, isTrue);

    // 融雪进行中：3 秒时应已融掉一轮（每 2.5s 全场 1 层）。
    final hints = <String>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final h = game.hint.value;
      if (h != null && (h.isEmpty || hints.isEmpty || hints.last != h)) {
        hints.add(h);
      }
    }
    expect(game.board.iceLayers, lessThan(8), reason: '融雪阀应已启动');
    expect(gameOver, isFalse, reason: '融雪期间不判负');
    expect(hints.any((h) => h.contains('冰')), isTrue,
        reason: '提示要说破冰块在裂开：$hints');

    // 再跑 5 秒：两层全融 → 棋盘全空可落子 → 安全退出，游戏继续。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(game.board.iceLayers, 0, reason: '两层冰应全部融化');
    expect(game.board.hasIce, isFalse);
    expect(game.board.isFull, isFalse, reason: '格子释放，可以重新抽牌');
    expect(gameOver, isFalse,
        reason: '翻盘成功：不判负、不挂起，玩家可以继续玩');
  });

  testWidgets('冰块填盘保证终止：融完仍无路 → 死局收尾而不是永久挂起',
      (tester) async {
    // 牌堆耗尽 + 棋盘全冰：融化后棋盘全空、牌堆空、无可合 →
    // 必须走死局收尾（onGameOver 触发），绝不允许游戏挂着永不结束。
    final level = _lv(stock: 1, boss: _dormantBoss());
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: const ValueKey(9402),
        level: level,
        data: PlayerData(),
        repo: SaveRepository(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final game = tester
        .widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget))
        .game as MergeGame;

    var gameOver = false;
    game.onGameOver = (_) => gameOver = true;

    // 抽掉唯一一张牌：牌堆耗尽。
    game.drawStock();
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.stockLeft.value, 0, reason: '牌堆应已耗尽');

    // 冰块填满棋盘（先清掉开局初始车，保证 4 格全部上冰）。
    for (var c = 0; c < 2; c++) {
      for (var r = 0; r < 2; r++) {
        game.board.removeAt(c, r);
        game.board.addObstacle(ObstacleType.ice, c, r, layers: 2);
      }
    }
    expect(game.board.isDeadlocked, isTrue);

    // 跑到游戏结束（融雪 5s + 收尾），80 步 × 250ms = 20s 上限。
    for (var i = 0; i < 80 && !gameOver; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(gameOver, isTrue,
        reason: '融完仍无路 → 必须死局收尾，不能永久挂起');
    expect(game.board.iceLayers, 0, reason: '收尾前冰应已全融');
  });
}

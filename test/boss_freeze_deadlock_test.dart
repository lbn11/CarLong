import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

/// 冰封死局回归（2026-10-17，用户提问「Boss 把牌全冻住岂不是永远解冻不了」）：
///
/// 修复一：hasPossibleMove / isDeadlocked / hintMove 原先**把冻车当成可合
/// 资源**——「唯一同等级对是冻车」会被判成有步可走，死局检测不触发，
/// 玩家零操作而游戏永久挂起。现在全部跳过冻车。
///
/// 修复二：融雪安全阀——玩家真卡死（牌堆空或棋盘满 且 无可合步）时，
/// 全场冻车每 2.5s 融 1 层：要么等到翻盘时刻继续玩，要么全场融化后
/// 走死局收尾。保证「永远解冻不了」在设计上不可能发生。
LevelDefinition _lv({
  int cols = 5,
  int rows = 5,
  int stock = 40,
  VehicleType? target,
  BossSpec? boss,
}) =>
    LevelDefinition(
      id: 9301,
      name: '冰封死局测试',
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
      firstDelay: 9999, // 测试窗口内不攻击，只验证冰封/融雪本身
      primary: BossAttackKind.freeze,
    );

void main() {
  // ─────────────────────────────────────────────────────────────
  //  BoardLogic 纯逻辑：检测必须跳过冻车
  // ─────────────────────────────────────────────────────────────

  test('hasPossibleMove：唯一同等级对被冻住 → 无步可走；融化后恢复', () {
    final b = BoardLogic(_lv());
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.placeAt(2, 0, StackData(VehicleType.bicycle));
    expect(b.hasPossibleMove, isTrue);

    b.freezeAt(0, 0);
    b.freezeAt(2, 0);
    expect(b.hasPossibleMove, isFalse,
        reason: '冻住的车不可动不可被合，不能算可合资源');

    // 融 1 层（默认 2 层）：还冻着，依旧无步。
    expect(b.meltAllFrozenOneLayer(), 2);
    expect(b.hasPossibleMove, isFalse);
    expect(b.frozenLayers, 2, reason: '两辆车各剩 1 层');

    // 全部融化：恢复可合。
    expect(b.meltAllFrozenOneLayer(), 2);
    expect(b.frozenLayers, 0);
    expect(b.hasFrozen, isFalse);
    expect(b.hasPossibleMove, isTrue);
  });

  test('hasPossibleMove：冻住一对中的一辆也杀死这对（剩车没有搭档）', () {
    final b = BoardLogic(_lv());
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.placeAt(1, 0, StackData(VehicleType.bicycle));
    b.placeAt(3, 0, StackData(VehicleType.bicycle));
    b.freezeAt(0, 0);
    // (1,0)(3,0) 仍是未冻的一对 → 有步。
    expect(b.hasPossibleMove, isTrue);
    b.freezeAt(1, 0);
    b.freezeAt(3, 0);
    expect(b.hasPossibleMove, isFalse);
  });

  test('isDeadlocked：棋盘满 + 唯一同等级对是冻车 → 死局（修前是 false）', () {
    // 2x1 棋盘：放满两张自行车，全冻 → 无空格且无可合。
    final b = BoardLogic(_lv(cols: 2, rows: 1, stock: 0));
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.placeAt(1, 0, StackData(VehicleType.bicycle));
    expect(b.isFull, isTrue);
    expect(b.isDeadlocked, isFalse, reason: '没冻时有对可合');

    b.freezeAt(0, 0);
    b.freezeAt(1, 0);
    expect(b.isDeadlocked, isTrue,
        reason: '冻车不算可合资源，满盘无对即死局');
    expect(b.hasFrozen, isTrue);

    // 融雪后出现可合 → 脱离死局。
    b.meltAllFrozenOneLayer();
    b.meltAllFrozenOneLayer();
    expect(b.isDeadlocked, isFalse);
  });

  test('hintMove：不把冻住的车当提示目标', () {
    final b = BoardLogic(_lv());
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.placeAt(1, 0, StackData(VehicleType.bicycle));
    b.placeAt(3, 0, StackData(VehicleType.bicycle));
    b.placeAt(4, 0, StackData(VehicleType.bicycle));
    // 冻 (0,0)(1,0) 这一对；(3,0)(4,0) 是未冻对。
    b.freezeAt(0, 0);
    b.freezeAt(1, 0);

    final hint = b.hintMove();
    expect(hint, isNotNull, reason: '未冻对应给出提示');
    final touched = [
      (hint!.fc, hint.fr),
      (hint.tc, hint.tr),
    ];
    for (final (c, r) in touched) {
      expect(b.at(c, r)!.frozen, 0, reason: '提示不能落在冻车上');
    }

    // 只剩冻对 → 无提示。
    b.freezeAt(3, 0);
    b.freezeAt(4, 0);
    expect(b.hintMove(), isNull);
  });

  test('融雪 API：hasFrozen / frozenLayers / meltAllFrozenOneLayer', () {
    final b = BoardLogic(_lv());
    expect(b.hasFrozen, isFalse);
    expect(b.frozenLayers, 0);
    expect(b.meltAllFrozenOneLayer(), 0, reason: '没有冻车时白跑一趟');

    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.freezeAt(0, 0, layers: 3);
    expect(b.hasFrozen, isTrue);
    expect(b.frozenLayers, 3);
    expect(b.meltAllFrozenOneLayer(), 1);
    expect(b.frozenLayers, 2);
    expect(b.at(0, 0)!.frozen, 2);
  });

  // ─────────────────────────────────────────────────────────────
  //  MergeGame 集成：融雪安全阀（用户的原始担忧场景）
  // ─────────────────────────────────────────────────────────────

  testWidgets('全冻翻盘：棋盘满+全冻 → 融雪后恢复可合，游戏不结束', (tester) async {
    // 2x2 小棋盘：两对同等级车，全部冻住。牌堆还有牌但棋盘满了，
    // 抽不了也合不了——正是「永远解冻不了」的担忧场景。
    final level = _lv(cols: 2, rows: 2, stock: 40, boss: _dormantBoss());
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: const ValueKey(9301),
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

    // 铺满并全冻。
    game.board.placeAt(0, 0, StackData(VehicleType.bicycle));
    game.board.placeAt(1, 0, StackData(VehicleType.bicycle));
    game.board.placeAt(0, 1, StackData(VehicleType.motorcycle));
    game.board.placeAt(1, 1, StackData(VehicleType.motorcycle));
    for (var c = 0; c < 2; c++) {
      for (var r = 0; r < 2; r++) {
        game.board.freezeAt(c, r);
      }
    }
    expect(game.board.frozenLayers, 8, reason: '4 辆车 × 2 层');
    expect(game.board.hasPossibleMove, isFalse);
    expect(game.board.isFull, isTrue);

    // 融雪进行中：3 秒时应已融掉一轮（每层 2.5s）。
    final hints = <String>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final h = game.hint.value;
      if (h != null && (h.isEmpty || hints.isEmpty || hints.last != h)) {
        hints.add(h);
      }
    }
    expect(game.board.frozenLayers, lessThan(8), reason: '融雪阀应已启动');
    expect(gameOver, isFalse, reason: '融雪期间不判负');
    expect(hints.any((h) => h.contains('冰层')), isTrue,
        reason: '提示要说破冰层在减弱：$hints');

    // 再跑 5 秒：两层全融 → 出现可合 → 安全退出，游戏继续。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(game.board.frozenLayers, 0, reason: '两层冰应全部融化');
    expect(game.board.hasFrozen, isFalse);
    expect(game.board.hasPossibleMove, isTrue,
        reason: '融化后自行车对恢复可合');
    expect(gameOver, isFalse,
        reason: '翻盘成功：不判负、不挂起，玩家可以继续玩');
  });

  testWidgets('全冻保证终止：融完仍无对 → 死局收尾而不是永久挂起', (tester) async {
    // 牌堆只有 1 张：抽掉它把牌堆耗尽，再摆 4 张互异档位的车全冻。
    // 融化后依然没有可合对 → 必须走死局收尾（onGameOver 触发），
    // 绝不允许游戏挂着永不结束。
    // （不能直接用 stockSize 0：空棋盘+空牌堆开局第一帧就死局，
    // 车还来不及摆——那是退化关卡，不是本测试要的场景。）
    final level = _lv(cols: 2, rows: 2, stock: 1, boss: _dormantBoss());
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: const ValueKey(9302),
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

    // 抽掉唯一一张牌：牌堆耗尽（开局还有 1 张垫底牌，无所谓——
    // 下面把 4 格全部覆写成互异档位，保证融化后全场没有可合对）。
    game.drawStock();
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.stockLeft.value, 0, reason: '牌堆应已耗尽');

    const distinct = [
      VehicleType.bicycle,
      VehicleType.motorcycle,
      VehicleType.truck,
      VehicleType.bus,
    ];
    var di = 0;
    for (var c = 0; c < 2; c++) {
      for (var r = 0; r < 2; r++) {
        game.board.placeAt(c, r, StackData(distinct[di++]));
      }
    }
    for (var c = 0; c < 2; c++) {
      for (var r = 0; r < 2; r++) {
        game.board.freezeAt(c, r);
      }
    }
    expect(game.board.frozenLayers, 8);
    expect(game.board.isFull, isTrue);
    expect(game.board.hasPossibleMove, isFalse);

    // 跑到游戏结束（融雪 5s + 收尾），80 步 × 250ms = 20s 上限。
    for (var i = 0; i < 80 && !gameOver; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(gameOver, isTrue,
        reason: '融化后仍无对 → 必须死局收尾，不能永久挂起');
    expect(game.board.frozenLayers, 0, reason: '收尾前冰应已全融');
  });
}

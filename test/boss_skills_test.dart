import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

/// Boss 新技能回归测试（2026-10-17，卡组制扩容）：
/// - 卡组工厂：确定性、同章不重样、招牌绰号、池子按章解锁
/// - 塌方：落碎石占格（障碍物数增加）
/// - 扣押：车被拖进车库，到期放回（车数先减后恢复）
/// - 退化：最高档原料车降档/被拆（hint 说破）
/// - 污染：taintCards 计数 + 抽牌递减
/// - 护盾：盾期间打 Boss 不扣血，盾消失后恢复扣血
LevelDefinition _skillLevel({
  required BossAttackKind primary,
  int id = 9201,
  int hp = 99,
  double firstDelay = 0.6,
  double interval = 0.6,
  int impoundSeconds = 3,
  int taintCards = 2,
  double shieldCycle = 0,
  double shieldDuration = 3,
}) {
  return LevelDefinition(
    id: id,
    name: '👑 Boss · 技能测试关',
    cols: 4,
    rows: 4,
    stockSize: 90,
    targetTier: VehicleType.scooter,
    targetCount: 1,
    boss: BossSpec(
      hp: hp,
      attackInterval: interval,
      firstDelay: firstDelay,
      primary: primary,
      impoundSeconds: impoundSeconds,
      taintCards: taintCards,
      shieldCycle: shieldCycle,
      shieldDuration: shieldDuration,
    ),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────
  //  卡组工厂（纯函数）
  // ─────────────────────────────────────────────────────────────

  test('卡组工厂：确定性（同章同序号两次生成一致）', () {
    for (var c = 0; c < 14; c++) {
      for (var b = 0; b < 4; b++) {
        final a = BossSpec.forLevel(c, b, 10);
        final d = BossSpec.forLevel(c, b, 10);
        expect(a.primary, d.primary, reason: '章$c Boss$b 主技应确定');
        expect(a.secondary, d.secondary, reason: '章$c Boss$b 辅技应确定');
        expect(a.epithet, d.epithet);
        expect(a.shieldCycle, d.shieldCycle);
      }
    }
  });

  test('卡组工厂：新手期池子只有冰封+拖车，尖峰有招牌', () {
    for (var b = 0; b < 3; b++) {
      final spec = BossSpec.forLevel(0, b, 10);
      expect(
          {spec.primary, spec.secondary},
          anyOf(
            {BossAttackKind.freeze, BossAttackKind.steal},
            {BossAttackKind.steal, BossAttackKind.freeze},
          ),
          reason: '章0 普通 Boss 只应会冰封+拖车');
    }
    // 章 0-1 尖峰招牌：碎石王 / 回收站。
    expect(BossSpec.forLevel(0, 3, 10).epithet, '碎石王');
    expect(BossSpec.forLevel(1, 3, 10).epithet, '回收站');
    // 终局招牌：终局车王，冰封 + 扣押 + 护盾。
    final last = BossSpec.forLevel(13, 3, 10);
    expect(last.epithet, '终局车王');
    expect(last.primary, BossAttackKind.freeze);
    expect(last.secondary, BossAttackKind.impound);
    expect(last.shieldCycle, greaterThan(0));
  });

  test('卡组工厂：参数按章缩放（冰封数/扣押秒/污染张/护盾）', () {
    final early = BossSpec.forLevel(0, 0, 10);
    expect(early.freezeCount, 1);
    expect(early.stealTopTier, isFalse);
    expect(early.lockStockSeconds, 0);
    expect(early.enrageAtHalf, isFalse);
    expect(early.shieldCycle, 0, reason: '章 9 前无护盾光环');

    final mid = BossSpec.forLevel(4, 0, 10);
    expect(mid.stealTopTier, isTrue, reason: '章 3+ 抢高档');
    expect(mid.devolveLevels, 1);

    final late = BossSpec.forLevel(12, 0, 10);
    expect(late.enrageAtHalf, isTrue, reason: '章 11+ 狂怒');
    expect(late.impoundSeconds, greaterThan(early.impoundSeconds));
    expect(late.taintCards, 3);
  });

  // ─────────────────────────────────────────────────────────────
  //  战斗模拟（widget 级，驱动真实对局）
  // ─────────────────────────────────────────────────────────────

  Future<MergeGame> pumpSkillGame(WidgetTester tester, LevelDefinition level,
      {Duration settle = const Duration(milliseconds: 150)}) async {
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
    await tester.pump(settle);
    await tester.pump(settle);
    final gw = tester.widget<GameWidget>(
        find.byWidgetPredicate((w) => w is GameWidget));
    return gw.game as MergeGame;
  }

  /// 循环 pump 直到 [done] 命中或超时（Boss 攻击周期约 2.5s）。
  Future<bool> pumpUntil(
      WidgetTester tester, bool Function() done, int steps) async {
    for (var i = 0; i < steps; i++) {
      if (done()) return true;
      await tester.pump(const Duration(milliseconds: 150));
    }
    return done();
  }

  testWidgets('塌方：Boss 落碎石占格（障碍物数增加、提示说破）', (tester) async {
    final level = _skillLevel(primary: BossAttackKind.rubble, id: 9211);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final obsBefore = _obstacleCount(game);
    expect(obsBefore, 0, reason: '测试关无预置障碍');

    final hit = await pumpUntil(
        tester, () => _obstacleCount(game) > obsBefore, 40);
    expect(hit, isTrue, reason: '塌方应落下至少一块碎石');
    expect(game.hint.value, isNotNull);
    expect(game.hint.value!.contains('Boss'), isTrue,
        reason: '提示要说破：${game.hint.value}');
  });

  testWidgets('扣押：车被拖进车库后到期放回', (tester) async {
    final level = _skillLevel(
        primary: BossAttackKind.impound, id: 9212, impoundSeconds: 2);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final carsBefore = _carCount(game);
    expect(carsBefore, greaterThan(0));

    // 等扣押出手：车数下降即被拖走。
    final taken = await pumpUntil(
        tester, () => _carCount(game) < carsBefore, 40);
    expect(taken, isTrue, reason: '扣押应拖走一辆车');
    final carsLow = _carCount(game);
    expect(carsLow, carsBefore - 1, reason: '一次扣押一张');

    // 扣押 2 秒：到期放回（棋盘有空格，智能落位）。
    final back =
        await pumpUntil(tester, () => _carCount(game) > carsLow, 40);
    expect(back, isTrue, reason: '扣押到期应放回场上');
  });

  testWidgets('退化：最高档原料车被降档或拆掉', (tester) async {
    final level = _skillLevel(primary: BossAttackKind.devolve, id: 9213);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    // 退化出手的证据：hint 说破（降档或拆底两分支都含关键词）。
    final hit = await pumpUntil(
        tester,
        () =>
            game.hint.value != null &&
            (game.hint.value!.contains('退化') ||
                game.hint.value!.contains('拆掉')),
        40);
    expect(hit, isTrue, reason: '退化应命中并提示，实际 hint=${game.hint.value}');
  });

  testWidgets('污染：计数生效且抽牌递减', (tester) async {
    final level = _skillLevel(
        primary: BossAttackKind.taint, id: 9214, taintCards: 2);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final tainted = await pumpUntil(
        tester, () => game.taintCards.value > 0, 40);
    expect(tainted, isTrue, reason: '污染技能应置计数');
    expect(game.taintCards.value, 2);
    expect(game.hint.value, isNotNull);
    expect(game.hint.value!.contains('污染'), isTrue);

    // 抽牌消耗污染计数。
    game.drawStock();
    await tester.pump(const Duration(milliseconds: 80));
    expect(game.taintCards.value, 1);
    game.drawStock();
    await tester.pump(const Duration(milliseconds: 80));
    expect(game.taintCards.value, 0);
  });

  testWidgets('护盾：盾期间产出不扣血，盾消失后恢复', (tester) async {
    // cycle 30s / duration 3s：前 3 秒开盾，之后长时间空白，测试可控。
    final level = _skillLevel(
      primary: BossAttackKind.freeze,
      id: 9215,
      hp: 2,
      firstDelay: 9999,
      shieldCycle: 30,
      shieldDuration: 3,
    );
    final game = await pumpSkillGame(tester, level);

    // 开局盾开（相位 0 < duration）。
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.bossShielded.value, isTrue, reason: '开局护盾应张开');

    // 盾期间打 Boss：不扣血。
    var guard = 0;
    while (game.produced.value == 0 && guard < 60) {
      guard++;
      game.drawStock();
      game.drawStock();
      final pair = findMergePair(game);
      if (pair != null) {
        await tapCell(tester, game, pair.from.$1, pair.from.$2);
        await tapCell(tester, game, pair.to.$1, pair.to.$2);
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.produced.value, greaterThan(0), reason: '应合出了目标车');
    expect(game.bossHp.value, 2, reason: '盾期间不应扣血');

    // 等盾消失（duration 3s 过完）。
    final down = await pumpUntil(
        tester, () => game.bossShielded.value == false, 40);
    expect(down, isTrue, reason: '护盾应到期消失');

    // 再打：恢复扣血（棋盘满就先洗牌解锁，避免空转）。
    guard = 0;
    while (game.bossHp.value == 2 && guard < 120) {
      guard++;
      if (game.board.isFull) game.shuffleBoard();
      game.drawStock();
      game.drawStock();
      final pair = findMergePair(game);
      if (pair != null) {
        await tapCell(tester, game, pair.from.$1, pair.from.$2);
        await tapCell(tester, game, pair.to.$1, pair.to.$2);
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.bossHp.value, lessThan(2), reason: '盾消失后应扣血');
  });
}

// ─────────────────────────────────────────────────────────────
//  辅助（与 boss_fight_test 同款，复制以保持测试文件独立）
// ─────────────────────────────────────────────────────────────

int _obstacleCount(MergeGame game) {
  var n = 0;
  for (var c = 0; c < game.level.cols; c++) {
    for (var r = 0; r < game.level.rows; r++) {
      if (game.board.obstacleAt(c, r) != null) n++;
    }
  }
  return n;
}

int _carCount(MergeGame game) {
  var n = 0;
  for (var c = 0; c < game.level.cols; c++) {
    for (var r = 0; r < game.level.rows; r++) {
      final d = game.board.at(c, r);
      if (d != null && !d.isEmpty) n++;
    }
  }
  return n;
}

Offset _cellCenter(WidgetTester tester, MergeGame game, int col, int row) {
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
  await tester.tapAt(_cellCenter(tester, game, col, row));
  await tester.pump(const Duration(milliseconds: 120));
}

({(int, int) from, (int, int) to})? findMergePair(MergeGame game) {
  final cells = <({int col, int row, int count, VehicleType tier})>[];
  for (var c = 0; c < game.level.cols; c++) {
    for (var r = 0; r < game.level.rows; r++) {
      final d = game.board.at(c, r);
      if (d == null || d.isEmpty || d.isWildcard || d.isBomb) continue;
      cells.add((col: c, row: r, count: d.count, tier: d.tier));
    }
  }
  for (final a in cells) {
    if (a.count != 2) continue;
    for (final b in cells) {
      if ((b.col, b.row) == (a.col, a.row)) continue;
      if (b.tier == a.tier) {
        return (from: (b.col, b.row), to: (a.col, a.row));
      }
    }
  }
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

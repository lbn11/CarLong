import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/logic/board_logic.dart';
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
  double glueSeconds = 4,
  double holeSeconds = 6,
  double banSeconds = 4,
  int fogCells = 2,
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
      glueSeconds: glueSeconds,
      holeSeconds: holeSeconds,
      banSeconds: banSeconds,
      fogCells: fogCells,
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

  // ─────────────────────────────────────────────────────────────
  //  第二批技能（2026-10-18）：纯逻辑（BoardLogic 直驱）
  // ─────────────────────────────────────────────────────────────

  test('胶水状态：粘住 → locked 阻断 → 到期自动干掉', () {
    final board = _board();
    board.placeAt(0, 0, StackData(VehicleType.bicycle));
    board.placeAt(1, 0, StackData(VehicleType.bicycle));
    board.glueAt(0, 0, 3);
    expect(board.at(0, 0)!.locked, isTrue);
    // 胶车不能动、不能被合（与冰封同一 locked 阻断面）。
    expect(board.move(0, 0, 1, 0).valid, isFalse);
    expect(board.move(1, 0, 0, 0).valid, isFalse);
    expect(board.hasGlue, isTrue);
    expect(board.glueLeft, closeTo(3, 0.001));

    // 倒计时递减，归零解封。
    expect(board.tickGlue(1), 0);
    expect(board.glueLeft, closeTo(2, 0.001));
    expect(board.tickGlue(2), 1, reason: '返回干掉的张数');
    expect(board.hasGlue, isFalse);
    expect(board.move(0, 0, 1, 0).valid, isTrue, reason: '解封后能合');
  });

  test('死局感知：唯一可合对被胶水粘住 → 无步可走、hint 不指它', () {
    final board = _board();
    board.placeAt(0, 0, StackData(VehicleType.bicycle));
    board.placeAt(1, 0, StackData(VehicleType.bicycle));
    expect(board.hasPossibleMove, isTrue);
    board.glueAt(0, 0, 4);
    expect(board.hasPossibleMove, isFalse,
        reason: '粘住的车不算可合资源（防软锁）');
    expect(board.hintMove(), isNull, reason: 'hint 不能指向粘住的车');
  });

  test('黑洞：占格挡落点 + 拖进去被吞 + 到期闭合', () {
    final board = _board();
    board.placeAt(0, 0, StackData(VehicleType.bicycle));
    board.placeAt(1, 0, StackData(VehicleType.bicycle));
    board.addHole(2, 0, 5);
    expect(board.holeAt(2, 0), isTrue);
    expect(board.holeLeftAt(2, 0), closeTo(5, 0.001));

    // 占格：落点永远避开黑洞（4x4 有 13 个可用空格）。
    for (var i = 0; i < 12; i++) {
      final cell = board.placeTierSmart(VehicleType.bicycle);
      expect(cell, isNotNull);
      expect(board.holeAt(cell!.col, cell.row), isFalse);
    }

    // 拖卡进黑洞：被吞（valid 但不结算合并，源格清空）。
    final r = board.move(0, 0, 2, 0);
    expect(r.valid, isTrue);
    expect(r.swallowed, isTrue);
    expect(board.at(0, 0), isNull);
    expect(board.at(2, 0), isNull, reason: '黑洞格本身不落卡');

    // 到期闭合。
    expect(board.tickHoles(5), 1);
    expect(board.hasHoles, isFalse);
    expect(board.holeAt(2, 0), isFalse);
  });

  test('洗牌：多重集合不变、冻车原地不动', () {
    final board = _board();
    board.placeAt(0, 0, StackData(VehicleType.bicycle));
    board.placeAt(0, 1, StackData(VehicleType.sedan));
    board.placeAt(1, 0, StackData(VehicleType.bus));
    board.placeAt(1, 1, StackData(VehicleType.bicycle));
    board.freezeAt(1, 1); // 冻住 (1,1) 的自行车

    final n = board.shuffleUnlocked();
    expect(n, 3, reason: '只有 3 张没冻/粘的车参与重排');

    // 冻车没动（冰封叙事是「原地救车」，不能被洗走）。
    expect(board.at(1, 1)!.tier, VehicleType.bicycle);
    expect(board.at(1, 1)!.frozen, greaterThan(0));

    // 多重集合不变。
    final tiers = <VehicleType>[];
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        final d = board.at(c, r);
        if (d != null && !d.isEmpty) tiers.add(d.tier);
      }
    }
    tiers.sort((a, b) => a.index.compareTo(b.index));
    expect(tiers, [
      VehicleType.bicycle,
      VehicleType.bicycle,
      VehicleType.sedan,
      VehicleType.bus,
    ]);
  });

  test('迷雾：盖住 + 落子揭开（远处的雾不揭）', () {
    final board = _board();
    board.placeAt(2, 2, StackData(VehicleType.bicycle));
    expect(board.isFogged(2, 2), isFalse);
    board.fogCellsAt([
      (col: 2, row: 2),
      (col: 0, row: 0),
    ]);
    expect(board.isFogged(2, 2), isTrue);
    expect(board.isFogged(0, 0), isTrue);
    board.revealNear(2, 2);
    expect(board.isFogged(2, 2), isFalse);
    expect(board.isFogged(0, 0), isTrue, reason: '远处的雾不该被揭');
  });

  // ─────────────────────────────────────────────────────────────
  //  第二批技能（2026-10-18）：widget 级（驱动真实对局）
  // ─────────────────────────────────────────────────────────────

  testWidgets('胶水：车被定时粘住，到期自动干掉', (tester) async {
    final level = _skillLevel(
        primary: BossAttackKind.glue, id: 9216, glueSeconds: 2, interval: 30);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final glued = await pumpUntil(tester, () => game.board.hasGlue, 60);
    expect(glued, isTrue, reason: '胶水应粘住一辆车');
    expect(game.hint.value, isNotNull);
    expect(game.hint.value!.contains('胶水'), isTrue);

    // 粘住的车合不了（board.move 直接验证 locked 阻断面）。
    ({int col, int row})? gluedCell() {
      for (var c = 0; c < game.level.cols; c++) {
        for (var r = 0; r < game.level.rows; r++) {
          final d = game.board.at(c, r);
          if (d != null && !d.isEmpty && d.glueT > 0) return (col: c, row: r);
        }
      }
      return null;
    }

    final gc = gluedCell();
    expect(gc, isNotNull);
    // 找一个空格：胶车挪不过去。
    var target = (-1, -1);
    outer:
    for (var c = 0; c < game.level.cols; c++) {
      for (var r = 0; r < game.level.rows; r++) {
        final d = game.board.at(c, r);
        if (d == null || d.isEmpty) {
          target = (c, r);
          break outer;
        }
      }
    }
    expect(target.$1, greaterThanOrEqualTo(0));
    expect(game.board.move(gc!.col, gc.row, target.$1, target.$2).valid, isFalse,
        reason: '胶水期间挪不动');

    // 到期自动干掉（glueSeconds=2）。
    final dried = await pumpUntil(tester, () => !game.board.hasGlue, 60);
    expect(dried, isTrue, reason: '胶水应到点自动干掉');
    expect(game.hint.value, contains('胶水干'));
  });

  testWidgets('黑洞：占格期间抽牌落不进旋涡，到期闭合', (tester) async {
    final level = _skillLevel(
        primary: BossAttackKind.hole, id: 9217, holeSeconds: 2, interval: 30);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final holed = await pumpUntil(tester, () => game.board.hasHoles, 60);
    expect(holed, isTrue, reason: '黑洞应出现');
    expect(game.hint.value, isNotNull);
    expect(game.hint.value!.contains('黑洞'), isTrue);

    // 占格期间抽牌：永远落不进黑洞（placeTierSmart 避开）。
    ({int col, int row})? holeCell() {
      for (var c = 0; c < game.level.cols; c++) {
        for (var r = 0; r < game.level.rows; r++) {
          if (game.board.holeAt(c, r)) return (col: c, row: r);
        }
      }
      return null;
    }

    final hc = holeCell();
    expect(hc, isNotNull);
    for (var i = 0; i < 8; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(game.board.at(hc!.col, hc.row), isNull,
        reason: '黑洞格不能被落牌占据');

    // 到期闭合。
    final closed = await pumpUntil(tester, () => !game.board.hasHoles, 60);
    expect(closed, isTrue, reason: '黑洞应到期闭合');
    expect(game.hint.value, contains('黑洞闭合'));
  });

  testWidgets('洗牌：布局被打乱但车辆集合不变', (tester) async {
    final level = _skillLevel(
        primary: BossAttackKind.shuffle, id: 9218, interval: 30);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 8; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    List<VehicleType> tiersNow() {
      final tiers = <VehicleType>[];
      for (var c = 0; c < game.level.cols; c++) {
        for (var r = 0; r < game.level.rows; r++) {
          final d = game.board.at(c, r);
          if (d != null && !d.isEmpty) tiers.add(d.tier);
        }
      }
      tiers.sort((a, b) => a.index.compareTo(b.index));
      return tiers;
    }

    final before = tiersNow();
    expect(before.length, greaterThanOrEqualTo(4), reason: '场上要有车可洗');

    final shuffled = await pumpUntil(
        tester, () => game.hint.value?.contains('洗牌') ?? false, 60);
    expect(shuffled, isTrue, reason: '洗牌应出手并说破');
    expect(tiersNow(), before, reason: '洗牌不增不减车辆');
  });

  testWidgets('禁合：该档合并被拒，到期恢复', (tester) async {
    final level = _skillLevel(
        primary: BossAttackKind.ban, id: 9219, banSeconds: 3, interval: 30);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 8; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final banned = await pumpUntil(tester, () => game.banActive, 60);
    expect(banned, isTrue, reason: '禁合应生效');
    expect(game.banTier, isNotNull);
    expect(game.hint.value, isNotNull);
    expect(game.hint.value!.contains('禁合'), isTrue);

    // 找两张被禁档位的车（没有就摆两张）：点选合并 → 应被拒。
    final tier = game.banTier!;
    ({int col, int row})? findCar(VehicleType t, {({int col, int row})? skip}) {
      for (var c = 0; c < game.level.cols; c++) {
        for (var r = 0; r < game.level.rows; r++) {
          if (skip != null && skip.col == c && skip.row == r) continue;
          final d = game.board.at(c, r);
          if (d != null && !d.isEmpty && !d.isWildcard && !d.isBomb &&
              d.tier == t) {
            return (col: c, row: r);
          }
        }
      }
      return null;
    }

    var a = findCar(tier);
    var b = a == null ? null : findCar(tier, skip: a);
    if (a == null || b == null) {
      // 场上凑不齐两张：摆两张再重刷精灵表（shuffleBoard 内部
      // _syncSpritesFromBoard，直接 placeAt 是没有精灵的，点不到）。
      final empties = <({int col, int row})>[];
      for (var c = 0; c < game.level.cols; c++) {
        for (var r = 0; r < game.level.rows; r++) {
          final d = game.board.at(c, r);
          if (d == null || d.isEmpty) empties.add((col: c, row: r));
        }
      }
      if (empties.length >= 2) {
        game.board.placeAt(empties[0].col, empties[0].row, StackData(tier));
        game.board.placeAt(empties[1].col, empties[1].row, StackData(tier));
        game.shuffleBoard();
        a = findCar(tier);
        b = a == null ? null : findCar(tier, skip: a);
      }
    }
    expect(a, isNotNull, reason: '场上应有被禁档位的车');
    expect(b, isNotNull);

    await tapCell(tester, game, a!.col, a.row);
    await tapCell(tester, game, b!.col, b.row);
    await tester.pump(const Duration(milliseconds: 120));
    expect(game.board.at(a.col, a.row), isNotNull,
        reason: '禁合期间合并应被拒，车没动');
    expect(game.board.at(b.col, b.row), isNotNull);
    expect(game.hint.value, contains('禁合'));

    // 到期恢复：同样的两步合并成功（b 格变成 2 张）。
    final recovered = await pumpUntil(tester, () => !game.banActive, 60);
    expect(recovered, isTrue, reason: '禁合应到期解除');
    await tapCell(tester, game, a.col, a.row);
    await tapCell(tester, game, b.col, b.row);
    await tester.pump(const Duration(milliseconds: 120));
    final srcAfter = game.board.at(a.col, a.row);
    expect(srcAfter == null || srcAfter.isEmpty, isTrue,
        reason: '解禁后合并成功，源格清空');
    expect(game.board.at(b.col, b.row)!.count, greaterThanOrEqualTo(2));
  });

  testWidgets('抢目标：Boss 受伤后才可放，命中回 1 血', (tester) async {
    // interval 3s：首次攻击（满血 → 无可抢 → 退化成扔冰）之后很快
    // 就有第二击；测试窗口（pumpUntil 60 步 ≈ 9s）内必须吃到抢目标。
    final level = _skillLevel(
        primary: BossAttackKind.stealGoal, id: 9220, hp: 5, interval: 3);
    final game = await pumpSkillGame(tester, level);

    // 先打掉 1 血：满血时抢目标不可用（没东西可抢，天然防连放）。
    var guard = 0;
    while (game.bossHp.value == 5 && guard < 100) {
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
    final before = game.bossHp.value;
    expect(before, lessThan(5), reason: '至少打掉 1 血才能被抢');
    expect(before, greaterThan(0), reason: '别把 Boss 打死了');

    // 等抢目标出手：血涨回去（只有抢目标会加血）。
    final stolen = await pumpUntil(
        tester, () => game.bossHp.value > before, 60);
    expect(stolen, isTrue, reason: '抢目标应把血抢回去');
    expect(game.hint.value, contains('抢'));
  });

  testWidgets('迷雾：盖住的车看不见，落子附近揭开', (tester) async {
    final level = _skillLevel(
        primary: BossAttackKind.fog, id: 9221, fogCells: 2, interval: 30);
    final game = await pumpSkillGame(tester, level);

    for (var i = 0; i < 8; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final fogged = await pumpUntil(
        tester, () => game.hint.value?.contains('迷雾') ?? false, 60);
    expect(fogged, isTrue, reason: '迷雾应出手并说破');

    // 有车被盖住。
    var foggedCars = 0;
    for (var c = 0; c < game.level.cols; c++) {
      for (var r = 0; r < game.level.rows; r++) {
        final d = game.board.at(c, r);
        if (d != null && !d.isEmpty && game.board.isFogged(c, r)) {
          foggedCars++;
        }
      }
    }
    expect(foggedCars, greaterThan(0), reason: '迷雾应盖住车');

    // 落子揭开：在一张被盖的车旁合并/落子 → 雾散。
    ({int col, int row})? foggedCell() {
      for (var c = 0; c < game.level.cols; c++) {
        for (var r = 0; r < game.level.rows; r++) {
          final d = game.board.at(c, r);
          if (d != null && !d.isEmpty && game.board.isFogged(c, r)) {
            return (col: c, row: r);
          }
        }
      }
      return null;
    }

    final fc = foggedCell();
    expect(fc, isNotNull);
    game.board.revealNear(fc!.col, fc.row);
    expect(game.board.isFogged(fc.col, fc.row), isFalse,
        reason: '落子附近应揭开迷雾');
  });
}

/// 第二批技能的纯逻辑棋盘（4x4 无障碍）。
BoardLogic _board() => BoardLogic(LevelDefinition(
      id: 9990,
      name: '逻辑测试关',
      cols: 4,
      rows: 4,
      stockSize: 10,
      targetTier: VehicleType.scooter,
      targetCount: 1,
    ));

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

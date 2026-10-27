import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';
import 'package:merge_fleet/services/level_progression.dart';

import 'helpers/localized_app.dart';

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
  bool stealTop = false,
  double lockSec = 0,
  bool enrage = false,
  BossAttackKind primary = BossAttackKind.freeze,
  BossAttackKind? secondary,
  int freezeCount = 1,
  int rubbleCount = 1,
  int impoundSeconds = 3,
  int taintCards = 2,
  int devolveLevels = 1,
  double shieldCycle = 0,
  double shieldDuration = 3,
  String? bossKey,
}) {
  return LevelDefinition(
    id: id,
    zhName: '👑 Boss · 测试关',
    cols: 4,
    rows: 4,
    stockSize: stock,
    targetTier: VehicleType.scooter,
    targetCount: 1,
    boss: BossSpec(
      hp: hp,
      attackInterval: interval,
      firstDelay: firstDelay,
      primary: primary,
      secondary: secondary,
      stealTopTier: stealTop,
      lockStockSeconds: lockSec,
      enrageAtHalf: enrage,
      freezeCount: freezeCount,
      rubbleCount: rubbleCount,
      impoundSeconds: impoundSeconds,
      taintCards: taintCards,
      devolveLevels: devolveLevels,
      shieldCycle: shieldCycle,
      shieldDuration: shieldDuration,
    ),
    bossKey: bossKey,
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
    LevelDefinition level, {
    PlayerData? data,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(l10nHost(
      GameScreen(
        key: ValueKey(level.id),
        level: level,
        data: data ?? PlayerData(),
        repo: SaveRepository(),
      ),
      locale: const Locale('zh'),
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
    // 必须用游戏真实 boardOrigin：Boss 关为悬浮位预留空间后棋盘不再
    // 垂直居中（2026-10-19 压棋盘修复），按居中公式算会点偏格子。
    final origin = game.boardOriginForTest;
    return Offset(
      rect.left + origin.x + col * (cell + gap) + cell / 2,
      rect.top + origin.y + row * (cell + gap) + cell / 2,
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

  testWidgets('Boss 胜利点亮徽章墙 key 并刷新最高连消纪录', (tester) async {
    // 2026-10-19 成长感三件套之一：击败 Boss = 徽章墙点亮（稳定 key
    // 「章.序号」），同局 maxCombo > 旧 bestCombo 时写档。
    final data = PlayerData();
    final level = _bossLevel(hp: 3, firstDelay: 9999, bossKey: '0.0');
    final game = await pumpBossGame(tester, level, data: data);

    expect(data.defeatedBosses, isEmpty);
    expect(data.bestCombo, 0);

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
    expect(game.bossHp.value, 0, reason: 'guard=$guard');

    // 结算弹窗出现时写档已完成：徽章点亮 + 连消纪录 ≥ 本局值。
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('👑 Boss 击败！'), findsOneWidget);
    expect(data.defeatedBosses, contains('0.0'));
    expect(data.bestCombo, greaterThanOrEqualTo(game.maxCombo));
    expect(data.bestCombo, greaterThanOrEqualTo(2),
        reason: '连合 3 次目标车必然触发连消窗口');
  });

  testWidgets('Boss 会动手：技能池至少出一种（冰封/偷车/锁牌堆/扔冰）', (tester) async {
    // firstDelay/interval 都压到 0.6s：测试时间内必然发动攻击。
    // 默认 spec = 章 0 语义（只会冰封 + 拖最低档 + 冰块填充）。
    final level = _bossLevel(id: 9002, hp: 99, firstDelay: 0.6, interval: 0.6);
    final game = await pumpBossGame(tester, level);

    // 先摆几辆车（给冰封/拖车准备目标）。
    for (var i = 0; i < 6; i++) {
      game.drawStock();
      await tester.pump(const Duration(milliseconds: 80));
    }
    final carsBefore = _carCount(game);
    expect(carsBefore, greaterThan(0));

    // 攻击周期：idle 0.6 + stalk 0.65 + windup 0.95 + strike 0.34 ≈ 2.5s
    // 出手一次；再留余量给第二轮。
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // 攻击证据（任一成立即算 Boss 真的动了手）：
    final froze = _frozenCount(game) > 0;
    final iced = _obstacleCount(game) > 0;
    final locked = game.stockLocked.value;
    final stolen = _carCount(game) < carsBefore;
    expect(froze || iced || locked || stolen, isTrue,
        reason: 'Boss 应发动至少一种攻击（冻=$froze 冰=$iced 锁=$locked 偷=$stolen）');
    expect(game.hint.value, isNotNull);
    expect(game.hint.value!.contains('Boss'), isTrue,
        reason: '攻击要有提示说破：${game.hint.value}');
  });

  testWidgets('锁牌堆：锁定期间 drawStock 无效，解封后恢复', (tester) async {
    final level = _bossLevel(id: 9003, hp: 99, firstDelay: 9999);
    final game = await pumpBossGame(tester, level);
    final before = game.stockLeft.value;

    // 正常出牌扣牌堆。
    game.drawStock();
    await tester.pump(const Duration(milliseconds: 60));
    expect(game.stockLeft.value, before - 1);

    // Boss 上锁：出牌被拦（MergeGame.drawStock 内的拦截 + UI 置锁）。
    game.stockLocked.value = true;
    final lockedAt = game.stockLeft.value;
    game.drawStock();
    game.drawStock();
    await tester.pump(const Duration(milliseconds: 60));
    expect(game.stockLeft.value, lockedAt, reason: '锁定期牌堆不应减少');
    expect(game.hint.value, isNotNull);

    // 解封恢复。
    game.stockLocked.value = false;
    game.drawStock();
    await tester.pump(const Duration(milliseconds: 60));
    expect(game.stockLeft.value, lockedAt - 1);
  });

  testWidgets('狂怒：半血触发 bossEnraged（章 11+ 专属）', (tester) async {
    final level = _bossLevel(id: 9004, hp: 4, firstDelay: 9999, enrage: true);
    final game = await pumpBossGame(tester, level);
    expect(game.bossEnraged.value, isFalse);

    // 合成目标车打 Boss：4 血打到 2（= 半血）应触发狂怒。
    var guard = 0;
    while (!game.bossEnraged.value && guard < 60) {
      guard++;
      game.drawStock();
      game.drawStock();
      final pair = findMergePair(game);
      if (pair != null) {
        await tapCell(tester, game, pair.from.$1, pair.from.$2);
        await tapCell(tester, game, pair.to.$1, pair.to.$2);
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    expect(game.bossEnraged.value, isTrue, reason: '半血应触发狂怒');
    expect(game.bossHp.value, 2);
  });

  test('Boss 技能成长线：按章节解锁（章0 冰封 / 章3 抢高档 / 章7 锁牌堆 / 章11 狂怒）', () {
    // 每章第一个 Boss 的落点（章内偏移 10）。
    const ids = {0: 81, 3: 216, 7: 396, 11: 576};
    for (final e in ids.entries) {
      final lvl = levels[e.value - 1];
      final spec = lvl.boss;
      expect(spec, isNotNull, reason: '章${e.key} L${e.value} 应是 Boss 关');
      final c = e.key;
      expect(spec!.stealTopTier, c >= 3, reason: '章$c stealTopTier');
      expect(spec.lockStockSeconds > 0, c >= 7, reason: '章$c lockStock');
      expect(spec.enrageAtHalf, c >= 11, reason: '章$c enrage');
      // 冰封张数：章 11+ 恒 2；章 3+ 卡组含冰封也 2（提前登场）；
      // 章 0 保护期内 1；章 7 的 0 号位（impound+shuffle）不含冰封 → 1。
      const freezeCounts = {0: 1, 3: 2, 7: 1, 11: 2};
      expect(spec.freezeCount, freezeCounts[c], reason: '章$c freezeCount');
      expect(spec.freezeLayers, 2, reason: '章$c freezeLayers');
    }
  });

  test('Boss 关 id 公式与全表实际落点一致（调试面板 56 关列表同源）', () {
    // 生成器选点：章内偏移 10 + b×11。调试面板的 _allBossIds 用的是
    // 同一个公式，这里反向钉死：公式集合 == 全表 boss != null 的集合，
    // 防止一边改了另一边漂移（调面板时少关/多关立刻暴露）。
    final expected = <int>{};
    for (var c = 0; c < 14; c++) {
      for (var b = 0; b < 4; b++) {
        expected.add(71 + c * 45 + 10 + b * 11);
      }
    }
    final actual = <int>{};
    for (final lvl in levels) {
      if (lvl.boss != null) actual.add(lvl.id);
    }
    expect(actual.length, 56, reason: '全表应有 56 个 Boss 关');
    expect(actual, expected, reason: 'Boss 关落点应与公式一致');
  });

  test('Boss 卡组制：同章 4 个卡组不重样、尖峰有招牌、全表覆盖多技能', () {
    // 每章 4 个 Boss（章内偏移 10/21/32/43），起始 id = 71 + 章×45。
    final decksByChapter = <int, Set<String>>{};
    final primaries = <BossAttackKind>{};
    for (var c = 0; c < 14; c++) {
      decksByChapter[c] = {};
      for (var b = 0; b < 4; b++) {
        final id = 71 + c * 45 + 10 + b * 11;
        final spec = levels[id - 1].boss;
        expect(spec, isNotNull, reason: 'L$id 应是 Boss 关');
        expect(spec!.primary, isNotNull);
        expect(spec.secondary, isNotNull, reason: 'L$id 卡组应有辅技能');
        decksByChapter[c]!.add('${spec.primary.name}+${spec.secondary!.name}');
        primaries.add(spec.primary);
        if (b == 3) {
          // 尖峰位：招牌 Boss，绰号非空。
          expect(spec.epithet, isNotNull, reason: 'L$id 尖峰应有招牌绰号');
        } else {
          expect(spec.epithet, isNull, reason: 'L$id 普通卡组不应有绰号');
        }
      }
    }
    // 同章 4 个 Boss 卡组：章 2+ 池子 ≥4 种，4 个互不相同；
    // 章 0-1 池子只有 2 个技能（新手期），0/2 号位主技相同属刻意设计
    // ——先让玩家把冰封+拖车练熟，再上卡组多样性。
    for (final e in decksByChapter.entries) {
      expect(
          e.value.length,
          e.key <= 1 ? greaterThanOrEqualTo(3) : 4,
          reason: '章${e.key} 4 个 Boss 卡组应互不相同，实际 ${e.value.length}');
    }
    // 全表 56 个 Boss 至少覆盖 5 种不同主技能（卡组制不是换皮）。
    expect(primaries.length, greaterThanOrEqualTo(5),
        reason: '主技能种类：$primaries');
    // 末章（全池）：4 个 Boss 主技 ≥3 种、主辅合计覆盖 ≥5 个技能
    // （组合互异已由上面的循环断言；招牌主技允许与普通位相同）。
    final lastPrimaries = <BossAttackKind>{};
    final lastSkills = <BossAttackKind>{};
    for (var b = 0; b < 4; b++) {
      final id = 71 + 13 * 45 + 10 + b * 11;
      final spec = levels[id - 1].boss!;
      lastPrimaries.add(spec.primary);
      lastSkills.add(spec.primary);
      lastSkills.add(spec.secondary!);
    }
    expect(lastPrimaries.length, greaterThanOrEqualTo(3),
        reason: '末章主技种类：$lastPrimaries');
    expect(lastSkills.length, greaterThanOrEqualTo(5),
        reason: '末章技能覆盖：$lastSkills');

    // 第二批技能（2026-10-18）六个新技能在全表至少各出现一次
    // （主或辅）——入池不是摆设，玩家真的能见到。
    const secondBatch = {
      BossAttackKind.glue,
      BossAttackKind.hole,
      BossAttackKind.shuffle,
      BossAttackKind.ban,
      BossAttackKind.stealGoal,
      BossAttackKind.fog,
    };
    final seen = <BossAttackKind>{};
    for (var c = 0; c < 14; c++) {
      for (var b = 0; b < 4; b++) {
        final s = BossSpec.forLevel(c, b, 10);
        seen.add(s.primary);
        if (s.secondary != null) seen.add(s.secondary!);
      }
    }
    for (final k in secondBatch) {
      expect(seen, contains(k), reason: '第二批技能 $k 应在全表出现');
    }
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

/// 棋盘上被 Boss 冰封的车辆数（冰封技能的直接证据）。
int _frozenCount(MergeGame game) {
  var n = 0;
  for (var c = 0; c < game.level.cols; c++) {
    for (var r = 0; r < game.level.rows; r++) {
      final d = game.board.at(c, r);
      if (d != null && !d.isEmpty && d.frozen > 0) n++;
    }
  }
  return n;
}

/// 棋盘上的车辆数（拖车技能的直接证据：变少即被偷）。
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

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';
import 'package:merge_fleet/services/level_data_generator.dart';

import 'helpers/localized_app.dart';

/// 参考时间（par）回归测试（2026-10-17，方案 B 落地）：
/// - parSeconds：全表覆盖、随章节增长、Boss 按 HP 折算、清盘关有值、无尽为 0
/// - paceRatio：实时倍率外推模型（抽牌速率 + 收尾系数）、开局保护、
///   手快>1/手慢<1 方向、牌堆抽空退化
/// - beatPar / parBonusCoins：纯函数语义（边界、失败、钳制）
/// - HUD：无硬限时的关卡显示 pace 倍率徽章（⚡1.4×），限时关不显示
///
/// 设计背景：Boss 关不加硬限时（末章 Boss 正常打 3-5 分钟，时钟会砍死它；
/// Boss 每 9 秒一招不看玩家节奏，本身就是反磨蹭机制），改用软 par：
/// 超时不罚，比参考时间块有速通奖。HUD 表达从「⏱ 用时/参考」双数字
/// （要玩家心算差值）换成倍率徽章（>1 金 = 可速通，<1 灰 = 无奖励不罚）。
/// 常数 parSecPerDraw=3.0 待埋点（level_end.elapsed_s / beat_par）校准。
void main() {
  // ─────────────────────────────────────────────────────────────
  //  parSeconds（纯函数）
  // ─────────────────────────────────────────────────────────────

  test('parSeconds：全表非无尽关都有正参考时间', () {
    var checked = 0;
    for (final lvl in levels) {
      if (lvl.endless) continue;
      expect(LevelDataGenerator.parSeconds(lvl), greaterThan(0),
          reason: 'L${lvl.id}（${lvl.goalType.name}）应有 par');
      checked++;
    }
    expect(checked, levels.length, reason: '主表应无无尽关');
  });

  test('parSeconds：无尽模式为 0（不适用）', () {
    final endless = LevelDefinition(
      id: 9999,
      name: '无尽',
      cols: 6,
      rows: 6,
      stockSize: 90,
      targetTier: VehicleType.taxi,
      targetCount: 1,
      endless: true,
    );
    expect(LevelDataGenerator.parSeconds(endless), 0);
    expect(
        LevelDataGenerator.beatPar(endless, won: true, elapsedSeconds: 1),
        isFalse,
        reason: '无尽关无 par，永不应判速通');
  });

  test('parSeconds：随章节增长（章均 par 末章 > 首章）', () {
    double chapterMean(int chapterIdx) {
      final pars = levels
          .where((l) =>
              !l.endless &&
              l.goalType == GoalType.produce &&
              l.boss == null &&
              l.id >= 71 &&
              (l.id - LevelDataGenerator.firstId) ~/
                  LevelDataGenerator.chapterSize ==
                  chapterIdx)
          .map(LevelDataGenerator.parSeconds);
      return pars.reduce((a, b) => a + b) / pars.length;
    }

    final early = chapterMean(0);
    final late = chapterMean(13);
    expect(late, greaterThan(early * 2),
        reason: '末章普通关均 par(${late.round()}s) 应显著大于首章'
            '(${early.round()}s)——目标档位深度翻倍');
  });

  test('parSeconds：Boss 关按 HP 折算，显著高于邻居普通关', () {
    // 章内偏移 % 11 == 10 的 Boss 落点及其后一个普通关。
    const pairs = {81: 82, 216: 217, 396: 397, 576: 577, 699: 700};
    for (final e in pairs.entries) {
      final bossLvl = levels[e.key - 1];
      final normalLvl = levels[e.value - 1];
      expect(bossLvl.boss, isNotNull, reason: 'L${e.key} 应是 Boss 关');
      final bossPar = LevelDataGenerator.parSeconds(bossLvl);
      final normalPar = LevelDataGenerator.parSeconds(normalLvl);
      expect(bossPar, greaterThan(normalPar),
          reason: 'L${e.key} Boss par(${bossPar.round()}s) 应高于邻居'
              'L${e.value}(${normalPar.round()}s)');
    }
  });

  test('parSeconds：Boss 公式 = expectedDraws × hp/count × 常数', () {
    final bossLvl = levels[576 - 1]; // 章 11 深水区 Boss
    final expected = LevelDataGenerator.expectedDraws(bossLvl);
    final want = expected *
        bossLvl.boss!.hp /
        bossLvl.targetCount *
        LevelDataGenerator.parSecPerDraw;
    expect(LevelDataGenerator.parSeconds(bossLvl), closeTo(want, 0.001));
    // 终局车王：par 在 3-4 分钟区间（不打硬限时的依据）。
    final lastBoss = LevelDataGenerator.parSeconds(levels[699 - 1]);
    expect(lastBoss, greaterThan(180));
    expect(lastBoss, lessThan(300));
  });

  test('parSeconds：清盘关走牌堆口径（正值，且大于同牌堆 produce 关量级）', () {
    // L70 / L700 是手写/生成的清盘关。
    for (final id in [70, 700]) {
      final lvl = levels[id - 1];
      expect(lvl.goalType, GoalType.clearBoard);
      final par = LevelDataGenerator.parSeconds(lvl);
      expect(par, greaterThan(60), reason: 'L$id 清盘 par=$par');
      expect(par, closeTo(lvl.stockSize * 0.75 * 3.0, 0.001));
    }
  });

  // ─────────────────────────────────────────────────────────────
  //  beatPar / parBonusCoins（纯函数）
  // ─────────────────────────────────────────────────────────────

  test('beatPar：边界（== par 算达成）、超时/失败不算', () {
    final lvl = levels[81 - 1];
    final par = LevelDataGenerator.parSeconds(lvl);
    expect(LevelDataGenerator.beatPar(lvl, won: true, elapsedSeconds: par),
        isTrue,
        reason: '正好压线算达成');
    expect(
        LevelDataGenerator.beatPar(lvl, won: true, elapsedSeconds: par + 0.1),
        isFalse,
        reason: '超参考线不判速通（但也不罚）');
    expect(LevelDataGenerator.beatPar(lvl, won: false, elapsedSeconds: 1),
        isFalse,
        reason: '输了永远不算');
  });

  test('parBonusCoins：score/20 钳制在 20-150，未达成为 0', () {
    final lvl = levels[81 - 1];
    final par = LevelDataGenerator.parSeconds(lvl);
    int bonus(int score) => LevelDataGenerator.parBonusCoins(lvl,
        won: true, elapsedSeconds: par - 1, score: score);

    expect(bonus(100), 20, reason: '低分保底 20');
    expect(bonus(1000), 50, reason: '中段按 score/20');
    expect(bonus(99999), 150, reason: '高分封顶 150');
    expect(
        LevelDataGenerator.parBonusCoins(lvl,
            won: true, elapsedSeconds: par + 5, score: 99999),
        0,
        reason: '超时无奖金');
    expect(
        LevelDataGenerator.parBonusCoins(lvl,
            won: false, elapsedSeconds: 1, score: 99999),
        0,
        reason: '失败无奖金');
  });

  // ─────────────────────────────────────────────────────────────
  //  paceRatio（纯函数）
  // ─────────────────────────────────────────────────────────────

  test('paceRatio：开局保护（elapsed≤0 / 无尽为 0）', () {
    final lvl = levels[81 - 1];
    expect(
        LevelDataGenerator.paceRatio(lvl, elapsed: 0, stockLeft: 90), 0,
        reason: '开局零秒不显示徽章');
    expect(
        LevelDataGenerator.paceRatio(lvl, elapsed: -1, stockLeft: 90), 0,
        reason: '负时间防御');
    final endless = LevelDefinition(
      id: 9998,
      name: '无尽',
      cols: 6,
      rows: 6,
      stockSize: 90,
      targetTier: VehicleType.taxi,
      targetCount: 1,
      endless: true,
    );
    expect(
        LevelDataGenerator.paceRatio(endless, elapsed: 30, stockLeft: 60), 0,
        reason: '无尽无 par 无徽章');
  });

  test('paceRatio：攒料期只有先验兜底（温和值，不 0.0× 吓人）', () {
    final lvl = levels[81 - 1]; // Boss 关：need = hp
    final par = LevelDataGenerator.parSeconds(lvl);
    final need = lvl.boss!.hp;
    // 10 秒零进度：prior = 已用 + 剩余 × (par/need) = 10 + par。
    final p = LevelDataGenerator.paceRatio(lvl,
        elapsed: 10, stockLeft: 80, bossHp: need);
    expect(p, closeTo(par / (10 + par), 0.001));
    expect(p, lessThan(1));
    expect(p, greaterThan(0.5),
        reason: '开局先验应给温和值（已用远小于 par 时接近 1）');
  });

  test('paceRatio：手快 >1、手慢 <1（方向正确）', () {
    final lvl = levels[82 - 1]; // 普通 produce 关
    final par = LevelDataGenerator.parSeconds(lvl);
    final need = lvl.targetCount;
    // 手快：6 秒产出 1/need（obs=6 < par）。
    final fast = LevelDataGenerator.paceRatio(lvl,
        elapsed: 6, stockLeft: 80, produced: 1);
    expect(fast, greaterThan(1), reason: '手快应显示可速通');
    // 手慢：60 秒才产出 1/need。
    final slow = LevelDataGenerator.paceRatio(lvl,
        elapsed: 60, stockLeft: 80, produced: 1);
    expect(slow, lessThan(1));
    expect(slow, lessThan(fast));
    expect(par, greaterThan(0));
    expect(need, greaterThan(0));
  });

  test('paceRatio：进度过 25% 后观测接管（先验+观测线性融合）', () {
    final lvl = levels[699 - 1]; // 末章终局 Boss（need 最大，融合区可观测）
    final par = LevelDataGenerator.parSeconds(lvl);
    final need = lvl.boss!.hp;
    // 深章攒料期典型值：100 秒只打了 1 下。
    const elapsed = 100.0;
    const done = 1;
    final progress = done / need;
    expect(progress, lessThan(LevelDataGenerator.paceObsFloor),
        reason: '深章早期进度应落在融合区');
    final prior = elapsed + (need - done) * (par / need);
    final obs = elapsed / progress;
    final w = progress / LevelDataGenerator.paceObsFloor;
    final want = prior + w * (obs - prior);
    final p = LevelDataGenerator.paceRatio(lvl,
        elapsed: elapsed, stockLeft: 200, bossHp: need - done);
    expect(p, closeTo(par / want, 0.001));
    // 纯 obs 会比融合值更极端（观测被先验拉住）——验证融合确实在生效。
    expect(par / obs, lessThan(par / want));
  });

  test('paceRatio：Boss 关进度按剩余 HP 折算', () {
    final lvl = levels[81 - 1];
    final par = LevelDataGenerator.parSeconds(lvl);
    final need = lvl.boss!.hp;
    // 满血 = 零进度；打掉一半 → progress 0.5。
    final half = LevelDataGenerator.paceRatio(lvl,
        elapsed: 18, stockLeft: 80, bossHp: (need / 2).round());
    final done = (need - (need / 2).round()).toDouble();
    final progress = done / need;
    final prior = 18 + (need - done) * (par / need);
    final obs = 18 / progress;
    final w = (progress / LevelDataGenerator.paceObsFloor).clamp(0.0, 1.0);
    expect(half, closeTo(par / (prior + w * (obs - prior)), 0.001));
    // 满血零进度 < 半血有进度（同 elapsed 下）。
    final full = LevelDataGenerator.paceRatio(lvl,
        elapsed: 18, stockLeft: 80, bossHp: need);
    expect(full, lessThan(half), reason: '有进度应比零进度乐观');
  });

  test('paceRatio：清盘关走牌堆外推（剩牌=剩余工作量）', () {
    final lvl = levels[70 - 1];
    expect(lvl.goalType, GoalType.clearBoard);
    final par = LevelDataGenerator.parSeconds(lvl);
    // 30 秒抽了 10 张（3s/张）：projected = 30 + 剩牌 × 3 × 1.25。
    final stockLeft = lvl.stockSize - 10;
    final p = LevelDataGenerator.paceRatio(lvl,
        elapsed: 30, stockLeft: stockLeft);
    final projected = 30 + stockLeft * 3.0 * LevelDataGenerator.paceTailFactor;
    expect(p, closeTo(par / projected, 0.001));
    // 抽空牌堆：退化为 par / 已用时间。
    final drained = LevelDataGenerator.paceRatio(lvl,
        elapsed: par * 0.8, stockLeft: 0);
    expect(drained, closeTo(par / (par * 0.8), 0.001));
    expect(drained, greaterThan(1));
  });

  test('paceRatio：Boss 关与普通关同输入时 Boss 更宽松（par 折算 HP）', () {
    final bossLvl = levels[81 - 1]; // Boss 关
    final normalLvl = levels[82 - 1]; // 邻居普通关
    final bossPar = LevelDataGenerator.parSeconds(bossLvl);
    final normalPar = LevelDataGenerator.parSeconds(normalLvl);
    // 同 elapsed/零进度：Boss 关 prior 的剩余按 hp 折算，pace 更高。
    final bossPace = LevelDataGenerator.paceRatio(bossLvl,
        elapsed: 30, stockLeft: 60, bossHp: bossLvl.boss!.hp);
    final normalPace = LevelDataGenerator.paceRatio(normalLvl,
        elapsed: 30, stockLeft: 60, produced: 0);
    expect(bossPar, greaterThan(normalPar));
    expect(bossPace, greaterThan(normalPace),
        reason: 'Boss 关 par 已按 hp 折算，同零进度下倍率更宽松');
  });

  // ─────────────────────────────────────────────────────────────
  //  HUD 徽章（widget 级）
  // ─────────────────────────────────────────────────────────────

  /// 休眠 Boss 测试关：不攻击、无硬限时 → pace 徽章应显示。
  LevelDefinition parLevel({int id = 9301}) {
    return LevelDefinition(
      id: id,
      name: '👑 Boss · par 测试关',
      cols: 4,
      rows: 4,
      stockSize: 90,
      targetTier: VehicleType.scooter,
      targetCount: 1,
      boss: BossSpec(hp: 99, firstDelay: 9999),
    );
  }

  testWidgets('HUD：无硬限时关卡显示 pace 倍率徽章', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(l10nHost(
      GameScreen(
        key: const ValueKey(9301),
        level: parLevel(),
        data: PlayerData(),
        repo: SaveRepository(),
      ),
      locale: const Locale('zh'),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    final game = tester
        .widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget))
        .game as MergeGame;

    // 开局 elapsed=0 → pace=0 → 徽章不显示（开局保护）。
    expect(find.textContaining(RegExp(r'\d\.\d×')), findsNothing,
        reason: '开局零秒不显示徽章');

    // 走 2.2 秒（跨过 0.25s 节流）：徽章出现。
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(game.elapsedTick.value, greaterThanOrEqualTo(2));
    expect(game.pace.value, greaterThan(0), reason: '引擎应产出 pace 值');
    expect(find.textContaining(RegExp(r'\d\.\d×')), findsOneWidget,
        reason: 'pace 徽章应在 HUD 显示');
  });

  testWidgets('HUD：限时关不显示 pace 徽章（倒计时独占）', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: const ValueKey(9302),
        level: LevelDefinition(
          id: 9302,
          name: '限时测试关',
          cols: 4,
          rows: 4,
          stockSize: 60,
          targetTier: VehicleType.scooter,
          targetCount: 1,
          timeLimitSeconds: 120,
        ),
        data: PlayerData(),
        repo: SaveRepository(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.textContaining(RegExp(r'⏱ \d+ s')), findsOneWidget,
        reason: '限时关显示倒计时');
    expect(find.textContaining(RegExp(r'\d\.\d×')), findsNothing,
        reason: '限时关不叠 pace 徽章');
  });

  testWidgets('暂停面板：显示 用时/参考/预计 三数据块', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(l10nHost(
      GameScreen(
        key: const ValueKey(9303),
        level: parLevel(id: 9303),
        data: PlayerData(),
        repo: SaveRepository(),
      ),
      locale: const Locale('zh'),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    // 点暂停 → 弹窗。
    await tester.tap(find.byIcon(Icons.pause_circle_outline));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('用时'), findsOneWidget);
    expect(find.text('参考'), findsOneWidget);
    expect(find.text('预计'), findsOneWidget);
  });
}

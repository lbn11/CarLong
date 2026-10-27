import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

/// 2026-10-19 浏览器实玩 L81 复盘（两层结论）：
///
/// **① 终局判负本身合规。** 像素级解码终局截图：5×5 棋盘、9 块冰、
/// 1 辆面包车、右下角两辆**相邻**飞越（🚇）、牌堆已空。此时确有合法
/// 合并（hasPossibleMove=true）。但对话框截图比该状态晚 68 秒，且底部
/// 显示「💧 冰块全部融化！」——融雪阀只在 hasPossibleMove=false 时启动，
/// 说明判负前那对飞越已不存在（被合掉或被 Boss 拖走）。牌堆耗尽时原料
/// 链凑不齐 3 张高铁，失败是设计内的，「看广告续命·牌堆+2」正是为此。
///
/// **② 但挖出真正的语义缺口（本文件第 4、5 个用例钉死）：**
/// [BoardLogic.move] 是格对格合并——任意两张同档非冻车点哪都能合，
/// 不看距离/空格通路（UI 高亮 _canMergeWith 与 hintMove 同口径）。
/// 而旧 hasPossibleMove 却要求 BFS 空格通路或相邻交换（W1 滑块合并
/// 时代遗留）：被别的车墙隔开的同档对会被误判「无路可走」，牌堆空时
/// 直接误判负——hint 按钮却能指出那一步，自相矛盾。
void main() {
  LevelDefinition bossLevel() {
    return LevelDefinition(
      id: 9001,
      zhName: 'test',
      cols: 5,
      rows: 5,
      stockSize: 0, // 牌堆直接空
      targetTier: VehicleType.highspeed,
      targetCount: 1,
      boss: BossSpec(hp: 3, attackInterval: 9999, firstDelay: 9999),
    );
  }

  void clearBoard(BoardLogic board, {int cols = 5, int rows = 5}) {
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        board.removeAt(c, r);
      }
    }
  }

  test('两张相邻干净的目标档原料车：hasPossibleMove 必须为 true', () {
    final board = BoardLogic(bossLevel());
    clearBoard(board);
    board.placeAt(3, 3, StackData(VehicleType.subway));
    board.placeAt(4, 3, StackData(VehicleType.subway));
    expect(board.hasPossibleMove, isTrue,
        reason: '两张同档相邻车必须算有步可走，否则牌堆空时会被误判负');
  });

  test('四周被冰块包围的两张相邻原料车：仍应可合（冰不挡相邻合并）', () {
    final board = BoardLogic(bossLevel());
    clearBoard(board);
    board.placeAt(3, 3, StackData(VehicleType.subway));
    board.placeAt(4, 3, StackData(VehicleType.subway));
    // 复盘时棋盘四周有冰块；相邻合并不依赖通路，冰块不该让这对变不可合。
    board.addObstacle(ObstacleType.ice, 3, 2);
    board.addObstacle(ObstacleType.ice, 4, 2);
    board.addObstacle(ObstacleType.ice, 2, 3);
    expect(board.hasPossibleMove, isTrue,
        reason: '冰块在别处不挡相邻同档对');
  });

  test('竖直相邻的两张原料车：hasPossibleMove 必须为 true', () {
    final board = BoardLogic(bossLevel());
    clearBoard(board);
    // 复盘实测形态：同列相邻（col4, row3+row4）。
    board.placeAt(4, 3, StackData(VehicleType.subway));
    board.placeAt(4, 4, StackData(VehicleType.subway));
    expect(board.hasPossibleMove, isTrue);
    // 且合并合法。
    final mv = board.move(4, 3, 4, 4);
    expect(mv.valid, isTrue, reason: '两张 subway 合并应合法');
  });

  test('语义缺口：被车墙隔开的同档对，move 合法 ⇒ 死局检测必须放行', () {
    // 修复前 hasPossibleMove 要求 BFS 空格通路/相邻交换（比 move() 严）：
    // 对角两张 subway + 中间填满自行车墙 → 旧实现判 false（误判负），
    // 而 move()/hintMove()/UI 高亮都认为点一下就能合。
    final board = BoardLogic(bossLevel());
    clearBoard(board);
    board.placeAt(0, 0, StackData(VehicleType.subway));
    board.placeAt(4, 4, StackData(VehicleType.subway));
    for (var c = 0; c < 5; c++) {
      for (var r = 0; r < 5; r++) {
        if ((c == 0 && r == 0) || (c == 4 && r == 4)) continue;
        board.placeAt(c, r, StackData(VehicleType.bicycle));
      }
    }
    expect(board.move(0, 0, 4, 4).valid, isTrue,
        reason: '格对格合并不看距离：墙对面的同档车也必须合得动');
    expect(board.hintMove(), isNotNull,
        reason: 'hint 按钮与死局检测必须同口径');
    expect(board.hasPossibleMove, isTrue,
        reason: '有合法合并步 ⇒ 不是死局；旧 BFS 实现这里误判 false');
  });

  test('语义缺口：单堆 count=2 不算可合（不能自己合自己）', () {
    // 数堆数而非 count：一堆 count=2 的自行车孤零零在场上，没有搭档。
    final board = BoardLogic(bossLevel());
    clearBoard(board);
    board.placeAt(2, 2, StackData(VehicleType.bicycle, count: 2));
    expect(board.hasPossibleMove, isFalse,
        reason: '单堆无法自己合自己——数 count 会造出幽灵合并');
    expect(board.move(2, 2, 2, 2).valid, isFalse);
  });

  testWidgets('L81 终局复盘：牌堆空 + 相邻同档对 + 冰块 ⇒ 不得判负',
      (tester) async {
    // 像素级复刻终局截图（5×5：9 冰 + 面包车 + 右下两辆相邻飞越，
    // 牌堆空）。只要场上还有合法合并，就不许走 deadEnd——旧实现
    // 在这里合规（相邻对 BFS 能找到），本测试把不变量钉在游戏层。
    final level = LevelDefinition(
      id: 9002,
      zhName: 'L81 终局复盘',
      cols: 5,
      rows: 5,
      stockSize: 0,
      goalType: GoalType.produce,
      targetTier: VehicleType.highspeed,
      targetCount: 3,
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        key: const ValueKey(9002),
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

    clearBoard(game.board);
    // 冰块（截图实测位置）。
    for (final (c, r) in [
      (3, 0), (4, 0),
      (1, 1), (2, 1), (3, 1),
      (2, 2), (3, 2), (4, 2),
      (3, 3),
    ]) {
      game.board.addObstacle(ObstacleType.ice, c, r);
    }
    game.board.placeAt(2, 3, StackData(VehicleType.van));
    game.board.placeAt(4, 3, StackData(VehicleType.subway));
    game.board.placeAt(4, 4, StackData(VehicleType.subway));

    expect(game.board.hasPossibleMove, isTrue,
        reason: '两辆相邻飞越 = 有合法合并');
    expect(game.board.hasIce, isTrue);

    // 跑 5 秒：融雪阀不应启动（有步可走），更不许判负。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(game.board.iceLayers, greaterThan(0),
        reason: '有合法合并时融雪阀不启动，冰块保持原样');
    expect(gameOver, isFalse,
        reason: '场上还有合法合并 ⇒ 绝不许 deadEnd 误判负');
  });
}

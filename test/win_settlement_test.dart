import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「任务达成却没结算」排查用回归测试。
///
/// 玩家反馈：目标看起来完成了，但没退出关卡、还能继续玩。
/// 这里把四条胜利路径逐条钉死——任何一条不再「达成即结算」都会红。
///
/// 用真实 GameScreen：结算弹窗是页面层产物，只断言游戏内部标志会漏掉
/// 「_finished 提前置位 → 弹窗被 return 挡掉」这类页面级 bug。
/// 棋盘变化走 `board.move`（判定只读 board 字段），不依赖 Flame 输入层——
/// 输入模拟在测试环境里对布局时序极敏感，会让用例随机失败，
/// 掩盖真正要守的判定逻辑。

LevelDefinition _level({
  int id = 9001,
  GoalType goalType = GoalType.produce,
  VehicleType? targetTier,
  int targetCount = 1,
  int stockSize = 24,
  int? movesLimit,
}) {
  return LevelDefinition(
    id: id,
    name: '结算测试 #$id',
    cols: 5,
    rows: 5,
    stockSize: stockSize,
    goalType: goalType,
    targetTier: targetTier,
    targetCount: targetCount,
    clearLimit: goalType == GoalType.clearBoard ? 4 : null,
    movesLimit: movesLimit,
  );
}

Future<MergeGame> _pumpGame(WidgetTester tester, LevelDefinition level) async {
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

/// 铺一张 count 指定的牌（模拟已经合过几次的堆），并清掉同格旧的。
void _place(MergeGame game, int col, int row, VehicleType tier, int count) {
  game.board.removeAt(col, row);
  game.board.placeAt(col, row, StackData(tier, count: count));
}

void main() {
  testWidgets('produce：目标车合成后下一帧就弹结算', (tester) async {
    final game = await _pumpGame(
      tester,
      _level(targetTier: VehicleType.scooter, targetCount: 1),
    );

    // scooter = bicycle + 1 档。2 张 + 1 张凑满 3 → 升级为目标车。
    _place(game, 0, 0, VehicleType.bicycle, 2);
    _place(game, 1, 0, VehicleType.bicycle, 1);
    final r = game.board.move(0, 0, 1, 0);
    expect(r.producedTarget, isTrue, reason: '3 张自行车必须合出目标车');
    await tester.pump(const Duration(milliseconds: 120));

    expect(game.board.producedCount, 1);
    expect(find.text('🚀 通关成功！'), findsOneWidget,
        reason: '目标达成必须弹结算，不能继续留在关卡里');
  });

  testWidgets('produce：目标达成时步数见底 → 判胜，不判步数用尽', (tester) async {
    final game = await _pumpGame(
      tester,
      _level(
        targetTier: VehicleType.scooter,
        targetCount: 1,
        movesLimit: 1,
      ),
    );

    _place(game, 0, 0, VehicleType.bicycle, 2);
    _place(game, 1, 0, VehicleType.bicycle, 1);
    game.board.move(0, 0, 1, 0);
    // 模拟"最后一步"：判定只看 producedCount 与 movesLeft 的先后关系。
    game.movesLeft.value = 0;
    await tester.pump(const Duration(milliseconds: 120));

    expect(game.board.producedCount, 1);
    expect(find.text('🚀 通关成功！'), findsOneWidget,
        reason: '目标达成时步数见底也必须判胜');
    expect(find.text('⏰ 差一点'), findsNothing, reason: '不能被步数判负抢先');
  });

  testWidgets('produce：多目标关打满 N 次才结算，1/N 时不结束', (tester) async {
    final game = await _pumpGame(
      tester,
      _level(targetTier: VehicleType.scooter, targetCount: 2),
    );

    _place(game, 0, 0, VehicleType.bicycle, 2);
    _place(game, 1, 0, VehicleType.bicycle, 1);
    game.board.move(0, 0, 1, 0);
    await tester.pump(const Duration(milliseconds: 120));

    expect(game.board.producedCount, 1);
    expect(find.text('🚀 通关成功！'), findsNothing, reason: '1/2 不该结算');

    _place(game, 0, 1, VehicleType.bicycle, 2);
    _place(game, 1, 1, VehicleType.bicycle, 1);
    game.board.move(0, 1, 1, 1);
    await tester.pump(const Duration(milliseconds: 120));

    expect(game.board.producedCount, 2);
    expect(find.text('🚀 通关成功！'), findsOneWidget, reason: '2/2 必须结算');
  });

  testWidgets('clearBoard：牌堆空 + 残堆达标 → 立即结算', (tester) async {
    final game = await _pumpGame(
      tester,
      _level(goalType: GoalType.clearBoard, stockSize: 0, targetCount: 1),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(game.stockLeft.value, 0);
    expect(find.text('🎉 清空成功！'), findsOneWidget,
        reason: '牌堆空且残堆 ≤ 上限，应结算');
  });
}

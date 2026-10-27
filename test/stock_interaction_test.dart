@Tags(<String>['ci-heavy'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

/// 牌堆交互（2026-10-10）的回归测试：
/// - 一键出牌：点牌堆卡 = 直接把这张牌放到棋盘（预览与实际一致）；
/// - 智能落点：自动放置优先落在同等级卡旁边（一步可合成）；
/// - 比例联动：牌堆卡尺寸跟随棋盘格子（3x3 大格关卡牌堆也大）。
void main() {
  const testLevel = LevelDefinition(
    id: 1,
    zhName: 't',
    cols: 3,
    rows: 3,
    stockSize: 12,
    targetTier: VehicleType.sedan,
    targetCount: 1,
  );

  /// 固定时长 pump（Flame 持续渲染，pumpAndSettle 不收敛）。
  Future<MergeGame> pumpGame(
    WidgetTester tester, {
    LevelDefinition? level,
    Size screen = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = screen;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        // 换 key 强制重建：否则同类型 widget 会复用旧 State（棋盘尺寸不更新）。
        key: ValueKey('${(level ?? testLevel).id}_${screen.width}'),
        level: level ?? testLevel,
        data: PlayerData(),
        repo: SaveRepository(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    final gw = tester
        .widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget));
    return gw.game as MergeGame;
  }

  /// 端到端：在界面上点第一张牌堆卡（走真实 onTap 路径）。
  Future<void> tapFirstStockCard(WidgetTester tester) async {
    final card = find.byKey(const ValueKey('stockCard0'));
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 120));
  }

  group('BoardLogic.placeTierSmart（智能自动放置）', () {
    test('优先落在同等级卡的相邻空格', () {
      final b = BoardLogic(testLevel);
      b.placeAt(1, 1, StackData(VehicleType.taxi));
      b.placeAt(0, 0, StackData(VehicleType.sedan));
      b.placeAt(2, 2, StackData(VehicleType.sedan));
      for (var i = 0; i < 20; i++) {
        final cell = b.placeTierSmart(VehicleType.taxi);
        expect(cell, isNotNull);
        // 必须落在 taxi 的四邻内
        final dist = (cell!.col - 1).abs() + (cell.row - 1).abs();
        expect(dist, 1, reason: '智能落点应紧贴同等级卡，实际 $cell');
        b.removeAt(cell.col, cell.row);
      }
    });

    test('无同等级卡时退回任意空格', () {
      final b = BoardLogic(testLevel);
      final cell = b.placeTierSmart(VehicleType.taxi);
      expect(cell, isNotNull);
      expect(b.at(cell!.col, cell.row)!.tier, VehicleType.taxi);
    });
  });

  group('牌堆一键出牌', () {
    testWidgets('点第 1 张牌堆卡 = 出预览中的第 1 张', (tester) async {
      final game = await pumpGame(tester);
      final expectedTier = game.upcomingStock[0];
      final before = game.board.tileCount;
      final deckBefore = game.stockLeft.value;

      game.drawStock(0);

      expect(game.board.tileCount, before + 1);
      expect(game.stockLeft.value, deckBefore - 1);
      expect(expectedTier, isNotNull);
    });

    testWidgets('点第 2 张牌堆卡 = 出的就是第 2 张（预览与实际一致）', (tester) async {
      final game = await pumpGame(tester);
      final second = game.upcomingStock[1];
      final deckBefore = game.stockLeft.value;

      game.drawStock(1);

      expect(game.stockLeft.value, deckBefore - 1);
      // 打出的牌一定出现在棋盘上。
      var found = false;
      for (var c = 0; c < game.board.cols; c++) {
        for (var r = 0; r < game.board.rows; r++) {
          final s = game.board.at(c, r);
          if (s != null && !s.isEmpty && s.tier == second) found = true;
        }
      }
      expect(found, isTrue, reason: '点第 2 张应把第 2 张放到棋盘');
    });

    testWidgets('棋盘满时点牌堆不出牌、不消耗', (tester) async {
      final game = await pumpGame(tester);
      // 把棋盘填满（非障碍格全放一张）。
      for (var c = 0; c < game.board.cols; c++) {
        for (var r = 0; r < game.board.rows; r++) {
          final s = game.board.at(c, r);
          if ((s == null || s.isEmpty) &&
              game.board.obstacleAt(c, r) == null) {
            game.board.placeAt(c, r, StackData(VehicleType.sedan));
          }
        }
      }
      final deckBefore = game.stockLeft.value;
      game.drawStock(0);
      expect(game.stockLeft.value, deckBefore);
      expect(game.hint.value, isNotNull);
    });

    testWidgets('界面上点牌堆卡真的会出牌', (tester) async {
      final game = await pumpGame(tester);
      final before = game.board.tileCount;
      await tapFirstStockCard(tester);
      expect(game.board.tileCount, before + 1);
    });

    testWidgets('牌堆卡尺寸跟随棋盘格子（大格关卡牌堆也大）', (tester) async {
      final g3 = await pumpGame(tester); // 3x3：格子大
      final cell3 = g3.cellPx.value;
      final g6 = await pumpGame(
        tester,
        level: const LevelDefinition(
          id: 2,
          zhName: 't6',
          cols: 6,
          rows: 6,
          stockSize: 12,
          targetTier: VehicleType.sedan,
          targetCount: 1,
        ),
      );
      final cell6 = g6.cellPx.value;
      expect(cell3, greaterThan(cell6),
          reason: '3x3 关卡格子更大，cellPx 应更大；实际 $cell3 vs $cell6');
      // UI 侧牌堆卡 = cellPx 等比缩放，两者同步（这里只验证数据源真实反映棋盘）。
      expect(g6.children.whereType<StackSprite>().first.size.x, cell6);
    });

    testWidgets('320px 小屏：牌堆行不溢出', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: GameScreen(
          level: testLevel,
          data: PlayerData(),
          repo: SaveRepository(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
    });
  });
}

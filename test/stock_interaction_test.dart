import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

/// 牌堆交互重设计（2026-10-10）的回归测试：
/// - 两段式出牌：点牌堆 = 拿起 → 点棋盘空格 = 精确落子；
/// - 快速通道：再点同一张牌堆卡 = 智能自动放置；
/// - 智能落点：自动放置优先落在同等级卡旁边（一步可合成）。
void main() {
  const testLevel = LevelDefinition(
    id: 1,
    name: 't',
    cols: 3,
    rows: 3,
    stockSize: 12,
    targetTier: VehicleType.sedan,
    targetCount: 1,
  );

  /// 固定时长 pump（Flame 持续渲染，pumpAndSettle 不收敛）。
  Future<MergeGame> pumpGame(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
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
    final gw = tester
        .widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget));
    return gw.game as MergeGame;
  }

  (int, int)? firstEmpty(MergeGame game) {
    for (var c = 0; c < game.board.cols; c++) {
      for (var r = 0; r < game.board.rows; r++) {
        final s = game.board.at(c, r);
        if (s == null || s.isEmpty) return (c, r);
      }
    }
    return null;
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

  group('牌堆两段式交互', () {
    testWidgets('拿起 → 指定空格精确落子', (tester) async {
      final game = await pumpGame(tester);
      expect(game.heldStock.value, isNull);

      final expectedTier = game.upcomingStock[0];
      game.selectStock(0);
      expect(game.heldStock.value, 0);

      final target = firstEmpty(game)!;
      final before = game.board.tileCount;
      expect(game.placeHeldAt(target.$1, target.$2), isTrue);
      expect(game.heldStock.value, isNull);
      expect(game.board.at(target.$1, target.$2)!.tier, expectedTier);
      expect(game.board.tileCount, before + 1);
    });

    testWidgets('拿起后点占用格 = 取消拿起，牌留在牌堆', (tester) async {
      final game = await pumpGame(tester);
      game.selectStock(0);
      expect(game.heldStock.value, 0);

      // 找一个有卡的格子
      (int, int)? occupied;
      for (var c = 0; c < game.board.cols; c++) {
        for (var r = 0; r < game.board.rows; r++) {
          final s = game.board.at(c, r);
          if (s != null && !s.isEmpty) occupied = (c, r);
        }
      }
      expect(occupied, isNotNull);
      final deckBefore = game.stockLeft.value;
      expect(game.placeHeldAt(occupied!.$1, occupied.$2), isFalse);
      expect(game.heldStock.value, isNull);
      expect(game.stockLeft.value, deckBefore); // 没消耗牌
    });

    testWidgets('再点同一张牌堆卡 = 自动放置一张', (tester) async {
      final game = await pumpGame(tester);
      game.selectStock(0);
      final before = game.board.tileCount;
      game.selectStock(0); // 第二次点 = 快速通道
      expect(game.heldStock.value, isNull);
      expect(game.board.tileCount, before + 1);
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

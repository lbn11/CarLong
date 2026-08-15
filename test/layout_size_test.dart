import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

void main() {
  Future<BoardBackdrop> pump(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          level: levels[4],
          data: PlayerData(),
          repo: SaveRepository(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final gw = tester.widget<GameWidget>(
        find.byWidgetPredicate((w) => w is GameWidget));
    final game = gw.game as MergeGame;
    final backdrop = game.children.whereType<BoardBackdrop>().first;
    return backdrop;
  }

  testWidgets('竖屏：棋盘撑满宽度', (tester) async {
    final backdrop = await pump(tester, const Size(390, 844));
    final boardW = backdrop.size.x - 24; // 去掉底板边距 = 棋盘实际宽
    // 棋盘按宽度撑满（390 - 两侧边距 24 = 366）
    expect(boardW, greaterThan(360));
    expect(boardW, lessThan(390));
  });

  testWidgets('横屏手机：棋盘撑满高度', (tester) async {
    final backdrop = await pump(tester, const Size(640, 360));
    final boardH = backdrop.size.y - 24;
    expect(boardH, greaterThan(330));
    expect(boardH, lessThanOrEqualTo(360));
  });

  testWidgets('超宽屏：棋盘撑满高度', (tester) async {
    final backdrop = await pump(tester, const Size(1920, 1080));
    final boardH = backdrop.size.y - 24;
    expect(boardH, greaterThan(1050));
  });
}

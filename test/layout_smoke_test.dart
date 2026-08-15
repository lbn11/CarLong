import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
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
  }

  testWidgets('竖屏布局无溢出', (tester) async {
    await pump(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('横屏手机布局无溢出', (tester) async {
    await pump(tester, const Size(640, 360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('超宽屏布局无溢出', (tester) async {
    await pump(tester, const Size(1920, 1080));
    expect(tester.takeException(), isNull);
  });
}

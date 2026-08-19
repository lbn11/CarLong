import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';
import 'package:merge_fleet/game/vehicle_icons.dart';
import 'package:merge_fleet/main.dart' as app;
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/achievements_screen.dart';
import 'package:merge_fleet/screens/collection_screen.dart';
import 'package:merge_fleet/screens/game_screen.dart';
import 'package:merge_fleet/screens/home_screen.dart';
import 'package:merge_fleet/screens/level_select_screen.dart';
import 'package:merge_fleet/screens/parking_level_select.dart';
import 'package:merge_fleet/screens/parking_screen.dart';
import 'package:merge_fleet/screens/shop_screen.dart';
import 'package:merge_fleet/services/parking_generator.dart';

/// Flame 有持续渲染循环、首页有循环氛围动画，pumpAndSettle 永远不收敛，
/// 所以统一用「固定时长 pump」代替。
Future<void> pumpFor(
  WidgetTester tester,
  Widget widget, [
  Size size = const Size(390, 844),
  Duration settle = const Duration(milliseconds: 300),
]) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: widget));
  await tester.pump(settle);
  await tester.pump(settle);
}

void main() {
  setUpAll(() async {
    await precomputeVehicleBounds().timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  });

  /// 启动应用 + 首页渲染（验证 home_screen 浅色重构未崩溃）
  testWidgets('应用启动且首页渲染正常', (tester) async {
    await pumpFor(tester, app.MergeGameApp(data: PlayerData(), repo: SaveRepository()));
    expect(tester.takeException(), isNull);
    expect(find.text('开始游戏'), findsWidgets);
  });

  /// 主玩法：进入合成关卡 + 在棋盘上点两下（模拟选车/移动），不应崩溃
  testWidgets('合成关卡：进入并点击棋盘可交互', (tester) async {
    await pumpFor(tester,
        GameScreen(level: levels[0], data: PlayerData(), repo: SaveRepository()));
    expect(tester.takeException(), isNull);

    final board =
        find.byWidgetPredicate((w) => w is GameWidget, description: 'Flame GameWidget');
    expect(board, findsWidgets);

    final rect = tester.getRect(board.first);
    if (rect.width > 60 && rect.height > 60) {
      await tester.tapAt(rect.center - const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tapAt(rect.center + const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });

  /// 停车模式：进入关卡 + 点击棋盘中心（模拟选车/移动），不应崩溃
  testWidgets('停车关卡：进入并点击棋盘可交互', (tester) async {
    await pumpFor(tester,
        ParkingScreen(level: ParkingLevelGenerator.generateOne(21), data: PlayerData(), repo: SaveRepository()));
    expect(tester.takeException(), isNull);
    expect(find.byType(ParkingScreen), findsOneWidget);

    // 棋盘居中，点击中心模拟一次选车/移动
    final rect = tester.getRect(find.byType(ParkingScreen).first);
    await tester.tapAt(rect.center);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  /// 各主界面直接渲染：验证浅色重构后的 build 均不抛异常 / 不溢出
  testWidgets('各主界面渲染不崩溃(手机)', (tester) async {
    final data = PlayerData();
    final repo = SaveRepository();
    final screens = [
      HomeScreen(data: data, repo: repo),
      GameScreen(level: levels[0], data: data, repo: repo),
      ParkingScreen(level: ParkingLevelGenerator.generateOne(21), data: data, repo: repo),
      CollectionScreen(data: data, repo: repo),
      ShopScreen(data: data, repo: repo),
      AchievementsScreen(data: data, repo: repo),
      LevelSelectScreen(data: data, repo: repo),
      ParkingLevelSelectScreen(data: data, repo: repo),
    ];
    for (final w in screens) {
      await pumpFor(tester, w);
      expect(tester.takeException(), isNull, reason: '渲染 $w 时抛出异常');
    }
  });

  /// 平板尺寸下主界面也不溢出
  testWidgets('主界面在平板尺寸不溢出', (tester) async {
    final data = PlayerData();
    final repo = SaveRepository();
    await pumpFor(tester, HomeScreen(data: data, repo: repo), const Size(820, 1180));
    expect(tester.takeException(), isNull);
    await pumpFor(tester,
        ParkingScreen(level: ParkingLevelGenerator.generateOne(21), data: data, repo: repo),
        const Size(820, 1180));
    expect(tester.takeException(), isNull);
  });
}

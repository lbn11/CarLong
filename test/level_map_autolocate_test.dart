import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/level_select_screen.dart';
import 'package:merge_fleet/screens/parking_level_select.dart';
import 'package:merge_fleet/widgets/pressable.dart';

/// 关卡地图「进页自动定位到当前进度」的回归测试。
///
/// 700 关分 14 章：地图如果每次都从顶部开始，玩家打完一关回来要往下翻
/// 十几屏才找得到自己打到哪。这里锁死三件事——
/// ① 进页把视口推到「下一关」；② 卡片确实落在视口内（不是算错位置）；
/// ③ 当前关带 ▶ 继续标记，扫一眼就知道打哪张。

Future<void> _pumpMap(
  WidgetTester tester, {
  required int unlocked,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final data = PlayerData(unlockedLevel: unlocked);
  await tester.pumpWidget(MaterialApp(
    home: LevelSelectScreen(data: data, repo: SaveRepository()),
  ));
  // 定位链路跨好几帧：首帧量尺寸 → 落位 → 校正动画（220ms）。
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

double _scrollOffset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

/// 停车选关页：所有章节解锁（collection 全收集），只看定位行为。
Future<void> _pumpParkingMap(
  WidgetTester tester, {
  required int unlocked,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final data = PlayerData(
    parkingUnlocked: unlocked,
    collection: VehicleType.values.map((v) => v.id).toSet(),
  );
  await tester.pumpWidget(MaterialApp(
    home: ParkingLevelSelectScreen(data: data, repo: SaveRepository()),
  ));
  // 定位是「跳 → 实测校正 → 再跳」的循环，每轮跨一帧。
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// 当前关卡片（按「第 N 关」标签反查所属 LevelCard）。
Finder _cardOf(int id) => find
    .ancestor(of: find.text('第 $id 关'), matching: find.byType(LevelCard))
    .first;

void main() {
  testWidgets('深层关卡进地图自动定位到当前关', (tester) async {
    await _pumpMap(tester, unlocked: 401);

    expect(find.text('第 401 关'), findsOneWidget,
        reason: '当前关必须在视口内被懒加载出来');
    expect(_scrollOffset(tester), greaterThan(2000),
        reason: '第 401 关在地图深处，必须真的滚下去而不是停在顶部');

    final rect = tester.getRect(_cardOf(401));
    expect(rect.top, greaterThanOrEqualTo(0.0));
    expect(rect.bottom, lessThanOrEqualTo(844.0));
    // 落在视口上三分之一附近：上方留出章节标题的上下文，下方接后续关卡。
    expect(rect.top, lessThan(844 * 0.55));
  });

  testWidgets('当前关带 ▶ 继续标记，且只挂在当前关', (tester) async {
    await _pumpMap(tester, unlocked: 401);

    final badge = find.byIcon(Icons.play_arrow_rounded);
    expect(badge, findsOneWidget, reason: '整页只有一个"接下来打这关"的标记');

    final cardRect = tester.getRect(_cardOf(401));
    expect(cardRect.contains(tester.getRect(badge).center), isTrue,
        reason: '▶ 标记必须落在当前关卡片内');
  });

  testWidgets('章首关卡：连章标题一起露出来（玩家知道自己在哪一章）', (tester) async {
    // L386 是第 15 章第一关：标题就在卡片正上方，应当一起可见。
    await _pumpMap(tester, unlocked: 386);

    final header = tester.getRect(find.text(chapterForId(386).title));
    expect(header.top, greaterThanOrEqualTo(0.0),
        reason: '章标题不能被推到视口上方');
    expect(header.top, lessThan(160.0),
        reason: '章标题应贴在上沿附近，而不是留在屏幕中段');

    final card = tester.getRect(_cardOf(386));
    expect(card.top, greaterThan(header.bottom), reason: '卡片在章标题下方');
  });

  testWidgets('章末关卡：标题离得太远时优先保证卡片可见', (tester) async {
    // L401 在本章第 7 行，标题在 1200px 之外——硬露标题会把卡片顶出屏幕，
    // 这时应当退回「卡片落在上三分之一」。
    await _pumpMap(tester, unlocked: 401);

    final card = tester.getRect(_cardOf(401));
    expect(card.top, greaterThanOrEqualTo(0.0));
    expect(card.bottom, lessThanOrEqualTo(844.0));
    expect(card.top, lessThan(844 * 0.55));
  });

  testWidgets('开局（第 1 关）不会被甩到地图中段', (tester) async {
    await _pumpMap(tester, unlocked: 1);

    expect(find.text('第 1 关'), findsOneWidget);
    expect(_scrollOffset(tester), lessThan(600),
        reason: '第 1 关就在开头，估算不该把列表往下推');
  });

  testWidgets('横屏视口也落在可见范围（几何公式不依赖竖屏比例）', (tester) async {
    await _pumpMap(tester, unlocked: 401, size: const Size(844, 390));

    // 横屏 844 宽下两列网格的格子有 357px 高，比视口还高——整张卡必然
    // 装不下，能保证的是「卡片顶部（序号徽标）落在视口内」。
    final pill = tester.getRect(find.text('第 401 关'));
    expect(pill.top, greaterThanOrEqualTo(0.0));
    expect(pill.bottom, lessThanOrEqualTo(390.0),
        reason: '横屏下序号徽标也必须看得见，不能被推到视口外');
  });

  testWidgets('全部通关后停在最后一关，不越界', (tester) async {
    await _pumpMap(tester, unlocked: 99999);

    final lastId = levels.length;
    expect(find.text('第 $lastId 关'), findsOneWidget);
    expect(_scrollOffset(tester), greaterThan(2000));
    expect(tester.takeException(), isNull);
  });

  // ── 停车模式：800 关 / 22 章，同一套「进页定位」──────────────
  group('停车关卡地图', () {
    testWidgets('深层章节进页自动定位到下一关', (tester) async {
      await _pumpParkingMap(tester, unlocked: 253);

      expect(find.text('253'), findsOneWidget, reason: '下一关的格子必须被构建出来');
      expect(_scrollOffset(tester), greaterThan(1500),
          reason: 'L253 在第 8 章，必须真的滚下去');
      final rect = tester.getRect(find.text('253'));
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(844.0));
    });

    testWidgets('当前关有 ▶ 继续标记，且只挂在当前关', (tester) async {
      await _pumpParkingMap(tester, unlocked: 253);

      final tile = find.ancestor(
        of: find.text('253'),
        matching: find.byType(Pressable),
      );
      expect(tile, findsOneWidget);
      final badge = find.descendant(
        of: tile,
        matching: find.byIcon(Icons.play_arrow_rounded),
      );
      expect(badge, findsOneWidget, reason: '当前关格子要有 ▶ 标记');
    });

    testWidgets('开局（第 2 关）停在顶部，不甩到章节中段', (tester) async {
      await _pumpParkingMap(tester, unlocked: 2);

      expect(find.text('2'), findsWidgets);
      expect(_scrollOffset(tester), lessThan(600));
    });

    testWidgets('最深处章节（L700）校正循环也能收敛', (tester) async {
      await _pumpParkingMap(tester, unlocked: 700);

      expect(find.text('700'), findsOneWidget);
      final rect = tester.getRect(find.text('700'));
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(844.0),
          reason: '估算误差要靠实测校正补掉，不能越滚越偏');
      expect(_scrollOffset(tester), greaterThan(8000));
    });
  });
}

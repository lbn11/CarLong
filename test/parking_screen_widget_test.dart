import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/car.dart';
import 'package:merge_fleet/models/parking_level.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/parking_screen.dart';

/// 构造 size×size 全 road 网格，停车位放在 (size-1, size-2)。
List<List<ParkingCellType>> _grid(int size) {
  final g = List.generate(
    size,
    (_) => List.filled(size, ParkingCellType.road),
  );
  g[size - 1][size - 2] = ParkingCellType.parking;
  return g;
}

/// 固定竖屏视口，避免测试默认 800x600 横屏触发与 C 无关的布局问题。
void _usePortrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('停车界面初始渲染不抛异常（含 AnimatedPositioned 车辆）',
      (tester) async {
    _usePortrait(tester);
    final level = ParkingLevel(
      id: 1,
      name: 't',
      rows: 4,
      cols: 4,
      grid: _grid(4),
      vehicles: [
        VehicleSpawn(col: 0, row: 0, tier: CarTier.car),
      ],
      targetTier: CarTier.car,
    );
    final data = PlayerData()..tutorialCompleted.add(-1); // 跳过教学，避免延迟回调
    await tester.pumpWidget(MaterialApp(
      home: ParkingScreen(
        level: level,
        data: data,
        repo: SaveRepository(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ParkingScreen), findsOneWidget);
  });

  testWidgets('点击选中再滑入车位 → 胜利弹窗与彩带不抛异常', (tester) async {
    _usePortrait(tester);
    final level = ParkingLevel(
      id: 1,
      name: 't',
      rows: 4,
      cols: 4,
      grid: _grid(4),
      vehicles: [
        VehicleSpawn(col: 1, row: 3, tier: CarTier.car),
      ],
      targetTier: CarTier.car,
    );
    final data = PlayerData()..tutorialCompleted.add(-1); // 跳过教学，避免延迟回调
    await tester.pumpWidget(MaterialApp(
      home: ParkingScreen(
        level: level,
        data: data,
        repo: SaveRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    // 先选中 (3,1) 的车，再点击车位 (3,2) 滑入获胜。
    await tester.tap(find.byKey(const ValueKey('cell-3-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cell-3-2')));
    await tester.pumpAndSettle(); // 跑完入场动画 + 胜利彩带

    expect(find.text('停车成功!'), findsOneWidget);

    // 接入校验：胜利后目标车型点亮图鉴、最佳星级落盘、解锁下一关。
    expect(data.collection.contains(CarTier.car.index), isTrue);
    expect(data.parkingBestStars[1], greaterThan(0));
    expect(data.parkingUnlocked, greaterThanOrEqualTo(2));
  });

  testWidgets('胜利彩带 WinConfetti 渲染不抛异常', (tester) async {
    _usePortrait(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: WinConfetti())),
      ),
    );
    await tester.pumpAndSettle();
  });
}

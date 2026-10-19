@Tags(<String>['ci-heavy'])
library;
import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/collection_screen.dart';
import 'package:merge_fleet/screens/shop_screen.dart';
import 'package:merge_fleet/widgets/candy_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI 交互冒烟（任务81）：商店购买 / 图鉴详情 / 经济弹层 关键路径不崩。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('商店：金币礼包购买后金币增加', (tester) async {
    final data = PlayerData(coins: 100);
    final repo = SaveRepository();
    await tester.pumpWidget(MaterialApp(
      home: ShopScreen(data: data, repo: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget); // 余额 100
    await tester.tap(find.text('¥6 购买'));
    await tester.pumpAndSettle();
    expect(data.coins, greaterThanOrEqualTo(600)); // 购买后 +600
  });

  testWidgets('商店：金币不足时宝箱按钮禁用', (tester) async {
    final data = PlayerData(coins: 10);
    final repo = SaveRepository();
    await tester.pumpWidget(MaterialApp(
      home: ShopScreen(data: data, repo: repo),
    ));
    await tester.pumpAndSettle();
    // 主推的宝箱按钮：金币不足时必须是不可点的（新版统一走 CandyButton）。
    final chestBtn =
        tester.widget<CandyButton>(find.byType(CandyButton).first);
    expect(chestBtn.onTap, isNull); // 金币不足禁用
  });

  testWidgets('图鉴：点击卡片弹出车型详情', (tester) async {
    final data = PlayerData(collection: {VehicleType.bicycle.index});
    final repo = SaveRepository();
    await tester.pumpWidget(MaterialApp(
      home: CollectionScreen(data: data, repo: repo),
    ));
    await tester.pumpAndSettle();
    // Boss 徽章墙是第一个 section（56 格，桌面视口下总高 3000+px），
    // 车辆卡在 ListView 懒加载区外——滚到位之前 widget 根本不存在，
    // dragUntilVisible 不适用（它要求目标已构建），只能固定步数拖。
    for (var i = 0; i < 20; i++) {
      if (find.text('自行车').evaluate().isNotEmpty) break;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    // 点第一张车卡（自行车，50 车系统迁移后的 1 级车）
    await tester.tap(find.text('自行车').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('已收集'), findsWidgets); // 详情弹层出现
  });
}

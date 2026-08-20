import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/collection_screen.dart';
import 'package:merge_fleet/screens/shop_screen.dart';
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
    final chestBtn = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(chestBtn.onPressed, isNull); // 金币不足禁用
  });

  testWidgets('图鉴：点击卡片弹出车型详情', (tester) async {
    final data = PlayerData(collection: {VehicleType.bicycle.index});
    final repo = SaveRepository();
    await tester.pumpWidget(MaterialApp(
      home: CollectionScreen(data: data, repo: repo),
    ));
    await tester.pumpAndSettle();
    // 点第一张车卡（单车）
    await tester.tap(find.text('单车').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('已收集'), findsWidgets); // 详情弹层出现
  });
}

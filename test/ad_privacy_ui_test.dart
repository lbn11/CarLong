@Tags(<String>['ci-heavy'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/home_screen.dart';
import 'package:merge_fleet/services/ads/ad_service.dart';
import 'package:merge_fleet/services/ads/mock_ad_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 隐私设置入口（UMP 合规）的可见性与反馈。
///
/// 欧盟区要求 `PrivacyOptionsRequirementStatus.required` 时 App 内必须能
/// 随时撤回广告同意，缺入口属于明确的不合规项。这里锁三件事：
/// 1. 入口在设置弹窗里**确实存在**（不能被后续改版顺手删掉）；
/// 2. 地区不要求时给明确说明，不留一个点了没反应的按钮；
/// 3. 要求时真的转发到 provider（真实 SDK 下就是弹表单）。
void main() {
  late PlayerData data;
  late SaveRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    data = PlayerData();
    repo = SaveRepository();
    AdService.resetForTest();
  });

  tearDown(() {
    AdService.provider = MockAdProvider(playback: Duration.zero);
  });

  /// 首页有常驻的环境光动画（`_ambient..repeat()`），`pumpAndSettle` 永远
  /// 不会 settle，只能用固定步长的 pump 推进。
  Future<void> settle(WidgetTester tester, [int frames = 6]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen(data: data, repo: repo)));
    await settle(tester, 8); // 入场动画
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await settle(tester);
  }

  testWidgets('设置里有隐私设置入口，地区不要求时给出说明', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdService.provider = MockAdProvider(playback: Duration.zero)
      ..privacyRequired = false;

    await openSettings(tester);
    expect(find.text('隐私设置与广告偏好'), findsOneWidget);

    await tester.tap(find.text('隐私设置与广告偏好'));
    await settle(tester);
    expect(find.text('当前地区无需设置'), findsOneWidget);
  });

  testWidgets('地区要求时点入口会真的打开表单（转发到 provider）', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = MockAdProvider(playback: Duration.zero);
    AdService.provider = provider;

    await openSettings(tester);
    await tester.tap(find.text('隐私设置与广告偏好'));
    await settle(tester);

    expect(provider.privacyShowCount, 1);
    // 弹出成功不再叠一个「打不开」的提示。
    expect(find.text('隐私设置暂时打不开'), findsNothing);
  });
}

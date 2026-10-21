@Tags(<String>['ci-heavy'])
library;
import 'package:merge_fleet/models/vehicle.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vehicle asset contact sheet', (tester) async {
    // 文件名唯一真源是 `VehicleType.sprite`（bicycle → bike、sedan → car…）。
    // 早期这里用 tier.name 拼路径，路径根本不存在，过滤后列表为空、测试空跑。
    final entries = [
      for (final t in VehicleType.values)
        if (t.sprite != null && File('assets/vehicles/${t.sprite}.png').existsSync())
          (tier: t, sprite: t.sprite!),
    ];
    expect(entries, isNotEmpty, reason: '一张车模都没找到，检查 VehicleType.sprite 与 assets 目录');
    // 2026-10-21 补齐最后 10 档后，50 个档位应全部有 PNG。缺一张就翻红，
    // 避免再出现"某档悄悄回退 emoji"（Web 端 emoji 还是豆腐块）。
    expect(
      entries.length,
      VehicleType.values.length,
      reason: '有档位没有车模 PNG：'
          '${VehicleType.values.where((t) => t.sprite == null || !File('assets/vehicles/${t.sprite}.png').existsSync()).map((t) => t.name).toList()}',
    );

    // 视口要装得下全部档位：5 张/行 × (152 高 + 10 间距) ≈ 1644。
    // 默认 800×600 只能看到前 16 张，后面新增的档位永远拍不进 golden，
    // 等于这张对照表长期漏检。
    tester.view.physicalSize = const Size(720, 1760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final cards = <Widget>[];
    for (final e in entries) {
      final tier = e.tier;
      cards.add(
        SizedBox(
          width: 124,
          height: 152,
          child: Column(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A313C), Color(0xFF161B22)],
                  ),
                  border: Border.all(color: tier.color.withValues(alpha: 0.55), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/vehicles/${e.sprite}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 档位名有长有短（forklift / cementmixer），固定一行不换行，
              // 否则 Content 撑高会把 Column 顶出溢出黄条。
              Text(
                e.sprite,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1D23),
          body: Center(
            child: SingleChildScrollView(
              child: Container(
                width: 680,
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold));
    for (final e in entries) {
      await tester.runAsync(() async {
        await precacheImage(
          AssetImage('assets/vehicles/${e.sprite}.png'),
          ctx,
        );
      });
    }
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('vehicle_assets.png'),
    );
  });
}

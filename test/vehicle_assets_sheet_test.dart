import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/car.dart';

void main() {
  testWidgets('vehicle asset contact sheet', (tester) async {
    final cards = <Widget>[];
    for (final tier in CarTier.values) {
      cards.add(
        SizedBox(
          width: 120,
          height: 140,
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
                      'assets/vehicles/${tier.name}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tier.label,
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
    for (final tier in CarTier.values) {
      await tester.runAsync(() async {
        await precacheImage(
          AssetImage('assets/vehicles/${tier.name}.png'),
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

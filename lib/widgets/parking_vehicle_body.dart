import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// 停车模式华容道车身：俯视角矢量绘制，沿滑动轴拉伸成整条车身。
/// 横车横躺、竖车竖立（内部统一按"竖直、车头朝上"绘制，横车整体旋转）。
/// 结构：渐变车身 + 前挡风玻璃座舱 + 两侧外凸轮胎 + 车头灯/尾灯 + 描边。
class ParkingVehicleBody extends StatelessWidget {
  final VehicleType tier;

  /// 占格数（沿车身轴）。
  final int length;

  /// true = 横车（车身沿水平轴）。
  final bool horizontal;
  final double cellSize;

  const ParkingVehicleBody({
    super.key,
    required this.tier,
    required this.length,
    required this.horizontal,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    // 统一画竖直车身，再旋转 90° 得到横车。
    final vertical = SizedBox(
      width: cellSize,
      height: cellSize * length,
      child: CustomPaint(
        painter: _TopDownBodyPainter(tier.color, cells: length),
      ),
    );
    if (!horizontal) return vertical;
    return RotatedBox(quarterTurns: 1, child: vertical);
  }
}

class _TopDownBodyPainter extends CustomPainter {
  final Color base;
  final int cells;

  _TopDownBodyPainter(this.base, {required this.cells});

  Color get _light => Color.lerp(base, Colors.white, 0.30)!;
  Color get _dark => Color.lerp(base, Colors.black, 0.32)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wheelW = w * 0.13; // 轮胎长边
    final wheelT = w * 0.11; // 轮胎厚度（外凸量）
    final inset = wheelT * 0.55; // 车身与画布边缘的间隙
    final bodyW = w - 2 * inset;
    final bodyH = h - 2 * inset;

    // ---- 轮胎（先画，压在车身下面外露两侧）----
    final wheelPaint = Paint()..color = const Color(0xFF2A2D33);
    final wheelHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.10);
    // 每格一对（左右各一），位于格子中点略偏前后。
    for (var i = 0; i < cells; i++) {
      final cy = h * ((i + 0.5) / cells);
      for (final dy in [-wheelW * 0.42, wheelW * 0.42]) {
        for (final left in [true, false]) {
          final cx = left ? inset * 0.35 : w - inset * 0.35 - wheelT;
          final rect = Rect.fromLTWH(cx, cy + dy - wheelW / 2, wheelT, wheelW);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(wheelT * 0.45)),
            wheelPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                rect.deflate(wheelT * 0.22), Radius.circular(wheelT * 0.3)),
            wheelHighlight,
          );
        }
      }
    }

    // ---- 车身 ----
    final bodyRect = Rect.fromLTWH(inset, inset, bodyW, bodyH);
    final radius = Radius.circular(math.min(bodyW * 0.32, bodyH * 0.14));
    final rrect = RRect.fromRectAndRadius(bodyRect, radius);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_light, base, _dark],
          stops: const [0, 0.55, 1],
        ).createShader(bodyRect),
    );
    // 顶部镜面高光。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bodyRect.left + bodyW * 0.10, bodyRect.top + bodyH * 0.02,
            bodyW * 0.80, bodyH * 0.16),
        Radius.circular(radius.x),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    // 描边。
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.025)
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // ---- 座舱玻璃：前段深色圆角块（约占车身 22%~46%）----
    final glassTop = bodyRect.top + bodyH * 0.20;
    final glassH = math.min(bodyH * 0.24, bodyW * 1.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            bodyRect.left + bodyW * 0.16, glassTop, bodyW * 0.68, glassH),
        Radius.circular(bodyW * 0.18),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3B4A5C).withValues(alpha: 0.92),
            const Color(0xFF222E3C).withValues(alpha: 0.95),
          ],
        ).createShader(Rect.fromLTWH(
            bodyRect.left, glassTop, bodyW, glassH)),
    );

    // ---- 车头灯（前）/ 尾灯（后）----
    final lampR = bodyW * 0.075;
    final headY = bodyRect.top + bodyH * 0.055;
    final tailY = bodyRect.bottom - bodyH * 0.055;
    for (final fx in [0.26, 0.74]) {
      final x = bodyRect.left + bodyW * fx;
      canvas.drawCircle(
          Offset(x, headY), lampR, Paint()..color = const Color(0xFFFFE082));
      canvas.drawCircle(
          Offset(x, tailY), lampR * 0.85, Paint()..color = const Color(0xFFEF5350));
    }
  }

  @override
  bool shouldRepaint(_TopDownBodyPainter old) =>
      old.base != base || old.cells != cells;
}

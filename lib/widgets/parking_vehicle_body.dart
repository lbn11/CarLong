import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/vehicle_sprites.dart';
import '../models/vehicle.dart';

/// 停车模式华容道车身。
///
/// 有真实车模 PNG 时直接贴图（侧视图，横车原样、竖车转 90°），与 mini 端
/// `drawSpriteFit(stretch:)` 同一套裁剪比例；缺图的档位回退原来的俯视矢量车身
/// （渐变车身 + 座舱玻璃 + 轮胎 + 车灯）。
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
      child: ValueListenableBuilder<int>(
        valueListenable: VehicleSprites.revision,
        builder: (context, _, _) {
          final img = VehicleSprites.of(tier);
          if (img != null) {
            return CustomPaint(painter: _SpriteBodyPainter(img));
          }
          return CustomPaint(
            painter: _TopDownBodyPainter(tier.color, cells: length),
          );
        },
      ),
    );
    if (!horizontal) return vertical;
    return RotatedBox(quarterTurns: 1, child: vertical);
  }
}

/// 侧视车模贴到长条车身上。
///
/// 车模是 1:1 方图、车身只占中间横向一条（约 80% 宽 × 45% 高）。若按方图
/// 等比 contain，2 格车的车身只剩三分之一长、像张贴纸；所以改为"按车身在
/// 图中的实际占比"做 contain——等比放大 1.2~2 倍填满长条，且不会把车轮
/// 拉成椭圆。
class _SpriteBodyPainter extends CustomPainter {
  _SpriteBodyPainter(this.image);

  final ui.Image image;

  static const double _fillW = 0.8;
  static const double _fillH = 0.45;

  /// 收缩系数：让车身与格子边框留出空气（实测 0.9 仍会压到白色描边）
  static const double _inset = 0.83;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.high
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (iw <= 0 || ih <= 0) return;

    // 车模侧视车头朝右；竖车整体转 90°，车头朝下（与 mini 端一致）。
    final bw = size.height;
    final bh = size.width;
    final s = math.min(bw / (iw * _fillW), bh / (ih * _fillH)) * _inset;
    final dw = iw * s;
    final dh = ih * s;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 2);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
      _paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpriteBodyPainter old) => old.image != image;
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

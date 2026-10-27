import 'package:flutter/material.dart';

import '../models/traffic_sign.dart';

/// 交通标志面板形状（真实路牌的三类：圆形指示/禁令、方形指路、三角警告）。
enum TrafficSignShape { circle, square, triangle }

/// 每种标志的面板形状。
TrafficSignShape _shapeOf(TrafficSignKind kind) => switch (kind) {
  TrafficSignKind.parking ||
  TrafficSignKind.trafficLight ||
  TrafficSignKind.straight ||
  TrafficSignKind.ramp ||
  TrafficSignKind.glide ||
  TrafficSignKind.tunnel ||
  TrafficSignKind.anchor ||
  TrafficSignKind.factory => TrafficSignShape.square,
  TrafficSignKind.noEntry || TrafficSignKind.orbit => TrafficSignShape.circle,
  TrafficSignKind.turn ||
  TrafficSignKind.crossing ||
  TrafficSignKind.warning => TrafficSignShape.triangle,
};

/// 每种标志的面板图形（Material 图标里现成的路牌符号）。
IconData _iconOf(TrafficSignKind kind) => switch (kind) {
  TrafficSignKind.parking => Icons.local_parking_rounded,
  TrafficSignKind.trafficLight => Icons.traffic_rounded,
  TrafficSignKind.turn => Icons.turn_sharp_left_rounded,
  TrafficSignKind.crossing => Icons.close_rounded,
  TrafficSignKind.straight => Icons.arrow_upward_rounded,
  TrafficSignKind.ramp => Icons.north_east_rounded,
  TrafficSignKind.glide => Icons.south_east_rounded,
  TrafficSignKind.tunnel => Icons.arrow_downward_rounded,
  TrafficSignKind.anchor => Icons.anchor_rounded,
  TrafficSignKind.factory => Icons.factory_rounded,
  TrafficSignKind.warning => Icons.priority_high_rounded,
  TrafficSignKind.noEntry => Icons.do_not_disturb_on_rounded,
  TrafficSignKind.orbit => Icons.autorenew_rounded,
};

/// 通用交通标志。
///
/// 停车模式把它当**章节图标**与**关卡格子符号**，替代原来的车模 PNG：
/// 一章 36 关全是同一款车时，车模只会变成 36 份重复噪音；
/// 而换别的车当图标又会提前剧透玩家还没解锁的车型。详见 [TrafficSignKind]。
///
/// 图形与颜色都由调用方给（`color` 用章节身份色），所以同一套标志
/// 换章节换色就能区分，不用为每一章画一张图。
class TrafficSign extends StatelessWidget {
  final TrafficSignKind kind;
  final double size;

  /// 描边 + 图形颜色，一般传章节身份色。
  final Color color;

  /// 面板底色（默认奶白，像真的搪瓷路牌）。
  final Color face;

  const TrafficSign({
    super.key,
    required this.kind,
    required this.size,
    required this.color,
    this.face = const Color(0xFFFDFDFB),
  });

  @override
  Widget build(BuildContext context) {
    final shape = _shapeOf(kind);
    final ink = color;
    final bg = face;
    final stroke = size * 0.07;
    final glyph = Icon(
      _iconOf(kind),
      size: size * _glyphScale(kind),
      color: ink,
    );

    switch (shape) {
      case TrafficSignShape.circle:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: ink, width: stroke),
          ),
          child: glyph,
        );
      case TrafficSignShape.square:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(size * 0.2),
            border: Border.all(color: ink, width: stroke),
          ),
          child: glyph,
        );
      case TrafficSignShape.triangle:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TriangleSignPainter(
                    face: bg,
                    ring: ink,
                    stroke: stroke,
                  ),
                ),
              ),
              // 三角形重心偏低，图形跟着下沉一点才显得居中。
              Padding(
                padding: EdgeInsets.only(top: size * 0.18),
                child: glyph,
              ),
            ],
          ),
        );
    }
  }
}

/// 图标相对面板的尺寸系数：三角形可用面积小，P 面板几乎占满。
double _glyphScale(TrafficSignKind kind) => switch (kind) {
  TrafficSignKind.parking => 0.66,
  TrafficSignKind.turn ||
  TrafficSignKind.crossing ||
  TrafficSignKind.warning => 0.46,
  _ => 0.56,
};

/// 三角警告牌：白面 + 圆角描边。
class _TriangleSignPainter extends CustomPainter {
  final Color face;
  final Color ring;
  final double stroke;

  const _TriangleSignPainter({
    required this.face,
    required this.ring,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.055)
      ..lineTo(w * 0.965, h * 0.925)
      ..lineTo(w * 0.035, h * 0.925)
      ..close();
    canvas.drawPath(path, Paint()..color = face);
    canvas.drawPath(
      path,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TriangleSignPainter old) =>
      old.face != face || old.ring != ring || old.stroke != stroke;
}

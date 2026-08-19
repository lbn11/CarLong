import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/car.dart';

/// 用 Canvas 绘制 8 种车辆的"玩具车"风格剪影(侧视图, 车头朝左)。
/// 采用奶油色渐变车身 + 顶部镜面高光 + 大轮胎 + 柔和高光点，
/// 营造类似 3D 渲染玩具车的圆润光泽质感。车体用等级色系，识别度高。
void paintVehicleIcon(
  Canvas canvas,
  CarTier tier,
  double size, {
  Color body = const Color(0xFFFFFFFF),
  Color? shade,
}) {
  // 用启动时量好的外接框，把视觉中心平移到 (50,50)，
  // 保证在卡片/格子里始终居中。量不到（异常）时退回原样绘制。
  final bounds = _tierBounds[tier];
  canvas.save();
  canvas.scale(size / 100);
  if (bounds != null) {
    canvas.translate(50 - bounds.center.dx, 50 - bounds.center.dy);
  }
  _paintTier(canvas, tier, body);
  canvas.restore();
}

/// 炸弹卡图标：黑色炸弹球 + 引信 + 星芒警示。
void paintBombIcon(Canvas canvas, double size) {
  canvas.save();
  canvas.scale(size / 100);
  final cx = 50.0, cy = 58.0;
  // 引信火花
  canvas.drawLine(
    Offset(cx + 4, cy - 32),
    Offset(cx + 16, cy - 52),
    Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawCircle(
    Offset(cx + 20, cy - 56),
    8,
    Paint()..color = const Color(0xFFFFB300),
  );
  // 弹体
  canvas.drawCircle(
    Offset(cx, cy),
    30,
    Paint()
      ..color = const Color(0xFF3E444C)
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: const [Color(0xFF59616B), Color(0xFF23272D)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 30)),
  );
  // 高光
  canvas.drawCircle(
    Offset(cx - 10, cy - 12),
    7,
    Paint()..color = const Color(0x66FFFFFF),
  );
  // 警示星芒
  final star = Paint()
    ..color = const Color(0xFFFFCA28)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 8; i++) {
    final a = i * pi / 4;
    canvas.drawLine(
      Offset(cx + 30 * cos(a), cy + 30 * sin(a)),
      Offset(cx + 40 * cos(a), cy + 40 * sin(a)),
      star,
    );
  }
  canvas.restore();
}

/// 万能卡图标：金色星星 + 全彩光环。
void paintWildcardIcon(Canvas canvas, double size) {
  canvas.save();
  canvas.scale(size / 100);
  final cx = 50.0, cy = 50.0;
  // 全彩光环
  canvas.drawCircle(
    Offset(cx, cy),
    34,
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF5252),
          Color(0xFFFFCA28),
          Color(0xFF66BB6A),
          Color(0xFF42A5F5),
          Color(0xFFAB47BC),
          Color(0xFFFF5252),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 34)),
  );
  // 五角星
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final a = -pi / 2 + i * pi / 5;
    final r = i.isEven ? 24.0 : 11.0;
    final p = Offset(cx + r * cos(a), cy + r * sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFFFFD54F)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFFFF176), Color(0xFFFFA000)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 28)),
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFFB28704)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  canvas.restore();
}

void _paintTier(Canvas canvas, CarTier tier, Color body) {
  switch (tier) {
    case CarTier.bike:
      _drawBike(canvas, body);
    case CarTier.scooter:
      _drawScooter(canvas, body);
    case CarTier.car:
      _drawCar(canvas, body);
    case CarTier.taxi:
      _drawTaxi(canvas, body);
    case CarTier.bus:
      _drawBus(canvas, body);
    case CarTier.truck:
      _drawTruck(canvas, body);
    case CarTier.train:
      _drawTrain(canvas, body);
    case CarTier.rocket:
      _drawRocket(canvas, body);
    case CarTier.tanker:
      _drawTanker(canvas, body);
    case CarTier.metro:
      _drawMetro(canvas, body);
    case CarTier.plane:
      _drawPlane(canvas, body);
    case CarTier.jet:
      _drawJet(canvas, body);
    case CarTier.shuttle:
      _drawShuttle(canvas, body);
    case CarTier.ufo:
      _drawUfo(canvas, body);
    case CarTier.maglev:
      _drawMaglev(canvas, body);
    case CarTier.station:
      _drawStation(canvas, body);
    case CarTier.comet:
      _drawComet(canvas, body);
    // 任务93 新档：PNG 是主视觉，此处兜底剪影复用最接近的绘制。
    case CarTier.warp:
      _drawRocket(canvas, body);
    case CarTier.hover:
      _drawUfo(canvas, body);
    case CarTier.cruiser:
      _drawShuttle(canvas, body);
    case CarTier.mecha:
      _drawTruck(canvas, body);
    case CarTier.antigrav:
      _drawUfo(canvas, body);
  }
}

/// 每种车型绘制内容的外接框缓存（64×64 坐标，启动预计算更快）。
/// 由 [precomputeVehicleBounds] 在启动时一次性量好。
final Map<CarTier, Rect> _tierBounds = <CarTier, Rect>{};

/// 离屏渲染分辨率（启动预计算用，越小越快）。
const int _boundsRes = 64;

/// 把每种车型离屏渲染到 64×64，扫描不透明像素得到真实内容外接框。
/// 在 runApp 前 await 调用，确保首帧就有精确的居中数据。
Future<void> precomputeVehicleBounds() async {
  for (final tier in CarTier.values) {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _paintTier(canvas, tier, const Color(0xFFFFFFFF));
      final image = await recorder.endRecording().toImage(_boundsRes, _boundsRes);
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      image.dispose();
      if (data == null) continue;
      final bytes = data.buffer.asUint8List();
      var minX = _boundsRes, minY = _boundsRes, maxX = -1, maxY = -1;
      for (var y = 0; y < _boundsRes; y++) {
        for (var x = 0; x < _boundsRes; x++) {
          if (bytes[(y * _boundsRes + x) * 4 + 3] > 0) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (maxX >= 0) {
        _tierBounds[tier] = Rect.fromLTRB(
          minX.toDouble(),
          minY.toDouble(),
          (maxX + 1).toDouble(),
          (maxY + 1).toDouble(),
        );
      }
    } catch (_) {
      // 个别平台渲染失败时跳过，仅退回不做居中。
    }
  }
}

const _ink = Color(0xFF161A20);
const _glass = Color(0xFF101A28);
const _hubHi = Color(0xFFD9E1EA);
const _hubLo = Color(0xFF39424D);

/// 车身奶油色系：顶部打亮、中部主体、底部压暗，模拟 3D 受光。
List<Color> _bodyColors(Color base) {
  final mid = Color.lerp(base, Colors.white, 0.42)!;
  return <Color>[
    Color.lerp(mid, Colors.white, 0.55)!,
    mid,
    Color.lerp(mid, Colors.black, 0.3)!,
  ];
}

Color _edge(Color base) => Color.lerp(base, Colors.black, 0.5)!;

Paint _fill(Color base, Rect rect) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: _bodyColors(base),
  ).createShader(rect);

/// 圆角车身填充：渐变 + 描边 + 底部内阴影(立体感)。
void _fillRRect(Canvas c, RRect rr, Color base) {
  c.drawRRect(rr, _fill(base, rr.outerRect));
  c.drawRRect(
    rr,
    Paint()
      ..color = _edge(base)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round,
  );
  final r = rr.outerRect;
  final h = r.height * 0.3;
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(r.left + 1.5, r.bottom - h, r.width - 3, h),
      Radius.circular(rr.tlRadius.x),
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.14),
  );
}

/// 异形车身填充：渐变 + 描边 + 底部内阴影。
void _fillPath(Canvas c, Path p, Color base) {
  c.drawPath(p, _fill(base, p.getBounds()));
  c.drawPath(
    p,
    Paint()
      ..color = _edge(base)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round,
  );
  c.save();
  c.clipPath(p);
  final b = p.getBounds();
  c.drawRect(
    Rect.fromLTWH(b.left, b.bottom - b.height * 0.28, b.width, b.height * 0.28),
    Paint()..color = Colors.black.withValues(alpha: 0.13),
  );
  c.restore();
}

/// 顶部镜面高光：白色渐变从强到无，模拟烤漆反光。
void _glossTop(
  Canvas c,
  Rect body,
  double radius, {
  double inset = 3,
  double hFrac = 0.45,
}) {
  final r = Rect.fromLTWH(
    body.left + inset,
    body.top + inset * 0.6,
    body.width - inset * 2,
    body.height * hFrac,
  );
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  c.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(r),
  );
  c.restore();
}

/// 小范围镜面光斑(引擎盖/车顶的小亮点)。
void _specular(Canvas c, Offset center, double r) {
  c.drawCircle(center, r, Paint()..color = Colors.white.withValues(alpha: 0.5));
  c.drawCircle(
    center - Offset(r * 0.3, r * 0.3),
    r * 0.45,
    Paint()..color = Colors.white.withValues(alpha: 0.9),
  );
}

/// 与地面接触的柔和投影。
void _groundShadow(Canvas c, double x0, double x1, double y) {
  c.drawOval(
    Rect.fromLTRB(x0, y - 3, x1, y + 6),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
}

/// 大块头玩具轮胎：深色胎面 + 顶部高光弧 + 渐变轮毂 + 高光点。
void _toyWheel(Canvas c, Offset center, double r) {
  c.drawCircle(center, r, Paint()..color = _ink);
  c.drawArc(
    Rect.fromCircle(center: center, radius: r - 0.5),
    -pi * 1.2,
    pi * 0.85,
    false,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round,
  );
  final hub = r * 0.58;
  c.drawCircle(
    center,
    hub,
    Paint()
      ..shader = RadialGradient(
        colors: const [_hubHi, Color(0xFF7E8A99), _hubLo],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(
        Rect.fromCircle(center: center - Offset(hub, hub), radius: hub * 2),
      ),
  );
  c.drawCircle(center, hub * 0.32, Paint()..color = const Color(0xFF232A33));
  c.drawCircle(
    center - Offset(hub * 0.26, hub * 0.26),
    hub * 0.2,
    Paint()..color = Colors.white.withValues(alpha: 0.9),
  );
}

/// 玩具车窗：深色玻璃 + 斜向反光条 + 小亮点。
void _toyWindow(Canvas c, RRect w) {
  c.drawRRect(w, Paint()..color = _glass);
  c.drawRRect(
    w,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  c.save();
  c.clipRRect(w);
  final r = w.outerRect;
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        r.left - r.width * 0.15,
        r.bottom - r.height * 0.62,
        r.width * 1.45,
        r.height * 0.34,
      ),
      Radius.circular(r.height * 0.4),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.4),
  );
  c.drawCircle(
    Offset(r.left + r.width * 0.7, r.top + r.height * 0.32),
    r.height * 0.12,
    Paint()..color = Colors.white.withValues(alpha: 0.6),
  );
  c.restore();
}

void _headlight(Canvas c, Offset o) {
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: 6, height: 9),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0xFFFFF7D6),
  );
  c.drawCircle(o + Offset(2.5, -2.5), 2.5,
      Paint()..color = const Color(0x33FFFFFF));
}

void _taillight(Canvas c, Offset o) {
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: 6, height: 9),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0xFFFF5B57),
  );
}

void _drawBike(Canvas c, Color base) {
  _groundShadow(c, 22, 78, 80);
  _toyWheel(c, const Offset(36, 74), 14);
  _toyWheel(c, const Offset(64, 74), 14);

  final bounds = Rect.fromLTRB(20, 20, 76, 62);
  final frame = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: _bodyColors(base),
    ).createShader(bounds);
  final path = Path()
    ..moveTo(58, 26) // 座垫下
    ..lineTo(46, 50) // 底部中轴
    ..lineTo(28, 32) // 车头
    ..moveTo(58, 26)
    ..lineTo(64, 68) // 座管到后轮
    ..moveTo(46, 50)
    ..lineTo(36, 68); // 链拉到前轮
  c.drawPath(path, frame);
  // 车把
  c.drawLine(
    const Offset(19, 22),
    const Offset(30, 30),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _bodyColors(base),
      ).createShader(Rect.fromLTRB(19, 22, 30, 30)),
  );
  // 玩具座垫
  final seat = RRect.fromRectAndRadius(
    const Rect.fromLTWH(53, 17, 20, 10),
    const Radius.circular(5),
  );
  _fillRRect(c, seat, base);
  _glossTop(c, seat.outerRect, 5, inset: 2, hFrac: 0.5);
}

void _drawScooter(Canvas c, Color base) {
  _groundShadow(c, 22, 78, 82);
  _toyWheel(c, const Offset(30, 78), 13);
  _toyWheel(c, const Offset(62, 78), 13);
  // 踏板
  final deck = RRect.fromRectAndRadius(
    const Rect.fromLTWH(24, 70, 46, 11),
    const Radius.circular(5.5),
  );
  _fillRRect(c, deck, base);
  _glossTop(c, deck.outerRect, 5, inset: 2, hFrac: 0.4);
  // 前柱
  c.drawLine(
    const Offset(30, 64),
    const Offset(30, 42),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _bodyColors(base),
      ).createShader(Rect.fromLTRB(27, 42, 33, 64)),
  );
  // 车把 + 车灯
  c.drawLine(
    const Offset(22, 34),
    const Offset(38, 38),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _bodyColors(base),
      ).createShader(Rect.fromLTRB(22, 34, 38, 38)),
  );
  _headlight(c, const Offset(24, 36));
  // 座管 + 座垫
  c.drawLine(
    const Offset(56, 54),
    const Offset(56, 70),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _bodyColors(base),
      ).createShader(Rect.fromLTRB(53, 54, 59, 70)),
  );
  final seat = RRect.fromRectAndRadius(
    const Rect.fromLTWH(44, 46, 26, 11),
    const Radius.circular(5.5),
  );
  _fillRRect(c, seat, base);
  _glossTop(c, seat.outerRect, 5, inset: 2, hFrac: 0.45);
}

void _drawCar(Canvas c, Color base) {
  _groundShadow(c, 10, 90, 88);
  _toyWheel(c, const Offset(34, 84), 13);
  _toyWheel(c, const Offset(68, 84), 13);
  // 座舱
  final cabin = RRect.fromRectAndRadius(
    const Rect.fromLTWH(30, 36, 42, 22),
    const Radius.circular(11),
  );
  _fillRRect(c, cabin, base);
  _glossTop(c, cabin.outerRect, 11, hFrac: 0.5);
  // 车身
  final body = RRect.fromRectAndRadius(
    const Rect.fromLTWH(6, 54, 88, 32),
    const Radius.circular(16),
  );
  _fillRRect(c, body, base);
  _glossTop(c, body.outerRect, 16, hFrac: 0.42);
  _specular(c, const Offset(18, 58), 4);
  // 车窗
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(35, 42, 12, 11),
      const Radius.circular(5),
    ),
  );
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(53, 42, 12, 11),
      const Radius.circular(5),
    ),
  );
  _headlight(c, const Offset(12, 68));
  _taillight(c, const Offset(88, 68));
}

void _drawTaxi(Canvas c, Color base) {
  // 车顶灯
  final sign = RRect.fromRectAndRadius(
    const Rect.fromLTWH(43, 22, 14, 8),
    const Radius.circular(4),
  );
  c.drawRRect(
    sign,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFFFD54F), Color(0xFFFF9800)],
      ).createShader(sign.outerRect),
  );
  c.drawRRect(
    sign,
    Paint()
      ..color = _edge(base)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(43, 22, 14, 3.5),
      const Radius.circular(2),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.5),
  );
  _drawCar(c, base);
}

void _drawBus(Canvas c, Color base) {
  _groundShadow(c, 8, 92, 86);
  _toyWheel(c, const Offset(22, 84), 11);
  _toyWheel(c, const Offset(50, 84), 11);
  _toyWheel(c, const Offset(78, 84), 11);
  final body = RRect.fromRectAndRadius(
    const Rect.fromLTWH(6, 34, 88, 52),
    const Radius.circular(13),
  );
  _fillRRect(c, body, base);
  _glossTop(c, body.outerRect, 13, hFrac: 0.35);
  _specular(c, const Offset(16, 40), 3.5);
  const wx = [11.0, 29.0, 47.0, 65.0];
  for (final x in wx) {
    _toyWindow(
      c,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 41, 14, 15),
        const Radius.circular(5),
      ),
    );
  }
  _headlight(c, const Offset(9, 68));
  _taillight(c, const Offset(91, 68));
}

void _drawTruck(Canvas c, Color base) {
  _groundShadow(c, 10, 90, 88);
  _toyWheel(c, const Offset(28, 84), 11);
  _toyWheel(c, const Offset(44, 84), 11);
  _toyWheel(c, const Offset(68, 84), 11);
  _toyWheel(c, const Offset(84, 84), 11);
  // 货厢
  final cargo = RRect.fromRectAndRadius(
    const Rect.fromLTWH(44, 26, 50, 58),
    const Radius.circular(8),
  );
  _fillRRect(c, cargo, base);
  _glossTop(c, cargo.outerRect, 8, hFrac: 0.3);
  final rib = Paint()
    ..color = _edge(base).withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;
  c.drawLine(const Offset(66, 32), const Offset(66, 78), rib);
  c.drawLine(const Offset(84, 32), const Offset(84, 78), rib);
  // 驾驶室
  final cab = RRect.fromRectAndRadius(
    const Rect.fromLTWH(6, 46, 34, 38),
    const Radius.circular(10),
  );
  _fillRRect(c, cab, base);
  _glossTop(c, cab.outerRect, 10, hFrac: 0.4);
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 52, 16, 13),
      const Radius.circular(5),
    ),
  );
  _headlight(c, const Offset(9, 70));
  _taillight(c, const Offset(42, 70));
}

void _drawTrain(Canvas c, Color base) {
  _groundShadow(c, 8, 92, 88);
  _toyWheel(c, const Offset(16, 84), 9);
  _toyWheel(c, const Offset(36, 84), 9);
  _toyWheel(c, const Offset(58, 84), 9);
  _toyWheel(c, const Offset(78, 84), 9);
  final p = Path()
    ..moveTo(30, 34)
    ..quadraticBezierTo(14, 34, 8, 50)
    ..quadraticBezierTo(4, 68, 16, 80)
    ..lineTo(84, 80)
    ..quadraticBezierTo(94, 79, 94, 66)
    ..quadraticBezierTo(94, 46, 80, 34)
    ..close();
  _fillPath(c, p, base);
  // 顶部高光条带
  c.save();
  c.clipPath(p);
  final b = p.getBounds();
  c.drawRect(
    Rect.fromLTWH(b.left, b.top, b.width, b.height * 0.3),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, 10, b.height * 0.3)),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(b.left + 14, b.top + 4, b.width - 30, b.height * 0.16),
      const Radius.circular(5),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.4),
  );
  c.restore();
  const wx = [16.0, 33.0, 50.0, 67.0];
  for (final x in wx) {
    _toyWindow(
      c,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 40, 13, 13),
        const Radius.circular(5),
      ),
    );
  }
  _headlight(c, const Offset(10, 62));
  // 底部灯带
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 74, 76, 4),
      const Radius.circular(2),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.25),
  );
}

void _drawRocket(Canvas c, Color base) {
  _groundShadow(c, 36, 64, 90);
  // 尾翼
  c.drawPath(
    Path()
      ..moveTo(40, 62)
      ..quadraticBezierTo(24, 72, 24, 88)
      ..quadraticBezierTo(38, 80, 45, 74)
      ..close(),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _bodyColors(base),
      ).createShader(Rect.fromLTRB(24, 62, 45, 88)),
  );
  c.drawPath(
    Path()
      ..moveTo(60, 62)
      ..quadraticBezierTo(76, 72, 76, 88)
      ..quadraticBezierTo(62, 80, 55, 74)
      ..close(),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _bodyColors(base),
      ).createShader(Rect.fromLTRB(55, 62, 76, 88)),
  );
  // 机身
  final p = Path()
    ..moveTo(50, 4)
    ..quadraticBezierTo(70, 26, 68, 50)
    ..quadraticBezierTo(66, 66, 58, 78)
    ..lineTo(42, 78)
    ..quadraticBezierTo(34, 66, 32, 50)
    ..quadraticBezierTo(30, 26, 50, 4)
    ..close();
  _fillPath(c, p, base);
  // 机身左侧高光
  c.save();
  c.clipPath(p);
  final b = p.getBounds();
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(b.left + 6, b.top + 10, 12, b.height * 0.5),
      const Radius.circular(6),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
  c.restore();
  // 舱窗
  c.drawCircle(const Offset(50, 42), 10, Paint()..color = _glass);
  c.drawCircle(
    const Offset(50, 42),
    10,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  c.drawCircle(
    const Offset(46, 38),
    4,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
  // 尾焰
  c.drawPath(
    Path()
      ..moveTo(42, 80)
      ..quadraticBezierTo(50, 94, 58, 80)
      ..close(),
    Paint()..color = const Color(0xFFFFB300),
  );
  c.drawPath(
    Path()
      ..moveTo(46, 80)
      ..quadraticBezierTo(50, 88, 54, 80)
      ..close(),
    Paint()..color = const Color(0xFFFFF3C4),
  );
}

void _drawTanker(Canvas c, Color base) {
  _groundShadow(c, 8, 92, 86);
  _toyWheel(c, const Offset(26, 84), 11);
  _toyWheel(c, const Offset(44, 84), 11);
  _toyWheel(c, const Offset(68, 84), 11);
  _toyWheel(c, const Offset(84, 84), 11);
  // 罐体：横置圆筒
  final tank = RRect.fromRectAndRadius(
    const Rect.fromLTWH(38, 26, 54, 44),
    const Radius.circular(22),
  );
  _fillRRect(c, tank, base);
  _glossTop(c, tank.outerRect, 22, hFrac: 0.3);
  // 罐体加强环
  final ring = Paint()
    ..color = _edge(base).withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;
  c.drawLine(const Offset(58, 28), const Offset(58, 68), ring);
  c.drawLine(const Offset(76, 30), const Offset(76, 66), ring);
  // 右端盖（圆拱 + 高光）
  c.drawCircle(
    Offset(87, 48),
    12,
    Paint()
      ..shader = RadialGradient(
        colors: _bodyColors(base),
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: const Offset(84, 45), radius: 12)),
  );
  c.drawCircle(
    const Offset(84, 44),
    3,
    Paint()..color = Colors.white.withValues(alpha: 0.5),
  );
  // 驾驶室
  final cab = RRect.fromRectAndRadius(
    const Rect.fromLTWH(6, 48, 32, 36),
    const Radius.circular(10),
  );
  _fillRRect(c, cab, base);
  _glossTop(c, cab.outerRect, 10, hFrac: 0.42);
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 54, 15, 12),
      const Radius.circular(5),
    ),
  );
  _headlight(c, const Offset(9, 72));
  _taillight(c, const Offset(44, 72));
}

void _drawMetro(Canvas c, Color base) {
  _groundShadow(c, 6, 94, 84);
  // 全裙板流线车身（左端尖鼻）
  final p = Path()
    ..moveTo(18, 40)
    ..quadraticBezierTo(4, 42, 4, 54)
    ..quadraticBezierTo(4, 78, 28, 78)
    ..lineTo(92, 78)
    ..quadraticBezierTo(96, 78, 96, 62)
    ..quadraticBezierTo(96, 44, 78, 40)
    ..close();
  _fillPath(c, p, base);
  c.save();
  c.clipPath(p);
  final b = p.getBounds();
  // 顶部高光
  c.drawRect(
    Rect.fromLTWH(b.left, b.top, b.width, b.height * 0.22),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, 10, b.height * 0.22)),
  );
  // 腰带高光条
  c.drawRect(
    Rect.fromLTWH(b.left + 8, 62, b.width - 16, 4),
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );
  c.restore();
  // 车头挡风 + 长车窗带
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(7, 46, 11, 13),
      const Radius.circular(5),
    ),
  );
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(25, 46, 30, 13),
      const Radius.circular(6),
    ),
  );
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(60, 46, 30, 13),
      const Radius.circular(6),
    ),
  );
  _headlight(c, const Offset(7, 64));
  // 裙板反光 + 轨道线
  final rail = Paint()
    ..color = const Color(0xCC555F6B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  c.drawLine(const Offset(10, 90), const Offset(90, 90), rail);
  _specular(c, const Offset(22, 44), 2.5);
}

void _drawPlane(Canvas c, Color base) {
  _groundShadow(c, 16, 84, 88);
  // 垂尾 + 平尾
  final tailFin = Path()
    ..moveTo(72, 42)
    ..quadraticBezierTo(70, 22, 62, 14)
    ..quadraticBezierTo(84, 22, 86, 42)
    ..close();
  _fillPath(c, tailFin, base);
  final tailWing = Path()
    ..moveTo(68, 42)
    ..lineTo(66, 52)
    ..lineTo(90, 52)
    ..lineTo(88, 42)
    ..close();
  _fillPath(c, tailWing, base);
  // 机身
  final body = RRect.fromRectAndRadius(
    const Rect.fromLTWH(12, 42, 76, 18),
    const Radius.circular(9),
  );
  _fillRRect(c, body, base);
  _glossTop(c, body.outerRect, 9, hFrac: 0.55);
  // 机头挡风
  _toyWindow(
    c,
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(15, 46, 10, 10),
      const Radius.circular(5),
    ),
  );
  // 舷窗
  const ports = [34.0, 48.0, 62.0];
  for (final x in ports) {
    c.drawCircle(Offset(x + 8, 51), 3, Paint()..color = _glass);
    c.drawCircle(
      Offset(x + 7.4, 50.4),
      1.2,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }
  // 主翼
  final wing = Path()
    ..moveTo(44, 58)
    ..quadraticBezierTo(38, 76, 24, 84)
    ..quadraticBezierTo(60, 82, 72, 58)
    ..close();
  _fillPath(c, wing, base);
  // 翼下发动机
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(42, 62, 16, 11),
      const Radius.circular(5.5),
    ),
    Paint()..color = _edge(base),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(45, 64, 10, 7),
      const Radius.circular(3.5),
    ),
    Paint()..color = const Color(0xFFB7C2CE),
  );
  _taillight(c, const Offset(86, 51));
  _specular(c, const Offset(24, 44), 3);
}

void _drawJet(Canvas c, Color base) {
  _groundShadow(c, 12, 88, 88);
  // 尾焰
  c.drawPath(
    Path()
      ..moveTo(78, 50)
      ..quadraticBezierTo(95, 42, 95, 50)
      ..quadraticBezierTo(95, 58, 78, 58)
      ..close(),
    Paint()..color = const Color(0xFFFFB300),
  );
  c.drawPath(
    Path()
      ..moveTo(80, 50)
      ..quadraticBezierTo(91, 46, 91, 50)
      ..quadraticBezierTo(91, 54, 80, 54)
      ..close(),
    Paint()..color = const Color(0xFFFFF3C4),
  );
  // 三角主翼
  final wing = Path()
    ..moveTo(52, 52)
    ..quadraticBezierTo(36, 74, 16, 84)
    ..quadraticBezierTo(48, 80, 70, 54)
    ..close();
  _fillPath(c, wing, base);
  _glossTop(c, wing.getBounds(), 6, inset: 2, hFrac: 0.4);
  // 垂尾
  final fin = Path()
    ..moveTo(64, 44)
    ..quadraticBezierTo(62, 24, 56, 16)
    ..quadraticBezierTo(78, 26, 78, 44)
    ..close();
  _fillPath(c, fin, base);
  // 机身（尖鼻）
  final body = Path()
    ..moveTo(6, 52)
    ..quadraticBezierTo(16, 42, 40, 42)
    ..lineTo(72, 42)
    ..quadraticBezierTo(78, 42, 78, 50)
    ..lineTo(78, 54)
    ..quadraticBezierTo(72, 60, 40, 60)
    ..quadraticBezierTo(16, 62, 6, 52)
    ..close();
  _fillPath(c, body, base);
  // 座舱罩
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 36, 22, 13),
      const Radius.circular(7),
    ),
    Paint()..color = _glass,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 36, 22, 13),
      const Radius.circular(7),
    ),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  // 机头进气道
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 46, 9, 12),
      const Radius.circular(4.5),
    ),
    Paint()..color = const Color(0xFF101A28),
  );
  _specular(c, const Offset(30, 43), 2.5);
}

void _drawShuttle(Canvas c, Color base) {
  _groundShadow(c, 14, 86, 86);
  // 发动机喷口 + 尾焰
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(70, 52, 12, 10),
      const Radius.circular(4),
    ),
    Paint()..color = const Color(0xFF101A28),
  );
  c.drawPath(
    Path()
      ..moveTo(80, 50)
      ..quadraticBezierTo(94, 56, 80, 64)
      ..close(),
    Paint()..color = const Color(0xFFFFB300),
  );
  // 尾翼
  final fin = Path()
    ..moveTo(60, 44)
    ..quadraticBezierTo(56, 20, 50, 12)
    ..quadraticBezierTo(74, 22, 72, 44)
    ..close();
  _fillPath(c, fin, base);
  // 三角翼
  final wing = Path()
    ..moveTo(50, 56)
    ..quadraticBezierTo(30, 76, 12, 84)
    ..quadraticBezierTo(48, 80, 68, 58)
    ..close();
  _fillPath(c, wing, base);
  // 机身
  final body = Path()
    ..moveTo(6, 52)
    ..quadraticBezierTo(16, 44, 42, 44)
    ..lineTo(68, 44)
    ..quadraticBezierTo(74, 44, 74, 54)
    ..lineTo(74, 58)
    ..quadraticBezierTo(66, 62, 42, 62)
    ..quadraticBezierTo(16, 64, 6, 52)
    ..close();
  _fillPath(c, body, base);
  // 机鼻黑色隔热瓦
  c.drawPath(
    Path()
      ..moveTo(6, 52)
      ..quadraticBezierTo(14, 47, 24, 46)
      ..quadraticBezierTo(16, 60, 8, 56)
      ..close(),
    Paint()..color = const Color(0xFF232A33),
  );
  // 座舱窗
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 42, 13, 10),
      const Radius.circular(4.5),
    ),
    Paint()..color = _glass,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 42, 13, 10),
      const Radius.circular(4.5),
    ),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  // 货舱门线
  c.drawLine(
    const Offset(30, 53),
    const Offset(66, 53),
    Paint()
      ..color = _edge(base).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  _specular(c, const Offset(34, 46), 3);
}

void _drawUfo(Canvas c, Color base) {
  _groundShadow(c, 14, 86, 88);
  // 顶部天线 + 信号灯
  c.drawLine(
    const Offset(50, 34),
    const Offset(50, 22),
    Paint()
      ..color = _edge(base)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );
  c.drawCircle(
    const Offset(50, 20),
    2.5,
    Paint()..color = const Color(0xFFFF5B57),
  );
  // 中央玻璃穹顶
  final dome = Path()
    ..moveTo(38, 48)
    ..quadraticBezierTo(38, 30, 50, 30)
    ..quadraticBezierTo(62, 30, 62, 48)
    ..close();
  _fillPath(c, dome, _glass);
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(43, 34, 14, 13),
      const Radius.circular(6),
    ),
    Paint()..color = _glass,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(43, 34, 14, 13),
      const Radius.circular(6),
    ),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  // 飞碟主体
  final disk = Path()
    ..moveTo(14, 56)
    ..quadraticBezierTo(20, 42, 50, 42)
    ..quadraticBezierTo(80, 42, 86, 56)
    ..quadraticBezierTo(80, 68, 50, 68)
    ..quadraticBezierTo(20, 68, 14, 56)
    ..close();
  _fillPath(c, disk, base);
  c.save();
  c.clipPath(disk);
  c.drawRect(
    const Rect.fromLTWH(16, 44, 68, 6),
    Paint()..color = Colors.white.withValues(alpha: 0.4),
  );
  c.restore();
  // 环绕小灯
  final lamp = Paint()..color = const Color(0xFFFFD54F);
  c.drawCircle(const Offset(24, 55), 2.5, lamp);
  c.drawCircle(const Offset(76, 55), 2.5, lamp);
  c.drawCircle(const Offset(48, 68), 2.5, lamp);
  // 底部能量环 + 下射光束
  c.drawOval(
    Rect.fromLTWH(26, 60, 48, 10),
    Paint()
      ..color = const Color(0xFFB39DDB).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  c.drawOval(
    Rect.fromLTWH(34, 74, 32, 8),
    Paint()
      ..color = const Color(0x66B39DDB)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
}

/// 磁悬浮列车：流线型长车身 + 玻璃车头 + 底部磁轨。
void _drawMaglev(Canvas c, Color base) {
  _groundShadow(c, 8, 92, 88);
  // 底部磁轨
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 80, 80, 6),
      const Radius.circular(3),
    ),
    Paint()..color = _edge(base).withValues(alpha: 0.5),
  );
  // 车身
  final body = Path()
    ..moveTo(6, 44)
    ..quadraticBezierTo(14, 36, 44, 36)
    ..quadraticBezierTo(78, 36, 92, 50)
    ..quadraticBezierTo(88, 62, 44, 62)
    ..quadraticBezierTo(14, 62, 6, 52)
    ..close();
  _fillPath(c, body, base);
  // 车头玻璃（靠右，行进方向）
  c.drawPath(
    Path()
      ..moveTo(76, 40)
      ..quadraticBezierTo(88, 42, 92, 50)
      ..quadraticBezierTo(84, 56, 74, 56)
      ..close(),
    Paint()..color = _glass,
  );
  // 车窗带
  c.save();
  c.clipPath(body);
  c.drawRect(
    const Rect.fromLTWH(18, 44, 48, 10),
    Paint()
      ..color = _glass.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
  );
  c.restore();
  // 磁轨高光
  c.drawLine(
    const Offset(14, 81),
    const Offset(86, 81),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5,
  );
  _specular(c, const Offset(30, 40), 3);
}

/// 空间站：中央生活舱 + 两侧太阳能帆板 + 天线。
void _drawStation(Canvas c, Color base) {
  _groundShadow(c, 12, 88, 90);
  // 天线
  c.drawLine(
    const Offset(50, 34),
    const Offset(50, 20),
    Paint()
      ..color = _edge(base)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );
  c.drawCircle(const Offset(50, 18), 2.5, Paint()..color = const Color(0xFFFF5B57));
  // 左太阳能帆板
  final lPanel = Path()
    ..moveTo(8, 42)
    ..lineTo(26, 42)
    ..lineTo(26, 68)
    ..lineTo(8, 68)
    ..close();
  _fillPath(c, lPanel, base);
  // 右太阳能帆板
  final rPanel = Path()
    ..moveTo(74, 42)
    ..lineTo(92, 42)
    ..lineTo(92, 68)
    ..lineTo(74, 68)
    ..close();
  _fillPath(c, rPanel, base);
  // 帆板网格
  final grid = Paint()
    ..color = _edge(base).withValues(alpha: 0.4)
    ..strokeWidth = 1;
  for (var x = 12; x <= 22; x += 5) {
    c.drawLine(Offset(x.toDouble(), 44), Offset(x.toDouble(), 66), grid);
  }
  for (var x = 78; x <= 88; x += 5) {
    c.drawLine(Offset(x.toDouble(), 44), Offset(x.toDouble(), 66), grid);
  }
  // 连接杆
  c.drawLine(
    const Offset(26, 55),
    const Offset(74, 55),
    Paint()..color = _edge(base)..strokeWidth = 3,
  );
  // 中央生活舱
  final hub = Path()
    ..moveTo(36, 38)
    ..quadraticBezierTo(50, 32, 64, 38)
    ..lineTo(64, 70)
    ..quadraticBezierTo(50, 76, 36, 70)
    ..close();
  _fillPath(c, hub, base);
  // 舱窗
  final win = Paint()..color = _glass;
  c.drawCircle(const Offset(50, 54), 5, win);
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(40, 50, 20, 8), const Radius.circular(4)),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  _specular(c, const Offset(42, 44), 2.5);
}

/// 彗星：冰核 + 彗尾（拖曳粒子）。
void _drawComet(Canvas c, Color base) {
  _groundShadow(c, 20, 90, 90);
  // 彗尾
  final tail = Path()
    ..moveTo(40, 50)
    ..quadraticBezierTo(14, 26, 2, 18)
    ..quadraticBezierTo(6, 52, 40, 62)
    ..close();
  final tailPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(42, 55),
      const Offset(4, 22),
      [base.withValues(alpha: 0.8), base.withValues(alpha: 0.0)],
    );
  c.drawPath(tail, tailPaint);
  // 尾迹光点
  final glow = Paint()..color = Colors.white.withValues(alpha: 0.7);
  c.drawCircle(const Offset(24, 40), 2, glow);
  c.drawCircle(const Offset(16, 48), 1.5, glow);
  c.drawCircle(const Offset(30, 32), 1.2, glow);
  // 冰核
  final nucleus = Path()
    ..moveTo(34, 34)
    ..quadraticBezierTo(50, 26, 66, 38)
    ..quadraticBezierTo(76, 50, 66, 62)
    ..quadraticBezierTo(50, 72, 34, 60)
    ..quadraticBezierTo(26, 48, 34, 34)
    ..close();
  _fillPath(c, nucleus, base);
  // 环形尘带
  c.save();
  c.clipPath(nucleus);
  c.drawOval(
    Rect.fromLTWH(28, 40, 44, 16),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  c.restore();
  // 冰核斑点
  c.drawCircle(
    const Offset(48, 50),
    3,
    Paint()..color = Colors.white.withValues(alpha: 0.4),
  );
  c.drawCircle(
    const Offset(58, 44),
    2,
    Paint()..color = Colors.white.withValues(alpha: 0.3),
  );
  _specular(c, const Offset(42, 40), 3);
}

/// Flutter 侧的车图标组件(纯图标, 无卡面)。
class VehicleIcon extends StatelessWidget {
  final CarTier tier;
  final double size;
  final Color color;

  const VehicleIcon({
    super.key,
    required this.tier,
    required this.size,
    this.color = const Color(0xFFFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _VehicleIconPainter(tier: tier, color: color),
    );
  }
}

class _VehicleIconPainter extends CustomPainter {
  final CarTier tier;
  final Color color;

  _VehicleIconPainter({required this.tier, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    paintVehicleIcon(canvas, tier, size.shortestSide, body: color);
  }

  @override
  bool shouldRepaint(_VehicleIconPainter oldDelegate) =>
      oldDelegate.tier != tier || oldDelegate.color != color;
}

/// 与棋盘卡面完全一致的迷你卡(牌堆预览/主页用小卡)。
class VehicleCard extends StatelessWidget {
  final CarTier tier;
  final double size;
  final bool enabled;

  const VehicleCard({
    super.key,
    required this.tier,
    this.size = 46,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = tier.color;
    final radius = size * 0.28;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.30)!,
            color,
            Color.lerp(color, Colors.black, 0.28)!,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.32 : 0.15),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size * 0.6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.30),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
              ),
            ),
          ),
          Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: VehicleIcon(tier: tier, size: size * 0.66, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

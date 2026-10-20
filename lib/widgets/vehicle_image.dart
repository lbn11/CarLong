import 'package:flutter/material.dart';

import '../game/vehicle_sprites.dart';
import '../models/vehicle.dart';

/// 车辆图标组件：优先用真实车模 PNG，缺图时回退 emoji。
///
/// 文件名唯一真源是 [VehicleType.sprite]（`assets/vehicles/<sprite>.png`）。
/// 图鉴、目标 chip、首页车队、选关页都用它，一处改完全站生效。
class VehicleImage extends StatelessWidget {
  final VehicleType vehicle;
  final double size;

  /// 保留给「未解锁灰显」等调用方；PNG 模式下由外层 ColorFiltered 控制。
  final Color? color;

  const VehicleImage({
    super.key,
    required this.vehicle,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sprite = vehicle.sprite;
    if (sprite == null) {
      return Text(vehicle.icon, style: TextStyle(fontSize: size * 0.7));
    }
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    // 原图 1024²、一辆车约 4MB 解码内存；按实际显示尺寸降采样即可。
    final cacheW = (size * dpr).clamp(48, 512).round();
    return Image.asset(
      '${VehicleSprites.dir}/$sprite.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      // 兜底剪影：资源缺失时不红屏
      errorBuilder: (context, _, _) =>
          Text(vehicle.icon, style: TextStyle(fontSize: size * 0.7)),
    );
  }
}

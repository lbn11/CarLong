import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// 车辆图标组件：统一使用 emoji 显示车辆。
class VehicleImage extends StatelessWidget {
  final VehicleType vehicle;
  final double size;
  final Color? color;

  const VehicleImage({
    super.key,
    required this.vehicle,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      vehicle.icon,
      style: TextStyle(fontSize: size * 0.7),
    );
  }
}

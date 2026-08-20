import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// 车辆图片组件：优先加载 assets/vehicles/{name}.png，失败时回退到 emoji。
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
    return Image.asset(
      'assets/vehicles/${vehicle.name}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Text(
        vehicle.icon,
        style: TextStyle(fontSize: size * 0.7),
      ),
    );
  }
}

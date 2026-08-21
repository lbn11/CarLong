import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../save/save_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/vehicle_image.dart';

/// 交通图鉴：按 5 大车系分组展示全部车辆，首次合成点亮。
class CollectionScreen extends StatelessWidget {
  final PlayerData data;
  final SaveRepository repo;

  const CollectionScreen({super.key, required this.data, required this.repo});

  @override
  Widget build(BuildContext context) {
    final total = VehicleType.values.length;
    final owned = data.collection.length;
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: AppColors.ink2),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.ink3.withValues(alpha: 0.14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('交通图鉴',
                        style: TextStyle(
                            color: AppColors.ink1,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    _chip(
                      gradient: const [Color(0xFFFFD54F), Color(0xFFFF9800)],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📖', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$owned/$total',
                              style: const TextStyle(
                                  color: Color(0xFF4E342E),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : owned / total,
                    minHeight: 6,
                    backgroundColor: AppColors.ink3.withValues(alpha: 0.18),
                    color: AppColors.accent,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final family in VehicleCategory.values) ...[
                      _buildFamilyHeader(family),
                      const SizedBox(height: 8),
                      _buildFamilyGrid(context, family),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyHeader(VehicleCategory family) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _familyColor(family).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${family.label} ${_familyIcon(family)}',
            style: TextStyle(
              color: AppColors.ink1,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _familySub(family),
            style: const TextStyle(color: AppColors.ink3, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyGrid(BuildContext context, VehicleCategory family) {
    final tiers = VehicleType.values.where((t) => t.category == family).toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final tier in tiers)
          _CollectionCard(
            vehicle: tier,
            unlocked: data.collection.contains(tier.id),
            onTap: () => _showDetail(context, tier),
          ),
      ],
    );
  }

  /// 车型详情弹层（#88）：大图 + 名称 + 车系 + 解锁状态。
  void _showDetail(BuildContext context, VehicleType vehicle) {
    final unlocked = data.collection.contains(vehicle.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.tierCard(vehicle.color, radius: 20),
                child: VehicleImage(vehicle: vehicle, size: 150),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(vehicle.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(vehicle.name,
                      style: const TextStyle(
                          color: AppColors.ink1,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _familyColor(vehicle.category).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${vehicle.category.label}系 · ${_familySub(vehicle.category)}',
                  style: const TextStyle(
                      color: AppColors.ink2,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                unlocked
                    ? '✅ 已收集 · 等级 ${vehicle.id + 1}/${VehicleType.values.length}'
                    : '🔒 未收集 · 合成或停车通关解锁',
                style: TextStyle(
                  color: unlocked ? const Color(0xFF66BB6A) : AppColors.ink3,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 12),
                ),
                child: const Text('好',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _familyColor(VehicleCategory family) => switch (family) {
        VehicleCategory.land => const Color(0xFF66BB6A),
        VehicleCategory.heavy => const Color(0xFF8D6E63),
        VehicleCategory.rail => const Color(0xFF5C6BC0),
        VehicleCategory.maritime => const Color(0xFF0288D1),
        VehicleCategory.air => const Color(0xFF3949AB),
        VehicleCategory.space => const Color(0xFF7E57C2),
      };

  String _familyIcon(VehicleCategory family) => switch (family) {
        VehicleCategory.land => '🚗',
        VehicleCategory.heavy => '🚛',
        VehicleCategory.rail => '🚄',
        VehicleCategory.maritime => '🚢',
        VehicleCategory.air => '✈️',
        VehicleCategory.space => '🚀',
      };

  String _familySub(VehicleCategory family) => switch (family) {
        VehicleCategory.land => '马路上的日常出行',
        VehicleCategory.heavy => '重量级的物流主力',
        VehicleCategory.rail => '奔跑在钢铁轨道上',
        VehicleCategory.maritime => '乘风破浪的水上交通',
        VehicleCategory.air => '划破云层的钢铁之翼',
        VehicleCategory.space => '飞向星辰大海',
      };

  Widget _chip({
    required List<Color> gradient,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

  /// 单辆车辆的图鉴卡片：点亮显示真实 3D 车模，未点亮显示去色剪影。
  class _CollectionCard extends StatelessWidget {
    final VehicleType vehicle;
    final bool unlocked;
    final VoidCallback onTap;

    const _CollectionCard({
      required this.vehicle,
      required this.unlocked,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      final image = VehicleImage(vehicle: vehicle, size: 36);
      return GestureDetector(
        onTap: onTap,
        child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: unlocked
            ? AppTheme.tierCard(vehicle.color, radius: 16)
            : AppTheme.card(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 48,
              child: unlocked
                  ? image
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Opacity(opacity: 0.4, child: image),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              unlocked ? vehicle.name : '???',
              style: TextStyle(
                color: unlocked ? AppTheme.tierInk(vehicle.color) : AppColors.ink3,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unlocked ? vehicle.icon : '未发现',
              style: TextStyle(
                color: unlocked ? AppColors.ink2 : AppColors.ink3,
                fontSize: 10,
              ),
            ),
          ],
        ),
        ),
      );
    }
  }
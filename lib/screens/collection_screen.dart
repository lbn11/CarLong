import 'package:flutter/material.dart';

import '../game/vehicle_icons.dart';
import '../models/car.dart';
import '../save/save_repository.dart';

/// 交通图鉴：按 5 大车系分组展示全部车辆，首次合成点亮。
class CollectionScreen extends StatelessWidget {
  final PlayerData data;
  final SaveRepository repo;

  const CollectionScreen({super.key, required this.data, required this.repo});

  @override
  Widget build(BuildContext context) {
    final total = CarTier.values.length;
    final owned = data.collection.length;
    return Scaffold(
      backgroundColor: const Color(0xFF171A1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.3,
            colors: [Color(0xFF23303E), Color(0xFF171A1E), Color(0xFF0E1013)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x22FFFFFF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('交通图鉴',
                        style: TextStyle(
                            color: Colors.white,
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
                    backgroundColor: const Color(0xFF2C2F36),
                    color: const Color(0xFF4A90D9),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final family in CarFamily.values) ...[
                      _buildFamilyHeader(family),
                      const SizedBox(height: 8),
                      _buildFamilyGrid(family),
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

  Widget _buildFamilyHeader(CarFamily family) {
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
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _familySub(family),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyGrid(CarFamily family) {
    final tiers = CarTier.values.where((t) => t.family == family).toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final tier in tiers)
          _CollectionCard(
            tier: tier,
            unlocked: data.collection.contains(tier.index),
          ),
      ],
    );
  }

  Color _familyColor(CarFamily family) => switch (family) {
        CarFamily.ground => const Color(0xFF66BB6A),
        CarFamily.heavy => const Color(0xFF8D6E63),
        CarFamily.rail => const Color(0xFF5C6BC0),
        CarFamily.air => const Color(0xFF3949AB),
        CarFamily.space => const Color(0xFF7E57C2),
      };

  String _familyIcon(CarFamily family) => switch (family) {
        CarFamily.ground => '🚗',
        CarFamily.heavy => '🚛',
        CarFamily.rail => '🚄',
        CarFamily.air => '✈️',
        CarFamily.space => '🚀',
      };

  String _familySub(CarFamily family) => switch (family) {
        CarFamily.ground => '马路上的日常出行',
        CarFamily.heavy => '重量级的物流主力',
        CarFamily.rail => '奔跑在钢铁轨道上',
        CarFamily.air => '划破云层的钢铁之翼',
        CarFamily.space => '飞向星辰大海',
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

/// 单辆车辆的图鉴卡片：点亮显示彩色车辆，未点亮显示剪影与问号。
class _CollectionCard extends StatelessWidget {
  final CarTier tier;
  final bool unlocked;

  const _CollectionCard({required this.tier, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: unlocked
              ? [tier.color.withValues(alpha: 0.22), const Color(0xFF1E2229)]
              : const [Color(0xFF23262B), Color(0xFF1A1D22)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? tier.color.withValues(alpha: 0.45)
              : const Color(0xFF2A2F38),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: unlocked
                ? VehicleIcon(tier: tier, size: 40, color: tier.color)
                : Icon(Icons.help_outline, color: Colors.white24, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            unlocked ? tier.label : '???',
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unlocked ? tier.icon : '未发现',
            style: TextStyle(
              color: unlocked ? Colors.white60 : Colors.white24,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
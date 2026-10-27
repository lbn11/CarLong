import 'package:flutter/material.dart';

import '../game/audio_feedback.dart';
import '../l10n/l10n.dart';
import '../models/level.dart';
import '../models/vehicle.dart';
import '../save/save_repository.dart';
import '../services/level_data_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_ui.dart';
import '../widgets/pressable.dart';
import '../widgets/vehicle_image.dart';

/// 交通图鉴：按车系分组展示全部车辆，首次合成点亮。
///
/// 视觉设计：每个车系一个身份色（陆地绿 / 重装棕 / 轨道靛 / 水上蓝 / 航空靛 / 太空紫），
/// 卡片用车型渐变打底；未收集用"灰度 + 问号"而不是空洞灰块，保持收藏欲但不惩罚感。
class CollectionScreen extends StatelessWidget {
  final PlayerData data;
  final SaveRepository repo;

  const CollectionScreen({super.key, required this.data, required this.repo});

  @override
  Widget build(BuildContext context) {
    final l = L10n.value;
    final total = VehicleType.values.length;
    final owned = data.collection.length;
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              CandyAppBar(
                title: l.collectionTitle,
                subtitle: l.collectionSubtitle,
                accent: AppColors.grape,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  SoftChip(
                    label: '$owned/$total',
                    icon: Icons.auto_stories_rounded,
                    color: AppColors.lemon,
                    solid: true,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: CandyProgress(
                  value: total == 0 ? 0 : owned / total,
                  color: AppColors.grape,
                  height: 10,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _buildBossWallSection(context),
                    const SizedBox(height: 16),
                    for (final family in VehicleCategory.values) ...[
                      _buildFamilySection(context, family),
                      const SizedBox(height: 16),
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

  /// Boss 徽章墙：56 枚（14 章 × 4）。已击败显主技能 + 绰号/章号，
  /// 未击败是问号剪影。Boss 卡组已全部做成确定性生成（同章同序号永远
  /// 同一只），差的只是"打过"这个事实被记住。
  Widget _buildBossWallSection(BuildContext context) {
    final l = L10n.value;
    final total = LevelDataGenerator.bossTotal;
    final done = data.defeatedBosses.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: l.bossWallTitle,
          subtitle: l.bossWallSub(done, total),
          accent: AppColors.grape,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.84,
          ),
          itemCount: total,
          itemBuilder: (context, i) {
            final c = i ~/ LevelDataGenerator.bossPerChapter;
            final b = i % LevelDataGenerator.bossPerChapter;
            final spec = BossSpec.forLevel(c, b, 5);
            return _BossBadge(
              spec: spec,
              chapterIdx: c,
              bossIndex: b,
              defeated: data.defeatedBosses.contains('$c.$b'),
              onTap: () => _showBossDetail(context, spec, c, b),
            );
          },
        ),
      ],
    );
  }

  /// Boss 详情抽屉：绰号/技能组/所在章。未击败也可见配置——
  /// 收藏墙的意义一半是"还没打过的那些长什么样"。
  void _showBossDetail(
      BuildContext context, BossSpec spec, int c, int b) {
    final l = L10n.value;
    final defeated = data.defeatedBosses.contains('$c.$b');
    final skills = <BossAttackKind>[
      spec.primary,
      if (spec.secondary != null) spec.secondary!,
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceLight, Color(0xFFF3E9F9)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.grape.withValues(alpha: 0.34)),
          boxShadow: [
            BoxShadow(
              color: AppColors.grape.withValues(alpha: 0.26),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.ink3.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                Text(spec.epithetLabel ?? l.bossGuardian(c + 1, b + 1),
                    style: const TextStyle(
                        color: AppColors.ink1,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  b == 3 ? l.signatureBoss : l.bossSlotOrder(b + 1),
                  style: const TextStyle(color: AppColors.ink3, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final k in skills) ...[
                      SoftChip(
                        label: '${bossSkillIcon(k)} ${bossSkillLabel(k)}',
                        color: AppColors.grape,
                        solid: true,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (spec.enrageAtHalf) ...[
                      SoftChip(
                        label: '💢 ${l.enraged}',
                        color: AppColors.blossom,
                        solid: true,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (spec.shieldCycle > 0) ...[
                      SoftChip(
                        label: '🛡️ ${l.shield}',
                        color: AppColors.lemon,
                        solid: true,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                SoftChip(
                  label: defeated
                      ? l.bossBeatenBadge
                      : l.bossUnbeaten(c + 1),
                  icon: defeated ? Icons.check_circle : Icons.search,
                  color: defeated ? AppColors.mint : AppColors.ink3,
                  solid: defeated,
                ),
                const SizedBox(height: 16),
                CandyButton(
                  label: L10n.value.done,
                  size: CandyButtonSize.medium,
                  colors: AppTheme.gradientOf(AppColors.grape),
                  onTap: () {
                    AudioFeedback.uiTap();
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFamilySection(BuildContext context, VehicleCategory family) {
    final l = L10n.value;
    final tiers = VehicleType.values.where((t) => t.category == family).toList();
    final done = tiers.where((t) => data.collection.contains(t.id)).length;
    final color = familyColor(family);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: l.collectionFamilyHeader(familyIcon(family), family.displayLabel),
          subtitle: l.collectionFamilyMeta(
              familySub(family), done, tiers.length),
          accent: color,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemCount: tiers.length,
          itemBuilder: (context, i) => _CollectionCard(
            vehicle: tiers[i],
            unlocked: data.collection.contains(tiers[i].id),
            onTap: () => _showDetail(context, tiers[i]),
          ),
        ),
      ],
    );
  }

  /// 车型详情糖果抽屉（大图 + 名称 + 车系 + 解锁状态）。
  void _showDetail(BuildContext context, VehicleType vehicle) {
    final l = L10n.value;
    final unlocked = data.collection.contains(vehicle.id);
    final family = vehicle.category;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceLight,
              Color.lerp(vehicle.color, Colors.white, 0.90)!,
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: vehicle.color.withValues(alpha: 0.34)),
          boxShadow: [
            BoxShadow(
              color: vehicle.color.withValues(alpha: 0.30),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 抽屉把手
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.ink3.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color.lerp(vehicle.color, Colors.white, 0.78)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: vehicle.color.withValues(alpha: 0.40), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: vehicle.color.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: VehicleImage(vehicle: vehicle, size: 140),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VehicleImage(vehicle: vehicle, size: 26),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(vehicle.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.ink1,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SoftChip(
                  label: l.collectionFamilyChip(
                      family.displayLabel, familySub(family)),
                  color: familyColor(family),
                ),
                const SizedBox(height: 12),
                SoftChip(
                  label: unlocked
                      ? l.collectionIndex(
                          vehicle.id + 1, VehicleType.values.length)
                      : l.collectionLocked,
                  icon: unlocked ? Icons.check_circle : Icons.search,
                  color: unlocked ? AppColors.mint : AppColors.ink3,
                  solid: unlocked,
                ),
                const SizedBox(height: 16),
                CandyButton(
                  label: L10n.value.done,
                  size: CandyButtonSize.medium,
                  colors: AppTheme.gradientOf(vehicle.color),
                  onTap: () {
                    AudioFeedback.uiTap();
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 车系身份色（全项目统一入口，替代原先散布在各处的 family 颜色表）。
Color familyColor(VehicleCategory family) => switch (family) {
      VehicleCategory.land => AppColors.forest,
      VehicleCategory.heavy => AppColors.cocoa,
      VehicleCategory.rail => const Color(0xFF6C79F2),
      VehicleCategory.maritime => AppColors.sky,
      VehicleCategory.air => const Color(0xFF5B8DEF),
      VehicleCategory.space => AppColors.grape,
    };

String familyIcon(VehicleCategory family) => switch (family) {
      VehicleCategory.land => '🚗',
      VehicleCategory.heavy => '🚛',
      VehicleCategory.rail => '🚄',
      VehicleCategory.maritime => '🚢',
      VehicleCategory.air => '✈️',
      VehicleCategory.space => '🚀',
    };

/// 车系一句话（图鉴小节副标题 / 详情抽屉标签）。
String familySub(VehicleCategory family) {
  final l = L10n.value;
  return switch (family) {
    VehicleCategory.land => l.catDescLand,
    VehicleCategory.heavy => l.catDescHeavy,
    VehicleCategory.rail => l.catDescRail,
    VehicleCategory.maritime => l.catDescMaritime,
    VehicleCategory.air => l.catDescAir,
    VehicleCategory.space => l.catDescSpace,
  };
}

/// 单辆车的图鉴卡：点亮显示真实 3D 车模，未点亮显示去色剪影。
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.vehicle,
    required this.unlocked,
    required this.onTap,
  });

  final VehicleType vehicle;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = VehicleImage(vehicle: vehicle, size: 52);
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: unlocked
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Color.lerp(vehicle.color, Colors.white, 0.80)!,
                  ],
                )
              : null,
          color: unlocked ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unlocked
                ? vehicle.color.withValues(alpha: 0.45)
                : AppColors.ink3.withValues(alpha: 0.20),
            width: unlocked ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: unlocked
                  ? vehicle.color.withValues(alpha: 0.22)
                  : AppColors.shadow.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 46,
              child: unlocked
                  ? image
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Opacity(opacity: 0.45, child: image),
                    ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                unlocked ? vehicle.name : '???',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked
                      ? AppTheme.deepen(vehicle.color, 0.42)
                      : AppColors.ink3,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              unlocked ? vehicle.icon : L10n.value.collectionLockedShort,
              style: TextStyle(
                color: unlocked ? AppColors.ink2 : AppColors.ink3,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boss 攻击技能 → 展示 emoji / 中文名（徽章墙与详情抽屉共用）。
String bossSkillIcon(BossAttackKind k) => switch (k) {
      BossAttackKind.freeze => '🧊',
      BossAttackKind.steal => '😈',
      BossAttackKind.rubble => '🪨',
      BossAttackKind.impound => '🏍️',
      BossAttackKind.devolve => '📉',
      BossAttackKind.taint => '☠️',
      BossAttackKind.lock => '🔒',
      BossAttackKind.glue => '🍯',
      BossAttackKind.hole => '🕳️',
      BossAttackKind.ban => '🚫',
      BossAttackKind.fog => '🌫️',
      BossAttackKind.shuffle => '🔀',
      BossAttackKind.stealGoal => '🎯',
      BossAttackKind.shield => '🛡️',
      BossAttackKind.ice => '❄️',
    };

/// Boss 技能名（徽章墙与详情抽屉共用）。
///
/// 与 [bossSkillIcon] 成对：图标是语言无关的 emoji，名字走 arb。
String bossSkillLabel(BossAttackKind k) {
  final l = L10n.value;
  return switch (k) {
    BossAttackKind.freeze => l.attackFreeze,
    BossAttackKind.steal => l.attackSteal,
    BossAttackKind.rubble => l.attackRubble,
    BossAttackKind.impound => l.attackImpound,
    BossAttackKind.devolve => l.attackDevolve,
    BossAttackKind.taint => l.attackTaint,
    BossAttackKind.lock => l.attackLock,
    BossAttackKind.glue => l.attackGlue,
    BossAttackKind.hole => l.attackHole,
    BossAttackKind.ban => l.attackBan,
    BossAttackKind.fog => l.attackFog,
    BossAttackKind.shuffle => l.attackShuffle,
    BossAttackKind.stealGoal => l.attackStealGoal,
    BossAttackKind.shield => l.attackShield,
    BossAttackKind.ice => l.attackIce,
  };
}

/// 徽章墙单格：已击败 = 主技能 + 绰号/章号；未击败 = 剪影问号。
class _BossBadge extends StatelessWidget {
  const _BossBadge({
    required this.spec,
    required this.chapterIdx,
    required this.bossIndex,
    required this.defeated,
    required this.onTap,
  });

  final BossSpec spec;
  final int chapterIdx;
  final int bossIndex;
  final bool defeated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = spec.epithetLabel ?? L10n.value.chapterOnly(chapterIdx + 1);
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: defeated
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Color.lerp(AppColors.grape, Colors.white, 0.78)!,
                  ],
                )
              : null,
          color: defeated ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: defeated
                ? AppColors.grape.withValues(alpha: 0.5)
                : AppColors.ink3.withValues(alpha: 0.20),
            width: defeated ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: defeated
                  ? AppColors.grape.withValues(alpha: 0.22)
                  : AppColors.shadow.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
              // 尖峰招牌多一顶王冠角标，墙上扫一眼就能认出"这只揍过我"。
              child: defeated
                  ? (bossIndex == 3
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(bossSkillIcon(spec.primary),
                                style: const TextStyle(fontSize: 22)),
                            const Positioned(
                              right: 0,
                              top: 0,
                              child: Text('👑',
                                  style: TextStyle(fontSize: 10)),
                            ),
                          ],
                        )
                      : Text(bossSkillIcon(spec.primary),
                          style: const TextStyle(fontSize: 22)))
                  : const Text('❔',
                      style: TextStyle(fontSize: 18, color: AppColors.ink3)),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                defeated ? caption : '???',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: defeated
                      ? AppTheme.deepen(AppColors.grape, 0.42)
                      : AppColors.ink3,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../game/audio_feedback.dart';
import '../models/achievement.dart';
import '../save/save_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_ui.dart';
import '../widgets/pressable.dart';

/// 成就页：按 7 个分组分节展示，支持状态筛选。
///
/// 视觉设计：整体走紫罗兰（taro）模块色；顶部一张「收集」贺卡给出整体进度，
/// 每条成就用所属分组的身份色圆润卡，达成后点亮彩色 + 弹出领取按钮。
/// 语气上刻意弱化「未完成」的灰色压迫：未达成的卡片只用淡灰描边，不用骷髅/锁头强调。
///
/// # 为什么必须分组
///
/// 成就从 27 条扩到 70+ 条之后，平铺列表要滑 10 屏以上，玩家无法定位
/// 「我还差哪一类」。分组 + 状态筛选是这类长列表的最低配置。
class AchievementsScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const AchievementsScreen({super.key, required this.data, required this.repo});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

/// 分组身份色（与首页 4 个小方块、图鉴车系色区隔开，自成一套成就色）。
Color _groupColor(AchievementGroup g) => switch (g) {
      AchievementGroup.progress => AppColors.coral,
      AchievementGroup.chapter => AppColors.sky,
      AchievementGroup.boss => AppColors.coralDeep,
      AchievementGroup.parking => AppColors.mint,
      AchievementGroup.collection => AppColors.grape,
      AchievementGroup.skill => AppColors.sun,
      AchievementGroup.life => AppColors.lemon,
    };

IconData _groupIcon(AchievementGroup g) => switch (g) {
      AchievementGroup.progress => Icons.flag_rounded,
      AchievementGroup.chapter => Icons.map_rounded,
      AchievementGroup.boss => Icons.workspace_premium_rounded,
      AchievementGroup.parking => Icons.local_parking_rounded,
      AchievementGroup.collection => Icons.auto_stories_rounded,
      AchievementGroup.skill => Icons.bolt_rounded,
      AchievementGroup.life => Icons.event_available_rounded,
    };

/// 状态筛选：全部 / 进行中（未达成）/ 可领取（达成未领）/ 已完成（已领取）。
enum _Filter { all, active, claimable, done }

class _AchievementsScreenState extends State<AchievementsScreen> {
  PlayerData get data => widget.data;

  _Filter _filter = _Filter.all;

  void _claim(Achievement a) {
    if (data.claimedAchievements.contains(a.id)) return;
    AudioFeedback.uiTap();
    setState(() {
      data.claimedAchievements.add(a.id);
      data.addCoins(a.reward);
    });
    widget.repo.save(data);
    CandyDialog.show(
      context,
      emoji: '🎉',
      color: AppColors.sun,
      title: '成就达成！+${a.reward} 🪙',
      message: '「${a.title}」已入袋，继续收集更多奖章吧。',
    );
  }

  @override
  Widget build(BuildContext context) {
    // 一次算完达成状态，后面分组/筛选/计数都复用，避免 achieved() 被反复调用
    // （章节成就每次调用要查 45 个 id，70 条 × 多轮 build 会白白多算几千次）。
    final achievedMap = <String, bool>{
      for (final a in achievements) a.id: a.achieved(data),
    };
    final claimedCount = achievements
        .where((a) => data.claimedAchievements.contains(a.id))
        .length;
    final achievedCount = achievements.where((a) => achievedMap[a.id]!).length;
    final claimableCount = achievements
        .where((a) =>
            achievedMap[a.id]! && !data.claimedAchievements.contains(a.id))
        .length;
    final total = achievements.length;
    final progress = total == 0 ? 0.0 : claimedCount / total;

    bool visible(Achievement a) {
      final achieved = achievedMap[a.id]!;
      final claimed = data.claimedAchievements.contains(a.id);
      return switch (_filter) {
        _Filter.all => true,
        _Filter.active => !achieved,
        _Filter.claimable => achieved && !claimed,
        _Filter.done => claimed,
      };
    }

    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              CandyAppBar(
                title: '成就',
                subtitle: '收集路上的小奖章',
                accent: AppColors.grape,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  CoinPill(amount: data.coins, compact: true),
                  const SizedBox(width: 10),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _SummaryCard(
                      claimed: claimedCount,
                      achieved: achievedCount,
                      total: total,
                      progress: progress,
                    ),
                    const SizedBox(height: 12),
                    _buildFilterRow(
                      achievedCount: achievedCount,
                      claimableCount: claimableCount,
                      claimedCount: claimedCount,
                      total: total,
                    ),
                    const SizedBox(height: 6),
                    for (final group in AchievementGroup.values)
                      ..._buildGroupSection(
                        group,
                        achievedMap: achievedMap,
                        visible: visible,
                      ),
                    // 筛选后一条都不剩（例如「可领取」但都还没打）→ 空态提示，
                    // 否则玩家会以为页面加载失败。
                    if (achievements.every((a) => !visible(a)))
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text('这个分类还空着，先去打几关吧',
                              style: TextStyle(color: AppColors.ink3)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分组节：标题（含该组进度）+ 该组可见条目。
  List<Widget> _buildGroupSection(
    AchievementGroup group, {
    required Map<String, bool> achievedMap,
    required bool Function(Achievement) visible,
  }) {
    final all = achievements.where((a) => a.group == group).toList();
    final shown = all.where(visible).toList();
    if (shown.isEmpty) return const [];
    final done =
        all.where((a) => data.claimedAchievements.contains(a.id)).length;
    final color = _groupColor(group);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: SectionTitle(
          title: '${group.label} · ${all.length} 枚',
          subtitle: '已领取 $done/${all.length}',
          accent: color,
          trailing: Icon(_groupIcon(group), size: 18, color: color),
        ),
      ),
      for (final a in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AchievementTile(
            achievement: a,
            accent: color,
            achieved: achievedMap[a.id]!,
            claimed: data.claimedAchievements.contains(a.id),
            onClaim: () => _claim(a),
          ),
        ),
    ];
  }

  /// 筛选 chip 行：横向可滚动，避免 4 个 chip 在 320px 小屏挤压。
  Widget _buildFilterRow({
    required int achievedCount,
    required int claimableCount,
    required int claimedCount,
    required int total,
  }) {
    final items = <(_Filter, String, int)>[
      (_Filter.all, '全部', total),
      (_Filter.active, '进行中', total - achievedCount),
      (_Filter.claimable, '可领取', claimableCount),
      (_Filter.done, '已完成', claimedCount),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (f, label, count) = items[i];
          final selected = _filter == f;
          final color = f == _Filter.claimable ? AppColors.sun : AppColors.grape;
          return Pressable(
            onTap: () {
              if (_filter == f) return;
              AudioFeedback.uiTap();
              setState(() => _filter = f);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.deepen(color),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.86)
                          : AppTheme.deepen(color).withValues(alpha: 0.7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 顶部汇总卡：整体进度 + 一句鼓励。进度条用糖果条。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.claimed,
    required this.achieved,
    required this.total,
    required this.progress,
  });

  final int claimed;
  final int achieved;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CandyCard(
      accent: AppColors.grape,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: AppTheme.gradientFor(AppColors.grape),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.grape.withValues(alpha: 0.34),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$claimed',
                      style: const TextStyle(
                        color: AppColors.ink1,
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      ' / $total 枚',
                      style: const TextStyle(
                        color: AppColors.ink3,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '已达成 $achieved',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink3,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                CandyProgress(
                    value: progress, color: AppColors.grape, height: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.accent,
    required this.achieved,
    required this.claimed,
    required this.onClaim,
  });

  final Achievement achievement;
  final Color accent;
  final bool achieved;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    // 未达成：整卡弱化成"还没点亮"的淡灰，不用锁头制造压迫。
    final effective = achieved ? accent : AppColors.ink3;
    return CandyCard(
      accent: effective,
      radius: 20,
      muted: !achieved,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: achieved ? AppTheme.gradientFor(accent) : null,
              color: achieved ? null : AppColors.ink3.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              a.icon,
              size: 24,
              color: achieved ? Colors.white : AppColors.ink3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: achieved ? AppColors.ink1 : AppColors.ink2,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(a.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: achieved ? AppColors.ink2 : AppColors.ink3,
                        fontSize: 12)),
                if (achieved && !claimed) ...[
                  const SizedBox(height: 6),
                  SoftChip(
                    label: '可领取 +${a.reward} 🪙',
                    icon: Icons.redeem,
                    color: AppColors.sun,
                    solid: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (claimed)
            SoftChip(label: '已领取', icon: Icons.check, color: AppColors.mint)
          else if (achieved)
            CandyButton(
              label: '领取',
              size: CandyButtonSize.small,
              dense: true,
              colors: AppTheme.gradientOf(accent),
              onTap: onClaim,
            )
          else
            const Icon(Icons.hourglass_empty_rounded,
                color: AppColors.ink3, size: 20),
        ],
      ),
    );
  }
}

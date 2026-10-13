import 'package:flutter/material.dart';

import '../game/audio_feedback.dart';
import '../models/achievement.dart';
import '../save/save_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_ui.dart';

/// 成就页：展示全部奖章与领取状态。
///
/// 视觉设计：整体走紫罗兰（taro）模块色；顶部一张「收集」贺卡给出整体进度，
/// 每条成就用同一黑葡萄身份色的圆润卡，达成后点亮彩色 + 弹出领取按钮。
/// 语气上刻意弱化「未完成」的灰色压迫：未达成的卡片只用淡灰描边，不用骷髅/锁头强调。
class AchievementsScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const AchievementsScreen({super.key, required this.data, required this.repo});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

/// 每条成就一个循环身份色，让长列表不至于是一片同色导致视觉疲劳。
const List<Color> _tileColors = [
  AppColors.grape,
  AppColors.sky,
  AppColors.mint,
  AppColors.sun,
  AppColors.blossom,
  AppColors.aqua,
  AppColors.coral,
];

class _AchievementsScreenState extends State<AchievementsScreen> {
  PlayerData get data => widget.data;

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
    final claimed = achievements
        .where((a) => data.claimedAchievements.contains(a.id))
        .length;
    final total = achievements.length;
    final progress = total == 0 ? 0.0 : claimed / total;

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
                      claimed: claimed,
                      total: total,
                      progress: progress,
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                      child: SectionTitle(
                        title: '全部奖章',
                        subtitle: progress >= 1
                            ? '全部收集完成，你太棒了！'
                            : '还有 ${total - claimed} 枚等着点亮',
                        accent: AppColors.grape,
                      ),
                    ),
                    for (var i = 0; i < achievements.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AchievementTile(
                          achievement: achievements[i],
                          accent: _tileColors[i % _tileColors.length],
                          achieved: achievements[i].achieved(data),
                          claimed:
                              data.claimedAchievements.contains(achievements[i].id),
                          onClaim: () => _claim(achievements[i]),
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
}

/// 顶部汇总卡：整体进度 + 一句鼓励。进度条用糖果条。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.claimed,
    required this.total,
    required this.progress,
  });

  final int claimed;
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

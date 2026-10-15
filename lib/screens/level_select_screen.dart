import 'package:flutter/material.dart';

import '../game/audio_feedback.dart';
import '../theme/app_theme.dart';
import '../models/level.dart';
import '../save/save_repository.dart';
import '../services/level_data_generator.dart';
import '../services/level_progression.dart';
import '../services/level_rhythm.dart';
import '../widgets/candy_ui.dart';
import '../widgets/pressable.dart';
import '../widgets/vehicle_image.dart';
import 'game_screen.dart';

/// 完整关卡选择页：从首页「全部关卡」进入。
///
/// 视觉设计：每章一个身份色（按章节顺序循环彩虹），章节头用糖果色条 +
/// 进度；关卡卡做成「浮雕糖果砖」——车型渐变打底、顶部三分高光、右下角一枚
/// 半透明大车型图标做水印，视觉重量靠近 Kitchen/《Royal Match》的关卡地图。
class LevelSelectScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const LevelSelectScreen({super.key, required this.data, required this.repo});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

/// 章节身份色：按章循环，让长列表一路往下看得见颜色变化。
const List<Color> _chapterColors = [
  AppColors.mint,
  AppColors.sky,
  AppColors.grape,
  AppColors.blossom,
  AppColors.sun,
  AppColors.aqua,
  AppColors.coral,
];

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  PlayerData get data => widget.data;

  Future<void> _openLevel(LevelDefinition level) async {
    AudioFeedback.uiTap();
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: level, data: data, repo: widget.repo),
      ),
    );
    if (result == true && mounted) {
      // 通关后刷新星星/进度。
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LevelSelectScreen(data: data, repo: widget.repo),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    final total = levels.length;
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              CandyAppBar(
                title: '关卡地图',
                subtitle: '已完成 $completed/$total 关 · 慢慢来，一关一关开',
                accent: AppColors.sky,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  CoinPill(amount: data.coins, compact: true),
                  const SizedBox(width: 10),
                ],
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                        child: TotalProgressCard(
                          completed: completed,
                          total: total,
                          stars: data.bestStars.values.fold(0, (a, b) => a + b),
                        ),
                      ),
                    ),
                    for (var i = 0; i < levelChapters.length; i++)
                      ..._chapterSlivers(
                          levelChapters[i], _chapterColors[i % _chapterColors.length]),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单章渲染：章节色条头 + 该章关卡网格。
  List<Widget> _chapterSlivers(LevelChapter chapter, Color chapterColor) {
    final idx = levelChapters.indexOf(chapter);
    final endId = idx + 1 < levelChapters.length
        ? levelChapters[idx + 1].startId
        : 1 << 30;
    final cl =
        levels.where((l) => l.id >= chapter.startId && l.id < endId).toList();
    if (cl.isEmpty) return const [];
    final cleared = cl.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    final unlockedCount = cl.where((l) => l.id <= data.unlockedLevel).length;
    final locked = unlockedCount == 0;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SectionTitle(
            title: chapter.title,
            // 魔王章：大阶段（3 章）末章的整章 +1 档。徽标说破身份，
            // 玩家才会把「这一章特别难」理解为阶段收官而不是数值出错。
            subtitle: LevelProgression.isMergeDemon(chapter.startId)
                ? '👹 魔王章 · ${chapter.subtitle}'
                : chapter.subtitle,
            accent: chapterColor,
            trailing: SoftChip(
              label: '$cleared/${cl.length}',
              icon: locked ? Icons.lock_outline : Icons.flag_rounded,
              color: chapterColor,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final level = cl[index];
              final unlocked = level.id <= data.unlockedLevel;
              return LevelCard(
                level: level,
                unlocked: unlocked,
                best: data.bestScores[level.id] ?? 0,
                bestStars: data.bestStars[level.id] ?? 0,
                accent: chapterColor,
                onTap: unlocked ? () => _openLevel(level) : null,
              );
            },
            childCount: cl.length,
          ),
        ),
      ),
    ];
  }
}

/// 顶部总进度：一屏之内先给「我到哪了」的安心感。
class TotalProgressCard extends StatelessWidget {
  const TotalProgressCard({
    super.key,
    required this.completed,
    required this.total,
    required this.stars,
  });

  final int completed;
  final int total;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return CandyCard(
      accent: AppColors.sky,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 5),
                    Text('$stars',
                        style: const TextStyle(
                            color: AppColors.ink1,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 4),
                    Text('累计星星',
                        style: TextStyle(
                            color: AppColors.ink3,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                CandyProgress(value: progress, color: AppColors.sky, height: 9),
                const SizedBox(height: 6),
                Text(
                  progress >= 1
                      ? '全部关卡都已点亮，了不起！'
                      : '再过 ${total - completed} 关就全部点亮啦',
                  style: const TextStyle(color: AppColors.ink2, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppTheme.gradientFor(AppColors.sun),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sun.withValues(alpha: 0.36),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

/// 广告挑战关小标：🎬 + 「挑战」，标出每 5 关一个的 +1 档难关。
///
/// 设计意图说给玩家：这一关比同位置难一档，但**不是墙** ——
/// 失败了可以看广告续命/加步数（降难支援），硬实力也能直接过。
class _AdGateChip extends StatelessWidget {
  const _AdGateChip({this.dim = false});

  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.coralDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: dim
            ? AppColors.ink3.withValues(alpha: 0.12)
            : c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🎬',
            style: TextStyle(fontSize: 9, color: dim ? AppColors.ink3 : null),
          ),
          const SizedBox(width: 3),
          Text(
            '挑战',
            style: TextStyle(
              color: dim ? AppColors.ink3 : AppTheme.deepen(c, 0.30),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 难度心跳小标：色点 + 档位名，让玩家一眼看出这一关在本轮 5 关里的位置。
class _RhythmChip extends StatelessWidget {
  const _RhythmChip({required this.phase, this.dim = false});

  final int phase;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = LevelRhythm.colorOf(RhythmMode.merge, phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: dim ? AppColors.ink3.withValues(alpha: 0.12) : c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: dim ? AppColors.ink3 : c,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            LevelRhythm.nameOf(RhythmMode.merge, phase),
            style: TextStyle(
              color: dim ? AppColors.ink3 : AppTheme.deepen(c, 0.30),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class LevelCard extends StatelessWidget {
  const LevelCard({
    super.key,
    required this.level,
    required this.unlocked,
    required this.best,
    required this.bestStars,
    required this.accent,
    this.onTap,
  });

  final LevelDefinition level;
  final bool unlocked;
  final int best;
  final int bestStars;
  final VoidCallback? onTap;

  /// 所属章节身份色（未解锁时作为灰化的基准）。
  final Color accent;

  /// 卡片强调色：优先目标车型色（颜色=车型身份），无目标车时回落章节色。
  Color get _accent => level.targetTier?.color ?? accent;

  @override
  Widget build(BuildContext context) {
    final c = unlocked ? _accent : AppColors.ink3;
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
                    Color.lerp(c, Colors.white, 0.86)!,
                  ],
                )
              : null,
          color: unlocked ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: c.withValues(alpha: unlocked ? 0.42 : 0.20),
            width: unlocked ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: unlocked
                  ? c.withValues(alpha: 0.22)
                  : AppColors.shadow.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // 右下角巨型水印车标：给卡片"内容感"，同时不抢主信息。
              if (unlocked && level.targetTier != null)
                Positioned(
                  right: -14,
                  bottom: -16,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.16,
                      child: VehicleImage(vehicle: level.targetTier!, size: 96),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: unlocked
                                ? AppTheme.gradientFor(c)
                                : null,
                            color: unlocked
                                ? null
                                : AppColors.ink3.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '第 ${level.id} 关',
                            style: TextStyle(
                                color: unlocked ? Colors.white : AppColors.ink3,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5),
                          ),
                        ),
                        // 难度心跳标记：只标生成段（L71+）。手写关的参数是逐关
                        // 手工调的，套用相位会与实际体感不符，不如不标。
                        if (level.id >= LevelDataGenerator.firstId) ...[
                          const SizedBox(width: 5),
                          _RhythmChip(
                            phase: LevelDataGenerator.rhythmPhase(level.id),
                            dim: !unlocked,
                          ),
                          // 广告挑战关：与心跳标记并列（都是「这一关什么强度」的
                          // 预告信息），🎬 徽标让玩家提前知道难关在哪。
                          if (LevelProgression.isMergeAdGate(level.id)) ...[
                            const SizedBox(width: 4),
                            _AdGateChip(dim: !unlocked),
                          ],
                        ],
                        const Spacer(),
                        if (!unlocked)
                          const Icon(Icons.lock_rounded,
                              color: AppColors.ink3, size: 16)
                        else
                          StarRow(stars: bestStars, size: 13),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: unlocked
                              ? c.withValues(alpha: 0.18)
                              : AppColors.ink3.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: level.targetTier != null
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Opacity(
                                    opacity: unlocked ? 1.0 : 0.35,
                                    child: VehicleImage(
                                        vehicle: level.targetTier!, size: 42),
                                  ),
                                )
                              : Icon(Icons.grid_view_rounded,
                                  size: 26,
                                  color: unlocked
                                      ? AppColors.ink2
                                      : AppColors.ink3),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: unlocked ? AppColors.ink1 : AppColors.ink3,
                          fontSize: 15,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      best > 0
                          ? '最佳 $best 分'
                          : (unlocked ? '还没挑战过' : '通过前面关卡解锁'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: best > 0
                              ? AppColors.sun
                              : (unlocked ? AppColors.ink2 : AppColors.ink3),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700),
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

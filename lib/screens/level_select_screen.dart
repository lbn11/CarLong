import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/level.dart';
import '../save/save_repository.dart';
import '../widgets/vehicle_image.dart';
import 'game_screen.dart';

/// 完整关卡选择页：从首页「全部关卡」进入。
class LevelSelectScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const LevelSelectScreen({super.key, required this.data, required this.repo});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  PlayerData get data => widget.data;

  Future<void> _openLevel(LevelDefinition level) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: level, data: data, repo: widget.repo),
      ),
    );
    if (result == true && mounted) {
      // 通关后刷新星星/进度。
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              LevelSelectScreen(data: data, repo: widget.repo),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        foregroundColor: AppColors.ink1,
        title: const Text('选择关卡',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('已完成 $completed/${levels.length}',
                  style: const TextStyle(
                      color: AppColors.ink3, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: GlowBackground(
        child: CustomScrollView(
          slivers: [
            for (final chapter in levelChapters) ..._chapterSlivers(chapter),
          ],
        ),
      ),
    );
  }

  /// 单章渲染：章节标题条 + 该章关卡网格。
  List<Widget> _chapterSlivers(LevelChapter chapter) {
    final idx = levelChapters.indexOf(chapter);
    final endId =
        idx + 1 < levelChapters.length ? levelChapters[idx + 1].startId : 1 << 30;
    final cl = levels.where((l) => l.id >= chapter.startId && l.id < endId).toList();
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter.title,
                      style: const TextStyle(
                          color: AppColors.ink1,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(chapter.subtitle,
                      style: const TextStyle(
                          color: AppColors.ink3, fontSize: 12)),
                ],
              ),
            ],
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
            childAspectRatio: 1.15,
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

class LevelCard extends StatelessWidget {
  final LevelDefinition level;
  final bool unlocked;
  final int best;
  final int bestStars;
  final VoidCallback? onTap;

  const LevelCard({
    super.key,
    required this.level,
    required this.unlocked,
    required this.best,
    required this.bestStars,
    this.onTap,
  });

  Color get _accent => level.targetTier?.color ?? const Color(0xFFF2784E);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: unlocked
            ? AppTheme.tierCard(_accent)
            : BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.ink3.withValues(alpha: 0.4),
                ),
              ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '第 ${level.id} 关',
                            style: TextStyle(
                                color: AppTheme.tierInk(_accent),
                                fontWeight: FontWeight.w700,
                                fontSize: 10),
                          ),
                        ),
                        const Spacer(),
                        if (!unlocked)
                          const Icon(Icons.lock, color: AppColors.ink3, size: 16)
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              3,
                              (i) => Text(
                                i < bestStars ? '⭐' : '☆',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: unlocked
                              ? _accent.withValues(alpha: 0.16)
                              : AppColors.ink3.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: level.targetTier != null
                              ? Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Opacity(
                                    opacity: unlocked ? 1.0 : 0.4,
                                    child: VehicleImage(vehicle: level.targetTier!, size: 40),
                                  ),
                                )
                              : Icon(Icons.grid_view,
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
                      style: const TextStyle(
                          color: AppColors.ink1,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      best > 0 ? '最佳 $best 分' : '未通关',
                      style: TextStyle(
                          color: best > 0
                              ? AppColors.sun
                              : AppColors.ink3,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../game/parking_daily_challenge.dart';
import '../models/parking_level.dart';
import '../save/save_repository.dart';
import '../services/parking_chapters.dart';
import '../services/parking_generator.dart';
import '../theme/app_theme.dart';
import 'parking_screen.dart';

/// 停车关卡选择屏（按车型章节分组，章节解锁与合成图鉴双向联动）。
class ParkingLevelSelectScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const ParkingLevelSelectScreen({
    super.key,
    required this.data,
    required this.repo,
  });

  @override
  State<ParkingLevelSelectScreen> createState() =>
      _ParkingLevelSelectScreenState();
}

class _ParkingLevelSelectScreenState extends State<ParkingLevelSelectScreen> {
  /// 已生成的全部停车关卡（id 1..N）。
  late final List<ParkingLevel> _levels;

  /// 章节 → 该章节内的关卡列表。
  late final Map<ParkingChapter, List<ParkingLevel>> _byChapter;

  @override
  void initState() {
    super.initState();
    _levels = ParkingLevelGenerator.generate(count: 100);
    _byChapter = {};
    for (final c in ParkingChapters.all) {
      _byChapter[c] = _levels
          .where((l) => ParkingChapters.chapterForId(l.id) == c)
          .toList();
    }
  }

  /// 章节是否可进入（双向联动）。
  bool _chapterAccessible(ParkingChapter c) =>
      ParkingChapters.isAccessible(c, widget.data.collection, widget.data.parkingBestStars);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink1),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('停车模式', style: TextStyle(color: AppColors.ink1)),
      ),
      body: GlowBackground(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '把目标车辆停到停车位上 · 章节随合成图鉴解锁',
                style: TextStyle(color: AppColors.ink2, fontSize: 14),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: ParkingChapters.all.length + 1, // +1 for daily challenge
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  if (i == 0) return _buildDailyChallengeCard();
                  return _chapterCard(ParkingChapters.all[i - 1]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chapterCard(ParkingChapter chapter) {
    final levels = _byChapter[chapter]!;
    final accessible = _chapterAccessible(chapter);
    final cleared =
        levels.where((l) => (widget.data.parkingBestStars[l.id] ?? 0) > 0).length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceLight,
        border: Border.all(
          color: accessible ? chapter.tier.color.withValues(alpha: 0.5) : AppColors.ink3.withValues(alpha: 0.3),
          width: accessible ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 章节头：车型图标 + 名称 + 进度 / 锁定提示
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: chapter.tier.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: accessible
                        ? Text(chapter.tier.icon, style: const TextStyle(fontSize: 22))
                        : const Icon(Icons.lock_outline,
                            color: AppColors.ink3, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: const TextStyle(
                          color: AppColors.ink1,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        accessible
                            ? '${chapter.subtitle} · 已通关 $cleared/${levels.length}'
                            : ParkingChapters.lockReason(chapter),
                        style: TextStyle(
                          color: accessible ? AppColors.ink2 : AppColors.ink3,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (accessible)
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.95,
                ),
                itemCount: levels.length,
                itemBuilder: (context, i) => _levelTile(levels[i]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.ink3.withValues(alpha: 0.08),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.ink3, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      ParkingChapters.lockReason(chapter),
                      style: const TextStyle(color: AppColors.ink3, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _levelTile(ParkingLevel level) {
    final stars = widget.data.parkingBestStars[level.id] ?? 0;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ParkingScreen(
            level: level,
            data: widget.data,
            repo: widget.repo,
          ),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          border: Border.all(
            color: AppColors.sky,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${level.id}',
              style: const TextStyle(
                color: AppColors.ink1,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 11,
                color: i < stars ? AppColors.sun : AppColors.ink3,
              )),
            ),
            Text(
              level.targetTier.icon,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChallengeCard() {
    final cleared = widget.data.dailyClearedDate == ParkingDailyChallenge.todayKey;
    final streak = widget.data.dailyStreak;
    final level = ParkingDailyChallenge.today();
    final accent = level.targetTier.color;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(Colors.white, accent, 0.16)!,
              Color.lerp(Colors.white, accent, 0.08)!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: cleared ? null : _openParkingDaily,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_today,
                      color: Color(0xFFB39DDB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('每日停车挑战',
                          style: TextStyle(
                              color: AppColors.ink1,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        cleared
                            ? '今日已完成${streak > 0 ? ' · 连续 $streak 天' : ''}'
                            : streak >= 2
                                ? '连续 $streak 天 · 完成领 +${ParkingDailyChallenge.reward + ParkingDailyChallenge.streakBonus(streak)} 🪙'
                                : '完成今日挑战，领 +${ParkingDailyChallenge.reward} 🪙',
                        style: TextStyle(
                            color: cleared ? const Color(0xFF66BB6A) : AppColors.ink2,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (cleared)
                  const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 26)
                else
                  FilledButton.icon(
                    onPressed: _openParkingDaily,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('挑战'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openParkingDaily() {
    final level = ParkingDailyChallenge.today();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParkingScreen(
          level: level,
          data: widget.data,
          repo: widget.repo,
          isDaily: true,
        ),
      ),
    );
  }
}

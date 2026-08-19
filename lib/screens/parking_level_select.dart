import 'package:flutter/material.dart';

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
                itemCount: ParkingChapters.all.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) =>
                    _chapterCard(ParkingChapters.all[i]),
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
}

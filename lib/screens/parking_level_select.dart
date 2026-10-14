import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/audio_feedback.dart';
import '../game/parking_daily_challenge.dart';
import '../models/parking_level.dart';
import '../save/save_repository.dart';
import '../services/level_rhythm.dart';
import '../services/parking_chapters.dart';
import '../services/parking_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_ui.dart';
import '../widgets/pressable.dart';
import 'parking_screen.dart';

/// 停车关卡选择屏（按车型章节分组，章节解锁与合成图鉴双向联动）。
///
/// 视觉设计：整页走薄荷身份色（停车=绿地 dio），章节卡头用车型身份色渐变条，
/// 关卡格做成统一圆角"糖块"，已通关的格带星 avatars。
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
  /// 全部停车关卡 id（1..800）。
  ///
  /// **性能关键**：这里只持有 id，不持有 [ParkingLevel]。
  /// 全量生成 800 关实测 68 秒（85ms/关，求解器主导），在 initState 里同步跑
  /// 会让选关页卡死一分钟。选关页实际只需要 id（查星级）与章节车型，
  /// 真正的关卡在进入某一关时才由 [ParkingLevelGenerator.generateOne] 生成。
  late final List<int> _levelIds;

  /// 章节 → 该章节内的关卡 id 列表。
  late final Map<ParkingChapter, List<int>> _byChapter;

  /// 正在生成的关卡 id（生成是同步 CPU 活，尖峰关最坏 ~0.7s，
  /// 不给反馈的话玩家会以为点愣住了）。null = 空闲。
  int? _loadingId;

  @override
  void initState() {
    super.initState();
    _levelIds = [
      for (var i = 1; i <= ParkingChapters.totalLevels; i++) i,
    ];
    _byChapter = {};
    for (final c in ParkingChapters.all) {
      _byChapter[c] = _levelIds
          .where((id) => ParkingChapters.chapterForId(id) == c)
          .toList();
    }
  }

  /// 章节是否可进入（双向联动）。
  bool _chapterAccessible(ParkingChapter c) =>
      ParkingChapters.isAccessible(c, widget.data.collection, widget.data.parkingBestStars);

  @override
  Widget build(BuildContext context) {
    final total = _levelIds.length;
    final cleared =
        _levelIds.where((id) => (widget.data.parkingBestStars[id] ?? 0) > 0).length;
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              CandyAppBar(
                title: '停车模式',
                subtitle: cleared == 0
                    ? '把车轻轻停进格子就好，别有负担'
                    : '已停稳 $cleared/$total 关 · 越停越顺手',
                accent: AppColors.mint,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  CoinPill(amount: widget.data.coins, compact: true),
                  const SizedBox(width: 10),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  children: [
                    _buildDailyChallengeCard(),
                    const SizedBox(height: 14),
                    for (final chapter in ParkingChapters.all) ...[
                      _chapterCard(chapter),
                      const SizedBox(height: 14),
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

  Widget _chapterCard(ParkingChapter chapter) {
    final levels = _byChapter[chapter]!;
    final accessible = _chapterAccessible(chapter);
    final cleared =
        levels.where((id) => (widget.data.parkingBestStars[id] ?? 0) > 0).length;
    final tier = chapter.tier.color;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceLight,
            Color.lerp(tier, Colors.white, accessible ? 0.94 : 0.97)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accessible
              ? tier.withValues(alpha: 0.34)
              : AppColors.ink3.withValues(alpha: 0.18),
          width: accessible ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accessible
                ? tier.withValues(alpha: 0.18)
                : AppColors.shadow.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: accessible ? AppTheme.gradientFor(tier) : null,
                    color: accessible
                        ? null
                        : AppColors.ink3.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: accessible
                        ? Text(chapter.tier.icon,
                            style: const TextStyle(fontSize: 22))
                        : const Icon(Icons.lock_person_rounded,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accessible ? AppColors.ink1 : AppColors.ink2,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        accessible
                            ? '${chapter.subtitle} · 已通关 $cleared/${levels.length}'
                            : ParkingChapters.lockReason(chapter),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accessible ? AppColors.ink2 : AppColors.ink3,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (accessible)
                  SoftChip(
                    label: '$cleared/${levels.length}',
                    color: tier,
                  ),
              ],
            ),
          ),
          if (accessible)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: 0.92,
                ),
                itemCount: levels.length,
                itemBuilder: (context, i) => _levelTile(levels[i], tier),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.ink3.withValues(alpha: 0.07),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_clock_rounded,
                        color: AppColors.ink3, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ParkingChapters.lockReason(chapter),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.ink3, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _levelTile(int levelId, Color chapterColor) {
    final stars = widget.data.parkingBestStars[levelId] ?? 0;
    final cleared = stars > 0;
    final accent = cleared ? AppColors.sun : chapterColor;
    return Pressable(
      onTap: () async {
        AudioFeedback.uiTap();
        if (_loadingId != null) return; // 正在生成，防连点
        setState(() => _loadingId = levelId);
        // 先让加载态渲染一帧，再跑同步生成：
        // 尖峰关（6 关一轮里最重的一拍）最坏 ~0.7s，不给反馈就是一次卡顿。
        await SchedulerBinding.instance.endOfFrame;
        if (!mounted) return;
        final level = ParkingLevelGenerator.generateOne(levelId);
        if (!mounted) return;
        setState(() => _loadingId = null);
        // 等对局返回后强制重绘：ParkingScreen 直接改的是共享的 data，
        // 不 setState 的话本页仍显示旧星级，看起来像"通关没被记录"。
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ParkingScreen(
            level: level,
            data: widget.data,
            repo: widget.repo,
          ),
        ));
        if (mounted) setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color.lerp(accent, Colors.white, 0.88)!,
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: accent.withValues(alpha: cleared ? 0.42 : 0.24),
            width: cleared ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: cleared ? 0.20 : 0.12),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$levelId',
                  style: TextStyle(
                    color: AppTheme.deepen(accent, 0.34),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                StarRow(stars: stars, size: 11),
                const SizedBox(height: 1),
                Text(
                  ParkingChapters.tierForId(levelId).icon,
                  style: TextStyle(fontSize: 13, color: AppColors.ink2),
                ),
              ],
            ),
            // 难度心跳角标：一个色点表明这一关在本轮 6 关中的位置，
            // 让玩家能预知「下一关是该发力还是该喘口气」。
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: LevelRhythm.colorOf(
                    RhythmMode.parking,
                    ParkingLevelGenerator.rhythmPhase(levelId),
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
              ),
            ),
            // 生成中的加载态：盖住卡片内容 + 中央转圈，避免同步生成
            // （尖峰关最坏 ~0.7s）期间玩家以为点愣住了。
            if (_loadingId == levelId)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.coralDeep),
                      ),
                    ),
                  ),
                ),
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
    final accent = cleared ? AppColors.mint : level.targetTier.color;

    return CandyCard(
      accent: accent,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.gradientFor(accent),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.34),
                  blurRadius: 13,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              cleared ? Icons.check_rounded : Icons.today_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('每日停车挑战',
                    style: TextStyle(
                        color: AppColors.ink1,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                const SizedBox(height: 3),
                Text(
                  cleared
                      ? '今天已经停好啦${streak > 0 ? ' · 连续 $streak 天' : ''}'
                      : streak >= 2
                          ? '连续 $streak 天 · 完成领 +${ParkingDailyChallenge.reward + ParkingDailyChallenge.streakBonus(streak)} 🪙'
                          : '今天的一局，完成领 +${ParkingDailyChallenge.reward} 🪙',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: cleared ? AppColors.mint : AppColors.ink2,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (cleared)
            SoftChip(label: '已完成', icon: Icons.check_circle, color: AppColors.mint, solid: true)
          else
            CandyButton(
              label: '停车去',
              icon: Icons.play_arrow_rounded,
              size: CandyButtonSize.small,
              dense: true,
              colors: AppTheme.gradientOf(accent),
              onTap: _openParkingDaily,
            ),
        ],
      ),
    );
  }

  void _openParkingDaily() async {
    AudioFeedback.uiTap();
    final level = ParkingDailyChallenge.today();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParkingScreen(
          level: level,
          data: widget.data,
          repo: widget.repo,
          isDaily: true,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

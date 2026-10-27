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
import '../l10n/l10n.dart';

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

  final ScrollController _scroll = ScrollController();

  /// 量尺寸/校正用的锚点：总进度卡、每章标题、视口本体。
  ///
  /// 章节块的高度不能写死——标题跟着系统字号/文本缩放会长，格子宽度跟着
  /// 视口宽变。所以首帧实测一次，再按 [SliverGrid] 的固定几何推导。
  final GlobalKey _progressKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();
  final List<GlobalKey> _headerKeys =
      List.generate(levelChapters.length, (_) => GlobalKey());

  /// 定位到「下一关」的卡片（滚动后用它把卡片精确推进视口）。
  final GlobalKey _currentCardKey = GlobalKey();

  /// 自动定位只跑一次（本页是 pushReplacement 重建的，每次进页都会跑）。
  bool _located = false;

  /// 定位完成前先隐藏列表：否则玩家会先看到列表顶部闪一下再跳下去。
  bool _listReady = false;

  /// 玩家接下来该打的那一关（= 已解锁的最后一关）。
  int get _currentLevelId => data.unlockedLevel.clamp(1, levels.length);

  @override
  void initState() {
    super.initState();
    // 首帧之后布局才有尺寸可量。直接在本帧算会拿到 null / 0。
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLocate());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 关卡地图自动定位到当前进度。
  ///
  /// 700 关地图分 14 章：打完一关回到地图如果每次都从头开始，玩家得往下
  /// 翻十几屏才能找回自己打到哪了。这里进页就把视口推到「下一关」，
  /// 并给它一圈高亮环（见 [LevelCard.current]）。
  Future<void> _autoLocate() async {
    if (_located || !mounted || !_scroll.hasClients) return;
    _located = true;

    final dest = _offsetForLevel(_currentLevelId);
    if (dest == null) {
      setState(() => _listReady = true);
      return;
    }
    final maxExtent = _scroll.position.maxScrollExtent;
    final target = dest.clamp(0.0, maxExtent);
    final far = (target - _scroll.offset).abs() >
        _scroll.position.viewportDimension * 2;

    if (far) {
      // 跨章跳几千像素：直接落位。做成补间会高速掠过十几章，看久了晕。
      _scroll.jumpTo(target);
      if (mounted) setState(() => _listReady = true);
    } else {
      // 近距离（同一两屏内）滑过去，让玩家看清「自己是在往下走」。
      if (mounted) setState(() => _listReady = true);
      await _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }

    // 几何推导再准也可能差几十像素（标题换行/文本缩放），落位后按真实
    // 布局校正：优先让章标题露在上沿，装不下才退回「卡片在上三分之一」。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final chIdx = _chapterIndexOf(_currentLevelId);
    if (chIdx != null) await _settleOnCurrentCard(chIdx);
  }

  /// 关卡所属章节下标；null = 不在任何章节（不该发生）。
  int? _chapterIndexOf(int levelId) {
    for (var i = 0; i < levelChapters.length; i++) {
      if (_levelsOfChapter(i).any((l) => l.id == levelId)) return i;
    }
    return null;
  }

  /// 收口：优先把「当前章标题」推到视口上沿（玩家一眼知道在哪一章），
  /// 卡片因此掉出视口下方时退回「卡片落在上三分之一」。
  ///
  /// 章标题在卡片上方 ~1-2 行处，可能落在 cacheExtent 之外还没被构建，
  /// 所以先按同章几何（行高是网格常量、标题高度首帧量过）反推落点，
  /// 落位后再用实测位置精修一次。
  Future<void> _settleOnCurrentCard(int chapterIdx) async {
    final cardCtx = _currentCardKey.currentContext;
    if (cardCtx == null) return; // 卡片没建出来：接受当前落点
    final aligned = _chapterAlignedOffset(chapterIdx);
    if (aligned == null) return;
    await _scroll.animateTo(
      aligned.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final refined = _headerPreferredOffset(chapterIdx);
    if (refined != null && (refined - _scroll.offset).abs() > 2) {
      await _scroll.animateTo(
        refined.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 让章标题贴住视口上沿的落点：标题已构建时用实测，否则按同章几何反推。
  double? _chapterAlignedOffset(int chapterIdx) {
    final cardCtx = _currentCardKey.currentContext;
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (cardCtx == null || viewportBox is! RenderBox) return null;

    final exact = _headerPreferredOffset(chapterIdx);
    if (exact != null) return exact;

    final cardBox = cardCtx.findRenderObject();
    if (cardBox is! RenderBox) return null;
    final cl = _levelsOfChapter(chapterIdx);
    final idx = cl.indexWhere((l) => l.id == _currentLevelId);
    if (idx < 0) return null;
    const columns = 2;
    const gap = 12.0;
    final width = viewportBox.size.width;
    final cellH = ((width - 32 - gap * (columns - 1)) / columns) / 1.12;
    final headerBlock = _headerKeys[0].currentContext?.size?.height ?? 48.0;
    final cardTop = _scroll.offset +
        cardBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final rowsAbove = idx ~/ columns;
    final aligned = cardTop - headerBlock - rowsAbove * (cellH + gap) - 8;
    // 卡片会被挤出视口下方就不硬来，退回「卡片落在上三分之一」。
    if (cardTop - aligned + cardBox.size.height >
        _scroll.position.viewportDimension - 10) {
      return null;
    }
    return aligned;
  }

  /// 章标题已构建时，让它贴住视口上沿的精确落点；未构建或卡片会被挤出时
  /// 返回 null。
  double? _headerPreferredOffset(int chapterIdx) {
    final headerCtx = _headerKeys[chapterIdx].currentContext;
    final cardCtx = _currentCardKey.currentContext;
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (headerCtx == null || cardCtx == null || viewportBox is! RenderBox) {
      return null;
    }
    final headerBox = headerCtx.findRenderObject();
    final cardBox = cardCtx.findRenderObject();
    if (headerBox is! RenderBox || cardBox is! RenderBox) return null;
    final hTop = _scroll.offset +
        headerBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final cTop = _scroll.offset +
        cardBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final cBottom = cTop + cardBox.size.height;
    final viewH = _scroll.position.viewportDimension;
    final aligned = hTop - 8;
    if (cTop - aligned < 0 || cBottom - aligned > viewH - 10) return null;
    return aligned;
  }

  /// 目标关卡在滚动坐标系里的落点；null = 找不到（不该发生）。
  ///
  /// 几何模型与 [_chapterSlivers] 一一对应：
  /// 总进度卡（实测高）+ 每章「标题（实测高）+ 网格（行数 × 格高 + 行距）」
  /// + 最后的 16px 收尾。格子几何取自 SliverGrid 的固定参数。
  double? _offsetForLevel(int levelId) {
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.hasSize) return null;
    final width = viewportBox.size.width;

    // 首帧实测：进度卡与章标题的整块高度（含各自的 padding）。
    final progressBlock =
        _progressKey.currentContext?.size?.height ?? 92.0;
    final headerBlock = _headerKeys[0].currentContext?.size?.height ?? 48.0;

    const gridHPad = 16.0;
    const crossGap = 12.0;
    const mainGap = 12.0;
    const aspect = 1.12;
    const columns = 2;
    final cellW = (width - gridHPad * 2 - crossGap * (columns - 1)) / columns;
    final cellH = cellW / aspect;

    var y = progressBlock;
    for (var i = 0; i < levelChapters.length; i++) {
      final cl = _levelsOfChapter(i);
      if (cl.isEmpty) continue;
      final rows = (cl.length + columns - 1) ~/ columns;
      final gridH = rows * cellH + (rows - 1) * mainGap;
      final idx = cl.indexWhere((l) => l.id == levelId);
      if (idx >= 0) {
        // 卡片落在视口上三分之一：上面留一点章标题的上下文，下面留出
        // 后续关卡，玩家一眼看得出「这是哪一章、后面还有什么」。
        final rowTop = y + headerBlock + (idx ~/ columns) * (cellH + mainGap);
        final viewportH = _scroll.position.viewportDimension;
        return rowTop - viewportH * 0.30;
      }
      y += headerBlock + gridH;
    }
    return null;
  }

  /// 第 idx 章的关卡（边界规则与 [_chapterSlivers] 完全一致）。
  List<LevelDefinition> _levelsOfChapter(int idx) {
    final startId = levelChapters[idx].startId;
    final endId = idx + 1 < levelChapters.length
        ? levelChapters[idx + 1].startId
        : 1 << 30;
    return levels.where((l) => l.id >= startId && l.id < endId).toList();
  }

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
                title: L10n.value.levelMapTitle,
                subtitle: L10n.value.levelMapSubtitle(completed, total),
                accent: AppColors.sky,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  CoinPill(amount: data.coins, compact: true),
                  const SizedBox(width: 10),
                ],
              ),
              Expanded(
                child: AnimatedOpacity(
                  // 定位落定前不显示：不然会先瞥见列表顶部再"跳"下去。
                  // 透明度不影响布局，首帧照样能量到真实高度。
                  opacity: _listReady ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: CustomScrollView(
                    key: _viewportKey,
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          key: _progressKey,
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                          child: TotalProgressCard(
                            completed: completed,
                            total: total,
                            stars:
                                data.bestStars.values.fold(0, (a, b) => a + b),
                          ),
                        ),
                      ),
                      for (var i = 0; i < levelChapters.length; i++)
                        ..._chapterSlivers(
                          i,
                          levelChapters[i],
                          _chapterColors[i % _chapterColors.length],
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单章渲染：章节色条头 + 该章关卡网格。
  List<Widget> _chapterSlivers(
      int idx, LevelChapter chapter, Color chapterColor) {
    final cl = _levelsOfChapter(idx);
    if (cl.isEmpty) return const [];
    final cleared = cl.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    final unlockedCount = cl.where((l) => l.id <= data.unlockedLevel).length;
    final locked = unlockedCount == 0;
    final currentId = _currentLevelId;

    return [
      SliverToBoxAdapter(
        child: Padding(
          // 第一章的标题块量一次高度，作为所有章标题块的高度（SectionTitle
          // 的 title/subtitle 都是 maxLines:1，各章等高）。
          key: _headerKeys[idx],
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SectionTitle(
            title: chapter.title,
            // 魔王章：大阶段（3 章）末章的整章 +1 档。徽标说破身份，
            // 玩家才会把「这一章特别难」理解为阶段收官而不是数值出错。
            subtitle: LevelProgression.isMergeDemon(chapter.startId)
                ? L10n.value.demonChapter(chapter.subtitle)
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
              final isCurrent = level.id == currentId;
              return LevelCard(
                key: isCurrent ? _currentCardKey : null,
                level: level,
                unlocked: unlocked,
                current: isCurrent,
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
                    Text(L10n.value.totalStars,
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
                      ? L10n.value.allLevelsUnlocked
                      : L10n.value.levelsLeftToUnlock(total - completed),
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
  const _AdGateChip();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.coralDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎬', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            L10n.value.adChallengeBadge,
            style: TextStyle(
              color: AppTheme.deepen(c, 0.30),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boss 关小标：👑 + 「BOSS」，标出两个完整心跳后的超级难关。
///
/// 与 🎬 挑战关的区别说给玩家：🎬 是「难一档，硬实力能过」；
/// 👑 是「这一关就是冲着你来的」—— 全表最紧的节点，档位更高、
/// 障碍更多、牌堆更紧，失败看广告有支援，但不是墙。
/// Boss 关**不显示**心跳相位标（它的强度与相位无关，标「轻松/顺手」
/// 会误导）—— 👑 徽标本身就是最强的难度预告。
class _BossChip extends StatelessWidget {
  const _BossChip();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.grape;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            'BOSS',
            style: TextStyle(
              color: AppTheme.deepen(c, 0.30),
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 难度心跳小标：色点 + 档位名，让玩家一眼看出这一关在本轮 5 关里的位置。
class _RhythmChip extends StatelessWidget {
  const _RhythmChip({required this.phase});

  final int phase;

  @override
  Widget build(BuildContext context) {
    final c = LevelRhythm.colorOf(RhythmMode.merge, phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            LevelRhythm.displayNameOf(RhythmMode.merge, phase),
            style: TextStyle(
              color: AppTheme.deepen(c, 0.30),
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
    this.current = false,
    this.onTap,
  });

  final LevelDefinition level;
  final bool unlocked;
  final int best;
  final int bestStars;
  final VoidCallback? onTap;

  /// 是否是「接下来该打的那一关」（= 已解锁的最后一关）。
  ///
  /// 地图一滚就是十几屏，光把视口推过去还不够——玩家需要一眼认出
  /// 「就是这张」。所以当前关加一圈实色环 + 车标角上的 ▶ 继续标记。
  final bool current;

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
            color: c.withValues(
                alpha: current ? 1.0 : (unlocked ? 0.42 : 0.20)),
            width: current ? 3 : (unlocked ? 2 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: unlocked
                  ? c.withValues(alpha: current ? 0.42 : 0.22)
                  : AppColors.shadow.withValues(alpha: 0.5),
              blurRadius: current ? 20 : 14,
              offset: const Offset(0, 5),
            ),
            // 当前关再加一层外扩光环：扫视时最先落到这张卡上。
            if (current)
              BoxShadow(
                color: c.withValues(alpha: 0.28),
                blurRadius: 26,
                spreadRadius: 2,
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
                        // 序号 + 难度徽标用 FittedBox 兜住：三星卡在 390px 宽的
                        // 两列网格里只有 ~143px，塞满「第 N 关 + 心跳 + 🎬」会
                        // RenderFlex 溢出（release 下面板被静默裁掉）。
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
                                    L10n.value.levelNumberChip(level.id),
                                    style: TextStyle(
                                        color: unlocked
                                            ? Colors.white
                                            : AppColors.ink3,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10.5),
                                  ),
                                ),
                                // 难度徽标：只标生成段（L71+）。手写关的参数是
                                // 逐关手工调的，套用相位会与实际体感不符。
                                //
                                // 👑 Boss 与 🎬 广告关都**不叠心跳标**：两者都是
                                // 「整关 +1 档以上」，标成「轻松/顺手」会说反强度。
                                // 卡面窄，也只容得下一个徽标。
                                if (level.id >= LevelDataGenerator.firstId &&
                                    unlocked) ...[
                                  const SizedBox(width: 5),
                                  if (LevelProgression.isMergeBossLevel(level.id))
                                    const _BossChip()
                                  else if (LevelProgression.isMergeAdGate(
                                      level.id))
                                    const _AdGateChip()
                                  else
                                    _RhythmChip(
                                      phase: LevelDataGenerator.rhythmPhase(
                                          level.id),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!unlocked)
                          const Icon(Icons.lock_rounded,
                              color: AppColors.ink3, size: 16),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
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
                                            vehicle: level.targetTier!,
                                            size: 42),
                                      ),
                                    )
                                  : Icon(Icons.grid_view_rounded,
                                      size: 26,
                                      color: unlocked
                                          ? AppColors.ink2
                                          : AppColors.ink3),
                            ),
                          ),
                          // 「继续」角标：当前关的车标上挂一枚播放按钮，
                          // 和边框光环配合，让"打哪一关"无需阅读文字。
                          if (current)
                            Positioned(
                              right: -3,
                              bottom: -3,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.gradientFor(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.withValues(alpha: 0.45),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    size: 15, color: Colors.white),
                              ),
                            ),
                        ],
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
                    // 星级常驻右下角：和「最佳 N 分」同源，放一起读着更顺，
                    // 也把卡头那行让给「序号 + 难度徽标」（窄卡塞不下四样）。
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            best > 0
                                ? L10n.value.bestScoreInline(best)
                                : (unlocked
                                    ? L10n.value.levelNotPlayed
                                    : L10n.value.levelLockedHint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: best > 0
                                    ? AppColors.sun
                                    : (unlocked
                                        ? AppColors.ink2
                                        : AppColors.ink3),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (bestStars > 0) ...[
                          const SizedBox(width: 4),
                          StarRow(stars: bestStars, size: 12),
                        ],
                      ],
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

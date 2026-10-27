import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/audio_feedback.dart';
import '../game/parking_daily_challenge.dart';
import '../l10n/l10n.dart';
import '../models/parking_level.dart';
import '../save/save_repository.dart';
import '../services/level_progression.dart';
import '../services/level_rhythm.dart';
import '../services/parking_chapters.dart';
import '../services/parking_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_ui.dart';
import '../widgets/pressable.dart';
import '../widgets/vehicle_image.dart';
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

  final ScrollController _scroll = ScrollController();

  /// 量尺寸/校正用的锚点：每日卡、每一章的卡片、列表视口。
  final GlobalKey _dailyKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();
  final List<GlobalKey> _chapterKeys =
      List.generate(ParkingChapters.all.length, (_) => GlobalKey());

  /// 定位到「下一关」的格子（滚动后把格子精确推进视口）。
  final GlobalKey _currentTileKey = GlobalKey();

  /// 自动定位只跑一次（进页跑一次即可，返回本页时 State 不重建）。
  bool _located = false;

  /// 定位落定前先隐藏列表，避免玩家先看到列表顶部再"跳"下去。
  bool _listReady = false;

  /// 玩家接下来该打的那一关（= 下一个待解锁关卡）。
  int get _currentLevelId =>
      widget.data.parkingUnlocked.clamp(1, ParkingChapters.totalLevels);

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
    // 首帧之后才有尺寸可量。
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLocate());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 800 关分 22 章：进页把视口推到「下一关」所在的章节与格子。
  ///
  /// 章节卡高度差异很大（解锁章整片关卡格 vs 锁定章一个提示条），
  /// 单靠公式外推会飘几百像素，所以采用「先跳到估算位 → 用已构建章节卡
  /// 的真实位置反推误差 → 再跳」的校正循环，最后用 ensureVisible 收口。
  Future<void> _autoLocate() async {
    if (_located || !mounted || !_scroll.hasClients) return;
    _located = true;

    var dest = _estimateOffset(_currentLevelId);
    for (var attempt = 0; attempt < 4; attempt++) {
      if (dest == null) break;
      _scroll.jumpTo(dest.clamp(0.0, _scroll.position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (_currentTileKey.currentContext != null) break;
      // 目标格还没被建出来：拿任一个已构建章节卡的真实起点校正模型。
      final fix = _modelError();
      if (fix == null) break;
      dest -= fix;
    }

    if (mounted) setState(() => _listReady = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _settleOnCurrentTile();
  }

  /// 收口：优先把「这一章的卡头」推到视口上沿，让玩家一眼看清自己在
  /// 哪一章（停车格很小，只推格子会把章标题挤出屏幕）；目标格因此
  /// 掉出视口下方时，退回「格子落在上三分之一」。
  Future<void> _settleOnCurrentTile() async {
    final tileCtx = _currentTileKey.currentContext;
    if (tileCtx == null) return;
    final dest = _headerPreferredOffset();
    if (dest != null && (dest - _scroll.offset).abs() > 2) {
      await _scroll.animateTo(
        dest.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await Scrollable.ensureVisible(
      tileCtx,
      alignment: 0.3,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// 目标关所在章节的卡头贴住视口上沿所需落点；目标格会被挤出时返回 null。
  double? _headerPreferredOffset() {
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    final tileCtx = _currentTileKey.currentContext;
    if (viewportBox is! RenderBox || tileCtx == null) return null;
    final chIdx = ParkingChapters.all
        .indexWhere((c) => _currentLevelId >= c.startId && _currentLevelId <= c.endId);
    if (chIdx < 0) return null;
    final chapterCtx = _chapterKeys[chIdx].currentContext;
    if (chapterCtx == null) return null;
    final chapterBox = chapterCtx.findRenderObject();
    final tileBox = tileCtx.findRenderObject();
    if (chapterBox is! RenderBox || tileBox is! RenderBox) return null;
    final chTop = _scroll.offset +
        chapterBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final tTop =
        _scroll.offset + tileBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final tBottom = tTop + tileBox.size.height;
    final viewH = _scroll.position.viewportDimension;
    final aligned = chTop - 8;
    if (tTop - aligned < 0 || tBottom - aligned > viewH - 10) return null;
    return aligned;
  }

  /// 已构建章节卡里「模型起点 − 真实起点」的最大值（= 累计误差估计）。
  ///
  /// 取离视口最近的那张已构建卡片做参照：它的上方所有章节都被跨过，
  /// 误差与目标处的误差最接近。
  double? _modelError() {
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (viewportBox is! RenderBox) return null;
    for (var i = ParkingChapters.all.length - 1; i >= 0; i--) {
      final ctx = _chapterKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final real =
          _scroll.offset + box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      return _chapterTop(i) - real;
    }
    return null;
  }

  /// 第 idx 章卡片在滚动内容里的模型起点（含列表内边距与章间距）。
  double _chapterTop(int idx) {
    var y = 4 + _dailyBlockH + 14;
    for (var i = 0; i < idx; i++) {
      y += _chapterBlockH(i) + 14;
    }
    return y;
  }

  /// 目标关卡所在格子的估算落点；null = 章节映射失败（不该发生）。
  double? _estimateOffset(int levelId) {
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.hasSize) return null;
    final chIdx = ParkingChapters.all
        .indexWhere((c) => levelId >= c.startId && levelId <= c.endId);
    if (chIdx < 0) return null;
    final ch = ParkingChapters.all[chIdx];
    const columns = 5;
    const gap = 7.0;
    const chromeV = 12 + 66 + 14; // 网格内边距 + 卡头 + 网格下边距估算
    final cardW = viewportBox.size.width - 28;
    final cellW = (cardW - 4 - 24 - gap * (columns - 1)) / columns;
    final cellH = cellW / 0.92;
    final row = (levelId - ch.startId) ~/ columns;
    final gridTop = _chapterTop(chIdx) + chromeV;
    final viewportH = _scroll.position.viewportDimension;
    return gridTop + row * (cellH + gap) - viewportH * 0.30;
  }

  /// 每日挑战卡整块高度（含上下间距的一半），首帧实测。
  double get _dailyBlockH =>
      _dailyKey.currentContext?.size?.height ?? 88.0;

  /// 章节卡高度：解锁章按网格行数推，锁定章是固定提示条（估算）。
  ///
  /// 误差不影响正确性——[_modelError] 会拿实际布局把它校回来。
  double _chapterBlockH(int idx) {
    final ch = ParkingChapters.all[idx];
    if (!_chapterAccessible(ch)) return 134;
    final count = _byChapter[ch]!.length;
    const columns = 5;
    const gap = 7.0;
    final rows = (count + columns - 1) ~/ columns;
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    final width = viewportBox is RenderBox && viewportBox.hasSize
        ? viewportBox.size.width
        : 390.0;
    final cellW = ((width - 28) - 4 - 24 - gap * (columns - 1)) / columns;
    final cellH = cellW / 0.92;
    return 66 + 14 + rows * cellH + (rows - 1) * gap;
  }

  /// 章节是否可进入（双向联动）。
  bool _chapterAccessible(ParkingChapter c) =>
      ParkingChapters.isAccessible(c, widget.data.collection, widget.data.parkingBestStars);

  @override
  Widget build(BuildContext context) {
    final l = L10n.value;
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
                title: l.parkingMode,
                subtitle: cleared == 0
                    ? l.parkingSelectSubEmpty
                    : l.parkingSelectProgress(cleared, total),
                accent: AppColors.mint,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  CoinPill(amount: widget.data.coins, compact: true),
                  const SizedBox(width: 10),
                ],
              ),
              Expanded(
                child: AnimatedOpacity(
                  // 定位落定前不显示：不然会先瞥见列表顶部再"跳"下去。
                  // 透明度不影响布局，首帧照样能量到真实高度。
                  opacity: _listReady ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: ListView(
                    key: _viewportKey,
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    children: [
                      KeyedSubtree(
                        key: _dailyKey,
                        child: _buildDailyChallengeCard(),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < ParkingChapters.all.length; i++) ...[
                        KeyedSubtree(
                          key: _chapterKeys[i],
                          child: _chapterCard(ParkingChapters.all[i]),
                        ),
                        const SizedBox(height: 14),
                      ],
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

  Widget _chapterCard(ParkingChapter chapter) {
    final l = L10n.value;
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
                        ? VehicleImage(vehicle: chapter.tier, size: 32)
                        : const Icon(Icons.lock_person_rounded,
                            color: AppColors.ink3, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 魔王章徽标：大阶段（3 章）的末章，整章 +1 档。
                      // 阶段结构只有被看见才存在——玩家看到「魔王章」
                      // 才会意识到「我在打一个阶段的收官战」。
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chapter.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    accessible ? AppColors.ink1 : AppColors.ink2,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (LevelProgression.isParkingDemon(chapter.startId)) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.coralDeep
                                    .withValues(alpha: accessible ? 0.16 : 0.08),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                l.parkingDemonBadge,
                                style: const TextStyle(
                                  color: AppColors.coralDeep,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        accessible
                            ? l.parkingChapterMeta(
                                LevelProgression.displayStageName(
                                  LevelProgression.stageOf(
                                    LevelProgression.parkingChapterIndex(
                                        chapter.startId),
                                  ),
                                ),
                                chapter.subtitle,
                              )
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
    // 「接下来该打的那一关」：加一圈实色环 + ▶ 角标，进页自动定位后
    // 玩家不用再猜该点哪个格子。
    final current = levelId == _currentLevelId;
    final accent = cleared ? AppColors.sun : chapterColor;
    final tile = Pressable(
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
            color: accent.withValues(
                alpha: current ? 1.0 : (cleared ? 0.42 : 0.24)),
            width: current ? 2.6 : (cleared ? 1.8 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: current ? 0.40 : (cleared ? 0.20 : 0.12)),
              blurRadius: current ? 16 : 9,
              offset: const Offset(0, 3),
            ),
            if (current)
              BoxShadow(
                color: accent.withValues(alpha: 0.26),
                blurRadius: 20,
                spreadRadius: 2,
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
                VehicleImage(
                  vehicle: ParkingChapters.tierForId(levelId),
                  size: 20,
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
            // 广告挑战关角标：🎬 徽标。这一关比同位置难一档（步数 +1 /
            // 挡路车 +1），但失败了可以看广告续命/撤销/提示——是难关，不是墙。
            if (LevelProgression.isParkingAdGate(levelId))
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.coralDeep.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '🎬',
                    style: TextStyle(fontSize: 7.5, height: 1.1),
                  ),
                ),
              ),
            // 「继续」角标：当前关右下角挂一枚播放按钮，配合实色环
            // 让"点哪一格"无需阅读。
            if (current)
              Positioned(
                bottom: 3,
                right: 3,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradientFor(accent),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 10, color: Colors.white),
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
    return current ? KeyedSubtree(key: _currentTileKey, child: tile) : tile;
  }

  Widget _buildDailyChallengeCard() {
    final l = L10n.value;
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
                Text(l.parkingDailyTitle,
                    style: const TextStyle(
                        color: AppColors.ink1,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                const SizedBox(height: 3),
                Text(
                  cleared
                      ? (streak > 0
                          ? l.parkingDailyDone + l.parkingDailyStreakSuffix(streak)
                          : l.parkingDailyDone)
                      : streak >= 2
                          ? l.parkingDailyStreakReward(streak,
                              ParkingDailyChallenge.reward +
                                  ParkingDailyChallenge.streakBonus(streak))
                          : l.parkingDailyTodayReward(
                              ParkingDailyChallenge.reward),
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
            SoftChip(label: l.parkingDoneChip, icon: Icons.check_circle, color: AppColors.mint, solid: true)
          else
            CandyButton(
              label: l.parkingGo,
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

import 'package:flutter/foundation.dart'; // kDebugMode：调试专用按钮用
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
      // ─────────────────────────────────────────────────────────────
      //  调试专用（发布前删除）：Boss 关快速入口
      //  debug/profile 模式渲染，release 构建自动不渲染（这就是上次
      //  release 预览看不到按钮的原因）；删代码时连同本段 +
      //  文件末尾 _BossDebugButton + 顶部 foundation import 一起删。
      // ─────────────────────────────────────────────────────────────
      floatingActionButton: (kDebugMode || kProfileMode)
          ? _BossDebugButton(onPick: (id) => _openLevel(levels[id - 1]))
          : null,
      // ─────────────────────────────────────────────────────────────
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

/// Boss 关小标：👑 + 「BOSS」，标出两个完整心跳后的超级难关。
///
/// 与 🎬 挑战关的区别说给玩家：🎬 是「难一档，硬实力能过」；
/// 👑 是「这一关就是冲着你来的」—— 全表最紧的节点，档位更高、
/// 障碍更多、牌堆更紧，失败看广告有支援，但不是墙。
/// Boss 关**不显示**心跳相位标（它的强度与相位无关，标「轻松/顺手」
/// 会误导）—— 👑 徽标本身就是最强的难度预告。
class _BossChip extends StatelessWidget {
  const _BossChip({this.dim = false});

  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.grape;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: dim
            ? AppColors.ink3.withValues(alpha: 0.12)
            : c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '👑',
            style: TextStyle(fontSize: 9, color: dim ? AppColors.ink3 : null),
          ),
          const SizedBox(width: 3),
          Text(
            'BOSS',
            style: TextStyle(
              color: dim ? AppColors.ink3 : AppTheme.deepen(c, 0.30),
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
                          // Boss 关：只显示 👑 BOSS 徽标。它的强度与心跳
                          // 相位无关（刻意错开），显示相位标会说反强度。
                          if (LevelProgression.isMergeBossLevel(level.id))
                            _BossChip(dim: !unlocked)
                          else ...[
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

// ─────────────────────────────────────────────────────────────
//  调试专用（发布前删除）：Boss 关快速入口
//  删除时连同 build 里的 floatingActionButton 段和顶部
//  `import 'package:flutter/foundation.dart';` 一起删。
// ─────────────────────────────────────────────────────────────

/// 调试专用 Boss 入口：debug/profile 模式渲染，release 自动不渲染。
///
/// 点开列出**全量 56 个 Boss 关**（14 章 × 4，与生成器选点公式一致：
/// 章内偏移 10 + b×11），按章分组；每行显示卡组摘要（主技+辅技+绰号/盾/怒）
/// 和 HP，点哪行进哪关，不需要先解锁。调 Boss 手感、验卡组分布时用。
class _BossDebugButton extends StatelessWidget {
  const _BossDebugButton({required this.onPick});

  final void Function(int levelId) onPick;

  /// 技能中文名（仅调试面板展示；线上玩家的识别手段是预警环配色）。
  static const Map<BossAttackKind, String> _skillNames = {
    BossAttackKind.freeze: '冰封',
    BossAttackKind.steal: '拖车',
    BossAttackKind.lock: '锁堆',
    BossAttackKind.ice: '冰块',
    BossAttackKind.rubble: '塌方',
    BossAttackKind.impound: '扣押',
    BossAttackKind.devolve: '退化',
    BossAttackKind.taint: '污染',
    BossAttackKind.shield: '护盾',
  };

  /// 全量 Boss 关 id：章 c 内偏移 10 + b×11（b = 0..3）。
  static List<int> get _allBossIds => [
        for (var c = 0; c < LevelDataGenerator.chapterCount; c++)
          for (var b = 0; b < 4; b++)
            LevelDataGenerator.firstId +
                c * LevelDataGenerator.chapterSize +
                10 +
                b * 11,
      ];

  /// 「冰封 + 拖车 · 碎石王 盾」式卡组摘要。
  static String _deckLabel(BossSpec spec) {
    final skills = [
      _skillNames[spec.primary] ?? spec.primary.name,
      if (spec.secondary != null)
        _skillNames[spec.secondary!] ?? spec.secondary!.name,
    ].join(' + ');
    final marks = [
      if (spec.epithet != null) spec.epithet!,
      if (spec.shieldCycle > 0) '盾',
      if (spec.enrageAtHalf) '怒',
    ];
    return marks.isEmpty ? skills : '$skills · ${marks.join(' ')}';
  }

  /// Boss 在章内的槽位（0..3，3 = 尖峰招牌）。
  static int _slotOf(int id) {
    final c =
        (id - LevelDataGenerator.firstId) ~/ LevelDataGenerator.chapterSize;
    return (id - LevelDataGenerator.firstId - c * LevelDataGenerator.chapterSize -
            10) ~/
        11;
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFFB3372F),
      foregroundColor: Colors.white,
      elevation: 6,
      onPressed: () => _showBossSheet(context),
      icon: const Text('👑', style: TextStyle(fontSize: 18)),
      label: const Text('BOSS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  void _showBossSheet(BuildContext context) {
    AudioFeedback.uiTap();
    // 扁平化行表：章头 + 该章 4 个 Boss 行。
    final rows = <({bool header, int chapter, int id})>[];
    for (var c = 0; c < LevelDataGenerator.chapterCount; c++) {
      rows.add((header: true, chapter: c, id: 0));
      for (final id in _allBossIds) {
        final cc =
            (id - LevelDataGenerator.firstId) ~/ LevelDataGenerator.chapterSize;
        if (cc == c) rows.add((header: false, chapter: c, id: id));
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text('👑 Boss 调试入口 · 全 56 关',
                  style: TextStyle(
                      color: AppColors.ink1,
                      fontWeight: FontWeight.w900,
                      fontSize: 17)),
              const SizedBox(height: 2),
              const Text('仅调试模式可见 · 发布前删除',
                  style: TextStyle(color: AppColors.ink2, fontSize: 11.5)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return r.header
                        ? _chapterHeader(r.chapter)
                        : _bossTile(ctx, r.id);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapterHeader(int c) {
    final color = _chapterColors[c % _chapterColors.length];
    final firstIdOfChapter =
        LevelDataGenerator.firstId + c * LevelDataGenerator.chapterSize;
    final tierName = levels[firstIdOfChapter - 1].targetTier?.name ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('第 ${c + 1} 章',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 12.5)),
          ),
          const SizedBox(width: 8),
          Text('L$firstIdOfChapter 起 · $tierName',
              style: const TextStyle(color: AppColors.ink2, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _bossTile(BuildContext ctx, int id) {
    final level = levels[id - 1];
    final spec = level.boss!;
    final c =
        (id - LevelDataGenerator.firstId) ~/ LevelDataGenerator.chapterSize;
    final b = _slotOf(id);
    final isPeak = b == 3;
    return ListTile(
      dense: true,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPeak ? const Color(0xFF8E24AA) : const Color(0xFFB3372F),
          shape: BoxShape.circle,
        ),
        child: Text(
          isPeak ? '👑' : '${b + 1}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
      title: Text('L$id · ${_deckLabel(spec)}',
          style: const TextStyle(
              color: AppColors.ink1, fontWeight: FontWeight.w800, fontSize: 13.5)),
      subtitle: Text(
        '第 ${c + 1} 章 · 第 ${b + 1} 个${isPeak ? ' · 尖峰' : ''} · HP ${spec.hp}',
        style: const TextStyle(color: AppColors.ink2, fontSize: 11.5),
      ),
      trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.ink2),
      onTap: () {
        Navigator.pop(ctx);
        onPick(id);
      },
    );
  }
}

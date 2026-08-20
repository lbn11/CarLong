import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/daily_challenge.dart';
import '../game/game_config.dart';
import '../game/music_player.dart';
import '../analytics/analytics.dart';
import '../models/achievement.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../models/level.dart';
import '../save/save_repository.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/vehicle_image.dart';
import 'achievements_screen.dart';
import 'collection_screen.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'parking_level_select.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const HomeScreen({super.key, required this.data, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware {
  PlayerData get data => widget.data;

  late final AnalyticsService _analytics;

  /// 入场仪式：控制各区块的淡入上浮。
  late final AnimationController _enter;
  late final Animation<double> _enterAnim;

  /// 环境氛围：缓慢漂移的背景光晕。
  late final AnimationController _ambient;

  // ===== 首页首启引导 =====
  /// 首页引导的存档 key（与合成/停车教程区分）。
  static const int _homeTutorialKey = -2;
  bool _homeTutorialActive = false;
  int _homeStepIndex = 0;
  Rect? _homeHighlightRect;
  final GlobalKey _levelListKey = GlobalKey();
  final GlobalKey _parkingEntryKey = GlobalKey();
  final GlobalKey _shopRowKey = GlobalKey();

  static const List<TutorialStep> _homeSteps = [
    TutorialStep(
      text: '👋 欢迎来到车队！点这里选择关卡，'
          '第一关会手把手教你合成玩法',
      highlight: TutorialHighlight.homeLevels,
      blocking: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _analytics = AnalyticsService(widget.data, widget.repo);
    _analytics.appLaunch(isFirst: widget.data.analyticsEvents.isEmpty);
    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _enterAnim = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _ambient = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))
      ..repeat();
    // 首启引导：等首帧布局完成再算高亮矩形（2026-08-19 重做轻量版后恢复）。
    if (!widget.data.tutorialCompleted.contains(_homeTutorialKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _homeTutorialActive = true;
            _homeStepIndex = 0;
          });
          _updateHomeHighlight();
        }
      });
    }
    // 离线收益：进入首页即结算并更新在线时间戳。
    _checkOfflineReward();
    // 首页 BGM（跟随音效开关）。
    if (widget.data.soundOn) {
      MusicPlayer.instance.play(MusicPlayer.home);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      musicRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // 从合成/停车返回首页：恢复首页 BGM。
    if (widget.data.soundOn) {
      MusicPlayer.instance.play(MusicPlayer.home);
    }
  }

  @override
  void dispose() {
    musicRouteObserver.unsubscribe(this);
    _enter.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// 离线收益（留存钩子）：离开 30 分钟+ 回来自动领金币。
  /// 速率 20🪙/小时，上限 8 小时。首次进入（无时间戳）不发放。
  void _checkOfflineReward() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = data.lastSeenAt;
    data.lastSeenAt = now;
    widget.repo.save(data);
    if (last == null) return;
    final offlineMs = now - last;
    if (offlineMs < 30 * 60 * 1000) return;
    final hours = (offlineMs / 3600000).clamp(0, 8).toDouble();
    // 离线速率 12🪙/h（上限 8h = 96），防补贴通胀（原 20/h）。
    final reward = (hours * GameConfig.offlineCoinsPerHour).floor();
    if (reward <= 0) return;
    data.addCoins(reward);
    widget.repo.save(data);
    _analytics.offlineReward(reward, hours.round());
    final hoursText = offlineMs >= 2 * 3600000
        ? '${(offlineMs / 3600000).toStringAsFixed(1)} 小时'
        : '${(offlineMs / 60000).round()} 分钟';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.surfaceLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👋', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 10),
                const Text('欢迎回来！',
                    style: TextStyle(
                        color: AppColors.ink1,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('离线 $hoursText，车队帮你攒了',
                    style: const TextStyle(color: AppColors.ink2)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text('+$reward 🪙',
                        style: const TextStyle(
                            color: AppColors.coinText,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                  ),
                  child: const Text('收下啦',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// 根据当前步骤计算高亮区域（GlobalKey -> 屏幕 Rect）。
  void _updateHomeHighlight() {
    if (!_homeTutorialActive ||
        _homeStepIndex >= _homeSteps.length) {
      _homeHighlightRect = null;
      return;
    }
    final step = _homeSteps[_homeStepIndex];
    GlobalKey? target;
    switch (step.highlight) {
      case TutorialHighlight.homeLevels:
        target = _levelListKey;
        break;
      case TutorialHighlight.homeParking:
        target = _parkingEntryKey;
        break;
      case TutorialHighlight.homeShop:
        target = _shopRowKey;
        break;
      default:
        target = null;
    }
    Rect? rect;
    if (target != null) {
      final ctx = target.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.attached) {
          rect = box.localToGlobal(Offset.zero) & box.size;
        }
      }
    }
    // 修复：关卡入口在首页滚动列表下方，首屏可能不可见。
    // 引导激活时自动滚动到目标，保证高亮真正在玩家视野内。
    if (target != null && rect != null) {
      final targetCtx = target.currentContext;
      if (targetCtx != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _homeTutorialActive) {
            Scrollable.ensureVisible(
              targetCtx,
              duration: const Duration(milliseconds: 350),
              alignment: 0.5,
            );
          }
        });
      }
    }
    setState(() => _homeHighlightRect = rect);
  }

  void _advanceHomeTutorial() {
    if (_homeStepIndex < _homeSteps.length - 1) {
      setState(() => _homeStepIndex++);
      _updateHomeHighlight();
    } else {
      // 引导结束：标记完成并直接进入选关页（新玩家衔接 L1 合成教学）。
      _finishHomeTutorial();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              LevelSelectScreen(data: data, repo: widget.repo),
        ),
      );
    }
  }

  void _finishHomeTutorial() {
    setState(() {
      _homeTutorialActive = false;
      _homeHighlightRect = null;
    });
    widget.data.tutorialCompleted.add(_homeTutorialKey);
    widget.repo.save(widget.data);
    _analytics.tutorialComplete('home');
  }

  String _dateFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _today() => _dateFor(DateTime.now());

  String _yesterday() =>
      _dateFor(DateTime.now().subtract(const Duration(days: 1)));

  /// 7 日签到固定档位：前 6 天递增，第 7 天大奖。
  static const List<int> _signInRewards = GameConfig.signInRewards;

  void _onSignIn() {
    final today = _today();
    if (data.lastSignInDate == today) {
      _showDialog(
        '今日已签到',
        '已连续签到 ${data.signInStreak} 天，坚持到第 7 天领大奖！',
        Icons.check_circle,
        const Color(0xFF66BB6A),
      );
      return;
    }
    final consecutive = data.lastSignInDate == _yesterday();
    final streak = consecutive ? data.signInStreak + 1 : 1;
    // 7 日循环：断签回到第 1 天，连续则推进到下一档（第 8 天回到第 1 天）。
    final day = consecutive ? (data.signInDay % 7) + 1 : 1;
    data.lastSignInDate = today;
    data.signInStreak = streak;
    data.signInTotal += 1;
    data.signInDay = day;
    final reward = _signInRewards[day - 1];
    data.addCoins(reward);
    widget.repo.save(data);
    _analytics.signIn(day, reward);
    setState(() {});
    _showDialog(
      day == 7 ? '🎁 签到大奖！+$reward 🪙' : '签到成功！+$reward 🪙',
      day == 7
          ? '已连续签到 $streak 天，集满 7 日循环，豪礼到手！'
              '明天开启新一轮循环。'
          : '已连续签到 $streak 天，累计 $reward 金币入账。'
              '坚持签到，第 7 天有大奖 🎁',
      Icons.calendar_month,
      const Color(0xFFFFCA28),
    );
  }

  void _showDialog(String title, String body, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 44),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.ink1,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.ink2)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 12),
                ),
                child: const Text('好'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('设置',
              style: TextStyle(
                  color: AppColors.ink1, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: data.soundOn,
                title: const Text('音效',
                    style: TextStyle(color: AppColors.ink1)),
                activeTrackColor: AppColors.accent,
                onChanged: (v) {
                  setDialogState(() => data.soundOn = v);
                  widget.repo.save(data);
                  // BGM 跟随音效开关。
                  MusicPlayer.instance.syncEnabled(v, MusicPlayer.home);
                  setState(() {});
                },
              ),
              SwitchListTile(
                value: data.vibrateOn,
                title: const Text('振动',
                    style: TextStyle(color: AppColors.ink1)),
                activeTrackColor: AppColors.accent,
                onChanged: (v) {
                  setDialogState(() => data.vibrateOn = v);
                  widget.repo.save(data);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('完成', style: TextStyle(color: AppColors.ink2)),
            ),
          ],
        ),
      ),
    );
  }

  void _openLevel(LevelDefinition level) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: level, data: data, repo: widget.repo),
      ),
    );
    if (result == true && mounted) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(data: data, repo: widget.repo),
        ),
      );
    }
  }

  void _showEndlessRank() {
    final list = data.endlessBest;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌌 无尽排行榜',
                  style: TextStyle(
                      color: AppColors.ink1,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('还没有纪录，去无尽模式创造高分吧！',
                      style: TextStyle(color: AppColors.ink2)),
                )
              else
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: i == 0
                                      ? const Color(0xFFFFCA28)
                                      : AppColors.ink2,
                                  fontWeight: FontWeight.w800)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: list[i] / (list.first == 0 ? 1 : list.first),
                              minHeight: 8,
                              backgroundColor: AppColors.ink3.withValues(alpha: 0.2),
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${list[i]} 分',
                            style: const TextStyle(
                                color: AppColors.ink1, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 12),
                ),
                child: const Text('好'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradientLight),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (_, _) => CustomPaint(
                  painter: _AmbientPainter(_ambient.value),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Reveal(anim: _enterAnim, start: 0.0, child: _buildHeader()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Reveal(
                            anim: _enterAnim,
                            start: 0.08,
                            child: _buildHero()),
                        const SizedBox(height: 12),
                        _Reveal(
                            anim: _enterAnim,
                            start: 0.22,
                            child: _buildDailyBanner()),
                        const SizedBox(height: 12),
                        _Reveal(
                            anim: _enterAnim,
                            start: 0.34,
                            child: _buildEndlessBanner()),
                        const SizedBox(height: 12),
                        _Reveal(
                            anim: _enterAnim,
                            start: 0.46,
                            child: _buildSignInBanner()),
                        const SizedBox(height: 12),
                        _Reveal(
                          anim: _enterAnim,
                          start: 0.58,
                          child: Row(
                            key: _shopRowKey,
                            children: [
                              Expanded(
                                child: _buildMiniEntry(
                                  icon: Icons.emoji_events,
                                  color: const Color(0xFFFFCA28),
                                  title: '成就',
                                  subtitle:
                                      '已领 ${data.claimedAchievements.length}/${achievements.length}',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AchievementsScreen(
                                          data: data, repo: widget.repo),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMiniEntry(
                                  icon: Icons.storefront,
                                  color: const Color(0xFF66BB6A),
                                  title: '商店',
                                  subtitle: '购买开局道具，巧用金币',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ShopScreen(
                                          data: data, repo: widget.repo),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Reveal(
                          anim: _enterAnim,
                          start: 0.64,
                          child: _buildCollectionBanner(),
                        ),
                        const SizedBox(height: 12),
                        _Reveal(
                          anim: _enterAnim,
                          start: 0.7,
                          child: KeyedSubtree(
                            key: _levelListKey,
                            child: _buildLevelListEntry(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Reveal(
                          anim: _enterAnim,
                          start: 0.82,
                          child: KeyedSubtree(
                            key: _parkingEntryKey,
                            child: _buildParkingEntry(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 首启引导覆盖层（最顶层，轻量版：不拦截点击，玩家可直接点入口）。
          if (_homeTutorialActive)
            Positioned.fill(
              child: TutorialOverlay(
                steps: _homeSteps,
                onComplete: _finishHomeTutorial,
                onActionDetected: (_) {},
                highlightRect: _homeHighlightRect,
                showNext: true,
                nextLabel: '开始游戏',
                externalStep: _homeStepIndex,
                onNextTap: _advanceHomeTutorial,
              ),
            ),
        ],
      ),
    );
  }

  /// 停车模式入口
  Widget _buildParkingEntry() {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceLight, AppColors.surfaceSoft],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink3.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ParkingLevelSelectScreen(data: data, repo: widget.repo),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.ink3.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.local_parking,
                      color: AppColors.ink2, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('停车模式',
                          style: TextStyle(
                              color: AppColors.ink1,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      Text('把车辆停到指定车位',
                          style:
                              TextStyle(color: AppColors.ink2, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.ink3, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 收藏召回（留存钩子）：图鉴收集进度 + 全图鉴大奖。
  /// 已点亮 X/17 驱动"还差几个"的收集欲；集齐后一次性大奖 500🪙。
  Widget _buildCollectionBanner() {
    final collected = data.collection.length;
    final total = VehicleType.values.length;
    final complete = collected >= total;
    final claimed = data.collectionRewardClaimed;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceLight, AppColors.surfaceSoft],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink3.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CollectionScreen(data: data, repo: widget.repo),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.grape.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_transportation,
                      color: AppColors.grape, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('图鉴收集',
                              style: TextStyle(
                                  color: AppColors.ink1,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          const Spacer(),
                          Text('$collected/$total',
                              style: const TextStyle(
                                  color: AppColors.grape,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : collected / total,
                          minHeight: 8,
                          backgroundColor:
                              AppColors.ink3.withValues(alpha: 0.2),
                          color: AppColors.grape,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (complete && !claimed)
                        FilledButton(
                          onPressed: _claimCollectionReward,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB23E),
                            foregroundColor: const Color(0xFF7A4A12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999)),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                          child: const Text('🎉 领取全图鉴大奖 +500 🪙'),
                        )
                      else
                        Text(
                          complete
                              ? '全图鉴达成！恭喜收藏家 🏆'
                              : '还差 ${total - collected} 个点亮，去合成/停车解锁新车吧！',
                          style: const TextStyle(
                              color: AppColors.ink2, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.ink3, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _claimCollectionReward() {
    if (data.collectionRewardClaimed) return;
    data.collectionRewardClaimed = true;
    data.addCoins(GameConfig.collectionGrandReward);
    widget.repo.save(data);
    setState(() {});
    _showDialog(
      '🎉 全图鉴大奖 +500 🪙',
      '集齐全部 17 款车辆，收藏家之名当之无愧！',
      Icons.emoji_events,
      const Color(0xFFFFB23E),
    );
  }

  /// 收纳入口：首页只留一行「全部关卡」，点进去看完整网格。
  Widget _buildLevelListEntry() {
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceLight, AppColors.surfaceSoft],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink3.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  LevelSelectScreen(data: data, repo: widget.repo),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.ink3.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.grid_view_rounded,
                      color: AppColors.ink2, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('全部关卡',
                          style: TextStyle(
                              color: AppColors.ink1,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('已完成 $completed/${levels.length} 关',
                          style: const TextStyle(
                              color: AppColors.ink2, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.ink3, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 今日挑战卡：每天一个按日期生成的固定关卡。
  Widget _buildDailyBanner() {
    final level = DailyChallenge.levelFor(DateTime.now());
    final cleared = data.dailyClearedDate == _today();
    final accent = level.targetTier!.color;
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openDaily,
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
                      const Text('每日挑战',
                          style: TextStyle(
                              color: AppColors.ink1,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        cleared
                            ? '今日已完成 · 连续挑战 ${data.dailyStreak} 天'
                            : data.dailyStreak >= 2
                                ? '连续挑战 ${data.dailyStreak} 天 · 完成领 +${DailyChallenge.reward + 50} 🪙'
                                : '完成今日挑战，领 +${DailyChallenge.reward} 🪙',
                        style: TextStyle(
                            color:
                                cleared ? const Color(0xFF66BB6A) : AppColors.ink2,
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
                    onPressed: _openDaily,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF101318),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('开玩',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDaily() async {
    final level = DailyChallenge.levelFor(DateTime.now());
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: level, data: data, repo: widget.repo),
      ),
    );
    if (result == true && mounted) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(data: data, repo: widget.repo),
        ),
      );
    }
  }

  /// 成排的半宽入口卡（成就 / 商店等）。
  Widget _buildMiniEntry({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceLight, AppColors.surfaceSoft],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink3.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppColors.ink1,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.ink2, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.ink3, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 首页主角卡：下一步挑战。给「开始」一个明确的仪式入口。
  Widget _buildHero() {
    final nextIndex = (data.unlockedLevel - 1).clamp(0, levels.length - 1);
    final level = levels[nextIndex];
    final accent = level.targetTier?.color ?? AppColors.accent;
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    final progress = completed / levels.length;
    final best = data.bestScores[level.id] ?? 0;
    final isFresh = completed == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, accent, 0.16)!,
            Color.lerp(Colors.white, accent, 0.08)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -22,
            child: _FloatingIcon(
              ambient: _ambient,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.30),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: level.targetTier != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: VehicleImage(vehicle: level.targetTier!, size: 42),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.grid_view,
                            size: 42, color: AppColors.ink2)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isFresh ? '启程时刻' : '继续挑战',
                      style: const TextStyle(
                          color: AppColors.ink1,
                          fontWeight: FontWeight.w800,
                          fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  if (best > 0)
                    Text('最佳 $best 分',
                        style: const TextStyle(
                            color: Color(0xFFFFCA28),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.ink1,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(level.goalText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.ink2, fontSize: 13)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('总进度',
                                style: TextStyle(
                                    color: AppColors.ink2, fontSize: 11)),
                            const Spacer(),
                            Text('$completed/${levels.length} 关',
                                style: const TextStyle(
                                    color: AppColors.ink2,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: AppColors.ink3.withValues(alpha: 0.12),
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  FilledButton.icon(
                    onPressed: () => _openLevel(level),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF101318),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text('开始游戏',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.coral, AppColors.coralDeep, AppColors.grape],
                  ).createShader(rect),
                  child: const Text('车水马龙',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink1,
                          height: 1.1)),
                ),
                const SizedBox(height: 2),
                const Text('Merge Fleet · 合成车队，解锁星辰宇宙',
                    style: TextStyle(
                        color: AppColors.ink3,
                        fontSize: 11,
                        letterSpacing: 1)),
              ],
            ),
          ),
          IconButton(
            onPressed: _showSettings,
            tooltip: '设置',
            icon: const Icon(Icons.settings, color: AppColors.ink2),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.ink3.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB39DDB), Color(0xFF7E57C2)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x557E57C2),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🚗', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Text('车库 ${data.collection.length}/17',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.coinGold1, AppColors.coinGold2],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF66B23E),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text('${data.coins}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: AppColors.coinText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInBanner() {
    final signedToday = data.lastSignInDate == _today();
    final nextDay = (data.signInDay % 7) + 1;
    final nextReward = _signInRewards[nextDay - 1];
    final progress = data.signInDay / 7;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, const Color(0xFFFFCA28), 0.16)!,
            Color.lerp(Colors.white, const Color(0xFFFFCA28), 0.08)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x55FFCA28)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0x33FFCA28),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_month, color: Color(0xFFFFCA28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连续签到 ${data.signInStreak} 天',
                  style: const TextStyle(
                      color: AppColors.ink1,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  signedToday ? '明天再来可领 +$nextReward 🪙' : '今日签到立得 +$nextReward 🪙',
                  style: const TextStyle(color: AppColors.ink2, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.ink3.withValues(alpha: 0.12),
                    color: const Color(0xFFFFCA28),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: signedToday ? null : _onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFCA28),
              disabledBackgroundColor: const Color(0x33333333),
              disabledForegroundColor: AppColors.ink3,
              foregroundColor: const Color(0xFF4E342E),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(signedToday ? '已签到' : '签到',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildEndlessBanner() {
    final best = data.endlessBest.isEmpty ? 0 : data.endlessBest.first;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
            gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(Colors.white, const Color(0xFFB39DDB), 0.16)!,
              Color.lerp(Colors.white, const Color(0xFFB39DDB), 0.08)!,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x55B39DDB)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openLevel(endlessLevel),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0x44B39DDB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Color(0xFFB39DDB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('无尽模式',
                          style: TextStyle(
                              color: AppColors.ink1,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        best > 0 ? '最佳纪录 $best 分' : '合成永不停歇，冲刺最高分',
                        style: TextStyle(
                            color: best > 0
                                ? const Color(0xFFFFCA28)
                                : AppColors.ink2,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openLevel(endlessLevel),
                  icon: const Icon(Icons.play_circle_fill,
                      color: Color(0xFFB39DDB), size: 34),
                ),
                IconButton(
                  onPressed: _showEndlessRank,
                  tooltip: '排行榜',
                  icon: const Icon(Icons.emoji_events,
                      color: Color(0xFFFFCA28), size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 入场仪式：从下方淡入上浮的区块。
class _Reveal extends StatelessWidget {
  final Animation<double> anim;
  final double start;
  final Widget child;

  const _Reveal({required this.anim, required this.start, required this.child});

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(
      parent: anim,
      curve: Interval(start, (start + 0.26).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(a),
        child: child,
      ),
    );
  }
}

/// 随环境节奏缓慢上下漂浮的目标车辆。
class _FloatingIcon extends StatelessWidget {
  final Animation<double> ambient;
  final Widget child;

  const _FloatingIcon({required this.ambient, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambient,
      builder: (context, _) {
        final dy = math.sin(ambient.value * math.pi * 4) * 6.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
    );
  }
}

/// 首页背景中缓慢漂移的彩色光晕，营造氛围仪式感。
class _AmbientPainter extends CustomPainter {
  final double t;

  _AmbientPainter(this.t);

  void _orb(Canvas canvas, Size size, double fx, double fy, double radius,
      Color color, double phase) {
    final dx = math.sin(phase) * 22.0;
    final dy = math.cos(phase * 0.8) * 16.0;
    final center = Offset(size.width * fx + dx, size.height * fy + dy);
    final paint = Paint()
      ..shader = ui.Gradient.radial(center, radius, [
        color.withValues(alpha: 0.10),
        color.withValues(alpha: 0.0),
      ]);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _orb(canvas, size, 0.16, 0.30, 190, AppColors.accent, t * 1.1);
    _orb(canvas, size, 0.86, 0.62, 230, const Color(0xFFFFCA28), t * 0.9 + 2.1);
    _orb(canvas, size, 0.62, 0.12, 160, const Color(0xFFB39DDB), t * 1.3 + 4.0);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t;
}

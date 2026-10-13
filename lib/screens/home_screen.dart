import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/audio_feedback.dart';
import '../game/daily_challenge.dart';
import '../game/game_config.dart';
import '../game/music_player.dart';
import '../analytics/analytics.dart';
import '../models/achievement.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../models/level.dart';
import '../save/save_repository.dart';
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

  // ===== 板块锚点（原首启引导已移除，键保留供布局复用） =====

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
                  AudioFeedback.uiTap();
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
                  // 振动总开关：切换时立即给一次确认触感（开着才振动时，
                  // 关掉前给最后一次，打开后从此有了）。
                  HapticFeedback.selectionClick();
                  AudioFeedback.globalVibrateOn = v;
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
                        // ===== L1 主行动：唯一的 Hero 大卡（继续挑战）=====
                        _Reveal(
                            anim: _enterAnim,
                            start: 0.08,
                            child: _buildHero()),
                        const SizedBox(height: 12),
                        // ===== L2 玩法入口：双列半宽，视觉重量减半 =====
                        _Reveal(
                          anim: _enterAnim,
                          start: 0.22,
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(child: _buildDailyCard()),
                                const SizedBox(width: 12),
                                Expanded(child: _buildEndlessCard()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Reveal(
                          anim: _enterAnim,
                          start: 0.34,
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(child: _buildParkingCard()),
                                const SizedBox(width: 12),
                                Expanded(child: _buildLevelListCard()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ===== L3 系统/工具：一行 4 个小方块 =====
                        _Reveal(
                          anim: _enterAnim,
                          start: 0.46,
                          child: Row(
                            children: [
                              Expanded(child: _buildSignInSquare()),
                              const SizedBox(width: 10),
                              Expanded(child: _buildAchievementsSquare()),
                              const SizedBox(width: 10),
                              Expanded(child: _buildCollectionSquare()),
                              const SizedBox(width: 10),
                              Expanded(child: _buildShopSquare()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 停车模式入口（半宽玩法卡）。
  Widget _buildParkingCard() {
    return _buildModeCard(
      icon: Icons.local_parking,
      accent: AppColors.accent,
      title: '停车模式',
      subtitle: '把车停到指定车位',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ParkingLevelSelectScreen(data: data, repo: widget.repo),
        ),
      ),
    );
  }

  /// 收纳入口：小方块展示进度；全图鉴达成未领奖时红点提醒，点击直接领。
  Widget _buildCollectionSquare() {
    final collected = data.collection.length;
    final total = VehicleType.values.length;
    final complete = collected >= total;
    final claimable = complete && !data.collectionRewardClaimed;
    return _buildSquareEntry(
      icon: Icons.auto_stories,
      color: AppColors.grape,
      title: '图鉴',
      subtitle: claimable ? '领大奖!' : '$collected/$total',
      dot: claimable,
      onTap: claimable
          ? _claimCollectionReward
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CollectionScreen(data: data, repo: widget.repo),
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

  /// 关卡选择入口（半宽玩法卡）。
  Widget _buildLevelListCard() {
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    return _buildModeCard(
      icon: Icons.grid_view_rounded,
      accent: const Color(0xFFFFB23E),
      title: '全部关卡',
      subtitle: '已完成 $completed/${levels.length} 关',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LevelSelectScreen(data: data, repo: widget.repo),
        ),
      ),
    );
  }

  /// 今日挑战卡（半宽玩法卡）：每天一个按日期生成的固定关卡。
  Widget _buildDailyCard() {
    final level = DailyChallenge.levelFor(DateTime.now());
    final cleared = data.dailyClearedDate == _today();
    final accent = level.targetTier!.color;
    final streak = data.dailyStreak;
    return _buildModeCard(
      icon: Icons.calendar_today,
      accent: accent,
      title: '每日挑战',
      subtitle: cleared
          ? '已完成 · 连签 $streak 天'
          : (streak >= 2 ? '连签 $streak 天 · +${DailyChallenge.reward + 50}🪙' : '完成领 +${DailyChallenge.reward} 🪙'),
      subColor: cleared ? const Color(0xFF66BB6A) : null,
      onTap: _openDaily,
      trailing: Icon(
        cleared ? Icons.check_circle : Icons.play_circle_fill,
        size: 24,
        color: cleared ? const Color(0xFF66BB6A) : accent,
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

  /// L2 玩法卡（半宽、纵向紧凑）：图标 + 标题 + 一句副标题 + 状态角标。
  /// 首页所有玩法入口共用，保证四张卡同构——同构才有"层级"，不抢戏。
  Widget _buildModeCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    Color? subColor,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.ink1,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: subColor ?? AppColors.ink2, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// L3 系统小方块（一行 4 个）：图标 + 短标题 + 一行小字，可带红点提醒。
  Widget _buildSquareEntry({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool dot = false,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink3.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    if (dot)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title,
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.ink1,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.ink3, fontSize: 9)),
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

  Widget _buildSignInSquare() {
    final signedToday = data.lastSignInDate == _today();
    final nextDay = (data.signInDay % 7) + 1;
    final nextReward = _signInRewards[nextDay - 1];
    return _buildSquareEntry(
      icon: Icons.calendar_month,
      color: const Color(0xFFFFCA28),
      title: '签到',
      subtitle: signedToday ? '连签 ${data.signInStreak} 天' : '+$nextReward 🪙',
      dot: !signedToday,
      onTap: signedToday ? null : _onSignIn,
    );
  }

  Widget _buildAchievementsSquare() {
    return _buildSquareEntry(
      icon: Icons.emoji_events,
      color: const Color(0xFFFFB23E),
      title: '成就',
      subtitle: '${data.claimedAchievements.length}/${achievements.length}',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AchievementsScreen(data: data, repo: widget.repo),
        ),
      ),
    );
  }

  Widget _buildShopSquare() {
    return _buildSquareEntry(
      icon: Icons.storefront,
      color: const Color(0xFF66BB6A),
      title: '商店',
      subtitle: '${data.coins} 🪙',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShopScreen(data: data, repo: widget.repo),
        ),
      ),
    );
  }

  Widget _buildEndlessCard() {
    final best = data.endlessBest.isEmpty ? 0 : data.endlessBest.first;
    return _buildModeCard(
      icon: Icons.auto_awesome,
      accent: const Color(0xFFB39DDB),
      title: '无尽模式',
      subtitle: best > 0 ? '最高 $best 分' : '合成不停歇，冲高分',
      subColor: best > 0 ? const Color(0xFFFFCA28) : null,
      onTap: () => _openLevel(endlessLevel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _showEndlessRank,
            child: const Icon(Icons.emoji_events,
                color: Color(0xFFFFCA28), size: 20),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.play_circle_fill,
              color: Color(0xFFB39DDB), size: 26),
        ],
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

  /// 固定光晕规格：(fx, fy, 半径, 颜色, 相位基准, 相位速度)。
  static const _orbSpecs = <(double, double, double, Color, double, double)>[
    (0.16, 0.30, 190, AppColors.accent, 0.0, 1.1),
    (0.86, 0.62, 230, Color(0xFFFFCA28), 2.1, 0.9),
    (0.62, 0.12, 160, Color(0xFFB39DDB), 4.0, 1.3),
  ];

  /// shader 只与固定规格有关，进程级缓存一份（以原点为圆心），
  /// 每次绘制用 canvas.translate 把圆心挪到光晕位置，避免每帧重建渐变 shader。
  static final List<Paint> _orbPaints = [
    for (final s in _orbSpecs)
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, s.$3, [
          s.$4.withValues(alpha: 0.10),
          s.$4.withValues(alpha: 0.0),
        ]),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _orbSpecs.length; i++) {
      final s = _orbSpecs[i];
      final phase = s.$5 + t * s.$6;
      final dx = math.sin(phase) * 22.0;
      final dy = math.cos(phase * 0.8) * 16.0;
      canvas.save();
      canvas.translate(size.width * s.$1 + dx, size.height * s.$2 + dy);
      canvas.drawCircle(Offset.zero, s.$3, _orbPaints[i]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t;
}

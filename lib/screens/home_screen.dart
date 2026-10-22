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
import '../services/ads/ad_diagnostics.dart';
import '../services/ads/ad_service.dart';
import '../services/level_data_generator.dart';
import '../widgets/candy_ui.dart';
import '../widgets/vehicle_image.dart';
import 'achievements_screen.dart';
import 'collection_screen.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'parking_level_select.dart';
import 'shop_screen.dart';

/// 首页：整局游戏的"门厅"。
///
/// 信息层级（从重到轻）：
/// 1. Hero 主行动卡——今天要玩什么，一眼一个按钮；
/// 2. 玩法双列（每日 / 无尽 / 停车 / 关卡）——四张同构卡；
/// 3. 系统小方块一行（签到 / 成就 / 图鉴 / 商店）。
///
/// 刻意做的减压设计：整页一屏不滚、一次只给一个"主要建议"、失败/未完成态
/// 全部用柔和灰而非警告色，红点只在真的能领奖时出现。
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
  /// 速率见 GameConfig.offlineCoinsPerHour，上限 8 小时。首次进入（无时间戳）不发放。
  void _checkOfflineReward() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = data.lastSeenAt;
    data.lastSeenAt = now;
    widget.repo.save(data);
    if (last == null) return;
    final offlineMs = now - last;
    if (offlineMs < 30 * 60 * 1000) return;
    final hours = (offlineMs / 3600000).clamp(0, 8).toDouble();
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
      CandyDialog.show(
        context,
        emoji: '👋',
        color: AppColors.sun,
        title: '欢迎回来！',
        message: '离线 $hoursText，车队帮你攒了 +$reward 🪙。慢慢玩，不着急。',
        confirmLabel: '收下啦',
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
    AudioFeedback.uiTap();
    final today = _today();
    if (data.lastSignInDate == today) {
      CandyDialog.show(
        context,
        icon: Icons.check_circle_rounded,
        color: AppColors.mint,
        title: '今天已经签过啦',
        message: '已连续签到 ${data.signInStreak} 天，坚持到第 7 天领大奖！',
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
    CandyDialog.show(
      context,
      emoji: day == 7 ? '🎁' : '📅',
      color: AppColors.lemon,
      title: day == 7 ? '签到大奖！+$reward 🪙' : '签到成功！+$reward 🪙',
      message: day == 7
          ? '已连续签到 $streak 天，集满 7 日循环，豪礼到手！明天开启新一轮循环。'
          : '已连续签到 $streak 天，累计 $reward 金币入账。坚持签到，第 7 天有大奖 🎁',
    );
  }

  void _showSettings() {
    AudioFeedback.uiTap();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceLight,
                  Color.lerp(AppColors.grape, Colors.white, 0.94)!,
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.grape.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.grape.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('设置',
                        style: const TextStyle(
                            color: AppColors.ink1,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.ink3, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: data.soundOn,
                  title: const Text('音效与音乐',
                      style: TextStyle(color: AppColors.ink1)),
                  activeThumbColor: AppColors.coral,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onChanged: (v) {
                    // 开关本身吃掉一次点击反馈：这里不再叠加音效。
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
                  activeThumbColor: AppColors.coral,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
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
                const SizedBox(height: 4),
                // 隐私设置入口：UMP 的 PrivacyOptionsRequirementStatus.required
                // 时这里是**必须存在**的（欧盟用户要能随时撤回广告同意）。
                // 放在设置里而不是首页第 5 个方块：不占首屏权重，但永远可达。
                InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openAdPrivacy();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.privacy_tip_rounded,
                            size: 19, color: AppColors.grape),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('隐私设置与广告偏好',
                                  style: TextStyle(
                                      color: AppColors.ink1,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('随时修改或撤回广告同意',
                                  style: TextStyle(
                                      color: AppColors.ink3, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.ink3, size: 20),
                      ],
                    ),
                  ),
                ),
                if (AdDiagnostics.enabled) ...[
                  const SizedBox(height: 10),
                  _buildAdDiagBlock(data),
                ],
                const SizedBox(height: 8),
                CandyButton(
                  label: '完成',
                  colors: AppTheme.gradientOf(AppColors.grape),
                  expand: true,
                  size: CandyButtonSize.medium,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 广告自检块（debug / profile 默认显示，release 隐藏）。
  ///
  /// 唯一用途是回答「现在这条广告到底是不是真的」：真机上打开设置就能确认，
  /// 不用连调试器、也不用猜日志。三种状态用一句话说清（见 [AdDiagnostics]）。
  Widget _buildAdDiagBlock(PlayerData data) {
    final rows = AdService.diagnose(data);
    final warn = rows.any((r) => r.level == AdDiagLevel.warn);
    final tone = warn ? AppColors.coral : AppColors.mint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_rounded, size: 13, color: tone),
              const SizedBox(width: 5),
              Text(
                '广告自检（开发版可见）',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.25,
                        fontWeight: row.level == AdDiagLevel.warn
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: row.level == AdDiagLevel.warn
                            ? tone
                            : AppColors.ink2,
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

  /// 打开隐私设置（UMP）：撤回/修改广告同意。
  ///
  /// 三种结果都要说清，别让玩家以为按钮坏了：
  /// 1. 地区不要求 → 告知「当前地区无需设置」（不弹空表单）；
  /// 2. 弹出成功 → 静默（表单本身就是反馈）；
  /// 3. 打不开 → 演示环境说明 / 网络重试提示。
  Future<void> _openAdPrivacy() async {
    final required = await AdService.privacyOptionsRequired();
    if (!mounted) return;
    if (!required) {
      CandyDialog.show(
        context,
        icon: Icons.privacy_tip_rounded,
        color: AppColors.sky,
        title: '当前地区无需设置',
        message: AdService.usingMock
            ? '演示环境没有真实广告 SDK，因此这里不会弹表单。上线后该地区要求同意管理时会自动出现。'
            : '你所在地区不要求广告同意管理，我们目前只请求非个性化广告。',
        confirmLabel: '知道了',
      );
      return;
    }
    final shown = await AdService.showPrivacyOptions();
    if (!mounted || shown) return;
    CandyDialog.show(
      context,
      icon: Icons.info_outline,
      color: AppColors.ink3,
      title: '隐私设置暂时打不开',
      message: AdService.usingMock
          ? '演示环境：真实 SDK 下这里会打开系统的同意管理表单。'
          : '请检查网络后重试。广告同意状态没有变化，你的现有设置仍然有效。',
      confirmLabel: '知道了',
    );
  }

  void _openLevel(LevelDefinition level) async {
    AudioFeedback.uiTap();
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
    AudioFeedback.uiTap();
    final list = data.endlessBest;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surfaceLight,
                Color.lerp(AppColors.taro, Colors.white, 0.93)!,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.taro.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: AppColors.taro.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.sun, size: 26),
                  const SizedBox(width: 8),
                  const Text('无尽排行榜',
                      style: TextStyle(
                          color: AppColors.ink1,
                          fontSize: 19,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('还没有纪录，去无尽模式随便玩两把试试～',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.ink2)),
                )
              else
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            gradient: AppTheme.gradientFor(
                              i == 0
                                  ? AppColors.sun
                                  : (i == 1
                                      ? AppColors.blossom
                                      : AppColors.taro),
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CandyProgress(
                            value: list[i] / (list.first == 0 ? 1 : list.first),
                            color: i == 0 ? AppColors.sun : AppColors.taro,
                            height: 8,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${list[i]} 分',
                            style: const TextStyle(
                                color: AppColors.ink1,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
              CandyButton(
                label: '好',
                colors: AppTheme.gradientOf(AppColors.taro),
                expand: true,
                size: CandyButtonSize.medium,
                onTap: () => Navigator.of(context).pop(),
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
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradientLight),
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
                            anim: _enterAnim, start: 0.08, child: _buildHero()),
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
                        const SizedBox(height: 14),
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
      icon: Icons.local_parking_rounded,
      accent: AppColors.mint,
      title: '停车模式',
      subtitle: '把车轻轻挪进车位',
      onTap: () {
        AudioFeedback.uiTap();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ParkingLevelSelectScreen(data: data, repo: widget.repo),
          ),
        );
      },
    );
  }

  /// 收纳入口：小方块展示进度；全图鉴达成未领奖时红点提醒，点击直接领。
  Widget _buildCollectionSquare() {
    final collected = data.collection.length;
    final total = VehicleType.values.length;
    final complete = collected >= total;
    final claimable = complete && !data.collectionRewardClaimed;
    return _buildSquareEntry(
      icon: Icons.auto_stories_rounded,
      color: AppColors.grape,
      title: '图鉴',
      subtitle: claimable ? '领大奖!' : '$collected/$total',
      dot: claimable,
      onTap: claimable
          ? _claimCollectionReward
          : () {
              AudioFeedback.uiTap();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionScreen(data: data, repo: widget.repo),
                ),
              );
            },
    );
  }

  void _claimCollectionReward() {
    if (data.collectionRewardClaimed) return;
    AudioFeedback.uiTap();
    data.collectionRewardClaimed = true;
    data.addCoins(GameConfig.collectionGrandReward);
    widget.repo.save(data);
    setState(() {});
    CandyDialog.show(
      context,
      emoji: '🎉',
      color: AppColors.lemon,
      title: '全图鉴大奖 +${GameConfig.collectionGrandReward} 🪙',
      message: '集齐全部 ${VehicleType.values.length} 款车辆，收藏家之名当之无愧！',
    );
  }

  /// 关卡选择入口（半宽玩法卡）。
  Widget _buildLevelListCard() {
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    return _buildModeCard(
      icon: Icons.grid_view_rounded,
      accent: AppColors.lemon,
      title: '全部关卡',
      subtitle: '已完成 $completed/${levels.length} 关',
      onTap: () {
        AudioFeedback.uiTap();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LevelSelectScreen(data: data, repo: widget.repo),
          ),
        );
      },
    );
  }

  /// 今日挑战卡（半宽玩法卡）：每天一个按日期生成的固定关卡。
  Widget _buildDailyCard() {
    final level = DailyChallenge.levelFor(DateTime.now());
    final cleared = data.dailyClearedDate == _today();
    final accent = level.targetTier!.color;
    final streak = data.dailyStreak;
    return _buildModeCard(
      icon: Icons.today_rounded,
      accent: cleared ? AppColors.mint : accent,
      title: '每日挑战',
      subtitle: cleared
          ? '今天已完成 · 连签 $streak 天'
          : (streak >= 2
              ? '连签 $streak 天 · +${DailyChallenge.reward + 50}🪙'
              : '完成领 +${DailyChallenge.reward} 🪙'),
      onTap: _openDaily,
      trailing: Icon(
        cleared ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
        size: 24,
        color: cleared ? AppColors.mint : accent,
      ),
    );
  }

  Future<void> _openDaily() async {
    AudioFeedback.uiTap();
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
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return CandyCard(
      accent: accent,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.gradientFor(accent),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.30),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.ink1,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppColors.ink2, fontSize: 11)),
        ],
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
    return CandyCard(
      accent: color,
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      onTap: onTap,
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
                  gradient: AppTheme.gradientFor(color),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.34),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              if (dot)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
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
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.ink3, fontSize: 9.5)),
        ],
      ),
    );
  }

  /// 首页主角卡：下一步挑战。给「开始」一个明确的仪式入口。
  ///
  /// 装饰全部约束在 ClipRRect 内（绝不溢出卡外），避免上一次迭代里
  /// 「右上角光晕被列表裁掉」的观感问题。
  Widget _buildHero() {
    final nextIndex = (data.unlockedLevel - 1).clamp(0, levels.length - 1);
    final level = levels[nextIndex];
    final accent = level.targetTier?.color ?? AppColors.coral;
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    final progress = completed / levels.length;
    final best = data.bestScores[level.id] ?? 0;
    final isFresh = completed == 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color.lerp(accent, Colors.white, 0.80)!,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.40), width: 2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.26),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 右上角柔和光环 + 车模（完全在卡内，不溢出）。
            Positioned(
              right: -18,
              top: -26,
              child: _FloatingIcon(
                ambient: _ambient,
                child: Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.34),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: level.targetTier != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 26, 18, 0),
                            child: VehicleImage(
                                vehicle: level.targetTier!, size: 62),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SoftChip(
                        label: isFresh ? '启程时刻' : '继续挑战',
                        color: accent,
                        solid: true,
                      ),
                      const Spacer(),
                      if (best > 0)
                        SoftChip(
                          label: '最佳 $best 分',
                          color: AppColors.sun,
                          icon: Icons.star_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.ink1,
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(level.goalText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.ink2, fontSize: 13, height: 1.4)),
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
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            CandyProgress(value: progress, color: accent, height: 7),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      CandyButton(
                        label: '开始游戏',
                        icon: Icons.play_arrow_rounded,
                        colors: AppTheme.gradientOf(accent),
                        size: CandyButtonSize.medium,
                        dense: true,
                        onTap: () => _openLevel(level),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [
                          AppColors.coral,
                          AppColors.blossom,
                          AppColors.grape,
                        ],
                      ).createShader(rect),
                      child: const Text('车水马龙',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              height: 1.1)),
                    ),
                    const SizedBox(height: 1),
                    const Text('随手玩两把，慢慢攒车队',
                        style: TextStyle(
                            color: AppColors.ink3,
                            fontSize: 11.5,
                            letterSpacing: 0.6)),
                    const SizedBox(height: 3),
                    // 成长标尺行：跨关卡的技巧纪录 + Boss 徽章墙进度。
                    // 有值才显示对应段——0 纪录的玩家只看到 Boss 目标，
                    // 不会被空白的"x0"提醒自己不行。
                    Text(
                      [
                        if (data.bestCombo >= 2)
                          '🔥 最高连消 x${data.bestCombo}',
                        '👑 Boss ${data.defeatedBosses.length}'
                            '/${LevelDataGenerator.bossTotal}',
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.ink2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.settings_rounded,
                color: AppColors.grape,
                onTap: _showSettings,
              ),
              const SizedBox(width: 8),
              CoinPill(amount: data.coins),
            ],
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
      icon: signedToday ? Icons.task_alt_rounded : Icons.calendar_month_rounded,
      color: AppColors.lemon,
      title: '签到',
      subtitle: signedToday ? '连签 ${data.signInStreak} 天' : '+$nextReward 🪙',
      dot: !signedToday,
      onTap: signedToday ? null : _onSignIn,
    );
  }

  Widget _buildAchievementsSquare() {
    // 只统计当前表里还存在的成就：成就改版后被删掉的旧 id 仍留在
    // claimedAchievements 里，直接用 length 会算出 13/70 这种假进度。
    final claimed = achievements
        .where((a) => data.claimedAchievements.contains(a.id))
        .length;
    final claimable = achievements.any((a) =>
        !data.claimedAchievements.contains(a.id) && a.achieved(data));
    return _buildSquareEntry(
      icon: Icons.emoji_events_rounded,
      color: AppColors.sun,
      title: '成就',
      subtitle: claimable
          ? '可领取!'
          : '$claimed/${achievements.length}',
      dot: claimable,
      onTap: () {
        AudioFeedback.uiTap();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AchievementsScreen(data: data, repo: widget.repo),
          ),
        );
      },
    );
  }

  Widget _buildShopSquare() {
    return _buildSquareEntry(
      icon: Icons.storefront_rounded,
      color: AppColors.mint,
      title: '商店',
      subtitle: '${data.coins} 🪙',
      onTap: () {
        AudioFeedback.uiTap();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShopScreen(data: data, repo: widget.repo),
          ),
        );
      },
    );
  }

  Widget _buildEndlessCard() {
    final best = data.endlessBest.isEmpty ? 0 : data.endlessBest.first;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildModeCard(
          icon: Icons.auto_awesome_rounded,
          accent: AppColors.taro,
          title: '无尽模式',
          subtitle: best > 0 ? '最高 $best 分' : '合成不停歇',
          onTap: () => _openLevel(endlessLevel),
          trailing: GestureDetector(
            onTap: _showEndlessRank,
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColors.sun, size: 22),
          ),
        ),
      ],
    );
  }
}

/// 入场仪式：从下方淡入上浮的区块。
class _Reveal extends StatelessWidget {
  const _Reveal(
      {required this.anim, required this.start, required this.child});

  final Animation<double> anim;
  final double start;
  final Widget child;

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
        position:
            Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}

/// 随环境节奏缓慢上下漂浮的目标车辆。
class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.ambient, required this.child});

  final Animation<double> ambient;
  final Widget child;

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
    (0.16, 0.30, 190, AppColors.coral, 0.0, 1.1),
    (0.86, 0.62, 230, AppColors.lemon, 2.1, 0.9),
    (0.62, 0.12, 160, AppColors.grape, 4.0, 1.3),
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

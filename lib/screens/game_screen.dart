import 'dart:async';

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/analytics.dart';
import '../game/audio_feedback.dart';
import '../game/daily_challenge.dart';
import '../game/game_config.dart';
import '../game/music_player.dart';
import '../game/merge_game.dart';
import '../theme/app_theme.dart';
import '../models/level.dart';
import '../models/vehicle.dart';
import '../save/save_repository.dart';
import '../services/level_progression.dart';
import '../widgets/candy_ui.dart';
import '../widgets/pressable.dart';
import '../widgets/vehicle_image.dart';

class GameScreen extends StatefulWidget {
  final LevelDefinition level;
  final PlayerData data;
  final SaveRepository repo;

  const GameScreen({
    super.key,
    required this.level,
    required this.data,
    required this.repo,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final MergeGame _game;
  late final AnalyticsService _analytics;
  bool _finished = false;
  bool _hammering = false;

  // 板块锚点（供滚动定位等复用；原教学高亮已移除）
  final GlobalKey _stockBarKey = GlobalKey();
  final GlobalKey _toolsKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _hammerToolKey = GlobalKey();
  final GlobalKey _undoToolKey = GlobalKey();
  final GlobalKey _addCardsToolKey = GlobalKey();

  /// 双倍卡生效中：本关通关金币 ×2。
  bool _doubleCoin = false;

  static final int _hammerCost = GameConfig.hammerCost;
  static final int _undoCost = GameConfig.undoCost;
  static final int _addCardsCost = GameConfig.addCardsCost;
  static final int _shuffleCost = GameConfig.shuffleCost;
  static final int _hintCost = GameConfig.hintCost;

  @override
  void initState() {
    super.initState();
    _game = MergeGame(widget.level);
    _game.onGameOver = _onGameOver;
    _game.onTierProduced = (tier) {
      if (widget.data.collection.add(tier.index)) {
        widget.data.addCoins(GameConfig.collectionNewReward);
        _game.hint.value = '📖 图鉴点亮 ${tier.icon} ${tier.name} +5🪙';
        widget.repo.save(widget.data);
        _analytics.collectionNew(tier.index);
      }
    };
    _game.onEndlessMilestone = (endlessLevel, reward) {
      widget.data.addCoins(reward);
      _game.hint.value = '🏆 里程碑达成！无尽第 $endlessLevel 档 +$reward 🪙';
      widget.repo.save(widget.data);
    };
    _game.feedback.soundOn = widget.data.soundOn;
    _game.feedback.vibrateOn = widget.data.vibrateOn;
    // 同步全局振动开关，供 Pressable 等 UI 层触感入口使用。
    AudioFeedback.globalVibrateOn = widget.data.vibrateOn;
    _analytics = AnalyticsService(widget.data, widget.repo);
    _analytics.levelStart(widget.level);
    _applyBoosters();
    // 清道夫关开局教学：胜利条件与"顶级车升空"机制一句话讲清。
    if (widget.level.goalType == GoalType.clearBoard) {
      _game.hint.value =
          '🎯 把牌堆用完，场上剩 ≤${widget.level.clearLimit ?? 0} 组就赢！'
          '同级车拖一起合成，最高档三合一会升空消失';
    }

    // 合成场景 BGM（跟随音效开关；返回首页由 home 的 didPopNext 恢复）。
    if (widget.data.soundOn) {
      MusicPlayer.instance.play(MusicPlayer.merge);
    }
  }

  /// 开局道具：加时 / 补卡 / 双倍，各消耗 1 个。
  void _applyBoosters() {
    final b = widget.data.boosters;
    var used = false;
    if ((b['time'] ?? 0) > 0) {
      b['time'] = b['time']! - 1;
      if (widget.level.timeLimitSeconds != null) {
        _game.addTime(30);
        _game.hint.value = '🕐 加时卡生效：+30 秒';
      } else {
        widget.data.addCoins(30);
        _game.hint.value = '🕐 加时卡（非限时关）转为 +30 🪙';
      }
      used = true;
    }
    if ((b['cards'] ?? 0) > 0) {
      b['cards'] = b['cards']! - 1;
      _game.addCards(3);
      _game.hint.value = '📦 补卡卡生效：牌堆 +3';
      used = true;
    }
    if ((b['double'] ?? 0) > 0) {
      b['double'] = b['double']! - 1;
      _doubleCoin = true;
      _game.hint.value = '🎲 双倍卡生效：通关金币 ×2';
      used = true;
    }
    if (used) widget.repo.save(widget.data);
  }

  @override
  void dispose() {
    // 中途退出（返回/暂停回主页/重开）未经过 _onGameOver：补记一次失败结算，
    // 保证 level_start 与 level_end 一一对应，胜率统计不失真。
    if (!_finished) {
      _analytics.levelEnd(
        level: widget.level,
        won: false,
        score: _game.score.value,
        stars: 0,
        maxCombo: _game.maxCombo,
        elapsedSeconds: _game.elapsedTime,
        coins: widget.data.coins,
      );
    }
    _game.score.dispose();
    _game.produced.dispose();
    _game.stockLeft.dispose();
    _game.cellPx.dispose();
    _game.hint.dispose();
    _game.combo.dispose();
    _game.timeLeft.dispose();
    _game.movesLeft.dispose();
    super.dispose();
  }

  void _onGameOver(bool won) {
    if (_finished) return;
    _finished = true;

    final isEndless = widget.level.endless;
    final score = _game.score.value;
    final stars = isEndless ? 0 : _calcStars(won);
    final consolation = GameConfig.mergeFailConsolation;
    var reward = won ? _starReward(score, stars) : consolation;
    if (_doubleCoin && won) reward *= 2;
    // 每日挑战：当天首次通关领固定大奖（不影响关卡解锁与星级）。
    var dailyBonus = 0;
    if (widget.level.daily && won) {
      final today = _dateString();
      if (widget.data.dailyClearedDate != today) {
        widget.data.dailyClearedDate = today;
        // #83 每日连胜：昨天也通关过 → +1，否则重置 1；连 3 天起 +50 奖励。
        final yesterday = _dateString(
            DateTime.now().subtract(const Duration(days: 1)));
        final streak = widget.data.dailyLastDate == yesterday
            ? widget.data.dailyStreak + 1
            : 1;
        widget.data.dailyStreak = streak;
        widget.data.dailyLastDate = today;
        dailyBonus = DailyChallenge.reward + (streak >= 3 ? 50 : 0);
      }
    }
    reward += dailyBonus;
    if (dailyBonus > 0) _analytics.dailyClear(dailyBonus);
    widget.data.addCoins(reward);
    if (!isEndless && won && !widget.level.daily) {
      if (widget.level.id >= widget.data.unlockedLevel) {
        widget.data.unlockedLevel = widget.level.id + 1;
      }
      final best = widget.data.bestScores[widget.level.id] ?? 0;
      if (score > best) widget.data.bestScores[widget.level.id] = score;
      final prevStars = widget.data.bestStars[widget.level.id] ?? 0;
      if (stars > prevStars) widget.data.bestStars[widget.level.id] = stars;
    }
    int? endlessRank;
    if (isEndless) {
      endlessRank = _submitEndlessScore(score);
    }
    _analytics.levelEnd(
      level: widget.level,
      won: won,
      score: score,
      stars: stars,
      maxCombo: _game.maxCombo,
      elapsedSeconds: _game.elapsedTime,
      coins: widget.data.coins,
    );
    widget.repo.save(widget.data);

    final message = won ? '达成目标：${widget.level.goalText}' : _goalRemainText();
    final title = isEndless
        ? (won ? '🌌 无尽纪录！' : '💥 棋盘满啦')
        : won
            ? (widget.level.goalType == GoalType.clearBoard
                ? '🎉 清空成功！'
                : '🚀 通关成功！')
            // 广告挑战关的失败标题说破身份：这是设计好的难关，
            // 看广告续命是官方后路，不是玩家不行。
            : (LevelProgression.isMergeAdGate(widget.level.id)
                ? '🎬 挑战关 · 差一点'
                : '⏰ 差一点');

    if (!mounted) return;
    // 失败且有续命次数时，按失败原因给出对应"看广告续命"按钮。
    // 注：失败 levelEnd 已记录，续命后最终结局会再记一次（同一局两条 end，
    // 以最后一条为准）；量级小先接受，接 SDK 后可加 runId 关联去重。
    final reviveLabel = !won && _game.revivesLeft > 0
        ? switch (_game.failReason) {
            MergeFailReason.timeOut => '🎬 看广告续命 · +30 秒',
            MergeFailReason.movesOut => '🎬 看广告续命 · +10 步',
            MergeFailReason.deadEnd => '🎬 看广告续命 · 牌堆+2 并重排',
            MergeFailReason.endlessStuck => '🎬 看广告续命 · 清 3 组腾位',
            null => null,
          }
        : null;

    // 胜利结算支持"看广告金币×2"：翻倍后弹窗重建（金额更新、按钮消失）。
    void showResultDialog(int shownReward, bool canDouble) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResultDialog(
          won: won,
          score: score,
          message: message,
          title: title,
          stars: stars,
          maxCombo: _game.maxCombo,
          elapsedText: _elapsedText(),
          endlessLevel: widget.level.endless ? _game.endlessLevel : 0,
          rank: endlessRank,
          reward: shownReward,
          consolation: won ? 0 : consolation,
          reviveLabel: reviveLabel,
          onRevive: reviveLabel == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  _analytics.toolUse('ad_revive', 0, widget.data.coins);
                  setState(() => _finished = false);
                  _game.revive();
                },
          onDoubleReward: canDouble && won
              ? () {
                  widget.data.addCoins(shownReward);
                  widget.repo.save(widget.data);
                  _analytics.toolUse('ad_double', 0, widget.data.coins);
                  Navigator.of(context).pop();
                  showResultDialog(shownReward * 2, false);
                }
              : null,
          onReplay: _restart,
          // 通关且还有下一关时，主按钮直接进下一关（无尽/每日仍为再来一局）。
          onNext: won && !isEndless && !widget.level.daily && widget.level.id + 1 < levels.length
              ? () {
                  Navigator.of(context).pop();
                  // levels 按 id 升序（id 从 1 开始），下一关即 levels[id]。
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        level: levels[widget.level.id],
                        data: widget.data,
                        repo: widget.repo,
                      ),
                    ),
                  );
                }
              : null,
          onHome: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop(true);
          },
          // 分享战绩：复制文案到剪贴板（零依赖，跨平台；接 SDK 后可换系统分享）。
          onShare: () {
            final text = isEndless
                ? '我在《车水马龙》无尽模式冲到 $score 分！来挑战我 🚀'
                : won
                    ? '我在《车水马龙》第 ${widget.level.id} 关拿到 $stars 星！'
                        '合成车队解锁星辰宇宙，来挑战我 🚗✨'
                    : '我在《车水马龙》挑战第 ${widget.level.id} 关，'
                        '你也来试试合成车队 🚗';
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('✅ 分享文案已复制，去粘贴给好友吧！'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          },
        ),
      );
    }

    showResultDialog(reward, won);
  }

  String _dateString([DateTime? date]) {
    final n = date ?? DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  void _restart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          level: widget.level,
          data: widget.data,
          repo: widget.repo,
        ),
      ),
    );
  }

  /// 暂停：停表并弹菜单。关闭/继续后恢复引擎。
  Future<void> _showPause() async {
    _game.pauseEngine();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surfaceLight,
                Color.lerp(AppColors.grape, Colors.white, 0.93)!,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.grape.withValues(alpha: 0.30)),
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
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppTheme.gradientFor(AppColors.grape),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('暂停中',
                      style: TextStyle(
                          color: AppColors.ink1,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Text(
                  widget.level.endless
                      ? '休息一下，随时回来接着合'
                      : '不着急，慢慢想下一步',
                  style: const TextStyle(
                      color: AppColors.ink2, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 16),
              CandyButton(
                label: '继续游戏',
                icon: Icons.play_arrow_rounded,
                colors: AppTheme.gradientOf(AppColors.grape),
                expand: true,
                onTap: () => Navigator.of(ctx).pop('resume'),
              ),
              const SizedBox(height: 9),
              CandyButton(
                label: '重新开始',
                icon: Icons.refresh_rounded,
                colors: AppTheme.softGradient,
                expand: true,
                onTap: () => Navigator.of(ctx).pop('restart'),
              ),
              const SizedBox(height: 9),
              CandyButton(
                label: '返回主页',
                icon: Icons.home_rounded,
                colors: AppTheme.softGradient,
                expand: true,
                onTap: () => Navigator.of(ctx).pop('home'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'restart':
        _restart();
      case 'home':
        Navigator.of(context).pop(true);
      default:
        _game.resumeEngine();
    }
  }

  /// 通关星级：限时关看剩余时间比例，普通关看最大连消。
  int _calcStars(bool won) {
    if (!won) return 0;
    final limit = widget.level.timeLimitSeconds;
    if (limit != null && limit > 0) {
      final ratio = _game.timeLeft.value / limit;
      if (ratio >= 0.5) return 3;
      if (ratio >= 0.25) return 2;
      return 1;
    }
    final mc = _game.maxCombo;
    if (mc >= 4) return 3;
    if (mc >= 2) return 2;
    return 1;
  }

  int _starReward(int score, int stars) {
    final base = score ~/ 10;
    switch (stars) {
      case 3:
        return (base * 2).round();
      case 2:
        return (base * 1.5).round();
      default:
        return base;
    }
  }

  /// 无尽分数入榜，返回名次（未进前 10 返回 null）。
  int? _submitEndlessScore(int score) {
    final list = widget.data.endlessBest;
    list.add(score);
    list.sort((a, b) => b.compareTo(a));
    if (list.length > 10) list.removeRange(10, list.length);
    final rank = list.indexOf(score);
    return rank >= 0 ? rank + 1 : null;
  }

  String _elapsedText() {
    final secs = _game.elapsedTime.round();
    final m = secs ~/ 60;
    final s = secs % 60;
    return m > 0 ? '${m}m${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  String _goalRemainText() {
    final level = widget.level;
    if (level.endless) {
      return '合成到第 ${_game.endlessLevel} 档目标，下次冲更高！';
    }
    if (level.timeLimitSeconds != null && _game.timeLeft.value <= 0) {
      return '时间到，差一点就成功了';
    }
    if (level.goalType == GoalType.clearBoard) {
      final left = _game.produced.value;
      final limit = level.clearLimit ?? 0;
      return left > limit
          ? '场上还剩 $left 组车（目标 ≤$limit 组）'
          : '再动一动棋子就清空啦';
    }
    final produced = _game.produced.value;
    final remain = (level.targetCount - produced).clamp(0, 999);
    return '还差 $remain 辆 ${level.targetTier!.icon} ${level.targetTier!.name}';
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.bg1,
        body: GlowBackground(
          child: Stack(
            children: [
              SafeArea(
                child: isLandscape
                    ? _buildLandscapeLayout()
                    : _buildPortraitLayout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 系统返回/手势：对局中先确认，防误退丢进度。
  Future<void> _handleBack() async {
    if (_finished) {
      Navigator.of(context).pop();
      return;
    }
    _game.pauseEngine();
    final quit = await CandyDialog.show<bool>(
      context,
      emoji: '🚪',
      color: AppColors.grape,
      title: '退出本关？',
      message: '当前这局的进度会丢掉哦，确定要走吗？',
      confirmLabel: '继续玩',
      confirmValue: false,
      cancelLabel: '退出',
      cancelValue: true,
    );
    if (!mounted) return;
    if (quit == true) {
      Navigator.of(context).pop();
    } else {
      _game.resumeEngine();
    }
  }

  /// 竖屏：HUD 在上、牌堆和道具在下的上下布局。
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHud(),
        _buildGoalBar(),
        Expanded(
          child: KeyedSubtree(key: _boardKey, child: GameWidget(game: _game)),
        ),
        _buildStockBar(),
        _buildTools(),
      ],
    );
  }

  /// 横屏/超宽屏：棋盘独占左侧撑满高度，右侧窄栏放 HUD、牌堆与道具。
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          child: KeyedSubtree(key: _boardKey, child: GameWidget(game: _game)),
        ),
        Container(
          width: 156,
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLdHud(),
                      const SizedBox(height: 6),
                      _buildLdStock(),
                      const Spacer(),
                      _buildLdTools(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLdHud() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _smallIconButton(
              icon: Icons.arrow_back,
              tooltip: '返回',
              onPressed: _finished
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            _smallIconButton(
              icon: Icons.pause_circle_outline,
              tooltip: '暂停',
              onPressed: _finished ? null : _showPause,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<int>(
          valueListenable: _game.score,
          builder: (_, v, _) => _chip(
            gradient: const [AppColors.coinGold1, AppColors.coinGold2],
            shadow: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 13, height: 1)),
                const SizedBox(width: 3),
                Text('$v',
                    style: const TextStyle(
                        color: AppColors.coinText,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _game.combo,
          builder: (_, c, _) => c >= 2
              ? _chip(
                  gradient: const [Color(0xFFFF7043), Color(0xFFE53935)],
                  shadow: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text('x$c',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13)),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        _buildLdGoalChip(),
        const SizedBox(height: 4),
        _buildGoalBar(compact: true),
        if (widget.level.timeLimitSeconds != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildLdTimerChip(),
          ),
      ],
    );
  }

  Widget _buildLdGoalChip() {
    return ValueListenableBuilder<int>(
      valueListenable: _game.produced,
      builder: (_, v, _) {
        final endless = widget.level.endless;
        final isClear = widget.level.goalType == GoalType.clearBoard;
        final accent = endless
            ? _game.endlessTarget.color
            : widget.level.targetTier?.color ?? AppColors.accent;
        final Widget child;
        if (endless) {
          child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: VehicleImage(vehicle: _game.endlessTarget, size: 16)),
              const SizedBox(width: 4),
              Text('$v / ${_game.endlessNeed}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ],
          );
        } else if (isClear) {
          // 清道夫关两阶段目标：打牌阶段看牌堆进度，收尾阶段才看残堆。
          child = ValueListenableBuilder<int>(
            valueListenable: _game.stockLeft,
            builder: (_, left, _) => Text(
              left > 0
                  ? '🂠 打完牌堆 · 剩 $left 张'
                  : (v <= (widget.level.clearLimit ?? 0)
                      ? '✅ 达标！场上 $v 组'
                      : '场上 $v 组 / 目标 ≤${widget.level.clearLimit ?? 0}'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12),
            ),
          );
        } else {
          child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: VehicleImage(vehicle: widget.level.targetTier!, size: 16)),
              const SizedBox(width: 4),
              Text('$v / ${widget.level.targetCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ],
          );
        }
        return _chip(
          gradient: [
            Color.lerp(accent, Colors.white, 0.15)!,
            Color.lerp(accent, Colors.black, 0.15)!,
          ],
          child: child,
        );
      },
    );
  }

  Widget _buildLdTimerChip() {
    return ValueListenableBuilder<int>(
      valueListenable: _game.timeLeft,
      builder: (_, t, _) {
        final urgent = t <= 10;
        return _chip(
          gradient: urgent
              ? const [Color(0xFFE53935), Color(0xFFC62828)]
              : AppTheme.gradientOf(AppColors.aqua),
          shadow: urgent,
          child: Text('⏱ $t s',
              style: TextStyle(
                  color: urgent ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
        );
      },
    );
  }

  Widget _buildLdStock() {
    return ValueListenableBuilder<int>(
      valueListenable: _game.stockLeft,
      builder: (context, left, _) {
        final next = _game.upcomingStock;
        return Column(
          // 复用竖屏牌堆的 GlobalKey：教学高亮（stockPile）在横屏也能正确定位。
          key: _stockBarKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < next.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _stockCard(
                      next[i],
                      index: i,
                      size: 44,
                      leading: i == 0,
                      enabled: left > 0 && !_finished,
                      onTap: () => _game.drawStock(i),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.level.endless ? '无限牌堆' : '牌堆剩 $left 张',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: left > 0 ? AppColors.ink2 : AppColors.ink3,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLdTools() {
    final coins = widget.data.coins;
    final disabled = _finished;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _chip(
          gradient: const [AppColors.coinGold1, AppColors.coinGold2],
          shadow: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💰', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text('$coins',
                  style: const TextStyle(
                      color: AppColors.coinText,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_hammering)
          _toolButton(
            key: _hammerToolKey,
            icon: Icons.close,
            label: '取消',
            cost: null,
            onTap: _cancelHammer,
            danger: true,
          )
        else
          _toolButton(
            key: _hammerToolKey,
            icon: Icons.construction,
            label: '清除',
            cost: _hammerCost,
            onTap: _useHammer,
            enabled: coins >= _hammerCost && !disabled,
          ),
        const SizedBox(height: 6),
        _toolButton(
          key: _undoToolKey,
          icon: Icons.undo,
          label: '撤销',
          cost: _undoCost,
          onTap: _useUndo,
          enabled: coins >= _undoCost && !disabled && _game.canUndo,
        ),
        if (!widget.level.endless) ...[
          const SizedBox(height: 6),
          _toolButton(
            key: _addCardsToolKey,
            icon: Icons.add_box,
            label: '加牌',
            cost: _addCardsCost,
            onTap: _useAddCards,
            enabled: coins >= _addCardsCost && !disabled,
          ),
        ],
        const SizedBox(height: 6),
        _toolButton(
          icon: Icons.shuffle,
          label: '洗牌',
          cost: _shuffleCost,
          onTap: _useShuffle,
          enabled: coins >= _shuffleCost && !disabled,
        ),
        const SizedBox(height: 6),
        _toolButton(
          icon: Icons.lightbulb_outline,
          label: '提示',
          cost: _hintCost,
          onTap: _useHint,
          enabled: coins >= _hintCost && !disabled,
        ),
      ],
    );
  }

  Widget _smallIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceLight,
                    Color.lerp(AppColors.grape, Colors.white, 0.90)!,
                  ],
                )
              : null,
          color: onPressed != null ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: onPressed != null
                ? AppColors.grape.withValues(alpha: 0.30)
                : AppColors.ink3.withValues(alpha: 0.18),
          ),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: AppColors.grape.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(icon,
            size: 17,
            color: onPressed != null ? AppColors.ink1 : AppColors.ink3),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                color: AppColors.coral,
                onTap: _finished
                    ? null
                    : () {
                        AudioFeedback.uiTap();
                        Navigator.of(context).pop();
                      },
              ),
              // 弹性标题：小屏自动省略，永不把 HUD 撑溢出。
              Flexible(
                child: _chip(
                  gradient: const [AppColors.surfaceLight, AppColors.surfaceLight],
                  shadow: true,
                  child: Text(
                    widget.level.endless
                        ? '🌌 无尽模式'
                        : '第 ${widget.level.id} 关 · ${widget.level.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.ink1,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: _game.combo,
                builder: (_, c, _) => c >= 2
                    ? _chip(
                        gradient: const [Color(0xFFFF7043), Color(0xFFE53935)],
                        shadow: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 3),
                            Text(
                              'x$c',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _game.score,
                builder: (_, v, _) => _chip(
                  gradient: const [AppColors.coinGold1, AppColors.coinGold2],
                  shadow: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐',
                          style: TextStyle(fontSize: 15, height: 1)),
                      const SizedBox(width: 3),
                      Text(
                        '$v',
                        style: const TextStyle(
                            color: AppColors.coinText,
                            fontWeight: FontWeight.w900,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              RoundIconButton(
                icon: Icons.pause_circle_outline,
                color: AppColors.grape,
                onTap: _finished
                    ? null
                    : () {
                        AudioFeedback.uiTap();
                        _showPause();
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: _game.produced,
            builder: (_, v, _) {
              final isClear = widget.level.goalType == GoalType.clearBoard;
              final endless = widget.level.endless;
              final goalChip = _chip(
                gradient: [
                  Color.lerp(
                      (endless
                              ? _game.endlessTarget.color
                              : widget.level.targetTier?.color ??
                                  AppColors.accent),
                      Colors.white,
                      0.15)!,
                  Color.lerp(
                      (endless
                              ? _game.endlessTarget.color
                              : widget.level.targetTier?.color ??
                                  AppColors.accent),
                      Colors.black,
                      0.15)!,
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: endless
                      ? [
                          const Text('目标',
                              style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 6),
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: VehicleImage(vehicle: _game.endlessTarget, size: 20)),
                          const SizedBox(width: 6),
                          Text(
                            '$v / ${_game.endlessNeed}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900),
                          ),
                        ]
                      : isClear
                          ? [
                              const Text('目标 ',
                                  style: TextStyle(color: Colors.white)),
                              ValueListenableBuilder<int>(
                                valueListenable: _game.stockLeft,
                                builder: (_, left, _) => Text(
                                  left > 0
                                      ? '打完牌堆 · 剩 $left 张'
                                      : (v <= (widget.level.clearLimit ?? 0)
                                          ? '✅ 达标 场上 $v 组'
                                          : '场上 $v 组 / 目标 ≤${widget.level.clearLimit ?? 0}'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ]
                          : [
                              const Text('目标',
                                  style: TextStyle(color: Colors.white)),
                              const SizedBox(width: 6),
                              SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: VehicleImage(vehicle: widget.level.targetTier!, size: 20)),
                              const SizedBox(width: 6),
                              Text(
                                '$v / ${widget.level.targetCount}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                ),
              );
              final chips = <Widget>[goalChip];
              if (widget.level.timeLimitSeconds != null) {
                chips.add(const SizedBox(width: 8));
                chips.add(ValueListenableBuilder<int>(
                  valueListenable: _game.timeLeft,
                  builder: (_, t, _) {
                    final urgent = t <= 10;
                    return _chip(
                      gradient: urgent
                          ? const [Color(0xFFE53935), Color(0xFFC62828)]
                          : const [Color(0xFF17C2CF), Color(0xFF0D93A0)],
                      shadow: urgent,
                      child: Text(
                        '⏱ $t s',
                        style: TextStyle(
                          color: urgent ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ));
              }
              if (widget.level.movesLimit != null) {
                chips.add(const SizedBox(width: 8));
                chips.add(ValueListenableBuilder<int>(
                  valueListenable: _game.movesLeft,
                  builder: (_, m, _) {
                    final urgent = m <= 5;
                    return _chip(
                      gradient: urgent
                          ? const [Color(0xFFE53935), Color(0xFFC62828)]
                          : const [Color(0xFF17C2CF), Color(0xFF0D93A0)],
                      shadow: urgent,
                      child: Text(
                        '👟 $m 步',
                        style: TextStyle(
                          color: urgent ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ));
              }
              return chips.length == 1
                  ? chips.first
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: chips,
                    );
            },
          ),
        ],
      ),
    );
  }

  /// 常驻目标栏：每关固定显示"通关目的 + 怎么赢"，
  /// 尤其清道夫关（第 6/9 关等）胜利条件与普通关不同，
  /// 没有说明时玩家会不知道怎么过关、误以为是 bug。
  Widget _buildGoalBar({bool compact = false}) {
    final level = widget.level;
    final String title;
    final String howTo;
    if (level.endless) {
      title = '🌌 无尽冲档：不断合成更高级车辆';
      howTo = '棋盘放满即结束';
    } else {
      // 清道夫关不用 goalText（"残留≤N 堆"太术语化，玩家看不懂），
      // 改成大白话：牌堆用完 + 场上剩的车不超过 N 组就赢。
      title = switch (level.goalType) {
        GoalType.clearBoard =>
          '🎯 目标：用光牌堆，场上剩 ≤${level.clearLimit ?? 0} 组就赢',
        _ => level.goalText,
      };
      howTo = switch (level.goalType) {
        GoalType.clearBoard => '同级 3 辆拖一起合成升级，最高档合成会升空消失',
        _ => '同级车拖一起合成升级',
      };
    }
    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 0 : 12, 0, compact ? 0 : 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceLight,
            Color.lerp(AppColors.coralDeep, Colors.white, 0.92)!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coralDeep.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.coralDeep.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text('🎯', style: TextStyle(fontSize: compact ? 11 : 13)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink1,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  howTo,
                  style: TextStyle(
                    color: AppColors.ink2,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 统一 chip 质感：给定渐变后自动补顶部白高光 + 同色柔投影，
  /// 让 HUD 上的一堆小标签像"一排糖果"而不是各自 принципи不同的色块。
  Widget _chip({
    required List<Color> gradient,
    required Widget child,
    bool shadow = false,
  }) {
    final base = gradient.last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(gradient.first, Colors.white, 0.30)!,
            base,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: shadow ? 0.34 : 0.16),
            blurRadius: shadow ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStockBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _game.stockLeft,
      builder: (context, left, _) {
        final next = _game.upcomingStock;
        return ValueListenableBuilder<String?>(
          valueListenable: _game.hint,
          builder: (context, hint, _) {
            return ValueListenableBuilder<double>(
              valueListenable: _game.cellPx,
              builder: (context, cellPx, _) {
                return LayoutBuilder(builder: (context, bc) {
                  final n = next.length;
                  // 牌堆卡与棋盘格同尺寸：棋盘格子大（如 3x3 关）牌堆卡也大，
                  // 格子小（如 6x6 关）也小，消除"两套尺寸"的割裂感。
                  // 张数信息改为牌堆下方一行小字，让出横向空间给卡片本身。
                  const slotPad = 6.0;
                  const cardGap = 8.0;
                  // 32 = 外层左右 padding，+2 = 牌槽描边，避免边界像素溢出。
                  final byWidth =
                      (bc.maxWidth - 34 - slotPad * 2 - cardGap * (n - 1)) / n;
                  var size = cellPx * 0.96;
                  if (size > byWidth) size = byWidth;
                  size = size.clamp(36.0, 104.0);
                  return Padding(
                    key: _stockBarKey,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hint != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.coralDeep, fontSize: 12),
                            ),
                          ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(slotPad),
                            decoration: AppTheme.frostedPanel(
                              accent: AppColors.grape,
                              radius: 22,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < n; i++) ...[
                                  if (i > 0) const SizedBox(width: cardGap),
                                  _stockCard(
                                    next[i],
                                    index: i,
                                    size: size,
                                    // 第一张是下一张要出的牌，用金边强调。
                                    leading: i == 0,
                                    enabled: left > 0 && !_finished,
                                    onTap: () => _game.drawStock(i),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.level.endless
                              ? '🂠 无限牌堆 · 点卡片出牌'
                              : (left > 0
                                  ? '🂠 牌堆剩 $left 张 · 点卡片出牌'
                                  : '🂠 牌已用完'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: left > 0 ? AppColors.ink2 : AppColors.ink3,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                });
              },
            );
          },
        );
      },
    );
  }

  /// 牌堆卡：与棋盘上的卡同款视觉（同色系渐变底 + 同比例 emoji + 同圆角比），
  /// 尺寸跟随棋盘格子，玩家一眼能预判"这张牌落下去就是这么大一张"。
  Widget _stockCard(
    VehicleType vehicle, {
    required int index,
    required double size,
    required bool leading,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final light = Color.lerp(vehicle.color, Colors.white, 0.66)!;
    final deep = Color.lerp(vehicle.color, Colors.white, 0.82)!;
    final radius = size * 0.14;
    return Pressable(
      key: ValueKey('stockCard$index'),
      onTap: enabled ? onTap : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [light, deep],
          ),
          border: Border.all(
            color: leading
                ? const Color(0xFFFFC107)
                : vehicle.color.withValues(alpha: 0.6),
            width: leading ? 2.4 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: vehicle.color.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 顶部高光（与棋盘卡一致）。
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: 0.32),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.45,
                  child: Text(
                    vehicle.icon,
                    style: TextStyle(fontSize: size * 0.62),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTools() {
    final coins = widget.data.coins;
    final disabled = _finished;
    // 工具按钮较多（清除/撤销/加牌/洗牌/提示），窄屏横向滚动避免溢出。
    return Padding(
      key: _toolsKey,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              gradient: const [AppColors.coinGold1, AppColors.coinGold2],
              shadow: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 4),
                  Text(
                    '$coins',
                    style: const TextStyle(
                        color: AppColors.coinText,
                        fontWeight: FontWeight.w900,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_hammering)
              _toolButton(
                key: _hammerToolKey,
                icon: Icons.close,
                label: '取消',
                cost: null,
                onTap: _cancelHammer,
                danger: true,
              )
            else
              _toolButton(
                key: _hammerToolKey,
                icon: Icons.construction,
                label: '清除',
                cost: _hammerCost,
                onTap: _useHammer,
                enabled: coins >= _hammerCost && !disabled,
              ),
            _toolButton(
              key: _undoToolKey,
              icon: Icons.undo,
              label: '撤销',
              cost: _undoCost,
              onTap: _useUndo,
              enabled: coins >= _undoCost && !disabled && _game.canUndo,
            ),
            if (!widget.level.endless)
              _toolButton(
                key: _addCardsToolKey,
                icon: Icons.add_box,
                label: '加牌',
                cost: _addCardsCost,
                onTap: _useAddCards,
                enabled: coins >= _addCardsCost && !disabled,
              ),
          _toolButton(
            icon: Icons.shuffle,
            label: '洗牌',
            cost: _shuffleCost,
            onTap: _useShuffle,
            enabled: coins >= _shuffleCost && !disabled,
          ),
          _toolButton(
            icon: Icons.lightbulb_outline,
            label: '提示',
            cost: _hintCost,
            onTap: _useHint,
            enabled: coins >= _hintCost && !disabled,
          ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton({
    Key? key,
    required IconData icon,
    required String label,
    required int? cost,
    required VoidCallback onTap,
    bool enabled = true,
    bool danger = false,
  }) {
    final on = enabled ? onTap : null;
    // 身份色：危险操作红、其余用珊瑚，禁用时统一灰。
    final tint = danger ? AppColors.melon : AppColors.coral;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 8),
      child: Pressable(
        onTap: on,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surfaceLight,
                      Color.lerp(tint, Colors.white, 0.90)!,
                    ],
                  )
                : null,
            color: enabled ? null : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled
                  ? tint.withValues(alpha: 0.32)
                  : AppColors.ink3.withValues(alpha: 0.18),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 19,
                  color: enabled
                      ? AppTheme.deepen(tint, 0.22)
                      : AppColors.ink3),
              const SizedBox(height: 2),
              Text(
                cost == null ? label : '$label $cost',
                style: TextStyle(
                  fontSize: 10.5,
                  color: enabled
                      ? AppTheme.deepen(tint, 0.34)
                      : AppColors.ink3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _useHammer() {
    if (_finished || widget.data.coins < _hammerCost) return;
    setState(() => _hammering = true);
    _game.deselect();
    _game.hammerArmed = true;
    // 实际清除成功后才扣费（点空格没锁/取消都不扣钱）。
    _game.onHammerUsed = () {
      if (!mounted) return;
      if (widget.data.coins >= _hammerCost) {
        widget.data.coins -= _hammerCost;
        _analytics.toolUse('hammer', _hammerCost, widget.data.coins);
        widget.repo.save(widget.data);
      }
      setState(() => _hammering = false);
    };
  }

  void _cancelHammer() {
    _game.hammerArmed = false;
    _game.onHammerUsed = null;
    setState(() => _hammering = false);
  }

  void _useUndo() {
    if (_finished || widget.data.coins < _undoCost) return;
    if (!_game.canUndo) return;
    widget.data.coins -= _undoCost;
    _analytics.toolUse('undo', _undoCost, widget.data.coins);
    widget.repo.save(widget.data);
    _game.undoMove();
    setState(() {});
  }

  void _useAddCards() {
    if (_finished || widget.data.coins < _addCardsCost) return;
    widget.data.coins -= _addCardsCost;
    _analytics.toolUse('add_cards', _addCardsCost, widget.data.coins);
    widget.repo.save(widget.data);
    _game.addCards(3);
    setState(() {});
  }

  void _useShuffle() {
    if (_finished || widget.data.coins < _shuffleCost) return;
    widget.data.coins -= _shuffleCost;
    _analytics.toolUse('shuffle', _shuffleCost, widget.data.coins);
    widget.repo.save(widget.data);
    _game.shuffleBoard();
    setState(() {});
  }

  void _useHint() {
    if (_finished || widget.data.coins < _hintCost) return;
    widget.data.coins -= _hintCost;
    _analytics.toolUse('hint', _hintCost, widget.data.coins);
    widget.repo.save(widget.data);
    _game.showHint();
    setState(() {});
  }
}

class _ResultDialog extends StatelessWidget {
  final bool won;
  final int score;
  final String message;
  final String title;

  /// 通关星级（1-3，失败/无尽为 0）。
  final int stars;
  final int maxCombo;
  final String elapsedText;

  /// 无尽模式等级与榜单名次（非无尽为 0 / null）。
  final int endlessLevel;
  final int? rank;

  final int reward;
  final int consolation;

  /// 失败时的安慰金币数（用于提示文案）。
  final VoidCallback onReplay;
  final VoidCallback onHome;

  /// 通关且有下一关时的"直接进下一关"回调；为空则主按钮显示再来一局。
  final VoidCallback? onNext;

  /// 分享战绩回调（#80，可为空则隐藏分享按钮）。
  final VoidCallback? onShare;

  /// 失败时"看广告续命"按钮文案（null = 不显示，胜利/次数用完）。
  final String? reviveLabel;
  final VoidCallback? onRevive;

  /// 胜利时"看广告金币×2"回调（null = 不显示或已翻倍）。
  final VoidCallback? onDoubleReward;

  const _ResultDialog({
    required this.won,
    required this.score,
    required this.message,
    required this.title,
    required this.stars,
    required this.maxCombo,
    required this.elapsedText,
    required this.endlessLevel,
    required this.rank,
    required this.reward,
    required this.consolation,
    required this.onReplay,
    required this.onHome,
    this.onNext,
    this.onShare,
    this.reviveLabel,
    this.onRevive,
    this.onDoubleReward,
  });

  @override
  Widget build(BuildContext context) {
    final isEndless = endlessLevel > 0;
    // 失败时改用柔和葡萄紫而不是刺眼的警示色：这一局没成，不代表失败。
    final headerColors = won
        ? const [AppColors.coral, AppColors.coralDeep]
        : <Color>[AppColors.grape, AppTheme.deepen(AppColors.grape, 0.14)];
    return Dialog(
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: headerColors,
                ),
              ),
              child: Column(
                children: [
                  if (stars > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          3,
                          (i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 450 + i * 150),
                              curve: Curves.elasticOut,
                              builder: (_, v, child) =>
                                  Transform.scale(scale: v, child: child),
                              child: Text(
                                i < stars ? '⭐' : '☆',
                                style: const TextStyle(fontSize: 30),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.ink2),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.coinGold1, AppColors.coinGold2],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      won
                          ? '得分 $score  ·  +$reward 🪙'
                          : '得分 $score  ·  安慰 +$consolation 🪙',
                      style: const TextStyle(
                          color: AppColors.coinText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 胜利广告位：看广告金币×2（每局一次，翻倍后隐藏）。
                  if (onDoubleReward != null) ...[
                    CandyButton(
                      label: '看广告 金币 ×2（+$reward 🪙）',
                      icon: Icons.movie_creation_outlined,
                      colors: AppTheme.gradientOf(AppColors.lemon),
                      expand: true,
                      onTap: onDoubleReward,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isEndless)
                    Text(
                      rank != null
                          ? '完成 ${endlessLevel - 1} 档目标 · 榜单第 $rank 名'
                          : '完成 ${endlessLevel - 1} 档目标 · 未进前 10',
                      style: const TextStyle(color: AppColors.ink2, fontSize: 14),
                    )
                  else
                    Text(
                      '最大连消 x$maxCombo  ·  用时 $elapsedText',
                      style: const TextStyle(color: AppColors.ink2, fontSize: 14),
                    ),
                  const SizedBox(height: 20),
                  // 失败广告位：看广告续命（每局一次），放在主操作上方最显眼处。
                  if (reviveLabel != null && onRevive != null) ...[
                    CandyButton(
                      label: reviveLabel!,
                      icon: Icons.play_circle_fill,
                      colors: AppTheme.gradientOf(AppColors.mint),
                      expand: true,
                      onTap: onRevive,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (onShare != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CandyButton(
                        label: '分享战绩',
                        icon: Icons.ios_share,
                        colors: AppTheme.softGradient,
                        expand: true,
                        onTap: onShare,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: CandyButton(
                          label: '返回',
                          colors: AppTheme.softGradient,
                          size: CandyButtonSize.medium,
                          onTap: onHome,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CandyButton(
                          label: onNext != null ? '下一关 ▶' : '再来一局',
                          colors: AppTheme.gradientOf(AppColors.coral),
                          size: CandyButtonSize.medium,
                          onTap: onNext ?? onReplay,
                        ),
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
}
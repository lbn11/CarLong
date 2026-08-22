import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/analytics.dart';
import '../game/daily_challenge.dart';
import '../game/game_config.dart';
import '../game/music_player.dart';
import '../game/merge_game.dart';
import '../theme/app_theme.dart';
import '../models/vehicle.dart';
import '../models/level.dart';
import '../save/save_repository.dart';
import '../widgets/tutorial_overlay.dart';
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

  // 教程高亮区域追踪
  final GlobalKey _stockBarKey = GlobalKey();
  final GlobalKey _toolsKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _hammerToolKey = GlobalKey();
  final GlobalKey _undoToolKey = GlobalKey();
  final GlobalKey _addCardsToolKey = GlobalKey();
  Rect? _currentHighlightRect;

  void _updateHighlightRect() {
    if (!_tutorialActive || _tutorialStepIndex >= _tutorialSteps.length) {
      _currentHighlightRect = null;
      return;
    }
    final step = _tutorialSteps[_tutorialStepIndex];
    GlobalKey? targetKey;
    switch (step.highlight) {
      case TutorialHighlight.stockPile: targetKey = _stockBarKey; break;
      case TutorialHighlight.board: targetKey = _boardKey; break;
      case TutorialHighlight.hammerTool: targetKey = _hammerToolKey; break;
      case TutorialHighlight.undoTool: targetKey = _undoToolKey; break;
      case TutorialHighlight.addCardsTool: targetKey = _addCardsToolKey; break;
      case TutorialHighlight.coinsDisplay: targetKey = _toolsKey; break;
      case TutorialHighlight.homeLevels:
      case TutorialHighlight.homeParking:
      case TutorialHighlight.homeShop:
      case TutorialHighlight.none: targetKey = null; break;
    }
    if (targetKey == null) { _currentHighlightRect = null; return; }
    final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) { _currentHighlightRect = null; return; }
    _currentHighlightRect = box.localToGlobal(Offset.zero) & box.size;
  }

  void _scheduleHighlightUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tutorialActive) {
        _updateHighlightRect();
        setState(() {});
      }
    });
  }

  /// 双倍卡生效中：本关通关金币 ×2。
  bool _doubleCoin = false;

  /// 教程状态
  bool _tutorialActive = false;
  List<TutorialStep> _tutorialSteps = const [];
  int _tutorialStepIndex = 0;

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
    _game.onPlayerAction = _onPlayerAction;
    _analytics = AnalyticsService(widget.data, widget.repo);
    _analytics.levelStart(widget.level);
    _applyBoosters();
    // 清道夫关开局教学：胜利条件与"顶级车升空"机制一句话讲清。
    if (widget.level.goalType == GoalType.clearBoard) {
      _game.hint.value =
          '🎯 把牌堆用完，场上剩 ≤${widget.level.clearLimit ?? 0} 组就赢！'
          '同级车拖一起合成，最高档三合一会升空消失';
    }

    // 教程:前 3 关开启引导（2026-08-19 重做轻量版后恢复启用：
    // 无全屏遮罩、不拦截点击、动作检测 + 按钮双通道推进，永不卡死）。
    final tutorialScript = TutorialScript.getScript(widget.level.id);
    if (tutorialScript != null &&
        !widget.data.tutorialCompleted.contains(widget.level.id)) {
      _tutorialActive = true;
      _tutorialSteps = tutorialScript;
      _tutorialStepIndex = 0;
      // 激活后立即（postFrame）计算首步高亮，否则首步只有气泡没有高亮框。
      _scheduleHighlightUpdate();
    }
    // 合成场景 BGM（跟随音效开关；返回首页由 home 的 didPopNext 恢复）。
    if (widget.data.soundOn) {
      MusicPlayer.instance.play(MusicPlayer.merge);
    }
  }

  void _advanceTutorial() {
    if (!_tutorialActive) return;
    if (_tutorialStepIndex < _tutorialSteps.length - 1) {
      setState(() => _tutorialStepIndex++);
      _scheduleHighlightUpdate();
    } else {
      setState(() => _tutorialActive = false);
      widget.data.tutorialCompleted.add(widget.level.id);
      widget.repo.save(widget.data);
      _analytics.tutorialComplete('merge');
    }
  }

  void _notifyTutorialAction(TutorialAction action) {
    if (!_tutorialActive) return;
    final currentStep = _tutorialSteps[_tutorialStepIndex];
    if (currentStep.action == action && currentStep.blocking) {
      _advanceTutorial();
    }
  }

  void _skipTutorial() {
    setState(() => _tutorialActive = false);
    widget.data.tutorialCompleted.add(widget.level.id);
    widget.repo.save(widget.data);
    _analytics.tutorialComplete('merge', skipped: true);
  }

  void _onPlayerAction(String action, VehicleType? tier) {
    switch (action) {
      case 'draw':
        _notifyTutorialAction(TutorialAction.draw);
        break;
      case 'merge':
        _notifyTutorialAction(TutorialAction.merge);
        break;
      case 'hammer':
        _notifyTutorialAction(TutorialAction.hammer);
        break;
      case 'move':
        _notifyTutorialAction(TutorialAction.move);
        break;
      case 'reveal':
        _notifyTutorialAction(TutorialAction.reveal);
        break;
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
            : '⏰ 差一点';

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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('暂停中',
            style: TextStyle(color: AppColors.ink1, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pauseAction(Icons.play_arrow, '继续游戏', () {
              Navigator.of(ctx).pop('resume');
            }),
            _pauseAction(Icons.refresh, '重新开始', () {
              Navigator.of(ctx).pop('restart');
            }),
            _pauseAction(Icons.home, '返回主页', () {
              Navigator.of(ctx).pop('home');
            }),
          ],
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

  Widget _pauseAction(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.ink2, size: 20),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.ink1, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: GlowBackground(
        child: Stack(
          children: [
            SafeArea(
              child: isLandscape
                  ? _buildLandscapeLayout()
                  : _buildPortraitLayout(),
            ),
            // 修复：TutorialOverlay 必须放在 SafeArea 外层——高亮 rect 用的是
            // localToGlobal（全屏坐标），若 overlay 在 SafeArea 内，两者坐标系
            // 差一个 SafeArea 偏移（状态栏高度），高亮框会整体错位、与界面对不上。
            if (_tutorialActive)
              Positioned.fill(
                child: TutorialOverlay(
                  steps: _tutorialSteps,
                  onComplete: _skipTutorial,
                  onActionDetected: (action) => _notifyTutorialAction(action),
                  highlightRect: _currentHighlightRect,
                ),
              ),
          ],
        ),
      ),
    );
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
              : const [Color(0xFF2A2F38), Color(0xFF1F242C)],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < next.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: left > 0 && !_finished
                          ? () => _game.drawStock(i)
                          : null,
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: VehicleImage(vehicle: next[i], size: 34),
                      ),
                    ),
                  ),
              ],
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
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white70, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      style: IconButton.styleFrom(backgroundColor: const Color(0x22FFFFFF)),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _finished
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x22FFFFFF),
                ),
              ),
              _chip(
                gradient: const [AppColors.surfaceLight, AppColors.surfaceLight],
                shadow: true,
                child: Text(
                  widget.level.endless
                      ? '🌌 无尽模式'
                      : '第 ${widget.level.id} 关 · ${widget.level.name}',
                  style: const TextStyle(
                      color: AppColors.ink1,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
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
              IconButton(
                onPressed: _finished ? null : _showPause,
                tooltip: '暂停',
                icon: const Icon(Icons.pause_circle_outline,
                    color: Colors.white70),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x22FFFFFF),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FF5E7A)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
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

  Widget _chip({
    required List<Color> gradient,
    required Widget child,
    bool shadow = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
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
            return Padding(
              key: _stockBarKey,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                  Row(
                    children: [
                      for (var i = 0; i < next.length; i++)
                        GestureDetector(
                          onTap: left > 0 && !_finished
                              ? () => _game.drawStock(i)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: VehicleImage(vehicle: next[i], size: 46),
                            ),
                          ),
                        ),
                      const Spacer(),
                      _chip(
                        gradient: const [AppColors.surfaceLight, AppColors.surfaceLight],
                        shadow: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.style,
                                size: 15, color: AppColors.ink2),
                            const SizedBox(width: 4),
                            Text(
                              widget.level.endless
                                  ? '无限牌堆'
                                  : (left > 0 ? '牌堆剩 $left 张' : '牌已用完'),
                              style: TextStyle(
                                color:
                                    left > 0 ? AppColors.ink2 : AppColors.ink3,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: enabled
                  ? danger
                      ? const [Color(0xFFE53935), Color(0xFFC62828)]
                      : const [AppColors.surfaceLight, AppColors.surfaceLight]
                  : const [Color(0xFFE7E0E9), Color(0xFFDCD3E0)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: on,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 18,
                      color: enabled ? AppColors.ink1 : AppColors.ink3),
                  const SizedBox(height: 2),
                  Text(
                    cost == null ? label : '$label $cost',
                    style: TextStyle(
                      fontSize: 10,
                      color: enabled
                          ? AppColors.coralDeep
                          : AppColors.ink3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
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
    return Dialog(
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.coral, AppColors.coralDeep],
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
                    FilledButton.icon(
                      onPressed: onDoubleReward,
                      icon: const Icon(Icons.movie_creation_outlined, size: 18),
                      label: Text('看广告 金币 ×2（+$reward 🪙）',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coinGold2,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
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
                    FilledButton.icon(
                      onPressed: onRevive,
                      icon: const Icon(Icons.play_circle_fill, size: 20),
                      label: Text(reviveLabel!,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF66BB6A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (onShare != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: const Text('分享战绩',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.grape,
                          side: BorderSide(
                              color: AppColors.grape.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onHome,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink2,
                            side: BorderSide(color: AppColors.ink3),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('返回'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: onNext ?? onReplay,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.coral,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child:
                              Text(onNext != null ? '下一关 ▶' : '再来一局'),
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
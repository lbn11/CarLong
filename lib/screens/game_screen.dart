import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../game/daily_challenge.dart';
import '../game/merge_game.dart';
import '../game/vehicle_icons.dart';
import '../models/car.dart';
import '../models/level.dart';
import '../save/save_repository.dart';
import '../widgets/tutorial_overlay.dart';

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
  List<TutorialStep> _tutorialSteps = [];
  int _tutorialStepIndex = 0;

  static const int _hammerCost = 20;
  static const int _undoCost = 30;
  static const int _addCardsCost = 40;

  @override
  void initState() {
    super.initState();
    _game = MergeGame(widget.level);
    _game.onGameOver = _onGameOver;
    _game.onTierProduced = (tier) {
      if (widget.data.collection.add(tier.index)) {
        widget.data.coins += 5;
        _game.hint.value = '📖 图鉴点亮 ${tier.icon} ${tier.label} +5🪙';
        widget.repo.save(widget.data);
      }
    };
    _game.onEndlessMilestone = (endlessLevel, reward) {
      widget.data.coins += reward;
      _game.hint.value = '🏆 里程碑达成！无尽第 $endlessLevel 档 +$reward 🪙';
      widget.repo.save(widget.data);
    };
    _game.feedback.soundOn = widget.data.soundOn;
    _game.feedback.vibrateOn = widget.data.vibrateOn;
    _game.onPlayerAction = _onPlayerAction;
    _analytics = AnalyticsService(widget.data, widget.repo);
    _analytics.levelStart(widget.level);
    _applyBoosters();

    // 教程:前 3 关开启引导
    final tutorialScript = TutorialScript.getScript(widget.level.id);
    if (tutorialScript != null && !widget.data.tutorialCompleted.contains(widget.level.id)) {
      _tutorialActive = true;
      _tutorialSteps = tutorialScript;
      _tutorialStepIndex = 0;
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
  }

  void _onPlayerAction(String action, CarTier? tier) {
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
    if (widget.level.timeLimitSeconds != null && (b['time'] ?? 0) > 0) {
      b['time'] = b['time']! - 1;
      _game.addTime(30);
      _game.hint.value = '🕐 加时卡生效：+30 秒';
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
    const consolation = 10;
    var reward = won ? _starReward(score, stars) : consolation;
    if (_doubleCoin && won) reward *= 2;
    // 每日挑战：当天首次通关领固定大奖（不影响关卡解锁与星级）。
    var dailyBonus = 0;
    if (widget.level.daily && won) {
      final today = _dateString();
      if (widget.data.dailyClearedDate != today) {
        widget.data.dailyClearedDate = today;
        dailyBonus = DailyChallenge.reward;
      }
    }
    reward += dailyBonus;
    widget.data.coins += reward;
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
        reward: reward,
        consolation: won ? 0 : consolation,
        onReplay: _restart,
        onHome: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop(true);
        },
      ),
    );
  }

  String _dateString() {
    final n = DateTime.now();
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
        backgroundColor: const Color(0xFF232830),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('暂停中',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
        color: const Color(0xFF2C2F36),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16)),
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
      return left > 0 ? '还剩 $left 张卡没合成清空' : '再动一动棋子就清空啦';
    }
    final produced = _game.produced.value;
    final remain = (level.targetCount - produced).clamp(0, 999);
    return '还差 $remain 辆 ${level.targetTier!.icon} ${level.targetTier!.label}';
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: const Color(0xFF171A1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF23303E), Color(0xFF171A1E), Color(0xFF0E1013)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              isLandscape
                  ? _buildLandscapeLayout()
                  : _buildPortraitLayout(),
              if (_tutorialActive)
                TutorialOverlay(
                  steps: _tutorialSteps,
                  onComplete: _skipTutorial,
                  onActionDetected: (action) => _notifyTutorialAction(action),
                  highlightRect: _currentHighlightRect,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 竖屏：HUD 在上、牌堆和道具在下的上下布局。
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHud(),
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
            gradient: const [Color(0xFFFFD54F), Color(0xFFFF9800)],
            shadow: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 13, height: 1)),
                const SizedBox(width: 3),
                Text('$v',
                    style: const TextStyle(
                        color: Color(0xFF4E342E),
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
            : widget.level.targetTier?.color ?? const Color(0xFF4A90D9);
        final Widget child;
        if (endless) {
          child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              VehicleIcon(
                  tier: _game.endlessTarget,
                  size: 14,
                  color: _game.endlessTarget.color),
              const SizedBox(width: 4),
              Text('$v / ${_game.endlessNeed}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ],
          );
        } else if (isClear) {
          child = Text('清空 · 剩 $v 格',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12));
        } else {
          child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              VehicleIcon(
                  tier: widget.level.targetTier!,
                  size: 14,
                  color: widget.level.targetTier!.color),
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
                      child: VehicleCard(tier: next[i], size: 34),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.level.endless ? '无限牌堆' : '牌堆剩 $left 张',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: left > 0 ? Colors.white70 : Colors.white38,
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
          gradient: const [Color(0xFFFFD54F), Color(0xFFFF9800)],
          shadow: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💰', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text('$coins',
                  style: const TextStyle(
                      color: Color(0xFF4E342E),
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_hammering)
          _toolButton(
            icon: Icons.close,
            label: '取消',
            cost: null,
            onTap: _cancelHammer,
            danger: true,
          )
        else
          _toolButton(
            icon: Icons.construction,
            label: '清除',
            cost: _hammerCost,
            onTap: _useHammer,
            enabled: coins >= _hammerCost && !disabled,
          ),
        const SizedBox(height: 6),
        _toolButton(
          icon: Icons.undo,
          label: '撤销',
          cost: _undoCost,
          onTap: _useUndo,
          enabled: coins >= _undoCost && !disabled && _game.canUndo,
        ),
        if (!widget.level.endless) ...[
          const SizedBox(height: 6),
          _toolButton(
            icon: Icons.add_box,
            label: '加牌',
            cost: _addCardsCost,
            onTap: _useAddCards,
            enabled: coins >= _addCardsCost && !disabled,
          ),
        ],
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
                gradient: const [Color(0xFF2A2F38), Color(0xFF1F242C)],
                child: Text(
                  widget.level.endless
                      ? '🌌 无尽模式'
                      : '第 ${widget.level.id} 关 · ${widget.level.name}',
                  style: const TextStyle(
                      color: Colors.white,
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
                  gradient: const [Color(0xFFFFD54F), Color(0xFFFF9800)],
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
                            color: Color(0xFF4E342E),
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
                                  const Color(0xFF4A90D9)),
                      Colors.white,
                      0.15)!,
                  Color.lerp(
                      (endless
                              ? _game.endlessTarget.color
                              : widget.level.targetTier?.color ??
                                  const Color(0xFF4A90D9)),
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
                          VehicleIcon(
                              tier: _game.endlessTarget,
                              size: 18,
                              color: _game.endlessTarget.color),
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
                              const Text('目标 清空棋盘 · 剩余 ',
                                  style: TextStyle(color: Colors.white)),
                              Text(
                                '$v 格',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900),
                              ),
                            ]
                          : [
                              const Text('目标',
                                  style: TextStyle(color: Colors.white)),
                              const SizedBox(width: 6),
                              VehicleIcon(
                                  tier: widget.level.targetTier!,
                                  size: 18,
                                  color: widget.level.targetTier!.color),
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
                          : const [Color(0xFF2A2F38), Color(0xFF1F242C)],
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
                          : const [Color(0xFF2A2F38), Color(0xFF1F242C)],
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
                            color: Color(0xFFFFCA28), fontSize: 12),
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
                            child: VehicleCard(tier: next[i], size: 46),
                          ),
                        ),
                      const Spacer(),
                      _chip(
                        gradient: left > 0
                            ? const [Color(0xFF2A2F38), Color(0xFF1F242C)]
                            : const [Color(0xFF3A2A2A), Color(0xFF2A1F1F)],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.style,
                                size: 15, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              widget.level.endless
                                  ? '无限牌堆'
                                  : (left > 0 ? '牌堆剩 $left 张' : '牌已用完'),
                              style: TextStyle(
                                color:
                                    left > 0 ? Colors.white70 : Colors.white38,
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
    return Padding(
      key: _toolsKey,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _chip(
            gradient: const [Color(0xFFFFD54F), Color(0xFFFF9800)],
            shadow: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💰', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Text(
                  '$coins',
                  style: const TextStyle(
                      color: Color(0xFF4E342E),
                      fontWeight: FontWeight.w900,
                      fontSize: 14),
                ),
              ],
            ),
          ),
          const Spacer(),
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
        ],
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
                      : const [Color(0xFF3A4452), Color(0xFF262B33)]
                  : const [Color(0xFF23262B), Color(0xFF1D2024)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x40000000),
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
                      color: enabled ? Colors.white : Colors.white24),
                  const SizedBox(height: 2),
                  Text(
                    cost == null ? label : '$label $cost',
                    style: TextStyle(
                      fontSize: 10,
                      color: enabled
                          ? const Color(0xFFFFCA28)
                          : Colors.white30,
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

  /// 失败时的安慰金币数（用于提示文案）。
  final int consolation;
  final VoidCallback onReplay;
  final VoidCallback onHome;

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
  });

  @override
  Widget build(BuildContext context) {
    final isEndless = endlessLevel > 0;
    return Dialog(
      backgroundColor: const Color(0xFF232830),
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
                  colors: [Color(0xFF2A3D5C), Color(0xFF1B2437)],
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
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      won
                          ? '得分 $score  ·  +$reward 🪙'
                          : '得分 $score  ·  安慰 +$consolation 🪙',
                      style: const TextStyle(
                          color: Color(0xFF4E342E),
                          fontSize: 17,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isEndless)
                    Text(
                      rank != null
                          ? '完成 ${endlessLevel - 1} 档目标 · 榜单第 $rank 名'
                          : '完成 ${endlessLevel - 1} 档目标 · 未进前 10',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    )
                  else
                    Text(
                      '最大连消 x$maxCombo  ·  用时 $elapsedText',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onHome,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('返回'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: onReplay,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90D9),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('再来一局'),
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
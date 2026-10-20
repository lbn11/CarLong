import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../game/audio_feedback.dart';
import '../widgets/pressable.dart';
import '../game/game_config.dart';
import '../game/music_player.dart';
import '../game/parking_daily_challenge.dart';
import '../game/parking_game.dart';
import '../models/parking_level.dart';
import '../models/vehicle.dart';
import '../save/save_repository.dart';
import '../services/level_progression.dart';
import '../services/level_rhythm.dart';
import '../services/parking_chapters.dart';
import '../services/parking_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_ui.dart';
import '../widgets/parking_vehicle_body.dart';
import '../widgets/vehicle_image.dart';

/// 车辆滑动动画时长（选车滑行 / 重置归位）。
const Duration _kVehicleSlide = Duration(milliseconds: 170);

/// 停车模式主屏
class ParkingScreen extends StatefulWidget {
  final ParkingLevel level;
  final PlayerData data;
  final SaveRepository repo;
  final bool isDaily;

  const ParkingScreen({
    super.key,
    required this.level,
    required this.data,
    required this.repo,
    this.isDaily = false,
  });

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen>
    with WidgetsBindingObserver {
  late final ParkingGame _game;
  final AudioFeedback _audio = AudioFeedback();
  late final AnalyticsService _analytics;
  int? _selectedVehicle;

  /// 提示状态：被建议移动的车辆索引（用于高亮，null 表示未激活）。
  int? _hintVehicle;
  /// 提示目标落点的整块格集合（长条车为多格），用于青色高亮。
  List<(int, int)> _hintCells = const [];

  /// 当前激活的道具模式（null = 未激活）。
  String? _activeItem;
  /// 双倍移动：第一次移动后允许再移动一次。
  bool _doubleMoveActive = false;
  /// 标记模式：true = 标记格子（X/!/？），false = 正常选择车辆
  bool _markMode = false;

  /// 连胜计数
  int _winStreak = 0;

  /// 本关在 5 关难度心跳中的相位（0 轻松 … 4 硬仗）。
  int get _phase => ParkingLevelGenerator.rhythmPhase(widget.level.id);

  /// 死局弹窗已弹出标记（同一死局只弹一次，棋盘恢复可动后重置）。
  bool _deadlockDialogShown = false;

  /// 限时紧迫提示去重：记录上次已提示的剩余秒数（每秒只提示一次）。
  int? _lastUrgentTick;

  /// 操作反馈提示（如"横车只能左右滑"），2 秒后自动消失。
  String? _toast;
  Timer? _toastTimer;

  /// 目标车位幽灵车呼吸脉冲（Timer 驱动；不用循环动画控制器，
  /// 避免测试里 pumpAndSettle 永不结束）。
  bool _ghostPulse = false;
  Timer? _ghostTimer;

  /// 停车位坐标（关卡不可变，初始化一次）。
  late final (int, int) _parkingCell = _findParkingCell();

  (int, int) _findParkingCell() {
    for (var r = 0; r < widget.level.rows; r++) {
      for (var c = 0; c < widget.level.cols; c++) {
        if (widget.level.grid[r][c] == ParkingCellType.parking) {
          return (r, c);
        }
      }
    }
    return (-1, -1);
  }

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  void initState() {
    super.initState();
    // 后台切换时暂停/恢复计时（接电话、回微信不该被扣时间）。
    WidgetsBinding.instance.addObserver(this);
    _analytics = AnalyticsService(widget.data, widget.repo);
    _game = ParkingGame(widget.level);
    _game.addListener(_onGameUpdate);
    // 音效/触感跟随全局开关。
    _audio.soundOn = widget.data.soundOn;
    _audio.vibrateOn = widget.data.vibrateOn;
    // 同步全局振动开关，供 Pressable 等 UI 层触感入口使用。
    AudioFeedback.globalVibrateOn = widget.data.vibrateOn;
    unawaited(_audio.load());
    // 目标车位幽灵车呼吸脉冲。
    _ghostTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _ghostPulse = !_ghostPulse);
    });
    // 停车场景 BGM（跟随音效开关；返回首页由 home 的 didPopNext 恢复）。
    if (widget.data.soundOn) {
      MusicPlayer.instance.play(MusicPlayer.parking);
    }
  }

  void _onGameUpdate() {
    if (!mounted) return;
    // 限时最后 10 秒：每秒 tick 音 + 轻振，与合成模式的紧迫感一致。
    final tl = _game.timeLeft;
    if (tl != null && tl > 0 && tl <= 10 && tl != _lastUrgentTick) {
      _lastUrgentTick = tl;
      _audio.play(Sfx.tick);
      unawaited(_audio.select());
    }
    // 死局检测：无车可动时弹窗引导，避免无限僵持（每次死局只弹一次）。
    if (_game.isDeadlocked && !_deadlockDialogShown) {
      _deadlockDialogShown = true;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_settled && _game.isDeadlocked) {
          _showDeadlockDialog();
        }
      });
      return;
    }
    if (!_game.isDeadlocked) _deadlockDialogShown = false;
    setState(() {});
  }

  /// 死局弹窗：撤销 3 步 / 道具提示 / 重新开始。
  void _showDeadlockDialog() {
    // 死局弹窗打开时停表（限时关读选项不该被扣时间）。
    _game.pauseTimer();
    CandyChoiceDialog.show<String>(
      context,
      barrierDismissible: false,
      emoji: '🚧',
      title: '无车可动',
      message: '这局卡住了，给你三条路：',
      accent: AppColors.sun,
      options: <CandyChoice<String>>[
        if (_game.canUndo)
          const CandyChoice<String>(
            label: '撤销 3 步',
            value: 'undo',
            icon: Icons.undo_rounded,
            highlight: true,
          ),
        const CandyChoice<String>(
          label: '使用道具',
          value: 'items',
          icon: Icons.construction_rounded,
        ),
        const CandyChoice<String>(
          label: '重新开始',
          value: 'restart',
          icon: Icons.refresh_rounded,
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'undo':
          _useUndo();
        case 'restart':
          _resetGame();
        default:
          break; // 留在场内使用道具
      }
      if (mounted) _game.resumeTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_game.hasWon || _game.hasLost) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _game.pauseTimer();
    } else if (state == AppLifecycleState.resumed) {
      _game.resumeTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    _ghostTimer?.cancel();
    _game.removeListener(_onGameUpdate);
    _game.dispose();
    super.dispose();
  }

  void _handleCellTap(int row, int col) {
    if (_game.hasWon || _game.hasLost) return;

    // 标记模式
    if (_markMode && !_game.hasWon && !_game.hasLost) {
      _game.toggleMark(row, col);
      _audio.play(Sfx.tick);
      unawaited(_audio.select());
      return;
    }

    // 道具使用
    if (_activeItem != null) {
      _useItemOnCell(row, col);
      return;
    }

    if (_selectedVehicle != null) {
      // 点到另一辆可动的车 → 直接切换选中；再点自己 → 取消选中。
      // 修复：之前选中后点别车只会报"被挡住"，永远无法换车，
      // 若选中的车暂时无路可走，玩家会觉得整个棋盘卡死。
      final tapped = _game.vehicleAt(row, col);
      if (tapped != null && !tapped.parked && tapped.index != _selectedVehicle) {
        setState(() {
          _selectedVehicle = tapped.index;
          _hintVehicle = null;
          _hintCells = const [];
        });
        unawaited(_audio.tap());
        return;
      }
      if (tapped != null && tapped.index == _selectedVehicle) {
        setState(() => _selectedVehicle = null);
        unawaited(_audio.tap());
        return;
      }
      // 沿车身方向滑到点击侧最远可达处（长条车只能沿轴滑动）。
      final moved = _game.slideTo(_selectedVehicle!, row, col);
      if (moved) {
        _audio.play(Sfx.move);
        final bonusMove = _doubleMoveActive;
        setState(() {
          _hintVehicle = null;
          _hintCells = const [];
          if (bonusMove) {
            // 双倍卡：消耗一次机会，保留选中让本车再滑一次。
            _doubleMoveActive = false;
          } else {
            _selectedVehicle = null;
          }
        });
        if (_game.hasWon) {
          _settleWin();
        } else if (_game.hasLost) {
          _settleLose();
        }
      } else {
        // 点了滑不过去的方向：明确告知原因（方向不对 vs 被挡住），
        // 否则玩家以为"不能上下移动"是 bug。
        final v = _game.vehicles[_selectedVehicle!];
        final canTurn = v.tier.stats.ability == SpecialAbility.turn;
        final wrongAxis = !canTurn &&
            v.length > 1 &&
            ((v.orientation == ParkingOrientation.horizontal &&
                    row != v.row) ||
                (v.orientation == ParkingOrientation.vertical &&
                    col != v.col));
        if (wrongAxis) {
          _showToast(v.orientation == ParkingOrientation.horizontal
              ? '↔️ 横车只能左右滑'
              : '↕️ 竖车只能上下滑');
        } else {
          _showToast('🚧 前方被挡住了');
        }
        // 滑不动的失败反馈：error 音 + 拒绝触感，配合 toast 明确告知。
        _audio.play(Sfx.error);
        unawaited(_audio.reject());
      }
    } else {
      final v = _game.vehicleAt(row, col);
      if (v != null && !v.parked) {
        // 道具使用在车辆上
        if (_activeItem == 'spring' || _activeItem == 'balloon' || _activeItem == 'doubleMove') {
          _selectedVehicle = v.index;
          _useItemOnCell(v.row, v.col);
          return;
        }
        setState(() => _selectedVehicle = v.index);
        _audio.play(Sfx.tick);
        unawaited(_audio.tap());
      }
    }
  }

  /// 是否已结算过（胜利/失败的奖励与解锁只落盘一次）。
  bool _settled = false;
  int _lastStars = 0;
  int _lastReward = 0;

  /// 本次胜利是否首次点亮目标车型图鉴（用于通关卡片提示）。
  bool _collectionNew = false;
  int _collectionBonus = 0;

  /// 本次 3 星通关奖励的合成道具卡 key（'time'/'cards'/'double'），null 表示未奖励。
  String? _boosterKey;

  /// 每日挑战连续通关额外奖励（>0 时显示在结果卡片）。
  int _dailyStreakBonus = 0;

  static const Map<String, String> _boosterLabels = {
    'time': '🕐 加时卡',
    'cards': '📦 补卡卡',
    'double': '🎲 双倍卡',
  };

  void _settleWin() {
    if (_settled) return;
    _settled = true;
    _winStreak++;
    final stars = _game.calcStars();
    var reward = GameConfig.parkingBaseReward + stars * GameConfig.parkingStarReward;
    _lastStars = stars;
    _lastReward = reward;

    // 每日挑战奖励
    if (widget.isDaily) {
      final today = ParkingDailyChallenge.todayKey;
      if (widget.data.dailyClearedDate != today) {
        widget.data.dailyClearedDate = today;
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        final streak = widget.data.dailyLastDate == yKey
            ? widget.data.dailyStreak + 1
            : 1;
        widget.data.dailyStreak = streak;
        widget.data.dailyLastDate = today;
        final dailyBonus = ParkingDailyChallenge.reward + ParkingDailyChallenge.streakBonus(streak);
        reward += dailyBonus;
        _lastReward = reward;
        if (streak >= 3) {
          _dailyStreakBonus = ParkingDailyChallenge.streakBonus(streak);
        }
      }
    }

    widget.data.addCoins(reward);

    // 图鉴接入：通关停车关卡即点亮目标车型（与合成游戏共享同一套交通图鉴）。
    _collectionNew = widget.data.collection.add(widget.level.targetTier.index);
    if (_collectionNew) {
      _collectionBonus = GameConfig.parkingCollectionReward;
      widget.data.addCoins(_collectionBonus);
    }

    if (widget.level.id >= widget.data.parkingUnlocked) {
      widget.data.parkingUnlocked = widget.level.id + 1;
    }
    final prev = widget.data.parkingBestStars[widget.level.id] ?? 0;
    if (stars > prev) widget.data.parkingBestStars[widget.level.id] = stars;

    // 双向联动：3 星通关额外奖励一张合成可用道具卡（加时/补卡/双倍轮换）。
    // 这些卡在合成开局会自动消耗（见 GameScreen._applyBoosters），形成停车→合成的回馈环。
    if (stars >= 3) {
      const boosterTypes = ['time', 'cards', 'double'];
      final key = boosterTypes[widget.level.id % boosterTypes.length];
      widget.data.boosters[key] = (widget.data.boosters[key] ?? 0) + 1;
      _boosterKey = key;
    }

    widget.repo.save(widget.data);
    _analytics.parkingEnd(
        level: widget.level.id, won: true, stars: stars, reward: reward);
    _audio.play(Sfx.win);
    unawaited(_audio.success());
  }

  void _settleLose() {
    if (_settled) return;
    _settled = true;
    _winStreak = 0;
    widget.repo.save(widget.data);
    _audio.play(Sfx.lose);
    unawaited(_audio.fail());
  }

  void _resetGame() {
    _game.reset();
    _game.clearMarks();
    setState(() {
      _settled = false;
      _collectionNew = false;
      _collectionBonus = 0;
      _boosterKey = null;
      _dailyStreakBonus = 0;
      _hintVehicle = null;
      _hintCells = const [];
      _activeItem = null;
      _doubleMoveActive = false;
      _markMode = false;
    });
  }

  /// 撤销 3 步：有撤销卡消耗一张，没有则看广告。
  void _useUndo() {
    if (_game.hasWon || _game.hasLost) return;
    if (!_game.canUndo) {
      _showToast('没有可撤销的操作');
      return;
    }
    _activeItem = null;
    _doubleMoveActive = false;
    final stock = widget.data.boosters['undo'] ?? 0;
    if (stock > 0) {
      setState(() => widget.data.boosters['undo'] = stock - 1);
      widget.repo.save(widget.data);
      final n = _game.undoMoves(3);
      _analytics.toolUse('undo', 0, widget.data.coins);
      _audio.play(Sfx.undo);
      _showToast('↩️ 撤销卡 · 回退 $n 步');
      return;
    }
    // 无撤销卡：看广告回退 3 步（模拟广告，接 SDK 后替换为真实播放）。
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🧯 撤销卡不足', textAlign: TextAlign.center),
        content: const Text(
          '看一条广告，立即回退 3 步。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!_game.canUndo) return;
              _analytics.toolUse('ad_undo', 0, widget.data.coins);
              final n = _game.undoMoves(3);
              _audio.play(Sfx.undo);
              _showToast('🎬 广告撤销 · 回退 $n 步');
            },
            icon: const Icon(Icons.play_circle_fill),
            label: const Text('🎬 看广告'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 提示：每次都需看广告解锁。
  void _requestHint() {
    if (_game.hasWon || _game.hasLost) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💡 获取提示', textAlign: TextAlign.center),
        content: const Text(
          '看一条广告，解锁下一步最优走法。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _analytics.toolUse('ad_hint', 0, widget.data.coins);
              _applyHint();
            },
            icon: const Icon(Icons.play_circle_fill),
            label: const Text('🎬 看广告'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _applyHint() {
    final h = _game.hint();
    setState(() {
      _hintVehicle = h?.vehicleIndex;
      // 计算建议落点的整块格（长条车为多格），用于青色高亮。
      if (h != null) {
        final v = _game.vehicles[h.vehicleIndex];
        _hintCells = List.generate(v.length, (i) {
          return v.orientation == ParkingOrientation.horizontal
              ? (h.toRow, h.toCol + i)
              : (h.toRow + i, h.toCol);
        });
        _audio.play(Sfx.tick);
      } else {
        _hintCells = const [];
      }
    });
    if (h == null) {
      // 无解提示：error 音 + 拒绝触感，别让玩家觉得"点了没反应"。
      _audio.play(Sfx.error);
      unawaited(_audio.reject());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时找不到解法，试试撤销或重置'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showHelpDialog() {
    // 帮助弹窗打开时停表（用户在读说明，不该被扣时间）。
    _game.pauseTimer();
    CandyDialog.show<void>(
      context,
      emoji: '🅿️',
      color: AppColors.mint,
      title: '停车模式',
      confirmLabel: '知道了',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '目标：把 ${widget.level.targetTier.icon} ${widget.level.targetTier.name} 开进虚线车位',
              style: const TextStyle(
                  color: AppColors.ink1, fontWeight: FontWeight.w800)),
          const Text('（车位上停着同款半透明"幽灵车"，就是它）',
              style: TextStyle(color: AppColors.ink2, fontSize: 12)),
          const SizedBox(height: 10),
          _helpLine('点击一辆车选中（金色边框）'),
          _helpLine('点击空地或车位 — 直线滑行过去'),
          _helpLine('碰到 🧱 障碍和其他车会停下'),
          _helpLine('其他车是障碍，拖开它们让路'),
          _helpLine('横/竖长车只能沿车身方向滑动'),
          _helpLine('可以撤销、重置，别怕试错'),
        ],
      ),
    ).then((_) {
      if (mounted) _game.resumeTimer();
    });
  }

  /// 帮助文案行：统一行距与色阶，避免像一堵字墙。
  Widget _helpLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.ink2, fontSize: 13, height: 1.35)),
            ),
          ],
        ),
      );

  /// 暂停弹窗：停表并给继续/重开/主页（与合成模式同一套交互）。
  Future<void> _showPauseDialog() async {
    AudioFeedback.uiTap();
    _game.pauseTimer();
    final action = await CandyChoiceDialog.show<String>(
      context,
      emoji: '☕',
      title: '暂停中',
      message: '不急，慢慢想下一步',
      accent: AppColors.grape,
      options: <CandyChoice<String>>[
        const CandyChoice<String>(
            label: '继续游戏',
            value: 'resume',
            icon: Icons.play_arrow_rounded,
            highlight: true),
        const CandyChoice<String>(
            label: '重新开始', value: 'restart', icon: Icons.refresh_rounded),
        const CandyChoice<String>(
            label: '返回主页', value: 'home', icon: Icons.home_rounded),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'restart':
        _resetGame();
      case 'home':
        Navigator.of(context).pop();
      default:
        _game.resumeTimer();
    }
  }

  /// 底栏「重置」先确认：一步误触不该清空整盘步数与标记。
  Future<void> _confirmReset() async {
    AudioFeedback.uiTap();
    _game.pauseTimer();
    final confirmed = await CandyDialog.show<bool>(
      context,
      emoji: '🔄',
      color: AppColors.grape,
      title: '重新开始本关？',
      message: '当前步数与标记会全部清空。',
      confirmLabel: '重开',
      confirmValue: true,
      cancelLabel: '取消',
      cancelValue: false,
    );
    if (!mounted) return;
    if (confirmed == true) {
      _resetGame();
    } else {
      _game.resumeTimer();
    }
  }

  /// 系统返回/手势：对局中先确认，防误退丢进度。
  Future<void> _handleBack() async {
    if (_game.hasWon || _game.hasLost) {
      Navigator.of(context).pop();
      return;
    }
    _game.pauseTimer();
    final quit = await CandyDialog.show<bool>(
      context,
      emoji: '🚪',
      color: AppColors.grape,
      title: '退出本关？',
      message: '这一局的进度会丢掉哦。',
      confirmLabel: '继续玩',
      confirmValue: false,
      cancelLabel: '退出',
      cancelValue: true,
    );
    if (!mounted) return;
    if (quit == true) {
      Navigator.of(context).pop();
    } else {
      _game.resumeTimer();
    }
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
          child: SafeArea(
            child: Stack(
              children: [
                isLandscape
                    ? _buildLandscapeLayout()
                    : _buildPortraitLayout(),
                if (_game.hasWon || _game.hasLost)
                  _buildResultOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final won = _game.hasWon;
    final nextId = widget.level.id + 1;
    // 下一关仅在「胜利」且「未超出总关数」且「下一关所属章节已解锁」时可用。
    // 边界保护：L800 通关后不能再生成 L801（章节表只到 800）。
    final canNext = won &&
        nextId <= ParkingChapters.totalLevels &&
        ParkingChapters.isAccessible(
          ParkingChapters.chapterForId(nextId),
          widget.data.collection,
          widget.data.parkingBestStars,
        );
    return Container(
      color: Colors.black54,
      child: Stack(
        children: [
          if (won) const WinConfetti(),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              builder: (context, t, child) {
                final scale = 0.82 + 0.18 * Curves.elasticOut.transform(t);
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: _buildResultCard(won, canNext),
            ),
          ),
        ],
      ),
    );
  }

  /// 结算卡：胜/负共用一张糖卡，只在颜色与文案上区分。
  /// 失败不用红色警示——「这一局卡住了」比「失败」听起来更容易再来一次。
  Widget _buildResultCard(bool won, bool canNext) {
    final accent = won ? AppColors.mint : AppColors.grape;
    return Container(
      margin: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceLight,
            Color.lerp(accent, Colors.white, 0.92)!,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withValues(alpha: 0.34), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部彩带头：一句话结果 + 车-icon，情绪的第一落点。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, AppTheme.deepen(accent, 0.14)],
                ),
              ),
              child: Column(
                children: [
                  Text(won ? '🎉' : '🤔', style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      VehicleImage(
                          vehicle: widget.level.targetTier, size: 26),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          won ? '停好啦！' : '这一局卡住了',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (won)
                    _buildStarsRow()
                  else
                    const Text('没有可走的移动了 · 撤销一步或换个思路试试',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.ink2, fontSize: 13)),
                  const SizedBox(height: 10),
                  Text(
                    '步数 ${_game.moves} · 用时 ${_game.elapsedSeconds}s',
                    style: const TextStyle(
                        color: AppColors.ink2,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                  // 奖励行：统一 chip 化，颜色按奖励类型分（金币/图鉴/道具/连胜）。
                  if (won) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        SoftChip(
                          label: '金币 +$_lastReward 🪙',
                          color: AppColors.sun,
                          solid: true,
                        ),
                        if (_collectionNew)
                          SoftChip(
                            label: '📖 图鉴点亮 +$_collectionBonus 🪙',
                            color: AppColors.mint,
                            solid: true,
                          ),
                        if (_boosterKey != null)
                          SoftChip(
                            label: '🎁 ${_boosterLabels[_boosterKey]!}',
                            color: AppColors.grape,
                            solid: true,
                          ),
                        if (_dailyStreakBonus > 0)
                          SoftChip(
                            label: '🔥 连续 +${ParkingDailyChallenge.reward + _dailyStreakBonus} 🪙',
                            color: AppColors.melon,
                            solid: true,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // 失败且有撤销空间：把"救回来"放在最上面，降低重开成本。
                  // 广告挑战关换一套文案：说破「这关就是设计成难一档的，
                  // 看广告是官方给的后路」，玩家就不会因为连败而弃游。
                  if (!won && _game.canUndo) ...[
                    CandyButton(
                      label: LevelProgression.isParkingAdGate(widget.level.id)
                          ? '🎬 挑战支援 · 看广告回退 3 步'
                          : '看广告回退 3 步',
                      icon: Icons.play_circle_fill,
                      colors: AppTheme.gradientOf(AppColors.mint),
                      expand: true,
                      onTap: () {
                        // 模拟观看广告：回退 3 步并解除判负（步数/时间随之返还）。
                        _analytics.toolUse('ad_undo', 0, widget.data.coins);
                        final n = _game.undoMoves(3);
                        _settled = false;
                        setState(() {});
                        _audio.play(Sfx.undo);
                        _showToast('🎬 广告撤销 · 回退 $n 步');
                      },
                    ),
                    const SizedBox(height: 9),
                  ],
                  if (canNext)
                    CandyButton(
                      label: '下一关 ▶',
                      icon: Icons.skip_next_rounded,
                      colors: AppTheme.gradientOf(AppColors.mint),
                      expand: true,
                      onTap: _goNext,
                    )
                  else
                    CandyButton(
                      label: won ? '再玩一次' : '重玩本关',
                      icon: Icons.refresh_rounded,
                      colors: AppTheme.gradientOf(AppColors.coral),
                      expand: true,
                      onTap: _resetGame,
                    ),
                  const SizedBox(height: 9),
                  CandyButton(
                    label: '返回',
                    icon: Icons.home_rounded,
                    colors: AppTheme.softGradient,
                    expand: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 胜利星星逐颗弹出（stagger）。
  Widget _buildStarsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final earned = i < _lastStars;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 520),
          curve: Curves.linear,
          builder: (_, t, _) {
            final start = i * 0.22;
            final local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
            final eased = Curves.elasticOut.transform(local);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: earned ? eased : 1.0,
                child: Icon(
                  earned ? Icons.star : Icons.star_border,
                  color: earned ? const Color(0xFFFFD54F) : AppColors.ink3.withValues(alpha: 0.4),
                  size: 28,
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _goNext() {
    final nextId = widget.level.id + 1;
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ParkingScreen(
        level: ParkingLevelGenerator.generateOne(nextId),
        data: widget.data,
        repo: widget.repo,
      ),
    ));
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHud(),
        Expanded(child: Center(child: _buildBoard())),
        _buildToast(),
        _buildActionBar(),
      ],
    );
  }

  /// 操作反馈条：点错方向/被挡时给一句话解释，2 秒自动消失。
  Widget _buildToast() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      child: _toast == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.ink1.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _toast!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(child: Center(child: _buildBoard())),
        Container(
          width: 156,
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHud(),
              const Spacer(),
              _buildActionBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            color: AppColors.mint,
            onTap: () {
              AudioFeedback.uiTap();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildInfoChip(
                      '🚗 ${widget.isDaily ? '每日挑战' : widget.level.name}', AppColors.accent),
                  const SizedBox(width: 6),
                  // 常驻目标提示：把哪辆车开到车位（车型色底 + 真实车模，
                  // 与棋盘上的幽灵车位同一套视觉语言）。
                  _buildTargetChip(widget.level.targetTier),
                  const SizedBox(width: 6),
                  // 难度心跳标记：告诉玩家这一关在本轮 6 关里的位置。
                  // 看到「尖峰」会下意识认真一点，看到「轻松」则放松点两下 ——
                  // 节奏被说破了才真正起作用。
                  _buildInfoChip(
                    '${LevelRhythm.nameOf(RhythmMode.parking, _phase)} '
                    '${widget.level.minMoves ?? 0} 步起',
                    LevelRhythm.colorOf(RhythmMode.parking, _phase),
                  ),
                  const SizedBox(width: 6),
                  // 广告挑战关标记：🎬 说明这一关比同位置难一档，
                  // 同时暗示「失败了有后路」——失败弹窗的看广告续命/撤销/提示
                  // 就是为它准备的降难支援。说破了，玩家才敢点进来。
                  if (LevelProgression.isParkingAdGate(widget.level.id)) ...[
                    _buildInfoChip('🎬 挑战关', AppColors.coralDeep),
                    const SizedBox(width: 6),
                  ],
                  _buildInfoChip('👣 ${_game.moves}', AppColors.surfaceSoft),
                  const SizedBox(width: 6),
                  // 撤销卡库存（替代原生命值展示）
                  Builder(builder: (context) {
                    final undoStock = widget.data.boosters['undo'] ?? 0;
                    return _buildInfoChip('🧯 x$undoStock', AppColors.surfaceSoft);
                  }),
                  if (_winStreak > 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCA28).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🔥 x$_winStreak',
                        style: const TextStyle(
                          color: Color(0xFFFFCA28),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  if (widget.level.timeLimit != null) ...[
                    const SizedBox(width: 6),
                    _buildInfoChip(
                      '⏱ ${_game.timeLeft}s',
                      _game.timeLeft! <= 10
                          ? const Color(0xFFE53935)
                          : AppColors.surfaceSoft,
                    ),
                  ],
                  const SizedBox(width: 6),
                  RoundIconButton(
                    icon: Icons.pause_circle_outline,
                    color: AppColors.grape,
                    onTap: _game.hasWon || _game.hasLost
                        ? null
                        : _showPauseDialog,
                  ),
                  const SizedBox(width: 6),
                  RoundIconButton(
                    icon: Icons.help_outline_rounded,
                    color: AppColors.sky,
                    onTap: () {
                      AudioFeedback.uiTap();
                      _showHelpDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// HUD 信息 chip：统一糖果质感（白 stacked 描边 + 顶部高光 + 同色柔投影），
  /// 替代原先的纯实色方块——实色方块在浅色背景上压得很重，容易抢棋盘注意力。
  Widget _buildInfoChip(String label, Color color) {
    final isLight = color.computeLuminance() > 0.72;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: _chipDecoration(color),
      child: Text(
        label,
        style: TextStyle(
          color: isLight ? AppColors.ink1 : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  /// 目标车 chip：把「🎯 车模 → 🅿」做成一条，车模用真实 PNG，
  /// 和棋盘上的目标车/幽灵车位是同一张图。
  Widget _buildTargetChip(VehicleType tier) {
    final color = tier.color;
    final isLight = color.computeLuminance() > 0.72;
    final ink = isLight ? AppColors.ink1 : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: _chipDecoration(color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          VehicleImage(vehicle: tier, size: 20),
          Text(
            '→ 🅿',
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _chipDecoration(Color color) => BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.42)!,
            color,
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _buildItemButton(String key, String icon, String label, Color color) {
    final count = widget.data.boosters[key] ?? 0;
    return Pressable(
      onTap: count > 0 ? () => _activateItem(key) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: count > 0 ? color.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _activeItem == key ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            Text(
              '$label ×$count',
              style: TextStyle(
                fontSize: 11,
                color: count > 0 ? AppColors.ink2 : AppColors.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _activateItem(String key) {
    final count = widget.data.boosters[key] ?? 0;
    if (count <= 0) return;
    
    setState(() {
      _activeItem = (_activeItem == key) ? null : key; // Toggle
      _selectedVehicle = null;
      _hintVehicle = null;
      _hintCells = [];
    });
  }

  void _useItemOnCell(int row, int col) {
    if (_activeItem == null) return;
    final key = _activeItem!;
    final count = widget.data.boosters[key] ?? 0;
    if (count <= 0) {
      // 数量耗尽自动退出道具模式，避免点击全部被道具分支吞掉导致棋盘无响应。
      setState(() => _activeItem = null);
      return;
    }
    
    bool used = false;
    int? removedIdx;
    
    switch (key) {
      case 'bomb':
        removedIdx = _game.useBomb(row, col);
        used = removedIdx >= 0;
        break;
      case 'spring':
        if (_selectedVehicle != null) {
          final pos = _game.useSpring(_selectedVehicle!);
          used = pos.$1 >= 0;
          _selectedVehicle = null;
        }
        break;
      case 'balloon':
        if (_selectedVehicle != null) {
          final pos = _game.useBalloon(_selectedVehicle!, row, col);
          used = pos.$1 >= 0;
          _selectedVehicle = null;
        }
        break;
      case 'key':
        used = _game.useKey(row, col);
        break;
      case 'hammer':
        removedIdx = _game.useHammer(row, col);
        used = removedIdx >= 0;
        break;
      case 'doubleMove':
        if (_selectedVehicle != null) {
          _doubleMoveActive = true;
          _activeItem = null; // 激活完成，退出道具模式，后续点击走正常移动
          used = true; // Will be consumed on next move
        }
        break;
    }
    
    if (used) {
      widget.data.boosters[key] = count - 1;
      widget.repo.save(widget.data);
      _audio.play(Sfx.place);
      unawaited(_audio.merge());
      setState(() {});
    }
    
    // Clear item mode after use (except spring/balloon which need vehicle selection first)
    if (key != 'spring' && key != 'balloon') {
      setState(() => _activeItem = null);
    }
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // 道具按钮（仅在停车模式可用）
          if (!_game.hasWon && !_game.hasLost) ...[
            // 标记模式切换
            Pressable(
              onTap: () => setState(() {
                _markMode = !_markMode;
                _activeItem = null;
                _selectedVehicle = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: _markMode ? const Color(0xFFFFCA28).withValues(alpha: 0.2) : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _markMode ? const Color(0xFFFFCA28) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🏷️', style: const TextStyle(fontSize: 16)),
                    Text(
                      '标记',
                      style: TextStyle(
                        fontSize: 11,
                        color: _markMode ? const Color(0xFFFFCA28) : AppColors.ink2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // 道具身份色与商店统一到糖果色板（原先是各自随手的 Material 原色）。
            _buildItemButton('bomb', '💣', '炸弹', AppColors.melon),
            const SizedBox(width: 6),
            _buildItemButton('spring', '🌀', '弹簧', AppColors.forest),
            const SizedBox(width: 6),
            _buildItemButton('balloon', '🎈', '气球', AppColors.sky),
            const SizedBox(width: 6),
            _buildItemButton('key', '🔑', '钥匙', AppColors.lemon),
            const SizedBox(width: 6),
            _buildItemButton('hammer', '🔨', '锤子', AppColors.cocoa),
            const SizedBox(width: 6),
            _buildItemButton('doubleMove', '↔️', '双倍', AppColors.taro),
            const SizedBox(width: 12),
          ],
          CandyButton(
            label: _game.canUndo ? '撤销 3 步' : '撤销',
            icon: Icons.undo_rounded,
            colors: AppTheme.softGradient,
            size: CandyButtonSize.small,
            dense: true,
            onTap: _useUndo,
          ),
          const SizedBox(width: 8),
          CandyButton(
            label: '提示',
            icon: Icons.lightbulb_outlined,
            colors: AppTheme.gradientOf(AppColors.coral),
            size: CandyButtonSize.small,
            dense: true,
            onTap: _requestHint,
          ),
          const SizedBox(width: 8),
          CandyButton(
            label: '重置',
            icon: Icons.refresh_rounded,
            colors: AppTheme.softGradient,
            size: CandyButtonSize.small,
            dense: true,
            onTap: _confirmReset,
          ),
          if (_game.hasWon || _game.hasLost) ...[
            const SizedBox(width: 8),
            CandyButton(
              label: '完成',
              icon: Icons.check_rounded,
              colors: AppTheme.gradientOf(AppColors.mint),
              size: CandyButtonSize.small,
              dense: true,
              onTap: () {
                AudioFeedback.uiTap();
                Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
      ),
    );
  }

  /// 棋盘：躺在一块"糖霜托盘"上（原本是裸叠 Strokes 在背景上，像线框图）。
  /// 托盘只做外框与内边距，不参与坐标计算——棋盘内所有定位都以自身尺寸为准。
  Widget _buildBoard() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: AppTheme.frostedPanel(accent: AppColors.mint, radius: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableSize = math.min(
            constraints.maxWidth,
            constraints.maxHeight,
          );
        final cellSize = (availableSize / math.max(_game.rows, _game.cols))
            .clamp(56.0, 140.0);
        final boardW = _game.cols * cellSize;
        final boardH = _game.rows * cellSize;
        final hasHints = widget.level.rowHints != null || widget.level.colHints != null;
        final hintSize = cellSize * 0.35;

        return SizedBox(
          width: boardW + (hasHints ? hintSize + 4 : 0),
          height: boardH + (hasHints ? hintSize + 4 : 0),
          child: Stack(
            children: [
              // 行列约束提示（扫雷风格）
              if (hasHints) ...[
                // 顶部列提示
                if (widget.level.colHints != null)
                  Positioned(
                    left: hasHints ? hintSize + 4 : 0,
                    top: 0,
                    width: boardW,
                    height: hintSize,
                    child: Row(
                      children: List.generate(_game.cols, (c) {
                        final hint = widget.level.colHints![c];
                        return SizedBox(
                          width: cellSize,
                          child: Center(
                            child: hint != null
                                ? Text(
                                    '$hint',
                                    style: TextStyle(
                                      fontSize: hintSize * 0.6,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.ink2,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),
                  ),
                // 左侧行提示
                if (widget.level.rowHints != null)
                  Positioned(
                    left: 0,
                    top: hasHints ? hintSize + 4 : 0,
                    width: hintSize,
                    height: boardH,
                    child: Column(
                      children: List.generate(_game.rows, (r) {
                        final hint = widget.level.rowHints![r];
                        return SizedBox(
                          height: cellSize,
                          child: Center(
                            child: hint != null
                                ? Text(
                                    '$hint',
                                    style: TextStyle(
                                      fontSize: hintSize * 0.6,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.ink2,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
              // 底层：格子（背景/障碍/车位/入口），并接收点击。
              Positioned(
                left: hasHints ? hintSize + 4 : 0,
                top: hasHints ? hintSize + 4 : 0,
                width: boardW,
                height: boardH,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_game.rows, (r) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_game.cols, (c) {
                        return _buildCell(r, c, cellSize);
                      }),
                    );
                  }),
                ),
              ),
              // 目标车位幽灵车：把目标车按真实车身形状半透明画在停车位上，
              // 玩家一眼看懂"哪辆车停进哪里"。
              if (!_game.hasWon && !_game.hasLost)
                _buildParkingSlotGhost(cellSize,
                    offsetX: hasHints ? hintSize + 4 : 0,
                    offsetY: hasHints ? hintSize + 4 : 0),
              // 覆盖层：车辆（长条车画成一整块），IgnorePointer 让点击穿透到格子。
              for (final v in _game.vehicles)
                _buildVehicleOverlay(v, cellSize,
                    offsetX: hasHints ? hintSize + 4 : 0,
                    offsetY: hasHints ? hintSize + 4 : 0),
            ],
          ),
        );
        },
      ),
    );
  }

  /// 车辆覆盖层：长条车按占用格数绘制成一整块圆角车身（含车图标居中）。
  /// 颜色按车型(tier)取，颜色即"车的身份"，玩家可凭色辨认不同车。
  Widget _buildVehicleOverlay(VehicleState v, double size, {double offsetX = 0, double offsetY = 0}) {
    final isSelected = v.index == _selectedVehicle;
    final isHint = v.index == _hintVehicle;
    final w = (v.orientation == ParkingOrientation.horizontal ? v.length : 1) *
        size;
    final h = (v.orientation == ParkingOrientation.vertical ? v.length : 1) *
        size;
    final left = v.col * size;
    final top = v.row * size;
    final inset = size * 0.06;
    final isTarget = v.tier == widget.level.targetTier;

    final borderColor = isSelected
        ? const Color(0xFFFFD54F)
        : (isHint
            ? const Color(0xFF26C6DA)
            : (isTarget ? const Color(0xFFFBC02D) : v.tier.color.withValues(alpha: 0.55)));
    final borderWidth = (isSelected || isHint || isTarget) ? 3.0 : 1.0;
    return AnimatedPositioned(
      key: ValueKey(v.index),
      duration: _kVehicleSlide,
      curve: Curves.easeOutCubic,
      left: left + inset + offsetX,
      top: top + inset + offsetY,
      width: w - 2 * inset,
      height: h - 2 * inset,
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  // 车型色光晕：让精致车模更立体、更"影棚"。
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size * 0.2),
                      gradient: RadialGradient(
                        center: const Alignment(0.5, 0.42),
                        radius: 0.78,
                        colors: [
                          v.tier.color.withValues(alpha: 0.36),
                          v.tier.color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // 玻璃卡槽 + 柔和投影
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size * 0.18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          v.tier.color.withValues(alpha: 0.28),
                          v.tier.color.withValues(alpha: 0.10),
                        ],
                      ),
                      border: Border.all(color: borderColor, width: borderWidth),
                      // 目标车追加金色光晕，与幽灵车位遥相呼应。
                      boxShadow: isTarget
                          ? const [
                              BoxShadow(
                                color: Color(0x88FBC02D),
                                blurRadius: 12,
                                offset: Offset(0, 3),
                              ),
                            ]
                          : const [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                    ),
                    child: ParkingVehicleBody(
                      tier: v.tier,
                      length: v.length,
                      horizontal:
                          v.orientation == ParkingOrientation.horizontal,
                      cellSize: size,
                    ),
                  ),
                ],
              ),
            ),
            // 目标车标记：提示玩家"把这部停进去"。
            if (isTarget)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.06,
                    vertical: size * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F),
                    borderRadius: BorderRadius.circular(size * 0.1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text('🎯', style: TextStyle(fontSize: size * 0.18)),
                ),
              ),
            // 双倍卡充能标记：本车下一步可连滑两次。
            if (_doubleMoveActive && isSelected)
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.06,
                    vertical: size * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAB47BC),
                    borderRadius: BorderRadius.circular(size * 0.1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text('🎲×2', style: TextStyle(fontSize: size * 0.16)),
                ),
              ),
            // 长条车滑动方向指示：横车 ‹›、竖车 ˄˅。
            // 华容道规则：长车只能沿车身轴滑动；turn 能力车可任意向，不标。
            if (v.length > 1 && v.tier.stats.ability != SpecialAbility.turn) ...[
              if (v.orientation == ParkingOrientation.horizontal) ...[
                Positioned(
                  left: size * 0.02,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: _dirChevron(Icons.chevron_left, size)),
                ),
                Positioned(
                  right: size * 0.02,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: _dirChevron(Icons.chevron_right, size)),
                ),
              ] else ...[
                Positioned(
                  top: size * 0.02,
                  left: 0,
                  right: 0,
                  child: Center(
                      child: _dirChevron(Icons.expand_less, size)),
                ),
                Positioned(
                  bottom: size * 0.02,
                  left: 0,
                  right: 0,
                  child: Center(
                      child: _dirChevron(Icons.expand_more, size)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 方向指示小圆标（半透明黑底白箭头，不抢车身视觉）。
  Widget _dirChevron(IconData icon, double size) {
    return Container(
      width: size * 0.24,
      height: size * 0.24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: size * 0.18,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  /// 目标车位"幽灵车"：目标车按真实车身形状（长度/朝向一致）半透明停进
  /// 虚线车位框，配呼吸脉冲 —— 解决"目标车位要停什么车看不出来"。
  Widget _buildParkingSlotGhost(double size,
      {double offsetX = 0, double offsetY = 0}) {
    if (_parkingCell.$1 < 0) return const SizedBox.shrink();
    final tier = widget.level.targetTier;
    // 目标车的真实形状（长度/朝向），幽灵车与棋盘上的实际车一模一样。
    VehicleSpawn spawn;
    try {
      spawn = widget.level.vehicles.firstWhere((v) => v.tier == tier);
    } catch (_) {
      spawn = VehicleSpawn(col: 0, row: 0, tier: tier);
    }
    final len = spawn.length;
    final horiz = spawn.orientation == ParkingOrientation.horizontal;
    final w = (horiz ? len : 1) * size;
    final h = (horiz ? 1 : len) * size;

    return Positioned(
      left: _parkingCell.$2 * size + offsetX,
      top: _parkingCell.$1 * size + offsetY,
      width: w,
      height: h,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          opacity: _ghostPulse ? 0.50 : 0.92,
          child: Stack(
            children: [
              // 虚线车位框（车型色）。
              Positioned.fill(
                child: CustomPaint(
                  painter: _SlotDashesPainter(tier.color),
                ),
              ),
              // 半透明同款车身。
              Positioned.fill(
                child: Opacity(
                  opacity: 0.55,
                  child: ParkingVehicleBody(
                    tier: tier,
                    length: len,
                    horizontal: horiz,
                    cellSize: size,
                  ),
                ),
              ),
              // 车位角标。
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.05,
                    vertical: size * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: tier.color,
                    borderRadius: BorderRadius.circular(size * 0.1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text('🅿',
                      style: TextStyle(
                        fontSize: size * 0.18,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 停车模式车辆卡：矢量绘制的车身（高光 + 车窗 + 车轮 + 车灯），
  /// 颜色由车型决定，整体比纯渐变块更有质感、更像"一张车卡"。
  Widget _buildCell(int row, int col, double size) {
    final cell = _game.cellAt(row, col);
    final vehicle = _game.vehicleAt(row, col);

    // 背景色
    Color bg;
    switch (cell.type) {
      case ParkingCellType.road:
        bg = AppColors.surfaceSoft;
        break;
      case ParkingCellType.parking:
        // 车位底色用目标车型色（与幽灵车同色系，强化"这停这辆车"）。
        bg = widget.level.targetTier.color.withValues(alpha: 0.16);
        break;
      case ParkingCellType.obstacle:
        bg = AppColors.ink3.withValues(alpha: 0.18);
        break;
      case ParkingCellType.entrance:
        bg = AppColors.sky.withValues(alpha: 0.30);
        break;
      case ParkingCellType.exit:
        bg = AppColors.grape.withValues(alpha: 0.30);
        break;
    }

    // 提示落点格（仅空格）：叠加青色半透明高亮底。
    final isHintTarget = _hintCells.contains((row, col)) && vehicle == null;
    if (isHintTarget) {
      bg = Color.lerp(bg, AppColors.hint, 0.45)!;
    }
    // 每格加一点点内发光：上边高光、下边投影，让格子像"扣出来的糖砖"。
    final isRoad = cell.type == ParkingCellType.road;
    return Pressable(
      behavior: HitTestBehavior.opaque,
      key: ValueKey('cell-$row-$col'),
      onTap: () => _handleCellTap(row, col),
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(bg, Colors.white, isRoad ? 0.55 : 0.40)!,
                    bg,
                  ],
                ),
                border: Border.all(
                  color: isHintTarget
                      ? AppColors.hint
                      : AppColors.ink3.withValues(alpha: 0.20),
                  width: isHintTarget ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _buildCellContent(cell, vehicle, size),
            ),
            // 标记覆盖层
            if (_game.getMark(row, col) != null)
              Positioned.fill(
                child: Center(
                  child: Text(
                    _game.getMark(row, col) == 'x' ? '❌' :
                    _game.getMark(row, col) == '!' ? '❗' : '❓',
                    style: TextStyle(fontSize: size * 0.5),
                  ),
                ),
              ),
          ],
        ),
    );
  }

  Widget? _buildCellContent(ParkingCell cell, VehicleState? vehicle, double size) {
    // 车辆图标由覆盖层 _buildVehicleOverlay 统一绘制，这里只画地形标记。
    // 障碍图标
    if (cell.isObstacle) {
      return const Center(
        child: Text('🧱', style: TextStyle(fontSize: 18)),
      );
    }
    // 停车位：幽灵车由 _buildParkingSlotGhost 在棋盘层绘制，这里不再画 emoji。
    if (cell.isParking) {
      return null;
    }
    // 入口
    if (cell.isEntrance) {
      return const Center(child: Text('⬅️', style: TextStyle(fontSize: 14)));
    }
    // 出口
    if (cell.isExit) {
      return const Center(child: Text('🏁', style: TextStyle(fontSize: 14)));
    }

    return null;
  }
}


/// 车位虚线描边画笔：沿圆角矩形均匀画短划线，语义是"这是可停车位"。
class _SlotDashesPainter extends CustomPainter {
  final Color color;
  _SlotDashesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 12 || size.height < 12) return;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      Radius.circular(size.shortestSide * 0.18),
    );
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    // ~22 段虚线：短划 + 等长间隙。
    final dash = metric.length / 44;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var d = 0.0; d < metric.length; d += dash * 2) {
      canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0.0, metric.length)), paint);
    }
    // 内侧一层淡色填充，强化车位区域。
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(_SlotDashesPainter old) => old.color != color;
}

/// 胜利彩带：一次性下落的 emoji 粒子，stateless（固定种子保证重绘稳定、不掉帧）。
class WinConfetti extends StatelessWidget {
  const WinConfetti({super.key});

  static final List<_Confetto> _particles = _buildParticles();

  static List<_Confetto> _buildParticles() {
    final rand = math.Random(20260817);
    const emojis = ['🎉', '⭐', '✨', '🟢'];
    return List.generate(28, (i) {
      return _Confetto(
        xFrac: rand.nextDouble(),
        delay: rand.nextDouble() * 0.25,
        durMs: 900 + rand.nextInt(800),
        emoji: emojis[i % emojis.length],
        phase: rand.nextDouble() * math.pi * 2,
        size: 16 + rand.nextDouble() * 14,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return SizedBox.expand(
      child: Stack(
        children: [
          for (var i = 0; i < _particles.length; i++)
            _ConfettoWidget(p: _particles[i], index: i, w: w, h: h),
        ],
      ),
    );
  }
}

class _ConfettoWidget extends StatelessWidget {
  final _Confetto p;
  final int index;
  final double w;
  final double h;

  const _ConfettoWidget({
    required this.p,
    required this.index,
    required this.w,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: p.durMs),
      curve: Curves.easeIn,
      builder: (_, t, _) {
        final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
        final y = -34 + local * (h + 68);
        final opacity = (1 - local).clamp(0.0, 1.0);
        final x = p.xFrac * w + math.sin(local * 6 + p.phase) * 16;
        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
          ),
        );
      },
    );
  }
}

class _Confetto {
  final double xFrac;
  final double delay;
  final int durMs;
  final String emoji;
  final double phase;
  final double size;

  const _Confetto({
    required this.xFrac,
    required this.delay,
    required this.durMs,
    required this.emoji,
    required this.phase,
    required this.size,
  });
}

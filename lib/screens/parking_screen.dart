import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../game/audio_feedback.dart';
import '../game/game_config.dart';
import '../game/music_player.dart';
import '../game/parking_game.dart';
import '../models/parking_level.dart';
import '../save/save_repository.dart';
import '../services/parking_chapters.dart';
import '../services/parking_generator.dart';
import '../theme/app_theme.dart';

/// 车辆滑动动画时长（选车滑行 / 重置归位）。
const Duration _kVehicleSlide = Duration(milliseconds: 170);

/// 停车模式主屏
class ParkingScreen extends StatefulWidget {
  final ParkingLevel level;
  final PlayerData data;
  final SaveRepository repo;

  const ParkingScreen({
    super.key,
    required this.level,
    required this.data,
    required this.repo,
  });

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  late final ParkingGame _game;
  final AudioFeedback _audio = AudioFeedback();
  late final AnalyticsService _analytics;
  int? _selectedVehicle;
  int _tutorialStep = 0;
  bool _tutorialActive = false;

  /// 提示状态：被建议移动的车辆索引（用于高亮，null 表示未激活）。
  int? _hintVehicle;
  /// 提示目标落点的整块格集合（长条车为多格），用于青色高亮。
  List<(int, int)> _hintCells = const [];

  @override
  void initState() {
    super.initState();
    _analytics = AnalyticsService(widget.data, widget.repo);
    _game = ParkingGame(widget.level);
    _game.addListener(_onGameUpdate);
    // 音效/触感跟随全局开关。
    _audio.soundOn = widget.data.soundOn;
    _audio.vibrateOn = widget.data.vibrateOn;
    unawaited(_audio.load());
    // 停车模式首次进入弹出教学
    // 【2026-08-19 临时禁用】用户反馈新手教学无法使用，先去掉（代码保留可逆）。
    // if (!widget.data.tutorialCompleted.contains(-1)) {
    //   _tutorialActive = true;
    // }
    // 停车场景 BGM（跟随音效开关；返回首页由 home 的 didPopNext 恢复）。
    if (widget.data.soundOn) {
      MusicPlayer.instance.play(MusicPlayer.parking);
    }
  }

  void _onGameUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _game.removeListener(_onGameUpdate);
    _game.dispose();
    super.dispose();
  }

  void _handleCellTap(int row, int col) {
    if (_game.hasWon || _game.hasLost) return;

    if (_selectedVehicle != null) {
      // 沿车身方向滑到点击侧最远可达处（长条车只能沿轴滑动）。
      final moved = _game.slideTo(_selectedVehicle!, row, col);
      if (moved) {
        _audio.play(Sfx.move);
        setState(() {
          _selectedVehicle = null;
          _hintVehicle = null;
          _hintCells = const [];
        });
        _onPlayerAction('move');
        if (_game.hasWon) {
          _settleWin();
        } else if (_game.hasLost) {
          _settleLose();
        }
      }
    } else {
      final v = _game.vehicleAt(row, col);
      if (v != null && !v.parked) {
        setState(() => _selectedVehicle = v.index);
        _audio.play(Sfx.tick);
        unawaited(_audio.tap());
        _onPlayerAction('select');
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

  static const Map<String, String> _boosterLabels = {
    'time': '🕐 加时卡',
    'cards': '📦 补卡卡',
    'double': '🎲 双倍卡',
  };

  void _settleWin() {
    if (_settled) return;
    _settled = true;
    final stars = _game.calcStars();
    final reward = GameConfig.parkingBaseReward + stars * GameConfig.parkingStarReward;
    _lastStars = stars;
    _lastReward = reward;
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
    // 失败不解锁、不发奖，仅保底存盘。
    widget.repo.save(widget.data);
    _audio.play(Sfx.lose);
    unawaited(_audio.fail());
  }

  void _resetGame() {
    _game.reset();
    setState(() {
      _settled = false;
      _collectionNew = false;
      _collectionBonus = 0;
      _boosterKey = null;
      _hintVehicle = null;
      _hintCells = const [];
    });
  }

  void _undo() {
    if (!_game.canUndo) return;
    _game.undo();
    _audio.play(Sfx.undo);
  }

  void _requestHint() {
    if (_game.hasWon || _game.hasLost) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时找不到解法，试试撤销或重置'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPlayerAction(String action) {
    if (!_tutorialActive) return;
    if (_tutorialStep == 0 && action == 'select') {
      setState(() => _tutorialStep = 1);
    } else if (_tutorialStep == 1 && action == 'move') {
      // Check if the moved vehicle is the target and it reached parking
      if (_game.hasWon) {
        setState(() => _tutorialStep = 2);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _tutorialActive = false);
            widget.data.tutorialCompleted.add(-1);
            widget.repo.save(widget.data);
            _analytics.tutorialComplete('parking');
          }
        });
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🅿️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              '停车模式',
              style: const TextStyle(
                color: AppColors.ink1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('目标：把 ${widget.level.targetTier.icon} 停到 🟢 绿色车位上',
                style: const TextStyle(color: AppColors.ink1, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('• 点击一辆车选中（金色边框）', style: TextStyle(color: AppColors.ink2)),
            const Text('• 点击空地或车位 — 直线滑行过去', style: TextStyle(color: AppColors.ink2)),
            const Text('• 碰到 🧱 障碍和其他车会停下', style: TextStyle(color: AppColors.ink2)),
            const Text('• 其他车是障碍，拖开它们让路', style: TextStyle(color: AppColors.ink2)),
            const Text('• 可以撤销、重置', style: TextStyle(color: AppColors.ink2)),
            const Text('• 横/竖长车只能沿车身方向滑动，先挪开挡路的车', style: TextStyle(color: AppColors.ink2)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
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
              if (_tutorialActive)
                _buildParkingTutorial(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParkingTutorial() {
    final step0 = _tutorialStep == 0;
    final text = step0
        ? '点击车辆选中它（金色边框）'
        : (_tutorialStep == 1 ? '点击绿色车位 — 把车停进去' : '🎉 停车成功！');
    final bottomOffset = step0 ? 120.0 : 180.0;

    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 40, right: 16),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _tutorialActive = false;
                  _tutorialStep = 0;
                });
                widget.data.tutorialCompleted.add(-1);
                widget.repo.save(widget.data);
                _analytics.tutorialComplete('parking', skipped: true);
              },
              child: const Text(
                '跳过',
                style: TextStyle(color: AppColors.ink2, fontSize: 14),
              ),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.coral, AppColors.coralDeep],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.coralDeep.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: bottomOffset),
      ],
    );
  }

  Widget _buildResultOverlay() {
    final won = _game.hasWon;
    final nextId = widget.level.id + 1;
    // 下一关仅在「胜利」且「下一关所属章节已解锁」时可用。
    final canNext = won &&
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

  Widget _buildResultCard(bool won, bool canNext) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won ? '🎉' : '😞',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            won ? '停车成功!' : '失败',
            style: const TextStyle(
              color: AppColors.ink1,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (won)
            _buildStarsRow()
          else
            const Text('再试一次吧', style: TextStyle(color: AppColors.ink2)),
          const SizedBox(height: 8),
          Text(
            won
                ? '步数: ${_game.moves} | 时间: ${_game.elapsedSeconds}s'
                : '没有可用的移动了',
            style: const TextStyle(color: AppColors.ink2),
          ),
          if (won)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+$_lastReward 🪙',
                  style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w800)),
            ),
          if (won && _collectionNew)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '📖 图鉴点亮 ${widget.level.targetTier.icon} +$_collectionBonus 🪙',
                style: const TextStyle(
                    color: Color(0xFF159C6A), fontWeight: FontWeight.w800),
              ),
            ),
          if (won && _boosterKey != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '🎁 获得 ${_boosterLabels[_boosterKey]!} · 合成开局可用',
                style: const TextStyle(
                    color: Color(0xFF7E57C2), fontWeight: FontWeight.w800),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: _resetGame,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                child: const Text('重玩'),
              ),
              const SizedBox(width: 12),
              if (canNext)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton(
                    onPressed: _goNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: const Text('下一关'),
                  ),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  foregroundColor: AppColors.ink1,
                ),
                child: const Text('返回'),
              ),
            ],
          ),
        ],
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
        _buildActionBar(),
      ],
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.ink1),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildInfoChip(
                      '🚗 ${widget.level.name}', AppColors.accent),
                  const SizedBox(width: 6),
                  // 常驻目标提示：把哪辆车开到绿车位（不依赖教学弹窗）。
                  _buildInfoChip(
                    '🎯 ${widget.level.targetTier.icon}→🟢',
                    AppColors.mint.withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 6),
                  _buildInfoChip('👣 ${_game.moves}', AppColors.surfaceSoft),
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
                  IconButton(
                    icon: const Icon(Icons.help_outline,
                        color: AppColors.ink2, size: 20),
                    onPressed: _showHelpDialog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    final isLight = color.computeLuminance() > 0.5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isLight ? AppColors.ink1 : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          ElevatedButton.icon(
            onPressed: _game.canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
            label: const Text('撤销'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.ink1,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _requestHint,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('提示'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
            label: const Text('重置'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.ink1,
            ),
          ),
          if (_game.hasWon || _game.hasLost) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('完成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final cellSize = (availableSize / math.max(_game.rows, _game.cols))
            .clamp(56.0, 140.0);
        final boardW = _game.cols * cellSize;
        final boardH = _game.rows * cellSize;

        return SizedBox(
          width: boardW,
          height: boardH,
          child: Stack(
            children: [
              // 底层：格子（背景/障碍/车位/入口），并接收点击。
              Column(
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
              // 覆盖层：车辆（长条车画成一整块），IgnorePointer 让点击穿透到格子。
              for (final v in _game.vehicles) _buildVehicleOverlay(v, cellSize),
            ],
          ),
        );
      },
    );
  }

  /// 车辆覆盖层：长条车按占用格数绘制成一整块圆角车身（含车图标居中）。
  /// 颜色按车型(tier)取，颜色即"车的身份"，玩家可凭色辨认不同车。
  Widget _buildVehicleOverlay(VehicleState v, double size) {
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
      left: left + inset,
      top: top + inset,
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
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(size * 0.18),
                      child: Padding(
                        padding: EdgeInsets.all(size * 0.08),
                        child: Image.asset(
                          'assets/vehicles/${v.tier.name}.png',
                          fit: BoxFit.contain,
                          // 新档车模 PNG 未就位时降级为车型色 icon，避免红屏。
                          errorBuilder: (_, _, _) => Icon(
                            Icons.directions_car,
                            color: v.tier.color.withValues(alpha: 0.7),
                            size: size * 0.4,
                          ),
                        ),
                      ),
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
          ],
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
        bg = AppColors.mint.withValues(alpha: 0.30);
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
      bg = Color.lerp(bg, const Color(0xFF26C6DA), 0.45)!;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      key: ValueKey('cell-$row-$col'),
      onTap: () => _handleCellTap(row, col),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isHintTarget ? const Color(0xFF26C6DA) : AppColors.ink3.withValues(alpha: 0.18),
            width: isHintTarget ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _buildCellContent(cell, vehicle, size),
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
    // 停车位图标（停在车下的幽灵图标）
    if (cell.isParking) {
      final parked = vehicle != null;
      return Center(
        child: Text(widget.level.targetTier.icon,
            style: TextStyle(
                fontSize: size * 0.4,
                color: parked ? AppColors.mint : AppColors.ink3.withValues(alpha: 0.4))),
      );
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

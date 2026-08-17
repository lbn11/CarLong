import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/audio_feedback.dart';
import '../game/parking_game.dart';
import '../game/vehicle_icons.dart';
import '../models/parking_level.dart';
import '../save/save_repository.dart';
import '../services/parking_generator.dart';

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
    _game = ParkingGame(widget.level);
    _game.addListener(_onGameUpdate);
    // 音效/触感跟随全局开关。
    _audio.soundOn = widget.data.soundOn;
    _audio.vibrateOn = widget.data.vibrateOn;
    unawaited(_audio.load());
    // 停车模式首次进入弹出教学
    if (!widget.data.tutorialCompleted.contains(-1)) {
      _tutorialActive = true;
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

  void _settleWin() {
    if (_settled) return;
    _settled = true;
    final stars = _game.calcStars();
    final reward = 20 + stars * 10;
    _lastStars = stars;
    _lastReward = reward;
    widget.data.coins += reward;

    // 图鉴接入：通关停车关卡即点亮目标车型（与合成游戏共享同一套交通图鉴）。
    _collectionNew = widget.data.collection.add(widget.level.targetTier.index);
    if (_collectionNew) {
      _collectionBonus = 10;
      widget.data.coins += _collectionBonus;
    }

    if (widget.level.id >= widget.data.parkingUnlocked) {
      widget.data.parkingUnlocked = widget.level.id + 1;
    }
    final prev = widget.data.parkingBestStars[widget.level.id] ?? 0;
    if (stars > prev) widget.data.parkingBestStars[widget.level.id] = stars;
    widget.repo.save(widget.data);
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
        backgroundColor: const Color(0xFF232830),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🅿️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              '停车模式',
              style: const TextStyle(
                color: Colors.white,
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('• 点击一辆车选中（金色边框）', style: TextStyle(color: Colors.white70)),
            const Text('• 点击空地或车位 — 直线滑行过去', style: TextStyle(color: Colors.white70)),
            const Text('• 碰到 🧱 障碍和其他车会停下', style: TextStyle(color: Colors.white70)),
            const Text('• 其他车是障碍，拖开它们让路', style: TextStyle(color: Colors.white70)),
            const Text('• 可以撤销、重置', style: TextStyle(color: Colors.white70)),
            const Text('• 横/竖长车只能沿车身方向滑动，先挪开挡路的车', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A90D9),
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
              },
              child: const Text(
                '跳过',
                style: TextStyle(color: Colors.white70, fontSize: 14),
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
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app,
                  color: Color(0xFF4E342E),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF4E342E),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
    final canNext = won && widget.level.id < widget.data.parkingUnlocked;
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
        color: const Color(0xFF232830),
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
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (won)
            _buildStarsRow()
          else
            const Text('再试一次吧', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            won
                ? '步数: ${_game.moves} | 时间: ${_game.elapsedSeconds}s'
                : '没有可用的移动了',
            style: const TextStyle(color: Colors.white70),
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
                    color: Color(0xFF7CD9AE), fontWeight: FontWeight.w800),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: _resetGame,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90D9),
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
                      backgroundColor: const Color(0xFF66BB6A),
                    ),
                    child: const Text('下一关'),
                  ),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2F38),
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
                  color: earned ? const Color(0xFFFFD54F) : Colors.white24,
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildInfoChip(
                      '🚗 ${widget.level.name}', const Color(0xFF4A90D9)),
                  const SizedBox(width: 6),
                  _buildInfoChip('👣 ${_game.moves}', const Color(0xFF2A2F38)),
                  if (widget.level.timeLimit != null) ...[
                    const SizedBox(width: 6),
                    _buildInfoChip(
                      '⏱ ${_game.timeLeft}s',
                      _game.timeLeft! <= 10
                          ? const Color(0xFFE53935)
                          : const Color(0xFF2A2F38),
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.help_outline,
                        color: Colors.white70, size: 20),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
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
              backgroundColor: const Color(0xFF2A2F38),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _requestHint,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('提示'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90D9),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
            label: const Text('重置'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2F38),
              foregroundColor: Colors.white,
            ),
          ),
          if (_game.hasWon || _game.hasLost) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('完成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66BB6A),
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
            .clamp(40.0, 80.0);
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
    final color = v.tier.color;

    return AnimatedPositioned(
      key: ValueKey(v.index),
      duration: _kVehicleSlide,
      curve: Curves.easeOutCubic,
      left: left + inset,
      top: top + inset,
      width: w - 2 * inset,
      height: h - 2 * inset,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, Colors.white, 0.30)!,
                color,
                Color.lerp(color, Colors.black, 0.28)!,
              ],
            ),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFD54F)
                  : (isHint ? const Color(0xFF26C6DA) : Colors.white10),
              width: (isSelected || isHint) ? 3 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: VehicleIcon(
              tier: v.tier,
              size: math.min(w, h) * 0.6,
              color: v.parked ? const Color(0xFFFFD54F) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, double size) {
    final cell = _game.cellAt(row, col);
    final vehicle = _game.vehicleAt(row, col);

    // 背景色
    Color bg;
    switch (cell.type) {
      case ParkingCellType.road:
        bg = const Color(0xFF2A2F38);
        break;
      case ParkingCellType.parking:
        bg = const Color(0xFF2E7D32);
        break;
      case ParkingCellType.obstacle:
        bg = const Color(0xFF5D4037);
        break;
      case ParkingCellType.entrance:
        bg = const Color(0xFF1565C0);
        break;
      case ParkingCellType.exit:
        bg = const Color(0xFF6A1B9A);
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
            color: isHintTarget ? const Color(0xFF26C6DA) : Colors.white10,
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
                color: parked ? Colors.white : Colors.white30)),
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

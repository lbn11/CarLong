import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/parking_game.dart';
import '../game/vehicle_icons.dart';
import '../models/parking_level.dart';
import '../save/save_repository.dart';
import '../services/parking_generator.dart';

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
  int? _selectedVehicle;
  int _tutorialStep = 0;
  bool _tutorialActive = false;

  @override
  void initState() {
    super.initState();
    _game = ParkingGame(widget.level);
    _game.addListener(_onGameUpdate);
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
      final moved = _game.moveVehicle(_selectedVehicle!, row, col);
      if (moved) {
        setState(() => _selectedVehicle = null);
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
        _onPlayerAction('select');
      }
    }
  }

  /// 是否已结算过（胜利/失败的奖励与解锁只落盘一次）。
  bool _settled = false;
  int _lastStars = 0;
  int _lastReward = 0;

  void _settleWin() {
    if (_settled) return;
    _settled = true;
    final stars = _game.calcStars();
    final reward = 20 + stars * 10;
    _lastStars = stars;
    _lastReward = reward;
    widget.data.coins += reward;
    if (widget.level.id >= widget.data.parkingUnlocked) {
      widget.data.parkingUnlocked = widget.level.id + 1;
    }
    final prev = widget.data.parkingBestStars[widget.level.id] ?? 0;
    if (stars > prev) widget.data.parkingBestStars[widget.level.id] = stars;
    widget.repo.save(widget.data);
  }

  void _settleLose() {
    if (_settled) return;
    _settled = true;
    // 失败不解锁、不发奖，仅保底存盘。
    widget.repo.save(widget.data);
  }

  void _resetGame() {
    _game.reset();
    setState(() => _settled = false);
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
      child: Center(
        child: Container(
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final earned = i < _lastStars;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        earned ? Icons.star : Icons.star_border,
                        color: earned ? const Color(0xFFFFD54F) : Colors.white24,
                        size: 28,
                      ),
                    );
                  }),
                )
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
        ),
      ),
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
          const Spacer(),
          _buildInfoChip('🚗 ${widget.level.name}', const Color(0xFF4A90D9)),
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
            icon: const Icon(Icons.help_outline, color: Colors.white70, size: 20),
            onPressed: _showHelpDialog,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _game.canUndo ? () => _game.undo() : null,
            icon: const Icon(Icons.undo),
            label: const Text('撤销'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2F38),
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_game.rows, (r) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_game.cols, (c) {
                return _buildCell(r, c, cellSize);
              }),
            );
          }),
        );
      },
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

    final isSelected = vehicle?.index == _selectedVehicle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleCellTap(row, col),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD54F)
                : Colors.white10,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _buildCellContent(cell, vehicle, size),
      ),
    );
  }

  Widget? _buildCellContent(ParkingCell cell, VehicleState? vehicle, double size) {
    if (vehicle != null) {
      return Center(
        child: VehicleIcon(
          tier: vehicle.tier,
          size: size * 0.7,
          color: vehicle.parked ? const Color(0xFFFFD54F) : Colors.white,
        ),
      );
    }

    // 障碍图标
    if (cell.isObstacle) {
      return const Center(
        child: Text('🧱', style: TextStyle(fontSize: 18)),
      );
    }
    // 停车位图标
    if (cell.isParking) {
      final parked = vehicle != null;
      return Center(
        child: Text(widget.level.targetTier.icon,
            style: TextStyle(fontSize: size * 0.4, color: parked ? Colors.white : Colors.white30)),
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

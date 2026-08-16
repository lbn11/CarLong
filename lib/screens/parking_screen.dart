import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/parking_game.dart';
import '../game/vehicle_icons.dart';
import '../models/parking_level.dart';
import '../save/save_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _game = ParkingGame(widget.level);
    _game.addListener(_onGameUpdate);
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
      // 尝试移动
      final moved = _game.moveVehicle(_selectedVehicle!, row, col);
      if (moved) {
        setState(() => _selectedVehicle = null);
      }
    } else {
      // 选择该位置的车辆
      final v = _game.vehicleAt(row, col);
      if (v != null && !v.parked) {
        setState(() => _selectedVehicle = v.index);
      }
    }
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final won = _game.hasWon;
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
              Text(
                won
                    ? '步数: ${_game.moves} | 时间: ${_game.elapsedSeconds}s'
                    : '再试一次吧',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () => _game.reset(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9),
                    ),
                    child: const Text('重玩'),
                  ),
                  const SizedBox(width: 12),
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
            onPressed: () => _game.reset(),
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
      return Center(
        child: Text(widget.level.targetTier.icon,
            style: TextStyle(fontSize: size * 0.4, color: Colors.white30)),
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

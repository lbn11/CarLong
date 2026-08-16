import 'package:flutter/material.dart';

import '../models/parking_level.dart';
import '../save/save_repository.dart';
import '../services/parking_generator.dart';
import 'parking_screen.dart';

/// 停车关卡选择屏
class ParkingLevelSelectScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const ParkingLevelSelectScreen({
    super.key,
    required this.data,
    required this.repo,
  });

  @override
  State<ParkingLevelSelectScreen> createState() => _ParkingLevelSelectScreenState();
}

class _ParkingLevelSelectScreenState extends State<ParkingLevelSelectScreen> {
  static const int _pageSize = 50;
  int _page = 0;
  late final List<ParkingLevel> _levels;

  @override
  void initState() {
    super.initState();
    _levels = ParkingLevelGenerator.generate(count: 100);
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_levels.length / _pageSize).ceil();
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, _levels.length);
    final items = _levels.sublist(start, end);

    return Scaffold(
      backgroundColor: const Color(0xFF171A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171A1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('停车模式', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '把目标车辆停到停车位上',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _levelTile(items[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white70),
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                ),
                Text('${_page + 1} / $totalPages',
                    style: const TextStyle(color: Colors.white70)),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white70),
                  onPressed: _page < totalPages - 1
                      ? () => setState(() => _page++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelTile(ParkingLevel level) {
    final unlocked = widget.data.unlockedLevel > level.id;
    final stars = widget.data.bestStars[level.id] ?? 0;

    return GestureDetector(
      onTap: unlocked
          ? () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ParkingScreen(
                  level: level,
                  data: widget.data,
                  repo: widget.repo,
                ),
              ));
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: unlocked ? const Color(0xFF2A2F38) : const Color(0xFF1A1E24),
          border: Border.all(
            color: unlocked ? const Color(0xFF4A90D9) : const Color(0xFF252A32),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${level.id}',
              style: TextStyle(
                color: unlocked ? Colors.white : Colors.white30,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 12,
                color: i < stars ? const Color(0xFFFFD54F) : Colors.white24,
              )),
            ),
            const SizedBox(height: 2),
            Text(
              level.targetTier.icon,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../game/vehicle_icons.dart';
import '../models/level.dart';
import '../save/save_repository.dart';
import 'game_screen.dart';

/// 完整关卡选择页：从首页「全部关卡」进入。
class LevelSelectScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const LevelSelectScreen({super.key, required this.data, required this.repo});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  PlayerData get data => widget.data;

  Future<void> _openLevel(LevelDefinition level) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: level, data: data, repo: widget.repo),
      ),
    );
    if (result == true && mounted) {
      // 通关后刷新星星/进度。
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              LevelSelectScreen(data: data, repo: widget.repo),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        levels.where((l) => (data.bestStars[l.id] ?? 0) > 0).length;
    return Scaffold(
      backgroundColor: const Color(0xFF171A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E23),
        foregroundColor: Colors.white,
        title: const Text('选择关卡',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('已完成 $completed/${levels.length}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemCount: levels.length,
        itemBuilder: (context, index) {
          final level = levels[index];
          final unlocked = index < data.unlockedLevel;
          return LevelCard(
            level: level,
            unlocked: unlocked,
            best: data.bestScores[level.id] ?? 0,
            bestStars: data.bestStars[level.id] ?? 0,
            onTap: unlocked ? () => _openLevel(level) : null,
          );
        },
      ),
    );
  }
}

class LevelCard extends StatelessWidget {
  final LevelDefinition level;
  final bool unlocked;
  final int best;
  final int bestStars;
  final VoidCallback? onTap;

  const LevelCard({
    super.key,
    required this.level,
    required this.unlocked,
    required this.best,
    required this.bestStars,
    this.onTap,
  });

  Color get _accent => level.targetTier?.color ?? const Color(0xFF4A90D9);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? const [Color(0xFF2A2F38), Color(0xFF1E2229)]
                : const [Color(0xFF20242A), Color(0xFF1A1D22)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked
                ? _accent.withValues(alpha: 0.35)
                : const Color(0xFF2A2F38),
          ),
          boxShadow: unlocked
              ? const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '第 ${level.id} 关',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10),
                          ),
                        ),
                        const Spacer(),
                        if (!unlocked)
                          const Icon(Icons.lock, color: Colors.white24, size: 16)
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              3,
                              (i) => Text(
                                i < bestStars ? '⭐' : '☆',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: unlocked
                              ? _accent.withValues(alpha: 0.16)
                              : const Color(0x14FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: level.targetTier != null
                              ? VehicleIcon(
                                  tier: level.targetTier!,
                                  size: 30,
                                  color: unlocked
                                      ? level.targetTier!.color
                                      : level.targetTier!.color.withValues(
                                          alpha: 0.35),
                                )
                              : Icon(Icons.grid_view,
                                  size: 26,
                                  color: unlocked
                                      ? const Color(0xFFFFFFFF)
                                      : const Color(0x55FFFFFF)),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      best > 0 ? '最佳 $best 分' : '未通关',
                      style: TextStyle(
                          color: best > 0
                              ? const Color(0xFFFFCA28)
                              : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
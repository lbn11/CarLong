import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../save/save_repository.dart';

class AchievementsScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const AchievementsScreen({super.key, required this.data, required this.repo});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  PlayerData get data => widget.data;

  void _claim(Achievement a) {
    if (data.claimedAchievements.contains(a.id)) return;
    setState(() {
      data.claimedAchievements.add(a.id);
      data.coins += a.reward;
    });
    widget.repo.save(data);
  }

  @override
  Widget build(BuildContext context) {
    final coins = data.coins;
    final claimed = achievements
        .where((a) => data.claimedAchievements.contains(a.id))
        .length;
    return Scaffold(
      backgroundColor: const Color(0xFF171A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E23),
        foregroundColor: Colors.white,
        title: const Text('成就',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('已领 $claimed/${achievements.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A3D5C), Color(0xFF1B2437)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                const Text('当前金币',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$coins',
                    style: const TextStyle(
                        color: Color(0xFFFFCA28),
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final a in achievements)
            _AchievementTile(
              achievement: a,
              achieved: a.achieved(data),
              claimed: data.claimedAchievements.contains(a.id),
              onClaim: () => _claim(a),
            ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool achieved;
  final bool claimed;
  final VoidCallback onClaim;

  const _AchievementTile({
    required this.achievement,
    required this.achieved,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final accent = achieved ? const Color(0xFFFFCA28) : Colors.white30;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: achieved
                ? [const Color(0xFF2A2F38), const Color(0xFF1E2229)]
                : [const Color(0xFF20242A), const Color(0xFF1A1D22)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: achieved
                  ? const Color(0x44FFCA28)
                  : const Color(0xFF2A2F38)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(a.icon, color: accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: TextStyle(
                          color: achieved ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(a.desc,
                      style: TextStyle(
                          color: achieved ? Colors.white54 : Colors.white24,
                          fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (claimed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x2266BB6A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('已领取',
                    style: TextStyle(
                        color: Color(0xFF66BB6A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              )
            else if (achieved)
              FilledButton(
                onPressed: onClaim,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCA28),
                  foregroundColor: const Color(0xFF4E342E),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('领取 +${a.reward}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              )
            else
              const Icon(Icons.lock_outline, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
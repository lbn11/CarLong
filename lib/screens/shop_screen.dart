import 'package:flutter/material.dart';

import '../save/save_repository.dart';

class _ShopItem {
  final String key;
  final String name;
  final String desc;
  final int cost;
  final IconData icon;
  final Color color;

  const _ShopItem(this.key, this.name, this.desc, this.cost, this.icon, this.color);
}

const _items = <_ShopItem>[
  _ShopItem('time', '加时卡', '限时关卡开场 +30 秒', 40, Icons.schedule, Color(0xFF4A90D9)),
  _ShopItem('cards', '补卡卡', '开局牌堆额外 +3 张', 30, Icons.inventory_2, Color(0xFF66BB6A)),
  _ShopItem('double', '双倍卡', '下一关通关金币 ×2', 50, Icons.casino, Color(0xFFFFCA28)),
];

class ShopScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const ShopScreen({super.key, required this.data, required this.repo});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  PlayerData get data => widget.data;

  void _buy(_ShopItem item) {
    if (data.coins < item.cost) return;
    setState(() {
      data.coins -= item.cost;
      data.boosters[item.key] = (data.boosters[item.key] ?? 0) + 1;
    });
    widget.repo.save(data);
  }

  @override
  Widget build(BuildContext context) {
    final coins = data.coins;
    return Scaffold(
      backgroundColor: const Color(0xFF171A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E23),
        foregroundColor: Colors.white,
        title: const Text('商店', style: TextStyle(fontWeight: FontWeight.w900)),
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
                const Text('我的金币',
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
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('开局道具（下一关自动生效，每关每种各消耗 1 个）',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A2F38), Color(0xFF1E2229)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x335C6BC0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(item.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('持有 ${data.boosters[item.key] ?? 0}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(item.desc,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed:
                          coins >= item.cost ? () => _buy(item) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: item.color,
                        disabledBackgroundColor: const Color(0xFF2A2F38),
                        disabledForegroundColor: Colors.white30,
                        foregroundColor: const Color(0xFF101318),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('$item.cost 🪙',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            '小提示：关卡内还可用金币直接购买锤子、撤销与补牌。',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
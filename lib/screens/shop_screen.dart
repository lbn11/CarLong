import 'dart:math';

import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../game/game_config.dart';
import '../save/save_repository.dart';
import '../theme/app_theme.dart';

/// 商店：只卖"金币宝箱"（回收阀）。
/// 设计：宝箱花 100 金币抽奖，随机开 booster（加时/补卡/双倍）或金币。
/// 金币期望略低于投入（约 -20%），Booster 不可变现 → 不构成通胀；
/// 同时与停车 3 星免费发放的 booster 完全解耦，商店不再是 booster 直购点。
class ShopScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const ShopScreen({super.key, required this.data, required this.repo});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static final int _chestCost = GameConfig.chestCost;
  /// 激励广告：每日免费观看次数与单次奖励（模拟，待接真实广告 SDK）。
  static final int _dailyAdLimit = GameConfig.dailyAdLimit;
  static final int _adReward = GameConfig.adReward;

  /// 金币礼包（模拟 IAP）：600 金币档。
  static final int _coinPackAmount = GameConfig.coinPackAmount;

  PlayerData get data => widget.data;
  late final AnalyticsService _analytics = AnalyticsService(widget.data, widget.repo);
  final _rng = Random();

  static const _boosterMeta = <String, ({String name, IconData icon, Color color})>{
    'time': (name: '加时卡', icon: Icons.schedule, color: AppColors.sky),
    'cards': (name: '补卡卡', icon: Icons.inventory_2, color: AppColors.mint),
    'double': (name: '双倍卡', icon: Icons.casino, color: AppColors.sun),
  };

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// 今日剩余广告次数（跨日重置）。
  int get _adLeftToday {
    if (data.adWatchDate != _today()) return _dailyAdLimit;
    return (_dailyAdLimit - data.adWatchCount).clamp(0, _dailyAdLimit);
  }

  /// 激励广告（模拟）：点击后模拟"观看完成"立即发奖。
  void _watchAd() {
    final left = _adLeftToday;
    if (left <= 0) return;
    final today = _today();
    final count = data.adWatchDate == today ? data.adWatchCount : 0;
    data.adWatchDate = today;
    data.adWatchCount = count + 1;
    data.addCoins(_adReward);
    widget.repo.save(data);
    _analytics.adWatch(_adReward);
    setState(() {});
    _showResult(
      icon: Icons.smart_display,
      color: AppColors.sky,
      title: '广告看完 +$_adReward 🪙',
      desc: '今日还可看 $_adLeftToday 次（模拟广告，接入 SDK 后替换）',
    );
  }

  /// 金币礼包（模拟 IAP）：600 金币档。
  void _buyCoinPack() {
    data.addCoins(_coinPackAmount);
    widget.repo.save(data);
    _analytics.iapPurchase('coin_pack_600', _coinPackAmount);
    setState(() {});
    _showResult(
      icon: Icons.workspace_premium,
      color: const Color(0xFFFFB23E),
      title: '金币礼包 +$_coinPackAmount 🪙',
      desc: '演示版：上架后接入真实内购（iOS IAP / 安卓 Google Play）',
    );
  }

  void _showResult({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 34),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.ink1,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(desc,
                  style:
                      const TextStyle(color: AppColors.ink2, fontSize: 14)),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text('好',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChest() {
    if (data.coins < _chestCost) return;
    setState(() => data.coins -= _chestCost);
    widget.repo.save(data);

    // 开箱结果：40% booster / 35% +90 / 20% +150 / 5% +300（金币期望 ~76.5 < 投入）。
    final roll = _rng.nextDouble();
    final String title;
    final String desc;
    final IconData icon;
    final Color color;
    if (roll < 0.40) {
      final key = _boosterMeta.keys.elementAt(_rng.nextInt(_boosterMeta.length));
      data.boosters[key] = (data.boosters[key] ?? 0) + 1;
      final meta = _boosterMeta[key]!;
      title = '🎁 开到 ${meta.name}！';
      desc = '库存 +1，下一关开局自动生效';
      icon = meta.icon;
      color = meta.color;
    } else if (roll < 0.75) {
      data.addCoins(90);
      title = '🎁 金币 +90';
      desc = '小亏，下次再来一箱！';
      icon = Icons.monetization_on;
      color = const Color(0xFFFFB23E);
    } else if (roll < 0.95) {
      data.addCoins(150);
      title = '🎁 金币 +150';
      desc = '小赚一笔！';
      icon = Icons.monetization_on;
      color = const Color(0xFFFFB23E);
    } else {
      data.addCoins(300);
      title = '✨ 金币 +300！';
      desc = '欧气爆发！';
      icon = Icons.auto_awesome;
      color = const Color(0xFFFF5E7A);
    }
    widget.repo.save(data);
    _analytics.chestOpen(
        _chestCost, roll < 0.40 ? 'booster' : (roll < 0.75 ? 'coins90' : (roll < 0.95 ? 'coins150' : 'coins300')));

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 34),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.ink1,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(desc,
                  style: const TextStyle(color: AppColors.ink2, fontSize: 14)),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text('收下啦',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final coins = data.coins;
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.ink1,
        title: const Text('商店', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: GlowBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.card(radius: 18),
              child: Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  const Text('我的金币',
                      style: TextStyle(
                          color: AppColors.ink2, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('$coins',
                      style: const TextStyle(
                          color: AppColors.sun,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.card(radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFD982),
                              Color(0xFFFFB23E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x66FFB23E),
                                blurRadius: 12,
                                offset: Offset(0, 4)),
                          ],
                        ),
                        child: const Icon(Icons.card_giftcard,
                            color: Color(0xFF7A4A12), size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('金币宝箱',
                                style: TextStyle(
                                    color: AppColors.ink1,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17)),
                            const SizedBox(height: 4),
                            const Text(
                              '100 🪙 抽一箱：40% 开到加时/补卡/双倍卡，\n'
                              '60% 开到金币（+90 ~ +300）。',
                              style: TextStyle(
                                  color: AppColors.ink2, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '消耗品说明：加时卡限时关 +30s（非限时关 +30🪙）、'
                              '补卡卡牌堆 +3、双倍卡通关金币 ×2，'
                              '也可在停车模式三星奖励免费获得。',
                              style: TextStyle(
                                  color: AppColors.ink3, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: coins >= _chestCost ? _openChest : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.ink3.withValues(alpha: 0.2),
                        disabledForegroundColor: AppColors.ink3,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      child: Text(coins >= _chestCost
                          ? '开一箱 · $_chestCost 🪙'
                          : '金币不足（还需 ${_chestCost - coins} 🪙）'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.card(radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('每日福利 · 看广告赚金币',
                      style: TextStyle(
                          color: AppColors.ink1,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    '每天最多看 $_dailyAdLimit 次，每次 +$_adReward 🪙',
                    style: const TextStyle(color: AppColors.ink2, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _adLeftToday > 0 ? _watchAd : null,
                          icon: const Icon(Icons.smart_display, size: 18),
                          label: Text(
                            _adLeftToday > 0
                                ? '看广告 +$_adReward 🪙（剩 $_adLeftToday 次）'
                                : '今日次数已用完，明天再来',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.sky,
                            disabledForegroundColor: AppColors.ink3,
                            side: BorderSide(
                                color: AppColors.sky.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '演示版：点击即发奖。上架后接入激励视频 SDK（AdMob/穿山甲）。',
                    style: TextStyle(color: AppColors.ink3, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.card(radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFD982),
                              Color(0xFFFFB23E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.workspace_premium,
                            color: Color(0xFF7A4A12), size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('金币礼包',
                                style: TextStyle(
                                    color: AppColors.ink1,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('$_coinPackAmount 🪙 · 6 元档',
                                style: const TextStyle(
                                    color: AppColors.ink2, fontSize: 12)),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: _buyCoinPack,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB23E),
                          foregroundColor: const Color(0xFF7A4A12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                        child: const Text('¥6 购买'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '演示版：免费发放。上架后接入 IAP 真实扣款并走平台合规。',
                    style: TextStyle(color: AppColors.ink3, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.card(radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('我的消耗品',
                      style: TextStyle(
                          color: AppColors.ink1, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final entry in _boosterMeta.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(entry.value.icon,
                              color: entry.value.color, size: 20),
                          const SizedBox(width: 8),
                          Text(entry.value.name,
                              style: const TextStyle(
                                  color: AppColors.ink2, fontSize: 14)),
                          const Spacer(),
                          Text('持有 ${data.boosters[entry.key] ?? 0}',
                              style: const TextStyle(
                                  color: AppColors.ink3,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    '消耗品来自金币宝箱与停车模式三星奖励，商店不再直接出售。',
                    style: TextStyle(color: AppColors.ink3, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '小提示：关卡内还可以用金币直接购买清除、撤销、加牌、洗牌重排与提示。',
              style: TextStyle(color: AppColors.ink3, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

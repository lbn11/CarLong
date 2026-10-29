import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../game/audio_feedback.dart';
import '../game/game_config.dart';
import '../l10n/app_localizations.dart';
import '../save/save_repository.dart';
import '../services/ads/ad_service.dart';
import '../services/ads/ad_types.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_ui.dart';

/// 商店：只卖"金币宝箱"（回收阀）。
/// 设计：宝箱花 100 金币抽奖，随机开 booster（加时/补卡/双倍）或金币。
/// 金币期望略低于投入（约 -20%），Booster 不可变现 → 不构成通胀；
/// 同时与停车 3 星免费发放的 booster 完全解耦，商店不再是 booster 直购点。
///
/// 视觉设计：柠檬金身份色（商店=阳光），主推的宝箱做一张大 Hero 卡，
/// 其余内容按「每日福利 / 我的消耗品」两段排列，避免一页全堆同权重卡片。
///
/// **没有内购**：金币只能靠看广告与游玩获得。这里曾有一个「¥6 购买 600 🪙」
/// 的模拟内购按钮，已删除，原因有三：
/// 1. 标价却不扣款是审核红线（Apple 3.1.1 要求 IAP、2.3.1 虚假功能；
///    Play Payments Policy 同样禁止真实货币定价却不走 Play Billing）。
/// 2. 只发海外却硬编码人民币符号，且 IAP 价格必须由商店返回（已本地化、
///    含地区定价与税），代码里永远不能写死金额。
/// 3. 它与「看广告 +100」并排放在同一张卡里，等于把「一次广告值多少钱」
///    直接算给玩家看 —— 这是广告游戏最不该让玩家做的换算。
///
/// 真要加内购，做「去广告」买断（付费后激励视频改为直接领取），不要卖金币。
class ShopScreen extends StatefulWidget {
  final PlayerData data;
  final SaveRepository repo;

  const ShopScreen({super.key, required this.data, required this.repo});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static final int _chestCost = GameConfig.chestCost;
  /// 单次广告奖励（每日次数与上限由 AdService 按广告位管理）。
  static final int _adReward = GameConfig.adReward;

  PlayerData get data => widget.data;
  late final AnalyticsService _analytics =
      AnalyticsService(widget.data, widget.repo);
  final _rng = Random();

  /// 广告请求进行中（防连点重复请求 SDK）。
  bool _adLoading = false;

  @override
  void initState() {
    super.initState();
    // 商店福利是唯一「进页面就打算点」的广告位：进页先拉好，
    // 点下去直接起播，不用等 2-5 秒加载。
    unawaited(AdService.preload(AdPlacement.shopDaily));
  }

  /// 道具身份色统一走 AppColors 糖果色板（替换原先零散的 Material 500/600 色）。
  ///
  /// 这里**不存展示名**：这是 static const，拿不到 context，而名字必须跟随语言。
  /// 名字统一由 [_boosterName] 按 id 查 l10n。
  static const _boosterMeta = <String, ({IconData icon, Color color, bool parkingOnly})>{
    // 合成模式道具：开局自动生效（GameScreen._applyBoosters）
    'time': (icon: Icons.schedule, color: AppColors.aqua, parkingOnly: false),
    'cards': (
      icon: Icons.inventory_2,
      color: AppColors.mint,
      parkingOnly: false
    ),
    'double': (icon: Icons.casino, color: AppColors.sun, parkingOnly: false),
    // 停车模式专用道具：仅停车对局内使用
    'undo': (icon: Icons.undo, color: AppColors.grape, parkingOnly: true),
    'bomb': (icon: Icons.whatshot, color: AppColors.melon, parkingOnly: true),
    'spring': (icon: Icons.open_with, color: AppColors.forest, parkingOnly: true),
    'balloon': (
      icon: Icons.location_on,
      color: AppColors.sky,
      parkingOnly: true
    ),
    'key': (icon: Icons.vpn_key, color: AppColors.lemon, parkingOnly: true),
    'hammer': (icon: Icons.build, color: AppColors.cocoa, parkingOnly: true),
    'doubleMove': (
      icon: Icons.compare_arrows,
      color: AppColors.taro,
      parkingOnly: true
    ),
  };

  /// 道具名的唯一出口。新增道具时这里和 arb 都要加，
  /// 漏了会回落到原始 id（比直接崩溃好定位）。
  static String _boosterName(String id, AppLocalizations l10n) => switch (id) {
        'time' => l10n.boosterTimeCard,
        'cards' => l10n.boosterExtraCards,
        'double' => l10n.boosterDoubleCoins,
        'undo' => l10n.boosterUndoCard,
        'bomb' => l10n.boosterBomb,
        'spring' => l10n.boosterSpring,
        'balloon' => l10n.boosterBalloon,
        'key' => l10n.boosterKey,
        'hammer' => l10n.boosterHammer,
        'doubleMove' => l10n.boosterDoubleMove,
        _ => id,
      };

  /// 今日剩余广告次数。
  ///
  /// 取「本位剩余」与「全局剩余」的较小值：单点 3 次还没用完、但全站
  /// 30 条已经看满时，按钮必须同步变灰，否则点下去才弹上限提示。
  int get _adLeftToday {
    final placementLeft =
        AdService.remainingToday(AdPlacement.shopDaily, data) ?? 0;
    final globalLeft = AdService.remainingGlobalToday(data);
    return placementLeft < globalLeft ? placementLeft : globalLeft;
  }

  /// 激励广告：必须等到 AdService 返回「看完」才发奖。
  ///
  /// 真实 SDK 的失败路径（无填充 / 玩家中途关闭 / 青少年模式）在这里统一
  /// 弹提示，**绝不在点击时就加金币**。
  Future<void> _watchAd() async {
    AudioFeedback.uiTap();
    if (_adLeftToday <= 0) return;
    setState(() => _adLoading = true);
    final result = await AdService.show(
      AdPlacement.shopDaily,
      data: data,
      repo: widget.repo,
      analytics: _analytics,
    );
    if (!mounted) return;
    setState(() => _adLoading = false);
    if (!result.isRewarded) {
      _showAdNotice(result);
      return;
    }
    data.addCoins(_adReward);
    widget.repo.save(data);
    _analytics.adWatch(_adReward);
    setState(() {});
    final l10n = AppLocalizations.of(context);
    CandyDialog.show(
      context,
      icon: Icons.smart_display,
      color: AppColors.sky,
      title: l10n.adRewardLine(_adReward),
      message:
          _adLeftToday > 0 ? l10n.adLeftToday(_adLeftToday) : l10n.adUsedUp,
      confirmLabel: l10n.takeIt,
    );
  }

  /// 广告没看成：说清原因，别让玩家以为按钮坏了。
  void _showAdNotice(AdResult result) {
    final l10n = AppLocalizations.of(context);
    CandyDialog.show(
      context,
      icon: Icons.info_outline,
      color: AppColors.ink3,
      title: l10n.adDidNotFinish,
      message: result.userMessage,
      confirmLabel: l10n.gotIt,
    );
  }

  void _openChest() {
    if (data.coins < _chestCost) return;
    final l10n = AppLocalizations.of(context);
    AudioFeedback.uiTap();
    setState(() => data.coins -= _chestCost);
    widget.repo.save(data);

    // 开箱结果：40% booster / 35% +90 / 20% +150 / 5% +300（金币期望 ~76.5 < 投入）。
    final roll = _rng.nextDouble();
    final String title;
    final String desc;
    final IconData? icon;
    final String? emoji;
    final Color color;
    if (roll < 0.40) {
      final key = _boosterMeta.keys.elementAt(_rng.nextInt(_boosterMeta.length));
      data.boosters[key] = (data.boosters[key] ?? 0) + 1;
      final meta = _boosterMeta[key]!;
      emoji = '🎁';
      icon = null;
      title = l10n.chestGotItem(_boosterName(key, l10n));
      desc = meta.parkingOnly ? l10n.chestStockParking : l10n.chestStockMerge;
      color = meta.color;
    } else if (roll < 0.75) {
      data.addCoins(90);
      emoji = null;
      icon = Icons.monetization_on;
      title = l10n.chestCoins90;
      desc = l10n.chestCoins90Note;
      color = AppColors.lemon;
    } else if (roll < 0.95) {
      data.addCoins(150);
      emoji = null;
      icon = Icons.monetization_on;
      title = l10n.chestCoins150;
      desc = l10n.chestCoins150Note;
      color = AppColors.lemon;
    } else {
      data.addCoins(300);
      emoji = '✨';
      icon = null;
      title = l10n.chestCoins300;
      desc = l10n.chestCoins300Note;
      color = AppColors.blossom;
    }
    widget.repo.save(data);
    _analytics.chestOpen(
        _chestCost,
        roll < 0.40
            ? 'booster'
            : (roll < 0.75
                ? 'coins90'
                : (roll < 0.95 ? 'coins150' : 'coins300')));

    if (!mounted) return;
    setState(() {});
    CandyDialog.show(
      context,
      emoji: emoji,
      icon: icon,
      color: color,
      title: title,
      message: desc,
      confirmLabel: l10n.takeIt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coins = data.coins;
    final l10n = AppLocalizations.of(context);
    final affordable = coins >= _chestCost;
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              CandyAppBar(
                title: l10n.shopTitle,
                subtitle: l10n.shopTagline,
                accent: AppColors.lemon,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  CoinPill(amount: coins, compact: true),
                  const SizedBox(width: 10),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    // ===== 主推：金币宝箱 =====
                    CandyCard(
                      accent: AppColors.lemon,
                      radius: 28,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.coinGold1,
                                      AppColors.coinGold2,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.coinGold2
                                          .withValues(alpha: 0.42),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.card_giftcard_rounded,
                                    color: AppColors.coinText, size: 32),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.chestTitle,
                                        style: const TextStyle(
                                            color: AppColors.ink1,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18)),
                                    const SizedBox(height: 3),
                                    Text(
                                      l10n.chestPerDraw(_chestCost),
                                      style: const TextStyle(
                                          color: AppColors.ink2, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.chestBoosterHelp,
                            style: const TextStyle(
                                color: AppColors.ink3, fontSize: 11.5, height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          CandyButton(
                            label: affordable
                                ? l10n.chestOpen(_chestCost)
                                : l10n.chestNeedMore(_chestCost - coins),
                            icon: affordable
                                ? Icons.auto_awesome_rounded
                                : Icons.hourglass_empty_rounded,
                            colors: affordable
                                ? AppTheme.gradientOf(AppColors.lemon)
                                : AppTheme.softGradient,
                            onTap: affordable ? _openChest : null,
                            expand: true,
                            size: CandyButtonSize.large,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== 每日福利 =====
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: SectionTitle(
                        title: l10n.dailyPerks,
                        subtitle: l10n.dailyPerksTagline,
                        accent: AppColors.sky,
                      ),
                    ),
                    CandyCard(
                      accent: AppColors.sky,
                      radius: 22,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _adLeftToday > 0
                                      ? l10n.adLeftTodayWithReward(
                                          _adLeftToday, _adReward)
                                      : l10n.adUsedUp,
                                  style: const TextStyle(
                                      color: AppColors.ink1,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 10),
                              CandyButton(
                                label: _adLoading
                                    ? l10n.loadingEllipsis
                                    : l10n.claimPlus(_adReward),
                                size: CandyButtonSize.small,
                                dense: true,
                                colors: _adLeftToday > 0 && !_adLoading
                                    ? AppTheme.gradientOf(AppColors.sky)
                                    : AppTheme.softGradient,
                                onTap: _adLeftToday > 0 && !_adLoading
                                    ? _watchAd
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 说清「没有充值入口」：既防玩家找，也让审核一眼看到
                          // 本作不涉及 IAP（省掉一整轮 3.1.1 问询）。
                          Text(
                            l10n.noPurchaseNotice,
                            style: const TextStyle(
                                color: AppColors.ink3,
                                fontSize: 11,
                                height: 1.4),
                          ),
                          // 只在「debug + 模拟 provider」下说破：给开发看，玩家
                          // 在 profile / release 里永远看不到这行「演示版」字样。
                          if (kDebugMode && AdService.usingMock) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.demoAdNotice,
                              style: const TextStyle(
                                  color: AppColors.ink3, fontSize: 10.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== 我的消耗品 =====
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: SectionTitle(
                        title: l10n.myBoosters,
                        subtitle: l10n.myBoostersFrom,
                        accent: AppColors.grape,
                      ),
                    ),
                    CandyCard(
                      accent: AppColors.grape,
                      radius: 22,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SoftChip(
                              label: l10n.mergeBoostersLabel,
                              icon: Icons.auto_awesome,
                              color: AppColors.mint),
                          const SizedBox(height: 8),
                          _boosterGrid(false),
                          const SizedBox(height: 12),
                          SoftChip(
                              label: l10n.parkingBoostersLabel,
                              icon: Icons.local_parking,
                              color: AppColors.taro),
                          const SizedBox(height: 8),
                          _boosterGrid(true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 消耗品网格：2 列小卡，图标 + 名称 + 库存数字，替代原先的长列表文字行。
  Widget _boosterGrid(bool parkingOnly) {
    final l10n = AppLocalizations.of(context);
    final entries =
        _boosterMeta.entries.where((e) => e.value.parkingOnly == parkingOnly);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.9,
      children: [
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: entry.value.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: entry.value.color.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(entry.value.icon, color: entry.value.color, size: 19),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(_boosterName(entry.key, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.deepen(entry.value.color, 0.34),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                ),
                Text('${data.boosters[entry.key] ?? 0}',
                    style: TextStyle(
                        color: AppTheme.deepen(entry.value.color, 0.34),
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
      ],
    );
  }
}

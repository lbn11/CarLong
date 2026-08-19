import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/game_config.dart';

/// 正式回归测试（任务76）：新玩家 7 天经济循环。
/// 断言：破产率 < 1%，且 D7 余额 p50 落在健康区间（不破产、不失控通胀）。
/// 输入取真实代码数值（与 lib 内 const 保持一致，改价需同步）。
///  合成奖励 score/10×星级系数(1~3星) ~5-30/关，失败 +10
///  停车奖励 20+stars*10 = 30/40/50，图鉴新点亮 +10
///  签到 7 日 [10,15,20,25,30,40,80]
///  每日挑战 +150（当天首通）
///  离线收益 12🪙/h（按 1-8h 随机）
///  激励广告 100×3/天（0-3 次随机）
///  道具消耗：清除25/撤销40/加牌50/洗牌60/提示40（每天 0-2 个）
///  宝箱 150🪙（每周约 2 次）
/// 输出：每日余额分位 + 7 天累计 + 破产率。
void main() {
  test('new player 7-day economy simulation', () {
    final rng = Random(2026);
    const sims = 400;

    int mergeReward() {
      final score = 50 + rng.nextInt(101); // 50-150
      final stars = 1 + rng.nextInt(3);
      final base = score ~/ 10;
      final r = stars == 3
          ? base * 2
          : stars == 2
              ? (base * 1.5).round()
              : base;
      return rng.nextDouble() < 0.85 ? r : 10; // 15% 失败安慰
    }

    int parkingReward() => 20 + (1 + rng.nextInt(3)) * 10;
    bool newCollectionDay(int day) =>
        rng.nextDouble() < (day == 1 ? 0.8 : 0.25);

    const signIn = [10, 15, 20, 25, 30, 40, 80];

    final balances = <int, List<int>>{};
    var broke = 0;
    for (var s = 0; s < sims; s++) {
      var coins = 0;
      for (var day = 1; day <= 7; day++) {
        // 收入
        for (var i = 0; i < 5; i++) {
          coins += mergeReward(); // 5 关合成
        }
        for (var i = 0; i < 10; i++) {
          coins += parkingReward(); // 10 关停车
        }
        coins += signIn[day - 1]; // 签到
        coins += 150; // 每日挑战
        coins += (1 + rng.nextInt(8)) * GameConfig.offlineCoinsPerHour; // 离线 1-8h
        coins += rng.nextInt(4) * GameConfig.adReward; // 广告 0-3 次
        if (newCollectionDay(day)) coins += 10 + (rng.nextDouble() < 0.5 ? 5 : 0); // 图鉴点亮
        // 支出
        final tools = rng.nextInt(3); // 0-2 个道具
        for (var i = 0; i < tools; i++) {
          coins -= [GameConfig.hammerCost, GameConfig.undoCost, GameConfig.addCardsCost, GameConfig.shuffleCost, GameConfig.hintCost][rng.nextInt(5)];
        }
        if (rng.nextDouble() < 0.3) coins -= GameConfig.chestCost; // 约每周 2 次宝箱
        if (coins < 0) coins = 0; // 金币不为负（实际有上限钳制）
        if (day == 7 && coins == 0) broke++;
        balances[day] = [...(balances[day] ?? []), coins];
      }
    }

    int pct(List<int> list, double p) {
      final l = [...list]..sort();
      return l[(l.length * p).clamp(0, l.length - 1).toInt()];
    }

    final buf = StringBuffer();
    buf.writeln('=== 新玩家 7 天经济模拟（$sims 人）===');
    buf.writeln('day | p25 | p50 | p75 | 当日净收入中位');
    var prev = 0;
    for (var day = 1; day <= 7; day++) {
      final list = balances[day]!;
      final net = pct(list, 0.5) - prev;
      prev = pct(list, 0.5);
      buf.writeln(
          'D$day | ${pct(list, 0.25)} | ${pct(list, 0.5)} | ${pct(list, 0.75)} | +$net');
    }
    buf.writeln('');
    buf.writeln('破产率（D7 余额为 0）= ${(broke / sims * 100).toStringAsFixed(1)}%');
    final end = balances[7]!;
    buf.writeln('D7 余额 p50=${pct(end, 0.5)}，均值=${(end.reduce((a, b) => a + b) / end.length).round()}');
    buf.writeln('道具购买力：D1 合成 1 关约 $mergeReward 🪙 vs 最贵道具洗牌 60');
    buf.writeln('宝箱(150)购买力：D2 p50 余额 ${pct(balances[2]!, 0.5)} → 能买 ${(pct(balances[2]!, 0.5) / 150).floor()} 个');    File('/tmp/economy_sim.txt').writeAsStringSync(buf.toString());
    // 断言：破产率极低（不卡死新玩家）。
    expect(broke / sims < 0.01, isTrue,
        reason: '破产率过高（${broke / sims}），收入/支出失衡');
    // 断言：D7 余额 p50 在健康区间 [1500, 12000]（不破产、不过度通胀）。
    final endP50 = pct(end, 0.5);
    expect(endP50 >= 1500 && endP50 <= 12000, isTrue,
        reason: 'D7 余额 p50=$endP50 超出健康区间（1500-12000）');
  });
}

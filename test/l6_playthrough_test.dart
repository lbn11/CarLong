import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/logic/board_logic.dart';

/// 用真实 BoardLogic 复现 L6 玩法流：开局种子 + 逐张出牌 + 贪心合并。
/// 中等偏随机策略（不刻意规划），统计通关率与失败原因分布。
void main() {
  test('L6 headless playthrough', () {
    final level = levels.firstWhere((l) => l.id == 6);
    final rng = Random(2026);
    var win = 0, full = 0, deadLoss = 0;
    var residueSum = 0;
    const trials = 500;
    for (var t = 0; t < trials; t++) {
      final b = BoardLogic(level, random: Random(rng.nextInt(1 << 30)));
      // 开局种子（与 MergeGame 一致）
      final seedCount = (level.cols * level.rows ~/ 4).clamp(1, 4);
      for (var i = 0; i < seedCount; i++) {
        b.placeTier(b.randomTier());
      }
      // 牌堆
      final deck = List.generate(level.stockSize, (_) => b.randomTier());
      var fullFlag = false;
      for (var di = 0; di < deck.length; di++) {
        // 盘满则先尝试合并腾位；合不动即判负
        while (b.isFull) {
          if (!greedyMerge(b)) break;
        }
        if (b.isFull) {
          fullFlag = true;
          break;
        }
        b.placeTier(deck[di]);
        greedyMerge(b);
      }
      if (!fullFlag) {
        // 抽完后再合并到不能再合
        while (greedyMerge(b)) {}
      }
      final res = b.tileCount;
      if (fullFlag) {
        full++;
      } else if (res <= (level.clearLimit ?? 0)) {
        win++;
        residueSum += res;
      } else {
        deadLoss++;
      }
    }
    // ignore: avoid_print
    print('WIN $win/$trials  FULL $full  DEAD>$deadLoss'
        '  avgResidueWhenWin=${win > 0 ? residueSum / win : '-'}');
    expect(win, greaterThan(trials * 60 ~/ 100),
        reason: 'L6 应有 60%+ 通过率');
  });
}

/// 贪心合并一轮：找到任意一对可合并的堆，执行 board.move。
/// 返回是否发生了至少一次合并。移动规则与真实一致（自由滑动）。
bool greedyMerge(BoardLogic b) {
  final stacks = <({int col, int row})>[];
  for (var c = 0; c < b.cols; c++) {
    for (var r = 0; r < b.rows; r++) {
      final s = b.at(c, r);
      if (s != null && !s.isEmpty) stacks.add((col: c, row: r));
    }
  }
  for (var i = 0; i < stacks.length; i++) {
    for (var j = i + 1; j < stacks.length; j++) {
      final a = stacks[i], d = stacks[j];
      final sa = b.at(a.col, a.row)!, sd = b.at(d.col, d.row)!;
      final mergeable = (sa.isBomb && sd.isBomb) ||
          (sa.isWildcard || sd.isWildcard) ||
          (!sa.isBomb &&
              !sd.isWildcard &&
              !sa.isWildcard &&
              !sd.isBomb &&
              sa.tier == sd.tier);
      if (!mergeable) continue;
      final result = b.move(a.col, a.row, d.col, d.row);
      if (result.valid) return true;
    }
  }
  return false;
}

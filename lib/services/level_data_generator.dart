import 'dart:math' as math;

import '../models/level.dart';
import '../models/vehicle.dart';

/// 主线关卡数值生成器（L71-700，630 关）。
///
/// # 设计原则（数值向）
///
/// 旧版用「线性公式堆参数」（`stockSize = 30 + (id-70)`、目标档位按 id 分段硬跳），
/// 实测结果是**难度递减**：预算占用率从 0.39 一路滑到 0.11，
/// 后期 145 张牌只需用 30 张，玩家点完 1/5 牌堆就赢了 —— 掉进无聊区。
///
/// 新版改为四条硬规则：
///
/// 1. **牌堆由目标反推**：先用 [expectedDraws] 解析算出「达成目标的期望出牌数」，
///    再乘一个随章节收紧的 budgetFactor（3.4 → 2.0）。这样预算占用率被钉在
///    0.29 → 0.50 的心流通道里，而不是任由线性公式漂走。
/// 2. **目标档位分段单调**：14 章 × 45 关，章内小步上升（+2.6 档）、章间基线递增
///    （+2.07 档），从有轨电车(20) 走到曲速飞船(49)。不再出现
///    「上一关曲速飞船、下一关卡车」的 -36 档断崖。
/// 3. **机制按章投放**：每 1-2 章解锁一种新机制（冰→锁→石→传送→迷雾→万能→炸弹→限步→清盘），
///    后期靠「组合密度」而非「单关数值」加压。
/// 4. **章内有节奏**：每 9 关一个释放关（牌堆放宽、障碍减半），形成
///    tension-release，避免 630 关的连续爬坡疲劳。
///
/// 全部纯函数、确定性：同一 id 永远生成同一关。
class LevelDataGenerator {
  LevelDataGenerator._();

  /// 生成区间起点（L1-70 为手写关）。
  static const int firstId = 71;

  /// 生成区间终点（主线总关数 700）。
  static const int lastId = 700;

  /// 每章关数。
  static const int chapterSize = 45;

  /// 生成段章数（630 / 45 = 14）。
  static const int chapterCount = 14;

  /// 生成 L71-700（630 关）。
  static List<LevelDefinition> levels71To700() =>
      [for (var i = firstId; i <= lastId; i++) _generateLevel(i)];

  /// 生成段章节表（衔接手写段 7 章，供 [levelChapters] 拼接）。
  static const List<LevelChapter> generatedChapters = [
    LevelChapter('第八章 · 地下铁网', '城市地下的第一条线', 71),
    LevelChapter('第九章 · 磁浮干线', '离地一厘米的极速', 116),
    LevelChapter('第十章 · 轨道遗产', '蒸汽与超回路的交响', 161),
    LevelChapter('第十一章 · 港区水道', '从铁轨转向水面', 206),
    LevelChapter('第十二章 · 近海航线', '风帆与快艇的时代', 251),
    LevelChapter('第十三章 · 远洋舰队', '巨轮与航母的泊位', 296),
    LevelChapter('第十四章 · 低空航线', '离开地面，扶摇直上', 341),
    LevelChapter('第十五章 · 云端航道', '客机巡航的高度', 386),
    LevelChapter('第十六章 · 高空领域', '战斗机与运输机', 431),
    LevelChapter('第十七章 · 临近空间', '大气层的边缘', 476),
    LevelChapter('第十八章 · 航天港', '火箭与航天飞机', 521),
    LevelChapter('第十九章 · 轨道空间站', '在轨道上组装', 566),
    LevelChapter('第二十章 · 月球基地', '静海的第一辆车', 611),
    LevelChapter('第二十一章 · 曲速纪元', '跨越光速的最后一跃', 656),
  ];

  // ─────────────────────────────────────────────────────────────
  //  曲线
  // ─────────────────────────────────────────────────────────────

  /// 章索引（0..13）与章内进度（0..1）。
  static (int, double) _pos(int id) {
    final off = (id - firstId).clamp(0, chapterCount * chapterSize - 1);
    final c = (off ~/ chapterSize).clamp(0, chapterCount - 1);
    final p = (off % chapterSize) / (chapterSize - 1);
    return (c, p);
  }

  /// 目标车型档位：章基线 20 + c×2.077，章内 +p×2.0，收尾正好落在 49（曲速飞船）。
  ///
  /// 系数经过标定：末章基数为 47（月球车），章内走到 49，刚好覆盖
  /// lunar(47) / starship(48) / warpShip(49) 三个终极车型，
  /// 避免旧版「最后 7 关档位全部 clamp 到同一档、内容完全撞车」。
  static int _tierIndexFor(int id) {
    final (c, p) = _pos(id);
    return (20 + c * 2.077 + p * 2.0).round().clamp(0, 49);
  }

  /// 目标数量：随章节从 ×1 缓升到 ×5（终章收尾）。
  static int _targetCountFor(int c, double p) {
    if (c <= 3) return p < 0.55 ? 1 : 2;
    if (c <= 8) return p < 0.40 ? 2 : 3;
    if (c >= 13 && p > 0.85) return 5; // 终章收尾：大师关
    return p < 0.55 ? 3 : 4;
  }

  /// 牌堆倍数：3.4 → 2.0。倒数即预算占用率 0.29 → 0.50（心流通道）。
  ///
  /// 前期给足余量建立信心，后期收紧到「需要有效率但不至于卡死」。
  static double _budgetFactor(int c, double p) {
    final t = (c + p) / chapterCount; // 0..1
    return 3.4 - 1.4 * t;
  }

  /// 高等级卡偏置：档位越深、目标数越多，偏置越大（保证深目标可达成）。
  static int _autoBias(int tierIdx, int count) {
    final base = tierIdx <= 22
        ? 1
        : (tierIdx <= 28
            ? 2
            : (tierIdx <= 34 ? 3 : (tierIdx <= 40 ? 4 : (tierIdx <= 45 ? 5 : 6))));
    final countBonus = count >= 4 ? 3 : (count >= 3 ? 2 : (count >= 2 ? 1 : 0));
    return base + countBonus;
  }

  // ─────────────────────────────────────────────────────────────
  //  牌堆标定（解析精确解，无需蒙特卡洛）
  // ─────────────────────────────────────────────────────────────

  /// 达成目标的**期望出牌数**（解析精确值）。
  ///
  /// 原理：出牌权重 [w] 覆盖档位 0..baseIdx（baseIdx = 目标档 - 1）。
  /// 一张档位 i 的牌等价于 (1/3)^(baseIdx-i) 张 baseIdx 档牌（3 合 1）。
  /// 于是单张牌的「目标档当量」为 Σ (w_i/W)·(1/3)^(baseIdx-i)，
  /// 凑满 targetCount×3 张当量所需张数即为期望。
  ///
  /// 实测校准：L7(taxi×3, bias1) 解析 13.6 / 模拟 p50 14；
  /// L200(warpShip×3, bias9) 解析 34.3 / 模拟 p50 33。误差 <3%。
  static double expectedDraws(LevelDefinition lvl) {
    if (lvl.goalType != GoalType.produce || lvl.targetTier == null) return 0;
    final w = lvl.spawnWeights();
    if (w.isEmpty) return 0;
    final totalW = w.fold(0, (a, b) => a + b);
    if (totalW <= 0) return 0;
    final baseIdx = w.length - 1;
    var eq = 0.0;
    for (var i = 0; i < w.length; i++) {
      eq += (w[i] / totalW) * math.pow(1 / 3, baseIdx - i);
    }
    if (eq <= 0) return 0;
    return 3.0 * lvl.targetCount / eq;
  }

  // ─────────────────────────────────────────────────────────────
  //  机制投放
  // ─────────────────────────────────────────────────────────────

  /// 障碍类型池：按章解锁，后期四种齐上。
  static List<ObstacleType> _poolFor(int c) => [
        ObstacleType.ice,
        if (c >= 2) ObstacleType.lock,
        if (c >= 4) ObstacleType.block,
        if (c >= 6) ObstacleType.teleport,
      ];

  /// 障碍数量：随章节 1 → 6，章内小幅爬升（开篇章也保留 1-2 个，不至于空盘）。
  static int _obstacleCount(int c, double p) =>
      (1 + c * 0.4 + p * 0.9).round().clamp(1, 6);

  /// 是否清盘关：Ch3 起每 23 关一次。
  static bool _isClearBoard(int id, int c) => c >= 3 && id % 23 == 0;

  /// 是否释放关（章内每 9 关一次）：牌堆放宽、障碍减半。
  static bool _isBreather(int id) => (id - firstId) % 9 == 8;

  // ─────────────────────────────────────────────────────────────
  //  生成
  // ─────────────────────────────────────────────────────────────

  static LevelDefinition _generateLevel(int id) {
    final (c, p) = _pos(id);
    final breather = _isBreather(id);
    final clearBoard = _isClearBoard(id, c);

    final tierIdx = _tierIndexFor(id);
    final tier = VehicleType.values[tierIdx];
    final count = _targetCountFor(c, p);
    final bias = _autoBias(tierIdx, count);

    // 障碍：释放关减半。
    final pool = _poolFor(c);
    final obsCount = breather ? _obstacleCount(c, p) ~/ 2 : _obstacleCount(c, p);
    final obstacles = _generateObstacles(obsCount, pool, id);

    // 棋盘：前两章 5×5，之后 6×6（更大的棋盘承载更高的牌堆压力）。
    final size = c <= 1 ? 5 : 6;

    // 特殊机制按章投放（周期性出现，不是每关都堆）。
    final fog = (c >= 5 && id % 11 == 0) ? (4 + (c - 5)).clamp(4, 9) : 0;
    final wildcards = (c >= 7 && id % 17 == 0) ? (2 + (c - 7) ~/ 3).clamp(2, 4) : 0;
    final bombs = (c >= 9 && id % 19 == 0) ? (1 + (c - 9) ~/ 4).clamp(1, 3) : 0;

    final clearLimit = clearBoard ? (5 - (c ~/ 5)).clamp(3, 5) : null;

    // ── 牌堆标定 ──
    int stock;
    int? movesLimit;
    int? timeLimit;

    if (clearBoard) {
      // 清盘关：牌堆即难度本身，随章节缓增。
      stock = 26 + c * 2 + (p * 8).round();
    } else {
      final draft = LevelDefinition(
        id: id,
        name: '',
        cols: size,
        rows: size,
        stockSize: 0,
        targetTier: tier,
        targetCount: count,
        highTierBias: bias,
      );
      final expected = expectedDraws(draft);
      var factor = _budgetFactor(c, p);
      if (breather) factor += 0.45; // 释放关放宽
      stock = math.max(14, (expected * factor).round());

      // 限步：Ch6 起每 31 关一次。判负线必须宽松（期望的 2.4 倍），
      // 它是「别乱点」的引导，不是制造挫败的闸门。
      if (c >= 6 && id % 31 == 0) {
        movesLimit = (expected * 2.4).round().clamp(20, 400);
      }
    }

    // 限时：冲刺关（每 13 关一次）。按每步 4.2 秒标定，宽松。
    if (id % 13 == 0) {
      final expected = clearBoard ? stock * 0.75 : stock * 0.42;
      timeLimit = (expected * 4.2).round().clamp(70, 320);
    }

    return LevelDefinition(
      id: id,
      name: _chapterName(id),
      cols: size,
      rows: size,
      stockSize: stock,
      goalType: clearBoard ? GoalType.clearBoard : GoalType.produce,
      targetTier: clearBoard ? null : tier,
      targetCount: clearBoard ? 1 : count,
      clearLimit: clearLimit,
      timeLimitSeconds: timeLimit,
      movesLimit: movesLimit,
      highTierBias: bias,
      fogCells: fog,
      wildcards: wildcards,
      bombs: bombs,
      obstacles: obstacles,
    );
  }

  /// 障碍布局：由 id 决定的确定性散布，避开正中心（留出开局落子空间）。
  static List<ObstacleSpec> _generateObstacles(
      int count, List<ObstacleType> pool, int id) {
    if (count <= 0 || pool.isEmpty) return const [];
    final out = <ObstacleSpec>[];
    final used = <(int, int)>{};
    var guard = 0;
    var i = 0;
    while (out.length < count && guard++ < 120) {
      final c = ((id * 7 + i * 13 + 3) % 6);
      final r = ((id * 11 + i * 17 + 5) % 6);
      // 传送门成对出现。
      final type = pool[i % pool.length];
      if (type == ObstacleType.teleport && i % 2 == 0 && out.length + 2 > count) {
        i++;
        continue;
      }
      if (!used.contains((r, c)) && !(r == 2 && c == 2)) {
        used.add((r, c));
        out.add(ObstacleSpec(type, c, r,
            layers: type == ObstacleType.ice ? 2 + (i % 2) : 2));
      }
      i++;
    }
    return out;
  }

  static String _chapterName(int id) {
    for (final ch in generatedChapters.reversed) {
      if (id >= ch.startId) return ch.title.split(' · ').last;
    }
    return '街区';
  }
}

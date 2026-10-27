import 'dart:math' as math;

import '../models/level.dart';
import '../models/vehicle.dart';
import 'level_progression.dart';

/// 主线关卡数值生成器（L71-700，630 关）。
///
/// # 设计原则（数值向）
///
/// 旧版用「线性公式堆参数」（`stockSize = 30 + (id-70)`、目标档位按 id 分段硬跳），
/// 实测结果是**难度递减**：预算占用率从 0.39 一路滑到 0.11，
/// 后期 145 张牌只需用 30 张，玩家点完 1/5 牌堆就赢了 —— 掉进无聊区。
///
/// 新版改为七条硬规则：
///
/// 1. **牌堆由目标反推**：先用 [expectedDraws] 解析算出「达成目标的期望出牌数」，
///    再乘一个随章节收紧的 budgetFactor（3.4 → 2.0）。这样预算占用率被钉在
///    0.29 → 0.50 的心流通道里，而不是任由线性公式漂走。
/// 2. **目标档位分段单调**：14 章 × 45 关，章内小步上升（+2 档）、章间基线递增
///    （+2.07 档），从有轨电车(20) 走到曲速飞船(49)。不再出现
///    「上一关曲速飞船、下一关卡车」的 -36 档断崖。
/// 3. **机制按章投放**：每 1-2 章解锁一种新机制（冰→锁→石→传送→迷雾→万能→炸弹→限步→清盘），
///    后期靠「组合密度」而非「单关数值」加压。
/// 4. **5 关难度心跳**：简单 → 中等 → 难 → 中等 → 特难，不停轮回
///    （与停车模式共用同一套节奏语言，详见 [rhythmPhase]）。心流的本质不是
///    「越来越难」而是**张弛交替**：连续爬坡会疲劳，一直平又会无聊。
///    两个模式的周期**故意不同**（合成 5 关 / 停车 6 关）：局部难度曲线的
///    关卡数不能相同，否则交替游玩时紧张点叠加，节奏感互相抵消。
/// 5. **新车型在组首登场**：一个心跳组（5 关）内目标车型恒定，且组的第 1 关
///    就是相位 0（轻松）—— 新车先给个轻松的亮相，再在同一组里逐步加压。
/// 6. **三层难度结构 + 广告挑战关**（详见 [LevelProgression]）：心流循环之上
///    还有章（36-45 关）与大阶段（3 章，阶段末章 = 魔王章），让玩家有宏观梯度感；
///    每 5 关 1 个广告挑战关（牌堆 ×0.92）—— 难一档但远非无解，
///    看广告只提供降难支援，不是通行证。
/// 7. **Boss 关**（详见 [LevelProgression.isMergeBossLevel]）：两个完整心跳后
///    插入一个，占用下一组的心跳槽位（每章第一个落在轻松槽——打断预期；
///    因 11 mod 5 = 1，后续在相位 1-3 轮转，永不叠加硬仗峰值）。
///    Boss 关是**真有 Boss 的**：棋盘上方悬浮一辆会动的捣乱车（暗红车身 +
///    王冠 + 血条），每隔 9 秒盯上一个格子——红圈预警后往空格扔冰块、
///    或把场上最低档的车拖走。合成目标车 = 攻击 Boss，HP = 目标数 +2，
///    打空血条即胜（详见 [MergeGame] 的 Boss 战与 `BossSprite`）。
///    配方 = 目标档位 +2 + 障碍 +2 + 牌堆按硬仗档位再收紧（×0.92）。
///    仍远低于无解线，失败有广告支援兜底。**停车模式没有 Boss 关**（无敌人概念）。
///
/// 全部纯函数、确定性：同一 id 永远生成同一关。
class LevelDataGenerator {
  LevelDataGenerator._();

  /// 生成区间起点（L1-70 为手写关）。
  static const int firstId = 71;

  /// 生成区间终点（主线总关数 700）。
  static const int lastId = 700;

  /// 每章关数（可被 [rhythmPeriod] 整除，保证章边界不打断心跳）。
  static const int chapterSize = 45;

  /// 生成段章数（630 / 45 = 14）。
  static const int chapterCount = 14;

  /// 每章 Boss 数（11 关超级周期占 1 个，章内偏移 %11==10 判定）。
  static const int bossPerChapter = 4;

  /// Boss 徽章墙总格数（14 × 4 = 56，与 [BossSpec.forLevel] 的
  /// (chapterIdx, bossIndex) 参数空间一致）。首页进度与徽章墙共用。
  static int get bossTotal => chapterCount * bossPerChapter;

  /// 难度心跳周期（关）：合成 5 关一轮。
  ///
  /// 与停车模式（[ParkingLevelGenerator.rhythmPeriod] = 6）**故意不同** ——
  /// 产品要求两个模式的局部难度曲线关卡数不能相同。
  static const int rhythmPeriod = 5;

  /// 相位名（0..4），供 UI 显示难度标记。
  static const List<String> phaseNames = ['轻松', '顺手', '动脑', '顺手', '硬仗'];

  /// 难度心跳相位（0..4）：章内偏移取模。
  ///
  /// 45 能被 5 整除，所以每章第 1 关恒为相位 0，章边界不会打断心跳。
  static int rhythmPhase(int id) => (id - firstId) % rhythmPeriod;

  /// 生成 L71-700（630 关）。
  static List<LevelDefinition> levels71To700() =>
      [for (var i = firstId; i <= lastId; i++) _generateLevel(i)];

  /// 生成段章节表（衔接手写段 7 章，供 [levelChapters] 拼接）。
  static const List<LevelChapter> generatedChapters = [
    LevelChapter('第八章 · 地下铁网', '城市地下的第一条线', 71),  // i18n-data
    LevelChapter('第九章 · 磁浮干线', '离地一厘米的极速', 116),  // i18n-data
    LevelChapter('第十章 · 轨道遗产', '蒸汽与超回路的交响', 161),  // i18n-data
    LevelChapter('第十一章 · 港区水道', '从铁轨转向水面', 206),  // i18n-data
    LevelChapter('第十二章 · 近海航线', '风帆与快艇的时代', 251),  // i18n-data
    LevelChapter('第十三章 · 远洋舰队', '巨轮与航母的泊位', 296),  // i18n-data
    LevelChapter('第十四章 · 低空航线', '离开地面，扶摇直上', 341),  // i18n-data
    LevelChapter('第十五章 · 云端航道', '客机巡航的高度', 386),  // i18n-data
    LevelChapter('第十六章 · 高空领域', '战斗机与运输机', 431),  // i18n-data
    LevelChapter('第十七章 · 临近空间', '大气层的边缘', 476),  // i18n-data
    LevelChapter('第十八章 · 航天港', '火箭与航天飞机', 521),  // i18n-data
    LevelChapter('第十九章 · 轨道空间站', '在轨道上组装', 566),  // i18n-data
    LevelChapter('第二十章 · 月球基地', '静海的第一辆车', 611),  // i18n-data
    LevelChapter('第二十一章 · 曲速纪元', '跨越光速的最后一跃', 656),  // i18n-data
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

  /// 目标车型档位：章基线 20 + c×2.077，章内按**心跳组**递增（9 组 ×0.25 = +2）。
  ///
  /// 关键：**同一心跳组（5 关）内档位恒定**（Boss 关除外，见下）。
  /// 组的第 1 关是相位 0（轻松），于是新车型永远在轻松关首次登场，
  /// 随后 4 关用同一车型逐步加压 —— 先亮相再考验，比连续跳档更利于形成认知。
  ///
  /// 系数经过标定：末章基数为 47（月球车），章内走到 49，刚好覆盖
  /// lunar(47) / starship(48) / warpShip(49) 三个终极车型，
  /// 避免旧版「最后 7 关档位全部 clamp 到同一档、内容完全撞车」。
  ///
  /// **Boss 关 +2 档**：它抢占的是下一组的轻松亮相位，若不提档，
  /// 「Boss 关开着一辆刚见过的车」毫无事件感；+2 档让 Boss 提前开出
  /// 高阶车，组内后续关卡再回到本组车型——先惊艳后考验。
  static int _tierIndexFor(int id) {
    final (c, _) = _pos(id);
    final group = (id - firstId) % chapterSize ~/ rhythmPeriod; // 0..8
    final base = (20 + c * 2.077 + group * 0.25).round().clamp(0, 49);
    if (LevelProgression.isMergeBossLevel(id)) {
      return (base + 2).clamp(0, 49);
    }
    return base;
  }

  /// 目标数量：随章节从 ×1 缓升到 ×5（终章硬仗关）。
  ///
  /// 相位维度：动脑 / 硬仗相位多要一辆 —— 同一车型要凑更多台，
  /// 这是比「砍牌堆」更温和的加压方式（牌堆砍狠了会直接卡死，与放松定位冲突）。
  static int _targetCountFor(int c, int phase) {
    final base = c <= 3 ? 1 : (c <= 8 ? 2 : 3);
    var n = phase >= 2 ? base + 1 : base;
    if (c >= 13 && phase == 4) n += 1; // 终章硬仗：大师关
    return n.clamp(1, 6);
  }

  /// 各相位对牌堆倍数的增减。正数 = 牌堆宽裕 = 轻松，负数 = 收紧 = 紧张。
  ///
  /// 形状与停车模式一致：相位 1/3 都是"顺手"（中等），中间夹一个"动脑"，
  /// 硬仗之后必有回落，玩家不会连吃两关高压。
  static const List<double> _phaseBudget = [0.50, 0.18, 0.0, 0.25, -0.18];

  /// 广告挑战关的牌堆收紧系数（×0.93 ≈ 预算占用率上限 0.57）。
  ///
  /// 刻意温和：广告关是「难一档的挑战关」而不是墙。收紧后 p50 玩家
  /// 刚好压线（多数局需要一次续命/高效操作），但远不到无解 ——
  /// 硬实力玩家不看出能过，这是产品红线。
  static const double _adGateTighten = 0.93;

  /// 魔王章（大阶段末章）的牌堆收紧系数。比广告关温和：
  /// 魔王章的难度由整章累积体现，单关不再加码。
  static const double _demonTighten = 0.95;

  /// Boss 关的牌堆收紧系数（在硬仗档位基数上再 ×0.92）。
  ///
  /// Boss = +2 档 + 障碍 +2 + 本系数，是全表最紧节点：终章 Boss 的
  /// 预算占用率约 0.60，刻意超出心流通道上限 0.55（Boss 就是用来
  /// 超出日常节奏的），但仍远低于「必须全中」的 1.0——硬实力玩家
  /// 不看出能过，失败有广告支援，不是墙。
  ///
  /// 注意基数取**硬仗档位**（effPhase = 4）而非 Boss 实际落在的相位：
  /// Boss 在相位 0-3 上轮转，若踩着相位 0 的宽松基数，最紧的节点
  /// 反而会比普通轻松关还松，「Boss 关凑数」。
  static const double _bossTighten = 0.92;

  /// 牌堆倍数：3.4 → 2.0，再叠相位调制。倒数即预算占用率 0.29 → 0.50（心流通道）。
  ///
  /// 前期给足余量建立信心，后期收紧到「需要有效率但不至于卡死」。
  ///
  /// 宏观层（魔王章 / 广告挑战关 / Boss 关）在此收紧扣，三者**不叠加**（取较强）：
  /// 阶段末连吃两个收紧会把玩家劝退，违背心流原则。
  static double _budgetFactor(int id, int c, double p, int phase) {
    final t = (c + p) / chapterCount; // 0..1
    // Boss 关在相位 0-3 上轮转，但一律按硬仗档位起算——否则踩着
    // 相位 0/1 的宽松基数，最紧的节点反而比普通轻松关还松。
    final effPhase = LevelProgression.isMergeBossLevel(id) ? 4 : phase;
    var f = 3.4 - 1.4 * t + _phaseBudget[effPhase];
    if (LevelProgression.isMergeBossLevel(id)) {
      f *= _bossTighten;
    } else if (LevelProgression.isMergeAdGate(id)) {
      f *= _adGateTighten;
    } else if (LevelProgression.isMergeDemon(id)) {
      f *= _demonTighten;
    }
    return f;
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
  //  参考时间（par）
  // ─────────────────────────────────────────────────────────────

  /// 参考时间标定：一次「抽牌 → 合并」循环按 3 秒计。
  ///
  /// 与硬相位限时公式（`stock×0.42×4.2`，即 4.2 秒/次）同源但更紧：
  /// 限时是「慢于这个节奏就输」的判负线，par 是「正常手感能达成」的
  /// 参考线——超了不罚、不判负，比它快才有速通奖。两个口径差约 40%，
  /// 落在「熟练玩家大概率达成、新手需要专心」的区间。
  ///
  /// 校准通道：埋点（[AnalyticsService.levelEnd] 的 `elapsed_s` / `beat_par`）
  /// 每次通关都在记录真实用时，攒够对局后按同章均值回调本常数即可，
  /// 不需要改任何结构。
  static const double parSecPerDraw = 3.0;

  /// 参考时间（秒）：这关「正常打」大概要多久。0 = 不适用（无尽模式）。
  ///
  /// 与牌堆反推同一套数学（[expectedDraws]），不引入新参数：
  /// - produce：期望出牌数 × [parSecPerDraw]
  /// - Boss 关：打空血条 = 产出 `boss.hp` 辆目标车（expectedDraws 对
  ///   targetCount 线性，按 hp/count 折算——Boss 关天生比同关普通关慢）
  /// - clearBoard：与硬相位限时同口径（约用掉 75% 牌堆）
  ///
  /// 软设计：par 只是 HUD 上的一条参考线和结算时的速通奖门槛，
  /// 超时零惩罚（Boss 攻击每 9 秒一招不看玩家节奏，本身就是反磨蹭机制）。
  static double parSeconds(LevelDefinition lvl) {
    if (lvl.endless) return 0;
    if (lvl.goalType == GoalType.clearBoard) {
      return lvl.stockSize * 0.75 * parSecPerDraw;
    }
    if (lvl.targetTier == null || lvl.targetCount <= 0) return 0;
    final base = expectedDraws(lvl);
    if (base <= 0) return 0;
    final need = lvl.boss?.hp ?? lvl.targetCount;
    return base * need / lvl.targetCount * parSecPerDraw;
  }

  /// 收尾系数：抽空牌堆后还有「合并 → 出完目标车」的尾巴动作，
  /// 预计总用时 = 已用 + 剩牌 × 每张秒数 × 本系数。仅清盘关用。
  static const double paceTailFactor = 1.25;

  /// 观测外推的接管进度门槛：进度占比过 25% 后完全信任历史速率，
  /// 之前按占比线性融合。合成游戏前 1/4 是纯攒料期——深章 Boss 的
  /// 第一辆目标车可能要 90 秒，此时 elapsed/progress 单点外推会直接
  /// 崩一个数量级（把攒料期当成每辆平均耗时）。
  static const double paceObsFloor = 0.25;

  /// 实时 pace 倍率（HUD 徽章用）：**>1 = 照当前手感预计快于 par**
  /// （能拿速通奖），**<1 = 预计慢于 par**（无奖励、不罚）。0 = 不显示。
  ///
  /// 外推模型按关卡类型分流（与 [parSeconds] 同一标定体系）：
  /// - **清盘关**：剩余牌堆 = 剩余工作量，牌堆外推
  ///   （已用 + 剩牌 × 每张秒数 × [paceTailFactor]）准确
  /// - **produce / Boss 关**：牌堆是 2-10 倍冗余设计，剩牌 ≠ 剩余工作量，
  ///   改用进度外推与先验融合：
  ///   - 先验 prior = 已用 + 剩余目标 × (par/need)（剩余按参考均速完成）
  ///   - 观测 obs = 已用 / 进度占比（历史平均速率）
  ///   - 预计 = prior + w×(obs-prior)，w = (进度/[paceObsFloor]).clamp(0,1)
  ///   pace = par / 预计
  ///
  /// 开局保护：elapsed ≤ 0 或无尽返回 0（不显示徽章）。攒料期
  /// （零进度）只有先验兜底——「已用 + par」的温和值，不会一开场
  /// 就 0.0× 吓人。Boss 关 need = hp（par 已按 hp/count 折算，
  /// 每辆参考秒数与普通关同口径）。
  static double paceRatio(
    LevelDefinition lvl, {
    required double elapsed,
    required int stockLeft,
    int produced = 0,
    int bossHp = 0,
  }) {
    final par = parSeconds(lvl);
    if (par <= 0 || elapsed <= 0) return 0;
    if (lvl.goalType == GoalType.clearBoard) {
      final drawn = lvl.stockSize - stockLeft;
      final perDraw = drawn > 0 ? elapsed / drawn : parSecPerDraw;
      final projected = elapsed + stockLeft * perDraw * paceTailFactor;
      return projected <= 0 ? 0 : par / projected;
    }
    final need = lvl.boss?.hp ?? lvl.targetCount;
    if (need <= 0) return 0;
    final done = lvl.boss != null
        ? (lvl.boss!.hp - bossHp).clamp(0, need)
        : produced;
    final progress = done / need;
    // 先验：剩余目标按 par 均速完成。零进度（攒料期）时它是唯一估计。
    final prior = elapsed + (need - done) * (par / need);
    if (progress <= 0) return par / prior;
    final obs = elapsed / progress;
    final w = (progress / paceObsFloor).clamp(0.0, 1.0);
    final projected = prior + w * (obs - prior);
    return projected <= 0 ? 0 : par / projected;
  }

  /// 速通判定：获胜且用时 ≤ 参考时间。纯函数，UI 与测试共用。
  static bool beatPar(
    LevelDefinition lvl, {
    required bool won,
    required double elapsedSeconds,
  }) {
    if (!won) return false;
    final par = parSeconds(lvl);
    return par > 0 && elapsedSeconds <= par;
  }

  /// 速通奖金币：按分数缩放（score/20，钳 20-150），未达成 0。
  ///
  /// 数值待真实通关时长校准（与 [parSecPerDraw] 同一校准通道）。
  static int parBonusCoins(
    LevelDefinition lvl, {
    required bool won,
    required double elapsedSeconds,
    required int score,
  }) {
    if (!beatPar(lvl, won: won, elapsedSeconds: elapsedSeconds)) return 0;
    return (score ~/ 20).clamp(20, 150);
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

  /// 章内心跳组序号（0..8）：一个组 = 一个车型 + 一轮难度轮回。
  static int _groupOf(int id) => (id - firstId) % chapterSize ~/ rhythmPeriod;

  /// 是否清盘关：Ch3 起，每 3 个心跳组（15 关）在硬仗相位出现一次。
  static bool _isClearBoard(int c, int group, bool hard) =>
      c >= 3 && hard && group % 3 == 2;

  // ─────────────────────────────────────────────────────────────
  //  生成
  // ─────────────────────────────────────────────────────────────

  static LevelDefinition _generateLevel(int id) {
    final (c, p) = _pos(id);
    final phase = rhythmPhase(id);
    final group = _groupOf(id);
    final hard = phase == 4; // 硬仗
    final easy = phase == 0; // 轻松：新车型登场关
    final boss = LevelProgression.isMergeBossLevel(id);
    // Boss 关强制 produce 目标：胜负改成「打空 Boss 血条」，
    // 清盘/限时/限步都与 Boss 战互斥（Boss 相位恒为 0-3，本就不会触发，
    // 这里显式关掉是为了即使相位公式调整也不破不变量）。
    final clearBoard = !boss && _isClearBoard(c, group, hard);

    final tierIdx = _tierIndexFor(id);
    final tier = VehicleType.values[tierIdx];
    final count = _targetCountFor(c, phase);
    final bias = _autoBias(tierIdx, count);

    // 障碍：轻松关减 1（给新车型一个干净的亮相），硬仗关加 1。
    // Boss 关再 +2 —— 「捣乱」的主要手段就是往棋盘上堆干扰物，
    // 让合成路径不得不绕路。Boss 关无万能/炸弹补给（它占的是
    // 不发补给的相位 0），应急工具只能靠看广告支援。
    final pool = _poolFor(c);
    final obsCount = (_obstacleCount(c, p) +
            (hard ? 1 : 0) -
            (easy ? 1 : 0) +
            (boss ? 2 : 0))
        .clamp(1, 6);
    final obstacles = _generateObstacles(obsCount, pool, id);

    // 棋盘：前两章 5×5，之后 6×6（更大的棋盘承载更高的牌堆压力）。
    final size = c <= 1 ? 5 : 6;

    // 特殊机制：按章解锁 + **只挂在动脑/硬仗相位**上按组轮转。
    // 旧版用 id % 11 / % 17 / % 19 这种与难度无关的机械周期，
    // 结果新机制常常落在刚放宽的轻松关上，玩家感知不到"变难了"。
    final armed = phase >= 2;
    final fog = (c >= 5 && armed && group % 3 == 1)
        ? (4 + (c - 5)).clamp(4, 9)
        : 0;
    final wildcards = (c >= 7 && armed && group % 4 == 2)
        ? (2 + (c - 7) ~/ 3).clamp(2, 4)
        : 0;
    final bombs = (c >= 9 && armed && group % 5 == 3)
        ? (1 + (c - 9) ~/ 4).clamp(1, 3)
        : 0;

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
        zhName: '',
        cols: size,
        rows: size,
        stockSize: 0,
        targetTier: tier,
        targetCount: count,
        highTierBias: bias,
      );
      final expected = expectedDraws(draft);
      stock = math.max(14, (expected * _budgetFactor(id, c, p, phase)).round());

      // 限步：Ch6 起，每 4 个心跳组（20 关）在硬仗相位出现一次。
      // 判负线必须宽松（期望的 2.4 倍），它是「别乱点」的引导，不是闸门。
      if (c >= 6 && hard && group % 4 == 3) {
        movesLimit = (expected * 2.4).round().clamp(20, 400);
      }
    }

    // 限时：只在硬仗相位、每 2 个心跳组（10 关）一次。
    // 给硬仗关一个可辨识的身份，而不是每 13 关机械地插一次。
    if (hard && group % 2 == 1) {
      final expected = clearBoard ? stock * 0.75 : stock * 0.42;
      timeLimit = (expected * 4.2).round().clamp(70, 320);
    }

    // 广告挑战关 / 魔王章：清盘关的牌堆同样收紧（produce 关已在
    // [_budgetFactor] 内收过，这里只补 clearBoard 公式分支）。
    // 插在限时之后 —— 限时/限步是「别乱点」的引导线，不随挑战关缩放。
    if (clearBoard) {
      final tighten = LevelProgression.isMergeAdGate(id)
          ? _adGateTighten
          : (LevelProgression.isMergeDemon(id) ? _demonTighten : 1.0);
      if (tighten < 1.0) stock = (stock * tighten).round();
    }

    // bossKey（徽章墙稳定 id）与 spec 同参数算，避免两处公式漂移。
    final bossIndex = (id - firstId - c * chapterSize - 10) ~/ 11;

    return LevelDefinition(
      id: id,
      // 关名存中文原文（导出用）；本地化版本由 LevelDefinition.name 组装。
      zhName: boss ? '👑 Boss · ${_chapterName(id)}' : _chapterName(id),
      cols: size,
      rows: size,
      stockSize: stock,
      goalType: clearBoard ? GoalType.clearBoard : GoalType.produce,
      targetTier: clearBoard ? null : tier,
      targetCount: clearBoard ? 1 : count,
      clearLimit: clearLimit,
      timeLimitSeconds: timeLimit,
      movesLimit: movesLimit,
      // Boss 战配置：HP = 目标车数 +2（多打两下，事件感够但不劝退）。
      // 卡组按章节深度解锁（主+辅技能，尖峰位是招牌 Boss），
      // 详见 [BossSpec.forLevel]。
      boss: boss
          ? BossSpec.forLevel(c, bossIndex, (clearBoard ? 1 : count) + 2)
          : null,
      bossKey: boss ? '$c.$bossIndex' : null,
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

  /// 生成关的关名取章节短名。**必须用 zhShortTitle**——`title` 是本地化
  /// 版本，拿它当落盘关名会让同一台机器换个系统语言就产出不同的关卡数据。
  static String _chapterName(int id) {
    for (final ch in generatedChapters.reversed) {
      if (id >= ch.startId) return ch.zhShortTitle;
    }
    return '街区';
  }
}

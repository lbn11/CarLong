import 'dart:math';

import '../l10n/l10n.dart';
import '../l10n/level_names.dart';
import 'vehicle.dart';
import '../services/level_data_generator.dart';

/// 章节（叙事包装）：手写段每 10 关一章，生成段每 45 关一章。
///
/// `zhTitle` / `zhSubtitle` 是**原文**：导出 `shared/levels` 与生成关卡名
/// 都读它们，必须与 locale 无关。`title` / `subtitle` 才是上界面的本地化
/// 版本（拿不到文案表时回落原文）。
class LevelChapter {
  final String zhTitle;
  final String zhSubtitle;
  final int startId;

  const LevelChapter(this.zhTitle, this.zhSubtitle, this.startId);

  /// 去掉「第 X 章 ·」前缀的纯地名，生成关卡拿它当默认关名。
  String get zhShortTitle => zhTitle.split(' · ').last;

  String get title {
    final l = L10n.current;
    if (l == null) return zhTitle;
    return chapterTitleByStartId(l, startId) ?? zhTitle;
  }

  String get shortTitle {
    final l = L10n.current;
    if (l == null) return zhShortTitle;
    return chapterNameByStartId(l, startId) ?? zhShortTitle;
  }

  String get subtitle {
    final l = L10n.current;
    if (l == null) return zhSubtitle;
    return chapterSubtitleByStartId(l, startId) ?? zhSubtitle;
  }
}

/// 手写段章节表（L1-70，7 章）。
const List<LevelChapter> _handChapters = [
  LevelChapter('第一章 · 街区起步', '从一辆自行车开始你的车队', 1),  // i18n-data
  LevelChapter('第二章 · 城市干线', '车流渐密，货运繁忙', 11),  // i18n-data
  LevelChapter('第三章 · 轨道时代', '高铁地铁，四通八达', 21),  // i18n-data
  LevelChapter('第四章 · 天空征途', '客机战机，冲向云端', 31),  // i18n-data
  LevelChapter('第五章 · 星际探索', '穿梭星辰大海', 41),  // i18n-data
  LevelChapter('第六章 · 星港试炼', '终极枢纽的考验', 51),  // i18n-data
  LevelChapter('第七章 · 机关极限', '限步传送，大师关卡', 61),  // i18n-data
];

/// 合成模式章节表（L1-700 分 21 章：手写 7 章 + 生成 14 章，按 id 区间）。
const List<LevelChapter> levelChapters = [
  ..._handChapters,
  ...LevelDataGenerator.generatedChapters,
];

/// 关卡 id 所属章节（按 startId 取最后一个 <= id 的章）。
LevelChapter chapterForId(int levelId) {
  LevelChapter? last;
  for (final c in levelChapters) {
    if (levelId >= c.startId) {
      last = c;
    }
  }
  return last ?? levelChapters.first;
}

/// 关卡目标类型。
enum GoalType {
  /// 合成指定等级的目标车辆。
  produce,

  /// 把牌堆用完并把棋盘合成清空。
  clearBoard,
}

/// 棋盘障碍物类型。
enum ObstacleType {
  /// 冰块：普通移动不可进入，在其四邻格上合成会消融一层，融完变普通空格。
  ice,

  /// 锁链：不可进入，只能用锤子清除。
  lock,

  /// 石块：永久占格，不可进入、不可清除。
  block,

  /// 传送门：卡片移入后从配对的另一个传送门出现（成对定义，顺序配对）。
  teleport,
}

/// 障碍物的关卡配置（const，写在关卡表里）。
class ObstacleSpec {
  final ObstacleType type;
  final int col;
  final int row;

  /// 冰块层数（其余类型忽略）。
  final int layers;

  const ObstacleSpec(this.type, this.col, this.row, {this.layers = 2});
}

/// 障碍物的运行时状态（层数会随游戏变化）。
class Obstacle {
  final ObstacleType type;
  final int col;
  final int row;
  int layers;

  /// 锁链被锤子移除后为 true。
  bool removed;

  Obstacle.fromSpec(ObstacleSpec spec, {int? layers})
      : type = spec.type,
        col = spec.col,
        row = spec.row,
        layers = layers ?? spec.layers,
        removed = false;

  /// 是否仍生效（冰融完 / 锁被移除后为 false）。
  bool get active =>
      !removed && (type != ObstacleType.ice || layers > 0);
}

/// Boss 攻击技能（卡组制的原子单位）。
///
/// 按打击的维度分四组，全部只打「过程」不打「胜利」：
/// - **原料链**：freeze 冰封（冻住最高档原料车）/ devolve 退化（最高档车
///   打低 1-2 档）/ impound 扣押（拖进车库几秒后放回）
/// - **空间**：steal 拖车（拖走一辆车）/ rubble 塌方（N 块碎石落随机
///   空格占格）/ ice 冰块（单块占格，只作填充技）
/// - **节奏**：lock 锁牌堆（抽牌读条点不动）/ taint 污染（接下来 K 张
///   出牌强制 -1 档）
/// - **博弈**：shield 护盾（周期开盾、产出不计 HP）——**被动光环，不进
///   攻击轮盘**，由 spec.shieldCycle 参数驱动
///
/// 每个技能都必须满足三条红线（踩过的坑见 git 历史）：
/// ① 净压力——不帮玩家腾格子/解冻；② 有反制窗口——预警期玩家能操作
/// 规避或补救；③ 视觉可读——预警环颜色与技能一一对应。
enum BossAttackKind {
  freeze,
  steal,
  lock,
  ice,
  rubble,
  impound,
  devolve,
  taint,
  shield,
  // ── 第二批（2026-10-18）──
  /// 胶水：把一辆车粘住几秒（只随时间干掉，反制 = 等）。
  glue,
  /// 黑洞：空格开旋涡占格，可以把卡拖进去喂给它（吞掉不结算）。
  hole,
  /// 洗牌：全场没冻/粘的车随机重排（搅局，顺带破解死局）。
  shuffle,
  /// 禁合：某等级几秒内不能合并（红 ✕ 标出，预警环点名单辆车）。
  ban,
  /// 抢目标：Boss 抓回一个已达成的目标车补 1 血（唯一碰胜利资源的
  /// 技能，所以金色预警 + 只在水战区/招牌位出现）。
  stealGoal,
  /// 迷雾：盖住几辆车看不见（落子附近可揭开，反制 = 靠记忆/探头）。
  fog,
}

/// Boss 战配置（仅合成模式，null = 普通关）。
///
/// **卡组制**：每个 Boss = 1 主技 + 1 辅技（从章节解锁池抽取）+ 0-1 被动
/// （狂怒 / 护盾）。早期版本是「if(章≥3) 加拖车」的开关式解锁，只增不
/// 减，56 个 Boss 实际只有 4 种技能组、同章 4 个配置完全相同——空洞的
/// 根源不是技能数量而是组装方式。卡组制下同章 4 个不重样，参数再按
/// 关卡 id 派生，同卡组也不同强度。
///
/// 章内第 4 个 Boss（尖峰槽位）是**招牌 Boss**：固定强组合 + 绰号
/// （碎石王 / 回收站 / 退化射线 / 银行家…），给玩家记忆点；普通 Boss
/// 用卡组随机，保持新鲜感。
///
/// 玩家合成目标车 = 攻击 Boss（每次 -1 HP），打空血条即胜。胜利条件
/// 改成打 Boss：Boss 关的叙事就是「击败它」，赢了它还要去凑原来的
/// 产出数，事件感会被稀释。需要的命中数 = 原目标数 +2，不是墙。
class BossSpec {
  /// Boss 总 HP（= 需要产出的目标车总数，含 +2 的 Boss 加码）。
  final int hp;

  /// 攻击间隔（秒）：预警 + 出手都算在内的一次完整攻击周期。
  final double attackInterval;

  /// 首次攻击延迟（秒）：给玩家读条、看清 Boss 长什么样再挨打。
  final double firstDelay;

  /// 主技能：本 Boss 的招牌，一直可用。
  final BossAttackKind primary;

  /// 辅技能：与主技轮换上场（null = 单技能 Boss）。
  final BossAttackKind? secondary;

  /// 招牌绰号中文原文（尖峰 Boss 独有，如「碎石王」；普通卡组 Boss 为 null）。
  /// 上界面请用 [epithetLabel]。
  final String? epithet;

  /// 该 Boss 所属章序号（0 起），本地化 [epithet] 用；非招牌 Boss 为 null。
  final int? epithetChapter;

  /// 上界面的绰号（null = 普通卡组 Boss，由调用方决定兜底文案）。
  String? get epithetLabel {
    if (epithet == null) return null;
    final l = L10n.current;
    if (l == null || epithetChapter == null) return epithet;
    return bossEpithetByChapter(l, epithetChapter!) ?? epithet;
  }

  /// 每次冰封攻击波及几张最高档原料车（狂怒时 +1）。
  final int freezeCount;

  /// 冰封层数：每在邻格完成一次合并融化 1 层。
  final int freezeLayers;

  /// 拖车抢最高档原料车。false = 只拖最低档（新手期轻骚扰，
  /// 免得玩家刚建起的车队就被拆）。
  final bool stealTopTier;

  /// 锁牌堆秒数。0 = 不会锁（牌堆点不动，打断抽牌节奏）。
  final double lockStockSeconds;

  /// 残血（HP ≤ 一半）狂怒：攻击提速、冰封数 +1、整车变红。
  final bool enrageAtHalf;

  /// 塌方：一次落几块碎石（章 8+ 两块）。
  final int rubbleCount;

  /// 扣押：拖进车库几秒后放回场上。
  final int impoundSeconds;

  /// 污染：接下来几张出牌 -1 档。
  final int taintCards;

  /// 退化：打低几档（章 9+ 两档）。
  final int devolveLevels;

  /// 护盾周期（秒，0 = 不会盾；章 9+ 每 12 秒开盾一次）。
  final double shieldCycle;

  /// 护盾持续秒数（盾期间产出不计 HP）。
  final double shieldDuration;

  /// 胶水：粘几秒（章越深越久，4-6 秒）。
  final double glueSeconds;

  /// 黑洞：旋涡持续秒数。
  final double holeSeconds;

  /// 禁合：某等级禁止合并秒数。
  final double banSeconds;

  /// 迷雾：一次盖住几辆车。
  final int fogCells;

  const BossSpec({
    required this.hp,
    this.attackInterval = 9,
    this.firstDelay = 6,
    this.primary = BossAttackKind.freeze,
    this.secondary,
    this.epithet,
    this.epithetChapter,
    this.freezeCount = 1,
    this.freezeLayers = 2,
    this.stealTopTier = false,
    this.lockStockSeconds = 0,
    this.enrageAtHalf = false,
    this.rubbleCount = 1,
    this.impoundSeconds = 3,
    this.taintCards = 2,
    this.devolveLevels = 1,
    this.shieldCycle = 0,
    this.shieldDuration = 3,
    this.glueSeconds = 4,
    this.holeSeconds = 6,
    this.banSeconds = 4,
    this.fogCells = 2,
  });

  /// 按章节深度推导卡组（Boss 成长线，见类文档）。
  ///
  /// [chapterIdx] 生成段章索引（0..13），[bossIndex] 章内 Boss 序号
  /// （0..3；3 = 尖峰招牌位），[hp] 目标车数 +2。
  ///
  /// 攻击技能池按章解锁（同维度不堆同技能，保持组合差异）：
  /// - 章 0-1：冰封 + 拖车（新手期轻骚扰）
  /// - 章 2-3：+ 塌方 + 扣押
  /// - 章 3：+ 胶水（第一种「等时间」型干扰）
  /// - 章 4-5：+ 退化、洗牌
  /// - 章 6-7：+ 污染 + 锁牌堆 + 禁合
  /// - 章 7-8：+ 黑洞、迷雾
  /// - 章 9+：+ 抢目标（唯一碰胜利资源的技能，压轴）
  ///
  /// 普通 Boss 主技按序号轮转（保证同章不重样）、辅技按种子抽；
  /// 尖峰 Boss 查招牌表。被动（狂怒章 11+ / 护盾章 9+）与攻击卡组
  /// 正交叠加。种子带章号与序号——同一关每次生成结果一致（可测试、
  /// 可复现），不同关不同。
  factory BossSpec.forLevel(int chapterIdx, int bossIndex, int hp) {
    final c = chapterIdx;
    final pool = <BossAttackKind>[
      BossAttackKind.freeze,
      BossAttackKind.steal,
    ];
    if (c >= 2) pool.addAll([BossAttackKind.rubble, BossAttackKind.impound]);
    if (c >= 3) pool.add(BossAttackKind.glue);
    if (c >= 4) pool.add(BossAttackKind.devolve);
    if (c >= 5) pool.add(BossAttackKind.shuffle);
    if (c >= 6) {
      pool.addAll([BossAttackKind.taint, BossAttackKind.lock]);
    }
    if (c >= 6) pool.add(BossAttackKind.ban);
    if (c >= 7) pool.add(BossAttackKind.hole);
    if (c >= 8) pool.add(BossAttackKind.fog);
    if (c >= 9) pool.add(BossAttackKind.stealGoal);
    // ice 是填充技不进卡组。

    final rnd = Random(c * 31 + bossIndex * 7 + 101);
    final sig = _signatureDeck(c);
    BossAttackKind primary;
    BossAttackKind? secondary;
    String? epithet;
    var shieldCycle = 0.0;

    if (bossIndex == 3) {
      // 尖峰招牌：固定强组合 + 绰号。
      primary = sig.$1;
      secondary = sig.$2;
      epithet = sig.$3;
      shieldCycle = sig.$4 ? 12 : 0;
    } else {
      // 主技轮转带章偏移：pool[(序号 + 章×2) % 池长]。只按序号轮转时
      // 深章也永远从池头（冰封/拖车/塌方）起跳，池尾技能（抢目标等）
      // 只能当辅技偶然露脸；加章偏移后每章领头羊不同，覆盖更匀。
      // 池 ≥3 时三个序号的主技必然互异（连续三格）；池 =2 的章 0-1
      // 刻意让 0/2 号位重复（新手期先练熟冰封+拖车）。
      primary = pool[(bossIndex + c * 2) % pool.length];
      var rest = pool.where((k) => k != primary).toList();
      // 辅技避开招牌组合：尖峰位要独一份，不能被普通位抢先。
      if (primary == sig.$1 && rest.length > 1) {
        rest = rest.where((k) => k != sig.$2).toList();
      }
      secondary = rest[rnd.nextInt(rest.length)];
      // 章 9+ 普通 Boss 也有半数概率带护盾光环（深水区压迫感）。
      if (c >= 9 && rnd.nextDouble() < 0.5) shieldCycle = 12;
    }

    return BossSpec(
      hp: hp,
      primary: primary,
      secondary: secondary,
      epithet: epithet,
      epithetChapter: epithet == null ? null : c,
      attackInterval: 9,
      firstDelay: 6,
      // 含冰封的卡组从章 3 起就冻两张（「双重冻气」提前登场）。
      freezeCount: c >= 11 || (c >= 3 && _hasFreeze(primary, secondary))
          ? 2
          : 1,
      freezeLayers: 2,
      stealTopTier: c >= 3,
      lockStockSeconds: c >= 7 ? 3.0 : 0,
      enrageAtHalf: c >= 11,
      rubbleCount: c >= 8 ? 2 : 1,
      impoundSeconds: (3 + c ~/ 3).clamp(3, 6),
      taintCards: c >= 6 ? 3 : 2,
      devolveLevels: c >= 9 ? 2 : 1,
      glueSeconds: (4 + c ~/ 4).clamp(4, 6).toDouble(),
      holeSeconds: 6,
      banSeconds: (3 + c ~/ 4).clamp(3, 5).toDouble(),
      fogCells: (2 + c ~/ 6).clamp(2, 4),
      shieldCycle: shieldCycle,
      shieldDuration: 3,
    );
  }

  static bool _hasFreeze(BossAttackKind a, BossAttackKind? b) =>
      a == BossAttackKind.freeze || b == BossAttackKind.freeze;

  /// 招牌 Boss 表（章 0..13 的尖峰位）：
  /// (主技, 辅技, 绰号, 是否带护盾)。
  ///
  /// 排布逻辑：前 10 章每章亮出一个新技能的「纯正形态」（碎石王 /
  /// 回收站 / 退化射线 / 毒池…），后 4 章上双强组合 + 护盾，终章
  /// 「终局车王」冰封 + 扣押 + 盾全齐。第二批技能（胶水/黑洞/洗牌/
  /// 禁合/迷雾/抢目标）从第 10 章起进招牌位——新机制先在普通池
  /// 里让玩家见过面，尖峰位再给记忆点。
  static (BossAttackKind, BossAttackKind?, String, bool) _signatureDeck(
      int c) {
    const decks = <(BossAttackKind, BossAttackKind?, String, bool)>[
      (BossAttackKind.rubble, BossAttackKind.freeze, '碎石王', false),  // i18n-data
      (BossAttackKind.impound, BossAttackKind.steal, '回收站', false),  // i18n-data
      (BossAttackKind.devolve, BossAttackKind.freeze, '退化射线', false),  // i18n-data
      (BossAttackKind.freeze, BossAttackKind.rubble, '双重冻气', false),  // i18n-data
      (BossAttackKind.taint, BossAttackKind.lock, '毒池', false),  // i18n-data
      (BossAttackKind.impound, BossAttackKind.devolve, '拆迁队', false),  // i18n-data
      (BossAttackKind.freeze, BossAttackKind.taint, '霜寒之心', false),  // i18n-data
      (BossAttackKind.lock, BossAttackKind.taint, '银行家', true),  // i18n-data
      (BossAttackKind.rubble, BossAttackKind.impound, '崩落巨兽', false),  // i18n-data
      (BossAttackKind.devolve, BossAttackKind.taint, '蚀变工场', true),  // i18n-data
      (BossAttackKind.lock, BossAttackKind.ban, '终焉保险', true),  // i18n-data
      (BossAttackKind.taint, BossAttackKind.fog, '腐败漩涡', true),  // i18n-data
      (BossAttackKind.devolve, BossAttackKind.glue, '铁锈君王', true),  // i18n-data
      (BossAttackKind.freeze, BossAttackKind.impound, '终局车王', true),  // i18n-data
    ];
    return decks[c.clamp(0, decks.length - 1)];
  }
}

/// 一次关卡的定义。
class LevelDefinition {
  final int id;

  /// 中文关名原文。**导出 `shared/levels` 只准读它**——`name` 会随
  /// 系统语言变，写进数据文件等于每台机器产出不同关卡表。
  final String zhName;

  final int cols;
  final int rows;

  /// 本关牌堆总张数。点一下出牌，牌从牌堆进入棋盘。
  final int stockSize;
  final GoalType goalType;

  /// 目标等级（produce 目标使用；clearBoard 目标为 null）。
  final VehicleType? targetTier;
  final int targetCount;

  /// 限时秒数（null = 不限时）。可与任意目标类型叠加。
  final int? timeLimitSeconds;

  /// 限步数（null = 不限步数）。每放置/移动一张卡消耗 1 步。
  final int? movesLimit;

  /// 高等级卡出现偏置：>0 时显著提升靠上目标等级区间的出牌概率，
  /// 用于让磁悬浮/空间站/彗星等超高目标在对应关卡里可达成。
  final int highTierBias;

  /// 开局放置在棋盘上的万能卡数量。
  final int wildcards;

  /// 开局放置在棋盘上的炸弹卡数量。
  final int bombs;

  /// clearBoard 目标的残留上限：牌堆抽完时棋盘剩余堆数 ≤ 此值即胜利。
  /// 合并-3 机制下"绝对清空"需要全局三进制守恒（概率≈0），
  /// 以残留上限闭环；模拟显示顶部窗口出牌时残堆 ≤4 概率约 90%、≤6 约 99%。
  final int? clearLimit;

  /// clearBoard 胜利判定：牌堆抽完后棋盘剩余堆数是否达标。
  bool boardCleared(int tileCount) => tileCount <= (clearLimit ?? 0);

  /// 开局被迷雾盖住的格子数（靠近/落子后揭开）。
  final int fogCells;

  /// 无尽模式：目标达成后自动升级，牌堆无限，死局即结束。
  final bool endless;

  /// Boss 战配置（null = 非 Boss 关）：棋盘上有会动的 Boss，
  /// 合成目标车攻击它，HP 打空即胜（详见 [BossSpec]）。
  final BossSpec? boss;

  /// Boss 徽章墙的稳定 key：`「章索引.Boss序号」`（如 "3.2"）。
  /// 生成时算好（与 [BossSpec.forLevel] 同参数），结算/徽章墙共用；
  /// null = 非 Boss 关。不用关卡 id：重温旧关不重复解锁同一枚徽章。
  final String? bossKey;

  /// 每日挑战：参与每日玩法（不推进关卡解锁、不记录星级）。
  final bool daily;

  /// 棋盘上的障碍物。
  final List<ObstacleSpec> obstacles;

  const LevelDefinition({
    required this.id,
    required this.zhName,
    required this.cols,
    required this.rows,
    required this.stockSize,
    required this.targetTier,
    required this.targetCount,
    this.goalType = GoalType.produce,
    this.timeLimitSeconds,
    this.movesLimit,
    this.highTierBias = 0,
    this.wildcards = 0,
    this.bombs = 0,
    this.clearLimit,
    this.fogCells = 0,
    this.endless = false,
    this.daily = false,
    this.boss,
    this.bossKey,
    this.obstacles = const [],
  });

  /// 上界面的关名（随 locale 变）。拿不到文案表时回落 [zhName]。
  ///
  /// 三段分流：每日挑战 / 无尽 / 主线。主线再按 id 分界——1..70 是手写关
  /// （关名逐关不同，查 [levelNameById]），71..700 由生成器产出（关名
  /// 就是章节名，Boss 关再套一层 `👑 Boss ·`）。超出这两段的自造关卡
  /// （测试、活动）直接用 [zhName]。
  String get name {
    final l = L10n.current;
    if (l == null) return zhName;
    if (daily) return l.dailyChallengeName;
    if (endless) return l.levelEndlessName;
    if (id >= 1 && id <= 70) {
      return levelNameById(l, id) ?? zhName;
    }
    if (id > 70 && id <= 700) {
      final ch = chapterForId(id);
      return boss != null ? l.bossLevelName(ch.shortTitle) : ch.shortTitle;
    }
    return zhName;
  }

  /// 出生权重：窗口式分布，出牌集中在目标下方 3 档内。
  /// produce 目标只生成【低于】目标等级的卡片——目标车必须靠合成产出，
  /// 避免"抽到目标卡却在棋盘上却不计数"的困惑（producedCount 只在合成升级命中时加）。
  ///
  /// 历史：17 档时代用"线性递减"权重（低档多、高档少），链深=目标档位；
  /// 迁移到 50 车系统后目标档位深度翻倍（truck 5→12、rocket 7→44），
  /// 线性权重下深目标的期望出牌数远超牌堆预算，设计上不可达成。
  /// 改为窗口式：距目标 0/1/2/3 档权重 12/8/5/3，更低档位保留长尾 1 用于填场，
  /// 链深恒定 ≈3~4，任何目标都能在原设计的 stockSize 内合成出来。
  ///
  /// clearBoard 特例：出牌只落在最高 3 档（49:12 / 48:8 / 47:5），
  /// 链深 ≤2 即触顶消失，残堆分布稳定（0.9 概率 ≤4 堆），配合 clearLimit 闭环。
  List<int> spawnWeights() {
    final maxIdx = VehicleType.values.length - 1;
    if (goalType == GoalType.clearBoard) {
      final w = List.filled(maxIdx + 1, 0);
      w[maxIdx] = 12;
      w[maxIdx - 1] = 8;
      w[maxIdx - 2] = 5;
      return w;
    }
    final baseIdx = (targetTier!.index - 1).clamp(0, maxIdx);
    final t = baseIdx.clamp(0, maxIdx);
    final topN = highTierBias.clamp(0, t + 1);
    return List.generate(
      t + 1,
      (i) {
        final d = t - i;
        final base = switch (d) {
          0 => 12,
          1 => 8,
          2 => 5,
          3 => 3,
          _ => 1,
        };
        return base + (i > t - topN ? (i - (t - topN)) * 4 : 0);
      },
    );
  }

  /// 关卡目标的一句话描述（HUD/主页/结算用）。
  ///
  /// 会随 locale 变：拿不到文案表（单测直接构造 level）时回落到中文字面量。
  /// 注意 **不能**把它写进存档或导出——那是 `shared/levels` 的事，
  /// 导出器只认 `name` 这类与 locale 无关的字段。
  String get goalText {
    final l = L10n.current;
    final limit = timeLimitSeconds;
    final moves = movesLimit;
    final goal = switch (goalType) {
      GoalType.produce => l == null
          ? '目标：合成 ${targetTier!.name} ×$targetCount'  // i18n-data
              '${boss != null ? '（攻击 👑 Boss）' : ''}'
          : (boss != null
              ? l.goalProduceBoss(targetTier!.name, targetCount)
              : l.goalProduce(targetTier!.name, targetCount)),
      GoalType.clearBoard => l == null
          ? '目标：用光牌堆，场上剩 ≤${clearLimit ?? 0} 组车'  // i18n-data
          : l.goalClearBoard(clearLimit ?? 0),
    };
    final obs = obstacles.isEmpty
        ? ''
        : obstacles
            .map((o) => switch (o.type) {
                  ObstacleType.ice => '❄',
                  ObstacleType.lock => '🔒',
                  ObstacleType.block => '🪨',
                  ObstacleType.teleport => '🌀',
                })
            .toSet()
            .join();
    final special = [
      if (wildcards > 0) l == null ? '⭐ 万能卡×$wildcards' : l.bonusWildcard(wildcards),
      if (bombs > 0) l == null ? '💣 炸弹×$bombs' : l.bonusBomb(bombs),
      if (fogCells > 0) l == null ? '🌫 迷雾×$fogCells' : l.bonusFog(fogCells),
    ].join(' ');
    final body = '$goal$obs$special';
    if (moves != null) {
      return l == null ? '$moves 步内$body' : l.goalWithinMoves(moves, body);
    }
    if (limit != null) {
      return l == null ? '$limit 秒内$body' : l.goalWithinTime(limit, body);
    }
    return body;
  }
}

/// 无尽模式关卡定义（不进关卡列表，主页单独入口）。
const endlessLevel = LevelDefinition(
  id: 999,
  zhName: '无尽模式',
  cols: 5,
  rows: 5,
  stockSize: 999,
  targetTier: VehicleType.taxi,
  targetCount: 3,
  endless: true,
);

/// 手写主线关卡（L1-70，7 章），70 关之后由 [LevelDataGenerator] 程序化扩展。
const _handLevels = <LevelDefinition>[
  LevelDefinition(
    id: 1,
    zhName: '清晨路段',
    cols: 4,
    rows: 3,
    stockSize: 18,
    targetTier: VehicleType.taxi,
    targetCount: 1,
  ),
  LevelDefinition(
    id: 2,
    zhName: '早高峰',
    cols: 4,
    rows: 4,
    stockSize: 24,
    targetTier: VehicleType.bus,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 1, 2),
    ],
  ),
  LevelDefinition(
    id: 3,
    zhName: '环城快线',
    cols: 5,
    rows: 4,
    stockSize: 30,
    targetTier: VehicleType.truck,
    targetCount: 1,
    fogCells: 6,
  ),
  LevelDefinition(
    id: 4,
    zhName: '货运枢纽',
    cols: 5,
    rows: 4,
    stockSize: 38,
    targetTier: VehicleType.truck,
    highTierBias: 1,
    targetCount: 2,
  ),
  LevelDefinition(
    id: 5,
    zhName: '钢铁干线',
    cols: 5,
    rows: 5,
    stockSize: 34,
    targetTier: VehicleType.highspeed,
    highTierBias: 1,
    targetCount: 1,
  ),
  LevelDefinition(
    id: 6,
    zhName: '星光清道夫',
    cols: 5,
    rows: 5,
    stockSize: 30,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 6,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.block, 3, 3),
    ],
  ),
  LevelDefinition(
    id: 7,
    zhName: '午夜冲刺',
    cols: 4,
    rows: 4,
    // 数值校准：原 stock=20 时预算占用率 0.70（全表最紧，第 7 关就要榨干牌堆，
    // 与「放松无挫折」定位冲突）。放宽到 26 → 占用率 0.54，落回心流通道。
    stockSize: 26,
    targetTier: VehicleType.taxi,
    highTierBias: 1,
    targetCount: 3,
    timeLimitSeconds: 60,
  ),
  LevelDefinition(
    id: 8,
    zhName: '都市高速',
    cols: 5,
    rows: 4,
    stockSize: 34,
    targetTier: VehicleType.truck,
    highTierBias: 1,
    targetCount: 3,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 1),
      ObstacleSpec(ObstacleType.ice, 4, 2),
    ],
  ),
  LevelDefinition(
    id: 9,
    zhName: '限时清道夫',
    cols: 5,
    rows: 5,
    stockSize: 30,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 6,
    timeLimitSeconds: 75,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 0),
      ObstacleSpec(ObstacleType.ice, 3, 4),
      ObstacleSpec(ObstacleType.lock, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 10,
    zhName: '终局冲刺',
    cols: 5,
    rows: 5,
    stockSize: 40,
    targetTier: VehicleType.highspeed,
    highTierBias: 2,
    targetCount: 3,
    timeLimitSeconds: 120,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 4, 4, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 4),
      ObstacleSpec(ObstacleType.block, 1, 3),
    ],
  ),
  LevelDefinition(
    id: 11,
    zhName: '街头初段',
    cols: 4,
    rows: 4,
    stockSize: 22,
    targetTier: VehicleType.scooter,
    targetCount: 3,
    timeLimitSeconds: 45,
  ),
  LevelDefinition(
    id: 12,
    zhName: '环城小巴',
    cols: 4,
    rows: 4,
    stockSize: 26,
    targetTier: VehicleType.bus,
    highTierBias: 1,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 1),
      ObstacleSpec(ObstacleType.ice, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 13,
    zhName: '冰雪送货',
    cols: 4,
    rows: 5,
    stockSize: 30,
    targetTier: VehicleType.truck,
    highTierBias: 1,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 2),
      ObstacleSpec(ObstacleType.ice, 3, 4, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 14,
    zhName: '限时货运',
    cols: 4,
    rows: 4,
    stockSize: 24,
    targetTier: VehicleType.truck,
    highTierBias: 1,
    targetCount: 1,
    timeLimitSeconds: 60,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 15,
    zhName: '清道夫之巅',
    cols: 5,
    rows: 5,
    stockSize: 34,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 6,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.ice, 0, 4, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 16,
    zhName: '轨道延伸',
    cols: 4,
    rows: 5,
    stockSize: 32,
    targetTier: VehicleType.highspeed,
    highTierBias: 1,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 3),
      ObstacleSpec(ObstacleType.ice, 2, 0),
      ObstacleSpec(ObstacleType.block, 3, 3),
    ],
  ),
  LevelDefinition(
    id: 17,
    zhName: '火箭升空',
    cols: 5,
    rows: 5,
    stockSize: 38,
    targetTier: VehicleType.rocket,
    highTierBias: 1,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.lock, 4, 0),
    ],
  ),
  LevelDefinition(
    id: 18,
    zhName: '限时清盘 II',
    cols: 5,
    rows: 5,
    stockSize: 32,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 6,
    timeLimitSeconds: 90,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 4),
      ObstacleSpec(ObstacleType.block, 4, 1),
    ],
  ),
  LevelDefinition(
    id: 19,
    zhName: '重装集结',
    cols: 5,
    rows: 5,
    stockSize: 40,
    targetTier: VehicleType.highspeed,
    highTierBias: 2,
    targetCount: 3,
    timeLimitSeconds: 120,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 0, layers: 2),
      ObstacleSpec(ObstacleType.lock, 3, 4),
      ObstacleSpec(ObstacleType.block, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 20,
    zhName: '终极枢纽',
    cols: 5,
    rows: 6,
    stockSize: 44,
    targetTier: VehicleType.subway,
    highTierBias: 2,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 3),
      ObstacleSpec(ObstacleType.ice, 4, 0, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 3),
      ObstacleSpec(ObstacleType.block, 1, 1),
    ],
  ),
  LevelDefinition(
    id: 21,
    zhName: '快速轨道',
    cols: 5,
    rows: 5,
    stockSize: 36,
    targetTier: VehicleType.highspeed,
    highTierBias: 1,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 1),
      ObstacleSpec(ObstacleType.ice, 3, 3),
    ],
  ),
  LevelDefinition(
    id: 22,
    zhName: '油罐运输',
    cols: 5,
    rows: 5,
    stockSize: 36,
    targetTier: VehicleType.tanker,
    highTierBias: 2,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 2, 2),
      ObstacleSpec(ObstacleType.ice, 0, 4),
    ],
  ),
  LevelDefinition(
    id: 23,
    zhName: '清道夫 III',
    cols: 5,
    rows: 5,
    stockSize: 32,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 6,
    timeLimitSeconds: 75,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.lock, 3, 3),
      ObstacleSpec(ObstacleType.ice, 4, 0),
    ],
  ),
  LevelDefinition(
    id: 24,
    zhName: '高铁提速',
    cols: 5,
    rows: 6,
    stockSize: 42,
    targetTier: VehicleType.subway,
    highTierBias: 2,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 2),
      ObstacleSpec(ObstacleType.ice, 4, 3),
    ],
  ),
  LevelDefinition(
    id: 25,
    zhName: '地铁高峰',
    cols: 5,
    rows: 6,
    stockSize: 44,
    targetTier: VehicleType.subway,
    highTierBias: 4,
    targetCount: 3,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 1),
      ObstacleSpec(ObstacleType.ice, 4, 4),
    ],
  ),
  LevelDefinition(
    id: 26,
    zhName: '机场跑道',
    cols: 5,
    rows: 6,
    stockSize: 44,
    targetTier: VehicleType.airliner,
    highTierBias: 1,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.lock, 4, 1),
    ],
  ),
  LevelDefinition(
    id: 27,
    zhName: '限时清盘 III',
    cols: 5,
    rows: 6,
    stockSize: 36,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 6,
    timeLimitSeconds: 90,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.lock, 2, 5),
      ObstacleSpec(ObstacleType.ice, 4, 2),
    ],
  ),
  LevelDefinition(
    id: 28,
    zhName: '空中走廊',
    cols: 5,
    rows: 6,
    stockSize: 46,
    targetTier: VehicleType.airliner,
    highTierBias: 2,
    targetCount: 2,
    timeLimitSeconds: 150,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 4),
      ObstacleSpec(ObstacleType.ice, 3, 0),
      ObstacleSpec(ObstacleType.block, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 29,
    zhName: '港铁枢纽',
    cols: 5,
    rows: 6,
    stockSize: 48,
    targetTier: VehicleType.subway,
    highTierBias: 4,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 4, 5, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 3),
    ],
  ),
  LevelDefinition(
    id: 30,
    zhName: '千钧一发',
    cols: 5,
    rows: 6,
    stockSize: 40,
    targetTier: VehicleType.airliner,
    highTierBias: 3,
    targetCount: 2,
    timeLimitSeconds: 120,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.block, 3, 4),
      ObstacleSpec(ObstacleType.lock, 2, 5),
    ],
  ),
  LevelDefinition(
    id: 31,
    zhName: '六轨立交',
    cols: 6,
    rows: 6,
    stockSize: 46,
    targetTier: VehicleType.tanker,
    highTierBias: 2,
    targetCount: 3,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 1),
      ObstacleSpec(ObstacleType.ice, 4, 4),
    ],
  ),
  LevelDefinition(
    id: 32,
    zhName: '战机升空',
    cols: 6,
    rows: 6,
    stockSize: 50,
    targetTier: VehicleType.fighter,
    highTierBias: 1,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.lock, 4, 1),
    ],
  ),
  LevelDefinition(
    id: 33,
    zhName: '清盘极限',
    cols: 6,
    rows: 6,
    stockSize: 42,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 5,
    timeLimitSeconds: 100,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
      ObstacleSpec(ObstacleType.ice, 2, 4),
    ],
  ),
  LevelDefinition(
    id: 34,
    zhName: '空中霸主',
    cols: 6,
    rows: 6,
    stockSize: 52,
    targetTier: VehicleType.fighter,
    highTierBias: 2,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 4, 5, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 35,
    zhName: '暴风限时',
    cols: 6,
    rows: 6,
    stockSize: 44,
    targetTier: VehicleType.fighter,
    highTierBias: 3,
    targetCount: 2,
    timeLimitSeconds: 150,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 3, 3),
      ObstacleSpec(ObstacleType.lock, 1, 4),
      ObstacleSpec(ObstacleType.ice, 5, 1),
    ],
  ),
  LevelDefinition(
    id: 36,
    zhName: '星际预演',
    cols: 6,
    rows: 6,
    stockSize: 54,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 1,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.block, 3, 3),
      ObstacleSpec(ObstacleType.lock, 5, 0),
    ],
  ),
  LevelDefinition(
    id: 37,
    zhName: '多重拦截',
    cols: 6,
    rows: 6,
    stockSize: 56,
    targetTier: VehicleType.fighter,
    highTierBias: 3,
    targetCount: 3,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 0, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 4),
      ObstacleSpec(ObstacleType.block, 4, 2),
    ],
  ),
  LevelDefinition(
    id: 38,
    zhName: '限时清盘 IV',
    cols: 6,
    rows: 6,
    stockSize: 48,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 5,
    timeLimitSeconds: 120,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
      ObstacleSpec(ObstacleType.lock, 2, 2),
      ObstacleSpec(ObstacleType.ice, 4, 4),
    ],
  ),
  LevelDefinition(
    id: 39,
    zhName: '重装巅峰',
    cols: 6,
    rows: 6,
    stockSize: 58,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 3,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.block, 4, 4),
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 5, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 40,
    zhName: '终局预演',
    cols: 6,
    rows: 6,
    stockSize: 56,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 2,
    targetCount: 2,
    timeLimitSeconds: 180,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 2, 1),
      ObstacleSpec(ObstacleType.lock, 3, 4),
      ObstacleSpec(ObstacleType.block, 0, 3),
      ObstacleSpec(ObstacleType.ice, 5, 2),
    ],
  ),
  LevelDefinition(
    id: 41,
    zhName: '星辰之路',
    cols: 6,
    rows: 6,
    stockSize: 58,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 2,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 5, layers: 3),
      ObstacleSpec(ObstacleType.block, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 42,
    zhName: '极限清盘',
    cols: 6,
    rows: 6,
    stockSize: 50,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 5,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
      ObstacleSpec(ObstacleType.lock, 1, 4),
      ObstacleSpec(ObstacleType.ice, 4, 1),
    ],
  ),
  LevelDefinition(
    id: 43,
    zhName: '深空舰队',
    cols: 6,
    rows: 6,
    stockSize: 60,
    targetTier: VehicleType.fighter,
    highTierBias: 4,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.block, 3, 3),
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 0, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 44,
    zhName: '时空之门',
    cols: 6,
    rows: 6,
    stockSize: 58,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 2,
    targetCount: 2,
    timeLimitSeconds: 150,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.block, 4, 4),
      ObstacleSpec(ObstacleType.lock, 2, 5),
      ObstacleSpec(ObstacleType.lock, 3, 0),
    ],
  ),
  LevelDefinition(
    id: 45,
    zhName: '群星汇聚',
    cols: 6,
    rows: 6,
    stockSize: 60,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 4,
    targetCount: 3,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 4, layers: 3),
      ObstacleSpec(ObstacleType.ice, 4, 1, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 2),
      ObstacleSpec(ObstacleType.block, 3, 3),
    ],
  ),
  LevelDefinition(
    id: 46,
    zhName: '命运交叉',
    cols: 6,
    rows: 6,
    stockSize: 62,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 3,
    targetCount: 3,
    timeLimitSeconds: 200,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 3),
      ObstacleSpec(ObstacleType.block, 5, 2),
      ObstacleSpec(ObstacleType.lock, 2, 1),
      ObstacleSpec(ObstacleType.lock, 3, 4),
    ],
  ),
  LevelDefinition(
    id: 47,
    zhName: '混沌清盘',
    cols: 6,
    rows: 6,
    stockSize: 54,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 5,
    timeLimitSeconds: 150,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
      ObstacleSpec(ObstacleType.block, 2, 4),
      ObstacleSpec(ObstacleType.ice, 3, 1, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 48,
    zhName: '星际舰队',
    cols: 6,
    rows: 6,
    stockSize: 62,
    targetTier: VehicleType.fighter,
    highTierBias: 4,
    targetCount: 2,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.block, 3, 3),
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 5, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 49,
    zhName: '破晓之辉',
    cols: 6,
    rows: 6,
    stockSize: 64,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 3,
    targetCount: 3,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 5),
      ObstacleSpec(ObstacleType.block, 5, 0),
      ObstacleSpec(ObstacleType.lock, 2, 3),
      ObstacleSpec(ObstacleType.lock, 3, 2),
      ObstacleSpec(ObstacleType.ice, 1, 1),
    ],
  ),
  LevelDefinition(
    id: 50,
    zhName: '终极星港',
    cols: 6,
    rows: 6,
    // 数值校准：原 stock=66 时预算占用率 0.62（偏紧）。放宽到 78 → 0.53。
    stockSize: 78,
    targetTier: VehicleType.spaceShuttle,
    highTierBias: 7,
    targetCount: 4,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.block, 4, 4),
      ObstacleSpec(ObstacleType.lock, 2, 4),
      ObstacleSpec(ObstacleType.lock, 3, 1),
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 5, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 51,
    zhName: '星港终战',
    cols: 6,
    rows: 6,
    stockSize: 70,
    targetTier: VehicleType.warpShip,
    highTierBias: 1,
    targetCount: 1,
    timeLimitSeconds: 180,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.block, 4, 4),
      ObstacleSpec(ObstacleType.lock, 2, 3),
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 0, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 52,
    zhName: '磁浮首航',
    cols: 6,
    rows: 6,
    stockSize: 70,
    targetTier: VehicleType.maglev,
    targetCount: 1,
    highTierBias: 6,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 2),
      ObstacleSpec(ObstacleType.ice, 4, 3),
    ],
  ),
  LevelDefinition(
    id: 53,
    zhName: '轨道穿越',
    cols: 6,
    rows: 6,
    stockSize: 74,
    targetTier: VehicleType.spaceStation,
    targetCount: 1,
    highTierBias: 8,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 2, 2),
      ObstacleSpec(ObstacleType.lock, 3, 3),
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 54,
    zhName: '彗星追迹',
    cols: 6,
    rows: 6,
    stockSize: 78,
    targetTier: VehicleType.starship,
    targetCount: 1,
    highTierBias: 10,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 1, layers: 3),
      ObstacleSpec(ObstacleType.ice, 4, 4, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 4),
      ObstacleSpec(ObstacleType.block, 3, 1),
    ],
  ),
  LevelDefinition(
    id: 55,
    zhName: '限步物流',
    cols: 5,
    rows: 6,
    stockSize: 42,
    targetTier: VehicleType.truck,
    highTierBias: 1,
    targetCount: 3,
    movesLimit: 45,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 2),
      ObstacleSpec(ObstacleType.ice, 4, 3),
    ],
  ),
  LevelDefinition(
    id: 56,
    zhName: '限步高铁',
    cols: 6,
    rows: 6,
    stockSize: 46,
    targetTier: VehicleType.subway,
    highTierBias: 3,
    targetCount: 3,
    movesLimit: 55,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 2, 1),
      ObstacleSpec(ObstacleType.lock, 3, 4),
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 57,
    zhName: '限步清盘',
    cols: 6,
    rows: 6,
    stockSize: 54,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 5,
    movesLimit: 70,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
      ObstacleSpec(ObstacleType.ice, 2, 4),
      ObstacleSpec(ObstacleType.lock, 4, 1),
    ],
  ),
  LevelDefinition(
    id: 58,
    zhName: '极限清盘',
    cols: 6,
    rows: 6,
    stockSize: 56,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 4,
    timeLimitSeconds: 120,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 0),
      ObstacleSpec(ObstacleType.block, 4, 5),
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.lock, 3, 3),
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 0, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 59,
    zhName: '星云迷雾',
    cols: 5,
    rows: 5,
    stockSize: 52,
    targetTier: VehicleType.rocket,
    targetCount: 1,
    fogCells: 8,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 2, 2, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 60,
    zhName: '传送枢纽',
    cols: 5,
    rows: 6,
    stockSize: 58,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 4,
    obstacles: [
      ObstacleSpec(ObstacleType.teleport, 1, 1),
      ObstacleSpec(ObstacleType.teleport, 3, 4),
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 4, 5),
      ObstacleSpec(ObstacleType.ice, 2, 5),
    ],
  ),
  LevelDefinition(
    id: 61,
    zhName: '万能试炼',
    cols: 5,
    rows: 5,
    stockSize: 50,
    targetTier: VehicleType.highspeed,
    targetCount: 1,
    wildcards: 3,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 62,
    zhName: '爆破拆除',
    cols: 5,
    rows: 5,
    stockSize: 48,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 4,
    bombs: 2,
    timeLimitSeconds: 90,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 4, 4),
      ObstacleSpec(ObstacleType.lock, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 63,
    zhName: '迷雾列车',
    cols: 6,
    rows: 6,
    stockSize: 62,
    targetTier: VehicleType.subway,
    highTierBias: 1,
    targetCount: 2,
    fogCells: 6,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.ice, 5, 5, layers: 3),
      ObstacleSpec(ObstacleType.block, 2, 3),
    ],
  ),
  LevelDefinition(
    id: 64,
    zhName: '双重传送',
    cols: 6,
    rows: 6,
    stockSize: 66,
    targetTier: VehicleType.airliner,
    highTierBias: 1,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.teleport, 0, 0),
      ObstacleSpec(ObstacleType.teleport, 5, 5),
      ObstacleSpec(ObstacleType.teleport, 1, 2),
      ObstacleSpec(ObstacleType.teleport, 4, 3),
      ObstacleSpec(ObstacleType.lock, 2, 1),
      ObstacleSpec(ObstacleType.ice, 3, 4, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 65,
    zhName: '万能火箭',
    cols: 6,
    rows: 6,
    stockSize: 68,
    targetTier: VehicleType.rocket,
    highTierBias: 1,
    targetCount: 2,
    wildcards: 4,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 66,
    zhName: '炸弹狂潮',
    cols: 6,
    rows: 6,
    stockSize: 64,
    targetTier: VehicleType.tanker,
    highTierBias: 1,
    targetCount: 2,
    bombs: 3,
    timeLimitSeconds: 120,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
    ],
  ),
  LevelDefinition(
    id: 67,
    zhName: '传送清盘',
    cols: 6,
    rows: 6,
    stockSize: 60,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 4,
    movesLimit: 60,
    obstacles: [
      ObstacleSpec(ObstacleType.teleport, 0, 2),
      ObstacleSpec(ObstacleType.teleport, 5, 2),
      ObstacleSpec(ObstacleType.block, 2, 2),
      ObstacleSpec(ObstacleType.lock, 3, 3),
      ObstacleSpec(ObstacleType.ice, 1, 5, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 68,
    zhName: '迷雾星港',
    cols: 6,
    rows: 6,
    stockSize: 70,
    targetTier: VehicleType.spaceShuttle,
    targetCount: 1,
    highTierBias: 4,
    fogCells: 8,
    obstacles: [
      ObstacleSpec(ObstacleType.lock, 2, 4),
      ObstacleSpec(ObstacleType.ice, 3, 1, layers: 3),
    ],
  ),
  LevelDefinition(
    id: 69,
    zhName: '组合地狱',
    cols: 6,
    rows: 6,
    stockSize: 72,
    targetTier: VehicleType.airliner,
    highTierBias: 2,
    targetCount: 3,
    wildcards: 2,
    fogCells: 6,
    timeLimitSeconds: 150,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.lock, 4, 4),
      ObstacleSpec(ObstacleType.ice, 0, 5, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 70,
    zhName: '终极传送',
    cols: 6,
    rows: 6,
    stockSize: 64,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    clearLimit: 4,
    movesLimit: 80,
    obstacles: [
      ObstacleSpec(ObstacleType.teleport, 1, 0),
      ObstacleSpec(ObstacleType.teleport, 4, 5),
      ObstacleSpec(ObstacleType.teleport, 0, 3),
      ObstacleSpec(ObstacleType.teleport, 5, 3),
      ObstacleSpec(ObstacleType.teleport, 2, 1),
      ObstacleSpec(ObstacleType.teleport, 3, 4),
      ObstacleSpec(ObstacleType.block, 2, 4),
      ObstacleSpec(ObstacleType.block, 3, 1),
    ],
  ),
];

/// 完整主线关卡表：手写 L1-70 + 生成 L71-700（共 700 关）。
/// 生成器纯函数、确定性，接入后 [levels] 数量从 70 → 700，
/// 图鉴/成就/选关/解锁等按 levels.length 自适应的逻辑自动跟随。
final List<LevelDefinition> levels = <LevelDefinition>[
  ..._handLevels,
  ...LevelDataGenerator.levels71To700(),
];

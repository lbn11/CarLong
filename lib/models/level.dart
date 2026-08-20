import 'vehicle.dart';
import '../services/level_data_generator.dart';

/// 章节（叙事包装）：按关卡 id 每 10 关一章，共 7 章。
class LevelChapter {
  final String title;
  final String subtitle;
  final int startId;

  const LevelChapter(this.title, this.subtitle, this.startId);
}

/// 合成模式章节表（L1-200 分 14 章：手写 7 章 + 生成 7 章，按 id 区间）。
const List<LevelChapter> levelChapters = [
  LevelChapter('第一章 · 街区起步', '从一辆自行车开始你的车队', 1),
  LevelChapter('第二章 · 城市干线', '车流渐密，货运繁忙', 11),
  LevelChapter('第三章 · 轨道时代', '高铁地铁，四通八达', 21),
  LevelChapter('第四章 · 天空征途', '客机战机，冲向云端', 31),
  LevelChapter('第五章 · 星际探索', '穿梭星辰大海', 41),
  LevelChapter('第六章 · 星港试炼', '终极枢纽的考验', 51),
  LevelChapter('第七章 · 机关极限', '限步传送，大师关卡', 61),
  LevelChapter('第八章 · 地铁线', '城市地下，疾驰如风', 71),
  LevelChapter('第九章 · 航空港', '跑道尽头是天空', 90),
  LevelChapter('第十章 · 星际前哨', '第一座深空驿站', 110),
  LevelChapter('第十一章 · 深空巡航', '远离太阳系', 130),
  LevelChapter('第十二章 · 时空裂隙', '扭曲的宇宙结构', 150),
  LevelChapter('第十三章 · 宇宙尽头', '边缘之外的黑暗', 170),
  LevelChapter('第十四章 · 彗星计划', '终极的一跃', 190),
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

/// 一次关卡的定义。
class LevelDefinition {
  final int id;
  final String name;
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

  /// 开局被迷雾盖住的格子数（靠近/落子后揭开）。
  final int fogCells;

  /// 无尽模式：目标达成后自动升级，牌堆无限，死局即结束。
  final bool endless;

  /// 每日挑战：参与每日玩法（不推进关卡解锁、不记录星级）。
  final bool daily;

  /// 棋盘上的障碍物。
  final List<ObstacleSpec> obstacles;

  const LevelDefinition({
    required this.id,
    required this.name,
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
    this.fogCells = 0,
    this.endless = false,
    this.daily = false,
    this.obstacles = const [],
  });

  /// 出生权重：低等级卡出现概率更高。
  /// produce 目标只生成【低于】目标等级的卡片——目标车必须靠合成产出，
  /// 避免"抽到目标卡却在棋盘上却不计数"的困惑（producedCount 只在合成升级命中时加）。
  /// clearBoard 无目标等级，按出租车档位取一个中低位区间。
  List<int> spawnWeights() {
    final maxIdx = VehicleType.values.length - 1;
    final baseIdx = targetTier != null
        ? (targetTier!.index - 1).clamp(0, maxIdx)
        : (VehicleType.taxi.index + 2).clamp(0, maxIdx);
    final t = baseIdx.clamp(0, maxIdx);
    final topN = highTierBias.clamp(0, t + 1);
    return List.generate(
      t + 1,
      (i) => (t - i + 1) +
          (i > t - topN ? (i - (t - topN)) * 4 : 0),
    );
  }

  /// 关卡目标的一句话描述（HUD/主页用）。
  String get goalText {
    final limit = timeLimitSeconds;
    final moves = movesLimit;
    final goal = switch (goalType) {
      GoalType.produce =>
        '目标：合成 ${targetTier!.icon} ${targetTier!.name} ×$targetCount',
      GoalType.clearBoard => '目标：清空棋盘',
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
      if (wildcards > 0) '⭐ 万能卡×$wildcards',
      if (bombs > 0) '💣 炸弹×$bombs',
      if (fogCells > 0) '🌫 迷雾×$fogCells',
    ].join(' ');
    if (moves != null) return '$moves 步内$goal$obs$special';
    if (limit != null) return '$limit 秒内$goal$obs$special';
    return '$goal$obs$special';
  }
}

/// 无尽模式关卡定义（不进关卡列表，主页单独入口）。
const endlessLevel = LevelDefinition(
  id: 999,
  name: '无尽模式',
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
    name: '清晨路段',
    cols: 4,
    rows: 3,
    stockSize: 18,
    targetTier: VehicleType.taxi,
    targetCount: 1,
  ),
  LevelDefinition(
    id: 2,
    name: '早高峰',
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
    name: '环城快线',
    cols: 5,
    rows: 4,
    stockSize: 30,
    targetTier: VehicleType.truck,
    targetCount: 1,
    fogCells: 6,
  ),
  LevelDefinition(
    id: 4,
    name: '货运枢纽',
    cols: 5,
    rows: 4,
    stockSize: 38,
    targetTier: VehicleType.truck,
    highTierBias: 1,
    targetCount: 2,
  ),
  LevelDefinition(
    id: 5,
    name: '钢铁干线',
    cols: 5,
    rows: 5,
    stockSize: 34,
    targetTier: VehicleType.highspeed,
    highTierBias: 1,
    targetCount: 1,
  ),
  LevelDefinition(
    id: 6,
    name: '星光清道夫',
    cols: 5,
    rows: 5,
    stockSize: 30,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.block, 3, 3),
    ],
  ),
  LevelDefinition(
    id: 7,
    name: '午夜冲刺',
    cols: 4,
    rows: 4,
    stockSize: 20,
    targetTier: VehicleType.taxi,
    highTierBias: 1,
    targetCount: 3,
    timeLimitSeconds: 60,
  ),
  LevelDefinition(
    id: 8,
    name: '都市高速',
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
    name: '限时清道夫',
    cols: 5,
    rows: 5,
    stockSize: 30,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    timeLimitSeconds: 75,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 1, 0),
      ObstacleSpec(ObstacleType.ice, 3, 4),
      ObstacleSpec(ObstacleType.lock, 2, 2),
    ],
  ),
  LevelDefinition(
    id: 10,
    name: '终局冲刺',
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
    name: '街头初段',
    cols: 4,
    rows: 4,
    stockSize: 22,
    targetTier: VehicleType.scooter,
    targetCount: 3,
    timeLimitSeconds: 45,
  ),
  LevelDefinition(
    id: 12,
    name: '环城小巴',
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
    name: '冰雪送货',
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
    name: '限时货运',
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
    name: '清道夫之巅',
    cols: 5,
    rows: 5,
    stockSize: 34,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.ice, 0, 4, layers: 2),
    ],
  ),
  LevelDefinition(
    id: 16,
    name: '轨道延伸',
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
    name: '火箭升空',
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
    name: '限时清盘 II',
    cols: 5,
    rows: 5,
    stockSize: 32,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    timeLimitSeconds: 90,
    obstacles: [
      ObstacleSpec(ObstacleType.ice, 0, 0, layers: 3),
      ObstacleSpec(ObstacleType.lock, 2, 4),
      ObstacleSpec(ObstacleType.block, 4, 1),
    ],
  ),
  LevelDefinition(
    id: 19,
    name: '重装集结',
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
    name: '终极枢纽',
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
    name: '快速轨道',
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
    name: '油罐运输',
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
    name: '清道夫 III',
    cols: 5,
    rows: 5,
    stockSize: 32,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    timeLimitSeconds: 75,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 1, 1),
      ObstacleSpec(ObstacleType.lock, 3, 3),
      ObstacleSpec(ObstacleType.ice, 4, 0),
    ],
  ),
  LevelDefinition(
    id: 24,
    name: '高铁提速',
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
    name: '地铁高峰',
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
    name: '机场跑道',
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
    name: '限时清盘 III',
    cols: 5,
    rows: 6,
    stockSize: 36,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    timeLimitSeconds: 90,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.lock, 2, 5),
      ObstacleSpec(ObstacleType.ice, 4, 2),
    ],
  ),
  LevelDefinition(
    id: 28,
    name: '空中走廊',
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
    name: '港铁枢纽',
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
    name: '千钧一发',
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
    name: '六轨立交',
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
    name: '战机升空',
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
    name: '清盘极限',
    cols: 6,
    rows: 6,
    stockSize: 42,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    timeLimitSeconds: 100,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
      ObstacleSpec(ObstacleType.ice, 2, 4),
    ],
  ),
  LevelDefinition(
    id: 34,
    name: '空中霸主',
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
    name: '暴风限时',
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
    name: '星际预演',
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
    name: '多重拦截',
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
    name: '限时清盘 IV',
    cols: 6,
    rows: 6,
    stockSize: 48,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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
    name: '重装巅峰',
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
    name: '终局预演',
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
    name: '星辰之路',
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
    name: '极限清盘',
    cols: 6,
    rows: 6,
    stockSize: 50,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
    obstacles: [
      ObstacleSpec(ObstacleType.block, 0, 0),
      ObstacleSpec(ObstacleType.block, 5, 5),
      ObstacleSpec(ObstacleType.lock, 1, 4),
      ObstacleSpec(ObstacleType.ice, 4, 1),
    ],
  ),
  LevelDefinition(
    id: 43,
    name: '深空舰队',
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
    name: '时空之门',
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
    name: '群星汇聚',
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
    name: '命运交叉',
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
    name: '混沌清盘',
    cols: 6,
    rows: 6,
    stockSize: 54,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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
    name: '星际舰队',
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
    name: '破晓之辉',
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
    name: '终极星港',
    cols: 6,
    rows: 6,
    stockSize: 66,
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
    name: '星港终战',
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
    name: '磁浮首航',
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
    name: '轨道穿越',
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
    name: '彗星追迹',
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
    name: '限步物流',
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
    name: '限步高铁',
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
    name: '限步清盘',
    cols: 6,
    rows: 6,
    stockSize: 54,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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
    name: '极限清盘',
    cols: 6,
    rows: 6,
    stockSize: 56,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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
    name: '星云迷雾',
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
    name: '传送枢纽',
    cols: 5,
    rows: 6,
    stockSize: 58,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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
    name: '万能试炼',
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
    name: '爆破拆除',
    cols: 5,
    rows: 5,
    stockSize: 48,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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
    name: '迷雾列车',
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
    name: '双重传送',
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
    name: '万能火箭',
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
    name: '炸弹狂潮',
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
    name: '传送清盘',
    cols: 6,
    rows: 6,
    stockSize: 60,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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
    name: '迷雾星港',
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
    name: '组合地狱',
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
    name: '终极传送',
    cols: 6,
    rows: 6,
    stockSize: 64,
    goalType: GoalType.clearBoard,
    targetTier: null,
    targetCount: 1,
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

/// 完整主线关卡表：手写 L1-70 + 生成 L71-200（共 200 关）。
/// 生成器纯函数、确定性，接入后 [levels] 数量从 70 → 200，
/// 图鉴/成就/选关/解锁等按 levels.length 自适应的逻辑自动跟随。
final List<LevelDefinition> levels = <LevelDefinition>[
  ..._handLevels,
  ...LevelDataGenerator.levels71To200(),
];

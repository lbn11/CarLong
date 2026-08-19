import 'dart:ui';

/// 车系分组（收集图鉴的分类）。
enum CarFamily {
  ground('陆地'),
  heavy('重工'),
  rail('轨道'),
  air('航空'),
  space('星际');

  final String label;

  const CarFamily(this.label);
}

/// 车辆等级。三张同等级卡片合成升一级（跨车系线性递进）。
enum CarTier {
  bike(0, '单车', '🚲', Color(0xFF4CAF50), CarFamily.ground),
  scooter(1, '踏板', '🛵', Color(0xFF009688), CarFamily.ground),
  car(2, '汽车', '🚗', Color(0xFFF44336), CarFamily.ground),
  taxi(3, '出租车', '🚕', Color(0xFFFF9800), CarFamily.ground),
  bus(4, '巴士', '🚌', Color(0xFF2196F3), CarFamily.ground),
  truck(5, '卡车', '🚚', Color(0xFF795548), CarFamily.heavy),
  train(6, '列车', '🚆', Color(0xFF9C27B0), CarFamily.rail),
  rocket(7, '火箭', '🛸', Color(0xFFE91E63), CarFamily.space),
  tanker(8, '油罐车', '🚛', Color(0xFFFFC107), CarFamily.heavy),
  metro(9, '高铁', '🚄', Color(0xFF00BCD4), CarFamily.rail),
  plane(10, '客机', '✈️', Color(0xFF607D8B), CarFamily.air),
  jet(11, '战机', '🛩️', Color(0xFF8BC34A), CarFamily.air),
  shuttle(12, '航天飞机', '🚀', Color(0xFF673AB7), CarFamily.space),
  ufo(13, '星舰', '🛰️', Color(0xFF3F51B5), CarFamily.space),
  maglev(14, '磁悬浮', '🚝', Color(0xFF00BFA5), CarFamily.rail),
  station(15, '空间站', '🛸', Color(0xFF7E57C2), CarFamily.space),
  comet(16, '彗星', '☄️', Color(0xFFC2185B), CarFamily.space),
  // 任务93：comet 之后追加 5 档未来载具（保持前 17 档 index 不变，存量存档安全）。
  warp(17, '曲速车', '⚡', Color(0xFF3F5AFE), CarFamily.space),
  hover(18, '悬浮车', '💨', Color(0xFF00B8D4), CarFamily.space),
  cruiser(19, '巡洋舰', '🛫', Color(0xFF7C4DFF), CarFamily.space),
  mecha(20, '机甲', '🤖', Color(0xFFFF6E40), CarFamily.space),
  antigrav(21, '反重力', '🪐', Color(0xFFFF4081), CarFamily.space);

  final int tierIndex;
  final String label;
  final String icon;
  final Color color;
  final CarFamily family;

  const CarTier(
    this.tierIndex,
    this.label,
    this.icon,
    this.color,
    this.family,
  );

  CarTier? get next =>
      index + 1 < CarTier.values.length ? CarTier.values[index + 1] : null;

  static CarTier fromIndex(int i) => CarTier.values[i];
}

/// 棋盘上的一叠卡片。count 表示已经合并了几张。
class StackData {
  CarTier tier;
  int count;

  /// 万能卡：可与任意同等级卡片合并（等效为该等级的 1 张）。
  bool isWildcard;

  /// 炸弹卡：只与炸弹合并，集满 3 张引爆并清空周围一圈。
  bool isBomb;

  StackData(
    this.tier, {
    this.count = 1,
    this.isWildcard = false,
    this.isBomb = false,
  });

  bool get isEmpty => count <= 0;

  StackData copy() =>
      StackData(tier, count: count, isWildcard: isWildcard, isBomb: isBomb);
}

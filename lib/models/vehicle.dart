import 'dart:ui';

/// 交通工具大类
enum VehicleCategory {
  land('陆地'),
  heavy('重工'),
  rail('轨道'),
  maritime('船舶'),
  air('航空'),
  space('星际');

  final String label;
  const VehicleCategory(this.label);
}

/// 地形类型
enum TerrainType {
  land,
  water,
  rail,
  air,
}

/// 稀有度
enum Rarity {
  common('普通', Color(0xFF9E9E9E)),
  rare('稀有', Color(0xFF2196F3)),
  epic('史诗', Color(0xFF9C27B0)),
  legendary('传说', Color(0xFFFFC107));

  final String label;
  final Color color;
  const Rarity(this.label, this.color);
}

/// 特殊能力（精简版）
enum SpecialAbility {
  none,
  turn,
  flyOver,
  breakIce,
  breakChain,
  clearRock,
  waterWalk,
  railOnly,
  teleport,
  pickup,
  sonar,
  vertical,
  amphibious,
  tow,
  carry,
  warp;

  String get label => switch (this) {
    none => '无',
    turn => '转弯',
    flyOver => '飞越',
    breakIce => '破冰',
    breakChain => '解锁',
    clearRock => '清石',
    waterWalk => '水上',
    railOnly => '轨道限定',
    teleport => '传送',
    pickup => '搬运',
    sonar => '侦察',
    vertical => '垂直起降',
    amphibious => '两栖',
    tow => '拖拽',
    carry => '装载',
    warp => '曲速',
  };
}

/// 交通工具属性
class VehicleStats {
  final int moveDistance;
  final Set<TerrainType> terrain;
  final SpecialAbility ability;
  final Rarity rarity;

  const VehicleStats({
    required this.moveDistance,
    required this.terrain,
    this.ability = SpecialAbility.none,
    required this.rarity,
  });
}

/// 交通工具等级（50种）
enum VehicleType {
  // ── 陆地 (0-11) ──
  bicycle(0, '自行车', '🚲', Color(0xFF4CAF50), VehicleCategory.land,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, rarity: Rarity.common)),
  scooter(1, '踏板车', '🛵', Color(0xFF009688), VehicleCategory.land,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, rarity: Rarity.common)),
  sedan(2, '轿车', '🚗', Color(0xFFF44336), VehicleCategory.land,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, rarity: Rarity.common)),
  taxi(3, '出租车', '🚕', Color(0xFFFF9800), VehicleCategory.land,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, rarity: Rarity.common)),
  bus(4, '巴士', '🚌', Color(0xFF2196F3), VehicleCategory.land,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, rarity: Rarity.rare)),
  motorcycle(5, '摩托车', '🏍️', Color(0xFF795548), VehicleCategory.land,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, ability: SpecialAbility.turn, rarity: Rarity.rare)),
  suv(6, '越野车', '🚙', Color(0xFF607D8B), VehicleCategory.land,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, ability: SpecialAbility.flyOver, rarity: Rarity.rare)),
  van(7, '面包车', '🚐', Color(0xFF8BC34A), VehicleCategory.land,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, rarity: Rarity.rare)),
  ambulance(8, '救护车', '🚑', Color(0xFFE91E63), VehicleCategory.land,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, ability: SpecialAbility.breakChain, rarity: Rarity.epic)),
  police(9, '警车', '🚔', Color(0xFF1565C0), VehicleCategory.land,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, ability: SpecialAbility.breakChain, rarity: Rarity.epic)),
  firetruck(10, '消防车', '🚒', Color(0xFFD32F2F), VehicleCategory.land,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.land}, ability: SpecialAbility.breakIce, rarity: Rarity.epic)),
  limousine(11, '豪华轿车', '✨', Color(0xFF212121), VehicleCategory.land,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.land}, ability: SpecialAbility.turn, rarity: Rarity.legendary)),

  // ── 重工 (12-19) ──
  truck(12, '卡车', '🚚', Color(0xFF795548), VehicleCategory.heavy,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, rarity: Rarity.common)),
  tanker(13, '油罐车', '🚛', Color(0xFFFFC107), VehicleCategory.heavy,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, rarity: Rarity.common)),
  bulldozer(14, '推土机', '🚜', Color(0xFFFFC107), VehicleCategory.heavy,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, ability: SpecialAbility.clearRock, rarity: Rarity.rare)),
  crane(15, '起重机', '🏗️', Color(0xFF607D8B), VehicleCategory.heavy,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, ability: SpecialAbility.pickup, rarity: Rarity.rare)),
  excavator(16, '挖掘机', '🦾', Color(0xFFFFC107), VehicleCategory.heavy,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, ability: SpecialAbility.clearRock, rarity: Rarity.rare)),
  dumptruck(17, '自卸车', '🚛', Color(0xFF795548), VehicleCategory.heavy,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, rarity: Rarity.rare)),
  forklift(18, '叉车', '🏗️', Color(0xFFFF9800), VehicleCategory.heavy,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, ability: SpecialAbility.pickup, rarity: Rarity.epic)),
  cementmixer(19, '搅拌车', '🏗️', Color(0xFF9E9E9E), VehicleCategory.heavy,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land}, rarity: Rarity.epic)),

  // ── 轨道 (20-27) ──
  tram(20, '有轨电车', '🚋', Color(0xFFFFC107), VehicleCategory.rail,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.rail}, ability: SpecialAbility.railOnly, rarity: Rarity.common)),
  lightrail(21, '轻轨', '🚈', Color(0xFF4CAF50), VehicleCategory.rail,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.rail}, ability: SpecialAbility.railOnly, rarity: Rarity.common)),
  subway(22, '地铁', '🚇', Color(0xFF607D8B), VehicleCategory.rail,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.rail}, ability: SpecialAbility.flyOver, rarity: Rarity.rare)),
  highspeed(23, '高铁', '🚄', Color(0xFFE91E63), VehicleCategory.rail,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.rail}, ability: SpecialAbility.flyOver, rarity: Rarity.rare)),
  maglev(24, '磁悬浮', '🚝', Color(0xFF00BFA5), VehicleCategory.rail,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.rail}, ability: SpecialAbility.flyOver, rarity: Rarity.epic)),
  monorail(25, '单轨', '🚈', Color(0xFF2196F3), VehicleCategory.rail,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.rail}, ability: SpecialAbility.railOnly, rarity: Rarity.rare)),
  steam(26, '蒸汽火车', '🚂', Color(0xFF5D4037), VehicleCategory.rail,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.rail}, rarity: Rarity.common)),
  hyperloop(27, '超级高铁', '🚄', Color(0xFF00BCD4), VehicleCategory.rail,
    VehicleStats(moveDistance: 4, terrain: {TerrainType.rail}, ability: SpecialAbility.turn, rarity: Rarity.legendary)),

  // ── 船舶 (28-35) ──
  dinghy(28, '小艇', '🛟', Color(0xFF2196F3), VehicleCategory.maritime,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.water}, rarity: Rarity.common)),
  fishing(29, '渔船', '🎣', Color(0xFF795548), VehicleCategory.maritime,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.water}, rarity: Rarity.common)),
  ferry(30, '渡轮', '⛴️', Color(0xFF607D8B), VehicleCategory.maritime,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.water}, rarity: Rarity.common)),
  sailboat(31, '帆船', '⛵', Color(0xFFE91E63), VehicleCategory.maritime,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.water}, rarity: Rarity.rare)),
  speedboat(32, '快艇', '🚤', Color(0xFF2196F3), VehicleCategory.maritime,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.water}, rarity: Rarity.rare)),
  barge(33, '驳船', '🚢', Color(0xFF795548), VehicleCategory.maritime,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.water}, ability: SpecialAbility.tow, rarity: Rarity.rare)),
  warship(34, '军舰', '🚢', Color(0xFF455A64), VehicleCategory.maritime,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.water}, ability: SpecialAbility.breakIce, rarity: Rarity.epic)),
  carrier(35, '航空母舰', '🚢', Color(0xFF37474F), VehicleCategory.maritime,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.water}, ability: SpecialAbility.carry, rarity: Rarity.legendary)),

  // ── 航空 (36-43) ──
  glider(36, '滑翔机', '🪂', Color(0xFF90A4AE), VehicleCategory.air,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.air}, ability: SpecialAbility.flyOver, rarity: Rarity.common)),
  helicopter(37, '直升机', '🚁', Color(0xFF2196F3), VehicleCategory.air,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.air}, ability: SpecialAbility.vertical, rarity: Rarity.common)),
  drone(38, '无人机', '🛸', Color(0xFF607D8B), VehicleCategory.air,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.air}, ability: SpecialAbility.sonar, rarity: Rarity.common)),
  airliner(39, '客机', '✈️', Color(0xFF607D8B), VehicleCategory.air,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.air}, ability: SpecialAbility.flyOver, rarity: Rarity.rare)),
  fighter(40, '战斗机', '🛩️', Color(0xFF455A64), VehicleCategory.air,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.air}, rarity: Rarity.rare)),
  cargo(41, '运输机', '✈️', Color(0xFF795548), VehicleCategory.air,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.air}, ability: SpecialAbility.carry, rarity: Rarity.rare)),
  seaplane(42, '水上飞机', '✈️', Color(0xFF0288D1), VehicleCategory.air,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.air, TerrainType.water}, ability: SpecialAbility.amphibious, rarity: Rarity.epic)),
  stealth(43, '隐身飞机', '🛩️', Color(0xFF212121), VehicleCategory.air,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.air}, rarity: Rarity.legendary)),

  // ── 星际 (44-49) ──
  rocket(44, '火箭', '🚀', Color(0xFFE91E63), VehicleCategory.space,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land, TerrainType.water, TerrainType.air}, rarity: Rarity.common)),
  spaceShuttle(45, '航天飞机', '🛸', Color(0xFF673AB7), VehicleCategory.space,
    VehicleStats(moveDistance: 2, terrain: {TerrainType.land, TerrainType.water, TerrainType.air}, ability: SpecialAbility.teleport, rarity: Rarity.rare)),
  spaceStation(46, '空间站', '🛰️', Color(0xFF7E57C2), VehicleCategory.space,
    VehicleStats(moveDistance: 0, terrain: {TerrainType.land, TerrainType.water, TerrainType.air}, ability: SpecialAbility.teleport, rarity: Rarity.epic)),
  lunar(47, '月球车', '🌙', Color(0xFFBDBDBD), VehicleCategory.space,
    VehicleStats(moveDistance: 1, terrain: {TerrainType.land}, rarity: Rarity.common)),
  starship(48, '星际飞船', '🌌', Color(0xFF7C4DFF), VehicleCategory.space,
    VehicleStats(moveDistance: 3, terrain: {TerrainType.land, TerrainType.water, TerrainType.air}, ability: SpecialAbility.turn, rarity: Rarity.epic)),
  warpShip(49, '曲速飞船', '⚡', Color(0xFF3F5AFE), VehicleCategory.space,
    VehicleStats(moveDistance: 4, terrain: {TerrainType.land, TerrainType.water, TerrainType.air}, ability: SpecialAbility.warp, rarity: Rarity.legendary));

  final int id;
  final String name;
  final String icon;
  final Color color;
  final VehicleCategory category;
  final VehicleStats stats;

  const VehicleType(
    this.id,
    this.name,
    this.icon,
    this.color,
    this.category,
    this.stats,
  );

  VehicleType? get next =>
      index + 1 < VehicleType.values.length ? VehicleType.values[index + 1] : null;

  static VehicleType fromId(int id) => VehicleType.values[id];

  bool canMoveOn(TerrainType terrain) => stats.terrain.contains(terrain);

  String get moveDescription {
    final base = '移动${stats.moveDistance}格';
    if (stats.ability == SpecialAbility.turn) return '$base+转弯';
    return base;
  }

  String get abilityDescription =>
      stats.ability == SpecialAbility.none ? '无特殊能力' : stats.ability.label;
}

/// 棋盘上的一叠卡片（合并游戏用，兼容旧逻辑）
class StackData {
  VehicleType tier;
  int count;
  bool isWildcard;
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

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
/// 共 100 档，5 大车系各 20 档。
enum CarTier {
  // ── 陆地 (0-19) ──
  bike(0, '单车', '🚲', Color(0xFF4CAF50), CarFamily.ground),
  scooter(1, '踏板', '🛵', Color(0xFF009688), CarFamily.ground),
  car(2, '汽车', '🚗', Color(0xFFF44336), CarFamily.ground),
  taxi(3, '出租车', '🚕', Color(0xFFFF9800), CarFamily.ground),
  bus(4, '巴士', '🚌', Color(0xFF2196F3), CarFamily.ground),
  motorcycle(5, '摩托车', '🏍️', Color(0xFF795548), CarFamily.ground),
  suv(6, '越野车', '🚙', Color(0xFF607D8B), CarFamily.ground),
  van(7, '面包车', '🚐', Color(0xFF8BC34A), CarFamily.ground),
  ambulance(8, '救护车', '🚑', Color(0xFFE91E63), CarFamily.ground),
  police(9, '警车', '🚔', Color(0xFF1565C0), CarFamily.ground),
  firetruck(10, '消防车', '🚒', Color(0xFFD32F2F), CarFamily.ground),
  limousine(11, '豪华轿车', ' limo', Color(0xFF212121), CarFamily.ground),
  sports(12, '跑车', '🏎️', Color(0xFFFF5722), CarFamily.ground),
  vintage(13, '老爷车', '🚗', Color(0xFF8D6E63), CarFamily.ground),
  electric(14, '电动车', '⚡', Color(0xFF00BCD4), CarFamily.ground),
  segway(15, '平衡车', '🛴', Color(0xFF9C27B0), CarFamily.ground),
  unicycle(16, '独轮车', '🎪', Color(0xFFFF9800), CarFamily.ground),
  atv(17, '全地形车', '🏍️', Color(0xFF4CAF50), CarFamily.ground),
  gokart(18, '卡丁车', '🏎️', Color(0xFFFF5722), CarFamily.ground),
  rickshaw(19, '三轮车', '🛺', Color(0xFF795548), CarFamily.ground),

  // ── 重工 (20-39) ──
  truck(20, '卡车', '🚚', Color(0xFF795548), CarFamily.heavy),
  tanker(21, '油罐车', '🚛', Color(0xFFFFC107), CarFamily.heavy),
  bulldozer(22, '推土机', '🚜', Color(0xFFFFC107), CarFamily.heavy),
  crane(23, '起重机', '🏗️', Color(0xFF607D8B), CarFamily.heavy),
  excavator(24, '挖掘机', '🦾', Color(0xFFFFC107), CarFamily.heavy),
  dumptruck(25, '自卸车', '🚛', Color(0xFF795548), CarFamily.heavy),
  forklift(26, '叉车', '🏗️', Color(0xFFFF9800), CarFamily.heavy),
  cementmixer(27, '搅拌车', '🏗️', Color(0xFF9E9E9E), CarFamily.heavy),
  roadroller(28, '压路机', '🏗️', Color(0xFF607D8B), CarFamily.heavy),
  towtruck(29, '拖车', '🛻', Color(0xFF1565C0), CarFamily.heavy),
  tractor(30, '拖拉机', '🚜', Color(0xFF4CAF50), CarFamily.heavy),
  combine(31, '收割机', '🌾', Color(0xFFFFC107), CarFamily.heavy),
  mining(32, '矿车', '⛏️', Color(0xFF795548), CarFamily.heavy),
  container(33, '集装箱车', '📦', Color(0xFF1565C0), CarFamily.heavy),
  flatbed(34, '平板车', '🚚', Color(0xFF9E9E9E), CarFamily.heavy),
  concrete(35, '泵车', '🏗️', Color(0xFF607D8B), CarFamily.heavy),
  pile(36, '打桩机', '🏗️', Color(0xFF795548), CarFamily.heavy),
  tunnel(37, '掘进机', '⛏️', Color(0xFF607D8B), CarFamily.heavy),
  offshore(38, '海上平台', '🛢️', Color(0xFF1565C0), CarFamily.heavy),
  freight(39, '货运列车', '🚂', Color(0xFF5D4037), CarFamily.heavy),

  // ── 轨道 (40-59) ──
  train(40, '列车', '🚆', Color(0xFF9C27B0), CarFamily.rail),
  metro(41, '高铁', '🚄', Color(0xFF00BCD4), CarFamily.rail),
  maglev(42, '磁悬浮', '🚝', Color(0xFF00BFA5), CarFamily.rail),
  monorail(43, '单轨', '🚈', Color(0xFF2196F3), CarFamily.rail),
  bullet(44, '子弹头', '🚄', Color(0xFFE91E63), CarFamily.rail),
  cable(45, '缆车', '🚡', Color(0xFFFF9800), CarFamily.rail),
  funicular(46, '登山铁路', '🚃', Color(0xFF795548), CarFamily.rail),
  hyperloop(47, '超级高铁', '🚄', Color(0xFF00BCD4), CarFamily.rail),
  tram(48, '有轨电车', '🚋', Color(0xFFFFC107), CarFamily.rail),
  trolley(49, '无轨电车', '🚎', Color(0xFF2196F3), CarFamily.rail),
  lightrail(50, '轻轨', '🚈', Color(0xFF4CAF50), CarFamily.rail),
  highspeed(51, '高速列车', '🚄', Color(0xFFE91E63), CarFamily.rail),
  steam(52, '蒸汽火车', '🚂', Color(0xFF5D4037), CarFamily.rail),
  diesel(53, '内燃机车', '🚂', Color(0xFF795548), CarFamily.rail),
  electricTrain(54, '电力机车', '🚄', Color(0xFF2196F3), CarFamily.rail),
  subway(55, '地铁', '🚇', Color(0xFF607D8B), CarFamily.rail),
  airport(56, '机场快线', '🚄', Color(0xFF00BCD4), CarFamily.rail),
  maglev2(57, '超导磁悬浮', '🚝', Color(0xFF00BFA5), CarFamily.rail),
  orbital(58, '轨道列车', '🛰️', Color(0xFF9C27B0), CarFamily.rail),
  maglev3(59, '真空管列车', '🚄', Color(0xFF00BCD4), CarFamily.rail),

  // ── 航空 (60-79) ──
  plane(60, '客机', '✈️', Color(0xFF607D8B), CarFamily.air),
  jet(61, '战机', '🛩️', Color(0xFF8BC34A), CarFamily.air),
  helicopter(62, '直升机', '🚁', Color(0xFF2196F3), CarFamily.air),
  glider(63, '滑翔机', '🪂', Color(0xFF90A4AE), CarFamily.air),
  blimp(64, '飞艇', '🎈', Color(0xFFFF9800), CarFamily.air),
  drone(65, '无人机', '🛸', Color(0xFF607D8B), CarFamily.air),
  fighter(66, '战斗机', '🛩️', Color(0xFF455A64), CarFamily.air),
  bomber(67, '轰炸机', '✈️', Color(0xFF37474F), CarFamily.air),
  seaplane(68, '水上飞机', '✈️', Color(0xFF0288D1), CarFamily.air),
  autogyro(69, '自转旋翼机', '🚁', Color(0xFF8BC34A), CarFamily.air),
  tiltrotor(70, '倾转旋翼机', '🚁', Color(0xFF607D8B), CarFamily.air),
  supersonic(71, '超音速客机', '✈️', Color(0xFFE91E63), CarFamily.air),
  stealth(72, '隐身飞机', '🛩️', Color(0xFF212121), CarFamily.air),
  cargo(73, '运输机', '✈️', Color(0xFF795548), CarFamily.air),
  recon(74, '侦察机', '🛩️', Color(0xFF455A64), CarFamily.air),
  patrol(75, '巡逻机', '✈️', Color(0xFF1565C0), CarFamily.air),
  rescue(76, '救援直升机', '🚁', Color(0xFFE53935), CarFamily.air),
  fireplane(77, '消防飞机', '✈️', Color(0xFFFF5722), CarFamily.air),
  agricultural(78, '农业飞机', '🛩️', Color(0xFF4CAF50), CarFamily.air),
  experimental(79, '实验飞机', '✈️', Color(0xFF9C27B0), CarFamily.air),

  // ── 星际 (80-99) ──
  rocket(80, '火箭', '🛸', Color(0xFFE91E63), CarFamily.space),
  shuttle(81, '航天飞机', '🚀', Color(0xFF673AB7), CarFamily.space),
  ufo(82, '星舰', '🛰️', Color(0xFF3F51B5), CarFamily.space),
  station(83, '空间站', '🛸', Color(0xFF7E57C2), CarFamily.space),
  comet(84, '彗星', '☄️', Color(0xFFC2185B), CarFamily.space),
  warp(85, '曲速车', '⚡', Color(0xFF3F5AFE), CarFamily.space),
  hover(86, '悬浮车', '💨', Color(0xFF00B8D4), CarFamily.space),
  cruiser(87, '巡洋舰', '🛫', Color(0xFF7C4DFF), CarFamily.space),
  mecha(88, '机甲', '🤖', Color(0xFFFF6E40), CarFamily.space),
  antigrav(89, '反重力', '🪐', Color(0xFFFF4081), CarFamily.space),
  lunar(90, '月球车', '🌙', Color(0xFFBDBDBD), CarFamily.space),
  mars(91, '火星车', '🔴', Color(0xFFD84315), CarFamily.space),
  asteroid(92, '小行星矿车', '☄️', Color(0xFF5D4037), CarFamily.space),
  elevator(93, '太空电梯', '🛗', Color(0xFF78909C), CarFamily.space),
  dyson(94, '戴森球', '☀️', Color(0xFFFFC107), CarFamily.space),
  wormhole(95, '虫洞飞船', '🌀', Color(0xFF7C4DFF), CarFamily.space),
  nebula(96, '星云飞船', '🌌', Color(0xFF5C6BC0), CarFamily.space),
  galaxy(97, '星系飞船', '🌀', Color(0xFFAB47BC), CarFamily.space),
  quantum(98, '量子飞船', '⚛️', Color(0xFF00BCD4), CarFamily.space),
  cosmic(99, '宇宙飞船', '🚀', Color(0xFFFFD54F), CarFamily.space);

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

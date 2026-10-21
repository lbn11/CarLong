import 'package:flutter/material.dart';

import '../save/save_repository.dart';
import '../services/level_data_generator.dart';
import 'level.dart';
import 'vehicle.dart';

/// 成就分组。成就页按此顺序分节渲染（组内保持声明顺序）。
///
/// 分组的意义：27 条时平铺还看得过来，扩到 70+ 条后玩家无法定位
/// 「我还差哪一类」，必须靠分组 + 状态筛选来导航。
enum AchievementGroup {
  progress('进度'),
  chapter('章节'),
  boss('Boss'),
  parking('停车'),
  collection('图鉴'),
  skill('技巧'),
  life('日常');

  final String label;
  const AchievementGroup(this.label);
}

/// 一个成就定义。达成条件基于现有存档字段计算，无需额外埋点。
class Achievement {
  final String id;
  final AchievementGroup group;
  final String title;
  final String desc;
  final int reward;
  final IconData icon;
  final bool Function(PlayerData data) achieved;

  const Achievement({
    required this.id,
    required this.group,
    required this.title,
    required this.desc,
    required this.reward,
    required this.icon,
    required this.achieved,
  });
}

// ─────────────────────────────────────────────────────────────
//  达成判据的公共计算
// ─────────────────────────────────────────────────────────────

int _completed(PlayerData d) =>
    levels.where((l) => (d.bestStars[l.id] ?? 0) > 0).length;

int _totalStars(PlayerData d) =>
    d.bestStars.values.fold(0, (a, b) => a + b);

/// 已通关的停车关卡数（拿到 ≥1 星即算通关）。
int _parkingCompleted(PlayerData d) =>
    d.parkingBestStars.values.where((s) => s > 0).length;

/// `[start, end]` 区间内是否**全部**通关（主线）。
///
/// 只按 id 区间遍历 + map 查表，不做整表 where 扫描：章节成就 21 条，
/// 每次 build 都会调用一次，整表扫描是 21×700 次白白浪费。
bool _allCleared(PlayerData d, int start, int end) {
  for (var id = start; id <= end; id++) {
    if ((d.bestStars[id] ?? 0) <= 0) return false;
  }
  return true;
}

/// `[start, end]` 区间内是否**全部**通关（停车）。
bool _allParked(PlayerData d, int start, int end) {
  for (var id = start; id <= end; id++) {
    if ((d.parkingBestStars[id] ?? 0) <= 0) return false;
  }
  return true;
}

bool _familyCollected(PlayerData d, VehicleCategory c) =>
    VehicleType.values
        .where((t) => t.category == c)
        .every((t) => d.collection.contains(t.id));

int _bossKills(PlayerData d) => d.defeatedBosses.length;

// ─────────────────────────────────────────────────────────────
//  全量成就表
// ─────────────────────────────────────────────────────────────

final achievements = <Achievement>[
  // ── 进度：主线通关里程碑 ──────────────────────────────────
  // 700 关跨越 21 章，里程碑必须密：早期 1/10/30 给新手连续正反馈，
  // 中期 100/200/300 顶住「看不到头」的疲劳，后期 500/700 才够到终局。
  Achievement(
    id: 'first_win',
    group: AchievementGroup.progress,
    title: '初出茅庐',
    desc: '通关第 1 关',
    reward: 30,
    icon: Icons.directions_car,
    achieved: (d) => (d.bestStars[1] ?? 0) > 0,
  ),
  Achievement(
    id: 'clear_10',
    group: AchievementGroup.progress,
    title: '十关先锋',
    desc: '累计通关 10 关',
    reward: 60,
    icon: Icons.map,
    achieved: (d) => _completed(d) >= 10,
  ),
  Achievement(
    id: 'clear_30',
    group: AchievementGroup.progress,
    title: '马路老手',
    desc: '累计通关 30 关',
    reward: 80,
    icon: Icons.route,
    achieved: (d) => _completed(d) >= 30,
  ),
  Achievement(
    id: 'clear_100',
    group: AchievementGroup.progress,
    title: '城市通途',
    desc: '累计通关 100 关',
    reward: 120,
    icon: Icons.map_rounded,
    achieved: (d) => _completed(d) >= 100,
  ),
  Achievement(
    id: 'clear_200',
    group: AchievementGroup.progress,
    title: '干线贯通',
    desc: '累计通关 200 关',
    reward: 140,
    icon: Icons.alt_route_rounded,
    achieved: (d) => _completed(d) >= 200,
  ),
  Achievement(
    id: 'clear_300',
    group: AchievementGroup.progress,
    title: '环城大师',
    desc: '累计通关 300 关',
    reward: 160,
    icon: Icons.location_city_rounded,
    achieved: (d) => _completed(d) >= 300,
  ),
  Achievement(
    id: 'clear_500',
    group: AchievementGroup.progress,
    title: '跨越星港',
    desc: '累计通关 500 关',
    reward: 180,
    icon: Icons.rocket_launch_rounded,
    achieved: (d) => _completed(d) >= 500,
  ),
  Achievement(
    id: 'clear_all',
    group: AchievementGroup.progress,
    title: '都市传奇',
    desc: '通关全部 ${levels.length} 关',
    reward: 200,
    icon: Icons.workspace_premium,
    achieved: (d) => _completed(d) >= levels.length,
  ),

  // ── 章节：每章通关一条（按 levelChapters 自动生成）──────────
  // 手写「chapter_1_clear / chapter_4_clear」已删除：它们把 id 区间
  // 硬编码成 1-10 / 1-40，章节一扩就失同步（文案还写着「第四章」）。
  // 现在每章一条，章节表改了几章就自动有几条。
  ..._chapterAchievements(),

  // ── Boss：56 只 Boss 是内容投入最重的一块，成就侧必须有回声 ──
  Achievement(
    id: 'boss_first',
    group: AchievementGroup.boss,
    title: '初战告捷',
    desc: '首次击败守关 Boss',
    reward: 100,
    icon: Icons.sports_martial_arts,
    achieved: (d) => _bossKills(d) >= 1,
  ),
  Achievement(
    id: 'boss_5',
    group: AchievementGroup.boss,
    title: '猎手入场',
    desc: '击败 5 只 Boss',
    reward: 120,
    icon: Icons.gps_fixed_rounded,
    achieved: (d) => _bossKills(d) >= 5,
  ),
  Achievement(
    id: 'boss_15',
    group: AchievementGroup.boss,
    title: '守关者克星',
    desc: '击败 15 只 Boss',
    reward: 150,
    icon: Icons.shield_moon_rounded,
    achieved: (d) => _bossKills(d) >= 15,
  ),
  Achievement(
    id: 'boss_30',
    group: AchievementGroup.boss,
    title: 'Boss 收割机',
    desc: '击败 30 只 Boss',
    reward: 180,
    icon: Icons.local_fire_department_rounded,
    achieved: (d) => _bossKills(d) >= 30,
  ),
  Achievement(
    id: 'boss_sweep',
    group: AchievementGroup.boss,
    title: '一章节全清',
    desc: '清空任意一章的全部 4 只 Boss',
    reward: 150,
    icon: Icons.done_all_rounded,
    achieved: (d) => _anyChapterSwept(d),
  ),
  Achievement(
    id: 'boss_all',
    group: AchievementGroup.boss,
    title: '徽章墙圆满',
    desc: '击败全部 ${LevelDataGenerator.bossTotal} 只 Boss',
    reward: 300,
    icon: Icons.military_tech_rounded,
    achieved: (d) => _bossKills(d) >= LevelDataGenerator.bossTotal,
  ),

  // ── 停车：800 关独立赛道 ──────────────────────────────────
  Achievement(
    id: 'park_first',
    group: AchievementGroup.parking,
    title: '初停牛刀',
    desc: '通关第 1 个停车关卡',
    reward: 30,
    icon: Icons.local_parking,
    achieved: (d) => (d.parkingBestStars[1] ?? 0) > 0,
  ),
  Achievement(
    id: 'park_clear_5',
    group: AchievementGroup.parking,
    title: '泊车新手',
    desc: '累计通关 5 个停车关卡',
    reward: 60,
    icon: Icons.directions_car,
    achieved: (d) => _parkingCompleted(d) >= 5,
  ),
  Achievement(
    id: 'park_clear_10',
    group: AchievementGroup.parking,
    title: '停车达人',
    desc: '累计通关 10 个停车关卡',
    reward: 100,
    icon: Icons.emoji_events,
    achieved: (d) => _parkingCompleted(d) >= 10,
  ),
  Achievement(
    id: 'park_clear_100',
    group: AchievementGroup.parking,
    title: '车位老手',
    desc: '累计通关 100 个停车关卡',
    reward: 140,
    icon: Icons.garage_rounded,
    achieved: (d) => _parkingCompleted(d) >= 100,
  ),
  Achievement(
    id: 'park_master',
    group: AchievementGroup.parking,
    title: '泊车大师',
    desc: '解锁第 20 个停车关卡',
    reward: 100,
    icon: Icons.workspace_premium,
    achieved: (d) => d.parkingUnlocked > 20,
  ),
  Achievement(
    id: 'park_star_3',
    group: AchievementGroup.parking,
    title: '完美泊车',
    desc: '任一停车关卡拿到 3 星',
    reward: 80,
    icon: Icons.star_rate,
    achieved: (d) => d.parkingBestStars.values.any((s) => s >= 3),
  ),
  Achievement(
    id: 'park_star5',
    group: AchievementGroup.parking,
    title: '三星泊车手',
    desc: '5 个停车关卡拿到 3 星',
    reward: 120,
    icon: Icons.star,
    achieved: (d) => d.parkingBestStars.values.where((s) => s >= 3).length >= 5,
  ),
  Achievement(
    id: 'park_star50',
    group: AchievementGroup.parking,
    title: '车位精度控',
    desc: '50 个停车关卡拿到 3 星',
    reward: 150,
    icon: Icons.auto_awesome_rounded,
    achieved: (d) =>
        d.parkingBestStars.values.where((s) => s >= 3).length >= 50,
  ),
  Achievement(
    id: 'park_chapters_5',
    group: AchievementGroup.parking,
    title: '前五章清场',
    desc: '通关停车前 5 章（第 1-180 关）',
    reward: 130,
    icon: Icons.subdirectory_arrow_right_rounded,
    achieved: (d) => _allParked(d, 1, 180),
  ),
  Achievement(
    id: 'park_clear_all',
    group: AchievementGroup.parking,
    title: '终极泊车王',
    desc: '通关全部 800 个停车关卡',
    reward: 300,
    icon: Icons.workspaces_rounded,
    achieved: (d) => _parkingCompleted(d) >= 800,
  ),

  // ── 图鉴：先点亮关键车型，再按车系收满 ────────────────────
  Achievement(
    id: 'train_1',
    group: AchievementGroup.collection,
    title: '铁轨轰鸣',
    desc: '合成出第一辆高铁',
    reward: 80,
    icon: Icons.train,
    // 原来判据是 subway（地铁），与「高铁」文案不符，改判 highspeed。
    achieved: (d) => d.collection.contains(VehicleType.highspeed.id),
  ),
  Achievement(
    id: 'plane_1',
    group: AchievementGroup.collection,
    title: '冲向云霄',
    desc: '合成出第一架客机',
    reward: 100,
    icon: Icons.flight,
    achieved: (d) => d.collection.contains(VehicleType.airliner.id),
  ),
  Achievement(
    id: 'comet_1',
    group: AchievementGroup.collection,
    title: '彗星追迹者',
    desc: '合成出星际飞船',
    reward: 120,
    icon: Icons.auto_awesome,
    achieved: (d) => d.collection.contains(VehicleType.starship.id),
  ),
  Achievement(
    id: 'void_1',
    group: AchievementGroup.collection,
    title: '终极造物',
    desc: '合成出最高级的曲速飞船',
    reward: 200,
    icon: Icons.rocket_launch,
    achieved: (d) => d.collection.contains(VehicleType.warpShip.id),
  ),
  Achievement(
    id: 'collection_25',
    group: AchievementGroup.collection,
    title: '小有收藏',
    desc: '点亮 ${(VehicleType.values.length / 2).floor()} 款车型',
    reward: 100,
    icon: Icons.inventory_2_rounded,
    achieved: (d) =>
        d.collection.length >= (VehicleType.values.length / 2).floor(),
  ),
  // 车系全覆盖：6 条，给中期玩家「下一个目标很具体」的收集节奏。
  for (final family in VehicleCategory.values)
    Achievement(
      id: 'collection_${family.name}',
      group: AchievementGroup.collection,
      title: '${family.label}系全收',
      desc: '点亮全部 '
          '${VehicleType.values.where((t) => t.category == family).length} '
          '款${family.label}车型',
      reward: 80,
      icon: Icons.directions_bus_rounded,
      achieved: (d) => _familyCollected(d, family),
    ),
  Achievement(
    id: 'collection_all',
    group: AchievementGroup.collection,
    title: '终极收藏家',
    desc: '点亮全部 ${VehicleType.values.length} 款车型',
    reward: 250,
    icon: Icons.collections_bookmark,
    achieved: (d) => VehicleType.values.every((t) => d.collection.contains(t.id)),
  ),

  // ── 技巧：连消与三星，衡量「打得好」而不只是「打得远」────────
  Achievement(
    id: 'combo_5',
    group: AchievementGroup.skill,
    title: '连消起步',
    desc: '单局达成 5 连消',
    reward: 80,
    icon: Icons.bolt_rounded,
    achieved: (d) => d.bestCombo >= 5,
  ),
  Achievement(
    id: 'combo_10',
    group: AchievementGroup.skill,
    title: '连锁反应',
    desc: '单局达成 10 连消',
    reward: 120,
    icon: Icons.flash_on_rounded,
    achieved: (d) => d.bestCombo >= 10,
  ),
  Achievement(
    id: 'combo_15',
    group: AchievementGroup.skill,
    title: '连消之神',
    desc: '单局达成 15 连消',
    reward: 180,
    icon: Icons.whatshot_rounded,
    achieved: (d) => d.bestCombo >= 15,
  ),
  Achievement(
    id: 'stars_30',
    group: AchievementGroup.skill,
    title: '星级收藏家',
    desc: '累计获得 30 颗星',
    reward: 100,
    icon: Icons.stars,
    achieved: (d) => _totalStars(d) >= 30,
  ),
  Achievement(
    id: 'stars_300',
    group: AchievementGroup.skill,
    title: '三星猎手',
    desc: '累计获得 300 颗星',
    reward: 150,
    icon: Icons.star_half_rounded,
    achieved: (d) => _totalStars(d) >= 300,
  ),
  Achievement(
    id: 'stars_1000',
    group: AchievementGroup.skill,
    title: '满星征途',
    desc: '累计获得 1000 颗星',
    reward: 250,
    icon: Icons.grade_rounded,
    achieved: (d) => _totalStars(d) >= 1000,
  ),

  // ── 日常：金币 / 签到 / 每日挑战 / 无尽 ────────────────────
  Achievement(
    id: 'coins_500',
    group: AchievementGroup.life,
    title: '小有积蓄',
    desc: '持有 500 金币',
    reward: 50,
    icon: Icons.savings,
    achieved: (d) => d.coins >= 500,
  ),
  Achievement(
    id: 'coins_2000',
    group: AchievementGroup.life,
    title: '家财万贯',
    desc: '持有 2000 金币',
    reward: 120,
    icon: Icons.account_balance_wallet,
    achieved: (d) => d.coins >= 2000,
  ),
  Achievement(
    id: 'coins_5000',
    group: AchievementGroup.life,
    title: '车库财主',
    desc: '持有 5000 金币',
    reward: 180,
    icon: Icons.diamond_rounded,
    achieved: (d) => d.coins >= 5000,
  ),
  Achievement(
    id: 'signin_7',
    group: AchievementGroup.life,
    title: '七日签到',
    desc: '累计签到 7 天',
    reward: 80,
    icon: Icons.event_available,
    achieved: (d) => d.signInTotal >= 7,
  ),
  Achievement(
    id: 'signin_30',
    group: AchievementGroup.life,
    title: '月度全勤',
    desc: '累计签到 30 天',
    reward: 150,
    icon: Icons.calendar_month_rounded,
    achieved: (d) => d.signInTotal >= 30,
  ),
  Achievement(
    id: 'signin_streak_7',
    group: AchievementGroup.life,
    title: '铁杆签到党',
    desc: '连续签到 7 天',
    reward: 100,
    icon: Icons.local_fire_department,
    achieved: (d) => d.signInStreak >= 7,
  ),
  Achievement(
    id: 'daily_first',
    group: AchievementGroup.life,
    title: '今日挑战',
    desc: '完成一次每日挑战',
    reward: 60,
    icon: Icons.today_rounded,
    achieved: (d) => d.dailyClearedDate != null,
  ),
  Achievement(
    id: 'daily_streak_7',
    group: AchievementGroup.life,
    title: '每日全勤',
    desc: '每日挑战连续通关 7 天',
    reward: 180,
    icon: Icons.event_repeat_rounded,
    achieved: (d) => d.dailyStreak >= 7,
  ),
  Achievement(
    id: 'endless_1000',
    group: AchievementGroup.life,
    title: '永动引擎',
    desc: '无尽模式突破 1000 分',
    reward: 120,
    icon: Icons.auto_awesome,
    achieved: (d) => (d.endlessBest.isEmpty ? 0 : d.endlessBest.first) >= 1000,
  ),
  Achievement(
    id: 'endless_3000',
    group: AchievementGroup.life,
    title: '永动机',
    desc: '无尽模式突破 3000 分',
    reward: 150,
    icon: Icons.bolt,
    achieved: (d) => (d.endlessBest.isEmpty ? 0 : d.endlessBest.first) >= 3000,
  ),
];

// ─────────────────────────────────────────────────────────────
//  章节成就生成
// ─────────────────────────────────────────────────────────────

/// 每章一条通关成就，id 为 `chapter_01` … `chapter_21`。
///
/// 章节表 [levelChapters] 是单一真源：改章节数量 / 边界后这里自动跟随，
/// 不再出现「文案写第四章、判据查 40 关」的失同步。
List<Achievement> _chapterAchievements() {
  final out = <Achievement>[];
  for (var i = 0; i < levelChapters.length; i++) {
    final start = levelChapters[i].startId;
    final end =
        i + 1 < levelChapters.length ? levelChapters[i + 1].startId - 1 : levels.last.id;
    final name = _shortChapterName(levelChapters[i].title);
    final isLast = i == levelChapters.length - 1;
    out.add(Achievement(
      id: 'chapter_${(i + 1).toString().padLeft(2, '0')}',
      group: AchievementGroup.chapter,
      title: isLast ? '终章 · $name' : name,
      desc: '通关${levelChapters[i].title}（第 $start-$end 关）',
      reward: isLast ? 150 : (i < 10 ? 50 : 70),
      icon: isLast ? Icons.flag_circle_rounded : Icons.flag_rounded,
      achieved: (d) => _allCleared(d, start, end),
    ));
  }
  return out;
}

/// `第八章 · 地下铁网` → `地下铁网`（取「·」后的短名）。
String _shortChapterName(String title) {
  final idx = title.indexOf('·');
  if (idx < 0) return title;
  return title.substring(idx + 1).trim();
}

/// 是否清空过任意一章的全部 Boss（每章 [LevelDataGenerator.bossPerChapter] 只）。
///
/// key 格式与 `PlayerData.defeatedBosses` 一致：`「章索引.序号」`。
bool _anyChapterSwept(PlayerData d) {
  for (var c = 0; c < LevelDataGenerator.chapterCount; c++) {
    var all = true;
    for (var b = 0; b < LevelDataGenerator.bossPerChapter; b++) {
      if (!d.defeatedBosses.contains('$c.$b')) {
        all = false;
        break;
      }
    }
    if (all) return true;
  }
  return false;
}

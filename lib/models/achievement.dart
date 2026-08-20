import 'package:flutter/material.dart';

import '../save/save_repository.dart';
import 'vehicle.dart';
import 'level.dart';

/// 一个成就定义。达成条件基于现有存档字段计算，无需额外埋点。
class Achievement {
  final String id;
  final String title;
  final String desc;
  final int reward;
  final IconData icon;
  final bool Function(PlayerData data) achieved;

  const Achievement({
    required this.id,
    required this.title,
    required this.desc,
    required this.reward,
    required this.icon,
    required this.achieved,
  });
}

int _completed(PlayerData d) =>
    levels.where((l) => (d.bestStars[l.id] ?? 0) > 0).length;

int _totalStars(PlayerData d) =>
    d.bestStars.values.fold(0, (a, b) => a + b);

/// 已通关的停车关卡数（拿到 ≥1 星即算通关）。
int _parkingCompleted(PlayerData d) =>
    d.parkingBestStars.values.where((s) => s > 0).length;

final achievements = <Achievement>[
  Achievement(
    id: 'first_win',
    title: '初出茅庐',
    desc: '通关第 1 关',
    reward: 30,
    icon: Icons.directions_car,
    achieved: (d) => (d.bestStars[1] ?? 0) > 0,
  ),
  Achievement(
    id: 'clear_10',
    title: '十关先锋',
    desc: '累计通关 10 关',
    reward: 60,
    icon: Icons.map,
    achieved: (d) => _completed(d) >= 10,
  ),
  Achievement(
    id: 'clear_30',
    title: '马路老手',
    desc: '累计通关 30 关',
    reward: 80,
    icon: Icons.route,
    achieved: (d) => _completed(d) >= 30,
  ),
  Achievement(
    id: 'clear_all',
    title: '都市传奇',
    desc: '通关全部关卡',
    reward: 200,
    icon: Icons.workspace_premium,
    achieved: (d) => _completed(d) >= levels.length,
  ),
  Achievement(
    id: 'train_1',
    title: '铁轨轰鸣',
    desc: '合成出第一辆高铁',
    reward: 80,
    icon: Icons.train,
    achieved: (d) => d.collection.contains(VehicleType.subway.id),
  ),
  Achievement(
    id: 'plane_1',
    title: '冲向云霄',
    desc: '合成出第一架飞机',
    reward: 100,
    icon: Icons.flight,
    achieved: (d) => d.collection.contains(VehicleType.airliner.id),
  ),
  Achievement(
    id: 'coins_500',
    title: '小有积蓄',
    desc: '持有 500 金币',
    reward: 50,
    icon: Icons.savings,
    achieved: (d) => d.coins >= 500,
  ),
  Achievement(
    id: 'coins_2000',
    title: '家财万贯',
    desc: '持有 2000 金币',
    reward: 120,
    icon: Icons.account_balance_wallet,
    achieved: (d) => d.coins >= 2000,
  ),
  Achievement(
    id: 'signin_7',
    title: '七日签到',
    desc: '累计签到 7 天',
    reward: 80,
    icon: Icons.event_available,
    achieved: (d) => d.signInTotal >= 7,
  ),
  Achievement(
    id: 'endless_1000',
    title: '永动引擎',
    desc: '无尽模式突破 1000 分',
    reward: 120,
    icon: Icons.auto_awesome,
    achieved: (d) => (d.endlessBest.isEmpty ? 0 : d.endlessBest.first) >= 1000,
  ),
  Achievement(
    id: 'stars_30',
    title: '星级收藏家',
    desc: '累计获得 30 颗星',
    reward: 100,
    icon: Icons.stars,
    achieved: (d) => _totalStars(d) >= 30,
  ),

  // —— 停车模式成就（基于 parkingBestStars / parkingUnlocked）——
  Achievement(
    id: 'park_first',
    title: '初停牛刀',
    desc: '通关第 1 个停车关卡',
    reward: 30,
    icon: Icons.local_parking,
    achieved: (d) => (d.parkingBestStars[1] ?? 0) > 0,
  ),
  Achievement(
    id: 'park_clear_5',
    title: '泊车新手',
    desc: '累计通关 5 个停车关卡',
    reward: 60,
    icon: Icons.directions_car,
    achieved: (d) => _parkingCompleted(d) >= 5,
  ),
  Achievement(
    id: 'park_clear_10',
    title: '停车达人',
    desc: '累计通关 10 个停车关卡',
    reward: 100,
    icon: Icons.emoji_events,
    achieved: (d) => _parkingCompleted(d) >= 10,
  ),
  Achievement(
    id: 'park_star_3',
    title: '完美泊车',
    desc: '任一停车关卡拿到 3 星',
    reward: 80,
    icon: Icons.star_rate,
    achieved: (d) => d.parkingBestStars.values.any((s) => s >= 3),
  ),
  Achievement(
    id: 'park_master',
    title: '泊车大师',
    desc: '解锁第 20 个停车关卡',
    reward: 100,
    icon: Icons.workspace_premium,
    achieved: (d) => d.parkingUnlocked > 20,
  ),

  // —— 深化成就（任务78）：章节 / 收集 / 连续 / 里程碑 ——
  Achievement(
    id: 'chapter_1_clear',
    title: '街区新星',
    desc: '通关第一章（第 1-10 关）',
    reward: 80,
    icon: Icons.home_work,
    achieved: (d) => levels
        .where((l) => l.id <= 10)
        .every((l) => (d.bestStars[l.id] ?? 0) > 0),
  ),
  Achievement(
    id: 'chapter_4_clear',
    title: '天空征服者',
    desc: '通关第四章（第 1-40 关）',
    reward: 80,
    icon: Icons.flight_takeoff,
    achieved: (d) => levels
        .where((l) => l.id <= 40)
        .every((l) => (d.bestStars[l.id] ?? 0) > 0),
  ),
  Achievement(
    id: 'signin_streak_7',
    title: '铁杆签到党',
    desc: '连续签到 7 天',
    reward: 100,
    icon: Icons.local_fire_department,
    achieved: (d) => d.signInStreak >= 7,
  ),
  Achievement(
    id: 'collection_ground',
    title: '陆地霸主',
    desc: '收集全部 6 款陆地车',
    reward: 60,
    icon: Icons.directions_bus,
    achieved: (d) => VehicleType.values
        .where((t) => t.category == VehicleCategory.land)
        .every((t) => d.collection.contains(t.id)),
  ),
  Achievement(
    id: 'collection_all',
    title: '终极收藏家',
    desc: '点亮全部 17 款车型',
    reward: 100,
    icon: Icons.collections_bookmark,
    achieved: (d) => VehicleType.values.every((t) => d.collection.contains(t.id)),
  ),
  Achievement(
    id: 'comet_1',
    title: '彗星追迹者',
    desc: '合成出彗星',
    reward: 120,
    icon: Icons.auto_awesome,
    achieved: (d) => d.collection.contains(VehicleType.starship.id),
  ),
  Achievement(
    id: 'park_star5',
    title: '三星泊车手',
    desc: '5 个停车关卡拿到 3 星',
    reward: 120,
    icon: Icons.star,
    achieved: (d) =>
        d.parkingBestStars.values.where((s) => s >= 3).length >= 5,
  ),
  Achievement(
    id: 'endless_3000',
    title: '永动机',
    desc: '无尽模式突破 3000 分',
    reward: 150,
    icon: Icons.bolt,
    achieved: (d) => (d.endlessBest.isEmpty ? 0 : d.endlessBest.first) >= 3000,
  ),
  Achievement(
    id: 'void_1',
    title: '终极造物',
    desc: '合成出最高级的反重力车',
    reward: 200,
    icon: Icons.rocket_launch,
    achieved: (d) => d.collection.contains(VehicleType.warpShip.id),
  ),
];
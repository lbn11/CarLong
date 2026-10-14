import '../models/vehicle.dart';

/// 停车模式章节模型：按车型(VehicleType)把关卡分段，每段对应一个档位 + 主题。
///
/// 章节解锁与合成图鉴(collection)双向联动：
/// - 单车章节(tier 0)始终开放，作为新玩家起步；
/// - 在合成中收集到该档 → 直接解锁对应停车章节（可跳章，合成加速停车）；
/// - 或通关上一章最后一关 → 停车自身也能顺序推进（纯停车玩家不被卡死）。
///
/// 分段边界必须与 [ParkingLevelGenerator] 的车型区间一致。
class ParkingChapter {
  final VehicleType tier;
  final int startId;
  final int endId;
  final String title;
  final String subtitle;

  const ParkingChapter(
    this.tier,
    this.startId,
    this.endId, {
    required this.title,
    required this.subtitle,
  });

  int get count => endId - startId + 1;
}

class ParkingChapters {
  /// 停车模式总关数（800）。
  ///
  /// 全量 800 关运行时生成实测 68s（85ms/关），选关页不能同步生成，
  /// 因此选关页只持有 id 列表，进入具体关卡时才 [generateOne]。
  static const int totalLevels = 800;

  /// 停车章节（车型分段，800 关覆盖 22 个车型主题）。
  ///
  /// 1000 → 800 的取舍：原表后 200 关是难度早已平台化的重复内容
  /// （实测 L501-1000 平均最短路恒定在 4.3-4.4，700 关同一难度），
  /// 砍掉这段纯重复、把 22 个主题压紧到 36-37 关/章，反而让每章更紧凑。
  /// 注意单车章节 id 从 1 起，0 不使用。
  static const List<ParkingChapter> all = [
    ParkingChapter(VehicleType.bicycle, 1, 36, title: '单车街区', subtitle: '新手上路，稳稳停好'),
    ParkingChapter(VehicleType.scooter, 37, 72, title: '街头巷尾', subtitle: '小巷穿梭，见缝插针'),
    ParkingChapter(VehicleType.sedan, 73, 108, title: '城市街区', subtitle: '车流渐密的市中心'),
    ParkingChapter(VehicleType.taxi, 109, 144, title: '出租热点', subtitle: '随时待命的出租车'),
    ParkingChapter(VehicleType.bus, 145, 180, title: '公交枢纽', subtitle: '大块头也要好停车'),
    ParkingChapter(VehicleType.truck, 181, 216, title: '货运干线', subtitle: '重卡物流的考验'),
    ParkingChapter(VehicleType.highspeed, 217, 252, title: '铁轨编组', subtitle: '列车进站的节奏'),
    ParkingChapter(VehicleType.rocket, 253, 288, title: '发射台', subtitle: '倒计时前的最后停车'),
    ParkingChapter(VehicleType.tanker, 289, 324, title: '油港码头', subtitle: '小心驾驶，稳中求进'),
    ParkingChapter(VehicleType.subway, 325, 360, title: '地铁网络', subtitle: '地下世界的调度'),
    ParkingChapter(VehicleType.airliner, 361, 396, title: '机场跑道', subtitle: '冲向云端之前'),
    ParkingChapter(VehicleType.fighter, 397, 432, title: '空军基地', subtitle: '战机的精准停放'),
    ParkingChapter(VehicleType.spaceShuttle, 433, 468, title: '航天中心', subtitle: '通往太空的走廊'),
    ParkingChapter(VehicleType.warpShip, 469, 504, title: '星际港口', subtitle: '外星访客的泊位'),
    ParkingChapter(VehicleType.maglev, 505, 541, title: '磁浮走廊', subtitle: '悬浮列车的停靠'),
    ParkingChapter(VehicleType.spaceStation, 542, 578, title: '空间站', subtitle: '轨道上的会合'),
    ParkingChapter(VehicleType.starship, 579, 615, title: '彗星轨道', subtitle: '追逐流星之尾'),
    ParkingChapter(VehicleType.warpShip, 616, 652, title: '曲速航道', subtitle: '突破光速的弯道'),
    ParkingChapter(VehicleType.starship, 653, 689, title: '悬浮城', subtitle: '浮空平台的停车'),
    ParkingChapter(VehicleType.warship, 690, 726, title: '巡洋编队', subtitle: '星际舰队的列队'),
    ParkingChapter(VehicleType.starship, 727, 763, title: '机甲工厂', subtitle: '钢铁巨人的归位'),
    ParkingChapter(VehicleType.warpShip, 764, 800, title: '反重力区', subtitle: '终极泊车大师'),
  ];

  /// 停车关卡 id → 车型（与生成器分段一致；超出预定义范围按最高档）。
  static VehicleType tierForId(int id) {
    for (final c in all) {
      if (id >= c.startId && id <= c.endId) return c.tier;
    }
    return VehicleType.warpShip;
  }

  /// 停车关卡 id → 所属章节。
  static ParkingChapter chapterForId(int id) {
    for (final c in all) {
      if (id >= c.startId && id <= c.endId) return c;
    }
    return all.last;
  }

  /// 当前章节的前一章（用于"通关上一章解锁"判断），首章返回 null。
  static ParkingChapter? chapterBefore(ParkingChapter c) {
    final idx = all.indexOf(c);
    return idx > 0 ? all[idx - 1] : null;
  }

  /// 章节是否可进入（双向联动核心逻辑）。
  ///
  /// [collection] 为合成图鉴（已点亮档位集合），[parkingBestStars] 为停车每关最佳星级。
  static bool isAccessible(
    ParkingChapter c,
    Set<int> collection,
    Map<int, int> parkingBestStars,
  ) {
    if (c.tier.id == 0) return true; // 单车章节：新玩家起步常开
    if (collection.contains(c.tier.id)) return true; // 合成收集 → 解锁
    final prev = chapterBefore(c);
    // 上一章最后一关已通关（任意星级）→ 停车自身顺序推进
    if (prev != null && (parkingBestStars[prev.endId] ?? 0) > 0) return true;
    return false;
  }

  /// 锁定原因文案（选关界面提示玩家如何解锁）。
  static String lockReason(ParkingChapter c) {
    return '在合成中收集 ${c.tier.icon} ${c.tier.name} 解锁';
  }
}

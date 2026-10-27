import '../l10n/l10n.dart';
import '../l10n/parking_texts.dart';
import '../models/traffic_sign.dart';
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

  /// 章节标题 / 副标题的**中文原文**。
  ///
  /// 与 [LevelChapter] 同一套约定：字段本身是落盘/导出用的稳定值，
  /// 界面一律读 [title] / [subtitle] 这两个本地化 getter。
  final String zhTitle;
  final String zhSubtitle;

  /// 章节图标用的**通用交通标志**（见 [TrafficSignKind]）。
  ///
  /// 故意不用 [tier] 的车模当图标：一章 36 关的车是同一款，
  /// 图标会退化成 36 份重复车影；而换别的车当图标等于提前剧透未解锁车型。
  final TrafficSignKind sign;

  const ParkingChapter(
    this.tier,
    this.startId,
    this.endId, {
    required this.zhTitle,
    required this.zhSubtitle,
    required this.sign,
  });

  int get count => endId - startId + 1;

  /// 界面标题。拿不到文案表（单测直接 new 模型）时回落中文原文。
  String get title {
    final l = L10n.current;
    if (l == null) return zhTitle;
    return parkingChapterTitleByStartId(l, startId) ?? zhTitle;
  }

  /// 界面副标题，回落策略同 [title]。
  String get subtitle {
    final l = L10n.current;
    if (l == null) return zhSubtitle;
    return parkingChapterSubtitleByStartId(l, startId) ?? zhSubtitle;
  }
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
  ///
  /// **22 章 = 22 款互不相同的车型**（2026-10-21 修正）。原表里
  /// `warpShip` 用了 3 次（星际港口 / 曲速航道 / 反重力区）、`starship`
  /// 用了 3 次（彗星轨道 / 悬浮城 / 机甲工厂），后 4 章只是换了标题文字，
  /// 棋盘上的车、章节图标、目标车全是同一张 PNG —— 玩家把 800 关当
  /// 「22 个新主题」期待，实际只见到 18 款车。今改为：
  /// - L469-504 星际港口 → 运输机（星港货运）
  /// - L616-652 曲速航道 → 超级高铁（音速管道）
  /// - L653-689 悬浮城 → 滑翔机（浮空滑翔）
  /// - L727-763 机甲工厂 → 起重机（巨械装配厂）
  ///
  /// 选型约束：**必须有车模 PNG**（`VehicleType.sprite != null`）。
  /// 2026-10-21 补齐船舶 6 档 + 军舰 / 航母 + 直升机 / 无人机后，
  /// 50 档全部有图，这条约束已不再限制任何车型；第 20 章「巡洋编队」
  /// 的军舰也有了真车模（原先只能显示 🚢 emoji）。
  ///
  /// 同时修掉一处名不副实：第 9 章标题叫「油港码头」，棋盘目标车却是
  /// 陆地的油罐车 tanker。现在换成真正的水上车型 ferry（渡轮），
  /// 标题改为「轮渡码头」，让「码头」这个主题第一次名副其实。
  ///
  /// 车型只决定**目标车外观 + 牌堆里车型的轮转**，棋盘几何由布局决定，
  /// 因此换车型不会改变难度结构；可解性由
  /// `test/parking_solvability_full_test.dart` 全量 1..800 把关。
  // i18n-data-block：章节名的中文原文（界面走 title/subtitle getter，
  // 导出与存档读 zhTitle/zhSubtitle，两者故意分开）
  static const List<ParkingChapter> all = [
    ParkingChapter(
      VehicleType.bicycle,
      1,
      36,
      zhTitle: '单车街区',
      zhSubtitle: '新手上路，稳稳停好',
      sign: TrafficSignKind.trafficLight,
    ),
    ParkingChapter(
      VehicleType.scooter,
      37,
      72,
      zhTitle: '街头巷尾',
      zhSubtitle: '小巷穿梭，见缝插针',
      sign: TrafficSignKind.turn,
    ),
    ParkingChapter(
      VehicleType.sedan,
      73,
      108,
      zhTitle: '城市街区',
      zhSubtitle: '车流渐密的市中心',
      sign: TrafficSignKind.trafficLight,
    ),
    ParkingChapter(
      VehicleType.taxi,
      109,
      144,
      zhTitle: '出租热点',
      zhSubtitle: '随时待命的出租车',
      sign: TrafficSignKind.parking,
    ),
    ParkingChapter(
      VehicleType.bus,
      145,
      180,
      zhTitle: '公交枢纽',
      zhSubtitle: '大块头也要好停车',
      sign: TrafficSignKind.parking,
    ),
    ParkingChapter(
      VehicleType.truck,
      181,
      216,
      zhTitle: '货运干线',
      zhSubtitle: '重卡物流的考验',
      sign: TrafficSignKind.warning,
    ),
    ParkingChapter(
      VehicleType.highspeed,
      217,
      252,
      zhTitle: '铁轨编组',
      zhSubtitle: '列车进站的节奏',
      sign: TrafficSignKind.crossing,
    ),
    ParkingChapter(
      VehicleType.rocket,
      253,
      288,
      zhTitle: '发射台',
      zhSubtitle: '倒计时前的最后停车',
      sign: TrafficSignKind.ramp,
    ),
    ParkingChapter(
      VehicleType.ferry,
      289,
      324,
      zhTitle: '轮渡码头',
      zhSubtitle: '码头边的来回穿梭',
      sign: TrafficSignKind.anchor,
    ),
    ParkingChapter(
      VehicleType.subway,
      325,
      360,
      zhTitle: '地铁网络',
      zhSubtitle: '地下世界的调度',
      sign: TrafficSignKind.tunnel,
    ),
    ParkingChapter(
      VehicleType.airliner,
      361,
      396,
      zhTitle: '机场跑道',
      zhSubtitle: '冲向云端之前',
      sign: TrafficSignKind.straight,
    ),
    ParkingChapter(
      VehicleType.fighter,
      397,
      432,
      zhTitle: '空军基地',
      zhSubtitle: '战机的精准停放',
      sign: TrafficSignKind.noEntry,
    ),
    ParkingChapter(
      VehicleType.spaceShuttle,
      433,
      468,
      zhTitle: '航天中心',
      zhSubtitle: '通往太空的走廊',
      sign: TrafficSignKind.ramp,
    ),
    ParkingChapter(
      VehicleType.cargo,
      469,
      504,
      zhTitle: '星港货运',
      zhSubtitle: '跨星际的快递航线',
      sign: TrafficSignKind.factory,
    ),
    ParkingChapter(
      VehicleType.maglev,
      505,
      541,
      zhTitle: '磁浮走廊',
      zhSubtitle: '悬浮列车的停靠',
      sign: TrafficSignKind.straight,
    ),
    ParkingChapter(
      VehicleType.spaceStation,
      542,
      578,
      zhTitle: '空间站',
      zhSubtitle: '轨道上的会合',
      sign: TrafficSignKind.orbit,
    ),
    ParkingChapter(
      VehicleType.starship,
      579,
      615,
      zhTitle: '彗星轨道',
      zhSubtitle: '追逐流星之尾',
      sign: TrafficSignKind.orbit,
    ),
    ParkingChapter(
      VehicleType.hyperloop,
      616,
      652,
      zhTitle: '音速管道',
      zhSubtitle: '真空管道里的一千公里',
      sign: TrafficSignKind.tunnel,
    ),
    ParkingChapter(
      VehicleType.glider,
      653,
      689,
      zhTitle: '浮空滑翔',
      zhSubtitle: '没有引擎的降落',
      sign: TrafficSignKind.glide,
    ),
    ParkingChapter(
      VehicleType.warship,
      690,
      726,
      zhTitle: '巡洋编队',
      zhSubtitle: '星际舰队的列队',
      sign: TrafficSignKind.noEntry,
    ),
    ParkingChapter(
      VehicleType.crane,
      727,
      763,
      zhTitle: '巨械装配厂',
      zhSubtitle: '钢铁巨臂的归位',
      sign: TrafficSignKind.factory,
    ),
    ParkingChapter(
      VehicleType.warpShip,
      764,
      800,
      zhTitle: '反重力区',
      zhSubtitle: '终极泊车大师',
      sign: TrafficSignKind.orbit,
    ),
  ];
  // i18n-data-end

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
  ///
  /// 车型名走 [VehicleType.name]（本地化），所以英文包里会是
  /// 「Collect 🚗 Sedan in Merge to unlock」。
  static String lockReason(ParkingChapter c) {
    final l = L10n.current;
    final name = c.tier.name;
    if (l == null) return '在合成中收集 $name 解锁'; // i18n-data
    return l.parkingLockReason(name);
  }
}

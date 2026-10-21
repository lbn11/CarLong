import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 玩家存档。
class PlayerData {
  int coins;

  /// 金币上限（防御性，避免长期通胀导致数值溢出/显示异常）。
  static const int kMaxCoins = 99999;

  /// 统一加金币入口：自动钳制到 [0, kMaxCoins]，所有金币来源都应走这里。
  void addCoins(int amount) {
    coins = (coins + amount).clamp(0, kMaxCoins);
  }
  int unlockedLevel;
  Map<int, int> bestScores;

  /// 每关最佳星级（1-3）。
  Map<int, int> bestStars;

  /// 最近一次签到日期（yyyy-MM-dd）与连续签到天数。
  String? lastSignInDate;
  int signInStreak;
  int signInTotal;

  /// 当前 7 日循环所处位置（1-7，未签到为 0）。
  int signInDay;

  /// 无尽模式历史最高分（降序，最多 10 条）。
  List<int> endlessBest;

  /// 已点亮的图鉴：首次合成出的车辆等级索引集合。
  Set<int> collection;

  /// 音效 / 振动开关。
  bool soundOn;
  bool vibrateOn;

  /// 最近一次通关每日挑战的日期（yyyy-MM-dd），当天未通关为 null。
  String? dailyClearedDate;

  /// 每日挑战连续通关天数与最近通关日期（#83：连胜奖励）。
  int dailyStreak;
  String? dailyLastDate;

  /// 已领取过奖励的成就 id 集合。
  Set<String> claimedAchievements;

  /// 道具库存：{'time': 加时卡, 'cards': 补卡卡, 'double': 双倍卡}。
  Map<String, int> boosters;

  /// 轻量埋点事件日志（封顶 [AnalyticsService.maxEvents] 条，最早丢弃）。
  /// 本地记录行为数据，供后续调数值/看留存使用。
  List<Map<String, Object>> analyticsEvents;

  /// 停车模式解锁到的关卡序号（独立于主线）。
  int parkingUnlocked;

  /// 停车模式每关最佳星级（1-3），key 为停车关卡 id。
  Map<int, int> parkingBestStars;

  /// 最近一次在线时间（epoch 毫秒），用于离线收益计算。
  int? lastSeenAt;

  /// 激励广告：今日已观看次数与日期（yyyy-MM-dd）。
  ///
  /// 旧字段，只保留给「商店每日福利」做降级兼容；**新代码请走
  /// [adDailyCounts] + `AdService`**（同一个日期字段管所有广告位）。
  String? adWatchDate;
  int adWatchCount;

  /// 广告观看计数的日期（yyyy-MM-dd，跨日清零）。
  String? adDailyDate;

  /// 今日各广告位已观看次数，key 为 `AdPlacement.key`（shop / merge_revive /
  /// parking_hint …）。用 map 而不是每加一个广告位就加一个字段：广告位是
  /// 运营手段，会频繁增删，字段爆炸不可接受。
  Map<String, int> adDailyCounts;

  /// 全图鉴大奖（点亮全部 VehicleType 款）是否已领取。
  bool collectionRewardClaimed;

  /// 已击败的 Boss 集合，key 为「章索引.Boss序号」（如 "3.2" = 第 4 章
  /// 尖峰招牌位）。BossSpec.forLevel 是确定性函数——同一个 (章, 序号)
  /// 永远是同一个 Boss，徽章墙据此点亮。key 而非关卡 id：玩家重温旧关
  /// 不该重复解锁同一枚徽章。
  Set<String> defeatedBosses;

  /// 合成模式历史最高连消（跨关卡持久化，技巧成长的标尺）。
  int bestCombo;

  PlayerData({
    this.coins = 0,
    this.unlockedLevel = 1,
    Map<int, int>? bestScores,
    Map<int, int>? bestStars,
    this.lastSignInDate,
    this.signInStreak = 0,
    this.signInTotal = 0,
    this.signInDay = 0,
    List<int>? endlessBest,
    Set<int>? collection,
    this.soundOn = true,
    this.vibrateOn = true,
    this.dailyClearedDate,
    this.dailyStreak = 0,
    this.dailyLastDate,
    Set<String>? claimedAchievements,
    Map<String, int>? boosters,
    List<Map<String, Object>>? analyticsEvents,
    this.parkingUnlocked = 2,
    Map<int, int>? parkingBestStars,
    this.lastSeenAt,
    this.adWatchDate,
    this.adWatchCount = 0,
    this.adDailyDate,
    Map<String, int>? adDailyCounts,
    this.collectionRewardClaimed = false,
    Set<String>? defeatedBosses,
    this.bestCombo = 0,
  })  : bestScores = bestScores ?? {},
        bestStars = bestStars ?? {},
        endlessBest = endlessBest ?? [],
        collection = collection ?? {},
        claimedAchievements = claimedAchievements ?? {},
        boosters = boosters ?? {},
        analyticsEvents = analyticsEvents ?? [],
        parkingBestStars = parkingBestStars ?? {},
        adDailyCounts = adDailyCounts ?? {},
        defeatedBosses = defeatedBosses ?? {};

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'unlockedLevel': unlockedLevel,
        'bestScores': bestScores.map((k, v) => MapEntry(k.toString(), v)),
        'bestStars': bestStars.map((k, v) => MapEntry(k.toString(), v)),
        'lastSignInDate': lastSignInDate,
        'signInStreak': signInStreak,
        'signInTotal': signInTotal,
        'signInDay': signInDay,
        'endlessBest': endlessBest,
        'collection': collection.toList(),
        'soundOn': soundOn,
        'vibrateOn': vibrateOn,
        'dailyClearedDate': dailyClearedDate,
        'dailyStreak': dailyStreak,
        'dailyLastDate': dailyLastDate,
        'claimedAchievements': claimedAchievements.toList(),
        'boosters': boosters,
        'analytics': analyticsEvents,
        'parkingUnlocked': parkingUnlocked,
        'parkingBestStars':
            parkingBestStars.map((k, v) => MapEntry(k.toString(), v)),
        'lastSeenAt': lastSeenAt,
        'adWatchDate': adWatchDate,
        'adWatchCount': adWatchCount,
        'adDailyDate': adDailyDate,
        'adDailyCounts': adDailyCounts,
        'collectionRewardClaimed': collectionRewardClaimed,
        'defeatedBosses': defeatedBosses.toList(),
        'bestCombo': bestCombo,
      };

  /// 解析各广告位的今日次数，并把旧版 `adWatchCount`（只有商店福利这一档）
  /// 迁移进新结构 —— 否则升级当天老玩家能再看 3 次。
  static Map<String, int> _parseAdCounts(Map<String, dynamic> json) {
    final raw = json['adDailyCounts'] as Map?;
    if (raw != null && raw.isNotEmpty) {
      return raw.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    final legacy = (json['adWatchCount'] as num?)?.toInt() ?? 0;
    if (legacy > 0 && json['adWatchDate'] != null) {
      return {'shop': legacy};
    }
    return {};
  }

  factory PlayerData.fromJson(Map<String, dynamic> json) => PlayerData(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        unlockedLevel: (json['unlockedLevel'] as num?)?.toInt() ?? 1,
        bestScores: (json['bestScores'] as Map?)
                ?.map((k, v) => MapEntry(int.parse(k), (v as num).toInt())) ??
            {},
        bestStars: (json['bestStars'] as Map?)
                ?.map((k, v) => MapEntry(int.parse(k), (v as num).toInt())) ??
            {},
        lastSignInDate: json['lastSignInDate'] as String?,
        signInStreak: (json['signInStreak'] as num?)?.toInt() ?? 0,
        signInTotal: (json['signInTotal'] as num?)?.toInt() ?? 0,
        signInDay: (json['signInDay'] as num?)?.toInt() ?? 0,
        endlessBest: (json['endlessBest'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [],
        collection: (json['collection'] as List?)
                ?.map((e) => (e as num).toInt())
                .toSet() ??
            {},
        soundOn: json['soundOn'] as bool? ?? true,
        vibrateOn: json['vibrateOn'] as bool? ?? true,
        dailyClearedDate: json['dailyClearedDate'] as String?,
        dailyStreak: (json['dailyStreak'] as num?)?.toInt() ?? 0,
        dailyLastDate: json['dailyLastDate'] as String?,
        claimedAchievements:
            (json['claimedAchievements'] as List?)?.cast<String>().toSet() ??
                {},
        boosters: (json['boosters'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
            {},
        analyticsEvents: (json['analytics'] as List?)
            ?.map((e) => Map<String, Object>.from(e as Map))
            .toList() ??
            [],
        // 旧存档中的 tutorialCompleted 键已忽略（教学系统已删除）。
        // parkingUnlocked 表示"下一个待解锁的关卡 id"，第 1 关默认可玩，
        // 故下限钳制为 2；修复旧存档中持久化为 1 导致的全关死锁。
        parkingUnlocked: ((json['parkingUnlocked'] as num?)?.toInt() ?? 2)
            .clamp(2, 1 << 30),
        parkingBestStars: (json['parkingBestStars'] as Map?)
                ?.map((k, v) => MapEntry(int.parse(k), (v as num).toInt())) ??
            {},
        lastSeenAt: (json['lastSeenAt'] as num?)?.toInt(),
        adWatchDate: json['adWatchDate'] as String?,
        adWatchCount: (json['adWatchCount'] as num?)?.toInt() ?? 0,
        adDailyDate: json['adDailyDate'] as String? ?? json['adWatchDate'] as String?,
        adDailyCounts: _parseAdCounts(json),
        collectionRewardClaimed:
            json['collectionRewardClaimed'] as bool? ?? false,
        defeatedBosses:
            (json['defeatedBosses'] as List?)?.cast<String>().toSet() ?? {},
        bestCombo: (json['bestCombo'] as num?)?.toInt() ?? 0,
      );
}

/// 使用 SharedPreferences 的存档仓库。
class SaveRepository {
  static const _key = 'traffic_merge_save_v1';

  Future<PlayerData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return PlayerData();
    try {
      return PlayerData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlayerData();
    }
  }

  Future<void> save(PlayerData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }
}

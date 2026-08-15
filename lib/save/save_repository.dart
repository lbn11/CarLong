import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 玩家存档。
class PlayerData {
  int coins;
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

  /// 已领取过奖励的成就 id 集合。
  Set<String> claimedAchievements;

  /// 道具库存：{'time': 加时卡, 'cards': 补卡卡, 'double': 双倍卡}。
  Map<String, int> boosters;

  /// 轻量埋点事件日志（封顶 [AnalyticsService.maxEvents] 条，最早丢弃）。
  /// 本地记录行为数据，供后续调数值/看留存使用。
  List<Map<String, Object>> analyticsEvents;

  /// 已完成教程的关卡 id 集合。
  Set<int> tutorialCompleted;

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
    Set<String>? claimedAchievements,
    Map<String, int>? boosters,
    List<Map<String, Object>>? analyticsEvents,
    Set<int>? tutorialCompleted,
  })  : bestScores = bestScores ?? {},
        bestStars = bestStars ?? {},
        endlessBest = endlessBest ?? [],
        collection = collection ?? {},
        claimedAchievements = claimedAchievements ?? {},
        boosters = boosters ?? {},
        analyticsEvents = analyticsEvents ?? [],
        tutorialCompleted = tutorialCompleted ?? {};

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
        'claimedAchievements': claimedAchievements.toList(),
        'boosters': boosters,
        'analytics': analyticsEvents,
        'tutorialCompleted': tutorialCompleted.toList(),
      };

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
        tutorialCompleted: (json['tutorialCompleted'] as List?)
                ?.map((e) => (e as num).toInt())
                .toSet() ??
            {},
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

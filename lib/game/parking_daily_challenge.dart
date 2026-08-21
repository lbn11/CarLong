import '../models/parking_level.dart';
import '../services/parking_generator.dart';

/// 停车模式每日挑战：每天生成一个固定停车关卡，全服同题。
///
/// 灵感来自 Meowdoku 的每日挑战机制——每天一题，保持玩家粘性。
/// 关卡基于日期 seed 确定性生成，保证同一天所有玩家拿到相同题目。
class ParkingDailyChallenge {
  ParkingDailyChallenge._();

  /// 今日挑战的关卡 id（用于存档）。
  static const int levelId = -1;

  /// 获取今天的挑战关卡（基于日期 seed 生成，确定性可复现）。
  static ParkingLevel today() {
    final seed = _todaySeed();
    // 用 seed 生成一个中等难度关卡（id 范围 200-400 对应 5x5 棋盘，难度适中）
    final id = 200 + (seed % 200);
    return ParkingLevelGenerator.generateOne(id);
  }

  /// 今天的日期种子。
  static int _todaySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  /// 今天的日期字符串（用作存储 key）。
  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 今天的奖励金币数。
  static int get reward => 100;

  /// 连续挑战额外奖励（>=3天连挑战额外+50）。
  static int streakBonus(int streak) => streak >= 3 ? 50 : 0;
}

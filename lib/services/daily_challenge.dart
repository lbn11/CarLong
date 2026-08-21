import '../models/parking_level.dart';
import 'parking_generator.dart';

/// 每日挑战：每天生成一个固定停车关卡，全服同题。
///
/// 灵感来自 Meowdoku 的每日挑战机制——每天一题，保持玩家粘性。
/// 关卡基于日期 seed 确定性生成，保证同一天所有玩家拿到相同题目。
class DailyChallenge {
  DailyChallenge._();

  /// 获取今天的挑战关卡（基于日期 seed 生成，确定性可复现）。
  static ParkingLevel today() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    // 用 seed 生成一个中等难度关卡（id 范围 200-400 对应 5x5 棋盘，难度适中）
    final id = 200 + (seed % 200);
    return ParkingLevelGenerator.generateOne(id);
  }

  /// 今天的日期字符串（用作存储 key）。
  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 判断某个日期 key 是否是今天。
  static bool isToday(String? key) => key == todayKey;

  /// 获取连续挑战天数（从最近的今天往回数）。
  static int streakFromHistory(List<String> completedDates) {
    if (completedDates.isEmpty) return 0;
    final sorted = [...completedDates]..sort();
    // 从今天往回数连续天数
    var streak = 0;
    var checkDate = DateTime.now();
    while (true) {
      final key =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (sorted.contains(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}

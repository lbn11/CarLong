import '../models/level.dart';
import 'parking_chapters.dart';

/// 总关卡进度：三层难度结构 + 贯穿全表的「广告挑战关」。
///
/// # 为什么需要这一层
///
/// 心流循环（合成 5 关 / 停车 6 关一轮）只解决**局部张弛**，
/// 章（36-45 关）只解决**新内容登场**。缺的是**宏观梯度**：
/// 章与章之间难度是重置的，玩家从头看只是一条条相同的波浪，
/// 感觉不到「我现在比 100 关前强多少」。
///
/// 三层嵌套之后：
/// - **心流循环**（5/6 关）：张弛交替，抗疲劳
/// - **章**（36-45 关）：新车型 / 新机制章节，章内基线爬升
/// - **大阶段**（3 章）：整体上台阶，阶段末章 = 魔王章（+1 档），
///   让玩家在阶段结尾明确感到「这一阶段比开头强」
///
/// # 广告挑战关（占比 20-25%）
///
/// 判定用**章内偏移取模**，间隔与心跳周期**互质**，这是关键：
/// - 合成：章内每 4 关 1 个（25%）。4 与心跳周期 5 互质 →
///   广告关在 5 个相位上轮转（4→3→2→1→0→4…），不会扎堆。
///   （早期版本用 `id % 5 == 0`，而 firstId 71 ≡ 1 (mod 5)，
///   导致**所有**广告关恰好落在 phase 4 硬仗相位，还连撞限时/限步机制。）
/// - 停车：章内每 5 关 1 个（20%）。5 与心跳周期 6 互质 →
///   6 个相位全覆盖。
///
/// 两个模式的广告关密度也**故意不同**（20% vs 25%）：与心跳周期错开
/// 同一道理——同步的广告节奏会让交替游玩时「被推销感」叠加。
///
/// 新手期豁免：停车前 15 关、合成前 74 关（手写段 + 生成段头几关）。
///
/// 广告关 = 同位置正常关 **+1 档**的挑战关：
/// - 停车：目标最短步数 +1（封顶 7）+ 挡路车 +1
/// - 合成：牌堆整体 ×0.93（预算占用率上限约 0.57，仍远低于卡死线）
///
/// **广告关不是墙，这是产品红线**：加成后依然远低于「无解」线，
/// 硬实力玩家不看出能过；看广告提供的是**降难支援**
/// （续命 / 撤销 / 提示），不是通行证。做成「不看过不去」会伤留存、
/// 招差评，且与休闲定位冲突。魔王章与广告关加成**不叠加**（取较强），
/// 避免阶段末连吃两个 +1 档直接把玩家劝退。
class LevelProgression {
  LevelProgression._();

  /// 停车广告关间隔（章内每 5 关 1 个 = 20%）。
  ///
  /// 与心跳周期 6 互质，保证 6 个相位全覆盖。
  static const int parkingAdEvery = 5;

  /// 合成广告关间隔（章内每 4 关 1 个 = 25%）。
  ///
  /// 与心跳周期 5 互质，保证 5 个相位全覆盖。
  static const int mergeAdEvery = 4;

  /// 新手保护期：停车前 15 关不放广告关（玩家还没学会玩法）。
  static const int parkingGrace = 15;

  /// 合成保护期：L71 起才由生成器接管，手写段（L1-70）不放；
  /// 生成段头 4 关也当新手期（第一关就是挑战关太早）。
  static const int mergeGrace = 74;

  /// 一个大阶段包含的章数。
  static const int stageChapters = 3;

  /// 阶段名（按阶段序号，越界回退最后一个）。
  static const List<String> stageNames = [
    '启航',
    '蓄力',
    '进击',
    '精通',
    '大师',
    '传奇',
    '巅峰',
  ];

  /// 停车广告挑战关判定（章内偏移 % 5，前 15 关豁免）。
  static bool isParkingAdGate(int id) {
    if (id <= parkingGrace) return false;
    final c = ParkingChapters.chapterForId(id);
    return (id - c.startId) % parkingAdEvery == 0;
  }

  /// 合成广告挑战关判定（章内偏移 % 4，前 74 关豁免）。
  static bool isMergeAdGate(int id) {
    if (id <= mergeGrace) return false;
    final c = chapterForId(id);
    return (id - c.startId) % mergeAdEvery == 0;
  }

  /// 停车章序号（0-based）。
  static int parkingChapterIndex(int id) {
    final i = ParkingChapters.all.indexOf(ParkingChapters.chapterForId(id));
    return i < 0 ? 0 : i;
  }

  /// 合成章序号（0-based）。
  static int mergeChapterIndex(int id) {
    final i = levelChapters.indexOf(chapterForId(id));
    return i < 0 ? 0 : i;
  }

  /// 章序号 → 阶段序号（0-based）。
  static int stageOf(int chapterIdx) =>
      (chapterIdx < 0 ? 0 : chapterIdx) ~/ stageChapters;

  /// 是否魔王章（阶段末章）。末段不满整阶段时，最后一章同样收官，
  /// 但**避免连续两个魔王章**：最后一章若本身就是新阶段首章
  /// （idx % 3 == 0），则把收官让给前一章，否则玩家连打两章高压。
  static bool isDemonChapter(int chapterIdx, int totalChapters) =>
      chapterIdx >= 0 &&
      ((chapterIdx + 1) % stageChapters == 0 ||
          (chapterIdx == totalChapters - 1 && chapterIdx % stageChapters != 0));

  /// 停车魔王章判定。
  static bool isParkingDemon(int id) =>
      isDemonChapter(parkingChapterIndex(id), ParkingChapters.all.length);

  /// 合成魔王章判定。
  static bool isMergeDemon(int id) =>
      isDemonChapter(mergeChapterIndex(id), levelChapters.length);

  /// 阶段名。
  static String stageName(int stageIdx) =>
      stageNames[stageIdx.clamp(0, stageNames.length - 1)];
}

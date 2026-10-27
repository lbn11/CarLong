// 生成文件，勿手改（来源 /tmp/gen_ach_i18n.py，与 arb 一一对应）。
//
// 成就表是静态 final 列表，构造时没有 locale，所以这里按成就 id 查表：
// id 是 ASCII 契约（first_win / chapter_03 / collection_land），
// 动态部分（章节边界、车系车数）从 id 自己解出来，不往模型塞参数。

import '../models/level.dart';
import '../models/vehicle.dart';
import '../services/level_data_generator.dart';
import 'app_localizations.dart';

String? achievementTitleById(AppLocalizations l, String id) {
  final chapter = _chapterIndexOf(id);
  if (chapter != null) {
    final ch = levelChapters[chapter];
    return chapter == levelChapters.length - 1
        ? l.achFinalChapter(ch.shortTitle)
        : ch.shortTitle;
  }
  final family = _familyOf(id);
  if (family != null) return l.achFamilyTitle(family.displayLabel);
  return switch (id) {
    'first_win' => l.achFirstWinTitle,
    'clear_10' => l.achClear10Title,
    'clear_30' => l.achClear30Title,
    'clear_100' => l.achClear100Title,
    'clear_200' => l.achClear200Title,
    'clear_300' => l.achClear300Title,
    'clear_500' => l.achClear500Title,
    'boss_first' => l.achBossFirstTitle,
    'boss_5' => l.achBoss5Title,
    'boss_15' => l.achBoss15Title,
    'boss_30' => l.achBoss30Title,
    'park_first' => l.achParkFirstTitle,
    'park_clear_5' => l.achParkClear5Title,
    'park_clear_10' => l.achParkClear10Title,
    'park_clear_100' => l.achParkClear100Title,
    'park_master' => l.achParkMasterTitle,
    'park_star_3' => l.achParkStar3Title,
    'park_star5' => l.achParkStar5Title,
    'park_star50' => l.achParkStar50Title,
    'park_chapters_5' => l.achParkChapters5Title,
    'park_clear_all' => l.achParkClearAllTitle,
    'train_1' => l.achTrain1Title,
    'plane_1' => l.achPlane1Title,
    'comet_1' => l.achComet1Title,
    'void_1' => l.achVoid1Title,
    'combo_5' => l.achCombo5Title,
    'combo_10' => l.achCombo10Title,
    'combo_15' => l.achCombo15Title,
    'stars_30' => l.achStars30Title,
    'stars_300' => l.achStars300Title,
    'stars_1000' => l.achStars1000Title,
    'coins_500' => l.achCoins500Title,
    'coins_2000' => l.achCoins2000Title,
    'coins_5000' => l.achCoins5000Title,
    'signin_7' => l.achSignin7Title,
    'signin_30' => l.achSignin30Title,
    'signin_streak_7' => l.achSigninStreak7Title,
    'daily_first' => l.achDailyFirstTitle,
    'daily_streak_7' => l.achDailyStreak7Title,
    'endless_1000' => l.achEndless1000Title,
    'endless_3000' => l.achEndless3000Title,
    'clear_all' => l.achClearAllTitle,
    'boss_sweep' => l.achBossSweepTitle,
    'boss_all' => l.achBossAllTitle,
    'collection_25' => l.achCollection25Title,
    'collection_all' => l.achCollectionAllTitle,
    _ => null,
  };
}

String? achievementDescById(AppLocalizations l, String id) {
  final chapter = _chapterIndexOf(id);
  if (chapter != null) {
    final start = levelChapters[chapter].startId;
    final end = chapter + 1 < levelChapters.length
        ? levelChapters[chapter + 1].startId - 1
        : levels.last.id;
    return l.achChapterDesc(levelChapters[chapter].title, start, end);
  }
  final family = _familyOf(id);
  if (family != null) {
    final count = VehicleType.values.where((t) => t.category == family).length;
    return l.achFamilyDesc(family.displayLabel, count);
  }
  return switch (id) {
    'first_win' => l.achFirstWinDesc,
    'clear_10' => l.achClear10Desc,
    'clear_30' => l.achClear30Desc,
    'clear_100' => l.achClear100Desc,
    'clear_200' => l.achClear200Desc,
    'clear_300' => l.achClear300Desc,
    'clear_500' => l.achClear500Desc,
    'boss_first' => l.achBossFirstDesc,
    'boss_5' => l.achBoss5Desc,
    'boss_15' => l.achBoss15Desc,
    'boss_30' => l.achBoss30Desc,
    'park_first' => l.achParkFirstDesc,
    'park_clear_5' => l.achParkClear5Desc,
    'park_clear_10' => l.achParkClear10Desc,
    'park_clear_100' => l.achParkClear100Desc,
    'park_master' => l.achParkMasterDesc,
    'park_star_3' => l.achParkStar3Desc,
    'park_star5' => l.achParkStar5Desc,
    'park_star50' => l.achParkStar50Desc,
    'park_chapters_5' => l.achParkChapters5Desc,
    'park_clear_all' => l.achParkClearAllDesc,
    'train_1' => l.achTrain1Desc,
    'plane_1' => l.achPlane1Desc,
    'comet_1' => l.achComet1Desc,
    'void_1' => l.achVoid1Desc,
    'combo_5' => l.achCombo5Desc,
    'combo_10' => l.achCombo10Desc,
    'combo_15' => l.achCombo15Desc,
    'stars_30' => l.achStars30Desc,
    'stars_300' => l.achStars300Desc,
    'stars_1000' => l.achStars1000Desc,
    'coins_500' => l.achCoins500Desc,
    'coins_2000' => l.achCoins2000Desc,
    'coins_5000' => l.achCoins5000Desc,
    'signin_7' => l.achSignin7Desc,
    'signin_30' => l.achSignin30Desc,
    'signin_streak_7' => l.achSigninStreak7Desc,
    'daily_first' => l.achDailyFirstDesc,
    'daily_streak_7' => l.achDailyStreak7Desc,
    'endless_1000' => l.achEndless1000Desc,
    'endless_3000' => l.achEndless3000Desc,
    'clear_all' => l.achClearAllDesc(levels.length),
    'boss_sweep' => l.achBossSweepDesc(LevelDataGenerator.bossPerChapter),
    'boss_all' => l.achBossAllDesc(LevelDataGenerator.bossTotal),
    'collection_25' => l.achCollection25Desc(
      (VehicleType.values.length / 2).floor(),
    ),
    'collection_all' => l.achCollectionAllDesc(VehicleType.values.length),
    _ => null,
  };
}

/// `chapter_03` → 2（0 起下标）；不是章节成就返回 null。
int? _chapterIndexOf(String id) {
  if (!id.startsWith('chapter_')) return null;
  final n = int.tryParse(id.substring(8));
  if (n == null || n < 1 || n > levelChapters.length) return null;
  return n - 1;
}

/// `collection_land` → VehicleCategory.land；不是车系成就返回 null。
/// 注意 `collection_all` / `collection_25` 也带这个前缀，先排除掉。
VehicleCategory? _familyOf(String id) {
  if (!id.startsWith('collection_')) return null;
  final suffix = id.substring(11);
  for (final c in VehicleCategory.values) {
    if (c.name == suffix) return c;
  }
  return null;
}

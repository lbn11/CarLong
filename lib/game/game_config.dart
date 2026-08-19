/// 全局数值配置（任务86/89）：所有金币价格与奖励的单一事实来源。
///
/// 好处：
/// 1. 改数值只动这一处，界面/结算/经济模拟全部跟随；
/// 2. 为将来的 A/B 实验预留覆盖入口（[GameConfig.overrides]，
///    远程配置下发时写入 key -> value 即可，无需改代码）。
class GameConfig {
  GameConfig._();

  /// A/B / 远程配置覆盖：key -> 数值（int）。当前为空，接口预留。
  static Map<String, int> overrides = {};

  static int _v(int base, String key) => overrides[key] ?? base;

  // ===== 合成盘道具价格 =====
  static int get hammerCost => _v(25, 'hammerCost');
  static int get undoCost => _v(40, 'undoCost');
  static int get addCardsCost => _v(50, 'addCardsCost');
  static int get shuffleCost => _v(60, 'shuffleCost');
  static int get hintCost => _v(40, 'hintCost');

  // ===== 商店 =====
  static int get chestCost => _v(150, 'chestCost'); // 金币宝箱
  static int get dailyAdLimit => _v(3, 'dailyAdLimit'); // 激励广告每日次数
  static int get adReward => _v(100, 'adReward'); // 单次广告奖励
  static int get coinPackAmount => _v(600, 'coinPackAmount'); // 金币礼包

  // ===== 经济循环 =====
  static int get offlineCoinsPerHour => _v(12, 'offlineCoinsPerHour');
  static const List<int> signInRewards = [10, 15, 20, 25, 30, 40, 80];
  static int get collectionGrandReward => _v(500, 'collectionGrandReward'); // 全图鉴大奖
  static int get parkingBaseReward => _v(20, 'parkingBaseReward');
  static int get parkingStarReward => _v(10, 'parkingStarReward');
  static int get mergeFailConsolation => _v(10, 'mergeFailConsolation');
  static int get collectionNewReward => _v(5, 'collectionNewReward'); // 合成点亮图鉴
  static int get parkingCollectionReward => _v(10, 'parkingCollectionReward'); // 停车点亮图鉴
  static int get dailyChallengeReward => _v(150, 'dailyChallengeReward');
}

import 'package:merge_fleet/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/save/save_repository.dart';

void main() {
  testWidgets('保存序列化往返一致', (tester) async {
    final data = PlayerData(
      coins: 120,
      unlockedLevel: 3,
      bestScores: {1: 500},
    );
    final json = data.toJson();
    final restored = PlayerData.fromJson(json);
    expect(restored.coins, 120);
    expect(restored.unlockedLevel, 3);
    expect(restored.bestScores[1], 500);
  });

  test('等级生成权重之和大于零', () {
    final level = levels.first;
    final weights = level.spawnWeights();
    expect(weights, isNotEmpty);
    expect(weights.reduce((a, b) => a + b), greaterThan(0));
  });

  test('最高级卡片无法继续升级', () {
    expect(VehicleType.warpShip.next, isNull);
    expect(VehicleType.starship.next, VehicleType.warpShip); // 任务93：comet 之后有 5 档新车
  });
}

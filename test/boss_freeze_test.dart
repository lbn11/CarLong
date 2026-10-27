import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/logic/board_logic.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';

/// 测试关：5x5、produce 目标、无干扰项，专测冰封规则本身。
LevelDefinition _lv({VehicleType? target}) => LevelDefinition(
      id: 9001,
      zhName: '冰封测试',
      cols: 5,
      rows: 5,
      stockSize: 40,
      goalType: GoalType.produce,
      targetTier: target ?? VehicleType.scooter,
      targetCount: 5,
    );

void main() {
  // ─────────────────────────────────────────────────────────────
  //  冰封规则（BoardLogic 纯逻辑，无 Flame）
  // ─────────────────────────────────────────────────────────────

  test('冰封车一步也动不了：作为出发点和作为目标都被拒', () {
    final b = BoardLogic(_lv());
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.placeAt(2, 0, StackData(VehicleType.bicycle));
    b.freezeAt(0, 0);
    expect(b.at(0, 0)!.frozen, 2);

    // 冻住的车不能移到空格。
    expect(b.move(0, 0, 1, 0).valid, isFalse);
    expect(b.at(0, 0), isNotNull, reason: '应还在原地');

    // 别的车也不能拖到它身上（合成/交换都拒绝）。
    expect(b.move(2, 0, 0, 0).valid, isFalse);
  });

  test('冰封融化：每次邻格合并 -1 层，归零后解封可移动', () {
    final b = BoardLogic(_lv());
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.placeAt(2, 0, StackData(VehicleType.bicycle));
    b.placeAt(1, 0, StackData(VehicleType.bicycle));
    b.freezeAt(1, 0);
    expect(b.at(1, 0)!.frozen, 2);

    // 合并发生在 (0,0)（(2,0) 拖过去）：四邻 (1,0) 融化 1 层。
    expect(b.move(2, 0, 0, 0).valid, isTrue);
    expect(b.at(1, 0)!.frozen, 1);

    // 再在 (2,0) 合一次（(3,0) 拖过去，(2,0) 与 (1,0) 相邻）。
    b.placeAt(3, 0, StackData(VehicleType.bicycle));
    b.placeAt(2, 0, StackData(VehicleType.bicycle));
    expect(b.move(3, 0, 2, 0).valid, isTrue);
    expect(b.at(1, 0)!.frozen, 0);

    // 解封后恢复自由。
    expect(b.move(1, 0, 4, 0).valid, isTrue);
  });

  test('冰封保护名单：不冻目标车规则由 freezeAt 只接普通车保证', () {
    final b = BoardLogic(_lv());
    // 万能卡/炸弹/空格都不接受冰封（Boss 技能的无耻红线）。
    b.placeAt(0, 0, StackData(VehicleType.bicycle, isWildcard: true));
    b.placeAt(1, 0, StackData(VehicleType.bicycle, isBomb: true));
    b.freezeAt(0, 0);
    b.freezeAt(1, 0);
    b.freezeAt(3, 0);
    expect(b.at(0, 0)!.frozen, 0);
    expect(b.at(1, 0)!.frozen, 0);
    expect(b.at(3, 0), isNull);

    // 普通车正常冻。
    b.placeAt(4, 0, StackData(VehicleType.bicycle));
    b.freezeAt(4, 0);
    expect(b.at(4, 0)!.frozen, 2);
  });

  test('撤销兼容：快照/恢复带回 frozen（Boss 扔的冰封随撤销消失）', () {
    final b = BoardLogic(_lv());
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    final snap = b.snapshot();
    b.freezeAt(0, 0);
    expect(b.at(0, 0)!.frozen, 2);
    b.restore(snap);
    expect(b.at(0, 0)!.frozen, 0);
  });

  test('冰封车不影响死局/合成检测的正确性（isFull 计数不变）', () {
    final b = BoardLogic(_lv());
    b.placeAt(0, 0, StackData(VehicleType.bicycle));
    b.freezeAt(0, 0);
    // 冻住的车仍占格、仍是合法棋盘内容。
    expect(b.tileCount, 1);
    expect(b.at(0, 0)!.isFrozen, isTrue);
  });
}

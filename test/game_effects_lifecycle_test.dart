// 生命周期专项测试：验证 2026-08-15 把 `this._life = ...` 改成
// `double life = ...` + `: _life = life` 之后，构造参数仍然正确
// 赋值给私有字段 `_life`，并且 `update()` 在累计 `_t` 达到 `_life` 时
// 会调用 `removeFromParent()`。
//
// 不挂真 Flame GameWidget，直接用 Component 当 host parent。
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';

/// 简易 host：构造时不进 GameWidget。
/// Flame 基类 Component.updateTree 在 mounted=false 时,
/// _removeChild 会立即修改 _children 集合 → 触发迭代器 ConcurrentModification。
/// 所以我们自己手动迭代 children，分别 update(dt)。
typedef _Host = Component;

/// 取 host 的 children 列表（_children 是 private internal）。
List<Component> _childrenOf(Component c) => c.children.toList(growable: false);

/// 挂到 host 上跑一段 dt，返回该组件当前是否还活着。
bool _tickAndIsMounted(Component host, Component child, double dt) {
  for (final c in _childrenOf(host)) {
    c.update(dt);
  }
  return child.parent != null;
}

/// 类似上面，但支持多个 child 同时挂载（回归测试用）。
void _tick(Component host, double dt) {
  for (final c in _childrenOf(host)) {
    c.update(dt);
  }
}

void main() {
  group('FloatText(life: ...)', () {
    test('默认 life=0.9，写到私有 _life', () {
      final ft = FloatText(
        '+3',
        position: Vector2.zero(),
      );
      // _life 不可直接读；用 update 时机反推：update 0.5 仍活着，0.9 移除
      final host = _Host();
      host.add(ft);
      expect(_tickAndIsMounted(host, ft, 0.5), isTrue,
          reason: '0.5s 未满 0.9s 仍应挂载');
      expect(_tickAndIsMounted(host, ft, 0.5), isFalse,
          reason: '累计 1.0s 超过默认 life=0.9，应被 removeFromParent');
    });

    test('自定义 life: 2.0，update 1.9 仍挂载，2.0 移除', () {
      final ft = FloatText(
        '+1',
        position: Vector2.zero(),
        life: 2.0,
      );
      final host = _Host();
      host.add(ft);
      expect(_tickAndIsMounted(host, ft, 1.0), isTrue);
      expect(_tickAndIsMounted(host, ft, 0.9), isTrue);
      expect(_tickAndIsMounted(host, ft, 0.2), isFalse,
          reason: '累计 2.1 超过自定义 life=2.0');
    });
  });

  group('BurstParticles(life: ...)', () {
    test('默认 life=0.35', () {
      final bp = BurstParticles(Vector2.zero(), const Color(0xFFFFFFFF));
      final host = _Host();
      host.add(bp);
      expect(_tickAndIsMounted(host, bp, 0.2), isTrue);
      expect(_tickAndIsMounted(host, bp, 0.2), isFalse,
          reason: '累计 0.4 超过默认 life=0.35');
    });

    test('自定义 life: 1.0', () {
      final bp = BurstParticles(
        Vector2.zero(),
        const Color(0xFFFFFFFF),
        life: 1.0,
      );
      final host = _Host();
      host.add(bp);
      // t 累到 0.99 仍应挂载（< life）
      expect(_tickAndIsMounted(host, bp, 0.5), isTrue);
      expect(_tickAndIsMounted(host, bp, 0.49), isTrue);
      // t 累到 1.0 → _t >= _life → removeFromParent
      expect(_tickAndIsMounted(host, bp, 0.01), isFalse,
          reason: '累计 1.0 达到自定义 life=1.0');
    });

    test('speed/count/size 默认 + 命名参数都能正确接收', () {
      // 烟雾测试：只确认构造不抛异常，count/size 字段生效
      // （BurstParticles 用 count/size 在构造体里生成 dots，不存字段）
      // 若构造参数缺失，编译阶段就会挂。
      final bp = BurstParticles(
        Vector2(5, 5),
        const Color(0xFFFF0000),
        speed: 100,
        count: 20,
        size: 8,
      );
      expect(bp, isNotNull);
      // 仍然遵守默认 life=0.35
      final host = _Host();
      host.add(bp);
      expect(_tickAndIsMounted(host, bp, 0.4), isFalse);
    });
  });

  group('Shockwave(life: ...)', () {
    test('默认 life=0.45，maxRadius=60 默认', () {
      final sw = Shockwave(
        Vector2.zero(),
        color: const Color(0xFFFFAA00),
      );
      final host = _Host();
      host.add(sw);
      expect(_tickAndIsMounted(host, sw, 0.2), isTrue);
      expect(_tickAndIsMounted(host, sw, 0.3), isFalse,
          reason: '累计 0.5 超过默认 life=0.45');
    });

    test('自定义 life: 0.8', () {
      final sw = Shockwave(
        Vector2.zero(),
        color: const Color(0xFFFFAA00),
        maxRadius: 80,
        life: 0.8,
      );
      final host = _Host();
      host.add(sw);
      // t 累到 0.79 仍挂载
      expect(_tickAndIsMounted(host, sw, 0.4), isTrue);
      expect(_tickAndIsMounted(host, sw, 0.39), isTrue);
      // t 累到 0.8 → 移除
      expect(_tickAndIsMounted(host, sw, 0.01), isFalse,
          reason: '累计 0.8 达到自定义 life=0.8');
    });
  });

  group('回归：未指定 life 时各组件互不干扰', () {
    test('三个 effect 共存，各自按自己的 _life 移除', () {
      final ft = FloatText('combo', position: Vector2.zero());
      final bp = BurstParticles(Vector2.zero(), const Color(0xFFFFFFFF));
      final sw = Shockwave(Vector2.zero(), color: const Color(0xFFFFFFFF));

      final host = _Host();
      host.add(ft);
      host.add(bp);
      host.add(sw);

      // t=0.2：burst(0.35) 还活着；float(0.9) 还活着；shockwave(0.45) 还活着
      _tick(host, 0.2);
      expect(ft.parent, isNotNull);
      expect(bp.parent, isNotNull);
      expect(sw.parent, isNotNull);

      // 再 0.2 → t=0.4：burst 已过 0.35，移除；其它两个还活着
      _tick(host, 0.2);
      expect(ft.parent, isNotNull);
      expect(bp.parent, isNull, reason: 'burst 累计 0.4 应移除');
      expect(sw.parent, isNotNull);

      // 再 0.1 → t=0.5：shockwave 过 0.45 移除；float 还活着
      _tick(host, 0.1);
      expect(ft.parent, isNotNull);
      expect(sw.parent, isNull, reason: 'shockwave 累计 0.5 应移除');

      // 再 0.5 → t=1.0：float 过 0.9 移除
      _tick(host, 0.5);
      expect(ft.parent, isNull, reason: 'float 累计 1.0 应移除');
    });
  });

  // 仅占用 pi 以确认 dart:math 链路正常（如果将来要在测试里用 Random）
  test('dummy', () => expect(pi.isFinite, isTrue));
}

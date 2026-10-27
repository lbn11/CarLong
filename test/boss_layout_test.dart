import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_fleet/game/merge_game.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/save/save_repository.dart';
import 'package:merge_fleet/screens/game_screen.dart';

/// Boss 悬浮布局回归（2026-10-19 实玩复盘）：
///
/// 复盘时发现浏览器里 Boss 贴在屏幕右缘、王冠被裁、横屏干脆看不见。
/// 根因是**双重平移**：Flame 的 Transform2DDecorator 在调用 render() 前
/// 已把画布平移到 position（anchor=topLeft），而 BossSprite.render 里又
/// `canvas.translate(position.x, position.y)` ——Boss 被画到 2×position
/// （竖屏 195→390 飞出右缘；横屏 344→688 落进右侧 UI 面板后面）。
///
/// 修复：render 里只叠击退偏移 `canvas.translate(_knock.x, _knock.y)`。
/// 本测试守住数据层不变量（home 必须落在棋盘中心）；渲染层由浏览器
/// 截图实测验证（修复前后对比见提交说明）。
LevelDefinition _bossLevel({int cols = 5, int rows = 5, int hp = 3}) {
  return LevelDefinition(
    id: 9001,
    zhName: '👑 Boss · 测试关',
    cols: cols,
    rows: rows,
    stockSize: 90,
    targetTier: VehicleType.scooter,
    targetCount: 1,
    boss: BossSpec(
      hp: hp,
      attackInterval: 9999,
      firstDelay: 9999,
    ),
  );
}

/// 把 GameScreen 立起来，返回游戏与 GameWidget 矩形。
Future<(MergeGame, Rect)> _pump(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final level = _bossLevel();
  await tester.pumpWidget(MaterialApp(
    home: GameScreen(
      key: ValueKey(level.id),
      level: level,
      data: PlayerData(),
      repo: SaveRepository(),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  final gw = tester.widget<GameWidget>(
      find.byWidgetPredicate((w) => w is GameWidget));
  final rect =
      tester.getRect(find.byWidgetPredicate((w) => w is GameWidget));
  return (gw.game as MergeGame, rect);
}

void main() {
  testWidgets('Boss home：竖屏应悬浮在棋盘正上方中央', (tester) async {
    final (game, rect) = await _pump(tester, const Size(390, 844));

    final boss = game.bossForTest!;
    final cell = game.cellPx.value;
    const gap = 6.0;
    final boardW = game.level.cols * cell + gap * (game.level.cols - 1);
    final boardCx = rect.left + rect.width / 2;
    final boardCy = rect.top + (rect.height - boardW) / 2;

    expect(boss.homeForTest.x, closeTo(boardCx, 1.0),
        reason: 'home.x = origin.x + boardW/2 = 带宽/2，必须居中');
    expect(boss.homeForTest.x, closeTo(195, 1.0));
    expect(boss.position.x, closeTo(boss.homeForTest.x, 1.0),
        reason: 'intro/idle 钉在 home');
    expect(boss.homeForTest.y, lessThanOrEqualTo(boardCy),
        reason: 'Boss 悬浮在棋盘上方，不压第一行');
    expect(boss.size.x, closeTo(cell * 1.7, 0.5), reason: '尺寸 = 1.7 格');
  });

  testWidgets('Boss 不压棋盘：悬浮位底部须在棋盘第一行上方（竖屏+横屏）',
      (tester) async {
    // 复盘实测：修复前布局公式的 max() 钳位把 Boss 按到棋盘上——
    // 竖屏盖住第 1 行 2/3、横屏盖住整个第 1 行，玩家的棋子被压住看不见。
    // 修复：Boss 关在 onGameResize 里给悬浮位预留 1.7 格 + 间距，
    // 棋盘整体下移。这里同时锁竖屏与横屏两种几何。
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      final (game, rect) = await _pump(tester, size);
      final boss = game.bossForTest!;
      final boardTop = game.boardOriginForTest.y; // 乐队坐标
      const gap = 6.0;
      final boardH = game.level.rows * game.cellPx.value +
          gap * (game.level.rows - 1);
      final bossBottom = boss.homeForTest.y + boss.size.y / 2;

      expect(bossBottom, lessThanOrEqualTo(boardTop + 0.5),
          reason: 'Boss 底部不能压住棋盘第一行（$size）');
      expect(boardTop + boardH, lessThanOrEqualTo(rect.height + 0.5),
          reason: '给 Boss 让位后棋盘不能掉出画布底部（$size）');
      expect(boss.homeForTest.x, closeTo(rect.width / 2, 1.0),
          reason: '仍以带宽中心为 home（$size）');
    }
  });

  testWidgets('Boss home：横屏应悬浮在棋盘带正上方中央', (tester) async {
    // 横屏布局：棋盘独占左侧，右侧 156px 窄栏放 HUD。Boss 仍须在
    // 棋盘带中央——修复前 2×position 会把它甩进右侧面板后面。
    final (game, rect) = await _pump(tester, const Size(844, 390));

    final boss = game.bossForTest!;
    final bandCx = rect.left + rect.width / 2;

    expect(boss.homeForTest.x, closeTo(bandCx, 1.0),
        reason: '横屏同样以棋盘带宽中心为 home');
    expect(boss.position.x, closeTo(boss.homeForTest.x, 1.0));
  });

  testWidgets('Boss home：窗口尺寸变化后重新布局仍居中', (tester) async {
    final (game, rect) = await _pump(tester, const Size(390, 844));
    final boss = game.bossForTest!;
    expect(boss.homeForTest.x, closeTo(rect.left + rect.width / 2, 1.0));

    // 改视口（模拟旋转/窗口缩放）：onGameResize 重排后 home 仍居中。
    tester.view.physicalSize = const Size(430, 844);
    await tester.pump(const Duration(milliseconds: 300));
    expect(boss.homeForTest.x, closeTo(rect.left + 430 / 2, 1.5),
        reason: '宽度变化后 Boss 必须跟着重新居中');
  });
}

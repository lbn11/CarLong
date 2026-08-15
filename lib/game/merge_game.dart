import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' hide View;

import '../logic/board_logic.dart';
import '../models/car.dart';
import '../models/level.dart';
import 'audio_feedback.dart';
import 'vehicle_icons.dart';

/// 在指定圆角矩形上绘制不透明的迷雾层（隐藏卡面/盖住空格）。
void paintFog(Canvas canvas, RRect rr) {
  final rect = rr.outerRect;
  canvas.drawRRect(
    rr,
    Paint()
      ..color = const Color(0xFF14161B)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFF1E232B), Color(0xFF101216)],
      ).createShader(rect),
  );
  final swirl = Paint()
    ..color = const Color(0xFF4A5A72)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.12);
  canvas.drawCircle(
    Offset(rect.width * 0.35, rect.height * 0.38),
    rect.width * 0.3,
    swirl,
  );
  canvas.drawCircle(
    Offset(rect.width * 0.68, rect.height * 0.72),
    rect.width * 0.26,
    swirl,
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..color = const Color(0x66889AB0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

/// 核心游戏。负责棋盘渲染、交互、生成与胜负判定。
class MergeGame extends FlameGame {
  final LevelDefinition level;
  final BoardLogic board;

  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> produced = ValueNotifier<int>(0);

  /// 牌堆剩余张数。牌堆点一下出一张牌。
  final ValueNotifier<int> stockLeft = ValueNotifier<int>(0);

  /// 连消计数（连续合成升级，短暂时间内叠加）。
  final ValueNotifier<int> combo = ValueNotifier<int>(0);

  /// 剩余秒数（限时关卡），向上取整。非限时关卡恒为 0。
  final ValueNotifier<int> timeLeft = ValueNotifier<int>(0);

  /// 剩余步数（限步关卡）。非限步关卡恒为 0。
  final ValueNotifier<int> movesLeft = ValueNotifier<int>(0);

  /// 状态提示（棋盘满了 / 自动清理等）。
  final ValueNotifier<String?> hint = ValueNotifier<String?>(null);

  /// 游戏结束回调 (是否获胜)。
  void Function(bool won)? onGameOver;

  /// 合成出新等级时回调（图鉴收集：首次点亮）。
  void Function(CarTier tier)? onTierProduced;

  /// 无尽模式里程碑达成回调（每 5 档，参数：档位、奖励金币）。
  void Function(int endlessLevel, int reward)? onEndlessMilestone;

  /// 音效与触觉反馈。
  final AudioFeedback feedback = AudioFeedback();

  double _cellSize = 64;
  final double _gap = 6;
  Vector2 _boardOrigin = Vector2.zero();
  int _bonusScore = 0;
  double _timeLeftSec = 0;

  /// 本局统计。
  int maxCombo = 0;
  double elapsedTime = 0;

  /// 无尽模式动态目标。
  late CarTier _endlessTarget = level.targetTier ?? CarTier.taxi;
  int _endlessNeed = 3;
  int _endlessProduced = 0;
  CarTier get endlessTarget => _endlessTarget;
  int get endlessNeed => _endlessNeed;

  final List<CellSprite> _cellSprites = [];
  final List<StackSprite> _stackSprites = [];
  final List<CarTier> _deck = [];

  /// 无尽模式真实的下几张牌（预览与实际出牌共用，保证一致）。
  final List<CarTier> _upcoming = [];
  final List<({BoardSnapshot snap, int bonus})> _undoStack = [];
  ({int col, int row})? _selected;
  bool _ended = false;

  BoardBackdrop? _backdrop;

  /// 屏震:衰减计时。
  double _shakeT = 0;
  double _shakeDur = 0.0001;
  double _shakeAmp = 0;
  double _shakeSeed = 0;

  /// 锤子模式：下次点卡片 = 清除该卡。
  bool hammerArmed = false;
  void Function()? onHammerUsed;

  static const int _maxUndo = 30;

  int _combo = 0;
  double _comboTimer = 0;
  static const double _comboWindow = 1.6;

  MergeGame(this.level) : board = BoardLogic(level);

  /// 牌堆接下来的几张（用于 UI 预览）。无尽模式按当前目标动态生成。
  List<CarTier> get upcomingStock {
    if (!level.endless) return _deck.take(3).toList();
    while (_upcoming.length < 3) {
      _upcoming.add(board.weightedTierUpTo((_endlessTarget.tierIndex - 1).clamp(0, CarTier.values.length - 1)));
    }
    return List.unmodifiable(_upcoming);
  }

  /// 当前目标是否达成。
  bool get _isWin {
    if (level.endless) return false;
    if (level.goalType == GoalType.clearBoard) {
      return _deck.isEmpty && board.isEmpty;
    }
    return board.producedCount >= level.targetCount;
  }

  int _endlessLevel = 1;
  int get endlessLevel => _endlessLevel;

  /// 无尽模式：达成当前合成目标 → 升级到下一档目标。
  void _onEndlessGoalHit() {
    _endlessProduced++;
    if (_endlessProduced < _endlessNeed) return;
    _endlessProduced = 0;
    final next = _endlessTarget.next;
    if (next == null) {
      _endlessNeed += 2;
    } else {
      _endlessTarget = next;
      _endlessNeed = 3;
    }
    _endlessLevel++;
    _upcoming.clear();
    _bonusScore += 500;
    if (_endlessLevel > 0 && _endlessLevel % 5 == 0) {
      onEndlessMilestone?.call(_endlessLevel, (_endlessLevel ~/ 5) * 50);
    }
    final center = _cellCenter(level.cols ~/ 2, level.rows ~/ 2);
    add(BurstParticles(center, const Color(0xFFFFD54F), count: 40, speed: 160));
    add(Shockwave(center, color: const Color(0xFFFFD54F), maxRadius: _cellSize * 1.4));
    add(Confetti(center));
    shake(7, 0.28);
    _spawnFloat(
      level.cols ~/ 2,
      level.rows ~/ 2,
      '🎯 目标升级！下一档 ${_endlessTarget.icon} ${_endlessTarget.label}',
      color: const Color(0xFFFFCA28),
      fontSize: 18,
      dy: -_cellSize * 0.8,
    );
    _spawnFloat(
      level.cols ~/ 2,
      level.rows ~/ 2,
      '+500',
      color: const Color(0xFFFFCA28),
      fontSize: 22,
      dy: -_cellSize * 1.4,
    );
    hint.value = '达成目标！目标升级为 ${_endlessTarget.icon} ${_endlessTarget.label}';
    feedback.play(Sfx.bonus);
  }

  /// 把目标进度同步到 UI（produce=已产出数；clearBoard=剩余格数）。
  void _refreshGoal() {
    if (level.endless) {
      produced.value = _endlessProduced;
      return;
    }
    produced.value = level.goalType == GoalType.clearBoard
        ? board.tileCount
        : board.producedCount;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    await feedback.load();
    add(AmbientBackground()..priority = -2);
    for (var c = 0; c < level.cols; c++) {
      for (var r = 0; r < level.rows; r++) {
        add(CellSprite(game: this, col: c, row: r));
      }
    }
    // 开局放几张垫底，方便马上能开始合成。
    final seedCount = (level.cols * level.rows ~/ 4).clamp(1, 4);
    for (var i = 0; i < seedCount; i++) {
      final cell = level.endless
          ? board.placeTier(board.weightedTierUpTo((_endlessTarget.tierIndex - 1).clamp(0, CarTier.values.length - 1)))
          : board.placeTier(board.randomTier());
      if (cell == null) break;
      _addStack(cell.col, cell.row);
    }
    // 万能卡与炸弹：铺在随机空格上。
    for (var i = 0; i < level.wildcards; i++) {
      final cell = board.placeWildcard();
      if (cell == null) break;
      _addStack(cell.col, cell.row);
    }
    for (var i = 0; i < level.bombs; i++) {
      final cell = board.placeBomb();
      if (cell == null) break;
      _addStack(cell.col, cell.row);
    }
    _deck
      ..clear()
      ..addAll(level.endless
          ? const []
          : List.generate(level.stockSize, (_) => board.randomTier()));
    stockLeft.value = level.endless ? 1 : _deck.length;
    _timeLeftSec = (level.timeLimitSeconds ?? 0).toDouble();
    timeLeft.value = _timeLeftSec.ceil();
    movesLeft.value = level.movesLimit ?? 0;
    _refreshGoal();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _cellSprites.clear();
    _stackSprites.clear();
    const margin = 12.0;
    final availW = size.x - margin * 2;
    final availH = size.y - margin * 2;
    // 优先撑满屏幕：卡片恒为正方形、比例不变，仅靠格子大小适配。
    // 竖屏按宽度撑满，横屏/超宽屏按高度撑满，始终占满受约束的那个维度。
    var cell = (availW - _gap * (level.cols - 1)) / level.cols;
    if (cell * level.rows + _gap * (level.rows - 1) > availH) {
      cell = (availH - _gap * (level.rows - 1)) / level.rows;
    }
    _cellSize = cell.clamp(12.0, double.infinity);
    final totalW = _cellSize * level.cols + _gap * (level.cols - 1);
    final totalH = _cellSize * level.rows + _gap * (level.rows - 1);
    _boardOrigin = Vector2((size.x - totalW) / 2, (size.y - totalH) / 2);

    _backdrop?.removeFromParent();
    _backdrop = BoardBackdrop(size: Vector2(totalW + 24, totalH + 24))
      ..priority = -1
      ..position = _boardOrigin - Vector2.all(12);
    add(_backdrop!);

    for (final c in children.whereType<CellSprite>()) {
      c.size = Vector2.all(_cellSize);
      c.position = _cellPos(c.col, c.row);
      _cellSprites.add(c);
    }
    for (final s in children.whereType<StackSprite>()) {
      s.size = Vector2.all(_cellSize);
      s.position = _cellPos(s.col, s.row);
      _stackSprites.add(s);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_shakeT > 0) {
      _shakeT -= dt;
      final k = (_shakeT / _shakeDur).clamp(0.0, 1.0);
      _shakeSeed += dt * 110;
      final amp = _shakeAmp * k;
      camera.viewfinder.position = Vector2(
        sin(_shakeSeed) * amp,
        cos(_shakeSeed * 0.7) * amp,
      );
      if (_shakeT <= 0) {
        camera.viewfinder.position = Vector2.zero();
      }
    }

    if (_comboTimer > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0 && _combo > 0) {
        _combo = 0;
        combo.value = 0;
      }
    }

    if (_ended) return;
    elapsedTime += dt;
    if (_isWin) {
      _end(true);
      return;
    }
    // 限步倒扣。
    if (level.movesLimit != null && movesLeft.value <= 0) {
      hint.value = '⏹ 步数用尽！';
      _end(false);
      return;
    }
    // 限时倒计时。
    if (_timeLeftSec > 0) {
      _timeLeftSec -= dt;
      final ticks = _timeLeftSec.ceil();
      if (ticks != timeLeft.value) {
        timeLeft.value = ticks;
        // 最后 10 秒每秒滴答提醒。
        if (ticks > 0 && ticks <= 10) feedback.play(Sfx.tick);
      }
      if (_timeLeftSec <= 0) {
        hint.value = '⏰ 时间到！';
        _end(false);
        return;
      }
    }
    if (board.isDeadlocked) {
      if (level.endless) {
        _end(false);
      } else if (_deck.isEmpty) {
        _end(false);
      } else {
        _clearLowestAuto();
      }
      return;
    }
    // 没牌又没得合：温和收尾（可重试，无惩罚）。无尽模式只按死局判定，不适用。
    if (!level.endless && _deck.isEmpty && !board.hasPossibleMove) {
      _end(false);
    }
  }

  /// 从牌堆出一张牌到棋盘。index 指向备选预览中用户点的那张。
  void drawStock([int index = 0]) {
    if (_ended) return;
    final source = level.endless ? _upcoming : _deck;
    if (source.isEmpty) return;
    if (board.isFull) {
      hint.value = '棋盘满了，先合成腾出位置';
      feedback.play(Sfx.error);
      return;
    }
    final safe = index.clamp(0, source.length - 1);
    final tier = source.removeAt(safe);
    if (!level.endless) stockLeft.value = _deck.length;
    final cell = board.placeTier(tier);
    if (cell != null) {
      _addStack(cell.col, cell.row);
      board.revealNear(cell.col, cell.row);
      hint.value = null;
      feedback.play(Sfx.place);
      feedback.tap();
      _consumeMove();
      _refreshGoal();
    }
  }

  /// 限步关卡：每次成功放置/移动消耗 1 步。
  void _consumeMove() {
    if (level.movesLimit == null) return;
    if (movesLeft.value > 0) {
      movesLeft.value = movesLeft.value - 1;
      if (movesLeft.value <= 5 && movesLeft.value > 0) {
        feedback.play(Sfx.tick);
      }
    }
  }

  /// 死局时自动移除棋盘上等级最低的一张卡。
  void _clearLowestAuto() {
    final removed = board.removeLowest();
    if (removed == null) return;
    final sprite = _findStack(removed.col, removed.row);
    if (sprite != null) {
      _stackSprites.remove(sprite);
      sprite.removePuff();
    }
    hint.value = '自动清理了一辆 ${removed.tier.icon} ${removed.tier.label}，腾出位置';
    feedback.play(Sfx.error);
    _refreshGoal();
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    if (won) {
      add(Confetti(_cellCenter(level.cols ~/ 2, level.rows ~/ 2), count: 60));
      shake(8, 0.3);
      feedback.play(Sfx.win);
      feedback.success();
    } else {
      feedback.play(Sfx.lose);
      feedback.fail();
    }
    onGameOver?.call(won);
  }

  /// 是否还有可撤销的步骤。
  bool get canUndo => _undoStack.isNotEmpty;

  /// 取消当前选中。
  void deselect() {
    _selected = null;
    _refreshSelection();
  }

  /// 撤销上一步移动/合并/交换。返回是否成功。
  bool undoMove() {
    if (_ended || _undoStack.isEmpty) return false;
    final entry = _undoStack.removeLast();
    board.restore(entry.snap);
    _bonusScore = entry.bonus;
    _combo = 0;
    _comboTimer = 0;
    combo.value = 0;
    _selected = null;
    _refreshSelection();
    _syncSpritesFromBoard();
    score.value = board.totalMerges * 5 + _bonusScore;
    _refreshGoal();
    feedback.play(Sfx.undo);
    feedback.tap();
    return true;
  }

  /// 清除指定格的卡片（锤子道具）。
  void _hammerAt(int col, int row) {
    if (_ended) return;
    final data = board.removeAt(col, row);
    if (data == null) return;
    final sprite = _findStack(col, row);
    if (sprite != null) {
      _stackSprites.remove(sprite);
      sprite.removePuff();
    }
    feedback.play(Sfx.merge);
    feedback.tap();
    _refreshGoal();
    onHammerUsed?.call();
  }

  /// 锤子清除锁链障碍（点在空格的锁上时）。
  void _hammerObstacle(int col, int row) {
    if (_ended) return;
    final removed = board.removeObstacleAt(col, row);
    if (removed == null) {
      hint.value = '这里没有锁链，点击有 🔒 的格子';
      feedback.play(Sfx.error);
      return;
    }
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFFB0BEC5),
      count: 14,
      speed: 70,
    ));
    add(Shockwave(
      _cellCenter(col, row),
      color: const Color(0xFFB0BEC5),
      maxRadius: _cellSize * 0.7,
    ));
    feedback.play(Sfx.merge);
    feedback.tap();
    hint.value = '🔓 锁链已清除';
    hammerArmed = false;
    onHammerUsed?.call();
  }

  /// 限时关加时（道具）。
  void addTime(int seconds) {
    if (_ended || level.timeLimitSeconds == null || seconds <= 0) return;
    _timeLeftSec += seconds.toDouble();
    timeLeft.value = _timeLeftSec.ceil();
  }

  /// 牌堆补充 n 张随机卡片（道具）。
  void addCards(int n) {
    if (_ended || n <= 0) return;
    _deck.addAll(List.generate(n, (_) => board.randomTier()));
    stockLeft.value = _deck.length;
    _refreshGoal();
  }

  /// 把棋盘上的卡片精灵全部重建（撤销后同步显示），并高亮最高阶卡。
  void _syncSpritesFromBoard() {
    for (final s in _stackSprites) {
      s.removeFromParent();
    }
    _stackSprites.clear();
    for (var c = 0; c < level.cols; c++) {
      for (var r = 0; r < level.rows; r++) {
        final data = board.at(c, r);
        if (data != null && !data.isEmpty) _addStack(c, r);
      }
    }
    final top = board.highest();
    if (top != null) {
      _findStack(top.col, top.row)?.pulse();
    }
  }

  /// 点卡片：无选中 → 选中；点了已选中的卡 → 取消；选中了别的卡 → 移过去。
  void _onTapStack(int col, int row) {
    if (hammerArmed) {
      hammerArmed = false;
      _hammerAt(col, row);
      return;
    }
    final sel = _selected;
    if (sel == null) {
      _select(col, row);
      return;
    }
    if (sel.col == col && sel.row == row) {
      _selected = null;
      _refreshSelection();
      return;
    }
    _selected = null;
    _refreshSelection();
    _tryMove(sel.col, sel.row, col, row);
  }

  /// 点空格：有选中的卡就移过去；锤子模式下清除锁链障碍。
  void _onTapCell(int col, int row) {
    if (hammerArmed) {
      _hammerObstacle(col, row);
      return;
    }
    final sel = _selected;
    if (sel == null) return;
    _selected = null;
    _refreshSelection();
    _tryMove(sel.col, sel.row, col, row);
  }

  void _select(int col, int row) {
    _selected = (col: col, row: row);
    _refreshSelection();
  }

  /// 拖拽释放：执行移动/合并/交换，并驱动对应动画。
  void _onDragEnd(int fc, int fr, int? tc, int? tr) {
    _selected = null;
    _refreshSelection();
    final from = board.at(fc, fr);
    if (from == null) return;

    if (tc == null || tr == null || (tc == fc && tr == fr)) {
      snapBack(fc, fr);
      return;
    }

    if (!_tryMove(fc, fr, tc, tr)) snapBack(fc, fr);
  }

  /// 尝试把 (fc,fr) 移动到 (tc,tr)。成功返回 true。
  bool _tryMove(int fc, int fr, int tc, int tr) {
    final from = board.at(fc, fr);
    if (from == null) return false;
    if (fc == tc && fr == tr) return false;

    _undoStack.add((snap: board.snapshot(), bonus: _bonusScore));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);

    final result = board.move(fc, fr, tc, tr);
    if (!result.valid) {
      _undoStack.removeLast();
      return false;
    }
    _consumeMove();

    // 落子揭开附近迷雾。
    board.revealNear(fc, fr);
    board.revealNear(tc, tr);

    // 视觉终点以移动后为准（传送门可能改道；合并判定看源格是否已清空）。
    final dstSprite = _findStack(tc, tr);
    final sameTier =
        dstSprite != null && board.at(fc, fr) == null && dstSprite.col == tc;

    // 传送门：在出口位置给一个传送闪光。
    if (result.teleported) {
      final center = _cellCenter(tc, tr);
      add(BurstParticles(
        center,
        const Color(0xFFB39DDB),
        count: 10,
        speed: 70,
      ));
      add(Shockwave(
        center,
        color: const Color(0xFFB39DDB),
        maxRadius: _cellSize * 0.55,
      ));
    }

    // 炸弹引爆：大范围清场特效。
    if (result.detonated) {
      final at = result.detonatedAt!;
      for (final cell in result.detonatedCells) {
        final stack = _findStack(cell.col, cell.row);
        if (stack != null) {
          _stackSprites.remove(stack);
          stack.removePuff();
        }
      }
      final center = _cellCenter(at.col, at.row);
      add(BurstParticles(
        center,
        const Color(0xFFFF7043),
        count: 24,
        speed: 160,
      ));
      add(BurstParticles(
        center,
        const Color(0xFFFFB300),
        count: 18,
        speed: 110,
      ));
      add(Shockwave(
        center,
        color: const Color(0xFFFF7043),
        maxRadius: _cellSize * 2.0,
      ));
      shake(10, 0.35);
      _bonusScore += 300;
      _spawnFloat(at.col, at.row, '💥 引爆 +300',
          color: const Color(0xFFFF7043), fontSize: 22);
      score.value = board.totalMerges * 5 + _bonusScore;
      _refreshGoal();
      feedback.play(Sfx.merge);
      feedback.success();
      return true;
    }

    // 合并融化相邻冰块：给碎冰特效并提示。
    if (result.meltedIce.isNotEmpty) {
      for (final cell in result.meltedIce) {
        add(BurstParticles(
          _cellCenter(cell.col, cell.row),
          const Color(0xFF81D4FA),
          count: 12,
          speed: 80,
        ));
        add(Shockwave(
          _cellCenter(cell.col, cell.row),
          color: const Color(0xFF81D4FA),
          maxRadius: _cellSize * 0.65,
        ));
      }
      hint.value = '❄ 冰块融化，格子空出来了';
    }

    if (result.upgraded) {
      // 连续合成：窗口内升级则连消叠加，奖励递增。
      _combo = _comboTimer > 0 ? _combo + 1 : 1;
      _comboTimer = _comboWindow;
      combo.value = _combo;
      if (_combo > maxCombo) maxCombo = _combo;
      final comboBonus = (_combo - 1) * 10;
      _bonusScore += 50 + comboBonus;
      final producedTier = board.at(tc, tr)?.tier;
      if (producedTier != null) onTierProduced?.call(producedTier);
      _spawnJuice(
        tc,
        tr,
        points: 50 + comboBonus,
        tierColor: dstSprite?.data.tier.color,
        combo: _combo,
      );
      feedback.play(Sfx.merge);
      feedback.tap();
    }
    final goalHit = level.endless
        ? (result.upgraded && (board.at(tc, tr)?.tier == _endlessTarget))
        : level.goalType == GoalType.clearBoard
            ? (result.upgraded && (board.at(tc, tr)?.isEmpty ?? false))
            : result.producedTarget;
    if (goalHit) {
      _bonusScore += 300;
      _spawnBurst(tc, tr, const Color(0xFFFFD54F), count: 18, speed: 90);
      add(Shockwave(_cellCenter(tc, tr),
          color: const Color(0xFFFFD54F), maxRadius: _cellSize * 0.95));
      _spawnFloat(tc, tr,
          level.goalType == GoalType.clearBoard ? '+300 清掉一格!' : '+300 目标达成!',
          color: const Color(0xFFFFD54F), fontSize: 24);
      feedback.play(Sfx.bonus);
      feedback.success();
      if (level.endless) _onEndlessGoalHit();
    }
    score.value = board.totalMerges * 5 + _bonusScore;
    _refreshGoal();

    // 最高级合成后目标格被清空（count 归 0）：移除目标卡精灵，避免幽灵卡残留。
    if (result.upgraded) {
      final dstData = board.at(tc, tr);
      if (dstData != null && dstData.isEmpty) {
        final ghost = _findStack(tc, tr);
        if (ghost != null) {
          _stackSprites.remove(ghost);
          ghost.removePuff();
        }
      }
    }

    _animateMove(fc, fr, tc, tr, hadDst: dstSprite != null, sameTier: sameTier);
    return true;
  }

  /// 升级合成时的反馈：粒子 + 飘字 + 冲击波 + 屏震。
  void _spawnJuice(
    int col,
    int row, {
    required int points,
    required Color? tierColor,
    required int combo,
  }) {
    final center = _cellCenter(col, row);
    _spawnBurst(col, row, tierColor ?? const Color(0xFFFFFFFF));
    add(Shockwave(center, color: const Color(0xFFFFFFFF)));
    shake(3 + combo * 2, 0.18);
    _spawnFloat(col, row, '+$points',
        color: const Color(0xFFFFFFFF), fontSize: 20);
    if (combo >= 2) {
      _spawnFloat(col, row, '🔥 连消 x$combo',
          color: const Color(0xFFFFCA28), fontSize: 18, dy: -_cellSize * 0.6);
    }
  }

  void _spawnBurst(int col, int row, Color color,
      {int count = 12, double speed = 70}) {
    final center = _cellCenter(col, row);
    add(BurstParticles(
      center,
      color,
      count: count,
      speed: speed,
    ));
  }

  /// 屏幕震动(合成/目标达成时的打击感)。
  void shake(double amplitude, double duration) {
    _shakeAmp = max(_shakeAmp, amplitude);
    _shakeDur = duration;
    _shakeT = duration;
  }

  void _spawnFloat(int col, int row, String text,
      {Color color = const Color(0xFFFFFFFF),
      double fontSize = 20,
      double? dy}) {
    final center = _cellCenter(col, row);
    add(FloatText(
      text,
      position: center + Vector2(0, dy ?? -_cellSize * 0.35),
      color: color,
      fontSize: fontSize,
    ));
  }

  /// 把卡弹回格子位置（无效拖拽）。
  void snapBack(int col, int row) {
    final s = _findStack(col, row);
    if (s != null) s.flyTo(_cellPos(col, row));
  }

  /// 三种情况的视觉动画：移动 / 合并 / 交换。
  void _animateMove(
    int fc,
    int fr,
    int tc,
    int tr, {
    required bool hadDst,
    required bool sameTier,
  }) {
    final src = _findStack(fc, fr);
    if (src == null) return;
    final targetPos = _cellPos(tc, tr);

    if (!hadDst) {
      // 移动到空格
      src.flyTo(targetPos, onDone: () {
        src.col = tc;
        src.row = tr;
      });
    } else if (sameTier) {
      // 合并：源卡飞过去消失，目标卡升级脉冲
      final dst = _findStack(tc, tr);
      src.flyTo(
        targetPos,
        removeAfter: true,
        onDone: () => _stackSprites.remove(src),
      );
      dst?.pulse();
    } else {
      // 交换：两张卡交叉飞
      final dst = _findStack(tc, tr);
      final srcPos = _cellPos(fc, fr);
      src.flyTo(targetPos, onDone: () {
        src.col = tc;
        src.row = tr;
      });
      dst?.flyTo(srcPos, onDone: () {
        dst.col = fc;
        dst.row = fr;
      });
    }
  }

  StackSprite? _findStack(int col, int row) {
    for (final s in _stackSprites) {
      if (s.col == col && s.row == row) return s;
    }
    return null;
  }

  /// 把屏幕坐标换算成格子坐标；超出棋盘返回 null。
  ({int col, int row})? cellAt(Vector2 pos) {
    final dx = pos.x - _boardOrigin.x;
    final dy = pos.y - _boardOrigin.y;
    if (dx < -_cellSize * 0.35 || dy < -_cellSize * 0.35) return null;
    final c = (dx / (_cellSize + _gap)).floor();
    final r = (dy / (_cellSize + _gap)).floor();
    if (c < 0 || c >= level.cols || r < 0 || r >= level.rows) return null;
    return (col: c, row: r);
  }

  Vector2 _cellPos(int col, int row) =>
      _boardOrigin + Vector2(col * (_cellSize + _gap), row * (_cellSize + _gap));

  Vector2 _cellCenter(int col, int row) =>
      _cellPos(col, row) + Vector2.all(_cellSize / 2);

  void _addStack(int col, int row) {
    final sprite = StackSprite(
      game: this,
      col: col,
      row: row,
      data: board.at(col, row)!,
    );
    sprite.size = Vector2.all(_cellSize);
    sprite.position = _cellPos(col, row);
    sprite.spawn();
    _stackSprites.add(sprite);
    add(sprite);
  }

  void _refreshSelection() {
    for (final s in children.whereType<StackSprite>()) {
      s.selected = _selected != null &&
          _selected!.col == s.col &&
          _selected!.row == s.row;
    }
  }
}

/// 网格背景格。点击空格时，把选中的卡片移过去。
class CellSprite extends PositionComponent with TapCallbacks {
  final MergeGame game;
  final int col;
  final int row;

  CellSprite({required this.game, required this.col, required this.row});

  double _lastSize = -1;
  RRect _rr = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  RRect _inset = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  late final Paint _base = Paint()..color = const Color(0xFF22262C);
  Paint? _topShade;
  Paint? _bottomLight;

  @override
  void onTapDown(TapDownEvent event) {
    game._onTapCell(col, row);
  }

  void _ensureVisualCache() {
    if (size.x == _lastSize) return;
    _lastSize = size.x;
    final r = size.x * 0.14;
    _rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Radius.circular(r),
    );
    _inset = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.x - 3, size.y - 3),
      Radius.circular(r),
    );
    // 顶部内阴影，模拟凹槽
    _topShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x42000000), Color(0x00000000)],
      ).createShader(_inset.outerRect);
    // 底部微光
    _bottomLight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00000000), Color(0x12FFFFFF)],
      ).createShader(_inset.outerRect);
  }

  @override
  void render(Canvas canvas) {
    _ensureVisualCache();
    canvas.drawRRect(_rr, _base);
    canvas.drawRRect(_inset, _topShade!);
    canvas.drawRRect(_inset, _bottomLight!);

    final obs = game.board.obstacleAt(col, row);
    if (obs != null) _drawObstacle(canvas, obs, size.x);

    // 迷雾盖住空格。
    if (obs == null && game.board.isFogged(col, row)) {
      paintFog(canvas, _rr);
    }
  }

  /// 障碍物绘制：冰（青色半透明 + 裂缝）、锁（灰底 + 锁头）、石块（暗色 + 叉）。
  void _drawObstacle(Canvas canvas, Obstacle obs, double s) {
    final inset = s * 0.06;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2),
      Radius.circular(s * 0.12),
    );
    switch (obs.type) {
      case ObstacleType.ice:
        canvas.drawRRect(
          rr,
          Paint()
            ..color = const Color(0xFF7FB7D9).withValues(alpha: 0.85),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..color = const Color(0xFFD6F1FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.045,
        );
        // 左上高光
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(inset + s * 0.05, inset + s * 0.05,
                s * 0.28, s * 0.28),
            Radius.circular(s * 0.08),
          ),
          Paint()
            ..color = const Color(0x99FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.04,
        );
        // 冰层数：画内框线（每层一圈）
        final layPaint = Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035;
        for (var i = 1; i < obs.layers; i++) {
          final k = i / (obs.layers + 0.5);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rr.outerRect.deflate(s * 0.12 * k),
              Radius.circular(s * 0.1 * (1 - k * 0.5)),
            ),
            layPaint,
          );
        }
      case ObstacleType.lock:
        canvas.drawRRect(
          rr,
          Paint()
            ..color = const Color(0xFF3A3F48).withValues(alpha: 0.9),
        );
        final cx = s / 2;
        final bodyW = s * 0.34;
        final bodyH = s * 0.28;
        final bodyY = s * 0.52;
        final lockPaint = Paint()
          ..color = const Color(0xFFE8C86A)
          ..strokeWidth = s * 0.05
          ..style = PaintingStyle.stroke;
        final bodyRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, bodyY),
            width: bodyW,
            height: bodyH,
          ),
          Radius.circular(s * 0.06),
        );
        canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFFE8C86A));
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, bodyY - bodyH * 0.28),
              width: bodyW * 0.62, height: bodyH * 0.62),
          0,
          pi,
          false,
          lockPaint,
        );
        // 锁孔
        canvas.drawCircle(
          Offset(cx, bodyY + s * 0.02),
          s * 0.045,
          Paint()..color = const Color(0xFF2A2F38),
        );
      case ObstacleType.block:
        canvas.drawRRect(
          rr,
          Paint()
            ..color = const Color(0xFF2B2F37).withValues(alpha: 0.95),
        );
        // 石块边缘
        canvas.drawRRect(
          rr,
          Paint()
            ..color = const Color(0xFF4A515C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.04,
        );
        // 对角叉
        final cross = Paint()
          ..color = const Color(0xFF626A76)
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round;
        final m = s * 0.3;
        canvas.drawLine(Offset(m, m), Offset(s - m, s - m), cross);
        canvas.drawLine(Offset(s - m, m), Offset(m, s - m), cross);
      case ObstacleType.teleport:
        // 传送门：紫色漩涡圆环。
        canvas.drawRRect(
          rr,
          Paint()
            ..color = const Color(0xFF2A2440).withValues(alpha: 0.95),
        );
        final cx = s / 2;
        final rOuter = s * 0.36;
        final vortex = Paint()
          ..color = const Color(0xFFB39DDB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.055
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cx), radius: rOuter - i * s * 0.1),
            0.8 + i * 2.1,
            4.2,
            false,
            vortex,
          );
        }
        canvas.drawCircle(
          Offset(cx, cx),
          s * 0.16,
          Paint()..color = const Color(0xFF7E57C2),
        );
    }
  }
}

/// 一张车辆卡片。支持点选/拖拽移动 + 出生/移动/合并动画。
class StackSprite extends PositionComponent
    with DragCallbacks, TapCallbacks {
  final MergeGame game;
  int col;
  int row;
  StackData data;
  bool selected = false;

  bool _flying = false;
  Vector2 _flyFrom = Vector2.zero();
  Vector2 _flyTo = Vector2.zero();
  double _flyT = 0;
  final double _flyDuration = 0.15;
  bool _removeAfterFly = false;
  void Function()? _onFlyDone;

  bool _pulsing = false;
  double _pulseT = 0;

  bool _spawning = false;
  double _spawnT = 0;

  bool _removing = false;
  double _removeT = 0;

  double _dragDist = 0;

  StackSprite({
    required this.game,
    required this.col,
    required this.row,
    required this.data,
  });

  /// 出生动画：从 0 缩放弹出。
  void spawn() {
    _spawning = true;
    _spawnT = 0;
    scale = Vector2.all(0.01);
  }

  void flyTo(
    Vector2 target, {
    bool removeAfter = false,
    void Function()? onDone,
  }) {
    _flyFrom = position.clone();
    _flyTo = target;
    _removeAfterFly = removeAfter;
    _onFlyDone = onDone;
    _flyT = 0;
    _flying = true;
  }

  /// 合并脉冲：放大再回弹。
  void pulse() {
    _pulsing = true;
    _pulseT = 0;
  }

  /// 缩小消失（自动清理低阶车时用）。
  void removePuff() {
    _removing = true;
    _removeT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_spawning) {
      _spawnT += dt;
      final t = (_spawnT / 0.18).clamp(0.0, 1.0);
      scale = Vector2.all(max(0.01, Curves.easeOutBack.transform(t)));
      if (t >= 1) {
        _spawning = false;
        scale = Vector2.all(1);
      }
    }

    if (_flying) {
      _flyT += dt;
      final t = (_flyT / _flyDuration).clamp(0.0, 1.0);
      position = _flyFrom + (_flyTo - _flyFrom) * Curves.easeOut.transform(t);
      if (t >= 1) {
        position = _flyTo;
        _flying = false;
        final cb = _onFlyDone;
        _onFlyDone = null;
        if (_removeAfterFly) removeFromParent();
        cb?.call();
      }
    }

    if (_pulsing) {
      _pulseT += dt;
      final t = (_pulseT / 0.3).clamp(0.0, 1.0);
      scale = Vector2.all(1 + 0.35 * sin(pi * t));
      if (t >= 1) {
        _pulsing = false;
        scale = Vector2.all(1);
      }
    }

    if (_removing) {
      _removeT += dt;
      final t = (_removeT / 0.18).clamp(0.0, 1.0);
      scale = Vector2.all(1 - Curves.easeIn.transform(t));
      if (t >= 1) removeFromParent();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    // 按下时不处理，等手势尘埃落定：若最终是拖拽则走 onDragEnd，
    // 若是点击则走 onTapUp。避免"先选中一张再拖另一张"时在按下瞬间
    // 就触发一次合并，随后拖拽释放又移动一次，导致合并被拆散。
  }

  @override
  void onTapUp(TapUpEvent event) {
    game._onTapStack(col, row);
  }

  @override
  void onTapCancel(TapCancelEvent event) {}

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragDist = 0;
    priority = 1;
    scale = Vector2.all(1.08);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragDist += event.localDelta.length;
    position.add(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    priority = 0;
    scale = Vector2.all(1);
    if (_dragDist < 14) {
      // 距离很小：视为点击（选中）
      game._onTapStack(col, row);
    } else {
      // 以卡片中心的落点（而非左上角锚点）换算目标格，
      // 避免"按住卡片中心拖到另一张上"时被算成相邻格/空格。
      final center = position + size / 2;
      final cell = game.cellAt(center);
      game._onDragEnd(col, row, cell?.col, cell?.row);
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    priority = 0;
    scale = Vector2.all(1);
    game.snapBack(col, row);
  }

  double _lastSize = -1;
  RRect _rr = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  RRect _glossRR = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  Paint? _gradient;
  Paint? _gloss;
  Paint? _badgeGradient;
  late final Paint _shadow = Paint()
    ..color = const Color(0x4D000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  late final Paint _border = Paint()
    ..color = const Color(0x50FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  late final Paint _selBorder = Paint()
    ..color = const Color(0xFFFFD54F)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;

  void _ensureVisualCache() {
    if (size.x == _lastSize) return;
    _lastSize = size.x;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final r = size.x * 0.14;
    _rr = RRect.fromRectAndRadius(rect, Radius.circular(r));
    _glossRR = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y * 0.6),
      Radius.circular(r),
    );
    _gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(data.tier.color, const Color(0xFFFFFFFF), 0.3)!,
          data.tier.color,
          Color.lerp(data.tier.color, const Color(0xFF000000), 0.28)!,
        ],
      ).createShader(rect);
    _gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x52FFFFFF),
          Color(0x14FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y * 0.6));
    final w = size.x * 0.44;
    final h = w * 0.5;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x * 0.74, size.y * 0.86),
        width: w,
        height: h,
      ),
      Radius.circular(h / 2),
    );
    _badgeGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF3A3F48), Color(0xFF171A1E)],
      ).createShader(badgeRect.outerRect);
  }

  @override
  void render(Canvas canvas) {
    _ensureVisualCache();
    final rr = _rr;

    // 选中光晕
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rr.outerRect.inflate(5),
          Radius.circular(rr.tlRadius.x + 3),
        ),
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // 柔和投影(单层)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rr.outerRect.translate(0, 3.5),
        rr.tlRadius,
      ),
      _shadow,
    );

    // 卡面渐变:上亮下深
    canvas.drawRRect(rr, _gradient!);

    // 顶部高光
    canvas.drawRRect(_glossRR, _gloss!);

    // 边框/选中描边
    if (selected) {
      canvas.drawRRect(rr, _selBorder);
    } else {
      canvas.drawRRect(rr, _border);
    }

    // 合并闪光
    if (_pulsing) {
      canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: 0.45 * sin(pi * _pulseT)),
      );
    }

    _drawIcon(canvas);
    if (data.count == 2) _drawBadge(canvas);

    // 迷雾覆盖：隐藏卡面。
    if (game.board.isFogged(col, row)) {
      paintFog(canvas, rr);
    }
  }

  void _drawIcon(Canvas canvas) {
    final box = size.x * 0.62;
    canvas.save();
    canvas.translate(size.x / 2, size.y * 0.5);
    if (data.isBomb) {
      paintBombIcon(canvas, box);
    } else if (data.isWildcard) {
      paintWildcardIcon(canvas, box);
    } else {
      paintVehicleIcon(canvas, data.tier, box, body: data.tier.color);
    }
    canvas.restore();
  }

  void _drawBadge(Canvas canvas) {
    final w = size.x * 0.44;
    final h = w * 0.5;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x * 0.74, size.y * 0.86),
        width: w,
        height: h,
      ),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(
      badgeRect,
      _badgeGradient!,
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _paintText(
      canvas,
      'x2',
      fontSize: size.x * 0.22,
      color: const Color(0xFFFFD54F),
      center: Offset(size.x * 0.74, size.y * 0.86),
    );
  }

  void _paintText(
    Canvas canvas,
    String text, {
    required double fontSize,
    required Color color,
    required Offset center,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontFamily: 'Noto Sans SC',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}

/// 向上飘并淡出的文字（得分 / 连消提示）。
class FloatText extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  final double _life;
  double _t = 0;

  FloatText(
    this.text, {
    required Vector2 position,
    this.color = const Color(0xFFFFFFFF),
    this.fontSize = 20,
    double life = 0.9,
  }) : _life = life {
    super.position = position;
  }

  @override
  void update(double dt) {
    _t += dt;
    position.y -= dt * 42;
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1 - _t / _life).clamp(0.0, 1.0);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color.withValues(alpha: alpha),
          fontWeight: FontWeight.w800,
          fontFamily: 'Noto Sans SC',
          shadows: const [
            Shadow(color: Color(0x8A000000), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );
  }
}

/// 合并时的粒子爆开效果。
class BurstParticles extends PositionComponent {
  final double _life;
  double _t = 0;
  final List<_BurstDot> _dots = [];

  BurstParticles(
    Vector2 position,
    Color color, {
    double speed = 70,
    int count = 12,
    double life = 0.35,
    double size = 3,
  }) : _life = life {
    super.position = position;
    final rnd = Random();
    for (var i = 0; i < count; i++) {
      final angle = rnd.nextDouble() * pi * 2;
      final sp = speed * (0.5 + rnd.nextDouble());
      _dots.add(_BurstDot(
        position: Vector2.zero(),
        velocity: Vector2(cos(angle), sin(angle)) * sp,
        size: size * (0.6 + rnd.nextDouble()),
        color: color,
      ));
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    for (final d in _dots) {
      d.position += d.velocity * dt;
      d.velocity *= (1 - 4 * dt);
    }
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1 - _t / _life).clamp(0.0, 1.0);
    final paint = Paint();
    for (final d in _dots) {
      paint.color = d.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(d.position.x, d.position.y), d.size, paint);
    }
  }
}

class _BurstDot {
  Vector2 position;
  Vector2 velocity;
  final double size;
  final Color color;

  _BurstDot({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
  });
}

/// 环境背景:中心微亮的径向渐变,替代纯黑底。
class AmbientBackground extends PositionComponent with HasGameReference<MergeGame> {
  Shader? _shader;
  double _w = -1;
  double _h = -1;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    if (_shader == null || w != _w || h != _h) {
      _w = w;
      _h = h;
      _shader = RadialGradient(
        center: const Alignment(0.0, -0.3),
        radius: 1.35,
        colors: const [Color(0xFF23303E), Color(0xFF171A1E), Color(0xFF0E1013)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = _shader);
  }
}

/// 棋盘底板:包裹整个格子的圆角面板。
class BoardBackdrop extends PositionComponent {
  BoardBackdrop({required super.size});

  double _lastW = -1;
  double _lastH = -1;
  Paint? _panel;
  late final Paint _shadow = Paint()
    ..color = const Color(0x50000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  late final Paint _border = Paint()
    ..color = const Color(0x38FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    if (_panel == null || size.x != _lastW || size.y != _lastH) {
      _lastW = size.x;
      _lastH = size.y;
      _panel = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF2A2F38), Color(0xFF1A1E24)],
        ).createShader(rect);
    }
    const r = Radius.circular(22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, 7), r),
      _shadow,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), _panel!);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), _border);
  }
}

/// 合成时的冲击波扩散环。
class Shockwave extends PositionComponent {
  final Color color;
  final double maxRadius;
  final double _life;
  double _t = 0;

  Shockwave(
    Vector2 position, {
    required this.color,
    this.maxRadius = 60,
    double life = 0.45,
  }) : _life = life, super(position: position);

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (_t / _life).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 + (1 - k) * 7
      ..color = color.withValues(alpha: (1 - k) * 0.85);
    canvas.drawCircle(Offset.zero, maxRadius * Curves.easeOut.transform(k), paint);
  }
}

/// 通关/目标升级时从天而降的彩带。
class Confetti extends PositionComponent {
  final double _life = 1.5;
  double _t = 0;
  late final List<_ConfettiPiece> _pieces;

  Confetti(Vector2 position, {int count = 36}) : super(position: position) {
    final rnd = Random();
    const palette = [
      Color(0xFFFFD54F),
      Color(0xFF4A90D9),
      Color(0xFF66BB6A),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
    ];
    _pieces = List.generate(count, (_) {
      return _ConfettiPiece(
        position: Vector2(rnd.nextDouble() * 240 - 120, rnd.nextDouble() * 180 - 90),
        velocity: Vector2(rnd.nextDouble() * 60 - 30, 30 + rnd.nextDouble() * 70),
        size: 5 + rnd.nextDouble() * 6,
        color: palette[rnd.nextInt(palette.length)],
        rotation: rnd.nextDouble() * pi * 2,
        rotSpeed: (rnd.nextDouble() - 0.5) * 7,
      );
    });
  }

  @override
  void update(double dt) {
    _t += dt;
    for (final p in _pieces) {
      p.velocity.y += 240 * dt;
      p.velocity.x *= (1 - 1.2 * dt);
      p.position += p.velocity * dt;
      p.rotation += p.rotSpeed * dt;
    }
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1 - _t / _life).clamp(0.0, 1.0);
    final paint = Paint();
    for (final p in _pieces) {
      paint.color = p.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(p.position.x, p.position.y);
      canvas.rotate(p.rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.7, height: p.size),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }
}

class _ConfettiPiece {
  Vector2 position;
  Vector2 velocity;
  final double size;
  final Color color;
  double rotation;
  final double rotSpeed;

  _ConfettiPiece({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotSpeed,
  });
}

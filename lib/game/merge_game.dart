import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' hide View;

import '../logic/board_logic.dart';
import '../models/vehicle.dart';
import '../models/level.dart';
import '../services/level_data_generator.dart';
import '../theme/app_theme.dart';
import 'audio_feedback.dart';
import 'vehicle_icons.dart';

/// 在指定圆角矩形上绘制不透明的迷雾层（隐藏卡面/盖住空格）。
/// 视觉内容与尺寸唯一对应，烘焙成 [ui.Picture] 缓存，避免每个迷雾格
/// 每帧都重建 shader / 模糊遮罩（GPU 资源反复分配）。
final Map<({int w, int h}), ui.Picture> _fogCache = <({int w, int h}), ui.Picture>{};

void paintFog(Canvas canvas, RRect rr) {
  final w = rr.outerRect.width.round();
  final h = rr.outerRect.height.round();
  final key = (w: w, h: h);
  var picture = _fogCache[key];
  if (picture == null) {
    picture = _buildFogPicture(w, h, rr.tlRadius.x);
    _fogCache[key] = picture;
  }
  canvas.drawPicture(picture);
}

ui.Picture _buildFogPicture(int w, int h, double radius) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  canvas.drawRRect(
    rr,
    Paint()
      // 棋盘底板：奶油→粉雾糖霜，与全局 GlowBackground 同一氛围。
      ..color = const Color(0xFFFDF7F0)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFFDF7F0), Color(0xFFF7ECF6)],
      ).createShader(rect),
  );
  final swirl = Paint()
    ..color = const Color(0x22FF7A5C)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.12);
  canvas.drawCircle(
    Offset(rect.width * 0.35, rect.height * 0.38),
    rect.width * 0.3,
    swirl,
  );
  final swirl2 = Paint()
    ..color = const Color(0x264CC2FF)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.12);
  canvas.drawCircle(
    Offset(rect.width * 0.68, rect.height * 0.72),
    rect.width * 0.26,
    swirl2,
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..color = const Color(0x40B79BFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  return recorder.endRecording();
}

/// 核心游戏。负责棋盘渲染、交互、生成与胜负判定。
/// 失败原因（决定结算弹窗提供哪种"看广告续命"补偿）。
enum MergeFailReason {
  /// 限时关时间归零 → 续命 +30 秒。
  timeOut,

  /// 限步关步数用尽 → 续命 +10 步。
  movesOut,

  /// 牌堆打完且无可行合成（普通/清道夫关）→ 续命牌堆+2 并重排棋盘。
  deadEnd,

  /// 无尽模式死局（棋盘满且无合成）→ 续命清理最低的 3 组腾位。
  endlessStuck,
}

class MergeGame extends FlameGame {
  final LevelDefinition level;
  final BoardLogic board;

  /// Flame 默认画布底色是纯黑，会把 GlowBackground 的奶油渐变整个盖住。
  /// 改成透明，让 Flutter 侧背景透出来（棋盘底板由 BoardBackdrop 自己画）。
  @override
  ui.Color backgroundColor() => const ui.Color(0x00000000);

  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> produced = ValueNotifier<int>(0);

  /// 牌堆剩余张数。牌堆点一下出一张牌。
  final ValueNotifier<int> stockLeft = ValueNotifier<int>(0);

  /// 当前棋盘格子的像素边长（随布局变化）。
  /// UI 侧的牌堆卡据此缩放，保证"待出的牌"与"棋盘上的卡"视觉体量一致
  /// （否则 3x3 大格关卡里牌堆显得极小，6x6 小格关卡里又显得过大）。
  /// 注意：只能在帧末通知——onGameResize 发生在 build 期间，同步 setValue
  /// 会触发 "setState during build"。
  final ValueNotifier<double> cellPx = ValueNotifier<double>(64);

  /// 连消计数（连续合成升级，短暂时间内叠加）。
  final ValueNotifier<int> combo = ValueNotifier<int>(0);

  /// 剩余秒数（限时关卡），向上取整。非限时关卡恒为 0。
  final ValueNotifier<int> timeLeft = ValueNotifier<int>(0);

  /// 剩余步数（限步关卡）。非限步关卡恒为 0。
  final ValueNotifier<int> movesLeft = ValueNotifier<int>(0);

  /// 状态提示（棋盘满了 / 自动清理等）。
  final ValueNotifier<String?> hint = ValueNotifier<String?>(null);

  /// Boss 关血条（非 Boss 关恒 0）。UI 读它画 HUD。
  late final ValueNotifier<int> bossHp;
  late final ValueNotifier<int> bossMaxHp;

  /// Boss 是否已狂怒（残血触发）。UI 读它把血条改成闪红。
  final ValueNotifier<bool> bossEnraged = ValueNotifier<bool>(false);

  /// 牌堆是否被 Boss 锁住（锁牌堆技能）。UI 读它盖锁徽标。
  final ValueNotifier<bool> stockLocked = ValueNotifier<bool>(false);

  /// Boss 护盾是否张开（护盾光环技能）。UI 读它把血条改成金色。
  final ValueNotifier<bool> bossShielded = ValueNotifier<bool>(false);

  /// 牌堆污染剩余张数（污染技能：接下来 N 张出牌 -1 档）。
  final ValueNotifier<int> taintCards = ValueNotifier<int>(0);

  /// 本局用时（整秒，HUD 参考时间 chip 用）。只在秒数变化时通知，
  /// 避免每帧重建。无参考时间的关卡（限时关/无尽）没有监听者，零成本。
  final ValueNotifier<int> elapsedTick = ValueNotifier<int>(0);

  /// 游戏结束回调 (是否获胜)。
  void Function(bool won)? onGameOver;

  /// 合成出新等级时回调（图鉴收集：首次点亮）。
  void Function(VehicleType tier)? onTierProduced;

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

  /// 实时 pace 倍率（HUD 徽章）：>1 预计快于 par 可速通，<1 无奖励不罚，
  /// 0 = 不显示（无尽/限时关/开局）。0.25s 节流重算，见
  /// [LevelDataGenerator.paceRatio]。
  final ValueNotifier<double> pace = ValueNotifier<double>(0);
  double _paceT = 0;

  /// [elapsedTick] 上一次发出的整秒值（变化才通知，省重建）。
  int _lastElapsedTick = 0;

  /// 无尽模式动态目标。
  late VehicleType _endlessTarget = level.targetTier ?? VehicleType.taxi;
  int _endlessNeed = 3;
  int _endlessProduced = 0;
  VehicleType get endlessTarget => _endlessTarget;
  int get endlessNeed => _endlessNeed;

  final List<CellSprite> _cellSprites = [];
  final List<StackSprite> _stackSprites = [];
  final List<VehicleType> _deck = [];

  /// 无尽模式真实的下几张牌（预览与实际出牌共用，保证一致）。
  final List<VehicleType> _upcoming = [];
  final List<({BoardSnapshot snap, int bonus})> _undoStack = [];
  ({int col, int row})? _selected;

  /// 正在拖拽的源格（拖拽期间显示可合并提示，与点选互斥使用）。
  (int, int)? _dragSrc;

  /// 拖拽落点预览格（磁吸目标，高亮显示）。
  ({int col, int row})? _dropPreview;
  bool _dropPreviewValid = true;

  /// 清道夫关"棋盘已清空"提醒只发一次的标记（棋盘重新有牌后复位）。
  bool _emptyBoardHinted = false;
  bool _ended = false;

  /// 最近一次失败原因（胜利/进行中为 null）；结算弹窗据此展示对应续命按钮。
  MergeFailReason? _failReason;
  MergeFailReason? get failReason => _failReason;

  /// 看广告续命每局限 1 次，防止无限续命破坏难度曲线。
  int _revivesUsed = 0;
  static const int maxRevivesPerRun = 1;

  /// 本局剩余续命次数。
  int get revivesLeft => maxRevivesPerRun - _revivesUsed;

  BoardBackdrop? _backdrop;

  /// Boss 实体（null = 非 Boss 关）。
  BossSprite? _boss;

  // 测试专用 getter（boss_layout/boss_fight/boss_skills 回归测试用）：
  // 布局不变量必须在真实 widget 树里断言，不能只靠浏览器人肉截图。
  BossSprite? get bossForTest => _boss;
  Vector2 get boardOriginForTest => _boardOrigin;

  /// Boss 死亡演出倒计时（>0 = 正在播死亡动画，结束后才判定胜利）。
  double _bossDeathT = 0;

  /// 锁牌堆剩余秒数（Boss 技能）。>0 时牌堆点不动。
  double _stockLockT = 0;

  /// 禁合：被禁的档位 + 剩余秒数（Boss 技能）。
  VehicleType? _banTier;
  double _banT = 0;

  /// 融雪安全阀计时：玩家被冻车卡死时，每 2.5s 全场冻车融 1 层，
  /// 保证「永远解冻不了」不可能发生。非卡死状态归零。
  double _meltT = 0;

  /// 扣押中的车（Boss 技能⑤）：到 releaseAt 时刻放回场上。
  final List<({StackData data, double releaseAt})> _impounded = [];

  /// 污染剩余张数（Boss 技能⑦）：>0 时抽出的牌 -1 档。
  int _taintCards = 0;

  /// 护盾周期相位（Boss 护盾光环）：cycle 内前 duration 秒开盾。
  double _shieldPhase = 0;
  bool _shieldUp = false;

  /// 屏震:衰减计时。
  double _shakeT = 0;
  double _shakeDur = 0.0001;
  double _shakeAmp = 0;
  double _shakeSeed = 0;

  /// 锤子模式：下次点卡片 = 清除该卡。
  bool hammerArmed = false;
  void Function()? onHammerUsed;

  /// 玩家操作回调(教程用): action = draw / move / merge / hammer
  void Function(String action, VehicleType? tier)? onPlayerAction;

  static const int _maxUndo = 30;

  int _combo = 0;
  double _comboTimer = 0;
  static const double _comboWindow = 1.6;

  MergeGame(this.level) : board = BoardLogic(level) {
    // 构造时即带上关卡配置的血条：避免首帧渲染出「0 / N」再跳正。
    bossHp = ValueNotifier<int>(level.boss?.hp ?? 0);
    bossMaxHp = ValueNotifier<int>(level.boss?.hp ?? 0);
  }

  /// 牌堆接下来的几张（用于 UI 预览）。无尽模式按当前目标动态生成。
  List<VehicleType> get upcomingStock {
    if (!level.endless) return _deck.take(3).toList();
    while (_upcoming.length < 3) {
      _upcoming.add(board.weightedTierUpTo((_endlessTarget.id - 1).clamp(0, VehicleType.values.length - 1)));
    }
    return List.unmodifiable(_upcoming);
  }

  /// 当前目标是否达成。
  bool get _isWin {
    if (level.endless) return false;
    // Boss 关：胜负 = 打空 Boss 血条（产出目标车就是攻击手段）。
    // 死亡演出期间不算赢——让爆炸/彩带先播完。
    if (level.boss != null) {
      return _boss != null && _boss!.hp <= 0 && _bossDeathT <= 0;
    }
    if (level.goalType == GoalType.clearBoard) {
      // 残留 ≤ clearLimit 即胜利（合并-3 下绝对清空需三进制全局守恒，
      // 概率≈0；顶部窗口出牌时残堆 90% ≤4、99% ≤6，按上限闭环）。
      return _deck.isEmpty && level.boardCleared(board.tileCount);
    }
    return board.producedCount >= level.targetCount;
  }

  /// 玩家操作落地后立刻补一次结算检查（不等下一帧 update）。
  ///
  /// `update` 每帧也会查，但它依赖 Flame 的 game loop 一直转：关卡介绍卡、
  /// 暂停遮罩、特写浮层等页面态一旦让引擎停摆，而玩家已经达成目标，
  /// 就会出现「任务做完了却停在关卡里」的观感。判定本身很便宜
  /// （几个字段比较），在操作后同步补一次是兜底也是即时反馈。
  /// Boss 关的死亡演出由 `_isWin` 里的 `_bossDeathT` 条件自然挡住。
  void _checkGoalNow() {
    if (_ended) return;
    if (!_isWin) return;
    _end(true);
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
      '🎯 目标升级！下一档 ${_endlessTarget.icon} ${_endlessTarget.name}',
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
    hint.value = '达成目标！目标升级为 ${_endlessTarget.icon} ${_endlessTarget.name}';
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
    // 音效池后台加载（不阻塞棋盘初始化；pool 未就绪时 play 自动静默）。
    // 此前 await 会卡死整个 onLoad——测试环境/音频异常时棋盘永远空盘。
    unawaited(feedback.load());
    // 跳出当前 build/attach 同步段，避免初始化期间的 ValueNotifier 通知
    // 触发 "setState during build"（ValueListenableBuilder 正在构建中）。
    await Future<void>.delayed(Duration.zero);
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
          ? board.placeTier(board.weightedTierUpTo((_endlessTarget.id - 1).clamp(0, VehicleType.values.length - 1)))
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
    // Boss 关：在棋盘上方放出 Boss 实体（会动、会攻击的那种）。
    final spec = level.boss;
    if (spec != null && level.targetTier != null) {
      bossMaxHp.value = spec.hp;
      bossHp.value = spec.hp;
      final boss = BossSprite(
        game: this,
        tier: level.targetTier!.next?.next ?? level.targetTier!,
        spec: spec,
      )..priority = 2;
      boss.layout(_boardOrigin, _cellSize);
      _boss = boss;
      add(boss);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _cellSprites.clear();
    _stackSprites.clear();
    const margin = 12.0;
    final availW = size.x - margin * 2;
    final availH = size.y - margin * 2;
    final hasBoss = level.boss != null;
    // 优先撑满屏幕：卡片恒为正方形、比例不变，仅靠格子大小适配。
    // 竖屏按宽度撑满，横屏/超宽屏按高度撑满，始终占满受约束的那个维度。
    var cell = (availW - _gap * (level.cols - 1)) / level.cols;
    // Boss 关：Boss 常驻悬浮在棋盘正上方，占 1.7 格 + 间距。这段高度必须
    // 先从 availH 里扣掉再算格子——否则布局公式的 max() 钳位会把 Boss
    // 按到棋盘第一行上（实测竖屏盖住第 1 行 2/3、横屏盖住整个第 1 行），
    // 玩家的棋子被 Boss 压住看不见。解一环：
    //   cell*rows + gap*(rows-1) + cell*1.7 + 12 <= availH
    if (hasBoss) {
      final bossCell =
          (availH - _gap * (level.rows - 1) - 12) / (level.rows + 1.7);
      if (cell > bossCell) cell = bossCell;
    }
    if (cell * level.rows + _gap * (level.rows - 1) > availH) {
      cell = (availH - _gap * (level.rows - 1)) / level.rows;
    }
    _cellSize = cell.clamp(12.0, double.infinity);
    final totalW = _cellSize * level.cols + _gap * (level.cols - 1);
    final totalH = _cellSize * level.rows + _gap * (level.rows - 1);
    // Boss 关：棋盘整体下移给悬浮 Boss 让位（贴顶 + 1.7 格 + 间距），
    // home.y 的 max() 钳位就不会再把 Boss 按回棋盘上；非 Boss 关保持垂直居中。
    // min() 兜底防止极端矮屏幕把棋盘顶出底部。
    final bossPad = hasBoss ? _cellSize * 1.7 + 12 : 0.0;
    _boardOrigin = Vector2(
      (size.x - totalW) / 2,
      hasBoss
          ? min(bossPad, max(0.0, size.y - totalH - 4))
          : (size.y - totalH) / 2,
    );

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
    // Boss 跟随棋盘重新布局（悬浮位置由格子尺寸算出）。
    _boss?.layout(_boardOrigin, _cellSize);
    // 帧末再通知 UI（onGameResize 处于 build 阶段，同步通知会抛错）。
    if ((cellPx.value - _cellSize).abs() > 0.5) {
      final v = _cellSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) cellPx.value = v;
      });
    }
  }

  bool _disposed = false;

  @override
  void onDispose() {
    _disposed = true;
    super.onDispose();
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

    // 锁牌堆倒计时：到点自动解封。
    if (_stockLockT > 0) {
      _stockLockT -= dt;
      if (_stockLockT <= 0) {
        _stockLockT = 0;
        stockLocked.value = false;
        hint.value = '🔓 牌堆解锁了';
      }
    }

    // 胶水倒计时：到点自动干掉（不像冰封要邻格合并救）。
    final glueDried = board.tickGlue(dt);
    if (glueDried > 0) {
      hint.value = '🍯 胶水干了，车可以动了！';
      feedback.play(Sfx.bonus);
    }

    // 黑洞倒计时：到点闭合。
    final holesGone = board.tickHoles(dt);
    if (holesGone > 0) {
      hint.value = '🌀 黑洞闭合了，格子能用了！';
      feedback.play(Sfx.bonus);
    }

    // 禁合倒计时：到点解禁。
    if (_banT > 0) {
      _banT -= dt;
      if (_banT <= 0) {
        _banT = 0;
        _banTier = null;
        hint.value = '🚫 禁合解除，可以正常合成了！';
        feedback.play(Sfx.bonus);
      }
    }

    // Boss 扣押放回：到点的车智能落位回场（满了顺延，不吞车）。
    _releaseImpounded();

    // Boss 护盾光环：cycle 内前 duration 秒开盾，期间产出不计 HP。
    final bossSpec = level.boss;
    if (_boss != null &&
        !_boss!.dead &&
        bossSpec != null &&
        bossSpec.shieldCycle > 0) {
      _shieldPhase = (_shieldPhase + dt) % bossSpec.shieldCycle;
      final up = _shieldPhase < bossSpec.shieldDuration;
      if (up != _shieldUp) {
        _shieldUp = up;
        bossShielded.value = up;
        if (up) {
          hint.value = '🛡 Boss 张开护盾，攒不住劲了，先布局！';
          feedback.play(Sfx.bonus);
        } else {
          hint.value = '🛡 护盾消失，全力进攻！';
        }
      }
    } else if (_shieldUp) {
      _shieldUp = false;
      bossShielded.value = false;
    }

    if (_ended) return;
    elapsedTime += dt;
    final tick = elapsedTime.round();
    if (tick != _lastElapsedTick) {
      _lastElapsedTick = tick;
      elapsedTick.value = tick;
    }
    // pace 徽章节流重算（0.25s）：HUD 显示「照当前手感能不能速通」。
    _paceT += dt;
    if (_paceT >= 0.25) {
      _paceT = 0;
      pace.value = LevelDataGenerator.paceRatio(
        level,
        elapsed: elapsedTime,
        stockLeft: stockLeft.value,
        produced: produced.value,
        bossHp: bossHp.value,
      );
    }
    // Boss 死亡演出：血条打空后先播 1.15s 爆炸/彩带再结算，
    // 否则「砰」下一秒就弹窗，事件感被掐掉。
    if (_bossDeathT > 0) {
      _bossDeathT -= dt;
      if (_bossDeathT <= 0) {
        _end(true);
        return;
      }
    }
    if (_isWin) {
      _end(true);
      return;
    }
    // 清道夫关：棋盘提前清空但牌堆没打完 → 明确提醒（否则玩家会困惑
    // "桌面啥也没有为啥不过关"——胜利还要求打完牌堆）。
    if (!level.endless && level.goalType == GoalType.clearBoard) {
      if (board.tileCount == 0 && _deck.isNotEmpty) {
        if (!_emptyBoardHinted) {
          _emptyBoardHinted = true;
          hint.value =
              '✨ 棋盘清空了！还剩 ${_deck.length} 张牌没打完，'
              '继续出牌，最后场上剩 ≤${level.clearLimit ?? 0} 组就赢';
        }
      } else if (board.tileCount > 0) {
        _emptyBoardHinted = false;
      }
    }
    // 限步倒扣。
    if (level.movesLimit != null && movesLeft.value <= 0) {
      hint.value = '⏹ 步数用尽！';
      _end(false, failReason: MergeFailReason.movesOut);
      return;
    }
    // 限时倒计时。
    if (_timeLeftSec > 0) {
      _timeLeftSec -= dt;
      final ticks = _timeLeftSec.ceil();
      if (ticks != timeLeft.value) {
        timeLeft.value = ticks;
        // 最后 10 秒每秒滴答 + 轻振，紧迫感拉满。
        if (ticks > 0 && ticks <= 10) {
          feedback.play(Sfx.tick);
          feedback.select();
        }
      }
      if (_timeLeftSec <= 0) {
        hint.value = '⏰ 时间到！';
        _end(false, failReason: MergeFailReason.timeOut);
        return;
      }
    }
    // ── 融雪安全阀 ──
    // 玩家真卡死（牌堆空或棋盘满，且无可合步）时，若场上还有冻车/冰块：
    // 每 2.5s 全场融 1 层。没有它，「Boss 把车全冻住」会出现两种永久的
    // 坏结局——① hasPossibleMove 曾把冻车算成可合资源，死局检测不触发，
    // 游戏挂着永不结束；② 检测修好后直接判负，玩家没有任何翻盘机会。
    // 冰块（addObstacle 的 ice）同理但更严重：它只能被相邻合并融化，
    // 填满棋盘后玩家零操作、死局收尾删不到冰、牌堆永远抽不完——
    // 不接进来就是永久软锁。胶水更简单：它只随时间干掉，等着就行。
    // 融雪期间暂停死局收尾；全部融化后仍无步 → 走下面的标准死局处理。
    if (!level.endless &&
        (board.hasFrozen || board.hasGlue || board.hasIce) &&
        (_deck.isEmpty || board.isFull) &&
        !board.hasPossibleMove) {
      if (board.hasFrozen) {
        _meltT += dt;
        if (_meltT >= 2.5) {
          _meltT = 0;
          final melted = board.meltAllFrozenOneLayer();
          if (melted > 0) {
            final left = board.frozenLayers;
            hint.value = left > 0
                ? '☃️ 无路可走了…冰层在减弱（还剩 $left 层）'
                : '☀️ 冰层全部融化！';
            feedback.play(Sfx.bonus);
          }
        }
      } else if (board.hasIce) {
        _meltT += dt;
        if (_meltT >= 2.5) {
          _meltT = 0;
          final melted = board.meltAllIceOneLayer();
          if (melted > 0) {
            final left = board.iceLayers;
            hint.value = left > 0
                ? '🧊 冰封棋盘…冰块在裂开（还剩 $left 层）'
                : '💧 冰块全部融化！';
            feedback.play(Sfx.bonus);
          }
        }
      } else {
        // 只有胶水：等它自己干（最多几秒，不做额外动作）。
        _meltT = 0;
        final left = board.glueLeft.ceil();
        hint.value = '🍯 无路可走了…胶水还有 $left 秒干掉，等一下';
      }
      return;
    }
    _meltT = 0;
    if (board.isDeadlocked) {
      if (level.endless) {
        _end(false, failReason: MergeFailReason.endlessStuck);
      } else if (_deck.isEmpty) {
        _end(false, failReason: MergeFailReason.deadEnd);
      } else {
        _clearLowestAuto();
      }
      return;
    }
    // 没牌又没得合：温和收尾（可重试，无惩罚）。无尽模式只按死局判定，不适用。
    if (!level.endless && _deck.isEmpty && !board.hasPossibleMove) {
      _end(false, failReason: MergeFailReason.deadEnd);
    }
  }

  /// 从牌堆出一张牌到棋盘。index 指向备选预览中用户点的那张。
  /// 落点用 [BoardLogic.placeTierSmart]：优先同等级卡旁（一步可合），其次随机。
  void drawStock([int index = 0]) {
    if (_ended) return;
    // Boss 锁牌堆：整段读条时间牌堆点不动（打断抽牌节奏）。
    if (stockLocked.value) {
      hint.value = '🔒 Boss 锁住了牌堆，等一下！';
      feedback.play(Sfx.error);
      return;
    }
    final source = level.endless ? _upcoming : _deck;
    if (source.isEmpty) return;
    if (board.isFull) {
      hint.value = '棋盘满了，先合成腾出位置';
      feedback.play(Sfx.error);
      return;
    }
    final safe = index.clamp(0, source.length - 1);
    final tier = _applyTaint(source.removeAt(safe));
    if (!level.endless) stockLeft.value = _deck.length;
    final cell = board.placeTierSmart(tier);
    if (cell != null) {
      _addStack(cell.col, cell.row);
      board.revealNear(cell.col, cell.row);
      hint.value = null;
      feedback.play(Sfx.place);
      feedback.tap();
      _consumeMove();
      _refreshGoal();
      // 清道夫关：抽走最后一张牌 + 场上残堆达标 = 达成，立即结算。
      _checkGoalNow();
      onPlayerAction?.call('draw', tier);
    } else if (board.hasHoles) {
      // 有黑洞占着格导致落不下牌：说破，别让玩家以为 bug。
      hint.value = '🌀 黑洞堵着，落不下牌——喂它一张或等它闭合';
      feedback.play(Sfx.error);
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
    hint.value = '自动清理了一辆 ${removed.tier.icon} ${removed.tier.name}，腾出位置';
    feedback.play(Sfx.error);
    _refreshGoal();
  }

  void _end(bool won, {MergeFailReason? failReason}) {
    if (_ended) return;
    _ended = true;
    _failReason = won ? null : failReason;
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

  // ─────────────────────────────────────────────────────────────
  //  Boss 战
  // ─────────────────────────────────────────────────────────────

  /// 玩家产出一辆目标车 = 打 Boss 一下。血条打空 → 死亡演出 → 胜利。
  void _damageBoss(int col, int row) {
    final boss = _boss;
    if (boss == null || boss.dead) return;
    // 护盾张着：这一击被挡下（不扣血、不触发死亡/狂怒判定），
    // 只播受击反馈——玩家要等盾间隙再爆发。
    if (_shieldUp) {
      boss.hit(blocked: true);
      _spawnFloat(col, row, '🛡 格挡',
          color: const Color(0xFFFFD54F), fontSize: 20);
      hint.value = '🛡 护盾挡下了这一击，等盾消失再进攻！';
      feedback.play(Sfx.error);
      return;
    }
    boss.hit();
    bossHp.value = boss.hp;
    _spawnFloat(col, row, '👑 -1',
        color: const Color(0xFFEF5350), fontSize: 24);
    add(Shockwave(_cellCenter(col, row),
        color: const Color(0xFFEF5350), maxRadius: _cellSize * 0.9));
    feedback.play(Sfx.merge);
    // 残血狂怒（章 11+）：血条过半那一刻 Boss 进入狂暴，攻击提速、
    // 冰封数 +1、整车变红——Boss 战的节奏弧线顶点。
    final spec = level.boss;
    if (spec != null &&
        spec.enrageAtHalf &&
        !boss.enraged &&
        boss.hp <= spec.hp / 2) {
      boss.enrage();
      bossEnraged.value = true;
      hint.value = '👑 Boss 狂怒了！攻击变快了！';
      feedback.play(Sfx.bonus);
      shake(6, 0.3);
    }
    if (boss.hp <= 0) {
      _bossDeathT = 1.15;
      hint.value = '👑 Boss 倒下了！';
      add(BurstParticles(boss.position.clone(), const Color(0xFFFF7043),
          count: 30, speed: 200));
      add(BurstParticles(boss.position.clone(), const Color(0xFFFFD54F),
          count: 20, speed: 140));
      add(Confetti(boss.position.clone(), count: 60));
      shake(9, 0.4);
      feedback.play(Sfx.bonus);
    }
  }

  /// Boss 技能①冰封：把场上最高档的**非目标**普通车冻住（默认 1 张，
  /// 狂怒/深水区 2 张）。冰封车动不了也合不了，玩家必须在其邻格
  /// 完成 freezeLayers 次合并才能「救」回来——合成链顶端被掐断，
  /// 这才是真正有痛感的阻挡。
  ///
  /// 不冻目标车：胜利资源被偷会造成「赢了却被赖掉」的挫败感，
  /// 痛感应来自「进度被拖慢」而不是「胜利被剥夺」。
  /// 返回实际冻住几张（0 = 全场没货，调用方应换招）。
  int _bossFreezeCar({int count = 1, int layers = 2}) {
    final target = level.targetTier;
    final candidates = <({int col, int row, int tierId})>[];
    for (var c = 0; c < level.cols; c++) {
      for (var r = 0; r < level.rows; r++) {
        final d = board.at(c, r);
        if (d == null || d.isEmpty || d.isWildcard || d.isBomb) continue;
        if (d.locked) continue; // 已冻/粘过的别再冻（浪费一招）
        if (d.tier == target) continue; // 不碰目标车
        candidates.add((col: c, row: r, tierId: d.tier.index));
      }
    }
    if (candidates.isEmpty) return 0;
    candidates.sort((a, b) => b.tierId.compareTo(a.tierId));
    var froze = 0;
    for (final t in candidates.take(count.clamp(1, 3))) {
      board.freezeAt(t.col, t.row, layers: layers);
      add(BurstParticles(
        _cellCenter(t.col, t.row),
        const Color(0xFF81D4FA),
        count: 14,
        speed: 100,
      ));
      add(Shockwave(
        _cellCenter(t.col, t.row),
        color: const Color(0xFF4FC3F7),
        maxRadius: _cellSize * 0.6,
      ));
      froze++;
    }
    shake(4, 0.2);
    hint.value = froze > 1
        ? '🧊 Boss 冰封了 $froze 张原料车，在旁边合成来救它们！'
        : '🧊 Boss 冻住了你的原料车，在旁边合成来救它！';
    feedback.play(Sfx.place);
    return froze;
  }

  /// Boss 技能②拖车：把场上的一辆车拖走。
  /// [topTier] = 抢最高档（掠夺资产，章 3+）；false = 拖最低档
  /// （新手期轻骚扰——最低档本就是待清理的合成废料）。
  void _bossStealCar(int col, int row) {
    final data = board.removeAt(col, row);
    if (data == null) return;
    final sprite = _findStack(col, row);
    if (sprite != null) {
      _stackSprites.remove(sprite);
      sprite.removePuff();
    }
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFFAB47BC),
      count: 14,
      speed: 90,
    ));
    hint.value = '😈 Boss 拖走了你的 ${data.tier.icon} ${data.tier.name}！';
    feedback.play(Sfx.error);
    _refreshGoal();
  }

  /// Boss 技能③锁牌堆：seconds 秒内牌堆点不动（抽牌节奏被打断）。
  void _bossLockStock(double seconds) {
    if (seconds <= 0) return;
    _stockLockT = seconds;
    stockLocked.value = true;
    hint.value = '🔒 Boss 锁住了牌堆 ${seconds.round()} 秒！';
    feedback.play(Sfx.error);
    shake(5, 0.25);
  }

  /// Boss 填充技：往空格扔一块冰（占格、挡路，邻格合成可融化）。
  /// 只在「没有车可冻/可抢」时用——冰块本身很弱，不能当主菜。
  void _bossDropIce(int col, int row) {
    if (board.at(col, row) != null || board.obstacleAt(col, row) != null) return;
    board.addObstacle(ObstacleType.ice, col, row, layers: 1);
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFF81D4FA),
      count: 16,
      speed: 110,
    ));
    add(Shockwave(
      _cellCenter(col, row),
      color: const Color(0xFF4FC3F7),
      maxRadius: _cellSize * 0.7,
    ));
    shake(4, 0.2);
    hint.value = '🧊 Boss 扔出冰块，占了一个格子！';
    feedback.play(Sfx.place);
  }

  /// Boss 技能④塌方：往空格落一块碎石（两层冰，需两次邻格合并化掉）。
  /// 与冰块的区别：塌方一次落 N 块（章 8+ 两块）且预警环是石灰色，
  /// 玩家看到褐色圈就要开始清列——范围压迫，不是补位。
  void _bossDropStone(int col, int row) {
    if (board.at(col, row) != null || board.obstacleAt(col, row) != null) return;
    board.addObstacle(ObstacleType.ice, col, row, layers: 2);
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFFBCAAA4),
      count: 18,
      speed: 130,
    ));
    add(Shockwave(
      _cellCenter(col, row),
      color: const Color(0xFF8D6E63),
      maxRadius: _cellSize * 0.65,
    ));
    shake(5, 0.25);
    feedback.play(Sfx.place);
  }

  /// Boss 技能⑤扣押：把一辆原料车拖进 Boss 车库，[spec.impoundSeconds]
  /// 秒后放回场上（[_releaseImpounded] 驱动）。与拖车的区别：车只是
  /// 「暂时没了」而不是永久损失——痛感来自关键位突然空出来，以及
  /// 放回位置不可控（智能落点，未必回原格）。
  ///
  /// 只扣 count==1 的单张：一堆两辆的车已是半步合成状态，扣了放回时
  /// 数量恢复不了，属于「赢了却被赖掉」的挫败设计，不做。
  void _bossImpoundCar(int col, int row) {
    final data = board.removeAt(col, row);
    if (data == null) return;
    final sprite = _findStack(col, row);
    if (sprite != null) {
      _stackSprites.remove(sprite);
      sprite.removePuff();
    }
    _impounded.add((
      data: data,
      releaseAt: elapsedTime + (level.boss?.impoundSeconds ?? 3),
    ));
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFFEC407A),
      count: 16,
      speed: 100,
    ));
    add(Shockwave(
      _cellCenter(col, row),
      color: const Color(0xFFEC407A),
      maxRadius: _cellSize * 0.6,
    ));
    hint.value =
        '🚗 Boss 把 ${data.tier.icon} ${data.tier.name} 扣押进了车库，'
        '${level.boss?.impoundSeconds ?? 3} 秒后放回！';
    feedback.play(Sfx.error);
    _refreshGoal();
  }

  /// 扣押到期放回：智能落点（优先同等级邻格）。棋盘满了就顺延到下一帧，
  /// 不会吞车。
  void _releaseImpounded() {
    if (_impounded.isEmpty) return;
    for (final item in _impounded.toList()) {
      if (elapsedTime < item.releaseAt) continue;
      final cell = board.placeTierSmart(item.data.tier);
      if (cell == null) continue; // 满了：下一帧再试
      _impounded.remove(item);
      _addStack(cell.col, cell.row);
      add(BurstParticles(
        _cellCenter(cell.col, cell.row),
        const Color(0xFFEC407A),
        count: 12,
        speed: 90,
      ));
      hint.value = '✨ 被扣押的 ${item.data.tier.icon} 放回来了！';
    }
  }

  /// Boss 技能⑥退化：把一辆原料车打低 [levels] 档（章 9+ 两档）。
  /// 不碰目标车；已经是最低档（自行车）的直接拆掉——等级链顶端被
  /// 削掉，玩家要重新攒，这才是真痛感（对比：冰块占格还能绕）。
  void _bossDevolveCar(int col, int row, {int levels = 1}) {
    final d = board.at(col, row);
    if (d == null || d.isEmpty || d.isWildcard || d.isBomb) return;
    if (d.tier == level.targetTier) return; // 不碰目标车
    final newIdx = (d.tier.index - levels)
        .clamp(0, VehicleType.values.length - 1);
    final old = d.tier;
    if (newIdx == d.tier.index) {
      // 已经到底：拆解移除。
      board.removeAt(col, row);
      final sprite = _findStack(col, row);
      if (sprite != null) {
        _stackSprites.remove(sprite);
        sprite.removePuff();
      }
      hint.value = '💥 Boss 拆掉了你的 ${old.icon} ${old.name}！';
    } else {
      d.tier = VehicleType.values[newIdx];
      hint.value = '📉 Boss 施了退化射线：${old.icon} ${old.name} '
          '→ ${d.tier.icon} ${d.tier.name}！';
    }
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFF7E57C2),
      count: 18,
      speed: 110,
    ));
    add(Shockwave(
      _cellCenter(col, row),
      color: const Color(0xFF7E57C2),
      maxRadius: _cellSize * 0.7,
    ));
    shake(5, 0.25);
    feedback.play(Sfx.error);
    _refreshGoal();
  }

  /// Boss 技能⑦污染：接下来 [spec.taintCards] 张从牌堆出的牌强制 -1 档
  /// （在 drawStock 里执行）。反制：这几张吃存粮不抽牌，或者故意把
  /// 要合的垫脚车位置留给它们。
  void _bossTaint() {
    final source = level.endless ? _upcoming : _deck;
    if (source.isEmpty) return;
    _taintCards = level.boss?.taintCards ?? 2;
    taintCards.value = _taintCards;
    hint.value = '☠️ Boss 污染了牌堆！接下来 $_taintCards 张会降一档！';
    feedback.play(Sfx.error);
    shake(4, 0.2);
  }

  /// 抽牌时应用污染：抽出的牌 -1 档（最低档保持不变，不会变负）。
  VehicleType _applyTaint(VehicleType tier) {
    if (_taintCards <= 0) return tier;
    _taintCards--;
    taintCards.value = _taintCards;
    return VehicleType.values[(tier.index - 1)
        .clamp(0, VehicleType.values.length - 1)];
  }

  // ─────────────────────────────────────────────────────────────
  //  Boss 战 · 第二批技能（胶水 / 黑洞 / 洗牌 / 禁合 / 抢目标 / 迷雾）
  // ─────────────────────────────────────────────────────────────

  /// 当前被禁合的档位（null = 没有）。StackSprite 读它给该档车画红 ✕。
  VehicleType? get banTier => _banTier;

  /// 禁合是否生效中（秒数 > 0）。
  bool get banActive => _banT > 0 && _banTier != null;

  /// Boss 技能⑧胶水：把一辆原料车粘住 [seconds] 秒。与冰封共用
  /// [StackData.locked] 阻断面（动不了/合不了、死局检测/hint 同步
  /// 感知），但**只随时间干掉**——反制就是等，短促的节奏干扰。
  void _bossGlueCar(int col, int row, {double seconds = 4}) {
    final d = board.at(col, row);
    if (d == null || d.isEmpty || d.isWildcard || d.isBomb) return;
    if (d.locked) return;
    board.glueAt(col, row, seconds);
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFFFFB300),
      count: 16,
      speed: 100,
    ));
    add(Shockwave(
      _cellCenter(col, row),
      color: const Color(0xFFFFB300),
      maxRadius: _cellSize * 0.6,
    ));
    shake(4, 0.2);
    hint.value = '🍯 Boss 泼了胶水：${d.tier.icon} ${d.tier.name} '
        '${seconds.round()} 秒内动不了，等它干！';
    feedback.play(Sfx.error);
    _refreshGoal();
  }

  /// 胶水的「出手瞬间改判」版：现扫场选最高档原料车粘住。
  /// 返回是否粘到（0 张可粘 → 调用方退化成冰/空转）。
  bool _bossGlueHighest({double seconds = 4}) {
    final pick = _highestFreeCar();
    if (pick == null) return false;
    _bossGlueCar(pick.col, pick.row, seconds: seconds);
    return true;
  }

  /// Boss 技能⑨黑洞：在空格撕开一个持续 [seconds] 秒的旋涡。
  /// 占格期间落不下牌（[BoardLogic.placeTierSmart] 自动避开），
  /// 但玩家可以把卡**拖进去喂给它**——陷阱不是墙，有利用空间。
  void _bossAddHole(int col, int row, {double seconds = 6}) {
    if (board.at(col, row) != null || board.obstacleAt(col, row) != null) {
      return;
    }
    board.addHole(col, row, seconds);
    add(BurstParticles(
      _cellCenter(col, row),
      const Color(0xFF4A148C),
      count: 20,
      speed: 140,
    ));
    add(Shockwave(
      _cellCenter(col, row),
      color: const Color(0xFF7B1FA2),
      maxRadius: _cellSize * 0.7,
    ));
    shake(5, 0.25);
    hint.value = '🌀 Boss 撕开一个黑洞！落子要避开，也可以把废牌喂给它';
    feedback.play(Sfx.error);
  }

  /// Boss 技能⑩洗牌：全场没冻/粘的车随机重排（冻车胶车原地不动）。
  /// 纯搅局——破坏玩家布局，也顺带破解死局。视觉：全部卡片瞬移
  /// 重排 + 屏幕轻晃。
  void _bossShuffle() {
    final n = board.shuffleUnlocked();
    if (n == 0) {
      hint.value = '🌀 Boss 想洗牌，但你的车都被冻住/粘住了，没得洗！';
      return;
    }
    _syncSpritesFromBoard();
    shake(6, 0.3);
    hint.value = '🌀 Boss 洗牌！$n 辆车被打乱了，重新找组合！';
    feedback.play(Sfx.error);
    _refreshGoal();
  }

  /// Boss 技能⑪禁合：[tier] 在 [seconds] 秒内不能合并（只挡合并，
  /// 不挡换位/挪窝——留出路，不制造软锁）。该档车会画红 ✕。
  void _bossBanMerge(VehicleType? tier, {double seconds = 4}) {
    if (tier == null) return;
    _banTier = tier;
    _banT = seconds;
    hint.value = '🚫 禁合：${tier.icon} ${tier.name} ${seconds.round()} '
        '秒内不能合并，先合别的！';
    feedback.play(Sfx.error);
    shake(4, 0.2);
  }

  /// 场上数量最多的非目标档位（禁合的出手瞬间改判用）。
  VehicleType? _mostCommonFreeTier() {
    final byTier = <VehicleType, int>{};
    for (var c = 0; c < level.cols; c++) {
      for (var r = 0; r < level.rows; r++) {
        final d = board.at(c, r);
        if (d == null || d.isEmpty || d.isWildcard || d.isBomb) continue;
        if (d.locked) continue;
        if (d.tier == level.targetTier) continue;
        byTier[d.tier] = (byTier[d.tier] ?? 0) + 1;
      }
    }
    if (byTier.isEmpty) return null;
    var best = byTier.entries.first;
    for (final e in byTier.entries) {
      if (e.value > best.value) best = e;
    }
    return best.key;
  }

  /// 场上最高档的可动原料车（胶水/退化式「现扫场」选点共用）。
  ({int col, int row})? _highestFreeCar() {
    ({int col, int row, int tierId})? best;
    for (var c = 0; c < level.cols; c++) {
      for (var r = 0; r < level.rows; r++) {
        final d = board.at(c, r);
        if (d == null || d.isEmpty || d.isWildcard || d.isBomb) continue;
        if (d.locked) continue;
        if (d.tier == level.targetTier) continue;
        if (best == null || d.tier.index > best.tierId) {
          best = (col: c, row: r, tierId: d.tier.index);
        }
      }
    }
    return best == null ? null : (col: best.col, row: best.row);
  }

  /// Boss 技能⑫抢目标：抓回一个已达成的目标车补 1 血。
  /// **唯一碰胜利资源的技能**——所以：① 金色预警；② 只在 Boss
  /// 已受伤时可用（满血没东西可抢，天然防连放）；③ 深水区才入池。
  void _bossStealGoal() {
    final boss = _boss;
    if (boss == null || boss.dead) return;
    boss.hp += 1;
    if (boss.hp > boss.maxHp) boss.maxHp = boss.hp;
    bossHp.value = boss.hp;
    bossMaxHp.value = boss.maxHp;
    add(FloatText(
      '🏆 抢回 1 血！',
      position: boss.position.clone() + Vector2(0, -_cellSize * 0.5),
      color: const Color(0xFFFFD700),
      fontSize: 20,
    ));
    add(Shockwave(boss.position.clone(),
        color: const Color(0xFFFFD700), maxRadius: _cellSize * 1.2));
    add(BurstParticles(
      boss.position.clone(),
      const Color(0xFFFFD54F),
      count: 18,
      speed: 130,
    ));
    hint.value = '🏆 Boss 抢走了你一个目标车，回了 1 点血！';
    feedback.play(Sfx.error);
    shake(6, 0.3);
  }

  /// Boss 技能⑬迷雾：盖住 [cells] 里的车（复用关卡迷雾表与
  /// [BoardLogic.revealNear]——落子/合并不远处就能揭开，反制靠探头）。
  void _bossFog(List<({int col, int row})> cells) {
    if (cells.isEmpty) return;
    board.fogCellsAt(cells);
    hint.value = cells.length > 1
        ? '🌫 Boss 放出迷雾，盖住了 ${cells.length} 辆车！'
        : '🌫 Boss 放出一团迷雾，盖住了 1 辆车！';
    feedback.play(Sfx.error);
    shake(4, 0.2);
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
    onPlayerAction?.call('hammer', null);
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

  /// 洗牌重排（金币道具）：重排棋盘卡片位置，可解除死局（即"复活"）。
  void shuffleBoard() {
    if (_ended) return;
    board.shuffleTiles();
    _syncSpritesFromBoard();
    _refreshGoal();
    feedback.play(Sfx.merge);
    feedback.tap();
    hint.value = board.isDeadlocked
        ? '😵 重排后仍是死局，换个思路或再试一次'
        : '🔀 棋盘已重排，寻找新组合！';
  }

  /// 看广告续命：解除结束状态，按失败原因补偿并继续本局。
  /// 返回 false 表示不可续命（未结束 / 次数已用完）。
  bool revive() {
    if (!_ended || revivesLeft <= 0) return false;
    // 先解除结束态：addTime/addCards 在 _ended 时会直接返回。
    _ended = false;
    _revivesUsed++;
    switch (_failReason) {
      case MergeFailReason.timeOut:
        addTime(30);
        hint.value = '▶️ 续命成功：+30 秒，冲！';
      case MergeFailReason.movesOut:
        movesLeft.value += 10;
        hint.value = '▶️ 续命成功：+10 步，冲！';
      case MergeFailReason.deadEnd:
        // 牌堆见底且无合成：补 2 张新料 + 重排棋盘打开局面。
        addCards(2);
        board.shuffleTiles();
        _syncSpritesFromBoard();
        hint.value = '▶️ 续命成功：牌堆 +2 并重排棋盘';
      case MergeFailReason.endlessStuck:
        // 无尽死局：清掉最低的 3 组腾出空间（不走 _clearLowestAuto，避免报错音效）。
        for (var i = 0; i < 3; i++) {
          final removed = board.removeLowest();
          if (removed == null) break;
          final sprite = _findStack(removed.col, removed.row);
          if (sprite != null) {
            _stackSprites.remove(sprite);
            sprite.removePuff();
          }
        }
        _refreshGoal();
        hint.value = '▶️ 续命成功：清理了 3 组车，继续冲档！';
      case null:
        // 理论不可达（胜利不会触发续命），保险起见恢复结束态。
        _ended = true;
        _revivesUsed--;
        return false;
    }
    feedback.play(Sfx.bonus);
    return true;
  }

  /// 提示一步（金币道具）：高亮一个可合并的操作。
  void showHint() {
    if (_ended) return;
    final m = board.hintMove();
    if (m == null) {
      hint.value = _deck.isEmpty
          ? '😅 没有可合并的了，试试洗牌或加牌'
          : '😅 场上没得合，点牌堆出新卡试试';
      feedback.play(Sfx.error);
      return;
    }
    _findStack(m.fc, m.fr)?.pulse();
    _findStack(m.tc, m.tr)?.pulse();
    final from = board.at(m.fc, m.fr);
    final to = board.at(m.tc, m.tr);
    if (from != null && to != null && from.tier == to.tier) {
      hint.value = '💡 把 ${from.tier.icon} 拖到 ${to.tier.icon} 上合并！';
    } else if (to != null && to.isWildcard) {
      hint.value = '💡 把 ${from!.tier.icon} 拖到万能卡上！';
    } else if (from != null && from.isBomb && to != null && to.isBomb) {
      hint.value = '💡 把炸弹拖到一起，集满 3 颗引爆！';
    } else {
      hint.value = '💡 把这张卡拖到那张卡上！';
    }
    feedback.tap();
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
  /// 拿着牌堆卡时点卡片 = 取消拿起（卡片格不能落子）。
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
      feedback.select();
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
    // 点选反馈：tick 音（触感由 onDragStart 起手时给，避免重复触发）。
    feedback.play(Sfx.tick);
  }

  /// 拖拽释放：执行移动/合并/交换，并驱动对应动画。
  void _onDragEnd(int fc, int fr, int? tc, int? tr) {
    _dragSrc = null;
    updateDropPreview(null);
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

    // Boss 禁合：该档位合并被禁（只挡合并，不挡换位/挪窝——留出路，
    // 不制造软锁；禁合最多几秒，等待有界）。
    if (banActive) {
      final dst = board.at(tc, tr);
      if (dst != null &&
          !dst.isEmpty &&
          !from.isBomb &&
          !dst.isBomb &&
          (from.isWildcard || dst.isWildcard || from.tier == dst.tier)) {
        final mergedTier = from.isWildcard ? dst.tier : from.tier;
        if (mergedTier == _banTier) {
          hint.value = '🚫 禁合中：${_banTier!.icon} ${_banTier!.name} '
              '还不能合并（还剩 ${_banT.ceil()} 秒）';
          feedback.play(Sfx.error);
          feedback.reject();
          return false;
        }
      }
    }

    _undoStack.add((snap: board.snapshot(), bonus: _bonusScore));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    final mergesBefore = board.totalMerges;

    final result = board.move(fc, fr, tc, tr);
    if (!result.valid) {
      _undoStack.removeLast();
      // 无效移动不再静默：error 音 + 短促拒绝触感，明确告诉玩家"这步不行"。
      feedback.play(Sfx.error);
      feedback.reject();
      return false;
    }
    _consumeMove();

    // Boss 黑洞：卡被旋涡吞掉（不结算合并）。拖拽中的卡先飞进旋涡
    // 再消失——「废牌喂黑洞」是合法策略，「好牌掉进去」是惩罚。
    if (result.swallowed) {
      final sprite = _findStack(fc, fr);
      if (sprite != null) {
        _stackSprites.remove(sprite);
        sprite.flyTo(_cellPos(tc, tr), onDone: sprite.removePuff);
      }
      final center = _cellCenter(tc, tr);
      add(BurstParticles(center, const Color(0xFF4A148C), count: 22,
          speed: 150));
      add(Shockwave(center,
          color: const Color(0xFF7B1FA2), maxRadius: _cellSize * 0.8));
      hint.value = '🌀 黑洞吞掉了你的 ${from.tier.icon} ${from.tier.name}！';
      feedback.play(Sfx.error);
      shake(5, 0.25);
      _refreshGoal();
      onPlayerAction?.call('swallow', from.tier);
      return true;
    }

    // 落子揭开附近迷雾（sonar 能力扩大侦察范围）。
    final wasFogged = board.isFogged(fc, fr) || board.isFogged(tc, tr);
    final moverTier = from.tier;
    final sonarRange = moverTier.stats.ability == SpecialAbility.sonar ? 2 : 1;
    board.revealNear(fc, fr, range: sonarRange);
    board.revealNear(tc, tr, range: sonarRange);
    if (wasFogged) {
      onPlayerAction?.call('reveal', null);
    }

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

    // 特殊能力激活提示。
    final ability = moverTier.stats.ability;
    if (ability == SpecialAbility.breakIce && result.meltedIce.isNotEmpty) {
      _spawnFloat(tc, tr, '🔥 破冰！',
          color: const Color(0xFF81D4FA), fontSize: 16, dy: -_cellSize * 0.5);
    } else if (ability == SpecialAbility.breakChain) {
      _spawnFloat(tc, tr, '🔓 解锁！',
          color: const Color(0xFFE8C86A), fontSize: 16, dy: -_cellSize * 0.5);
    } else if (ability == SpecialAbility.clearRock) {
      _spawnFloat(tc, tr, '💥 碎石！',
          color: const Color(0xFF90A4AE), fontSize: 16, dy: -_cellSize * 0.5);
    } else if (ability == SpecialAbility.flyOver) {
      _spawnFloat(tc, tr, '✈️ 飞越！',
          color: const Color(0xFF90CAF9), fontSize: 16, dy: -_cellSize * 0.5);
    } else if (ability == SpecialAbility.teleport) {
      _spawnFloat(tc, tr, '⚡ 传送！',
          color: const Color(0xFFB39DDB), fontSize: 16, dy: -_cellSize * 0.5);
    } else if (ability == SpecialAbility.warp) {
      _spawnFloat(tc, tr, '🌀 曲速！',
          color: const Color(0xFF7E57C2), fontSize: 16, dy: -_cellSize * 0.5);
    }

    if (ability == SpecialAbility.sonar && sonarRange > 1) {
      _spawnFloat(fc, fr, '📡 侦察！',
          color: const Color(0xFF80CBC4), fontSize: 16, dy: -_cellSize * 0.5);
    }

    void Function()? onArrive;
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
      onPlayerAction?.call('merge', producedTier);
      // 特效与音效/触感延迟到卡片飞抵终点的瞬间：打击点落在"碰撞"上
      // 而不是"起飞"上（拖拽路径同样受益——短飞后同样在落格瞬间炸）。
      final juiceColor = dstSprite?.data.tier.color;
      final juicePoints = 50 + comboBonus;
      final juiceCombo = _combo;
      onArrive = () {
        _spawnJuice(
          tc,
          tr,
          points: juicePoints,
          tierColor: juiceColor,
          combo: juiceCombo,
        );
        feedback.play(Sfx.merge);
        feedback.combo(juiceCombo);
      };
    }
    // 修复：非升级合并（2 张同档）也算"合成动作"，供新手教学推进
    // （L1 教程"拖两张合并"不升级，若只在 upgraded 时回调会卡住）。
    if (!result.upgraded && board.totalMerges > mergesBefore) {
      onPlayerAction?.call('merge', board.at(tc, tr)?.tier);
    }
    final goalHit = level.endless
        ? (result.upgraded && (board.at(tc, tr)?.tier == _endlessTarget))
        : level.goalType == GoalType.clearBoard
            ? (result.upgraded && (board.at(tc, tr)?.isEmpty ?? false))
            : result.producedTarget;
    if (goalHit) {
      if (level.boss != null) {
        // Boss 关：产出目标车 = 攻击 Boss（每次 -1 HP），打空即胜。
        // 不再走普通关的 +300 目标奖励——Boss 有自己的受击反馈。
        _damageBoss(tc, tr);
      } else {
        _bonusScore += 300;
        _spawnBurst(tc, tr, const Color(0xFFFFD54F), count: 18, speed: 90);
        add(Shockwave(_cellCenter(tc, tr),
            color: const Color(0xFFFFD54F), maxRadius: _cellSize * 0.95));
        _spawnFloat(
            tc,
            tr,
            // 「目标达成」只在真的达成时喊。以前每合出一辆目标车都飘
            // 「目标达成」，多目标关（×2/×3）打到第 1 辆就喊，玩家会以为
            // 关该结算了却没结算——这是"达到任务却不退出"的观感来源。
            level.goalType == GoalType.clearBoard
                ? '+300 清掉一格!'
                : (board.producedCount >= level.targetCount
                    ? '+300 目标达成!'
                    : '+300 目标车 '
                        '${board.producedCount}/${level.targetCount}'),
            color: const Color(0xFFFFD54F),
            fontSize: 24);
        feedback.play(Sfx.bonus);
        feedback.success();
        if (level.endless) _onEndlessGoalHit();
      }
    }
    score.value = board.totalMerges * 5 + _bonusScore;
    _refreshGoal();
    // 达成即结算：不等下一帧 update（见 _checkGoalNow 注释）。
    _checkGoalNow();

    // 最高级合成后目标格被清空（count 归 0）：移除目标卡精灵，避免幽灵卡残留。
    if (result.upgraded) {
      final dstData = board.at(tc, tr);
      if (dstData != null && dstData.isEmpty) {
        // 顶级车三合一升空（合成模式核心机制：最高档不占格）。
        // 补充说明飘字（+300 特效在下方 goalHit 处），避免"凭空消失"困惑。
        final ghost = _findStack(tc, tr);
        if (ghost != null) {
          _stackSprites.remove(ghost);
          ghost.removePuff();
        }
        _spawnFloat(
          tc,
          tr,
          level.goalType == GoalType.clearBoard
              ? '🚀 顶级车升空，清掉 3 堆！'
              : '🚀 ${board.at(tc, tr)?.tier.name ?? "顶级车"}已交付',
          color: const Color(0xFFFFD54F),
          fontSize: 15,
          dy: -_cellSize * 0.95,
        );
      }
    }

    _animateMove(
      fc,
      fr,
      tc,
      tr,
      hadDst: dstSprite != null,
      sameTier: sameTier,
      onArrive: onArrive,
    );
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
  /// [onArrive] 在卡飞抵终点的瞬间触发（合成特效与飞行同步，而非起飞即炸）。
  void _animateMove(
    int fc,
    int fr,
    int tc,
    int tr, {
    required bool hadDst,
    required bool sameTier,
    void Function()? onArrive,
  }) {
    final src = _findStack(fc, fr);
    if (src == null) {
      onArrive?.call();
      return;
    }
    final targetPos = _cellPos(tc, tr);

    if (!hadDst) {
      // 移动到空格：飞过去 + 落地小弹跳。
      src.flyTo(targetPos, onDone: () {
        src.col = tc;
        src.row = tr;
        src.pulse(0.12);
      });
    } else if (sameTier) {
      // 合并：源卡飞过去消失，目标卡升级脉冲，落地的瞬间炸特效。
      final dst = _findStack(tc, tr);
      src.flyTo(
        targetPos,
        removeAfter: true,
        onDone: () {
          _stackSprites.remove(src);
          dst?.pulse();
          onArrive?.call();
        },
      );
    } else {
      // 交换：两张卡交叉飞。
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
      onArrive?.call();
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

  /// 磁吸落点：拖拽中心附近（≤0.45 格）最近的【合法】目标格。
  /// 只修正真正的近失误——精确落在格内的走原有判定，远离棋盘仍视为取消。
  ({int col, int row})? nearestDropCell(Vector2 center, int fc, int fr) {
    ({int col, int row})? best;
    var bestD = double.infinity;
    final r = _cellSize * 0.45;
    for (var c = 0; c < level.cols; c++) {
      for (var rr2 = 0; rr2 < level.rows; rr2++) {
        final d = (_cellCenter(c, rr2) - center).length;
        if (d >= bestD || d > r) continue;
        if (!_canDropOn(fc, fr, c, rr2)) continue;
        bestD = d;
        best = (col: c, row: rr2);
      }
    }
    return best;
  }

  /// 落点合法性预判（不执行移动）：空格可放；同级车/万能卡/炸弹对可合；
  /// 石块等障碍不可落。传送门按可落处理，最终以 _tryMove 的完整校验为准。
  bool _canDropOn(int fc, int fr, int tc, int tr) {
    final from = board.at(fc, fr);
    if (from == null || (fc == tc && fr == tr)) return false;
    if (tc < 0 || tc >= level.cols || tr < 0 || tr >= level.rows) {
      return false;
    }
    final obs = board.obstacleAt(tc, tr);
    if (obs != null && obs.type != ObstacleType.teleport) return false;
    final dst = board.at(tc, tr);
    if (dst == null) return true;
    return _canMergeWith(from, dst);
  }

  /// 解析最终落点：精确命中且合法 → 原样返回（手感与旧版一致）；
  /// 否则尝试近失磁吸；再不行返回原始包含结果（由 _tryMove 弹回）。
  ({int col, int row})? resolveDrop(Vector2 center, int fc, int fr) {
    final raw = cellAt(center);
    if (raw != null && _canDropOn(fc, fr, raw.col, raw.row)) return raw;
    return nearestDropCell(center, fc, fr) ?? raw;
  }

  /// 更新拖拽落点预览高亮（同格重复调用无副作用）。
  /// [valid] 表示该落点能否真正落下，决定预览环是金色还是红色。
  void updateDropPreview(({int col, int row})? cell, {bool valid = true}) {
    if (cell == _dropPreview && valid == _dropPreviewValid) return;
    _dropPreview = cell;
    _dropPreviewValid = valid;
    for (final s in children.whereType<CellSprite>()) {
      s.dropTarget =
          cell != null && s.col == cell.col && s.row == cell.row;
      s.dropValid = valid;
    }
  }

  /// 可合并提示：选中/拖拽源与其他堆能否合并。
  /// 规则与 board.move 一致——同级车、万能卡×任意、炸弹×炸弹。
  bool _canMergeWith(StackData src, StackData dst) {
    if (src.isBomb || dst.isBomb) {
      return src.isBomb && dst.isBomb;
    }
    if (src.isWildcard || dst.isWildcard) return true;
    return src.tier == dst.tier;
  }

  /// 刷新"可合并"提示（点选或拖拽时调用；null 清除全部提示）。
  void _setMergeHints((int, int)? src) {
    final srcData = src == null ? null : board.at(src.$1, src.$2);
    for (final s in children.whereType<StackSprite>()) {
      final isSrc = src != null && s.col == src.$1 && s.row == src.$2;
      s.mergeHint = !isSrc &&
          srcData != null &&
          _canMergeWith(srcData, s.data);
    }
  }

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
    final sel = _selected;
    for (final s in children.whereType<StackSprite>()) {
      s.selected = sel != null && sel.col == s.col && sel.row == s.row;
    }
    // 选中时同步高亮所有可合并目标；无选中且非拖拽则清空提示。
    if (sel != null) {
      _setMergeHints((sel.col, sel.row));
    } else if (_dragSrc == null) {
      _setMergeHints(null);
    }
  }
}

/// 网格背景格。点击空格时，把选中的卡片移过去。
class CellSprite extends PositionComponent with TapCallbacks {
  final MergeGame game;
  final int col;
  final int row;

  CellSprite({required this.game, required this.col, required this.row});

  /// 拖拽落点预览：当前磁吸目标格高亮环（金色=可落，红色=松手会弹回）。
  bool dropTarget = false;

  /// 落点是否合法（与 [MergeGame._canDropOn] 一致），决定预览环颜色。
  bool dropValid = true;

  double _lastSize = -1;
  RRect _rr = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  RRect _inset = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  late final Paint _base = Paint()..color = const Color(0xFFFCF7F2);
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
    // 顶部内阴影，模拟凹槽（浅色版：只留一点点，避免把白格压灰）
    _topShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x14000000), Color(0x00000000)],
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

    // 拖拽落点预览：磁吸目标格高亮环。金色=松手即落这里；红色=放不下，
    // 提前告知省得松手弹回后才知道（配合松手时的 error 音+拒绝触感）。
    if (dropTarget) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _rr.outerRect.inflate(3),
          Radius.circular(_rr.tlRadius.x + 2),
        ),
        Paint()
          ..color = dropValid
              ? const Color(0xFFFFD54F)
              : const Color(0xFFEF5350)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final obs = game.board.obstacleAt(col, row);
    if (obs != null) _drawObstacle(canvas, obs, size.x);

    // 黑洞旋涡（Boss 技能）：暗紫涡旋占格，落子要绕开。
    final holeLeft = game.board.holeLeftAt(col, row);
    if (holeLeft > 0) _drawHole(canvas, size.x, holeLeft);

    // 迷雾盖住空格。
    if (obs == null && game.board.isFogged(col, row)) {
      paintFog(canvas, _rr);
    }
  }

  /// 黑洞视觉：暗紫径向底 + 两条反向旋转的螺旋弧 + 中心白点。
  /// 出场/消失带淡入淡出（holeLeft 判寿命），旋转相位取对局时间，
  /// 停住的游戏里涡旋也是凝住的。
  void _drawHole(Canvas canvas, double s, double left) {
    final c = Offset(s / 2, s / 2);
    final fade = left < 0.5 ? (left / 0.5).clamp(0.0, 1.0) : 1.0;
    canvas.drawCircle(
      c,
      s * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1A0033).withValues(alpha: 0.95 * fade),
            const Color(0xFF4A148C).withValues(alpha: 0.75 * fade),
            const Color(0xFF7B1FA2).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.42)),
    );
    final phase = game.elapsedTime * 3.2;
    for (var i = 0; i < 2; i++) {
      final dir = i == 0 ? 1.0 : -1.0;
      final arc = Paint()
        ..color = const Color(0xFFCE93D8).withValues(alpha: 0.85 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round;
      final r = s * (0.16 + 0.1 * i);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        phase * dir + i * 2.1,
        2.4,
        false,
        arc,
      );
    }
    canvas.drawCircle(
      c,
      s * 0.05,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * fade),
    );
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

  /// 可合并提示：选中/拖拽某张卡时，能与之合并的目标堆高亮细环。
  bool mergeHint = false;

  bool _flying = false;
  Vector2 _flyFrom = Vector2.zero();
  Vector2 _flyTo = Vector2.zero();
  double _flyT = 0;
  final double _flyDuration = 0.15;
  bool _removeAfterFly = false;
  void Function()? _onFlyDone;

  bool _pulsing = false;
  double _pulseT = 0;
  double _pulseAmp = 0.35;

  bool _spawning = false;
  double _spawnT = 0;

  bool _removing = false;
  double _removeT = 0;

  double _dragDist = 0;

  /// 选中态缩放过渡（0→1 平滑跟随 selected 标志）：选中的卡"拿起来"。
  double _selScaleT = 0;

  /// 当前动画帧的基础缩放（spawn/pulse/drag 写入），最终 scale 在 update
  /// 末尾统一 = _animScale × (1 + 选中放大系数)。
  double _animScale = 1;

  /// 提示环/选中光晕呼吸相位。
  double _breathT = 0;

  /// 拖拽悬浮偏移量：卡片抬到手指上方，避免拇指遮挡（松手时归零）。
  double _liftY = 0;

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
    _animScale = 0.01;
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

  /// 合并脉冲：放大再回弹（[amp] 控制幅度，移动落地用小幅度）。
  void pulse([double amp = 0.35]) {
    _pulsing = true;
    _pulseT = 0;
    _pulseAmp = amp;
  }

  /// 缩小消失（自动清理低阶车时用）。
  void removePuff() {
    _removing = true;
    _removeT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _breathT += dt;

    // 选中缩放平滑跟随（拿起/放下都有过渡，不跳变）。
    final selTarget = selected ? 1.0 : 0.0;
    _selScaleT += (selTarget - _selScaleT) * (dt * 14).clamp(0.0, 1.0);

    if (_spawning) {
      _spawnT += dt;
      final t = (_spawnT / 0.18).clamp(0.0, 1.0);
      _animScale = max(0.01, Curves.easeOutBack.transform(t));
      if (t >= 1) {
        _spawning = false;
        _animScale = 1;
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
      _animScale = 1 + _pulseAmp * sin(pi * t);
      if (t >= 1) {
        _pulsing = false;
        _animScale = 1;
      }
    }

    if (_removing) {
      _removeT += dt;
      final t = (_removeT / 0.18).clamp(0.0, 1.0);
      _animScale = 1 - Curves.easeIn.transform(t);
      if (t >= 1) removeFromParent();
    }

    // 最终缩放 = 动画基础缩放 × 选中放大。选中的卡"拿起来"，
    // 取消选中平滑放回，与金圈呼吸一起构成选中态的体感。
    scale = Vector2.all(_animScale * (1 + 0.06 * _selScaleT));
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
    _animScale = 1.08;
    // 悬浮偏移：卡片小幅抬到手指上方（0.55 格），拇指不挡卡面又不突兀。
    _liftY = game._cellSize * 0.55;
    position.y -= _liftY;
    game._dragSrc = (col, row);
    game._setMergeHints((col, row));
    // 拿起反馈：清脆的 selectionClick（真正的 tap 会走到 _select 只补 tick 音）。
    game.feedback.select();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragDist += event.localDelta.length;
    position.add(event.localDelta);
    // 实时落点预览：与松手判定同一函数，所见即所得；
    // 同时标注落点合法性，红色环=松手会弹回。
    final drop = game.resolveDrop(position + size / 2, col, row);
    game.updateDropPreview(
      drop,
      valid: drop == null || game._canDropOn(col, row, drop.col, drop.row),
    );
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    priority = 0;
    _animScale = 1;
    if (_dragDist < 14) {
      // 距离很小：视为点击（选中）。回弹悬浮偏移后按原逻辑处理。
      position.y += _liftY;
      _liftY = 0;
      game._dragSrc = null;
      game.updateDropPreview(null);
      game._onTapStack(col, row);
      return;
    }
    // 以卡片中心（含悬浮偏移，即用户看到的卡面位置）换算目标格。
    final center = position + size / 2;
    final cell = game.resolveDrop(center, col, row);
    game._onDragEnd(col, row, cell?.col, cell?.row);
    _liftY = 0;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    priority = 0;
    _animScale = 1;
    _liftY = 0;
    game._dragSrc = null;
    game.updateDropPreview(null);
    game.snapBack(col, row);
  }

  double _lastSize = -1;
  RRect _rr = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  RRect _glossRR = RRect.fromRectAndRadius(Rect.zero, const Radius.circular(0));
  Paint? _gradient;
  Paint? _gloss;
  Paint? _badgeGradient;
  int _lastKind = -1; // 0=普通车 1=万能卡 2=炸弹，类型变化时重算卡面。
  int _lastTier = -2; // 车辆等级变化（升级合成）时重算卡面颜色。
  late final Paint _shadow = Paint()
    ..color = const Color(0x4D000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  // 车型色同色投影：让"每车一色卡"在奶油底上更醒目（特殊卡仍用中性 _shadow）。
  late final Paint _tierShadow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  late final Paint _selBorder = Paint()
    ..color = const Color(0xFFFFD54F)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;
  // 特殊卡（万能卡/炸弹）专属描边，运行时按类型着色。
  late final Paint _ring = Paint()..style = PaintingStyle.stroke;

  // ---- 静态部分烘焙：投影/渐变/高光/图标/能力徽章记录成 Picture ----
  ui.Picture? _face;
  int _faceKeySize = -1;
  int _faceKeyKind = -1;
  int _faceKeyTier = -1;

  /// 右下角 "x2" 徽章的缓存 Picture（按尺寸重建）。
  ui.Picture? _badgePic;
  int _badgePicSize = -1;

  // 动态叠加层复用 Paint，避免每帧分配。
  late final Paint _selGlow = Paint()
    ..color = const Color(0xFFFFD54F).withValues(alpha: 0.5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
  late final Paint _hintRing = Paint()
    ..color = const Color(0xFF66BB6A).withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4;
  late final Paint _pulseFill = Paint();

  void _ensureVisualCache() {
    final kind = data.isBomb ? 2 : (data.isWildcard ? 1 : 0);
    if (size.x == _lastSize &&
        kind == _lastKind &&
        data.tier.id == _lastTier) {
      return;
    }
    _lastSize = size.x;
    _lastKind = kind;
    _lastTier = data.tier.id;
    // 尺寸/类型/等级变了，静态 Picture 缓存全部作废，下次用到时重建。
    _face = null;
    _badgePic = null;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final r = size.x * 0.14;
    _rr = RRect.fromRectAndRadius(rect, Radius.circular(r));
    _glossRR = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y * 0.6),
      Radius.circular(r),
    );
    final isSpecial = data.isBomb || data.isWildcard;
    final isVehicle = !isSpecial;
    _gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isVehicle
            ? [
                Color.lerp(data.tier.color, const Color(0xFFFFFFFF), 0.66)!,
                Color.lerp(data.tier.color, const Color(0xFFFFFFFF), 0.82)!,
              ]
            // 特殊卡（万能卡/炸弹）用中性玻璃底，不再染车型色，
            // 避免被误认成普通车卡（它们的底层 tier 默认是 bike）。
            : const [
                Color(0xFF2A313C),
                Color(0xFF161B22),
              ],
      ).createShader(rect);
    if (isVehicle) {
      _border.color = data.tier.color.withValues(alpha: 0.6);
      _tierShadow.color = data.tier.color.withValues(alpha: 0.22);
    }
    // 特殊卡专属描边：万能卡彩虹环，炸弹橙色危险环。
    if (data.isWildcard) {
      _ring
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF5252),
            Color(0xFFFFCA28),
            Color(0xFF66BB6A),
            Color(0xFF42A5F5),
            Color(0xFFAB47BC),
            Color(0xFFFF5252),
          ],
        ).createShader(rect)
        ..strokeWidth = 3;
    } else if (data.isBomb) {
      _ring
        ..color = const Color(0xFFFF7043)
        ..shader = null
        ..strokeWidth = 3;
    }
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
        // 徽章跟随车型身份色（糖果版：不再是深灰药丸）。
        colors: [
          Color.lerp(data.tier.color, const Color(0xFFFFFFFF), 0.15)!,
          AppTheme.deepen(data.tier.color, 0.12),
        ],
      ).createShader(badgeRect.outerRect);
  }

  /// 把卡面静态部分（投影/渐变/高光/图标/能力徽章）烘焙成一张 Picture。
  /// 每帧渲染只需回放一次，不再逐帧排版文字、分配 Paint 或重复模糊填充。
  void _ensureFace() {
    final keySize = (size.x * 64).round();
    if (_face != null &&
        _faceKeySize == keySize &&
        _faceKeyKind == _lastKind &&
        _faceKeyTier == _lastTier) {
      return;
    }
    _faceKeySize = keySize;
    _faceKeyKind = _lastKind;
    _faceKeyTier = _lastTier;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final rr = _rr;
    // 柔和投影(单层)：普通车用同色投影强化身份色，特殊卡用中性投影。
    c.drawRRect(
      RRect.fromRectAndRadius(rr.outerRect.translate(0, 3.5), rr.tlRadius),
      (data.isBomb || data.isWildcard) ? _shadow : _tierShadow,
    );
    // 卡面渐变 + 顶部高光。
    c.drawRRect(rr, _gradient!);
    c.drawRRect(_glossRR, _gloss!);
    // 图标 + 能力徽章。
    _drawIcon(c);
    _drawAbilityBadge(c);
    _face = recorder.endRecording();
  }

  void _ensureBadgePic() {
    final keySize = (size.x * 64).round();
    if (_badgePic != null && _badgePicSize == keySize) return;
    _badgePicSize = keySize;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
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
    c.drawRRect(
      badgeRect,
      _badgeGradient!,
    );
    c.drawRRect(
      badgeRect,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _paintText(
      c,
      'x2',
      fontSize: size.x * 0.22,
      color: const Color(0xFFFFD54F),
      center: Offset(size.x * 0.74, size.y * 0.86),
    );
    _badgePic = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    _ensureVisualCache();
    _ensureFace();
    final rr = _rr;

    // 选中光晕（软金黄，垫底）：呼吸明暗，让"已选中"是活的而不是贴纸。
    if (selected) {
      _selGlow.color = const Color(0xFFFFD54F)
          .withValues(alpha: 0.38 + 0.17 * sin(_breathT * 4.2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rr.outerRect.inflate(5 + 1.5 * sin(_breathT * 4.2)),
          Radius.circular(rr.tlRadius.x + 3),
        ),
        _selGlow,
      );
    }

    // 可合并提示环：细绿环呼吸闪烁，与选中金环区分，提示"拖到这里能合"。
    if (mergeHint && !selected) {
      _hintRing.color = const Color(0xFF66BB6A)
          .withValues(alpha: 0.5 + 0.4 * (0.5 + 0.5 * sin(_breathT * 5)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rr.outerRect.inflate(3),
          Radius.circular(rr.tlRadius.x + 2),
        ),
        _hintRing,
      );
    }

    // 静态卡面（投影 / 渐变 / 高光 / 图标 / 能力徽章）一次回放。
    canvas.drawPicture(_face!);

    // 边框/选中描边（选中态完全覆盖省的边框高亮，与旧视觉一致）。
    if (selected) {
      canvas.drawRRect(rr, _selBorder);
    } else if (data.isBomb || data.isWildcard) {
      canvas.drawRRect(rr, _ring);
    } else {
      canvas.drawRRect(rr, _border);
    }

    // 合并闪光（覆盖在卡面上，含图标）。
    if (_pulsing) {
      _pulseFill.color = const Color(0xFFFFFFFF)
          .withValues(alpha: 0.45 * sin(pi * _pulseT));
      canvas.drawRRect(rr, _pulseFill);
    }

    if (data.count == 2) _drawBadge(canvas);

    // Boss 冰封覆盖：蓝白霜面 + 层数点，盖在卡面上（迷雾之前）。
    if (data.frozen > 0) _drawFrost(canvas, rr);

    // Boss 胶水覆盖：蜂蜜色膜 + 滴点（只有秒数没有层数）。
    if (data.glueT > 0) _drawGlue(canvas, rr);

    // Boss 禁合徽章：该档位被禁时，卡面右上角红 ✕（预警名单可视化）。
    if (game.banActive && !data.isWildcard && !data.isBomb &&
        data.tier == game.banTier) {
      _drawBanBadge(canvas);
    }

    // 迷雾覆盖：隐藏卡面。
    if (game.board.isFogged(col, row)) {
      paintFog(canvas, rr);
    }
  }

  /// 胶水视觉：半透蜂蜜膜 + 深色描边 + 底部滴点 + 中央 🍯 标。
  /// 与冰封的蓝霜面严格区分——一眼看出「这张要等」而不是「要合两次救」。
  void _drawGlue(Canvas canvas, RRect rr) {
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFFFC107).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 蠕动的滴点：底部三个小圆，位置随时间轻晃——"黏稠感"。
    final dotR = size.x * 0.04;
    final wobble = sin(_breathT * 6) * dotR * 0.5;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(-dotR * 3 + dotR * 3 * i + wobble, size.y * 0.4),
        dotR,
        Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.95),
      );
    }
    final tp = TextPainter(
      text: const TextSpan(
        text: '🍯',
        style: TextStyle(fontSize: 18, color: Color(0xE6FFFFFF)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(-tp.width / 2 + size.x * 0.28, -tp.height / 2 - size.y * 0.28),
    );
  }

  /// 禁合徽章：右上角红色禁行圆牌（该档位几秒内不能合并）。
  void _drawBanBadge(Canvas canvas) {
    final r = size.x * 0.16;
    final c = Offset(size.x * 0.34, -size.y * 0.34);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xD5E53935));
    final bar = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.round;
    final d = r * 0.5;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), bar);
    canvas.drawLine(c + Offset(-d, d), c + Offset(d, -d), bar);
  }

  /// 冰封视觉：半透蓝白霜面 + 霜边 + 层数点（还剩几层没化）。
  /// 让"这张车动不了"一眼可辨，且层数递减时玩家看得见进度。
  void _drawFrost(Canvas canvas, RRect rr) {
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFE1F5FE).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 层数点：底部一排小圆点，化掉一层少一个。
    final dotR = size.x * 0.035;
    final gap = dotR * 3;
    final totalW = gap * (data.frozen - 1);
    for (var i = 0; i < data.frozen; i++) {
      canvas.drawCircle(
        Offset(-totalW / 2 + gap * i, size.y * 0.38),
        dotR,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95),
      );
    }
    // 中央 ❄ 标，冰封身份 unmistakable。
    final tp = TextPainter(
      text: const TextSpan(
        text: '❄',
        style: TextStyle(fontSize: 20, color: Color(0xE6FFFFFF)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(-tp.width / 2 + size.x * 0.28, -tp.height / 2 - size.y * 0.28),
    );
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
      // 统一用 emoji 显示车辆
      final tp = TextPainter(
        text: TextSpan(
          text: data.tier.icon,
          style: TextStyle(fontSize: box),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }
    canvas.restore();
  }

  void _drawBadge(Canvas canvas) {
    _ensureBadgePic();
    canvas.drawPicture(_badgePic!);
  }

  /// 右上角能力标识小徽章（非 none 时绘制半透明深底药丸 + 能力文字）。
  void _drawAbilityBadge(Canvas canvas) {
    final ability = data.tier.stats.ability;
    if (ability == SpecialAbility.none) return;
    final label = ability.label;
    final fontSize = size.x * 0.15;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFFFFFFFF),
          fontFamily: 'Noto Sans SC',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final padX = fontSize * 0.35;
    final padY = fontSize * 0.18;
    final pillW = tp.width + padX * 2;
    final pillH = tp.height + padY * 2;
    final pillCx = size.x - pillW / 2 - 3;
    final pillCy = pillH / 2 + 3;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pillCx, pillCy),
        width: pillW,
        height: pillH,
      ),
      Radius.circular(pillH / 2),
    );
    canvas.drawRRect(
      pillRect,
      Paint()..color = const Color(0xAA1A1E24),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    tp.paint(
      canvas,
      Offset(pillCx - tp.width / 2, pillCy - tp.height / 2),
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
  final Paint _paint = Paint();

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
    for (final d in _dots) {
      _paint.color = d.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(d.position.x, d.position.y), d.size, _paint);
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

/// 环境背景:全局 GlowBackground 已经负责氛围渐变，Flame 层保持透明，
/// 让 Flutter 侧的奶油→粉雾→天空背景透出来（旧的深空黑底已随糖果化移除）。
class AmbientBackground extends PositionComponent with HasGameReference<MergeGame> {
  @override
  void render(Canvas canvas) {
    // no-op：透明背景（保留组件以兼容挂载点）。
  }
}

/// 棋盘底板:包裹整个格子的圆角面板。
class BoardBackdrop extends PositionComponent {
  BoardBackdrop({required super.size});

  double _lastW = -1;
  double _lastH = -1;
  Paint? _panel;
  late final Paint _shadow = Paint()
    ..color = const Color(0x24323256)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  late final Paint _border = Paint()
    ..color = const Color(0x40B79BFF)
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
          // 棋盘托板：白色 → 极淡紫，和 GlowBackground 融为一体。
          colors: const [Color(0xFFFDFBF7), Color(0xFFF6EFF8)],
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
  final Paint _paint = Paint();

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
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 + (1 - k) * 7
      ..color = color.withValues(alpha: (1 - k) * 0.85);
    canvas.drawCircle(
        Offset.zero, maxRadius * Curves.easeOut.transform(k), _paint);
  }
}

/// 通关/目标升级时从天而降的彩带。
class Confetti extends PositionComponent {
  final double _life = 1.5;
  double _t = 0;
  late final List<_ConfettiPiece> _pieces;
  final Paint _paint = Paint();

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
    for (final p in _pieces) {
      _paint.color = p.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(p.position.x, p.position.y);
      canvas.rotate(p.rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.7, height: p.size),
          const Radius.circular(2),
        ),
        _paint,
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

/// Boss 行为状态。
enum BossState { intro, idle, stalk, windup, strike, recover, hurt, dead }

/// Boss 实体：一辆悬浮在棋盘上方、**会自己动**的捣乱车。
///
/// 行为循环（每一步都有预警，没有暗箱）：
/// - `intro`  出生弹出（0.6s），期间不攻击
/// - `idle`   上下浮动待机，血条可见，倒计时下一次攻击
/// - `stalk`  盯上目标，飞过去
/// - `windup` 举牌预警：目标红圈收缩闪烁 + Boss 原地抖
/// - `strike` 出手
/// - `recover` 飞回悬浮位
/// - `hurt`   被玩家的目标车命中：闪白 + 击退，**正在进行的攻击被打断**
/// - `dead`   血条打空：旋转缩小消失
///
/// 技能执行走**卡组制**（见 [BossSpec]）：每个 Boss 带 1 主 + 1 辅技能，
/// [_chooseAttack] 轮换调度，不再从大池随机抽——同章 4 个 Boss 各打各的
/// 卡组。护盾是被动光环（spec.shieldCycle），不进攻击轮盘。
///
/// 技能池两批（按章节解锁线逐步开放）：
/// - 第一批：冰封最高档原料车（主菜）/ 拖车 / 锁牌堆 / 冰块（填充技）
/// - 第二批：胶水（定时粘住）/ 黑洞（占格陷阱，可喂卡清位）/ 洗牌
///   （重排布局）/ 禁合（某等级禁合几秒）/ 迷雾（盖车看不见）/
///   抢目标（抓回已达成的目标车补 1 血——唯一碰胜利资源的技能，
///   所以只在章 9+ 出现且满血时不可用，天然防连放）
///
/// 反派要有压迫感，但不能无耻：不碰万能卡/炸弹、不冻目标车、
/// 每次攻击都有预警、残血狂怒也有视觉前置（整车变红）。
class BossSprite extends PositionComponent {
  BossSprite({
    required this.game,
    required this.tier,
    required this.spec,
  })  : hp = spec.hp,
        maxHp = spec.hp;

  final MergeGame game;
  final VehicleType tier;
  final BossSpec spec;
  int hp;
  /// 血条上限。抢目标技能会让 Boss 回血超出初始 HP，上限跟着涨
  /// （否则血条比例失真）——写成非 final 就是这个原因。
  int maxHp;

  /// 残血狂怒标志（攻击提速 + 冰封数 +1 + 变红）。
  bool enraged = false;

  BossState state = BossState.intro;
  double stateT = 0;
  bool get dead => state == BossState.dead;

  double _t = 0;
  double _attackTimer = 0;
  double _hurtFlash = 0;
  double _introT = 0;
  double _deadT = 0;
  bool _struck = false;
  BossAttackKind _kind = BossAttackKind.freeze;
  BossAttackKind? _lastKind;

  /// 禁合技能选中的档位（预警环点亮名单 + 出手时交给 MergeGame）。
  VehicleType? _banTier;

  /// 本次攻击的全部目标格（冰封深水区可同时冻 2 张）。
  /// 位置/预警/出手都遍历它；单目标攻击就只有一格。
  final List<({int col, int row})> _targets = [];

  ({int col, int row})? get _target =>
      _targets.isNotEmpty ? _targets.first : null;

  final Vector2 _knock = Vector2.zero();
  final Random _rnd = Random();

  Vector2 _home = Vector2.zero();
  // 测试专用：布局测试断言 home 必须落在棋盘带中心。
  Vector2 get homeForTest => _home;
  double _cell = 64;
  double _bossSize = 108;
  bool _laidOut = false;

  static const double _introDur = 0.6;
  static const double _stalkDur = 0.65;
  static const double _windupDur = 0.95;
  static const double _strikeDur = 0.34;
  static const double _recoverDur = 0.5;
  static const double _hurtDur = 0.42;
  static const double _deadDur = 0.8;

  /// 当前攻击间隔（狂怒时提速 40%）。
  double get _interval => enraged ? spec.attackInterval * 0.6 : spec.attackInterval;

  /// 当前冰封张数（狂怒 +1）。
  int get _freezeCount => enraged ? spec.freezeCount + 1 : spec.freezeCount;

  /// 残血狂怒（章 11+ 由 MergeGame._damageBoss 触发）。
  void enrage() {
    if (enraged) return;
    enraged = true;
    _attackTimer = min(_attackTimer, 1.2); // 很快就有下一击
  }

  /// 重新布局：Boss 悬浮在棋盘正上方中央，尺寸 = 1.7 格。
  void layout(Vector2 boardOrigin, double cellSize) {
    _cell = cellSize;
    _bossSize = cellSize * 1.7;
    size = Vector2.all(_bossSize);
    final boardW = game.level.cols * (cellSize + game._gap) - game._gap;
    _home = Vector2(
      boardOrigin.x + boardW / 2,
      max(boardOrigin.y - cellSize * 0.95, _bossSize / 2 + 4),
    );
    if (!_laidOut) {
      position = _home.clone();
      _laidOut = true;
    } else if (state == BossState.idle || state == BossState.intro) {
      position = _home.clone();
    }
  }

  void _setState(BossState s) {
    state = s;
    stateT = 0;
  }

  Vector2 _lerp(Vector2 a, Vector2 b, double t) => a + (b - a) * t;

  Vector2 _hoverPos() {
    final t = _target;
    if (t == null) return _home;
    return game._cellCenter(t.col, t.row) - Vector2(0, _cell * 0.95);
  }

  Vector2 _targetCell() {
    final t = _target;
    if (t == null) return _home;
    return game._cellCenter(t.col, t.row);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _hurtFlash = max(0, _hurtFlash - dt / _hurtDur);
    final decay = max(0, 1 - 6 * dt);
    _knock.x *= decay;
    _knock.y *= decay;

    if (state == BossState.dead) {
      _deadT += dt;
      if (_deadT >= _deadDur) removeFromParent();
      return;
    }
    // 对局已结束（非死亡演出）：冻结，不再攻击。
    if (game._ended) return;

    stateT += dt;
    switch (state) {
      case BossState.intro:
        _introT = (stateT / _introDur).clamp(0.0, 1.0);
        position = _home.clone();
        if (stateT >= _introDur) {
          _setState(BossState.idle);
          _attackTimer = spec.firstDelay;
        }
      case BossState.idle:
        _attackTimer -= dt;
        position = _home + Vector2(0, sin(_t * 2.2) * _cell * 0.07);
        if (_attackTimer <= 0) _chooseAttack();
      case BossState.stalk:
        final k = (stateT / _stalkDur).clamp(0.0, 1.0);
        position = _lerp(_home, _hoverPos(), Curves.easeInOut.transform(k));
        if (stateT >= _stalkDur) _setState(BossState.windup);
      case BossState.windup:
        position =
            _hoverPos() + Vector2(sin(stateT * 46) * _cell * 0.035, 0);
        if (stateT >= _windupDur) {
          _struck = false;
          _setState(BossState.strike);
        }
      case BossState.strike:
        final half = _strikeDur * 0.55;
        if (stateT < half) {
          final k = (stateT / half).clamp(0.0, 1.0);
          position = _lerp(_hoverPos(), _targetCell(), Curves.easeIn.transform(k));
        } else {
          if (!_struck) {
            _struck = true;
            _performAttack();
          }
          final k = ((stateT - half) / (_strikeDur - half)).clamp(0.0, 1.0);
          position =
              _lerp(_targetCell(), _hoverPos(), Curves.easeOut.transform(k));
        }
        if (stateT >= _strikeDur) _setState(BossState.recover);
      case BossState.recover:
        final k = (stateT / _recoverDur).clamp(0.0, 1.0);
        position = _lerp(position, _home, Curves.easeOut.transform(k));
        if (stateT >= _recoverDur) {
          _setState(BossState.idle);
          _attackTimer = _interval;
        }
      case BossState.hurt:
        position =
            _home + Vector2(0, sin(_t * 2.2) * _cell * 0.07) + _knock;
        if (stateT >= _hurtDur) {
          _setState(BossState.idle);
          _attackTimer = _interval;
        }
      case BossState.dead:
        break;
    }
  }

  /// 挑选下一次攻击：按本 Boss 的卡组（主 + 辅）调度。
  ///
  /// 卡组可用性判断：
  /// - freeze/devolve/glue：有未冻的非目标原料车（打合成链顶端）
  /// - steal/impound：同上（只打扰活跃资产——拖走冻车等于帮玩家解冻）
  /// - lock：spec 会锁且当前没锁着
  /// - taint：牌堆还有牌
  /// - ban：有车可禁（选场上最多的非目标档位）
  /// - fog：场上有车可盖
  /// - hole：有空格可开
  /// - shuffle：至少 2 张没冻/粘的车（重排它们）
  /// - stealGoal：Boss 已受伤（满血没东西可抢）；非 Boss 关要有目标车
  /// - rubble/ice：有空空格
  ///
  /// 三条调度规则：① 主辅轮换，不连续重复同一招（保持节奏可预期）；
  /// ② 卡组全不可用（全场只剩目标车/冻车）→ 有空格就扔块冰，不浪费
  /// 这一轮预警；③ 全场无货时歇 2 秒再看，不至于空转。
  void _chooseAttack() {
    final empties = <({int col, int row})>[];
    final cars = <({int col, int row, int tierId, bool isTarget})>[];
    for (var c = 0; c < game.level.cols; c++) {
      for (var r = 0; r < game.level.rows; r++) {
        final d = game.board.at(c, r);
        if (d == null || d.isEmpty) {
          if (game.board.obstacleAt(c, r) == null &&
              !game.board.holeAt(c, r)) {
            empties.add((col: c, row: r));
          }
          continue;
        }
        if (d.isWildcard || d.isBomb) continue;
        cars.add((
          col: c,
          row: r,
          tierId: d.tier.index,
          isTarget: d.tier == game.level.targetTier,
        ));
      }
    }
    if (empties.isEmpty && cars.isEmpty) {
      _attackTimer = 2; // 棋盘空空：歇一会再看
      return;
    }

    // 候选原料车：未冻、非目标，按档位降序（最高档在前）。
    final freeCars =
        cars.where((c) => !c.isTarget && !_isLocked(c.col, c.row)).toList()
          ..sort((a, b) => b.tierId.compareTo(a.tierId));

    // 禁合选档：场上数量最多的非目标档位（最能打乱玩家当前计划）。
    // 选点即预警——_targets 点亮该档全部车，玩家一眼看懂要被禁什么。
    VehicleType? banTier;
    if (freeCars.isNotEmpty) {
      final byTier = <VehicleType, int>{};
      for (final c in freeCars) {
        final t = VehicleType.values[c.tierId];
        byTier[t] = (byTier[t] ?? 0) + 1;
      }
      var best = -1;
      for (final e in byTier.entries) {
        if (e.value > best || (e.value == best && _rnd.nextBool())) {
          best = e.value;
          banTier = e.key;
        }
      }
    }

    // 迷雾选点：优先盖住高档位原料车（信息价值最大），数量 = spec.fogCells。
    final fogTargets = cars
        .where((c) => !_isLocked(c.col, c.row))
        .toList()
      ..sort((a, b) => b.tierId.compareTo(a.tierId));
    final fogPicks = fogTargets.take(spec.fogCells).toList();

    bool usable(BossAttackKind k) => switch (k) {
          BossAttackKind.freeze ||
          BossAttackKind.devolve ||
          BossAttackKind.steal ||
          BossAttackKind.impound ||
          BossAttackKind.glue =>
            freeCars.isNotEmpty,
          BossAttackKind.lock =>
            spec.lockStockSeconds > 0 && !game.stockLocked.value,
          BossAttackKind.taint =>
            (game.level.endless ? game._upcoming : game._deck).isNotEmpty,
          BossAttackKind.ban => banTier != null,
          BossAttackKind.fog => fogPicks.isNotEmpty,
          BossAttackKind.hole => empties.isNotEmpty,
          BossAttackKind.shuffle => freeCars.length >= 2,
          // 满血的 Boss 没被抢过东西，无可抢——天然防连放。
          BossAttackKind.stealGoal => game.bossHp.value < game.bossMaxHp.value,
          BossAttackKind.rubble || BossAttackKind.ice => empties.isNotEmpty,
          BossAttackKind.shield => false, // 被动光环，不进攻击轮盘
        };

    final deck = <BossAttackKind>[
      if (usable(spec.primary)) spec.primary,
      if (spec.secondary != null && usable(spec.secondary!)) spec.secondary!,
    ];
    _targets.clear();
    _banTier = null;

    if (deck.isEmpty) {
      // 卡组全不可用：填充技扔块冰占格，不断压迫感；没空格就歇。
      if (empties.isNotEmpty) {
        empties.shuffle(_rnd);
        _targets.add(empties.first);
        _kind = BossAttackKind.ice;
        _setState(BossState.stalk);
      } else {
        _attackTimer = 2;
      }
      return;
    }

    // 优先选与上一招不同的（保持节奏可预期）；只剩一招时除外。
    final pick = deck.length == 1 || deck.first != _lastKind
        ? deck.first
        : deck.last;
    _lastKind = pick;
    _kind = pick;

    switch (pick) {
      case BossAttackKind.freeze:
        // 冰封最高档的 N 张原料车（深水区/狂怒 N=2，双倍掐链）。
        for (final t in freeCars.take(_freezeCount)) {
          _targets.add((col: t.col, row: t.row));
        }
      case BossAttackKind.devolve:
        // 退化最高档的一张：出手瞬间校验，被挪走就改打次高档。
        _targets.add((col: freeCars.first.col, row: freeCars.first.row));
      case BossAttackKind.glue:
        // 胶水粘住最高档的一张（定时干扰，反制 = 等）。
        _targets.add((col: freeCars.first.col, row: freeCars.first.row));
      case BossAttackKind.steal:
        // 章 3+ 抢最高档（掠夺资产）；之前拖最低档（轻骚扰）。
        final victim = spec.stealTopTier
            ? freeCars.first
            : (freeCars.toList()
              ..sort((a, b) => a.tierId.compareTo(b.tierId))).first;
        _targets.add((col: victim.col, row: victim.row));
      case BossAttackKind.impound:
        // 扣押最高档一张（拖进车库，到点放回）。
        _targets.add((col: freeCars.first.col, row: freeCars.first.row));
      case BossAttackKind.ban:
        // 禁合：点亮该档全部车（预警即名单）。
        _banTier = banTier;
        for (final t in freeCars.where((c) =>
            VehicleType.values[c.tierId] == banTier).take(4)) {
          _targets.add((col: t.col, row: t.row));
        }
      case BossAttackKind.fog:
        for (final t in fogPicks) {
          _targets.add((col: t.col, row: t.row));
        }
      case BossAttackKind.hole:
        // 黑洞开在随机空格（占格陷阱；玩家可以绕，也可以喂卡）。
        empties.shuffle(_rnd);
        _targets.add(empties.first);
      case BossAttackKind.rubble:
        // 塌方：N 块碎石落随机空格（章 8+ 两块）。
        empties.shuffle(_rnd);
        for (final t in empties.take(spec.rubbleCount)) {
          _targets.add(t);
        }
      case BossAttackKind.ice:
        empties.shuffle(_rnd);
        _targets.add(empties.first);
      case BossAttackKind.stealGoal:
        // 抢目标：Boss 关没有棋盘目标（补血本身即惩罚，金色预警走
        // Boss 光环）；理论上非 Boss 关才点目标车，生成器不会产出。
        break;
      case BossAttackKind.lock:
      case BossAttackKind.taint:
      case BossAttackKind.shuffle:
      case BossAttackKind.shield:
        break; // 无棋盘目标：靠 Boss 自身光环 + hint 说破
    }
    _setState(BossState.stalk);
  }

  /// 冰封或胶水（任何「动不了」的状态）——选目标/出手校验用它，
  /// 避免堵了一种又漏一种（冻结死局 bug 的教训）。
  bool _isLocked(int col, int row) {
    final d = game.board.at(col, row);
    return d != null && d.locked;
  }

  /// 出手瞬间执行攻击（目标可能已被玩家操作改变，先校验）。
  void _performAttack() {
    switch (_kind) {
      case BossAttackKind.freeze:
        // 冰封最高档的 N 张（深水区/狂怒 N=2）。_bossFreezeCar 内部
        // 现扫场选取，与预警环选点的规则一致；玩家在 0.95s 预警期内
        // 挪走了最高档车时会改冻次高档——目标校验以出手瞬间为准。
        final froze = game._bossFreezeCar(
            count: _targets.length, layers: spec.freezeLayers);
        if (froze == 0) {
          // 目标失效（全场只剩目标车/玩家挪空了）：退化成扔块冰，
          // 不浪费这一轮预警。
          final t = _targets.first;
          if (game.board.at(t.col, t.row) == null &&
              game.board.obstacleAt(t.col, t.row) == null) {
            game._bossDropIce(t.col, t.row);
          }
        }
      case BossAttackKind.steal:
        for (final t in _targets) {
          final d = game.board.at(t.col, t.row);
          if (d == null || d.isEmpty) continue;
          game._bossStealCar(t.col, t.row);
        }
      case BossAttackKind.impound:
        for (final t in _targets) {
          final d = game.board.at(t.col, t.row);
          if (d == null || d.isEmpty || d.frozen > 0) continue;
          game._bossImpoundCar(t.col, t.row);
        }
      case BossAttackKind.devolve:
        // 目标被挪走/合掉/冻住 → 改打当前最高档；全场没货 → 退化成冰封。
        final t = _targets.isNotEmpty ? _targets.first : null;
        final d = t == null ? null : game.board.at(t.col, t.row);
        final ok = d != null &&
            !d.isEmpty &&
            d.frozen == 0 &&
            d.tier != game.level.targetTier;
        if (ok) {
          game._bossDevolveCar(t!.col, t.row, levels: spec.devolveLevels);
        } else if (game._bossFreezeCar(count: 1, layers: spec.freezeLayers) ==
            0) {
          final e = t;
          if (e != null &&
              game.board.at(e.col, e.row) == null &&
              game.board.obstacleAt(e.col, e.row) == null) {
            game._bossDropIce(e.col, e.row);
          }
        }
      case BossAttackKind.rubble:
        var dropped = 0;
        for (final t in _targets) {
          if (game.board.at(t.col, t.row) != null ||
              game.board.obstacleAt(t.col, t.row) != null) {
            continue;
          }
          game._bossDropStone(t.col, t.row);
          dropped++;
        }
        if (dropped > 0) {
          game.hint.value = dropped > 1
              ? '🪨 Boss 掀起塌方，$dropped 块碎石堵住了格子！'
              : '🪨 Boss 抡下一块碎石，占了一个格子！';
        } else {
          game.hint.value = '🪨 Boss 抡起碎石，但你都提前挪开了！';
        }
      case BossAttackKind.taint:
        game._bossTaint();
      case BossAttackKind.glue:
        // 胶水：定时粘住。目标被挪走/合掉 → 改粘当前最高档；
        // 全场没货 → 不浪费预警，扔块冰。
        final gt = _targets.isNotEmpty ? _targets.first : null;
        final gd = gt == null ? null : game.board.at(gt.col, gt.row);
        if (gd != null && !gd.isEmpty && !gd.locked) {
          game._bossGlueCar(gt!.col, gt.row, seconds: spec.glueSeconds);
        } else {
          game._bossGlueHighest(seconds: spec.glueSeconds);
        }
      case BossAttackKind.hole:
        final ht = _targets.isNotEmpty ? _targets.first : null;
        if (ht != null &&
            game.board.at(ht.col, ht.row) == null &&
            game.board.obstacleAt(ht.col, ht.row) == null &&
            !game.board.holeAt(ht.col, ht.row)) {
          game._bossAddHole(ht.col, ht.row, seconds: spec.holeSeconds);
        }
      case BossAttackKind.shuffle:
        game._bossShuffle();
      case BossAttackKind.ban:
        // 出手瞬间重选档位：玩家可能在预警期内把该档合没了。
        game._bossBanMerge(_banTier ?? game._mostCommonFreeTier(),
            seconds: spec.banSeconds);
      case BossAttackKind.fog:
        final fogNow = _targets
            .where((t) => game.board.at(t.col, t.row) != null)
            .toList();
        if (fogNow.isNotEmpty) {
          game._bossFog(fogNow);
        } else {
          game.hint.value = '🌫 Boss 放出迷雾，但你已经把车都挪开了！';
        }
      case BossAttackKind.stealGoal:
        game._bossStealGoal();
      case BossAttackKind.lock:
        game._bossLockStock(spec.lockStockSeconds);
      case BossAttackKind.ice:
        final t = _targets.first;
        if (game.board.at(t.col, t.row) != null ||
            game.board.obstacleAt(t.col, t.row) != null) {
          return;
        }
        game._bossDropIce(t.col, t.row);
      case BossAttackKind.shield:
        break; // 被动光环，永不出现在攻击分支
    }
  }

  /// 被玩家命中：扣 1 HP、闪白、击退；进行中的攻击被打断。
  /// [blocked] = 护盾挡下：只播受击反馈，不扣血、不判死。
  void hit({bool blocked = false}) {
    if (dead) return;
    _hurtFlash = 1;
    _knock.setValues(
      (_rnd.nextDouble() - 0.5) * _cell * 0.3,
      -_cell * 0.35,
    );
    _targets.clear(); // 打断进行中的攻击
    if (blocked) {
      if (state != BossState.hurt) _setState(BossState.hurt);
      return;
    }
    hp -= 1;
    if (hp <= 0) {
      _setState(BossState.dead);
      _deadT = 0;
    } else {
      _setState(BossState.hurt);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  渲染
  // ─────────────────────────────────────────────────────────────

  final Paint _auraPaint = Paint();
  final Paint _hpFill = Paint();
  ui.Picture? _face;
  int _faceKey = -1;
  int _faceTier = -2;
  bool _auraReady = false;
  int _hpKey = -1;

  @override
  void render(Canvas canvas) {
    if (!_laidOut) return;
    final s = _bossSize;

    // 预警环：遍历本次攻击的全部目标格（世界坐标，先于 translate）。
    // 冰封深水区会同时冻 2 张，两个格子都要画环——每个都有预警。
    if (_targets.isNotEmpty &&
        (state == BossState.stalk ||
            state == BossState.windup ||
            state == BossState.strike)) {
      for (final t in _targets) {
        final cellCenter = game._cellCenter(t.col, t.row);
        _drawWarning(
          canvas,
          Offset(cellCenter.x - position.x, cellCenter.y - position.y),
          kind: _kind,
        );
      }
    }

    // 注意：Flame 的 Transform2DDecorator 已在 render 前把画布平移到
    // position（anchor=topLeft），这里只能再叠击退偏移，绝不能重复平移
    // position——否则 Boss 会被画到 2×position（竖屏直接飞出右缘）。
    canvas.save();
    canvas.translate(_knock.x, _knock.y);
    if (state == BossState.dead) {
      final k = (_deadT / _deadDur).clamp(0.0, 1.0);
      canvas.rotate(k * 2.4);
      canvas.scale(max(0.05, 1 - k * 0.85));
    }
    if (state == BossState.intro) {
      canvas.scale(max(0.01, Curves.easeOutBack.transform(_introT)));
    }

    _drawAura(canvas, s);
    _ensureFace();
    canvas.drawPicture(_face!);
    _drawHpBar(canvas, s);

    if (_hurtFlash > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-s / 2, -s / 2, s, s),
          Radius.circular(s * 0.16),
        ),
        Paint()
          ..color =
              const Color(0xFFFFFFFF).withValues(alpha: 0.55 * _hurtFlash),
      );
    }
    canvas.restore();
  }

  /// 红色威压光晕：待机缓慢呼吸，锁定目标时急促闪烁，狂怒时常亮急闪。
  void _drawAura(Canvas canvas, double s) {
    if (!_auraReady) {
      _auraReady = true;
      _auraPaint.shader = RadialGradient(
        colors: [
          const Color(0xFFFF1744).withValues(alpha: 0.95),
          const Color(0xFFFF1744).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: s / 2));
    }
    final charging = state == BossState.stalk || state == BossState.windup;
    final speed = enraged ? 14 : (charging ? 9 : 3);
    final pulse = 0.5 + 0.5 * sin(_t * speed);
    _auraPaint.color = const Color(0xFFFF1744).withValues(
      alpha: enraged
          ? 0.40 + 0.25 * pulse
          : charging
              ? 0.30 + 0.25 * pulse
              : 0.15 + 0.08 * pulse,
    );
    canvas.drawCircle(
        Offset.zero, s * (enraged ? 0.86 : (charging ? 0.80 : 0.70)), _auraPaint);
  }

  /// 目标格预警环：外圈 + 收缩内圈 + 十字准星。
  /// 颜色按技能类型区分——冰封冰蓝、退化深紫、扣押紫红、拖车紫、
  /// 塌方石灰、锁牌堆琥珀、污染毒绿、冰块亮蓝、胶水蜂蜜、黑洞暗紫、
  /// 禁合警告红、抢目标金、迷雾灰，
  /// 玩家看一眼环的颜色就知道 Boss 要干什么。
  void _drawWarning(Canvas canvas, Offset center,
      {BossAttackKind kind = BossAttackKind.ice}) {
    final ring = switch (kind) {
      BossAttackKind.freeze => const Color(0xFF40C4FF),
      BossAttackKind.devolve => const Color(0xFF7E57C2),
      BossAttackKind.impound => const Color(0xFFEC407A),
      BossAttackKind.steal => const Color(0xFFAB47BC),
      BossAttackKind.rubble => const Color(0xFF8D6E63),
      BossAttackKind.lock => const Color(0xFFFFB300),
      BossAttackKind.taint => const Color(0xFF8BC34A),
      BossAttackKind.ice => const Color(0xFF81D4FA),
      BossAttackKind.glue => const Color(0xFFFFB300),
      BossAttackKind.hole => const Color(0xFF7B1FA2),
      BossAttackKind.ban => const Color(0xFFE53935),
      BossAttackKind.stealGoal => const Color(0xFFFFD700),
      BossAttackKind.fog => const Color(0xFF90A4AE),
      BossAttackKind.shuffle => const Color(0xFF00BCD4),
      BossAttackKind.shield => const Color(0xFFFFD54F),
    };
    final r = _cell * 0.44;
    final pulse = 0.5 + 0.5 * sin(_t * 12);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = ring.withValues(alpha: 0.25 + 0.3 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // 内圈随预警进程收缩：像瞄准落点，出手瞬间合拢。
    final k = state == BossState.strike
        ? 1.0
        : state == BossState.windup
            ? 0.55 + 0.45 * (stateT / _windupDur)
            : 0.25;
    canvas.drawCircle(
      center,
      r * (1 - 0.55 * k),
      Paint()
        ..color = ring.withValues(alpha: 0.5 + 0.4 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final cross = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final d = r * 0.5;
    canvas.drawLine(center + Offset(-d, 0), center + Offset(d, 0), cross);
    canvas.drawLine(center + Offset(0, -d), center + Offset(0, d), cross);
  }

  /// 血条：分段显示（≤8 段画分格线），已失去的血量留暗红残影。
  void _drawHpBar(Canvas canvas, double s) {
    final barW = s * 0.88;
    final barH = s * 0.13;
    final cy = -s / 2 - barH - s * 0.06 + barH / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, cy), width: barW, height: barH),
      Radius.circular(barH / 2),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xCC1A0A10));
    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    if (ratio > 0) {
      final key = (barW * 16).round();
      if (_hpKey != key) {
        _hpKey = key;
        _hpFill.shader = LinearGradient(
          colors: const [Color(0xFFFF8A65), Color(0xFFE53935)],
        ).createShader(Rect.fromLTWH(0, 0, barW - 4, barH - 4));
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.outerRect.left + 2, rect.outerRect.top + 2,
              (barW - 4) * ratio, barH - 4),
          Radius.circular((barH - 4) / 2),
        ),
        _hpFill,
      );
      if (maxHp > 1 && maxHp <= 8) {
        final seg = Paint()
          ..color = const Color(0x66000000)
          ..strokeWidth = 1.2;
        for (var i = 1; i < maxHp; i++) {
          final x = rect.outerRect.left + 2 + (barW - 4) * (i / maxHp);
          canvas.drawLine(
            Offset(x, rect.outerRect.top + 2),
            Offset(x, rect.outerRect.bottom - 2),
            seg,
          );
        }
      }
    }
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFFFF8A80).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    _paintBossText(canvas, '$hp / $maxHp',
        fontSize: s * 0.085,
        color: const Color(0xFFFFFFFF),
        center: Offset(0, cy));
  }

  /// 车身静态部分烘焙：暗色渐变 + 王冠 + 怒眉 + 车型 emoji。
  /// 狂怒时整套烘焙换成亮红（缓存 key 带 enraged 位，切换即重建）。
  void _ensureFace() {
    final key = (size.x * 32).round() * (enraged ? -1 : 1);
    if (_face != null && _faceKey == key && _faceTier == tier.id) return;
    _faceKey = key;
    _faceTier = tier.id;
    final s = size.x;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(-s / 2, -s / 2, s, s),
      Radius.circular(s * 0.16),
    );
    // 同色系暗投影
    c.drawRRect(
      RRect.fromRectAndRadius(rr.outerRect.translate(0, s * 0.06), rr.tlRadius),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
    );
    // 反派车身：深红 → 炭黑；狂怒时换成亮红（一眼看出"它急了"）。
    c.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: enraged
              ? const [Color(0xFFE53935), Color(0xFF7F0000)]
              : const [Color(0xFF6B1420), Color(0xFF1E1218)],
        ).createShader(rr.outerRect),
    );
    // 顶部高光
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-s / 2, -s / 2, s, s * 0.5),
        Radius.circular(s * 0.16),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(-s / 2, -s / 2, s, s * 0.5)),
    );
    c.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035,
    );
    _paintBossText(c, '👑',
        fontSize: s * 0.24,
        color: const Color(0xFFFFD54F),
        center: Offset(0, -s * 0.34));
    // 怒眉：两条内倾的粗线，把 emoji 衬出凶相
    final brow = Paint()
      ..color = const Color(0xFF0B0204)
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;
    final ey = -s * 0.16;
    c.drawLine(
        Offset(-s * 0.26, ey - s * 0.05), Offset(-s * 0.08, ey + s * 0.03), brow);
    c.drawLine(
        Offset(s * 0.26, ey - s * 0.05), Offset(s * 0.08, ey + s * 0.03), brow);
    final tp = TextPainter(
      text: TextSpan(
        text: tier.icon,
        style: TextStyle(fontSize: s * 0.42),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2 + s * 0.14));
    _face = recorder.endRecording();
  }

  void _paintBossText(
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
          fontWeight: FontWeight.w900,
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

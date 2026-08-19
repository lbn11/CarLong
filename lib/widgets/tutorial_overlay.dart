import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 教程步骤动作类型
enum TutorialAction {
  draw, // 点击牌堆出牌
  move, // 拖拽/移动卡片
  merge, // 合成卡片
  hammer, // 使用锤子
  reveal, // 揭开迷雾
  custom, // 自定义(只显示文字)
}

/// 教程高亮区域
enum TutorialHighlight {
  none,
  stockPile, // 牌堆
  board, // 棋盘
  hammerTool, // 锤子工具
  undoTool, // 撤销工具
  addCardsTool, // 加牌工具
  coinsDisplay, // 金币显示
  homeLevels, // 首页-关卡入口
  homeParking, // 首页-停车入口
  homeShop, // 首页-成就/商店行
}

/// 教程步骤定义
class TutorialStep {
  final String text;
  final TutorialAction action;
  final TutorialHighlight highlight;
  final bool blocking; // 是否阻塞等待玩家操作

  const TutorialStep({
    required this.text,
    this.action = TutorialAction.custom,
    this.highlight = TutorialHighlight.none,
    this.blocking = true,
  });
}

/// 教程脚本(按关卡)
class TutorialScript {
  static const Map<int, List<TutorialStep>> scripts = {
    1: [
      TutorialStep(
        text: '👆 点击牌堆的车辆，让它开进棋盘',
        action: TutorialAction.draw,
        highlight: TutorialHighlight.stockPile,
      ),
      TutorialStep(
        text: '再点 1 张，棋盘上凑齐 3 张同款就能合成',
        action: TutorialAction.draw,
        highlight: TutorialHighlight.stockPile,
      ),
      TutorialStep(
        text: '👆 点住卡片，拖到另一张同款上合成'
            '（没有同款就继续点牌堆）',
        action: TutorialAction.merge,
        highlight: TutorialHighlight.board,
      ),
      TutorialStep(
        text: '🎉 太棒了！继续合成，目标是出租车 🚕',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    2: [
      TutorialStep(
        text: '🔒 碰到锁链？点锤子，再点锁链格清除',
        action: TutorialAction.hammer,
        highlight: TutorialHighlight.hammerTool,
      ),
      TutorialStep(
        text: '✅ 清除了！继续合成吧',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    3: [
      TutorialStep(
        text: '🌫️ 迷雾下的牌看不见，把牌移到迷雾旁就能揭开',
        action: TutorialAction.reveal,
        highlight: TutorialHighlight.board,
      ),
      TutorialStep(
        text: '🎯 目标是卡车 🚛，加油！',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    55: [
      TutorialStep(
        text: '⏳ 本关限步！每放一张牌/移动一次消耗 1 步，规划好再动手',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    60: [
      TutorialStep(
        text: '🌀 传送门！卡片移入会从配对的另一个传送门钻出来',
        action: TutorialAction.move,
        highlight: TutorialHighlight.board,
      ),
      TutorialStep(
        text: '利用传送门把牌送到需要的位置，突破棋盘限制',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    61: [
      TutorialStep(
        text: '⭐ 万能卡可以代替任意车辆参与合成！',
        action: TutorialAction.merge,
        highlight: TutorialHighlight.board,
      ),
      TutorialStep(
        text: '把任意卡拖到万能卡上，等于多了一张该等级的卡',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    62: [
      TutorialStep(
        text: '💣 炸弹只有炸弹能合并，集满 3 颗引爆，清空周围 3×3！',
        action: TutorialAction.merge,
        highlight: TutorialHighlight.board,
      ),
      TutorialStep(
        text: '把两颗炸弹拖到一起，第 3 颗落下时引爆全场',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    900: [
      TutorialStep(
        text: '🎯 每日挑战：今天目标随机，每天 0 点刷新，'
            '通关领 150 🪙！只此一关，抓紧哦',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
    999: [
      TutorialStep(
        text: '♾️ 无尽模式：目标达成后自动升级，牌堆无限，'
            '死局即结束。来挑战最高分！',
        action: TutorialAction.custom,
        highlight: TutorialHighlight.none,
        blocking: false,
      ),
    ],
  };

  static List<TutorialStep>? getScript(int levelId) => scripts[levelId];
}

/// 轻量教程覆盖层（2026-08-19 重做）。
///
/// 设计原则（吸取前几轮教训，从根上避开问题）：
/// 1. **无全屏遮罩**：不压暗、不挖空，游戏全程清晰可见、可操作——
///    之前 0.7/0.35 黑幕遮罩被用户明确反馈"挡住游戏看不到"。
/// 2. **不拦截任何点击**：玩家自由操作，教学只是提示（之前 GestureDetector
///    全屏拦截吞掉高亮区点击导致教学卡死）。
/// 3. **双通道推进，永不卡死**：
///    - blocking 步骤：动作检测（onActionDetected）匹配自动推进；
///      气泡上同时有「下一步」按钮——动作检测万一没触发，玩家点按钮也能过。
///    - non-blocking 步骤：4 秒自动消失（单步说明类，如每日/无尽），点按钮也可关闭。
///    - 任意时刻可点右上角「跳过」结束整个教学。
/// 4. **坐标一致**：调用方把浮层放在全屏 Stack（SafeArea 外层），
///    highlightRect 用 localToGlobal 全屏坐标，两者天然对齐。
class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final void Function(TutorialAction action) onActionDetected;
  final Rect? highlightRect;

  /// 是否显示"下一步"按钮（用于无游戏动作可检测的引导，如首页）。
  /// 显示时玩家手动点按钮推进；隐藏时依赖 [onActionDetected] 自动推进。
  final bool showNext;

  /// 最后一个下一步按钮的文案（默认"开始游戏"）。
  final String nextLabel;

  /// 外部驱动的当前步骤索引（非空时优先于内部状态机，配合 [onNextTap] 使用，
  /// 用于首页引导这类需要外部控制高亮区域的场景）。
  final int? externalStep;

  /// 外部"下一步"回调（showNext 模式且 [externalStep] 非空时按钮调用它）。
  final VoidCallback? onNextTap;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onActionDetected,
    this.highlightRect,
    this.showNext = false,
    this.nextLabel = '开始游戏',
    this.externalStep,
    this.onNextTap,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  Timer? _autoDismiss;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    // 整段教学只有 non-blocking 步骤（如每日/无尽的单步说明）时，
    // 没有 blocking 动作触发 _advanceStep —— 启动自动消失定时器，
    // 避免气泡永久挂着（旧版 bug）。
    if (widget.externalStep == null &&
        widget.steps.isNotEmpty &&
        !widget.steps.first.blocking) {
      _scheduleAutoDismiss();
    }
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  TutorialStep get currentStep {
    final idx = widget.externalStep ?? _currentStep;
    return widget.steps[idx.clamp(0, widget.steps.length - 1)];
  }

  bool get _isLast =>
      (widget.externalStep ?? _currentStep) >= widget.steps.length - 1;

  /// 手动推进（按钮）。非阻塞步骤 = 直接过；阻塞步骤 = 手动跳过该步。
  void _advanceStep() {
    _autoDismiss?.cancel();
    if (widget.externalStep != null) {
      widget.onNextTap?.call();
      return;
    }
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
      final next = widget.steps[_currentStep];
      if (!next.blocking) _scheduleAutoDismiss();
    } else {
      widget.onComplete();
    }
  }

  void _scheduleAutoDismiss() {
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 4), () {
      if (mounted) _advanceStep();
    });
  }

  /// 由父 widget 调用,通知检测到玩家操作
  void notifyAction(TutorialAction action) {
    if (widget.externalStep != null) return; // 外部驱动模式不监听游戏动作
    if (currentStep.action == action && currentStep.blocking) {
      _advanceStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final highlight = widget.highlightRect;
    final hasHighlight =
        highlight != null && currentStep.highlight != TutorialHighlight.none;

    return Stack(
      children: [
        // 高亮框（纯视觉，不拦截、不遮罩——游戏全程可见可操作）。
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _HighlightPainter(
                highlightRect: hasHighlight ? highlight : null,
                glowAnimation: _glowAnimation,
              ),
            ),
          ),
        ),

        // 跳过按钮（顶部，轻量小字）
        Positioned(
          top: 12,
          right: 16,
          child: GestureDetector(
            onTap: widget.onComplete,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ink1.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '跳过 ✕',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),

        // 气泡（贴高亮区域或底部）
        if (hasHighlight)
          _buildBubbleNearHighlight(mediaSize, highlight!)
        else
          _buildBubbleAtBottom(mediaSize),
      ],
    );
  }

  /// 气泡主体（含按钮行）。
  Widget _bubbleBody({bool showArrowDown = false, bool showArrowUp = false}) {
    final isLast = _isLast;
    final nextText = showNext
        ? (isLast ? widget.nextLabel : '下一步')
        : (isLast ? '知道了' : '下一步');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.ink1.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showArrowUp)
            _arrow(Alignment.topCenter, -6)
          else if (showArrowDown)
            _arrow(Alignment.bottomCenter, 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app, color: AppColors.sun, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currentStep.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 下一步/知道了按钮（blocking 步骤也提供手动推进，永不卡死）
              GestureDetector(
                onTap: _advanceStep,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.coral, AppColors.coralDeep],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    nextText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 小三角箭头。
  Widget _arrow(Alignment alignment, double dy) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.rotate(
          angle: 0.785398, // 45°
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.ink1.withValues(alpha: 0.96),
            ),
          ),
        ),
      ),
    );
  }

  /// 气泡贴在高亮区域下方（优先）或上方。
  Widget _buildBubbleNearHighlight(Size screenSize, Rect highlight) {
    const bubbleH = 76.0;
    final spaceBelow = screenSize.height - highlight.bottom;
    final putBelow = spaceBelow > bubbleH + 24;

    final double top;
    final bool arrowUp;
    if (putBelow) {
      top = highlight.bottom + 12;
      arrowUp = true; // 气泡在高亮下方，箭头朝上指向高亮
    } else {
      top = highlight.top - bubbleH - 12;
      arrowUp = false;
    }
    final clamped =
        top.clamp(48.0, screenSize.height - bubbleH - 24).toDouble();

    return Positioned(
      top: clamped,
      left: 16,
      right: 16,
      child: _bubbleBody(showArrowUp: arrowUp, showArrowDown: !arrowUp),
    );
  }

  Widget _buildBubbleAtBottom(Size screenSize) {
    return Positioned(
      bottom: 96,
      left: 16,
      right: 16,
      child: _bubbleBody(),
    );
  }
}

/// 高亮框画笔：只画目标边框 + 微光（无遮罩、无挖空——不挡游戏）。
class _HighlightPainter extends CustomPainter {
  final Rect? highlightRect;
  final Animation<double> glowAnimation;

  _HighlightPainter({
    this.highlightRect,
    required this.glowAnimation,
  }) : super(repaint: glowAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    if (highlightRect == null) return;
    final r = highlightRect!.inflate(6);

    // 发光描边（呼吸动画）
    final glowPaint = Paint()
      ..color = AppColors.coral.withValues(
          alpha: 0.35 * glowAnimation.value + 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(14)),
      glowPaint,
    );

    // 主描边
    final mainPaint = Paint()
      ..color = AppColors.sun
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(14)),
      mainPaint,
    );

    // 四角小勾角，强化"目标"感
    final cornerPaint = Paint()
      ..color = AppColors.sun
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const len = 10.0;
    final paths = <Path>[
      Path()
        ..moveTo(r.left, r.top + len)
        ..lineTo(r.left, r.top)
        ..lineTo(r.left + len, r.top),
      Path()
        ..moveTo(r.right - len, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right, r.top + len),
      Path()
        ..moveTo(r.right, r.bottom - len)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.right - len, r.bottom),
      Path()
        ..moveTo(r.left + len, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..lineTo(r.left, r.bottom - len),
    ];
    for (final p in paths) {
      canvas.drawPath(p, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
        oldDelegate.glowAnimation != glowAnimation;
  }
}

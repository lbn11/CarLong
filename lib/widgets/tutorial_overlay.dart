import 'package:flutter/material.dart';

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
        text: '👆 点击车辆，让它开进棋盘',
        action: TutorialAction.draw,
        highlight: TutorialHighlight.stockPile,
      ),
      TutorialStep(
        text: '再点 1 辆自行车，凑齐 3 辆',
        action: TutorialAction.draw,
        highlight: TutorialHighlight.stockPile,
      ),
      TutorialStep(
        text: '👆 点住自行车，拖到另一辆上面',
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
        text: '🔒 碰到锁链怎么办？用锤子清除',
        action: TutorialAction.hammer,
        highlight: TutorialHighlight.hammerTool,
      ),
      TutorialStep(
        text: '点击锤子，然后点击锁链格',
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
        text: '揭开迷雾，找到隐藏的牌',
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
  };

  static List<TutorialStep>? getScript(int levelId) => scripts[levelId];
}

/// 教程覆盖层 Widget
class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final void Function(TutorialAction action) onActionDetected;
  final Rect? highlightRect;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onActionDetected,
    this.highlightRect,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  TutorialStep get currentStep => widget.steps[_currentStep];

  void _advanceStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
      // non-blocking step 自动推进
      final next = widget.steps[_currentStep];
      if (!next.blocking) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _advanceStep();
        });
      }
    } else {
      widget.onComplete();
    }
  }

  /// 由父 widget 调用,通知检测到玩家操作
  void notifyAction(TutorialAction action) {
    if (currentStep.action == action && currentStep.blocking) {
      _advanceStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final highlight = widget.highlightRect;
    final hasHighlight = highlight != null && currentStep.highlight != TutorialHighlight.none;

    return Stack(
      children: [
        // 全屏遮罩(带高亮挖空)
        Positioned.fill(
          child: GestureDetector(
            onTap: () {}, // 拦截点击,防止穿透
            child: CustomPaint(
              painter: _HighlightPainter(
                highlightRect: hasHighlight ? highlight : null,
                glowAnimation: _glowAnimation,
              ),
            ),
          ),
        ),

        // 跳过按钮(顶部)
        Positioned(
          top: 40,
          right: 16,
          child: TextButton(
            onPressed: widget.onComplete,
            child: const Text(
              '跳过',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),

        // 文字气泡(在高亮区域下方或上方)
        if (hasHighlight)
          _buildBubbleNearHighlight(mediaSize, highlight)
        else
          _buildBubbleAtBottom(mediaSize),

        // 步骤指示器(底部)
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.steps.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentStep ? Colors.white : Colors.white38,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleNearHighlight(Size screenSize, Rect highlight) {
    // 气泡放在高亮区域下方,如果空间不够则放在上方
    const bubbleHeight = 60.0;
    final spaceBelow = screenSize.height - highlight.bottom;
    final putBelow = spaceBelow > bubbleHeight + 40;

    final top = putBelow ? highlight.bottom + 16 : highlight.top - bubbleHeight - 16;

    return Positioned(
      top: top.clamp(80.0, screenSize.height - bubbleHeight - 80),
      left: 24,
      right: 24,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF4E342E), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentStep.text,
                  style: const TextStyle(
                    color: Color(0xFF4E342E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleAtBottom(Size screenSize) {
    return Positioned(
      bottom: 100,
      left: 24,
      right: 24,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF4E342E), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentStep.text,
                  style: const TextStyle(
                    color: Color(0xFF4E342E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 遮罩画笔: 半透明底色 + 高亮挖空 + 发光边框
class _HighlightPainter extends CustomPainter {
  final Rect? highlightRect;
  final Animation<double> glowAnimation;

  _HighlightPainter({
    this.highlightRect,
    required this.glowAnimation,
  }) : super(repaint: glowAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRect(Offset.zero & size, paint);

    if (highlightRect != null) {
      // 挖空: 用 BlendMode.clear 挖掉高亮区域
      final clearPaint = Paint()..blendMode = BlendMode.clear;
      final r = highlightRect!.inflate(6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(12)),
        clearPaint,
      );

      // 发光边框
      final glowPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.4 * glowAnimation.value + 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(12)),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
        oldDelegate.glowAnimation != glowAnimation;
  }
}

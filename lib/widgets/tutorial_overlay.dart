import 'package:flutter/material.dart';

/// 教程步骤动作类型
enum TutorialAction {
  tapStock, // 点击牌堆
  drawCard, // 出牌到棋盘
  selectCard, // 选中卡片
  dragCard, // 拖拽卡片
  mergeCards, // 合成卡片
  useHammer, // 使用锤子
  revealFog, // 揭开迷雾
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
        text: '👆 点击这里的车牌，让它开进棋盘',
        action: TutorialAction.tapStock,
        highlight: TutorialHighlight.stockPile,
      ),
      TutorialStep(
        text: '再点两张牌，凑齐 3 辆自行车',
        action: TutorialAction.drawCard,
        highlight: TutorialHighlight.stockPile,
      ),
      TutorialStep(
        text: '👆 点住这张自行车，拖到另一辆上面',
        action: TutorialAction.dragCard,
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
        action: TutorialAction.useHammer,
        highlight: TutorialHighlight.hammerTool,
      ),
      TutorialStep(
        text: '点击锤子，然后点击锁链格',
        action: TutorialAction.useHammer,
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
        action: TutorialAction.revealFog,
        highlight: TutorialHighlight.board,
      ),
      TutorialStep(
        text: '揭开迷雾，找到隐藏的牌',
        action: TutorialAction.revealFog,
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

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onActionDetected,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  TutorialStep get currentStep => widget.steps[_currentStep];

  void _advanceStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
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
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 半透明遮罩
          Positioned.fill(
            child: Container(
              color: Colors.black54,
            ),
          ),

          // 高亮区域(简化:只显示文字气泡)
          Positioned(
            bottom: 120,
            left: 24,
            right: 24,
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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
                    const Icon(
                      Icons.touch_app,
                      color: Color(0xFF4E342E),
                      size: 24,
                    ),
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
          ),

          // 步骤指示器
          Positioned(
            bottom: 90,
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
                      color: i == _currentStep
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
              ],
            ),
          ),

          // 跳过按钮
          Positioned(
            top: 40,
            right: 16,
            child: TextButton(
              onPressed: widget.onComplete,
              child: const Text(
                '跳过',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

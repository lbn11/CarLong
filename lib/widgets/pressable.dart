import 'package:flutter/material.dart';

import '../game/audio_feedback.dart';

/// 统一的按压缩放反馈容器：按下缩小到 [pressedScale] 并给轻点触感，
/// 松手回弹。替代裸 GestureDetector，让所有可点元素有一致的按压手感
/// （裸 GestureDetector 点击无任何视觉/触感响应，体感像"没点上"）。
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.behavior,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  /// 命中测试行为：棋盘格等底色半透明的元素需显式传 opaque。
  final HitTestBehavior? behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool v) {
    if (!_enabled) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: widget.child,
    );
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled
          ? () {
              AudioFeedback.uiTap();
              widget.onTap!();
            }
          : null,
      child: child,
    );
  }
}

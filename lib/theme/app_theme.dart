import 'package:flutter/material.dart';

/// 全局统一配色与质感体系。
///
/// 让各界面与升级后的 3D 车模协调：统一的暗色底 + 暖琥珀主强调色
/// （呼应 Material 主题种子橙），语义色（成功/危险/提示）稳定不变。
class AppColors {
  AppColors._();

  /// 背景层次
  static const bg = Color(0xFF171A1E);
  static const bgDeep = Color(0xFF0E1013);
  static const bgPanel = Color(0xFF232830);

  /// 卡片/表面层次
  static const surface = Color(0xFF232830);
  static const surfaceHi = Color(0xFF2A2F38);
  static const surfaceLo = Color(0xFF1E2229);

  /// 主交互强调色（暖琥珀，呼应主题种子橙）。
  static const accent = Color(0xFFFFA726);
  static const accentStrong = Color(0xFFFF7043);

  /// 语义色
  static const success = Color(0xFF66BB6A);
  static const danger = Color(0xFFE53935);
  static const hint = Color(0xFF26C6DA);
  static const gold = Color(0xFFFFD54F);

  /// 文本层次
  static const textHi = Colors.white;
  static const textMid = Colors.white70;
  static const textLo = Colors.white38;
}

/// 可复用的质感装饰，减少各界面重复的 Decoration 样板。
class AppTheme {
  AppTheme._();

  /// 统一的背景径向渐变（深空感，呼应升级后的车辆影棚光）。
  static const backgroundGradient = RadialGradient(
    center: Alignment(0, -0.45),
    radius: 1.3,
    colors: [Color(0xFF23303E), Color(0xFF171A1E), Color(0xFF0E1013)],
  );

  /// 卡片玻璃质感：暗色底 + 顶部高光 + 细描边。
  static BoxDecoration glass({
    List<Color>? gradient,
    Color? border,
    double radius = 16,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradient ??
            [AppColors.surfaceHi, AppColors.surfaceLo],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: border ?? Colors.white.withValues(alpha: 0.08),
        width: borderWidth,
      ),
    );
  }

  /// 主强调按钮样式（暖琥珀）。
  static ButtonStyle accentButton({Color? background}) =>
      FilledButton.styleFrom(
        backgroundColor: background ?? AppColors.accent,
        foregroundColor: const Color(0xFF3A2400),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      );

  /// 次级按钮样式（暗面）。
  static ButtonStyle surfaceButton({Color? background}) =>
      FilledButton.styleFrom(
        backgroundColor: background ?? AppColors.surfaceHi,
        foregroundColor: Colors.white,
      );
}

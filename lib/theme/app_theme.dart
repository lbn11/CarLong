import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 全局统一配色与质感体系。
///
/// Sunny Candy 浅色基调：奶油底 + 珊瑚/莓红主强调 + 每款车型一个身份色
/// （颜色 = 车型身份）+ 圆润字体（Baloo 2 / Nunito）。深色令牌保留以兼容旧引用。
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

  /// 主交互强调色（珊瑚，Sunny Candy 品牌主色，对应设计稿 #FF7A5C/#FF5E7A）。
  static const accent = Color(0xFFFF7A5C);
  static const accentStrong = Color(0xFFFF5E7A);

  /// 语义色
  static const success = Color(0xFF66BB6A);
  static const danger = Color(0xFFE53935);
  static const hint = Color(0xFF26C6DA);
  static const gold = Color(0xFFFFD54F);

  /// 文本层次
  static const textHi = Colors.white;
  static const textMid = Colors.white70;
  static const textLo = Colors.white38;

  // ===== Sunny Candy 浅色基调（参考蛋仔派对/合成类休闲风）=====
  /// 浅色背景层次（暖奶油 → 粉雾 → 天空）。
  static const bg1 = Color(0xFFFCF3EA);
  static const bg2 = Color(0xFFFDE7F1);
  static const bg3 = Color(0xFFE7F1FF);
  /// 浅色表面（白卡）。
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFCF6F1);
  static const surfaceTint = Color(0xFFFBEFF6);
  /// 浅色墨字（柔和深梅紫，比纯黑更亲）。
  static const ink1 = Color(0xFF2B2440);
  static const ink2 = Color(0xFF6B6480);
  static const ink3 = Color(0xFFA39DB5);
  /// 品牌强调（珊瑚 / 莓红）。
  static const coral = Color(0xFFFF7A5C);
  static const coralDeep = Color(0xFFFF5E7A);
  /// 浅色语义色。
  static const sun = Color(0xFFFFC24B);
  static const sky = Color(0xFF4CC2FF);
  static const mint = Color(0xFF3ED598);
  static const grape = Color(0xFFA78BFA);
  /// 浅色柔和阴影（~rgba(50,32,86,.14)）。
  static const shadow = Color(0x24323256);

  /// 金币/分数 chip 金渐变（设计稿 #FFD982→#FFB23E，字色 #7A4A12）。
  static const coinGold1 = Color(0xFFFFD982);
  static const coinGold2 = Color(0xFFFFB23E);
  static const coinText = Color(0xFF7A4A12);
}

/// 可复用的质感装饰，减少各界面重复的 Decoration 样板。
class AppTheme {
  AppTheme._();

  /// 统一的背景径向渐变（深空感，保留兼容旧用）。
  static const backgroundGradient = RadialGradient(
    center: Alignment(0, -0.45),
    radius: 1.3,
    colors: [Color(0xFF23303E), Color(0xFF171A1E), Color(0xFF0E1013)],
  );

  /// 卡片玻璃质感：暗色底 + 顶部高光 + 细描边（保留兼容旧用）。
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
        colors: gradient ?? [AppColors.surfaceHi, AppColors.surfaceLo],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: border ?? Colors.white.withValues(alpha: 0.08),
        width: borderWidth,
      ),
    );
  }

  /// 浅色背景渐变（奶油 → 粉雾 → 天空），用于 Scaffold。
  static const backgroundGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.bg1, AppColors.bg2, AppColors.bg3],
  );

  /// 珊瑚主渐变（品牌 CTA：珊瑚 → 莓红）。
  static const List<Color> primaryGradient = [
    AppColors.coral,
    AppColors.coralDeep
  ];

  /// 浅色白卡：纯白 + 柔和彩色投影。
  static BoxDecoration card({double radius = 18}) => BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      );

  /// 车型身份卡：浅色车型底（车型色提亮成浅版）+ 饱和同色描边 + 同色投影。颜色 = 车型身份色。
  static BoxDecoration tierCard(Color tier, {double radius = 16}) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(tier, Colors.white, 0.66)!,
            Color.lerp(tier, Colors.white, 0.82)!,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tier.withValues(alpha: 0.60), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: tier.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// 车型色实色描边（用于已停放/已占用的实框）。
  static Color tierBorder(Color tier) => tier.withValues(alpha: 0.55);

  /// 车型色徽标墨色（比原色深一档，保证白底可读）。
  static Color tierInk(Color tier) => Color.lerp(tier, Colors.black, 0.35)!;

  /// 主强调按钮样式（珊瑚渐变 pill + 白字 + 珊瑚投影，匹配设计稿 .btn）。
  static ButtonStyle accentButton({Color? background}) => FilledButton.styleFrom(
        backgroundColor: background ?? AppColors.coral,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        shadowColor: AppColors.coralDeep,
        elevation: 4,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      );

  /// 次级按钮样式（白卡 + 墨字）。
  static ButtonStyle surfaceButton({Color? background}) => FilledButton.styleFrom(
        backgroundColor: background ?? AppColors.surfaceLight,
        foregroundColor: AppColors.ink1,
      );
}

/// 浅色背景 + 三处彩色径向光晕（珊瑚左上 / 晴空右上 / 葡萄底部），
/// 对应设计稿 Sunny Candy 的“奶油底 + 光晕”氛围。直接作为 Scaffold body 使用。
class GlowBackground extends StatelessWidget {
  final Widget child;

  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradientLight),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GlowPainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  void _orb(Canvas canvas, Size size, double fx, double fy, double r, Color color) {
    final center = Offset(size.width * fx, size.height * fy);
    final paint = Paint()
      ..shader = ui.Gradient.radial(center, r, [
        color.withValues(alpha: 0.16),
        color.withValues(alpha: 0.0),
      ]);
    canvas.drawCircle(center, r, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _orb(canvas, size, 0.12, 0.08, size.width * 0.55, AppColors.coral);
    _orb(canvas, size, 0.92, 0.18, size.width * 0.50, AppColors.sky);
    _orb(canvas, size, 0.70, 1.00, size.width * 0.60, AppColors.grape);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => false;
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

/// 统一的「糖果休闲」UI 组件库（Candy Pop）。
///
/// 设计目标：明亮多彩、圆润无压的高级休闲感——高光白卡、彩渐变 pill 按钮、
/// 圆角抽屉式弹层。所有页面共用同一套零件，视觉天然一致，也让"点一下"更爽。
/// 组件内部一律引用 AppColors / AppTheme，禁止裸色值。

// ============================================================
//  AppBar
// ============================================================

/// 统一糖果顶栏：奶油玻璃底 + 圆形返回键 + 大标题 + 右侧挂件。
///
/// 比 Material AppBar 更柔：无硬分割线、圆角 cytometry 胶囊返回键、
/// 标题带可选副标题（把"页面在干什么"一句讲清）。
class CandyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CandyAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.accent,
  });

  final String title;
  final String? subtitle;

  /// 右侧挂件（金币胶囊、进度 chip 等）。
  final List<Widget> actions;

  /// 为空则不显示返回键（首页场景）。
  final VoidCallback? onBack;

  /// 标题前的圆点强调色；为空用品牌珊瑚。
  final Color? accent;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.coral;
    return SafeArea(
      bottom: false,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Row(
          children: [
            if (onBack != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: RoundIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack!,
                  color: color,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink1,
                            fontSize: 21,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 15, top: 1),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.ink3, fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// 圆形糖果图标按钮（顶栏返回/关闭、游戏 HUD 共用）。
/// [onTap] 为空时自动进入禁用态（灰描边、无按压），保证随时可渲染。
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final effective = enabled ? color : AppColors.ink3;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceLight,
                    Color.lerp(color, Colors.white, 0.90)!,
                  ],
                )
              : null,
          color: enabled ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: effective.withValues(alpha: enabled ? 0.30 : 0.18)),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: effective.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(icon,
            size: 17, color: enabled ? AppColors.ink1 : AppColors.ink3),
      ),
    );
  }
}

// ============================================================
//  卡片
// ============================================================

/// 糖果白卡：纯白底 + 顶部高光 + 可选强调色边缘/投影。
///
/// [accent] 给定时，卡片会带一层极淡的同色渐层与更柔的同色投影，
/// 让"这张卡属于哪个模块"一眼可辨（模块身份色）。
class CandyCard extends StatelessWidget {
  const CandyCard({
    super.key,
    this.accent,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.child,
    this.muted = false,
  });

  final Color? accent;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Widget? child;

  /// 弱化态（锁定/未完成）：去掉强调色，改灰mauve 底 + 虚线感描边。
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final accentColor = muted ? AppColors.ink3 : (accent ?? AppColors.coral);
    final card = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: muted
              ? [AppColors.surfaceSoft, AppColors.surfaceSoft]
              : [
                  AppColors.surfaceLight,
                  Color.lerp(accentColor, Colors.white, 0.94)!,
                ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accentColor.withValues(alpha: muted ? 0.22 : 0.28),
        ),
        boxShadow: [
          // 顶部内高光：模拟打在卡面边缘的一点光，"贵"就来自这一层。
          BoxShadow(
            color: AppColors.whiteGlint.withValues(alpha: 0.9),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: muted
                ? AppColors.shadow.withValues(alpha: 0.6)
                : accentColor.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}

// ============================================================
//  按钮
// ============================================================

/// 糖果渐变按钮：pill 形 + 顶部白色高光条 + 同色投影 + 按压回弹。
///
/// 颜色由 palette 决定：主 CTA 用珊瑚→莓红，次要操作各自模块色。
class CandyButton extends StatelessWidget {
  const CandyButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.colors,
    this.expand = false,
    this.size = CandyButtonSize.medium,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  /// 渐变两色；默认珊瑚 → 莓红。
  final List<Color>? colors;

  /// 是否撑满父级宽度。
  final bool expand;
  final CandyButtonSize size;

  /// 紧凑版（卡片内的小按钮），减少水平内边距。
  final bool dense;

  double get _height => switch (size) {
        CandyButtonSize.small => 34,
        CandyButtonSize.medium => 44,
        CandyButtonSize.large => 52,
      };

  double get _fontSize => switch (size) {
        CandyButtonSize.small => 12.5,
        CandyButtonSize.medium => 14.5,
        CandyButtonSize.large => 16.5,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = colors ?? const [AppColors.coral, AppColors.coralDeep];
    final gradient =
        enabled ? c : [AppColors.ink3.withValues(alpha: 0.25), AppColors.ink3.withValues(alpha: 0.25)];
    // 浅色渐变（如次级/取消按钮）自动改用墨色字，避免白字在浅底上消失。
    final bright = gradient.first.computeLuminance() > 0.6;
    final fg =
        enabled ? (bright ? AppColors.ink1 : Colors.white) : AppColors.ink3;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: size == CandyButtonSize.small ? 15 : 19, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: _fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );

    final button = Container(
      height: _height,
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : (size == CandyButtonSize.large ? 26 : 18)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: c.last.withValues(alpha: 0.34),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: content,
    );

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          button,
          // 上半层白色高光，让 pill 有"打过光"的圆润立体感。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _height * 0.46,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: enabled ? 0.28 : 0.0),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final Widget sized = expand
        ? SizedBox(width: double.infinity, child: clipped)
        : IntrinsicWidth(child: clipped);

    if (!enabled) return Opacity(opacity: 0.9, child: sized);
    return Pressable(pressedScale: 0.95, onTap: onTap, child: sized);
  }
}

enum CandyButtonSize { small, medium, large }

// ============================================================
//  小零件
// ============================================================

/// 金币胶囊（耳机/Pill 造型，金色渐变小球+数字）。无处不在的资源条。
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.amount, this.onTap, this.compact = false});

  final int amount;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.coinGold1, AppColors.coinGold2],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.coinGold2.withValues(alpha: 0.42),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💰', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 4),
          Text(
            '$amount',
            style: TextStyle(
              color: AppColors.coinText,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return Pressable(onTap: onTap, child: pill);
  }
}

/// 柔和 chip（标签/状态）：淡色底 + 同色字，用在标题旁与 meta 行。
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.solid = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  /// 实色版（用于强调状态，如"可领取"）。
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.coral;
    final fg = solid ? Colors.white : AppTheme.deepen(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 区块小标题：色条 + 标题 + 右侧可选 widget。
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.accent,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.coral;
    return Row(
      children: [
        Container(
          width: 5,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c, c.withValues(alpha: 0.45)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.ink1,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.ink3, fontSize: 11)),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 圆润进度条（比 LinearProgressIndicator 更"糖果"，带轨道胶囊与柔光端点）。
class CandyProgress extends StatelessWidget {
  const CandyProgress({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.coral;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.ink3.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color.lerp(c, Colors.white, 0.35)!,
                    c,
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 星星行（关卡星级）。统一大小与颜色，替换散落的 List.generate。
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.total = 3, this.size = 13});

  final int stars;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 1.5),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars ? AppColors.sun : AppColors.ink3,
            ),
          ),
      ],
    );
  }
}

// ============================================================
//  弹层
// ============================================================

/// 通用「多选一」糖果弹窗：暂停菜单、死局处理这类"给玩家 2~3 个出口"的场景。
///
/// 合成页与停车页此前各自手写了一份暂停菜单（两套视觉持续漂移），统一到这里。
class CandyChoice<T> {
  const CandyChoice({
    required this.label,
    this.value,
    this.icon,
    this.highlight = false,
    this.colors,
  });

  final String label;
  final T? value;
  final IconData? icon;

  /// 主推操作（如"继续游戏"）：用强调色渐变，其余次要用柔和灰底。
  final bool highlight;

  /// 显式指定渐变（覆盖 highlight 的默认取色）。
  final List<Color>? colors;
}

class CandyChoiceDialog<T> extends StatelessWidget {
  const CandyChoiceDialog({
    super.key,
    required this.title,
    required this.accent,
    required this.options,
    this.message,
    this.emoji,
  });

  final String title;
  final String? message;
  final String? emoji;
  final Color accent;
  final List<CandyChoice<T>> options;

  /// 弹出选择弹窗并返回被选中项的值。
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Color accent,
    required List<CandyChoice<T>> options,
    String? message,
    String? emoji,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => CandyChoiceDialog<T>(
        title: title,
        message: message,
        emoji: emoji,
        accent: accent,
        options: options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceLight,
              Color.lerp(accent, Colors.white, 0.92)!,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.26),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradientFor(accent),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: emoji != null
                        ? Text(emoji!, style: const TextStyle(fontSize: 22))
                        : const Icon(Icons.touch_app_rounded,
                            color: Colors.white, size: 23),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.ink1,
                              fontSize: 19,
                              fontWeight: FontWeight.w900)),
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(message!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.ink2, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            for (var i = 0; i < options.length; i++) ...[
              CandyButton(
                label: options[i].label,
                icon: options[i].icon,
                colors: options[i].colors ??
                    (options[i].highlight
                        ? AppTheme.gradientOf(accent)
                        : AppTheme.softGradient),
                expand: true,
                onTap: () => Navigator.of(context).pop(options[i].value),
              ),
              if (i != options.length - 1) const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }
}

/// 统一糖果弹窗：图标泡泡 + 标题 + 说明 + 一到两个按钮。
///
/// 替代各页面重复的 showDialog 样板，保证标题层级/圆角/按钮完全一致。
class CandyDialog extends StatelessWidget {
  const CandyDialog({
    super.key,
    this.emoji,
    this.icon,
    required this.title,
    this.message,
    this.color,
    this.confirmLabel = '好',
    this.onConfirm,
    this.cancelLabel,
    this.confirmValue,
    this.cancelValue,
    this.child,
  });

  final String? emoji;
  final IconData? icon;
  final String title;
  final String? message;
  final Color? color;

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final String? cancelLabel;

  /// 两个按钮各自 pop 出去的返回值（用于「退出？yes/no」这类二选一确认）。
  final Object? confirmValue;
  final Object? cancelValue;

  /// 自定义主体（例如奖励列表），给出时不渲染 message。
  final Widget? child;

  /// 弹出一个糖果弹窗并返回被点击按钮对应的值。
  static Future<T?> show<T>(
    BuildContext context, {
    String? emoji,
    IconData? icon,
    required String title,
    String? message,
    Color? color,
    String confirmLabel = '好',
    VoidCallback? onConfirm,
    String? cancelLabel,
    Widget? child,
    bool barrierDismissible = true,
    T? confirmValue,
    T? cancelValue,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => CandyDialog(
        emoji: emoji,
        icon: icon,
        title: title,
        message: message,
        color: color,
        confirmLabel: confirmLabel,
        onConfirm: onConfirm,
        cancelLabel: cancelLabel,
        confirmValue: confirmValue,
        cancelValue: cancelValue,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.coral;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceLight,
              Color.lerp(c, Colors.white, 0.94)!,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.withValues(alpha: 0.30), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.26),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(c, Colors.white, 0.55)!,
                    c.withValues(alpha: 0.85),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: emoji != null
                    ? Text(emoji!, style: const TextStyle(fontSize: 30))
                    : Icon(icon ?? Icons.auto_awesome, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.ink1,
                    fontSize: 19,
                    fontWeight: FontWeight.w900)),
            if (child != null) ...[
              const SizedBox(height: 12),
              child!,
            ],
            if (message != null) ...[
              const SizedBox(height: 7),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.ink2, fontSize: 13.5, height: 1.45)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (cancelLabel != null) ...[
                  Expanded(
                    child: CandyButton(
                      label: cancelLabel!,
                      size: CandyButtonSize.medium,
                      colors: AppTheme.softGradient,
                      onTap: () => Navigator.of(context).pop(cancelValue),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: CandyButton(
                    label: confirmLabel,
                    size: CandyButtonSize.medium,
                    colors: [c, AppTheme.deepen(c)],
                    onTap: () {
                      Navigator.of(context).pop(confirmValue);
                      onConfirm?.call();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:merge_fleet/l10n/app_localizations.dart';
import 'package:merge_fleet/l10n/l10n.dart';

/// 带本地化的测试宿主。所有会渲染带文案界面的测试都要用它包一层。
///
/// 为什么必须有它：`l10n.yaml` 里 `nullable-getter: false`，gen-l10n 生成的
/// `AppLocalizations.of(context)` 内部对 `Localizations.of` 的结果加了 `!`。
/// 测试里如果用裸 `MaterialApp(home: ...)`，delegate 没挂上，它会在运行时抛
/// ``Null check operator used on a null value``——真机不会（main.dart 已配
/// `localizationsDelegates`），**只有测试会踩到**。
///
/// 想验证中文包就传 `locale: const Locale('zh')`。
MaterialApp l10nHost(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // 与 MergeGameApp.builder 保持一致：模型 getter / Flame 组件靠这份广播
    // 拿到当前 locale 的文案，否则测试里读到的永远是中文回落值。
    builder: (context, inner) {
      L10n.sync(AppLocalizations.of(context));
      return inner!;
    },
    home: child,
  );
}

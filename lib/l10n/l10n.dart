import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// 非 widget 代码取文案的唯一入口。
///
/// **为什么需要它**：本项目一半的文案不在 widget 里。
/// ① 模型 getter（[VehicleType.name]、[Rarity.displayLabel]…）是纯数据，
///    签名里没有 `BuildContext`，而它们被几十处界面直接插值；
/// ② Flame 的棋盘/车卡/Boss 是 `PositionComponent`，在 `render()` 里画字，
///    同样拿不到 context；
/// ③ 存档、导出、排序等纯逻辑也不该为了取一个字符串而拖进 BuildContext。
///
/// 把 `AppLocalizations` 塞进这些地方的唯一办法就是**在 widget 树顶部同步一份
/// 当前实例**。刷新点在 `MaterialApp.builder`：它在 locale 变化时会重建，
/// 且早于任何子 widget 的 build/render，所以下游读到的永远是本帧的 locale。
///
/// **回落策略**：`current == null`（单测直接 new 模型、或首帧之前）时，
/// 各 getter 回落到中文字面量。中文是源码里写过、被测试断言过的原文，
/// 而不是空串——这样「没接上下文」只会显示中文，不会显示空白或 key。
abstract final class L10n {
  L10n._();

  static AppLocalizations? _current;

  /// 未同步时的兜底实例。选英文而不是中文：`supportedLocales` 里 en 排第一，
  /// 也就是「系统语言不认识」时的实际默认语言。
  static final AppLocalizations _fallback = AppLocalizationsEn();

  /// 当前 locale 的文案表；未同步时为 null。
  static AppLocalizations? get current => _current;

  /// **保证非空**的文案表，widget 侧一律用它——尤其是 `initState`：
  /// 那时还轮不到 `dependOnInheritedWidgetOfExactType`，`AppLocalizations.of`
  /// 会直接抛断言，只能从这里拿。
  ///
  /// 注意与模型 getter 的回落策略不同：那边没有文案表可用，只能回落到
  /// 源码里的中文字面量（`zhName`）；这边有完整表，所以给默认语言。
  static AppLocalizations get value => _current ?? _fallback;

  /// 由 [MergeGameApp] 与测试宿主 `l10nHost` 在 builder 里调用。
  static void sync(AppLocalizations? value) => _current = value;

  /// 仅供测试：把持有者清回「未同步」，避免上一个用例的 locale 泄漏到下一个。
  static void resetForTest() => _current = null;
}

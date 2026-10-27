import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import 'ad_types.dart';

/// 诊断行的语气（只影响颜色，不影响逻辑）。
enum AdDiagLevel {
  /// 真实库存，可上架。
  good,

  /// 中性信息。
  info,

  /// 需要处理：演示通道、测试库存、初始化失败。
  warn,
}

/// 一条诊断信息：`通道 · 正式广告 / 测试广告 / 演示通道`。
///
/// 存在的理由很直接：广告这块最容易出的问题是「以为在赚钱，其实在放测试
/// 广告」。日志只有连着调试器才看得到，所以把它做成 App 内的一行字——
/// 真机上打开设置就能确认，不用猜。
@immutable
class AdDiagRow {
  final String label;
  final String value;
  final AdDiagLevel level;

  const AdDiagRow(this.label, this.value, {this.level = AdDiagLevel.info});

  @override
  String toString() => '$label=$value';
}

/// 广告通道的「真实性」判定与文案。
///
/// 三种状态互斥，别混：
/// | 状态 | isMock | usesTestInventory | 有画面 | 有收入 | 可上架 |
/// |---|---|---|---|---|---|
/// | 演示通道 | true | — | 否 | 否 | 否 |
/// | 测试广告 | false | true | **是** | 否 | 否 |
/// | 正式广告 | false | false | 是 | 是 | 是 |
class AdDiagnostics {
  /// 是否在 App 内显示诊断区。
  ///
  /// debug / profile 默认显示（真机联调、渠道演示都能看到）；
  /// release 默认隐藏，避免玩家看到内部信息，但允许
  /// `--dart-define=ADS_DIAGNOSTICS=true` 打开（给 QA 包用）。
  static bool get enabled =>
      const bool.fromEnvironment('ADS_DIAGNOSTICS') || !kReleaseMode;

  static AdDiagLevel levelOf({
    required bool isMock,
    required bool testInventory,
  }) {
    if (isMock) return AdDiagLevel.warn;
    if (testInventory) return AdDiagLevel.warn;
    return AdDiagLevel.good;
  }

  /// 通道一句话（设置里展示 + 启动日志用同一句，避免两处说法不一致）。
  static String channelText({
    required String provider,
    required bool isMock,
    required bool testInventory,
  }) {
    final l = L10n.value;
    if (isMock) return l.adDiagMock(provider);
    if (testInventory) return l.adDiagTest(provider);
    return l.adDiagLive(provider);
  }

  /// 启动时打一行，方便在 `flutter run` / `adb logcat` 里第一眼确认环境。
  static String logLine({
    required String provider,
    required bool isMock,
    required bool testInventory,
    required bool initialized,
  }) {
    final channel = channelText(
      provider: provider,
      isMock: isMock,
      testInventory: testInventory,
    );
    final l = L10n.value;
    return l.adDiagLog(channel, initialized ? l.adDiagStateOk : l.adDiagStateFail);
  }

  /// 单点剩余次数文案：`商店 1/3`。
  static String slotText(AdPlacement placement, int used) {
    final cap = placement.dailyCap;
    final left = cap == null ? 0 : (cap - used).clamp(0, cap);
    return '${_shortLabel(placement)} $left/${cap ?? '∞'}';
  }

  static String _shortLabel(AdPlacement placement) => switch (placement) {
        AdPlacement.shopDaily => L10n.value.adPlacementShopShort,
        AdPlacement.mergeRevive => L10n.value.adPlacementReviveShort,
        AdPlacement.mergeDouble => L10n.value.adPlacementDoubleShort,
        AdPlacement.parkingUndo => L10n.value.adPlacementUndoShort,
        AdPlacement.parkingHint => L10n.value.adPlacementHintShort,
      };
}

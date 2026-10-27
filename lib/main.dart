import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/music_player.dart';
import 'game/vehicle_icons.dart';
import 'game/vehicle_sprites.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'save/save_repository.dart';
import 'screens/home_screen.dart';
import 'services/ads/ad_diagnostics.dart';
import 'services/ads/ad_policy.dart';
import 'services/ads/ad_provider_factory.dart';
import 'services/ads/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 游戏锁定竖屏（用户约定：本作只能竖屏玩）。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await precomputeVehicleBounds().timeout(
    const Duration(seconds: 5),
    onTimeout: () {},
  );
  // 真实车模预载：棋盘卡面/停车车身是 Canvas 直接画图，必须提前解码到内存，
  // 否则首帧会先闪 emoji。失败只降级，不拦启动。
  await VehicleSprites.preloadAll().timeout(
    const Duration(milliseconds: 2500),
    onTimeout: () {},
  );
  final repo = SaveRepository();
  final data = await repo.load();
  // ── 广告层 ──────────────────────────────────────────────────────────
  // 按平台选 provider（唯一需要区分平台的地方，见 ad_provider_factory.dart）：
  //   Android / iOS → AdMob（google_mobile_ads）
  //   Web / 桌面    → MockAdProvider（预览与自动化测试用）
  //   --dart-define=MOCK_ADS=true → 强制 Mock（演示/失败路径回归）
  // 业务侧 5 个广告位全部走 AdService.show()，不需要任何改动。
  AdService.provider = createAdProvider();
  // 频次策略（单点上限在 AdPlacementMeta，全局总量/总开关在这里）：
  // --dart-define=AD_GLOBAL_DAILY_CAP=20 收紧总量；=0 或 ADS_DISABLED=true 全关。
  AdService.policy = AdPolicy.fromEnvironment();
  // 初始化放到首帧之后：
  // 1. AdMob 的 UMP 同意表单（GDPR）需要已挂载的 Activity / ViewController；
  // 2. 冷启动不该被 SDK 的网络请求拖住（原来 await 2s 超时会直接卡白屏）。
  // 玩家在 SDK 就绪前点了广告位也没关系——AdService.show() 会 await 同一个
  // 初始化 future，UI 侧本来就有加载态。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      final ok = await AdService.initialize();
      // 启动日志一行，回答「这个包里放的到底是不是真广告」。
      // 三个状态：演示通道 / 测试广告（真 SDK·零收入）/ 正式广告。
      debugPrint(AdDiagnostics.logLine(
        provider: AdService.providerName,
        isMock: AdService.usingMock,
        testInventory: AdService.usingTestInventory,
        initialized: ok,
      ));
    }());
  });
  runApp(MergeGameApp(data: data, repo: repo));
}

class MergeGameApp extends StatelessWidget {
  final PlayerData data;
  final SaveRepository repo;

  const MergeGameApp({super.key, required this.data, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 标题也要本地化。MaterialApp.title 拿不到 context，只能用
      // onGenerateTitle 延迟到需要时再查（安卓任务管理器会显示它）。
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 顺序即回落顺序：arb 按字母序生成 [en, zh]，所以非中英语言一律落到英文。
      // 英文是海外玩家的默认语言，中文保留给自己调试与将来可能的国服。
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [musicRouteObserver],
      // 游戏 HUD/棋盘都是固定尺寸布局：系统大字体钳制到 1.3 倍，
      // 既照顾低视力用户，又避免文字撑爆棋盘与按钮。
      builder: (context, child) {
        // 模型 getter 与 Flame 组件拿不到 context，只能靠这里广播一份当前
        // 文案表（见 lib/l10n/l10n.dart）。builder 在 locale 变化时会重建，
        // 且早于子树的 build/render，所以下游读到的永远是本帧的 locale。
        L10n.sync(AppLocalizations.of(context));
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Baloo2',
        // Nunito.ttf 文件已截断损坏（gvar 表越界）且 Baloo2 覆盖全部拉丁字符，
        // 2026-10-27 移除；拉丁缺口由 Noto Sans SC 兜底。
        fontFamilyFallback: const [
          'NotoColorEmoji',
          'Noto Sans SC',
          'PingFang SC',
          'Microsoft YaHei'
        ],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A5C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFCF3EA),
      ),
      home: HomeScreen(data: data, repo: repo),
    );
  }
}

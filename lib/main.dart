import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/music_player.dart';
import 'game/vehicle_icons.dart';
import 'game/vehicle_sprites.dart';
import 'save/save_repository.dart';
import 'screens/home_screen.dart';
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
    unawaited(AdService.initialize());
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
      title: '车水马龙',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [musicRouteObserver],
      // 游戏 HUD/棋盘都是固定尺寸布局：系统大字体钳制到 1.3 倍，
      // 既照顾低视力用户，又避免文字撑爆棋盘与按钮。
      builder: (context, child) {
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
        fontFamilyFallback: const [
          'NotoColorEmoji',
          'Nunito',
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

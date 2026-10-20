import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/music_player.dart';
import 'game/vehicle_icons.dart';
import 'game/vehicle_sprites.dart';
import 'save/save_repository.dart';
import 'screens/home_screen.dart';

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/music_player.dart';
import 'game/vehicle_icons.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Baloo2',
        fontFamilyFallback: const [
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

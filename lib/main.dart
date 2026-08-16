import 'package:flutter/material.dart';

import 'game/vehicle_icons.dart';
import 'save/save_repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Noto Sans SC',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF2784E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF171A1E),
      ),
      home: HomeScreen(data: data, repo: repo),
    );
  }
}

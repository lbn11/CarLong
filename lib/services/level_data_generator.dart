import 'dart:convert';
import 'dart:io';

import '../models/car.dart';
import '../models/level.dart';

/// 主线关卡数据生成器(71-200 关)
class LevelDataGenerator {
  /// 生成 200 关主线数据(JSON 格式,后续可转 YAML)
  static String generateMainLevelsJson() {
    final levels = <Map<String, dynamic>>[];

    for (var i = 71; i <= 200; i++) {
      levels.add(_generateLevel(i));
    }
    return jsonEncode(levels);
  }

  static Map<String, dynamic> _generateLevel(int id) {
    final tier = _tierForLevel(id);
    final size = id < 100 ? 5 : (id < 150 ? 5 : 6);
    final obstacles = ((id - 70) ~/ 10).clamp(0, 8);
    final timeLimit = id % 3 == 0 ? 90 + ((id - 70) ~/ 5) * 5 : null;

    return {
      'id': id,
      'name': _chapterName(id),
      'cols': size,
      'rows': size,
      'stockSize': 30 + (id - 70),
      'targetTier': tier.index,
      'targetCount': (id < 120) ? 1 : ((id < 180) ? 2 : 3),
      'goalType': id % 7 == 0 ? 'clearBoard' : 'produce',
      'timeLimitSeconds': timeLimit,
      'movesLimit': null,
      'obstacles': _generateObstacles(obstacles, size),
    };
  }

  static CarTier _tierForLevel(int id) {
    if (id < 90) return CarTier.bus;
    if (id < 110) return CarTier.truck;
    if (id < 130) return CarTier.train;
    if (id < 150) return CarTier.metro;
    if (id < 170) return CarTier.jet;
    if (id < 190) return CarTier.shuttle;
    return CarTier.ufo;
  }

  static String _chapterName(int id) {
    if (id < 90) return '地铁线';
    if (id < 110) return '航空港';
    if (id < 130) return '星际前哨';
    if (id < 150) return '深空巡航';
    if (id < 170) return '时空裂隙';
    if (id < 190) return '宇宙尽头';
    return '彗星计划';
  }

  static List<Map<String, dynamic>> _generateObstacles(int count, int size) {
    final obstacles = <Map<String, dynamic>>[];
    final types = ['block', 'ice', 'lock', 'teleport'];

    for (var i = 0; i < count; i++) {
      final type = types[i % types.length];
      final c = ((i * 7 + 3) % (size - 2)) + 1;
      final r = ((i * 11 + 5) % (size - 2)) + 1;
      obstacles.add({
        'type': type,
        'col': c,
        'row': r,
        if (type == 'ice') 'layers': 2 + (i % 2),
      });
    }
    return obstacles;
  }

  static Future<void> writeToFile(String path) async {
    final json = generateMainLevelsJson();
    final file = File(path);
    await file.writeAsString(json);
  }
}

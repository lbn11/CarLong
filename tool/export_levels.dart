// 关卡数据导出器 —— 把 Dart 里的「程序化关卡」固化成跨端通用的 JSON。
//
// 为什么需要它：
// 主线的 700 关和停车的 800 关都是**运行时生成**的（确定性纯函数）。
// 一旦要用别的语言/引擎做小游戏端，就必须把生成结果导出，而不是移植算法：
//   ① Dart 的 `Random(seed)` 序列跨语言不可复现；
//   ② 停车关是「反向 BFS 倒走」产生的布局，本质是一份解谜数据，不是公式。
//
// 导出产物（shared/levels/）是**跨端唯一真源**：Flutter 端、未来的 TS 端、
// 服务端下发都读同一份。改数值只改 Dart，重跑本工具即可。
//
// 用法（必须有 dart:ui，所以走 flutter test 而不是 dart run）：
//   flutter test tool/export_levels_runner.dart
//
// 产物：
//   shared/levels/index.json          —— manifest：版本、数量、章节表、指纹
//   shared/levels/vehicles.json       —— 50 档车型（颜色/图标/属性/稀有度）
//   shared/levels/merge_levels.json   —— 700 关合成
//   shared/levels/parking_levels.json —— 800 关停车
import 'dart:convert';
import 'dart:io';

import 'package:merge_fleet/logic/parking_solver.dart';
import 'package:merge_fleet/models/level.dart';
import 'package:merge_fleet/models/parking_level.dart';
import 'package:merge_fleet/models/vehicle.dart';
import 'package:merge_fleet/services/level_data_generator.dart';
import 'package:merge_fleet/services/level_progression.dart';
import 'package:merge_fleet/services/parking_chapters.dart';
import 'package:merge_fleet/services/parking_generator.dart';

/// 数据 schema 版本。**字段语义变了就 +1**，客户端据此拒绝旧数据。
const int kLevelSchemaVersion = 1;

/// FNV-1a 32 位指纹：只用于「同一次生成是否完全一致」的自检，
/// 不引入 crypto 依赖。换行/空格已排除（对紧凑 JSON 直接算字节）。
int fnv1a(List<int> bytes) {
  var h = 0x811c9dc5;
  for (final b in bytes) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

String _hex(int argb) =>
    '#${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// 去掉 null 值，让 JSON 紧凑且不与「0 / false」混淆。
Map<String, dynamic> _compact(Map<String, dynamic> m) {
  m.removeWhere((_, v) => v == null);
  return m;
}

Map<String, dynamic> vehicleToJson(VehicleType t) => {
      'id': t.id,
      'name': t.name,
      'icon': t.icon,
      'color': _hex(t.color.toARGB32()),
      'category': t.category.name,
      'rarity': t.stats.rarity.name,
      'rarityColor': _hex(t.stats.rarity.color.toARGB32()),
      'ability': t.stats.ability.name,
      'move': t.stats.moveDistance,
      'terrain': [for (final x in t.stats.terrain) x.name],
    };

Map<String, dynamic> bossToJson(BossSpec b) => _compact({
      'hp': b.hp,
      'interval': b.attackInterval,
      'firstDelay': b.firstDelay,
      'primary': b.primary.name,
      'secondary': b.secondary?.name,
      'epithet': b.epithet,
      'freezeCount': b.freezeCount,
      'freezeLayers': b.freezeLayers,
      'stealTopTier': b.stealTopTier,
      'lockStockSeconds': b.lockStockSeconds,
      'enrageAtHalf': b.enrageAtHalf,
      'rubbleCount': b.rubbleCount,
      'impoundSeconds': b.impoundSeconds,
      'taintCards': b.taintCards,
      'devolveLevels': b.devolveLevels,
      'shieldCycle': b.shieldCycle,
      'shieldDuration': b.shieldDuration,
      'glueSeconds': b.glueSeconds,
      'holeSeconds': b.holeSeconds,
      'banSeconds': b.banSeconds,
      'fogCells': b.fogCells,
    });

Map<String, dynamic> mergeLevelToJson(LevelDefinition l) => _compact({
      'id': l.id,
      'name': l.name,
      'cols': l.cols,
      'rows': l.rows,
      'stock': l.stockSize,
      'goal': l.goalType.name,
      'target': l.targetTier?.id,
      'targetName': l.targetTier?.name,
      'count': l.targetCount,
      'bias': l.highTierBias,
      'time': l.timeLimitSeconds,
      'moves': l.movesLimit,
      'clear': l.clearLimit,
      'fog': l.fogCells > 0 ? l.fogCells : null,
      'wild': l.wildcards > 0 ? l.wildcards : null,
      'bomb': l.bombs > 0 ? l.bombs : null,
      'obs': l.obstacles.isEmpty
          ? null
          : [
              for (final o in l.obstacles)
                _compact({
                  'type': o.type.name,
                  'c': o.col,
                  'r': o.row,
                  'l': o.type == ObstacleType.ice ? o.layers : null,
                }),
            ],
      // 出牌权重也一并导出 —— 避免各端各写一遍 spawnWeights 逻辑而漂移。
      'spawn': l.spawnWeights(),
      // 参考时间（速通线的软标尺），由同一套期望出牌数推导。
      // 保留 1 位小数 —— 秒级精度足够，还能把小数点后的浮点噪声挡在数据外。
      'par': l.endless
          ? null
          : double.parse(LevelDataGenerator.parSeconds(l).toStringAsFixed(1)),
      'endless': l.endless ? true : null,
      'daily': l.daily ? true : null,
      // 派生标记：省得每个客户端重写一遍三层难度规则。
      'phase': l.endless ? null : LevelDataGenerator.rhythmPhase(l.id),
      'ch': l.endless ? null : LevelProgression.mergeChapterIndex(l.id),
      'ad': LevelProgression.isMergeAdGate(l.id) ? true : null,
      'demon': LevelProgression.isMergeDemon(l.id) ? true : null,
      'bossKey': l.bossKey,
      'bossSpec': l.boss == null ? null : bossToJson(l.boss!),
    });

Map<String, dynamic> parkingLevelToJson(ParkingLevel l, {int? minMoves}) => {
      'id': l.id,
      'name': l.name,
      'rows': l.rows,
      'cols': l.cols,
      // 格子类型压成字符串行（'r' 路 / 'p' 车位 / 'o' 障碍 / 'e' 入口 / 'x' 出口），
      // 比 [[0,0,1],...] 更省也更可读。
      'grid': [
        for (final row in l.grid) row.map(_cellChar).join(),
      ],
      'vehicles': [
        for (final v in l.vehicles)
          _compact({
            'c': v.col,
            'r': v.row,
            'tier': v.tier.id,
            'len': v.length == 1 ? null : v.length,
            'vert': v.length > 1 && v.orientation == ParkingOrientation.vertical
                ? true
                : null,
          }),
      ],
      'target': l.targetTier.id,
      'targetName': l.targetTier.name,
      'minMoves': minMoves ?? l.minMoves,
      'moves': l.movesLimit,
      'time': l.timeLimit,
      'rowHints': l.rowHints,
      'colHints': l.colHints,
    };

String _cellChar(ParkingCellType t) => switch (t) {
      ParkingCellType.road => 'r',
      ParkingCellType.parking => 'p',
      ParkingCellType.obstacle => 'o',
      ParkingCellType.entrance => 'e',
      ParkingCellType.exit => 'x',
    };

/// 车型表 payload（纯函数，不含时间/IO，可被测试直接比对）。
Map<String, dynamic> vehiclesPayload() => {
      'schema': kLevelSchemaVersion,
      'count': VehicleType.values.length,
      'categories': [
        for (final c in VehicleCategory.values)
          {'name': c.name, 'label': c.label},
      ],
      'rarities': [
        for (final r in Rarity.values)
          {'name': r.name, 'label': r.label, 'color': _hex(r.color.toARGB32())},
      ],
      'abilities': [
        for (final a in SpecialAbility.values)
          {'name': a.name, 'label': a.label},
      ],
      'vehicles': [for (final t in VehicleType.values) vehicleToJson(t)],
    };

/// 合成 700 关 payload。注意 [levels] 已含手写 L1-70 + 生成 L71-700，顺序即 id 顺序。
Map<String, dynamic> mergePayload() => {
      'schema': kLevelSchemaVersion,
      'mode': 'merge',
      'count': levels.length,
      'chapters': [
        for (final c in levelChapters)
          {'title': c.title, 'subtitle': c.subtitle, 'startId': c.startId},
      ],
      'phases': LevelDataGenerator.phaseNames,
      'levels': [for (final l in levels) mergeLevelToJson(l)],
    };

class ExportResult {
  final int mergeLevels;
  final int parkingLevels;
  final int bytes;
  final Map<String, int> fingerprints;
  final Map<String, int> byteSizes;

  const ExportResult({
    required this.mergeLevels,
    required this.parkingLevels,
    required this.bytes,
    required this.fingerprints,
    required this.byteSizes,
  });

  @override
  String toString() => '合并 $mergeLevels 关 / 停车 $parkingLevels 关 / '
      '${(bytes / 1024).toStringAsFixed(0)} KB';
}

/// 全量导出。返回统计信息，方便调用方打印/断言。
Future<ExportResult> exportLevels({
  required Directory out,
  bool verbose = true,
}) async {
  if (!out.existsSync()) out.createSync(recursive: true);
  final sw = Stopwatch()..start();
  final fps = <String, int>{};
  final sizes = <String, int>{};
  var total = 0;

  Future<void> write(String name, Object payload, {bool pretty = false}) async {
    final text = pretty
        ? const JsonEncoder.withIndent('  ').convert(payload)
        : jsonEncode(payload);
    final bytes = utf8.encode(text);
    total += bytes.length;
    fps[name] = fnv1a(bytes);
    sizes[name] = bytes.length;
    await File('${out.path}/$name').writeAsBytes(bytes);
    if (verbose) {
      // ignore: avoid_print
      print('  $name  ${(bytes.length / 1024).toStringAsFixed(1)} KB  '
          'fnv=${fps[name]!.toRadixString(16)}');
    }
  }

  // ── 车型表 / 合成关卡 ──
  // 两份 payload 都是纯函数，[test/level_data_sync_test.dart] 直接复用它们
  // 做「磁盘 JSON == 当前代码」的守卫，所以不要在里面读文件/看时间。
  await write('vehicles.json', vehiclesPayload());
  await write('merge_levels.json', mergePayload());

  // ── 停车 800 关 ──
  // 逐关过一遍 solver：既是**可解性闸门**（不可解直接抛错，不允许导出脏数据），
  // 也把 minMoves 校准到「求解器实测值」。
  //
  // 为什么不信生成器自报的 minMoves：反向倒走记录的是「走到的深度」，
  // 与真实最短路在极个别关卡上会差 1（本次全量抓出 1 关）。
  // 下游的 movesLimit / 星级门槛都以这个数为基准，必须是实测值。
  final parking = <Map<String, dynamic>>[];
  final minMovesDrift = <String>[];
  for (var id = 1; id <= ParkingChapters.totalLevels; id++) {
    final lvl = ParkingLevelGenerator.generateOne(id);
    final solverMin = ParkingSolver.minMoves(lvl);
    if (solverMin == null) {
      throw StateError('停车 L$id 不可解 —— 拒绝导出（先修生成器）');
    }
    if (lvl.minMoves != solverMin) {
      minMovesDrift.add('L$id:生成器 ${lvl.minMoves} / solver $solverMin');
    }
    parking.add(parkingLevelToJson(lvl, minMoves: solverMin));
  }
  if (verbose && minMovesDrift.isNotEmpty) {
    // ignore: avoid_print
    print('  ! minMoves 修正 ${minMovesDrift.length} 处：${minMovesDrift.join('，')}');
  }
  await write('parking_levels.json', {
    'schema': kLevelSchemaVersion,
    'mode': 'parking',
    'count': parking.length,
    'chapters': [
      for (final c in ParkingChapters.all)
        {
          'tier': c.tier.id,
          'startId': c.startId,
          'endId': c.endId,
          'title': c.title,
          'subtitle': c.subtitle,
        },
    ],
    'phases': ParkingLevelGenerator.phaseNames,
    'levels': parking,
  });

  // ── 索引 / 自检清单 ──
  await write(
    'index.json',
    {
      'schema': kLevelSchemaVersion,
      'note': '机器生成，勿手改。源：lib/services/level_data_generator.dart + '
          'parking_generator.dart。重新生成：flutter test tool/export_levels_runner.dart',
      'merge': {'count': levels.length, 'file': 'merge_levels.json'},
      'parking': {
        'count': parking.length,
        'file': 'parking_levels.json',
        // 全部经 solver 验证可解；此数为「生成器自报 minMoves 与实测不符」的关卡，
        // 导出时已按实测值修正（非 0 时说明反向倒走的深度记账有偏差，值得一看）。
        'minMovesVerified': true,
        'minMovesCorrected': minMovesDrift,
      },
      'vehicles': {'count': VehicleType.values.length, 'file': 'vehicles.json'},
      'fingerprints': {
        for (final e in fps.entries) e.key: e.value.toRadixString(16),
      },
      'bytes': sizes,
    },
    pretty: true,
  );

  if (verbose) {
    // ignore: avoid_print
    print('  ✓ 完成 ${sw.elapsedMilliseconds} ms，总计 '
        '${(total / 1024).toStringAsFixed(0)} KB');
  }
  return ExportResult(
    mergeLevels: levels.length,
    parkingLevels: parking.length,
    bytes: total,
    fingerprints: fps,
    byteSizes: sizes,
  );
}

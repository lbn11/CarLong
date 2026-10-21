import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/vehicle.dart';

/// 真实车模 PNG 的进程内缓存。
///
/// 文件名唯一真源是 `VehicleType.sprite`（bicycle → bike、sedan → car……），
/// 与 mini 端 `src/art/sprites.ts` 语义一致：**缺图不是错误**，调用方回退 emoji。
///
/// 两张棋盘卡面 / 停车车身都是 Canvas 直接 `drawImageRect`，所以这里缓存
/// 解码后的 `ui.Image`，而不是走 `Image.asset`（Flutter 的图片缓存是异步的，
/// 拿不到同步可画的帧）。
///
/// 解码按 [targetWidth] 降到 384px：原图 1024×1024，50 张全量解码约 30MB，
/// 降到 384 后约 12MB，而卡面实际最大也只有 90 逻辑像素 × 3 倍屏。
class VehicleSprites {
  VehicleSprites._();

  static const String dir = 'assets/vehicles';

  /// 解码宽度（足够 @3x 卡面与 2 格停车车身）
  static const int targetWidth = 384;

  static final Map<String, ui.Image> _images = {};

  /// 图片集变化计数：绘制层（烘焙的 `Picture`）据此失效缓存。
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<void>? _loading;

  /// 全部已命名的车模（50 档各一张，无重复）
  static Set<String> get names => {
        for (final t in VehicleType.values)
          if (t.sprite != null) t.sprite!,
      };

  static int get loadedCount => _images.length;

  static ui.Image? of(VehicleType tier) => byName(tier.sprite);

  static ui.Image? byName(String? name) =>
      name == null ? null : _images[name];

  /// 预载全部车模。重复调用只跑一次；单张失败只打印，不抛。
  static Future<void> preloadAll([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<void> _load(AssetBundle bundle) async {
    var ok = 0;
    for (final name in names) {
      if (_images.containsKey(name)) continue;
      try {
        final data = await bundle.load('$dir/$name.png');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: targetWidth,
        );
        final frame = await codec.getNextFrame();
        _images[name] = frame.image;
        ok++;
      } catch (err) {
        // 车模缺失只降级成 emoji，绝不阻塞启动
        debugPrint('[VehicleSprites] 车模缺失 $name: $err');
      }
    }
    if (ok > 0) revision.value++;
  }

  @visibleForTesting
  static void resetForTest() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _loading = null;
    revision.value = 0;
  }
}

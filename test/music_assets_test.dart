import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:merge_fleet/game/music_player.dart';

/// 「防静音」回归：BGM 曾经因为目录资源不递归 / 文件被挪出打包目录而整体
/// 静音，但从代码和 UI 上完全看不出来（音效正常、只是没背景音乐），很难
/// 第一时间定位。这条测试逐首把资源钉死，漏了就直接红。
void main() {
  group('BGM 资源', () {
    test('每首曲目都有对应音频文件且体积正常', () {
      for (final track in MusicPlayer.allTracks) {
        // FlameAudio 默认前缀是 `assets/audio/`，track 形如 `bgm/home.m4a`。
        final file = File('assets/audio/$track');
        expect(file.existsSync(), isTrue,
            reason: '$track 缺失 → 该场景静音，且不容易被发现');
        expect(file.lengthSync(), greaterThan(10 * 1024),
            reason: '$track 体积异常小，可能是空文件或转码失败');
      }
    });

    test('章节轮换不越界（含负数与越界章号）', () {
      for (var c = -3; c < 40; c++) {
        expect(() => MusicPlayer.mergeTrackFor(c), returnsNormally);
        expect(() => MusicPlayer.parkingTrackFor(c), returnsNormally);
      }
    });

    test('所有曲目都以 m4a 结尾（iOS 不支持 ogg）', () {
      for (final track in MusicPlayer.allTracks) {
        expect(track.endsWith('.m4a'), isTrue,
            reason: '$track 不是 m4a：iOS 的 AVAudioPlayer 不支持 ogg');
      }
    });
  });
}

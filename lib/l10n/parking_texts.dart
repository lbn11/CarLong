// 停车章节文案表。改章节名请同时改 lib/l10n/app_en.arb 与本表。

import 'app_localizations.dart';

/// 停车章节标题，按**起始关 id** 查（章节表是按 id 分段的，比数组下标稳）。
///
/// 用 id 而不是中文字符串当 key：switch 里不出现中文，改名也不会断链。
String? parkingChapterTitleByStartId(AppLocalizations l, int startId) =>
    switch (startId) {
      1 => l.park01Title,
      37 => l.park02Title,
      73 => l.park03Title,
      109 => l.park04Title,
      145 => l.park05Title,
      181 => l.park06Title,
      217 => l.park07Title,
      253 => l.park08Title,
      289 => l.park09Title,
      325 => l.park10Title,
      361 => l.park11Title,
      397 => l.park12Title,
      433 => l.park13Title,
      469 => l.park14Title,
      505 => l.park15Title,
      542 => l.park16Title,
      579 => l.park17Title,
      616 => l.park18Title,
      653 => l.park19Title,
      690 => l.park20Title,
      727 => l.park21Title,
      764 => l.park22Title,
      _ => null,
    };

/// 停车章节副标题（一句话主题）。
String? parkingChapterSubtitleByStartId(AppLocalizations l, int startId) =>
    switch (startId) {
      1 => l.park01Sub,
      37 => l.park02Sub,
      73 => l.park03Sub,
      109 => l.park04Sub,
      145 => l.park05Sub,
      181 => l.park06Sub,
      217 => l.park07Sub,
      253 => l.park08Sub,
      289 => l.park09Sub,
      325 => l.park10Sub,
      361 => l.park11Sub,
      397 => l.park12Sub,
      433 => l.park13Sub,
      469 => l.park14Sub,
      505 => l.park15Sub,
      542 => l.park16Sub,
      579 => l.park17Sub,
      616 => l.park18Sub,
      653 => l.park19Sub,
      690 => l.park20Sub,
      727 => l.park21Sub,
      764 => l.park22Sub,
      _ => null,
    };

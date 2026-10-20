# 小游戏端（路线 A）工程说明

> 目标：iOS / Android 继续用 Flutter 一份代码出包；微信/抖音小游戏另写 TS 渲染层，
> 复用**关卡数据 + 规则 + 数值 + 美术规范**，只重写「画」和「点」。
>
> 为什么不用 MPFlutter：它要锁定自己的 Flutter fork（本项目是 3.41.6），小游戏支持
> 属实验级，等于把商业项目押在社区分支上。为什么不用 Cocos：用户明确要求可读性更低
> 的产物（Cocos 产物是明文 JS，最好读）。

## 1. 工程结构

```
mini/
  build.mjs            esbuild 构建：出单文件 IIFE（小游戏要的就是 game.js）
  index.html           Web 调试宿主（浏览器预览用，不进小游戏包）
  src/
    main.ts            入口：web / wx 两条路径在这里汇合
    app.ts             应用壳：加载数据、选关 ⇄ 单关、主循环、存档
    platform/          ★ 唯一允许碰宿主 API 的层
      env.ts           平台探测（tt 优先于 wx，抖音会注入假 wx）
      runtime.ts       画布 / 读文件 / 存档 / 触摸 / 帧循环 / 安全区
    data/
      types.ts         关卡 JSON 的 schema（对应 shared/levels）
    core/              ★ 纯逻辑，零平台依赖，可在 node 里直接单测
      rng.ts           mulberry32，跨引擎结果一致
      stack.ts         棋盘卡（tier/count/万能/炸弹/冰封/胶水）
      board.ts         1:1 移植 lib/logic/board_logic.dart
      session.ts       一局：牌堆、出牌、选中/移动、目标、限步限时、撤销、连消
    art/               绘制原语与卡面（视觉参数对齐 Flutter StackSprite）
      theme.ts         色板（抄自 lib/theme/app_theme.dart）
      paint.ts         圆角/渐变/文字/药丸/箭头/背景
      card.ts          卡面、能力徽章、空槽、四种障碍
    ui/
      merge_scene.ts   布局 + 渲染 + 输入 + 动画 + 结算面板
      level_select.ts  选关网格
  test/
    board.test.ts      26 条规则用例（对齐 Dart 行为）
  tool/
    shot.mjs           无头 Chrome 截图（验收用，LEVEL=/AUTO= 可指定关卡/自动打完）
```

**分层纪律**：`core/` 不许出现 `window` / `wx` / `document`；`art/` 与 `ui/` 不许出现
`wx.`，平台差异只能通过 `Runtime` 接口进来。违反这条，跨端复用就断了。

## 2. 数据流

```
Flutter: lib/services/*_generator.dart
    │  flutter test tool/export_levels_runner.dart
    ▼
shared/levels/*.json   ← 跨端唯一真源（734KB）
    │  node build.mjs（复制）
    ▼
mini/dist/levels/*.json
    │  runtime.loadText()
    ▼
merge_levels.json → MergeSession → 渲染
```

**关键决定：小游戏端不移植关卡生成器**。1500 关是生成出来的，导出成 JSON 后任何语言
的端都能直接消费；反过来移植生成器要处理 Dart `Random` 跨语言不可复现、停车反向倒走
的工作量预算等一堆坑，纯负收益。

## 3. 与 Flutter 端的一致性纪律

规则改动**必须两边同时改**，否则同一关在 App 和小游戏上表现不同：

| 规则 | Dart | TS |
|---|---|---|
| 棋盘移动/合并/障碍/炸弹 | `lib/logic/board_logic.dart` | `src/core/board.ts` |
| 出牌权重抽取 | `_weightedTier`（整数 roll 逐个减） | `Rng.weighted`（同算法） |
| 卡面视觉 | `StackSprite._ensureFace` | `art/card.ts drawCard` |
| 色板 | `lib/theme/app_theme.dart` | `art/theme.ts` |

`Rng.weighted` 特意用「整数 roll + 逐个减权重」而不是浮点累加：分布一样但序列不同，
会让两端同一关出牌顺序不一致，服务端校验和 bug 回放都做不了。

## 4. 已完成（P0：可玩闭环）

- 合成模式核心规则：移动/合并/升级、交换、万能卡、炸弹引爆、四种障碍（冰/锁/石块/传送门）
- 牌堆：开局整副生成、预览 3 张、点牌堆一键出牌（智能落点优先同档四邻）
- 目标推进、限步、限时、死局判定（牌堆空 && 无同档对）
- 撤销（8 步）、连消（1.6s 窗口）、提示（找一对可合）
- 结算面板（胜负 + 目标进度 + 合并次数 + 最大连消）
- 选关网格 + 进度落档（通关即存，不依赖点「下一关」）
- 自适应布局（竖屏，棋盘按宽/高双约束取小，棋盘+牌堆整体居中）
- 26 条规则单测全绿；41KB 单文件产物

## 5. 待做（按优先级）

**P1 停车模式**（数据已导出，纯渲染色块 + 拖动，工作量最小、独立收益最大）
- 布局：`parking_levels.json` 的 grid/vehicles 直接画；滑动一次 = 沿朝向推到撞墙
- 目标车开出停车位判胜；限步/限时同合成模式
- 移动端体验关键：拖动时的「可走距离」预览线

**P2 Boss 战**（`bossSpec` 已在 JSON 里，但 56 卡组参数需要一并导出）
- 需要先在 `tool/export_levels.dart` 补导出 `bossSpec` 全字段（当前只有 hp/interval/first）
- BossSprite 状态机、7+ 种攻击、预警环、血条

**P3 UI 壳**：首页、图鉴、商店、签到、成就、每日挑战

**P4 微信小游戏真机**
- `game.js` + `game.json` + 分包；`wx.getFileSystemManager().readFileSync` 读关卡 JSON 需要
  验证（读不到就改成构建期内联进 bundle）
- 音频：`wx.createInnerAudioContext`（12 个 wav，需压 AAC）
- 资源：`python3 tool/asset_audit.py --optimize` 实测 26.2MB → 1.8MB
- 抖音同构（`tt` 全局优先），审核资质：软著 + 类目

## 6. 命令

```bash
cd mini
npm install                 # 只装 esbuild + typescript + @types/node
npm run typecheck           # tsc --noEmit
npm test                    # 26 条规则用例
npm run build               # → dist/bundle.js (41KB) + dist/levels (734KB)
npm run dev                 # watch

# 浏览器预览（每次改完必须换端口，否则旧 Service Worker/缓存看不到变化）
cd dist && python3 -m http.server 58880 --bind 127.0.0.1

# 截图验收（可指定关卡 / 自动打完）
LEVEL=600 node tool/shot.mjs
AUTO=1 LEVEL=1 node tool/shot.mjs
```

## 7. 已知问题 / 技术债

- 车模 PNG（17 张 3D 渲染）只在图鉴/停车用；合成棋盘用 emoji —— 与 Flutter `_drawIcon`
  一致。若要让棋盘也用 3D 车模，需要给 50 档车型补齐图（当前 17/50），否则一半图一半 emoji 更乱。
- 检查 `wx.getFileSystemManager().readFileSync` 能否读代码包内 JSON（P4 第一件事）。
- 结算面板目前只有「再来一次 / 下一关」，缺「分享战绩」「看广告续命」。
- 没有音效与震动。
- 横屏/平板未适配（只按竖屏算布局）。

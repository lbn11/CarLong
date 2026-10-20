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
      session.ts       合成一局：牌堆、出牌、选中/移动、目标、限步限时、撤销、连消
      parking.ts       1:1 移植 lib/game/parking_game.dart + parking_solver.dart
                       （滑动规则 + BFS 求解器，求解器同时供「提示」用）
    art/               绘制原语与卡面（视觉参数对齐 Flutter StackSprite）
      theme.ts         色板（抄自 lib/theme/app_theme.dart）
      paint.ts         圆角/渐变/文字/药丸/箭头/背景
      card.ts          卡面、能力徽章、空槽、四种障碍
      parking_draw.ts  停车场地面/车位/石墩/出入口、车辆（车身+车轮+高光）、可达箭头
    ui/
      merge_scene.ts   合成：布局 + 渲染 + 输入 + 动画 + 结算面板
      parking_scene.ts 停车：同上（含目标车卡片、可达轨迹、提示）
      level_select.ts  选关网格 + 模式 tab（合成 / 停车）
  test/
    board.test.ts      26 条合成规则用例（对齐 Dart 行为）
    parking.test.ts    20 条停车规则用例 + 真关卡 minMoves 对齐
  tool/
    shot.mjs           无头 Chrome 截图（MODE=/LEVEL=/AUTO= 指定模式、关卡、自动通关）
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
merge_levels.json   → MergeSession   → 渲染
parking_levels.json → ParkingSession → 渲染
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
| 停车滑动 / 车位独占 / 胜利判定 | `lib/game/parking_game.dart` | `src/core/parking.ts` |
| 停车最短解 | `lib/logic/parking_solver.dart` | `src/core/parking.ts solveParking` |
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

## 5. 已完成（P1：停车模式，与 App 端规则一致）

停车模式的滑动语义**不是**「推到撞墙」，而是 **点哪停哪**：

- 点一下车选中，再点同一行/列的任意格 → 车朝该方向滑到「不越过点击格」的最远可达位置。
  点得越远滑得越远。长条车车头对齐点击格（右/下方向时 anchor 回退 `length-1`）。
- 只有目标档的车能进停车位；胜利 = 目标车车身**任一格**压住车位（长条车压一格即算）。
- 限步关：步数耗尽且无目标车停好 → 判负。限时关：倒计时归零判负。
  死局**不判负**（与 Dart 一致）——只飘一句「没路可走了 · 撤销试试」，因为撤销还在。
- 选中后画**可达轨迹点 + 尽头箭头**：点哪停哪的语义不直观，不画这个玩家只能靠猜。
- 棋盘下方「目标车卡片」吃掉按宽度定尺后的剩余空白，同时给能力标签一个展示位。
- 提示：现算 BFS 取第一步，高亮该车 + 橙色虚线圈出落点，并告知「需要 N 步」。
- 20 条停车单测；其中两条是硬对齐：**抽样的 40 个真关卡，TS 求解步数必须等于
  Dart 导出的 `minMoves`**，且 solver 的解要在 `ParkingSession` 上真实走通并获胜。
  任何规则漂移（占用、车位独占、胜利条件）都会让最短步数变化，直接红。

## 6. 待做（按优先级）

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

## 7. 命令

```bash
cd mini
npm install                 # 只装 esbuild + typescript + @types/node
npm run typecheck           # tsc --noEmit
npm test                    # 46 条规则用例（合成 26 + 停车 20）
npm run build               # → dist/bundle.js (70KB) + dist/levels (734KB)
npm run dev                 # watch

# 浏览器预览（每次改完必须换端口，否则旧 Service Worker/缓存看不到变化）
cd dist && python3 -m http.server 58880 --bind 127.0.0.1

# 截图验收（可指定模式 / 关卡 / 自动通关）
LEVEL=600 node tool/shot.mjs
MODE=parking LEVEL=40 node tool/shot.mjs
AUTO=1 MODE=parking LEVEL=1 node tool/shot.mjs
```

## 8. 已知问题 / 技术债

- 车模 PNG（17 张 3D 渲染）只在图鉴/停车用；合成棋盘用 emoji —— 与 Flutter `_drawIcon`
  一致。若要让棋盘也用 3D 车模，需要给 50 档车型补齐图（当前 17/50），否则一半图一半 emoji 更乱。
- 检查 `wx.getFileSystemManager().readFileSync` 能否读代码包内 JSON（P4 第一件事）。
- 结算面板目前只有「再来一次 / 下一关」，缺「分享战绩」「看广告续命」。
- 没有音效与震动。
- 横屏/平板未适配（只按竖屏算布局）。
- **Dart 侧 `turn` 能力在停车模式实际无效**：`slideTo` 有 turn 分支（长条车四向滑），
  但 `canMoveTo` 的轴约束不看 turn，`moveVehicle → canMoveTo` 必然拒绝。
  TS 端**忠实移植了这个现状**（两端行为必须一致），并在测试里锁住。
  修 Dart 时 `test/parking.test.ts` 那条用例要一起改。
- 停车关卡 cell 在 320px 小屏 6×6 时约 46px，接近手指精度下限；再窄就不好点。
- 合成模式的棋盘点击仍用「精确矩形判定」，点格子边缘 2-3px 缝隙会漏；
  停车模式已改成「就近归格」（长条车几何中心必落在缝隙里，必须修）。合成侧暂未动。

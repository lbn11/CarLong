# 广告系统接入方案

> 状态：**骨架已落地**（`lib/services/ads/`），5 个广告位全部改由 `AdService` 统一发奖，
> 当前 provider = `MockAdProvider`（模拟播放 0.7s 后发奖）。
> 真实 SDK 接入 = 换一行 provider + 平台配置 + 合规材料，业务代码零改动。
>
> 关联文档：[monetization_design.md](monetization_design.md)（变现总览）、
> [mobile_build_checklist.md](mobile_build_checklist.md)（上架清单）。

## 1. 现有广告位（全部已接入 AdService）

| 广告位 | `AdPlacement` | 触发点 | 奖励 | 每日上限 |
|---|---|---|---|---|
| 商店每日福利 | `shopDaily` | 商店「看广告赚金币」 | +100 🪙 | **3 次**（`GameConfig.dailyAdLimit`） |
| 合成续命 | `mergeRevive` | 失败结算「看广告续命」 | +30s / +10 步 / 牌堆+2 / 清 3 组 | 每局 1 次（`MergeGame.revivesLeft`） |
| 合成金币翻倍 | `mergeDouble` | 胜利结算「金币 ×2」 | 本关奖励再发一遍 | 每局 1 次 |
| 停车广告撤销 | `parkingUndo` | 撤销卡不足时 | 回退 3 步 | 无（见 §6 风险） |
| 停车广告提示 | `parkingHint` | HUD 提示按钮 | 下一步最优走法 | 无（见 §6 风险） |

**设计红线（沿用既有产品决定）**：广告只做「降难支援」和「增益」，不做通行证 ——
广告挑战关不看不影响通关，失败续命是官方后路而不是收费墙。

## 2. 已经落地的骨架

```
lib/services/ads/
├── ad_types.dart        AdPlacement（5 个广告位 + 元数据）、AdOutcome、AdResult
├── ad_provider.dart     AdProvider 抽象：initialize / preload / showRewarded / dispose
├── mock_ad_provider.dart 模拟实现（可配 failRate / skipRate / nextOutcome）
└── ad_service.dart      AdService：发奖闸门 + 每日上限 + 跨日清零 + 埋点 + 降级
```

### 2.1 发奖闸门（最重要的一条）

历史模拟实现是「点击即发奖」。接真实 SDK 后**只有 provider 返回
`AdOutcome.rewarded` 才发奖**，其余四种结果一律不发：

| 结果 | 含义 | UI 表现 |
|---|---|---|
| `rewarded` | 完整看完，SDK 奖励回调已触发 | 正常发奖 |
| `skipped` | 玩家中途关闭 | 「广告还没看完，奖励先不发放」 |
| `failed` | 拉取失败 / 超时 / 无填充 | 「广告暂时没加载出来，稍后再试」 |
| `unavailable` | SDK 未初始化 / 家长控制 / 青少年模式 | 「当前环境暂时无法播放广告」 |
| `capped` | 本地每日上限拦截（不烧 SDK 请求） | 「今天的次数已经用完啦」 |

`test/ad_service_test.dart` 用 15 条用例锁死这些路径，其中最关键的是
「skipped/failed 计数不增加」「capped 不再调用 SDK」「provider 抛异常只降级成 failed」。

### 2.2 计数与存档

- 字段：`PlayerData.adDailyDate`（yyyy-MM-dd）+ `adDailyCounts`（广告位 key → 次数）。
- 跨日判断在读的时候做（不写盘、不依赖定时器），零点后第一次 `show` 自动清空。
- 旧存档迁移：`adWatchCount` → `{'shop': n}`；发奖时同步回旧字段，降级安装老版本
  不会白送一轮次数。

### 2.3 埋点

每次请求都记 `ad_impression`（placement / outcome / rewarded / detail），发奖额外记
`ad_watch`（reward）。**两个一起看才能算漏斗**：只看 `ad_watch` 会把「广告没加载出来」
误判成「玩家不想看」。上线前建议把这两个事件接到第三方（Firebase / 神策 / TalkingData）。

## 3. 待决策：SDK 与平台

### 3.1 渠道对比

| 方案 | 适用 | 优点 | 代价 |
|---|---|---|---|
| **穿山甲 CSJ** | 国内 Android 为主 | 国内填充率最高、eCPM 好、Flutter 插件社区方案多（`pangolin_ad_flutter` 等） | 需企业资质；审核严格；隐私合规文档要齐 |
| **优量汇 GDT** | 国内（腾讯系） | 与微信/QQ 流量协同，激励视频成熟 | 填充略低于穿山甲 |
| **GroMore / TopOn 聚合** | 国内多渠 | 瀑布流比价，eCPM 最高 | 接入复杂度高，调试链路长 |
| **AdMob** | 海外 / iOS 海外 | 官方 Flutter 插件（`google_mobile_ads`）质量最高 | **国内基本不可用**（无 Google 服务） |

**建议**：如果首发是国内 Android → 穿山甲单渠道先跑通；iOS 国内可先用 AdMob 兜底
或直接不开广告位；海外版本走 AdMob。**不建议一上来就聚合**：单渠道跑通 &
数据能看，再上聚合比价。

### 3.2 需要确认的三件事

1. **首发平台**（国内 Android / iOS / 双端）—— 决定先接哪个 SDK、走哪套合规材料。
2. **是否有企业资质**（穿山甲/优量汇开户要营业执照 + 软著/版号材料）。
3. **是否接受无后端**：当前没有服务端，激励发奖只能靠客户端回调 + 本地上限。
   风险见 §5.3。

## 4. 接入清单（以穿山甲 + Android 为例）

| 步骤 | 内容 | 注意 |
|---|---|---|
| 1 | `pubspec.yaml` 加 SDK 依赖 | 先用测试广告位 ID 跑通 |
| 2 | `AndroidManifest.xml` 加 `APPID` meta-data + 权限（网络、粗略位置可选） | 缺 APPID 会静默不加载 |
| 3 | **隐私政策弹窗同意后**再初始化 SDK | 国内合规硬红线：不同意前不得初始化、不得预加载 |
| 4 | 实现 `PangleAdProvider extends AdProvider` | `showRewarded` 必须 await 到 `onRewardVerify`/`onAdClose` |
| 5 | `main.dart` 换一行：`AdService.provider = PangleAdProvider(...)` | 其余代码不动 |
| 6 | 真机验证 5 个广告位 + 4 条失败路径 | 用 `MockAdProvider(failRate: 1)` 可本地复现无填充 |
| 7 | iOS 额外：`Info.plist` 加 `SKAdNetworkItems`、ATT 弹窗、`PrivacyInfo.xcprivacy` | iOS 17+ 隐私清单缺项会被拒 |

### 4.1 provider 实现骨架

```dart
class PangleAdProvider extends AdProvider {
  final String appId;
  final Map<AdPlacement, String> slotIds;

  @override String get name => 'pangle';
  @override bool get isMock => false;

  @override
  Future<bool> initialize() async { /* TTAdSdk.init(...) */ }

  @override
  Future<AdResult> showRewarded(AdPlacement placement) {
    final done = Completer<AdResult>();
    // loadRewardVideoAd → show → 回调映射：
    //   onRewardVerify/onRewardArrived → AdResult.granted（先完成，等 onAdClose 再 resolve 也可以）
    //   onAdClose 未触发奖励          → AdResult.skipped
    //   onError / 超时（10s）         → AdResult.failed
    return done.future;
  }
}
```

三条硬要求（写进 provider 注释了）：只在奖励回调里返回 `granted`；`showRewarded`
必须 await 到广告关闭；`initialize` 幂等。

## 5. 经济与风险

### 5.1 金币产出影响

商店福利 3 次 × 100 = **300 🪙/日**，是全游戏最大的单日固定产出（对比：签到 10-80、
每日挑战 150、停车每关 20+10×星）。接真实广告后**不建议提高**这个数：广告收入按
展示计费，金币是成本，300/日已经足够让玩家每天回来一次，再多会让宝箱（150）失去意义。

停车提示/撤销目前**不限次数**，属于放量口子：单个玩家理论上一天能看几十条，
eCPM 好看但玩家体验会崩（每一步都在看广告），也容易被渠道判定「诱导观看」。
建议接入时加软上限：提示 10 次/日、撤销 10 次/日（改 `AdPlacement.meta.dailyCap` 一处即可）。

### 5.2 体验红线

- 不在第 1 关、不在新手前 15 关（停车）/ 74 关（合成）出现任何广告。
- 结算页「看广告 ×2 / 续命」按钮**不高于**主操作按钮的视觉权重（现状已满足）。
- 不用插屏打断当前局；Banner 暂不接（棋盘是全屏核心区域，banner 会挤掉棋盘）。
- 广告失败必须说清原因，不能让玩家以为按钮坏了。

### 5.3 无后端带来的风险

| 风险 | 现状缓解 | 后续 |
|---|---|---|
| 本地改存档刷金币 | 金币只能买 booster/开宝箱，不可提现；单机游戏作弊收益有限 | 接 SSV（AdMob）或穿山甲服务端奖励回调 |
| 重装重置每日次数 | 无 | 需账号体系 |
| 无法远程关广告 / AB 奖励 | `GameConfig.overrides` 已预留，但没有下发通道 | 加轻量配置接口 |

## 6. 落地顺序

| 阶段 | 内容 | 产出 |
|---|---|---|
| **P0（已完成）** | 广告骨架 + 5 个广告位改造 + 15 条测试 + 埋点 | `lib/services/ads/`、`test/ad_service_test.dart` |
| **P1** | 定渠道 → 接 SDK → 换 provider → 真机跑 5 个位 + 4 条失败路径 | 能真实播广告、能发奖 |
| **P2** | 隐私政策/ATT/隐私清单/SDK 初始化时机 + 商店数据安全表单 | 可提审 |
| **P3** | 接第三方埋点，做 eCPM / 填充率 / 完播率 / 人均请求看板 | 能调优 |
| **P4** | 加停车提示/撤销软上限、考虑聚合比价、A/B 奖励 | 收入优化 |

## 7. 待办（本轮未做）

- [ ] 停车提示 / 撤销加每日软上限（需要产品确认数值）
- [ ] `MockAdProvider` 的 release 守卫：建议 `assert` + 启动日志告警，防止误发无广告版本
- [ ] 插屏广告位（是否要在关卡间插入，需产品决策）
- [ ] 未成年人模式：`AdProvider` 层直接返回 `unavailable`（需要先有年龄/家长开关）
- [ ] IAP（金币礼包仍是模拟实现，见 monetization_design.md §2）

# 广告系统接入方案

> 状态：**AdMob 已接入**（发行目标：海外 iOS App Store + Google Play）。
> 服务层 + 真实 provider + 双端平台配置全部落地；平台配置里当前是 **Google 官方
> 测试 App ID / 测试 unit**，上线前替换 5 个值即可（见 §4.2）。
> Web / 桌面自动回落 `MockAdProvider`（条件导入隔离，不影响 web 预览构建）。
>
> 关联文档：[store_launch_overseas.md](store_launch_overseas.md)（上架与合规清单）、
> [monetization_design.md](monetization_design.md)（变现总览）、
> [mobile_build_checklist.md](mobile_build_checklist.md)（编译与签名）。

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
├── ad_types.dart          AdPlacement（5 个广告位 + 元数据）、AdOutcome、AdResult
├── ad_provider.dart       AdProvider 抽象：initialize / preload / showRewarded / dispose
├── ad_provider_factory.dart 按平台选 provider（唯一分支点）
├── mock_ad_provider.dart  模拟实现（Web / MOCK_ADS / 测试）
├── ad_service.dart        发奖闸门 + 每日上限 + 跨日清零 + 埋点 + 降级
└── admob/
    ├── admob_config.dart              unit ID / 合规开关 / 官方测试 ID
    ├── admob_ad_provider.dart         唯一入口（条件导入）
    ├── admob_ad_provider_io.dart      Android/iOS 真实实现（ATT → UMP → SDK）
    └── admob_ad_provider_stub.dart    Web/桌面占位（永远 unavailable）
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

## 3. 渠道决策：AdMob（已定，2026-10-22）

发行目标确定是**海外 iOS App Store + Google Play**，渠道随之锁定 AdMob：

| 方案 | 结论 | 原因 |
|---|---|---|
| **AdMob**（`google_mobile_ads`） | **采用** | 官方 Flutter 插件；海外填充率最高；UMP 自带 GDPR/CCPA；iOS 侧唯一成熟选择 |
| 穿山甲 CSJ | 不用 | 海外无填充；需国内企业资质 |
| 优量汇 GDT | 不用 | 同上，且仅国内流量 |
| GroMore / AppLovin MAX 聚合 | 暂缓 | 单渠道还没跑出 eCPM 基线，聚合只会让问题变模糊（评估提纲见 [ad_mediation_eval.md](ad_mediation_eval.md)） |

后续若要提 eCPM，在 `ad_provider_factory.dart` 加一个分支接聚合 SDK，
5 个广告位的业务代码不用改。

## 4. 接入清单

### 4.1 已落地（本轮完成）

| 项 | 位置 | 说明 |
|---|---|---|
| SDK 依赖 | `pubspec.yaml` | `google_mobile_ads ^5.1.0`、`app_tracking_transparency ^2.0.7` |
| 真实 provider | `admob/admob_ad_provider_io.dart` | 拉取 / 展示 / 补拉 / 超时回收 / 异常降级 |
| 合规顺序 | 同上 `initialize()` | iOS 先 ATT 再 UMP；`canRequestAds == false` 时整个 provider 拒绝请求 |
| 平台隔离 | `admob/admob_ad_provider.dart` | 条件导入，Web 构建不会拖入 SDK（已验证 `flutter build web` 通过） |
| provider 选择 | `ad_provider_factory.dart` | Web/桌面 → Mock；`MOCK_ADS=true` → Mock；移动端 → AdMob |
| 启动时机 | `main.dart` | 首帧后 `postFrameCallback` 初始化（UMP 表单需已挂载 Activity；不再阻塞冷启动） |
| 初始化去重 | `ad_service.dart` | 缓存 `Future<bool>`（并发点击只初始化一次） |
| Android | `AndroidManifest.xml` | `INTERNET` + `AD_ID` 权限、`APPLICATION_ID` meta-data、延迟初始化开关 |
| iOS | `Info.plist` / `Podfile` | `GADApplicationIdentifier`、ATT 文案、`SKAdNetworkItems`、iOS 13.0 |
| 测试 | `test/admob_config_test.dart` | 10 条：unit 合法性、平台区分、生产/回落、合规开关默认值、并发初始化只跑一次 |

### 4.2 上线前必须做的（代码之外）

| # | 事项 | 位置 | 不做会怎样 |
|---|---|---|---|
| 1 | 换 Android 正式 App ID | `AndroidManifest.xml` | 用测试 ID 无收入；改错 ID 启动即崩 |
| 2 | 换 iOS 正式 App ID | `Info.plist` | 同上 |
| 3 | 换 unit ID | `--dart-define=ADMOB_ANDROID_UNIT` / `ADMOB_IOS_UNIT` | 测试 unit 永远不计费 |
| 4 | AdMob 后台发 UMP 消息（GDPR + IDFA） | AdMob → Privacy & messaging | 欧盟不弹同意表单 = 违规 |
| 5 | 部署 `app-ads.txt` | 开发者域名根目录 | 广告库存被劫持，收入流失 |
| 6 | 补全 `SKAdNetworkItems` | `Info.plist` | 目前只有 Google 自家一条，中介渠道归因缺失 |
| 7 | 隐私清单 `PrivacyInfo.xcprivacy` | `ios/Runner/` | iOS 17+ 缺项会被拒 |
| 8 | 隐私政策 URL | 商店列表 + App 内入口 | 双端都拒 |

完整步骤见 [store_launch_overseas.md](store_launch_overseas.md)。

### 4.3 provider 的三条硬约束（已写进实现）

1. **只在 SDK 奖励回调里返回 `granted`**，`onAdDismissed` 但没触发奖励 = `skipped`；
2. `showRewarded` 必须 await 到广告关闭（本项目用 `Completer` + 关闭回调，
   并有 3 分钟兜底超时，防止 SDK 不回调导致 UI 永远转圈）；
3. `initialize` 幂等，且同意未通过时**不发任何广告请求**。

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
| 本地改存档刷金币 | 金币只能买 booster/开宝箱，不可提现；单机游戏作弊收益有限 | 接 AdMob SSV（服务端奖励验证，需后端） |
| 重装重置每日次数 | 无 | 需账号体系（Game Center / Play Games 或自建账号） |
| 无法远程关广告 / AB 奖励 | `GameConfig.overrides` 已预留，但没有下发通道 | Firebase Remote Config（免费，海外首选） |

## 6. 落地顺序

| 阶段 | 内容 | 状态 |
|---|---|---|
| **P0** | 广告服务层 + 5 个广告位改造 + 15 条测试 + 埋点 | ✅ 已完成 |
| **P1** | AdMob provider + 双端平台配置 + 条件导入隔离 + 10 条测试 | ✅ 本轮完成 |
| **P2** | 替换正式 App ID / unit、AdMob 后台配 UMP、app-ads.txt | ⏳ 需账号与后台操作 |
| **P3** | 隐私政策、PrivacyInfo.xcprivacy、商店素材、Data safety / App Privacy | ⏳ 见 store_launch_overseas.md |
| **P4** | 真机跑 5 个位 + 4 条失败路径、提审 | ⏳ 需真机与商店账号 |
| **P5** | 第三方埋点看板、停车提示/撤销软上限、聚合比价、IAP | 待排 |

## 7. 待办（本轮未做）

- [ ] 停车提示 / 撤销加每日软上限（建议各 10 次/日，改 `dailyCap` 一处）
- [ ] `MockAdProvider` 的 release 守卫：release 包若是 mock 应打警告日志
- [ ] 补全 `SKAdNetworkItems`（当前只有 Google 自家一条，需从 AdMob 后台复制）
- [ ] `PrivacyInfo.xcprivacy` 主工程声明（tracking + 访问 API 类型）
- [ ] App 内「广告隐私设置」入口（`ConsentForm.showPrivacyOptionsForm`，仅 required 时显示）
- [ ] 插屏广告位（是否要在关卡间插入，需产品决策）
- [ ] 未成年人模式：`AdProvider` 层直接返回 `unavailable`（需要先有年龄/家长开关）
- [ ] IAP（金币礼包仍是模拟实现，见 monetization_design.md §2）

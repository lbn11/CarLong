# 广告系统接入方案

> 状态：**AdMob 已接入 + 已按海外双端定制**（发行目标：海外 iOS App Store + Google Play）。
> 服务层 + 真实 provider + 双端平台配置全部落地；平台配置里当前是 **Google 官方
> 测试 App ID / 测试 unit**，上线前替换 5 个值即可（见 §4.2）。
> Web / 桌面自动回落 `MockAdProvider`（条件导入隔离，不影响 web 预览构建）。
>
> 本轮定制（2026-10-22 晚）：频次治理三道闸（单点上限 + 单点冷却 + 全局日总量）、
> UMP 隐私设置入口、按广告位拆 unit、预加载接线、无填充静默重试、release mock 守卫。
>
> 关联文档：[admob_setup_guide.md](admob_setup_guide.md)（**建 AdMob 应用与填值手把手**）、
> [store_launch_overseas.md](store_launch_overseas.md)（上架与合规清单）、
> [monetization_design.md](monetization_design.md)（变现总览）、
> [ad_mediation_eval.md](ad_mediation_eval.md)（聚合评估）、
> [ad_benchmark_jcross.md](ad_benchmark_jcross.md)（逆向样本拆解）。

## 1. 现有广告位（全部已接入 AdService）

| 广告位 | `AdPlacement` | 触发点 | 奖励 | 每日上限 | 冷却 |
|---|---|---|---|---|---|
| 商店每日福利 | `shopDaily` | 商店「看广告赚金币」 | +100 🪙 | **3 次**（`GameConfig.dailyAdLimit`） | 8s |
| 合成续命 | `mergeRevive` | 失败结算「看广告续命」 | +30s / +10 步 / 牌堆+2 / 清 3 组 | 每局 1 次（`MergeGame.revivesLeft`） | 3s |
| 合成金币翻倍 | `mergeDouble` | 胜利结算「金币 ×2」 | 本关奖励再发一遍 | 每局 1 次 | 3s |
| 停车广告撤销 | `parkingUndo` | 撤销卡不足时 | 回退 3 步 | **10 次/日** | 12s |
| 停车广告提示 | `parkingHint` | HUD 提示按钮 | 下一步最优走法 | **10 次/日** | 12s |

另有**全局 30 条/日**的总量闸门（跨广告位，见 §2.4）。

**设计红线（沿用既有产品决定）**：广告只做「降难支援」和「增益」，不做通行证 ——
广告挑战关不看不影响通关，失败续命是官方后路而不是收费墙。

## 2. 已经落地的骨架

```
lib/services/ads/
├── ad_types.dart          AdPlacement（5 个位 + 元数据：上限/冷却/unit 后缀）、AdOutcome、AdResult
├── ad_policy.dart         全局策略：跨位日总量、总开关、--dart-define 覆盖
├── ad_provider.dart       AdProvider 抽象：initialize / preload / showRewarded /
│                          privacyOptionsRequired / showPrivacyOptions / dispose
├── ad_provider_factory.dart 按平台选 provider（唯一分支点）+ release mock 守卫
├── mock_ad_provider.dart  模拟实现（Web / MOCK_ADS / 测试），含模拟隐私表单
├── ad_service.dart        发奖闸门 + 三道频次闸 + 隐私入口 + 埋点 + 降级
└── admob/
    ├── admob_config.dart              unit ID（可逐位配）/ 合规开关 / 官方测试 ID
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
| `cooldown` | 距上次展示太近（同样本地拦截） | 「刚看过一条广告，等几秒再来」 |

`test/ad_service_test.dart` 用 24 条用例锁死这些路径，其中最关键的是
「skipped/failed 计数不增加」「capped/cooldown 不再调用 SDK」「provider 抛异常只降级成 failed」。

### 2.2 计数与存档

- 字段：`PlayerData.adDailyDate`（yyyy-MM-dd）+ `adDailyCounts`（广告位 key → 次数）。
- 跨日判断在读的时候做（不写盘、不依赖定时器），零点后第一次 `show` 自动清空。
- 旧存档迁移：`adWatchCount` → `{'shop': n}`；发奖时同步回旧字段，降级安装老版本
  不会白送一轮次数。

### 2.3 埋点

每次请求都记 `ad_impression`（placement / outcome / rewarded / detail），发奖额外记
`ad_watch`（reward）。**两个一起看才能算漏斗**：只看 `ad_watch` 会把「广告没加载出来」
误判成「玩家不想看」。被本地闸门拦下的请求（`capped` / `cooldown`）同样会记一条——
这才能看出「想看的量」和「被上限挡住的比例」。

### 2.4 频次治理：三道闸（本轮定制核心）

一个玩家一天最多能看到多少条广告，由三层共同决定，**全部本地拦截、不烧 SDK 请求**：

| 闸门 | 位置 | 默认 | 作用 |
|---|---|---|---|
| 单点每日上限 | `AdPlacementMeta.dailyCap` | 商店 3 / 停车各 10 / 续命翻倍 null | 防单点刷 |
| 单点冷却 | `AdPlacementMeta.cooldown` | 3-12s | 防连点，也避免「秒关再点」把展示次数刷成无效流量 |
| 全局日总量 | `AdPolicy.globalDailyCap` | **30 条** | 跨位兜底。五道单点上限相加约 33，接近渠道「诱导观看」的风控线 |

为什么之前单点上限不够：5 个位各自封顶后，理论上一天仍是 3+5+5+10+10 ≈ 33 条。
真实广告 15-30 秒一条，33 条 ≈ 每天 10-15 分钟纯广告，这个量级在新账号上很容易
被 AdMob 判定异常。加上全局 30 条后，最坏情况也可控。

`AdPolicy.adsEnabled = false`（或 `--dart-define=ADS_DISABLED=true`）可整体停广告，
审核期/活动期不需要发版。

### 2.5 隐私设置入口（合规硬门槛）

UMP 的 `PrivacyOptionsRequirementStatus.required` 表示**必须**在 App 内提供
随时可撤回广告同意的入口。缺失在欧盟区属于明确不合规（可被拒审/下架）。

- `AdProvider.privacyOptionsRequired()` / `showPrivacyOptions()` 收在 provider 层，
  UI 不认识 SDK；
- AdMob 实现走 `ConsentInformation.getPrivacyOptionsRequirementStatus()` +
  `ConsentForm.showPrivacyOptionsForm()`，表单关闭后重读 `canRequestAds()`
  （玩家撤回同意后，`show()` 会自然降级成 `unavailable`）；
- 入口位置：**首页右上角设置弹窗**里的「隐私设置与广告偏好」。不占首屏权重，但永远可达；
- 不要求时给一句「当前地区无需设置」，不留点了没反应的按钮。

> 坑：**不要**在表单关闭回调里判断 `required` 然后递归再弹一次——`required`
> 的意思是「需要一个入口」，不是「需要再弹一次表单」，那样会死循环。

入口实拍：`docs/preview/ad_settings.png`（首页右上角设置 → 隐私设置与广告偏好）。

### 2.6 加载体验（预加载 + 静默重试）

| 手段 | 位置 | 效果 |
|---|---|---|
| 进页预加载 | 商店 / 合成 / 停车 三屏 `initState` | 把「点广告 → 起播」的 2-5 秒等待压到 0 |
| 展示后补拉 | `AdMobAdProvider.preload` | 连看两条不用重新等 |
| 无填充静默重试 | `AdMobAdProvider._take` | 600ms 后重拉一次，吃掉 adapter 刚 init / 网络切换导致的瞬时 no-fill |

预加载失败不提示、不阻塞：真的点了会再拉一次。

### 2.7 广告真实性：三态与上架闸门

「接了广告」不等于「在赚钱」。这块最容易出的问题不是崩溃，而是**以为在放真广告、
其实在放测试广告**——画面正常、日志正常、收入恒为 0。所以把「真实性」做成了一等公民：

| 状态 | `isMock` | `usesTestInventory` | 有画面 | 有收入 | 可上架 |
|---|---|---|---|---|---|
| 演示通道 | true | — | 否 | 否 | **否** |
| 测试广告 | false | true | **是** | 否 | **否** |
| 正式广告 | false | false | 是 | 是 | 是 |

三处可见：

1. **App 内自检**（`ad_diagnostics.dart`）：首页设置弹窗底部一块「广告自检」，
   显示通道状态 / SDK 状态 / 今日总量 / 各广告位剩余。debug·profile 默认显示，
   release 隐藏（`--dart-define=ADS_DIAGNOSTICS=true` 可给 QA 包打开）。
2. **启动日志**：`[ads] 测试广告 · 真 SDK，测试 unit，零收入（admob） · 初始化成功`。
3. **提审前静态闸门**：`python3 tool/check_ads_release.py`

```
AdMob 上架自检
────────────────────────────────────────────
❌ Android APPLICATION_ID        仍是 Google 测试 App ID（ca-app-pub-3940256…）
✅ Android AD_ID 权限            已声明
❌ iOS GADApplicationIdentifier  仍是 Google 测试 App ID（ca-app-pub-3940256…）
✅ ATT 文案                      允许跟踪可帮助我们…
⚠️  SKAdNetworkItems            只有 1 条，需从 AdMob 后台补全完整 partner 列表
✅ iPhone 方向                   仅竖屏
✅ 隐私清单 · 跟踪声明            NSPrivacyTracking = true
────────────────────────────────────────────
通过 7 · 警告 2 · 失败 2
```

**为什么必须是静态检查**：这三种错误单元测试都发现不了（测试里 mock 永远成功），
只能靠发版前读平台配置文件。加 `--strict` 时 WARN 也算失败，提审前跑这一档。

`usesTestUnits` 判的是**生效值**：5 个位 × 双端共 10 个 unit，只要有一个落到
官方测试 unit（含「Android 填了、iOS 留空」这种半配置）就整体判成测试库存。
用 `every()` 判会漏掉半配置——那种包看着配好了，实际半个平台收入是 0。

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
| 合规顺序 | 同上 `initialize()` | **先 UMP 同意、再 iOS ATT**；`canRequestAds == false` 时整个 provider 拒绝请求（ATT 也不弹） |
| 平台隔离 | `admob/admob_ad_provider.dart` | 条件导入，Web 构建不会拖入 SDK（已验证 `flutter build web` 通过） |
| provider 选择 | `ad_provider_factory.dart` | Web/桌面 → Mock；`MOCK_ADS=true` → Mock；移动端 → AdMob |
| 启动时机 | `main.dart` | 首帧后 `postFrameCallback` 初始化（UMP 表单需已挂载 Activity；不再阻塞冷启动） |
| 初始化去重 | `ad_service.dart` | 缓存 `Future<bool>`（并发点击只初始化一次） |
| 频次治理 | `ad_types.dart` / `ad_policy.dart` | 单点上限 + 单点冷却 + 全局 30 条/日，全部本地拦截 |
| 隐私设置入口 | `home_screen.dart` + `admob_ad_provider_io.dart` | 设置弹窗入口；provider 转发 UMP 表单，撤回后自动降级 |
| 预加载 | `shop_screen` / `game_screen` / `parking_screen` | 进页即拉，点下去直接起播 |
| 逐位 unit | `admob_config.dart` | `ADMOB_{ANDROID,IOS}_UNIT_<SHOP\|REVIVE\|DOUBLE\|UNDO\|HINT>` |
| mock 守卫 | `ad_provider_factory.dart` | release 包里若仍是 mock，启动横幅式告警日志 |
| 真实性三态 | `ad_diagnostics.dart` | 演示 / 测试库存 / 正式三态；App 内自检面板 + 启动日志 |
| 上架闸门 | `tool/check_ads_release.py` | 测试 App ID / 测试 unit / 隐私清单 / SKAdNetwork 一次查完，FAIL 退出码 1 |
| iOS 隐私清单 | `ios/Runner/PrivacyInfo.xcprivacy` | NSPrivacyTracking + 3 类采集 + 4 类必需原因 API，已加进 Runner target |
| iOS 竖屏 | `Info.plist` | 只声明 portrait（配合代码里的 `setPreferredOrientations`），iPad 走 `UIRequiresFullScreen` |
| Android | `AndroidManifest.xml` | `INTERNET` + `AD_ID` 权限、`APPLICATION_ID` meta-data、延迟初始化开关 |
| iOS | `Info.plist` / `Podfile` | `GADApplicationIdentifier`、ATT 文案、`SKAdNetworkItems`、iOS 13.0 |
| 测试 | `test/admob_config_test.dart` | 16 条：unit 合法性、平台区分、生产/回落、半配置判定、并发初始化只跑一次 |
| 测试 | `test/ad_service_test.dart` / `test/ad_privacy_ui_test.dart` | 24 条：发奖闸门 / 三道频次闸 / 隐私入口 / 埋点；2 条 widget 级入口验证 |
| 测试 | `test/ad_diagnostics_test.dart` | 12 条：三态文案 / 额度文案 / 诊断只读 / 与 mock 区分 |

### 4.2 上线前必须做的（代码之外）

| # | 事项 | 位置 | 不做会怎样 |
|---|---|---|---|
| 1 | 换 Android 正式 App ID | `AndroidManifest.xml` | 用测试 ID 无收入；改错 ID 启动即崩 |
| 2 | 换 iOS 正式 App ID | `Info.plist` | 同上 |
| 3 | 换 unit ID | 逐位 `--dart-define=ADMOB_ANDROID_UNIT_SHOP=...`（也可用 `ADMOB_ANDROID_UNIT` 一位通吃） | 测试 unit 永远不计费 |
| 4 | AdMob 后台发 UMP 消息（GDPR + IDFA） | AdMob → Privacy & messaging | 欧盟不弹同意表单 = 违规 |
| 5 | 部署 `app-ads.txt` | 开发者域名根目录 | 广告库存被劫持，收入流失 |
| 6 | 补全 `SKAdNetworkItems` | `Info.plist` | 目前只有 Google 自家一条，中介渠道归因缺失 |
| 7 | 隐私政策 URL | 商店列表 + App 内入口 | 双端都拒 |
| 8 | 跑一遍 `python3 tool/check_ads_release.py --strict` | 仓库根目录 | 测试 App ID / 测试 unit 会被打进包，收入恒为 0 且查不出来 |

> 隐私清单 `ios/Runner/PrivacyInfo.xcprivacy` 已落地并加入 Runner target，
> iPhone/iPad 竖屏也已与代码对齐，这两项不用再手动做，闸门会一起校验。

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

停车提示/撤销原本**不限次数**，属于放量口子：单个玩家理论上一天能看几十条，
eCPM 好看但玩家体验会崩（每一步都在看广告），也容易被渠道判定「诱导观看」。
**本轮已收口**：各 10 次/日 + 12 秒冷却 + 全局 30 条/日；弹窗里直接显示
「今日还剩 N 次」，次数用完按钮置灰（比点下去才被拒更体面）。

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
| **P5** | 频次治理（三道闸）+ 隐私设置入口 + 预加载 + 逐位 unit + mock 守卫 | ✅ 本轮完成 |
| **P6** | 第三方埋点看板、聚合比价、IAP | 待排 |

## 7. 待办

- [x] 停车提示 / 撤销每日 10 次 + 12s 冷却（`AdPlacementMeta` 一处配置）
- [x] `MockAdProvider` 的 release 守卫（release 包打横幅告警日志）
- [x] App 内「隐私设置」入口（`showPrivacyOptionsForm`，仅 required 时显示）
- [x] 全局日总量闸门（30 条/日，`AdPolicy` 可 `--dart-define` 覆盖）
- [x] 进页预加载 + 无填充静默重试
- [x] `PrivacyInfo.xcprivacy` 主工程声明（tracking + 3 类采集 + 4 类访问 API，已进 Runner target）
- [x] 广告真实性三态 + App 内自检面板 + 启动日志
- [x] 上架静态闸门 `tool/check_ads_release.py`
- [x] 同意顺序修正为「UMP → ATT」（原来是 ATT 先弹）
- [x] iPhone/iPad 只声明竖屏（与代码的 `setPreferredOrientations` 一致）
- [ ] 补全 `SKAdNetworkItems`（当前只有 Google 自家一条，需从 AdMob 后台复制）
- [ ] 插屏广告位（是否要在关卡间插入，需产品决策）
- [ ] 未成年人模式：`AdProvider` 层直接返回 `unavailable`（需要先有年龄/家长开关）
- [x] ~~IAP（金币礼包）~~ → **已删除**：模拟内购（标价不扣款）已移除，本作纯广告变现，见 `monetization_design.md §2`

# JCross 广告系统拆解 · 与我们逐项对照

> 样本：`com.ucdevs.jcross`（Nonograms JCross 分渠道版，正版 `org.popapp.jc`）
> 材料：`~/Desktop/Reverse/`（逆向报告 + 自动分析器 + Kotlin 参考实现）
> 结论只用于**工程选型参考**，不搬运任何代码/资源。

---

## 0. 最重要的一条：它并没有"接一堆聚合"

逆向报告里最有价值的是那句自我修正：

> 仅凭 `com.google.ads.mediation.<net>` 类名把所有网络都算「已接入」是**多报**了。
> 用「该网络自有 SDK 包名是否也出现在 dex」交叉校验后：AdColony / AppLovin /
> Chartboost 的 SDK 在 dex 里 **0 次**，真正打包的只有 **AdMob 自家 + Meta FAN**。

也就是说这套被当成"聚合标杆"的系统，实际形态是：

```
AdMob Mediation（中介框架，Google 自带）
   ├── AdMob 自家需求  ← 主力填充
   └── Meta FAN       ← 唯一一家第三方中介网络
```

**这正是上一轮建议的路线**：AdMob 单渠道 → 加 1-2 家网络，而不是一上来铺 5-8 家。
样本数据直接印证了「聚合」在休闲游戏里的真实规模。

---

## 1. 它做对的四件事

| # | 做法 | 为什么对 |
|---|---|---|
| 1 | 用 AdMob Mediation 而不是自建 waterfall | 中介组、RTB、eCPM 选优全在 Google 后端，客户端零逻辑 |
| 2 | 只接 FAN 一家第三方 | 北美/欧洲 FAN 填充强，接一家就能显著补填充；每多一家都是包体+隐私成本 |
| 3 | 五种广告形式都备着 | Banner 大厅常驻、插屏关卡间、激励换资源、原生嵌列表——**按场景选形式**，不是全塞进一个界面 |
| 4 | 变现基础设施全用 SDK 原生 | 见 §2，不是自研 |

---

## 2. 破除三个误解（避免白做功）

| 报告里的说法 | 真相 |
|---|---|
| 「离线事件缓冲 `AdMobOfflineBufferedPings.db`」「智能定价 `ADMOB_SMART_PRICING_SCORE`」「可见性监控 `AdViewabilityMonitor`」「成本信号 `ADMOB_COST`」 | **全是 GMA SDK 内部类名**，只要接了 AdMob 就自动有，不需要写一行代码。我们的接入已经自带这些 |
| 「FAN 用 DexClassLoader 动态加载 5.2MB dex，缩小主包」 | **不能抄**。Google Play「Device and Network Abuse」政策禁止加载 Play 分发之外的可执行代码（含 assets 里的 dex）。这个样本本身是**分渠道改包版**，不是官方 Play 形态。抄了就是拒审/下架 |
| 「五种广告形式全支持 = 广告系统完整度高」 | 形式多不等于变现好。我们是全屏棋盘游戏，Banner 会直接挤掉棋盘，原生广告没有合适容器。真正该加的是**激励插屏**（见 §4.3） |

---

## 3. 与我们逐项对照

| 维度 | JCross | CarLong 现状 | 判断 |
|---|---|---|---|
| 中介层 | AdMob Mediation | AdMob（`google_mobile_ads` 5.1.0） | ✅ 同架构，已对齐 |
| 第三方网络 | FAN 一家 | 0 家 | 下一步加 FAN（§5） |
| 广告形式 | Banner / 插屏 / 激励 / 激励插屏 / 原生 | 5 个位全是激励视频 | 差异化选择，见 §4.3 |
| 同意管理 | UMP + DMA consent 表 + Firebase consent mode | UMP（GDPR + IDFA） | 缺「隐私设置」入口，见 §4.1 |
| 初始化时机 | Application / Splash，同意后初始化 | 首帧后 `postFrameCallback`，同意后初始化 | ✅ 等价 |
| 预加载 | `load()` 常驻一条 ready | 展示后自动补拉下一条 | ✅ 等价 |
| 频控 | 靠 SDK 内部质量信号 | 商店 3/日，其余**无上限** | ⚠️ 有风险，见 §4.2 |
| 内购 | `AFMC_PREMIUM`（疑似去广告/高级） | 模拟实现 | 下一阶段（广告+去广告是海外标准组合） |
| 离线缓冲/可见性/智能定价 | SDK 自带 | 同样自带 | ✅ 不用做 |

---

## 4. 现在就能抄的三件事（不依赖任何外部账号）

### 4.1 App 内「隐私设置」入口（合规缺口，优先级最高）

UMP 要求：当 `PrivacyOptionsRequirementStatus == required` 时，App 内必须有让用户
**撤回/修改同意**的入口。我们现在只有首次启动的同意弹窗，没有入口——欧盟区属于不合规。

- 落点：目前没有独立设置页（首页 L3 只有签到/成就/图鉴/商店），需要产品决策放哪：
  商店页底部、图鉴页 AppBar、或首页加第 5 个方块。
- 实现：在 `AdProvider` 加 `Future<void> showPrivacyOptions()`（stub 空实现），
  AdMob 侧调 `ConsentForm.showPrivacyOptionsForm(...)`；UI 侧先查
  `ConsentInformation.instance.getPrivacyOptionsRequirementStatus()`，
  只有 `required` 才显示按钮。
- 工作量：provider 3 个文件各加一个方法 + 一个按钮，半天。

### 4.2 广告冷却与软上限

它的频控靠 SDK 内部质量信号（`AdUnitQualitySignals(priorClickCount=...)`），
但那是 Google 侧的，产品层仍应有自己的节奏：

- 停车提示 / 撤销现在**不限次数**（`dailyCap` 为 null），建议各 10 次/日；
- 两次激励视频之间最短间隔 15-20s（防连点、防渠道判「诱导观看」）；
- 这两项都只改 `ad_types.dart` 的 `dailyCap` + `AdService.show` 一处判断。

### 4.3 把「金币 ×2」换成激励插屏（rewarded-interstitial）

JCross 五种形式里唯一对我们有增量价值的是 **Rewarded-Interstitial**：
非用户主动触发、但看完给奖励。它比插屏友好（有奖励），比激励视频轻（不用用户主动点）。

- 我们现在的 `mergeDouble`（胜利结算「金币 ×2」）本质就是「非主动触发的激励」，
  用 rewarded-interstitial 更自然，且不打断玩家进入下一步操作。
- 代码侧只需在 `AdPlacement` 加一个 `kind` 区分展示形式，provider 里换成
  `RewardedInterstitialAd.load`——但**没有真实 unit 之前别改**，属于上线后 A/B 项。

---

## 5. 加 FAN 的真实成本（比想象中小很多）

**关键结论：走 AdMob Mediation 加网络，Dart 代码零改动。**

因为广告还是由 `RewardedAd.load(adUnitId: ...)` 发起，中介组在 Google 后端决定
由哪个 adapter 出价并渲染。不需要新写 provider、不需要碰 5 个广告位的业务代码。

### 5.1 Android

`android/app/build.gradle.kts` 的 `dependencies` 加：

```kotlin
// Meta Audience Network 的 AdMob 中介适配器
// 版本必须查官方兼容矩阵（末位是 revision，形如 6.x.y.0），写死会编译失败：
// https://developers.google.com/admob/android/mediation/meta
implementation("com.google.ads.mediation:facebook:<adapter-version>")
```

### 5.2 iOS

`ios/Podfile` 的 `target 'Runner'` 里加：

```ruby
pod 'GoogleMobileAdsMediationFacebook'
```

### 5.3 后台（这一步才是真正的工作量）

1. Meta for Developers 建应用 → 加 Audience Network → 拿 **Placement ID**
2. AdMob 后台 → Mediation → 建中介组 → 广告来源选 **Meta Audience Network**
   → 填 Placement ID + 对应 unit → **优先选 Bidding（实时竞价）**，Waterfall 作为兜底
3. 中介组绑到我们 5 个 unit 上（可以先只绑 `shopDaily` 做灰度）

### 5.4 验证

- Android 日志里 `MobileAds.initialize` 的 `adapterStatusMap` 应出现 `facebook`
  的 `READY`（我们的 `AdMobAdProvider.initialize` 目前没打这个，加一行日志即可）
- 关掉 AdMob 自家需求（中介组里把 AdMob 出价设最低）能看到 FAN 填充

### 5.5 代价

| 项 | 成本 |
|---|---|
| 包体 | Android +3-5MB，iOS +8-15MB |
| 隐私表单 | App Privacy / Data safety 必须加「Meta」作为第三方 SDK |
| consent | FAN 在欧盟需要 TCF 字符串，UMP 已负责传；不要额外接 FAN 自己的 CMP（会冲突） |
| 调试 | 比单渠道多一层「中介组是否绑对 unit」的排查 |

---

## 6. 顺带：那份 Kotlin 参考实现有两个 bug，别照抄

| 位置 | 问题 | 正确做法 |
|---|---|---|
| `RewardedAdHelper.show()` | 先 `ad.show()` 再设 `fullScreenContentCallback`（第 58-66 行）→ 可能错过 `onAdDismissedFullScreenContent`，UI 永久转圈 | **先设回调再 show**（我们的 Flutter 实现顺序是对的） |
| `ConsentManager.loadAndShowConsentForm()` | show 完判断 `privacyOptionsRequirementStatus == REQUIRED` 就**递归再弹一次**（第 74-78 行）→ 无限循环。REQUIRED 的含义是「需要提供隐私设置入口」，不是「需要再弹表单」 | 用 `ConsentForm.loadAndShowConsentFormIfRequired`，或只判 `canRequestAds()` |

---

## 7. 结论与建议顺序

| 顺序 | 动作 | 依赖 | 收益 |
|---|---|---|---|
| 1 | AdMob 单渠道上线，拿真实填充率/eCPM | 账号 + 5 个 ID | 基线数据（没有它无法判断聚合是否有用） |
| 2 | 加 FAN adapter（Bidding） | Meta Placement ID + 中介组 | 填充率通常 +10-20% |
| 3 | 补隐私设置入口 + 广告冷却/上限 | 无 | 合规 + 防判「诱导观看」 |
| 4 | 金币 ×2 换激励插屏 A/B | 需真实数据 | 结算页体验 |
| 5 | 再评估第三家（AppLovin / Unity） | 上一步有收益才做 | 边际收益递减 |

> JCross 的样本已经回答了「要不要一上来就铺 5-8 家」：**没有**。它自己也只有一家第三方。

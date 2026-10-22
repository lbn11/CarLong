# 聚合广告（Mediation）评估 · 调研提纲

> 用途：明天调研商业游戏的广告系统时按这份清单看，回来直接对照决策。
> 关联：[ad_integration_plan.md](ad_integration_plan.md)、
> [store_launch_overseas.md](store_launch_overseas.md)。

---

## 1. 先分清层级（这是最容易混的一点）

「聚合」不是另一家广告平台，而是**中介层**：它同时向多个「需求方」要广告，谁出价高放谁。

```
        ┌─────────────── 中介层（Mediation）───────────────┐
        │  AdMob Mediation / AppLovin MAX / LevelPlay      │
        │  / TopOn / TradPlus                              │
        └───────┬──────────┬──────────┬──────────┬─────────┘
                │          │          │          │
             AdMob      AppLovin   Unity Ads   Mintegral / Pangle(海外)
           (需求方)      (需求方)    (需求方)      (需求方)
```

关键结论：**AdMob 既是需求方、也自带中介能力**。所以现在接的
`google_mobile_ads` 不是「和聚合二选一」，而是**任何聚合方案里都必然保留的一层**
（它通常贡献最大的一块填充）。现在这层不会白做。

---

## 2. 什么时候才值得上聚合

| 现状 | 是否需要聚合 |
|---|---|
| 还没上线，没有真实 eCPM / 填充率数据 | **不需要**。先跑 AdMob 单渠道拿基线 |
| 激励视频请求填充率 < 70% | 需要（长尾需求方补填充） |
| 单日广告展示 < 5k | 不需要，聚合的报表噪声大于收益 |
| 单日展示 > 2 万且有稳定留存 | 值得做，聚合通常能提 15-40% eCPM |
| 想按地区/时段调瀑布流 | 需要（但先有量再调） |

> 聚合的价值是「比价 + 补填充」，不是「凭空变多」。没有量的前提下，多接 5 家
> 只会让「为什么收入低」更难定位。

---

## 3. 调研清单（看别人游戏时按这 8 条看）

### 3.1 反推对方接了哪些 SDK（最快入口）

| 平台 | 方法 |
|---|---|
| Android | `unzip -l game.apk \| grep -iE "applovin\|ironsource\|unity3d\|mintegral\|bytedance\|pangle"`；再看 `AndroidManifest.xml` 里的 `<provider>` 与 meta-data |
| iOS | 解压 ipa，看 `Payload/*.app/Frameworks/` 下的框架名（`AppLovinSDK.framework`、`UnityAds.framework`、`IronSource.framework`、`GoogleMobileAds.framework`） |
| 双端通用 | **看商店隐私标签 / Data safety 里列的第三方 SDK 名单**——这一条最省事，等于官方公开了广告栈 |

### 3.2 行为层要观察的 8 件事

- [ ] 首次启动有没有弹同意表单？弹窗风格像 Google UMP、AppLovin CMP、还是自绘？
- [ ] 从点「看广告」到视频起播要多久？（>2s 说明没预加载，是体验硬伤）
- [ ] 飞行模式下点广告，提示是「无网络」还是「暂无广告」？（能看出有无多需求源兜底）
- [ ] 同一关卡连续看两次广告之间有无冷却？（防刷 + 渠道合规）
- [ ] 失败后是否自动换渠道重试？
- [ ] 结算页广告按钮的视觉权重 vs 主按钮（是否诱导）
- [ ] 有没有 banner / 插屏？插屏出现在哪些节点（关卡间 / 重开时）
- [ ] 有没有「移除广告」内购？（海外休闲游戏常见，$2.99-4.99）

### 3.3 报表侧（如果对方公开或你能问到）

- 用哪家做归因（AppsFlyer / Adjust / Firebase）？
- 奖励是否走 SSV（服务端回调）？—— 单机小游戏通常不做，作弊风险可接受。
- eCPM 是看聚合后台还是各家后台分别看？

---

## 4. 聚合的真实成本（决定要不要上）

| 成本 | 说明 |
|---|---|
| **包体** | 每多一个 SDK +3~15MB，5 家容易把包从 30MB 推到 100MB+（影响下载转化） |
| **隐私表单** | iOS App Privacy / Play Data safety **必须逐家声明**，漏一家就是审核风险 |
| **consent 冲突** | 聚合自带 CMP（MAX 有 MAX CMP、LevelPlay 有），和 Google UMP 二选一会互相打断；必须只留一套 |
| **初始化顺序** | 聚合 SDK → 同意 → 各家 adapter 初始化 → 首次预载，顺序错会导致「有量无填充」 |
| **调试成本** | 聚合后台的 test mode、各 adapter 版本兼容矩阵，出问题的定位链路比单渠道长 3 倍 |
| **结算** | 每家起付门槛独立（$100 / $50 不等），小额分散 |

---

## 5. 我们的落地路径（代码已就绪）

先区分两种「聚合」，成本差一个数量级：

| 方式 | 代码改动 | 说明 |
|---|---|---|
| **AdMob Mediation 加网络**（FAN / Unity / AppLovin adapter） | **Dart 零改动**，只加原生依赖 + 后台中介组 | 广告仍由 `RewardedAd.load` 发起，中介组在后端决定谁出价 |
| 换成 AppLovin MAX / LevelPlay 整套 SDK | 新写一个 `AdProvider` + factory 分支 | MAX 有自己的一套 API 与同意管理 |

第一种才是推荐路径（JCross 就是这个形态，实测见
[ad_benchmark_jcross.md](ad_benchmark_jcross.md)）。

`AdProvider` 抽象 + `ad_provider_factory.dart` 单点分叉，意味着换整套 SDK 时：

1. 新写一个 `MaxAdProvider`（或 `LevelPlayAdProvider`）实现 `initialize /
   preload / showRewarded / dispose`；
2. `main.dart` 里 `AdService.provider = createAdProvider()` 保持不变，
   在 factory 加一个分支（或用 `--dart-define=AD_NETWORK=max` 切换）；
3. **5 个广告位的业务代码一行都不用改**；
4. 想在埋点里区分「哪个渠道成交」，把 `AdResult.detail` 写成
   `source=applovin,ecpm=...`——`ad_impression` 已经把 detail 落进存档了。

聚合内部的第一层建议仍是 AdMob adapter（填充最稳），其余按地区补：
北美补 AppLovin / Meta，日韩补 Unity / LINE，东南亚补 Mintegral / Pangle。

---

## 6. 决策表（调研后填）

> **JCross 实测样本**（`com.ucdevs.jcross`，2026-10-22 静态逆向）：
> 它是 AdMob Mediation + **Meta FAN 一家**，AdColony/AppLovin/Chartboost 的 SDK
> 在 dex 里 0 次出现（只是聚合核心的注册表字符串）。详见
> [ad_benchmark_jcross.md](ad_benchmark_jcross.md)。
> 也就是说「很多游戏用聚合」的真实形态 ≈ 本表 B + 1-2 家 adapter。

| 选项 | 适用 | 决策 |
|---|---|---|
| A. 维持 AdMob 单渠道 | 上线前 3 个月，先拿基线 | 当前状态 |
| B. AdMob Mediation + 1-2 家 adapter | 想补填充、不想换主 SDK | **推荐下一步（JCross 同款）** |
| C. AppLovin MAX | 追求 eCPM、能接受包体 + 调试成本 | 待评估 |
| D. ironSource LevelPlay | 已有 Unity 生态 | 不适用（本项目 Flutter） |
| E. TopOn / TradPlus | 国内团队、需要中文支持 | 待评估 |

> 建议顺序：**A 跑 2-4 周拿到 eCPM/填充率 → 若填充 <70% 或想提 eCPM 再上 C 或 B**。
> 不要一上线就聚合：出问题时无法判断是「渠道没量」还是「聚合没配对」。

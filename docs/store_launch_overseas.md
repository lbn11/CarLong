# 海外发行清单（App Store + Google Play）

> 目标：**只发海外**（iOS App Store / Google Play），不含国内安卓商店。
> 变现：激励视频（AdMob）+ 后续 IAP；当前无后端，存档纯本地。
>
> 关联文档：[ad_integration_plan.md](ad_integration_plan.md)（广告实现）、
> [mobile_build_checklist.md](mobile_build_checklist.md)（编译与签名）、
> [monetization_design.md](monetization_design.md)（变现数值）。

---

## 0. 一句话结论

海外发行 = **AdMob 单渠道**（不是穿山甲/GroMore）。理由：

| 维度 | AdMob | 穿山甲 / 优量汇 |
|---|---|---|
| 海外填充率 | 高（Google 需求池） | 近乎为零（国内需求池） |
| iOS 支持 | 官方 SDK + UMP + ATT 全套 | iOS 侧基本没有海外量 |
| Flutter 插件 | 官方维护 `google_mobile_ads` | 社区插件，长期无人维护 |
| 审核/合规 | UMP 自带 GDPR/CCPA 表单 | 需自己实现国内隐私弹窗 |
| 结算 | 满 $100 电汇/Payoneer | 需国内企业资质 |

聚合（AppLovin MAX / ironSource）**先不做**：单渠道跑通、拿到真实 eCPM 与填充率
再上聚合，否则调不出「是聚合变好还是渠道本来就差」。

---

## 1. 账号与资质（并行启动，最快也要 3-7 天）

| 项目 | 费用 | 说明 | 阻塞什么 |
|---|---|---|---|
| Apple Developer Program | $99/年 | 个人或公司账号；公司账号需 D-U-N-S 号（免费申请，1-2 周） | iOS 一切 |
| Google Play 开发者账号 | $25 一次性 | 2023 年后个人账号需**身份验证 + 20 台设备测试 14 天**才能发正式版 | Android 一切 |
| AdMob 账号 | 免费 | 用同一个 Google 账号开通；App 上线前可先建「测试应用」 | 广告收入 |
| 开发者网站/域名 | ~$10/年 | **必需**：放隐私政策页 + `app-ads.txt` | 隐私政策 URL、AdMob 验证 |
| Payoneer / 电汇账户 | 免费 | AdMob 满 $100 结算 | 收款 |

> **个人 vs 公司**：个人账号在 App Store 上会显示真实姓名（除非用公司名）。
> 若在意品牌，走公司账号 + D-U-N-S。
>
> **Google Play 个人账号的 14 天/20 人封闭测试**是最容易被忽略的一条，
> 排期时先跑起来，别等包都做完了才发现还要等两周。

---

## 2. 广告接入（代码已就绪，剩下是后台配置）

### 2.1 代码侧已完成

| 文件 | 作用 |
|---|---|
| `lib/services/ads/admob/admob_config.dart` | unit ID / 合规开关 / 测试 ID 常量 |
| `lib/services/ads/admob/admob_ad_provider_io.dart` | AdMob 实现（ATT → UMP → SDK → 拉取/展示） |
| `lib/services/ads/admob/admob_ad_provider_stub.dart` | Web/桌面占位（条件导入隔离） |
| `lib/services/ads/ad_provider_factory.dart` | 按平台选 provider（唯一分支点） |
| `lib/main.dart` | 首帧后初始化（不阻塞启动，UMP 表单需要已挂载 Activity） |

平台配置已写（**当前全是 Google 官方测试 ID**）：

- `android/app/src/main/AndroidManifest.xml`：`INTERNET`、`AD_ID` 权限 +
  `com.google.android.gms.ads.APPLICATION_ID`
- `ios/Runner/Info.plist`：`GADApplicationIdentifier`、
  `NSUserTrackingUsageDescription`、`SKAdNetworkItems`（含 Google 标识）
- `ios/Podfile`：`platform :ios, '13.0'`

### 2.2 上线前必须替换的 5 个值

| # | 位置 | 现值（测试） | 换成 |
|---|---|---|---|
| 1 | AndroidManifest `APPLICATION_ID` | `ca-app-pub-3940256099942544~3347511713` | AdMob 后台 Android 应用的 App ID |
| 2 | Info.plist `GADApplicationIdentifier` | `ca-app-pub-3940256099942544~1458002511` | AdMob 后台 iOS 应用的 App ID |
| 3 | `--dart-define=ADMOB_ANDROID_UNIT` | 测试 unit | Android 激励视频 unit |
| 4 | `--dart-define=ADMOB_IOS_UNIT` | 测试 unit | iOS 激励视频 unit |
| 5 | `ADMOB_*_UNIT`（分广告位） | 共用 | 建议 5 个广告位各建一个 unit |

> 测试 ID 忘了换 = **零收入**且 AdMob 后台会报「无效流量」。本项目
> `AdMobConfig.usesTestUnits` 会返回 true，可以在启动日志里打一条警告。
>
> 构建命令示例：
> ```bash
> flutter build appbundle --release \
>   --dart-define=ADMOB_ANDROID_UNIT=ca-app-pub-XXXX/YYYY
> flutter build ipa --release \
>   --dart-define=ADMOB_IOS_UNIT=ca-app-pub-XXXX/ZZZZ
> ```

### 2.3 AdMob 后台要做的 4 件事

1. **建应用 + 建广告单元**（激励视频，5 个位各一个）。
2. **配 UMP 消息**：Privacy & messaging → GDPR（欧盟）+ IDFA（iOS 全球）。
   不配的话 `ConsentForm.loadAndShowConsentFormIfRequired` 永远不弹，
   欧盟用户会以「未同意」状态请求个性化广告 → 违规。
3. **app-ads.txt**：把 AdMob 给的记录放到开发者网站根目录（
   `https://yourdomain.com/app-ads.txt`），并在 App Store / Play 列表填同一个域名。
   不配会被「未授权广告库存」劫持，收入凭空少一截。
4. **测试设备**：真机调试时在日志里搜 `setTestDeviceIds`，把哈希串加到
   `AdMobConfig(testDeviceIds: [...])`，避免自己点广告被算无效流量（会被封号）。

---

## 3. 合规（最容易被拒的一节）

### 3.1 隐私政策页（双端强制）

必须是一个**公网可访问的 URL**（不是 PDF、不是 App 内页面）。至少写清：

- 收集什么：广告标识符（IDFA/GAID）、设备型号、粗略地区、崩溃日志
- 用途：广告投放与归因、防作弊、崩溃分析
- 第三方：Google AdMob（链接到 Google 隐私政策）、Apple/Google 平台
- 用户权利：欧盟 GDPR 撤回同意入口（App 内「隐私设置」按钮，调用
  `ConsentForm.showPrivacyOptionsForm`）、加州 CCPA 拒绝出售
- 儿童：明确「不面向 13 岁以下」，或走家庭政策（见 3.4）
- 联系方式 + 生效日期

> 建议同时在 App 内设置页放「隐私政策」入口（审核员会点）。
> `ConsentForm.showPrivacyOptionsForm` 适合做成「广告隐私设置」按钮，
> 只有 `PrivacyOptionsRequirementStatus.required` 时才显示。

### 3.2 App Store 隐私标签（App Privacy）

| 数据类型 | 是否收集 | 是否用于追踪 | 用途 |
|---|---|---|---|
| 标识符 → 设备 ID（IDFA） | 是 | **是** | 第三方广告 |
| 使用数据 → 广告数据 | 是 | 是 | 第三方广告 |
| 诊断 → 崩溃数据 | 是（如接 Crashlytics） | 否 | App 功能 |
| 购买 → 购买记录 | 是（接 IAP 后） | 否 | App 功能 |

同时确认 `PrivacyInfo.xcprivacy`：`google_mobile_ads` 5.1.0 自带一份，
但**主工程**需要声明 `NSPrivacyTracking = true` + `NSPrivacyTrackingDomains`
（AdMob 的域名），以及 `NSPrivacyAccessedAPITypes`
（`UserDefaults` / `FileTimestamp` 等，Flutter 引擎也会要）。

### 3.3 Google Play Data safety

与 3.2 口径必须一致：

- 收集「设备或其他 ID」→ 用于「广告或营销」→ **共享给第三方** → 传输加密
- 收集「应用活动 → 应用内互动」→ 广告归因
- 提供「用户可以请求删除数据」？单机无账号 → 选「不收集可识别个人身份的数据」，
  但要说明广告 ID 由 Google 处理
- **`AD_ID` 权限已在 Manifest 声明**，Play 会据此校验；声明与实际不符 = 下架风险

### 3.4 年龄分级与儿童政策

| 商店 | 建议分级 | 注意 |
|---|---|---|
| App Store | 4+（无暴力/无赌博） | 若含广告，需要在描述里写「含广告」；4+ 不等于可以投个性化广告 |
| Google Play | Everyone / 3+ | 内容分级问卷里「是否含广告」选是 |

**不要**勾选「面向儿童」（Made for Kids / Kids Category）：一旦进家庭政策，
个性化广告与 IDFA 全部禁用，AdMob 只能投非个性化，eCPM 掉一半。
本作是合成/解谜，按「全年龄但不专门面向儿童」申报即可。

### 3.5 欧盟/英国额外

- **DSA  trader 信息**：App Store Connect 与 Play Console 都要求填写「交易者」
  身份（公司名、地址、电话、邮箱），不填不能在欧盟上架。
- **GDPR 同意**：UMP 表单（§2.3 第 2 条）。
- **DMA**：若后续接第三方支付需另议，当前只有广告，不涉及。

---

## 4. 商店素材

| 项目 | App Store | Google Play |
|---|---|---|
| 图标 | 1024×1024 PNG，**无 alpha** | 512×512 PNG，32-bit |
| 截图 | 6.9"（1320×2868）、6.5"（1284×2778）必填；iPad 若支持也要 | 手机 ≥2 张，16:9 或 9:16，最短边 ≥320px |
| 预览视频 | 可选（15-30s，竖屏） | 可选（YouTube 链接） |
| 描述 | 副标题 30 字 + 描述 4000 字 | 简短说明 80 字 + 完整说明 4000 字 |
| 关键词 | 100 字符，逗号分隔 | 无（靠标题/描述） |

项目可用的生成方式：`tool/` 里的截图脚本 + 真机截图；文案先用中文写，
再出英文版（**海外发行必须英文**，其余语言可后补）。

---

## 5. 技术前置（不满足直接拒）

| 检查项 | 要求 | 本项目状态 |
|---|---|---|
| Android targetSdk | 以 Play Console 提示为准（2026 年新应用需 API 36） | `flutter.targetSdkVersion`，构建时确认 |
| Android 16 KB page size | 目标 Android 15+ 的设备需支持；`zipalign -c -P 16 -v 4 app-release.apk` 校验 | Flutter 3.41 已支持 |
| AAB 格式 | Play 只收 `.aab` | `flutter build appbundle` |
| iOS SDK | 用当年最新 Xcode 构建（Apple 每年春季强制新 SDK） | 需本机 Xcode 验证 |
| 隐私清单 | `PrivacyInfo.xcprivacy` + 主工程 tracking 声明 | 需补（§3.2） |
| ATT 文案 | `NSUserTrackingUsageDescription` 非空 | 已配 |
| 网络权限 | `INTERNET` | 已配 |
| 竖屏锁定 | 商店不校验，但本项目只支持竖屏 | 已锁 |

---

## 6. 审核风险与对策

| 风险 | 触发条件 | 对策 |
|---|---|---|
| 广告过多 / 强制观看 | 玩家不看广告就无法继续 | 现有设计已守住：广告只做降难与增益，挑战关不看也能过 |
| 「诱导观看」 | 用金币/抽奖强诱导 | 奖励文案写「可选支援」，不写「必看」 |
| 儿童广告违规 | 申报为儿童应用却投个性化广告 | 按 §3.4 申报 |
| 缺少隐私政策 | 描述里没有 URL | §3.1 |
| 账号删除要求 | 有账号体系才需要 | 无后端，不涉及 |
| 崩溃 / 白屏 | 缺 AdMob App ID（启动即崩） | 已在 Manifest/Info.plist 配好 |

---

## 7. 排期建议

| 阶段 | 内容 | 产出 |
|---|---|---|
| **P0（已完成）** | 广告服务层 + AdMob provider + 平台配置 + 304 条测试 | 代码可编译可回归 |
| **P1** | 注册开发者账号、AdMob 建应用/单元、配 UMP、app-ads.txt | 能拿到真实 unit ID |
| **P2** | 换 5 个 ID、真机跑 5 个广告位 + 4 条失败路径、补隐私清单 | 广告能真实播放并计费 |
| **P3** | 隐私政策页、商店素材、分级问卷、Data safety / App Privacy | 可提交审核 |
| **P4** | 提审、应对拒审、灰度发布 | 上线 |
| **P5** | 接埋点看板（eCPM / 填充率 / 完播率）、再评估聚合与 IAP | 调优 |

---

## 8. 提交前 Checklist

- [ ] AdMob 两个 App ID + 两个 unit ID 全部替换为正式值（测试 ID 应为 0 处）
- [ ] Android `AD_ID` 权限与 Play Data safety 声明一致
- [ ] iOS `NSUserTrackingUsageDescription` 已本地化（英文必填）
- [ ] `SKAdNetworkItems` 已从 AdMob 后台复制完整列表（当前只有 Google 自家一条）
- [ ] UMP 的 GDPR 消息 + IDFA 消息已在 AdMob 后台发布
- [ ] app-ads.txt 可访问，商店列表填了同域名
- [ ] 隐私政策 URL 公网可开，且 App 内有入口
- [ ] `PrivacyInfo.xcprivacy` 含 tracking 声明与 API 使用说明
- [ ] 关闭所有调试入口（Boss 调试 FAB 已删；确认 release 包无调试按钮）
- [ ] release 包确认 `AdService.usingMock == false`（日志里 provider 应为 `admob`）
- [ ] 真机各跑一遍：看广告成功 / 中途关闭 / 飞行模式无填充 / 每日上限

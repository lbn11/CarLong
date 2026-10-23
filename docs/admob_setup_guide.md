# AdMob 建应用与填值：手把手指南

> 目标：从「零 AdMob 账号」到「真机看到正式广告并且会计费」，一次走完不返工。
> 预计 60-90 分钟（其中 40 分钟是后台点点点 + 等审核）。
> 代码侧只有一条命令（见 §3），不要手改文件。

## 0. 先搞清顺序（顺序错了会白做一遍）

```
AdMob 账号 + 付款资料
      ↓
AdMob 建 2 个应用（Android / iOS）→ 拿 2 个 App ID
      ↓
每个应用建 5 个激励视频 unit → 拿 10 个 unit ID
      ↓
一条命令写进工程（tool/set_ads_ids.py）
      ↓
真机用测试 unit 跑通 5 个广告位（§4）
      ↓
域名 + 隐私政策 + app-ads.txt（§5）
      ↓
UMP 消息发布 + 商店上架 → 换正式 unit 提审
```

**关键判断**：AdMob 允许「应用还没上架」就先建（选 “No, it's not listed on a store
yet”），但**新应用在没有上架之前广告基本不出量**。所以这一步现在做是为了拿 ID
和跑通链路，不是马上有收入。

## 1. 账号与付款（只做一次）

| 步骤 | 位置 | 注意 |
|---|---|---|
| 1.1 | https://admob.google.com → 用**长期持有**的 Google 账号登录 | 别用临时号。账号被关联封禁会连带 App 停广告 |
| 1.2 | 左侧栏 **Payments（付款）** → Settings 区 **Manage settings** → 建 **Payments profile**（姓名/地址） | 没有 payments profile 就看不到税表入口；姓名地址要求与证件一致 |
| 1.3 | 同一个页面 → Payments profile 区 → **United States tax info** 旁的 ✎ → **Manage tax info** | 非美国居民个人填 **W-8BEN**；不填默认按 30% 预扣，且满 $100 也打不出款 |
| 1.4 | 关联一个 **Google Payments 收款方式**（银行账户/电汇） | 起付线 **$100**，每月 21 日左右结算；当月 20 号前提交税表才能在当月收到款 |

> 收款姓名/地址建议和 Apple Developer、Google Play 开发者账号保持一致，
> 后期核对收入来源时省事。

### 1.5 税表具体怎么走（2026-10 后台路径）

官方路径（找不到入口时照这个点）：

```
admob.google.com
  → 左侧栏 Payments（付款）
    → 「Settings」区 → Manage settings（管理设置）
      → 「Payments profile」区 → United States tax info 右侧 ✎
        → Manage tax info（管理税务信息）
```

入口不可用（灰色/看不到）的两个原因：① 还没建 payments profile（回 1.2）；
② 账号所在地区不需要美国税表。兜底入口：直接去 Google payments center
（pay.google.com → 设置 → 付款资料 → 税务信息）。

**填之前先备好这四样**（现场翻证件最容易填错）：

| 材料 | 用途 | 坑 |
|---|---|---|
| 中文全名 + 拼音（姓/名顺序与证件一致） | 表格姓名 | 拼音顺序填反 → 与银行账户比对失败，打款退回 |
| 详细住址（省市区 + 门牌号） | 表格地址 | 只写小区名会被打回；与你填的收款地址保持一致 |
| 纳税人识别号（个人 = 身份证号，作 **foreign TIN**） | 第 6 行 | 美国的 SSN/EIN 那栏（第 5 行）**留空**，非美国居民不填 |
| 银行账户信息 | 收款方式 | 账户名必须与税表姓名一致 |

关键判断：

- **个人 → W-8BEN；公司/个体户营业执照主体 → W-8BEN-E**。选错表等于没填。
- 想少扣税就要在第 II 部分**声明税收协定优惠**（居住国选 China，条款是特许权
  使用费 / Royalties，协定税率 10%）。不声明 = 按 30% 预扣。这一步是选填，
  但差别是 3 倍。
- 表格是**在线电子提交**，不需要打印签字扫描；提交后能下载 PDF，存一份。
- 提交后可能有身份核验（上传证件），人工审核几天。**当月 20 号前提交**才能赶
  上当月结算。
- 以上是操作路径，不是税务建议；涉及协定适用与个人报税请找税务顾问确认。

### 1.6 税务问答逐题怎么选（个人开发者）

进到「美国税务信息」后会先问几个定性问题，答案决定生成哪张表。个人独立开发者的
标准答案：

| 问题 | 选 | 选错的后果 |
|---|---|---|
| 「XXX 是什么类型的账号？」 | **个人** | 选「非个人/实体」会要求营业执照主体名 + 公司地址，个人收款账户对不上 |
| 「您是否为美国的公民或居民？」 | **否** | 选「是」会转 W-9，要 SSN，非美国居民填不了 |
| 是否有美国纳税人识别号（SSN/EIN/ITIN） | **否** | 填了没有的号会直接卡住审核 |
| 是否申请税收协定优惠（treaty benefits） | **是**（省钱关键） | 不申请 → 按 30% 预扣；申请后特许权使用费 10% |
| 居住国 / 税收协定国 | **China** | 选错国别拿不到协定税率 |
| 收入类型（如被问到） | **Royalties / 特许权使用费** | 选成 services 可能不适用协定条款 |

随后是身份信息页，按证件如实填：

| 字段 | 填什么 | 注意 |
|---|---|---|
| Last name / First name | 护照拼音，**姓在前**（刘博楠 → LIU / BONAN） | 只有 a-z 与数字，不许重音符号；顺序反了银行比对会失败 |
| Country of citizenship | China | 与护照国籍一致 |
| Permanent residence address | 身份证地址或常住房地址，省市区 + 门牌号 | 必须与 payments profile 的收款地址一致 |
| Mailing address | 同上（没有独立通信地址就勾「Same as permanent」） | — |
| Foreign (non-US) TIN | 身份证号（18 位） | 第 5 行的 US TIN 留空 |
| Date of birth | 与身份证一致 | — |
| 电子签名 | 输入与上面完全相同的英文全名 | 不需要打印扫描 |

提交后页面会给出 W-8BEN 的 PDF，下载留档。**当月 20 号前提交完才能在当月结算。**


## 2. AdMob 后台建应用与广告位（40 分钟）

### 2.1 建应用（两个都要建）

Apps → **Add app**

| 字段 | Android | iOS |
|---|---|---|
| Platform | Android | iOS |
| Is the app listed on a supported store? | 有 Play 商品页就选 Yes 并搜包名；没有选 **No** | 同左（App Store） |
| App name | `CarLong`（内部名，不必和商店名一致） | `CarLong` |
| User metrics / IAB | 都默认即可 | 同左 |

建完在 **App settings** 里能看到 **App ID**，形如：

```
ca-app-pub-1234567890123456~9876543210     ← 注意是「波浪号 ~」
```

两个 App ID 分别对应 Android / iOS。**它们必须是同一个 publisher ID**
（`ca-app-pub-` 后面那 16 位数字要一致），因为同一个账号下才共用付款资料。

### 2.2 建 10 个激励视频广告位

Apps → 选应用 → Ad units → **Add ad unit** → 选 **Rewarded**

**命名必须按这张表来**（后台报表按 unit 出数，名字乱后面查不了）：

| 广告位 | 代码触发点 | Android 名称 | iOS 名称 |
|---|---|---|---|
| `shopDaily` | 商店「看广告赚金币」+100🪙 | `CarLong_Android_Rewarded_Shop` | `CarLong_iOS_Rewarded_Shop` |
| `mergeRevive` | 合成失败续命 | `CarLong_Android_Rewarded_Revive` | `CarLong_iOS_Rewarded_Revive` |
| `mergeDouble` | 胜利金币 ×2 | `CarLong_Android_Rewarded_Double` | `CarLong_iOS_Rewarded_Double` |
| `parkingUndo` | 停车撤销卡不足 | `CarLong_Android_Rewarded_Undo` | `CarLong_iOS_Rewarded_Undo` |
| `parkingHint` | 停车提示 | `CarLong_Android_Rewarded_Hint` | `CarLong_iOS_Rewarded_Hint` |

其他字段：

- **Reward amount / item**：随意（`1` / `reward`），代码不读它，发奖自己判定。
- **eCPM floor**：先留空。没有数据前设 floor 只会把填充率压死。
- 建完每个 unit 会给出形如 `ca-app-pub-1234567890123456/1122334455`
  （这次是**斜杠 /**）。10 个 ID 全部抄下来。

### 2.3 立刻做但容易被忘的两件事

1. **App settings → 分类与内容分级**：如实填「游戏 / 休闲」。**不要勾「面向儿童」**
   ——勾了 Google 会禁掉全部个性化广告，eCPM 直接砍半以上。
2. **App settings → app-ads.txt**：这里会给你一行
   `google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0`，§5 要用。

## 3. 写进工程：一条命令（不要手改文件）

拿到 2 个 App ID + 10 个 unit 后，在项目根目录跑：

```bash
python3 tool/set_ads_ids.py \
  --android-app-id 'ca-app-pub-1234567890123456~1111111111' \
  --ios-app-id     'ca-app-pub-1234567890123456~2222222222' \
  --android-units  shop='ca-app-pub-.../1',revive='ca-app-pub-.../2',double='ca-app-pub-.../3',undo='ca-app-pub-.../4',hint='ca-app-pub-.../5' \
  --ios-units      shop='ca-app-pub-.../6',revive='ca-app-pub-.../7',double='ca-app-pub-.../8',undo='ca-app-pub-.../9',hint='ca-app-pub-.../10'
```

只建了一个 unit 想先跑通？用简写（5 个位共用一个 unit）：

```bash
python3 tool/set_ads_ids.py \
  --android-app-id 'ca-app-pub-...~111' --ios-app-id 'ca-app-pub-...~222' \
  --android-unit 'ca-app-pub-.../1' --ios-unit 'ca-app-pub-.../2'
```

脚本会做四件事，任一项不通过就**不改任何文件**：

1. 格式校验（App ID 必须带 `~`、unit 必须带 `/`，都是 16 位账号 + 10 位编号）；
2. **跨账号校验**：App ID 的 publisher 段和 10 个 unit 的 publisher 段必须一致
   ——不一致是真实事故（SDK 不报错，但永远无填充）；
3. 把 2 个 App ID 写进 `AndroidManifest.xml` / `Info.plist`；
4. 生成 `ads.env.json`（10 个 `ADMOB_*_UNIT_*`），最后自动跑一次上架闸门。

构建时带上配置：

```bash
flutter build appbundle --release --dart-define-from-file=ads.env.json
flutter build ipa       --release --dart-define-from-file=ads.env.json
```

> `ads.env.json` 已在 `.gitignore` 里，真实 ID 不入库。换机器/换 CI 时重新跑脚本或
> 从密码管理器取。

## 4. 真机验证（换正式 unit 前先做这一步）

**红线：不要拿自己的正式 unit 在自己手机上反复点。** 那是「无效流量」，
AdMob 第一次警告、第二次直接停用账号（收入全没）。

两种安全做法，任选一个：

- **A. 用测试 unit 跑真机**（最省事）：不加 `--dart-define-from-file` 构建，
  配置会回落到 Google 官方测试 unit，广告照播、不计费、点了也不会被记异常。
- **B. 加测试设备**：真机跑一次，在 `flutter run` 日志里搜
  `Use RequestConfiguration.Builder.setTestDeviceIds`，把那串哈希填进
  `AdMobConfig(testDeviceIds: [...])`，之后用正式 unit 调试也不会产生无效流量。

真机必测四条路径：

| 场景 | 期望 |
|---|---|
| 正常看完 | 发奖，金币/续命/撤销到账 |
| 播到一半关掉 | **不发奖**，提示「看完才能拿奖励」 |
| 飞行模式 | 提示「暂时无法播放广告」，不崩、不卡死 |
| 连续点第 N 次超上限 | 提示「今天次数用完」，且**不发广告请求**（`ad_impression` 不该多一条） |

App 内自检入口：首页右上角设置 → 底部「广告自检」。debug/profile 默认显示。
换成正式 ID 后这里应该变成绿色的「正式广告 · 真实库存，会计费」。

## 5. 域名三件套（提审硬门槛）

需要一个你能控制 DNS 的域名（没有就买个便宜的，$10/年）。放三样东西：

```
https://yourdomain.com/privacy      ← 隐私政策页（双端商店都要填）
https://yourdomain.com/app-ads.txt  ← AdMob 验证归属
https://yourdomain.com/support      ← 支持页（Apple 要求）
```

`app-ads.txt` 就是 §2.3 那一行，纯文本、**不要带 BOM**：

```
google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0
```

然后在 **App Store Connect 的「营销网址」**和 **Play 商店的「开发者网站」**里
填 `https://yourdomain.com`（只要域名，不要带路径）。AdMob 靠这个反查
app-ads.txt，**不填 = 广告库存可能被第三方劫持**（钱进别人口袋）。

> 隐私政策页我可以直接产出静态页 + 部署，见文末待办。

## 6. UMP 同意消息（不发 = 欧盟永远不弹窗）

AdMob → **Privacy & messaging** → 建三条消息并 **Publish**：

| 消息类型 | 覆盖 | 要点 |
|---|---|---|
| GDPR | 欧盟/英国/瑞士 | 必须选「Consent + Do not consent」两种选项；隐私政策 URL 填 §5 的地址 |
| US states | 加州等 | CCPA，选「Do not sell/share」入口 |
| IDFA explainer（iOS） | 全局 | iOS 上先用它解释再弹 ATT，通过率明显更高 |

三条都是 **Draft → Publish** 才算生效。没发布时 `canRequestAds()` 恒为 true，
代码不会报错，只是欧盟用户永远看不到表单 —— 属于「代码没问题、合规不合格」。

## 7. SKAdNetwork 的真相（省你一次白忙）

`Info.plist` 里现在只有 `cstr6suwn9.skadnetwork`（Google 自家）。**单渠道 AdMob
阶段这一条就够**，不要去找那份上百条的清单 —— 那份是给「接入中介网络」用的，
每接一家才补一家。

什么时候必须补：在 AdMob 后台建 **Mediation group** 加了 Meta / AppLovin / Unity
之后，按每家 provider 的官方文档把它们各自的 SKAdNetwork ID 加进来。漏了不会崩，
只是那家渠道的安装归因丢失（等于白买量）。

## 8. 常见拒审 / 事故清单

| 现象 | 根因 | 处理 |
|---|---|---|
| 启动即崩 | App ID 缺失或格式错（少 `~`） | `python3 tool/check_ads_release.py` |
| 广告永远无填充 | App ID 和 unit 属于不同账号 / 应用还没上架 | 跑脚本的跨账号校验；等上架 |
| 有画面但收入 0 | 打包进了测试 unit | 设置页「广告自检」应显示「正式广告」 |
| 欧盟不弹同意 | UMP 消息没 Publish | §6 |
| 账号被停用 | 自点广告 / 激励诱导（"看完必得大奖"式文案） | 用测试设备；文案改成「看广告领取」 |
| 收入被劫持 | app-ads.txt 缺失或商店未填开发者网站 | §5 |

## 9. 现在的状态与下一步

```
✅ 代码层（provider / 三道频次闸 / UMP 入口 / 隐私清单 / 自检）
✅ 平台配置骨架（当前是 Google 官方测试 ID）
⬜ AdMob 账号 + 付款 + 税表          ← 你，§1
⬜ 2 个 App ID + 10 个 unit          ← 你，§2
⬜ 跑一条命令填值                     ← 你，§3（1 分钟）
⬜ 域名 + 隐私政策 + app-ads.txt      ← 我出页面，你挂域名，§5
⬜ UMP 三条消息 Publish              ← 你，§6
⬜ 商店素材 / 分级 / 封闭测试 14 天    ← 你（Play 个人号硬性要求）
```

填完值后自查一条命令：

```bash
python3 tool/check_ads_release.py --strict
```

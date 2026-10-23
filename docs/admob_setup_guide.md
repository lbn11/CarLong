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
| 是否申请税收协定优惠（treaty benefits） | **是**（省钱关键） | 不申请 → 按 30% 预扣 |
| 居住国 / 税收协定国 | **China** | 选错国别拿不到协定税率 |
| 特殊税率与条件（详见 §1.6.1） | 只勾 **服务或其他商业收入 → 0%** | 勾成「其他版权版税」会按 10% 预扣，AdMob 不属于那类 |

随后是身份信息页，按证件如实填：

| 字段 | 填什么 | 注意 |
|---|---|---|
| Last name / First name | 护照拼音，**姓在前**（刘博楠 → Last `LIU` / First `BONAN`） | 全大写，只有 a-z；不许重音符号与中间名。顺序反了银行比对会失败 |
| Country of citizenship | China | 与护照国籍一致 |
| Permanent residence address | 身份证地址或常住房地址，省市区 + 门牌号 | 必须与 payments profile 的收款地址一致 |
| Mailing address | 同上（没有独立通信地址就勾「Same as permanent」） | — |
| Foreign (non-US) TIN | 身份证号（18 位） | 第 5 行的 US TIN 留空 |
| Date of birth | 与身份证一致 | — |
| 电子签名 | 输入与上面完全相同的英文全名 | 不需要打印扫描 |

提交后页面会给出 W-8BEN 的 PDF，下载留档。**当月 20 号前提交完才能在当月结算。**

#### 1.6.1 「特殊税率与条件」三个选项怎么勾（AdMob 只勾第二个）

这一页是中美税收协定第 12 条/第 7 条落到具体收入类型的对应关系。三项**按实际收入勾**，
全部勾上不会多拿钱，勾错类会按错的税率扣：

| 选项 | 协定税率 | 对应收入 | 本项目 |
|---|---|---|---|
| 其他版权版税（YouTube 合作伙伴计划、Cloud Marketplace 转销商、Play Pass） | **10%** | 版权/内容授权 | 不勾 |
| **服务或其他商业收入（如 AdSense，不含 AdSense YouTube 广告）** | **0%** | 广告发布收入 | **✅ 只勾这个** |
| 电影和电视版税 | **10%** | 影视版权 | 不勾 |

**为什么 AdMob 是 0% 而不是 10%**：AdMob 的收入性质与 AdSense 相同（广告展示分成），
被归入「服务或其他商业收入」，适用协定下的**营业利润**条款；中国居民在美国无常设机构，
美国对该项所得无征税权，故预扣 0%。选「其他版权版税」是把自己当成卖版权的
（YouTube 广告分成才是那类），AdMob 勾它等于自愿多缴 10%。

> 若以后同时做 YouTube 频道或 Play Pass 订阅分成，可以回来把第一项也勾上选 10%，
> 两个类目并存互不影响。当前只有 AdMob，只勾第二项即可。

**这一页最常见的一个阻塞报错**：

> 如需申请享受税收条约优惠，需要提供外国 TIN 或美国 TIN。
> 请在「第 1 步：纳税身份」中添加外国 TIN 或美国 TIN

意思是第 1 步的 `Foreign (non-US) TIN` 空着 —— 这一页只是**校验**，本页填不了。
点返回第 1 步，在 Foreign TIN 填 **18 位身份证号**（末尾是 X 就大写 X），
美国 TIN 那行保持空白，然后重新走到这一页。

#### 1.6.2 提交前最后三屏

| 屏 | 填 |
|---|---|
| 是否在美国针对 Google 开展活动 / 提供服务，或未来预计会 | **否** + 勾确认（选「是」→ 变 ECI，改用 W-8ECI，累进税率最高 37%，还要报 1040-NR） |
| 报税方式 | **无纸化 / 电子交付** |
| 纳税身份未变宣誓书「1 月 1 日，____ 年」 | **当前年份**（2026）。语义是「从该年 1 月 1 日起身份未变」，首次提交填当前年即可；填更早年份没有额外好处，反而多一句不精确声明 |
| 变更说明与日期（可选） | **留空**，首次提交没有变更 |
| 你确认自己是「纳税身份」所列的受益所有人吗 | **是的，我是**（选「不是」= 你不是这笔收入的归属人，与 §1.8 的结论直接冲突） |

#### 1.6.3 提交后显示「需要采取措施 / 30%」是正常流程，不是被拒

提交完 W-8BEN 后几乎必然出现这个状态，**不要当成失败**：

```
W-8BEN 表单   状态：需要采取措施
当前预扣税率：30%   在您的表单获得批准之前此税率适用
我们需要一些额外的文件才能验证您的信息。
```

三件事要分清：

| 现象 | 真实含义 |
|---|---|
| 「需要采取措施」 | Google 要一份**身份证明文件**，个人开发者传**身份证正反面**即可（有时要护照页） |
| 「当前预扣税率 30%」 | **待批准的占位税率**，不是判决。批准后按税目表生效（服务 0%） |
| 「可能需要按最高税率缴税或延迟付款」 | 针对**已有余额**的警告。账号没有真实收入时，它不会造成任何实际损失 |

处理动作只有一步：点「需要采取措施」→ 上传身份证正反面（清晰、四角完整、≤ 要求体积）
→ 提交 → 等审核（快则半小时，慢则几天，多数 1-2 个工作日）。

**注意**：这一屏的「在美国以外国家/地区从事经营活动的证明」如果单独要求书面材料，
用 [tax_proof_letter_template.md](tax_proof_letter_template.md) 的英文声明模板，
签字扫描后上传。**先只传身份证**，被明确要求时再补，不要一上来堆材料。

审核通过后：状态变「已批准」，税目表里服务一项的 0% 生效，之后产生的收入不再预扣。
之前按 30% 预扣的部分可退（仅限当前日历年内），会自动在后续付款中调整。


### 1.6.4 身份证「只能上传一张」怎么办

先别急着拼接，这多半是界面误读。按顺序排除：

| 情况 | 判断方法 |
|---|---|
| 还没点开上传框 | 点一下方框，等系统文件选择器弹出来再看 |
| 其实支持多选 | 文件选择器里**按住 `Cmd`（Mac）/ `Ctrl`（Win）点第二个文件**，一次带两张 |
| 正反面是两个分开的槽位 | 先传人像面，提交/下一步后反面槽位才出现 |
| 真的只有一个槽位 | 才需要合成，见下面 |

确认只有一个槽位后，**合成单页 PDF，不要合成 JPG**。PDF 是「一次整页扫描」的形态，
JPG 拼图一眼能看出是两段贴在一起；两者 Google 都收，但 PDF 更不容易被人工复核挑出来。

```bash
# 输出 id_card_merged.pdf：A4 / 300dpi / 上下排列 / 自动压到 3.5MB 内
python3 tool/merge_id_card.py 人像面.jpg 国徽面.jpg

# 想左右拼 / 想要 JPG
python3 tool/merge_id_card.py front.jpg back.jpg --layout side --jpg -o id_card.jpg
```

预期输出（`quality=92` 是内部压缩参数，不是报错）：

```
    人像面 2593x1653  国徽面 2623x1638
[ok] /Users/apple/Downloads/CarLong/id_card_merged.pdf
     2480x3508  1.45MB  quality=92  PDF/A4
     在 Finder 里定位：open -R '/Users/apple/Downloads/CarLong/id_card_merged.pdf'
```

**文件就落在你执行命令时所在的那个目录**（不是某个隐藏的缓存目录）。输出里第一行是完整路径，
倒数第二行给了一条可直接粘贴的 `open -R` 命令，会在 Finder 里选中该文件。
想换位置就加 `-o`：`python3 tool/merge_id_card.py front.jpg back.jpg -o ~/Desktop/id_card.pdf`。

**1–2MB 都正常**，上限 4MB；`quality=92` 说明一次压缩就进了限额，画质没有可见损失。
只有看到 `[!] 压不下去，等比缩小 15%` 才说明图太大，那时画质会略降，但仍可用。

> 粘贴命令时不要把 `#` 开头的注释行一起粘进终端：zsh 交互模式不把 `#` 当注释，
> 会报 `zsh: command not found: #`。跟脚本本身无关，忽略即可。

脚本只做「排列 + 压体积」，**刻意不做**裁剪、提亮、去背景、二值化 —— 这三条是红线：

1. **不裁证件边缘**。四角必须完整在画面里，裁掉一个角就是「信息不完整」。
2. **不加任何文字/水印/箭头**。用扫描 App 时尤其注意，很多国产扫描 App 会在角上打
   「由 XX 扫描」，这是身份证被打回最常见的原因，比照片模糊更致命。
3. **不做「美化增强」**。美白、锐化、黑白二值化会破坏防伪纹路，审核方看到的是「被处理过的文件」。

拍摄要求（手机原生相机，别用扫描模式）：平铺桌面、顶光、四角完整、无反光、手指不遮挡、
身份证号与有效期限可读。iPhone 的 HEIC 先转 JPG：

```bash
sips -s format jpeg IMG_1234.HEIC --out front.jpg
```

上传后状态回到「待审核」，1-2 个工作日。审核期间**不要改 payments profile 地址**
（材料与 profile 不一致会拉长审核）。

> ⚠️ **别让证件进版本库**。脚本产物默认落在项目根目录，`.gitignore` 已加
> `id_card*.pdf` / `id_card*.jpg` 挡住（用 `git check-ignore -v id_card_merged.pdf` 可验证）。
> 上传成功后建议直接删掉（`rm id_card_merged.pdf`）—— 身份证正反面留在项目目录里没有任何好处，
> 需要再传时跑一次脚本即可。


### 1.7 中文地址只能填拼音（只认 a-z）

税务表单的地址栏**不接受汉字**，必须转拼音，且顺序要符合国际邮寄习惯
（门牌/楼栋 → 街道 → 区 → 市 → 省 → 邮编）。示例（呼和浩特）：

| 字段 | 填 |
|---|---|
| 地址行 1 | `Neida Feicuicheng, Xilin South Road, Saihan District` |
| 公寓/套房/门牌号（选填） | `Building 10` |
| 城市 | `Hohhot` |
| 省/自治区 | `Inner Mongolia` |
| 邮政编码 | `010020`（按实际街道核对） |
| 国家 | `China` |

三条原则：

- **小区名用拼音，不要翻译**。`内大翡翠城` 写成 `Neida Feicuicheng`，
  别写成 `Emerald City` / `Inner Mongolia University` —— 翻译后既对不上证件，
  也确实送不到。
- **不要加标点缩写**（`Rd.` / `Dist.` 都不要），全拼即可，逗号只作分隔。

> **地址是「中英两版」，不是「两处一样」。** 这条最容易误会，单独说一下：
>
> | 字段 | payments profile（AdMob 后台） | W-8BEN 税表 |
> |---|---|---|
> | 语言 | **中文**（地区选中国后表单就只收中文） | **只能 a-z**（IRS 规定） |
> | 姓名 | `LIU BONAN`（拼音） | `LIU BONAN` ← **字形必须完全一致** |
> | 地址 | `上海市浦东新区周浦镇周秀路168弄11号1402室` | `Lane 168, Zhouxiu Road, Zhoupu Town, Pudong New Area` + `Building 11, Room 1402` |
>
> 两处地址**本来就长得不一样**，这是同一地址的两种书写，Google 与 IRS 都不会做字符比对。
> 只有**姓名**是两边都必须一模一样的字段（因为姓名另有拼音标准）。
>
> 真正的风险是「指向不同地址」：比如 profile 里是上海、税表里是呼和浩特，
> 或某一处漏了楼栋室号 —— 前者触发复核，后者 PIN 信寄不到。
> **PIN 邮寄走的是 payments profile 的中文地址**（邮局只认中文），
> 所以中文那一版反而更要写全、写对。

**直辖市 + 弄堂的写法**（上海示例：浦东新区周浦镇周秀路 168 弄）：

| 字段 | 填 |
|---|---|
| 地址行 1 | `Lane 168, Zhouxiu Road, Zhoupu Town, Pudong New Area` |
| 公寓/套房/门牌号 | `Building 11, Room 1402` ← **有楼栋室号一定要填** |
| 城市 | `Shanghai` |
| 省/自治区 | `Shanghai`（直辖市城市与省都填 Shanghai） |
| 邮政编码 | `201318`（周浦镇） |
| 国家 | `China` |

两个新知识点：

- **「XX 弄」译作 `Lane XXX`**（不是 Alley、不是 No. XXX）。上海地址里弄堂是独立一级，
  漏掉 `Lane` 会指向整条路，信找不到门。
- **直辖市城市与省填同一个词**。上海/北京/天津/重庆不设省，Google 的「省」栏选同名即可。

> ⚠️ 只写到「XX 弄」通常不够：一个弄里有几十栋楼，PIN 信会停在弄口或居委会。
> **楼栋 + 室号必须写进「公寓/门牌号」栏**（`Building 11, Room 1402`），否则等于没写门牌。

### 1.7.1 搬家了 / 身份证地址与现居地址不一致

**结论：不影响审核，只影响 PIN 信。** 三件事必须分开看：

| 环节 | 比对地址吗 | 结论 |
|---|---|---|
| 税表 W-8BEN 审核 | **不比对**。只校验姓名、TIN（身份证号）、出生日期，地址仅做格式与国家一致性检查 | 填**常住地址**即可。IRS 的 permanent residence address 定义就是实际居住地，不是户籍地 |
| 身份验证（传身份证） | **不比对**。Persona / Google 比对的是姓名 + 证件号 + 人脸 | 证件地址 ≠ 现居地在中国是常态，Google 处理大量这类账户，不会因此驳回 |
| 地址验证（PIN 邮寄） | **是，硬约束** | 寄到 payments profile 的**中文地址**。平信不打电话，楼层写错 = 收不到 |

所以唯一要动手检查的是 payments profile：

1. AdMob → 付款 → 设置 → 看 payments profile 的地址。
2. 是否写到**楼栋 + 室号**（`11号楼1402室` 这一级），且是**现在住的这一层** → 是，则什么都不用做。
3. 还是旧楼层 → 改。**但不要卡在身份证审核进行中改**（材料与 profile 不一致会拉长审核），等「需要采取措施」变成「已批准」再改。

改地址的真实代价，提前知道：

- 改 payments profile 地址**不会**自动作废旧税表；但如果连税表地址一起改，会生成一份新的 W-8BEN，需要重新电子签名、可能重新审核。
- 地址变更会**重置 PIN 计数**，在途的 PIN 作废。
- 地址验证共 **3 次 PIN 机会**，3 次失败后要提交「地址证明」（银行对账单 / 水电燃气账单，含姓名 + 地址，通常 90 天内）——这是「填实际居住地」的第二个理由：只有现居地你才拿得出凭证。

**PIN 不是提交税表就寄**：它在你首次产生收入、需要验证收款地址时才触发（一般余额接近付款阈值）。所以有窗口期，今天不必急着改。

同楼不同层的特殊风险：平信写错楼层最常见的结果是被投进楼上邻居信箱或退回分拣中心。
**旧楼层如果还是你或家人的房子**，风险小；**如果是租的、已经退租**，务必改成现在的门牌。

顺带两处（不必与税表一致，但不该长期错）：

- **Google Play 开发者账号的开发者地址**会公开显示在商店页，填能联系到的。
- **Apple Developer 付费应用协议**里也有税表，地址口径同上（常住地址）。


### 1.8 收款账户能不能用家人的（"税表写我、打钱给我爸"）

**结论：不要这样配。** 这是唯一一类「配置能提交成功、但钱会在最后一步被卡住」的问题，
而且暴露得很晚（余额满 $100 才走到付款环节，通常已经上线一两个月）。

Google 官方帮助页（[输入付款资料](https://support.google.com/admob/answer/12835021)）对个人账户
写的是：姓名「**必须与银行账户信息完全相符**」。个人账户的钱一律支付到**账户持有人**名下。

| 配法 | 结果 |
|---|---|
| 税表 = 本人、payments profile = 本人、银行卡 = 本人 | ✅ 唯一无风险配法 |
| 税表 = 本人、payments profile = 父亲、银行卡 = 父亲 | ⚠️ 属于「受益所有人 ≠ 收款人」。AdMob 身份验证会把 payments profile 姓名锁在验证过的身份上，改不动；能走的只剩「电汇到第三方账户」，会触发 payment hold 要求验证**账户持有人**的身份证件，可能需要父亲单独提交税表 |
| 税表 = 本人、payments profile = 本人、银行卡 = 父亲 | ❌ 三个名字对不上。Google 侧 payment hold + 国内银行侧入账核对失败，两头都退 |
| 税表、profile、银行卡全是父亲 | ⚠️ 可行，但要一开始就用父亲的 Google 账号做身份验证（人脸核验），且账户类型选定后**不可变更**，以后想改回本人极难 |

三条具体的坑：

1. **国内银行会先拦一道**。中行、招行等处理美元电汇时核对「收款人名称」与「开户证件姓名」，
   汇入报文收款人写 `LIU BONAN`、账户户主是父亲，多数情况直接退回。
2. **首次付款失败后 Google 会暂停该账户的所有后续付款**，要求重新提交有效收款信息；
   免费重试只有一次，之后每次失败收 $30 手续费。卡在这里比一开始就配对麻烦得多。
3. **税表申报的受益所有人是本人，钱却打给别人**，在 IRS 层面属于信息不实。个人小额极少被追，
   但这是「没被查」和「合规」的区别，别把它当成可行方案。

**推荐做法：全程用自己。** 国内个人账户完全可以收 Google 电汇，需要准备 SWIFT/BIC、
银行英文名与地址、账号、户名拼音（`LIU BONAN`，与护照一致）。多数银行要先把卡开通
「多币种/外币账户」，入账后在手机银行做「涉外收入申报（服务贸易项下）」再结汇。
个人年度结汇额度 5 万美元，广告收入通常远低于此，不构成障碍。

### 1.9 如果确定整套用家人的身份（四件套怎么配）

决定用父亲身份后，**姓名不是单独一项，而是四件必须配套的东西**。只改其中一件就会
在身份验证或付款环节断掉：

| 项 | 必须 | 为什么 |
|---|---|---|
| ① 身份证姓名 | 父亲的，拼音全拼 | Persona 人脸核验会比对证件，姓名不符直接失败 |
| ② 地址 | **父亲能收到实体信的地址**（最好就是父亲户籍/常住地） | 身份验证的备选方式是「证件 + 邮寄 PIN」，信上的收件人必须是父亲；地址与户名不符会被邮局退回 |
| ③ 银行卡 | 父亲名下、开通多币种 | 电汇收款人名称要与户名一致 |
| ④ 税表 W-8BEN | 父亲名义，foreign TIN 填**父亲身份证号** | 受益所有人必须等于收款人 |

**手机号不在校验项里**，Google 不比对中国手机号的实名归属。所以填谁的都行，
只有一个实用标准：**填能随时拿到验证码的那一个**。

- 操作是你做的 → 填你自己的号码更方便（验证码直接到你手机，不用每次找父亲转发）。
- 但如果你会把账号交给他管、或担心日后账号恢复要过他手 → 填他的。

真正会卡住的不是手机号，而是**身份验证那一步必须父亲本人出镜**：Persona 流程要
拍身份证正反面 + 活体人脸，只能他本人在场做（几分钟）。另一条路「ID + 邮寄 PIN」
也要寄到他的地址、由他签收。

**更干净的做法**：既然整套用父亲，就**用他的身份新注册一个 Google 账号**专门跑 AdMob，
不要在你的老账号上改 payments profile。原因是老账号已经绑定了你的使用痕迹（设备、
恢复邮箱），身份验证一旦用父亲证件，账号主体与历史信息不一致，人工复核时解释成本高。

代价要提前认下来：账号的二次验证、密码找回、以及将来任何申诉都在父亲手上；
收入在法律与税务上属于他（境外所得由他申报个税），你只是实际使用者。

> 这一节与 §1.8 不矛盾：§1.8 说的是「不要混搭」，这里说的是「要换就整套换」。
> 混搭（税表本人 + 卡父亲）是唯一必错的做法。

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

中文后台路径：左侧「应用」→「查看所有应用」→「添加应用」。三个易错点：

1. **平台选定不可改**。Android 应用建成了 iOS（或反之）只能删掉重建，App ID 会跟着变，
   之前填进工程的配置全部作废。建之前先确认右上角/弹窗里的平台图标。
2. **未上架就选「否」**（Is the app listed on a supported store? → No）。提交后应用状态会显示
   「在商店中找不到应用」，**这是正常的**，别以为建错了；上架后回「应用设置」补商店链接即可。
3. 两个应用都叫 `CarLong` 没问题，平台不同不冲突；这个内部名不必和商店名一致。

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

**建每个 unit 前，先看页面顶部/侧边的「应用」选择器，确认当前停在 Android 还是 iOS 那个应用下。**
在 Android 应用下建一个叫 `..._iOS_...` 的 unit 是最常见的返工点：ID 本身不报错、SDK 也照常加载，
但两端数据混在一起，之后按 unit 看 eCPM 就全废了。

### 2.2.1 每个 unit 建完都给「两个号」，只用第二个

建完一个 unit，页面会贴出两串 ID，看起来像「一个单元给了俩号」，其实不是：

```
使用下面这个应用 ID：CarLongca-app-pub-3751874625509987~6515229387      ← ① 应用 ID
使用下面的广告单元 ID：CarLong_iOS_Rewarded_Shopca-app-pub-.../6497550533  ← ② 单元 ID
```

| | 符号 | 数量 | 用在哪 | 会不会重复 |
|---|---|---|---|---|
| ① **应用 ID**（App ID） | `~` | 每个平台 1 个 | 初始化 SDK：iOS 的 `Info.plist` → `GADApplicationIdentifier`；Android 的 `AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID` | **每个 unit 页面都贴同一个**，因为它属于整个应用，不属于单元 |
| ② **广告单元 ID**（unit ID） | `/` | 10 个，各不相同 | 代码里加载具体广告位（本工程落在 `ads.env.json` 的 5 个 slot） | 每个单元唯一 |

两个必须分清，**填反了会崩**：把 unit ID（`/`）填进 `Info.plist` 会导致 iOS 启动即崩
（`GADInvalidInitializationException`）；把 App ID（`~`）填进 `ads.env.json` 则是永远加载不出广告、无报错。

页面上 `CarLongca-app-pub-` 这种粘连是排版问题（应用名 + ID 之间没留空），
**只抄 `ca-app-pub-` 开头那一段**，别把应用名带进去。

### 2.2.2 「合作平台出价」这个勾**不要勾**

建 unit 的表单里有一项「合作平台出价 / Third-party bidding」+ 一段免责说明，
它是 AdMob 给**已在别家中介平台做实时出价的人**准备的开关，本项目不适用。

勾了会发生什么（Google 原文的意思）：

- 该 unit **不能**用于 AdMob 中介（Mediation）或 AdMob 广告系列；
- **不能**通过第三方瀑布流去对接 Google Ads / Display & Video 360 需求；
- Google 可能还要向那家第三方中介付费。

对本项目（纯 AdMob 单渠道、没接 MAX / LevelPlay / TradPlus）来说，勾了等于
**主动切断唯一的需求方** —— 广告会永远不填充，而且**创建后不可更改**，只能删掉 unit 重建，
unit ID 跟着变，`ads.env.json` 要重填一遍。

**什么时候才勾**：你已经在 AppLovin MAX / ironSource LevelPlay 里把这个 AdMob unit
作为 bidding 来源接入了。将来真要上聚合，也建议**新建一批 unit 专供聚合用**，
不要动这批已经在跑数据的。

中文后台路径：广告单元 →「开始使用」→ 格式选「激励视频」→ 填名称 → 展开「高级设置」
把「eCPM 下限」留空 →「完成」。建完**不要**点「查看集成说明」，直接复制 ID —— 代码早就集成好了。

10 个建完后，逐个核对名称与平台后缀是否成对（Android 应用下必须是 `_Android_` 开头那 5 个）。

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

现在工程已经换成正式 unit，所以只剩**一种**安全做法 —— 把自己的调试机加进测试设备列表：

```bash
# 1. 不带测试设备跑一次，日志里会打出一行
flutter run --dart-define-from-file=ads.env.json
#    搜：[ads] 或 "setTestDeviceIds"，拿到形如 3F2A5C9D... 的哈希（Android）
#    iOS 拿到的是 UUID（大小写不敏感的 40 位十六进制）

# 2. 写进 ads.env.json（不要入库）
#    "ADMOB_TEST_DEVICE_IDS": "3F2A5C9D..., 另一台设备"

# 3. 重新构建，之后你的手机请求到的就是测试广告：正常播放、不发奖计费、
#    反复点也不会被判无效流量
```

多个设备用英文逗号分隔，空格会被自动清掉（`AdMobConfig.parseTestDeviceIds`）。
**测试设备广告的右上角有「Test Ad」角标**，看不到这个角标说明设备没被识别，别继续点。

> 为什么不能再用「不传 `--dart-define-from-file` 就回落测试 unit」这招：
> App ID 已经写死在 `AndroidManifest.xml` / `Info.plist` 里，回落只能改 unit，
> 会变成「正式 App ID + 测试 unit」的混合态 —— 广告能播，但诊断面板会报测试库存，
> 容易误判成「已经上线在赚钱」。

**没有真机也能测**：Android 模拟器必须选**带 Google Play** 的镜像（`Pixel_6_Play` 这类）；
AOSP 镜像没有 Play 服务，广告 SDK 初始化直接失败，会误判成"代码有问题"。

模拟器上**不要用正式 unit**，用官方测试 unit 把链路跑通：

```bash
flutter emulators --launch Pixel_6_Play
flutter run -d android \
  --dart-define=ADMOB_ANDROID_UNIT=ca-app-pub-3940256099942544/5224354917
```

5 个广告位共用这一个测试 unit：永远有填充、不计费、点多少次都安全，不受"新 unit 没量"影响。
此时诊断面板显示**测试库存**——这是对的，说明你测的是链路而不是收入。
代价是看不出哪个广告位更值钱，那部分只能等真机 + 正式 unit 放量后再看。

真机必测四条路径：

| 场景 | 期望 |
|---|---|
| 正常看完 | 发奖，金币/续命/撤销到账 |
| 播到一半关掉 | **不发奖**，提示「看完才能拿奖励」 |
| 飞行模式 | 提示「暂时无法播放广告」，不崩、不卡死 |
| 连续点第 N 次超上限 | 提示「今天次数用完」，且**不发广告请求**（`ad_impression` 不该多一条） |

App 内自检入口：首页右上角设置 → 底部「广告自检」。debug/profile 默认显示。
换成正式 ID 后这里应该变成绿色的「正式广告 · 真实库存，会计费」。

### 4.1 模拟器实测记录（2026-10-23，链路已验证通过）

命令只有一句（**不带任何 `--dart-define`**，10 个 unit 全空 → 自动回落到测试配置，
App ID 仍是正式的，属于「正式 App ID + 测试 unit」的混合态，只用于验证链路）：

```bash
flutter run -d emulator-5554 --no-pub
```

| 观察点 | 实测结果 |
|---|---|
| 广告自检 | 「测试广告 · 真 SDK，测试 unit，零收入（admob）」/ SDK 已就绪 |
| 广告画面 | 顶部有 `Test Ad` 角标 + Google Ads 测试创意 |
| 发奖回调 | 关闭时弹「Reward granted」，回 App 后弹「广告看完 +100」，金币 195 → 295 |
| 频次闸 | 商店当日剩余 3 → 2，弹窗文案同步写「今天还可以看 2 次」 |

**没有 `Test Ad` 角标就是没走测试库存，别继续点。**

#### 坑 1：Android 端此前从未构建成功（工具链版本超纲）

三个连环问题，逐层暴露：

1. `app/build.gradle.kts:38` 的 `kotlin { compilerOptions { … } }` 报
   `Unresolved reference 'compilerOptions'` —— `plugins {}` 里**根本没应用**
   `org.jetbrains.kotlin.android`（`settings.gradle.kts` 里只有 `apply false` 的声明），
   而 `MainActivity.kt` 是 Kotlin 源码。缺这个插件既让 DSL 无法解析，也编译不出 Activity。
2. 补上插件后，卡在 `google_mobile_ads 5.3.1/android/build.gradle:58` 的
   `configurations.all`：在 **Gradle 9** 上变成 `unknown property`（Gradle 9 移除了该属性访问）。
3. 根因是工程被抬到 **Gradle 9.1.0 + AGP 9.0.1 + Kotlin 2.3.20**，远超插件与 Flutter 支持范围。

修法是**对齐 Flutter SDK 自己的模板版本**（`flutter_tools/lib/src/android/gradle_utils.dart`）：

| 项 | 曾被抬到 | 对齐后（Flutter 3.41.6 官方值） |
|---|---|---|
| Gradle | 9.1.0 | **8.14** |
| AGP | 9.0.1 | **8.11.1** |
| Kotlin | 2.3.20 | **2.2.20** |

> **规则：这三者不要单独升级。** 升级 Flutter SDK 后，去
> `gradle_utils.dart` 查 `templateDefaultGradleVersion` /
> `templateAndroidGradlePluginVersion` / `templateKotlinGradlePluginVersion`，三者一起改。
> 只抬一个的后果就是上面这种「业务代码没问题、构建永远失败」。

#### 坑 2：磁盘剩余不足 2G 时，Gradle 报的是别的东西

真实报错是 `Failed to create Jar file …`（不是「空间不足」），极易误判成代码问题。
`df -h` 剩余 < 2G 就先腾空间：Xcode 的 `DerivedData`、未使用的 Android 系统镜像、
旧 NDK 都可以直接删，删完 APFS 回收可能延迟几分钟才反映到 `df`。

#### 坑 3：模拟器触摸全失效（`NO_INPUT_CHANNEL`）

`adb shell input tap` 完全没反应，但截图显示界面正常。`dumpsys input` 里能看到一个
`ActivityRecordInputSink` 覆盖全屏吞掉事件，同时 Activity 状态却是 `RESUMED`。
`adb reboot` 冷重启模拟器后恢复。

**判断依据：状态栏时钟不走了 = 画面已僵死，别在坐标上折腾。**
另外 `flutter run` 会话挂住时触摸也会失效，用 `adb shell am force-stop` + `am start`
把 App 与调试会话解耦即可。

## 5. 站点三件套（两个硬门槛 + 一个建议）

**不需要买域名。** 商店只认「URL 能不能打开」，不认域名归属。免费平台的子域
（`carlong.pages.dev` / `carlong.netlify.app`）一样过审、一样能验证 `app-ads.txt`。

需要挂三样东西：

```
https://<任意可访问域名>/privacy      ← 隐私政策页（双端商店都必填，硬门槛）
https://<任意可访问域名>/support      ← 支持页（App Store Connect「支持网址」必填）
https://<任意可访问域名>/app-ads.txt  ← AdMob 验证库存归属（建议，不影响能否上线）
```

第三样不是提审门槛。不挂照样出广告，只是库存归属无法被买方验证，程序化直客
可能因此不买你的量 —— 影响的是 eCPM 上限，不是能不能上架。

### 5.1 唯一的形态限制：必须在域名根目录

AdMob 的抓取链路是「商店里填的开发者网站 → **丢掉路径** → 请求
`https://<域名>/app-ads.txt`」。三条推论：

1. 开发者网站填 `https://xxx.com/abc` 与填 `https://xxx.com` 等效，路径无效。
2. 站点放在子目录（`/site/`、`/CarLong/`）**必然失败**，必须搬到根。
3. `app-ads.txt` 必须直接 200（不能 301/302 跳别处；http→https 跳转不算，AdMob 本来就用 https）。

所以 GitHub Pages 有个坑：普通仓库部署出来的地址是 `https://user.github.io/CarLong/`，
文件在子路径，**抓不到**。要用 GitHub Pages 就必须建一个名字正好叫 `user.github.io`
的仓库，把 `site/` 里的文件平铺到那个仓库根。

Cloudflare Pages / Netlify / Vercel 没有这个问题 —— 部署根就是域名根。

### 5.2 `app-ads.txt` 内容

`site/app-ads.txt` 已经是真实值，纯文本、无 BOM：

```
google.com, pub-3751874625509987, DIRECT, f08c47fec0942fa0
```

publisher 段必须与 `AndroidManifest.xml` 的 App ID 一致（`tool/check_site.py` 会自动比对）。

### 5.3 商店里填在哪

| 平台 | 字段 | 填什么 | 必填？ |
|---|---|---|---|
| App Store Connect | App 信息 → 支持网址 | `https://<域名>/support.html` | **必填** |
| App Store Connect | App 隐私 → 隐私政策网址 | `https://<域名>/privacy.html` | **必填** |
| App Store Connect | App 信息 → 营销网址 | `https://<域名>`（只填域名） | 选填，但填了才能反查 app-ads.txt |
| Google Play | 商店设置 → 隐私政策 | `https://<域名>/privacy.html` | **必填**（收集数据时） |
| Google Play | 商店设置 → 开发者网站 | `https://<域名>`（只填域名） | 选填，同上 |
| AdMob | 应用设置 → 隐私政策网址 | `https://<域名>/privacy.html` | 建议填 |
| AdMob | UMP → GDPR 消息 → 隐私政策网址 | `https://<域名>/privacy.html` | **必填** |

**AdMob 验证 app-ads.txt 的三个前提**（缺一个就永远验证不过）：

1. 应用**已上架**，或 AdMob 应用设置里已填商店链接；
2. 商店里的开发者网站域名 = `app-ads.txt` 所在域名；
3. 抓取有延迟，提交后几小时到一天生效，**别反复点验证**（点一次会重置）。

### 5.4 什么情况才值得买域名

满足任一条再买（`.com` 约 ¥80–110/年）：

- 准备长期做，以后要上第二个 App（多 App 共用一个根域最省事）；
- 需要 `support@你的域名` 这类邮箱；
- 想把域名印在商店页当身份。

不买的代价只有两条，都不影响上线：

| 风险 | 概率 | 影响 |
|---|---|---|
| 平台封号/误删项目，免费子域失效 | 低 | 商店里的隐私政策与支持链接全 404，可能被下架 |
| 以后换域名 | 必然 | 改 7 处字段 + `app-ads.txt` 重新验证（1 天窗口） |

**若确定要买，就现在买，别等上架后。** 现在站点还没被任何商店引用，换域名零成本；
上架后改开发者网站域名，AdMob 要重新验证，期间库存归属未验证。

> **备案**：域名解析到 Cloudflare / GitHub / Netlify 这类海外托管**不需要 ICP 备案**——
> 备案管的是国内服务器和国内 CDN，与域名本身无关。

> **页面已经生成好了**：`site/` 目录（`index.html` / `privacy.html` / `support.html` /
> `app-ads.txt` / `robots.txt` + `assets/`），纯静态、无 CDN 依赖、中英双语可切换，
> 条款与 `lib/services/ads/admob/` 的实际行为一一对应（无账号、进度仅在本地、
> 只有 AdMob 一个第三方、激励视频由玩家主动触发）。
>
> 部署步骤、商店字段对照表、验证用的三条 `curl` 都在 **`site/README.md`**。
> 部署前后各跑一次体检：
>
> ```bash
> python3 tool/check_site.py --strict
> ```
>
> 它会查：`app-ads.txt` 的 BOM / 换行 / 字段数 / cert 值 / **publisher 与
> AndroidManifest 是否同一个账号**、必需文件、所有本地链接、隐私政策 9 项必备条款、
> 残留占位符（`YOUR_EMAIL` / `example.com`）、以及有没有偷偷引用外部 CDN。
>
> **唯一必须手改的是邮箱**：`privacy.html` 与 `support.html` 里的
> `YOUR_EMAIL@example.com` 共 6 处，苹果审核会真的去点。

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
✅ AdMob 账号 + payments profile（能登录后台看付款/税务页 = 号已经有了）
✅ W-8BEN 已提交（2026-10-23，过期 2029-12-31）
🕐 身份验证审核中（1-2 工作日）→ 只把预扣税率从 30% 占位改为 0%，不阻塞下面任何一步
✅ 2 个 App ID + 10 个 unit（2026-10-23 建齐，publisher `3751874625509987`）
✅ 填值进工程（`AndroidManifest` / `Info.plist` / `ads.env.json`，闸门 11 通过 / 0 警告）
✅ Android 端首次构建成功（工具链对齐 Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20，§4.1）
✅ 路径 A 模拟器链路验证（`Test Ad` → `Reward granted` → 金币 195→295 → 剩余 3→2）
✅ 静态站生成（`site/` 三页 + app-ads.txt，体检 6 通过 / 1 警告 / 0 失败）
⬜ 换掉 `YOUR_EMAIL@example.com`（6 处）→ 免费托管上线（**不必买域名**）→ `check_site.py --strict` 全绿  ← §5，**下一步**
⬜ 调试机哈希加进 `ADMOB_TEST_DEVICE_IDS` + 真机四路径验证                ← §4
⬜ UMP 三条消息 Publish                                    ← §6
⬜ 商店素材 / 分级 / 封闭测试 14 天                          ← Play 个人号硬性要求
```

**「等税表通过」不是前置条件。** 常见的误判是把四件事当成一条串行链，实际只有一件被卡：

| 事 | 要等税表通过吗 |
|---|---|
| 建应用、拿 App ID | **不用**。未上架也能建，建应用时选「No, it's not listed on a store yet」 |
| 建广告单元、拿 10 个 unit ID | **不用** |
| 填值进工程、真机跑通广告 | **不用**。测试 unit 出画面、真实 unit 出画面但零收入，都与税表无关 |
| 域名 / 隐私政策 / UMP 消息 / 商店素材 | **不用** |
| 收入以 0% 预扣（而不是 30%） | **要等**。审核期间的收入照常累计，只是预扣 30%，批准后当年部分可退 |

所以别干等：审核在后台跑，你这边照常建应用和广告位。**唯一别做的是拿正式 unit 自己点**（无效流量会停号）。

应用上架后记得回 AdMob 把商店链接补上（应用详情页「应用商店」字段），否则广告可能被限流。


填完值后自查一条命令：

```bash
python3 tool/check_ads_release.py --strict
```

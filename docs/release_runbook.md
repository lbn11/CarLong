# 上架操作手册：一步一步照做

只列**还没做**的动作，按顺序执行。细节要查时再去翻
`admob_setup_guide.md`（广告）和 `store_launch_overseas.md`（商店）。

**排期唯一要记住的事**：Google Play 个人号要求「20 人封闭测试满 14 天」才能发正式版。
这件事**越早启动越好**，别等包做完才开始数这 14 天。

---

## 第 1 步：开发者账号（没有它后面一步都做不了）

**换链接、传包、填问卷，全都在商店后台里做——而进后台的前提是账号 + 已建好的
「应用条目」。所以这一步才是真正的起点，不是"5 分钟收尾"。**

| 账号 | 费用 | 状态 |
|---|---|---|
| Google Play 开发者 | $25 一次性 | 个人号已注册（还需走身份验证） |
| Apple Developer Program | $99/年 | **需确认有没有**——没有的话 iOS 一切免谈 |

没有 Apple 账号就先去 <https://developer.apple.com/programs/> 注册，个人号即可
（会显示你的真实姓名），公司号要 D-U-N-S（免费但 1-2 周）。

- [ ] Play Console 能用：进 <https://play.google.com/console> 看得到界面
- [ ] App Store Connect 能用：进 <https://appstoreconnect.apple.com> 看得到界面

---

## 第 2 步：建「应用条目」（链接就是填在这里面的）

- [ ] **Play Console** → 右上角「创建应用」→ 填应用名、默认语言（英语）、
      应用类型选**游戏**、免费 → 创建
- [ ] **App Store Connect** → 我的 App → 左上角 `+` → 新建 App
      （需要先在 Apple Developer 后台的 Certificates, Identifiers & Profiles
      里注册好 Bundle ID，与工程里的 `com.xxx` 一致）

> 建条目本身不需要安装包，随时可以建。**建完才能填隐私政策链接。**

---

## 第 3 步：填三个链接 + 删掉旧的 Workers 站

- [ ] 把商店里的三个链接填成新地址（旧的 `workers.dev` 会 404）：

  | 字段 | 填什么 | 在哪 |
  |---|---|---|
  | 隐私政策链接 | `https://carlong.pages.dev/privacy` | Play：政策 → 应用内容 → 隐私政策；Apple：App 信息 → Privacy Policy URL |
  | 技术支持链接 | `https://carlong.pages.dev/support` | Play：版本页面；Apple：版本 → Support URL |
  | 开发者网站 | `https://carlong.pages.dev` | Play：设置 → 商店设置；Apple：App 信息 → Marketing URL |

- [ ] 换完链接后，删掉废弃的 Workers 项目
  （Workers 和 Pages → `carlong` → 设置 → 最底下「删除」。
  **看清是 `workers.dev` 那个，别删 `pages.dev` 的**）

---

## 第 4 步：真机广告验证（必须在换正式包之前做）

**红线：绝不能拿自己的正式广告位在自己手机上反复点。** 那是无效流量，
AdMob 第一次警告、第二次直接停号。正确做法是把调试机加进测试设备列表。

1. 手机连电脑（或开一个**带 Google Play** 的模拟器，AOSP 镜像不行），跑：

   ```bash
   flutter run --dart-define-from-file=ads.env.json
   ```

2. 日志里搜 `setTestDeviceIds`，拿到你设备的哈希
   （Android 形如 `3F2A5C9D...`；iOS 是 40 位十六进制）

3. 写进 `ads.env.json`（**这个文件不入库，别提交**）：

   ```
   "ADMOB_TEST_DEVICE_IDS": "3F2A5C9D..., 另一台设备"
   ```

   多台设备英文逗号分隔。

4. 重新构建。之后你手机请求到的都是测试广告：
   **右上角必须有「Test Ad」角标**——看不到说明没识别成功，别继续点。

5. 五个广告位各走一遍，判据三条同时成立：
   出现 `Reward granted` → 金币到账 → 该点位当日剩余次数 -1

   - [ ] 商店 +100 金币
   - [ ] 停车/合成 复活
   - [ ] 双倍奖励
   - [ ] 撤销
   - [ ] 提示

6. 再走四条失败路径：**中途关闭**（不发奖）、**飞行模式**（无填充，不崩）、
   **当日上限**（拦住并给提示）、**冷却中**（12 秒内重复点被拦）

详细坑位见 `admob_setup_guide.md` §4。

---

## 第 5 步：UMP 三条消息发布（不发 = 欧盟永远不弹窗）

AdMob 后台 → **Privacy & messaging** → 建三条并逐个 **Publish**：

| 消息 | 覆盖 | 要点 |
|---|---|---|
| GDPR | 欧盟/英国/瑞士 | 必须有「Consent」和「Do not consent」两个选项；隐私政策 URL 填上面的地址 |
| US states | 加州等 | CCPA，提供「Do not sell/share」入口 |
| IDFA explainer | iOS 全局 | iOS 上先解释再弹 ATT，通过率更高 |

**Draft 不算数，必须 Publish。** 没发布时代码不会报错，只是欧盟用户永远看不到表单——
属于「代码没问题、合规不合格」。

---

## 第 6 步：商店素材

- [ ] 截图：手机截图 **至少 4 张**（两种玩法各两张），尺寸用商店要求的标准
- [ ] 图标：1024×1024（项目里 `tool/make_icon.py` 已生成）
- [ ] 简短描述 / 完整描述（英文）
- [ ] 关键词
- [ ] 年龄分级问卷：按「非儿童应用」申报（别勾儿童，否则个性化广告违规）

---

## 第 7 步：Google Play（尽早，因为要数 14 天）

1. 构建正式包：

   ```bash
   flutter build appbundle --release --dart-define-from-file=ads.env.json
   ```

2. Play Console → 创建应用 → 上传 `.aab`
3. 填 Data safety 表单（声明广告 ID、无账号体系、进度仅本地——与隐私政策一致）
4. 内容分级问卷
5. **开封闭测试**：邀请 20 个测试者，跑满 14 天
6. 14 天后申请正式发布

⚠️ Data safety 里声明的内容必须和网站隐私政策**一字一句对得上**，
对不上就是「声明与实际不一致」的下架级问题。

---

## 第 8 步：iOS（App Store）

1. 构建：

   ```bash
   flutter build ipa --release --dart-define-from-file=ads.env.json
   ```

2. App Store Connect → 新建 App → 填信息 → 上传（Xcode Transporter 或 `xcrun altool`）
3. 填 **App Privacy** 问卷（同 Data safety 口径）
4. 提交审核

---

## 第 9 步：提审前必跑（一条命令把机械检查做完）

```bash
python3 tool/check_ads_release.py --strict
```

会把 App ID / 10 个 unit / 隐私清单 / SKAdNetwork / ATT / 竖屏声明一次查完，
**全绿再提审**。

另外手工确认两条：

- [ ] 设置页「广告自检」显示**正式广告**（不是 Mock、不是测试库存）
- [ ] release 包里没有调试入口

---

## 不用等的事

W-8BEN 税表审核（1-2 工作日）**不阻塞上面任何一步**。它只影响预扣税率
（审核期按 30% 占位，批准后当年部分可退）。唯一要避开的还是那句：
**别拿正式 unit 自己点广告**。

应用上架后回 AdMob 把商店链接补进应用详情的「应用商店」字段，否则广告可能被限流。

# 静态站（域名三件套）

提审与广告反劫持的硬门槛，三样东西必须挂在**同一个域名的根目录**下：

| 路径 | 文件 | 谁要看 |
|---|---|---|
| `/privacy` | `privacy.html` | App Store Connect 必填、Play 商店必填、AdMob UMP 消息里要填 |
| `/support` | `support.html` | Apple 审核要求有支持入口 |
| `/app-ads.txt` | `app-ads.txt` | AdMob 反查归属，**不挂 = 广告库存可能被第三方劫持** |

`index.html` 是落地页，商店里的「开发者网站 / 营销网址」填它就够了。

## 唯一需要你替换的东西

把 `privacy.html` 和 `support.html` 里的 `YOUR_EMAIL@example.com` 换成真实可用邮箱
（共 6 处，一条命令搞定）：

```bash
cd /Users/apple/Downloads/CarLong
sed -i '' 's/YOUR_EMAIL@example.com/你的邮箱@gmail.com/g' site/privacy.html site/support.html
python3 tool/check_site.py --strict   # 这条必须 0 警告 0 失败
```

> 苹果审核会**真的去点**这个邮箱，填不可用的地址等于自己给自己制造打回理由。

## 部署（选一个，都免费）

### A. Cloudflare Pages（推荐）

自定义域名免费、自动 HTTPS、支持根目录文件：

```bash
npm i -g wrangler
wrangler pages deploy site --project-name carlong
# 首次会要求登录，之后给一个 https://carlong.pages.dev
```

然后在 Cloudflare 里绑自己的域名（`carlong.app` 之类），并把**根域**指向 Pages 项目。

### B. GitHub Pages

仓库 Settings → Pages → Source 选 `main` 分支 `/site` 目录。
缺点：`*.github.io` 域名能验证 app-ads.txt，但商店里填 github.io 显得不专业；建议绑自定义域名。

### C. 已有服务器 / 对象存储

把 `site/` 里的内容**平铺**到网站根目录（不是 `/site/` 子目录）。对象存储要允许
`text/plain` 直接返回，不能是下载弹窗。

## 验证（部署完立刻跑）

```bash
# 1. 必须是 200 + text/plain，不能是 301/302 跳到别处
curl -sI https://你的域名/app-ads.txt | head -3
curl -sI https://你的域名/privacy.html | head -3

# 2. 内容必须一字不差
curl -s https://你的域名/app-ads.txt
# 期望：google.com, pub-3751874625509987, DIRECT, f08c47fec0942fa0

# 3. 不能带 BOM、不能有 CRLF
curl -s https://你的域名/app-ads.txt | xxd | head -2
# 行首应该是 00000000: 676f 6f67 6c65 ...（google），不是 efbb bf
```

## 商店里填在哪

| 平台 | 字段 | 填什么 |
|---|---|---|
| App Store Connect | App 信息 → 营销网址 | `https://你的域名`（**只填域名，不要带路径**） |
| App Store Connect | App 隐私 → 隐私政策网址 | `https://你的域名/privacy.html` |
| Google Play Console | 商店设置 → 开发者网站 | `https://你的域名`（只填域名） |
| Google Play Console | 商店设置 → 隐私政策 | `https://你的域名/privacy.html` |
| AdMob | 应用设置 → 隐私政策网址 | `https://你的域名/privacy.html` |
| AdMob | UMP → GDPR 消息 → 隐私政策网址 | `https://你的域名/privacy.html` |

**AdMob 验证 app-ads.txt 的三个前提**（缺一个就永远验证不过）：

1. 应用**已上架**（或 AdMob 应用设置里已填商店链接）；
2. 商店里的开发者网站域名 = `app-ads.txt` 所在域名；
3. 抓取有延迟，提交后几小时到一天才生效，别反复点验证。

## 本地预览

```bash
python3 -m http.server -d site 8080
# 打开 http://localhost:8080
```

页面右上角有中英切换，选择记在 localStorage；不依赖 CDN，断网也能正常显示。

## 体检脚本做什么

`python3 tool/check_site.py [--strict]`

- `app-ads.txt`：BOM / 换行 / 字段数 / domain / publisher 与 `AndroidManifest` 一致性 / cert 值
- 必需文件是否齐全
- 所有本地链接是否都能命中（防止改名后 404）
- 隐私政策必备条款：Google 隐私链接、广告标识符、退出方式、儿童条款、CCPA、联系方式
- 是否残留 `YOUR_EMAIL` / `example.com` 占位符
- 是否引用了外部 CDN（离线会白页）

> 改完隐私政策记得同步改页面顶部的「最后更新 / Last updated」日期。
> 条款本身是和 `lib/services/ads/admob/` 的实际行为对齐的：没有账号、进度只在本地、
> 只有 AdMob 一个第三方、激励视频由玩家主动触发 —— 如果以后加了分析 SDK 或内购，
> 这一页必须跟着改，否则就是「隐私声明与实际行为不一致」，这是商店下架级问题。

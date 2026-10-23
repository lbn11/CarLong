# 静态站（站点三件套）

提审要用到的三样东西，都放在**同一个站点**上就够：

| 路径 | 文件 | 谁要看 | 是否硬门槛 |
|---|---|---|---|
| `/privacy` | `privacy.html` | App Store Connect、Play 商店、AdMob UMP | **是** |
| `/support` | `support.html` | App Store Connect「支持网址」 | **是** |
| `/app-ads.txt` | `app-ads.txt` | AdMob 验证库存归属 | 否，但影响 eCPM 上限 |

前两个只要「能打开」就行，放哪个域名、哪个子路径都无所谓。
`app-ads.txt` 例外 —— 它**必须在域名根目录**，原因见 §抓取规则。

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

**不需要买域名。** 商店审核和 AdMob 只认「地址能不能打开」，不认域名是不是你自有的。
免费平台给的子域一样过审、一样能验证 `app-ads.txt`。

三个方案唯一的差异在一个技术点：**`app-ads.txt` 必须在域名根目录**。
原因见 §抓取规则 —— AdMob 会丢掉路径，只请求 `https://<域名>/app-ads.txt`。

| 方案 | 免费域名 | 能否放根 | 备注 |
|---|---|---|---|
| Cloudflare Pages | `carlong.pages.dev` | ✅ 部署根就是域名根 | **推荐**，带宽不限 |
| Netlify | `carlong.netlify.app` | ✅ | 免费额度 100GB/月 |
| Vercel | `carlong.vercel.app` | ✅ | 免费额度 |
| GitHub Pages | `user.github.io` | ⚠️ 仅当**仓库名就是 `user.github.io`** | 普通仓库站点在 `/reponame/`，抓不到 |
| Notion / Google Sites | — | ❌ 无法放根文件 | 只能当隐私政策页，做不了 app-ads.txt |

### A. Cloudflare Pages（推荐）

```bash
npm i -g wrangler
wrangler pages deploy site --project-name carlong
# 首次会要求登录，之后给一个 https://carlong.pages.dev
```

**这一步做完就已经能提审了**，不用再绑域名。以后想绑自己的域名（`carlong.app` 之类），
在 Cloudflare 里把根域指到同一个 Pages 项目即可，文件不用重新部署。

### B. GitHub Pages

普通做法（Settings → Pages → Source 选 `main` 分支 `/site` 目录）部署出来的地址是
`https://user.github.io/CarLong/`，`app-ads.txt` 落在 `/CarLong/app-ads.txt` ——
**AdMob 抓不到**，它只请求域名根。

要用 GitHub Pages，就得**新建一个仓库，名字正好是 `user.github.io`**（GitHub 的保留名），
把 `site/` 里的文件**平铺**到该仓库根目录，而不是放在 `site/` 子目录里。

### C. 已有服务器 / 对象存储

把 `site/` 里的内容**平铺**到网站根目录（不是 `/site/` 子目录）。对象存储要允许
`text/plain` 直接返回，不能是下载弹窗。

> **备案**：域名解析到 Cloudflare / GitHub / Netlify 这类海外托管**不需要 ICP 备案**——
> 备案管的是国内服务器和国内 CDN，与域名本身无关。

## 抓取规则（为什么路径会被丢掉）

AdMob 验证 `app-ads.txt` 的完整链路：

```
App Store / Play 商店页里的「开发者网站」
   → 取它的域名（路径部分丢弃）
   → 请求 https://<域名>/app-ads.txt
   → 逐行比对 publisher ID 是不是你的
```

三条推论，每一条都踩过坑：

1. 开发者网站填 `https://xxx.com/anything` 和填 `https://xxx.com` 效果相同，路径无效。
2. 站点部署在子目录（`/site/`、`/CarLong/`）**一定失败**，必须搬到根。
3. 不能有 301/302 跳到别处，`app-ads.txt` 必须直接 200（http → https 的跳转不算，
   因为 AdMob 本来就请求 https）。

## 不买域名的真实代价

| 风险 | 概率 | 影响 | 怎么防 |
|---|---|---|---|
| 平台封号 / 误删项目，免费子域失效 | 低 | 商店里的隐私政策与支持链接全 404，可能被下架 | 别用可疑平台；页面在 git 里，随时能重新部署 |
| 以后想换域名 | 必然 | 改 5 处商店/AdMob 字段 + `app-ads.txt` 重新验证（几小时到一天，期间库存归属未验证） | 迁移前先在旧域 301 到新域，验证通过再撤 |
| 商店页显示 `xxx.pages.dev` | 必然 | 只是观感，审核方不因此打回 | 无 |

**什么时候该买**（满足任一条就买，¥80–110/年）：

- 准备长期做、以后要上第二个 App（多 App 共用一个根域最省事）
- 需要 `support@你的域名` 这类邮箱
- 要把域名印在商店页上当作身份

**如果确定要买，就现在买，别等上架后。** 上架后改开发者网站域名，AdMob 要重新验证，
中间有 1 天左右 `app-ads.txt` 未生效的窗口，那段时间库存归属无法验证。
现在站点还没被任何商店引用，换域名零成本。

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

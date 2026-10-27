# 把网站传到 Cloudflare Pages（免费，不用买域名）

全程 0 元，不需要信用卡，不需要买域名，10 分钟能搞定。

## 第一步：注册账号

打开 <https://dash.cloudflare.com>，用邮箱注册一个 Cloudflare 账号并登录。
（就一个普通账号，不用开付费套餐，什么都别买。）

## 第二步：进到上传页面

1. 登录后左侧菜单点 **Workers 和 Pages**
2. 右上角点 **创建**（Create）
3. 切到 **Pages** 标签页
4. 选 **上传资产**（Upload assets）—— 就是"直接把文件夹扔上来"，不用连 GitHub

## 第三步：给项目起名

项目名填 **`carlong`**（只能小写字母、数字、短横线）。

这个名字直接决定你的网址，起完就是：

```
https://carlong.pages.dev
```

## 第四步：上传文件夹

把项目里的 **`site` 文件夹整个拖进去**（或者点选择文件，把 `site` 里面的
`index.html`、`privacy.html`、`support.html`、`app-ads.txt`、`robots.txt`、
`assets` 一起选中）。

然后点 **部署**（Deploy），等一两分钟就好。

> ⚠️ 如果部署完打开首页是空白或者显示一个文件列表，说明多套了一层
> （网址变成了 `.../site/index.html`）。解决办法：回到上传，这次**选中文件夹里面的
> 所有文件**再拖，不要拖文件夹本身。

## 第五步：验收（这 4 个地址必须都能打开）

部署完 Cloudflare 会给你网址，把下面的 `carlong` 换成你实际的项目名，
逐个在浏览器里打开确认：

| 地址 | 应该看到什么 |
|---|---|
| `https://carlong.pages.dev/` | 游戏介绍首页 |
| `https://carlong.pages.dev/privacy.html` | 隐私政策（英文，底部有中文版） |
| `https://carlong.pages.dev/support.html` | 技术支持页，能看到你的邮箱 |
| `https://carlong.pages.dev/app-ads.txt` | 只有一行字：`google.com, pub-3751874625509987, DIRECT, f08c47fec0942fa0` |

第 4 个尤其重要：它是给 AdMob 看的"认领声明"，证明这个广告位是你的。
放在根目录才有效，放在子目录里等于没有。

## 第六步：把这 3 个链接填进商店

上架时的表单里这么填（**网址末尾不要带 `index.html`**）：

| 表单里的字段 | 填什么 |
|---|---|
| 隐私政策链接（两个商店都要，必填） | `https://carlong.pages.dev/privacy.html` |
| 技术支持链接（苹果要，必填） | `https://carlong.pages.dev/support.html` |
| 开发者网站 / 官网（选填，但建议填） | `https://carlong.pages.dev` |

**开发者网站必须填网址根目录**，不能填 `https://carlong.pages.dev/index.html`。
AdMob 是靠这个域名反查你的 `app-ads.txt` 的，填错了就等于没认领。

## 以后怎么改内容

- 改了 `site/` 里的文件 → 进 Cloudflare 的这个项目 → **创建部署** → 重新拖一次文件夹。
  **网址不会变**，商店里填的链接也不用改。
- 嫌每次手动拖麻烦 → 在项目里连一下 GitHub，以后推送自动更新。
- 哪天想买域名了 → 项目里点 **自定义域** 绑上去就行，原来的 `pages.dev` 网址依然能用。

## 一个小提醒

隐私政策页上写了你的真实邮箱，网站上线后会被爬虫扫到，偶尔会收到垃圾邮件。
这是上架的硬性要求（苹果审核员会真的去点这个邮箱能不能收信），没法避免，
嫌烦的话可以专门注册一个 Gmail 小号来用。

## 上线前本机自检

改完任何文件，在本机跑一遍：

```bash
python3 tool/check_site.py --strict
```

必须显示 **7 通过 / 0 警告 / 0 失败** 才能传。

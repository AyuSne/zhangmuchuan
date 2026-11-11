# 使用手册：怎么用这个博客

> 站点：<https://ayusne.github.io/zhangmuchuan/>
> 仓库：<https://github.com/AyuSne/zhangmuchuan>

这个博客没有后台、没有数据库。**文章就是仓库里的 Markdown 文件，`git push` 就是发布。**

下面按“想干什么”组织，可以只看你需要的那一节。

---

## 1. 本地环境（只需配置一次）

Hugo 和 Go 已经下载在项目的 `.tools/` 里（该目录不进 Git）。每次新开终端，先执行：

```powershell
cd "D:\AAA个人博客网站"

$env:PATH = "$PWD\.tools\go\bin;$PWD\.tools\hugo;$env:PATH"
$env:GOWORK = "off"
$env:HUGO_MODULE_WORKSPACE = "off"
```

验证：

```powershell
hugo version    # 应显示 v0.169.0 ... +extended
go version      # 应显示 go1.27.3
```

> 换电脑或 `.tools/` 被删时，需要重新下载：Hugo Extended 0.169.0 和 Go 1.27.3，解压到 `.tools/go`、`.tools/hugo`。也可以直接装到系统里，那样就不用每次设 PATH。

---

## 2. 本地预览

在项目根目录：

```powershell
hugo server --bind 127.0.0.1 --port 1313
```

打开 <http://localhost:1313/>。改文件会自动刷新，`Ctrl+C` 停止。

默认预览和正式构建都不会显示草稿。如需预览草稿，运行：

```powershell
hugo server --bind 127.0.0.1 --port 1313 --buildDrafts
```

---

## 3. 写一篇文章

### 3.1 新建文件

推荐用**页面文件夹**（page bundle），文章和它的图片放在一起：

```text
content/blog/my-first-post/
├── index.md
└── cover.png
```

文件夹名就是 URL：`content/blog/my-first-post/` → `/blog/my-first-post/`。建议用英文或拼音，避免中文 slug 带来的编码问题。

手动建：

```powershell
mkdir content/blog/my-first-post
notepad content/blog/my-first-post/index.md
```

### 3.2 开头写 front matter

```yaml
---
title: 我的第一篇文章
date: 2026-11-01
description: 一句话摘要，会显示在列表卡片、搜索结果和分享预览里。
tags: [随笔, 建站]
---
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `title` | 是 | 文章标题 |
| `date` | 是 | 发布日期，格式 `2026-11-01`；未来日期默认不发布 |
| `description` | 建议 | 摘要，用于卡片和 SEO |
| `tags` | 可选 | 数组，例如 `[Hugo, 建站]`；会生成 `/tags/xxx/` 页面 |
| `draft` | 可选 | `true` 表示草稿，正式构建时跳过 |
| `slug` | 可选 | 自定义 URL 末段，默认用文件夹名 |

### 3.3 写正文

front matter 的 `---` 之后就是正文，用 Markdown：

```markdown
这是第一段。

## 二级标题 {#custom-id}

- 列表项
- 另一个

代码块用三个反引号包起来。

> 引用

[链接](https://example.com)
```

OINK 还支持标签页、步骤条、卡片等原生 Markdown 扩展，需要时参考 <https://oink.pgsty.com/docs/components/>。

### 3.4 放图片

把图片放进文章文件夹，正文用相对路径：

```markdown
![封面](cover.png)
```

这样绑定自定义域名后图片也不会失效（不要写 `/images/...` 这种以斜杠开头的路径）。

### 3.5 添加译文

翻译工作文件存放在项目根目录的 `翻译/`，使用项目内的 [baoyu-translate 技能](../../AAA个人博客网站资料/.agents/skills/baoyu-translate/SKILL.md)处理：

1. 将原文章保存到 `翻译/原文/`，保留原文和可追溯的出处。
2. 将翻译产物放在 `翻译/翻译结果/`，可按文章分别建目录，保留技能生成的中间文件和最终译稿。
3. 按作者要求，将整理好的译稿和需要的插图适配到网站翻译栏目；注明原作者与原文链接。

`翻译/` 是被 Git 忽略的工作目录，网站使用的 `content/translations/` 则正常纳入 Git。提交、推送与上线以作者单独的发布请求为准。

译文放在独立的 `content/translations/<slug>/index.md` 目录，栏目地址是 `/translations/`。与博客文章一样填写标题、日期、摘要和标签，并在正文开头注明原作者和可访问的原文链接，例如：

```markdown
---
title: 中文译文标题
date: 2026-11-11
description: 一句话介绍这篇译文。
tags: [AI]
---

> 原文：[文章原题](https://example.com/original)；原作者：作者姓名

译文正文……
```

原文有可用的公开图片链接时，优先直接引用并保留图片说明；需要本地图片时，将图片放在对应文章目录并使用相对路径。新译文会自动出现在翻译栏目，也会参与首页最新文章排序。

### 3.6 草稿

先存着不发布：

```yaml
draft: true
```

本地用 `hugo server --buildDrafts` 能看到；推送到线上不会生成页面。写好后改成 `false` 再推。

### 3.7 系列文章和公式

需要把文章编成系列时，在每篇文章的 front matter 中填写相同的系列名和阅读顺序：

```yaml
series: [智能体第一性原理]
series_weight: 0
```

数字越小越靠前，同一系列的文章使用不同的数字。至少两篇文章可见时，文章页会显示系列导航；草稿不会出现在正式站点的系列目录中。

行内数学公式可以写成 `$E = mc^2$` 或 `\(E = mc^2\)`，独占一段的公式用 `$$` 包围。修改后请在本地预览中检查公式，并留意构建时的公式警告。

---

## 4. 发布文章

```powershell
git status                                  # 确认改了哪些文件
git add content/blog/my-first-post
git commit -m "post: 我的第一篇文章"
git push
```

推送后：

1. 打开 <https://github.com/AyuSne/zhangmuchuan/actions> 看构建，通常 30–60 秒。
2. 构建成功后访问 <https://ayusne.github.io/zhangmuchuan/blog/my-first-post/>。
3. 首页“最新文章”和 `/blog/` 列表会自动更新。

> 如果 `git push` 要求登录，先跑 `gh auth status` 确认已登录；没登录就 `gh auth login`。

---

## 5. 不想开本地环境：在网页上写

1. 打开仓库：<https://github.com/AyuSne/zhangmuchuan>
2. **Add file → Create new file**
3. 文件名输入 `content/blog/my-post/index.md`（输入 `/` 会自动建文件夹）
4. 粘贴 front matter + 正文
5. 页面底部 **Commit changes**，直接提交到 `main`

提交后同样会触发部署。

传图片：进入 `content/blog/my-post/` 文件夹 → **Add file → Upload files** → 上传后按文件名引用。

> 网页编辑器适合改错别字、发短文；长文还是本地写更舒服。

---

## 6. 改站点本身

| 想改什么 | 改哪里 |
|---|---|
| 站点标题 | `hugo.yaml` 的 `title:` |
| 站点描述 | `hugo.yaml` → `languages.zh.params.description` |
| 首页文案 | `data/home/zh.yaml`（hero、最新文章、入口卡片） |
| 关于页 | `data/landing/about/zh.yaml`（hero + markdown.body） |
| 导航菜单 | `content/blog/_index.md` 和 `content/about.md` 的 `menus.main`（`weight` 越小越靠前） |
| 视觉风格 | `hugo.yaml` → `params.ui.preset`：`paper` / `slate` / `ink` / `terminal` |
| 强调色 | 取消注释 `params.ui.theme_color`，填 `#rrggbb` |
| 搜索开关 | `params.offline_search`（默认开） |
| 评论 | 见第 8 节 |

改完推送即可，和发文章一样 `git add -A` → `commit` → `push`。

---

## 7. 绑定自己的域名

以 `zhangmuchuan.com` 为例：

### 7.1 买域名

在 Cloudflare、Porkbun、Namecheap 或阿里云注册（阿里云需要实名认证）。

### 7.2 配 DNS

在域名注册商的 DNS 设置里加：

| 类型 | 主机记录 | 值 |
|---|---|---|
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| CNAME | `www` | `ayusne.github.io` |

### 7.3 在 GitHub 里绑定

仓库 **Settings → Pages → Custom domain** 填 `zhangmuchuan.com` → **Save**。等 DNS 检查通过后，勾选 **Enforce HTTPS**。

### 7.4 改配置并推送

```yaml
# hugo.yaml
baseURL: https://zhangmuchuan.com/
```

然后 `git push`。工作流会自动用 Pages 的实际地址构建，部署后访问 <https://zhangmuchuan.com/>。

> DNS 生效可能要几分钟到几小时；HTTPS 证书要等 GitHub 签发，签发前不要急着开 Enforce HTTPS。

---

## 8. 开启评论（Giscus）

评论基于 GitHub Discussions，访客需用 GitHub 账号登录。

1. 仓库 **Settings → General → Features**，勾选 **Discussions**。
2. 安装 giscus App：<https://github.com/apps/giscus>，只授权这个仓库。
3. 打开 <https://giscus.app>，填入 `AyuSne/zhangmuchuan`，选择分类（如 `Announcements`），复制生成的 `repoId` 和 `categoryId`。
4. 在 `hugo.yaml` 里把注释掉的 `comments` 块改成：

```yaml
comments:
  enable: true
  type: giscus
  giscus:
    repo: AyuSne/zhangmuchuan
    repoId: R_xxxxxxxxxx
    category: Announcements
    categoryId: DIC_xxxxxxxxxx
    mapping: pathname
    inputPosition: bottom
    theme: auto
    loading: lazy
```

5. 推送。

---

## 9. 常见问题

| 现象 | 原因与处理 |
|---|---|
| 线上 404 / 样式丢失 | `baseURL` 和实际地址不一致。项目站点必须是 `https://ayusne.github.io/zhangmuchuan/`（带子路径）；绑定域名后改成根路径。注意工作流会用 Pages 地址覆盖，本地预览以 `hugo.yaml` 为准。 |
| 文章没出现在线上 | 检查 `draft: true`、`date` 是否在未来、文件是否在 `content/blog/` 下。 |
| 图片 404 | 图片是否和 `index.md` 在同一文件夹、文件名大小写是否一致。不要用以 `/` 开头的绝对路径。 |
| 构建失败 | 打开 Actions 看日志；本地跑 `hugo --printPathWarnings` 复现。 |
| `hugo` 命令找不到 | 没设 PATH。按第 1 节设置，或用 `.\tools\hugo\hugo.exe` 全路径。 |
| 拉取 OINK 模块很慢 | 设 `$env:GOPROXY = "https://goproxy.cn,direct"` 再构建。 |
| 推送要求密码 | `gh auth status` 检查登录，或跑 `gh auth login`。 |
| 中文 URL 显示乱码 | 文章文件夹改用英文/拼音。 |
| 想删掉示例文章 | `git rm -r content/blog/hello-world.md` 等，再推送。 |

---

## 10. 命令速查

```powershell
# 进入项目并准备工具链
cd "D:\AAA个人博客网站"
$env:PATH = "$PWD\.tools\go\bin;$PWD\.tools\hugo;$env:PATH"
$env:GOWORK = "off"; $env:HUGO_MODULE_WORKSPACE = "off"

# 本地预览（改文件自动刷新）
hugo server --bind 127.0.0.1 --port 1313

# 生产构建（产物在 public/，已在 .gitignore 里）
hugo --cleanDestinationDir --gc --minify --environment production --printPathWarnings

# 发布
git add -A
git commit -m "post: 文章标题"
git push

# 看部署状态
gh run list --limit 5
gh run watch

# 看线上地址
gh repo view --web
```

---

## 11. 这个博客的术语

见 [`GLOSSARY.md`](../GLOSSARY.md)：

- **站点**：整个网站（首页 + 博客 + 关于）
- **博客**：长文栏目
- **文章**：博客里的一篇
- **首页**：入口页
- **关于**：介绍页

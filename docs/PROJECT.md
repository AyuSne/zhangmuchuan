# 项目总结：张暮川的个人博客

> 状态：已上线
> 线上地址：<https://ayusne.github.io/zhangmuchuan/>
> 仓库：<https://github.com/AyuSne/zhangmuchuan>

## 1. 目标

一个面向技术读者的个人站点：首页介绍自己，博客放长文，翻译收录中文译文，关于页交代背景。阅读体验参考 vonng.com，但内容、配置和文章全部自己写，不复制它的仓库。

## 2. 时间线

| 时间 | 做了什么 |
|---|---|
| 2026-10-31 | 建仓库 `AyuSne/zhangmuchuan`，配置技能（issue tracker、triage 标签、`AGENTS.md`、`docs/agents/`） |
| 2026-10-31 | `/grill-with-docs` 设计访谈：确定中文单语、首页/博客/关于三区，不做笔记与文档区 |
| 2026-10-31 | 记录 ADR-0001：Hugo + OINK + GitHub Pages，并写入 `GLOSSARY.md` 术语表 |
| 2026-10-31 | `/implement`：从 `oink-starter` 起步，改造成中文单语博客，加自定义“最新文章”区块 |
| 2026-10-31 | `/code-review`：修复版本基线漂移、术语冲突、README 路径错误，关闭 categories |
| 2026-10-31 | 首次部署成功，站点上线 |
| 2026-11-08 | 删除三篇示例文章，发布“智能体第一性原理”系列（数学基石篇 + 前五篇），补齐系列内引用链接 |
| 2026-11-09 | 新增两篇 Agent Memory 专题（框架、记忆维护），统一博客插图风格 |
| 2026-11-11 | 开通翻译栏目，上线首批译文；新增“Matt Pocock Skills”系列，同期修订 Skills 文章的渐进式披露说明 |
| 2026-11-12 | 补 Skills 第五篇任务切片插图与“实现交付”篇，更新智能体记忆专题 |
| 2026-11-13 | 首页增加翻译栏目入口，更新 Skills 系列与 Agent 记忆文章 |
| 2026-11-13 | OINK 升级到 v1.5.1（构建基线 Hugo 0.169.0 不变）；隔离构建核对：107 页、产物文件集合与 1.4.0 一致，差异仅无障碍文案、归档分页语义、404 外壳与 RSS 日期 |

## 3. 技术选型

| 层 | 选择 | 理由 |
|---|---|---|
| 生成器 | Hugo Extended 0.169.0 | 构建快、纯静态、无运行时依赖 |
| 主题 | OINK 1.5.1（Apache-2.0） | 阅读排版、本地搜索、深浅色、组件齐全，不需要 Node.js |
| 内容 | Markdown + page bundle | 版本可控、图片随文章走、随时迁移、没有数据库 |
| 部署 | GitHub Actions → GitHub Pages | 零成本、`git push` 即发布 |
| 本地工具链 | `.tools/` 下的 Go 1.27.3 + Hugo（已 gitignore） | 不改系统环境，版本与 CI 一致 |

不选 Cloudflare Pages、Astro/Next 自建、复制 vonng.com 的原因记录在
[`docs/adr/0001-hugo-oink-static-site.md`](./adr/0001-hugo-oink-static-site.md)。

## 4. 仓库结构

```text
.
├── hugo.yaml                     # 全站唯一配置：标题、语言、菜单、Paper 风格、搜索、模块
├── go.mod / go.sum               # 固定 OINK v1.5.1
├── content/
│   ├── _index.md                 # 首页 front matter
│   ├── blog/
│   │   ├── _index.md             # 博客栏目：菜单项、cascade 类型
│   │   └── <slug>/               # 每篇一个 page bundle
│   │       ├── index.md
│   │       └── images/           # 插图，正文用相对路径引用
│   ├── translations/
│   │   ├── _index.md             # 翻译栏目：type: blog、菜单项、cascade
│   │   └── <slug>/index.md       # 译文，正文开头注明原作者与原文链接
│   └── about.md                  # 关于页外壳（layout: landing）
├── data/
│   ├── home/zh.yaml              # 首页内容：hero、最新文章、入口卡片
│   └── landing/about/zh.yaml     # 关于页正文
├── layouts/partials/custom/
│   └── latest-posts.html         # 首页“最新文章”区块（合并 blog 与 translations 排序）
├── .github/workflows/
│   └── github-pages.yaml         # 构建并发布到 Pages
├── static/favicon.svg            # 站点图标
├── assets/icons/logo.svg         # 站点 logo
├── .agents/skills/               # 技能仓库内副本（27 个，版本锁在 skills-lock.json）
├── docs/
│   ├── adr/0001-…md              # 架构决策记录
│   ├── agents/                   # 技能配置（issue tracker、triage、domain docs）
│   ├── PROJECT.md                # 本文
│   └── GUIDE.md                  # 使用手册
├── 翻译/                          # 翻译工作目录（原文、中间产物、译稿），已 gitignore
├── AGENTS.md                     # 构建基线 + 仓库卫生规则
├── GLOSSARY.md                   # 站点/首页/博客/文章/翻译/关于 的术语
├── README.md                     # 快速开始
├── skills-lock.json              # 技能版本锁
└── THIRD_PARTY.md                # 第三方组件与许可证
```

`public/`、`resources/`、`.tools/`、`翻译/` 都不进 Git；仓库只跟踪 199 个源文件。

## 5. 部署链路

```text
git push origin main
  └─ GitHub Actions (.github/workflows/github-pages.yaml)
       ├─ checkout（fetch-depth: 0，供 enableGitInfo 用）
       ├─ setup-go 1.27.3
       ├─ configure-pages（读取 Pages 地址）
       ├─ install Hugo Extended 0.169.0
       ├─ go mod download github.com/pgsty/oink
       ├─ hugo --cleanDestinationDir --gc --minify --environment production --baseURL <pages url>/
       └─ upload-pages-artifact → deploy-pages
            └─ https://ayusne.github.io/zhangmuchuan/
```

要点：

- 首次部署前，仓库 **Settings → Pages → Source** 必须选 **GitHub Actions**（已配置）。
- 工作流会用 Pages 的实际地址覆盖 `hugo.yaml` 的 `baseURL`，所以绑定自定义域名后无需改构建命令。
- 实测单次构建部署 41–54 秒，推送后到线上生效通常 1 分钟内。

## 6. 内容现状

- **首页**：hero 自我介绍 + 最新文章（blog 与 translations 合并按日期倒序取 3 篇）+ 三个入口卡片（博客、翻译、关于）。
- **博客**：19 篇长文，全部是 page bundle，插图 66 张。
- **翻译**：8 篇译文，复用博客模板，正文开头注明原作者与原文链接（多数另附原文发表时间）；其中 3 篇与站内原创长文构成“原创分析 + 同文译文”的配对。
- **关于**：landing 布局，文案在 `data/landing/about/zh.yaml`。
- **系列**：两个，都在文章页显示系列导航。
  - `智能体第一性原理`（7 篇，`series_weight` 0–6）：数学基石 → Agent Loop → 控制权 → Harness → 业务 → 行业 → 记忆。
  - `Matt Pocock Skills`（8 篇，`series_weight` 1–8）。
- **标签**：14 个标签页（`/tags/` 下），以 AI、Agent、软件工程为主，译文侧补充了中文主题词。
- **搜索**：OINK 本地搜索，构建时生成索引，无外部依赖。
- **评论**：关闭，Giscus 配置在 `hugo.yaml` 中以注释形式保留。
- **语言**：中文单语；英文已声明但禁用，为以后双语留位。

## 7. 质量检查

- 本地生产构建：**107 页，0 个路径警告**，仅有 OINK 上游的 LibSass 弃用警告（已接受，见 `AGENTS.md`）。
- 线上：首页 HTTP 200，内容与仓库一致；最新文章、入口卡片、翻译栏目均正常。
- CI：最近 5 次运行全部 `success`，耗时 41–54 秒。
- 仓库单一 `main` 分支，与 `origin/main` 同步推进；提交前确认工作区没有遗留改动。
- 建站期 `/code-review` 修掉的三个硬问题（Hugo 基线三处不一致、术语冲突、README 关于页路径错误）已闭环；Hugo 默认 `categories` 已关闭，只用 `tags` 与 `series`。

## 8. 已知限制与下一步

| 项 | 状态 | 下一步 |
|---|---|---|
| 自定义域名 | 未绑定；`zhangmuchuan.com` 查询时仍未注册 | 购买并按 `docs/GUIDE.md` 绑定 |
| 评论 | 关闭 | 需要时按 GUIDE 开启 Giscus |
| 英文 | 已声明、未启用 | 需要时添加 `.en.md` 翻译并启用 |
| logo / favicon | OINK Starter 的中性图标 | 有自己的标识后替换 |
| 标签词表 | 博客用 `Agent`、译文用 `AI Agent`，站上并存两个标签页 | 统一成一个词，或明确“原创 / 译文”分层规则 |
| 文档同步 | 本文已更新；`README.md` 的站点结构与 `docs/GUIDE.md` §11 术语表仍缺“翻译” | 下次改文档时一并补齐 |

## 9. 关键文件索引

- 写作与发布：`docs/GUIDE.md`
- 快速开始：`README.md`
- 架构决策：`docs/adr/0001-hugo-oink-static-site.md`
- 术语表：`GLOSSARY.md`
- 构建基线与仓库卫生：`AGENTS.md`
- 第三方许可证：`THIRD_PARTY.md`

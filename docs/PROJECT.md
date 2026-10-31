# 项目总结：张暮川的个人博客

> 状态：已上线
> 线上地址：<https://ayusne.github.io/zhangmuchuan/>
> 仓库：<https://github.com/AyuSne/zhangmuchuan>

## 1. 目标

一个面向技术读者的个人站点：首页介绍自己，博客放长文，关于页交代背景。阅读体验参考 vonng.com，但内容、配置和文章全部自己写，不复制它的仓库。

## 2. 时间线

| 时间 | 做了什么 |
|---|---|
| 2026-10-31 | 建仓库 `AyuSne/zhangmuchuan`，配置技能（issue tracker、triage 标签、`AGENTS.md`、`docs/agents/`） |
| 2026-10-31 | `/grill-with-docs` 设计访谈：确定中文单语、首页/博客/关于三区、不做笔记与文档区 |
| 2026-10-31 | 记录 ADR-0001：Hugo + OINK + GitHub Pages，并写入 `GLOSSARY.md` 术语表 |
| 2026-10-31 | `/implement`：从 `oink-starter` 起步，改造成中文单语博客，加自定义“最新文章”区块 |
| 2026-10-31 | `/code-review`：修复版本基线漂移、术语冲突、README 路径错误，关闭 categories |
| 2026-10-31 | 首次部署成功，站点上线 |

## 3. 技术选型

| 层 | 选择 | 理由 |
|---|---|---|
| 生成器 | Hugo Extended 0.169.0 | 构建快、纯静态、无运行时依赖 |
| 主题 | OINK 1.4.0（Apache-2.0） | 阅读排版、本地搜索、深浅色、组件齐全，不需要 Node.js |
| 内容 | Markdown 文件 | 版本可控、随时迁移、没有数据库 |
| 部署 | GitHub Actions → GitHub Pages | 零成本、`git push` 即发布 |
| 本地工具链 | `.tools/` 下的 Go 1.27.3 + Hugo（已 gitignore） | 不改系统环境，版本与 CI 一致 |

不选 Cloudflare Pages、Astro/Next 自建、复制 vonng.com 的原因记录在
[`docs/adr/0001-hugo-oink-static-site.md`](./adr/0001-hugo-oink-static-site.md)。

## 4. 仓库结构

```text
.
├── hugo.yaml                     # 全站唯一配置：标题、语言、菜单、Paper 风格、搜索、模块
├── go.mod / go.sum               # 固定 OINK v1.4.0
├── content/
│   ├── _index.md                 # 首页 front matter
│   ├── blog/
│   │   ├── _index.md             # 博客栏目：菜单项、cascade 类型
│   │   ├── hello-world.md        # 示例文章（占位）
│   │   ├── build-this-site.md    # 示例文章（占位）
│   │   └── what-i-write.md       # 示例文章（占位）
│   └── about.md                  # 关于页外壳（layout: landing）
├── data/
│   ├── home/zh.yaml              # 首页内容：hero、最新文章、入口卡片
│   └── landing/about/zh.yaml     # 关于页正文
├── layouts/partials/custom/
│   └── latest-posts.html         # 首页“最新文章”区块（自定义 partial）
├── .github/workflows/
│   └── github-pages.yaml         # 构建并发布到 Pages
├── static/favicon.svg            # 站点图标
├── assets/icons/logo.svg         # 站点 logo
├── docs/
│   ├── adr/0001-…md              # 架构决策记录
│   ├── agents/                   # 技能配置（issue tracker、triage、domain docs）
│   ├── PROJECT.md                # 本文
│   └── GUIDE.md                  # 使用手册
├── AGENTS.md                     # 构建基线 + 仓库卫生规则
├── GLOSSARY.md                   # 站点/首页/博客/文章/关于 的术语
├── README.md                     # 快速开始
└── THIRD_PARTY.md                # 第三方组件与许可证
```

## 5. 部署链路

```text
git push origin main
  └─ GitHub Actions (.github/workflows/github-pages.yaml)
       ├─ checkout
       ├─ setup-go 1.27.3
       ├─ configure-pages（读取 Pages 地址）
       ├─ install Hugo Extended 0.169.0
       ├─ go mod download github.com/pgsty/oink
       ├─ hugo --minify --environment production --baseURL <pages url>/
       └─ upload-pages-artifact → deploy-pages
            └─ https://ayusne.github.io/zhangmuchuan/
```

要点：

- 首次部署前，仓库 **Settings → Pages → Source** 必须选 **GitHub Actions**（已配置）。
- 构建约 30–60 秒，推送后到线上生效通常 1 分钟内。
- 工作流会用 Pages 的实际地址覆盖 `hugo.yaml` 的 `baseURL`，所以绑定自定义域名后无需改构建命令。

## 6. 内容现状

- 首页：hero 自我介绍 + 最新文章（按日期倒序）+ 入口卡片。
- 博客：3 篇示例文章，tags 组织（`建站`、`随笔`、`Hugo`）。
- 关于：landing 布局，文案在 `data/landing/about/zh.yaml`。
- 搜索：OINK 本地搜索，构建时生成索引，无外部依赖。
- 评论：关闭，Giscus 配置在 `hugo.yaml` 中以注释形式保留。
- 语言：中文单语；英文已声明但禁用，为以后双语留位。

## 7. 质量检查

- 本地构建：29 页，0 个路径警告，仅有 OINK 上游的 LibSass 弃用警告（已接受）。
- 线上内链检查：16 个链接全部 200。
- 代码审阅（Standards）：3 个硬问题已修——
  - Hugo 基线版本三处不一致 → 统一为 0.169.0；
  - “个人博客”与词表冲突 → 词表补充该术语；
  - README 关于页路径写错 → 改为 `content/about.md` + `data/landing/about/zh.yaml`。
- 代码审阅（Spec）：发现 Hugo 默认 `categories` 分类页仍然开着 → 已限制为只用 `tags`。
- 提交记录：`e70556b` 搭站 → `7bf0648` 修审阅问题 → `793d3c0` 关 categories。

## 8. 已知限制与下一步

| 项 | 状态 | 下一步 |
|---|---|---|
| 自定义域名 | 未绑定；`zhangmuchuan.com` 查询时仍未注册 | 购买并按 `docs/GUIDE.md` 绑定 |
| 示例文章 | 3 篇占位 | 替换成真实文章或删除 |
| 关于页 | 占位简介 | 改成自己的介绍 |
| 评论 | 关闭 | 需要时按 GUIDE 开启 Giscus |
| 英文 | 已声明、未启用 | 需要时添加 `.en.md` 翻译并启用 |
| logo / favicon | OINK Starter 的中性图标 | 有自己的标识后替换 |

## 9. 关键文件索引

- 写作与发布：`docs/GUIDE.md`
- 快速开始：`README.md`
- 架构决策：`docs/adr/0001-hugo-oink-static-site.md`
- 术语表：`GLOSSARY.md`
- 构建基线：`AGENTS.md`
- 第三方许可证：`THIRD_PARTY.md`

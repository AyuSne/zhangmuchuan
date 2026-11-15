# 张暮川的个人博客

基于 [Hugo](https://gohugo.io/) 与 [OINK](https://oink.pgsty.com/) 主题的静态博客，部署在 GitHub Pages。

## 文档

- [项目总结](docs/PROJECT.md)：做了什么、为什么这么选、现在到哪一步
- [使用手册](docs/GUIDE.md)：写文章、发布、改站点、绑域名、开评论、排错

## 本地开发

需要 **Hugo Extended ≥ 0.169.0** 与 **Go ≥ 1.27.3**（Hugo Modules 拉取主题用）。不需要 Node.js。

PowerShell：

```powershell
$env:GOWORK = "off"
$env:HUGO_MODULE_WORKSPACE = "off"
hugo server --bind 127.0.0.1 --port 1313
```

打开 <http://localhost:1313/>。首次运行会下载 OINK 模块（`v1.5.1`）。

生产构建：

```powershell
hugo --cleanDestinationDir --gc --minify --environment production --printPathWarnings
```

构建产物在 `public/`，已被 `.gitignore` 忽略，不要提交。

品牌回归测试会按与 CI 相同的命令出一次生产构建，再检查 header、侧栏与浏览器标签图标都是同一枚朱印（品牌标识的母版与约定见 `hugo.yaml` 的 `params.logo` 注释）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\brand-seal.ps1
```

窄屏沿用 OINK 的既有约定：宽度 <992px 时 header 只留朱印，≥768px 的有侧栏页面由侧栏显示朱印和站名，390 宽度下只剩朱印。这是主题行为，本次不改布局；渲染层的观感（不糊、不裁切、深色可辨认）是人工检查项。

## 写作

新文章放在 `content/blog/<slug>/index.md`（一篇一个文件夹，图片放同目录）：

```yaml
---
title: 标题
date: 2026-10-31
description: 一句话摘要
tags: [标签]
---
```

正文用 Markdown。站点结构：

- 首页：`data/home/zh.yaml` + `layouts/partials/custom/home/`（hero → 01 最近写作 → 02 系列 → 03 译文 → CTA）
- 博客：`content/blog/<slug>/index.md`
- 翻译：`content/translations/<slug>/index.md`（收录中文译文，注明原作者与原文；流程见使用手册第 3.5 节）
- 关于：`content/about.md`（页面外壳，`layout: landing`）+ `data/landing/about/zh.yaml`（正文）

## 部署

推送到 `main` 会触发 `.github/workflows/github-pages.yaml`：GitHub Actions 构建并发布到 GitHub Pages。

首次部署前，在仓库 **Settings → Pages → Source** 选择 **GitHub Actions**。

当前地址：<https://ayusne.github.io/zhangmuchuan/>。

绑定自定义域名 `zhangmuchuan.com` 后：把 `hugo.yaml` 的 `baseURL` 改成 `https://zhangmuchuan.com/`，并在 Settings → Pages 里填写域名。

## 许可

本站文章版权归张暮川所有。构建所用第三方组件与许可证见 [THIRD_PARTY.md](./THIRD_PARTY.md)。

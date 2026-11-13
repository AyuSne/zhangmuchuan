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

## 写作

新文章放在 `content/blog/<slug>.md`：

```yaml
---
title: 标题
date: 2026-10-31
description: 一句话摘要
tags: [标签]
---
```

正文用 Markdown。站点结构：

- 首页：`data/home/zh.yaml`（含 hero、最新文章、入口卡片）
- 博客：`content/blog/`
- 关于：`content/about.md`（页面外壳，`layout: landing`）+ `data/landing/about/zh.yaml`（正文）

## 部署

推送到 `main` 会触发 `.github/workflows/github-pages.yaml`：GitHub Actions 构建并发布到 GitHub Pages。

首次部署前，在仓库 **Settings → Pages → Source** 选择 **GitHub Actions**。

当前地址：<https://ayusne.github.io/zhangmuchuan/>。

绑定自定义域名 `zhangmuchuan.com` 后：把 `hugo.yaml` 的 `baseURL` 改成 `https://zhangmuchuan.com/`，并在 Settings → Pages 里填写域名。

## 许可

本站文章版权归张暮川所有。构建所用第三方组件与许可证见 [THIRD_PARTY.md](./THIRD_PARTY.md)。

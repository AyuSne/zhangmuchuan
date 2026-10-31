---
title: 这个站是怎么搭的
date: 2026-10-31
description: Hugo + OINK + GitHub Pages，一套零成本的静态博客方案。
tags: [建站, Hugo]
---

这个博客没有数据库、没有后台，也没有服务器。它是纯静态的：文章是仓库里的 Markdown，推送后由 GitHub Actions 构建成 HTML，发布到 GitHub Pages。

## 技术栈

- **Hugo Extended**：静态站点生成器，构建快、无运行时依赖。
- **OINK**：Hugo 主题，提供排版、本地搜索、深浅色和页面组件。
- **GitHub Actions + Pages**：推送即发布，免费。

## 为什么这么选

静态站省掉了服务器、数据库和运维；文章就是本地文件，随时能迁走。选 OINK 是因为它的阅读体验接近我想要的样子，而且不需要 Node.js 工具链。

## 写作流程

```
写 Markdown → git push → Actions 构建 → 线上更新
```

没有“发布”按钮，`git push` 就是发布。

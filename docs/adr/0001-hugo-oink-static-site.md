# 用 Hugo + OINK 搭建静态博客

张暮川的个人博客想要 vonng.com 那种阅读体验，但内容与配置全部自己写。我们决定用 Hugo Extended + OINK 主题（Apache-2.0，经 `oink-starter` 起步）构建纯静态站点，源码放 GitHub，用 GitHub Actions 构建并部署到 GitHub Pages，视觉用 OINK 的 Paper 风格。

## Considered Options

- **复制 Vonng/vonng.com**：上手最快，但它的内容受 CC BY 4.0 约束，仓库还带着用不上的 Docs / Book / 双语结构，配置与内容耦合，拆不干净。
- **Astro / Next.js 自建**：灵活，但要重新实现阅读排版、本地搜索、图库和主题系统，工作量远大于收益。
- **换别的 Hugo 主题**：OINK 的阅读体验、组件和本地搜索最接近目标，且仍在维护（1.4.0，2026-10）。
- **Cloudflare Pages**：额度更大、国内访问通常更稳，但要多维护一个平台账号；现阶段只用 GitHub 就够。

## Consequences

- 本地构建需要 Hugo Extended ≥ 0.168.0 与 Go ≥ 1.27.3（Hugo Modules 拉取主题）。
- 文章是仓库里的 Markdown，没有后台与数据库；发布靠 `git push`。
- GitHub Pages 有软限制（站点 1 GB、每月约 100 GB 流量、每小时约 10 次构建），个人博客够用。
- 绑定 `zhangmuchuan.com` 之前，站点地址是 `https://ayusne.github.io/zhangmuchuan/`，Hugo 的 `baseURL` 要带这个子路径；绑定域名后改回根路径。
- 评论先关闭，Giscus 开关保留；以后要开需要仓库公开并启用 Discussions。
- 以后要中英双语，OINK 原生支持，但配置要从单语言扩展成多语言。

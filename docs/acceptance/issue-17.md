# #17 四预设验收记录

2026-11-16，Windows 上的 Microsoft Edge（Chromium，Playwright 无头）访问本地 `hugo server`（生产环境，baseURL 带 `/zhangmuchuan/`）；构建基线为 OINK 1.5.1、Hugo Extended 0.169.0、Go 1.27.3。截图、检查脚本与原始结果保存在被忽略的 `.tools/issue17-shots/`、`.tools/issue17-verify.js`、`.tools/issue17-verify.json`，不进入 Git；这是本机验收记录，换电脑或清理 `.tools/` 后需重新生成。

交接时四预设的主要版式已经就位。本轮补了两处跨页问题并加了回归测试：索引、关于、404 不在 landing 作用域内，`--td-ink` / `--td-muted` 没有根映射，日期和摘要会退回正文色；搜索面板阴影写死暖色，没有跟随预设。两处都修在 token 层（`assets/scss/_styles_project.scss`、`assets/scss/_system_surfaces.scss`），由新增的 `tests/presets.ps1` 守住。

## 截图与响应式

- 生成 4 预设 × 2 明暗 × 4 宽度（390、768、1440、1920px，视口高 900px）× 8 类页面的 256 张首屏截图。页面为首页、文章、博客索引、翻译索引、关于、标签索引、系列及 404；文件名为 `<预设>-<明暗>-<宽度>-<页面>.png`。`contact-home.jpg`、`contact-pages-390.jpg`、`contact-pages-1440.jpg` 是同批缩略图。
- 自动测量 256 个视口：文档与 body 的 `scrollWidth` 都没有超过 `clientWidth`（差值 ≤ 1px）；每页都有 h1 和可见正文。首页四宽、其余页面 390/1440 的缩略图已人工核对；其余截图存档供复查。该检查不是对全部文章或页面全长的逐像素审阅。
- 计算样式：Paper / Slate / Ink 的 h1 是宋体栈（`Source Han Serif SC` … `Songti SC`、`SimSun`），Terminal 的 h1 是 `IBM Plex Mono` 等宽栈。正文按预设取字：Paper / Terminal 为 IBM Plex Sans，Slate / Ink 为 Inter，中文回退到平台字体。
- 四套预设 × 明暗下，首页 hero 与页脚字标都引用 `brand/seal.svg`；页脚「川」方块的 `::before` 背景固定为 `rgb(200, 64, 47)`，与母版 `#C8402F` 一致，不随预设或深色模式换色。
- 索引页的日期与摘要现在解析到各预设的三级文字色（例如 Paper 浅色 `#6b665d`、Slate `#586b80`、Ink `#636363`、Terminal `#606b63`），不再等于正文色；对画布色的对比度为 4.97–6.47:1。
- Paper / Ink / Terminal 的 landing 网格是 `transparent`，只有 Slate 保留冷色网格；没有把 Slate 的背景语言带进其它预设。

## 系统界面与搜索

- 页脚、搜索、命令面板和抽屉的样式编译到 `:root` 作用域；CSS 里没有 `[data-td-preset=paper] .td-shell-*` 的 Paper 专属选择器。
- 搜索弹窗在四预设 × 明暗下圆角 3px，面板底色取当前预设的 surface；阴影跟随 `--td-shell-shadow-lg`：Paper / Slate 有软阴影，Ink / Terminal 保持平面。
- 搜索选中项是预设强调色 10% 混合、正文色文字；按实际合成色计算，最低 10.49:1。焦点态是 2px 强调色内嵌线（Paper 为朱红）。
- 外观切换：点击 Ink 后 `data-td-preset` 变为 `ink`、写入 `localStorage['td-preset']`，刷新后保持；随后恢复默认 Paper。

## 行为与构建

- reduced-motion：四预设 × 明暗的首页和搜索弹窗，运行中的动画为 0；hero 行 `animation-name` 为 `none`、过渡为 `0s`、`scroll-behavior` 为 `auto`；首页统计直接显示 20 / 8 / 2。
- 禁用 JavaScript：八类页面的主内容与 h1 可见，首页统计为 20 / 8 / 2，`[data-td-reveal]` 没有隐藏项；截图以 `no-js-<页面>.png` 保存。
- 正常动效下，390px 滚动四预设 × 明暗的首页和代表文章，layout-shift 累计都是 0；页面脚本与控制台错误都是 0。
- 自有 `article.js`、`shell-drawer.js` 出包后分别为 991 和 550 字节，gzip 合计 851 字节（低于 10KB）；`node --check` 通过。文章正文与 front matter 零改动。
- 生产构建 109 页、0 条 path warning，只有已接受的上游 LibSass 弃用警告。`tests/presets.ps1` 56 项检查通过；`tests/` 六个脚本共 255 项检查全部通过。

## 限制

本次只使用 Edge 验证；Firefox、Safari 与不同设备上的实际字体回退尚未复测。主题升级后应重新执行矩阵，并检查搜索、命令面板、抽屉、键盘焦点和页脚。

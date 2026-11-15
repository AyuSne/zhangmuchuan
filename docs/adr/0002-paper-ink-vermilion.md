# 用「纸 · 墨 · 朱」替换 OINK 默认外观

站点采用纸色、墨色与朱印作为唯一视觉识别，首页、文章页、博客与翻译索引、关于、标签、系列和 404 共用同一套定制外壳；文章页恢复左侧文章目录、中栏正文和右侧页内目录，正文最大 954px，索引页改为行式列表。四套视觉预设保留，但只作为同一版式的 token 层：Paper、Slate、Ink 使用宋体标题，Terminal 保留等宽标题，朱印始终朱红。首屏入场、滚动渐显、数字滚动、hover 微交互、阅读进度、目录跟随、图片放大、回到顶部和 View Transitions 全量保留，并全部尊重 `prefers-reduced-motion`。

## Considered Options

- **保留 OINK 默认 Paper 外观**：最快，但和 OINK 示例站没有区别，首页仍是由两张等权卡片墙组成的模板。
- **只做 Paper 一套、去掉预设切换**：视觉身份最统一，但读者失去风格选择；现有 `preset_menu` 也白留。
- **四套完整设计**：每套单独排版与字体，成本约四倍，主题升级时维护不可持续。

## Consequences

- 定制样式、文章头部 partial 和首页/索引 partial 需要在 OINK 升级时复查；四套预设 × 明暗两种模式都要做视觉回归。
- 动效 JS 是渐进增强：脚本失败时内容完整可读，`prefers-reduced-motion` 下全部关闭；View Transitions 只在 Chromium 生效，其他浏览器直接跳转。
- 不改文章正文与 front matter；只动 `data/`、`layouts/`、`assets/`、`static/` 和 `hugo.yaml`。

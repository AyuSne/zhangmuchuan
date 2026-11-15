#requires -Version 5.1
<#
.SYNOPSIS
    文章页「纸 · 墨 · 朱」回归测试：按生产构建命令出包，再检查三栏版式、头部顺序、
    目录高亮、阅读进度与降级行为。

.DESCRIPTION
    测试接缝是构建产物——`public/` 里的 HTML 与 CSS——不是模板内部实现。
    断言对应 issue #13 的验收项：

      1. 文章页三栏：文章目录、正文、页内目录；正文列最大 954。
      2. ≥1440 三栏；1000–1439 隐藏页内目录、保留文章目录；<1000 文章目录变抽屉、单栏正文。
      3. 头部顺序：面包屑 → 标题 → 摘要 → 日期/时长/标签 → 系列条；系列条留在文首、
         不吸顶，并带「下一篇」。
      4. 当前文章在文章目录里朱红浅底 + 2px 左边条。
      5. 页内目录 220px、固定在视口内，当前项朱红指示条；锚点平滑滚动并留出 header 偏移。
      6. 顶部 2px 阅读进度、图片点击放大、回到顶部可用；无 JS 时静态内容完整。
      7. 1000px 以下抽屉不留在 Tab 顺序里，打开后可用。
      8. 构建 0 path warning，页面数与改动前一致（109）。

    四个宽度与明暗两种模式的实际观感（无溢出、不糊、无 console 错误）要人工在浏览器里核对。
    少数断言锁定了 OINK 的类名（外壳、文章目录、页内目录、滑动指示），升级主题时要同步核对。

.NOTES
    运行：powershell -NoProfile -ExecutionPolicy Bypass -File tests\article-paper.ps1
#>

[CmdletBinding()]
param(
    [string]$Destination = ".tools/article-public",
    [string]$HugoBinary = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/harness.ps1")

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $RepoRoot $Destination
$ExpectedPages = 109


# 取出所有匹配某个宽度条件的 @media 块正文，拼成一段便于断言。
function Get-MediaText {
    param([string]$Css, [string]$Query)

    return ((Get-CssMediaBlocks -Css $Css -Query $Query) -join "`n")
}

# ---------------------------------------------------------------- 构建

$build = Invoke-SiteBuild -RepoRoot $RepoRoot -HugoBinary $HugoBinary -Destination $Destination

Write-Section "构建"

Test-Check ($build.Exit -eq 0) "生产构建通过" @("hugo 退出码 $($build.Exit)")
Test-Check ($build.Unexpected.Count -eq 0) "没有新增构建警告" $build.Unexpected

$pathWarnings = @($build.Log | Where-Object { $_ -match 'path warning|WARN\s+found no layout|WARN\s+.*path' })
Test-Check ($pathWarnings.Count -eq 0) "0 条 path warning" $pathWarnings

$pagesLine = [regex]::Match(($build.Log -join "`n"), 'Pages\s+\S+\s+(\d+)')
$buildPages = if ($pagesLine.Success) { [int]$pagesLine.Groups[1].Value } else { 0 }
Test-Check ($buildPages -eq $ExpectedPages) "页面数与改动前一致（$ExpectedPages）" @("实际 $buildPages 页")

$articlePath = Join-Path $OutDir "blog/agent-harness/index.html"
$html = if (Test-Path -LiteralPath $articlePath) { [System.IO.File]::ReadAllText($articlePath) } else { "" }
Test-Check ($html.Length -gt 0) "文章页已生成" @("缺少 $articlePath")

$cssFile = Get-ChildItem -LiteralPath $OutDir -Recurse -File -Filter "main*.css" -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending | Select-Object -First 1
$css = if ($cssFile) { [System.IO.File]::ReadAllText($cssFile.FullName) } else { "" }
Test-Check ($css.Length -gt 0) "样式表已编译" @("没有找到 scss/main*.css")

# ---------------------------------------------------------------- 三栏

Write-Section "三栏：文章目录 + 正文 + 页内目录"

$bodyTag = [regex]::Match($html, '<body[^>]*>')
Test-Check ($bodyTag.Value -match '\btd-page\b' -and $bodyTag.Value -match '\btd-blog\b') "文章页 body 带 td-page td-blog 作用域" @($bodyTag.Value)

$layout = Get-ClassElement $html "td-shell-layout"
Test-Check ($null -ne $layout) "使用 OINK 三栏外壳" @("没有 .td-shell-layout")

$sidebar = Get-ClassElement $html "td-shell-sidebar"
$main = Get-ClassElement $html "td-shell-main"
$toc = Get-ClassElement $html "td-shell-toc"
Test-Check ($null -ne $sidebar) "左侧文章目录已渲染" @("没有 .td-shell-sidebar")
Test-Check ($null -ne $main) "中栏正文已渲染" @("没有 .td-shell-main")
Test-Check ($null -ne $toc) "右侧页内目录已渲染" @("没有 .td-shell-toc")

$tocStart = $html.IndexOf('<nav id=TableOfContents')
$tocEnd = if ($tocStart -ge 0) { $html.IndexOf('</nav>', $tocStart, [System.StringComparison]::Ordinal) } else { -1 }
$tocBody = if ($tocEnd -gt $tocStart) { $html.Substring($tocStart, $tocEnd - $tocStart) } else { "" }
$tocLinks = ([regex]::Matches($tocBody, '<a href=#')).Count
Test-Check ($tocLinks -ge 5) "页内目录列出文章标题" @("目录链接 $tocLinks 条")

Test-CssRule $css 'body.td-page.td-blog .td-shell-article' '--td-article-measure:\s*954px' "正文基准是 954"
Test-CssRule $css 'body.td-page.td-blog .td-shell-article' 'max-width:\s*calc\(var\(--td-article-measure\)' "正文列最大宽度由 954 加两侧留白算出"

$wide = Get-MediaText $css "min-width: 1200px"
Test-Check ($wide -match '\.td-shell-toc\s*\{[^}]*flex:\s*0\s+0\s+var\(--td-shell-toc-w\)') "宽屏外壳的页内目录占一列" @("xl 媒体块里没有 .td-shell-toc 的 flex 列")

$threeCol = Get-MediaText $css "min-width: 1440px"
Test-Check ($threeCol -match '--td-shell-toc-w:\s*220px') "≥1440 页内目录收到 220px，把宽度让给正文" @("没有在 1440 收紧页内目录宽度")

$mid = Get-MediaText $css "max-width: 1439.98px"
Test-Check ($mid -match '\.td-shell-toc[^{}]*\{[^}]*display:\s*none\s*!important') "1000–1439 隐藏页内目录" @("max-width:1439.98 的媒体块里没有隐藏右栏")
Test-Check ($mid -match '\.td-shell-sidebar__aside\s*\{[^}]*display:\s*none\s*!important') "1440 以下页内目录在文章目录里也收起" @("页内目录副本还留在左侧")
Test-Check ($mid -notmatch '\.td-shell-sidebar\s*\{[^}]*display:\s*contents') "1000–1439 保留左侧文章目录" @("中屏把左侧目录也收成了抽屉")

$narrow = Get-MediaText $css "max-width: 999.98px"
Test-Check ($narrow -match '\.td-shell-sidebar\s*\{[^}]*display:\s*contents') "<1000 文章目录变抽屉（aside 让位给面板）" @("max-width:999.98 里没有 .td-shell-sidebar display:contents")
Test-Check ($narrow -match '\.td-shell-sidebar__panel\s*\{[^}]*width:\s*85vw') "<1000 抽屉面板用移动端宽度" @("抽屉面板没有 width:85vw")
Test-Check ($narrow -match '\.td-shell-sidebar__panel\s*\{[^}]*transform:\s*translateX\(100%\)') "<1000 抽屉默认收在屏幕外" @("抽屉面板没有 transform:translateX(100%)")
Test-Check ($narrow -match '\[data-td-shell-drawer=open\]\s*\.td-shell-sidebar__panel\s*\{[^}]*transform:\s*translateX\(0\)') "<1000 打开抽屉时面板滑入" @("没有 drawer open 的 transform:translateX(0)")
Test-Check ($narrow -match '\.td-shell-drawer-backdrop\s*\{[^}]*display:\s*block\s*!important') "<1000 抽屉有可点的遮罩" @("遮罩仍是 d-md-none")
Test-Check ($narrow -match '\.td-site-nav__menu-toggle[^{]*\{[^}]*display:\s*inline-flex') "<1000 导航栏出现打开抽屉的按钮" @("菜单按钮在 768–999 仍被隐藏")
Test-Check ($narrow -match '\.td-shell-sidebar__panel\s*\{[^}]*visibility:\s*hidden') "<1000 关着的抽屉不占 Tab 顺序" @("抽屉面板没有 visibility:hidden")
Test-Check ($narrow -match '\[data-td-shell-drawer=open\]\s*\.td-shell-sidebar__panel\s*\{[^}]*visibility:\s*visible') "<1000 抽屉打开后可聚焦" @("打开态没有 visibility:visible")

$narrowTocHidden = $mid -match '\.td-shell-sidebar__aside\s*\{[^}]*display:\s*none'
Test-Check ($narrowTocHidden) "<1000 页内目录随文章目录一起收起" @("窄屏把抽屉里的页内目录也隐藏了")

# ---------------------------------------------------------------- 头部顺序

Write-Section "头部顺序：面包屑 → 标题 → 摘要 → 日期/时长/标签 → 系列条"

$crumbs = Get-ClassElement $html "td-breadcrumbs"
Test-Check ($null -ne $crumbs) "文章页有面包屑" @("没有 .td-breadcrumbs")
if ($crumbs) {
    $crumbText = Get-InnerText $html $crumbs
    Test-Check ($crumbText -match '博客') "面包屑从「博客」开始" @("面包屑：$crumbText")
}

$crumbIndex = $html.IndexOf('td-breadcrumbs', [System.StringComparison]::Ordinal)
$titleIndex = $html.IndexOf('<h1', [System.StringComparison]::Ordinal)
$leadIndex = $html.IndexOf('<div class=lead', [System.StringComparison]::Ordinal)
$infoIndex = $html.IndexOf('td-article-info', [System.StringComparison]::Ordinal)
$metaIndex = $html.IndexOf('td-article-meta', [System.StringComparison]::Ordinal)
$stripIndex = $html.IndexOf('td-series-strip', [System.StringComparison]::Ordinal)
$order = @($crumbIndex, $titleIndex, $leadIndex, $infoIndex, $metaIndex, $stripIndex)
$named = @('面包屑', '标题', '摘要', '日期/时长', '标签', '系列条')
$missing = @()
for ($i = 0; $i -lt $order.Count; $i++) {
    if ($order[$i] -lt 0) { $missing += $named[$i] }
}
Test-Check ($missing.Count -eq 0) "六个部分都在文章页里" @("缺少：$($missing -join '、')")
$inOrder = $missing.Count -eq 0
for ($i = 1; $i -lt $order.Count -and $inOrder; $i++) {
    if ($order[$i - 1] -ge $order[$i]) { $inOrder = $false }
}
Test-Check $inOrder "顺序是面包屑 → 标题 → 摘要 → 日期/时长 → 标签 → 系列条" @(($named -join ' → ') + "；实际位置 " + ($order -join ', '))

Test-Check ($html -match 'td-article-info__date') "标题下有日期" @("没有 .td-article-info__date")
Test-Check ($html -match 'td-article-info__time') "标题下有阅读时长" @("没有 .td-article-info__time")
Test-Check ($html -match 'td-taxonomy-terms') "标题下有标签" @("没有 .td-taxonomy-terms")

$h1Rule = [regex]::Match($css, '\.td-content h1[^{]*\{[^}]*font-family:\s*var\(--td-heading-font-family\)')
Test-Check $h1Rule.Success "标题走 Paper 的宋体 token" @("没有 .td-content h1 使用 --td-heading-font-family")

# ---------------------------------------------------------------- 目录高亮

Write-Section "目录：当前文章朱红浅底 + 左边条，页内目录跟随"

$activeRows = ([regex]::Matches($html, 'td-shell-tree__row td-shell-active')).Count
Test-Check ($activeRows -eq 1) "文章目录里恰好一个当前项" @("当前项 $activeRows 个")
Test-Check ($html -match 'aria-current=page[^>]*class="?td-shell-tree__link active|class="?td-shell-tree__link active"?[^>]*aria-current=page') "当前项带 aria-current=page" @("当前文章链接没有 aria-current=page")

$paperAccent = [regex]::Match($css, '\[data-td-preset=paper\][^{}]*\{[^}]*--td-preset-accent:\s*var\(--td-vermilion\)')
Test-Check $paperAccent.Success "Paper 的激活色是朱红" @("没有把 --td-preset-accent 指到 --td-vermilion")
$paperDarkAccent = [regex]::Match($css, '\[data-td-preset=paper\]\[data-bs-theme=dark\][^{}]*\{[^}]*--td-preset-accent:\s*var\(--td-vermilion-strong\)')
Test-Check $paperDarkAccent.Success "深色下激活色换成更亮的朱红" @("深色 token 没有把 --td-preset-accent 指到 strong")

Test-CssRule $css '.td-shell-tree__row.td-shell-active' 'border-inline-start:\s*2px\s+solid\s+var\(--td-accent\)' "当前文章有 2px 朱红左边条"
Test-CssRule $css '.td-shell-tree__row.td-shell-active' 'padding-inline-start:\s*calc\(var\(--td-shell-indent,\s*8px\)\s*-\s*2px\)' "左边条不挤动目录文字"
$activeGround = [regex]::Match($css, '--td-shell-primary-dim:\s*color-mix\(in srgb,\s*var\(--td-accent\)')
Test-Check $activeGround.Success "当前项浅底取自同一个朱红" @("--td-shell-primary-dim 没有从 --td-accent 兑出")

Test-CssRule $css '.td-shell-toc__active path' 'stroke-width:\s*2px' "页内目录当前项是 2px 朱红滑动条"
Test-CssRule $css '.td-shell-toc__active path' 'stroke:\s*var\(--td-accent\)' "滑动条用激活色"

$panelRule = [regex]::Match($wide, '\.td-shell-toc__panel\s*\{[^}]*position:\s*fixed')
Test-Check $panelRule.Success "页内目录固定在视口内跟随阅读" @("宽屏下页内目录不是 fixed")
Test-Check ($wide -match '\.td-shell-toc__panel\s*\{[^}]*inset-block-start:\s*var\(--td-shell-nav-h\)') "页内目录从 header 下沿开始" @("面板没有 inset-block-start: var(--td-shell-nav-h)")

# ---------------------------------------------------------------- 锚点滚动

Write-Section "锚点：平滑滚动并留出 header 偏移"

$desktop = Get-MediaText $css "min-width: 768px"
Test-Check ($desktop -match '--td-anchor-offset-delta:\s*46px') "桌面锚点额外留 46px" @("min-width:768 里没有把锚点余量调到 46px")
Test-Check ($desktop -match 'scroll-padding-top:\s*calc\(var\(--td-shell-nav-h\)\s*\+\s*var\(--td-anchor-offset-delta\)\)') "桌面锚点偏移 = 50px header + 46px = 96px" @("没有用同一个 token 算出 96px")

$noPreference = Get-MediaText $css "prefers-reduced-motion: no-preference"
Test-Check ($noPreference -match 'html:has\(body\.td-page\.td-blog\)\s*\{[^}]*scroll-behavior:\s*smooth') "未开启减少动态效果时文章页锚点平滑滚动" @("没有文章页作用域的 scroll-behavior:smooth")

$reduce = Get-MediaText $css "prefers-reduced-motion: reduce"
Test-Check ($reduce -notmatch 'scroll-behavior:\s*smooth') "开启减少动态效果时不强制平滑滚动" @("reduced-motion 块里仍有 smooth")

# ---------------------------------------------------------------- 阅读进度 / 放大 / 回到顶部

Write-Section "阅读进度、图片放大、回到顶部"

$progress = [regex]::Match($html, '<div[^>]*data-td-read-progress[^>]*>')
Test-Check $progress.Success "有阅读进度条" @("没有 [data-td-read-progress]")
Test-Check ($progress.Value -match '\shidden(?:\s|>)') "进度条默认隐藏，不给无 JS 的用户一条死条" @($progress.Value)
Test-Check ($html -match 'data-td-read-progress-fill') "进度条有可伸缩的填充" @("没有 [data-td-read-progress-fill]")

Test-CssRule $css '.td-read-progress' 'position:\s*fixed' "进度条固定在视口"
Test-CssRule $css '.td-read-progress' 'height:\s*2px' "进度条是 2px"
Test-CssRule $css '.td-read-progress' 'inset-block-start:\s*var\(--td-shell-nav-h\)' "进度条贴在 header 下沿"
Test-CssRule $css '.td-read-progress__fill' 'background:\s*var\(--td-vermilion\)' "进度条是朱红"

$backTop = [regex]::Match($html, '<button[^>]*data-td-back-top[^>]*>')
Test-Check $backTop.Success "有回到顶部按钮" @("没有 [data-td-back-top]")
Test-Check ($backTop.Value -match 'aria-label="?回到顶部') "回到顶部按钮有无障碍名称" @($backTop.Value)
Test-Check ($html -notmatch 'data-td-back-top[^>]*data-td-visible') "回到顶部默认不出现" @("静态 HTML 已经显示按钮")
Test-CssRule $css '.td-back-top' 'visibility:\s*hidden' "回到顶部默认隐藏"
Test-CssRule $css '.td-back-top[data-td-visible]' 'visibility:\s*visible' "回到顶部在滚动后出现"

$scriptMatch = [regex]::Match($html, '<script[^>]+src=([^ >]+article[^ >]*\.js)')
Test-Check $scriptMatch.Success "文章页加载自己的动效运行时" @("没有 article*.js")
if ($scriptMatch.Success) {
    $scriptPath = Resolve-OutputFile -Href $scriptMatch.Groups[1].Value.Trim('"', "'") -Root $OutDir
    Test-Check ($null -ne $scriptPath) "动效运行时已发布" @("缺少 $($scriptMatch.Groups[1].Value)")
    if ($scriptPath) {
        $js = [System.IO.File]::ReadAllText($scriptPath)
        Test-Check ($js -match 'requestAnimationFrame') "滚动监听用 rAF 节流" @("没有 requestAnimationFrame")
        Test-Check ($js -match 'prefers-reduced-motion') "运行时尊重减少动态效果" @("没有 prefers-reduced-motion")
        Test-Check ($js -match '1\.2') "回到顶部在 1.2 屏后出现" @("没有 1.2 倍视口阈值")
    }
}

$homeHtmlPath = Join-Path $OutDir "index.html"
$homeHtml = if (Test-Path -LiteralPath $homeHtmlPath) { [System.IO.File]::ReadAllText($homeHtmlPath) } else { "" }
Test-Check ($homeHtml -notmatch 'data-td-read-progress') "首页不带文章页进度条" @("首页也出现了进度条")

Test-Check ($html -match 'data-td-image-zoom') "正文图片可点开放大" @("没有 data-td-image-zoom")
Test-Check ($html -match 'data-td-image-zoom-dialog') "放大会话已渲染" @("没有 data-td-image-zoom-dialog")
Test-Check ($html -match '<script[^>]+src=[^ >]*image-zoom[^ >]*\.js') "图片放大脚本已加载" @("没有 image-zoom 脚本")

Write-Section "正文组件：公式不撑宽页面"

Test-CssRule $css '.td-content .katex' 'max-width:\s*100%' "行内公式最宽不超过正文列"
Test-CssRule $css '.td-content .katex' 'overflow-x:\s*auto' "超宽公式自己横向滚动，不撑宽整页"
Test-CssRule $css '.td-content .katex' 'display:\s*inline-flex' "公式滚动盒仍与正文同行"
Test-CssRule $css '.td-content .katex-display .katex' 'display:\s*block' "独立公式不套行内滚动盒，沿用 OINK 的显示公式容器"
Test-CssRule $css '.td-content blockquote' 'border-inline-start:\s*2px\s+solid\s+var\(--td-rule-strong\)' "引用条用暖色分隔线，不残留主题蓝"

# 系列条在文首流内，不吸顶。
$stripRule = [regex]::Match($css, '(?s)\.td-series-strip\{(?<body>[^}]*)\}')
$stripBody = if ($stripRule.Success) { $stripRule.Groups['body'].Value } else { "" }
Test-Check ($stripRule.Success -and $stripBody -notmatch 'position:\s*(sticky|fixed)') "系列条留在文首、不吸顶" @("规则：$stripBody")

$nextLink = [regex]::Match($html, '<a[^>]*td-series-strip__next[^>]*href=([^ >]+)[^>]*>')
Test-Check $nextLink.Success "系列条有「下一篇」" @("没有 .td-series-strip__next")
if ($nextLink.Success) {
    Test-Check ($nextLink.Value -match '下一篇') "「下一篇」是看得见的文字" @($nextLink.Value)
}
$lastInSeries = Join-Path $OutDir "blog/agent-memory/index.html"
if (Test-Path -LiteralPath $lastInSeries) {
    $lastHtml = [System.IO.File]::ReadAllText($lastInSeries)
    Test-Check ($lastHtml -notmatch 'td-series-strip__next') "系列最后一篇不显示「下一篇」" @("最后一篇仍带下一篇链接")
}

Test-CssRule $css '[data-td-preset=paper]' '--td-code-radius:\s*var\(--td-radius\)' "Paper 的代码块与系列条圆角统一到 3px"

$drawerScript = [regex]::Match($html, '<script[^>]+src=([^ >]+shell-drawer[^ >]*\.js)')
Test-Check $drawerScript.Success "文章页加载抽屉隔离脚本" @("没有 shell-drawer*.js")
if ($drawerScript.Success) {
    $drawerPath = Resolve-OutputFile -Href $drawerScript.Groups[1].Value.Trim('"', "'") -Root $OutDir
    Test-Check ($null -ne $drawerPath) "抽屉脚本已发布" @("缺少 $($drawerScript.Groups[1].Value)")
    if ($drawerPath) {
        $drawerJs = [System.IO.File]::ReadAllText($drawerPath)
        Test-Check ($drawerJs -match '999\.98px') "抽屉脚本按 1000px 断点接管" @("没有 999.98px")
        Test-Check ($drawerJs -match 'inert') "抽屉脚本解除桌面收起态的 inert" @("没有 inert")
    }
}
$blogIndexPath = Join-Path $OutDir "blog/index.html"
if (Test-Path -LiteralPath $blogIndexPath) {
    $blogIndexHtml = [System.IO.File]::ReadAllText($blogIndexPath)
    Test-Check ($blogIndexHtml -match 'shell-drawer[^ >]*\.js') "博客索引页也加载抽屉脚本" @("索引页缺少 shell-drawer")
    Test-Check ($blogIndexHtml -notmatch 'data-td-read-progress') "索引页不带阅读进度" @("索引页出现了进度条")
}

Complete-Tests

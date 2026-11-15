#requires -Version 5.1
<#
.SYNOPSIS
    首页「纸 · 墨 · 朱」回归测试：按生产构建命令出包，再检查首页版式、内容结构与降级行为。

.DESCRIPTION
    测试接缝是构建产物——`public/` 里的 HTML 与 CSS——不是模板内部实现。
    断言对应 issue #12 的验收项：

      1. 首页容器 1302；标题走系统宋体；「纸 · 墨 · 朱」token 在纸色与墨色两套下成立。
      2. hero 三个动作里「读博客」是唯一主按钮；「关于」仍在导航，不在 hero。
      3. hero 右侧有朱印与竖排短句；标题逐行、摘要/按钮/统计错开入场。
      4. 01 最近写作一主四辅：主推有标题、摘要、阅读全文；辅行有日期、标题、时长。
      5. 02 系列：标题「系列」，每卡有篇数、年份、说明与「进入系列」。
      6. 03 最近译文三行，含标题与原作者/日期；结尾有 RSS / GitHub / 关于我。
      7. 滚动渐显与数字滚动接 OINK 运行时，静态 HTML 不隐藏内容；reduced-motion 全静止。
      8. 构建 0 path warning，页面数与改动前一致（109）。

    四个宽度与明暗两种模式的实际观感（无溢出、不糊）要人工在浏览器里截图核对。

.NOTES
    运行：powershell -NoProfile -ExecutionPolicy Bypass -File tests\home-paper.ps1
#>

[CmdletBinding()]
param(
    [string]$Destination = ".tools/test-public",
    [string]$HugoBinary = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/harness.ps1")

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $RepoRoot $Destination
$HomePath = Join-Path $OutDir "index.html"
$ExpectedPages = 109

# ---------------------------------------------------------------- 构建

$build = Invoke-SiteBuild -RepoRoot $RepoRoot -HugoBinary $HugoBinary -Destination $Destination

Write-Section "构建"

Test-Check ($build.Exit -eq 0) "生产构建通过" @("hugo 退出码 $($build.Exit)")
Test-Check ($build.Unexpected.Count -eq 0) "没有新增构建警告" $build.Unexpected

$pathWarnings = @($build.Log | Where-Object { $_ -match 'path warning|WARN\s+found no layout|WARN\s+.*path' })
Test-Check ($pathWarnings.Count -eq 0) "0 条 path warning" $pathWarnings

$html = if (Test-Path -LiteralPath $HomePath) { [System.IO.File]::ReadAllText($HomePath) } else { "" }
Test-Check ($html.Length -gt 0) "首页已生成" @("缺少 $HomePath")

$pagesLine = [regex]::Match(($build.Log -join "`n"), 'Pages\s+\S+\s+(\d+)')
$buildPages = if ($pagesLine.Success) { [int]$pagesLine.Groups[1].Value } else { 0 }
Test-Check ($buildPages -eq $ExpectedPages) "页面数与改动前一致（$ExpectedPages）" @("实际 $buildPages 页；内容增删时同步更新 `$ExpectedPages")

# ---------------------------------------------------------------- 基座

Write-Section "基座：容器、字体、朱墨 token"

$cssFile = Get-ChildItem -LiteralPath $OutDir -Recurse -File -Filter "main*.css" -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending | Select-Object -First 1
$css = if ($cssFile) { [System.IO.File]::ReadAllText($cssFile.FullName) } else { "" }
Test-Check ($css.Length -gt 0) "样式表已编译" @("没有找到 scss/main*.css")

$hasContainerToken = $css -match '--td-home-max:\s*1302px'
$usesContainerToken = $css -match 'max-width:\s*var\(--td-home-max\)'
Test-Check $hasContainerToken "首页容器 token 是 1302" @("CSS 里没有 --td-home-max:1302px")
Test-Check $usesContainerToken "首页容器用上了该 token" @("CSS 里没有 max-width:var(--td-home-max)")

$hasSerif = $css -match '--td-serif' -and ($css -match 'Songti SC' -or $css -match 'SimSun')
$headingsUseSerif = $css -match '--td-heading-font-family:\s*var\(--td-serif\)'
Test-Check $hasSerif "定义了系统宋体栈" @("CSS 里没有 --td-serif 或宋体族名")
Test-Check $headingsUseSerif "Paper 的标题走宋体" @("CSS 里没有 --td-heading-font-family:var(--td-serif)")

$hasVermilion = ($css -match '--td-vermilion:\s*#') -and ($css -match '--td-vermilion-strong:\s*#')
Test-Check $hasVermilion "定义了朱印正色与深色可辨色" @("CSS 里缺 --td-vermilion / --td-vermilion-strong")

$darkBlocks = @([regex]::Matches($css, '\[data-bs-theme=dark\]\{([^}]*)\}') | ForEach-Object { $_.Groups[1].Value })
$darkText = ($darkBlocks -join "`n") -match '--td-vermilion-text:\s*var\(--td-vermilion-strong\)'
Test-Check $darkText "深色下朱色文字改用更亮的 strong" @("深色 token 块没有把 --td-vermilion-text 指到 strong")

$homeBody = $html -match '<body[^>]*class="?[^">]*\btd-home\b'
Test-Check $homeBody "首页 body 带 td-home 作用域" @("body 上没有 td-home 类")

# ---------------------------------------------------------------- hero

Write-Section "hero：三个动作、朱印、竖排短句、入场"

Test-Check ($html -match 'class="?td-home-hero\b') "hero 已渲染" @("没有 .td-home-hero")

$actionCount = Get-ClassCount $html "td-home-hero__action"
$primaryCount = Get-ClassCount $html "td-home-hero__action--primary"
Test-Check ($actionCount -eq 3) "hero 有三个动作" @("实际 $actionCount 个")
Test-Check ($primaryCount -eq 1) "「读博客」是唯一主按钮" @("主按钮 $primaryCount 个")

$heroRegion = ""
$heroIndex = $html.IndexOf("td-home-hero__actions", [System.StringComparison]::Ordinal)
if ($heroIndex -ge 0) {
    $heroEnd = $html.IndexOf("</section>", $heroIndex, [System.StringComparison]::Ordinal)
    if ($heroEnd -lt 0) { $heroEnd = $html.Length }
    $heroRegion = $html.Substring($heroIndex, $heroEnd - $heroIndex)
}
Test-Check ($heroRegion -match 'href=/zhangmuchuan/blog/') "主按钮指向博客" @("hero 里没有 /blog/ 链接")
Test-Check ($heroRegion -match 'href=/zhangmuchuan/translations/') "次按钮指向翻译" @("hero 里没有 /translations/ 链接")
Test-Check ($heroRegion -match 'href=/zhangmuchuan/index\.xml') "次按钮指向 RSS" @("hero 里没有 index.xml 链接")
Test-Check ($heroRegion -notmatch '/about/') "hero 里没有「关于」（它留在导航）" @("hero 动作里出现了 /about/")

$navZone = Get-ClassElement $html "td-nav-menu-zone"
$navHtml = if ($navZone) { $html.Substring($navZone.Start, [Math]::Min(4000, $html.Length - $navZone.Start)) } else { "" }
Test-Check ($navHtml -match '/about/') "「关于」仍在主导航" @("导航里没有 /about/")

$seal = Get-ClassElement $html "td-home-hero__seal"
Test-Check ($null -ne $seal) "hero 右侧有朱印" @("没有 .td-home-hero__seal")
if ($seal) {
    $sealSrc = $seal.Attrs["src"]
    Test-Check ($sealSrc -match 'brand/seal\.svg$') "hero 朱印用的是全站母版" @("src=$sealSrc")
}

$vertical = Get-ClassElement $html "td-home-hero__vertical"
$verticalText = Get-InnerText $html $vertical
Test-Check ($verticalText.Length -gt 0) "hero 右侧有竖排短句" @("短句为空")
Test-Check ($css -match 'writing-mode:\s*vertical-rl') "竖排短句真的竖排" @("CSS 里没有 writing-mode:vertical-rl")

$lineCount = Get-ClassCount $html "td-home-hero__line"
Test-Check ($lineCount -ge 2) "标题分成多行入场" @("标题行 $lineCount 行")
Test-Check ($html -match '--td-line-index:\s*0') "标题行带入场序号" @("HTML 里没有 --td-line-index")
Test-Check ($css -match 'animation-delay[^;]*var\(--td-line-index') "标题行按序号错开" @("CSS 里没有按 --td-line-index 的 animation-delay")
Test-Check ($css -match '@keyframes\s+td-home-line') "定义了标题行入场关键帧" @("CSS 里没有 @keyframes td-home-line")
Test-Check ($html -match '--td-rise-index:\s*2') "摘要/按钮/统计依次错开" @("HTML 里没有 --td-rise-index")
Test-Check ($css -match 'animation-delay[^;]*var\(--td-rise-index') "错开用同一个序号变量" @("CSS 里没有按 --td-rise-index 的 animation-delay")

$statCount = Get-ClassCount $html "td-home-hero__stat"
Test-Check ($statCount -eq 3) "hero 有三项统计" @("实际 $statCount 项")
$counters = @([regex]::Matches($heroRegion, 'data-td-count=\\?"?(\d+)'))
Test-Check ($counters.Count -eq 3) "统计数字接了数字滚动运行时" @("data-td-count 数量 $($counters.Count)")

$reducedBlocks = @(Get-CssMediaBlocks -Css $css -Query "prefers-reduced-motion: reduce")
$heroReduced = @($reducedBlocks | Where-Object { $_ -match '\.td-home-hero' })
Test-Check ($heroReduced.Count -gt 0) "reduced-motion 覆盖 hero" @("没有覆盖 .td-home-hero 的 reduced-motion 块")
Test-Check (($heroReduced -join "`n") -match 'animation:\s*none') "reduced-motion 下 hero 不动画" @("覆盖 hero 的块里没有 animation:none")

# ---------------------------------------------------------------- 01 最近写作

Write-Section "01 最近写作：一主四辅"

$recent = Get-ClassElement $html "td-home-recent"
Test-Check ($null -ne $recent) "01 区块已渲染" @("没有 .td-home-recent")
Test-Check ($html -match '最近写作') "01 标题是「最近写作」" @("页面上没有「最近写作」")

$featuredMatch = [regex]::Match($html, '(?s)<article[^>]*td-home-recent__featured[^>]*>.*?</article>')
Test-Check ($featuredMatch.Success) "主推是一篇文章" @("没有 .td-home-recent__featured")

$itemMatches = @([regex]::Matches($html, '(?s)<li[^>]*td-home-recent__item[^>]*>.*?</li>'))
Test-Check ($itemMatches.Count -eq 4) "辅列表是四条" @("实际 $($itemMatches.Count) 条")

if ($featuredMatch.Success) {
    $featured = $featuredMatch.Value
    Test-Check ($featured -match 'td-home-recent__featured-title') "主推有大标题" @("没有主推标题")
    Test-Check ($featured -match 'td-home-recent__summary') "主推有摘要" @("没有主推摘要")
    Test-Check ($featured -match '阅读全文') "主推有「阅读全文」" @("没有阅读全文")
}

$itemDates = @()
foreach ($m in $itemMatches) {
    $block = $m.Value
    $date = [regex]::Match($block, 'datetime="?(\d{4}-\d{2}-\d{2})')
    if ($date.Success) { $itemDates += $date.Groups[1].Value }
    if ($block -notmatch 'td-home-recent__item-title') { Test-Check $false "辅行有标题" @($block.Substring(0, [Math]::Min(120, $block.Length))) }
    if ($block -notmatch '\d+\s*分钟') { Test-Check $false "辅行有阅读时长" @($block.Substring(0, [Math]::Min(120, $block.Length))) }
}
Test-Check ($itemDates.Count -eq 4) "辅行都带日期" @("带日期的辅行 $($itemDates.Count) 条")

if ($featuredMatch.Success -and $itemDates.Count -eq 4) {
    $featuredDate = [regex]::Match($featuredMatch.Value, 'datetime="?(\d{4}-\d{2}-\d{2})')
    $featuredValue = if ($featuredDate.Success) { $featuredDate.Groups[1].Value } else { "" }
    $allDates = @($featuredValue) + $itemDates
    $descending = $true
    for ($i = 1; $i -lt $allDates.Count; $i++) {
        if ([string]::CompareOrdinal($allDates[$i - 1], $allDates[$i]) -lt 0) { $descending = $false }
    }
    Test-Check ($featuredValue -ne "") "主推带日期" @("主推没有 time 元素")
    Test-Check $descending "主推是最近发布的一篇，辅列表按时间倒序" @(($allDates -join ", "))
}

$recentMore = [regex]::Match($html, 'href="?/zhangmuchuan/blog/')
Test-Check $recentMore.Success "01 有「全部文章」入口" @("没有 /blog/ 链接")

# ---------------------------------------------------------------- 02 系列

Write-Section "02 系列"

$series = Get-ClassElement $html "td-home-series"
Test-Check ($null -ne $series) "02 区块已渲染" @("没有 .td-home-series")
Test-Check ($html -match '>系列<') "02 标题是「系列」" @("页面上没有「系列」标题")

$seriesCards = @([regex]::Matches($html, '(?s)<a[^>]*td-home-series__card[^>]*>.*?</a>'))
Test-Check ($seriesCards.Count -ge 2) "系列卡按数据渲染" @("实际 $($seriesCards.Count) 张")

foreach ($m in $seriesCards) {
    $card = $m.Value
    $hasCount = $card -match '\d+\s*篇'
    $hasYear = $card -match '20\d{2}'
    $hasBlurb = $card -match 'td-home-series__blurb'
    $hasEnter = $card -match '进入系列'
    $label = [regex]::Match($card, 'td-home-series__name[^>]*>([^<]+)').Groups[1].Value
    Test-Check ($hasCount -and $hasYear -and $hasBlurb -and $hasEnter) "系列卡「$label」有篇数、年份、说明与进入系列" @(
        "篇数=$hasCount 年份=$hasYear 说明=$hasBlurb 进入系列=$hasEnter")
}

# ---------------------------------------------------------------- 03 最近译文

Write-Section "03 最近译文"

$translations = Get-ClassElement $html "td-home-translations"
Test-Check ($null -ne $translations) "03 区块已渲染" @("没有 .td-home-translations")
Test-Check ($html -match '最近译文') "03 标题是「最近译文」" @("页面上没有「最近译文」")

$translationRows = @([regex]::Matches($html, '(?s)<li[^>]*td-home-translations__row[^>]*>.*?</li>'))
Test-Check ($translationRows.Count -eq 3) "最近译文是三行" @("实际 $($translationRows.Count) 行")

foreach ($m in $translationRows) {
    $row = $m.Value
    $by = [regex]::Match($row, 'td-home-translations__by[^>]*>([^<]*)<')
    $hasTitle = $row -match 'td-home-translations__title'
    $hasAuthor = $by.Success -and $by.Groups[1].Value.Trim().Length -gt 0
    $hasDate = $row -match 'datetime="?\d{4}-\d{2}-\d{2}'
    Test-Check ($hasTitle -and $hasAuthor -and $hasDate) "译文行有标题、原作者与日期" @(
        "标题=$hasTitle 原作者=$hasAuthor 日期=$hasDate")
}

# ---------------------------------------------------------------- CTA

Write-Section "结尾 CTA"

$cta = Get-ClassElement $html "td-home-cta"
Test-Check ($null -ne $cta) "CTA 已渲染" @("没有 .td-home-cta")
$ctaLinks = @([regex]::Matches($html, '<a\b[^>]*>') | Where-Object {
    $attrs = Get-Attrs $_.Value
    $attrs.ContainsKey("class") -and (($attrs["class"] -split '\s+') -contains "td-home-cta__link")
})
Test-Check ($ctaLinks.Count -eq 3) "CTA 有三个入口" @("实际 $($ctaLinks.Count) 个")
$ctaHrefs = @($ctaLinks | ForEach-Object { (Get-Attrs $_.Value)["href"] })
Test-Check (($ctaHrefs -join " ") -match '/zhangmuchuan/index\.xml') "CTA 有 RSS" @("没有 RSS 链接")
Test-Check (($ctaHrefs -join " ") -match 'https://github\.com/AyuSne/zhangmuchuan') "CTA 有 GitHub" @("没有 GitHub 链接")
Test-Check (($ctaHrefs -join " ") -match '/zhangmuchuan/about/') "CTA 有「关于我」" @("没有 /about/ 链接")

# ---------------------------------------------------------------- 动效与降级

Write-Section "动效与降级"

Test-Check ($html -match 'data-td-landing') "首页接了 OINK 的 landing 运行时" @("没有 data-td-landing")
$revealCount = ([regex]::Matches($html, 'data-td-reveal\b')).Count
Test-Check ($revealCount -ge 8) "区块与列表行接了滚动渐显（$revealCount 处）" @("data-td-reveal 只有 $revealCount 处")
Test-Check ($html -notmatch 'data-td-reveal-pending') "静态 HTML 不隐藏内容" @("HTML 里出现了 JS 才该加的 data-td-reveal-pending")
$rowDelays = [regex]::Matches($css, 'transition-delay[^;]*var\(--td-stagger')
$staggeredRows = ([regex]::Matches($html, 'style="?--td-stagger')).Count
Test-Check ($rowDelays.Count -ge 1 -and $staggeredRows -ge 8) "列表行按序号错开渐显（$staggeredRows 处）" @(
    "CSS 命中 $($rowDelays.Count) 条；HTML 里带序号的元素 $staggeredRows 个")

# hover 微交互：下划线画出、箭头右移、列表行右移、日期变朱色、卡片与按钮轻抬。


Test-CssRule $css '.td-home-recent__item-link:hover' 'translateX\(3px\)' "hover 列表行右移 3px"
Test-CssRule $css '.td-home-recent__featured-link:hover' 'background-size:\s*100% 1px' "hover 主推标题画下划线"
Test-CssRule $css 'a:hover .td-home-arrow' 'translateX\(4px\)' "hover 箭头右移 4px"
Test-CssRule $css '.td-home-series__card:hover' 'translateY\(-3px\)' "hover 系列卡上浮 3px"
Test-CssRule $css '.td-home-hero__action:hover' 'translateY\(-1px\)' "hover 按钮轻抬 1px"
Test-CssRule $css '.td-home-recent__item-link:hover .td-home-recent__item-date' 'var\(--td-vermilion-text\)' "hover 日期变朱色"

# 分区用 aria-labelledby 指向自己的标题；指的 id 必须真的存在。
$labelled = @([regex]::Matches($html, 'aria-labelledby="?([A-Za-z0-9_-]+)') | ForEach-Object { $_.Groups[1].Value })
$labelled = @($labelled | Where-Object { $_ -match '^td-home-' } | Select-Object -Unique)
$danglingIds = @($labelled | Where-Object { $html -notmatch ('id="?' + [regex]::Escape($_) + '[\s>"]') })
Test-Check ($labelled.Count -ge 4 -and $danglingIds.Count -eq 0) "分区的 aria-labelledby 都指向存在的标题" @(
    "分区 $($labelled.Count) 个；悬空 id：$($danglingIds -join ', ')")

Complete-Tests

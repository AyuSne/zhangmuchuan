#requires -Version 5.1
<#
.SYNOPSIS
    四预设外壳回归测试：按生产构建命令出包，再检查四套预设的调色板、标题字体、朱印与系统界面。

.DESCRIPTION
    测试接缝是构建产物——出包后的 HTML 与 CSS——不是模板内部实现。
    断言对应 issue #17 的验收项：

      1. 四套预设都出现在外观菜单，并各自声明明暗画布色。
      2. Paper / Slate / Ink 标题走宋体，Terminal 标题与 UI 走等宽；角色都由 token 决定。
      3. 朱印母版与 favicon 逐字节一致，颜色固定为朱红，四套预设共用同一枚。
      4. 页脚、搜索、抽屉的系统界面样式在根作用域生效，不再只在 Paper 下生效。
      5. --td-ink / --td-muted 在根上映射，索引、关于、404 的弱化文字不会退回正文色。
      6. reduced-motion 下主题组件的动画与过渡也被统一关闭。
      7. 自有动效 JS 的 gzip 体积低于 10KB；有 node 时顺带做语法检查。

    四个宽度与明暗两种模式的实际观感要人工在浏览器里截图核对。

.NOTES
    运行：powershell -NoProfile -ExecutionPolicy Bypass -File tests\presets.ps1
#>

[CmdletBinding()]
param(
    [string]$Destination = ".tools/presets-public",
    [string]$HugoBinary = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/harness.ps1")

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $RepoRoot $Destination
$ExpectedPages = 109

function Get-GzipLength {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $memory = New-Object System.IO.MemoryStream
    $gzip = New-Object System.IO.Compression.GZipStream -ArgumentList @(
        $memory,
        [System.IO.Compression.CompressionMode]::Compress,
        $true
    )
    try {
        $gzip.Write($bytes, 0, $bytes.Length)
    }
    finally {
        $gzip.Dispose()
    }
    $length = $memory.Length
    $memory.Dispose()
    return $length
}

# ---------------------------------------------------------------- 构建

$build = Invoke-SiteBuild -RepoRoot $RepoRoot -HugoBinary $HugoBinary -Destination $Destination

Write-Section "构建"
Test-Check ($build.Exit -eq 0) "生产构建通过" @("hugo 退出码 $($build.Exit)")
Test-Check ($build.Unexpected.Count -eq 0) "没有新增构建警告" $build.Unexpected

$pathWarnings = @($build.Log | Where-Object { $_ -match 'path warning|WARN\s+found no layout' })
Test-Check ($pathWarnings.Count -eq 0) "0 条 path warning" $pathWarnings

$pagesLine = [regex]::Match(($build.Log -join "`n"), 'Pages\s+\S+\s+(\d+)')
$buildPages = if ($pagesLine.Success) { [int]$pagesLine.Groups[1].Value } else { 0 }
Test-Check ($buildPages -eq $ExpectedPages) "页面数与基线一致（$ExpectedPages）" @("实际 $buildPages 页")

$html = [System.IO.File]::ReadAllText((Join-Path $OutDir "index.html"))
Test-Check ($html.Length -gt 0) "首页已生成" @("缺少 index.html")

$cssFile = Get-ChildItem -LiteralPath $OutDir -Recurse -File -Filter "main*.css" -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending | Select-Object -First 1
$css = if ($cssFile) { [System.IO.File]::ReadAllText($cssFile.FullName) } else { "" }
Test-Check ($css.Length -gt 0) "样式表已编译" @("没有找到 main*.css")

# ---------------------------------------------------------------- 菜单与调色板

Write-Section "四套预设：菜单、默认值、画布"

$presets = @("paper", "slate", "ink", "terminal")
foreach ($preset in $presets) {
    Test-Check ($html -match "data-td-preset-value=[""']?$preset\b") "外观菜单提供 $preset" @("HTML 里没有 data-td-preset-value=$preset")
    Test-Check ($html -match "html\[data-td-preset=$preset\]\{background:#[0-9a-f]{3,8}" -or ($preset -eq "paper" -and $html -match "html\{background:#[0-9a-f]{3,8}")) "HTML 头部为 $preset 预置画布底色" @("head 里没有 $preset 的画布底色")
    Test-Check ($css -match "\[data-td-preset=$preset\][^{}]*\{") "$preset 的样式块已编译" @("CSS 里没有 [data-td-preset=$preset]")
    Test-Check ($html -match "data-td-preset-value=$preset\b[^>]*data-td-canvas-light=#[0-9a-f]{3,8}[^>]*data-td-canvas-dark=#") "$preset 同时声明明暗画布" @("菜单项没有成对的 data-td-canvas-light / data-td-canvas-dark")
}

Test-Check ($html -match '<html[^>]*\bdata-td-preset=paper\b') "默认预设仍是纸（paper）" @("html 上没有 data-td-preset=paper")
Test-Check ($html -match '\bdata-td-site-preset=paper\b') "站点默认预设单独标注" @("html 上没有 data-td-site-preset")

# ---------------------------------------------------------------- 标题字体

Write-Section "标题字体：宋体与等宽"

Test-Check ($css -match '--td-serif:') "定义了系统宋体栈" @("CSS 里没有 --td-serif")
Test-Check ($css -match '(?s)--td-serif:[^;}]*Songti SC') "宋体栈包含 Songti SC" @("宋体栈没有 Songti SC")
Test-Check ($css -match '(?s)--td-serif:[^;}]*SimSun') "宋体栈包含 SimSun" @("宋体栈没有 SimSun")

foreach ($preset in @("paper", "slate", "ink")) {
    $serifRule = [regex]::Match($css, "\[data-td-preset=$preset\][^{}]*\{[^}]*--td-heading-font-family:\s*var\(--td-serif\)")
    Test-Check $serifRule.Success "$preset 标题走宋体" @("没有 $preset 的 --td-heading-font-family:var(--td-serif)")
}

$terminalMono = [regex]::Match($css, '\[data-td-preset=terminal\][^{}]*\{[^}]*--td-heading-font-family:\s*var\(--td-ui-font-family\)')
Test-Check $terminalMono.Success "Terminal 标题保持等宽角色" @("Terminal 没有 --td-heading-font-family:var(--td-ui-font-family)")
$terminalCode = [regex]::Match($css, '\[data-td-preset=terminal\][^{}]*\{[^}]*--td-ui-font-family:\s*var\(--td-code-font-family\)')
Test-Check $terminalCode.Success "Terminal 的界面字体走等宽栈" @("Terminal 没有 --td-ui-font-family:var(--td-code-font-family)")

# ---------------------------------------------------------------- 朱印

Write-Section "朱印：母版、favicon、四预设同色"

$sealFile = Join-Path $RepoRoot "static/brand/seal.svg"
$faviconFile = Join-Path $RepoRoot "static/favicon.svg"
Test-Check (Test-Path -LiteralPath $sealFile) "朱印母版存在" @("缺少 static/brand/seal.svg")
if (Test-Path -LiteralPath $sealFile) {
    Test-Check ((Get-Sha256 $sealFile) -eq (Get-Sha256 $faviconFile)) "favicon 与朱印母版逐字节一致" @("两个 SVG 的 SHA-256 不同")
    $seal = [System.IO.File]::ReadAllText($sealFile)
    $sealHex = [regex]::Match($seal, 'fill="#(?<hex>[0-9A-Fa-f]{6})"').Groups["hex"].Value
    Test-Check ($sealHex -eq "C8402F") "朱印母版固定为朱红 #C8402F" @("实际 $sealHex")
}

Test-Check ($css -match '(?i)--td-vermilion:\s*#c8402f') "token 层的朱印色与母版一致" @("--td-vermilion 不是 #c8402f")
Test-Check ($css -notmatch '(?i)filter:\s*(sepia|hue-rotate)') "没有用滤镜改朱印颜色" @("样式表里出现了 sepia / hue-rotate")

foreach ($route in @("index.html", "about/index.html", "404.html")) {
    $pagePath = Join-Path $OutDir $route
    $pageHtml = if (Test-Path -LiteralPath $pagePath) { [System.IO.File]::ReadAllText($pagePath) } else { "" }
    Test-Check ($pageHtml -match 'brand/seal\.svg') "$route 使用朱印母版" @("没有 brand/seal.svg")
}

# ---------------------------------------------------------------- 系统界面

Write-Section "系统界面：四预设共用"

Test-Check ($css -match ':root \.td-shell-footline') "页脚样式在根作用域生效" @("没有 :root .td-shell-footline")
Test-Check ($css -match ':root \.td-shell-search') "搜索样式在根作用域生效" @("没有 :root .td-shell-search")
Test-Check ($css -match ':root \.td-shell-sidebar__panel') "抽屉样式在根作用域生效" @("没有 :root .td-shell-sidebar__panel")

$paperScoped = [regex]::Matches($css, '\[data-td-preset=paper\][^{}]*td-shell-(footline|search|sidebar)')
Test-Check ($paperScoped.Count -eq 0) "系统界面不再只在 Paper 下生效" @("仍有 $($paperScoped.Count) 条 Paper 专属选择器")

Test-CssRule $css ':root .td-shell-search__panel' 'box-shadow:\s*var\(--td-shell-shadow-lg\)' "搜索面板沿用当前预设的阴影 token"

# ---------------------------------------------------------------- 跨页 token

Write-Section "跨页 token：弱化文字不再退回正文色"

foreach ($token in @(
        @{ Name = '--td-ink'; Expected = 'var\(--bs-body-color\)' },
        @{ Name = '--td-muted'; Expected = 'var\(--bs-tertiary-color\)' },
        @{ Name = '--td-rule'; Expected = 'var\(--bs-border-color\)' },
        @{ Name = '--td-surface'; Expected = 'var\(--bs-secondary-bg\)' }
    )) {
    Test-CssRule $css ':root' ($token.Name + ':\s*' + $token.Expected) "$($token.Name) 在根上映射"
}

# ---------------------------------------------------------------- 降级与 JS

Write-Section "降级：reduced-motion 统一关闭动画"

$reducedBlocks = @(Get-CssMediaBlocks $css 'prefers-reduced-motion: reduce')
Test-Check ($reducedBlocks.Count -gt 0) "有 reduced-motion 媒体查询" @("CSS 里没有 prefers-reduced-motion: reduce")

$universal = @($reducedBlocks | Where-Object { $_ -match '(?s)\*\s*,\s*\*::before\s*,\s*\*::after\s*\{[^}]*animation:\s*none\s*!important' })
Test-Check ($universal.Count -ge 1) "统一关闭主题组件的动画" @("reduced-motion 块里没有 * 级 animation:none!important")

$instantScroll = @($reducedBlocks | Where-Object { $_ -match 'scroll-behavior:\s*auto\s*!important' })
Test-Check ($instantScroll.Count -ge 1) "reduced-motion 下恢复瞬时滚动" @("reduced-motion 块里没有 scroll-behavior:auto!important")

Write-Section "动效 JS：体积与语法"

$jsDir = Join-Path $OutDir "js"
$motionJs = @(@("article", "shell-drawer") | ForEach-Object {
        Get-ChildItem -LiteralPath $jsDir -File -Filter "$_.min.*.js" -ErrorAction SilentlyContinue | Select-Object -First 1
    } | Where-Object { $_ })
Test-Check ($motionJs.Count -eq 2) "两个动效脚本都已出包" @("缺少 article.min.*.js 或 shell-drawer.min.*.js")

if ($motionJs.Count -eq 2) {
    $total = 0
    foreach ($file in $motionJs) { $total += Get-GzipLength $file.FullName }
    Test-Check ($total -lt 10240) ("动效 JS 合计 {0} 字节 gzip，低于 10KB" -f $total)
}

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    foreach ($file in $motionJs) {
        $syntax = @(& $node.Source --check $file.FullName 2>&1 | ForEach-Object { "$_" })
        Test-Check ($LASTEXITCODE -eq 0) "$($file.Name) 语法检查通过" $syntax
    }
}
else {
    Write-Host "  skip 未找到 node，跳过动效 JS 语法检查" -ForegroundColor DarkGray
}

Complete-Tests

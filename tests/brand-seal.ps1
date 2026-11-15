#requires -Version 5.1
<#
.SYNOPSIS
    朱印品牌回归测试：按 CI 的同一条生产构建命令出包，再检查 header、侧栏与浏览器标签图标是同一枚朱印。

.DESCRIPTION
    测试接缝（seam）是构建产物——`public/` 里的 HTML 与静态资源——不是模板内部实现。
    断言只关心读者能看到的结果：

      1. 生产构建（含 --minify）通过，且没有新增构建警告。
      2. header 品牌位的 logo 指向的文件，与 static/brand/seal.svg 逐字节相同。
      3. 侧栏品牌位（有侧栏的页面）指向同一枚朱印。
      4. 浏览器标签图标（<link rel="icon">）指向同一枚朱印。
      5. header 品牌文字仍是「张暮川」。
      6. 整个产物里不再有 OINK Starter 的蓝色图标色 #245f94。
      7. 朱印的印面与字口在纸色、墨色两种底色上都够对比（深色模式可辨认）。

    第 7 条读的是构建产物里的 theme-color meta，所以预设配色变了它会跟着变，不写死色值。

    脚本只检查产物里的标记与素材，不做渲染断言：四个宽度与深色模式下的实际观感
    （不糊、不裁切、可辨认）要人工在浏览器里看。OINK 在 <992px 收起品牌文字、只留朱印，
    这是主题的窄屏约定，不是本脚本能判定的内容。

.NOTES
    运行：powershell -NoProfile -ExecutionPolicy Bypass -File tests\brand-seal.ps1
#>

[CmdletBinding()]
param(
    # hugo --destination 的相对路径，相对仓库根目录。
    [string]$Destination = ".tools/test-public",

    # 指定 hugo 可执行文件；留空则依次找 PATH、.tools/hugo/。
    [string]$HugoBinary = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/harness.ps1")

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $RepoRoot $Destination
$SealPath = Join-Path $RepoRoot "static/brand/seal.svg"
$BrandText = "张暮川"
$StarterBlue = "245f94"

# 判断一个站内图片地址是不是朱印母版：通过返回空串，否则返回原因。
function Test-SealRef {
    param([string]$Href)

    if (-not $Href) { return "没有图片地址" }
    $file = Resolve-OutputFile -Href $Href -Root $OutDir
    if (-not $file) { return "文件找不到（$Href）" }
    # 母版本身缺失时有单独的断言，这里不重复报同一件事。
    if ($script:SealHash -and (Get-Sha256 $file) -ne $script:SealHash) {
        return "不是朱印（$Href）"
    }
    return ""
}

# ---------------------------------------------------------------- 构建

$build = Invoke-SiteBuild -RepoRoot $RepoRoot -HugoBinary $HugoBinary -Destination $Destination

Write-Section "构建与接线"

Test-Check ($build.Exit -eq 0) "生产构建通过" @("hugo 退出码 $($build.Exit)")
Test-Check ($build.Unexpected.Count -eq 0) "没有新增构建警告" $build.Unexpected

$ok = Test-Path -LiteralPath $SealPath
Test-Check $ok "朱印母版存在：static/brand/seal.svg" @("缺少 $SealPath")
$script:SealHash = if ($ok) { Get-Sha256 $SealPath } else { "" }

# ---------------------------------------------------------------- 页面

$pages = @()
if (Test-Path -LiteralPath $OutDir) {
    # 路径分隔符按两种都排除，脚本在 Windows 与 Linux 上判定一致。
    $pages = @(Get-ChildItem -LiteralPath $OutDir -Recurse -File -Filter *.html |
        Where-Object { $_.FullName -notmatch '[\\/]_print[\\/]' })
}
Test-Check ($pages.Count -gt 0) "产物里有页面" @("$OutDir 里没有 HTML")

$required = @(
    "index.html"
    "blog/index.html"
    "translations/index.html"
    "tags/index.html"
    "about/index.html"
    "404.html"
)
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $OutDir $_)) })
Test-Check ($missing.Count -eq 0) "首页、博客、翻译、标签、关于与 404 都在" $missing

$postPages = @()
$blogDir = Join-Path $OutDir "blog"
if (Test-Path -LiteralPath $blogDir) {
    $postPages = @(Get-ChildItem -LiteralPath $blogDir -Directory |
        Where-Object { $_.Name -ne "page" -and (Test-Path -LiteralPath (Join-Path $_.FullName "index.html")) })
}
Test-Check ($postPages.Count -gt 0) "文章页仍然渲染" @("blog/ 下没有文章页")

$logoBad = [System.Collections.Generic.List[string]]::new()
$favBad = [System.Collections.Generic.List[string]]::new()
$sideBad = [System.Collections.Generic.List[string]]::new()
$textBad = [System.Collections.Generic.List[string]]::new()
$sideTextBad = [System.Collections.Generic.List[string]]::new()
$scannedPages = 0
$pagesWithNavbar = 0
$pagesWithSidebar = 0
$faviconHrefs = [System.Collections.Generic.HashSet[string]]::new()
$logoHrefs = [System.Collections.Generic.HashSet[string]]::new()

foreach ($page in $pages) {
    $rel = $page.FullName.Substring($OutDir.Length).TrimStart('\', '/') -replace '\\', '/'
    $html = [System.IO.File]::ReadAllText($page.FullName)

    # 分页别名页只有 meta refresh 跳转，不是读者看到的页面。
    if ($html -match 'http-equiv\s*=\s*"?refresh') { continue }
    $scannedPages++

    # header 品牌位：logo 图 + 站名
    $brand = Get-ClassElement $html "td-nav-brand"
    if ($brand) {
        $pagesWithNavbar++
        $anchorEnd = $html.IndexOf("</a>", $brand.End, [System.StringComparison]::OrdinalIgnoreCase)
        if ($anchorEnd -lt 0) { $anchorEnd = $brand.End }

        $logo = Get-ClassElement $html "td-nav-logo" $brand.End $anchorEnd
        if (-not $logo) {
            $logoBad.Add("$rel：header 品牌位没有 logo 图")
        }
        else {
            $src = $logo.Attrs["src"]
            [void]$logoHrefs.Add($src)
            $why = Test-SealRef $src
            if ($why) { $logoBad.Add("$rel：header logo $why") }
        }

        $title = Get-ClassElement $html "td-nav-title" $brand.End $anchorEnd
        $titleText = Get-InnerText $html $title
        if ($titleText -ne $BrandText) { $textBad.Add("$rel：品牌文字是「$titleText」") }
    }

    # 侧栏品牌位
    $side = Get-ClassElement $html "td-shell-sidebar__brand"
    if ($side) {
        $pagesWithSidebar++
        $sideEnd = $html.IndexOf("</a>", $side.End, [System.StringComparison]::OrdinalIgnoreCase)
        if ($sideEnd -lt 0) { $sideEnd = $side.End }
        $markTag = $null
        if ($sideEnd -gt $side.End) {
            $markMatch = [regex]::Match($html.Substring($side.End, $sideEnd - $side.End), '<img\b[^>]*>')
            if ($markMatch.Success) { $markTag = $markMatch.Value }
        }
        if (-not $markTag) {
            $sideBad.Add("$rel：侧栏品牌位没有朱印")
        }
        else {
            $why = Test-SealRef (Get-Attrs $markTag)["src"]
            if ($why) { $sideBad.Add("$rel：侧栏图标 $why") }
        }

        $wordmark = Get-ClassElement $html "td-shell-wordmark" $side.End $sideEnd
        $wordmarkText = Get-InnerText $html $wordmark
        if ($wordmarkText -ne $BrandText) { $sideTextBad.Add("$rel：侧栏品牌文字是「$wordmarkText」") }
    }

    # 浏览器标签图标：每个 link 只解析一次属性
    $svgIcons = @()
    foreach ($m in [regex]::Matches($html, '<link\b[^>]*>')) {
        $attrs = Get-Attrs $m.Value
        if (-not $attrs.ContainsKey("rel")) { continue }
        if (($attrs["rel"] -split '\s+') -notcontains "icon") { continue }
        if (((($attrs["href"] -split '\?')[0]) -match '\.svg$')) { $svgIcons += $attrs }
    }
    if ($svgIcons.Count -eq 0) {
        $favBad.Add("$rel：没有 SVG 标签图标")
    }
    foreach ($icon in $svgIcons) {
        $href = $icon["href"]
        [void]$faviconHrefs.Add($href)
        $why = Test-SealRef $href
        if ($why) { $favBad.Add("$rel：标签图标 $why") }
    }
}

Test-Check ($scannedPages -gt 0) "有可检查的页面" @("除跳转别名页外没有页面")
Test-Check ($pagesWithNavbar -eq $scannedPages) "每个页面都渲染 header 品牌位" @(
    "$($scannedPages - $pagesWithNavbar) 个页面没有 td-nav-brand，不能只看单个页面")
Test-Check ($logoBad.Count -eq 0) "header 品牌位显示朱印" $logoBad.ToArray()
Test-Check ($textBad.Count -eq 0) "header 品牌位显示「$BrandText」" $textBad.ToArray()
Test-Check ($pagesWithSidebar -gt 0) "有页面渲染侧栏品牌位" @("没有找到 td-shell-sidebar__brand")
Test-Check ($sideBad.Count -eq 0) "侧栏品牌位显示同一枚朱印" $sideBad.ToArray()
Test-Check ($sideTextBad.Count -eq 0) "侧栏品牌位显示「$BrandText」" $sideTextBad.ToArray()
Test-Check ($favBad.Count -eq 0) "浏览器标签图标是朱印" $favBad.ToArray()
Test-Check ($logoHrefs.Count -le 1) "全站 header 用同一个 logo 地址" @($logoHrefs)
Test-Check ($faviconHrefs.Count -le 1) "全站标签图标用同一个地址" @($faviconHrefs)

# ---------------------------------------------------------------- 素材

Write-Section "品牌素材"

$starterHits = @()
if (Test-Path -LiteralPath $OutDir) {
    # 只看图形素材：主题 SCSS 里 #245f94 是 slate 预设的链接色，和品牌图标无关。
    $imageFiles = @(Get-ChildItem -LiteralPath $OutDir -Recurse -File |
        Where-Object { $_.Extension -in @(".svg", ".ico") })
    foreach ($file in $imageFiles) {
        if (Select-String -LiteralPath $file.FullName -Pattern $StarterBlue -SimpleMatch -Quiet -ErrorAction SilentlyContinue) {
            $starterHits += $file.FullName.Substring($OutDir.Length).TrimStart('\', '/')
        }
    }
}
Test-Check ($starterHits.Count -eq 0) "产物里没有 OINK Starter 蓝色图标色 #$StarterBlue" $starterHits

if ($script:SealHash) {
    $seal = [System.IO.File]::ReadAllText($SealPath)
    $groundTag = [regex]::Match($seal, '<rect\b[^>]*>').Value
    $glyphTag = [regex]::Match($seal, '<path\b[^>]*>').Value
    $ground = ConvertTo-HexColor ((Get-Attrs $groundTag)["fill"])
    $glyph = ConvertTo-HexColor ((Get-Attrs $glyphTag)["fill"])

    Test-Check ($null -ne $ground) "朱印有印面底色" @("static/brand/seal.svg 的 <rect> 没有 #rrggbb 填充")
    Test-Check ($null -ne $glyph) "朱印有字口颜色" @("static/brand/seal.svg 的 <path> 没有 #rrggbb 填充")

    if ($ground -and $glyph) {
        $homeHtml = [System.IO.File]::ReadAllText((Join-Path $OutDir "index.html"))
        $themeMeta = [regex]::Match($homeHtml, '<meta\b[^>]*name\s*=\s*"?theme-color"?[^>]*>').Value
        $metaAttrs = Get-Attrs $themeMeta
        $canvasLight = ConvertTo-HexColor ($metaAttrs["data-td-canvas-light"])
        $canvasDark = ConvertTo-HexColor ($metaAttrs["data-td-canvas-dark"])

        Test-Check ($null -ne $canvasLight -and $null -ne $canvasDark) "产物声明了纸色与墨色底色" @("theme-color meta 缺少 data-td-canvas-light/dark")

        if ($canvasLight) {
            $ratio = Get-ContrastRatio $ground $canvasLight
            Test-Check ($ratio -ge 3.0) "朱印在浅色底上可辨认（对比度 ${ratio}:1）" @("需要 ≥3:1")
        }
        if ($canvasDark) {
            $ratio = Get-ContrastRatio $ground $canvasDark
            Test-Check ($ratio -ge 3.0) "朱印在深色底上可辨认（对比度 ${ratio}:1）" @("需要 ≥3:1")
        }
        $glyphRatio = Get-ContrastRatio $glyph $ground
        Test-Check ($glyphRatio -ge 4.5) "「川」在印面上可辨认（对比度 ${glyphRatio}:1）" @("需要 ≥4.5:1")
    }
}

Complete-Tests

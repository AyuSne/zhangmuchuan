#requires -Version 5.1
<#
.SYNOPSIS
    本站测试脚本的共用工具箱：构建站点、断言、HTML 解析、颜色对比。

.DESCRIPTION
    测试接缝统一是构建产物——`hugo` 出包后的 HTML 与静态资源，不是模板内部实现。
    各测试脚本 dot-source 本文件，只保留自己的断言。

.NOTES
    运行脚本用：powershell -NoProfile -ExecutionPolicy Bypass -File tests\<名字>.ps1
    本文件以 UTF-8 with BOM 保存（Windows PowerShell 5.1 需要）。
#>

Set-StrictMode -Version Latest

$script:Passed = 0
$script:Failures = [System.Collections.Generic.List[string]]::new()

# 唯一允许的构建警告：上游 LibSass 弃用提示，逐字匹配。
$script:AcceptedWarning = '^WARN\s+deprecated: css\.Sass: libsass was deprecated in Hugo v0\.153\.0'

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host $Title
}

function Test-Check {
    param([bool]$Condition, [string]$Name, [string[]]$Detail = @())

    if ($Condition) {
        $script:Passed++
        Write-Host "  ok   $Name"
        return
    }
    $script:Failures.Add($Name)
    Write-Host "  FAIL $Name" -ForegroundColor Red
    foreach ($line in ($Detail | Select-Object -First 6)) {
        Write-Host "       $line" -ForegroundColor DarkGray
    }
    if ($Detail.Count -gt 6) {
        Write-Host "       ……还有 $($Detail.Count - 6) 条" -ForegroundColor DarkGray
    }
}

function Complete-Tests {
    Write-Host ""
    if ($script:Failures.Count -eq 0) {
        Write-Host "PASS  $($script:Passed) 项检查全部通过" -ForegroundColor Green
        exit 0
    }
    Write-Host "FAIL  $($script:Failures.Count) 项失败，$($script:Passed) 项通过" -ForegroundColor Red
    foreach ($name in $script:Failures) { Write-Host "  - $name" -ForegroundColor Red }
    exit 1
}

function Resolve-HugoBinary {
    param([string]$Explicit, [string]$RepoRoot)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { throw "找不到指定的 hugo：$Explicit" }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    $cmd = Get-Command hugo -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in @(".tools/hugo/hugo.exe", ".tools/hugo/hugo")) {
        $probe = Join-Path $RepoRoot $candidate
        if (Test-Path -LiteralPath $probe) { return $probe }
    }
    throw "找不到 hugo。把 Hugo Extended 放进 PATH，或用 -HugoBinary 指定。"
}

# 按与 README / CI 相同的生产构建命令出包，返回退出码、日志与未预期的警告。
function Invoke-SiteBuild {
    param(
        [string]$RepoRoot,
        [string]$HugoBinary,
        [string]$Destination = ".tools/test-public"
    )

    $hugo = Resolve-HugoBinary -Explicit $HugoBinary -RepoRoot $RepoRoot
    $env:GOWORK = "off"
    $env:HUGO_MODULE_WORKSPACE = "off"
    $goBin = Join-Path $RepoRoot ".tools/go/bin"
    if (Test-Path -LiteralPath $goBin) { $env:PATH = "$goBin;$env:PATH" }

    Write-Host "构建：$(Split-Path -Leaf $hugo) --destination $Destination --minify --environment production"
    $log = @()
    $exit = 0
    Push-Location $RepoRoot
    $previousEap = $ErrorActionPreference
    try {
        $buildArgs = @(
            "--destination", $Destination
            "--cleanDestinationDir", "--gc", "--minify"
            "--environment", "production"
            "--printPathWarnings"
        )
        # hugo 把警告写到 stderr；5.1 会把它变成错误记录，这里只要文本，不要中断。
        $ErrorActionPreference = "Continue"
        $log = @(& $hugo @buildArgs 2>&1 | ForEach-Object { "$_" })
        $exit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousEap
        Pop-Location
    }
    $log | ForEach-Object { Write-Host $_ }

    $warnings = @($log | Where-Object { $_ -match '^\s*(WARN|ERROR)\b' })
    $unexpected = @($warnings | Where-Object { $_ -notmatch $script:AcceptedWarning })
    return @{ Exit = $exit; Log = $log; Warnings = $warnings; Unexpected = $unexpected }
}

function Get-Attrs {
    param([string]$Tag)

    $attrs = @{}
    $pattern = '([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s>"'']+))'
    foreach ($m in [regex]::Matches($Tag, $pattern)) {
        $value = if ($m.Groups[2].Success) { $m.Groups[2].Value }
                 elseif ($m.Groups[3].Success) { $m.Groups[3].Value }
                 else { $m.Groups[4].Value }
        $attrs[$m.Groups[1].Value.ToLowerInvariant()] = $value
    }
    return $attrs
}

# 找到第一个 class 含 $Class 的元素（不受属性顺序、引号形式影响）。
function Get-ClassElement {
    param([string]$Html, [string]$Class, [int]$From = 0, [int]$To = -1)

    $length = if ($To -ge 0) { $To - $From } else { $Html.Length - $From }
    if ($length -le 0) { return $null }
    $region = $Html.Substring($From, $length)
    $pattern = '<(?<name>[A-Za-z][A-Za-z0-9]*)\b(?<attrs>[^>]*)>'
    foreach ($m in [regex]::Matches($region, $pattern)) {
        $attrs = Get-Attrs $m.Groups['attrs'].Value
        if (-not $attrs.ContainsKey("class")) { continue }
        if (($attrs["class"] -split '\s+' | Where-Object { $_ }) -contains $Class) {
            return @{
                Name  = $m.Groups['name'].Value.ToLowerInvariant()
                Tag   = $m.Value
                Start = $From + $m.Index
                End   = $From + $m.Index + $m.Length
                Attrs = $attrs
            }
        }
    }
    return $null
}

# 取元素开标签之后到对应闭标签之间的文字。
function Get-InnerText {
    param([string]$Html, $Element)

    if (-not $Element) { return "" }
    $close = "</$($Element.Name)>"
    $end = $Html.IndexOf($close, $Element.End, [System.StringComparison]::OrdinalIgnoreCase)
    if ($end -lt 0) { return "" }
    $raw = $Html.Substring($Element.End, $end - $Element.End)
    return ($raw -replace '<[^>]*>', '').Trim()
}

# 把站内链接解析成产物里的文件；文件名在产物内必须唯一，否则视为无法判定。
function Resolve-OutputFile {
    param([string]$Href, [string]$Root)

    if (-not $Href) { return $null }
    $path = ($Href -replace '^[A-Za-z][A-Za-z0-9+.-]*://[^/]+', '').Split('?')[0].Split('#')[0]
    $leaf = ($path -split '/')[-1]
    if (-not $leaf) { return $null }
    $hits = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue)
    if ($hits.Count -ne 1) { return $null }
    return $hits[0].FullName
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function ConvertTo-HexColor {
    param([string]$Value)

    $m = [regex]::Match($Value, '^#(?<hex>[0-9A-Fa-f]{6})$')
    if (-not $m.Success) { return $null }
    $hex = $m.Groups['hex'].Value
    return @(
        [Convert]::ToInt32($hex.Substring(0, 2), 16),
        [Convert]::ToInt32($hex.Substring(2, 2), 16),
        [Convert]::ToInt32($hex.Substring(4, 2), 16)
    )
}

function Get-RelativeLuminance {
    param([int[]]$Rgb)

    $channel = {
        param([int]$v)
        $s = $v / 255.0
        if ($s -le 0.04045) { return $s / 12.92 }
        return [Math]::Pow(($s + 0.055) / 1.055, 2.4)
    }
    $r = & $channel $Rgb[0]
    $g = & $channel $Rgb[1]
    $b = & $channel $Rgb[2]
    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Get-ContrastRatio {
    param([int[]]$Foreground, [int[]]$Background)

    $a = Get-RelativeLuminance $Foreground
    $b = Get-RelativeLuminance $Background
    $hi = [Math]::Max($a, $b)
    $lo = [Math]::Min($a, $b)
    return [Math]::Round(($hi + 0.05) / ($lo + 0.05), 2)
}

# 取出所有匹配的 @media 块（含嵌套规则），返回块内文本数组；没有就返回空数组。
function Get-CssMediaBlocks {
    param([string]$Css, [string]$Query)

    # 压缩后的 CSS 会去掉空格，所以按词拼正则而不是原样匹配整句。
    $queryPattern = (($Query -split '\s+') | Where-Object { $_ } | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    $blocks = @()
    foreach ($match in [regex]::Matches($Css, '@media\s*\(\s*' + $queryPattern + '[^)]*\)\s*\{', 'IgnoreCase')) {
        $start = $match.Index + $match.Length
        $depth = 1
        $i = $start
        while ($i -lt $Css.Length -and $depth -gt 0) {
            $ch = $Css[$i]
            if ($ch -eq '{') { $depth++ }
            elseif ($ch -eq '}') { $depth-- }
            $i++
        }
        if ($depth -eq 0) { $blocks += $Css.Substring($start, $i - $start - 1) }
    }
    return $blocks
}

# 统计 HTML 里某个 class 出现的次数（按开标签算）。
function Get-ClassCount {
    param([string]$Html, [string]$Class)

    $pattern = 'class\s*=\s*("([^"]*)"|''([^'']*)''|([^\s>]+))'
    $count = 0
    foreach ($m in [regex]::Matches($Html, $pattern)) {
        $value = if ($m.Groups[2].Success) { $m.Groups[2].Value }
                 elseif ($m.Groups[3].Success) { $m.Groups[3].Value }
                 else { $m.Groups[4].Value }
        if (($value -split '\s+' | Where-Object { $_ }) -contains $Class) { $count++ }
    }
    return $count
}

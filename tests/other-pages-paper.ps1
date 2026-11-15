#requires -Version 5.1
[CmdletBinding()]
param([string]$Destination = ".tools/other-pages-public", [string]$HugoBinary = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib/harness.ps1")
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root $Destination
$build = Invoke-SiteBuild -RepoRoot $root -HugoBinary $HugoBinary -Destination $Destination
Test-Check ($build.Exit -eq 0 -and $build.Unexpected.Count -eq 0) "生产构建成功且没有新增警告" $build.Unexpected
$pages = [regex]::Match(($build.Log -join "`n"), 'Pages\s+\S+\s+(\d+)')
Test-Check ($pages.Success -and [int]$pages.Groups[1].Value -eq 109) "页面数与基线一致"

Write-Section "系列页"
$series = [IO.File]::ReadAllText((Join-Path $out 'series/matt-pocock-skills/index.html'))
Test-Check ($series -match '逐条拆解一套 Agent 技能库的设计取舍与使用边界') "系列页显示系列说明"
$first = $series.IndexOf('/blog/matt-pocock-skills-01/')
$second = $series.IndexOf('/blog/matt-pocock-skills-02/')
$last = $series.IndexOf('/blog/matt-pocock-skills-07/')
Test-Check ($first -ge 0 -and $second -gt $first -and $last -gt $second) "系列文章按阅读顺序排列"

Write-Section "关于页"
$about = [IO.File]::ReadAllText((Join-Path $out 'about/index.html'))
Test-Check ($about -match '(?s)<section[^>]+td-landing-hero.*?brand/seal\.svg.*?</section>') "关于页 hero 包含朱印"
Test-Check ($about -match '这个博客用来记录技术' -and $about -match 'github.com/AyuSne') "关于页保留简介与联系链接"

Write-Section "标签索引"
$tags = [IO.File]::ReadAllText((Join-Path $out 'tags/index.html'))
Test-Check ($tags -notmatch 'td-taxonomy-cards' -and $tags -match 'href=["'']?[^ >"'']*/tags/ai/') "标签索引提供文字链接而非卡片墙"
$tag = [IO.File]::ReadAllText((Join-Path $out 'tags/ai/index.html'))
Test-Check ($tag -match '这里收录标有.*AI.*的文章与译文') "标签词条显示说明"
Test-Check ($tag -match '原作者 Anthropic' -and $tag -match '分钟阅读') "标签词条中的译文显示原作者与阅读时长"

Write-Section "404"
$notFound = [IO.File]::ReadAllText((Join-Path $out '404.html'))
Test-Check ($notFound -match '(?s)<main[^>]*>.*brand/seal\.svg.*data-td-shell-search-open.*?</main>') "404 主内容包含朱印和搜索入口"
Test-Check ($notFound -match '返回首页' -and $notFound -match '浏览博客' -and $notFound -match 'local-search' -and $notFound -match 'td-shell-search') "404 提供首页、博客和可用的站内搜索"

Complete-Tests

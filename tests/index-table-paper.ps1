#requires -Version 5.1
[CmdletBinding()]
param([string]$HugoBinary = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib/harness.ps1")
$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root '.tools/index-table-test.yaml'
$destination = Join-Path $root '.tools/index-table-test-public'
New-Item -ItemType Directory -Force (Split-Path $config) | Out-Null
[IO.File]::WriteAllText($config, "params:`n  ui:`n    blog_index: table`n", [Text.UTF8Encoding]::new($false))
$hugo = Resolve-HugoBinary -Explicit $HugoBinary -RepoRoot $root
$env:GOWORK = 'off'
$env:HUGO_MODULE_WORKSPACE = 'off'
$go = Join-Path $root '.tools/go/bin'
if (Test-Path $go) { $env:PATH = "$go;$env:PATH" }
Push-Location $root
try {
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $log = @(& $hugo --config "hugo.yaml,$config" --destination $destination --cleanDestinationDir --minify --environment production --printPathWarnings 2>&1 | ForEach-Object { "$_" })
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $previousEap
} finally { Pop-Location }
$unexpected = @($log | Where-Object { $_ -match '^\s*(WARN|ERROR)\b' -and $_ -notmatch $script:AcceptedWarning })
Test-Check ($exit -eq 0 -and $unexpected.Count -eq 0) 'table 配置下生产构建成功且没有新增警告' $unexpected
$page2 = Join-Path $destination 'blog/page/2/index.html'
Test-Check (Test-Path -LiteralPath $page2) 'table 配置下博客分页仍可用'
if (Test-Path -LiteralPath $page2) {
    $html = [IO.File]::ReadAllText($page2)
    Test-Check ($html -match '/blog/agent-harness/' -and $html -match '上一页') '第二页显示文章并提供返回链接'
    $head2 = ($html -split '</head>')[0]
    $first = [IO.File]::ReadAllText((Join-Path $destination 'blog/index.html'))
    $head1 = ($first -split '</head>')[0]
    Test-Check ($head1 -match '<link\s+rel=["'']?next["'']?\s+href=["'']?[^ >"'']*/blog/page/2/' -and $head2 -match '<link\s+rel=["'']?prev["'']?\s+href=["'']?[^ >"'']*/blog/') '分页页头提供上一页和下一页元数据'
}
Complete-Tests

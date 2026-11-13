<#
.SYNOPSIS
    DSH x B站 学习插件安装助手

.DESCRIPTION
    探测本机环境 -> 打印安装计划 -> 执行 -> 提示重启。
    默认不安装任何东西，除非你明确去掉 -WhatIf 或 -Check。

    设计原则：
      * 只装"学习向"插件，不装自动刷站 / 互动类
      * 不碰你的 B 站账号、不改已有插件行
      * 每步都可 -WhatIf 预演

.PARAMETER Plan
    A = 零依赖（只装 dsh-bili-study）
    B = 主力组合（dsh-bili-watch + dsh-bili-study）  默认
    C = 全功能（再加 dsh-bili-eyes + 闪卡复习）
    None = 只检查环境

.PARAMETER WithFFmpeg
    用 winget 装 ffmpeg（Gyan.FFmpeg）。也可以装完插件后在面板里一键装。

.PARAMETER WithPython
    用 winget 装 Python 3.12（本地 ASR / OCR 需要）。

.PARAMETER Check
    只探测环境并打印计划，不执行任何安装。

.PARAMETER WhatIf
    打印将要执行的命令，不实际执行。

.EXAMPLE
    .\install.ps1 -Check
    体检：看看缺什么。

.EXAMPLE
    .\install.ps1 -Plan B -WhatIf
    预演：看看方案 B 会装哪些包。

.EXAMPLE
    .\install.ps1 -Plan B -WithFFmpeg
    真装：装 ffmpeg + 两个插件，然后重启 DSH。

.NOTES
    本脚本保存为 UTF-8 with BOM，Windows PowerShell 5.1 与 pwsh 7 均可正确读取中文。
    注意：profile 里的 package.json 要求相反（必须无 BOM），否则 DSH 启动会崩，两者别记混。
#>
[CmdletBinding()]
param(
    [ValidateSet('A', 'B', 'C', 'None')]
    [string]$Plan = 'B',

    [switch]$WithFFmpeg,
    [switch]$WithPython,
    [switch]$Check,
    [switch]$WhatIf,

    [string]$DshBin = 'E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js',
    [string]$ProfileName = 'web'
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- 输出 helpers
function Write-Section([string]$text) {
    Write-Host ''
    Write-Host ("=" * 68) -ForegroundColor DarkGray
    Write-Host " $text" -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor DarkGray
}
function Write-Ok([string]$text)   { Write-Host ("  [OK]      " + $text) -ForegroundColor Green }
function Write-Miss([string]$text) { Write-Host ("  [MISSING] " + $text) -ForegroundColor Yellow }
function Write-Info([string]$text) { Write-Host ("  [i]       " + $text) -ForegroundColor Gray }
function Write-Bad([string]$text)  { Write-Host ("  [ERR]     " + $text) -ForegroundColor Red }

# ---------------------------------------------------------------- 环境探测
function Test-CommandExists([string]$name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Windows 的 python.exe 可能是应用商店存根，必须实际跑一次才算数
function Get-RealPython {
    foreach ($cand in @('python', 'py')) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        if ($cmd.Source -match 'WindowsApps') { continue }
        try {
            $out = & $cand --version 2>&1
            if ("$out" -match 'Python 3\.(\d+)') {
                return [pscustomobject]@{ Cmd = $cand; Version = "$out".Trim(); Path = $cmd.Source }
            }
        } catch { }
    }
    return $null
}

function Get-DshVersion {
    if (-not (Test-Path $DshBin)) { return $null }
    try { return (& node $DshBin --version 2>&1 | Select-Object -First 1).Trim() } catch { return $null }
}

function Get-InstalledPlugins {
    $pj = Join-Path $env:USERPROFILE ".dsh\profiles\$ProfileName\package.json"
    if (-not (Test-Path $pj)) { return @() }
    try {
        $j = Get-Content $pj -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($j.dependencies.PSObject.Properties.Name)
    } catch { return @() }
}

# ---------------------------------------------------------------- 1. 探测
Write-Section '1/4  环境探测'

if (-not (Test-Path $DshBin)) {
    Write-Bad "找不到 DSH 入口: $DshBin"
    Write-Info '用参数指定: -DshBin "<你的 bin.js 完整路径>"'
    exit 1
}
Write-Ok "DSH 入口  $DshBin"

$dshVer = Get-DshVersion
if ($dshVer) { Write-Ok "DSH 版本  $dshVer" } else { Write-Bad 'DSH 版本读取失败'; exit 1 }

if (Test-CommandExists 'node') {
    $nodeVer = (& node --version).Trim()
    Write-Ok "Node      $nodeVer"
} else {
    Write-Bad 'Node 未安装'; exit 1
}

if (Test-CommandExists 'pnpm') { Write-Ok 'pnpm      已安装（dsh plugin 依赖它）' }
else { Write-Miss 'pnpm      未安装 —— dsh plugin 会失败，先装 pnpm' }

if (Test-CommandExists 'git') { Write-Ok 'git       已安装（github: 前缀的包需要）' }
else { Write-Miss 'git       未安装 —— 只能装 npm 包' }

$ffmpegOk = (Test-CommandExists 'ffmpeg') -and (Test-CommandExists 'ffprobe')
if ($ffmpegOk) { Write-Ok 'ffmpeg    已安装（抽帧 / 宫格可用）' }
else { Write-Miss 'ffmpeg    未安装 —— 只能拿字幕/评论，看不了画面（见 -WithFFmpeg）' }

$py = Get-RealPython
if ($py) { Write-Ok ("Python    " + $py.Version + "  (" + $py.Path + ")") }
else {
    $stub = Get-Command 'python' -ErrorAction SilentlyContinue
    if ($stub) { Write-Miss 'Python    只有 Windows 应用商店存根，不是真解释器（见 -WithPython）' }
    else { Write-Miss 'Python    未安装 —— 本地 ASR / OCR 不可用（见 -WithPython）' }
}

if (Test-CommandExists 'uv') { Write-Ok 'uv        已安装' } else { Write-Info 'uv        未安装（可选，很多插件会优先用它建 venv）' }
if (Test-CommandExists 'yt-dlp') { Write-Ok 'yt-dlp    已安装' } else { Write-Info 'yt-dlp    未安装（只有非 B 站链接才需要）' }

Write-Host ''
Write-Info "目标 profile: $ProfileName"
$installed = Get-InstalledPlugins
if ($installed.Count -gt 0) { Write-Info ("已装依赖: " + ($installed -join ', ')) }
else { Write-Info '该 profile 目前没有第三方插件' }

# ---------------------------------------------------------------- 2. 计划
Write-Section '2/4  安装计划'

$plans = @{
    'None' = @()
    'A'    = @('dsh-bili-study')
    'B'    = @('dsh-bili-watch', 'dsh-bili-study')
    'C'    = @('dsh-bili-watch', 'dsh-bili-study', 'dsh-bili-eyes', '@ericwang1358/dsh-daily-flashcard')
}

$packages = @($plans[$Plan])
$planDesc = @{
    'None' = '只检查，不装'
    'A'    = '零依赖起步：学习管理'
    'B'    = '主力组合：内容获取 + 学习管理'
    'C'    = '全功能：再加视觉与闪卡复习'
}

Write-Info ("方案 $Plan —— " + $planDesc[$Plan])

if ($Check) {
    Write-Host ''
    Write-Info '-Check 模式：以下为将要安装的内容，本脚本不会执行安装。'
}

if ($WithFFmpeg) {
    Write-Info '将额外执行: winget install --id Gyan.FFmpeg'
}
if ($WithPython) {
    Write-Info '将额外执行: winget install --id Python.Python.3.12'
    Write-Info '  装完还要手动关掉「应用执行别名」里的 python.exe / python3.exe，否则仍是存根。'
}

$baseCmd = "node `"$DshBin`" plugin --profile $ProfileName add"
foreach ($pkg in $packages) {
    $mark = if ($installed -contains $pkg) { '（已装，跳过）' } else { '' }
    Write-Info ("$baseCmd $pkg  $mark")
}

if ($Check -or $WhatIf) {
    Write-Section '3/4  跳过执行'
    Write-Info '（-Check / -WhatIf 模式不安装任何东西）'
    Write-Section '4/4  完成'
    Write-Info '去掉 -Check / -WhatIf 再跑一次即可真正安装。'
    return
}

# ---------------------------------------------------------------- 3. 执行
Write-Section '3/4  执行安装'

$failed = @()

if ($WithFFmpeg) {
    if (Test-CommandExists 'winget') {
        Write-Info '安装 ffmpeg（winget）...'
        try {
            & winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) { Write-Miss 'winget 返回非 0；可改用插件面板一键装 ffmpeg' }
            else { Write-Ok 'ffmpeg 安装完成（新终端里 ffmpeg -version 验证）' }
        } catch {
            Write-Miss ("winget 执行失败: " + $_.Exception.Message)
        }
    } else {
        Write-Miss '没有 winget；请手动装 ffmpeg，或用插件面板的下载按钮'
    }
}

if ($WithPython) {
    if (Test-CommandExists 'winget') {
        Write-Info '安装 Python 3.12（winget）...'
        try {
            & winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) { Write-Miss 'winget 返回非 0；可到 python.org 手动装' }
            else { Write-Ok 'Python 安装完成（记得关掉应用执行别名）' }
        } catch {
            Write-Miss ("winget 执行失败: " + $_.Exception.Message)
        }
    } else {
        Write-Miss '没有 winget；请到 python.org 手动装 3.12'
    }
}

foreach ($pkg in $packages) {
    if ($installed -contains $pkg) {
        Write-Info "跳过（已装）: $pkg"
        continue
    }
    Write-Info "安装 $pkg ..."
    try {
        & node $DshBin plugin --profile $ProfileName add $pkg
        if ($LASTEXITCODE -ne 0) {
            Write-Bad "失败: $pkg (exit $LASTEXITCODE)"
            $failed += $pkg
        } else {
            Write-Ok "完成: $pkg"
        }
    } catch {
        Write-Bad ("失败: $pkg — " + $_.Exception.Message)
        $failed += $pkg
    }
}

# ---------------------------------------------------------------- 4. 收尾
Write-Section '4/4  下一步'

if ($failed.Count -gt 0) {
    Write-Bad ("以下包安装失败，请单独排查: " + ($failed -join ', '))
}

Write-Info '插件已写入 profile，但 DSH 需要重启才会加载（模块有缓存，不热重载）。'
Write-Info '重启方式：关掉当前 DSH Web 进程，重新启动。'
Write-Host ''
Write-Info '重启后按顺序验证：'
Write-Info '  1. 新开会话，问：「你有哪些 bilibili 相关工具？」应看到 bili_watch'
Write-Info '  2. 说：「用 bili_watch 的 view 看一下 BV1GJ411x7h7」——view 不需要 ffmpeg / 登录'
Write-Info '  3. 需要 AI 字幕：设置 -> bili-watch 面板 -> 扫码登录（建议小号）'
Write-Info '  4. 需要看画面：面板 -> 依赖状态 -> ffmpeg 行末下载按钮'
Write-Host ''
Write-Info '使用方案见：03-网课学习实操方案.md'

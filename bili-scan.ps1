<#
.SYNOPSIS
    区间扫描：把一个时间段均匀抽成 N 帧，缩成小格子拼成一张图，用于"定位"。

.DESCRIPTION
    典型用法是用户说"第 30 分钟那段代码"，但真正有趣的往往是 29:30~31:30。
    与其逐点抽帧试，不如先扫一遍看全貌：

        .\bili-scan.ps1 -Video BV1mqrTBvEaf -Page 7 -From 28:00 -To 33:00 -Count 6

    输出：
      * grid.jpg     —— N 帧拼图，每格烧了编号和时间点
      * frames/      —— 每帧单独的高清原图（供后续精读）
      * manifest.json—— 格子编号 → 时间点 → 原图路径

    为什么省 token：拼图时每格缩到 400px 宽（默认），6 格拼一张约 600 token；
    而 6 张高清单帧约 5850 token。代价是拼图看不清代码，只够定位。
    定位到目标后，用 bili-frame.ps1 对单点抽高清帧精读。

.PARAMETER From
    区间起点，支持 "28:00" / "1680" / "1:02:30"。

.PARAMETER To
    区间终点。必须大于 From。

.PARAMETER Count
    抽几帧，默认 6。会平均分布在区间内（含首尾）。

.PARAMETER CellWidth
    每格宽度（像素），默认 400。越小越省 token，但越看不清。

.PARAMETER Crop
    抽帧时的裁剪参数，格式 "left,top,right,bottom"（像素）。可选。

.EXAMPLE
    .\bili-scan.ps1 -Video BV1mqrTBvEaf -Page 7 -From 28:00 -To 33:00

.EXAMPLE
    # 只抽 4 帧、每格 600px，看细一点
    .\bili-scan.ps1 -Video BV1mqrTBvEaf -Page 7 -From 30:00 -To 31:00 -Count 4 -CellWidth 600
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Video,

    [int]$Page = 1,

    [Parameter(Mandatory = $true)]
    [string]$From,

    [Parameter(Mandatory = $true)]
    [string]$To,

    [int]$Count = 6,

    [int]$CellWidth = 400,

    [string]$Crop = "",

    [string]$OutDir = ".\scan",

    [int]$Quality = 0,

    [switch]$KeepFrames,   # 保留逐帧高清原图（默认保留）

    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

function ConvertTo-Seconds {
    param([string]$Text)
    $t = $Text.Trim()
    if ($t -match '^(\d+):(\d{1,2}):(\d{1,2})$') { return [int]$matches[1]*3600 + [int]$matches[2]*60 + [int]$matches[3] }
    if ($t -match '^(\d+):(\d{1,2})$')            { return [int]$matches[1]*60 + [int]$matches[2] }
    if ($t -match '^\d+(\.\d+)?$')                { return [int][double]$t }
    throw "无法解析时间: '$Text'"
}

function Format-Time([double]$sec) {
    $ts = [TimeSpan]::FromSeconds($sec)
    if ($ts.TotalHours -ge 1) { return "{0}:{1:00}:{2:00}" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds }
    return "{0:00}:{1:00}" -f $ts.Minutes, $ts.Seconds
}

if ($Count -lt 2) { throw "-Count 至少为 2" }
if ($Count -gt 12) { throw "-Count 最多 12（再多拼图就看不清了）" }

$fromSec = ConvertTo-Seconds $From
$toSec   = ConvertTo-Seconds $To
if ($toSec -le $fromSec) { throw "-To 必须大于 -From" }
$span = $toSec - $fromSec

# 均匀取点（含首尾）
$points = @()
for ($i = 0; $i -lt $Count; $i++) {
    if ($Count -eq 1) { $points += $fromSec }
    else { $points += [int]($fromSec + $span * $i / ($Count - 1)) }
}
$times = $points | ForEach-Object { Format-Time $_ }

# ---------------------------------------------------------------- 抽帧
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$framesDir = Join-Path $OutDir "frames"
if (Test-Path $framesDir) { Remove-Item $framesDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $framesDir | Out-Null

$frameScript = Join-Path $PSScriptRoot "bili-frame.ps1"
$frameArgs = @{
    Video  = $Video
    At     = ($times -join ',')
    Page   = $Page
    OutDir = $framesDir
    Quality = $Quality
    Json   = $true
}
if ($Crop) { $frameArgs['Crop'] = $Crop }

$raw = & $frameScript @frameArgs | Out-String
try {
    $parsed = $raw | ConvertFrom-Json
    $frameList = @($parsed)
} catch { throw "抽帧结果解析失败: $raw" }

$okFrames = @($frameList | Where-Object { $_.ok })
if ($okFrames.Count -eq 0) { throw "所有抽帧都失败了" }

# ---------------------------------------------------------------- 缩放 + 烧编号
$numbered = @()
$idx = 0
foreach ($f in $okFrames) {
    $idx++
    $num = "{0:D2}" -f $idx
    $dst = Join-Path $OutDir ("cell_{0}.jpg" -f $num)
    $label = $f.time
    # ffmpeg filter 里冒号是参数分隔符，必须转义，否则 "28:00" 会被截成 "28"
    $labelSafe = $label -replace ':', '\:'
    # 字号随格宽缩放，保证 400px 宽也能看清
    $fontSize = [math]::Max(14, [int]($CellWidth / 20))
    $ff = "scale=${CellWidth}:-2,drawtext=fontfile='C\:/Windows/Fonts/msyh.ttc':text='$num $labelSafe':fontsize=${fontSize}:fontcolor=yellow:box=1:boxcolor=black@0.65:boxborderw=6:x=8:y=8"
    & ffmpeg -y -loglevel error -i $f.file -vf $ff -q:v 3 $dst 2>&1 | Out-Null
    if (Test-Path $dst) {
        $numbered += [pscustomobject]@{ index = $idx; num = $num; time = $f.time; sec = $f.sec; cell = $dst; original = $f.file; link = $f.link }
    }
}

if ($numbered.Count -eq 0) { throw "缩放/烧号全部失败" }

# ---------------------------------------------------------------- 拼图
$cols = if ($numbered.Count -le 4) { 2 } elseif ($numbered.Count -le 9) { 3 } else { 4 }
$rows = [math]::Ceiling($numbered.Count / $cols)
$gridPath = Join-Path $OutDir "grid.jpg"

$seqDir = Join-Path $OutDir "_seq"
if (Test-Path $seqDir) { Remove-Item $seqDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $seqDir | Out-Null
$n = 0
foreach ($f in $numbered) { $n++; Copy-Item $f.cell (Join-Path $seqDir ("s{0:D2}.jpg" -f $n)) -Force }

& ffmpeg -y -loglevel error -framerate 1 -i (Join-Path $seqDir "s%02d.jpg") -vf "tile=${cols}x${rows}:padding=6:margin=6" -frames:v 1 -q:v 3 $gridPath 2>&1 | Out-Null

if (-not (Test-Path $gridPath)) {
    # tile 失败时退回逐格输出
    Write-Warning "拼图失败，仅保留逐格图片"
    $gridPath = $null
}
Remove-Item $seqDir -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------- 统计
Add-Type -AssemblyName System.Drawing
$gridW = 0; $gridH = 0; $gridKB = 0
if ($gridPath -and (Test-Path $gridPath)) {
    $img = [System.Drawing.Image]::FromFile($gridPath); $gridW = $img.Width; $gridH = $img.Height; $img.Dispose()
    $gridKB = [math]::Round((Get-Item $gridPath).Length / 1KB, 1)
}
$cellW = 0; $cellH = 0
$first = Get-Item $numbered[0].cell
$img2 = [System.Drawing.Image]::FromFile($first.FullName); $cellW = $img2.Width; $cellH = $img2.Height; $img2.Dispose()

$gridTokens = if ($gridW -gt 0) { [math]::Ceiling($gridW/32) * [math]::Ceiling($gridH/32) } else { 0 }
$singleTokens = [math]::Ceiling($okFrames[0].width/32) * [math]::Ceiling($okFrames[0].height/32)
$totalSingle = $singleTokens * $okFrames.Count

$manifest = [pscustomobject]@{
    video   = $okFrames[0].title
    part    = $okFrames[0].part
    bvid    = $okFrames[0].bvid
    page    = $Page
    range   = "$From ~ $To"
    count   = $numbered.Count
    grid    = $gridPath
    gridSize = if ($gridW) { "${gridW}x${gridH}" } else { $null }
    gridTokenEst = $gridTokens
    cells   = $numbered | ForEach-Object {
        [pscustomobject]@{ index=$_.index; time=$_.time; sec=$_.sec; link=$_.link; original=$_.original; cell=$_.cell }
    }
}
[System.IO.File]::WriteAllText((Join-Path $OutDir "manifest.json"), ($manifest | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))

# ---------------------------------------------------------------- 输出
if ($Json) {
    $manifest | ConvertTo-Json -Depth 5
} else {
    Write-Host ("视频: {0}" -f $manifest.video) -ForegroundColor Cyan
    Write-Host ("P{0}  {1}  扫描 {2} ～ {3}，{4} 帧" -f $Page, $manifest.part, $From, $To, $numbered.Count) -ForegroundColor Cyan
    Write-Host ("`n拼图: {0}" -f $gridPath) -ForegroundColor Green
    if ($gridW) {
        Write-Host ("  尺寸 {0}x{1} | {2} KB | 约 {3} token（{4} 帧，每格 {5}x{6}）" -f $gridW, $gridH, $gridKB, $gridTokens, $numbered.Count, $cellW, $cellH) -ForegroundColor DarkGray
        Write-Host ("  对比：逐张高清看约 {0} token → 拼图省 {1:P0}" -f $totalSingle, (1 - $gridTokens / $totalSingle)) -ForegroundColor DarkGray
    }
    Write-Host ("`n格子对照:") -ForegroundColor Cyan
    $numbered | ForEach-Object {
        Write-Host ("  [{0}] {1,8}  {2}" -f $_.num, $_.time, $_.link) -ForegroundColor Gray
    }
    Write-Host ("`n逐帧高清原图: {0}" -f $framesDir) -ForegroundColor DarkGray
    Write-Host ("清单: {0}" -f (Join-Path $OutDir 'manifest.json')) -ForegroundColor DarkGray
}

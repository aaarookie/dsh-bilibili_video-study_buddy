<#
.SYNOPSIS
    只转写视频的一小段，默认带"前铺垫 + 后延续"，避免整片转写。

.DESCRIPTION
    看课时真正需要的往往只是某一段。整片转写 2 小时要十几分钟，
    而只转"目标点 ± 90 秒"只要十几秒。

    但**裸切 90 秒会丢上下文**：够讲清"这段在干什么"，
    不够判断"这是新概念还是回顾"。所以默认往前多取 60 秒、往后多取 30 秒：

        .\bili-asr.ps1 -Video BV1mqrTBvEaf -Page 7 -At 30:00
        → 实际转写 29:00 ~ 30:30，并标出哪几行属于目标点

    两种模式：
      -At        单点模式，前后自动展开（-Pre / -Post）
      -From -To  区间模式，严格按给定范围

.PARAMETER At
    目标时间点。与 -From/-To 二选一。

.PARAMETER Pre
    目标点之前多取的秒数，默认 60。

.PARAMETER Post
    目标点之后多取的秒数，默认 30。

.PARAMETER Lang
    语言：auto（默认）/ zh / en / ja。

.EXAMPLE
    .\bili-asr.ps1 -Video BV1mqrTBvEaf -Page 7 -At 30:00

.EXAMPLE
    # 只要 29:00-32:00，不要自动扩展
    .\bili-asr.ps1 -Video BV1mqrTBvEaf -Page 7 -From 29:00 -To 32:00
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Video,

    [int]$Page = 1,

    [string]$At = "",
    [string]$From = "",
    [string]$To = "",

    [int]$Pre = 60,
    [int]$Post = 30,

    [ValidateSet('auto', 'zh', 'en', 'ja')]
    [string]$Lang = 'auto',

    [string]$OutDir = ".\asr",
    [string]$Model = "",
    [switch]$KeepWav,
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

# ---------------------------------------------------------------- 工具
$script:biliSession = $null
function Get-BiliSession {
    param([string]$Cookie)
    if ($null -ne $script:biliSession) { return $script:biliSession }
    if (-not $Cookie) { return $null }
    $s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    foreach ($pair in ($Cookie -split ';\s*')) {
        if ($pair -match '^([^=]+)=(.*)$') {
            $n = $matches[1].Trim(); $v = $matches[2].Trim()
            try { $s.Cookies.Add((New-Object System.Net.Cookie($n, $v, '/', '.bilibili.com'))) } catch { }
        }
    }
    $script:biliSession = $s
    return $s
}

function Invoke-BiliApi {
    param([string]$Url, [string]$Cookie, [string]$Referer)
    $h = @{ 'User-Agent' = $UA; 'Referer' = $Referer }
    $s = Get-BiliSession -Cookie $Cookie
    if ($s) { return Invoke-RestMethod $Url -WebSession $s -Headers $h -TimeoutSec 25 }
    return Invoke-RestMethod $Url -Headers $h -TimeoutSec 25
}

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

# ---------------------------------------------------------------- 登录态
$CredFile = Join-Path $env:USERPROFILE ".dsh\bili-watch\credential.json"
$cookieStr = ""
if (Test-Path $CredFile) {
    try {
        $c = Get-Content $CredFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $parts = @()
        if ($c.sessdata) { $parts += "SESSDATA=$($c.sessdata)" }
        if ($c.bili_jct) { $parts += "bili_jct=$($c.bili_jct)" }
        if ($c.buvid3)   { $parts += "buvid3=$($c.buvid3)" }
        if ($parts.Count -gt 0) { $cookieStr = $parts -join '; ' }
    } catch { }
}

if (-not $At -and -not ($From -and $To)) { throw "要么给 -At，要么同时给 -From 和 -To" }

if ($Video -notmatch '(BV[0-9A-Za-z]{10})') { throw "无法解析 BV 号" }
$bvid = $matches[1]
$referer = "https://www.bilibili.com/video/$bvid"

# ---------------------------------------------------------------- 区间
$usePointMode = [bool]$At
if ($usePointMode) {
    $atSec = ConvertTo-Seconds $At
    $clipFrom = [math]::Max(0, $atSec - $Pre)
    $clipTo = $atSec + $Post
} else {
    $clipFrom = ConvertTo-Seconds $From
    $clipTo = ConvertTo-Seconds $To
    if ($clipTo -le $clipFrom) { throw "-To 必须大于 -From" }
}
$clipDur = $clipTo - $clipFrom

# ---------------------------------------------------------------- 视频信息
$view = Invoke-BiliApi -Url "https://api.bilibili.com/x/web-interface/view?bvid=$bvid" -Cookie $cookieStr -Referer $referer
if ($view.code -ne 0) { throw "取视频信息失败 code=$($view.code)" }
if ($Page -lt 1 -or $Page -gt $view.data.videos) { throw "分 P 超出范围：共 $($view.data.videos) P" }
$pageInfo = $view.data.pages[$Page - 1]
$cid = $pageInfo.cid
$pageDur = [double]$pageInfo.duration
if ($clipFrom -ge $pageDur) { throw "起点 $From 超出 P$Page 时长 $(Format-Time $pageDur)" }
if ($clipTo -gt $pageDur) { $clipTo = $pageDur; $clipDur = $clipTo - $clipFrom }

# ---------------------------------------------------------------- 音频轨
$play = Invoke-BiliApi -Url "https://api.bilibili.com/x/player/playurl?bvid=$bvid&cid=$cid&qn=32&fnval=16&fnver=0" -Cookie $cookieStr -Referer $referer
if (-not $play.data.dash -or -not $play.data.dash.audio) { throw "取不到音频轨" }
$au = $play.data.dash.audio | Sort-Object { [int]$_.id } -Descending | Select-Object -First 1
$audioUrl = $au.baseUrl

# ---------------------------------------------------------------- 抽音频
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$wav = Join-Path $OutDir ("{0}_P{1}_{2}s-{3}s.wav" -f $bvid, $Page, [int]$clipFrom, [int]$clipTo)

& ffmpeg -y -loglevel error -headers "Referer: $referer`r`nUser-Agent: $UA`r`n" -ss $clipFrom -t $clipDur -i $audioUrl -vn -ac 1 -ar 16000 $wav 2>&1 | Out-Null
if (-not (Test-Path $wav) -or (Get-Item $wav).Length -eq 0) { throw "音频抽取失败" }

# ---------------------------------------------------------------- 模型
if (-not $Model) {
    $modelRoot = Join-Path $env:USERPROFILE ".dsh\bili-watch\deps\.hf-home\hub\models--Systran--faster-whisper-small\snapshots"
    if (Test-Path $modelRoot) {
        $Model = (Get-ChildItem $modelRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
}
if (-not $Model -or -not (Test-Path $Model)) { throw "找不到 faster-whisper 模型，先跑 dsh-bili-watch 的 fetch-deps，或用 -Model 指定" }

$py = Join-Path $env:USERPROFILE ".dsh\bili-watch\deps\.venv-asr\Scripts\python.exe"
if (-not (Test-Path $py)) { throw "找不到 ASR 解释器: $py" }

$helper = Join-Path $PSScriptRoot "asr_transcribe.py"
$jsonOut = Join-Path $OutDir ("{0}_P{1}_{2}s-{3}s.json" -f $bvid, $Page, [int]$clipFrom, [int]$clipTo)
& $py $helper $wav --model $Model --lang $Lang --offset $clipFrom --out $jsonOut 2>&1 | Out-Null
if (-not (Test-Path $jsonOut)) { throw "转写失败" }

$result = Get-Content $jsonOut -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $KeepWav) { Remove-Item $wav -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------- 输出
$lines = @()
$lines += ("# ASR 转写 | {0}" -f $view.data.title)
$lines += ""
$lines += ("> P{0} {1} ｜ 区间 {2} ~ {3}（{4:N0} 秒）｜ 语言 {5} ｜ 耗时 {6} 秒" -f `
    $Page, $pageInfo.part, (Format-Time $clipFrom), (Format-Time $clipTo), $clipDur, $result.lang, $result.elapsed)
if ($usePointMode) {
    $lines += ("> 目标点 {0}（已自动带上前 {1} 秒铺垫、后 {2} 秒延续）" -f (Format-Time $atSec), $Pre, $Post)
}
$lines += ""

foreach ($it in $result.items) {
    $mark = ""
    if ($usePointMode -and $it.from -le $atSec -and $it.to -ge $atSec) { $mark = "   <<< 目标点" }
    $lines += ("[{0}] {1}{2}" -f (Format-Time $it.from), $it.text, $mark)
}

$textPath = Join-Path $OutDir ("{0}_P{1}_{2}s-{3}s.md" -f $bvid, $Page, [int]$clipFrom, [int]$clipTo)
[System.IO.File]::WriteAllText($textPath, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

if ($Json) {
    [pscustomobject]@{
        ok = $true; bvid = $bvid; page = $Page
        range = "$(Format-Time $clipFrom) ~ $(Format-Time $clipTo)"
        seconds = [math]::Round($clipDur)
        lang = $result.lang
        elapsed = $result.elapsed
        count = $result.count
        file = $textPath
        items = $result.items
    } | ConvertTo-Json -Depth 5
} else {
    Write-Host ("视频: {0}" -f $view.data.title) -ForegroundColor Cyan
    Write-Host ("P{0}  {1}" -f $Page, $pageInfo.part) -ForegroundColor Cyan
    Write-Host ("转写区间: {0} ~ {1}（{2:N0} 秒）｜ 语言 {3} ｜ 耗时 {4} 秒" -f `
        (Format-Time $clipFrom), (Format-Time $clipTo), $clipDur, $result.lang, $result.elapsed) -ForegroundColor DarkGray
    if ($usePointMode) { Write-Host ("目标点: {0}（前 {1}s 铺垫 + 后 {2}s 延续）" -f (Format-Time $atSec), $Pre, $Post) -ForegroundColor DarkGray }
    Write-Host ""
    $lines | Select-Object -Skip 4 | ForEach-Object { Write-Host $_ }
    Write-Host ("`n[OK] 已保存 {0}" -f $textPath) -ForegroundColor Green
}

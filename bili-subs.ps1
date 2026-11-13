<#
.SYNOPSIS
    提取 B 站 AI/CC 字幕，并检测是否"串台"（内容与视频对不上）。

.DESCRIPTION
    B 站的 AI 字幕偶尔会返回**别的视频**的文稿（实测遇到过：GPT 课返回了核能字幕）。
    直接拿去写笔记会把完全无关的内容写进去。本脚本做三件事：

      1. 带登录态取字幕轨并下载全文；
      2. 用三个独立信号判断是否串台：
         - 覆盖度：字幕最后一条的时间 / 视频总时长（正常应 > 0.8）
         - 标题关键词命中：标题里的英文术语是否出现在字幕中
         - 语速合理性：平均每条字幕的时长（正常 1~6 秒）
      3. 给出 PASS / WARN / FAIL 结论，FAIL 时拒绝输出正文（除非 -Force）。

.PARAMETER Video
    BV 号或视频链接。

.PARAMETER Page
    第几个分 P，默认 1。

.PARAMETER Format
    输出格式：md（带时间码，默认）/ srt / txt。

.PARAMETER OutDir
    输出目录，默认 .\subs

.PARAMETER Force
    即使判定 FAIL 也输出字幕（仅用于人工核对）。

.EXAMPLE
    .\bili-subs.ps1 -Video BV1mqrTBvEaf -Page 7
    # 预期：FAIL —— 返回的字幕讲的是核能，与 GPT 课无关

.EXAMPLE
    .\bili-subs.ps1 -Video BV1xx411c7mD -Page 1 -Format srt
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Video,

    [int]$Page = 1,

    [ValidateSet('md', 'srt', 'txt')]
    [string]$Format = 'md',

    [string]$OutDir = ".\subs",

    [string]$CredFile = "",

    [switch]$Force,

    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

# ---------------------------------------------------------------- 登录态
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

if (-not $CredFile) { $CredFile = Join-Path $env:USERPROFILE ".dsh\bili-watch\credential.json" }
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
if (-not $cookieStr) { Write-Warning "没有登录凭证，AI 字幕通常取不到。先扫码登录 dsh-bili-watch。" }

# ---------------------------------------------------------------- 工具
function ConvertTo-SrtTime([double]$sec) {
    $ts = [TimeSpan]::FromSeconds($sec)
    return "{0:00}:{1:00}:{2:00},{3:000}" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds
}
function Format-Time([double]$sec) {
    $ts = [TimeSpan]::FromSeconds($sec)
    if ($ts.TotalHours -ge 1) { return "{0}:{1:00}:{2:00}" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds }
    return "{0:00}:{1:00}" -f $ts.Minutes, $ts.Seconds
}

# ---------------------------------------------------------------- 主流程
if ($Video -notmatch '(BV[0-9A-Za-z]{10})') { throw "无法从 '$Video' 解析 BV 号" }
$bvid = $matches[1]
$referer = "https://www.bilibili.com/video/$bvid"

$view = Invoke-BiliApi -Url "https://api.bilibili.com/x/web-interface/view?bvid=$bvid" -Cookie $cookieStr -Referer $referer
if ($view.code -ne 0) { throw "取视频信息失败 code=$($view.code): $($view.message)" }

$totalPages = $view.data.videos
if ($Page -lt 1 -or $Page -gt $totalPages) { throw "分 P 超出范围：共 $totalPages P" }
$pageInfo = $view.data.pages[$Page - 1]
$cid = $pageInfo.cid
$videoDuration = [double]$pageInfo.duration
$title = $view.data.title
$partTitle = $pageInfo.part
$desc = $view.data.desc

$pv = Invoke-BiliApi -Url "https://api.bilibili.com/x/player/v2?bvid=$bvid&cid=$cid" -Cookie $cookieStr -Referer $referer
$subs = $pv.data.subtitle.subtitles

if (-not $subs -or @($subs).Count -eq 0) {
    $msg = "该 P 没有可用的字幕轨（可能是真无字幕，或未登录）"
    if ($Json) {
        @{ ok = $false; bvid = $bvid; page = $Page; reason = $msg } | ConvertTo-Json
    } else {
        Write-Host ("视频: {0}" -f $title) -ForegroundColor Cyan
        Write-Host ("P{0}/{1}  {2}  时长 {3}" -f $Page, $totalPages, $partTitle, (Format-Time $videoDuration)) -ForegroundColor Cyan
        Write-Host "`n[无字幕] $msg" -ForegroundColor Yellow
    }
    exit 2
}

$track = @($subs)[0]
$subUrl = $track.subtitle_url
if ($subUrl.StartsWith('//')) { $subUrl = 'https:' + $subUrl }

try {
    $body = Invoke-BiliApi -Url $subUrl -Cookie $cookieStr -Referer "https://www.bilibili.com/"
} catch {
    throw "下载字幕正文失败: $($_.Exception.Message)"
}
$items = @($body.body)
if ($items.Count -eq 0) { throw "字幕正文为空" }

# ---------------------------------------------------------------- 串台检测
$lastFrom = ($items | Measure-Object -Property from -Maximum).Maximum
$coverage = if ($videoDuration -gt 0) { $lastFrom / $videoDuration } else { 0 }
$avgDur = if ($items.Count -gt 0) { ($items | Measure-Object -Property to -Average).Average - ($items | Measure-Object -Property from -Average).Average } else { 0 }

# 标题里的英文术语（长度 >= 3，去掉常见虚词）
$stopWords = @('the','and','for','with','from','into','your','this','that','are','you','can','not','but','all','out','one','two','how','why','what','when','will','has','have','was','were','they','them','its','his','her','our','their')
$titleTerms = [regex]::Matches("$title $partTitle", '[A-Za-z][A-Za-z0-9]{2,}') |
    ForEach-Object { $_.Value.ToLower() } |
    Where-Object { $stopWords -notcontains $_ } |
    Select-Object -Unique
$allText = ($items | ForEach-Object { $_.content }) -join ' '
$hitTerms = @($titleTerms | Where-Object { $allText -match [regex]::Escape($_) })
$hitRate = if (@($titleTerms).Count -gt 0) { $hitTerms.Count / @($titleTerms).Count } else { 1.0 }

$issues = @()
$level = 'PASS'
if ($coverage -lt 0.5) {
    $issues += ("字幕只覆盖到 {0}（视频 {1}），覆盖度 {2:P0} —— 极可能串台" -f (Format-Time $lastFrom), (Format-Time $videoDuration), $coverage)
    $level = 'FAIL'
} elseif ($coverage -lt 0.8) {
    $issues += ("字幕覆盖度偏低：{0:P0}（末条 {1} / 视频 {2}）" -f $coverage, (Format-Time $lastFrom), (Format-Time $videoDuration))
    if ($level -eq 'PASS') { $level = 'WARN' }
}
if (@($titleTerms).Count -ge 3 -and $hitTerms.Count -eq 0) {
    $issues += ("标题里的英文术语一个都没出现在字幕中（{0}）—— 内容对不上" -f (($titleTerms | Select-Object -First 6) -join ', '))
    $level = 'FAIL'
} elseif (@($titleTerms).Count -ge 3 -and $hitRate -lt 0.25) {
    $issues += ("标题术语命中率仅 {0:P0}" -f $hitRate)
    if ($level -eq 'PASS') { $level = 'WARN' }
}
if ($avgDur -lt 0.5 -or $avgDur -gt 8) {
    $issues += ("平均每条字幕 {0:N1} 秒，语速异常（正常 1~6 秒）" -f $avgDur)
    if ($level -eq 'PASS') { $level = 'WARN' }
}

$levelColor = @{ PASS='Green'; WARN='Yellow'; FAIL='Red' }[$level]

if (-not $Json) {
    Write-Host ("视频: {0}" -f $title) -ForegroundColor Cyan
    Write-Host ("P{0}/{1}  {2}  时长 {3}" -f $Page, $totalPages, $partTitle, (Format-Time $videoDuration)) -ForegroundColor Cyan
    Write-Host ("字幕: {0} 条 | 语言 {1} | 覆盖到 {2}" -f $items.Count, $track.lan_doc, (Format-Time $lastFrom)) -ForegroundColor DarkGray
    Write-Host ("`n[检测] {0}" -f $level) -ForegroundColor $levelColor
    if ($issues.Count -gt 0) { $issues | ForEach-Object { Write-Host ("  - {0}" -f $_) -ForegroundColor $levelColor } }
    else { Write-Host "  - 覆盖度、术语命中、语速均正常" -ForegroundColor Green }
    Write-Host ("  覆盖度 {0:P0} | 术语命中 {1}/{2} | 平均每条 {3:N1}s" -f $coverage, $hitTerms.Count, @($titleTerms).Count, $avgDur) -ForegroundColor DarkGray
}

if ($level -eq 'FAIL' -and -not $Force) {
    if ($Json) {
        @{ ok=$false; level=$level; bvid=$bvid; page=$Page; coverage=$coverage; issues=$issues; sample=(@($items | Select-Object -First 3 | ForEach-Object { $_.content })) } | ConvertTo-Json -Depth 4
    } else {
        Write-Host "`n[拒绝输出] 判定为串台。若仍要人工核对，加 -Force 或 -Json 查看样本。" -ForegroundColor Red
        Write-Host "  样本前 3 条:" -ForegroundColor DarkGray
        $items | Select-Object -First 3 | ForEach-Object { Write-Host ("    [{0}] {1}" -f (Format-Time $_.from), $_.content) -ForegroundColor DarkGray }
    }
    exit 3
}

# ---------------------------------------------------------------- 输出
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$baseName = "{0}_P{1}_{2}" -f $bvid, $Page, $track.lan

$lines = @()
switch ($Format) {
    'srt' {
        for ($i = 0; $i -lt $items.Count; $i++) {
            $lines += ($i + 1).ToString()
            $lines += ("{0} --> {1}" -f (ConvertTo-SrtTime $items[$i].from), (ConvertTo-SrtTime $items[$i].to))
            $lines += $items[$i].content
            $lines += ''
        }
    }
    'txt' {
        $lines = $items | ForEach-Object { $_.content }
    }
    default {
        $lines += ("# {0} · P{1}" -f $title, $Page)
        $lines += ""
        $lines += ("> 来源：B 站 AI 字幕（{0}）｜ 视频：{1} ｜ 时长 {2}" -f $track.lan_doc, $referer, (Format-Time $videoDuration))
        $lines += ("> 检测：{0} ｜ 覆盖度 {1:P0}" -f $level, $coverage)
        $lines += ""
        foreach ($it in $items) {
            $lines += ("[{0}] {1}" -f (Format-Time $it.from), $it.content)
        }
    }
}

$outPath = Join-Path $OutDir ("{0}.{1}" -f $baseName, $Format)
[System.IO.File]::WriteAllText($outPath, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

if ($Json) {
    @{
        ok = $true; level = $level; bvid = $bvid; page = $Page
        items = $items.Count; coverage = [math]::Round($coverage,3)
        termHit = "$($hitTerms.Count)/$(@($titleTerms).Count)"
        avgSec = [math]::Round($avgDur,2)
        issues = $issues; file = $outPath
    } | ConvertTo-Json
} else {
    Write-Host ("`n[OK] {0}（{1} 条）" -f $outPath, $items.Count) -ForegroundColor Green
}

<#
.SYNOPSIS
    模糊定位：只知道"大概在讲什么"，不知道在第几分钟时，抽样转写整片并搜索关键词。

.DESCRIPTION
    典型场景：用户说"讲 self-attention 数学技巧的那段"——没给时间点。
    直接整片转写 2 小时要十几分钟；本脚本按固定间隔抽样（默认每 5 分钟取 20 秒），
    批量转写后搜索关键词，给出"大概在哪几分钟"。

        .\bili-find.ps1 -Video BV1mqrTBvEaf -Page 7 -Query "attention,matmul,softmax"

    设计取舍：
      * 抽样保证能在 1~2 分钟内出结果，代价是可能漏掉短暂提及；
      * 命中结果给的是"大概区间"，不精确到秒——定位到区间后，
        用 bili-scan.ps1 扫一遍，再用 bili-asr.ps1 精听。

.PARAMETER Query
    关键词，多个用逗号分隔（OR 关系）。大小写不敏感。
    注意：匹配的是**转写文本**。如果视频是英文而你想搜中文概念，
    这里要填英文（如 attention 而不是"注意力"）。

.PARAMETER Step
    采样间隔（秒），默认 300（每 5 分钟一段）。

.PARAMETER Clip
    每段转写多少秒，默认 20。太短容易漏，太长变慢。

.PARAMETER MaxClips
    最多采多少个片段，默认 30（防止超长视频跑太久）。

.EXAMPLE
    .\bili-find.ps1 -Video BV1mqrTBvEaf -Page 7 -Query "attention"

.EXAMPLE
    # 密集采样找某个具体术语
    .\bili-find.ps1 -Video BV1mqrTBvEaf -Page 7 -Query "softmax,tril" -Step 120 -Clip 30
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Video,

    [int]$Page = 1,

    [Parameter(Mandatory = $true)]
    [string]$Query,

    [int]$Step = 300,
    [int]$Clip = 20,
    [int]$MaxClips = 30,

    [ValidateSet('auto', 'zh', 'en', 'ja')]
    [string]$Lang = 'auto',

    [string]$OutDir = ".\find",
    [string]$Model = "",
    [switch]$KeepAudio,
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

if ($Video -notmatch '(BV[0-9A-Za-z]{10})') { throw "无法解析 BV 号" }
$bvid = $matches[1]
$referer = "https://www.bilibili.com/video/$bvid"

$view = Invoke-BiliApi -Url "https://api.bilibili.com/x/web-interface/view?bvid=$bvid" -Cookie $cookieStr -Referer $referer
if ($view.code -ne 0) { throw "取视频信息失败 code=$($view.code)" }
if ($Page -lt 1 -or $Page -gt $view.data.videos) { throw "分 P 超出范围：共 $($view.data.videos) P" }
$pageInfo = $view.data.pages[$Page - 1]
$cid = $pageInfo.cid
$dur = [double]$pageInfo.duration

$play = Invoke-BiliApi -Url "https://api.bilibili.com/x/player/playurl?bvid=$bvid&cid=$cid&qn=32&fnval=16&fnver=0" -Cookie $cookieStr -Referer $referer
if (-not $play.data.dash -or -not $play.data.dash.audio) { throw "取不到音频轨" }
$au = $play.data.dash.audio | Sort-Object { [int]$_.id } -Descending | Select-Object -First 1
$audioUrl = $au.baseUrl

# ---------------------------------------------------------------- 采样点
$points = @()
for ($t = 0; $t -lt $dur; $t += $Step) { $points += [int]$t }
if ($points.Count -gt $MaxClips) {
    $points = $points | Select-Object -First $MaxClips
    Write-Warning "采样点过多，已截断到 $MaxClips 个（可用 -MaxClips 调整）"
}
if ($points.Count -eq 0) { $points = @(0) }

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$tmp = Join-Path $OutDir "_audio"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# ---------------------------------------------------------------- 抽音频
$jobs = @()
$i = 0
foreach ($p in $points) {
    $i++
    $clipDur = [math]::Min($Clip, $dur - $p)
    if ($clipDur -le 0) { continue }
    $wav = Join-Path $tmp ("clip_{0:D2}.wav" -f $i)
    & ffmpeg -y -loglevel error -headers "Referer: $referer`r`nUser-Agent: $UA`r`n" -ss $p -t $clipDur -i $audioUrl -vn -ac 1 -ar 16000 $wav 2>&1 | Out-Null
    if ((Test-Path $wav) -and (Get-Item $wav).Length -gt 0) {
        $jobs += [pscustomobject]@{ wav = $wav; offset = [double]$p; label = (Format-Time $p) }
    }
}
if ($jobs.Count -eq 0) { throw "所有音频片段都抽取失败" }

if (-not $Json) {
    Write-Host ("视频: {0}" -f $view.data.title) -ForegroundColor Cyan
    Write-Host ("P{0}  {1}  时长 {2}" -f $Page, $pageInfo.part, (Format-Time $dur)) -ForegroundColor Cyan
    Write-Host ("抽样 {0} 段（每 {1} 秒取 {2} 秒），共 {3} 秒音频" -f $jobs.Count, $Step, $Clip, ($jobs.Count * $Clip)) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------- 批量转写
if (-not $Model) {
    $modelRoot = Join-Path $env:USERPROFILE ".dsh\bili-watch\deps\.hf-home\hub\models--Systran--faster-whisper-small\snapshots"
    if (Test-Path $modelRoot) {
        $Model = (Get-ChildItem $modelRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
}
if (-not $Model -or -not (Test-Path $Model)) { throw "找不到 faster-whisper 模型" }

$py = Join-Path $env:USERPROFILE ".dsh\bili-watch\deps\.venv-asr\Scripts\python.exe"
if (-not (Test-Path $py)) { throw "找不到 ASR 解释器: $py" }

$jobsFile = Join-Path $OutDir "jobs.json"
$outFile = Join-Path $OutDir "asr.json"
$payload = @{ model = $Model; lang = $Lang; items = $jobs }
# 必须写无 BOM 的 UTF-8：PS 5.1 的 Set-Content -Encoding UTF8 会带 BOM，Python json.load 会失败
[System.IO.File]::WriteAllText($jobsFile, (ConvertTo-Json -InputObject $payload -Depth 5), [System.Text.UTF8Encoding]::new($false))

& $py (Join-Path $PSScriptRoot "asr_batch.py") $jobsFile $outFile 2>&1 | Out-Null
if (-not (Test-Path $outFile)) { throw "批量转写失败" }
$asr = Get-Content $outFile -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $KeepAudio) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------- 搜索
$keywords = @($Query -split '[,，;；]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($keywords.Count -eq 0) { throw "没有有效的关键词" }

$hits = @()
foreach ($it in $asr.items) {
    foreach ($kw in $keywords) {
        if ($it.text -and ($it.text -match [regex]::Escape($kw))) {
            $hits += [pscustomobject]@{
                keyword = $kw
                time    = Format-Time $it.video_time
                sec     = $it.video_time
                text    = $it.text
                link    = "https://www.bilibili.com/video/${bvid}?p=$Page&t=$([int]$it.video_time)"
            }
            break
        }
    }
}

# ---------------------------------------------------------------- 输出
$result = [pscustomobject]@{
    video = $view.data.title
    part  = $pageInfo.part
    bvid  = $bvid
    page  = $Page
    duration = Format-Time $dur
    lang  = $asr.lang
    sampled = $jobs.Count
    transcribeSeconds = $asr.elapsed
    keywords = $keywords
    hitCount = $hits.Count
    hits  = $hits
}

$outJson = Join-Path $OutDir ("{0}_P{1}_find.json" -f $bvid, $Page)
[System.IO.File]::WriteAllText($outJson, ($result | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    Write-Host ("`n转写耗时 {0} 秒 ｜ 命中 {1} 处" -f $asr.elapsed, $hits.Count) -ForegroundColor DarkGray
    if ($hits.Count -eq 0) {
        Write-Host "`n[未命中] 建议：" -ForegroundColor Yellow
        Write-Host "  - 换更宽泛的关键词（如 attention 而不是 self-attention math trick）"
        Write-Host "  - 视频是英文就说英文关键词"
        Write-Host "  - 用 -Step 120 -Clip 30 加密采样"
    } else {
        Write-Host "`n命中:" -ForegroundColor Green
        $hits | Sort-Object sec | ForEach-Object {
            Write-Host ("  [{0}] {1}" -f $_.time, $_.text) -ForegroundColor Gray
            Write-Host ("        {0}" -f $_.link) -ForegroundColor DarkGray
        }
        $groups = $hits | Group-Object { [math]::Floor($_.sec / $Step) * $Step } | Sort-Object { [int]$_.Name }
        Write-Host ("`n集中区间:") -ForegroundColor Cyan
        $groups | ForEach-Object {
            $start = [int]$_.Name
            Write-Host ("  {0} ~ {1}  （{2} 处）" -f (Format-Time $start), (Format-Time ($start + $Step)), $_.Count) -ForegroundColor Gray
        }
    }
    Write-Host ("`n清单: {0}" -f $outJson) -ForegroundColor DarkGray
}

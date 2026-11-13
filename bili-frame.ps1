<#
.SYNOPSIS
    按时间点从 B 站视频抽帧，支持登录态高清、局部裁剪与放大。

.DESCRIPTION
    看网课时用来"看某一刻的画面"：给 BV 号 + 时间点，把那一帧存成图片，
    并输出带 ?t= 的跳转链接。

    主要能力：
      * ffmpeg -ss 直取，不下载整段视频（秒级）
      * 自动读取 dsh-bili-watch 的扫码凭证，登录后拿 1080P + 字幕
      * 局部裁剪（-Crop）+ 放大（-Zoom），用更少 token 看清代码
      * 自动处理多 P（时间点必须在指定 P 之内）
      * 优先 avc1 编码；CDN 失败自动轮换重试

.PARAMETER Video
    BV 号或视频链接。

.PARAMETER At
    时间点，可多个。支持 "12:30" / "750" / "1:02:30"。

.PARAMETER Page
    第几个分 P，默认 1。多 P 课程务必指定。

.PARAMETER Quality
    清晰度 qn：16=360p 32=480p 64=720p 80=1080p。0（默认）= 自动：
    有登录态用 80，匿名用 32。

.PARAMETER Crop
    裁掉四边，格式 "left,top,right,bottom"（像素）。例：-Crop "0,90,0,60"
    左边距, 上边距, 右边距, 下边距。用于去掉浏览器工具栏、播放器 UI、字幕条。

.PARAMETER Zoom
    裁剪后放大倍数，默认 1。2 = 放大两倍（缩小图放大看细节）。

.PARAMETER CredFile
    凭证 JSON 路径。默认自动找 ~/.dsh/bili-watch/credential.json。

.PARAMETER Sessdata
    直接给 SESSDATA（优先级高于 CredFile）。

.EXAMPLE
    .\bili-frame.ps1 -Video BV1mqrTBvEaf -At 30:00 -Page 7

.EXAMPLE
    # 登录态 1080P + 裁掉顶部 100 和底部 60，再放大 1.5 倍
    .\bili-frame.ps1 -Video BV1mqrTBvEaf -At 30:00 -Page 7 -Crop "0,100,0,60" -Zoom 1.5

.EXAMPLE
    # 只保留左侧代码区（右边留给人脸小窗）
    .\bili-frame.ps1 -Video BV1mqrTBvEaf -At 30:00 -Page 7 -Crop "0,100,420,60" -Zoom 2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Video,

    [Parameter(Mandatory = $true, Position = 1)]
    [string[]]$At,

    [int]$Page = 1,
    [ValidateSet(0, 16, 32, 64, 80)]
    [int]$Quality = 0,
    [string]$Crop = "",
    [double]$Zoom = 1,
    [string]$OutDir = ".\frames",
    [string]$CredFile = "",
    [string]$Sessdata = "",
    [switch]$NoCache,
    [switch]$Json
)

# 外部程序（ffmpeg）会往 stderr 写日志，Stop 模式会把它当致命错误；致命错误统一用 throw。
$ErrorActionPreference = 'Continue'

# 兼容 powershell -File 传参：逗号不会被拆成数组
$At = @($At | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($At.Count -eq 0) { throw "没有提供有效的时间点" }

$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

# ---------------------------------------------------------------- 工具函数
function ConvertTo-Seconds {
    param([string]$Text)
    $t = $Text.Trim()
    if ($t -match '^(\d+):(\d{1,2}):(\d{1,2})$') { return [int]$matches[1]*3600 + [int]$matches[2]*60 + [int]$matches[3] }
    if ($t -match '^(\d+):(\d{1,2})$')            { return [int]$matches[1]*60 + [int]$matches[2] }
    if ($t -match '^\d+(\.\d+)?$')                { return [int][double]$t }
    throw "无法解析时间点: '$Text'（支持 750 / 12:30 / 1:02:30）"
}

function Format-Time {
    param([int]$Seconds)
    $h = [math]::Floor($Seconds/3600); $m = [math]::Floor(($Seconds%3600)/60); $s = $Seconds%60
    if ($h -gt 0) { return "{0}:{1:00}:{2:00}" -f $h,$m,$s }
    return "{0:00}:{1:00}" -f $m,$s
}

# 关键：不能用 -Headers 传 Cookie。PowerShell/.NET 会把它当受限头并解析，
# 而 SESSDATA 里含 %2C，会被当成分隔符截断 → 登录态失效。
# 改用 WebSession + Cookie 对象，值原样保留。
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

# ---------------------------------------------------------------- 登录态
$cookieStr = ""
$usingLogin = $false
if ($Sessdata) {
    $cookieStr = "SESSDATA=$Sessdata"
    $usingLogin = $true
} else {
    if (-not $CredFile) { $CredFile = Join-Path $env:USERPROFILE ".dsh\bili-watch\credential.json" }
    if (Test-Path $CredFile) {
        try {
            $c = Get-Content $CredFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $parts = @()
            if ($c.sessdata) { $parts += "SESSDATA=$($c.sessdata)" }
            if ($c.bili_jct) { $parts += "bili_jct=$($c.bili_jct)" }
            if ($c.buvid3)   { $parts += "buvid3=$($c.buvid3)" }
            if ($parts.Count -gt 0) { $cookieStr = $parts -join '; '; $usingLogin = $true }
        } catch { }
    }
}

# ---------------------------------------------------------------- 解析 BV
if ($Video -notmatch '(BV[0-9A-Za-z]{10})') { throw "无法从 '$Video' 中解析出 BV 号" }
$bvid = $matches[1]
$referer = "https://www.bilibili.com/video/$bvid"

# ---------------------------------------------------------------- 元数据
$view = Invoke-BiliApi -Url "https://api.bilibili.com/x/web-interface/view?bvid=$bvid" -Cookie $cookieStr -Referer $referer
if ($view.code -ne 0) { throw "B 站返回错误 code=$($view.code): $($view.message)" }

$totalPages = $view.data.videos
if ($Page -lt 1 -or $Page -gt $totalPages) {
    throw "分 P 超出范围：该视频共 $totalPages P，你请求的是 P$Page"
}
$pageInfo = $view.data.pages[$Page - 1]
$cid = $pageInfo.cid
$pageDuration = $pageInfo.duration

# ---------------------------------------------------------------- 播放地址
if ($Quality -eq 0) { $Quality = if ($usingLogin) { 80 } else { 32 } }
$playUrlApi = "https://api.bilibili.com/x/player/playurl?bvid=$bvid&cid=$cid&qn=$Quality&fnval=16&fnver=0&fourk=1"
$play = Invoke-BiliApi -Url $playUrlApi -Cookie $cookieStr -Referer $referer
if ($play.code -ne 0) { throw "取播放地址失败 code=$($play.code): $($play.message)" }
if (-not $play.data.dash) { throw "该视频没有 DASH 流（番剧/直播/互动视频不支持）" }

$tracks = $play.data.dash.video
# 优先 avc1，其次 hev1；同编码取最高清晰度
$track = $tracks | Where-Object { $_.codecs -like 'avc1*' } | Sort-Object { [int]$_.id } -Descending | Select-Object -First 1
if (-not $track) { $track = $tracks | Sort-Object { [int]$_.id } -Descending | Select-Object -First 1 }

$srcW = [int]$track.width
$srcH = [int]$track.height

$urlList = @($track.baseUrl) + @($track.backupUrl) | Where-Object { $_ } | Select-Object -Unique
if ($urlList.Count -eq 0) { throw "没有拿到可用的播放地址" }

# ---------------------------------------------------------------- 裁剪参数
$vf = ""
$outW = $srcW
$outH = $srcH
if ($Crop) {
    $parts = $Crop -split ',' | ForEach-Object { $_.Trim() }
    if ($parts.Count -ne 4) { throw "-Crop 需要 4 个值：left,top,right,bottom（像素）" }
    $l = [int]$parts[0]; $t = [int]$parts[1]; $r = [int]$parts[2]; $b = [int]$parts[3]
    if ($l -lt 0 -or $t -lt 0 -or $r -lt 0 -or $b -lt 0) { throw "-Crop 的值不能为负" }
    if (($l + $r) -ge $srcW) { throw "左右裁剪过多：源宽 $srcW，裁掉 $l+$r" }
    if (($t + $b) -ge $srcH) { throw "上下裁剪过多：源高 $srcH，裁掉 $t+$b" }
    $cw = $srcW - $l - $r
    $ch = $srcH - $t - $b
    # crop 要求偶数宽高，避免编码器报错
    if ($cw % 2 -ne 0) { $cw -= 1 }
    if ($ch % 2 -ne 0) { $ch -= 1 }
    $vf = "crop=$cw`:$ch`:$l`:$t"
    $outW = $cw; $outH = $ch
}
if ($Zoom -ne 1) {
    if ($Zoom -lt 0.1 -or $Zoom -gt 4) { throw "-Zoom 取值范围 0.1 ~ 4" }
    # 强制偶数宽高：JPEG/ffmpeg 对奇数尺寸不友好
    $zf = "scale=trunc(iw*$Zoom/2)*2:trunc(ih*$Zoom/2)*2:flags=lanczos"
    $vf = if ($vf) { "$vf,$zf" } else { $zf }
    $outW = [int]([math]::Floor($outW * $Zoom / 2) * 2)
    $outH = [int]([math]::Floor($outH * $Zoom / 2) * 2)
}

if (-not $Json) {
    Write-Host ("视频: {0}" -f $view.data.title) -ForegroundColor Cyan
    Write-Host ("P{0}/{1}  {2}  时长 {3}" -f $Page, $totalPages, $pageInfo.part, (Format-Time $pageDuration)) -ForegroundColor Cyan
    $loginTag = if ($usingLogin) { "已登录" } else { "匿名" }
    Write-Host ("画质: {0}x{1}  编码 {2}  [{3}, qn={4}]" -f $srcW, $srcH, $track.codecs, $loginTag, $Quality) -ForegroundColor DarkGray
    if ($Crop -or $Zoom -ne 1) {
        Write-Host ("输出: {0}x{1}  (裁剪 '{2}'  放大 x{3})" -f $outW, $outH, $Crop, $Zoom) -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------- 输出目录
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path

# ---------------------------------------------------------------- 抽帧
$results = @()
$ffHeaders = "Referer: $referer`r`nUser-Agent: $UA`r`n"

foreach ($raw in $At) {
    $sec = ConvertTo-Seconds -Text $raw

    if ($sec -ge $pageDuration) {
        Write-Warning "时间点 $raw (${sec}s) 超出 P$Page 时长 $(Format-Time $pageDuration)，跳过。多 P 视频请用 -Page 指定正确分 P。"
        continue
    }

    $label = Format-Time $sec
    $suffix = ""
    if ($Crop) { $suffix += "_crop" }
    if ($Zoom -ne 1) { $suffix += "_x$Zoom" }
    $file = Join-Path $OutDir ("{0}_P{1}_{2}s{3}.jpg" -f $bvid, $Page, $sec, $suffix)

    # 抽帧：先查缓存，未命中再走 CDN 轮换重试
    $ok = $false
    $cacheHit = $false
    $cachePath = $null
    if (-not $NoCache) {
        $cacheDir = Join-Path $env:USERPROFILE ".dsh\bili-watch\cache\bframe"
        if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }
        $cachePath = Join-Path $cacheDir ("{0}_P{1}_{2}s{3}_q{4}.jpg" -f $bvid, $Page, $sec, $suffix, $Quality)
        if ((Test-Path $cachePath) -and ((Get-Item $cachePath -ErrorAction SilentlyContinue).Length -gt 0)) {
            Copy-Item $cachePath $file -Force
            $ok = $true
            $cacheHit = $true
        }
    }

    if (-not $ok) {
        $maxTry = [Math]::Max(3, $urlList.Count)
        for ($attempt = 1; $attempt -le $maxTry; $attempt++) {
            $tryUrl = $urlList[($attempt - 1) % $urlList.Count]
            if (Test-Path $file) { Remove-Item $file -Force -ErrorAction SilentlyContinue }

            $ffArgs = @('-y', '-loglevel', 'error', '-headers', $ffHeaders, '-ss', $sec, '-i', $tryUrl, '-frames:v', '1')
            if ($vf) { $ffArgs += @('-vf', $vf) }
            $ffArgs += @('-q:v', '2', $file)

            & ffmpeg @ffArgs 2>&1 | Out-Null
            if ((Test-Path $file) -and ((Get-Item $file -ErrorAction SilentlyContinue).Length -gt 0)) { $ok = $true; break }
            if ($attempt -lt $maxTry) { Start-Sleep -Milliseconds 1200 }
        }
        if ($ok -and $cachePath) {
            try { Copy-Item $file $cachePath -Force -ErrorAction Stop } catch { }
        }
    }

    $link = "https://www.bilibili.com/video/${bvid}?p=$Page&t=$sec"

    if ($ok) {
        $kb = [math]::Round((Get-Item $file).Length / 1KB)
        if (-not $Json) {
            Write-Host ("[OK]   {0,8}  ->  {1}  ({2} KB)" -f $label, $file, $kb) -ForegroundColor Green
            Write-Host ("       回看: {0}" -f $link) -ForegroundColor DarkGray
        }
        $results += [pscustomobject]@{
            time=$label; sec=$sec; file=$file; kb=$kb; link=$link
            bvid=$bvid; page=$Page; title=$view.data.title; part=$pageInfo.part
            width=$outW; height=$outH; loggedIn=$usingLogin; cacheHit=$cacheHit; ok=$true
        }
    } else {
        if (-not $Json) { Write-Host ("[FAIL] {0}" -f $label) -ForegroundColor Red }
        $results += [pscustomobject]@{
            time=$label; sec=$sec; file=$file; kb=0; link=$link
            bvid=$bvid; page=$Page; title=$view.data.title; part=$pageInfo.part
            width=$outW; height=$outH; loggedIn=$usingLogin; ok=$false
        }
    }
}

if ($Json) {
    # 注意：不能用 @($results) | ConvertTo-Json —— 管道会把数组展开成多段 JSON。
    ConvertTo-Json -InputObject @($results) -Depth 4
} else {
    Write-Host ("`n共 {0} 个时间点，成功 {1} 个" -f $At.Count, @($results | Where-Object ok).Count) -ForegroundColor Cyan
    if ($Crop) {
        $px = [math]::Round(($outW * $outH) / ($srcW * $srcH) * 100)
        Write-Host ("裁剪后像素保留 {0}%（{1}x{2} vs {3}x{4}）" -f $px, $outW, $outH, $srcW, $srcH) -ForegroundColor DarkGray
    }
}

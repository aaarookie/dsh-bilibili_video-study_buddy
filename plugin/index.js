/**
 * dsh-study-buddy —— B 站网课伴学
 *
 * 给 DSH 模型四个工具，把「看一节课」拆成可组合的原子动作：
 *   study_frame  按时间点抽帧（登录态 1080P、裁剪、放大、缓存）
 *   study_scan   区间扫描：N 帧拼成一张小图，用来定位
 *   study_subs   AI 字幕提取 + 串台检测（B 站字幕会返回别的视频的文稿）
 *   study_asr    局部转写（默认带前 60s 铺垫 + 后 30s 延续）
 *
 * 设计原则：
 *   - 纯 Node，不依赖 PowerShell，Windows/macOS/Linux 通用
 *   - 只读：只用登录态取流和字幕，不点赞、不评论
 *   - 大图不大方：抽帧默认裁剪、扫描默认缩格子，token 花在刀刃上
 *   - 不猜：时间点越界、字幕可疑、依赖缺失，都明确报错而不是静默降级
 */
import { execFile } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync, copyFileSync, statSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname, resolve, basename } from 'node:path'
import { fileURLToPath } from 'node:url'

let defineTool = null
try {
  ({ defineTool } = await import('@deepseek-ai/dsh-tools'))
} catch {
  defineTool = null
}

const HERE = dirname(fileURLToPath(import.meta.url))
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

// ------------------------------------------------------------------ 通用小工具
function parseTime(text) {
  const t = String(text).trim()
  let m
  if ((m = t.match(/^(\d+):(\d{1,2}):(\d{1,2})$/))) return Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3])
  if ((m = t.match(/^(\d+):(\d{1,2})$/))) return Number(m[1]) * 60 + Number(m[2])
  if (/^\d+(\.\d+)?$/.test(t)) return Math.floor(Number(t))
  throw new Error(`无法解析时间: '${text}'（支持 750 / 12:30 / 1:02:30）`)
}

function fmtTime(sec) {
  const s = Math.max(0, Math.round(sec))
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const ss = s % 60
  const pad = (n) => String(n).padStart(2, '0')
  return h > 0 ? `${h}:${pad(m)}:${pad(ss)}` : `${pad(m)}:${pad(ss)}`
}

function bvOf(input) {
  const m = String(input).match(/(BV[0-9A-Za-z]{10})/)
  if (!m) throw new Error(`无法从 '${input}' 解析出 BV 号`)
  return m[1]
}

function sh(cmd, args, opts = {}) {
  return new Promise((resolvePromise, rejectPromise) => {
    execFile(cmd, args, { windowsHide: true, maxBuffer: 32 * 1024 * 1024, ...opts }, (err, stdout, stderr) => {
      if (err) {
        const msg = String(stderr || err.message || '').trim().split('\n').slice(-3).join(' | ')
        return rejectPromise(new Error(`${cmd} 失败: ${msg}`))
      }
      resolvePromise({ stdout, stderr })
    })
  })
}

// ------------------------------------------------------------------ 凭证
function dshHome() {
  return process.env.DSH_HOME || join(homedir(), '.dsh')
}

function credentialCandidates(config) {
  const list = []
  if (config?.credentialFile) list.push(config.credentialFile)
  if (process.env.BILI_WATCH_CRED) list.push(process.env.BILI_WATCH_CRED)
  list.push(join(dshHome(), 'bili-watch', 'credential.json'))
  list.push(join(homedir(), '.dsh', 'bili-watch', 'credential.json'))
  return [...new Set(list)]
}

function loadCookie(config) {
  if (process.env.SESSDATA) return { cookie: `SESSDATA=${process.env.SESSDATA}`, source: 'env:SESSDATA' }
  for (const p of credentialCandidates(config)) {
    try {
      if (!existsSync(p)) continue
      const j = JSON.parse(readFileSync(p, 'utf8'))
      const parts = []
      if (j.sessdata) parts.push(`SESSDATA=${j.sessdata}`)
      if (j.bili_jct) parts.push(`bili_jct=${j.bili_jct}`)
      if (j.buvid3) parts.push(`buvid3=${j.buvid3}`)
      if (parts.length) return { cookie: parts.join('; '), source: p }
    } catch { /* 继续找下一个 */ }
  }
  return { cookie: '', source: null }
}

// ------------------------------------------------------------------ B 站 API
async function biliApi(url, cookie, referer) {
  const headers = { 'User-Agent': UA, Referer: referer || 'https://www.bilibili.com/' }
  // 关键：Cookie 原样放进 header，不要走 CookieJar —— SESSDATA 含 %2C，会被当分隔符截断
  if (cookie) headers.Cookie = cookie
  const res = await fetch(url, { headers, signal: AbortSignal.timeout(25000) })
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`)
  return await res.json()
}

async function getView(bvid, cookie) {
  const referer = `https://www.bilibili.com/video/${bvid}`
  const j = await biliApi(`https://api.bilibili.com/x/web-interface/view?bvid=${bvid}`, cookie, referer)
  if (j.code !== 0) throw new Error(`B 站返回 code=${j.code}: ${j.message}`)
  return { data: j.data, referer }
}

async function getPlayUrl(bvid, cid, qn, cookie, referer) {
  const j = await biliApi(
    `https://api.bilibili.com/x/player/playurl?bvid=${bvid}&cid=${cid}&qn=${qn}&fnval=16&fnver=0&fourk=1`,
    cookie, referer)
  if (j.code !== 0) throw new Error(`取播放地址失败 code=${j.code}: ${j.message}`)
  if (!j.data?.dash) throw new Error('该视频没有 DASH 流（番剧/直播/互动视频不支持）')
  return j.data
}

// ------------------------------------------------------------------ ffmpeg
function ffmpegPath(config) {
  const cands = [config?.ffmpeg, process.env.BILI_WATCH_FFMPEG, process.env.FFMPEG_PATH].filter(Boolean)
  for (const c of cands) if (existsSync(c)) return c
  return 'ffmpeg' // 交给 PATH
}

function ffHeaders(referer, cookie) {
  let h = `Referer: ${referer}\r\nUser-Agent: ${UA}\r\n`
  if (cookie) h += `Cookie: ${cookie}\r\n`
  return h
}

function parseCrop(spec, srcW, srcH) {
  if (!spec) return null
  const parts = String(spec).split(',').map((s) => s.trim())
  if (parts.length !== 4) throw new Error('-crop 需要 4 个值：left,top,right,bottom（像素）')
  const [l, t, r, b] = parts.map((v) => {
    const n = Number(v)
    if (!Number.isFinite(n) || n < 0) throw new Error(`crop 值必须是非负数字: '${v}'`)
    return Math.floor(n)
  })
  if (l + r >= srcW) throw new Error(`左右裁剪过多：源宽 ${srcW}，裁掉 ${l}+${r}`)
  if (t + b >= srcH) throw new Error(`上下裁剪过多：源高 ${srcH}，裁掉 ${t}+${b}`)
  let w = srcW - l - r
  let h = srcH - t - b
  if (w % 2) w -= 1
  if (h % 2) h -= 1
  return { filter: `crop=${w}:${h}:${l}:${t}`, width: w, height: h }
}

function resolveCacheDir() {
  const dir = join(dshHome(), 'bili-watch', 'cache', 'study-buddy')
  mkdirSync(dir, { recursive: true })
  return dir
}

// ------------------------------------------------------------------ 工具：抽帧
async function doFrame(args, config) {
  const bvid = bvOf(args.video)
  const page = Number(args.page ?? 1)
  const cred = loadCookie(config)
  const { data: view, referer } = await getView(bvid, cred.cookie)

  if (page < 1 || page > view.videos) throw new Error(`分 P 超出范围：该视频共 ${view.videos} P`)
  const pageInfo = view.pages[page - 1]
  const pageDur = Number(pageInfo.duration)

  const atList = Array.isArray(args.at) ? args.at : String(args.at).split(',')
  const points = atList.map((s) => s.trim()).filter(Boolean).map((s) => ({ raw: s, sec: parseTime(s) }))
  if (!points.length) throw new Error('至少给一个时间点')

  const qn = Number(args.quality ?? 0) || (cred.cookie ? 80 : 32)
  const play = await getPlayUrl(bvid, pageInfo.cid, qn, cred.cookie, referer)

  const tracks = play.video || []
  const track = tracks.filter((t) => /^avc1/i.test(t.codecs || '')).sort((a, b) => Number(b.id) - Number(a.id))[0]
    || tracks.sort((a, b) => Number(b.id) - Number(a.id))[0]
  if (!track) throw new Error('没有可用的视频轨')

  const srcW = Number(track.width)
  const srcH = Number(track.height)
  const crop = parseCrop(args.crop, srcW, srcH)

  let vf = crop?.filter || ''
  let outW = crop?.width ?? srcW
  let outH = crop?.height ?? srcH
  const zoom = Number(args.zoom ?? 1)
  if (zoom !== 1) {
    if (zoom < 0.1 || zoom > 4) throw new Error('zoom 取值范围 0.1 ~ 4')
    const zf = `scale=trunc(iw*${zoom}/2)*2:trunc(ih*${zoom}/2)*2:flags=lanczos`
    vf = vf ? `${vf},${zf}` : zf
    outW = Math.floor((outW * zoom) / 2) * 2
    outH = Math.floor((outH * zoom) / 2) * 2
  }

  const outDir = resolve(args.outDir || join(process.cwd(), 'study-frames'))
  mkdirSync(outDir, { recursive: true })
  const cacheDir = resolveCacheDir()
  const suffix = `${crop ? '_crop' : ''}${zoom !== 1 ? `_x${zoom}` : ''}`
  const urls = [track.baseUrl, ...(track.backupUrl || [])].filter(Boolean)
  const fh = ffHeaders(referer, cred.cookie)
  const ff = ffmpegPath(config)

  const results = []
  for (const pt of points) {
    if (pt.sec >= pageDur) {
      results.push({ time: fmtTime(pt.sec), ok: false, error: `超出 P${page} 时长 ${fmtTime(pageDur)}，多 P 视频请检查 page` })
      continue
    }
    const file = join(outDir, `${bvid}_P${page}_${pt.sec}s${suffix}.jpg`)
    const cacheKey = join(cacheDir, `${bvid}_P${page}_${pt.sec}s${suffix}_q${qn}.jpg`)
    let fromCache = false
    try {
      if (existsSync(cacheKey) && statSync(cacheKey).size > 0) {
        copyFileSync(cacheKey, file)
        fromCache = true
      }
    } catch { /* 缓存坏了就重新抽 */ }

    if (!fromCache) {
      let ok = false
      const maxTry = Math.max(3, urls.length)
      for (let attempt = 0; attempt < maxTry; attempt++) {
        const u = urls[attempt % urls.length]
        const ffArgs = ['-y', '-loglevel', 'error', '-headers', fh, '-ss', String(pt.sec), '-i', u, '-frames:v', '1']
        if (vf) ffArgs.push('-vf', vf)
        ffArgs.push('-q:v', '2', file)
        try {
          await sh(ff, ffArgs)
          if (existsSync(file) && statSync(file).size > 0) { ok = true; break }
        } catch { /* 换下一个 CDN */ }
        await new Promise((r) => setTimeout(r, 1200))
      }
      if (ok) { try { copyFileSync(file, cacheKey) } catch { /* 缓存写失败不影响结果 */ } }
      if (!ok) {
        results.push({ time: fmtTime(pt.sec), ok: false, error: '抽帧失败（CDN 多次重试后仍失败）' })
        continue
      }
    }
    results.push({
      time: fmtTime(pt.sec),
      sec: pt.sec,
      ok: true,
      file,
      kb: Math.round(statSync(file).size / 1024),
      link: `https://www.bilibili.com/video/${bvid}?p=${page}&t=${pt.sec}`,
      fromCache,
    })
  }

  const okCount = results.filter((r) => r.ok).length
  const lines = [
    `视频：${view.title}`,
    `P${page}/${view.videos}  ${pageInfo.part}  时长 ${fmtTime(pageDur)}`,
    `画质：${srcW}x${srcH} [${cred.cookie ? '已登录' : '匿名'}, qn=${qn}]${crop ? ` → 裁剪 ${outW}x${outH}` : ''}${zoom !== 1 ? ` → 放大 x${zoom}` : ''}`,
    '',
  ]
  for (const r of results) {
    if (r.ok) {
      lines.push(`[OK] ${r.time} → ${r.file} (${r.kb} KB)${r.fromCache ? ' [缓存]' : ''}`)
      lines.push(`     回看 ${r.link}`)
    } else {
      lines.push(`[FAIL] ${r.time}  ${r.error}`)
    }
  }
  lines.push('', `共 ${results.length} 个时间点，成功 ${okCount} 个`)
  return lines.join('\n')
}

// ------------------------------------------------------------------ 工具：区间扫描
async function doScan(args, config) {
  const bvid = bvOf(args.video)
  const page = Number(args.page ?? 1)
  const fromSec = parseTime(args.from)
  const toSec = parseTime(args.to)
  if (toSec <= fromSec) throw new Error('to 必须大于 from')

  const count = Math.min(Math.max(Number(args.count ?? 6), 2), 12)
  const step = (toSec - fromSec) / (count - 1)
  const points = Array.from({ length: count }, (_, i) => Math.round(fromSec + step * i))
  const times = points.map((s) => fmtTime(s))

  const outDir = resolve(args.outDir || join(process.cwd(), 'study-scan'))
  mkdirSync(outDir, { recursive: true })
  const framesDir = join(outDir, 'frames')

  // 复用 doFrame：一次抽完所有点
  const frameOut = await doFrame(
    { video: bvid, page, at: times.join(','), crop: args.crop, quality: args.quality, outDir: framesDir },
    config)
  const frameRe = /\[OK\] (\d{1,2}:\d{2}(?::\d{2})?) → (.+?) \((\d+) KB\)/g
  const frames = []
  let m
  while ((m = frameRe.exec(frameOut))) frames.push({ time: m[1], file: m[2] })
  if (!frames.length) return `扫描失败：一帧都没抽到\n\n${frameOut}`

  // 缩格子 + 烧编号
  const cellW = Math.min(Math.max(Number(args.cellWidth ?? 400), 200), 900)
  const ff = ffmpegPath(config)
  const cells = []
  for (let i = 0; i < frames.length; i++) {
    const num = String(i + 1).padStart(2, '0')
    const cell = join(outDir, `cell_${num}.jpg`)
    const label = `${num} ${frames[i].time}`.replace(/:/g, '\\:')
    const fs = Math.max(14, Math.round(cellW / 20))
    const filter = `scale=${cellW}:-2,drawtext=fontfile='C\\:/Windows/Fonts/msyh.ttc':text='${label}':fontsize=${fs}:fontcolor=yellow:box=1:boxcolor=black@0.65:boxborderw=6:x=8:y=8`
    try {
      await sh(ff, ['-y', '-loglevel', 'error', '-i', frames[i].file, '-vf', filter, '-q:v', '3', cell])
    } catch {
      // drawtext 不可用时退化为纯缩放（不影响定位，只是没编号）
      try { await sh(ff, ['-y', '-loglevel', 'error', '-i', frames[i].file, '-vf', `scale=${cellW}:-2`, '-q:v', '3', cell]) } catch { }
    }
    if (existsSync(cell)) cells.push({ ...frames[i], cell, num })
  }
  if (!cells.length) return `扫描失败：缩格子全部失败\n\n${frameOut}`

  // 拼图
  const cols = cells.length <= 4 ? 2 : cells.length <= 9 ? 3 : 4
  const rows = Math.ceil(cells.length / cols)
  const seqDir = join(outDir, '_seq')
  mkdirSync(seqDir, { recursive: true })
  cells.forEach((c, i) => copyFileSync(c.cell, join(seqDir, `s${String(i + 1).padStart(2, '0')}.jpg`)))
  const grid = join(outDir, 'grid.jpg')
  try {
    await sh(ff, ['-y', '-loglevel', 'error', '-framerate', '1', '-i', join(seqDir, 's%02d.jpg'),
      '-vf', `tile=${cols}x${rows}:padding=6:margin=6`, '-frames:v', '1', '-q:v', '3', grid])
  } catch { /* 拼图失败保留逐格 */ }

  const manifest = {
    video: bvid, page, range: `${args.from} ~ ${args.to}`, count: cells.length,
    grid: existsSync(grid) ? grid : null,
    cells: cells.map((c) => ({ num: c.num, time: c.time, original: c.file, cell: c.cell })),
  }
  writeFileSync(join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 1), 'utf8')

  const lines = [
    `扫描 ${args.from} ~ ${args.to}，${cells.length} 帧，每格 ${cellW}px`,
    `拼图：${existsSync(grid) ? grid : '（拼图失败，见 cell_*.jpg）'}`,
    '',
  ]
  cells.forEach((c) => lines.push(`[${c.num}] ${c.time}  ${c.original}`))
  lines.push('', `原图目录：${framesDir}`, `清单：${join(outDir, 'manifest.json')}`)
  return lines.join('\n')
}

// ------------------------------------------------------------------ 工具：字幕 + 串台检测
async function doSubs(args, config) {
  const bvid = bvOf(args.video)
  const page = Number(args.page ?? 1)
  const cred = loadCookie(config)
  if (!cred.cookie) return '没有登录凭证，AI 字幕通常取不到。请先在 dsh-bili-watch 扫码，或设置 SESSDATA 环境变量。'

  const { data: view, referer } = await getView(bvid, cred.cookie)
  if (page < 1 || page > view.videos) throw new Error(`分 P 超出范围：共 ${view.videos} P`)
  const pageInfo = view.pages[page - 1]
  const dur = Number(pageInfo.duration)

  const pv = await biliApi(`https://api.bilibili.com/x/player/v2?bvid=${bvid}&cid=${pageInfo.cid}`, cred.cookie, referer)
  const subs = pv?.data?.subtitle?.subtitles || []
  if (!subs.length) {
    return `视频：${view.title}\nP${page} 时长 ${fmtTime(dur)}\n\n[无字幕] 该 P 没有可用字幕轨（真无字幕，或未登录）。\n建议改用 study_asr 做局部转写。`
  }

  const track = subs[0]
  let url = track.subtitle_url
  if (url.startsWith('//')) url = 'https:' + url
  const body = await biliApi(url, cred.cookie, 'https://www.bilibili.com/')
  const items = body?.body || []
  if (!items.length) return '[无字幕] 字幕正文为空'

  // 串台检测：三个独立信号
  const last = Math.max(...items.map((i) => Number(i.from)))
  const coverage = dur > 0 ? last / dur : 0
  const avgDur = items.reduce((s, i) => s + (Number(i.to) - Number(i.from)), 0) / items.length

  const stop = new Set(['the', 'and', 'for', 'with', 'from', 'into', 'your', 'this', 'that', 'are', 'you', 'can', 'not', 'but', 'all', 'out', 'one', 'two', 'how', 'why', 'what', 'when', 'will', 'has', 'have', 'was', 'were', 'they', 'them', 'its', 'his', 'her', 'our', 'their'])
  const terms = [...new Set(`${view.title} ${pageInfo.part}`.match(/[A-Za-z][A-Za-z0-9]{2,}/g) || [])]
    .map((s) => s.toLowerCase()).filter((s) => !stop.has(s))
  const allText = items.map((i) => i.content).join(' ')
  const hit = terms.filter((t) => allText.includes(t))
  const hitRate = terms.length ? hit.length / terms.length : 1

  const issues = []
  let level = 'PASS'
  if (coverage < 0.5) { issues.push(`字幕只覆盖到 ${fmtTime(last)}（视频 ${fmtTime(dur)}），覆盖度 ${(coverage * 100).toFixed(0)}% —— 极可能串台`); level = 'FAIL' }
  else if (coverage < 0.8) { issues.push(`覆盖度偏低：${(coverage * 100).toFixed(0)}%`); level = 'WARN' }
  if (terms.length >= 3 && hit.length === 0) { issues.push(`标题英文术语一个都没出现在字幕里（${terms.slice(0, 6).join(', ')}）—— 内容对不上`); level = 'FAIL' }
  else if (terms.length >= 3 && hitRate < 0.25) { issues.push(`标题术语命中率仅 ${(hitRate * 100).toFixed(0)}%`); if (level === 'PASS') level = 'WARN' }
  if (avgDur < 0.5 || avgDur > 8) { issues.push(`平均每条字幕 ${avgDur.toFixed(1)} 秒，语速异常`); if (level === 'PASS') level = 'WARN' }

  const head = [
    `视频：${view.title}`,
    `P${page}  ${pageInfo.part}  时长 ${fmtTime(dur)}`,
    `字幕：${items.length} 条 | ${track.lan_doc || track.lan} | 覆盖到 ${fmtTime(last)}`,
    '',
    `[检测] ${level}`,
    ...(issues.length ? issues.map((s) => `  - ${s}`) : ['  - 覆盖度、术语命中、语速均正常']),
    `  覆盖度 ${(coverage * 100).toFixed(0)}% | 术语命中 ${hit.length}/${terms.length} | 平均每条 ${avgDur.toFixed(1)}s`,
    '',
  ]

  if (level === 'FAIL' && !args.force) {
    head.push('[拒绝输出] 判定为串台。确认要人工核对就传 force=true。样例前 3 条：')
    items.slice(0, 3).forEach((i) => head.push(`  [${fmtTime(Number(i.from))}] ${i.content}`))
    return head.join('\n')
  }

  const fmt = String(args.format || 'md')
  const outDir = resolve(args.outDir || join(process.cwd(), 'study-subs'))
  mkdirSync(outDir, { recursive: true })
  const base = join(outDir, `${bvid}_P${page}_${track.lan || 'sub'}`)
  let content = ''
  if (fmt === 'srt') {
    content = items.map((i, idx) => {
      const t = (s) => {
        const x = Number(s); const h = Math.floor(x / 3600); const m2 = Math.floor((x % 3600) / 60); const ss = (x % 60).toFixed(3).padStart(6, '0')
        return `${String(h).padStart(2, '0')}:${String(m2).padStart(2, '0')}:${ss.replace('.', ',')}`
      }
      return `${idx + 1}\n${t(i.from)} --> ${t(i.to)}\n${i.content}\n`
    }).join('\n')
  } else if (fmt === 'txt') {
    content = items.map((i) => i.content).join('\n')
  } else {
    content = [`# ${view.title} · P${page}`, '', `> 来源：B 站 AI 字幕 ｜ ${referer} ｜ 检测 ${level}`, '']
      .concat(items.map((i) => `[${fmtTime(Number(i.from))}] ${i.content}`)).join('\n')
  }
  const file = `${base}.${fmt}`
  writeFileSync(file, content, 'utf8')

  head.push(`[OK] ${file}（${items.length} 条）`)
  return head.join('\n')
}

// ------------------------------------------------------------------ 工具：局部转写
function asrEnv(config) {
  const py = config?.python || process.env.BILI_WATCH_PYTHON
    || join(dshHome(), 'bili-watch', 'deps', '.venv-asr', 'Scripts', 'python.exe')
  const pyUnix = join(dshHome(), 'bili-watch', 'deps', '.venv-asr', 'bin', 'python')
  const python = py && existsSync(py) ? py : existsSync(pyUnix) ? pyUnix : null
  const modelRoot = join(dshHome(), 'bili-watch', 'deps', '.hf-home', 'hub', 'models--Systran--faster-whisper-small', 'snapshots')
  return { python, modelRoot }
}

async function doAsr(args, config) {
  const { python, modelRoot } = asrEnv(config)
  if (!python) {
    return [
      '没有找到 faster-whisper 环境。study_asr 需要：',
      '  1. Python 3.10–3.14',
      '  2. pip install faster-whisper',
      '  3. 一个模型目录（可用 -model 指定）',
      '',
      '临时替代：直接读画面（study_frame）比硬转写更可靠，代码/公式以画面为准。',
    ].join('\n')
  }
  if (!existsSync(modelRoot)) return `没有找到 faster-whisper 模型：${modelRoot}\n请先运行一次模型下载，或用环境变量指定。`

  const { readdirSync } = await import('node:fs')
  const snapshots = readdirSync(modelRoot).filter((n) => !n.startsWith('.'))
  if (!snapshots.length) return `模型目录为空：${modelRoot}`
  const model = args.model || join(modelRoot, snapshots[0])

  const bvid = bvOf(args.video)
  const page = Number(args.page ?? 1)
  const cred = loadCookie(config)
  const { data: view, referer } = await getView(bvid, cred.cookie)
  if (page < 1 || page > view.videos) throw new Error(`分 P 超出范围：共 ${view.videos} P`)
  const pageInfo = view.pages[page - 1]
  const pageDur = Number(pageInfo.duration)

  let fromSec, toSec, pointMode = false, atSec = 0
  if (args.at) {
    pointMode = true
    atSec = parseTime(args.at)
    const pre = Number(args.pre ?? 60)
    const post = Number(args.post ?? 30)
    fromSec = Math.max(0, atSec - pre)
    toSec = Math.min(pageDur, atSec + post)
  } else if (args.from && args.to) {
    fromSec = parseTime(args.from)
    toSec = Math.min(pageDur, parseTime(args.to))
  } else {
    throw new Error('要么给 at，要么同时给 from 和 to')
  }
  if (toSec <= fromSec) throw new Error('结束时间必须大于开始时间')

  const play = await getPlayUrl(bvid, pageInfo.cid, 32, cred.cookie, referer)
  const audio = (play.audio || []).sort((a, b) => Number(b.id) - Number(a.id))[0]
  if (!audio) throw new Error('取不到音频轨')

  const outDir = resolve(args.outDir || join(process.cwd(), 'study-asr'))
  mkdirSync(outDir, { recursive: true })
  const tag = `${bvid}_P${page}_${Math.round(fromSec)}s-${Math.round(toSec)}s`
  const wav = join(outDir, `${tag}.wav`)

  await sh(ffmpegPath(config), ['-y', '-loglevel', 'error', '-headers', ffHeaders(referer, cred.cookie),
    '-ss', String(fromSec), '-t', String(toSec - fromSec), '-i', audio.baseUrl,
    '-vn', '-ac', '1', '-ar', '16000', wav])

  // 调 python 转写
  const helper = join(HERE, 'lib', 'asr.py')
  const jsonOut = join(outDir, `${tag}.json`)
  const lang = args.lang || 'auto'
  await sh(python, [helper, wav, '--model', model, '--lang', lang, '--offset', String(fromSec), '--out', jsonOut])

  const result = JSON.parse(readFileSync(jsonOut, 'utf8'))
  const lines = [
    `视频：${view.title}`,
    `P${page}  ${pageInfo.part}`,
    `区间：${fmtTime(fromSec)} ~ ${fmtTime(toSec)}（${Math.round(toSec - fromSec)} 秒）｜ 语言 ${result.lang} ｜ 耗时 ${result.elapsed}s`,
  ]
  if (pointMode) lines.push(`目标点 ${fmtTime(atSec)}（前 ${args.pre ?? 60}s 铺垫 + 后 ${args.post ?? 30}s 延续）`)
  lines.push('')
  for (const it of result.items) {
    const mark = pointMode && it.from <= atSec && it.to >= atSec ? '   <<< 目标点' : ''
    lines.push(`[${fmtTime(it.from)}] ${it.text}${mark}`)
  }
  const mdFile = join(outDir, `${tag}.md`)
  writeFileSync(mdFile, lines.join('\n'), 'utf8')
  lines.push('', `[OK] ${mdFile}`)
  return lines.join('\n')
}

// ------------------------------------------------------------------ 工具描述
const TOOL_DESC_FRAME = '从 B 站视频按时间点抽帧，并把那一秒的回看链接一起给你。用于「讲一下这段代码」「这页幻灯片写了什么」。支持登录态 1080P、局部裁剪（去掉浏览器工具栏/播放器 UI/人脸小窗）、放大、命中缓存。多 P 视频必须给 page。抽完你自己用 read_image 看，不要凭标题猜内容。'

const TOOL_DESC_SCAN = '把一段时间内均匀抽 N 帧、缩成小格子拼成一张图，用来快速判断「这 5 分钟里哪一段是代码/公式/幻灯片」。拼图只够定位、不够读代码；定位到之后再用 frame 抽高清单帧。默认每格 400px，比逐张看省 90% token。'

const TOOL_DESC_SUBS = '取 B 站 AI/CC 字幕，并检测是否「串台」——B 站会返回别的视频的文稿（实测 GPT 课拿到过核能字幕和英文歌词）。用覆盖度、标题术语命中、语速三个信号判定 PASS/WARN/FAIL；FAIL 时默认拒绝输出正文。有正常字幕时它比 ASR 准得多，优先用它。'

const TOOL_DESC_ASR = '只转写视频的一小段，默认带前 60 秒铺垫和后 30 秒延续——裸切 90 秒只能讲清「这段在做什么」，讲不清「这是新概念还是回顾」。需要本机有 faster-whisper。注意 ASR 会系统性听错代码术语（free(p)→4AP、栈上→站上），所以代码一律以画面为准。'

// ------------------------------------------------------------------ 插件入口
export const name = 'dsh-study-buddy'
export const inject = ['tools']

/**
 * defineTool 的 output 是「author-facing spec」：不能写 required（编译期 allowRequired=false），
 * 且必须提供 render —— 少了它 defineTool 内部读 options.output.render 会直接抛。
 */
const TEXT_OUTPUT = {
  schema: {
    type: 'object',
    additionalProperties: false,
    properties: {
      ok: { type: 'boolean', description: '执行是否成功' },
      text: { type: 'string', description: '给模型看的文本' },
    },
  },
  render: (args, value) => {
    const warn = value?.ok === false ? '⚠ 本次调用失败（ok=false），下面是错误信息，不是视频内容。\n' : ''
    return [{ type: 'text', text: warn + String(value?.text ?? '') }]
  },
}

export function apply(ctx, config = {}) {
  const toolsSvc = (() => { try { return ctx.get('tools') } catch { return null } })()
  if (!toolsSvc?.register) {
    try { ctx.logger?.warn?.('[dsh-study-buddy] tools 服务不可用，工具未注册') } catch { }
    return
  }
  if (!defineTool) {
    try { ctx.logger?.warn?.('[dsh-study-buddy] 缺少 @deepseek-ai/dsh-tools，工具未注册') } catch { }
    return
  }

  const wrap = (fn) => async (args) => {
    try { return { ok: true, text: await fn(args || {}, config) } }
    catch (e) { return { ok: false, text: `⚠ 失败：${e?.message || e}` } }
  }

  const disposers = []

  disposers.push(toolsSvc.register(defineTool({
    name: 'study_frame',
    description: TOOL_DESC_FRAME,
    output: TEXT_OUTPUT,
    parameters: {
      video: { type: 'string', required: true, description: 'BV 号或视频链接' },
      at: { type: 'string', required: true, description: '时间点，可多个逗号分隔：12:30 或 750 或 1:02:30' },
      page: { type: 'number', description: '第几个分 P（1 起），默认 1。多 P 视频必须给对' },
      crop: { type: 'string', description: '裁掉四边，格式 left,top,right,bottom（像素）。例：0,150,420,130 去掉顶栏、字幕条、人脸小窗' },
      zoom: { type: 'number', description: '裁剪后放大倍数，默认 1。先裁剪，别急着放大' },
      quality: { type: 'number', description: '清晰度 qn：16=360p 32=480p 64=720p 80=1080p；默认自动（有登录用 80）' },
      outDir: { type: 'string', description: '输出目录，默认 ./study-frames' },
    },
    execute: wrap(doFrame),
  })))

  disposers.push(toolsSvc.register(defineTool({
    name: 'study_scan',
    description: TOOL_DESC_SCAN,
    output: TEXT_OUTPUT,
    parameters: {
      video: { type: 'string', required: true, description: 'BV 号或视频链接' },
      from: { type: 'string', required: true, description: '区间起点，如 28:00' },
      to: { type: 'string', required: true, description: '区间终点，如 33:00' },
      count: { type: 'number', description: '抽几帧，2~12，默认 6' },
      page: { type: 'number', description: '第几个分 P，默认 1' },
      crop: { type: 'string', description: '抽帧时的裁剪参数，同 study_frame' },
      cellWidth: { type: 'number', description: '每格宽度像素，默认 400。越小越省 token，但越看不清' },
      outDir: { type: 'string', description: '输出目录，默认 ./study-scan' },
    },
    execute: wrap(doScan),
  })))

  disposers.push(toolsSvc.register(defineTool({
    name: 'study_subs',
    description: TOOL_DESC_SUBS,
    output: TEXT_OUTPUT,
    parameters: {
      video: { type: 'string', required: true, description: 'BV 号或视频链接' },
      page: { type: 'number', description: '第几个分 P，默认 1' },
      format: { type: 'string', enum: ['md', 'srt', 'txt'], description: '输出格式，默认 md（带时间码）' },
      force: { type: 'boolean', description: '即使判定串台也输出正文（仅用于人工核对）' },
      outDir: { type: 'string', description: '输出目录，默认 ./study-subs' },
    },
    execute: wrap(doSubs),
  })))

  disposers.push(toolsSvc.register(defineTool({
    name: 'study_asr',
    description: TOOL_DESC_ASR,
    output: TEXT_OUTPUT,
    parameters: {
      video: { type: 'string', required: true, description: 'BV 号或视频链接' },
      page: { type: 'number', description: '第几个分 P，默认 1' },
      at: { type: 'string', description: '目标时间点（自动带前后文）；与 from/to 二选一' },
      from: { type: 'string', description: '区间起点' },
      to: { type: 'string', description: '区间终点' },
      pre: { type: 'number', description: 'at 模式往前多取几秒，默认 60' },
      post: { type: 'number', description: 'at 模式往后多取几秒，默认 30' },
      lang: { type: 'string', enum: ['auto', 'zh', 'en', 'ja'], description: '语言，默认 auto' },
      outDir: { type: 'string', description: '输出目录，默认 ./study-asr' },
    },
    execute: wrap(doAsr),
  })))

  try { ctx.effect?.(() => { for (const d of disposers) { try { d?.() } catch { } } }) } catch { }
}

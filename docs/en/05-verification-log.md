# 05 · Measured Verification Log

> This document records real tests run on this machine on 2026-11-13; **anything not tested is stated explicitly**.
> The purpose is to separate "the README says it works" from "it actually works on your machine".

---

## 1. Test environment

| Item | Value |
|---|---|
| OS | Windows (PowerShell 5.1 is the main shell; `pwsh` is not installed) |
| Working directory | `<workspace>` |
| DSH | `0.2.2-rc.1` (source checkout: `E:\deepseekharness\deepseek-harness`) |
| How DSH is started | `node apps/cli/lib/bin.js web --no-open`, listening on `127.0.0.1:3080` |
| profile | `web` (bundles: only `@deepseek-ai/dsh-base` + `@deepseek-ai/dsh-web-app`) |
| Node | `v24.19.0` |
| pnpm / git | both installed (`git 2.55.0.windows.2`) |
| winget | `v1.29.380` available |
| Default model | DeepSeek (only `DEEPSEEK_API_KEY` configured) |

---

## 2. Bilibili anonymous API availability — 4/4 passed ✅

This is the precondition for whether the whole approach can stand. Requests were sent bare, with a browser UA + Referer, directly (through no plugin):

| # | API | Purpose | Result |
|---|---|---|---|
| 1 | `x/web-interface/view` | Metadata (title/UP/duration/parts) | ✅ `code=0` |
| 2 | `x/web-interface/wbi/search/type` | In-site search | ✅ `code=0`, 20 hits |
| 3 | `x/player/videoshot` | Official frame snapshots (used by `peek`, no video download) | ✅ `code=0`, snapshot image retrievable |
| 4 | `x/player/v2` | Subtitle tracks | ⚠️ `code=0` but **subtitle track count = 0** (not logged in) |

**Raw evidence:**

```
1) view      → code=0  title=【官方 MV】Never Gonna Give You Up - Rick Astley
               UP=索尼音乐中国  时长=213s  分P=1
2) search    → code=0  message=OK
               命中 20 条，首条: 王道计算机考研 操作系统
3) videoshot → code=0  message=OK
               快照图数量: 1  图片: //i0.hdslb.com/bfs/videoshot/137649199.jpg
4) player/v2 → code=0
               字幕轨数量: 0
```

**Three conclusions:**

1. **This machine's network can reach the Bilibili API directly**; no proxy is needed. Anonymous access already gets metadata, search, and frame snapshots.
2. **Subtitles require login.** This point decides that once `dsh-bili-watch` is installed, you must scan the QR code (or fill in SESSDATA) before you can get AI subtitles.
3. **Search quality is usable**: searching "操作系统" (operating system) returns 「王道计算机考研 操作系统」 as the first hit — Bilibili really is the main venue for exam-prep/system courses,
   and this ecosystem matches your use case.

> It also verified in passing that `peek`'s "official frame snapshot" path really exists, which means **you can get a few keyframes even without ffmpeg**.

---

## 3. npm package status verified ✅

Checked against the registry one by one, to confirm it is not just README boasting:

| Package | Version | Monthly downloads | engines | Verdict |
|---|---|---:|---|---|
| `dsh-bili-watch` | 0.4.10 | 16,565 | `node >=22` | ✅ Node 24 on this machine satisfies it |
| `dsh-bili-eyes` | 0.8.3 | 3,742 | `node >=20` | ✅ |
| `dsh-bili-study` | 1.0.0 | 404 | `dsh >=0.2.1-rc.5 <0.3.0`; `node >=22.19.0` | ✅ 0.2.2-rc.1 / Node 24.19.0 on this machine satisfies it |
| `dsh-video-understand` | 0.5.2 | 5,241 | `node >=18` | ✅ (but still needs ffmpeg) |
| `dsh-video-storyboard` | 0.7.4 | 34,935 | `node >=20` | ✅ |
| `dsh-bili-subagent` | 0.9.9 | 9,888 | `dsh >=0.2.1-rc.2`; `node >=22` | ✅ (needs Python) |
| `dsh-bili-scroll` | 2.5.2 | 75,121 | `dsh >=0.1.7-rc.1`; `node >=22` | ✅ (but not recommended) |
| `@ericwang1358/dsh-daily-flashcard` | 4.5.1 | — | — | ✅ i.e. `dsh-web-studyhub`; it exists |
| `dsh-bili-summary` | — | — | — | ❌ not on npm; can only use `github:` |
| `dsh-video-coursemap` | — | — | — | ❌ not on npm |
| `bili-vision` | — | — | — | ❌ not on npm |
| `dsh-web-studyhub` | — | — | — | ⚠️ use the scoped package name from the table above |

**Conclusion**: `dsh-bili-watch` / `dsh-bili-eyes` / `dsh-bili-study` can all be `npm add`ed directly,
with no git and no building — the lowest risk when actually adopting them.

---

## 4. Install script self-test ✅

`install.ps1` has actually been run with `-Check` and `-WhatIf`, and the output was normal:

```
[OK]      DSH 入口  E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js
[OK]      DSH 版本  0.2.2-rc.1
[OK]      Node      v24.19.0
[OK]      pnpm      已安装
[OK]      git       已安装
[MISSING] ffmpeg    未安装
[MISSING] Python    只有 Windows 应用商店存根，不是真解释器
```

**One pitfall already fixed**: the script originally read `Test-CommandExists 'ffmpeg' -and (...)`;
PowerShell parsed `-and` as an argument of the function, so `$ffmpegOk` was always true.
It was changed to `(Test-CommandExists 'ffmpeg') -and (...)`, and verified under PS 5.1.

**Another pitfall (encoding)**: this machine has no `pwsh`, only Windows PowerShell 5.1, which reads a **UTF-8 without BOM** `.ps1`
as mojibake. So `install.ps1` is saved as **UTF-8 with BOM**.
(Conversely, **`package.json` in a profile must never carry a BOM**, otherwise DSH crashes on startup — the two requirements are opposite; don't mix them up.)

**How to run it:**

```powershell
cd <repo>
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Check
```

---

## 5. `dsh` CLI availability ✅

`dsh` is not on PATH, but the entry point in the checkout can be invoked normally:

```
node E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js --version
→ 0.2.2-rc.1

node ...\bin.js plugin --help
→ manage a profile's plugins by forwarding the remaining arguments to pnpm
  --profile <name>  the profile whose plugins to manage (initialized on first use)
```

Two notes:
- **`dsh plugin` is only a forwarder to pnpm**, so pnpm is required (it is installed).
- `dsh plugin --profile web list` prints nothing on this machine (pnpm's behavior when not on a TTY);
  to confirm what is installed, reading `dependencies` in `~/.dsh/profiles/web/package.json` is more reliable.

---

## 6. Second round of measurement: environment setup + timestamp frame grabbing ✅

### 6.1 Tool installation results

| Tool | Version | Size | Measured |
|---|---|---|---|
| ffmpeg | `N-92722` (2018 build) | 61.5 MB | ✅ muxing/frame grabbing/libx264 encoding all pass |
| ffprobe | `2023-02-13 essentials` | 77.2 MB | ✅ reads duration and stream info |
| yt-dlp | `2026.10.26` | 22.5 MB | ✅ parses Bilibili metadata (video formats require login) |
| uv | `0.13.8` | 46.4 MB | ✅ `uv python install 3.12` succeeded |
| Python 3.12 | `3.12.16` | 62.1 MB | ✅ for ASR/OCR |
| ASR/OCR venv | — | 404.1 MB | ✅ all four packages import successfully |

**One key tradeoff**: gyan.dev's official source measured only **43 KB/s** (109 MB would take 45 minutes),
so I switched to npm's `@ffmpeg-installer/win32-x64`, which downloaded in **20 seconds**. The price is an old version (2018),
but H.264/HEVC decoding, `-ss` seeking, and JPEG output were all measured working.

### 6.2 About your Python: it was there all along

```
py -0p
  -V:3.14[-64] *   %USERPROFILE%\AppData\Local\Python\pythoncore-3.14-64\python.exe
```

The reason `python --version` reported "not found" is that in PATH,
`WindowsApps` (the Store stub) is listed **before** `AppData\Local\Python\bin` (the real 3.14).
It was not missing; it was shadowed.

3.14 is left untouched; a separate 3.12 venv was created for ASR/OCR, and it was measured installing in one go:

```
faster-whisper 1.2.1 / ctranslate2 4.9.0 / onnxruntime 1.32.0 / cv2 5.0.0
```

### 6.3 Timestamp frame grabbing, full chain ✅

```
Anonymous view API → cid
Anonymous playurl(fnval=16) → 4 DASH video tracks (two tiers each of hev1/avc1)
ffmpeg -ss <seconds> -i <stream URL> -frames:v 1 → jpg
```

Measured timestamps that worked: **30s, 60s, 90s, 440s, 600s, 720s, 1080s**; each frame takes 1–3 seconds,
and **the whole video never needs to be downloaded**. Output is 28–67 KB, 640×480.

### 6.4 A real trap hit: multi-part videos

`BV1HE421j7Lt` (graduate-exam data structures) shows "99 minutes", but that is the **sum of 8 parts**:

```
P1  626s   P2  886s   P3 1133s   P4  343s
P5 1211s   ...
```

The first time I computed `-ss 1486` from the total duration and got an empty file — because the cid requested was only P1 (626s), which was long out of range.
After fixing it to "validate against the duration of the matching P in `pages[]`", it worked.

**This is already in the script**: going out of range gives a warning in Chinese instead of silently producing an empty image.

### 6.5 Vision vs OCR: the same frame compared ⭐

The same frame (P2 @443s, handwritten blackboard writing), recognized two ways:

| Actual content | Model viewing the image | rapidocr |
|---|---|---|
| `if (a==10)` | ✅ | ❌ not recognized |
| `a = a + 10;` | ✅ | ❌ `a=a+lo;` |
| `else if (a>=5){` | ✅ | ⚠️ parentheses turned full-width |
| `a += 5;` | ✅ | ❌ `a=ats` |
| `printf("%d", a);` | ✅ | ✅ |
| `a++;` | ✅ | ❌ `att;` / `1=+V` |
| Color annotations (red/green/orange boxes) | ✅ | ❌ completely lost |

**Conclusion**: in code/blackboard scenes, **viewing the image is clearly better than OCR**; OCR can only be a fallback when no vision capability is available.
This also directly overturns the first version of this report's judgment that "DeepSeek can't view images" (that judgment was quoted from the `dsh-video-understand` README and is outdated).

### 6.6 7 bugs fixed in the script

See section 7 of [07-environment-setup.md](07-environment-setup.md). The most valuable one:
**PowerShell treats the logs ffmpeg writes to stderr as fatal errors**, and under `ErrorActionPreference='Stop'` it aborts the script outright —
which shows up as "TLS flakiness made the whole frame-grabbing task fail".

---

## 7. What was **not** verified (you must know this)

| Item | Why it was not tested | Impact |
|---|---|---|
| **Actually installing any plugin** | Installing a third-party plugin = trusting its author's code, and **DSH must be restarted for it to take effect** (which interrupts the current session); it is an action that should be your decision | All "plugin capability" descriptions in this document come from READMEs, not from runtime measurement |
| Plugin runtime behavior (whether tools get mounted, return format) | Same as above | First use may require troubleshooting per the checklist in [04](04-install-and-pitfalls.md) |
| 1080P/720P quality | Requires Bilibili login; not logged in | Anonymous cap is 640×480; how much better it gets after login is unverified |
| Actual transcription quality of local ASR | The environment is set up, but no real long audio has been run | Accuracy, time cost, and hallucination rate are unknown |
| DeepSeek's actual token consumption | No billing statistics were done | Cost ranges are estimates, not a bill |

> Compared with the first version, **the ffmpeg/Python frame-grabbing effect has been measured** (see section 6);
> what remains unverified is concentrated in "plugin runtime" and "capabilities after login".

**In other words: environment, network, packages, versions, frame grabbing, image viewing, and scripts have all been verified; plugin runtime behavior has not.**
I want you to be clear about this boundary — it is the difference between "installable" and "installed and working".

---

## 8. How you can verify it yourself

```powershell
# 1. Environment check (installs nothing)
cd <repo>
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Check

# 2. Re-check the Bilibili APIs (anonymous)
$h = @{ 'User-Agent'='Mozilla/5.0'; 'Referer'='https://www.bilibili.com/' }
(Invoke-RestMethod 'https://api.bilibili.com/x/web-interface/view?bvid=BV1GJ411x7h7' -Headers $h).data.title

# 3. Re-check package versions
npm view dsh-bili-watch version engines
npm view dsh-bili-study version engines

# 4. Confirm the profile's current state
Get-Content "$env:USERPROFILE\.dsh\profiles\web\package.json" -Raw | ConvertFrom-Json |
  Select-Object -ExpandProperty dependencies

# 5. Re-check the full frame-grabbing chain (multi-part video, P5 specified)
.\bili-frame.ps1 -Video BV1HE421j7Lt -At 12:00 -Page 5 -OutDir .\verify
# expected: outputs ...P5_720s.jpg (about 60 KB) + review link ?p=5&t=720
```

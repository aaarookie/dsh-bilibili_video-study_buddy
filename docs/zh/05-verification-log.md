# 05 · 实测验证记录

> 本文记录 2026-11-13 在本机的真实测试，**没测的会明说**。
> 目的是把"README 说能"和"你这台机器上真能"区分开。

---

## 一、测试环境

| 项 | 值 |
|---|---|
| 系统 | Windows（PowerShell 5.1 为主 shell，`pwsh` 未安装） |
| 工作目录 | `<workspace>` |
| DSH | `0.2.2-rc.1`（源码 checkout：`E:\deepseekharness\deepseek-harness`） |
| DSH 启动方式 | `node apps/cli/lib/bin.js web --no-open`，监听 `127.0.0.1:3080` |
| profile | `web`（bundles 仅 `@deepseek-ai/dsh-base` + `@deepseek-ai/dsh-web-app`） |
| Node | `v24.19.0` |
| pnpm / git | 均已安装（`git 2.55.0.windows.2`） |
| winget | `v1.29.380` 可用 |
| 默认模型 | DeepSeek（仅配置 `DEEPSEEK_API_KEY`） |

---

## 二、B 站匿名接口可用性 —— 4/4 通过 ✅

这是整套方案能否成立的前提。用带浏览器 UA + Referer 的裸请求直接打（不经任何插件）：

| # | 接口 | 用途 | 结果 |
|---|---|---|---|
| 1 | `x/web-interface/view` | 元数据（标题/UP/时长/分P） | ✅ `code=0` |
| 2 | `x/web-interface/wbi/search/type` | 站内搜索 | ✅ `code=0`，命中 20 条 |
| 3 | `x/player/videoshot` | 官方截帧（`peek` 用，不下视频） | ✅ `code=0`，快照图可取 |
| 4 | `x/player/v2` | 字幕轨 | ⚠️ `code=0` 但**字幕轨数 = 0**（未登录） |

**原始证据：**

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

**三条结论：**

1. **本机网络能直连 B 站 API**，不需要代理。匿名就能拿元数据、搜索、截帧。
2. **字幕必须登录**。这一条决定了 `dsh-bili-watch` 装好后必须扫码（或填 SESSDATA）才拿得到 AI 字幕。
3. **搜索质量可用**：搜"操作系统"首条就是「王道计算机考研 操作系统」——B 站确实是考研/系统课的主阵地，
   这个生态对你的使用场景是对口的。

> 顺带验证了 `peek` 的"官方截帧"路径确实存在，意味着**没有 ffmpeg 也能拿到几张关键帧**。

---

## 三、npm 包状态核实 ✅

逐个查 registry，确认不是 README 吹的：

| 包 | 版本 | 月下载 | engines | 结论 |
|---|---|---:|---|---|
| `dsh-bili-watch` | 0.4.10 | 16,565 | `node >=22` | ✅ 本机 Node 24 满足 |
| `dsh-bili-eyes` | 0.8.3 | 3,742 | `node >=20` | ✅ |
| `dsh-bili-study` | 1.0.0 | 404 | `dsh >=0.2.1-rc.5 <0.3.0`；`node >=22.19.0` | ✅ 本机 0.2.2-rc.1 / Node 24.19.0 满足 |
| `dsh-video-understand` | 0.5.2 | 5,241 | `node >=18` | ✅（但仍需 ffmpeg） |
| `dsh-video-storyboard` | 0.7.4 | 34,935 | `node >=20` | ✅ |
| `dsh-bili-subagent` | 0.9.9 | 9,888 | `dsh >=0.2.1-rc.2`；`node >=22` | ✅（需 Python） |
| `dsh-bili-scroll` | 2.5.2 | 75,121 | `dsh >=0.1.7-rc.1`；`node >=22` | ✅（但不推荐） |
| `@ericwang1358/dsh-daily-flashcard` | 4.5.1 | — | — | ✅ 即 `dsh-web-studyhub`，存在 |
| `dsh-bili-summary` | — | — | — | ❌ 未上 npm，只能 `github:` |
| `dsh-video-coursemap` | — | — | — | ❌ 未上 npm |
| `bili-vision` | — | — | — | ❌ 未上 npm |
| `dsh-web-studyhub` | — | — | — | ⚠️ 用上表的 scope 包名 |

**结论**：`dsh-bili-watch` / `dsh-bili-eyes` / `dsh-bili-study` 三个可以直接 `npm add`，
不用 git、不用编译，落地风险最低。

---

## 四、安装脚本自测 ✅

`install.ps1` 已用 `-Check` 和 `-WhatIf` 实跑过，输出正常：

```
[OK]      DSH 入口  E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js
[OK]      DSH 版本  0.2.2-rc.1
[OK]      Node      v24.19.0
[OK]      pnpm      已安装
[OK]      git       已安装
[MISSING] ffmpeg    未安装
[MISSING] Python    只有 Windows 应用商店存根，不是真解释器
```

**一个已修的坑**：脚本原本写成 `Test-CommandExists 'ffmpeg' -and (...)`，
PowerShell 会把 `-and` 当成函数参数解析，导致 `$ffmpegOk` 恒为真。
已改为 `(Test-CommandExists 'ffmpeg') -and (...)`，并在 PS 5.1 下验证通过。

**另一个坑（编码）**：本机没有 `pwsh`，只有 Windows PowerShell 5.1，它读 **UTF-8 无 BOM** 的 `.ps1`
会把中文读成乱码。所以 `install.ps1` 已保存为 **UTF-8 with BOM**。
（反过来，**profile 里的 `package.json` 绝不能带 BOM**，否则 DSH 启动崩——两者要求相反，别记混。）

**运行方式**：

```powershell
cd <repo>
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Check
```

---

## 五、`dsh` CLI 可用性 ✅

`dsh` 不在 PATH，但 checkout 里的入口可正常调用：

```
node E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js --version
→ 0.2.2-rc.1

node ...\bin.js plugin --help
→ manage a profile's plugins by forwarding the remaining arguments to pnpm
  --profile <name>  the profile whose plugins to manage (initialized on first use)
```

注意两点：
- **`dsh plugin` 只是 pnpm 的转发器**，所以 pnpm 必需（已装）。
- `dsh plugin --profile web list` 在本机输出为空（pnpm 在非 TTY 下的行为），
  想确认装了什么，直接看 `~/.dsh/profiles/web/package.json` 的 `dependencies` 更可靠。

---

## 六、第二轮实测：环境配置 + 时间点抽帧 ✅

### 6.1 工具安装结果

| 工具 | 版本 | 体积 | 实测 |
|---|---|---|---|
| ffmpeg | `N-92722`（2018 构建） | 61.5 MB | ✅ 合成/抽帧/libx264 编码均通过 |
| ffprobe | `2023-02-13 essentials` | 77.2 MB | ✅ 读时长、流信息 |
| yt-dlp | `2026.10.26` | 22.5 MB | ✅ 解析 B 站元数据（视频格式需登录） |
| uv | `0.13.8` | 46.4 MB | ✅ `uv python install 3.12` 成功 |
| Python 3.12 | `3.12.16` | 62.1 MB | ✅ 供 ASR/OCR |
| ASR/OCR venv | — | 404.1 MB | ✅ 四个包全部 import 成功 |

**一个关键取舍**：gyan.dev 官方源实测只有 **43 KB/s**（109 MB 要 45 分钟），
改走 npm 的 `@ffmpeg-installer/win32-x64`，**20 秒**下完。代价是版本老（2018），
但 H.264/HEVC 解码、`-ss` 定位、JPEG 输出全部实测可用。

### 6.2 关于你的 Python：其实一直都有

```
py -0p
  -V:3.14[-64] *   %USERPROFILE%\AppData\Local\Python\pythoncore-3.14-64\python.exe
```

`python --version` 之所以报 "not found"，是因为 PATH 里
`WindowsApps`（应用商店存根）排在 `AppData\Local\Python\bin`（真 3.14）**前面**。
不是没装，是被遮蔽。

3.14 保留不动；ASR/OCR 另建 3.12 venv，实测一次装成：

```
faster-whisper 1.2.1 / ctranslate2 4.9.0 / onnxruntime 1.32.0 / cv2 5.0.0
```

### 6.3 时间点抽帧全链路 ✅

```
匿名 view 接口 → cid
匿名 playurl(fnval=16) → DASH 4 条视频轨（hev1/avc1 各两档）
ffmpeg -ss <秒> -i <流地址> -frames:v 1 → jpg
```

实测通过的抽帧点：**30s、60s、90s、440s、600s、720s、1080s**，每帧 1~3 秒完成，
**不需要下载整段视频**。产物 28~67 KB，640×480。

### 6.4 踩到的真实陷阱：多 P 视频

`BV1HE421j7Lt`（考研数据结构）显示"99 分钟"，但那是 **8 个 P 的总和**：

```
P1  626s   P2  886s   P3 1133s   P4  343s
P5 1211s   ...
```

第一次我按总时长算 `-ss 1486`，抽出来是空文件——因为请求的 cid 只是 P1（626s），早就越界了。
修正为"按 `pages[]` 里对应 P 的 duration 校验"后成功。

**这条已写进脚本**：越界会直接给中文警告，不会静默产出空图。

### 6.5 视觉 vs OCR：同一帧的对比 ⭐

同一帧画面（P2 @443s，手写板书），两种识别方式：

| 真实内容 | 模型看图 | rapidocr |
|---|---|---|
| `if (a==10)` | ✅ | ❌ 未识别 |
| `a = a + 10;` | ✅ | ❌ `a=a+lo;` |
| `else if (a>=5){` | ✅ | ⚠️ 括号变全角 |
| `a += 5;` | ✅ | ❌ `a=ats` |
| `printf("%d", a);` | ✅ | ✅ |
| `a++;` | ✅ | ❌ `att;` / `1=+V` |
| 颜色标注（红/绿/橙框） | ✅ | ❌ 完全丢失 |

**结论**：代码/板书场景下，**看图显著优于 OCR**；OCR 只能作为没有视觉能力时的兜底。
这也直接推翻了本报告第一版"DeepSeek 看不了图"的判断（该判断引自 `dsh-video-understand` README，已过时）。

### 6.6 脚本修掉的 7 个 bug

见 [07-environment-setup.md](07-environment-setup.md) 第七节。其中最有价值的一个是：
**PowerShell 会把 ffmpeg 写到 stderr 的日志当成致命错误**，在 `ErrorActionPreference='Stop'` 下直接中断脚本——
表现为"TLS 抖动导致整个抽帧任务失败"。

---

## 七、**没有**验证的部分（务必知道）

| 项 | 为什么没测 | 影响 |
|---|---|---|
| **实际安装任何插件** | 装第三方插件 = 信任其作者代码，且**必须重启 DSH 才生效**（会中断当前会话），属于应由你决定的动作 | 本文所有"插件能力"描述来自 README，非运行实测 |
| 插件运行时行为（工具是否挂载、返回格式） | 同上 | 首次使用可能需要按 [04](04-install-and-pitfalls.md) 的清单排查 |
| 1080P/720P 画质 | 需要 B 站登录，未登录 | 匿名上限 640×480；登录后能提升多少未验证 |
| 本地 ASR 的实际转写质量 | 环境装好了，但没跑真实长音频 | 转写准确率、耗时、幻觉率属未知 |
| DeepSeek 的实际 token 消耗 | 未做计费统计 | 成本区间是估算，不是账单 |

> 与第一版相比，**ffmpeg/Python 抽帧效果已经实测**（见第六节），
> 剩下没验证的集中在"插件运行时"和"登录后能力"。

**换句话说：环境、网络、包、版本、抽帧、看图、脚本都验证过了；插件的运行时行为没有。**
这个边界我希望你清楚——它是"可安装"和"已装好用"之间的差别。

---

## 八、你可以这样复核

```powershell
# 1. 环境体检（不装任何东西）
cd <repo>
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Check

# 2. 复核 B 站接口（匿名）
$h = @{ 'User-Agent'='Mozilla/5.0'; 'Referer'='https://www.bilibili.com/' }
(Invoke-RestMethod 'https://api.bilibili.com/x/web-interface/view?bvid=BV1GJ411x7h7' -Headers $h).data.title

# 3. 复核包版本
npm view dsh-bili-watch version engines
npm view dsh-bili-study version engines

# 4. 确认 profile 现状
Get-Content "$env:USERPROFILE\.dsh\profiles\web\package.json" -Raw | ConvertFrom-Json |
  Select-Object -ExpandProperty dependencies

# 5. 复核抽帧全链路（多 P 视频，指定 P5）
.\bili-frame.ps1 -Video BV1HE421j7Lt -At 12:00 -Page 5 -OutDir .\verify
# 期望：输出 ...P5_720s.jpg（约 60 KB）+ 回看链接 ?p=5&t=720
```
